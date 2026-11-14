--!strict
-- Space Base Odyssey - Planning overlay: the power board where the crew shares power cells between systems.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Meters = require(script.Parent.Meters)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef
type SystemId = "LifeSupport" | "Greenhouse" | "Science"

local SYSTEMS: { SystemId } = { "LifeSupport", "Greenhouse", "Science" }
local START_COOLDOWN = 1

local PowerBoard = {}

export type PowerBoardView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
}

type Row = {
	name: TextLabel,
	hint: TextLabel,
	slots: { TextLabel },
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
function PowerBoard.new(root: Frame, showMessage: (ref: TextRef) -> ()): PowerBoardView
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
		size = UDim2.fromScale(0.28, 0.1),
		position = UDim2.fromScale(0.18, 0.03),
		alignX = Enum.TextXAlignment.Left,
		textColor = Ui.COLORS.accent,
		maxText = 48,
		outline = true,
	})
	local eventBanner = Ui.iconText(screen, {
		name = "Event",
		size = UDim2.fromScale(0.31, 0.1),
		position = UDim2.fromScale(0.48, 0.03),
		color = Ui.COLORS.panelLight,
		stroke = 3,
		maxText = 36,
	})

	local meters = Meters.new(screen, {
		size = UDim2.fromScale(0.8, 0.11),
		position = UDim2.fromScale(0.1, 0.15),
	})

	local rows: { [SystemId]: Row } = {}
	local function setCells(system: SystemId, cells: number)
		if Store.phase() ~= "Planning" then
			return
		end
		Store.send({ type = "SetCells", system = system, cells = cells })
	end

	for index, system in SYSTEMS do
		local rowFrame = Ui.frame(screen, {
			name = system,
			size = UDim2.fromScale(0.9, 0.15),
			position = UDim2.fromScale(0.05, 0.29 + (index - 1) * 0.165),
			color = Ui.COLORS.panel,
			transparency = 0.05,
			corner = 0.18,
			stroke = 3,
		})
		-- Inside the row, sizes are fractions of the row (row height = 15% of the screen).
		Ui.icon(rowFrame, Ui.ICONS[system], {
			size = UDim2.fromScale(0.09, 0.84),
			position = UDim2.fromScale(0.01, 0.5),
			anchor = Vector2.new(0, 0.5),
		})
		local name = Ui.label(rowFrame, {
			name = "Name",
			size = UDim2.fromScale(0.34, 0.5),
			position = UDim2.fromScale(0.11, 0.06),
			alignX = Enum.TextXAlignment.Left,
			maxText = 40,
		})
		local hint = Ui.label(rowFrame, {
			name = "Hint",
			size = UDim2.fromScale(0.34, 0.38),
			position = UDim2.fromScale(0.11, 0.56),
			alignX = Enum.TextXAlignment.Left,
			textColor = Ui.COLORS.textSoft,
			maxText = 26,
		})

		local slots: { TextLabel } = {}
		local slotWidth = 0.22 / maxCells
		for slot = 1, maxCells do
			local slotLabel = Ui.label(rowFrame, {
				name = `Slot{slot}`,
				size = UDim2.fromScale(slotWidth - 0.01, 0.74),
				position = UDim2.fromScale(0.47 + (slot - 1) * slotWidth, 0.5),
				anchor = Vector2.new(0, 0.5),
				color = Ui.COLORS.cellEmpty,
				corner = 0.2,
				stroke = 3,
				maxText = 44,
			})
			table.insert(slots, slotLabel)
		end

		-- Buttons fill 90% of the row height, so they are at least 13% of the screen height.
		local minus = Ui.button(rowFrame, {
			name = "Minus",
			text = "-",
			size = UDim2.fromScale(0.12, 0.9),
			position = UDim2.fromScale(0.72, 0.5),
			anchor = Vector2.new(0, 0.5),
			color = Ui.COLORS.minus,
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
			color = Ui.COLORS.plus,
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

		rows[system] = { name = name, hint = hint, slots = slots, minus = minus, plus = plus }
	end

	local powerPanel = Ui.frame(screen, {
		name = "PowerLeft",
		size = UDim2.fromScale(0.42, 0.15),
		position = UDim2.fromScale(0.05, 0.8),
		color = Ui.COLORS.panel,
		corner = 0.25,
		stroke = 3,
		strokeColor = Ui.COLORS.cell,
	})
	local powerIcons = Ui.label(powerPanel, {
		name = "Cells",
		size = UDim2.fromScale(0.3, 0.8),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 48,
	})
	local powerText = Ui.label(powerPanel, {
		name = "Text",
		size = UDim2.fromScale(0.64, 0.8),
		position = UDim2.fromScale(0.34, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = Ui.COLORS.cell,
		maxText = 44,
	})

	local lastStart = 0
	local startButton = Ui.button(screen, {
		name = "StartShift",
		size = UDim2.fromScale(0.44, 0.15),
		position = UDim2.fromScale(0.51, 0.8),
		color = Ui.COLORS.go,
		stroke = 4,
		maxText = 52,
	}, function()
		if Store.phase() ~= "Planning" or os.clock() - lastStart < START_COOLDOWN then
			return
		end
		lastStart = os.clock()
		Store.send({ type = "StartShift" })
	end)

	local function render()
		local snap = Store.getSnapshot()
		startButton.Text = `{Ui.ICONS.rocket} {Store.t("ui.start_shift")}`
		for _, system in SYSTEMS do
			local row = rows[system]
			row.name.Text = Store.t("ui.system." .. system)
			row.hint.Text = Store.t("ui.system_hint." .. system)
		end
		if not snap then
			return
		end

		dayLabel.Text = Store.t("ui.day", { day = snap.day, total = snap.totalDays })
		eventBanner.set(Ui.EVENT_ICONS[snap.todayEvent] or "", Store.t("event." .. snap.todayEvent))
		meters.render()

		local left = math.max(0, powerLeft())
		for _, system in SYSTEMS do
			local row = rows[system]
			local cells = allocationOf(system)
			for slot, slotLabel in row.slots do
				local filled = slot <= cells
				slotLabel.Text = if filled then Ui.ICONS.cell else ""
				slotLabel.BackgroundColor3 = if filled then Ui.COLORS.cell else Ui.COLORS.cellEmpty
			end
			Ui.setButtonLook(row.minus, cells > 0, Ui.COLORS.minus)
			Ui.setButtonLook(row.plus, cells < maxCells and left > 0, Ui.COLORS.plus)
		end
		powerIcons.Text = if left > 0 then string.rep(Ui.ICONS.cell, left) else "0"
		powerText.Text = Store.t("ui.power_left", { n = left })
	end

	local function setVisible(visible: boolean)
		screen.Visible = visible
	end

	render()
	return { setVisible = setVisible, render = render }
end

return PowerBoard
