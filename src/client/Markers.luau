--!strict
-- Space Base Odyssey - task markers: during a shift, a bouncing icon with a short label floats above
-- every enabled task prompt (ProximityPrompt with a "TextKey" attribute), visible from far away.
-- During a storm warning or storm, task markers hide and a shelter marker shows the way to safety.
-- Hidden collectibles (prompts with a "CollectibleId" attribute, or "prompt.collect") never get a
-- marker: they are secrets to discover by exploring.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local TEXT_KEY_ATTRIBUTE = "TextKey"
local CONSOLE_KEY = "prompt.console" -- the power board inside: no marker
local DRILL_KEY = "prompt.drill"
local DELIVER_KEY = "prompt.deliver"
local SHELTER_MARKER = "ShelterDoor"
local COLLECT_KEY = "prompt.collect"
local COLLECTIBLE_ATTRIBUTE = "CollectibleId"
local NO_MARKER_ATTRIBUTE = "NoMarker"

-- Visual tuning (not gameplay numbers).
local MARKER_SIZE = UDim2.fromOffset(150, 96)
local MAX_DISTANCE = 5000
local HEIGHT_ABOVE = 3 -- studs above the top of the prompt's part
local BOUNCE_PIXELS = 12
local BOUNCE_SPEED = 4
local NEAR_EXTRA = 2 -- hide a marker this many studs beyond the prompt's own range (the prompt shows)
local REFRESH_SECONDS = 0.5 -- storm stage follows server time, so re-check a few times per second

local ROLE = Ui.ROLE
local ICONS: { [string]: string } = {
	["prompt.clean"] = Ui.ICONS.panel,
	["prompt.drill"] = Ui.ICONS.ice,
	["prompt.deliver"] = Ui.ICONS.drop,
	["prompt.repair"] = Ui.ICONS.repair,
	["prompt.antenna"] = Ui.ICONS.antenna,
}
local FALLBACK_ICON = Ui.ICONS.target
local SHELTER_ICON = Ui.ICONS.shelter

type Entry = {
	prompt: ProximityPrompt,
	gui: BillboardGui,
	bounce: Frame,
	label: TextLabel,
	icon: ImageLabel,
	phase: number,
	wanted: boolean,
	connections: { RBXScriptConnection },
}

local Markers = {}

local player = Players.LocalPlayer
local entries: { [ProximityPrompt]: Entry } = {}
local started = false
local playerGui: Instance? = nil
local shelterGui: BillboardGui? = nil
local shelterBounce: Frame? = nil

local function promptKey(prompt: ProximityPrompt): string?
	local key = prompt:GetAttribute(TEXT_KEY_ATTRIBUTE)
	if type(key) == "string" and key ~= "" then
		return key
	end
	return nil
end

local function labelText(key: string): string
	local text = Store.t(key)
	if text == key then
		return Store.t("marker.task")
	end
	return text
end

-- Billboard with a round icon badge on top and a label pill below; `bounce` is moved every frame.
-- Returns the gui, the bounce frame, the badge (background colour), the icon image and the label.
local function makeBillboard(
	name: string,
	adornee: Instance,
	offset: Vector3
): (BillboardGui, Frame, Frame, ImageLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Size = MARKER_SIZE
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local bounce = Ui.frame(gui, { name = "Bounce" })
	local badge = Ui.frame(bounce, {
		name = "Badge",
		size = UDim2.fromScale(0.62, 0.62),
		position = UDim2.fromScale(0.5, 0),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.panel,
		transparency = 0.05,
		corner = 0.5,
		stroke = 3,
		strokeColor = ROLE.accent,
		aspect = 1,
		zindex = 2,
	})
	local icon = Ui.icon(badge, FALLBACK_ICON, {
		name = "Icon",
		size = UDim2.fromScale(0.66, 0.66),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.accent,
		zindex = 3,
	})
	local label = Ui.label(bounce, {
		name = "Label",
		size = UDim2.fromScale(1, 0.34),
		position = UDim2.fromScale(0.5, 0.66),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.panel,
		transparency = 0.1,
		corner = 0.5,
		stroke = 2,
		strokeColor = ROLE.accent,
		maxText = 22,
		zindex = 2,
	})
	gui.Parent = playerGui
	return gui, bounce, badge, icon, label
end

local function adorneeOf(prompt: ProximityPrompt): (Instance?, Vector3)
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent, Vector3.new(0, parent.Size.Y / 2 + HEIGHT_ABOVE, 0)
	elseif parent and parent:IsA("Attachment") then
		return parent, Vector3.new(0, HEIGHT_ABOVE + 1, 0)
	end
	return nil, Vector3.zero
end

local function worldPosition(adornee: Instance?): Vector3?
	if adornee and adornee:IsA("BasePart") then
		return adornee.Position
	elseif adornee and adornee:IsA("Attachment") then
		return adornee.WorldPosition
	end
	return nil
end

-- Secrets are never pointed at.
local function isSecret(prompt: ProximityPrompt): boolean
	return prompt:GetAttribute(COLLECTIBLE_ATTRIBUTE) ~= nil
		or prompt:GetAttribute(NO_MARKER_ATTRIBUTE) == true
		or promptKey(prompt) == COLLECT_KEY
end

local function isWanted(entry: Entry, stage: Store.StormStage): boolean
	local prompt = entry.prompt
	local key = promptKey(prompt)
	if key == nil or key == CONSOLE_KEY or not prompt.Enabled or isSecret(prompt) then
		return false
	end
	if Store.phase() ~= "Shift" or stage ~= "none" then
		return false
	end
	-- The water machine is always open during a shift: point at it only when it is needed.
	local stats = Store.getStats()
	local carrying = stats ~= nil and stats.carryingIce
	if key == DELIVER_KEY and not carrying then
		return false
	end
	if key == DRILL_KEY and carrying then
		return false
	end
	return true
end

local function renderEntry(entry: Entry)
	local key = promptKey(entry.prompt)
	if key then
		entry.icon.Image = ICONS[key] or FALLBACK_ICON
		entry.label.Text = labelText(key)
	end
end

local function refresh()
	local stage = Store.stormStage()
	for _, entry in entries do
		entry.wanted = isWanted(entry, stage)
		if not entry.wanted then
			entry.gui.Enabled = false
		end
	end
	-- Shelter marker: during the warning and the storm, until the player is inside the shelter.
	local stats = Store.getStats()
	local showShelter = stage ~= "none" and not (stats ~= nil and stats.sheltered)
	-- The door marker is gone (base rebuilt or streamed out): drop the old billboard and look again.
	local oldGui = shelterGui
	local oldAdornee = if oldGui then oldGui.Adornee else nil
	if oldGui and (oldAdornee == nil or oldAdornee.Parent == nil) then
		oldGui:Destroy()
		shelterGui = nil
		shelterBounce = nil
	end
	if showShelter and not shelterGui then
		local door = Store.findMarker(SHELTER_MARKER)
		if door then
			local gui, bounce, badge, icon, label = makeBillboard("SBO_ShelterMarker", door, Vector3.new(0, 4, 0))
			-- Orange = warnings and the shelter.
			icon.Image = SHELTER_ICON
			icon.ImageColor3 = ROLE.primaryButtonText
			badge.BackgroundColor3 = ROLE.warning
			local stroke = badge:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = ROLE.text
			end
			label.Visible = false
			shelterGui = gui
			shelterBounce = bounce
		end
	end
	if shelterGui then
		shelterGui.Enabled = showShelter
	end
end

local function track(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local prompt = instance :: ProximityPrompt
	if entries[prompt] or promptKey(prompt) == CONSOLE_KEY or isSecret(prompt) then
		return
	end
	local adornee, offset = adorneeOf(prompt)
	if not adornee then
		return
	end
	local gui, bounce, _badge, icon, label = makeBillboard("SBO_TaskMarker", adornee, offset)
	local entry: Entry = {
		prompt = prompt,
		gui = gui,
		bounce = bounce,
		icon = icon,
		label = label,
		phase = math.random() * math.pi * 2,
		wanted = false,
		connections = {},
	}
	entries[prompt] = entry
	table.insert(entry.connections, prompt:GetPropertyChangedSignal("Enabled"):Connect(refresh))
	table.insert(
		entry.connections,
		prompt:GetAttributeChangedSignal(TEXT_KEY_ATTRIBUTE):Connect(function()
			renderEntry(entry)
			refresh()
		end)
	)
	renderEntry(entry)
	refresh()
end

local function untrack(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local entry = entries[instance :: ProximityPrompt]
	if entry then
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		entry.gui:Destroy()
		entries[instance :: ProximityPrompt] = nil
	end
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- Start watching Workspace for task prompts and keep the markers in sync with the mission.
function Markers.start()
	if started then
		return
	end
	started = true
	playerGui = player:WaitForChild("PlayerGui")

	workspace.DescendantAdded:Connect(track)
	workspace.DescendantRemoving:Connect(untrack)
	for _, descendant in workspace:GetDescendants() do
		track(descendant)
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "language" then
			for _, entry in entries do
				renderEntry(entry)
			end
		end
		refresh()
	end)

	local sinceRefresh = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		sinceRefresh += deltaTime
		if sinceRefresh >= REFRESH_SECONDS then
			sinceRefresh = 0
			refresh()
		end
		local t = os.clock()
		local here = rootPosition()
		for _, entry in entries do
			if entry.wanted then
				-- Close enough for the prompt itself to show: hide the marker so they never overlap.
				local position = worldPosition(entry.gui.Adornee)
				local near = here ~= nil
					and position ~= nil
					and (position - here).Magnitude <= entry.prompt.MaxActivationDistance + NEAR_EXTRA
				entry.gui.Enabled = not near
				if not near then
					local lift = math.abs(math.sin(t * BOUNCE_SPEED + entry.phase)) * BOUNCE_PIXELS
					entry.bounce.Position = UDim2.fromOffset(0, -lift)
				end
			end
		end
		if shelterGui and shelterGui.Enabled and shelterBounce then
			local lift = math.abs(math.sin(t * BOUNCE_SPEED * 1.5)) * BOUNCE_PIXELS * 1.5
			shelterBounce.Position = UDim2.fromOffset(0, -lift)
		end
	end)
end

return Markers
