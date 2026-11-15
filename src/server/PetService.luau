--!strict
-- Space Base Odyssey - pets that follow their astronaut around the base.
-- A player's equipped pet (BaseService.equipped(player).pet, "none" = no pet) is built from the Parts
-- data in Shared.PetModels (Santiago's models), scaled to about 2.8 studs tall, and placed in
-- Workspace.Pets.<UserId>. Pets are anchored and never collide, block rays or cast shadows: they are
-- only for fun and never change the game. The server moves them about 20 times a second toward a
-- spot behind-left of the player, on the ground, with a small hop while walking.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetModels = require(Shared:WaitForChild("PetModels"))
local Types = require(Shared:WaitForChild("Types"))

-- The parts of BaseService this module uses.
export type BaseApi = {
	equipped: (player: Player) -> Types.Equipped?,
	onEquippedChanged: (listener: (player: Player) -> ()) -> (),
}

-- Mirrors PetModels.PetPart.
type PetRow = {
	name: string,
	shape: string,
	size: { number },
	cframe: { number },
	color: { number },
	material: string,
	transparency: number,
	reflectance: number,
}

type Pet = {
	id: string,
	model: Model,
	parts: { BasePart },
	offsets: { CFrame }, -- each part relative to the pet's root (bottom centre, facing -Z)
	placed: boolean,
	position: Vector3, -- the root on the ground, without the hop
	yaw: number,
	hop: number,
}

local MODELS: { [string]: { PetRow } } = PetModels :: any

local PET_HEIGHT = 2.8 -- studs tall when following
local FOLLOW_OFFSET = Vector3.new(-3.2, 0, 3.2) -- behind-left of the player's root (root faces -Z)
local STEP_SECONDS = 1 / 20
local MAX_STEP_SECONDS = 0.25
local SMOOTHING = 7 -- higher follows more tightly
local TURN_SMOOTHING = 10
local SNAP_DISTANCE = 40
local MOVE_SPEED_MIN = 0.6 -- studs per second; slower counts as standing still
local HOP_HEIGHT = 0.45
local HOP_RATE = 11 -- radians per second of the hop wave
local RAY_UP = 2 -- the ground ray starts this far above the player's root (stays under ceilings)
local RAY_DOWN = 40
local FEET_BELOW_ROOT = 3 -- where the ground is when the ray finds nothing

local PetService = {}

local started = false
local baseApi: BaseApi? = nil
local folder: Folder? = nil
local pets: { [Player]: Pet } = {}

----------------------------------------------------------------------------------------------------
-- Building a pet

local function materialOf(name: string): Enum.Material
	local ok, value = pcall(function(): any
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(value) == "EnumItem" then
		return value :: Enum.Material
	end
	return Enum.Material.SmoothPlastic
end

local function rowFrame(row: PetRow, scale: number, lift: number): CFrame
	local c = row.cframe
	return CFrame.new(c[1] * scale, (c[2] + lift) * scale, c[3] * scale, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		:Orthonormalize()
end

-- Lowest and highest point of the model (its world-axis box), in model studs.
local function verticalBounds(rows: { PetRow }): (number, number)
	local low, high = math.huge, -math.huge
	for _, row in rows do
		local c, s = row.cframe, row.size
		local half = (math.abs(c[7]) * s[1] + math.abs(c[8]) * s[2] + math.abs(c[9]) * s[3]) / 2
		low = math.min(low, c[2] - half)
		high = math.max(high, c[2] + half)
	end
	return low, high
end

local function makePart(row: PetRow, scale: number): BasePart
	local s = row.size
	local size = Vector3.new(s[1], s[2], s[3]) * scale
	local part: BasePart
	if row.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if row.shape == "Ball" then
			if math.abs(s[1] - s[2]) < 0.01 and math.abs(s[1] - s[3]) < 0.01 then
				block.Shape = Enum.PartType.Ball
			else
				-- Roblox balls are always round; a sphere mesh keeps the egg shape of the model.
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = block
			end
		elseif row.shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		end
		part = block
	end
	part.Name = row.name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = materialOf(row.material)
	part.Color = Color3.fromRGB(row.color[1], row.color[2], row.color[3])
	part.Transparency = row.transparency
	part.Reflectance = row.reflectance
	return part
end

local function petsFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local found = workspace:FindFirstChild("Pets")
	local created: Folder
	if found and found:IsA("Folder") then
		created = found :: Folder
	else
		created = Instance.new("Folder")
		created.Name = "Pets"
		created.Parent = workspace
	end
	folder = created
	return created
end

local function buildPet(player: Player, id: string, rows: { PetRow }): Pet
	local low, high = verticalBounds(rows)
	local bottom = math.min(low, 0)
	local scale = PET_HEIGHT / math.max(high - bottom, 0.1)
	local lift = -bottom -- so the lowest point stands on the ground

	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	model:SetAttribute("PetId", id)
	model:SetAttribute("OwnerUserId", player.UserId)
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, row in rows do
		local part = makePart(row, scale)
		local offset = rowFrame(row, scale, lift)
		part.CFrame = CFrame.new(0, 1000, 0) * offset -- out of sight until the first follow step
		part.Parent = model
		table.insert(parts, part)
		table.insert(offsets, offset)
	end
	model.Parent = petsFolder()
	return {
		id = id,
		model = model,
		parts = parts,
		offsets = offsets,
		placed = false,
		position = Vector3.zero,
		yaw = 0,
		hop = 0,
	}
end

local function removePet(player: Player)
	local pet = pets[player]
	if pet then
		pets[player] = nil
		pet.model:Destroy()
	end
end

-- Shows the pet `player` has equipped now (or none).
local function refresh(player: Player)
	if player.Parent == nil then
		removePet(player)
		return
	end
	local api = baseApi
	local equipped = if api then api.equipped(player) else nil
	local id = if equipped then equipped.pet else "none"
	local rows = MODELS[id]
	if rows == nil then
		id = "none"
	end
	local current = pets[player]
	if current and current.id == id and current.model.Parent then
		return
	end
	removePet(player)
	if rows then
		local ok, result = pcall(buildPet, player, id, rows)
		if ok then
			pets[player] = result
		else
			warn(`[SpaceBaseOdyssey] could not build pet {id} for {player.Name}: {result}`)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Following

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true -- blueprints and effects do not count as ground

local function groundY(point: Vector3, rootY: number): number
	local origin = Vector3.new(point.X, rootY + RAY_UP, point.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -(RAY_UP + RAY_DOWN), 0), rayParams)
	if hit then
		return hit.Position.Y
	end
	return rootY - FEET_BELOW_ROOT
end

-- The shortest turn from `from` to `to`, in radians.
local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

local function step(dt: number)
	if next(pets) == nil then
		return
	end
	local exclude: { Instance } = { petsFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude

	local alpha = 1 - math.exp(-SMOOTHING * dt)
	local turnAlpha = 1 - math.exp(-TURN_SMOOTHING * dt)
	for player, pet in pets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") or pet.model.Parent == nil then
			continue
		end
		local rootFrame = (root :: BasePart).CFrame
		local spot = rootFrame:PointToWorldSpace(FOLLOW_OFFSET)
		local target = Vector3.new(spot.X, groundY(spot, rootFrame.Position.Y), spot.Z)

		local previous = pet.position
		if not pet.placed or (target - previous).Magnitude > SNAP_DISTANCE then
			pet.position = target
			pet.placed = true
			previous = target
		else
			pet.position = previous:Lerp(target, alpha)
		end

		local moved = pet.position - previous
		local flat = Vector3.new(moved.X, 0, moved.Z)
		local targetYaw: number
		if flat.Magnitude / dt > MOVE_SPEED_MIN then
			targetYaw = math.atan2(-flat.X, -flat.Z) -- face where it walks
			pet.hop += dt * HOP_RATE
		else
			local look = rootFrame.LookVector
			targetYaw = math.atan2(-look.X, -look.Z) -- standing: look the same way as the player
			pet.hop = 0
		end
		pet.yaw += angleDelta(pet.yaw, targetYaw) * turnAlpha

		local hopY = math.abs(math.sin(pet.hop)) * HOP_HEIGHT
		local pivot = CFrame.new(pet.position + Vector3.new(0, hopY, 0)) * CFrame.Angles(0, pet.yaw, 0)
		local frames = table.create(#pet.offsets) :: { CFrame }
		for i, offset in pet.offsets do
			frames[i] = pivot * offset
		end
		workspace:BulkMoveTo(pet.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- baseService: BaseService (already started), for each player's equipped pet.
function PetService.start(baseService: BaseApi)
	assert(not started, "PetService already started")
	started = true
	baseApi = baseService
	petsFolder()

	baseService.onEquippedChanged(refresh)
	local function addPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			refresh(player)
		end)
		refresh(player)
	end
	Players.PlayerAdded:Connect(addPlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	Players.PlayerRemoving:Connect(removePet)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < STEP_SECONDS then
			return
		end
		local stepSeconds = math.min(elapsed, MAX_STEP_SECONDS)
		elapsed = 0
		local ok, err = pcall(step, stepSeconds)
		if not ok then
			warn(`[SpaceBaseOdyssey] pet follow step failed: {err}`)
		end
	end)
end

-- The pet id a player shows now ("none" when no pet), for other services.
function PetService.petOf(player: Player): string
	local pet = pets[player]
	return if pet then pet.id else "none"
end

return PetService
