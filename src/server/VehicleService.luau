--!strict
-- Space Base Odyssey - the drivable vehicles from the garage (Stage 7 team feedback: "a rover you can
-- drive" and "a lunar garage for two vehicles").
--   * One copy of each vehicle per server (MissionData.BASE.VEHICLES): the moon buggy needs garage
--     level 1, the ice hauler garage level 2 (BaseService.effectiveBuilds().garage). Each waits in its
--     bay (world.garageBays[i], facing out) and disappears when the garage level falls (riders hop off).
--   * Each bay has a prompt: "prompt.take_vehicle" sits the player in the driver seat while the vehicle
--     is parked there; "prompt.return_vehicle" brings it back while it is away and empty. Away from the
--     bay the vehicle itself has a "prompt.take_vehicle" prompt on the driver seat (touching a seat
--     works too). An empty vehicle left away from its bay for ABANDON_SECONDS goes back by itself, and
--     so does one that falls off the map. A vehicle on its side or roof for FLIP_SECONDS is put back
--     on its wheels.
--   * The driver owns the vehicle's physics (network ownership), so driving feels instant. The server
--     drives the motors from the VehicleSeat input too (VehicleClient sets the same values locally).
--   * Hauler cargo: "prompt.load_ice" on the tailgate takes the ice core the player carries
--     (CrewService) up to VEHICLES.hauler.cargo, shown on the bed. Near the habitat's water machine
--     (UNLOAD_RANGE of the world's processor prompt) "prompt.unload_ice" hands them all to
--     MissionService.deliverIce(player, count).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local VehicleModels = require(script.Parent:WaitForChild("VehicleModels"))

type Rig = VehicleModels.Rig
type Params = { [string]: string | number }

type VehicleDef = {
	id: string,
	garage: number,
	maxSpeed: number,
	cargo: number?,
}

type Slot = {
	def: VehicleDef,
	bay: CFrame,
	rig: Rig?,
	cargo: number, -- ice cores on the hauler bed (kept when the hauler goes back to its bay)
	lastUsed: number,
	flipTime: number,
	spawnAt: number?,
	bayPart: BasePart,
	bayPrompt: ProximityPrompt,
	drivePrompt: ProximityPrompt?,
	loadPrompt: ProximityPrompt?,
	unloadPrompt: ProximityPrompt?,
}

-- Technical settings (not gameplay numbers).
local ABANDON_SECONDS = 120 -- an empty vehicle away from its bay this long drives itself home
local PARKED_RADIUS = 7 -- studs from the bay centre that count as parked
local SPAWN_DELAY_SECONDS = 2.5 -- lets the garage finish rising out of the ground first
local WATCH_SECONDS = 0.25
local FLIP_SECONDS = 2
local UPRIGHT_MIN = 0.3 -- chassis UpVector.Y below this counts as tipped over
local RIGHT_LIFT = 3 -- studs above the ground when put back on the wheels
local SPAWN_LIFT = 0.3
local FALL_Y = -80
local MAP_LIMIT = 640
local UNLOAD_RANGE = 25 -- studs (flat) from the water machine
local PROMPT_DISTANCE = 10
local CARGO_PROMPT_DISTANCE = 14
local PROMPT_EXTRA_RANGE = 8 -- server check beyond a prompt's own range (lag)
local BAY_PROMPT_GAP = 2.5 -- the bay prompt stands this far in front of the parked vehicle
local FLOOR_PROBE_UP = 3
local FLOOR_PROBE_DOWN = 20
-- Used only if WorldSites gave no bays: the garage centre from the Stage 7 layout, bays along Z.
local FALLBACK_GARAGE = Vector3.new(95, 0, 75)
local FALLBACK_BAY_SPACING = 16

local VehicleService = {}

local started = false
local world: any = nil
local base: any = nil
local mission: any = nil
local crew: any = nil
local folder: Instance? = nil
local messageRemote: RemoteEvent? = nil
local processorAt: Vector3? = nil
local slots: { Slot } = {}

----------------------------------------------------------------------------------------------------
-- Helpers

local function findMessageRemote(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild(Types.Remotes.FOLDER)
	local remote = if remotes then remotes:FindFirstChild(Types.Remotes.MESSAGE) else nil
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

local function sayTo(player: Player, key: string, params: Params?)
	local remote = messageRemote or findMessageRemote()
	messageRemote = remote
	if remote and player.Parent then
		local text: Types.TextRef = { key = key, params = params }
		remote:FireClient(player, text)
	end
end

local function vehicleDefs(): { VehicleDef }
	local list: { VehicleDef } = {}
	local raw: any = (MissionData.BASE :: any).VEHICLES
	if type(raw) ~= "table" then
		return list
	end
	for _, entry in raw do
		if type(entry) == "table" and type(entry.id) == "string" then
			table.insert(list, {
				id = entry.id,
				garage = if type(entry.garage) == "number" then entry.garage else 1,
				maxSpeed = if type(entry.maxSpeed) == "number" then entry.maxSpeed else 30,
				cargo = if type(entry.cargo) == "number" then entry.cargo else nil,
			})
		end
	end
	return list
end

local function builds(): { [string]: number }
	if base == nil or type(base.effectiveBuilds) ~= "function" then
		return {}
	end
	local ok, result = pcall(base.effectiveBuilds)
	return if ok and type(result) == "table" then result else {}
end

local function levelOf(levels: { [string]: number }, id: string): number
	local value = levels[id]
	return if type(value) == "number" then value else 0
end

local function flatLook(cf: CFrame): Vector3
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Bay CFrames from WorldSites (via the world), or a fallback row in the garage.
local function bayCFrames(count: number): { CFrame }
	local list: { CFrame } = {}
	local given = world and world.garageBays
	if type(given) == "table" then
		for _, value in given do
			if typeof(value) == "CFrame" then
				table.insert(list, value)
			end
		end
	end
	if #list < count then
		warn(`[SpaceBaseOdyssey] world.garageBays has {#list} of {count} bays; using fallback bays`)
		for index = #list + 1, count do
			local offset = (index - (count + 1) / 2) * FALLBACK_BAY_SPACING
			local position = FALLBACK_GARAGE + Vector3.new(0, 0, offset)
			list[index] = CFrame.lookAt(position, position - Vector3.xAxis)
		end
	end
	return list
end

local function excludeList(): { Instance }
	local list: { Instance } = {}
	if folder then
		table.insert(list, folder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Ground height under a point (raycast down), or `fallback`.
local function groundY(position: Vector3, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	params.IgnoreWater = true
	local hit = Workspace:Raycast(position + Vector3.new(0, FLOOR_PROBE_UP, 0), Vector3.new(0, -(FLOOR_PROBE_UP + FLOOR_PROBE_DOWN), 0), params)
	return if hit then hit.Position.Y else fallback
end

-- Where a vehicle stands in its bay: ground under the bay, facing out of the garage.
local function parkingCFrame(slot: Slot): CFrame
	local bay = slot.bay
	local y = groundY(bay.Position, bay.Position.Y)
	local position = Vector3.new(bay.Position.X, y + SPAWN_LIFT, bay.Position.Z)
	return CFrame.lookAt(position, position + flatLook(bay))
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function promptPart(prompt: ProximityPrompt): BasePart?
	local parent = prompt.Parent
	return if parent and parent:IsA("BasePart") then parent else nil
end

local function closeEnough(player: Player, prompt: ProximityPrompt): boolean
	local root = rootOf(player)
	local part = promptPart(prompt)
	if root == nil or part == nil then
		return false
	end
	return (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + PROMPT_EXTRA_RANGE
end

local function newPrompt(parent: Instance, key: string, fallback: string, hold: number, objectKey: string?, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VehiclePrompt"
	prompt.ActionText = fallback -- the client replaces it from TextKey (src/client/Prompts.luau)
	prompt.ObjectText = ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance or PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("TextKey", key)
	if objectKey then
		prompt:SetAttribute("ObjectKey", objectKey)
	end
	prompt.Parent = parent
	return prompt
end

-- Changes a prompt only when something is different (attributes and properties replicate).
local function setPrompt(prompt: ProximityPrompt?, enabled: boolean, key: string?, hold: number?)
	if prompt == nil then
		return
	end
	if key and prompt:GetAttribute("TextKey") ~= key then
		prompt:SetAttribute("TextKey", key)
	end
	if hold and prompt.HoldDuration ~= hold then
		prompt.HoldDuration = hold
	end
	if prompt.Enabled ~= enabled then
		prompt.Enabled = enabled
	end
end

local function occupantOf(seat: BasePart): Humanoid?
	local occupant = (seat :: any).Occupant
	if typeof(occupant) == "Instance" and occupant:IsA("Humanoid") then
		return occupant
	end
	return nil
end

local function playerIn(seat: BasePart): Player?
	local humanoid = occupantOf(seat)
	local character = if humanoid then humanoid.Parent else nil
	return if character then Players:GetPlayerFromCharacter(character) else nil
end

local function anyOccupant(rig: Rig): boolean
	for _, seat in rig.seats do
		if occupantOf(seat) then
			return true
		end
	end
	return false
end

local function alive(rig: Rig): boolean
	return rig.model.Parent ~= nil and rig.chassis.Parent ~= nil and rig.chassis:IsDescendantOf(Workspace)
end

local function isParked(slot: Slot): boolean
	local rig = slot.rig
	return rig ~= nil and flatDistance(rig.chassis.Position, slot.bay.Position) <= PARKED_RADIUS
end

-- The driver owns the physics; with no driver a passenger does; an empty vehicle belongs to the server.
local function setOwner(rig: Rig, player: Player?)
	for _, item in rig.model:GetDescendants() do
		if item:IsA("BasePart") and not item.Anchored and item.AssemblyRootPart == item then
			pcall(function()
				if item:CanSetNetworkOwnership() then
					item:SetNetworkOwner(player)
				end
			end)
		end
	end
end

local function updateOwner(rig: Rig)
	local owner: Player? = nil
	for _, seat in rig.seats do
		owner = playerIn(seat)
		if owner then
			break
		end
	end
	setOwner(rig, owner)
end

local function eject(rig: Rig)
	for _, seat in rig.seats do
		local humanoid = occupantOf(seat)
		if humanoid then
			local seatWeld = seat:FindFirstChild("SeatWeld")
			if seatWeld then
				seatWeld:Destroy()
			end
			humanoid.Sit = false
		end
	end
end

local function processorPosition(): Vector3?
	if processorAt then
		return processorAt
	end
	local prompt = world and world.processorPrompt
	if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
		local parent = prompt.Parent
		if parent and parent:IsA("BasePart") then
			processorAt = parent.Position
		elseif parent and parent:IsA("Attachment") then
			processorAt = parent.WorldPosition
		end
	end
	return processorAt
end

local function nearWaterMachine(rig: Rig): boolean
	if levelOf(builds(), "habitat") < 1 then
		return false
	end
	local target = processorPosition()
	local part = rig.cargoPart
	if target == nil or part == nil then
		return false
	end
	return flatDistance(part.Position, target) <= UNLOAD_RANGE
end

----------------------------------------------------------------------------------------------------
-- Vehicle life cycle

local function sitIn(slot: Slot, player: Player)
	local rig = slot.rig
	local humanoid = humanoidOf(player)
	if rig == nil or humanoid == nil then
		return
	end
	if occupantOf(rig.seat) then
		sayTo(player, "carl.vehicle.busy")
		return
	end
	if humanoid.SeatPart then
		return -- already sitting somewhere
	end
	rig.seat:Sit(humanoid)
end

local function onLoad(slot: Slot, player: Player)
	local rig = slot.rig
	if rig == nil or rig.cargoMax <= 0 or crew == nil then
		return
	end
	if slot.cargo >= rig.cargoMax then
		sayTo(player, "carl.vehicle.full")
		return
	end
	if not crew.isCarrying(player) then
		sayTo(player, "carl.vehicle.need_ice")
		return
	end
	crew.setCarrying(player, false)
	slot.cargo += 1
	VehicleModels.setCargo(rig, slot.cargo)
	sayTo(player, "carl.vehicle.loaded", { n = slot.cargo, max = rig.cargoMax })
end

local function onUnload(slot: Slot, player: Player)
	local rig = slot.rig
	local count = slot.cargo
	if rig == nil or count <= 0 or not nearWaterMachine(rig) then
		return
	end
	local deliver = mission and mission.deliverIce
	if type(deliver) ~= "function" then
		warn("[SpaceBaseOdyssey] MissionService.deliverIce is missing; the hauler keeps its ice")
		sayTo(player, "carl.vehicle.unload_later")
		return
	end
	local ok, result = pcall(deliver, player, count)
	if not ok then
		warn(`[SpaceBaseOdyssey] deliverIce failed: {result}`)
		return
	end
	-- deliverIce may return how many cores it took (number), false for none, or nothing for all.
	local delivered = count
	if result == false then
		delivered = 0
	elseif type(result) == "number" then
		delivered = math.clamp(math.floor(result), 0, count)
	end
	if delivered <= 0 then
		sayTo(player, "carl.vehicle.unload_later")
		return
	end
	slot.cargo -= delivered
	VehicleModels.setCargo(rig, slot.cargo)
	sayTo(player, "carl.vehicle.unloaded", { n = delivered })
end

local function spawnRig(slot: Slot)
	local parent = folder
	if parent == nil then
		return
	end
	local ok, result = pcall(VehicleModels.build, slot.def.id, { maxSpeed = slot.def.maxSpeed, cargo = slot.def.cargo }, parkingCFrame(slot), parent)
	if not ok then
		warn(`[SpaceBaseOdyssey] could not build vehicle {slot.def.id}: {result}`)
		slot.spawnAt = os.clock() + 10 -- try again later
		return
	end
	local rig: Rig = result
	slot.rig = rig
	slot.spawnAt = nil
	slot.lastUsed = os.clock()
	slot.flipTime = 0
	slot.cargo = math.clamp(slot.cargo, 0, rig.cargoMax)
	VehicleModels.setCargo(rig, slot.cargo)
	setOwner(rig, nil)

	local objectKey = `ui.vehicle.{slot.def.id}`
	local drivePrompt = newPrompt(rig.seat, "prompt.take_vehicle", "Drive", 0, objectKey)
	slot.drivePrompt = drivePrompt
	drivePrompt.Triggered:Connect(function(player: Player)
		if slot.rig == rig and closeEnough(player, drivePrompt) then
			sitIn(slot, player)
		end
	end)

	local cargoPart = rig.cargoPart
	if cargoPart and rig.cargoMax > 0 then
		local loadPrompt = newPrompt(cargoPart, "prompt.load_ice", "Load ice", 0.5, objectKey, CARGO_PROMPT_DISTANCE)
		local unloadPrompt = newPrompt(cargoPart, "prompt.unload_ice", "Unload ice", 1, objectKey, CARGO_PROMPT_DISTANCE)
		slot.loadPrompt = loadPrompt
		slot.unloadPrompt = unloadPrompt
		loadPrompt.Triggered:Connect(function(player: Player)
			if slot.rig == rig and closeEnough(player, loadPrompt) then
				onLoad(slot, player)
			end
		end)
		unloadPrompt.Triggered:Connect(function(player: Player)
			if slot.rig == rig and closeEnough(player, unloadPrompt) then
				onUnload(slot, player)
			end
		end)
	else
		slot.loadPrompt = nil
		slot.unloadPrompt = nil
	end

	for _, seat in rig.seats do
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if slot.rig ~= rig then
				return
			end
			slot.lastUsed = os.clock()
			updateOwner(rig)
		end)
	end
end

local function despawn(slot: Slot, sayKey: string?)
	local rig = slot.rig
	if rig == nil then
		return
	end
	if sayKey then
		for _, seat in rig.seats do
			local player = playerIn(seat)
			if player then
				sayTo(player, sayKey)
			end
		end
	end
	eject(rig)
	slot.rig = nil
	slot.drivePrompt = nil
	slot.loadPrompt = nil
	slot.unloadPrompt = nil
	rig.model:Destroy()
end

-- Back to the bay: a fresh copy appears there (the hauler keeps its ice).
local function returnToBay(slot: Slot)
	despawn(slot, nil)
	spawnRig(slot)
end

-- Puts a tipped-over vehicle back on its wheels where it is.
local function rightVehicle(slot: Slot)
	local rig = slot.rig
	if rig == nil then
		return
	end
	setOwner(rig, nil)
	local position = rig.chassis.Position
	local ground = groundY(position, position.Y - rig.rideHeight)
	local look = rig.chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		local up = rig.chassis.CFrame.UpVector
		flat = Vector3.new(-up.X, 0, -up.Z) -- nose straight down or up: use the roof direction
	end
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local target = Vector3.new(position.X, ground + rig.rideHeight + RIGHT_LIFT, position.Z)
	rig.model:PivotTo(CFrame.lookAt(target, target + flat.Unit))
	for _, item in rig.model:GetDescendants() do
		if item:IsA("BasePart") and item.AssemblyRootPart == item then
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
		end
	end
	updateOwner(rig)
	for _, seat in rig.seats do
		local player = playerIn(seat)
		if player then
			sayTo(player, "carl.vehicle.righted")
		end
	end
end

local function refreshPrompts(slot: Slot)
	local rig = slot.rig
	if rig == nil then
		setPrompt(slot.bayPrompt, false)
		return
	end
	local parked = isParked(slot)
	local driverFree = occupantOf(rig.seat) == nil
	if parked then
		setPrompt(slot.bayPrompt, driverFree, "prompt.take_vehicle", 0.5)
	else
		setPrompt(slot.bayPrompt, not anyOccupant(rig), "prompt.return_vehicle", 1)
	end
	setPrompt(slot.drivePrompt, driverFree and not parked)
	if slot.loadPrompt or slot.unloadPrompt then
		local nearBase = nearWaterMachine(rig)
		setPrompt(slot.loadPrompt, slot.cargo < rig.cargoMax and not nearBase)
		setPrompt(slot.unloadPrompt, slot.cargo > 0 and nearBase)
	end
end

local function onBayPrompt(slot: Slot, player: Player)
	local rig = slot.rig
	if rig == nil or not closeEnough(player, slot.bayPrompt) then
		return
	end
	if isParked(slot) then
		sitIn(slot, player)
	elseif anyOccupant(rig) then
		sayTo(player, "carl.vehicle.busy")
	else
		returnToBay(slot)
		sayTo(player, "carl.vehicle.returned")
	end
	refreshPrompts(slot)
end

local function watchSlot(slot: Slot, garage: number, now: number)
	local available = garage >= slot.def.garage
	if not available then
		slot.spawnAt = nil
		if slot.rig then
			despawn(slot, "carl.vehicle.gone")
		end
		refreshPrompts(slot)
		return
	end

	local rig = slot.rig
	if rig and not alive(rig) then
		despawn(slot, nil)
		rig = nil
	end
	if rig == nil then
		local spawnAt = slot.spawnAt
		if spawnAt == nil then
			slot.spawnAt = now + SPAWN_DELAY_SECONDS
		elseif now >= spawnAt then
			spawnRig(slot)
		end
		refreshPrompts(slot)
		return
	end

	local occupied = anyOccupant(rig)
	if occupied then
		slot.lastUsed = now
	end
	local position = rig.chassis.Position
	if position.Y < FALL_Y or math.abs(position.X) > MAP_LIMIT or math.abs(position.Z) > MAP_LIMIT then
		despawn(slot, "carl.vehicle.returned")
		spawnRig(slot)
	elseif not occupied and now - slot.lastUsed >= ABANDON_SECONDS and not isParked(slot) then
		returnToBay(slot)
	elseif rig.chassis.CFrame.UpVector.Y < UPRIGHT_MIN then
		slot.flipTime += WATCH_SECONDS
		if slot.flipTime >= FLIP_SECONDS then
			slot.flipTime = 0
			rightVehicle(slot)
		end
	else
		slot.flipTime = 0
	end
	refreshPrompts(slot)
end

local function watchAll()
	local garage = levelOf(builds(), "garage")
	local now = os.clock()
	for _, slot in slots do
		local ok, err = pcall(watchSlot, slot, garage, now)
		if not ok then
			warn(`[SpaceBaseOdyssey] vehicle {slot.def.id} watch failed: {err}`)
		end
	end
end

-- The server's copy of the drive input (the driver's client does the same every frame).
local function driveStep()
	for _, slot in slots do
		local rig = slot.rig
		if rig and rig.chassis.Parent then
			local seat = rig.seat
			if occupantOf(seat) then
				VehicleModels.applyDrive(rig, seat.ThrottleFloat, seat.SteerFloat)
			else
				VehicleModels.applyDrive(rig, 0, 0)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- worldRefs: WorldBuilder.World (garageBays, processorPrompt); baseService: BaseService
-- (effectiveBuilds, onBuildsChanged); missionService: MissionService (deliverIce); crewService:
-- CrewService (isCarrying, setCarrying).
function VehicleService.start(worldRefs: any, baseService: any, missionService: any, crewService: any)
	assert(not started, "VehicleService already started")
	started = true
	world = worldRefs
	base = baseService
	mission = missionService
	crew = crewService

	local parent = Workspace:FindFirstChild("Base") or Workspace
	local vehicles = Instance.new("Folder")
	vehicles.Name = "Vehicles"
	vehicles.Parent = parent
	folder = vehicles

	local defs = vehicleDefs()
	local bays = bayCFrames(#defs)
	for index, def in defs do
		if not VehicleModels.has(def.id) then
			warn(`[SpaceBaseOdyssey] no vehicle model for {def.id}`)
			continue
		end
		local bay = bays[index]
		local entrance = bay.Position
			+ flatLook(bay) * (VehicleModels.lengthOf(def.id) / 2 + BAY_PROMPT_GAP)
			+ Vector3.new(0, 3, 0)
		local bayPart = Instance.new("Part")
		bayPart.Name = `Bay_{def.id}`
		bayPart.Size = Vector3.one
		bayPart.CFrame = CFrame.new(entrance)
		bayPart.Anchored = true
		bayPart.CanCollide = false
		bayPart.CanTouch = false
		bayPart.CanQuery = false
		bayPart.Transparency = 1
		bayPart.Parent = vehicles
		local slot: Slot = {
			def = def,
			bay = bay,
			rig = nil,
			cargo = 0,
			lastUsed = os.clock(),
			flipTime = 0,
			spawnAt = nil,
			bayPart = bayPart,
			bayPrompt = newPrompt(bayPart, "prompt.take_vehicle", "Drive", 0.5, `ui.vehicle.{def.id}`),
			drivePrompt = nil,
			loadPrompt = nil,
			unloadPrompt = nil,
		}
		slot.bayPrompt.Triggered:Connect(function(player: Player)
			onBayPrompt(slot, player)
		end)
		table.insert(slots, slot)
	end

	if base and type(base.onBuildsChanged) == "function" then
		base.onBuildsChanged(function()
			watchAll()
		end)
	end

	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(driveStep)
		if not ok then
			warn(`[SpaceBaseOdyssey] vehicle drive failed: {err}`)
		end
	end)
	task.spawn(function()
		while true do
			watchAll()
			task.wait(WATCH_SECONDS)
		end
	end)
end

-- Gets the player off any seat (call before teleporting a character: a seated character is welded to
-- its seat and would drag the whole vehicle along).
function VehicleService.unseat(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if humanoid == nil or seat == nil then
		return
	end
	local seatWeld = seat:FindFirstChild("SeatWeld")
	if seatWeld then
		seatWeld:Destroy()
	end
	humanoid.Sit = false
end

-- The vehicle the player is sitting in (driver or passenger), or nil.
function VehicleService.vehicleOf(player: Player): string?
	for _, slot in slots do
		local rig = slot.rig
		if rig then
			for _, seat in rig.seats do
				if playerIn(seat) == player then
					return slot.def.id
				end
			end
		end
	end
	return nil
end

return VehicleService
