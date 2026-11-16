--!strict
-- Space Base Odyssey - Settings: a button in the top-right corner opens a panel with two pages.
-- "Game" page:
--   * Language (English / Spanish; Roblox can also auto-translate the experience),
--   * Music and Effects volume sliders (SoundService.SBO_Music and SoundService.SBO_SFX SoundGroups;
--     every sound joins one of these groups, see Audio.luau),
--   * C.A.R.L. fun facts on/off and C.A.R.L. guidance on/off,
--   * a "Redeem code" box. The server checks the code (src/server/Codes.luau, never sent to clients)
--     and answers through C.A.R.L. (carl.code_ok / carl.code_used / carl.code_bad); the answer also
--     shows inside the panel. Owned event cosmetics are listed under the box.
--   * Stage 10 (playtest: "I did not know how to save"): "Your game saves by itself" and a
--     "Save now" button (Action SaveNow; the server saves the loaded slot as soon as the DataStore
--     allows, and SaveIndicator.luau shows the "Game saved" pill when it lands). Rows are a bit
--     shorter to make room.
-- Stage 11 menu, "Helpers" page (accessibility): Text size (normal / big: Ui's text helpers read
-- Store.textScale), Less motion (Store.reduceMotion: no camera shake or big tweens), Message time
-- (Store.messageSeconds: C.A.R.L.'s bubbles stay longer) and Colour helper (Store.colourHelper:
-- shapes next to colour-only signals). Each row has a one-line explanation, and a sample line shows
-- the chosen text size.
-- Settings live in the Store. Stage 11 menu: the Store saves every change on the server (SaveSettings,
-- debounced; the language through SetLanguage), so they come back after a teleport or a rejoin.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef

local ROLE = Ui.ROLE

local MUSIC_GROUP = "SBO_Music"
local SFX_GROUP = "SBO_SFX"
local CODE_MAX_LENGTH = 24 -- same limit as the server
local REDEEM_COOLDOWN = 2 -- seconds; the server rate-limits too
local SAVE_NOW_COOLDOWN = 3 -- seconds between "Save now" presses; the server rate-limits too
local Z = 62 -- above every other screen (C.A.R.L. bubble 50, panels 55-60)

local Settings = {}

export type SettingsView = {
	render: () -> (),
	open: () -> (),
	close: () -> (),
	-- Show the server's answer to a code (a carl.code_* TextRef) inside the panel.
	showRedeemResult: (ref: TextRef) -> (),
}

type Page = "game" | "help"

local function soundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

function Settings.new(root: Frame): SettingsView
	Store.loadSettings()
	local musicGroup = soundGroup(MUSIC_GROUP)
	local sfxGroup = soundGroup(SFX_GROUP)
	local function applyVolumes()
		musicGroup.Volume = Store.settingNumber("musicVolume")
		sfxGroup.Volume = Store.settingNumber("effectsVolume")
	end
	applyVolumes()

	local modal = Ui.modal(root, "Settings", Z)
	local panel = Ui.panel(modal, {
		name = "Panel",
		size = UDim2.fromScale(0.5, 0.86),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.05,
		stroke = 4,
		strokeColor = ROLE.accent,
		zindex = Z + 1,
	})
	panel.Active = true

	-- Header: icon + title, the two page tabs, close button.
	Ui.icon(panel, Ui.ICONS.repair, {
		size = UDim2.fromScale(0.08, 0.07),
		position = UDim2.fromScale(0.04, 0.075),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = Z + 2,
	})
	local title = Ui.label(panel, {
		name = "Title",
		size = UDim2.fromScale(0.27, 0.08),
		position = UDim2.fromScale(0.12, 0.075),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 34,
		zindex = Z + 2,
	})

	local function close()
		modal.Visible = false
	end
	Ui.button(panel, {
		name = "Close",
		size = UDim2.fromScale(0.1, 0.09),
		position = UDim2.fromScale(0.97, 0.03),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 2,
	}, close)

	-- Stage 11 menu: two pages in the same panel.
	local pages: { [Page]: Frame } = {
		game = Ui.frame(panel, { name = "GamePage", zindex = Z + 1 }),
		help = Ui.frame(panel, { name = "HelpPage", zindex = Z + 1, visible = false }),
	}
	local currentPage: Page = "game"
	local render: () -> ()
	local tabs: { [Page]: TextButton } = {}
	for index, page in { "game", "help" } :: { Page } do
		tabs[page] = Ui.button(panel, {
			name = if page == "game" then "GameTab" else "HelpTab",
			size = UDim2.fromScale(0.22, 0.075),
			position = UDim2.fromScale(0.4 + (index - 1) * 0.235, 0.075),
			anchor = Vector2.new(0, 0.5),
			color = Ui.COLORS.secondary,
			stroke = 2,
			corner = 0.4,
			icon = if page == "game" then Ui.ICONS.play else Ui.ICONS.pointer,
			maxText = 22,
			zindex = Z + 3,
		}, function()
			if currentPage ~= page then
				currentPage = page
				render()
			end
		end)
	end

	-- One labelled row: icon, label on the left, control area on the right (returned).
	local ROW_HEIGHT = 0.085 -- Stage 10: rows every 0.1 (was 0.095 every 0.115) to fit the save row
	local function row(parent: Frame, name: string, y: number, image: string, tint: Color3): (TextLabel, Frame)
		local frame = Ui.frame(parent, {
			name = name,
			size = UDim2.fromScale(0.9, ROW_HEIGHT),
			position = UDim2.fromScale(0.05, y),
			color = ROLE.panelRaised,
			corner = 0.3,
			zindex = Z + 1,
		})
		Ui.icon(frame, image, {
			size = UDim2.fromScale(0.08, 0.6),
			position = UDim2.fromScale(0.02, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = tint,
			zindex = Z + 2,
		})
		local label = Ui.body(frame, {
			name = "Label",
			size = UDim2.fromScale(0.4, 0.7),
			position = UDim2.fromScale(0.12, 0.5),
			anchor = Vector2.new(0, 0.5),
			maxText = 22,
			minText = 9,
			zindex = Z + 2,
		})
		local control = Ui.frame(frame, {
			name = "Control",
			size = UDim2.fromScale(0.45, 0.76),
			position = UDim2.fromScale(0.53, 0.5),
			anchor = Vector2.new(0, 0.5),
			zindex = Z + 2,
		})
		return label, control
	end

	local gamePage = pages.game
	local helpPage = pages.help

	-- Language ----------------------------------------------------------------------------------
	local languageLabel, languageControl = row(gamePage, "Language", 0.135, Ui.ICONS.language, ROLE.accent)
	-- Two buttons with the language codes; the chosen one is cyan.
	local LANGUAGE_CODES: { [Store.Language]: string } = { en = "EN", es = "ES" }
	local languageButtons: { [Store.Language]: TextButton } = {}
	for index, language in { "en", "es" } :: { Store.Language } do
		languageButtons[language] = Ui.button(languageControl, {
			name = LANGUAGE_CODES[language],
			text = LANGUAGE_CODES[language],
			size = UDim2.fromScale(0.47, 1),
			position = UDim2.fromScale((index - 1) * 0.53, 0),
			color = Ui.COLORS.secondary,
			stroke = 2,
			corner = 0.4,
			maxText = 24,
			zindex = Z + 3,
		}, function()
			-- Stage 11 menu: shown at once and saved on the server (SetLanguage).
			Store.chooseLanguage(language)
		end)
	end

	-- Volume sliders ----------------------------------------------------------------------------
	type Slider = { set: (value: number) -> () }
	local function slider(control: Frame, setting: Store.SettingName, color: Color3): Slider
		local track = Instance.new("TextButton")
		track.Name = "Track"
		track.Text = ""
		track.AutoButtonColor = false
		track.BackgroundColor3 = Ui.COLORS.barBack
		track.BorderSizePixel = 0
		track.Size = UDim2.fromScale(0.72, 0.36)
		track.Position = UDim2.fromScale(0.04, 0.5)
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.ZIndex = Z + 3
		Ui.corner(track, 0.5)
		Ui.stroke(track, 2, ROLE.stroke)
		track.Parent = control
		local fill = Ui.frame(track, {
			name = "Fill",
			color = color,
			corner = 0.5,
			zindex = Z + 4,
		})
		local knob = Ui.frame(track, {
			name = "Knob",
			size = UDim2.fromScale(1.9, 1.9),
			position = UDim2.fromScale(0, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			color = ROLE.text,
			corner = 0.5,
			stroke = 2,
			strokeColor = color,
			aspect = 1,
			zindex = Z + 5,
		})
		local valueLabel = Ui.label(control, {
			name = "Value",
			size = UDim2.fromScale(0.2, 0.8),
			position = UDim2.fromScale(1, 0.5),
			anchor = Vector2.new(1, 0.5),
			alignX = Enum.TextXAlignment.Right,
			maxText = 20,
			zindex = Z + 3,
		})
		local function show(value: number)
			fill.Size = UDim2.fromScale(value, 1)
			fill.Visible = value > 0.01
			knob.Position = UDim2.fromScale(value, 0.5)
			valueLabel.Text = `{math.floor(value * 100 + 0.5)}%`
		end
		local function fromX(x: number)
			local width = track.AbsoluteSize.X
			if width <= 0 then
				return
			end
			local value = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
			value = math.floor(value * 20 + 0.5) / 20 -- 5% steps
			show(value)
			-- The Store saves on the server once the drag pauses (debounced).
			Store.setSetting(setting, value)
		end
		local dragging: InputObject? = nil
		track.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = input
				fromX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if dragging == nil then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or (input.UserInputType == Enum.UserInputType.Touch and input == dragging)
			then
				fromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				dragging ~= nil
				and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragging)
			then
				dragging = nil
			end
		end)
		show(Store.settingNumber(setting))
		return { set = show }
	end

	local musicLabel, musicControl = row(gamePage, "Music", 0.235, Ui.ICONS.play, ROLE.reward)
	local musicSlider = slider(musicControl, "musicVolume", ROLE.reward)
	local effectsLabel, effectsControl = row(gamePage, "Effects", 0.335, Ui.ICONS.cell, ROLE.star)
	local effectsSlider = slider(effectsControl, "effectsVolume", ROLE.star)

	-- On / off toggles --------------------------------------------------------------------------
	type Toggle = { button: TextButton, setting: Store.SettingName }
	local toggles: { Toggle } = {}
	local function toggle(control: Frame, setting: Store.SettingName): Toggle
		local button = Ui.button(control, {
			name = "Toggle",
			color = Ui.COLORS.go,
			stroke = 2,
			corner = 0.4,
			maxText = 22,
			zindex = Z + 3,
		}, function()
			Store.setSetting(setting, not Store.settingOn(setting))
		end)
		local entry = { button = button, setting = setting }
		table.insert(toggles, entry)
		return entry
	end
	local factsLabel, factsControl = row(gamePage, "FunFacts", 0.435, Ui.ICONS.book, ROLE.star)
	toggle(factsControl, "funFacts")
	local guideLabel, guideControl = row(gamePage, "Guidance", 0.535, Ui.ICONS.robot, ROLE.accent)
	toggle(guideControl, "guidance")

	-- Stage 10: save -----------------------------------------------------------------------------
	-- "Your game saves by itself" + "Save now". Grey (and ignored) until a world is loaded: the
	-- panel also opens from the start menu.
	local saveLabel, saveControl = row(gamePage, "Save", 0.635, Ui.ICONS.check, ROLE.good)
	local lastSaveNow = -math.huge
	local saveButton = Ui.button(saveControl, {
		name = "SaveNow",
		color = Ui.COLORS.go,
		stroke = 2,
		corner = 0.4,
		icon = Ui.ICONS.check,
		maxText = 22,
		zindex = Z + 3,
	}, function()
		if not Store.isSlotChosen() or os.clock() - lastSaveNow < SAVE_NOW_COOLDOWN then
			return
		end
		lastSaveNow = os.clock()
		Store.send({ type = "SaveNow" })
	end)

	-- Redeem code -------------------------------------------------------------------------------
	local redeem = Ui.frame(gamePage, {
		name = "Redeem",
		size = UDim2.fromScale(0.9, 0.25),
		position = UDim2.fromScale(0.05, 0.735),
		color = ROLE.panelRaised,
		corner = 0.12,
		stroke = 2,
		strokeColor = ROLE.reward,
		zindex = Z + 1,
	})
	Ui.icon(redeem, Ui.ICONS.gift, {
		size = UDim2.fromScale(0.08, 0.26),
		position = UDim2.fromScale(0.02, 0.17),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.reward,
		zindex = Z + 2,
	})
	local redeemTitle = Ui.label(redeem, {
		name = "Title",
		size = UDim2.fromScale(0.86, 0.26),
		position = UDim2.fromScale(0.12, 0.17),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.reward,
		maxText = 22,
		zindex = Z + 2,
	})
	local box = Instance.new("TextBox")
	box.Name = "Code"
	box.Size = UDim2.fromScale(0.6, 0.3)
	box.Position = UDim2.fromScale(0.03, 0.48)
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.BackgroundColor3 = ROLE.background
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Font = Ui.BODY_FONT
	box.TextColor3 = ROLE.text
	box.PlaceholderColor3 = ROLE.textDim
	box.TextScaled = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ZIndex = Z + 3
	Ui.corner(box, 0.3)
	Ui.stroke(box, 2, ROLE.stroke)
	local boxPadding = Instance.new("UIPadding")
	boxPadding.PaddingLeft = UDim.new(0.04, 0)
	boxPadding.PaddingRight = UDim.new(0.04, 0)
	boxPadding.PaddingTop = UDim.new(0.15, 0)
	boxPadding.PaddingBottom = UDim.new(0.15, 0)
	boxPadding.Parent = box
	local boxText = Instance.new("UITextSizeConstraint")
	boxText.MaxTextSize = 24
	boxText.MinTextSize = 10
	boxText.Parent = box
	box.Parent = redeem
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > CODE_MAX_LENGTH then
			box.Text = string.sub(box.Text, 1, CODE_MAX_LENGTH)
		end
	end)

	local result = Ui.body(redeem, {
		name = "Result",
		size = UDim2.fromScale(0.94, 0.2),
		position = UDim2.fromScale(0.03, 0.78),
		anchor = Vector2.new(0, 0.5),
		maxText = 18,
		minText = 8,
		zindex = Z + 2,
	})
	local resultRef: TextRef? = nil

	local lastRedeem = -math.huge
	local function submit()
		local code = trim(box.Text)
		if code == "" or os.clock() - lastRedeem < REDEEM_COOLDOWN then
			return
		end
		lastRedeem = os.clock()
		local action: any = { type = "RedeemCode", code = string.sub(code, 1, CODE_MAX_LENGTH) }
		Store.send(action)
	end
	local redeemButton = Ui.button(redeem, {
		name = "RedeemButton",
		size = UDim2.fromScale(0.32, 0.32),
		position = UDim2.fromScale(0.97, 0.48),
		anchor = Vector2.new(1, 0.5),
		color = ROLE.reward,
		icon = Ui.ICONS.gift,
		maxText = 22,
		zindex = Z + 3,
	}, submit)
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	-- Stage 11 menu: the "Helpers" page (accessibility) --------------------------------------------
	-- A row of option buttons (the chosen one is cyan), for settings with more than on / off.
	type Choice = { setting: Store.SettingName, buttons: { { button: TextButton, value: number | boolean, key: string } } }
	local choices: { Choice } = {}
	local function choice(control: Frame, setting: Store.SettingName, options: { { value: number | boolean, key: string } }): Choice
		local entry: Choice = { setting = setting, buttons = {} }
		local count = #options
		local gap = 0.04
		local width = (1 - gap * (count - 1)) / count
		for index, option in options do
			local button = Ui.button(control, {
				name = `Option{index}`,
				size = UDim2.fromScale(width, 1),
				position = UDim2.fromScale((index - 1) * (width + gap), 0),
				color = Ui.COLORS.secondary,
				stroke = 2,
				corner = 0.4,
				maxText = 20,
				minText = 8,
				zindex = Z + 3,
			}, function()
				Store.setSetting(setting, option.value)
			end)
			table.insert(entry.buttons, { button = button, value = option.value, key = option.key })
		end
		table.insert(choices, entry)
		return entry
	end
	-- One explanation line under a helper row.
	local hints: { { label: TextLabel, key: string } } = {}
	local function hint(y: number, key: string)
		local label = Ui.body(helpPage, {
			name = "Hint",
			size = UDim2.fromScale(0.86, 0.05),
			position = UDim2.fromScale(0.07, y),
			textColor = ROLE.textDim,
			maxText = 18,
			minText = 8,
			zindex = Z + 2,
		})
		table.insert(hints, { label = label, key = key })
	end

	local HELP_STEP = 0.15
	local textLabel, textControl = row(helpPage, "TextSize", 0.135, Ui.ICONS.book, ROLE.accent)
	choice(textControl, "bigText", {
		{ value = false, key = "ui.help_text_normal" },
		{ value = true, key = "ui.help_text_big" },
	})
	hint(0.135 + ROW_HEIGHT + 0.005, "ui.help_text_hint")
	local motionLabel, motionControl = row(helpPage, "Motion", 0.135 + HELP_STEP, Ui.ICONS.moon, ROLE.reward)
	toggle(motionControl, "reduceMotion")
	hint(0.135 + HELP_STEP + ROW_HEIGHT + 0.005, "ui.help_motion_hint")
	local speedLabel, speedControl = row(helpPage, "MessageTime", 0.135 + HELP_STEP * 2, Ui.ICONS.hourglass, ROLE.star)
	do
		local options: { { value: number | boolean, key: string } } = {}
		local keys = { "ui.help_speed_normal", "ui.help_speed_long", "ui.help_speed_longer" }
		for index, speed in Store.MESSAGE_SPEEDS do
			table.insert(options, { value = speed, key = keys[index] or "ui.help_speed_longer" })
		end
		choice(speedControl, "messageSpeed", options)
	end
	hint(0.135 + HELP_STEP * 2 + ROW_HEIGHT + 0.005, "ui.help_speed_hint")
	local colourLabel, colourControl = row(helpPage, "ColourHelper", 0.135 + HELP_STEP * 3, Ui.ICONS.check, ROLE.good)
	toggle(colourControl, "colourHelper")
	hint(0.135 + HELP_STEP * 3 + ROW_HEIGHT + 0.005, "ui.help_colour_hint")
	-- A sample line in the chosen text size.
	local sampleBox = Ui.frame(helpPage, {
		name = "Sample",
		size = UDim2.fromScale(0.9, 0.2),
		position = UDim2.fromScale(0.05, 0.765),
		color = ROLE.background,
		corner = 0.15,
		stroke = 2,
		strokeColor = ROLE.stroke,
		zindex = Z + 1,
	})
	Ui.icon(sampleBox, Ui.ICONS.robot, {
		size = UDim2.fromScale(0.1, 0.5),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = Z + 2,
	})
	local sample = Ui.body(sampleBox, {
		name = "Text",
		size = UDim2.fromScale(0.82, 0.8),
		position = UDim2.fromScale(0.15, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 22,
		zindex = Z + 2,
	})

	local function renderResult()
		local ref = resultRef
		if ref then
			result.Text = Store.t(ref.key, ref.params)
			result.TextColor3 = if ref.key == "carl.code_ok"
				then ROLE.good
				elseif ref.key == "carl.code_used" then ROLE.star
				else ROLE.danger
			return
		end
		-- No answer yet: list owned event cosmetics (if any).
		local names: { string } = {}
		for _, id in Store.cosmeticIds() do
			table.insert(names, Store.t("cosmetic." .. id .. ".name"))
		end
		result.Text = table.concat(names, ", ")
		result.TextColor3 = ROLE.star
	end

	render = function()
		title.Text = Store.t("ui.settings")
		for page, frame in pages do
			frame.Visible = page == currentPage
		end
		for page, button in tabs do
			Ui.setButton(button, Store.t(if page == "game" then "ui.settings_tab_game" else "ui.settings_tab_help"))
			Ui.setButtonColor(button, if page == currentPage then ROLE.accent else Ui.COLORS.secondary)
		end
		languageLabel.Text = Store.t("ui.language")
		for language, button in languageButtons do
			Ui.setButtonColor(button, if Store.getLanguage() == language then ROLE.accent else Ui.COLORS.secondary)
		end
		musicLabel.Text = Store.t("ui.music_volume")
		effectsLabel.Text = Store.t("ui.effects_volume")
		musicSlider.set(Store.settingNumber("musicVolume"))
		effectsSlider.set(Store.settingNumber("effectsVolume"))
		factsLabel.Text = Store.t("ui.funfacts_toggle")
		guideLabel.Text = Store.t("ui.guidance_toggle")
		for _, entry in toggles do
			local on = Store.settingOn(entry.setting)
			Ui.setButton(entry.button, Store.t(if on then "ui.on" else "ui.off"), if on then Ui.ICONS.check else Ui.ICONS.close)
			Ui.setButtonColor(entry.button, if on then Ui.COLORS.go else Ui.COLORS.secondary)
		end
		saveLabel.Text = Store.t("ui.save_auto")
		Ui.setButton(saveButton, Store.t("ui.save_now"))
		Ui.setButtonLook(saveButton, Store.isSlotChosen(), Ui.COLORS.go)
		redeemTitle.Text = Store.t("ui.redeem_title")
		box.PlaceholderText = Store.t("ui.redeem_placeholder")
		Ui.setButton(redeemButton, Store.t("ui.redeem_button"))
		renderResult()
		-- Stage 11 menu: the Helpers page.
		textLabel.Text = Store.t("ui.help_text")
		motionLabel.Text = Store.t("ui.help_motion")
		speedLabel.Text = Store.t("ui.help_speed")
		colourLabel.Text = Store.t("ui.help_colour")
		for _, entry in choices do
			local current = Store.getSetting(entry.setting)
			for _, option in entry.buttons do
				local chosen = current == option.value
				-- The chosen option also gets a check mark (never colour alone).
				Ui.setButton(option.button, Store.t(option.key), if chosen then Ui.ICONS.check else "")
				Ui.setButtonColor(option.button, if chosen then ROLE.accent else Ui.COLORS.secondary)
			end
		end
		for _, entry in hints do
			entry.label.Text = Store.t(entry.key)
		end
		sample.Text = Store.t("ui.help_sample")
	end

	local function open()
		resultRef = nil
		render()
		modal.Visible = true
	end

	local function showRedeemResult(ref: TextRef)
		resultRef = ref
		if ref.key == "carl.code_ok" then
			box.Text = ""
		end
		renderResult()
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "settings" then
			applyVolumes()
			if modal.Visible then
				render()
			end
		elseif kind == "progress" and modal.Visible then
			renderResult()
		elseif kind == "slots" and modal.Visible then
			Ui.setButtonLook(saveButton, Store.isSlotChosen(), Ui.COLORS.go) -- a world just loaded
		end
	end)
	-- Stage 10: a slot that loads while the panel is open (no "slots" change is sent then).
	local localPlayer = game:GetService("Players").LocalPlayer
	if localPlayer then
		localPlayer:GetAttributeChangedSignal(Store.SLOT_CHOSEN_ATTRIBUTE):Connect(function()
			Ui.setButtonLook(saveButton, Store.isSlotChosen(), Ui.COLORS.go)
		end)
	end

	-- Top-right corner button (where the language button used to be).
	local gear = Ui.button(root, {
		name = "SettingsButton",
		size = UDim2.fromScale(0.17, 0.08),
		position = UDim2.fromScale(0.985, 0.02),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		strokeColor = ROLE.accent,
		icon = Ui.ICONS.repair,
		tint = ROLE.accent,
		maxText = 24,
		zindex = 60,
	}, function()
		if modal.Visible then
			close()
		else
			open()
		end
	end)

	local baseRender = render
	local function renderAll()
		Ui.setButton(gear, Store.t("ui.settings"))
		baseRender()
	end

	renderAll()
	return { render = renderAll, open = open, close = close, showRedeemResult = showRedeemResult }
end

return Settings
