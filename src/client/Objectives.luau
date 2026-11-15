--!strict
-- Space Base Odyssey - mission objectives checklist: a compact panel in the top-left corner during
-- Planning and Shift, built from snapshot.mission.objectives. Done objectives get a lime check and
-- a small "pop"; open ones show an empty ring and their progress ("1/3"). Open build objectives
-- (Stage 6: build_solar, build_greenhouse, build_antenna, build_shelter) show a hammer instead of
-- the ring.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local TweenService = game:GetService("TweenService")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE

-- Layout (fractions of the screen). Below the Roblox menu buttons in the top-left corner.
--   Planning: y 0.10 to at most 0.28, above the first power-board row (y 0.29); meters start at x 0.23.
--   Shift: y 0.12 to at most 0.42; the HUD meters panel sits right under it (see getBottom).
local PANEL_X = 0.01
local PANEL_WIDTH = 0.2
local LAYOUT = table.freeze({
	Planning = { top = 0.1, header = 0.034, row = 0.034, maxHeight = 0.18 },
	Shift = { top = 0.12, header = 0.04, row = 0.046, maxHeight = 0.3 },
})
local PAD = 0.006
local MAX_ROWS = 6
local POP_SECONDS = 0.35

local Objectives = {}

export type ObjectivesView = {
	setPhase: (phase: string) -> (),
	render: () -> (),
	-- Bottom edge of the panel as a fraction of the screen height, or nil while it is hidden.
	getBottom: () -> number?,
}

type Row = {
	frame: Frame,
	ring: Frame,
	check: ImageLabel,
	build: ImageLabel,
	text: TextLabel,
	scale: UIScale,
	done: boolean,
	id: string?,
}

function Objectives.new(root: Frame): ObjectivesView
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

	local header = Ui.frame(panel, { name = "Header", zindex = 13 })
	Ui.icon(header, Ui.ICONS.target, {
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
		table.insert(rows, { frame = frame, ring = ring, check = check, build = build, text = text, scale = scale, done = false, id = nil })
	end

	local phase = "Briefing"

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

	local function render()
		local mission = Store.mission()
		local layout = (LAYOUT :: any)[phase]
		local objectives = if mission then mission.objectives else nil
		if layout == nil or mission == nil or type(objectives) ~= "table" or #objectives == 0 then
			panel.Visible = false
			return
		end
		local count = math.min(#objectives, MAX_ROWS)
		local rowHeight = math.min(layout.row, (layout.maxHeight - layout.header - PAD * 2) / count)
		local height = layout.header + rowHeight * count + PAD * 2
		panel.Position = UDim2.fromScale(PANEL_X, layout.top)
		panel.Size = UDim2.fromScale(PANEL_WIDTH, height)
		-- Children sizes are fractions of the panel.
		header.Size = UDim2.fromScale(1, layout.header / height)
		header.Position = UDim2.fromScale(0, PAD / height)
		title.Text = Store.t("ui.objectives")

		for index, row in rows do
			local objective = objectives[index]
			if index > count or objective == nil then
				row.frame.Visible = false
				row.id = nil
				continue
			end
			row.frame.Visible = true
			row.frame.Size = UDim2.fromScale(1, rowHeight / height)
			row.frame.Position = UDim2.fromScale(0, (PAD + layout.header + rowHeight * (index - 1)) / height)
			local done = objective.done == true
			-- A check that appears while the player watches gets a little pop.
			if done and not row.done and row.id == objective.id then
				row.scale.Scale = 1.6
				TweenService:Create(
					row.scale,
					TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
			row.done = done
			row.id = objective.id
			local isBuild = string.sub(objective.id, 1, 6) == "build_"
			row.check.Visible = done
			row.build.Visible = isBuild and not done
			row.ring.Visible = not done and not isBuild
			row.text.Text = objectiveText(objective)
			row.text.TextColor3 = if done then ROLE.good else ROLE.text
			row.text.TextTransparency = if done then 0.15 else 0
		end
		panel.Visible = true
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

	return { setPhase = setPhase, render = render, getBottom = getBottom }
end

return Objectives
