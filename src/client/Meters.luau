--!strict
-- Space Base Odyssey - the three base meters (air, food, dose) as icon + label + coloured bar + zone icon.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type Snapshot = Store.Snapshot

local METER_IDS: { "air" | "food" | "dose" } = { "air", "food", "dose" }
local METER_MAX = 100 -- display scale: Simulation clamps every meter to 0..100

local Meters = {}

export type MetersView = {
	frame: Frame,
	render: () -> (),
}

function Meters.new(parent: Instance, props: Ui.Props): MetersView
	local frame = Ui.frame(parent, props)
	frame.Name = "Meters"

	type Widget = { name: TextLabel, bar: Ui.Bar }
	local widgets: { [string]: Widget } = {}

	for index, meter in METER_IDS do
		local cell = Ui.panel(frame, {
			name = meter,
			size = UDim2.fromScale(0.32, 1),
			position = UDim2.fromScale((index - 1) * 0.34, 0),
			transparency = 0.1,
			corner = 0.25,
			stroke = 2,
		})
		Ui.icon(cell, Ui.ICONS[meter], {
			size = UDim2.fromScale(0.2, 0.7),
			position = UDim2.fromScale(0.03, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = (Ui.ROLE :: any)[meter],
		})
		local name = Ui.label(cell, {
			name = "Name",
			size = UDim2.fromScale(0.72, 0.4),
			position = UDim2.fromScale(0.25, 0.05),
			alignX = Enum.TextXAlignment.Left,
			maxText = 24,
		})
		local bar = Ui.bar(cell, {
			name = "Bar",
			size = UDim2.fromScale(0.7, 0.44),
			position = UDim2.fromScale(0.25, 0.5),
			maxText = 22,
		})
		widgets[meter] = { name = name, bar = bar }
	end

	local function render()
		local snap = Store.getSnapshot()
		for _, meter in METER_IDS do
			local widget = widgets[meter]
			widget.name.Text = Store.t("ui.meter." .. meter)
			if snap then
				local value: number = (snap :: any)[meter] or 0
				local zone = Simulation.meterZone(value, meter, MissionData)
				local shown = math.floor(value + 0.5)
				widget.bar.set(value / METER_MAX, Ui.zoneColor(zone), tostring(shown), Ui.ZONE_ICONS[zone])
			end
		end
	end

	render()
	return { frame = frame, render = render }
end

return Meters
