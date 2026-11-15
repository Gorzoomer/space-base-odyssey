--!strict
-- Space Base Odyssey - Planning overlay: the power board where the crew shares power cells between systems.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Meters = require(script.Parent.Meters)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef
export type SystemId = "LifeSupport" | "Greenhouse" | "Science"

local SYSTEMS: { SystemId } = { "LifeSupport", "Greenhouse", "Science" }
local START_COOLDOWN = 1
-- Onboarding guide look (visual tuning only).
local PULSE_SPEED = 5 -- radians per second
local STROKE_NORMAL = Ui.STROKE
local STROKE_PULSE = 6

local ROLE = Ui.ROLE
local HINT_POSITION = UDim2.fromScale(0.11, 0.56)
local HINT_POSITION_ICON = UDim2.fromScale(0.145, 0.56)

local PowerBoard = {}

-- Onboarding hook: `highlight` rows pulse with a pointer; `later` rows show the "food comes
-- tomorrow" hint. Both stay fully usable. nil clears the guide.
export type Guide = {
	highlight: { SystemId }?,
	later: { SystemId }?,
}

export type PowerBoardView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
	setGuide: (guide: Guide?) -> (),
}

type Slot = { frame: Frame, icon: ImageLabel }

type Row = {
	frame: Frame,
	stroke: UIStroke?,
	pointer: ImageLabel,
	name: TextLabel,
	hint: TextLabel,
	hintIcon: ImageLabel,
	slots: { Slot },
	minus: TextButton,
	plus: TextButton,
}

local function allocationOf(system: SystemId): number
	local snap = Store.getSnapshot()
	if not snap then
		return 0
	end
	return (snap.allocation :: any)[system] or 0
end

local function powerLeft(): number
	local snap = Store.getSnapshot()
	if not snap then
		return 0
	end
	local allocation = snap.allocation
	return snap.cellsAvailable - (allocation.LifeSupport + allocation.Greenhouse + allocation.Science)
end

-- `showMessage` lets the board explain locally why a press did nothing (the server validates too).
-- `addSourcesButton` comes from Sources: it places the "Real NASA data" button on this screen.
--
-- Screen layout (fractions of the screen):
--   y 0.02-0.13  day label 0.22-0.46, event 0.48-0.79, settings button 0.815-0.985 (Settings)
--   y 0.10-0.28  objectives panel 0.01-0.21 (Objectives.luau, during a mission)
--   y 0.115-0.185 sources button 0.815-0.985 (right edge, under the settings button)
--   y 0.15-0.26  meters 0.23-0.80 (air, food, radiation, water)
--   y 0.29-0.77  three system rows 0.05-0.95
--   y 0.80-0.95  power left 0.05-0.30 | C.A.R.L. bubble 0.315-0.585 (Messages) | Start 0.60-0.95
function PowerBoard.new(
	root: Frame,
	showMessage: (ref: TextRef) -> (),
	addSourcesButton: (parent: Instance, props: Ui.Props) -> TextButton
): PowerBoardView
	local maxCells: number = MissionData.POWER.MAX_CELLS_PER_SYSTEM

	local screen = Ui.frame(root, {
		name = "PowerBoard",
		color = Ui.COLORS.backdrop,
		transparency = 0.3,
		zindex = 10,
		visible = false,
	})

	local dayLabel = Ui.label(screen, {
		name = "Day",
		size = UDim2.fromScale(0.24, 0.1),
		position = UDim2.fromScale(0.22, 0.03),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.warning,
		maxText = 48,
		outline = true,
	})
	local eventBanner = Ui.iconText(screen, {
		name = "Event",
		size = UDim2.fromScale(0.31, 0.1),
		position = UDim2.fromScale(0.48, 0.03),
		color = Ui.COLORS.panelLight,
		stroke = Ui.STROKE,
		maxText = 36,
	})

	local meters = Meters.new(screen, {
		size = UDim2.fromScale(0.57, 0.11),
		position = UDim2.fromScale(0.23, 0.15),
	})

	addSourcesButton(screen, {
		size = UDim2.fromScale(0.17, 0.07),
		position = UDim2.fromScale(0.985, 0.115),
		anchor = Vector2.new(1, 0),
		zindex = 2,
	})

	local rows: { [SystemId]: Row } = {}
	local function setCells(system: SystemId, cells: number)
		if Store.phase() ~= "Planning" then
			return
		end
		Store.send({ type = "SetCells", system = system, cells = cells })
	end

	for index, system in SYSTEMS do
		local systemColor: Color3 = Ui.SYSTEM_COLORS[system]
		local rowFrame = Ui.panel(screen, {
			name = system,
			size = UDim2.fromScale(0.9, 0.15),
			position = UDim2.fromScale(0.05, 0.29 + (index - 1) * 0.165),
			transparency = 0.05,
		})
		-- Colour strip on the left edge: the system's identity colour.
		Ui.frame(rowFrame, {
			name = "Strip",
			size = UDim2.fromScale(0.01, 0.66),
			position = UDim2.fromScale(0.008, 0.5),
			anchor = Vector2.new(0, 0.5),
			color = systemColor,
			corner = 0.5,
		})
		-- Inside the row, sizes are fractions of the row (row height = 15% of the screen).
		Ui.icon(rowFrame, Ui.ICONS[system], {
			name = "Icon",
			size = UDim2.fromScale(0.075, 0.66),
			position = UDim2.fromScale(0.025, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = systemColor,
		})
		local name = Ui.label(rowFrame, {
			name = "Name",
			size = UDim2.fromScale(0.34, 0.5),
			position = UDim2.fromScale(0.11, 0.06),
			alignX = Enum.TextXAlignment.Left,
			textColor = systemColor,
			maxText = 40,
		})
		local hint = Ui.body(rowFrame, {
			name = "Hint",
			size = UDim2.fromScale(0.34, 0.38),
			position = HINT_POSITION,
			textColor = Ui.COLORS.textSoft,
			maxText = 22,
		})
		local hintIcon = Ui.icon(rowFrame, Ui.ICONS.hourglass, {
			name = "HintIcon",
			size = UDim2.fromScale(0.03, 0.34),
			position = UDim2.fromScale(0.11, 0.75),
			anchor = Vector2.new(0, 0.5),
			tint = ROLE.warning,
			visible = false,
		})

		local slots: { Slot } = {}
		local slotWidth = 0.22 / maxCells
		for slot = 1, maxCells do
			local slotFrame = Ui.frame(rowFrame, {
				name = `Slot{slot}`,
				size = UDim2.fromScale(slotWidth - 0.01, 0.74),
				position = UDim2.fromScale(0.47 + (slot - 1) * slotWidth, 0.5),
				anchor = Vector2.new(0, 0.5),
				color = Ui.COLORS.cellEmpty,
				corner = 0.2,
				stroke = 2,
			})
			local slotIcon = Ui.icon(slotFrame, Ui.ICONS.cell, {
				name = "Cell",
				size = UDim2.fromScale(0.7, 0.7),
				position = UDim2.fromScale(0.5, 0.5),
				anchor = Vector2.new(0.5, 0.5),
				tint = Ui.COLORS.textDark,
				visible = false,
			})
			table.insert(slots, { frame = slotFrame, icon = slotIcon })
		end

		-- Buttons fill 90% of the row height, so they are at least 13% of the screen height.
		local minus = Ui.button(rowFrame, {
			name = "Minus",
			text = "-",
			size = UDim2.fromScale(0.12, 0.9),
			position = UDim2.fromScale(0.72, 0.5),
			anchor = Vector2.new(0, 0.5),
			color = Ui.COLORS.secondary,
			maxText = 72,
		}, function()
			local current = allocationOf(system)
			if current > 0 then
				setCells(system, current - 1)
			end
		end)
		local plus = Ui.button(rowFrame, {
			name = "Plus",
			text = "+",
			size = UDim2.fromScale(0.12, 0.9),
			position = UDim2.fromScale(0.86, 0.5),
			anchor = Vector2.new(0, 0.5),
			color = ROLE.accent,
			maxText = 72,
		}, function()
			local current = allocationOf(system)
			if current >= maxCells then
				showMessage({ key = "error.cells_range" })
			elseif powerLeft() <= 0 then
				showMessage({ key = "error.no_power_left" })
			else
				setCells(system, current + 1)
			end
		end)

		-- Onboarding pointer, just left of the row (hidden unless the guide highlights this row).
		local pointer = Ui.icon(rowFrame, Ui.ICONS.pointer, {
			name = "GuidePointer",
			size = UDim2.fromScale(0.05, 0.6),
			position = UDim2.fromScale(-0.055, 0.5),
			anchor = Vector2.new(0, 0.5),
			aspect = 1,
			tint = ROLE.accent,
			zindex = 3,
			visible = false,
		})

		rows[system] = {
			frame = rowFrame,
			stroke = rowFrame:FindFirstChildOfClass("UIStroke"),
			pointer = pointer,
			name = name,
			hint = hint,
			hintIcon = hintIcon,
			slots = slots,
			minus = minus,
			plus = plus,
		}
	end

	-- Power left: cell icons on top, the number once in the text below (no icons when it is 0).
	local powerPanel = Ui.panel(screen, {
		name = "PowerLeft",
		size = UDim2.fromScale(0.25, 0.15),
		position = UDim2.fromScale(0.05, 0.8),
		corner = 0.25,
		strokeColor = Ui.COLORS.cell,
	})
	local powerIcons = Ui.frame(powerPanel, {
		name = "Cells",
		size = UDim2.fromScale(0.9, 0.42),
		position = UDim2.fromScale(0.5, 0.08),
		anchor = Vector2.new(0.5, 0),
	})
	local powerLayout = Instance.new("UIListLayout")
	powerLayout.FillDirection = Enum.FillDirection.Horizontal
	powerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	powerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	powerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	powerLayout.Padding = UDim.new(0.02, 0)
	powerLayout.Parent = powerIcons
	local maxPower: number = MissionData.POWER.ARRAYS + MissionData.POWER.BATTERY_CELLS
	local powerCells: { ImageLabel } = {}
	for index = 1, maxPower do
		local cellIcon = Ui.icon(powerIcons, Ui.ICONS.cell, {
			name = `Cell{index}`,
			size = UDim2.fromScale(0.2, 1),
			order = index,
			aspect = 1,
			tint = Ui.COLORS.cell,
			visible = false,
		})
		table.insert(powerCells, cellIcon)
	end
	local TEXT_BELOW_SIZE = UDim2.fromScale(0.9, 0.4)
	local TEXT_BELOW_POSITION = UDim2.fromScale(0.5, 0.54)
	local TEXT_ALONE_SIZE = UDim2.fromScale(0.9, 0.7)
	local TEXT_ALONE_POSITION = UDim2.fromScale(0.5, 0.15)
	local powerText = Ui.label(powerPanel, {
		name = "Text",
		size = TEXT_BELOW_SIZE,
		position = TEXT_BELOW_POSITION,
		anchor = Vector2.new(0.5, 0),
		textColor = Ui.COLORS.cell,
		maxText = 32,
	})

	local lastStart = 0
	local startButton = Ui.button(screen, {
		name = "StartShift",
		size = UDim2.fromScale(0.35, 0.15),
		position = UDim2.fromScale(0.6, 0.8),
		color = Ui.COLORS.go,
		icon = Ui.ICONS.rocket,
		maxText = 46,
	}, function()
		if Store.phase() ~= "Planning" or os.clock() - lastStart < START_COOLDOWN then
			return
		end
		lastStart = os.clock()
		Store.send({ type = "StartShift" })
	end)

	local highlighted: { [SystemId]: boolean } = {}
	local later: { [SystemId]: boolean } = {}
	local pulseConnection: RBXScriptConnection? = nil

	local function renderGuide()
		for _, system in SYSTEMS do
			local row = rows[system]
			local on = highlighted[system] == true
			row.pointer.Visible = on
			if not on then
				row.pointer.Position = UDim2.fromScale(-0.055, 0.5)
				if row.stroke then
					row.stroke.Color = ROLE.stroke
					row.stroke.Thickness = STROKE_NORMAL
				end
			end
			local isLater = later[system] == true
			row.hintIcon.Visible = isLater
			row.hint.Position = if isLater then HINT_POSITION_ICON else HINT_POSITION
			if isLater then
				row.hint.Text = Store.t("tip.greenhouse_tomorrow")
				row.hint.TextColor3 = ROLE.warning
			else
				row.hint.Text = Store.t("ui.system_hint." .. system)
				row.hint.TextColor3 = Ui.COLORS.textSoft
			end
		end
	end

	local function pulse()
		local wave = (math.sin(os.clock() * PULSE_SPEED) + 1) / 2
		for _, system in SYSTEMS do
			if highlighted[system] then
				local row = rows[system]
				if row.stroke then
					row.stroke.Color = ROLE.stroke:Lerp(ROLE.accent, 0.4 + 0.6 * wave)
					row.stroke.Thickness = STROKE_NORMAL + (STROKE_PULSE - STROKE_NORMAL) * wave
				end
				row.pointer.Position = UDim2.fromScale(-0.065 + 0.02 * wave, 0.5)
			end
		end
	end

	local function updatePulse()
		local wanted = screen.Visible and next(highlighted) ~= nil
		if wanted and not pulseConnection then
			pulseConnection = RunService.Heartbeat:Connect(pulse)
		elseif not wanted and pulseConnection then
			pulseConnection:Disconnect()
			pulseConnection = nil
		end
	end

	local function setGuide(guide: Guide?)
		table.clear(highlighted)
		table.clear(later)
		if guide then
			for _, system in guide.highlight or {} do
				highlighted[system] = true
			end
			for _, system in guide.later or {} do
				later[system] = true
			end
		end
		renderGuide()
		updatePulse()
	end

	local function render()
		local snap = Store.getSnapshot()
		Ui.setButton(startButton, Store.t("ui.start_shift"))
		for _, system in SYSTEMS do
			local row = rows[system]
			row.name.Text = Store.t("ui.system." .. system)
		end
		renderGuide()
		if not snap then
			return
		end

		dayLabel.Text = Store.t("ui.day", { day = snap.day, total = snap.totalDays })
		local event = snap.todayEvent
		eventBanner.set(Ui.EVENT_ICONS[event] or "", Store.t("event." .. event), Ui.EVENT_COLORS[event])
		meters.render()

		local left = math.max(0, powerLeft())
		for _, system in SYSTEMS do
			local row = rows[system]
			local cells = allocationOf(system)
			for slot, slotView in row.slots do
				local filled = slot <= cells
				slotView.icon.Visible = filled
				slotView.frame.BackgroundColor3 = if filled then Ui.COLORS.cell else Ui.COLORS.cellEmpty
			end
			Ui.setButtonLook(row.minus, cells > 0, Ui.COLORS.secondary)
			Ui.setButtonLook(row.plus, cells < maxCells and left > 0, ROLE.accent)
		end
		local hasCells = left > 0
		powerIcons.Visible = hasCells
		for index, cellIcon in powerCells do
			cellIcon.Visible = index <= left
		end
		powerText.Size = if hasCells then TEXT_BELOW_SIZE else TEXT_ALONE_SIZE
		powerText.Position = if hasCells then TEXT_BELOW_POSITION else TEXT_ALONE_POSITION
		powerText.Text = Store.t("ui.power_left", { n = left })
	end

	local function setVisible(visible: boolean)
		screen.Visible = visible
		updatePulse()
	end

	render()
	return { setVisible = setVisible, render = render, setGuide = setGuide }
end

return PowerBoard
