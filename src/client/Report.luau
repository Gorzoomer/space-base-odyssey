--!strict
-- Space Base Odyssey - end-of-mission report: outcome, stars, day-by-day timeline of causes, Restart button.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local MAX_STARS = 3
local PRESS_COOLDOWN = 1

local Report = {}

export type ReportView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
}

function Report.new(root: Frame): ReportView
	local screen = Ui.frame(root, {
		name = "Report",
		color = Ui.COLORS.backdrop,
		transparency = 0.12,
		zindex = 10,
		visible = false,
	})

	local heading = Ui.label(screen, {
		name = "Heading",
		size = UDim2.fromScale(0.5, 0.07),
		position = UDim2.fromScale(0.5, 0.03),
		anchor = Vector2.new(0.5, 0),
		textColor = Ui.COLORS.textSoft,
		maxText = 36,
		outline = true,
	})
	local outcome = Ui.label(screen, {
		name = "Outcome",
		size = UDim2.fromScale(0.8, 0.1),
		position = UDim2.fromScale(0.5, 0.1),
		anchor = Vector2.new(0.5, 0),
		textColor = Ui.COLORS.accent,
		maxText = 60,
		outline = true,
	})

	-- Stars: filled ones are solid, missing ones faded; the text repeats the count.
	local starRow = Ui.frame(screen, {
		name = "Stars",
		size = UDim2.fromScale(0.5, 0.1),
		position = UDim2.fromScale(0.5, 0.21),
		anchor = Vector2.new(0.5, 0),
	})
	local starLabels: { TextLabel } = {}
	for index = 1, MAX_STARS do
		local star = Ui.icon(starRow, Ui.ICONS.star, {
			name = `Star{index}`,
			size = UDim2.fromScale(0.16, 1),
			position = UDim2.fromScale((index - 1) * 0.17, 0),
		})
		table.insert(starLabels, star)
	end
	local starText = Ui.label(starRow, {
		name = "Count",
		size = UDim2.fromScale(0.46, 0.8),
		position = UDim2.fromScale(0.53, 0.1),
		alignX = Enum.TextXAlignment.Left,
		maxText = 36,
		outline = true,
	})

	local timeline = Ui.frame(screen, {
		name = "Timeline",
		size = UDim2.fromScale(0.86, 0.5),
		position = UDim2.fromScale(0.5, 0.32),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.panel,
		transparency = 0.1,
		corner = 0.06,
		stroke = 3,
	})
	Ui.padding(timeline, 0.015)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = timeline

	local lastPress = 0
	local restart = Ui.button(screen, {
		name = "Restart",
		size = UDim2.fromScale(0.42, 0.13),
		position = UDim2.fromScale(0.5, 0.85),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.go,
		stroke = 4,
		maxText = 48,
	}, function()
		if Store.phase() ~= "Report" or os.clock() - lastPress < PRESS_COOLDOWN then
			return
		end
		lastPress = os.clock()
		Store.send({ type = "Restart" })
	end)

	local rows: { Frame } = {}

	local function rebuildTimeline()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
		local snap = Store.getSnapshot()
		if not snap then
			return
		end
		local count = math.max(#snap.history, MissionData.MISSION.TOTAL_DAYS)
		local rowHeight = 1 / count - 0.01
		for index, record in snap.history do
			local row = Ui.frame(timeline, {
				name = `Day{record.day}`,
				size = UDim2.fromScale(1, rowHeight),
				color = Ui.COLORS.panelLight,
				corner = 0.3,
				order = index,
			})
			Ui.label(row, {
				name = "DayNumber",
				text = tostring(record.day),
				size = UDim2.fromScale(0.07, 0.9),
				position = UDim2.fromScale(0.01, 0.5),
				anchor = Vector2.new(0, 0.5),
				color = Ui.COLORS.accent,
				textColor = Ui.COLORS.textDark,
				corner = 0.5,
				maxText = 30,
			})
			Ui.icon(row, Ui.EVENT_ICONS[record.event] or "", {
				name = "EventIcon",
				size = UDim2.fromScale(0.06, 0.9),
				position = UDim2.fromScale(0.09, 0.5),
				anchor = Vector2.new(0, 0.5),
			})
			Ui.label(row, {
				name = "Event",
				text = Store.t("event." .. record.event),
				size = UDim2.fromScale(0.2, 0.8),
				position = UDim2.fromScale(0.16, 0.5),
				anchor = Vector2.new(0, 0.5),
				alignX = Enum.TextXAlignment.Left,
				textColor = Ui.COLORS.textSoft,
				maxText = 24,
			})
			Ui.label(row, {
				name = "Cause",
				text = Store.t(record.causeKey),
				size = UDim2.fromScale(0.62, 0.84),
				position = UDim2.fromScale(0.37, 0.5),
				anchor = Vector2.new(0, 0.5),
				alignX = Enum.TextXAlignment.Left,
				maxText = 28,
			})
			table.insert(rows, row)
		end
	end

	local function render()
		local snap = Store.getSnapshot()
		heading.Text = Store.t("ui.report_title")
		restart.Text = `{Ui.ICONS.restart} {Store.t("ui.restart")}`
		if not snap then
			return
		end
		outcome.Text = Store.t("ui.outcome." .. snap.outcome)
		local stars = math.clamp(snap.stars, 0, MAX_STARS)
		for index, star in starLabels do
			star.TextTransparency = if index <= stars then 0 else 0.8
		end
		starText.Text = Store.t("ui.stars", { n = stars })
		rebuildTimeline()
	end

	local function setVisible(visible: boolean)
		screen.Visible = visible
	end

	render()
	return { setVisible = setVisible, render = render }
end

return Report
