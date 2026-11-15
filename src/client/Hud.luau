--!strict
-- Space Base Odyssey - in-game HUD.
--   Shift screen: meters, shift timer, event banner, storm countdown (with the flare's data source),
--   Earth-link indicator.
--   Field (shift and while roaming the base): suit air bar (out of PlayerStats.suitMax) and ice.
--   Wallet (Stage 6: shift, roaming, base mode and mission select): credits, player level and an XP
--   bar, with a "+N" pop when credits rise.
--   Stage 7 (field): a "Carrying parts" pill while the player carries a parts crate from the lander,
--   a food boost timer while player attribute SBO_FoodBoostUntil (server time) is in the future, and a
--   small build-progress sign (a local BillboardGui) over every build pad with a build in progress
--   (BaseState.inProgress): step x/y and what is needed next (a crate, or Assemble with the wrench).
--   Top bar (Hud.newTopBar): Missions and Wardrobe buttons beside the Settings button, and the "Build
--   your base" hint pill in base mode. Stage 7: no Base button (team feedback: building from a menu
--   let players upgrade everything while standing still; builds happen at the pads in the world).
-- Screen layout (fractions of the screen):
--   top centre   y 0.02-0.09  shift timer 0.25-0.49 | today's event 0.51-0.75
--   top right    y 0.02-0.10  settings button 0.815-0.985 (Settings.luau); y 0.115-0.18 Earth link
--                base mode:  Missions | Wardrobe buttons 0.555-0.805, y 0.02-0.10;
--                            hint pill 0.3-0.7, y 0.115-0.175
--                elsewhere:  an icon-only Wardrobe square at the right edge, under the settings
--                            button (y 0.115: mission select, roaming) or under the Earth link or
--                            sources button (y 0.195: shift, power board)
--   left column  x 0.01-0.21  objectives (Objectives.luau, from y 0.10-0.12), then the meters panel
--                             right under it (air, food, radiation, water, data waiting), then the
--                             wallet (at y 0.105 when nothing is above it)
--   centre       y 0.10-0.25  C.A.R.L. bubble (Messages.luau, x 0.29-0.71)
--                y 0.27-0.48  storm countdown and flare source (x 0.22-0.78)
--   bottom       y 0.68-0.74  food boost; y 0.76-0.84  carrying ice or parts; y 0.86-0.96 suit air
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Types = require(Shared:WaitForChild("Types"))

local Meters = require(script.Parent.Meters)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

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
local WALLET_HEIGHT = 0.09
local POP_SECONDS = 0.9
local FOOD_BOOST_ATTRIBUTE = "SBO_FoodBoostUntil"
-- Build-progress signs over the pads (studs).
local SIGN_SIZE = UDim2.fromScale(13, 4.2)
local SIGN_HEIGHT = 9
local SIGN_MAX_DISTANCE = 220
local SIGN_POLL_SECONDS = 1 -- look again for pads that were not there yet

-- What the HUD shows (Main.client picks it from the phase and the open screens):
--   "shift"  work time: everything.   "roam"  planning with the power board closed (walk tasks).
--   "base"   base mode (Briefing with the mission select closed).   "select"  mission select open.
--   "board"  planning with the power board open.   "none"  report.
export type Mode = "shift" | "roam" | "base" | "select" | "board" | "none"

export type Deps = {
	-- Bottom edge (screen fraction) of the objectives panel, or nil while it is hidden.
	columnTop: (() -> number?)?,
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

function Hud.new(root: Frame, deps: Deps?): HudView
	local screen = Ui.frame(root, { name = "Hud", zindex = 5, visible = false })
	-- Suit air and carried ice: shown at work and while roaming the base.
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
		size = UDim2.fromScale(0.28, 0.08),
		position = UDim2.fromScale(0.5, 0.76),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.ice,
		stroke = 3,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.ICONS.ice,
		maxText = 32,
		visible = false,
	})

	-- Stage 7: a parts crate carried from the lander to a build pad (same place as the ice: one at a time).
	local crateBadge = Ui.iconText(field, {
		name = "CarryingCrate",
		size = UDim2.fromScale(0.28, 0.08),
		position = UDim2.fromScale(0.5, 0.76),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.star,
		stroke = 3,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.Icons.crate,
		maxText = 32,
		visible = false,
	})

	-- Stage 7: greenhouse food eaten: a short speed boost with a countdown.
	local foodBadge = Ui.iconText(field, {
		name = "FoodBoost",
		size = UDim2.fromScale(0.22, 0.06),
		position = UDim2.fromScale(0.5, 0.68),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.good,
		stroke = 3,
		strokeColor = ROLE.background,
		textColor = Ui.COLORS.textDark,
		icon = Ui.ICONS.food,
		maxText = 26,
		visible = false,
	})

	local suitPanel = Ui.panel(field, {
		name = "Suit",
		size = UDim2.fromScale(0.46, 0.1),
		position = UDim2.fromScale(0.5, 0.86),
		anchor = Vector2.new(0.5, 0),
		transparency = 0.1,
		corner = 0.3,
		visible = false,
	})
	local suitIcon = Ui.icon(suitPanel, Ui.ICONS.suit, {
		size = UDim2.fromScale(0.11, 0.7),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.suit,
	})
	local suitName = Ui.label(suitPanel, {
		name = "Name",
		size = UDim2.fromScale(0.3, 0.8),
		position = UDim2.fromScale(0.15, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		maxText = 28,
	})
	local suitBar = Ui.bar(suitPanel, {
		name = "Bar",
		size = UDim2.fromScale(0.52, 0.66),
		position = UDim2.fromScale(0.46, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 28,
	})

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
		size = UDim2.fromScale(0.13, 0.42),
		position = UDim2.fromScale(0.03, 0.28),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.star,
		zindex = 16,
	})
	local creditsText = Ui.label(wallet, {
		name = "Credits",
		size = UDim2.fromScale(0.4, 0.44),
		position = UDim2.fromScale(0.17, 0.28),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 24,
		minText = 8,
		zindex = 16,
	})
	local levelPill = Ui.label(wallet, {
		name = "Level",
		size = UDim2.fromScale(0.4, 0.4),
		position = UDim2.fromScale(0.97, 0.28),
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
		size = UDim2.fromScale(0.13, 0.38),
		position = UDim2.fromScale(0.03, 0.73),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.reward,
		zindex = 16,
	})
	local xpBar = Ui.bar(wallet, {
		name = "XpBar",
		size = UDim2.fromScale(0.8, 0.34),
		position = UDim2.fromScale(0.17, 0.73),
		anchor = Vector2.new(0, 0.5),
		maxText = 14,
		zindex = 16,
	})
	xpBar.label.Size = UDim2.fromScale(0.9, 0.9)

	local visible = false
	local mode: Mode = "none"
	local columnTop = COLUMN_TOP
	local walletTop = WALLET_TOP
	local shownCredits: number? = nil
	local shownLevel: number? = nil

	-- Keep the meters panel right under the objectives panel (its height changes with the mission).
	-- The wallet follows the meters (shift) or the objectives (roaming), else it sits at the top.
	local function placeColumn()
		local bottom = if deps and deps.columnTop then deps.columnTop() else nil
		local top = if bottom then bottom + COLUMN_GAP else COLUMN_TOP
		if math.abs(top - columnTop) > 0.0005 then
			columnTop = top
			meters.frame.Position = UDim2.fromScale(COLUMN_X, top)
		end
		local below: number? = if mode == "shift" then columnTop + METERS_HEIGHT else bottom
		local nextWalletTop = if below then below + COLUMN_GAP else WALLET_TOP
		if math.abs(nextWalletTop - walletTop) > 0.0005 then
			walletTop = nextWalletTop
			wallet.Position = UDim2.fromScale(COLUMN_X, walletTop)
		end
	end
	meters.frame.Position = UDim2.fromScale(COLUMN_X, COLUMN_TOP)

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
		if shownCredits ~= nil and credits > (shownCredits :: number) and wallet.Visible then
			popCredits(credits - (shownCredits :: number))
		end
		shownCredits = credits
		levelPill.Text = Store.t("ui.level", { n = state.level })
		if shownLevel ~= nil and state.level > (shownLevel :: number) and wallet.Visible then
			popLevel()
		end
		shownLevel = state.level
		local nextXp = state.nextLevelXp
		if nextXp ~= nil and nextXp > state.levelXp then
			local into = math.max(0, state.xp - state.levelXp)
			local span = nextXp - state.levelXp
			xpBar.set(into / span, ROLE.reward, `{math.floor(state.xp)}/{math.floor(nextXp)}`, nil)
		else
			xpBar.set(1, ROLE.reward, tostring(math.floor(state.xp)), nil) -- top level
		end
		placeColumn()
	end

	local function render()
		local snap = Store.getSnapshot()
		local stats = Store.getStats()
		placeColumn()
		meters.render()
		suitName.Text = Store.t("ui.meter.suit")
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
			local suitMax = suitMaxOf(stats)
			iceBadge.set(Ui.ICONS.ice, Store.t("ui.carrying_ice"), Ui.COLORS.textDark)
			iceBadge.frame.Visible = stats.carryingIce and not carryingCrate

			local suitShown = (not stats.inside) or stats.suitO2 < suitMax
			suitPanel.Visible = suitShown
			local percent = math.clamp(stats.suitO2 / suitMax * 100, 0, 100)
			local zone = Simulation.meterZone(percent, "air", MissionData)
			local shown = math.floor(stats.suitO2 + 0.5)
			suitBar.set(stats.suitO2 / suitMax, Ui.zoneColor(zone), tostring(shown), Ui.ZONE_ICONS[zone])
			Ui.setIcon(suitIcon, if stats.inside then Ui.ICONS.home else Ui.ICONS.suit)
		else
			iceBadge.frame.Visible = false
			suitPanel.Visible = false
		end
		renderWallet()
	end

	-- Food boost countdown (server time from the player attribute set by the server's ToolService).
	local player = game:GetService("Players").LocalPlayer
	local function renderFood()
		local value = player:GetAttribute(FOOD_BOOST_ATTRIBUTE)
		local left = if type(value) == "number" then value - workspace:GetServerTimeNow() else 0
		local boosted = left > 0
		foodBadge.frame.Visible = boosted
		if boosted then
			foodBadge.set(Ui.ICONS.food, Store.t("ui.food_boost", { seconds = math.ceil(left) }), Ui.COLORS.textDark)
		end
	end
	player:GetAttributeChangedSignal(FOOD_BOOST_ATTRIBUTE):Connect(renderFood)

	---------------------------------------------------------------------------------------------
	-- Build-progress signs: a BillboardGui on each pad (Workspace.Base.BuildPads.<id>) with a build
	-- in progress. Local only: every player sees the shared progress from their own BaseState.
	---------------------------------------------------------------------------------------------
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

	-- Sign text scales with the sign (a BillboardGui sized in studs), not with the screen.
	local function looseText(label: TextLabel)
		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then
			constraint.MaxTextSize = 60
			constraint.MinTextSize = 6
		end
	end

	local function makeSign(id: string, pad: BasePart): Sign
		local gui = Instance.new("BillboardGui")
		gui.Name = "SBO_BuildProgress"
		gui.Size = SIGN_SIZE
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
			stroke = 3,
			strokeColor = ROLE.accent,
		})
		local def = BaseBuild.buildDef(MissionData, id)
		Ui.icon(frame, Ui.iconImage(if def then def.icon else "build"), {
			name = "Icon",
			size = UDim2.fromScale(0.13, 0.36),
			position = UDim2.fromScale(0.03, 0.06),
			tint = ROLE.accent,
		})
		local title = Ui.label(frame, {
			name = "Title",
			size = UDim2.fromScale(0.56, 0.34),
			position = UDim2.fromScale(0.17, 0.07),
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
			size = UDim2.fromScale(0.1, 0.28),
			position = UDim2.fromScale(0.03, 0.66),
			tint = ROLE.star,
		})
		local need = Ui.body(frame, {
			name = "Need",
			size = UDim2.fromScale(0.82, 0.28),
			position = UDim2.fromScale(0.15, 0.66),
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
			local name = Store.t(`build.{id}.name`)
			current.title.Text = if progress.level > 1 then name .. "  " .. Store.t("ui.level", { n = progress.level }) else name
			current.step.Text = Store.t("ui.build_step", { n = progress.stage, max = progress.stages })
			local fraction = math.clamp(progress.stage / math.max(1, progress.stages), 0, 1)
			current.fill.Size = UDim2.fromScale(fraction, 1)
			current.fill.Visible = fraction > 0.005
			if progress.crate then
				Ui.setIcon(current.needIcon, Ui.Icons.failure, ROLE.good) -- the wrench
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
			renderFood()
		end
		if wallet.Visible then
			placeColumn() -- the objectives panel above the wallet can change height
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
			local image = if stats and stats.sheltered then Ui.ICONS.shelter else Ui.ICONS.storm
			stormNow.set(image, Store.t("ui.storm_now"), ROLE.text)
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

	-- Full bar (base mode): Missions | Wardrobe, left of the Settings button.
	local full = row("TopBar", UDim2.fromScale(0.25, BUTTON_HEIGHT), UDim2.fromScale(0.805, 0.02))
	local function fullButton(name: string, order: number, image: string, primary: boolean, onClick: () -> ()): TextButton
		return Ui.button(full, {
			name = name,
			size = UDim2.fromScale(0.48, 1),
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
		hint.label.Text = Store.t("ui.base_hint")
		local hasState = Store.getBase() ~= nil
		local hasWardrobe = deps.openWardrobe ~= nil and hasState
		wardrobeButton.Visible = hasWardrobe
		wardrobeSquare.Visible = hasWardrobe

		full.Visible = mode == "base"
		compact.Visible = hasWardrobe and (mode == "shift" or mode == "roam" or mode == "select" or mode == "board")
		local y = if mode == "shift" or mode == "board" then 0.195 else 0.115
		compact.Position = UDim2.fromScale(0.985, y)

		local showHint = mode == "base" and hasState and not Store.coreBuilt()
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

	render()
	return { setMode = setMode, render = render }
end

return Hud
