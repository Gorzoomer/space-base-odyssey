--!strict
-- Space Base Odyssey - in-game HUD.
--   Shift screen: meters, shift timer, event banner, storm countdown (with the flare's data source),
--   Earth-link indicator.
--   Field (shift and while roaming the base): suit air bar (out of PlayerStats.suitMax) and ice.
--   Wallet (Stage 6: shift, roaming, base mode and mission select): credits, player level and an XP
--   bar, with a "+N" pop when credits rise.
--   Top bar (Stage 6, Hud.newTopBar): Base, Wardrobe and Missions buttons beside the Settings button,
--   and the "Build your base" hint pill in base mode.
-- Screen layout (fractions of the screen):
--   top centre   y 0.02-0.09  shift timer 0.25-0.49 | today's event 0.51-0.75
--   top right    y 0.02-0.10  settings button 0.815-0.985 (Settings.luau); y 0.115-0.18 Earth link
--                base mode:  Missions | Wardrobe | Base buttons 0.43-0.805, y 0.02-0.10;
--                            hint pill 0.3-0.7, y 0.115-0.175
--                elsewhere:  icon-only Wardrobe | Base squares at the right edge, under the settings
--                            button (y 0.115: mission select, roaming) or under the Earth link or
--                            sources button (y 0.195: shift, power board)
--   left column  x 0.01-0.21  objectives (Objectives.luau, from y 0.10-0.12), then the meters panel
--                             right under it (air, food, radiation, water, data waiting), then the
--                             wallet (at y 0.105 when nothing is above it)
--   centre       y 0.10-0.25  C.A.R.L. bubble (Messages.luau, x 0.29-0.71)
--                y 0.27-0.48  storm countdown and flare source (x 0.22-0.78)
--   bottom       y 0.76-0.84  carrying ice; y 0.86-0.96 suit air
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

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
		if stats then
			local suitMax = suitMaxOf(stats)
			iceBadge.set(Ui.ICONS.ice, Store.t("ui.carrying_ice"), Ui.COLORS.textDark)
			iceBadge.frame.Visible = stats.carryingIce

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

	local function tick()
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

	render()
	return {
		setVisible = setVisible,
		setMode = setMode,
		render = render,
		renderWallet = renderWallet,
		tick = tick,
	}
end

-- Top bar -----------------------------------------------------------------------------------------

export type TopBarDeps = {
	openBase: (() -> ())?, -- nil when the Base panel failed to load: its buttons stay hidden
	openWardrobe: (() -> ())?,
	openMissions: () -> (),
}

export type TopBarView = {
	setMode: (mode: Mode) -> (),
	render: () -> (),
}

-- True when this player can do something in the Base panel right now (a build, upgrade or skill).
local function hasSomethingToDo(): boolean
	local state = Store.getBase()
	if state == nil then
		return false
	end
	if state.skillPoints > 0 then
		for _, def in MissionData.BASE.SKILLS do
			if BaseBuild.canLearn(MissionData, state.skills, state.level, def.id) then
				return true
			end
		end
	end
	for _, def in MissionData.BASE.BUILDS do
		if BaseBuild.canBuild(MissionData, state.builds, state.level, state.credits, def.id) then
			return true
		end
	end
	return false
end

function Hud.newTopBar(root: Frame, deps: TopBarDeps): TopBarView
	local Z = 52 -- above the C.A.R.L. bubble (50), under the Base and Wardrobe panels (53) and Settings (60+)
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

	-- A small gold dot on the Base buttons: something can be built or learned right now.
	local function dot(button: TextButton): Frame
		return Ui.frame(button, {
			name = "Dot",
			size = UDim2.fromScale(0.3, 0.3),
			position = UDim2.fromScale(1.04, -0.08),
			anchor = Vector2.new(1, 0),
			color = ROLE.star,
			corner = 0.5,
			stroke = 2,
			strokeColor = ROLE.background,
			aspect = 1,
			zindex = Z + 2,
			visible = false,
		})
	end

	local function call(callback: (() -> ())?): () -> ()
		return function()
			if callback then
				callback()
			end
		end
	end

	-- Full bar (base mode): Missions | Wardrobe | Base, left of the Settings button.
	local full = row("TopBar", UDim2.fromScale(0.375, BUTTON_HEIGHT), UDim2.fromScale(0.805, 0.02))
	local function fullButton(name: string, order: number, image: string, primary: boolean, onClick: () -> ()): TextButton
		return Ui.button(full, {
			name = name,
			size = UDim2.fromScale(0.32, 1),
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
	local baseButton = fullButton("BaseButton", 3, Ui.Icons.build, false, call(deps.openBase))
	local baseDot = dot(baseButton)

	-- Compact squares (other screens): Wardrobe | Base, icon only, at the right edge.
	local compact = row("TopBarCompact", UDim2.fromScale(0.2, SQUARE_HEIGHT), UDim2.fromScale(0.985, 0.115))
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
	local baseSquare = square("BaseSquare", 2, Ui.Icons.build, call(deps.openBase))
	local squareDot = dot(baseSquare)

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
		Ui.setButton(baseButton, Store.t("ui.top_base"))
		hint.label.Text = Store.t("ui.base_hint")
		local hasState = Store.getBase() ~= nil
		local hasBase = deps.openBase ~= nil and hasState
		local hasWardrobe = deps.openWardrobe ~= nil and hasState
		baseButton.Visible = hasBase
		wardrobeButton.Visible = hasWardrobe
		baseSquare.Visible = hasBase
		wardrobeSquare.Visible = hasWardrobe
		local todo = hasBase and hasSomethingToDo()
		baseDot.Visible = todo
		squareDot.Visible = todo

		full.Visible = mode == "base"
		compact.Visible = mode == "shift" or mode == "roam" or mode == "select" or mode == "board"
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
