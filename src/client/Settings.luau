--!strict
-- Space Base Odyssey - Settings: a button in the top-right corner opens a panel with
--   * Language (English / Spanish; Roblox can also auto-translate the experience),
--   * Music and Effects volume sliders (SoundService.SBO_Music and SoundService.SBO_SFX SoundGroups;
--     every future sound joins one of these groups),
--   * C.A.R.L. fun facts on/off and C.A.R.L. guidance on/off,
--   * a "Redeem code" box. The server checks the code (src/server/Codes.luau, never sent to clients)
--     and answers through C.A.R.L. (carl.code_ok / carl.code_used / carl.code_bad); the answer also
--     shows inside the panel. Owned event cosmetics are listed under the box.
-- Settings live in the Store and as attributes of the local player (Store.SETTING_ATTRIBUTES).
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
local Z = 62 -- above every other screen (C.A.R.L. bubble 50, panels 55-60)

local Settings = {}

export type SettingsView = {
	render: () -> (),
	open: () -> (),
	close: () -> (),
	-- Show the server's answer to a code (a carl.code_* TextRef) inside the panel.
	showRedeemResult: (ref: TextRef) -> (),
}

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

	-- Header: icon + title, close button.
	Ui.icon(panel, Ui.ICONS.repair, {
		size = UDim2.fromScale(0.08, 0.07),
		position = UDim2.fromScale(0.05, 0.075),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = Z + 2,
	})
	local title = Ui.label(panel, {
		name = "Title",
		size = UDim2.fromScale(0.62, 0.08),
		position = UDim2.fromScale(0.15, 0.075),
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
		position = UDim2.fromScale(0.96, 0.03),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 2,
	}, close)

	-- One labelled row: icon, label on the left, control area on the right (returned).
	local ROW_HEIGHT = 0.095
	local function row(name: string, y: number, image: string, tint: Color3): (TextLabel, Frame)
		local frame = Ui.frame(panel, {
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

	-- Language ----------------------------------------------------------------------------------
	local languageLabel, languageControl = row("Language", 0.14, Ui.ICONS.language, ROLE.accent)
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
			if Store.getLanguage() ~= language then
				Store.setLanguage(language)
				Store.send({ type = "SetLanguage", language = language })
			end
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

	local musicLabel, musicControl = row("Music", 0.255, Ui.ICONS.play, ROLE.reward)
	local musicSlider = slider(musicControl, "musicVolume", ROLE.reward)
	local effectsLabel, effectsControl = row("Effects", 0.37, Ui.ICONS.cell, ROLE.star)
	local effectsSlider = slider(effectsControl, "effectsVolume", ROLE.star)

	-- C.A.R.L. toggles --------------------------------------------------------------------------
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
	local factsLabel, factsControl = row("FunFacts", 0.485, Ui.ICONS.book, ROLE.star)
	toggle(factsControl, "funFacts")
	local guideLabel, guideControl = row("Guidance", 0.6, Ui.ICONS.robot, ROLE.accent)
	toggle(guideControl, "guidance")

	-- Redeem code -------------------------------------------------------------------------------
	local redeem = Ui.frame(panel, {
		name = "Redeem",
		size = UDim2.fromScale(0.9, 0.27),
		position = UDim2.fromScale(0.05, 0.715),
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

	local function render()
		title.Text = Store.t("ui.settings")
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
		redeemTitle.Text = Store.t("ui.redeem_title")
		box.PlaceholderText = Store.t("ui.redeem_placeholder")
		Ui.setButton(redeemButton, Store.t("ui.redeem_button"))
		renderResult()
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
		end
	end)

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
