--!strict
-- Space Base Odyssey - the base meters (air, food, radiation, water) as icon + label + coloured bar +
-- zone icon. Two layouts:
--   "row"    four cells side by side (power board while planning).
--   "column" a compact stacked panel (shift HUD, left column under the objectives), plus a small
--            "data waiting" row while science waits for the antenna.
-- Values glide toward each new Snapshot value and the row flashes on a big change: lime when the
-- change is good for the crew, red when it is bad (radiation going up is bad).
-- Stage 10: Meters.fillRow builds one column row (icon, name, bar with value and zone icon), shared
-- with the HUD's always-on vitals panel (Hud.luau) so both panels look the same.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type MeterId = "air" | "food" | "dose" | "water"

local METER_IDS: { MeterId } = { "air", "food", "dose", "water" }
local METER_MAX = 100 -- display scale: Simulation clamps air, food and dose to 0..100

-- Visual tuning (not gameplay numbers).
local GLIDE_RATE = 5 -- higher = the bar reaches the new value faster
local GLIDE_DONE = 0.02 -- close enough: snap to the target
local FLASH_THRESHOLD = 3 -- a change of at least this many points (of 100) flashes the row
local FLASH_SECONDS = 0.7

local ROLE = Ui.ROLE
local ICONS: { [MeterId]: string } = {
	air = Ui.ICONS.air,
	food = Ui.ICONS.food,
	dose = Ui.ICONS.dose,
	water = Ui.ICONS.drop,
}
local TINTS: { [MeterId]: Color3 } = {
	air = ROLE.air,
	food = ROLE.food,
	dose = ROLE.dose,
	water = Ui.COLORS.ice,
}

local Meters = {}

export type Layout = "row" | "column"

export type MetersView = {
	frame: Frame,
	render: () -> (),
}

type Widget = {
	cell: Frame,
	name: TextLabel,
	bar: Ui.Bar,
	flash: Frame,
	shown: number?, -- value on screen (0..100 scale)
	target: number, -- latest value (0..100 scale)
	units: number, -- water: units for the text
	unitsMax: number,
}

-- Current value of a meter on a 0..100 scale, plus the text to show.
local function readMeter(meter: MeterId): (number?, number, number)
	local snap = Store.getSnapshot()
	if not snap then
		return nil, 0, 0
	end
	if meter == "water" then
		local water, waterMax = Store.water()
		if waterMax <= 0 then
			return nil, 0, 0
		end
		return math.clamp(water / waterMax * METER_MAX, 0, METER_MAX), water, waterMax
	end
	local value: any = (snap :: any)[meter]
	if type(value) ~= "number" then
		return nil, 0, 0
	end
	return value, value, METER_MAX
end

-- Zone of a meter value; water uses the air thresholds (both are "good when high").
local function zoneOf(meter: MeterId, value: number): "green" | "yellow" | "red"
	local zoneMeter: any = if meter == "water" then "air" else meter
	return Simulation.meterZone(value, zoneMeter, MissionData)
end

-- One column row inside `cell`: icon | short name | slim bar with the value and the zone icon.
function Meters.fillRow(cell: Frame, image: string, tint: Color3, z: number): (ImageLabel, TextLabel, Ui.Bar)
	local icon = Ui.icon(cell, image, {
		name = "Icon",
		size = UDim2.fromScale(0.13, 0.78),
		position = UDim2.fromScale(0.01, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = tint,
		zindex = z + 1,
	})
	local name = Ui.label(cell, {
		name = "Name",
		size = UDim2.fromScale(0.36, 0.8),
		position = UDim2.fromScale(0.15, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.text,
		maxText = 16,
		minText = 7,
		zindex = z + 1,
	})
	local bar = Ui.bar(cell, {
		name = "Bar",
		size = UDim2.fromScale(0.47, 0.62),
		position = UDim2.fromScale(0.52, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 14,
		zindex = z + 1,
	})
	return icon, name, bar
end

function Meters.new(parent: Instance, props: Ui.Props, layout: Layout?): MetersView
	local mode: Layout = layout or "row"
	local frame = if mode == "column"
		then Ui.panel(parent, {
			name = props.name or "Meters",
			size = props.size,
			position = props.position,
			anchor = props.anchor,
			transparency = 0.08,
			corner = 0.08,
			stroke = 2,
			zindex = props.zindex,
		})
		else Ui.frame(parent, props)
	frame.Name = props.name or "Meters"
	local z = (props.zindex or 1) + 1

	local widgets: { [MeterId]: Widget } = {}
	local rowCount = #METER_IDS + (if mode == "column" then 1 else 0) -- column: + data waiting row
	local PAD = 0.04 -- column: top and bottom padding (fraction of the panel height)
	local rowHeight = (1 - PAD * 2) / rowCount

	for index, meter in METER_IDS do
		local cell: Frame
		if mode == "row" then
			local count = #METER_IDS
			local gap = 0.015
			local width = (1 - gap * (count - 1)) / count
			cell = Ui.panel(frame, {
				name = meter,
				size = UDim2.fromScale(width, 1),
				position = UDim2.fromScale((index - 1) * (width + gap), 0),
				transparency = 0.1,
				corner = 0.25,
				stroke = 2,
				zindex = z,
			})
		else
			cell = Ui.frame(frame, {
				name = meter,
				size = UDim2.fromScale(0.94, rowHeight * 0.92),
				position = UDim2.fromScale(0.03, PAD + rowHeight * (index - 1)),
				corner = 0.3,
				zindex = z,
			})
		end
		-- Flash overlay: invisible until a big change.
		local flash = Ui.frame(cell, {
			name = "Flash",
			color = ROLE.good,
			transparency = 1,
			corner = 0.3,
			zindex = z,
		})
		local name: TextLabel
		local bar: Ui.Bar
		if mode == "row" then
			Ui.icon(cell, ICONS[meter], {
				size = UDim2.fromScale(0.2, 0.7),
				position = UDim2.fromScale(0.03, 0.5),
				anchor = Vector2.new(0, 0.5),
				tint = TINTS[meter],
				zindex = z + 1,
			})
			name = Ui.label(cell, {
				name = "Name",
				size = UDim2.fromScale(0.72, 0.4),
				position = UDim2.fromScale(0.25, 0.05),
				alignX = Enum.TextXAlignment.Left,
				maxText = 22,
				zindex = z + 1,
			})
			bar = Ui.bar(cell, {
				name = "Bar",
				size = UDim2.fromScale(0.7, 0.44),
				position = UDim2.fromScale(0.25, 0.5),
				maxText = 20,
				zindex = z + 1,
			})
		else
			-- Column row: icon | short label | slim bar with the value.
			local _icon: ImageLabel
			_icon, name, bar = Meters.fillRow(cell, ICONS[meter], TINTS[meter], z)
		end
		widgets[meter] = {
			cell = cell,
			name = name,
			bar = bar,
			flash = flash,
			shown = nil,
			target = 0,
			units = 0,
			unitsMax = 0,
		}
	end

	-- Column only: data waiting for the antenna (hidden while nothing waits).
	local dataRow: Frame? = nil
	local dataText: TextLabel? = nil
	if mode == "column" then
		local row = Ui.frame(frame, {
			name = "DataWaiting",
			size = UDim2.fromScale(0.94, rowHeight * 0.92),
			position = UDim2.fromScale(0.03, PAD + rowHeight * #METER_IDS),
			color = ROLE.panelRaised,
			corner = 0.4,
			stroke = 1,
			strokeColor = ROLE.reward,
			zindex = z,
			visible = false,
		})
		Ui.icon(row, Ui.ICONS.satellite, {
			size = UDim2.fromScale(0.13, 0.78),
			position = UDim2.fromScale(0.01, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = ROLE.reward,
			zindex = z + 1,
		})
		dataText = Ui.label(row, {
			name = "Text",
			size = UDim2.fromScale(0.83, 0.8),
			position = UDim2.fromScale(0.15, 0.5),
			anchor = Vector2.new(0, 0.5),
			alignX = Enum.TextXAlignment.Left,
			textColor = ROLE.text,
			maxText = 15,
			minText = 7,
			zindex = z + 1,
		})
		dataRow = row
	end

	local function draw(meter: MeterId)
		local widget = widgets[meter]
		local value = widget.shown or widget.target
		local zone = zoneOf(meter, value)
		local text: string
		if meter == "water" then
			-- Water counts whole units: the text follows the glide, rounded.
			local units = value / METER_MAX * widget.unitsMax
			text = `{math.floor(units + 0.5)}/{math.floor(widget.unitsMax + 0.5)}`
		else
			text = tostring(math.floor(value + 0.5))
		end
		widget.bar.set(value / METER_MAX, Ui.zoneColor(zone), text, Ui.ZONE_ICONS[zone])
	end

	local function flashRow(widget: Widget, good: boolean)
		widget.flash.BackgroundColor3 = if good then ROLE.good else ROLE.danger
		widget.flash.BackgroundTransparency = 0.35
		TweenService:Create(
			widget.flash,
			TweenInfo.new(FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		):Play()
	end

	local glideConnection: RBXScriptConnection? = nil
	local function glide(deltaTime: number)
		local moving = false
		local alpha = 1 - math.exp(-deltaTime * GLIDE_RATE)
		for _, meter in METER_IDS do
			local widget = widgets[meter]
			local shown = widget.shown
			if shown ~= nil and shown ~= widget.target then
				local nextValue = shown + (widget.target - shown) * alpha
				if math.abs(widget.target - nextValue) < GLIDE_DONE then
					nextValue = widget.target
				else
					moving = true
				end
				widget.shown = nextValue
				if frame.Visible then
					draw(meter)
				end
			end
		end
		if not moving and glideConnection then
			glideConnection:Disconnect()
			glideConnection = nil
		end
	end

	local function render()
		for _, meter in METER_IDS do
			local widget = widgets[meter]
			widget.name.Text = Store.t("ui.meter." .. meter)
			local value, units, unitsMax = readMeter(meter)
			widget.cell.Visible = value ~= nil or meter ~= "water"
			if value == nil then
				continue
			end
			widget.units = units
			widget.unitsMax = unitsMax
			local previous = widget.target
			widget.target = value
			if widget.shown == nil then
				widget.shown = value -- first value: no glide, no flash
			elseif math.abs(value - previous) >= FLASH_THRESHOLD then
				local better = if meter == "dose" then value < previous else value > previous
				flashRow(widget, better)
			end
			draw(meter)
			if widget.shown ~= widget.target and glideConnection == nil then
				glideConnection = RunService.Heartbeat:Connect(glide)
			end
		end
		if dataRow and dataText then
			local pending = Store.pendingScience()
			dataRow.Visible = pending > 0
			if pending > 0 then
				dataText.Text = Store.t("ui.data_waiting", { n = math.floor(pending + 0.5) })
			end
		end
	end

	render()
	return { frame = frame, render = render }
end

return Meters
