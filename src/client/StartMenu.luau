--!strict
-- Space Base Odyssey - start menu (Stage 9): the first screen, in the "Lunar Sunrise" identity: the
-- game title over a live cinematic of the base (Stage 10), with:
--   * Continue   - loads the slot used last time (Store.continueSlot()); Stage 11 menu: a card under
--                  it says what it loads (world, base level, player level, last save),
--   * New game / My worlds (Stage 11 menu, team request: there is no "Load game" button any more, it
--                  looked like uploading a file) - the 3 world cards. An empty card starts a new world;
--                  a used card asks "Continue" or "Start over" (Start over asks once more, then the
--                  world starts fresh). The button says "New game" until the player has a world,
--   * Join a friend (Stage 10 fix) - the open worlds of the player's Roblox friends (name, base level,
--                  players n of 4), then "Pick your explorer save": which of the player's own slots
--                  comes along (an empty one starts a new explorer; nothing is ever wiped from here),
--   * Settings   - opens the existing Settings panel (it draws above this screen),
--   * Credits    - the team, the event and the data credits as text.
-- After a world is picked the player chooses "Just me" (nobody else) or "With friends" (up to 3
-- Roblox friends may join with Join a friend), and the client sends Action ChooseSlot { slot, mode,
-- fresh }. Stage 10 fix (private worlds): the public server is only a lobby, so both modes fly the
-- player to their own world server; Join a friend sends JoinWorld { owner, slot }. The player has no
-- character until the server loads the slot and sets the player attribute SBO_SlotChosen = true; then
-- this screen closes. A trip that fails brings the wait screen's reason (SBO_TripFailedReason) and a
-- Back button. A player teleported into a world server (TeleportData { owner, slot, ... }) never sees
-- the menu again: the server picks the slot there, so the screen only says "getting your base ready"
-- (or why that world sent them back: SBO_WorldNotice). Back in the lobby, TeleportData { notice }
-- (for example "your friend left") shows under the buttons.
-- Stage 11 menu (audit fixes):
--   * In a world server a slow load (WAIT_TIMEOUT) never leads back to the home buttons (the server
--     there refuses every choice): the wait screen says "still getting your base ready" and offers
--     "Back to the start", which teleports the player to the lobby (a public server of this place),
--     while it keeps waiting for SBO_SlotChosen.
--   * Every choice box puts the gamepad selection on its safe button and gives it back to the card.
--   * Trips use a themed teleport screen (TeleportService:SetTeleportGui) with the same words as the
--     wait screen; on arrival it stays a moment and fades out.
--   * Store.setMenuOpen follows the hidden-HUD state, so C.A.R.L. holds his lines until the menu
--     closes (Main.client).
--   * Store.reduceMotion() stops the waiting rocket's wobble and the teleport screen's fade.
-- Stage 10: the background is no longer drawn in 2D. Cinematic.luau plays the shots of
-- CinematicShots.MENU_ORDER on the real 3D world, looping with black fades, from the moment the menu
-- opens until it hides. The server shows a finished "showcase" base while nobody has loaded a save
-- (BaseService). A soft dark gradient over the left part of the screen and a light vignette keep the
-- title and buttons readable over any shot. Because the menu no longer covers the screen, the rest of
-- the game UI in the same root (HUD, top bar, C.A.R.L.'s bubble, Settings button, cards) waits in a
-- hidden holder frame ("GameLayer") while the menu is open and goes back when it hides; moving them
-- leaves every module's own Visible values untouched. Without Cinematic (load failure) the screen
-- falls back to a plain night colour.
-- Layout (fractions of the screen; the root is 720 units tall and as wide as the device, so it fits a
-- phone in landscape): title x 0.06-0.56 y 0.07-0.25, buttons x 0.06-0.40 y 0.335-0.87 (Continue,
-- its world card, My worlds, Join a friend, Settings + Credits), the dark gradient x 0-0.62,
-- sub-screens in one centred panel 0.86 x 0.82.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio) -- Stage 11 menu: sounds for the choice box
local Worlds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Worlds"))

type SlotInfo = Store.SlotInfo
type SlotMode = Store.SlotMode

local ROLE = Ui.ROLE
local ICONS = Ui.Icons

-- Above the HUD, the top bar (52), the Lab and Wardrobe (53), the cards (55-57) and the Settings
-- button (60); below the Settings panel (62), which opens on top of this screen.
local Z = 61
local PRESS_COOLDOWN = 0.35 -- seconds between two taps (no double sends)
local WAIT_TIMEOUT = 40 -- seconds without SBO_SlotChosen before the menu offers to go back
local ANIMATION_STEP = 1 / 30
local SHADE_WIDTH = 0.62 -- the dark gradient behind the title and buttons (fraction of the width)
local ARRIVAL_SCREEN_SECONDS = 1.2 -- Stage 11 menu: the arriving teleport screen stays, then fades
local ARRIVAL_FADE_SECONDS = 0.6
-- Root children that stay while the menu is open (everything else waits in the GameLayer holder).
local VEIL_KEEP: { [string]: boolean } = {
	StartMenu = true,
	Settings = true, -- the Settings panel opens over the menu
	MouseUnlock = true, -- frees the mouse while a panel is open (Main.client)
	GameLayer = true,
}
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

type ScreenName = "home" | "slots" | "mode" | "credits" | "wait" | "friends"
-- Stage 11 menu: "worlds" = the one world list (empty card: new world; used card: Continue or Start
-- over). "join" (Stage 10 fix): pick which own slot goes to a friend's world.
type Flow = "worlds" | "join"
type WaitKind = "solo" | "friends" | "join"

type FriendCard = {
	button: TextButton,
	stroke: UIStroke,
	name: TextLabel,
	base: Ui.IconText,
	players: Ui.IconText,
	fullPill: TextLabel,
}

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

-- What this player was teleported with: a world trip (the slot, and solo / friends / join), or a
-- notice from a world that sent them back to the lobby (Worlds.NOTICES).
local function teleportInfo(): (number?, WaitKind?, string?)
	local ok, data = pcall(function(): any
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	if not ok or type(data) ~= "table" then
		return nil, nil, nil
	end
	local notice = if type(data.notice) == "string" and Worlds.NOTICES[data.notice] then data.notice else nil
	local slot = tonumber(data.slot)
	if slot == nil or slot ~= math.floor(slot) or slot < 1 or slot > Store.SLOT_COUNT then
		return nil, nil, notice
	end
	local kind: WaitKind = if data.guest == true then "join" elseif data.mode == "friends" then "friends" else "solo"
	return slot, kind, nil
end

-- The text for why a trip or a world refused the player ("ui.menu_notice_<reason>").
local function noticeKey(reason: string?): string
	if reason ~= nil and Worlds.NOTICES[reason] then
		return `ui.menu_notice_{reason}`
	end
	return "ui.menu_wait_fail"
end

-- The wait screen's words for a trip (also on the teleport screen).
local function waitKey(kind: WaitKind): string
	return if kind == "solo" then "ui.menu_wait_solo" elseif kind == "join" then "ui.menu_wait_join" else "ui.menu_wait"
end

-- Stage 11 menu: the "Lunar Sunrise" screen Roblox shows during a trip (TeleportService:SetTeleportGui):
-- the title, the rocket badge and the wait screen's words, on night. Not parented: Roblox copies it.
local function teleportScreen(textKey: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "SBO_TeleportScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local back = Ui.frame(gui, { name = "Back", color = ROLE.background, zindex = 1 })
	Ui.label(back, {
		name = "Title",
		size = UDim2.fromScale(0.8, 0.12),
		position = UDim2.fromScale(0.5, 0.2),
		anchor = Vector2.new(0.5, 0.5),
		textColor = ROLE.warning,
		maxText = 72,
		text = Store.t("ui.title"),
		zindex = 2,
	})
	local badge = Ui.frame(back, {
		name = "Badge",
		size = UDim2.fromScale(0.22, 0.22),
		position = UDim2.fromScale(0.5, 0.48),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.5,
		aspect = 1,
		stroke = 4,
		strokeColor = ROLE.warning,
		zindex = 2,
	})
	Ui.icon(badge, ICONS.rocket, {
		name = "Icon",
		size = UDim2.fromScale(0.62, 0.62),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.warning,
		zindex = 3,
	})
	Ui.label(back, {
		name = "Text",
		size = UDim2.fromScale(0.8, 0.08),
		position = UDim2.fromScale(0.5, 0.72),
		anchor = Vector2.new(0.5, 0.5),
		textColor = ROLE.text,
		maxText = 40,
		text = Store.t(textKey),
		zindex = 2,
	})
	Ui.frame(back, {
		name = "Line",
		size = UDim2.fromScale(0.16, 0.008),
		position = UDim2.fromScale(0.5, 0.79),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.accent,
		corner = 0.5,
		zindex = 2,
	})
	return gui
end

local function useTeleportScreen(textKey: string)
	if RunService:IsStudio() then
		return -- Studio never teleports
	end
	local ok, err = pcall(function()
		TeleportService:SetTeleportGui(teleportScreen(textKey))
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] teleport screen unavailable: {err}`)
	end
end

-- The trip's screen, shown again for a moment after arriving, then faded out (Store.reduceMotion:
-- removed without a fade).
local function showArrivalScreen(player: Player)
	local ok, gui = pcall(function(): any
		return TeleportService:GetArrivingTeleportGui()
	end)
	if not ok or gui == nil or not gui:IsA("ScreenGui") then
		return
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		gui:Destroy()
		return
	end
	gui.Parent = playerGui
	task.delay(ARRIVAL_SCREEN_SECONDS, function()
		if gui.Parent == nil then
			return
		end
		if Store.reduceMotion() then
			gui:Destroy()
			return
		end
		local info = TweenInfo.new(ARRIVAL_FADE_SECONDS)
		for _, item in gui:GetDescendants() do
			if item:IsA("TextLabel") then
				TweenService:Create(item, info, { TextTransparency = 1 }):Play()
			elseif item:IsA("ImageLabel") then
				TweenService:Create(item, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif item:IsA("Frame") then
				TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
			elseif item:IsA("UIStroke") then
				TweenService:Create(item, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(ARRIVAL_FADE_SECONDS, function()
			gui:Destroy()
		end)
	end)
end

function StartMenu.new(root: Frame, deps: Deps): StartMenuView
	local player = Players.LocalPlayer

	-- Stage 10: Cinematic.luau moves the camera behind this screen (pcall: a broken module only
	-- brings back a plain background).
	local cinematic: any = nil
	do
		local ok, result = pcall(function(): any
			local moduleScript = script.Parent:WaitForChild("Cinematic", 5)
			if moduleScript == nil then
				error("Cinematic not found")
			end
			return (require :: any)(moduleScript)
		end)
		if ok and type(result) == "table" and type(result.playMenu) == "function" then
			cinematic = result
		else
			warn(`[SpaceBaseOdyssey] Cinematic unavailable, plain menu background: {result}`)
		end
	end

	local screen = Ui.frame(root, {
		name = "StartMenu",
		color = ROLE.background,
		transparency = if cinematic then 1 else 0,
		zindex = Z,
		visible = not Store.isSlotChosen(),
	})
	screen.Active = true -- taps never reach the world behind
	screen.ClipsDescendants = true

	-- Background: the cinematic's black fade, the dark gradient on the left and a light vignette ----

	local fade = Ui.frame(screen, { name = "Fade", color = ROLE.background, transparency = 0, zindex = Z })
	fade.Visible = cinematic ~= nil
	local shade = Ui.frame(screen, {
		name = "Shade",
		size = UDim2.fromScale(SHADE_WIDTH, 1),
		color = ROLE.background,
		zindex = Z + 1,
	})
	do
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.5, 0.38),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = shade
	end
	-- Vignette: darker top and bottom edges, and a little on the right.
	local vignette = Ui.frame(screen, { name = "Vignette", color = ROLE.background, zindex = Z + 1 })
	do
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.2, 1),
			NumberSequenceKeypoint.new(0.78, 1),
			NumberSequenceKeypoint.new(1, 0.4),
		})
		gradient.Parent = vignette
	end
	local vignetteSide = Ui.frame(screen, { name = "VignetteSide", color = ROLE.background, zindex = Z + 1 })
	do
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.85, 1),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		gradient.Parent = vignetteSide
	end

	-- The rest of the game UI waits in a hidden holder while the menu is open (see the header).
	local gameLayer: Frame? = nil
	local veilAdded: RBXScriptConnection? = nil
	local function veil(child: Instance)
		local holder = gameLayer
		if holder and child.Parent == root and child:IsA("GuiObject") and not VEIL_KEEP[child.Name] then
			child.Parent = holder
		end
	end
	local function setVeil(on: boolean)
		if on and gameLayer == nil then
			local holder = Ui.frame(root, { name = "GameLayer", zindex = 1, visible = false })
			gameLayer = holder
			for _, child in root:GetChildren() do
				veil(child)
			end
			veilAdded = root.ChildAdded:Connect(function(child: Instance)
				-- Deferred: the module that made it finishes setting it up first.
				task.defer(veil, child)
			end)
		elseif not on and gameLayer then
			local holder = gameLayer :: Frame
			gameLayer = nil
			if veilAdded then
				veilAdded:Disconnect()
				veilAdded = nil
			end
			for _, child in holder:GetChildren() do
				if child:IsA("GuiObject") then
					child.Parent = root
				end
			end
			holder:Destroy()
		end
		-- Stage 11 menu: the HUD is hidden exactly while the veil is on (C.A.R.L. waits meanwhile).
		Store.setMenuOpen(gameLayer ~= nil)
	end

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
		position = UDim2.fromScale(0.06, 0.335),
		zindex = Z + 6,
	})
	-- Stage 11 menu: Continue with its world card under it, then My worlds, Join a friend and
	-- Settings + Credits, all full width (column fractions; every button is ROW tall).
	local ROW = 0.155
	local CONTINUE_Y = 0
	local INFO_Y = 0.17
	local INFO_HEIGHT = 0.16
	-- The card hangs under Continue (small gap); the three rows below share one even gap.
	local WORLDS_Y = 0.395
	local JOIN_Y = 0.62
	local LAST_Y = 0.845 -- Settings + Credits (ends at the column's bottom)

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
	local sendJoin: (slot: number) -> ()

	local continueButton = Ui.button(column, {
		name = "Continue",
		size = UDim2.fromScale(1, ROW),
		position = UDim2.fromScale(0, CONTINUE_Y),
		icon = ICONS.play,
		maxText = 34,
		zindex = Z + 7,
	}, function()
		local slot = Store.continueSlot()
		if slot and pressAllowed() then
			openMode(slot, false, "home")
		end
	end)
	-- Stage 11 menu: what Continue loads (night card under the button): world and how it was played,
	-- base level, player level, last save. Without a world it says so.
	local continueInfo = Ui.panel(column, {
		name = "ContinueInfo",
		size = UDim2.fromScale(1, INFO_HEIGHT),
		position = UDim2.fromScale(0, INFO_Y),
		color = ROLE.background,
		transparency = 0.15,
		strokeColor = ROLE.good,
		corner = 0.25,
		zindex = Z + 7,
	})
	local function infoRow(name: string, x: number, y: number, icon: string, tint: Color3): Ui.IconText
		return Ui.iconText(continueInfo, {
			name = name,
			size = UDim2.fromScale(0.46, 0.4),
			position = UDim2.fromScale(x, y),
			icon = icon,
			tint = tint,
			textColor = ROLE.text,
			font = Ui.BODY_FONT,
			maxText = 20,
			zindex = Z + 8,
		})
	end
	local infoWorld = infoRow("World", 0.03, 0.07, ICONS.helmet, ROLE.good)
	local infoBase = infoRow("Base", 0.52, 0.07, ICONS.home, ROLE.good)
	local infoLevel = infoRow("Level", 0.03, 0.53, ICONS.xp, ROLE.reward)
	local infoSaved = infoRow("Saved", 0.52, 0.53, ICONS.clock, ROLE.textDim)
	local infoNone = Ui.body(continueInfo, {
		name = "None",
		size = UDim2.fromScale(0.9, 0.6),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.textDim,
		maxText = 20,
		zindex = Z + 8,
	})

	local worldsButton = Ui.button(column, {
		name = "Worlds",
		size = UDim2.fromScale(1, ROW),
		position = UDim2.fromScale(0, WORLDS_Y),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.planet,
		tint = ROLE.accent,
		maxText = 34,
		zindex = Z + 7,
	}, function()
		if Store.getSlots() and pressAllowed() then
			openSlots("worlds")
		end
	end)
	local worldsStroke = worldsButton:FindFirstChildOfClass("UIStroke") :: UIStroke
	local openFriends: () -> ()
	local joinButton = Ui.button(column, {
		name = "JoinFriend",
		size = UDim2.fromScale(1, ROW),
		position = UDim2.fromScale(0, JOIN_Y),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.good,
		icon = ICONS.language,
		tint = ROLE.good,
		maxText = 34,
		zindex = Z + 7,
	}, function()
		if Store.getSlots() and pressAllowed() then
			openFriends()
		end
	end)
	local joinStroke = joinButton:FindFirstChildOfClass("UIStroke") :: UIStroke
	local settingsButton = Ui.button(column, {
		name = "Settings",
		size = UDim2.fromScale(0.485, ROW),
		position = UDim2.fromScale(0, LAST_Y),
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
		position = UDim2.fromScale(0.515, LAST_Y),
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

	-- Gamepad: put the selection on a button (only while this screen shows).
	local function selectFirst(button: GuiObject?)
		if button and UserInputService.GamepadEnabled and screen.Visible then
			pcall(function()
				GuiService.SelectedObject = button
			end)
		end
	end

	-- Slots: three world cards -------------------------------------------------------------------

	local slotsView = content("Slots")
	local flow: Flow = "worlds"
	local pickedSlot: number? = nil -- the used world the choice box (and the wipe confirm) is about
	local choiceBox: Frame -- "Continue" or "Start over" (built below)
	local confirm: Frame -- the "start this world again?" box (built below)
	local openChoice: (slot: number) -> ()

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
			if info == nil or choiceBox.Visible or confirm.Visible or not pressAllowed() then
				return
			end
			if flow == "join" then
				sendJoin(slot) -- Stage 10 fix: this slot's explorer goes to the friend's world
			elseif info.used then
				openChoice(slot) -- Stage 11 menu: Continue or Start over
			else
				openMode(slot, true, "slots") -- an empty world starts fresh
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

	-- A box over the cards (the choice box and the wipe confirm share this look).
	local function coverBox(name: string, strokeColor: Color3, icon: string): (Frame, Frame, TextLabel, TextLabel)
		local cover = Ui.modal(slotsView, name, Z + 20)
		cover.Size = UDim2.fromScale(1.02, 1.05)
		cover.Position = UDim2.fromScale(-0.01, -0.02)
		local box = Ui.panel(cover, {
			name = "Box",
			size = UDim2.fromScale(0.62, 0.74),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			color = ROLE.panelRaised,
			corner = 0.08,
			stroke = 4,
			strokeColor = strokeColor,
			zindex = Z + 21,
		})
		box.Active = true
		Ui.icon(box, icon, {
			name = "Icon",
			size = UDim2.fromScale(0.2, 0.2),
			position = UDim2.fromScale(0.5, 0.06),
			anchor = Vector2.new(0.5, 0),
			tint = strokeColor,
			zindex = Z + 22,
		})
		local boxTitle = Ui.label(box, {
			name = "Title",
			size = UDim2.fromScale(0.9, 0.16),
			position = UDim2.fromScale(0.5, 0.29),
			anchor = Vector2.new(0.5, 0),
			textColor = strokeColor,
			maxText = 36,
			zindex = Z + 22,
		})
		local boxText = Ui.body(box, {
			name = "Text",
			size = UDim2.fromScale(0.86, 0.16),
			position = UDim2.fromScale(0.5, 0.47),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			maxText = 26,
			zindex = Z + 22,
		})
		return cover, box, boxTitle, boxText
	end

	-- Gamepad: while a box covers the cards, the selection cannot move onto them (called right after
	-- every change of the boxes' Visible, before the selection moves).
	local function syncCardSelection()
		local covered = (choiceBox ~= nil and choiceBox.Visible) or (confirm ~= nil and confirm.Visible)
		for _, card in slotCards do
			card.button.Selectable = not covered
		end
	end

	-- Gamepad: give the selection back to the card the boxes were about.
	local function selectPickedCard()
		syncCardSelection()
		local slot = pickedSlot
		local card = if slot then slotCards[slot] else nil
		selectFirst(if card then card.button else slotCards[1].button)
	end

	-- Stage 11 menu: a used world asks "Continue" (primary) or "Start over" (danger, asks again).
	local choiceBoxFrame, choiceInner, choiceTitle, choiceText = coverBox("Choice", ROLE.accent, ICONS.planet)
	choiceBox = choiceBoxFrame
	local function closeChoice()
		choiceBox.Visible = false
		selectPickedCard()
		pickedSlot = nil
	end
	local choiceContinue = Ui.button(choiceInner, {
		name = "Continue",
		size = UDim2.fromScale(0.43, 0.2),
		position = UDim2.fromScale(0.05, 0.72),
		icon = ICONS.play,
		maxText = 26,
		zindex = Z + 22,
	}, function()
		local slot = pickedSlot
		if slot and pressAllowed() then
			choiceBox.Visible = false
			pickedSlot = nil
			openMode(slot, false, "slots")
		end
	end)
	local choiceRestart = Ui.button(choiceInner, {
		name = "StartOver",
		size = UDim2.fromScale(0.43, 0.2),
		position = UDim2.fromScale(0.52, 0.72),
		color = ROLE.dangerButton,
		icon = ICONS.restart,
		maxText = 26,
		zindex = Z + 22,
	}, function()
		if pickedSlot and pressAllowed() then
			choiceBox.Visible = false
			confirm.Visible = true
			syncCardSelection()
			selectFirst(confirm:FindFirstChild("No", true) :: GuiObject?)
		end
	end)
	-- A small close button in the box's corner (gamepad B closes it too).
	Ui.button(choiceInner, {
		name = "Close",
		size = UDim2.fromScale(0.12, 0.14),
		position = UDim2.fromScale(0.97, 0.04),
		anchor = Vector2.new(1, 0),
		color = ROLE.secondaryButton,
		icon = ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 23,
	}, closeChoice)

	local function fillChoice(slot: number)
		local info = Store.slotInfo(slot)
		choiceTitle.Text = Store.t("ui.menu_world", { n = slot })
		choiceText.Text = if info
			then `{Store.t("ui.base_level", { n = info.habitat })}  -  {Store.t("ui.level", { n = info.level })}\n{Store.t("ui.menu_choice_text")}`
			else Store.t("ui.menu_choice_text")
	end
	openChoice = function(slot: number)
		pickedSlot = slot
		fillChoice(slot)
		choiceBox.Visible = true
		syncCardSelection()
		selectFirst(choiceContinue)
	end

	-- Confirm a wipe: covers the cards, asks once, "No" is the safe default on the left.
	local confirmFrame, confirmBox, confirmTitle, confirmText = coverBox("Confirm", ROLE.warning, ICONS.alert)
	confirm = confirmFrame
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
		-- Back to the choice for that world (nothing was wiped).
		confirm.Visible = false
		local slot = pickedSlot
		if slot then
			openChoice(slot)
		else
			selectPickedCard()
		end
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
		local slot = pickedSlot
		if slot and pressAllowed() then
			confirm.Visible = false
			pickedSlot = nil
			Audio.play("toast_pop") -- Stage 11 menu: a fresh start (Ui.button already clicked)
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
	local waitKind: WaitKind = "friends"
	local waitReason: string? = nil -- Stage 10 fix: why the trip failed (SBO_TripFailedReason)
	local waitNotice: string? = nil -- Stage 10 fix: why this world sends the player back (SBO_WorldNotice)
	local lobbyNotice: string? = nil -- Stage 10 fix: why a world sent the player back here (TeleportData)
	-- Stage 11 menu: this player arrived in their world server (the server picks the slot here, so
	-- the home buttons would do nothing): a slow load offers the way back to the lobby instead.
	local inWorldServer = false
	local leavingToLobby = false
	local waitToken = 0

	-- Stage 11 menu: back to the lobby (a public server of this place) from a world that is slow to load.
	local function leaveToLobby()
		if leavingToLobby then
			return
		end
		leavingToLobby = true
		useTeleportScreen("ui.menu_loading")
		local ok, err = pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
		if not ok then
			warn(`[SpaceBaseOdyssey] back to the lobby failed: {err}`)
			leavingToLobby = false
			waitReason = nil
			waitText.Text = Store.t("ui.menu_wait_fail")
			waitText.TextColor3 = ROLE.warning
		end
	end

	local waitBack = Ui.button(waitView, {
		name = "Back",
		size = UDim2.fromScale(0.36, 0.13),
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
		if not pressAllowed() then
			return
		end
		if inWorldServer then
			leaveToLobby()
		else
			showScreen("home")
		end
	end)
	-- Teleport failures are rare: leave the wait screen able to try again.
	TeleportService.TeleportInitFailed:Connect(function(who: Player)
		if who == player and leavingToLobby then
			leavingToLobby = false
		end
	end)

	-- Friends (Stage 10 fix): open worlds of the player's Roblox friends ------------------------------

	local friendsView = content("Friends")
	local chosenOwner: number? = nil -- the friend whose world the "join" slot pick is for
	local lastFriendsRequest = -math.huge
	local friendsStatus = Ui.label(friendsView, {
		name = "Status",
		size = UDim2.fromScale(0.8, 0.1),
		position = UDim2.fromScale(0.5, 0.32),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.text,
		maxText = 32,
		zindex = Z + 12,
	})
	local friendsHint = Ui.body(friendsView, {
		name = "Hint",
		size = UDim2.fromScale(0.7, 0.08),
		position = UDim2.fromScale(0.5, 0.45),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.textDim,
		maxText = 22,
		zindex = Z + 12,
	})
	local FRIEND_COLUMNS = 3
	local FRIEND_CARD_WIDTH = 0.31
	local FRIEND_CARD_HEIGHT = 0.38
	local friendCards: { FriendCard } = {}
	for index = 1, Worlds.LIST_LIMIT do
		local friendColumn = (index - 1) % FRIEND_COLUMNS
		local row = math.floor((index - 1) / FRIEND_COLUMNS)
		local x = (1 - FRIEND_CARD_WIDTH * FRIEND_COLUMNS - CARD_GAP * (FRIEND_COLUMNS - 1)) / 2
			+ (FRIEND_CARD_WIDTH + CARD_GAP) * friendColumn
		local button = Ui.button(friendsView, {
			name = `Friend{index}`,
			size = UDim2.fromScale(FRIEND_CARD_WIDTH, FRIEND_CARD_HEIGHT),
			position = UDim2.fromScale(x, 0.04 + row * (FRIEND_CARD_HEIGHT + 0.04)),
			color = ROLE.panelRaised,
			corner = 0.08,
			strokeColor = ROLE.good,
			zindex = Z + 12,
			visible = false,
		}, function()
			local view = Store.friendWorlds()
			local world = if view then view.worlds[index] else nil
			if world == nil or world.full or not pressAllowed() then
				return
			end
			chosenOwner = world.owner
			openSlots("join")
			backTarget = "friends" -- Back on the slot pick returns to this list
		end)
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		local name = Ui.label(button, {
			name = "Name",
			size = UDim2.fromScale(0.86, 0.24),
			position = UDim2.fromScale(0.5, 0.12),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.good,
			maxText = 28,
			zindex = Z + 13,
		})
		local baseRow = Ui.iconText(button, {
			name = "Base",
			size = UDim2.fromScale(0.86, 0.18),
			position = UDim2.fromScale(0.07, 0.46),
			icon = ICONS.home,
			tint = ROLE.good,
			textColor = ROLE.text,
			font = Ui.BODY_FONT,
			maxText = 20,
			zindex = Z + 13,
		})
		local playersRow = Ui.iconText(button, {
			name = "Players",
			size = UDim2.fromScale(0.86, 0.18),
			position = UDim2.fromScale(0.07, 0.7),
			icon = ICONS.helmet,
			tint = ROLE.accent,
			textColor = ROLE.text,
			font = Ui.BODY_FONT,
			maxText = 20,
			zindex = Z + 13,
		})
		local fullPill = pill(button, {
			name = "Full",
			size = UDim2.fromScale(0.5, 0.15),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0.5),
			textColor = ROLE.warning,
			zindex = Z + 15,
			visible = false,
		})
		table.insert(friendCards, {
			button = button,
			stroke = stroke,
			name = name,
			base = baseRow,
			players = playersRow,
			fullPill = fullPill,
		})
	end
	local friendsRefresh = Ui.button(friendsView, {
		name = "Refresh",
		size = UDim2.fromScale(0.3, 0.11),
		position = UDim2.fromScale(0.5, 0.88),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.secondaryButton,
		strokeColor = ROLE.accent,
		icon = ICONS.restart,
		tint = ROLE.accent,
		maxText = 26,
		zindex = Z + 12,
	}, function()
		if pressAllowed() then
			openFriends()
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
			{ key = "ui.menu_credit_sounds" }, -- Stage 11 audio
			{ key = "ui.menu_credits_help", header = true, color = ROLE.reward },
			{ key = "ui.menu_credit_ai" },
		})
	end

	-- Rendering ----------------------------------------------------------------------------------

	local current: ScreenName = "home"

	local function anyWorldUsed(): boolean
		local meta = Store.getSlots()
		if meta == nil then
			return false
		end
		for _, info in meta.slots do
			if info.used then
				return true
			end
		end
		return false
	end

	local function renderHome()
		title.Text = Store.t("ui.title")
		pitch.Text = Store.t("ui.pitch")
		footer.Text = Store.t("ui.menu_credits_event")
		local meta = Store.getSlots()
		local slot = Store.continueSlot()
		local ready = meta ~= nil
		-- Stage 11 menu: "New game" until the player has a world, then "My worlds".
		local hasWorld = anyWorldUsed()
		Ui.setButton(continueButton, Store.t("ui.continue"))
		Ui.setButton(worldsButton, Store.t(if hasWorld then "ui.menu_worlds" else "ui.menu_new_game"), if hasWorld then ICONS.planet else ICONS.rocket)
		Ui.setButton(joinButton, Store.t("ui.menu_join_friend"))
		Ui.setButton(settingsButton, Store.t("ui.settings"))
		Ui.setButton(creditsButton, Store.t("ui.menu_credits"))
		Ui.setButtonLook(continueButton, slot ~= nil, ROLE.primaryButton)
		-- What Continue loads.
		local info = if slot then Store.slotInfo(slot) else nil
		continueInfo.Visible = ready
		local showInfo = slot ~= nil and info ~= nil
		for _, row in { infoWorld, infoBase, infoLevel, infoSaved } do
			row.frame.Visible = showInfo
		end
		infoNone.Visible = not showInfo
		infoNone.Text = Store.t("ui.menu_continue_none")
		local infoStroke = continueInfo:FindFirstChildOfClass("UIStroke")
		if infoStroke then
			infoStroke.Color = if showInfo then ROLE.good else ROLE.stroke
		end
		if slot and info then
			infoWorld.set(modeIcon(info.mode), Store.t("ui.menu_world", { n = slot }), modeColor(info.mode))
			infoBase.label.Text = Store.t("ui.base_level", { n = info.habitat })
			infoLevel.label.Text = Store.t("ui.level", { n = info.level })
			infoSaved.label.Text = savedText(info.savedAt)
			infoSaved.frame.Visible = info.savedAt ~= nil
		end
		-- A new player has nothing to continue: New game is the big green button. Both stay grey
		-- until the slot list arrives.
		local worldsPrimary = ready and slot == nil
		Ui.setButtonLook(worldsButton, ready, if worldsPrimary then ROLE.primaryButton else ROLE.secondaryButton)
		Ui.setButtonLook(joinButton, ready, ROLE.secondaryButton)
		if ready then
			tintIcon(worldsButton, if worldsPrimary then ROLE.primaryButtonText else ROLE.accent)
			tintIcon(joinButton, ROLE.good)
		end
		worldsStroke.Color = if worldsPrimary then ROLE.stroke else ROLE.accent
		joinStroke.Color = ROLE.good
		-- Stage 10: once the list is here, say that the game saves by itself (playtest feedback).
		-- Not when saves could not be read (meta.offline): then nothing is saved this visit.
		homeStatus.Text = if lobbyNotice ~= nil
			then Store.t(noticeKey(lobbyNotice))
			elseif meta == nil then Store.t("ui.menu_loading")
			elseif meta.offline then ""
			else Store.t("ui.save_auto")
		-- Stage 10 fix: a world that sent the player back says why, in orange, until the next choice.
		homeStatus.TextColor3 = if lobbyNotice ~= nil then ROLE.warning else ROLE.accent
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
				Ui.setIcon(card.badgeIcon, if flow == "join" then ICONS.helmet else ICONS.rocket, ROLE.textDim)
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
			-- Stage 10 fix: joining a friend with an empty slot starts a new explorer, not a new base.
			card.emptyHint.Text = Store.t(if flow == "join" then "ui.menu_empty_join" else "ui.menu_empty_hint")
			local isLast = meta ~= nil and meta.last == slot and used
			card.lastPill.Visible = isLast
			card.lastPill.Text = Store.t("ui.menu_last_time")
			-- Stage 11 menu: a used world is a go (cyan, lime for the last one); the warning colour
			-- belongs to the "Start over" box only.
			card.stroke.Color = if isLast then ROLE.good elseif used then ROLE.accent else ROLE.stroke
			card.stroke.Thickness = if isLast then Ui.STROKE + 2 else Ui.STROKE
			card.button.BackgroundColor3 = if used then ROLE.panelRaised else ROLE.panel
		end
		slotsSaveNote.Text = if meta and meta.offline then "" else Store.t("ui.save_auto")
		Ui.setButton(choiceContinue, Store.t("ui.continue"))
		Ui.setButton(choiceRestart, Store.t("ui.menu_start_over"))
		if choiceBox.Visible and pickedSlot then
			fillChoice(pickedSlot) -- language change: refresh the box texts
		end
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
		if waitNotice ~= nil then
			-- Stage 10 fix: this world is not for this player; the server sends them back to the menu.
			waitText.Text = Store.t(noticeKey(waitNotice))
			waitText.TextColor3 = ROLE.warning
		elseif waitFailed and inWorldServer then
			-- Stage 11 menu: still loading in the world server; the player may go back to the lobby.
			waitText.Text = Store.t("ui.menu_wait_slow")
			waitText.TextColor3 = ROLE.text
		elseif waitFailed then
			waitText.Text = Store.t(noticeKey(waitReason))
			waitText.TextColor3 = ROLE.warning
		else
			waitText.Text = Store.t(waitKey(waitKind))
			waitText.TextColor3 = ROLE.text
		end
		waitBack.Visible = waitFailed and waitNotice == nil
		Ui.setButton(waitBack, Store.t(if inWorldServer then "ui.menu_back_lobby" else "ui.menu_back"))
	end

	-- Stage 10 fix: the "Join a friend" list.
	local function renderFriends()
		local view = Store.friendWorlds()
		local worlds = if view then view.worlds else {}
		local loading = view == nil or view.status == "loading"
		for index, card in friendCards do
			local world = worlds[index]
			card.button.Visible = world ~= nil
			if world then
				card.name.Text = if world.name ~= "" then world.name else Store.t("ui.menu_join_friend")
				card.base.label.Text = Store.t("ui.base_level", { n = world.baseLevel })
				card.players.label.Text = Store.t("ui.menu_friend_players", { n = world.players, m = world.max })
				card.fullPill.Visible = world.full
				card.fullPill.Text = Store.t("ui.menu_friend_full")
				card.stroke.Color = if world.full then ROLE.stroke else ROLE.good
				card.button.BackgroundColor3 = if world.full then ROLE.panel else ROLE.panelRaised
			end
		end
		local empty = #worlds == 0
		friendsStatus.Visible = empty
		friendsHint.Visible = empty and not loading
		if view ~= nil and view.status == "error" then
			friendsStatus.Text = Store.t("ui.menu_friends_error")
			friendsStatus.TextColor3 = ROLE.warning
		elseif loading then
			friendsStatus.Text = Store.t("ui.menu_friends_loading")
			friendsStatus.TextColor3 = ROLE.text
		else
			friendsStatus.Text = Store.t("ui.menu_friends_none")
			friendsStatus.TextColor3 = ROLE.text
		end
		friendsHint.Text = Store.t("ui.menu_friends_hint")
		Ui.setButton(friendsRefresh, Store.t("ui.menu_friends_refresh"))
		Ui.setButtonLook(friendsRefresh, not loading, ROLE.secondaryButton)
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
			panelTitle.Text = Store.t(if flow == "join" then "ui.menu_pick_join" else "ui.menu_pick_load")
			Ui.setIcon(panelIcon, if flow == "join" then ICONS.helmet else ICONS.planet, ROLE.accent)
		elseif current == "friends" then
			panelTitle.Text = Store.t("ui.menu_friends_title")
			Ui.setIcon(panelIcon, ICONS.language, ROLE.good)
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
		renderFriends()
		renderCredits()
		renderPanel()
	end

	showScreen = function(name: ScreenName)
		-- Stage 11 menu: a player in their world server stays on the wait screen (the server there
		-- refuses every other choice).
		if inWorldServer and name ~= "wait" then
			name = "wait"
		end
		current = name
		if name ~= "slots" then
			choiceBox.Visible = false
			confirm.Visible = false
			pickedSlot = nil
		end
		syncCardSelection() -- Stage 11 menu (review): the cards are selectable again
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
		friendsView.Visible = name == "friends"
		if name == "home" or name == "slots" or name == "credits" or name == "friends" then
			backTarget = "home"
		end
		render()
		if name == "home" then
			selectFirst(if Store.continueSlot() then continueButton else worldsButton)
		elseif name == "slots" then
			selectFirst(slotCards[1].button)
		elseif name == "mode" then
			selectFirst(modeCards[1].button)
		elseif name == "credits" then
			selectFirst(backButton)
		elseif name == "friends" then
			selectFirst(if friendCards[1].button.Visible then friendCards[1].button else friendsRefresh)
		elseif name == "wait" and waitBack.Visible then
			selectFirst(waitBack)
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

	local function startWait(kind: WaitKind)
		waitKind = kind
		waitFailed = false
		waitReason = nil
		lobbyNotice = nil -- a new choice: the old notice no longer applies
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
		-- Stage 10 fix: outside Studio both modes fly to the player's own world server.
		local kind: WaitKind = if mode == "solo" and not RunService:IsStudio() then "solo" else "friends"
		useTeleportScreen(waitKey(kind)) -- Stage 11 menu: before the server starts the trip
		Store.chooseSlot(chosenSlot, mode, chosenFresh)
		startWait(kind)
	end

	-- Stage 10 fix: Join a friend, then this slot: the server checks the friendship and the room.
	sendJoin = function(slot: number)
		local owner = chosenOwner
		if owner == nil then
			return -- (the slot card already applied the tap cooldown)
		end
		deps.closeSettings()
		chosenSlot = slot
		useTeleportScreen(waitKey("join")) -- Stage 11 menu
		Store.joinWorld(owner, slot)
		startWait("join")
	end

	openFriends = function()
		showScreen("friends")
		-- The server answers at most every few seconds; a faster tap keeps the list it has.
		if os.clock() - lastFriendsRequest >= 10.5 then
			lastFriendsRequest = os.clock()
			Store.requestFriendWorlds()
		end
	end
	Store.onFriendWorlds(function()
		if current == "friends" then
			renderFriends()
		end
	end)

	-- Stage 10 fix: the server could not take the player to that world (or it is full or closed).
	player:GetAttributeChangedSignal("SBO_TripFailed"):Connect(function()
		if current ~= "wait" or Store.isSlotChosen() then
			return
		end
		local reason = player:GetAttribute("SBO_TripFailedReason")
		waitReason = if type(reason) == "string" then reason else nil
		waitFailed = true
		renderWait()
		renderPanel()
		selectFirst(waitBack)
	end)
	-- Stage 10 fix: this world server is sending the player back to the lobby.
	player:GetAttributeChangedSignal("SBO_WorldNotice"):Connect(function()
		local notice = player:GetAttribute("SBO_WorldNotice")
		waitNotice = if type(notice) == "string" then notice else nil
		if screen.Visible then
			renderWait()
		end
	end)

	-- Animation: the waiting rocket (the background is the cinematic now). Stage 11 menu: it keeps
	-- moving while a world server is still loading, and stands still with Store.reduceMotion().
	local animation: RBXScriptConnection? = nil
	local sinceFrame = 0
	local function animate(deltaTime: number)
		sinceFrame += deltaTime
		if sinceFrame < ANIMATION_STEP then
			return
		end
		sinceFrame = 0
		local now = os.clock()
		local moving = waitView.Visible and (not waitFailed or inWorldServer) and not Store.reduceMotion()
		if moving then
			waitIcon.Rotation = 12 * math.sin(now * 3)
			waitBadge.Position = UDim2.fromScale(0.5, 0.12 - 0.015 * math.sin(now * 2))
		elseif waitIcon.Rotation ~= 0 then
			waitIcon.Rotation = 0
			waitBadge.Position = UDim2.fromScale(0.5, 0.12)
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

	-- Stage 10: the cinematic plays while the menu is open (fade = this screen's own night layer, so
	-- the title and buttons never fade).
	local cinematicOn = false
	local function setCinematic(on: boolean)
		if cinematic == nil or on == cinematicOn then
			return
		end
		cinematicOn = on
		local ok, err = pcall(function()
			if on then
				cinematic.playMenu({ fade = fade, owner = "menu" })
			elseif cinematic.owner() == "menu" then
				cinematic.stop() -- a recording started from DemoKeys keeps playing
			end
		end)
		if not ok then
			warn(`[SpaceBaseOdyssey] start menu cinematic failed: {err}`)
			fade.Visible = false
			screen.BackgroundTransparency = 0
		end
	end

	local function hide()
		waitToken += 1
		screen.Visible = false
		setAnimating(false)
		setCinematic(false)
		setVeil(false)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then
			pcall(function()
				GuiService.SelectedObject = nil
			end)
		end
	end

	-- Gamepad B goes back one screen (Stage 11 menu: closes a box first and gives the selection back).
	UserInputService.InputBegan:Connect(function(input: InputObject, _processed: boolean)
		if not screen.Visible or input.KeyCode ~= Enum.KeyCode.ButtonB then
			return
		end
		if confirm.Visible then
			confirm.Visible = false
			local slot = pickedSlot
			if slot then
				openChoice(slot)
			else
				selectPickedCard()
			end
		elseif choiceBox.Visible then
			closeChoice()
		elseif inWorldServer then
			return -- the world server's wait screen has its own button
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
			elseif screen.Visible and current == "home" then
				renderHome()
			end
		end
	end)

	if screen.Visible then
		setAnimating(true)
		setVeil(true)
		setCinematic(true)
		local teleportedSlot, teleportedKind, notice = teleportInfo()
		if teleportedSlot then
			-- Arrived in a world server: the server picks that slot by itself (or, if this world is not
			-- for this player, says why before it sends them back; the attribute may already be set).
			inWorldServer = true
			chosenSlot = teleportedSlot
			local worldNotice = player:GetAttribute("SBO_WorldNotice")
			waitNotice = if type(worldNotice) == "string" then worldNotice else nil
			startWait(teleportedKind or "friends")
			showArrivalScreen(player) -- Stage 11 menu: the trip's screen fades into the wait screen
		else
			lobbyNotice = notice -- back in the lobby: say why (for example "your friend left")
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
