--!strict
-- Space Base Odyssey - title screen: game name, one-line pitch and a big Start button.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local PRESS_COOLDOWN = 1

local Briefing = {}

export type BriefingView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
}

function Briefing.new(root: Frame): BriefingView
	local screen = Ui.frame(root, {
		name = "Briefing",
		color = Ui.COLORS.backdrop,
		transparency = 0.08,
		zindex = 10,
		visible = false,
	})
	screen.ClipsDescendants = true

	-- Decoration made of plain circles: the grey Moon horizon and a small blue Earth.
	Ui.frame(screen, {
		name = "MoonHorizon",
		size = UDim2.fromScale(1.6, 0.9),
		position = UDim2.fromScale(0.5, 1.25),
		anchor = Vector2.new(0.5, 0.5),
		color = Color3.fromRGB(120, 122, 130),
		corner = 0.5,
		zindex = 10,
	})
	local earth = Ui.frame(screen, {
		name = "Earth",
		size = UDim2.fromScale(0.13, 0.13),
		position = UDim2.fromScale(0.84, 0.2),
		anchor = Vector2.new(0.5, 0.5),
		color = Color3.fromRGB(70, 140, 235),
		corner = 0.5,
		aspect = 1,
		zindex = 10,
	})
	Ui.frame(earth, {
		name = "Cloud",
		size = UDim2.fromScale(0.5, 0.22),
		position = UDim2.fromScale(0.3, 0.35),
		anchor = Vector2.new(0.5, 0.5),
		color = Color3.fromRGB(240, 248, 255),
		corner = 0.5,
		zindex = 11,
	})

	local title = Ui.label(screen, {
		name = "Title",
		size = UDim2.fromScale(0.8, 0.2),
		position = UDim2.fromScale(0.5, 0.2),
		anchor = Vector2.new(0.5, 0),
		textColor = Ui.COLORS.accent,
		maxText = 96,
		outline = true,
		zindex = 12,
	})
	local pitch = Ui.label(screen, {
		name = "Pitch",
		size = UDim2.fromScale(0.75, 0.12),
		position = UDim2.fromScale(0.5, 0.42),
		anchor = Vector2.new(0.5, 0),
		maxText = 40,
		outline = true,
		zindex = 12,
	})

	local lastPress = 0
	local start = Ui.button(screen, {
		name = "Start",
		size = UDim2.fromScale(0.42, 0.17),
		position = UDim2.fromScale(0.5, 0.62),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.go,
		stroke = 4,
		maxText = 56,
		zindex = 12,
	}, function()
		if Store.phase() ~= "Briefing" or os.clock() - lastPress < PRESS_COOLDOWN then
			return
		end
		lastPress = os.clock()
		Store.send({ type = "StartMission" })
	end)

	local function render()
		title.Text = `{Ui.ICONS.moon} {Store.t("ui.title")}`
		pitch.Text = Store.t("ui.pitch")
		start.Text = `{Ui.ICONS.rocket} {Store.t("ui.start_mission")}`
	end

	local function setVisible(visible: boolean)
		screen.Visible = visible
	end

	render()
	return { setVisible = setVisible, render = render }
end

return Briefing
