--!strict
-- Space Base Odyssey - Shift HUD: meters, shift timer, event banner, storm countdown (with the flare's
-- data source), Earth-link indicator, suit oxygen and ice.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Meters = require(script.Parent.Meters)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local Hud = {}

local EARTH_LINK_ICON = "📡"
local FLARE_SOURCE_ICON = "🛰️"

-- "2024-05-10T06:54Z" -> "2024-05-10".
local function shortDate(value: string): string
	if string.match(value, "^%d%d%d%d%-%d%d%-%d%d") then
		return string.sub(value, 1, 10)
	end
	return value
end

export type HudView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
	tick: () -> (), -- call often (timers and storm countdown use server time)
}

function Hud.new(root: Frame): HudView
	local suitMax: number = MissionData.SUIT.MAX

	local screen = Ui.frame(root, { name = "Hud", zindex = 5, visible = false })

	local meters = Meters.new(screen, {
		size = UDim2.fromScale(0.56, 0.1),
		position = UDim2.fromScale(0.22, 0.02),
	})
	local timer = Ui.iconText(screen, {
		name = "Timer",
		size = UDim2.fromScale(0.27, 0.07),
		position = UDim2.fromScale(0.22, 0.13),
		color = Ui.COLORS.panel,
		transparency = 0.15,
		stroke = 2,
		maxText = 30,
	})
	local eventBanner = Ui.iconText(screen, {
		name = "Event",
		size = UDim2.fromScale(0.27, 0.07),
		position = UDim2.fromScale(0.51, 0.13),
		color = Ui.COLORS.panelLight,
		transparency = 0.15,
		stroke = 2,
		maxText = 30,
	})

	-- Storm warning (countdown) and "storm now" share the centre of the screen.
	local countdown = Ui.iconText(screen, {
		name = "StormCountdown",
		size = UDim2.fromScale(0.62, 0.17),
		position = UDim2.fromScale(0.5, 0.26),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.warning,
		stroke = 5,
		textColor = Ui.COLORS.textDark,
		maxText = 64,
		visible = false,
	})
	-- Under the countdown: says honestly whether the flare is live NASA data or an archive replay.
	-- Ends at y 0.49, above the C.A.R.L. bubble (y 0.5) and clear of the Run button (x >= 0.77).
	local flareSource = Ui.iconText(screen, {
		name = "FlareSource",
		size = UDim2.fromScale(0.44, 0.05),
		position = UDim2.fromScale(0.5, 0.44),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.panel,
		transparency = 0.1,
		stroke = 2,
		maxText = 24,
		visible = false,
	})
	-- A wide, short pill: keep the icon narrow so the text gets the room.
	flareSource.icon.Size = UDim2.fromScale(0.08, 0.86)
	flareSource.icon.Position = UDim2.fromScale(0.02, 0.5)
	flareSource.label.Size = UDim2.fromScale(0.88, 0.86)
	flareSource.label.Position = UDim2.fromScale(0.11, 0.5)

	-- Right edge, under the language button and clear of the meters (which end at x 0.78).
	local earthLink = Ui.iconText(screen, {
		name = "EarthLink",
		size = UDim2.fromScale(0.17, 0.065),
		position = UDim2.fromScale(0.985, 0.115),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.panel,
		transparency = 0.15,
		stroke = 2,
		maxText = 22,
		visible = false,
	})

	local stormNow = Ui.iconText(screen, {
		name = "StormNow",
		size = UDim2.fromScale(0.5, 0.14),
		position = UDim2.fromScale(0.5, 0.26),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.storm,
		stroke = 5,
		strokeColor = Color3.fromRGB(255, 255, 255),
		maxText = 56,
		outline = true,
		visible = false,
	})

	local iceBadge = Ui.iconText(screen, {
		name = "CarryingIce",
		size = UDim2.fromScale(0.28, 0.08),
		position = UDim2.fromScale(0.5, 0.76),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.ice,
		stroke = 3,
		textColor = Ui.COLORS.textDark,
		maxText = 32,
		visible = false,
	})

	local suitPanel = Ui.frame(screen, {
		name = "Suit",
		size = UDim2.fromScale(0.46, 0.1),
		position = UDim2.fromScale(0.5, 0.86),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.panel,
		transparency = 0.1,
		corner = 0.3,
		stroke = 3,
		visible = false,
	})
	local suitIcon = Ui.icon(suitPanel, Ui.ICONS.suit, {
		size = UDim2.fromScale(0.13, 0.86),
		position = UDim2.fromScale(0.02, 0.5),
		anchor = Vector2.new(0, 0.5),
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

	local visible = false

	local function render()
		local snap = Store.getSnapshot()
		local stats = Store.getStats()
		meters.render()
		suitName.Text = Store.t("ui.meter.suit")
		if snap then
			eventBanner.set(Ui.EVENT_ICONS[snap.todayEvent] or "", Store.t("event." .. snap.todayEvent))
		end
		local shift = if snap then snap.shift else nil
		earthLink.frame.Visible = shift ~= nil
		if shift then
			local linked = shift.antennaLinked
			earthLink.set(EARTH_LINK_ICON, Store.t(if linked then "ui.earth_link_on" else "ui.earth_link_off"))
			earthLink.frame.BackgroundColor3 = if linked then Ui.COLORS.go else Ui.COLORS.panel
		end
		if stats then
			iceBadge.set(Ui.ICONS.ice, Store.t("ui.carrying_ice"))
			iceBadge.frame.Visible = stats.carryingIce

			local suitShown = (not stats.inside) or stats.suitO2 < suitMax
			suitPanel.Visible = suitShown
			local percent = math.clamp(stats.suitO2 / suitMax * 100, 0, 100)
			local zone = Simulation.meterZone(percent, "air", MissionData)
			local shown = math.floor(stats.suitO2 + 0.5)
			suitBar.set(stats.suitO2 / suitMax, Ui.zoneColor(zone), `{shown} {Ui.ZONE_ICONS[zone]}`)
			suitIcon.Text = if stats.inside then Ui.ICONS.shelter else Ui.ICONS.suit
		else
			iceBadge.frame.Visible = false
			suitPanel.Visible = false
		end
	end

	local function tick()
		if not visible then
			return
		end
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
			countdown.set(Ui.ICONS.warning, Store.t("ui.storm_in", { seconds = seconds }))
			-- Pulse twice a second to grab attention (text and icon carry the meaning, not the colour).
			local pulse = math.floor(now * 2) % 2 == 0
			countdown.frame.BackgroundColor3 = if pulse then Ui.COLORS.warning else Ui.COLORS.accent
		end

		local weather = snap.spaceWeather
		flareSource.frame.Visible = warning and weather ~= nil
		if warning and weather then
			local key = if weather.source == "live" then "ui.flare_source_live" else "ui.flare_source_archive"
			flareSource.set(FLARE_SOURCE_ICON, Store.t(key, { date = shortDate(weather.flareDate) }))
		end

		stormNow.frame.Visible = storming
		if storming then
			local stats = Store.getStats()
			local glyph = if stats and stats.sheltered then Ui.ICONS.shelter else Ui.ICONS.storm
			stormNow.set(glyph, Store.t("ui.storm_now"))
		end
	end

	local function setVisible(value: boolean)
		visible = value
		screen.Visible = value
		if value then
			render()
			tick()
		end
	end

	render()
	return { setVisible = setVisible, render = render, tick = tick }
end

return Hud
