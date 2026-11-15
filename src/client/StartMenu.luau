--!strict
-- Space Base Odyssey - start menu (Stage 9): the first screen, in the "Lunar Sunrise" identity. A dark
-- starfield, the turning Earth (NASA Blue Marble map), a sunrise glow on the Moon's horizon and the
-- game title, with:
--   * Continue   - loads the slot used last time (Store.continueSlot()),
--   * New game   - pick one of the 3 worlds; a world that is already used asks before it is wiped,
--   * Load game  - the 3 world cards: base level, player level, credits, last save, how it was played,
--   * Settings   - opens the existing Settings panel (it draws above this screen),
--   * Credits    - the team, the event and the data credits as text.
-- After a world is picked the player chooses "Just me" (solo: the server may move them to their own
-- reserved server) or "With friends" (this server; friends join with Roblox's Join button), and the
-- client sends Action ChooseSlot { slot, mode, fresh }. The player has no character until the server
-- loads the slot and sets the player attribute SBO_SlotChosen = true; then this screen closes.
-- A player teleported into their solo server (TeleportData { slot, mode }) never sees the menu again:
-- the server picks the slot there, so the screen only says "getting your base ready".
-- Layout (fractions of the screen; the root is 720 units tall and as wide as the device, so it fits a
-- phone in landscape): title x 0.06-0.56 y 0.07-0.25, buttons x 0.06-0.40 y 0.34-0.88, Earth on the
-- right, sub-screens in one centred panel 0.86 x 0.82.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type SlotInfo = Store.SlotInfo
type SlotMode = Store.SlotMode

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE
local ICONS = Ui.Icons

-- Above the HUD, the top bar (52), the Lab and Wardrobe (53), the cards (55-57) and the Settings
-- button (60); below the Settings panel (62), which opens on top of this screen.
local Z = 61
local PRESS_COOLDOWN = 0.35 -- seconds between two taps (no double sends)
local WAIT_TIMEOUT = 40 -- seconds without SBO_SlotChosen before the menu offers to go back
local STAR_COUNT = 90
local STAR_SEED = 2026 -- the same sky every time
local EARTH_TURN_SECONDS = 160 -- one full turn of the Earth picture
local ANIMATION_STEP = 1 / 30
local TEAM_SIZE = 4 -- ui.menu_team_1 .. ui.menu_team_4

local StartMenu = {}

export type Deps = {
	openSettings: () -> (),
	closeSettings: () -> (),
}

export type StartMenuView = {
	render: () -> (),
	isOpen: () -> boolean,
	-- Close the menu for good (the slot is loaded, or an older server never sends slots).
	hide: () -> (),
}

type ScreenName = "home" | "slots" | "mode" | "credits" | "wait"
type Flow = "new" | "load"

type SlotCard = {
	button: TextButton,
	stroke: UIStroke,
	title: TextLabel,
	badge: Frame,
	badgeIcon: ImageLabel,
	lastPill: TextLabel,
	emptyTitle: TextLabel,
	emptyHint: TextLabel,
	rows: { Ui.IconText },
}

type ModeCard = {
	mode: SlotMode,
	button: TextButton,
	stroke: UIStroke,
	title: TextLabel,
	desc: TextLabel,
	lastPill: TextLabel,
}

type Star = { frame: Frame, base: number, speed: number, phase: number }

-- A small "pill" label (night fill, coloured text and stroke).
local function pill(parent: Instance, props: Ui.Props): TextLabel
	local withDefaults: Ui.Props = table.clone(props)
	withDefaults.color = props.color or ROLE.background
	withDefaults.corner = props.corner or 0.5
	withDefaults.stroke = props.stroke or 2
	withDefaults.strokeColor = props.strokeColor or props.textColor or ROLE.accent
	withDefaults.maxText = props.maxText or 18
	return Ui.label(parent, withDefaults)
end

-- Recolour a menu button's icon (Ui.setButtonLook paints it the text colour).
local function tintIcon(button: TextButton, color: Color3)
	local icon = button:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		icon.ImageColor3 = color
	end
end

-- "Saved just now" / "Saved 5 min ago" / ... from a save time in os.time() seconds.
local function savedText(savedAt: number?): string
	if savedAt == nil then
		return ""
	end
	local seconds = math.max(0, workspace:GetServerTimeNow() - savedAt)
	if seconds < 90 then
		return Store.t("ui.menu_saved_now")
	elseif seconds < 3600 then
		return Store.t("ui.menu_saved_min", { n = math.floor(seconds / 60) })
	elseif seconds < 7200 then
		return Store.t("ui.menu_saved_hour")
	elseif seconds < 86400 then
		return Store.t("ui.menu_saved_hours", { n = math.floor(seconds / 3600) })
	elseif seconds < 172800 then
		return Store.t("ui.menu_saved_day")
	end
	return Store.t("ui.menu_saved_days", { n = math.floor(seconds / 86400) })
end

local function modeKey(mode: SlotMode): string
	return if mode == "friends" then "ui.menu_mode_friends" else "ui.menu_mode_solo"
end

local function modeIcon(mode: SlotMode): string
	return if mode == "friends" then ICONS.language else ICONS.helmet
end

local function modeColor(mode: SlotMode): Color3
	return if mode == "friends" then ROLE.good else ROLE.accent
end

-- The slot and mode this player was teleported with (their own solo server), if any.
local function teleportSlot(): (number?, SlotMode?)
	local ok, data = pcall(function(): any
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	if not ok or type(data) ~= "table" then
		return nil, nil
	end
	local slot = tonumber(data.slot)
	if slot == nil or slot ~= math.floor(slot) or slot < 1 or slot > Store.SLOT_COUNT then
		return nil, nil
	end
	local mode: SlotMode = if data.mode == "friends" then "friends" else "solo"
	return slot, mode
end

function StartMenu.new(root: Frame, deps: Deps): StartMenuView
	local player = Players.LocalPlayer

	local screen = Ui.frame(root, {
		name = "StartMenu",
		color = ROLE.background,
		zindex = Z,
		visible = not Store.isSlotChosen(),
	})
	screen.Active = true -- taps never reach the world behind
	screen.ClipsDescendants = true
	-- A lighter night near the horizon (an overlay: a UIGradient colour would darken the fill).
	local depth = Ui.frame(screen, { name = "Depth", color = PALETTE.nightLight, zindex = Z })
	do
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new(1, 0.2)
		gradient.Parent = depth
	end

	-- Background: stars, the Earth, the sunrise glow and the Moon's horizon with a tiny base -------

	local sky = Ui.frame(screen, { name = "Sky", zindex = Z + 1 })
	local stars: { Star } = {}
	do
		local random = Random.new(STAR_SEED)
		local colours = { PALETTE.cream, PALETTE.cream, PALETTE.cream, PALETTE.cyan, PALETTE.gold }
		for index = 1, STAR_COUNT do
			local size = random:NextInteger(2, 5)
			local frame = Ui.frame(sky, {
				name = `Star{index}`,
				size = UDim2.fromOffset(size, size),
				position = UDim2.fromScale(random:NextNumber(0, 1), random:NextNumber(0, 0.78)),
				anchor = Vector2.new(0.5, 0.5),
				color = colours[random:NextInteger(1, #colours)],
				corner = 0.5,
				zindex = Z + 1,
			})
			local base = random:NextNumber(0, 0.45)
			frame.BackgroundTransparency = base
			table.insert(stars, {
				frame = frame,
				base = base,
				speed = random:NextNumber(0.6, 2.2),
				phase = random:NextNumber(0, math.pi * 2),
			})
		end
	end

	-- The Earth: the Blue Marble map scrolls inside a round CanvasGroup (it clips to its corner), with
	-- a soft night side and a thin cyan air glow.
	local earthHolder = Ui.frame(screen, {
		name = "Earth",
		size = UDim2.fromScale(0.44, 0.44),
		position = UDim2.fromScale(0.78, 0.36),
		anchor = Vector2.new(0.5, 0.5),
		aspect = 1,
		zindex = Z + 2,
	})
	Ui.frame(earthHolder, {
		name = "Glow",
		size = UDim2.fromScale(1.12, 1.12),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.cyan,
		transparency = 0.82,
		corner = 0.5,
		zindex = Z + 2,
	})
	local earthGroup = Instance.new("CanvasGroup")
	earthGroup.Name = "Globe"
	earthGroup.Size = UDim2.fromScale(1, 1)
	earthGroup.BackgroundColor3 = PALETTE.night
	earthGroup.BorderSizePixel = 0
	earthGroup.ZIndex = Z + 3
	Ui.corner(earthGroup, 0.5)
	earthGroup.Parent = earthHolder
	local maps: { ImageLabel } = {}
	for index = 1, 2 do
		local map = Instance.new("ImageLabel")
		map.Name = `Map{index}`
		map.BackgroundTransparency = 1
		map.Image = ICONS.earthMap
		map.ScaleType = Enum.ScaleType.Stretch
		map.Size = UDim2.fromScale(2, 1) -- the map is twice as wide as it is tall
		map.Position = UDim2.fromScale((index - 1) * 2, 0)
		map.ZIndex = Z + 3
		map.Parent = earthGroup
		table.insert(maps, map)
	end
	local nightSide = Ui.frame(earthGroup, { name = "NightSide", color = PALETTE.night, zindex = Z + 4 })
	do
		local shade = Instance.new("UIGradient")
		shade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.4, 0.55),
			NumberSequenceKeypoint.new(0.68, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		shade.Parent = nightSide
	end
	Ui.stroke(earthGroup, 2, PALETTE.cyan).Transparency = 0.35

	-- Sunrise glow over the horizon, the grey Moon and a tiny base with a blinking light.
	local glow = Ui.frame(screen, {
		name = "SunriseGlow",
		size = UDim2.fromScale(1, 0.42),
		position = UDim2.fromScale(0, 0.58),
		color = PALETTE.orange,
		zindex = Z + 2,
	})
	do
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.65, 0.8),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		gradient.Parent = glow
	end
	local moon = Ui.frame(screen, {
		name = "MoonHorizon",
		size = UDim2.fromScale(1.7, 0.5),
		position = UDim2.fromScale(0.5, 1.12),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.creamDim:Lerp(PALETTE.night, 0.62),
		corner = 0.5,
		zindex = Z + 3,
	})
	for index, crater in { { 0.36, 0.12, 0.05 }, { 0.52, 0.2, 0.035 }, { 0.6, 0.1, 0.025 }, { 0.43, 0.3, 0.03 } } do
		Ui.frame(moon, {
			name = `Crater{index}`,
			size = UDim2.fromScale(crater[3], crater[3] * 1.4),
			position = UDim2.fromScale(crater[1], crater[2]),
			anchor = Vector2.new(0.5, 0.5),
			color = PALETTE.night,
			transparency = 0.7,
			corner = 0.5,
			zindex = Z + 4,
		})
	end
	local baseDome = Ui.frame(screen, {
		name = "BaseDome",
		size = UDim2.fromScale(0.07, 0.07),
		position = UDim2.fromScale(0.62, 0.885),
		anchor = Vector2.new(0.5, 1),
		color = PALETTE.nightLight,
		corner = 0.5,
		aspect = 1.8,
		stroke = 2,
		strokeColor = PALETTE.nightLine,
		zindex = Z + 3,
	})
	Ui.frame(baseDome, {
		name = "Window",
		size = UDim2.fromScale(0.22, 0.3),
		position = UDim2.fromScale(0.5, 0.42),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.cyan,
		corner = 0.5,
		zindex = Z + 4,
	})
	local mast = Ui.frame(screen, {
		name = "Mast",
		size = UDim2.fromScale(0.004, 0.09),
		position = UDim2.fromScale(0.665, 0.875),
		anchor = Vector2.new(0.5, 1),
		color = PALETTE.creamDim,
		zindex = Z + 3,
	})
	local beacon = Ui.frame(mast, {
		name = "Beacon",
		size = UDim2.fromOffset(9, 9),
		position = UDim2.fromScale(0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.magenta,
		corner = 0.5,
		zindex = Z + 4,
	})

	-- Home: title and the menu buttons -------------------------------------------------------------

	local home = Ui.frame(screen, { name = "Home", zindex = Z + 5 })
	local title = Ui.label(home, {
		name = "Title",
		size = UDim2.fromScale(0.52, 0.17),
		position = UDim2.fromScale(0.06, 0.07),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.warning,
		maxText = 84,
		outline = true,
		zindex = Z + 6,
	})
	Ui.frame(home, {
		name = "TitleLine",
		size = UDim2.fromScale(0.16, 0.008),
		position = UDim2.fromScale(0.06, 0.245),
		color = ROLE.accent,
		corner = 0.5,
		zindex = Z + 6,
	})
	local pitch = Ui.body(home, {
		name = "Pitch",
		size = UDim2.fromScale(0.42, 0.06),
		position = UDim2.fromScale(0.06, 0.265),
		textColor = ROLE.textDim,
		maxText = 26,
		zindex = Z + 6,
	})

	local column = Ui.frame(home, {
		name = "Buttons",
		size = UDim2.fromScale(0.34, 0.54),
		position = UDim2.fromScale(0.06, 0.345),
		zindex = Z + 6,
	})
	local ROW = 0.205
	local ROW_STEP = 0.265

	local lastPress = 0
	local function pressAllowed(): boolean
		if os.clock() - lastPress < PRESS_COOLDOWN then
			return false
		end
		lastPress = os.clock()
		return true
	end

	-- Forward declarations: the screens below call each other.
	local showScreen: (name: ScreenName) -> ()
	local openSlots: (flow: Flow) -> ()
	local openMode: (slot: number, fresh: boolean, back: ScreenName) -> ()

	local continueButton = Ui.button(column, {
		name = "Continue",
		size = UDim2.fromScale(0.7, ROW),
		position = UDim2.fromScale(0, 0),
		icon = ICONS.play,
		maxText = 34,
		zindex = Z + 7,
	}, function()
		local slot = Store.continueSlot()
		if slot and pressAllowed() then
			openMode(slot, false, "home")
		end
	end)
	-- Which world Continue loads (night card beside the button).
	local continueTag = Ui.panel(column, {
		name = "ContinueWorld",
		size = UDim2.fromScale(0.27, ROW),
		position = UDim2.fromScale(0.73, 0),
		color = ROLE.background,
		strokeColor = ROLE.good,
		zindex = Z + 7,
	})
	local continueTagIcon = Ui.icon(continueTag, ICONS.home, {
		name = "Icon",
		size = UDim2.fromScale(0.3, 0.5),
		position = UDim2.fromScale(0.06, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.good,
		zindex = Z + 8,
	})
	local continueTagText = Ui.label(continueTag, {
		name = "World",
		size = UDim2.fromScale(0.6, 0.6),
		position = UDim2.fromScale(0.36, 0.5),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.good,
		maxText = 24,
		zindex = Z + 8,
	})

	local newButton = Ui.button(column, {
		name = "NewGame",
		size = UDim2.fromScale(1, ROW),
		position = UDim2.fromScale(0, ROW_STEP),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.rocket,
		tint = ROLE.accent,
		maxText = 34,
		zindex = Z + 7,
	}, function()
		if Store.getSlots() and pressAllowed() then
			openSlots("new")
		end
	end)
	local newStroke = newButton:FindFirstChildOfClass("UIStroke") :: UIStroke
	local loadButton = Ui.button(column, {
		name = "LoadGame",
		size = UDim2.fromScale(1, ROW),
		position = UDim2.fromScale(0, ROW_STEP * 2),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.data,
		tint = ROLE.accent,
		maxText = 34,
		zindex = Z + 7,
	}, function()
		if Store.getSlots() and pressAllowed() then
			openSlots("load")
		end
	end)
	local settingsButton = Ui.button(column, {
		name = "Settings",
		size = UDim2.fromScale(0.485, ROW),
		position = UDim2.fromScale(0, ROW_STEP * 3),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.stroke,
		icon = ICONS.repair,
		tint = ROLE.accent,
		maxText = 28,
		zindex = Z + 7,
	}, function()
		if pressAllowed() then
			deps.openSettings()
		end
	end)
	local creditsButton = Ui.button(column, {
		name = "Credits",
		size = UDim2.fromScale(0.485, ROW),
		position = UDim2.fromScale(0.515, ROW_STEP * 3),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.stroke,
		icon = ICONS.star,
		tint = ROLE.star,
		maxText = 28,
		zindex = Z + 7,
	}, function()
		if pressAllowed() then
			showScreen("credits")
		end
	end)
	-- "Getting ready..." until the server sends the slot list.
	local homeStatus = Ui.body(home, {
		name = "Status",
		size = UDim2.fromScale(0.34, 0.05),
		position = UDim2.fromScale(0.06, 0.9),
		textColor = ROLE.accent,
		maxText = 22,
		zindex = Z + 6,
	})
	local footer = Ui.body(screen, {
		name = "Event",
		size = UDim2.fromScale(0.4, 0.04),
		position = UDim2.fromScale(0.98, 0.975),
		anchor = Vector2.new(1, 1),
		alignX = Enum.TextXAlignment.Right,
		textColor = ROLE.textDim,
		maxText = 18,
		zindex = Z + 6,
	})

	-- The sub-screen panel: header (icon + title), back button, content -----------------------------

	local panel = Ui.panel(screen, {
		name = "Panel",
		size = UDim2.fromScale(0.86, 0.82),
		position = UDim2.fromScale(0.5, 0.53),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		transparency = 0.04,
		corner = 0.05,
		stroke = 4,
		strokeColor = ROLE.accent,
		zindex = Z + 10,
		visible = false,
	})
	panel.Active = true
	local panelIcon = Ui.icon(panel, ICONS.data, {
		name = "Icon",
		size = UDim2.fromScale(0.05, 0.09),
		position = UDim2.fromScale(0.03, 0.085),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = Z + 11,
	})
	local panelTitle = Ui.label(panel, {
		name = "Title",
		size = UDim2.fromScale(0.66, 0.1),
		position = UDim2.fromScale(0.09, 0.085),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 40,
		zindex = Z + 11,
	})
	local backTarget: ScreenName = "home"
	local backButton = Ui.button(panel, {
		name = "Back",
		size = UDim2.fromScale(0.17, 0.1),
		position = UDim2.fromScale(0.975, 0.035),
		anchor = Vector2.new(1, 0),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.close,
		tint = ROLE.text,
		maxText = 24,
		zindex = Z + 11,
	}, function()
		if pressAllowed() then
			showScreen(backTarget)
		end
	end)
	local function content(name: string): Frame
		return Ui.frame(panel, {
			name = name,
			size = UDim2.fromScale(0.94, 0.8),
			position = UDim2.fromScale(0.03, 0.17),
			zindex = Z + 11,
			visible = false,
		})
	end

	-- Slots: three world cards -------------------------------------------------------------------

	local slotsView = content("Slots")
	local flow: Flow = "load"
	local confirmSlot: number? = nil
	local confirm: Frame -- the "start this world again?" box (built below)

	local CARD_WIDTH = 0.31
	local CARD_GAP = 0.035
	local slotCards: { SlotCard } = {}
	for slot = 1, Store.SLOT_COUNT do
		local card: SlotCard
		local button = Ui.button(slotsView, {
			name = `Slot{slot}`,
			size = UDim2.fromScale(CARD_WIDTH, 0.84), -- Stage 10: was 0.9, the save line sits below
			position = UDim2.fromScale((1 - CARD_WIDTH * 3 - CARD_GAP * 2) / 2 + (CARD_WIDTH + CARD_GAP) * (slot - 1), 0.06),
			color = ROLE.panelRaised,
			corner = 0.07,
			zindex = Z + 12,
		}, function()
			local info = Store.slotInfo(slot)
			if info == nil or confirm.Visible or not pressAllowed() then
				return
			end
			if flow == "new" and info.used then
				confirmSlot = slot
				confirm.Visible = true
			else
				-- New game in an empty world, or Load: an empty world simply starts fresh.
				openMode(slot, flow == "new" or not info.used, "slots")
			end
		end)
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		local cardTitle = Ui.label(button, {
			name = "World",
			size = UDim2.fromScale(0.86, 0.11),
			position = UDim2.fromScale(0.5, 0.045),
			anchor = Vector2.new(0.5, 0),
			maxText = 30,
			zindex = Z + 13,
		})
		local badge = Ui.frame(button, {
			name = "Badge",
			size = UDim2.fromScale(0.6, 0.25),
			position = UDim2.fromScale(0.5, 0.175),
			anchor = Vector2.new(0.5, 0),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			stroke = 2,
			strokeColor = ROLE.stroke,
			zindex = Z + 13,
		})
		local badgeIcon = Ui.icon(badge, ICONS.home, {
			name = "Icon",
			size = UDim2.fromScale(0.6, 0.6),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			zindex = Z + 14,
		})
		local lastPill = pill(button, {
			name = "LastTime",
			size = UDim2.fromScale(0.6, 0.075),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0.5),
			textColor = ROLE.good,
			zindex = Z + 15,
			visible = false,
		})
		local emptyTitle = Ui.label(button, {
			name = "EmptyTitle",
			size = UDim2.fromScale(0.86, 0.11),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.textDim,
			maxText = 28,
			zindex = Z + 13,
		})
		local emptyHint = Ui.body(button, {
			name = "EmptyHint",
			size = UDim2.fromScale(0.8, 0.2),
			position = UDim2.fromScale(0.5, 0.64),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			textColor = ROLE.textDim,
			maxText = 20,
			zindex = Z + 13,
		})
		-- Base level, player level, credits, how it was played, last save.
		local rowIcons = { ICONS.home, ICONS.xp, ICONS.coin, ICONS.helmet, ICONS.clock }
		local rowTints = { ROLE.good, ROLE.reward, ROLE.star, ROLE.accent, ROLE.textDim }
		local rows: { Ui.IconText } = {}
		for index = 1, #rowIcons do
			local row = Ui.iconText(button, {
				name = `Row{index}`,
				size = UDim2.fromScale(0.86, 0.085),
				position = UDim2.fromScale(0.07, 0.465 + (index - 1) * 0.098),
				icon = rowIcons[index],
				tint = rowTints[index],
				textColor = if index == 5 then ROLE.textDim else ROLE.text,
				font = Ui.BODY_FONT,
				maxText = 20,
				zindex = Z + 13,
			})
			table.insert(rows, row)
		end
		card = {
			button = button,
			stroke = stroke,
			title = cardTitle,
			badge = badge,
			badgeIcon = badgeIcon,
			lastPill = lastPill,
			emptyTitle = emptyTitle,
			emptyHint = emptyHint,
			rows = rows,
		}
		table.insert(slotCards, card)
	end

	-- Stage 10: under the cards, "Your game saves by itself" (playtest: nobody knew how to save).
	local slotsSaveNote = Ui.body(slotsView, {
		name = "SaveNote",
		size = UDim2.fromScale(0.6, 0.06),
		position = UDim2.fromScale(0.5, 0.935),
		anchor = Vector2.new(0.5, 0.5),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.good,
		maxText = 20,
		zindex = Z + 12,
	})

	-- Confirm a wipe: covers the cards, asks once, "No" is the safe default on the left.
	confirm = Ui.modal(slotsView, "Confirm", Z + 20)
	confirm.Size = UDim2.fromScale(1.02, 1.05)
	confirm.Position = UDim2.fromScale(-0.01, -0.02)
	local confirmBox = Ui.panel(confirm, {
		name = "Box",
		size = UDim2.fromScale(0.62, 0.74),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panelRaised,
		corner = 0.08,
		stroke = 4,
		strokeColor = ROLE.warning,
		zindex = Z + 21,
	})
	confirmBox.Active = true
	Ui.icon(confirmBox, ICONS.alert, {
		name = "Icon",
		size = UDim2.fromScale(0.2, 0.2),
		position = UDim2.fromScale(0.5, 0.06),
		anchor = Vector2.new(0.5, 0),
		tint = ROLE.warning,
		zindex = Z + 22,
	})
	local confirmTitle = Ui.label(confirmBox, {
		name = "Title",
		size = UDim2.fromScale(0.9, 0.16),
		position = UDim2.fromScale(0.5, 0.29),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.warning,
		maxText = 36,
		zindex = Z + 22,
	})
	local confirmText = Ui.body(confirmBox, {
		name = "Text",
		size = UDim2.fromScale(0.86, 0.16),
		position = UDim2.fromScale(0.5, 0.47),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		maxText = 26,
		zindex = Z + 22,
	})
	local confirmNo = Ui.button(confirmBox, {
		name = "No",
		size = UDim2.fromScale(0.43, 0.2),
		position = UDim2.fromScale(0.05, 0.72),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.close,
		tint = ROLE.text,
		maxText = 26,
		zindex = Z + 22,
	}, function()
		confirm.Visible = false
		confirmSlot = nil
	end)
	local confirmYes = Ui.button(confirmBox, {
		name = "Yes",
		size = UDim2.fromScale(0.43, 0.2),
		position = UDim2.fromScale(0.52, 0.72),
		color = ROLE.dangerButton,
		icon = ICONS.restart,
		maxText = 26,
		zindex = Z + 22,
	}, function()
		local slot = confirmSlot
		if slot and pressAllowed() then
			confirm.Visible = false
			confirmSlot = nil
			openMode(slot, true, "slots")
		end
	end)

	-- Mode: "Just me" or "With friends" --------------------------------------------------------------

	local modeView = content("Mode")
	local chosenSlot = 1
	local chosenFresh = false
	local modeWorld = Ui.label(modeView, {
		name = "World",
		size = UDim2.fromScale(0.5, 0.08),
		position = UDim2.fromScale(0.5, 0),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.good,
		maxText = 28,
		zindex = Z + 12,
	})

	local sendChoice: (mode: SlotMode) -> ()
	local modeCards: { ModeCard } = {}
	for index, mode in { "solo", "friends" } :: { SlotMode } do
		local color = modeColor(mode)
		local button = Ui.button(modeView, {
			name = if mode == "solo" then "Solo" else "Friends",
			size = UDim2.fromScale(0.44, 0.8),
			position = UDim2.fromScale(if index == 1 then 0.04 else 0.52, 0.13),
			color = ROLE.panelRaised,
			corner = 0.08,
			strokeColor = color,
			zindex = Z + 12,
		}, function()
			if pressAllowed() then
				sendChoice(mode)
			end
		end)
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		local badge = Ui.frame(button, {
			name = "Badge",
			size = UDim2.fromScale(0.42, 0.36),
			position = UDim2.fromScale(0.5, 0.09),
			anchor = Vector2.new(0.5, 0),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			stroke = 3,
			strokeColor = color,
			zindex = Z + 13,
		})
		Ui.icon(badge, modeIcon(mode), {
			name = "Icon",
			size = UDim2.fromScale(0.6, 0.6),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			tint = color,
			zindex = Z + 14,
		})
		local modeTitle = Ui.label(button, {
			name = "Title",
			size = UDim2.fromScale(0.86, 0.14),
			position = UDim2.fromScale(0.5, 0.52),
			anchor = Vector2.new(0.5, 0),
			textColor = color,
			maxText = 40,
			zindex = Z + 13,
		})
		local desc = Ui.body(button, {
			name = "Desc",
			size = UDim2.fromScale(0.8, 0.22),
			position = UDim2.fromScale(0.5, 0.69),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			textColor = ROLE.textDim,
			maxText = 24,
			zindex = Z + 13,
		})
		local lastPill = pill(button, {
			name = "LastTime",
			size = UDim2.fromScale(0.42, 0.075),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0.5),
			textColor = color,
			zindex = Z + 15,
			visible = false,
		})
		table.insert(modeCards, {
			mode = mode,
			button = button,
			stroke = stroke,
			title = modeTitle,
			desc = desc,
			lastPill = lastPill,
		})
	end

	-- Wait: the server loads the world (or moves a solo player to their own server) ----------------

	local waitView = content("Wait")
	local waitBadge = Ui.frame(waitView, {
		name = "Badge",
		size = UDim2.fromScale(0.3, 0.4),
		position = UDim2.fromScale(0.5, 0.12),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.background,
		corner = 0.5,
		aspect = 1,
		stroke = 4,
		strokeColor = ROLE.warning,
		zindex = Z + 12,
	})
	local waitIcon = Ui.icon(waitBadge, ICONS.rocket, {
		name = "Icon",
		size = UDim2.fromScale(0.62, 0.62),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.warning,
		zindex = Z + 13,
	})
	local waitText = Ui.label(waitView, {
		name = "Text",
		size = UDim2.fromScale(0.8, 0.12),
		position = UDim2.fromScale(0.5, 0.58),
		anchor = Vector2.new(0.5, 0),
		maxText = 36,
		zindex = Z + 12,
	})
	local waitFailed = false
	local waitSolo = false
	local waitToken = 0
	local waitBack = Ui.button(waitView, {
		name = "Back",
		size = UDim2.fromScale(0.3, 0.13),
		position = UDim2.fromScale(0.5, 0.78),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.home,
		tint = ROLE.accent,
		maxText = 28,
		zindex = Z + 12,
		visible = false,
	}, function()
		if pressAllowed() then
			showScreen("home")
		end
	end)

	-- Credits ----------------------------------------------------------------------------------------

	local creditsView = content("Credits")
	local creditLabels: { { label: TextLabel, key: string } } = {}
	local function creditColumn(x: number, lines: { { key: string, header: boolean?, color: Color3? } })
		local y = 0.02
		for index, line in lines do
			local height = if line.header then 0.1 else 0.085
			local label = if line.header
				then Ui.label(creditsView, {
					name = `Line{index}`,
					size = UDim2.fromScale(0.44, height),
					position = UDim2.fromScale(x, y),
					alignX = Enum.TextXAlignment.Left,
					textColor = line.color or ROLE.accent,
					maxText = 30,
					zindex = Z + 12,
				})
				else Ui.body(creditsView, {
					name = `Line{index}`,
					size = UDim2.fromScale(0.44, height),
					position = UDim2.fromScale(x, y),
					textColor = line.color or ROLE.text,
					maxText = 22,
					zindex = Z + 12,
				})
			table.insert(creditLabels, { label = label, key = line.key })
			y += height + (if line.header then 0.02 else 0.015)
		end
	end
	do
		local team: { { key: string, header: boolean?, color: Color3? } } = {
			{ key = "ui.menu_credits_team", header = true },
		}
		for index = 1, TEAM_SIZE do
			table.insert(team, { key = `ui.menu_team_{index}` })
		end
		table.insert(team, { key = "ui.menu_credits_event", header = true, color = ROLE.warning })
		creditColumn(0.03, team)
		creditColumn(0.53, {
			{ key = "ui.menu_credits_data", header = true },
			{ key = "src.donki" },
			{ key = "ui.menu_credit_earth" },
			{ key = "ui.menu_credit_icons" },
			{ key = "ui.menu_credits_help", header = true, color = ROLE.reward },
			{ key = "ui.menu_credit_ai" },
		})
	end

	-- Rendering ----------------------------------------------------------------------------------

	local current: ScreenName = "home"

	local function renderHome()
		title.Text = Store.t("ui.title")
		pitch.Text = Store.t("ui.pitch")
		footer.Text = Store.t("ui.menu_credits_event")
		local meta = Store.getSlots()
		local slot = Store.continueSlot()
		Ui.setButton(continueButton, Store.t("ui.continue"))
		Ui.setButton(newButton, Store.t("ui.menu_new_game"))
		Ui.setButton(loadButton, Store.t("ui.menu_load_game"))
		Ui.setButton(settingsButton, Store.t("ui.settings"))
		Ui.setButton(creditsButton, Store.t("ui.menu_credits"))
		Ui.setButtonLook(continueButton, slot ~= nil, ROLE.primaryButton)
		continueTag.Visible = slot ~= nil
		if slot then
			local info = Store.slotInfo(slot)
			local mode: SlotMode = if info then info.mode else "solo"
			continueTagText.Text = Store.t("ui.menu_world", { n = slot })
			Ui.setIcon(continueTagIcon, modeIcon(mode), ROLE.good)
		end
		-- A new player has nothing to continue: New game is the big green button. Both stay grey
		-- until the slot list arrives.
		local ready = meta ~= nil
		local newPrimary = ready and slot == nil
		Ui.setButtonLook(newButton, ready, if newPrimary then ROLE.primaryButton else ROLE.secondaryButton)
		Ui.setButtonLook(loadButton, ready, ROLE.secondaryButton)
		if ready then
			tintIcon(newButton, if newPrimary then ROLE.primaryButtonText else ROLE.accent)
			tintIcon(loadButton, ROLE.accent)
		end
		newStroke.Color = if newPrimary then ROLE.stroke else ROLE.accent
		-- Stage 10: once the list is here, say that the game saves by itself (playtest feedback).
		-- Not when saves could not be read (meta.offline): then nothing is saved this visit.
		homeStatus.Text = if meta == nil
			then Store.t("ui.menu_loading")
			elseif meta.offline then ""
			else Store.t("ui.save_auto")
	end

	local function renderSlots()
		local meta = Store.getSlots()
		for slot, card in slotCards do
			local info: SlotInfo? = if meta then meta.slots[slot] else nil
			local used = info ~= nil and info.used
			card.title.Text = Store.t("ui.menu_world", { n = slot })
			card.badge.Visible = true
			if info and used then
				Ui.setIcon(card.badgeIcon, ICONS.home, ROLE.good)
				card.badgeIcon.ImageTransparency = 0
				local badgeStroke = card.badge:FindFirstChildOfClass("UIStroke")
				if badgeStroke then
					badgeStroke.Color = ROLE.good
				end
				card.rows[1].label.Text = Store.t("ui.base_level", { n = info.habitat })
				card.rows[2].label.Text = Store.t("ui.level", { n = info.level })
				card.rows[3].label.Text = tostring(info.credits)
				card.rows[4].set(modeIcon(info.mode), Store.t(modeKey(info.mode)), modeColor(info.mode))
				card.rows[5].label.Text = savedText(info.savedAt)
				card.rows[5].frame.Visible = info.savedAt ~= nil
			else
				Ui.setIcon(card.badgeIcon, if flow == "new" then ICONS.rocket else ICONS.build, ROLE.textDim)
				card.badgeIcon.ImageTransparency = 0.3
				local badgeStroke = card.badge:FindFirstChildOfClass("UIStroke")
				if badgeStroke then
					badgeStroke.Color = ROLE.stroke
				end
			end
			for index, row in card.rows do
				row.frame.Visible = used and (index ~= 5 or (info ~= nil and info.savedAt ~= nil))
			end
			card.emptyTitle.Visible = not used
			card.emptyHint.Visible = not used
			card.emptyTitle.Text = Store.t("ui.menu_empty")
			card.emptyHint.Text = Store.t("ui.menu_empty_hint")
			local isLast = meta ~= nil and meta.last == slot and used
			card.lastPill.Visible = isLast
			card.lastPill.Text = Store.t("ui.menu_last_time")
			-- New game over a used world is a warning (orange); every other choice is a go (cyan / lime).
			card.stroke.Color = if flow == "new" and used
				then ROLE.warning
				elseif isLast then ROLE.good
				elseif used then ROLE.accent
				else ROLE.stroke
			card.stroke.Thickness = if isLast then Ui.STROKE + 2 else Ui.STROKE
			card.button.BackgroundColor3 = if used then ROLE.panelRaised else ROLE.panel
		end
		slotsSaveNote.Text = if meta and meta.offline then "" else Store.t("ui.save_auto")
		confirmTitle.Text = Store.t("ui.menu_wipe_title")
		confirmText.Text = Store.t("ui.menu_wipe_text")
		Ui.setButton(confirmNo, Store.t("ui.menu_wipe_no"))
		Ui.setButton(confirmYes, Store.t("ui.menu_wipe_yes"))
	end

	local function renderMode()
		modeWorld.Text = Store.t("ui.menu_world", { n = chosenSlot })
		local info = Store.slotInfo(chosenSlot)
		local lastMode: SlotMode? = if info and info.used and not chosenFresh then info.mode else nil
		for _, card in modeCards do
			card.title.Text = Store.t(modeKey(card.mode))
			card.desc.Text = Store.t(if card.mode == "friends" then "ui.menu_friends_desc" else "ui.menu_solo_desc")
			card.lastPill.Visible = lastMode == card.mode
			card.lastPill.Text = Store.t("ui.menu_last_time")
			card.stroke.Thickness = if lastMode == card.mode then Ui.STROKE + 3 else Ui.STROKE
		end
	end

	local function renderWait()
		if waitFailed then
			waitText.Text = Store.t("ui.menu_wait_fail")
			waitText.TextColor3 = ROLE.warning
		else
			waitText.Text = Store.t(if waitSolo then "ui.menu_wait_solo" else "ui.menu_wait")
			waitText.TextColor3 = ROLE.text
		end
		waitBack.Visible = waitFailed
		Ui.setButton(waitBack, Store.t("ui.menu_back"))
	end

	local function renderCredits()
		for _, entry in creditLabels do
			entry.label.Text = Store.t(entry.key)
		end
	end

	local function renderPanel()
		Ui.setButton(backButton, Store.t("ui.menu_back"))
		backButton.Visible = current ~= "wait"
		if current == "slots" then
			panelTitle.Text = Store.t(if flow == "new" then "ui.menu_pick_new" else "ui.menu_pick_load")
			Ui.setIcon(panelIcon, if flow == "new" then ICONS.rocket else ICONS.data, ROLE.accent)
		elseif current == "mode" then
			panelTitle.Text = Store.t("ui.menu_mode_title")
			Ui.setIcon(panelIcon, ICONS.planet, ROLE.accent)
		elseif current == "credits" then
			panelTitle.Text = Store.t("ui.menu_credits")
			Ui.setIcon(panelIcon, ICONS.star, ROLE.star)
		elseif current == "wait" then
			panelTitle.Text = Store.t("ui.title")
			Ui.setIcon(panelIcon, ICONS.calm, ROLE.accent)
		end
	end

	local function render()
		renderHome()
		renderSlots()
		renderMode()
		renderWait()
		renderCredits()
		renderPanel()
	end

	-- Gamepad: put the selection on the screen's main button.
	local function selectFirst(button: GuiObject?)
		if button and UserInputService.GamepadEnabled and screen.Visible then
			pcall(function()
				GuiService.SelectedObject = button
			end)
		end
	end

	showScreen = function(name: ScreenName)
		current = name
		if name ~= "slots" then
			confirm.Visible = false
			confirmSlot = nil
		end
		if name ~= "wait" then
			waitToken += 1 -- a pending timeout no longer applies
			waitFailed = false
		end
		home.Visible = name == "home"
		panel.Visible = name ~= "home"
		slotsView.Visible = name == "slots"
		modeView.Visible = name == "mode"
		waitView.Visible = name == "wait"
		creditsView.Visible = name == "credits"
		if name == "home" or name == "slots" or name == "credits" then
			backTarget = "home"
		end
		render()
		if name == "home" then
			selectFirst(if Store.continueSlot() then continueButton else newButton)
		elseif name == "slots" then
			selectFirst(slotCards[1].button)
		elseif name == "mode" then
			selectFirst(modeCards[1].button)
		elseif name == "credits" then
			selectFirst(backButton)
		end
	end

	openSlots = function(newFlow: Flow)
		flow = newFlow
		showScreen("slots")
	end

	openMode = function(slot: number, fresh: boolean, back: ScreenName)
		chosenSlot = slot
		chosenFresh = fresh
		showScreen("mode")
		backTarget = back
	end

	local function startWait(solo: boolean)
		waitSolo = solo
		waitFailed = false
		showScreen("wait")
		waitToken += 1
		local token = waitToken
		task.delay(WAIT_TIMEOUT, function()
			if token == waitToken and current == "wait" and not Store.isSlotChosen() then
				waitFailed = true
				renderWait()
				renderPanel()
				selectFirst(waitBack)
			end
		end)
	end

	sendChoice = function(mode: SlotMode)
		deps.closeSettings()
		Store.chooseSlot(chosenSlot, mode, chosenFresh)
		-- Solo outside Studio means a trip to the player's own server.
		startWait(mode == "solo" and not RunService:IsStudio())
	end

	-- Animation: twinkling stars, the turning Earth, the base's blinking light, the waiting rocket.
	local animation: RBXScriptConnection? = nil
	local sinceFrame = 0
	local earthOffset = 0
	local function animate(deltaTime: number)
		sinceFrame += deltaTime
		if sinceFrame < ANIMATION_STEP then
			return
		end
		local step = sinceFrame
		sinceFrame = 0
		local now = os.clock()
		for _, star in stars do
			star.frame.BackgroundTransparency = math.clamp(star.base + 0.35 * (math.sin(now * star.speed + star.phase) + 1) / 2, 0, 0.95)
		end
		earthOffset = (earthOffset + step * 2 / EARTH_TURN_SECONDS) % 2
		maps[1].Position = UDim2.fromScale(-earthOffset, 0)
		maps[2].Position = UDim2.fromScale(2 - earthOffset, 0)
		beacon.BackgroundTransparency = if math.floor(now * 1.5) % 2 == 0 then 0 else 0.75
		if waitView.Visible and not waitFailed then
			waitIcon.Rotation = 12 * math.sin(now * 3)
			waitBadge.Position = UDim2.fromScale(0.5, 0.12 - 0.015 * math.sin(now * 2))
		end
	end

	local function setAnimating(on: boolean)
		if on and animation == nil then
			animation = RunService.Heartbeat:Connect(animate)
		elseif not on and animation then
			animation:Disconnect()
			animation = nil
		end
	end

	local function hide()
		waitToken += 1
		screen.Visible = false
		setAnimating(false)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then
			pcall(function()
				GuiService.SelectedObject = nil
			end)
		end
	end

	-- Gamepad B goes back one screen.
	UserInputService.InputBegan:Connect(function(input: InputObject, _processed: boolean)
		if not screen.Visible or input.KeyCode ~= Enum.KeyCode.ButtonB then
			return
		end
		if confirm.Visible then
			confirm.Visible = false
			confirmSlot = nil
		elseif current ~= "home" and backButton.Visible then
			showScreen(backTarget)
		elseif current == "wait" and waitFailed then
			showScreen("home")
		end
	end)

	-- The server loaded a slot: the menu closes for good.
	player:GetAttributeChangedSignal(Store.SLOT_CHOSEN_ATTRIBUTE):Connect(function()
		if Store.isSlotChosen() then
			hide()
		end
	end)

	-- "Last saved" times age while the menu is open.
	task.spawn(function()
		while screen.Visible do
			task.wait(30)
			if screen.Visible and current == "slots" then
				renderSlots()
			end
		end
	end)

	if screen.Visible then
		setAnimating(true)
		local teleportedSlot, teleportedMode = teleportSlot()
		if teleportedSlot then
			-- Arrived in the player's own server: the server picks that slot by itself.
			chosenSlot = teleportedSlot
			startWait(teleportedMode == "solo")
		else
			showScreen("home")
		end
	end
	render()

	return {
		render = render,
		isOpen = function(): boolean
			return screen.Visible
		end,
		hide = hide,
	}
end

return StartMenu
