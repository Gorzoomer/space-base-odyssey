--!strict
-- Space Base Odyssey - Shift HUD: meters, shift timer, event banner, storm countdown, suit oxygen and ice.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Meters = require(script.Parent.Meters)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local Hud = {}

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
