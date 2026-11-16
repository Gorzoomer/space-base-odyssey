--!strict
-- Space Base Odyssey - in-game HUD.
--   Shift screen: meters, shift timer, event banner, storm countdown (with the flare's data source),
--   Earth-link indicator.
--   Field (shift and while roaming the base): the vitals panel (suit air out of PlayerStats.suitMax)
--   and the carried ice.
--   Fix 8 (playtest): the field pills stack upwards from just above Roblox's tool bar (the backpack
--   hotbar, bottom centre, about 70 real pixels tall while the player has tools) and above the
--   vehicle panel while driving, so nothing hides under them. The left column starts under the
--   Roblox top bar (GuiService.TopbarInset), and the build-progress signs are small screen-sized
--   signs high above the pads, clear of the pad's own prompt.
--   Wallet (Stage 6: shift, roaming, base mode and mission select): credits, player level and an XP
--   bar, with a "+N" pop when credits rise. Stage 9: a third row with the base level (the habitat's
--   level, the town hall of the habitat tree), which pops when it goes up. Stage 11 tycoon client: a
--   slim "Machines: +N credits a minute" pill just under the wallet while this player's machines
--   earn (IncomePops.machineRate), and a friend's silo row is dimmed for a guest.
--   Stage 7 (field): a "Carrying parts" pill while the player carries a parts crate from the lander,
--   a food boost timer while player attribute SBO_FoodBoostUntil (server time) is in the future, and a
--   small build-progress sign (a local BillboardGui) over every build pad with a build in progress
--   (BaseState.inProgress): step x/y and what is needed next (a crate, or Assemble with the wrench).
--   Stage 8 (field): a gas tank bar for the gear (air boots, jetpack; Gear.luau simulates the tank)
--   with a small gear row (each owned gear's icon, lit while it is on, with its key letter B / J on
--   keyboards), shown only when the player owns any gear; and an "Auto-run (X)" pill while auto-run
--   is on (Sprint.luau).
--   Top bar (Hud.newTopBar): Missions and Wardrobe buttons beside the Settings button, and the "Build
--   your base" hint pill in base mode until the habitat and the solar panels stand (Stage 8: it used
--   to wait for every core build; Stage 9: never while the quest tracker shows a quest). Stage 7: no Base button (team feedback: building from a menu
--   let players upgrade everything while standing still; builds happen at the pads in the world).
--   Stage 10 (playtest polish): an always-on vitals panel in the left column in every field mode
--   (shift, roam, base) with the same rows as the meters panel (Meters.fillRow): suit air (always),
--   fresh greenhouse food (ready or seconds left, once the greenhouse stands; the food boost countdown
--   replaces it while the boost runs, also during a shift) and the silo ice (once a drill stands).
--   It replaces the big suit air bar and the food boost pill at the bottom centre; a small pulsing
--   "Low air! Go inside" pill stays there while the suit is low outside. The bottom pills are about
--   two thirds of their old height (team feedback: big boxes hid the world).
-- Screen layout (fractions of the screen):
--   top centre   y 0.02-0.09  shift timer 0.25-0.49 | today's event 0.51-0.75
--   top right    y 0.02-0.10  settings button 0.815-0.985 (Settings.luau); y 0.115-0.18 Earth link
--                base mode:  Missions | Wardrobe | Achievements buttons 0.43-0.805, y 0.02-0.10
--                            (Stage 10; 0.555-0.805 without Achievements);
--                            hint pill 0.3-0.7, y 0.115-0.175
--                elsewhere:  an icon-only Wardrobe square at the right edge, under the settings
--                            button (y 0.115: mission select, roaming) or under the Earth link or
--                            sources button (y 0.195: shift, power board)
--   left column  x 0.01-0.21  stacked top-down with 0.012 gaps (see placeColumn):
--                             objectives or, in base mode, the quest tracker (Objectives.luau, from
--                             y 0.10-0.12; its bottom comes from deps.columnTop), then in a shift
--                             the meters panel (0.19 tall: air, food, radiation, water, data
--                             waiting), then the vitals panel (field modes, 0.049-0.119 tall: one
--                             to three rows of 0.035), then the wallet (0.125) with, while the
--                             machines earn (not in a shift), the income pill 0.006 under it (0.036,
--                             Stage 11 tycoon client; a child of the wallet). The first panel
--                             starts at y 0.105 (0.12 for the meters) when nothing is above it,
--                             lower when the Roblox top bar is taller (e.g. on phones). Worst case
--                             (a shift with the tallest objectives) ends near y 0.85.
--   centre       y 0.115-0.21 C.A.R.L. bubble (Messages.luau, x 0.33-0.67; y 0.19-0.285 in base mode)
--                y 0.27-0.48  storm countdown and flare source (x 0.22-0.78)
--   bottom       stacked upwards from the tool bar's top edge (see placeStack): the low air pill
--                (0.046 tall, x 0.39-0.61), then the gear gas tank (0.042, x 0.375-0.625), then
--                auto-run (0.034, x 0.425-0.575), then carrying ice or parts (0.048, x 0.405-0.595)
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Types = require(Shared:WaitForChild("Types"))

local Meters = require(script.Parent.Meters)
local Objectives = require(script.Parent.Objectives)
local Store = require(script.Parent.Store)
local Audio = require(script.Parent.Audio) -- Stage 11 audio
local Ui = require(script.Parent.Ui)
-- Stage 11 tycoon client: machine income and whose silo it is.
local IncomePops = require(script.Parent.IncomePops)
local IceLineView = require(Shared:WaitForChild("IceLineView"))

local Hud = {}

local ROLE = Ui.ROLE

-- "2024-05-10T06:54Z" -> "2024-05-10".
local function shortDate(value: string): string
	if string.match(value, "^%d%d%d%d%-%d%d%-%d%d") then
		return string.sub(value, 1, 10)
	end
	return value
end

-- Left column: the meters sit this far under the objectives panel (fractions of the screen).
local COLUMN_X = 0.01
local COLUMN_WIDTH = 0.2
local COLUMN_TOP = 0.12 -- when no objectives panel is shown
local COLUMN_GAP = 0.012
local METERS_HEIGHT = 0.19
local WALLET_TOP = 0.105 -- under the Roblox menu buttons when nothing else is in the column
local WALLET_HEIGHT = 0.125 -- Stage 9: three rows (credits and level, XP, base level)
-- The first two rows keep their Stage 6 size: fractions of the old 0.09-tall wallet scaled by this.
local WALLET_K = 0.09 / WALLET_HEIGHT
-- Stage 11 tycoon client: the machine income pill under the wallet (fractions of the screen).
local INCOME_HEIGHT = 0.036
local INCOME_GAP = 0.006
local TOPBAR_GAP_PIXELS = 8 -- under the Roblox top bar (menu and chat buttons)
local POP_SECONDS = 0.9
local FOOD_BOOST_ATTRIBUTE = "SBO_FoodBoostUntil"
-- Bottom stack (fractions of the screen), above Roblox's tool bar. The default backpack hotbar uses
-- 60 px slots with a 5 px buffer: 70 real pixels at the bottom centre (not scaled by our UIScale).
local HOTBAR_PIXELS = 70
local HOTBAR_GAP_PIXELS = 14
local EDGE_PIXELS = 14 -- bottom margin when no tool bar shows
local STACK_GAP = 0.012
-- Stage 10: about two thirds of the old heights (carry 0.07, gas 0.06, auto-run 0.05) and narrower.
local CARRY_SIZE = UDim2.fromScale(0.19, 0.048)
local GAS_SIZE = UDim2.fromScale(0.25, 0.042)
local AUTORUN_SIZE = UDim2.fromScale(0.15, 0.034)
local LOW_AIR_SIZE = UDim2.fromScale(0.22, 0.046)
local PILL_TEXT_MAX = 22 -- one line, sized to the pill (Ui.oneLine)
-- Stage 10: vitals panel rows (the meters panel's row height: 0.19 * 0.92 / 5).
local VITALS_ROW = 0.035
local VITALS_PAD = 0.007
local VITALS_ROW_FILL = 0.92 -- share of a row slot the row's cell fills
local GAS_LOW_FRACTION = 0.25 -- the gas bar turns orange below this share of the tank (display only)
local VEHICLE_PANEL_NAME = "VehiclePanel" -- VehicleClient.luau, bottom centre while driving
-- Build-progress signs over the pads: screen-sized (pixels at UI scale 1), high above the pad so
-- the pad's ProximityPrompt (drawn at the pad) always stays readable.
local SIGN_PIXELS = Vector2.new(200, 58)
local SIGN_MIN_SCALE = 0.6
local SIGN_MAX_SCALE = 1.6
local SIGN_HEIGHT = 12 -- studs above the pad centre
local SIGN_MAX_DISTANCE = 150
local SIGN_POLL_SECONDS = 1 -- look again for pads that were not there yet

-- What the HUD shows (Main.client picks it from the phase and the open screens):
--   "shift"  work time: everything.   "roam"  planning with the power board closed (walk tasks).
--   "base"   base mode (Briefing with the mission select closed).   "select"  mission select open.
--   "board"  planning with the power board open.   "none"  report.
export type Mode = "shift" | "roam" | "base" | "select" | "board" | "none"

-- Stage 8 gear (Gear.luau), passed by Main.client; nil when Gear failed to load.
export type GearDeps = {
	gas: () -> (number, number), -- current, max
	level: (id: string) -> number, -- owned level (0 = not owned)
	isOn: (id: string) -> boolean,
}

export type Deps = {
	-- Bottom edge (screen fraction) of the objectives panel, or nil while it is hidden.
	columnTop: (() -> number?)?,
	gear: GearDeps?,
	autoRunning: (() -> boolean)?, -- Sprint.luau auto-run is on
}

export type HudView = {
	setVisible: (visible: boolean) -> (), -- true = setMode("shift"), false = setMode("none")
	setMode: (mode: Mode) -> (),
	render: () -> (),
	renderWallet: () -> (), -- call when a new BaseState arrives
	renderBase: () -> (), -- Stage 7: call when a new BaseState arrives (wallet, parts, build signs)
	tick: () -> (), -- call often (timers and storm countdown use server time)
}

-- Total suit air for the bar: PlayerStats.suitMax (the "tank" skill), or SUIT.MAX with an older server.
local function suitMaxOf(stats: Store.PlayerStats): number
	local value: any = (stats :: any).suitMax
	if type(value) == "number" and value > 0 then
		return value
	end
	return MissionData.SUIT.MAX
end

-- Stage 10: a short pill's icon and one-line text, laid out for its smaller height.
local function compactPill(pill: Ui.IconText)
	pill.icon.Size = UDim2.fromScale(0.14, 0.74)
	pill.icon.Position = UDim2.fromScale(0.035, 0.5)
	pill.label.Size = UDim2.fromScale(0.77, 0.84)
	pill.label.Position = UDim2.fromScale(0.19, 0.5)
	Ui.oneLine(pill.label)
end

-- Stage 10: at least one automatic ice drill stands (the silo only fills with one).
local function hasDrill(builds: { [string]: number }): boolean
	for id, level in builds do
		if level >= 1 and string.match(id, "^drill_%d+$") then
			return true
		end
	end
	return false
end

function Hud.new(root: Frame, deps: Deps?): HudView
	local screen = Ui.frame(root, { name = "Hud", zindex = 5, visible = false })
	-- Bottom field pills (low air, gas tank, auto-run, carried ice or parts): at work and roaming.
	-- Stage 10: the suit air value lives in the vitals panel (left column), not here.
	local field = Ui.frame(root, { name = "HudField", zindex = 5, visible = false })

	local meters = Meters.new(screen, {
		name = "Meters",
		size = UDim2.fromScale(COLUMN_WIDTH, METERS_HEIGHT),
		position = UDim2.fromScale(COLUMN_X, COLUMN_TOP),
	}, "column")
	local timer = Ui.iconText(screen, {
		name = "Timer",
		size = UDim2.fromScale(0.24, 0.07),
		position = UDim2.fromScale(0.25, 0.02),
		color = Ui.COLORS.panel,
		transparency = 0.1,
		stroke = 2,
		maxText = 30,
		icon = Ui.ICONS.timer,
		tint = ROLE.accent,
	})
	local eventBanner = Ui.iconText(screen, {
		name = "Event",
		size = UDim2.fromScale(0.24, 0.07),
		position = UDim2.fromScale(0.51, 0.02),
		color = Ui.COLORS.panelLight,
		transparency = 0.1,
		stroke = 2,
		maxText = 30,
	})

	-- Storm warning (countdown) and "storm now" share the centre of the screen.
	local countdown = Ui.iconText(screen, {
		name = "StormCountdown",
		size = UDim2.fromScale(0.56, 0.15),
		position = UDim2.fromScale(0.5, 0.27),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.warning,
		stroke = 5,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.ICONS.warning,
		maxText = 64,
		visible = false,
	})
	-- Under the countdown: says honestly whether the flare is live NASA data or an archive replay.
	-- Ends at y 0.48, clear of the Run button (x >= 0.77) and of the left column (x <= 0.21).
	local flareSource = Ui.iconText(screen, {
		name = "FlareSource",
		size = UDim2.fromScale(0.44, 0.05),
		position = UDim2.fromScale(0.5, 0.43),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.panel,
		transparency = 0.1,
		stroke = 2,
		maxText = 24,
		icon = Ui.ICONS.satellite,
		tint = ROLE.accent,
		visible = false,
	})
	-- A wide, short pill: keep the icon narrow so the text gets the room.
	flareSource.icon.Size = UDim2.fromScale(0.08, 0.86)
	flareSource.icon.Position = UDim2.fromScale(0.02, 0.5)
	flareSource.label.Size = UDim2.fromScale(0.88, 0.86)
	flareSource.label.Position = UDim2.fromScale(0.11, 0.5)

	-- Right edge, under the settings button.
	local earthLink = Ui.iconText(screen, {
		name = "EarthLink",
		size = UDim2.fromScale(0.17, 0.065),
		position = UDim2.fromScale(0.985, 0.115),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.panel,
		transparency = 0.15,
		stroke = 2,
		maxText = 22,
		icon = Ui.ICONS.antenna,
		visible = false,
	})

	local stormNow = Ui.iconText(screen, {
		name = "StormNow",
		size = UDim2.fromScale(0.5, 0.14),
		position = UDim2.fromScale(0.5, 0.27),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.storm,
		stroke = 5,
		strokeColor = ROLE.text,
		maxText = 56,
		outline = true,
		visible = false,
	})

	local iceBadge = Ui.iconText(field, {
		name = "CarryingIce",
		size = CARRY_SIZE,
		position = UDim2.fromScale(0.5, 0.76),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.ice,
		stroke = 2,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.ICONS.ice,
		maxText = PILL_TEXT_MAX,
		visible = false,
	})
	compactPill(iceBadge)

	-- Stage 7: a parts crate carried from the lander to a build pad (same place as the ice: one at a time).
	local crateBadge = Ui.iconText(field, {
		name = "CarryingCrate",
		size = CARRY_SIZE,
		position = UDim2.fromScale(0.5, 0.76),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.star,
		stroke = 2,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.Icons.crate,
		maxText = PILL_TEXT_MAX,
		visible = false,
	})
	compactPill(crateBadge)

	-- Stage 10: the suit is low outside: a small pulsing pill (the vitals panel shows the value).
	-- The Stage 7 food boost pill moved into the vitals panel's food row.
	local lowAirBadge = Ui.iconText(field, {
		name = "LowAir",
		size = LOW_AIR_SIZE,
		position = UDim2.fromScale(0.5, 0.8),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.warning,
		stroke = 2,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.ICONS.warning,
		tint = Ui.COLORS.textDark,
		maxText = PILL_TEXT_MAX,
		visible = false,
	})
	compactPill(lowAirBadge)

	-- Stage 8: the gear gas tank and the gear row (one chip per owned gear, lit while it is on).
	local gasPanel = Ui.panel(field, {
		name = "GearGas",
		size = GAS_SIZE,
		position = UDim2.fromScale(0.5, 0.78),
		anchor = Vector2.new(0.5, 0),
		transparency = 0.1,
		corner = 0.3,
		stroke = 2,
		visible = false,
	})
	Ui.icon(gasPanel, Ui.Icons.gas, {
		name = "GasIcon",
		size = UDim2.fromScale(0.1, 0.7),
		position = UDim2.fromScale(0.025, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
	})
	local gasBar = Ui.bar(gasPanel, {
		name = "Bar",
		size = UDim2.fromScale(0.5, 0.62),
		position = UDim2.fromScale(0.13, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 22,
	})
	type GearChip = { id: string, frame: Frame, icon: ImageLabel, key: TextLabel, stroke: UIStroke? }
	local gearChips: { GearChip } = {}
	for index, def in MissionData.BASE.GEAR do
		local chip = Ui.frame(gasPanel, {
			name = "Gear_" .. def.id,
			size = UDim2.fromScale(0.15, 0.8),
			position = UDim2.fromScale(0.66 + (index - 1) * 0.165, 0.5),
			anchor = Vector2.new(0, 0.5),
			color = ROLE.panelRaised,
			corner = 0.3,
			stroke = 2,
			strokeColor = ROLE.stroke,
			visible = false,
		})
		local chipIcon = Ui.icon(chip, Ui.iconImage(def.icon), {
			name = "Icon",
			size = UDim2.fromScale(0.56, 0.8),
			position = UDim2.fromScale(0.05, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = ROLE.textDim,
		})
		-- The key letter (MissionData GEAR key: a keyboard key name, not a word).
		local keyLabel = Ui.label(chip, {
			name = "Key",
			text = def.key,
			size = UDim2.fromScale(0.38, 0.7),
			position = UDim2.fromScale(0.97, 0.5),
			anchor = Vector2.new(1, 0.5),
			textColor = ROLE.textDim,
			maxText = 18,
			minText = 6,
		})
		table.insert(gearChips, {
			id = def.id,
			frame = chip,
			icon = chipIcon,
			key = keyLabel,
			stroke = chip:FindFirstChildOfClass("UIStroke"),
		})
	end

	-- Stage 8: auto-run is on (Sprint.luau).
	local autoRunBadge = Ui.iconText(field, {
		name = "AutoRun",
		size = AUTORUN_SIZE,
		position = UDim2.fromScale(0.5, 0.72),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.accent,
		stroke = 2,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.Icons.autorun,
		maxText = PILL_TEXT_MAX,
		visible = false,
	})
	compactPill(autoRunBadge)

	-- Stage 10: the always-on vitals panel (left column, field modes). Rows are made once here and
	-- only shown, hidden and moved while playing (no Instances per frame).
	local vitals = Ui.panel(root, {
		name = "Vitals",
		size = UDim2.fromScale(COLUMN_WIDTH, VITALS_PAD * 2 + VITALS_ROW),
		position = UDim2.fromScale(COLUMN_X, WALLET_TOP),
		transparency = 0.08,
		corner = 0.2,
		stroke = 2,
		zindex = 15,
		visible = false,
	})
	type VitalRow = { cell: Frame, icon: ImageLabel, name: TextLabel, bar: Ui.Bar }
	local function vitalRow(name: string, image: string, tint: Color3): VitalRow
		local cell = Ui.frame(vitals, {
			name = name,
			size = UDim2.fromScale(0.94, VITALS_ROW_FILL),
			position = UDim2.fromScale(0.03, 0),
			corner = 0.3,
			zindex = 16,
			visible = false,
		})
		local icon, label, bar = Meters.fillRow(cell, image, tint, 16)
		return { cell = cell, icon = icon, name = label, bar = bar }
	end
	local suitRow = vitalRow("SuitAir", Ui.ICONS.suit, ROLE.suit)
	local foodRow = vitalRow("FreshFood", Ui.ICONS.food, ROLE.food)
	local siloRow = vitalRow("SiloIce", Ui.Icons.silo, Ui.COLORS.ice)
	local vitalRows: { VitalRow } = { suitRow, foodRow, siloRow }

	-- Wallet: credits (gold coin), player level and an XP bar (magenta sparkles).
	local wallet = Ui.panel(root, {
		name = "Wallet",
		size = UDim2.fromScale(COLUMN_WIDTH, WALLET_HEIGHT),
		position = UDim2.fromScale(COLUMN_X, WALLET_TOP),
		transparency = 0.08,
		corner = 0.2,
		stroke = 2,
		strokeColor = ROLE.star,
		zindex = 15,
		visible = false,
	})
	Ui.icon(wallet, Ui.Icons.coin, {
		name = "CoinIcon",
		size = UDim2.fromScale(0.13, 0.42 * WALLET_K),
		position = UDim2.fromScale(0.03, 0.28 * WALLET_K),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.star,
		zindex = 16,
	})
	local creditsText = Ui.label(wallet, {
		name = "Credits",
		size = UDim2.fromScale(0.4, 0.44 * WALLET_K),
		position = UDim2.fromScale(0.17, 0.28 * WALLET_K),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 24,
		minText = 8,
		zindex = 16,
	})
	local levelPill = Ui.label(wallet, {
		name = "Level",
		size = UDim2.fromScale(0.4, 0.4 * WALLET_K),
		position = UDim2.fromScale(0.97, 0.28 * WALLET_K),
		anchor = Vector2.new(1, 0.5),
		color = ROLE.panelRaised,
		textColor = ROLE.accent,
		corner = 0.5,
		maxText = 18,
		minText = 8,
		zindex = 16,
	})
	local levelScale = Instance.new("UIScale")
	levelScale.Parent = levelPill
	Ui.icon(wallet, Ui.Icons.xp, {
		name = "XpIcon",
		size = UDim2.fromScale(0.13, 0.38 * WALLET_K),
		position = UDim2.fromScale(0.03, 0.73 * WALLET_K),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.reward,
		zindex = 16,
	})
	local xpBar = Ui.bar(wallet, {
		name = "XpBar",
		size = UDim2.fromScale(0.8, 0.34 * WALLET_K),
		position = UDim2.fromScale(0.17, 0.73 * WALLET_K),
		anchor = Vector2.new(0, 0.5),
		maxText = 14,
		zindex = 16,
	})
	xpBar.label.Size = UDim2.fromScale(0.9, 0.9)
	-- Stage 9: the base level (the habitat's level, 1-5): a cyan house and "Base level N".
	local baseRowY = (0.73 + (0.73 - 0.28)) * WALLET_K -- one row step below the XP bar
	Ui.icon(wallet, Ui.Icons.home, {
		name = "BaseIcon",
		size = UDim2.fromScale(0.13, 0.36 * WALLET_K),
		position = UDim2.fromScale(0.03, baseRowY),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = 16,
	})
	local baseLevelText = Ui.label(wallet, {
		name = "BaseLevel",
		size = UDim2.fromScale(0.8, 0.36 * WALLET_K),
		position = UDim2.fromScale(0.17, baseRowY),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 16,
		minText = 7,
		zindex = 16,
	})
	local baseLevelScale = Instance.new("UIScale")
	baseLevelScale.Parent = baseLevelText
	-- Stage 11 tycoon client: "Machines: +N credits a minute" in a slim pill just under the wallet
	-- (the wallet keeps its size, so its rows never move), while this player's machines earn.
	local incomePill = Ui.iconText(wallet, {
		name = "MachineIncome",
		size = UDim2.fromScale(1, INCOME_HEIGHT / WALLET_HEIGHT),
		position = UDim2.fromScale(0, 1 + INCOME_GAP / WALLET_HEIGHT),
		color = ROLE.panel,
		transparency = 0.08,
		stroke = 2,
		strokeColor = ROLE.star,
		icon = Ui.ICONS.robot,
		tint = ROLE.star,
		textColor = ROLE.star,
		maxText = 18,
		zindex = 16,
		visible = false,
	})
	incomePill.icon.Size = UDim2.fromScale(0.11, 0.78)
	incomePill.label.Size = UDim2.fromScale(0.83, 0.82)
	incomePill.label.Position = UDim2.fromScale(0.15, 0.5)
	Ui.oneLine(incomePill.label)

	local visible = false
	local mode: Mode = "none"
	local columnTop = COLUMN_TOP
	local walletTop = WALLET_TOP
	local shownCredits: number? = nil
	local shownLevel: number? = nil
	local shownXp: number? = nil -- Stage 11 audio: the XP sound
	local shownBaseLevel: number? = nil
	local player = Players.LocalPlayer

	local function viewportHeight(): number
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 0
		return if height > 0 then height else 720
	end

	-- Bottom of the Roblox top bar (screen fraction): on phones it takes more of the screen.
	local function topbarBottom(): number
		local inset = 0
		local ok, rect = pcall(function(): any
			return (GuiService :: any).TopbarInset
		end)
		if ok and typeof(rect) == "Rect" then
			inset = (rect :: Rect).Max.Y
		end
		if inset <= 0 then
			inset = GuiService:GetGuiInset().Y
		end
		return (inset + TOPBAR_GAP_PIXELS) / viewportHeight()
	end

	-- Keep the meters panel right under the objectives panel (its height changes with the mission).
	-- Stage 10: the vitals panel follows the meters (shift) or the objectives (roaming, base mode),
	-- and the wallet follows the vitals panel (or the objectives on the mission select); the first
	-- one sits at the top. Nothing starts under the Roblox top bar.
	local vitalsTop = WALLET_TOP
	local function placeColumn()
		local topLimit = topbarBottom()
		local bottom = if deps and deps.columnTop then deps.columnTop() else nil
		local top = if bottom then bottom + COLUMN_GAP else math.max(COLUMN_TOP, topLimit)
		if math.abs(top - columnTop) > 0.0005 then
			columnTop = top
			meters.frame.Position = UDim2.fromScale(COLUMN_X, top)
		end
		local below: number? = if mode == "shift" then columnTop + METERS_HEIGHT else bottom
		if vitals.Visible then
			local nextVitalsTop = if below then below + COLUMN_GAP else math.max(WALLET_TOP, topLimit)
			if math.abs(nextVitalsTop - vitalsTop) > 0.0005 then
				vitalsTop = nextVitalsTop
				vitals.Position = UDim2.fromScale(COLUMN_X, vitalsTop)
			end
			below = vitalsTop + vitals.Size.Y.Scale
		end
		local nextWalletTop = if below then below + COLUMN_GAP else math.max(WALLET_TOP, topLimit)
		if math.abs(nextWalletTop - walletTop) > 0.0005 then
			walletTop = nextWalletTop
			wallet.Position = UDim2.fromScale(COLUMN_X, walletTop)
		end
	end
	meters.frame.Position = UDim2.fromScale(COLUMN_X, COLUMN_TOP)

	-- True while Roblox shows its tool bar: the backpack core UI is on and the player has a tool.
	local function hotbarShown(): boolean
		local ok, enabled = pcall(function(): boolean
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end)
		if ok and enabled == false then
			return false
		end
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack and backpack:FindFirstChildOfClass("Tool") then
			return true
		end
		local character = player.Character
		return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
	end

	-- Lowest screen fraction the bottom pills may reach: above the tool bar (or the screen edge),
	-- and above the vehicle panel while driving.
	local function bottomLimit(): number
		local reserve = if hotbarShown() then HOTBAR_PIXELS + HOTBAR_GAP_PIXELS else EDGE_PIXELS
		local limit = 1 - reserve / viewportHeight()
		local vehicle = root:FindFirstChild(VEHICLE_PANEL_NAME)
		local rootHeight = root.AbsoluteSize.Y
		if vehicle and vehicle:IsA("GuiObject") and vehicle.Visible and rootHeight > 0 then
			local top = (vehicle.AbsolutePosition.Y - root.AbsolutePosition.Y) / rootHeight
			limit = math.min(limit, top - STACK_GAP)
		end
		return limit
	end

	-- Bottom centre pills, stacked upwards from bottomLimit (only the visible ones take room):
	-- the low air warning, the gear gas tank, auto-run, then carrying ice or parts.
	local stackOrder: { GuiObject } = { lowAirBadge.frame, gasPanel, autoRunBadge.frame, crateBadge.frame, iceBadge.frame }
	local function placeStack()
		local y = bottomLimit()
		for _, item in stackOrder do
			if not item.Visible then
				continue
			end
			y -= item.Size.Y.Scale
			if math.abs(item.Position.Y.Scale - y) > 0.0005 then
				item.Position = UDim2.fromScale(0.5, y)
			end
			y -= STACK_GAP
		end
	end

	-- "+N" rises from the credits and fades.
	local function popCredits(amount: number)
		local pop = Ui.label(wallet, {
			name = "CreditsPop",
			text = `+{amount}`,
			size = UDim2.fromScale(0.4, 0.5),
			position = UDim2.fromScale(0.17, 0.05),
			anchor = Vector2.new(0, 0.5),
			alignX = Enum.TextXAlignment.Left,
			textColor = ROLE.star,
			maxText = 26,
			outline = true,
			zindex = 18,
		})
		local tween = TweenService:Create(pop, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.3, -0.55),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween.Completed:Connect(function()
			pop:Destroy()
		end)
		tween:Play()
	end

	local function popLevel()
		levelScale.Scale = 1.5
		TweenService:Create(levelScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end

	local function walletShown(): boolean
		return Store.getBase() ~= nil and (mode == "shift" or mode == "roam" or mode == "base" or mode == "select")
	end

	local function renderWallet()
		local state = Store.getBase()
		wallet.Visible = walletShown()
		if state == nil then
			return
		end
		local credits = math.floor(state.credits)
		creditsText.Text = tostring(credits)
		local creditsRose = shownCredits ~= nil and credits > (shownCredits :: number) and wallet.Visible
		if creditsRose then
			popCredits(credits - (shownCredits :: number))
			-- Stage 11 audio; Stage 11 tycoon client: quiet when a "+N" pop near the player just played
			-- its own coin for the same delivery (IncomePops).
			if not IncomePops.coinHeardRecently() then
				Audio.play(if credits - (shownCredits :: number) >= 50 then "coin_burst" else "coin_single")
			end
		end
		shownCredits = credits
		levelPill.Text = Store.t("ui.level", { n = state.level })
		local levelRose = shownLevel ~= nil and state.level > (shownLevel :: number) and wallet.Visible
		if levelRose then
			popLevel()
			Audio.play("level_up") -- Stage 11 audio
			Audio.sting("sting_level_up") -- Stage 11 audio
		end
		shownLevel = state.level
		-- Stage 11 audio: XP alone (no coins, no level up) gets its own small sound.
		if shownXp ~= nil and state.xp > (shownXp :: number) and wallet.Visible and not creditsRose and not levelRose then
			Audio.play("xp_gain")
		end
		shownXp = state.xp
		-- Stage 9: the base level is the habitat's level.
		local baseLevel = BaseBuild.habitatLevel(state.builds)
		baseLevelText.Text = Store.t("ui.base_level", { n = baseLevel })
		if shownBaseLevel ~= nil and baseLevel > (shownBaseLevel :: number) and wallet.Visible then
			baseLevelScale.Scale = 1.5
			TweenService:Create(baseLevelScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		shownBaseLevel = baseLevel
		local nextXp = state.nextLevelXp
		if nextXp ~= nil and nextXp > state.levelXp then
			local into = math.max(0, state.xp - state.levelXp)
			local span = nextXp - state.levelXp
			xpBar.set(into / span, ROLE.reward, `{math.floor(state.xp)}/{math.floor(nextXp)}`, nil)
		else
			xpBar.set(1, ROLE.reward, tostring(math.floor(state.xp)), nil) -- top level
		end
		-- Stage 11 tycoon client: what this player's machines earn a minute (the world owner's only).
		local rate = IncomePops.machineRate()
		-- Not in a shift: the column is tallest then (it would reach the phone thumbstick).
		local earning = wallet.Visible and mode ~= "shift" and rate > 0 and IncomePops.isSiloOwner()
		incomePill.frame.Visible = earning
		if earning then
			incomePill.label.Text = Store.t("ui.line.machines", { n = IceLineView.formatRate(rate) })
		end
		placeColumn()
	end

	-- Stage 11 tycoon client: the machine income comes with the BaseState IncomePops keeps (it may
	-- arrive just after the Store's copy), so the wallet renders again then.
	IncomePops.onState(function()
		renderWallet()
	end)

	-- Defined below (after the gear widgets); render() calls it.
	local renderGear: () -> ()

	-- Stage 10: place the visible vitals rows top-down and fit the panel to them.
	local function layoutVitals()
		local count = 0
		for _, row in vitalRows do
			if row.cell.Visible then
				count += 1
			end
		end
		local height = VITALS_PAD * 2 + VITALS_ROW * math.max(1, count)
		local panelSize = UDim2.fromScale(COLUMN_WIDTH, height)
		if vitals.Size ~= panelSize then
			vitals.Size = panelSize
		end
		local cellSize = UDim2.fromScale(0.94, VITALS_ROW * VITALS_ROW_FILL / height)
		local index = 0
		for _, row in vitalRows do
			if row.cell.Visible then
				local y = (VITALS_PAD + VITALS_ROW * index + VITALS_ROW * (1 - VITALS_ROW_FILL) / 2) / height
				local position = UDim2.fromScale(0.03, y)
				if row.cell.Position ~= position then
					row.cell.Position = position
				end
				if row.cell.Size ~= cellSize then
					row.cell.Size = cellSize
				end
				index += 1
			end
		end
	end

	-- Stage 10: suit air (always), fresh food or the food boost, silo ice; plus the low air pill.
	-- Runs on every render and HUD tick (a few times a second): property writes only.
	local function renderVitals()
		local stats = Store.getStats()
		local state = Store.getBase()
		local fieldMode = mode == "shift" or mode == "roam" or mode == "base"
		vitals.Visible = fieldMode and stats ~= nil
		if not fieldMode or stats == nil then
			lowAirBadge.frame.Visible = false
			return
		end
		local now = workspace:GetServerTimeNow()

		-- Suit air: the same zones as the base air meter.
		local suitMax = suitMaxOf(stats)
		local percent = math.clamp(stats.suitO2 / suitMax * 100, 0, 100)
		local zone = Simulation.meterZone(percent, "air", MissionData)
		suitRow.cell.Visible = true
		suitRow.name.Text = Store.t("ui.meter.suit")
		suitRow.bar.set(stats.suitO2 / suitMax, Ui.zoneColor(zone), tostring(math.floor(stats.suitO2 + 0.5)), Ui.ZONE_ICONS[zone])
		Ui.setIcon(suitRow.icon, if stats.inside then Ui.ICONS.home else Ui.ICONS.suit, ROLE.suit)

		-- Low air outside: a small pulsing pill at the bottom (faster in the red zone).
		local lowAir = not stats.inside and zone ~= "green"
		lowAirBadge.frame.Visible = lowAir
		if lowAir then
			lowAirBadge.label.Text = Store.t("ui.low_air")
			local rate = if zone == "red" then 4 else 2
			local pulse = math.floor(os.clock() * rate) % 2 == 0
			lowAirBadge.frame.BackgroundColor3 = if pulse then Ui.COLORS.warning else Ui.COLORS.star
		end

		-- Food: the boost countdown while it runs (any field mode), else fresh greenhouse food
		-- (roaming and base mode, once the greenhouse stands): ready, or seconds until it is.
		local boostValue = player:GetAttribute(FOOD_BOOST_ATTRIBUTE)
		local boostLeft = if type(boostValue) == "number" then boostValue - now else 0
		local greenhouse = state ~= nil and (state.builds.greenhouse or 0) >= 1
		if boostLeft > 0 then
			foodRow.cell.Visible = true
			foodRow.name.Text = Store.t("ui.vitals.boost")
			local fraction = boostLeft / math.max(1, MissionData.BASE.FOOD.BOOST_SECONDS)
			foodRow.bar.set(fraction, ROLE.good, Store.t("ui.vitals.seconds", { seconds = math.ceil(boostLeft) }), nil)
			Ui.setIcon(foodRow.icon, Ui.Icons.run, ROLE.good)
		elseif greenhouse and state and mode ~= "shift" then
			foodRow.cell.Visible = true
			foodRow.name.Text = Store.t("ui.vitals.food")
			Ui.setIcon(foodRow.icon, Ui.ICONS.food, ROLE.food)
			local left = (state.foodReadyAt or 0) - now
			if left <= 0 then
				foodRow.bar.set(1, Ui.zoneColor("green"), Store.t("ui.vitals.ready"), Ui.ZONE_ICONS.green)
			else
				local cooldown = math.max(1, BaseBuild.foodCooldown(MissionData, state.builds))
				local text = Store.t("ui.vitals.seconds", { seconds = math.ceil(left) })
				foodRow.bar.set(1 - left / cooldown, ROLE.food, text, nil)
			end
		else
			foodRow.cell.Visible = false
		end

		-- Silo ice: once an automatic drill stands (roaming and base mode). Gold when full.
		local siloShown = state ~= nil and mode ~= "shift" and state.siloMax > 0 and hasDrill(state.builds)
		siloRow.cell.Visible = siloShown
		if siloShown and state then
			local ice = math.floor(state.siloIce)
			local max = math.floor(state.siloMax)
			siloRow.name.Text = Store.t("ui.vitals.silo")
			local color = if ice >= max then ROLE.star else Ui.COLORS.ice
			-- Stage 11 tycoon client: a friend's silo is shown dimmed (the guest cannot send its ice).
			if not IncomePops.isSiloOwner() then
				color = ROLE.textDim
			end
			siloRow.bar.set(ice / max, color, `{ice}/{max}`, nil)
		end
		layoutVitals()
	end

	local function render()
		local snap = Store.getSnapshot()
		local stats = Store.getStats()
		placeColumn()
		meters.render()
		if snap then
			local event = snap.todayEvent
			eventBanner.set(Ui.EVENT_ICONS[event] or "", Store.t("event." .. event), Ui.EVENT_COLORS[event])
		end
		local shift = if snap then snap.shift else nil
		earthLink.frame.Visible = shift ~= nil
		if shift then
			local linked = shift.antennaLinked
			local background = if linked then ROLE.accent else Ui.COLORS.panel
			local foreground = Ui.contrastText(background)
			earthLink.set(
				Ui.ICONS.antenna,
				Store.t(if linked then "ui.earth_link_on" else "ui.earth_link_off"),
				if linked then foreground else ROLE.textDim
			)
			earthLink.label.TextColor3 = foreground
			earthLink.frame.BackgroundColor3 = background
		end
		local carryingCrate = Store.carryingCrate()
		crateBadge.set(Ui.Icons.crate, Store.t("ui.carrying_parts"), Ui.COLORS.textDark)
		crateBadge.frame.Visible = carryingCrate
		if stats then
			iceBadge.set(Ui.ICONS.ice, Store.t("ui.carrying_ice"), Ui.COLORS.textDark)
			iceBadge.frame.Visible = stats.carryingIce and not carryingCrate
		else
			iceBadge.frame.Visible = false
		end
		renderGear()
		renderVitals()
		renderWallet()
		placeColumn() -- renderWallet skips it before the first BaseState; the vitals may have changed
		placeStack()
	end

	-- Food boost (server time in the player attribute set by the server's ToolService): the vitals
	-- panel's food row shows it at once; the HUD tick keeps the countdown going.
	player:GetAttributeChangedSignal(FOOD_BOOST_ATTRIBUTE):Connect(function()
		renderVitals()
		placeColumn()
		placeStack()
	end)

	-- Stage 8: gear gas tank, gear row and the auto-run pill (tick and render place the stack after).
	function renderGear()
		local gear = if deps then deps.gear else nil
		local ownsAny = false
		if gear then
			local keyboard = UserInputService.KeyboardEnabled
			for _, chip in gearChips do
				local owned = gear.level(chip.id) > 0
				chip.frame.Visible = owned
				if owned then
					ownsAny = true
					local on = gear.isOn(chip.id)
					local color = if on then ROLE.good else ROLE.textDim
					chip.icon.ImageColor3 = color
					chip.key.TextColor3 = color
					chip.key.Visible = keyboard
					chip.icon.Position = UDim2.fromScale(if keyboard then 0.05 else 0.22, 0.5)
					if chip.stroke then
						chip.stroke.Color = if on then ROLE.good else ROLE.stroke
					end
				end
			end
		end
		gasPanel.Visible = ownsAny
		if ownsAny and gear then
			local current, max = gear.gas()
			local fraction = if max > 0 then current / max else 0
			local color = if fraction <= 0.001
				then ROLE.danger
				elseif fraction < GAS_LOW_FRACTION then ROLE.warning
				else ROLE.accent
			gasBar.set(fraction, color, tostring(math.floor(current + 0.5)), nil)
		end
		local autoRunning = deps ~= nil and deps.autoRunning ~= nil and deps.autoRunning()
		autoRunBadge.frame.Visible = autoRunning
		if autoRunning then
			local key = if UserInputService.KeyboardEnabled then "ui.autorun_key" else "ui.autorun"
			autoRunBadge.set(Ui.Icons.autorun, Store.t(key), Ui.COLORS.textDark)
		end
	end

	---------------------------------------------------------------------------------------------
	-- Build-progress signs: a BillboardGui on each pad (Workspace.Base.BuildPads.<id>) with a build
	-- in progress. Local only: every player sees the shared progress from their own BaseState.
	---------------------------------------------------------------------------------------------
	-- The wrench's own icon (MissionData.BASE.TOOLS), the same as in the tool bar and the Lab.
	local WRENCH_IMAGE = Ui.Icons.failure
	for _, tool in MissionData.BASE.TOOLS do
		if tool.id == "wrench" then
			WRENCH_IMAGE = Ui.iconImage(tool.icon)
		end
	end

	type Sign = {
		gui: BillboardGui,
		title: TextLabel,
		step: TextLabel,
		fill: Frame,
		needIcon: ImageLabel,
		need: TextLabel,
	}
	local signs: { [string]: Sign } = {}

	local function findPad(id: string): BasePart?
		local base = workspace:FindFirstChild("Base")
		local pads = if base then base:FindFirstChild("BuildPads") else nil
		local pad = if pads then pads:FindFirstChild(id) else nil
		if pad and pad:IsA("BasePart") then
			return pad
		end
		return nil
	end

	-- Sign text scales with the sign (a BillboardGui sized in pixels, outside the root's UIScale).
	local function looseText(label: TextLabel)
		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then
			constraint.MaxTextSize = 40
			constraint.MinTextSize = 7
		end
	end

	-- Same size on every screen as the rest of the HUD (the root's UIScale), within limits.
	local function signSize(): UDim2
		local scale = math.clamp(Ui.scale(), SIGN_MIN_SCALE, SIGN_MAX_SCALE)
		return UDim2.fromOffset(math.floor(SIGN_PIXELS.X * scale), math.floor(SIGN_PIXELS.Y * scale))
	end

	local function makeSign(id: string, pad: BasePart): Sign
		local gui = Instance.new("BillboardGui")
		gui.Name = "SBO_BuildProgress"
		gui.Size = signSize()
		gui.StudsOffsetWorldSpace = Vector3.new(0, SIGN_HEIGHT, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = SIGN_MAX_DISTANCE
		gui.ResetOnSpawn = false
		gui.Adornee = pad
		local frame = Ui.panel(gui, {
			name = "Panel",
			color = ROLE.panel,
			transparency = 0.08,
			corner = 0.2,
			stroke = 2,
			strokeColor = ROLE.accent,
		})
		local def = BaseBuild.buildDef(MissionData, id)
		Ui.icon(frame, Ui.iconImage(if def then def.icon else "build"), {
			name = "Icon",
			size = UDim2.fromScale(0.12, 0.36),
			position = UDim2.fromScale(0.03, 0.06),
			tint = ROLE.accent,
		})
		local title = Ui.label(frame, {
			name = "Title",
			size = UDim2.fromScale(0.58, 0.34),
			position = UDim2.fromScale(0.16, 0.07),
			alignX = Enum.TextXAlignment.Left,
			textColor = ROLE.text,
		})
		looseText(title)
		local step = Ui.label(frame, {
			name = "Step",
			size = UDim2.fromScale(0.26, 0.3),
			position = UDim2.fromScale(0.97, 0.09),
			anchor = Vector2.new(1, 0),
			alignX = Enum.TextXAlignment.Right,
			textColor = ROLE.good,
		})
		looseText(step)
		local back = Ui.frame(frame, {
			name = "Bar",
			size = UDim2.fromScale(0.94, 0.13),
			position = UDim2.fromScale(0.03, 0.46),
			color = ROLE.background,
			corner = 0.5,
		})
		local fill = Ui.frame(back, {
			name = "Fill",
			size = UDim2.fromScale(0, 1),
			color = ROLE.good,
			corner = 0.5,
		})
		local needIcon = Ui.icon(frame, Ui.Icons.crate, {
			name = "NeedIcon",
			size = UDim2.fromScale(0.12, 0.3),
			position = UDim2.fromScale(0.03, 0.64),
			tint = ROLE.star,
		})
		local need = Ui.body(frame, {
			name = "Need",
			size = UDim2.fromScale(0.8, 0.3),
			position = UDim2.fromScale(0.16, 0.64),
			textColor = ROLE.star,
		})
		looseText(need)
		gui.Parent = pad
		return { gui = gui, title = title, step = step, fill = fill, needIcon = needIcon, need = need }
	end

	local function renderSigns()
		local state = Store.getBase()
		local inProgress: { [string]: Types.BuildProgress } = if state then state.inProgress else {}
		for id, sign in signs do
			if inProgress[id] == nil or sign.gui.Parent == nil then
				sign.gui:Destroy()
				signs[id] = nil
			end
		end
		local carrying = Store.carryingCrate()
		for id, progress in inProgress do
			local sign = signs[id]
			if sign == nil then
				local pad = findPad(id)
				if pad == nil then
					continue -- not there yet (or streamed out): the poll below tries again
				end
				sign = makeSign(id, pad)
				signs[id] = sign
			end
			local current = sign :: Sign
			local size = signSize()
			if current.gui.Size ~= size then
				current.gui.Size = size
			end
			local name = Store.t(`build.{id}.name`)
			current.title.Text = if progress.level > 1 then name .. "  " .. Store.t("ui.level", { n = progress.level }) else name
			current.step.Text = Store.t("ui.build_step", { n = progress.stage, max = progress.stages })
			local fraction = math.clamp(progress.stage / math.max(1, progress.stages), 0, 1)
			current.fill.Size = UDim2.fromScale(fraction, 1)
			current.fill.Visible = fraction > 0.005
			if progress.crate then
				Ui.setIcon(current.needIcon, WRENCH_IMAGE, ROLE.good)
				current.need.Text = Store.t("ui.build_need_assemble")
				current.need.TextColor3 = ROLE.good
			else
				Ui.setIcon(current.needIcon, Ui.Icons.crate, ROLE.star)
				current.need.Text = Store.t(if carrying then "ui.build_need_deliver" else "ui.build_need_crate")
				current.need.TextColor3 = ROLE.star
			end
		end
	end

	local sincePoll = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sincePoll += deltaTime
		if sincePoll < SIGN_POLL_SECONDS then
			return
		end
		sincePoll = 0
		local state = Store.getBase()
		if state == nil then
			return
		end
		for id in state.inProgress do
			local sign = signs[id]
			if sign == nil or sign.gui.Parent == nil then
				renderSigns()
				return
			end
		end
	end)

	local function tick()
		if field.Visible then
			renderGear() -- the gas tank drains and refills on this client
			renderVitals() -- food and boost countdowns, the low air pulse
			placeStack() -- the tool bar comes and goes with the tools
		end
		if wallet.Visible or vitals.Visible then
			placeColumn() -- the objectives panel above can change height
		end
		if not visible then
			return
		end
		placeColumn()
		local snap = Store.getSnapshot()
		local shift = if snap then snap.shift else nil
		if not snap or not shift then
			countdown.frame.Visible = false
			flareSource.frame.Visible = false
			stormNow.frame.Visible = false
			return
		end
		local now = workspace:GetServerTimeNow()
		local secondsLeft = math.max(0, math.ceil(shift.endsAt - now))
		timer.set(Ui.ICONS.timer, Store.t("ui.shift_time", { seconds = secondsLeft }))
		-- Tutorials never end on the clock (the server waits for the objectives): hide a clock at zero.
		timer.frame.Visible = not (Store.missionKind() == "Tutorial" and secondsLeft <= 0)

		-- A "false alarm" flare brings no particles: the warning still shows, the storm never does.
		local particlesExpected = not (snap.spaceWeather and snap.spaceWeather.particles == false)
		local warningAt = shift.stormWarningAt
		local arrivesAt = shift.stormArrivesAt
		local endsAt = shift.stormEndsAt

		local warning = warningAt ~= nil and arrivesAt ~= nil and now >= warningAt and now < arrivesAt
		local storming = particlesExpected
			and arrivesAt ~= nil
			and endsAt ~= nil
			and now >= arrivesAt
			and now < endsAt

		countdown.frame.Visible = warning
		if warning and arrivesAt then
			local seconds = math.max(0, math.ceil(arrivesAt - now))
			countdown.set(Ui.ICONS.warning, Store.t("ui.storm_in", { seconds = seconds }), Ui.COLORS.textDark)
			-- Pulse twice a second to grab attention (text and icon carry the meaning, not the colour).
			local pulse = math.floor(now * 2) % 2 == 0
			countdown.frame.BackgroundColor3 = if pulse then Ui.COLORS.warning else Ui.COLORS.star
		end

		local weather = snap.spaceWeather
		flareSource.frame.Visible = warning and weather ~= nil
		if warning and weather then
			local key = if weather.source == "live" then "ui.flare_source_live" else "ui.flare_source_archive"
			flareSource.set(Ui.ICONS.satellite, Store.t(key, { date = shortDate(weather.flareDate) }))
		end

		stormNow.frame.Visible = storming
		if storming then
			local stats = Store.getStats()
			local sheltered = stats ~= nil and stats.sheltered
			local image = if sheltered then Ui.ICONS.shelter else Ui.ICONS.storm
			-- Stage 10 fix: outside the shelter the banner says the radiation is rising right now (the
			-- radiation meter climbs second by second while anyone stands outside).
			stormNow.set(image, Store.t(if sheltered then "ui.storm_now" else "ui.storm_outside"), ROLE.text)
		end
	end

	local function setMode(value: Mode)
		mode = value
		visible = value == "shift"
		screen.Visible = visible
		field.Visible = value == "shift" or value == "roam" or value == "base"
		render()
		tick()
	end

	local function setVisible(value: boolean)
		setMode(if value then "shift" else "none")
	end

	-- A new BaseState: wallet, the parts pill and the build-progress signs.
	local function renderBase()
		renderWallet()
		local carryingCrate = Store.carryingCrate()
		crateBadge.set(Ui.Icons.crate, Store.t("ui.carrying_parts"), Ui.COLORS.textDark)
		crateBadge.frame.Visible = carryingCrate
		local stats = Store.getStats()
		iceBadge.frame.Visible = stats ~= nil and stats.carryingIce and not carryingCrate
		placeStack()
		renderSigns()
	end

	render()
	return {
		setVisible = setVisible,
		setMode = setMode,
		render = function()
			render()
			renderSigns()
		end,
		renderWallet = renderWallet,
		renderBase = renderBase,
		tick = tick,
	}
end

-- Top bar -----------------------------------------------------------------------------------------

export type TopBarDeps = {
	openWardrobe: (() -> ())?, -- nil when the Wardrobe failed to load: its buttons stay hidden
	openMissions: () -> (),
	-- Stage 10: the learning achievements panel (nil when it failed to load: no button).
	openAchievements: (() -> ())?,
}

export type TopBarView = {
	setMode: (mode: Mode) -> (),
	render: () -> (),
}

function Hud.newTopBar(root: Frame, deps: TopBarDeps): TopBarView
	local Z = 52 -- above the C.A.R.L. bubble (50), under the Lab and Wardrobe panels (53) and Settings (60+)
	local BUTTON_HEIGHT = 0.08 -- same height as the Settings button
	local SQUARE_HEIGHT = 0.07

	local function row(name: string, size: UDim2, position: UDim2): Frame
		local frame = Ui.frame(root, {
			name = name,
			size = size,
			position = position,
			anchor = Vector2.new(1, 0),
			zindex = Z,
			visible = false,
		})
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0.02, 0)
		layout.Parent = frame
		return frame
	end

	local function call(callback: (() -> ())?): () -> ()
		return function()
			if callback then
				callback()
			end
		end
	end

	-- Full bar (base mode): Missions | Wardrobe | Achievements, left of the Settings button. Stage 10:
	-- three buttons of the same width as before (the bar grows to the left).
	local hasAchievements = deps.openAchievements ~= nil
	local fullWidth = if hasAchievements then 0.375 else 0.25
	local buttonWidth = if hasAchievements then 0.32 else 0.48
	local full = row("TopBar", UDim2.fromScale(fullWidth, BUTTON_HEIGHT), UDim2.fromScale(0.805, 0.02))
	local function fullButton(name: string, order: number, image: string, primary: boolean, onClick: () -> ()): TextButton
		return Ui.button(full, {
			name = name,
			size = UDim2.fromScale(buttonWidth, 1),
			order = order,
			color = if primary then ROLE.primaryButton else Ui.COLORS.secondary,
			strokeColor = if primary then ROLE.stroke else ROLE.accent,
			icon = image,
			tint = if primary then nil else ROLE.accent,
			maxText = 24,
			zindex = Z + 1,
		}, onClick)
	end
	local missionsButton = fullButton("MissionsButton", 1, Ui.Icons.target, true, deps.openMissions)
	local wardrobeButton = fullButton("WardrobeButton", 2, Ui.Icons.wardrobe, false, call(deps.openWardrobe))
	local achievementsButton = fullButton("AchievementsButton", 3, Ui.Icons.trophy, false, call(deps.openAchievements))
	achievementsButton.Visible = false

	-- Compact square (other screens): Wardrobe, icon only, at the right edge.
	local compact = row("TopBarCompact", UDim2.fromScale(0.1, SQUARE_HEIGHT), UDim2.fromScale(0.985, 0.115))
	local function square(name: string, order: number, image: string, onClick: () -> ()): TextButton
		return Ui.button(compact, {
			name = name,
			size = UDim2.fromScale(1, 1),
			order = order,
			color = Ui.COLORS.secondary,
			strokeColor = ROLE.accent,
			icon = image,
			tint = ROLE.accent,
			aspect = 1,
			zindex = Z + 1,
		}, onClick)
	end
	local wardrobeSquare = square("WardrobeSquare", 1, Ui.Icons.wardrobe, call(deps.openWardrobe))

	-- Base mode hint for players whose base is not finished yet (pulsing orange border).
	local hint = Ui.iconText(root, {
		name = "BaseHint",
		size = UDim2.fromScale(0.4, 0.06),
		position = UDim2.fromScale(0.5, 0.115),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.panel,
		transparency = 0.1,
		stroke = 2,
		strokeColor = ROLE.warning,
		icon = Ui.Icons.build,
		tint = ROLE.warning,
		maxText = 24,
		zindex = 12,
		visible = false,
	})
	hint.icon.Size = UDim2.fromScale(0.08, 0.8)
	hint.icon.Position = UDim2.fromScale(0.03, 0.5)
	hint.label.Size = UDim2.fromScale(0.86, 0.84)
	hint.label.Position = UDim2.fromScale(0.12, 0.5)
	local hintStroke = hint.frame:FindFirstChildOfClass("UIStroke")

	local mode: Mode = "none"
	local pulseConnection: RBXScriptConnection? = nil

	local function render()
		Ui.setButton(missionsButton, Store.t("ui.top_missions"))
		Ui.setButton(wardrobeButton, Store.t("ui.top_wardrobe"))
		Ui.setButton(achievementsButton, Store.t("ui.top_achievements"))
		hint.label.Text = Store.t("ui.base_hint")
		local hasState = Store.getBase() ~= nil
		local hasWardrobe = deps.openWardrobe ~= nil and hasState
		wardrobeButton.Visible = hasWardrobe
		achievementsButton.Visible = hasAchievements and hasState
		wardrobeSquare.Visible = hasWardrobe

		full.Visible = mode == "base"
		compact.Visible = hasWardrobe and (mode == "shift" or mode == "roam" or mode == "select" or mode == "board")
		local y = if mode == "shift" or mode == "board" then 0.195 else 0.115
		compact.Position = UDim2.fromScale(0.985, y)

		-- Stage 8 (team feedback): once the habitat and the solar panels stand, the player knows the
		-- way (C.A.R.L. and the tips lead on), so the hint goes away.
		local firstBuilds = Store.buildLevel("habitat") >= 1 and Store.buildLevel("solar") >= 1
		-- Stage 9: the quest tracker already says what to build, so the hint waits for an older server.
		local questShown = Objectives.currentQuest() ~= nil
		local showHint = mode == "base" and hasState and not Store.coreBuilt() and not firstBuilds and not questShown
		hint.frame.Visible = showHint
		if showHint and pulseConnection == nil then
			pulseConnection = RunService.Heartbeat:Connect(function()
				if hintStroke then
					hintStroke.Thickness = 2 + 2 * (math.sin(os.clock() * 4) + 1) / 2
				end
			end)
		elseif not showHint and pulseConnection then
			pulseConnection:Disconnect()
			pulseConnection = nil
		end
	end

	local function setMode(value: Mode)
		mode = value
		render()
	end

	Objectives.onQuestChanged(render)
	render()
	return { setMode = setMode, render = render }
end

return Hud
