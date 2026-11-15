--!strict
-- Space Base Odyssey - task markers: a bouncing icon with a short label floats above an enabled task
-- prompt (ProximityPrompt with a "TextKey" attribute) during a shift and in base mode. To keep the
-- screen calm a marker shows only when it matters:
--   * the player is near it (NEAR_SHOW studs), or
--   * it is where C.A.R.L.'s guidance beam points now (CarlDrone.currentTarget()), or
--   * it belongs to the current mission objective (the first unfinished one with a task prompt).
-- Markers of disabled prompts never show, and markers fade in and out. Close enough for the prompt
-- itself to show, the marker hides so they never overlap.
-- The label is the prompt's own text with its {placeholders} filled from the "TextParams" JSON
-- attribute (the same values Prompts.luau uses), so no "{n}" ever shows.
-- During a storm warning or storm, task markers hide and a shelter marker shows the way to safety.
-- Hidden collectibles (prompts with a "CollectibleId" attribute, or "prompt.collect") never get a
-- marker: they are secrets to discover by exploring.
-- Stage 9 (habitat tree): in base mode a LOCKED build pad near the player (Workspace.Base.BuildPads)
-- shows a grey lock marker with what it waits for: "Needs base level N" when the habitat is too low
-- for the pad's next level (pad attribute SBO_HabNeed, else BaseBuild.habitatNeeded), or "Build X
-- first" when a required build is missing (SBO_Locked). Pads at their top level or under way never
-- get one.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local CarlDrone = require(script.Parent.CarlDrone)

local TEXT_KEY_ATTRIBUTE = "TextKey"
local TEXT_PARAMS_ATTRIBUTE = "TextParams"
local CONSOLE_KEY = "prompt.console" -- the power board inside: no marker
local DRILL_KEY = "prompt.drill"
-- Stage 9: a pad locked by the base level keeps its prompt on with this text; its grey lock marker
-- (refreshLocks) already says so, so it gets no task marker.
local HABITAT_LOCK_KEY = "prompt.need_habitat"
local DELIVER_KEY = "prompt.deliver"
local CRATE_KEY = "prompt.take_crate"
local SHELTER_MARKER = "ShelterDoor"
local COLLECT_KEY = "prompt.collect"
local COLLECTIBLE_ATTRIBUTE = "CollectibleId"
local NO_MARKER_ATTRIBUTE = "NoMarker"
local BUILD_OBJECTIVE_PREFIX = "build_"

-- Visual tuning (not gameplay numbers).
local MARKER_SIZE = UDim2.fromOffset(150, 96)
local MAX_DISTANCE = 5000
local HEIGHT_ABOVE = 3 -- studs above the top of the prompt's part
local BOUNCE_PIXELS = 12
local BOUNCE_SPEED = 4
local NEAR_EXTRA = 2 -- hide a marker this many studs beyond the prompt's own range (the prompt shows)
local NEAR_SHOW = 25 -- studs: any task marker this close shows (kept small: a calm screen)
local CARL_MATCH_RADIUS = 10 -- studs: prompts this close to C.A.R.L.'s guidance marker part
local FADE_SECONDS = 0.3
local REFRESH_SECONDS = 0.5 -- storm stage follows server time, so re-check a few times per second
local LOCK_SHOW = 30 -- studs: a locked pad this close shows what it waits for
local LOCK_HEIGHT = 3 -- studs above the top of the pad

local ROLE = Ui.ROLE
local ICON = Ui.Icons
local ICONS: { [string]: string } = {
	["prompt.clean"] = ICON.panel,
	["prompt.drill"] = ICON.ice,
	["prompt.deliver"] = ICON.drop,
	["prompt.repair"] = ICON.repairKit, -- the tool that fixes it (not the wrench)
	["prompt.antenna"] = ICON.antenna,
	["prompt.take_crate"] = ICON.crate,
	["prompt.deliver_crate"] = ICON.crate,
	["prompt.assemble"] = ICON.failure, -- the wrench (the tool it needs)
	["prompt.build"] = ICON.build,
	["prompt.build_free"] = ICON.build,
	["prompt.upgrade"] = ICON.upgrade,
	["prompt.scan"] = ICON.explore,
	["prompt.claim_silo"] = ICON.silo,
	["prompt.pick_food"] = ICON.food,
	["prompt.lab"] = ICON.flask,
	["prompt.take_vehicle"] = ICON.car,
	["prompt.return_vehicle"] = ICON.car,
	["prompt.load_ice"] = ICON.truck,
	["prompt.unload_ice"] = ICON.truck,
}
local FALLBACK_ICON = ICON.target
local SHELTER_ICON = ICON.shield

-- Task prompts per mission objective (TextKey of their prompts).
local OBJECTIVE_KEYS: { [string]: { [string]: boolean } } = {
	clean_panel = { ["prompt.clean"] = true },
	drill_ice = { [DRILL_KEY] = true },
	repair_leak = { ["prompt.repair"] = true },
	align_antenna = { ["prompt.antenna"] = true },
}

-- One transparency property of one GUI object, with its value when fully shown.
type Fade = { object: Instance, property: string, base: number }

type Entry = {
	prompt: ProximityPrompt,
	gui: BillboardGui,
	bounce: Frame,
	label: TextLabel,
	icon: ImageLabel,
	fades: { Fade },
	phase: number,
	eligible: boolean, -- enabled task prompt, right phase (refresh)
	alpha: number, -- 0 hidden .. 1 shown (fades toward the wanted state)
	shownAlpha: number, -- alpha last applied to the GUI
	connections: { RBXScriptConnection },
}

-- Stage 9: a lock marker over a locked build pad. `text` = what it waits for (nil = not locked).
type LockEntry = {
	pad: BasePart,
	gui: BillboardGui,
	bounce: Frame,
	label: TextLabel,
	fades: { Fade },
	phase: number,
	text: string?,
	alpha: number,
	shownAlpha: number,
}

local Markers = {}

local player = Players.LocalPlayer
local entries: { [ProximityPrompt]: Entry } = {}
local lockEntries: { [BasePart]: LockEntry } = {}
local objectivePrompts: { [ProximityPrompt]: boolean } = {}
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

-- The prompt's {placeholder} values: a JSON object in an attribute, or nil when missing or broken.
local function readParams(prompt: ProximityPrompt, attribute: string): { [string]: string | number }?
	local raw = prompt:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, decoded = pcall(function(): any
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil
	end
	local params: { [string]: string | number } = {}
	for name, value in decoded do
		if type(name) == "string" and (type(value) == "string" or type(value) == "number") then
			params[name] = value
		end
	end
	return params
end

local function hasPlaceholder(text: string): boolean
	return string.find(text, "{", 1, true) ~= nil
end

-- The label: the prompt's text with its values filled in; never a raw "{n}".
local function labelText(prompt: ProximityPrompt, key: string): string
	local text = Store.t(key, readParams(prompt, TEXT_PARAMS_ATTRIBUTE))
	if text ~= key and not hasPlaceholder(text) then
		return text
	end
	local action = prompt.ActionText
	if action ~= "" and not hasPlaceholder(action) then
		return action
	end
	return Store.t("marker.task")
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

-- Every transparency the fade drives, with its fully shown value.
local function collectFades(root: Instance): { Fade }
	local fades: { Fade } = {}
	local function add(object: Instance, property: string, base: number)
		table.insert(fades, { object = object, property = property, base = base })
	end
	for _, item in root:GetDescendants() do
		if item:IsA("UIStroke") then
			add(item, "Transparency", item.Transparency)
		elseif item:IsA("TextLabel") then
			add(item, "BackgroundTransparency", item.BackgroundTransparency)
			add(item, "TextTransparency", item.TextTransparency)
			add(item, "TextStrokeTransparency", item.TextStrokeTransparency)
		elseif item:IsA("ImageLabel") then
			add(item, "BackgroundTransparency", item.BackgroundTransparency)
			add(item, "ImageTransparency", item.ImageTransparency)
		elseif item:IsA("Frame") then
			add(item, "BackgroundTransparency", item.BackgroundTransparency)
		end
	end
	return fades
end

-- Task markers and lock markers fade the same way.
type Fadeable = { gui: BillboardGui, fades: { Fade }, alpha: number, shownAlpha: number }

local function applyAlpha(entry: Fadeable)
	local alpha = entry.alpha
	if alpha == entry.shownAlpha then
		return
	end
	entry.shownAlpha = alpha
	for _, fade in entry.fades do
		(fade.object :: any)[fade.property] = 1 - (1 - fade.base) * alpha
	end
	entry.gui.Enabled = alpha > 0
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

local function carryingIce(): boolean
	local stats = Store.getStats()
	return stats ~= nil and stats.carryingIce
end

local function carryingCrate(): boolean
	return player:GetAttribute("SBO_CarryingCrate") == true or Store.carryingCrate()
end

-- An enabled task prompt in a phase with markers (a shift without a storm, or base mode).
local function isEligible(entry: Entry, stage: Store.StormStage): boolean
	local prompt = entry.prompt
	local key = promptKey(prompt)
	if key == nil or key == CONSOLE_KEY or key == HABITAT_LOCK_KEY or not prompt.Enabled or isSecret(prompt) then
		return false
	end
	local phase = Store.phase()
	if not ((phase == "Shift" and stage == "none") or Store.isBaseMode()) then
		return false
	end
	-- The water machine is always open: point at it only when it is needed.
	local carrying = carryingIce()
	if key == DELIVER_KEY and not carrying then
		return false
	end
	if key == DRILL_KEY and carrying then
		return false
	end
	return true
end

-- The build pad prompt of one structure (Workspace.Base.BuildPads.<id>), or nil.
local function padPrompt(id: string): (ProximityPrompt?, Instance?)
	local base = workspace:FindFirstChild("Base")
	local pads = if base then base:FindFirstChild("BuildPads") else nil
	local pad = if pads then pads:FindFirstChild(id) else nil
	if pad == nil then
		return nil, nil
	end
	-- A pad has two prompts (BuildPrompt, AssemblePrompt) and only one is on: prefer the enabled one.
	local first: ProximityPrompt? = nil
	for _, item in pad:GetDescendants() do
		if item:IsA("ProximityPrompt") then
			if item.Enabled then
				return item, pad
			end
			first = first or item
		end
	end
	return first, pad
end

-- Prompts of the current mission objective: the first unfinished objective with an eligible task
-- prompt (during a shift).
local function refreshObjectivePrompts()
	table.clear(objectivePrompts)
	if Store.phase() ~= "Shift" then
		return
	end
	local mission = Store.mission()
	local objectives = if mission then mission.objectives else nil
	if type(objectives) ~= "table" then
		return
	end
	for _, objective in objectives do
		if objective.done then
			continue
		end
		local id = objective.id
		local keys: { [string]: boolean }? = OBJECTIVE_KEYS[id]
		if id == "deliver_ice" or id == "deliver_ice_total" then
			keys = { [if carryingIce() then DELIVER_KEY else DRILL_KEY] = true }
		elseif string.sub(id, 1, #BUILD_OBJECTIVE_PREFIX) == BUILD_OBJECTIVE_PREFIX then
			local prompt, pad = padPrompt(string.sub(id, #BUILD_OBJECTIVE_PREFIX + 1))
			local entry = if prompt then entries[prompt] else nil
			if entry and entry.eligible then
				objectivePrompts[entry.prompt] = true
				-- Parts needed and none in hand: the crate at the lander too.
				if pad and pad:GetAttribute("SBO_Phase") == "crate" and not carryingCrate() then
					keys = { [CRATE_KEY] = true }
				else
					return
				end
			end
		end
		if keys then
			local found = false
			for prompt, entry in entries do
				local key = promptKey(prompt)
				if entry.eligible and key ~= nil and keys[key] then
					objectivePrompts[prompt] = true
					found = true
				end
			end
			if found then
				return
			end
		end
	end
end

-- Is this marker where C.A.R.L. points now? The same Part / Attachment, or (for a guidance marker
-- part in Workspace.Base.Markers) a prompt right beside it.
local function isCarlTarget(entry: Entry, target: Instance?, targetPosition: Vector3?, position: Vector3?): boolean
	if target == nil then
		return false
	end
	local adornee = entry.gui.Adornee
	if adornee == target or entry.prompt.Parent == target then
		return true
	end
	local parent = target.Parent
	if targetPosition and position and parent and parent.Name == "Markers" then
		return (position - targetPosition).Magnitude <= CARL_MATCH_RADIUS
	end
	return false
end

local function renderEntry(entry: Entry)
	local key = promptKey(entry.prompt)
	if key then
		entry.icon.Image = ICONS[key] or FALLBACK_ICON
		entry.label.Text = labelText(entry.prompt, key)
	end
end

-- Stage 9: what a locked pad waits for, or nil (not locked, at its top level, or under way).
local function lockText(pad: BasePart): string?
	local phase = pad:GetAttribute("SBO_Phase")
	if phase == "crate" or phase == "assemble" then
		return nil
	end
	local idValue = pad:GetAttribute("BuildId")
	local id = if type(idValue) == "string" then idValue else pad.Name
	local def = BaseBuild.buildDef(MissionData, id)
	if def == nil then
		return nil
	end
	local levelValue = pad:GetAttribute("SBO_Level")
	local level = if type(levelValue) == "number" then levelValue else Store.buildLevel(id)
	if level >= def.maxLevel then
		return nil
	end
	local habNeed = pad:GetAttribute("SBO_HabNeed")
	if type(habNeed) ~= "number" then
		habNeed = BaseBuild.habitatNeeded(MissionData, id, level + 1)
	end
	if id ~= "habitat" and type(habNeed) == "number" and Store.buildLevel("habitat") < habNeed then
		return Store.t("base.why.habitat_n", { n = habNeed })
	end
	if pad:GetAttribute("SBO_Locked") == true then
		for needId, needLevel in def.requires do
			if Store.buildLevel(needId) < needLevel then
				return Store.t("panel.needs_build", { name = Store.t("build." .. needId .. ".name") })
			end
		end
	end
	return nil
end

-- Lock markers follow the pads in Workspace.Base.BuildPads (pads can be rebuilt).
local function refreshLocks()
	for pad, entry in lockEntries do
		if pad.Parent == nil then
			entry.gui:Destroy()
			lockEntries[pad] = nil
		end
	end
	local base = workspace:FindFirstChild("Base")
	local pads = if base then base:FindFirstChild("BuildPads") else nil
	local showLocks = Store.isBaseMode() and Store.stormStage() == "none"
	if pads == nil then
		return
	end
	for _, item in pads:GetChildren() do
		if not item:IsA("BasePart") then
			continue
		end
		local pad = item :: BasePart
		local text = if showLocks then lockText(pad) else nil
		local entry = lockEntries[pad]
		if entry == nil then
			if text == nil then
				continue
			end
			local gui, bounce, badge, icon, label =
				makeBillboard("SBO_LockMarker", pad, Vector3.new(0, pad.Size.Y / 2 + LOCK_HEIGHT, 0))
			-- Grey and orange: not yet, but it will open.
			icon.Image = ICON.lock
			icon.ImageColor3 = ROLE.textDim
			local badgeStroke = badge:FindFirstChildOfClass("UIStroke")
			if badgeStroke then
				badgeStroke.Color = ROLE.warning
			end
			local labelStroke = label:FindFirstChildOfClass("UIStroke")
			if labelStroke then
				labelStroke.Color = ROLE.warning
			end
			entry = {
				pad = pad,
				gui = gui,
				bounce = bounce,
				label = label,
				fades = collectFades(gui),
				phase = math.random() * math.pi * 2,
				text = nil,
				alpha = 0,
				shownAlpha = -1,
			}
			lockEntries[pad] = entry
			applyAlpha(entry :: LockEntry)
		end
		local lock = entry :: LockEntry
		lock.text = text
		if text then
			lock.label.Text = text
		end
	end
end

local function refresh()
	local stage = Store.stormStage()
	for _, entry in entries do
		entry.eligible = isEligible(entry, stage)
	end
	refreshObjectivePrompts()
	refreshLocks()
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
		fades = collectFades(gui),
		phase = math.random() * math.pi * 2,
		eligible = false,
		alpha = 0,
		shownAlpha = -1,
		connections = {},
	}
	entries[prompt] = entry
	applyAlpha(entry)
	table.insert(entry.connections, prompt:GetPropertyChangedSignal("Enabled"):Connect(refresh))
	table.insert(
		entry.connections,
		prompt.AttributeChanged:Connect(function(attribute: string)
			if attribute == TEXT_KEY_ATTRIBUTE or attribute == TEXT_PARAMS_ATTRIBUTE then
				renderEntry(entry)
				refresh()
			end
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
		objectivePrompts[instance :: ProximityPrompt] = nil
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
		local carlTarget = CarlDrone.currentTarget()
		local carlPosition = worldPosition(carlTarget)
		local step = deltaTime / FADE_SECONDS
		for _, entry in entries do
			local wanted = false
			if entry.eligible then
				local position = worldPosition(entry.gui.Adornee)
				local distance = if here and position then (position - here).Magnitude else math.huge
				-- Close enough for the prompt itself to show: hide the marker so they never overlap.
				local promptShows = distance <= entry.prompt.MaxActivationDistance + NEAR_EXTRA
				wanted = not promptShows
					and (
						distance <= NEAR_SHOW
						or objectivePrompts[entry.prompt] == true
						or isCarlTarget(entry, carlTarget, carlPosition, position)
					)
			end
			local goal = if wanted then 1 else 0
			if entry.alpha ~= goal then
				entry.alpha = if wanted then math.min(1, entry.alpha + step) else math.max(0, entry.alpha - step)
			end
			applyAlpha(entry)
			if entry.alpha > 0 then
				local lift = math.abs(math.sin(t * BOUNCE_SPEED + entry.phase)) * BOUNCE_PIXELS
				entry.bounce.Position = UDim2.fromOffset(0, -lift)
			end
		end
		-- Locked pads close by: what they wait for.
		for pad, lock in lockEntries do
			local wanted = false
			if lock.text ~= nil and here then
				wanted = (pad.Position - here).Magnitude <= LOCK_SHOW
			end
			local goal = if wanted then 1 else 0
			if lock.alpha ~= goal then
				lock.alpha = if wanted then math.min(1, lock.alpha + step) else math.max(0, lock.alpha - step)
			end
			applyAlpha(lock)
			if lock.alpha > 0 then
				local lift = math.abs(math.sin(t * BOUNCE_SPEED * 0.6 + lock.phase)) * BOUNCE_PIXELS * 0.5
				lock.bounce.Position = UDim2.fromOffset(0, -lift)
			end
		end
		if shelterGui and shelterGui.Enabled and shelterBounce then
			local lift = math.abs(math.sin(t * BOUNCE_SPEED * 1.5)) * BOUNCE_PIXELS * 1.5
			shelterBounce.Position = UDim2.fromOffset(0, -lift)
		end
	end)
end

return Markers
