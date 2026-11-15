--!strict
-- Space Base Odyssey - end-of-mission report: mission result (success, or what was missing), the
-- chapter's outro on success (the last chapter shows the partial ending and the secrets found),
-- stars for story and free play, a day-by-day timeline of causes, and Continue / Try again.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE
local MAX_STARS = 3
local PRESS_COOLDOWN = 1
local MAX_MISSING = 4
local FINALE_MISSION = "c3_failure"
local MIN_TIMELINE_ROWS = 4 -- a 1-day tutorial still gets a normal-height row

local Report = {}

export type ReportView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
}

-- Screen layout (fractions of the screen):
--   y 0.03-0.10 mission title (x 0.2-0.8; language button top right)
--   y 0.10-0.19 result line, y 0.20-0.28 stars (story and free play only)
--   y 0.31-0.80 timeline 0.04-0.56 | story card (outro or what was missing) 0.58-0.96
--   y 0.84-0.97 Continue 0.31-0.555 | Try again 0.57-0.80 | Real NASA data 0.815-0.985
--   (C.A.R.L. bubble: bottom-left, x 0.02-0.28)
-- `addSourcesButton` comes from Sources: it places the "Real NASA data" button on this screen.
function Report.new(root: Frame, addSourcesButton: (parent: Instance, props: Ui.Props) -> TextButton): ReportView
	local screen = Ui.frame(root, {
		name = "Report",
		color = ROLE.background,
		transparency = 0.1,
		zindex = 10,
		visible = false,
	})

	local heading = Ui.label(screen, {
		name = "Heading",
		size = UDim2.fromScale(0.6, 0.07),
		position = UDim2.fromScale(0.5, 0.03),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.textDim,
		maxText = 34,
	})
	local result = Ui.iconText(screen, {
		name = "Result",
		size = UDim2.fromScale(0.56, 0.09),
		position = UDim2.fromScale(0.5, 0.1),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.panelRaised,
		stroke = Ui.STROKE,
		corner = 0.5,
		maxText = 48,
	})
	result.icon.Size = UDim2.fromScale(0.1, 0.72)
	result.label.Size = UDim2.fromScale(0.82, 0.84)
	result.label.Position = UDim2.fromScale(0.15, 0.5)
	local resultStroke = result.frame:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- Stars: filled ones gold, missing ones as empty outlines; the text repeats the count.
	local starRow = Ui.frame(screen, {
		name = "Stars",
		size = UDim2.fromScale(0.36, 0.08),
		position = UDim2.fromScale(0.5, 0.205),
		anchor = Vector2.new(0.5, 0),
	})
	local starIcons: { ImageLabel } = {}
	for index = 1, MAX_STARS do
		local star = Ui.icon(starRow, Ui.ICONS.star, {
			name = `Star{index}`,
			size = UDim2.fromScale(0.16, 1),
			position = UDim2.fromScale((index - 1) * 0.17, 0),
			tint = ROLE.star,
		})
		table.insert(starIcons, star)
	end
	local starText = Ui.label(starRow, {
		name = "Count",
		size = UDim2.fromScale(0.46, 0.8),
		position = UDim2.fromScale(0.53, 0.1),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 32,
	})

	local timeline = Ui.panel(screen, {
		name = "Timeline",
		size = UDim2.fromScale(0.52, 0.49),
		position = UDim2.fromScale(0.04, 0.31),
		transparency = 0.08,
		corner = 0.05,
	})
	Ui.padding(timeline, 0.02)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.012, 0)
	layout.Parent = timeline

	-- Story card: the outro (success) or the list of what was missing (failure).
	local storyCard = Ui.panel(screen, {
		name = "StoryCard",
		size = UDim2.fromScale(0.38, 0.49),
		position = UDim2.fromScale(0.58, 0.31),
		color = ROLE.panelRaised,
		corner = 0.06,
		stroke = 4,
	})
	local storyStroke = storyCard:FindFirstChildOfClass("UIStroke") :: UIStroke
	local storyTitle = Ui.iconText(storyCard, {
		name = "Title",
		size = UDim2.fromScale(0.9, 0.13),
		position = UDim2.fromScale(0.05, 0.04),
		maxText = 30,
	})
	storyTitle.icon.Size = UDim2.fromScale(0.12, 0.8)
	storyTitle.icon.Position = UDim2.fromScale(0, 0.5)
	storyTitle.label.Size = UDim2.fromScale(0.85, 0.9)
	storyTitle.label.Position = UDim2.fromScale(0.15, 0.5)
	local outroText = Ui.body(storyCard, {
		name = "Outro",
		size = UDim2.fromScale(0.9, 0.5),
		position = UDim2.fromScale(0.05, 0.2),
		alignY = Enum.TextYAlignment.Top,
		maxText = 24,
	})
	-- Secrets line (last chapter): magenta = secrets.
	local secrets = Ui.iconText(storyCard, {
		name = "Secrets",
		size = UDim2.fromScale(0.9, 0.11),
		position = UDim2.fromScale(0.05, 0.72),
		color = ROLE.background,
		stroke = 2,
		strokeColor = ROLE.reward,
		textColor = ROLE.reward,
		icon = Ui.ICONS.gift,
		tint = ROLE.reward,
		maxText = 24,
		visible = false,
	})
	secrets.icon.Size = UDim2.fromScale(0.1, 0.72)
	secrets.label.Size = UDim2.fromScale(0.84, 0.84)
	secrets.label.Position = UDim2.fromScale(0.14, 0.5)
	local secretsHint = Ui.body(storyCard, {
		name = "SecretsHint",
		size = UDim2.fromScale(0.9, 0.12),
		position = UDim2.fromScale(0.05, 0.85),
		textColor = ROLE.textDim,
		maxText = 20,
		visible = false,
	})
	-- Missing objectives (failure).
	local missingRows: { Ui.IconText } = {}
	for index = 1, MAX_MISSING do
		local row = Ui.iconText(storyCard, {
			name = `Missing{index}`,
			size = UDim2.fromScale(0.9, 0.15),
			position = UDim2.fromScale(0.05, 0.2 + (index - 1) * 0.18),
			color = ROLE.background,
			stroke = 2,
			strokeColor = ROLE.warning,
			icon = Ui.ICONS.warning,
			tint = ROLE.warning,
			font = Ui.BODY_FONT,
			maxText = 22,
			visible = false,
		})
		row.icon.Size = UDim2.fromScale(0.1, 0.66)
		row.label.Size = UDim2.fromScale(0.84, 0.84)
		row.label.Position = UDim2.fromScale(0.14, 0.5)
		table.insert(missingRows, row)
	end

	local lastPress = 0
	local function pressAllowed(): boolean
		if Store.phase() ~= "Report" or os.clock() - lastPress < PRESS_COOLDOWN then
			return false
		end
		lastPress = os.clock()
		return true
	end

	local continueButton = Ui.button(screen, {
		name = "Continue",
		size = UDim2.fromScale(0.245, 0.13),
		position = UDim2.fromScale(0.31, 0.84),
		icon = Ui.ICONS.home,
		maxText = 40,
	}, function()
		if pressAllowed() then
			Store.send({ type = "Restart" }) -- back to mission select
		end
	end)
	local retryButton = Ui.button(screen, {
		name = "TryAgain",
		size = UDim2.fromScale(0.23, 0.13),
		position = UDim2.fromScale(0.57, 0.84),
		color = ROLE.secondaryButton,
		icon = Ui.ICONS.restart,
		maxText = 40,
	}, function()
		local mission = Store.mission()
		if not pressAllowed() then
			return
		end
		if mission then
			Store.startMission(mission.id) -- the server restarts this mission straight from the report
		else
			Store.send({ type = "Restart" })
		end
	end)

	addSourcesButton(screen, {
		size = UDim2.fromScale(0.17, 0.11),
		position = UDim2.fromScale(0.985, 0.85),
		anchor = Vector2.new(1, 0),
		zindex = 2,
	})

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
		local count = math.max(#snap.history, snap.totalDays or 1, MIN_TIMELINE_ROWS)
		local rowHeight = 1 / count - 0.012
		for index, record in snap.history do
			local row = Ui.frame(timeline, {
				name = `Day{record.day}`,
				size = UDim2.fromScale(1, rowHeight),
				color = ROLE.panelRaised,
				corner = 0.3,
				order = index,
			})
			Ui.label(row, {
				name = "DayNumber",
				text = tostring(record.day),
				size = UDim2.fromScale(0.08, 0.84),
				position = UDim2.fromScale(0.01, 0.5),
				anchor = Vector2.new(0, 0.5),
				color = ROLE.warning,
				textColor = ROLE.primaryButtonText,
				corner = 0.5,
				maxText = 26,
			})
			local event = record.event
			Ui.icon(row, Ui.EVENT_ICONS[event] or Ui.ICONS.moon, {
				name = "EventIcon",
				size = UDim2.fromScale(0.07, 0.7),
				position = UDim2.fromScale(0.105, 0.5),
				anchor = Vector2.new(0, 0.5),
				tint = Ui.EVENT_COLORS[event] or ROLE.accent,
			})
			Ui.body(row, {
				name = "Cause",
				text = Store.t(record.causeKey),
				size = UDim2.fromScale(0.8, 0.84),
				position = UDim2.fromScale(0.19, 0.5),
				anchor = Vector2.new(0, 0.5),
				maxText = 22,
			})
			table.insert(rows, row)
		end
	end

	-- Text for a missing item: objective keys get their target number ({n}) from the mission.
	local function missingText(key: string): string
		local mission = Store.mission()
		if mission then
			for _, objective in mission.objectives do
				if objective.textKey == key or ("obj." .. objective.id) == key then
					return Store.t(key, { n = objective.target })
				end
			end
		end
		return Store.t(key)
	end

	local function render()
		local snap = Store.getSnapshot()
		local mission = Store.mission()
		local missionResult = Store.missionResult()
		heading.Text = if mission then Store.t(mission.titleKey) else Store.t("ui.report_title")
		Ui.setButton(continueButton, Store.t("ui.continue"))
		Ui.setButton(retryButton, Store.t("ui.try_again"))
		if not snap then
			return
		end

		local kind = if mission then mission.kind else "Free"
		-- Without a mission result (older server) the outcome decides.
		local success = if missionResult then missionResult.success else snap.outcome == "Completed"

		-- Result line: lime trophy for success, orange alert for "not yet".
		local resultColor = if success then ROLE.good else ROLE.warning
		local resultKey = if missionResult or mission
			then (if success then "ui.mission_success" else "ui.mission_failed")
			else "ui.outcome." .. snap.outcome
		result.set(if success then Ui.ICONS.trophy else Ui.ICONS.warning, Store.t(resultKey), resultColor)
		result.label.TextColor3 = resultColor
		resultStroke.Color = resultColor

		-- Stars only for story chapters and free play (tutorials teach, they are not scored).
		local showStars = kind ~= "Tutorial"
		starRow.Visible = showStars
		local stars = math.clamp(snap.stars, 0, MAX_STARS)
		for index, star in starIcons do
			local earned = index <= stars
			Ui.setIcon(star, if earned then Ui.ICONS.star else Ui.ICONS.starEmpty, if earned then ROLE.star else ROLE.textDim)
		end
		starText.Text = Store.t("ui.stars", { n = stars })

		-- Story card.
		-- Failure list: why the crew came home early (if they did), then each unmet objective.
		local missing: { string } = {}
		if not success then
			if snap.outcome ~= "Completed" and snap.outcome ~= "InProgress" then
				table.insert(missing, "ui.outcome." .. snap.outcome)
			end
			if missionResult and type(missionResult.missingKeys) == "table" then
				for _, key in missionResult.missingKeys do
					if type(key) == "string" and not table.find(missing, key) then
						table.insert(missing, key)
					end
				end
			end
		end
		local showMissing = #missing > 0
		for index, row in missingRows do
			local key = missing[index]
			row.frame.Visible = showMissing and key ~= nil
			if showMissing and key then
				row.label.Text = missingText(key)
			end
		end
		local isFinale = mission ~= nil and mission.id == FINALE_MISSION and success
		local found = Store.collectibleCount()
		local total = #Store.COLLECTIBLES
		secrets.frame.Visible = isFinale
		secretsHint.Visible = isFinale and found < total
		if isFinale then
			secrets.label.Text = Store.t("ui.secrets_found", { n = found, total = total })
			secretsHint.Text = Store.t("story.secrets_hint")
		end
		if success then
			storyStroke.Color = if isFinale then ROLE.reward else ROLE.good
			storyTitle.set(Ui.ICONS.book, Store.t("ui.mission_success"), ROLE.good)
			storyTitle.label.TextColor3 = ROLE.good
			outroText.Visible = mission ~= nil
			outroText.Text = if mission then Store.t(`mission.{mission.id}.outro`) else ""
		else
			storyStroke.Color = ROLE.warning
			storyTitle.set(Ui.ICONS.target, Store.t("ui.missing"), ROLE.warning)
			storyTitle.label.TextColor3 = ROLE.warning
			-- Nothing listed (older server): just say it was not done yet.
			outroText.Visible = not showMissing
			outroText.Text = Store.t("ui.mission_failed")
		end
		outroText.Size = UDim2.fromScale(0.9, if isFinale then 0.5 else 0.72)

		-- Primary action: Continue after a success, Try again after a failure.
		Ui.setButtonColor(continueButton, if success then ROLE.primaryButton else ROLE.secondaryButton)
		Ui.setButtonColor(retryButton, if success then ROLE.secondaryButton else ROLE.primaryButton)
		retryButton.Visible = mission ~= nil or not success

		rebuildTimeline()
	end

	local function setVisible(visible: boolean)
		screen.Visible = visible
	end

	render()
	return { setVisible = setVisible, render = render }
end

return Report
