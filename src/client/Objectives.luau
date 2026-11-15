--!strict
-- Space Base Odyssey - objectives checklist: a compact panel in the top-left corner.
--   * During a mission (Planning and Shift): built from snapshot.mission.objectives. Done objectives
--     get a lime check and a small "pop"; open ones show an empty ring and their progress ("1/3").
--     Open build objectives (Stage 6: build_solar, build_greenhouse, build_antenna, build_shelter;
--     Stage 7: build_habitat) show the build's icon (a hammer by default, a house for the habitat).
--   * Stage 9 (open world, no mission menu): in base mode (Briefing, mission select closed) it is the
--     QUEST tracker, from BaseState.quest = { id, kind, stepIndex, steps = { { key, progress, target,
--     done } }, mainDone }. A small "Main quest" / "Side quest" tag, the quest's icon and title, then
--     every step of the quest (they all count at once) with "x/y" progress; the current step is lit.
--     A step that gets done pops its check; a finished quest flashes the panel lime before the next
--     one slides in. Once every main quest is done and no quest is left, it shows Quests.FINALE_KEY.
-- The quest arrives in the BaseState. Store.setBase may not keep that field, so this module also
-- listens to the BaseState remote itself and keeps the latest quest (Objectives.currentQuest, also
-- read by CarlDrone, Hud and Onboarding).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE

-- Layout (fractions of the screen). Below the Roblox menu buttons in the top-left corner.
--   Planning: y 0.10 to at most 0.28, above the first power-board row (y 0.29); meters start at x 0.23.
--   Shift: y 0.12 to at most 0.42; the HUD meters panel sits right under it (see getBottom).
--   Base (quest tracker): y 0.10 to at most 0.31; the HUD wallet sits right under it.
local PANEL_X = 0.01
local PANEL_WIDTH = 0.2
local LAYOUT = table.freeze({
	Planning = { top = 0.1, header = 0.034, row = 0.034, maxHeight = 0.18 },
	Shift = { top = 0.12, header = 0.04, row = 0.046, maxHeight = 0.3 },
})
local QUEST_LAYOUT = table.freeze({ top = 0.1, tag = 0.026, header = 0.04, row = 0.038, maxHeight = 0.21 })
local PAD = 0.006
local MAX_ROWS = 6
local POP_SECONDS = 0.35
local FLASH_SECONDS = 0.6 -- a finished quest: the panel border glows lime
local SLIDE_SECONDS = 0.35 -- the next quest slides in from the left
-- Stage 10 (playtest): a ticked step or a new quest also thickens the border for a moment, so the
-- eye goes to the tracker (QuestToasts.luau tells the same news on the right side).
local PULSE_THICKNESS = 2.5 -- times the normal border thickness

local Objectives = {}

-- Icon of an open build objective (Icons.luau images); others use the hammer.
local BUILD_ICONS: { [string]: string } = {
	build_habitat = Ui.Icons.home,
}

-- The quest the server sent last (see the header). Steps carry the Quests.luau step when known.
export type QuestStep = {
	key: string,
	progress: number,
	target: number,
	done: boolean,
	def: Quests.Step?,
}
export type QuestView = {
	id: string,
	kind: string, -- "main" | "side"
	stepIndex: number,
	steps: { QuestStep },
	mainDone: boolean,
	def: Quests.Quest?,
}
-- Nil = no quest (all done, or an older server). mainDone is also kept on its own.
local questCache: QuestView? = nil
local questReceived = false
local mainDoneCache = false
local questListeners: { () -> () } = {}

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

-- A raw BaseState.quest table -> QuestView (nil when missing or broken).
local function parseQuest(raw: any): QuestView?
	-- id "" = no quest left (the server then sends the finale title): no tracker quest.
	if type(raw) ~= "table" or type(raw.id) ~= "string" or raw.id == "" then
		return nil
	end
	local def = Quests.byId(raw.id)
	local steps: { QuestStep } = {}
	if type(raw.steps) == "table" then
		for index, step in raw.steps do
			if type(index) ~= "number" or type(step) ~= "table" then
				continue
			end
			local stepDef: Quests.Step? = if def then def.steps[index] else nil
			local target = math.max(1, math.floor(numberOr(step.target, if stepDef then Quests.stepTarget(stepDef) else 1)))
			local key = if type(step.key) == "string" then step.key else Quests.stepKey(raw.id, index)
			steps[index] = {
				key = key,
				progress = math.clamp(math.floor(numberOr(step.progress, 0)), 0, target),
				target = target,
				done = step.done == true,
				def = stepDef,
			}
		end
	end
	local kind = if raw.kind == "side" or raw.kind == "main" then raw.kind elseif def then def.kind else "main"
	return {
		id = raw.id,
		kind = kind,
		stepIndex = math.max(1, math.floor(numberOr(raw.stepIndex, 1))),
		steps = steps,
		mainDone = raw.mainDone == true,
		def = def,
	}
end

local function setQuestFrom(state: any)
	if type(state) ~= "table" then
		return
	end
	questReceived = true
	questCache = parseQuest(state.quest)
	local raw: any = state.quest
	mainDoneCache = (type(raw) == "table" and raw.mainDone == true) or state.questMainDone == true
	for _, listener in questListeners do
		task.spawn(listener)
	end
end

-- The quest to show and follow now (nil = none, or none received yet).
function Objectives.currentQuest(): QuestView?
	if questReceived then
		return questCache
	end
	-- Store.setBase may keep the field one day: read it through `any`.
	local base: any = Store.getBase()
	return if type(base) == "table" then parseQuest(base.quest) else nil
end

-- Every main quest is done (the finale line shows when no side quest is left either).
function Objectives.mainQuestsDone(): boolean
	local quest = Objectives.currentQuest()
	return mainDoneCache or (quest ~= nil and quest.mainDone)
end

-- The step to work on now: the current step when it is open, else the first open one (nil = none).
function Objectives.currentStep(quest: QuestView?): (QuestStep?, number?)
	if quest == nil then
		return nil, nil
	end
	local current = quest.steps[quest.stepIndex]
	if current and not current.done then
		return current, quest.stepIndex
	end
	for index, step in quest.steps do
		if not step.done then
			return step, index
		end
	end
	return nil, nil
end

-- Called when a new quest state arrives (in its own thread).
function Objectives.onQuestChanged(listener: () -> ())
	table.insert(questListeners, listener)
end

-- Listen to the BaseState remote once (a second listener beside Main.client's; it only reads).
local listening = false
local function listen()
	if listening then
		return
	end
	listening = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
		local name: string = (Types.Remotes :: any).BASE_STATE or "BaseState"
		local remote = remotes:WaitForChild(name, 60)
		if remote == nil or not remote:IsA("RemoteEvent") then
			return -- older server: no quests
		end
		(remote :: RemoteEvent).OnClientEvent:Connect(function(state: any)
			if type(state) == "table" and type(state.credits) == "number" then
				setQuestFrom(state)
			end
		end)
	end)
end

export type ObjectivesView = {
	setPhase: (phase: string) -> (),
	render: () -> (),
	-- Bottom edge of the panel as a fraction of the screen height, or nil while it is hidden.
	getBottom: () -> number?,
}

type Row = {
	frame: Frame,
	ring: Frame,
	ringStroke: UIStroke?,
	check: ImageLabel,
	build: ImageLabel,
	text: TextLabel,
	scale: UIScale,
	done: boolean,
	id: string?,
}

function Objectives.new(root: Frame): ObjectivesView
	listen()

	-- Above the power board (10) and the HUD (5), below the C.A.R.L. bubble (50) and the panels (55+).
	local panel = Ui.panel(root, {
		name = "Objectives",
		size = UDim2.fromScale(PANEL_WIDTH, 0.2),
		position = UDim2.fromScale(PANEL_X, 0.1),
		transparency = 0.08,
		corner = 0.12,
		strokeColor = ROLE.accent,
		zindex = 12,
		visible = false,
	})
	local panelStroke = panel:FindFirstChildOfClass("UIStroke")

	-- Stage 10: the border glows `color` and thickens, then eases back to the accent border.
	local function pulse(color: Color3)
		if panelStroke == nil then
			return
		end
		panelStroke.Color = color
		panelStroke.Thickness = Ui.STROKE * PULSE_THICKNESS
		TweenService:Create(panelStroke, TweenInfo.new(FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = ROLE.accent,
			Thickness = Ui.STROKE,
		}):Play()
	end

	-- Quest tag ("Main quest" / "Side quest"): a small pill above the title.
	local tag = Ui.label(panel, {
		name = "QuestTag",
		size = UDim2.fromScale(0.5, 0.1),
		position = UDim2.fromScale(0.04, 0),
		color = ROLE.star,
		textColor = ROLE.primaryButtonText,
		corner = 0.5,
		maxText = 14,
		minText = 7,
		zindex = 13,
		visible = false,
	})

	local header = Ui.frame(panel, { name = "Header", zindex = 13 })
	local headerIcon = Ui.icon(header, Ui.ICONS.target, {
		name = "Icon",
		size = UDim2.fromScale(0.12, 0.8),
		position = UDim2.fromScale(0.04, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = 13,
	})
	local title = Ui.label(header, {
		name = "Title",
		size = UDim2.fromScale(0.8, 0.9),
		position = UDim2.fromScale(0.18, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 22,
		minText = 8,
		zindex = 13,
	})

	local rows: { Row } = {}
	for index = 1, MAX_ROWS do
		local frame = Ui.frame(panel, { name = `Objective{index}`, zindex = 13, visible = false })
		local ring = Ui.frame(frame, {
			name = "Ring",
			size = UDim2.fromScale(0.09, 0.62),
			position = UDim2.fromScale(0.055, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			corner = 0.5,
			stroke = 2,
			strokeColor = ROLE.textDim,
			aspect = 1,
			zindex = 13,
		})
		local check = Ui.icon(frame, Ui.ICONS.check, {
			name = "Check",
			size = UDim2.fromScale(0.12, 0.86),
			position = UDim2.fromScale(0.055, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			tint = ROLE.good,
			zindex = 14,
			visible = false,
		})
		local build = Ui.icon(frame, Ui.Icons.build, {
			name = "Build",
			size = UDim2.fromScale(0.12, 0.86),
			position = UDim2.fromScale(0.055, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			tint = ROLE.warning,
			zindex = 14,
			visible = false,
		})
		local scale = Instance.new("UIScale")
		scale.Parent = check
		local text = Ui.body(frame, {
			name = "Text",
			size = UDim2.fromScale(0.84, 0.9),
			position = UDim2.fromScale(0.13, 0.5),
			anchor = Vector2.new(0, 0.5),
			maxText = 20,
			minText = 8,
			zindex = 13,
		})
		table.insert(rows, {
			frame = frame,
			ring = ring,
			ringStroke = ring:FindFirstChildOfClass("UIStroke"),
			check = check,
			build = build,
			text = text,
			scale = scale,
			done = false,
			id = nil,
		})
	end

	local phase = "Briefing"
	local shownQuestId: string? = nil -- the quest on screen (to animate the change to the next one)

	local function objectiveText(objective: Store.MissionObjective): string
		local key = if type(objective.textKey) == "string" then objective.textKey else "obj." .. objective.id
		local target = math.max(1, math.floor(objective.target or 1))
		local text = Store.t(key, { n = target })
		if target > 1 and not objective.done then
			local progress = math.clamp(math.floor(objective.progress or 0), 0, target)
			text = `{text}  {progress}/{target}`
		end
		return text
	end

	-- One checklist row: check (done), hammer (open build), else a ring. `lit` = the current step.
	local function setRow(row: Row, id: string, done: boolean, isBuild: boolean, buildIcon: string?, text: string, lit: boolean)
		-- A check that appears while the player watches gets a little pop.
		if done and not row.done and row.id == id then
			row.scale.Scale = 1.6
			TweenService:Create(row.scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
			pulse(ROLE.good)
		end
		row.done = done
		row.id = id
		row.check.Visible = done
		row.build.Visible = isBuild and not done
		if isBuild then
			row.build.Image = buildIcon or Ui.Icons.build
		end
		row.ring.Visible = not done and not isBuild
		if row.ringStroke then
			row.ringStroke.Color = if lit then ROLE.accent else ROLE.textDim
		end
		row.text.Text = text
		row.text.TextColor3 = if done then ROLE.good elseif lit then ROLE.text else ROLE.textDim
		row.text.TextTransparency = if done then 0.15 else 0
	end

	-- Rows from index `from` on are hidden.
	local function hideRows(from: number)
		for index = from, #rows do
			rows[index].frame.Visible = false
			rows[index].id = nil
		end
	end

	local function renderMission(mission: Store.MissionInfo, layout: any)
		local objectives = mission.objectives
		local count = math.min(#objectives, MAX_ROWS)
		local rowHeight = math.min(layout.row, (layout.maxHeight - layout.header - PAD * 2) / count)
		local height = layout.header + rowHeight * count + PAD * 2
		panel.Position = UDim2.fromScale(PANEL_X, layout.top)
		panel.Size = UDim2.fromScale(PANEL_WIDTH, height)
		-- Children sizes are fractions of the panel.
		tag.Visible = false
		header.Size = UDim2.fromScale(1, layout.header / height)
		header.Position = UDim2.fromScale(0, PAD / height)
		headerIcon.Image = Ui.ICONS.target
		headerIcon.ImageColor3 = ROLE.accent
		title.Text = Store.t("ui.objectives")
		title.TextColor3 = ROLE.accent
		shownQuestId = nil

		for index = 1, count do
			local row = rows[index]
			local objective = objectives[index]
			row.frame.Visible = true
			row.frame.Size = UDim2.fromScale(1, rowHeight / height)
			row.frame.Position = UDim2.fromScale(0, (PAD + layout.header + rowHeight * (index - 1)) / height)
			local isBuild = string.sub(objective.id, 1, 6) == "build_"
			setRow(row, objective.id, objective.done == true, isBuild, BUILD_ICONS[objective.id], objectiveText(objective), true)
		end
		hideRows(count + 1)
		panel.Visible = true
	end

	-- A finished quest: the border glows lime, then the next quest slides in from the left.
	local function animateNewQuest()
		pulse(ROLE.good)
		local goal = panel.Position
		panel.Position = UDim2.fromScale(goal.X.Scale - PANEL_WIDTH * 0.4, goal.Y.Scale)
		TweenService:Create(panel, TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = goal,
		}):Play()
	end

	-- The quest tracker (base mode). Returns false when there is nothing to show.
	local function renderQuest(): boolean
		local layout = QUEST_LAYOUT
		local quest = Objectives.currentQuest()
		local finale = quest == nil and Objectives.mainQuestsDone()
		if quest == nil and not finale then
			shownQuestId = nil
			return false
		end
		local count = if quest then math.min(#quest.steps, MAX_ROWS) else 0
		local rowHeight = if count > 0 then math.min(layout.row, (layout.maxHeight - layout.tag - layout.header - PAD * 2) / count) else 0
		local tagHeight = if quest then layout.tag else 0
		local height = tagHeight + layout.header + rowHeight * count + PAD * 2
		panel.Size = UDim2.fromScale(PANEL_WIDTH, height)

		if quest then
			local side = quest.kind == "side"
			tag.Visible = true
			tag.Text = Store.t(if side then "ui.quest_side" else "ui.quest_main")
			tag.BackgroundColor3 = if side then ROLE.reward else ROLE.star
			tag.Size = UDim2.fromScale(0.5, (tagHeight - PAD * 0.5) / height)
			tag.Position = UDim2.fromScale(0.04, PAD / height)
			local iconName = if quest.def then quest.def.icon else "target"
			headerIcon.Image = Ui.iconImage(iconName)
			headerIcon.ImageColor3 = if side then ROLE.reward else ROLE.star
			title.Text = Store.t(Quests.titleKey(quest.id))
			title.TextColor3 = ROLE.text
		else
			-- Every main quest is done: secrets and side quests wait.
			tag.Visible = false
			headerIcon.Image = Ui.ICONS.star
			headerIcon.ImageColor3 = ROLE.star
			title.Text = Store.t(Quests.FINALE_KEY)
			title.TextColor3 = ROLE.star
		end
		header.Size = UDim2.fromScale(1, layout.header / height)
		header.Position = UDim2.fromScale(0, (PAD + tagHeight) / height)

		local _, currentIndex = Objectives.currentStep(quest)
		for index = 1, count do
			local row = rows[index]
			local step = (quest :: QuestView).steps[index]
			if step == nil then
				row.frame.Visible = false
				row.id = nil
				continue
			end
			row.frame.Visible = true
			row.frame.Size = UDim2.fromScale(1, rowHeight / height)
			row.frame.Position = UDim2.fromScale(0, (PAD + tagHeight + layout.header + rowHeight * (index - 1)) / height)
			local text = Store.t(step.key, { n = step.target })
			if step.target > 1 and not step.done then
				text = `{text}  {step.progress}/{step.target}`
			end
			local def = step.def
			local isBuild = def ~= nil and def.type == "build"
			local buildIcon = if isBuild and def and def.id == "habitat" then Ui.Icons.home else nil
			setRow(row, `{(quest :: QuestView).id}:{index}`, step.done, isBuild, buildIcon, text, index == currentIndex)
		end
		hideRows(count + 1)

		local questId = if quest then quest.id else Quests.FINALE_KEY
		local changed = shownQuestId ~= nil and shownQuestId ~= questId
		shownQuestId = questId
		panel.Position = UDim2.fromScale(PANEL_X, layout.top)
		panel.Visible = true
		if changed then
			animateNewQuest()
		end
		return true
	end

	local function render()
		local layout = (LAYOUT :: any)[phase]
		local mission = Store.mission()
		local objectives = if mission then mission.objectives else nil
		if layout ~= nil and mission ~= nil and type(objectives) == "table" and #objectives > 0 then
			renderMission(mission, layout)
			return
		end
		-- No mission running: the quest tracker in base mode.
		if Store.phase() == "Briefing" and Store.isBaseMode() and renderQuest() then
			return
		end
		panel.Visible = false
	end

	local function setPhase(value: string)
		phase = value
		render()
	end

	local function getBottom(): number?
		if not panel.Visible then
			return nil
		end
		return panel.Position.Y.Scale + panel.Size.Y.Scale
	end

	-- Main.client renders on snapshots; quests change with the BaseState and the screen mode.
	Objectives.onQuestChanged(render)
	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "base" or kind == "view" then
			render()
		end
	end)

	return { setPhase = setPhase, render = render, getBottom = getBottom }
end

return Objectives
