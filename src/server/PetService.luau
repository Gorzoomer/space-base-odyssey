--!strict
-- Space Base Odyssey - pets that follow their astronaut around the base.
-- A player's equipped pet (BaseService.equipped(player).pet, "none" = no pet) is built from the Parts
-- data in Shared.PetModels (based on Santiago Alvarado Delgadillo's original pet designs), scaled to
-- the pet's height and placed in Workspace.Pets.<UserId>.
--
-- How a pet is put together: one invisible anchored "PetRoot" part at the bottom centre of the pet;
-- one invisible joint part per animated joint (head, ears, tail, legs...), linked to its parent with a
-- Motor6D; every visible part welded to its joint (or to the root). The server moves only the root
-- (about 20 times a second) and turns the joints by changing Motor6D.C0, so very little has to be
-- sent to the players. Pets never collide, block rays, trigger touches or cast shadows: they are only
-- for fun and never change the game.
--
-- What the pets do: follow behind-left of the player on the ground with a hop in each step (the
-- rabbit hops high with both feet), swing legs and arms while walking, wag tails, wiggle ears now and
-- then, sway antennas, blink backpack lights, breathe gently when standing, and turn to look at their
-- astronaut when the player stands still.
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
	anim: string?,
	pivot: { number }?,
}

-- How a pet moves (look only, never game rules).
type Gait = {
	height: number, -- studs tall
	hopHeight: number, -- studs
	hopRate: number, -- radians per second of the hop wave (two hops per wave)
	limbSwing: number, -- degrees
	together: boolean, -- legs move together (a hop) instead of one after the other
	waddle: number, -- degrees of side-to-side roll while walking
}

type JointKind = "head" | "tail" | "ear" | "limb" | "antenna" | "still"

type Joint = {
	kind: JointKind,
	motor: Motor6D,
	base: CFrame, -- C0 at rest
	side: number, -- ears: 1 = left (turns out toward -X), -1 = right
	phase: number, -- limbs: step phase in radians
}

type Light = {
	part: BasePart,
	on: boolean,
	offset: number, -- seconds, so lights do not all blink together
	litTransparency: number,
}

type Pet = {
	id: string,
	model: Model,
	root: BasePart,
	joints: { Joint },
	lights: { Light },
	gait: Gait,
	placed: boolean,
	position: Vector3, -- the root on the ground, without the hop
	yaw: number,
	hop: number, -- hop and step wave
	walk: number, -- 0 standing .. 1 walking, smoothed
	still: number, -- seconds standing still
	clock: number,
	tailWave: number,
	wiggleUntil: number,
	nextWiggle: number,
}

local MODELS: { [string]: { PetRow } } = PetModels :: any

local DEFAULT_GAIT: Gait = { height = 2.8, hopHeight = 0.4, hopRate = 11, limbSwing = 30, together = false, waddle = 0 }
local GAITS: { [string]: Gait } = {
	laika = { height = 3.0, hopHeight = 0.35, hopRate = 12, limbSwing = 35, together = false, waddle = 0 },
	-- The cheese lost its helmet (Stage 8): its top is now the antenna light, not the old antenna above
	-- the helmet, so 2.07 keeps the wedge the same size as before (2.7 * 3.01 / 3.93).
	cheese = { height = 2.07, hopHeight = 0.3, hopRate = 14, limbSwing = 40, together = false, waddle = 7 },
	rabbit = { height = 3.4, hopHeight = 0.85, hopRate = 8, limbSwing = 25, together = true, waddle = 0 },
	monkey = { height = 3.1, hopHeight = 0.3, hopRate = 11, limbSwing = 30, together = false, waddle = 3 },
}

-- Step phase of each limb: diagonal legs step together, arms swing against the legs on their side.
local LIMB_PHASE: { [string]: number } = {
	legFL = 0,
	legBR = 0,
	legFR = math.pi,
	legBL = math.pi,
	legL = 0,
	legR = math.pi,
	armL = math.pi,
	armR = 0,
}

local FOLLOW_OFFSET = Vector3.new(-3.2, 0, 3.2) -- behind-left of the player's root (root faces -Z)
local STEP_SECONDS = 1 / 20
local MAX_STEP_SECONDS = 0.25
local SMOOTHING = 7 -- higher follows more tightly
local TURN_SMOOTHING = 10
local WALK_SMOOTHING = 8
local SNAP_DISTANCE = 40
local MOVE_SPEED_MIN = 0.6 -- studs per second; slower counts as standing still
local LOOK_AT_OWNER_AFTER = 0.6 -- seconds standing still before turning to the player
local BREATHE_HEIGHT = 0.05 -- studs
local BREATHE_RATE = 2.4 -- radians per second
local BLINK_PERIOD = 1.4 -- seconds
local BLINK_ON = 1.0 -- seconds lit in each period
local LIGHT_OFF_TRANSPARENCY = 0.6
local WIGGLE_SECONDS = 0.6
local WIGGLE_GAP_MIN, WIGGLE_GAP_MAX = 2.5, 5.5 -- seconds between quick ear wiggles
local RAY_UP = 2 -- the ground ray starts this far above the player's root (stays under ceilings)
local RAY_DOWN = 40
local FEET_BELOW_ROOT = 3 -- where the ground is when the ray finds nothing
local HIDDEN = CFrame.new(0, 1000, 0) -- out of sight until the first follow step

local PetService = {}

local started = false
local baseApi: BaseApi? = nil
local folder: Folder? = nil
local pets: { [Player]: Pet } = {}
local random = Random.new()

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

-- Lowest and highest point of the model (its world-axis box), in model units.
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

local function quiet(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
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
	part.Anchored = false -- welded to the anchored root
	quiet(part)
	part.Material = materialOf(row.material)
	part.Color = Color3.fromRGB(row.color[1], row.color[2], row.color[3])
	part.Transparency = row.transparency
	part.Reflectance = row.reflectance
	return part
end

local function invisiblePart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.Transparency = 1
	quiet(part)
	return part
end

-- "head.earL" -> "head.earL", false; "head.light" -> "head", true; "light" -> nil, true; nil -> nil, false.
local function parseAnim(anim: string?): (string?, boolean)
	if anim == nil or anim == "" then
		return nil, false
	end
	local names = string.split(anim, ".")
	local isLight = names[#names] == "light"
	if isLight then
		table.remove(names)
	end
	if #names == 0 then
		return nil, isLight
	end
	return table.concat(names, "."), isLight
end

local function parentJoint(name: string): string?
	local names = string.split(name, ".")
	if #names <= 1 then
		return nil
	end
	table.remove(names)
	return table.concat(names, ".")
end

local function jointKind(name: string): (JointKind, number, number)
	local last = string.split(name, ".")
	local short = last[#last]
	if short == "head" then
		return "head", 0, 0
	elseif short == "tail" then
		return "tail", 0, 0
	elseif short == "antenna" then
		return "antenna", 0, 0
	elseif string.sub(short, 1, 3) == "ear" then
		return "ear", if string.sub(short, -1) == "R" then -1 else 1, 0
	elseif LIMB_PHASE[short] ~= nil then
		return "limb", 0, LIMB_PHASE[short]
	end
	return "still", 0, 0
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
	local gait = GAITS[id] or DEFAULT_GAIT
	local low, high = verticalBounds(rows)
	local bottom = math.min(low, 0)
	local scale = gait.height / math.max(high - bottom, 0.1)
	local lift = -bottom -- so the lowest point stands on the ground

	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	model:SetAttribute("PetId", id)
	model:SetAttribute("OwnerUserId", player.UserId)

	local root = invisiblePart("PetRoot")
	root.Anchored = true
	root.CFrame = HIDDEN
	root.Parent = model
	model.PrimaryPart = root

	-- Joint pivots (model space, scaled): the first part of each joint that gives one.
	local pivots: { [string]: CFrame } = {}
	local used: { [string]: boolean } = {}
	for _, row in rows do
		local joint = parseAnim(row.anim)
		local name = joint
		while name do
			used[name] = true
			name = parentJoint(name)
		end
		local p = row.pivot
		if joint and p and pivots[joint] == nil then
			pivots[joint] = CFrame.new(p[1] * scale, (p[2] + lift) * scale, p[3] * scale)
		end
	end

	-- Joint parts, parents first.
	local names: { string } = {}
	for name in used do
		table.insert(names, name)
	end
	table.sort(names, function(a: string, b: string): boolean
		local da, db = #string.split(a, "."), #string.split(b, ".")
		if da ~= db then
			return da < db
		end
		return a < b
	end)
	local jointParts: { [string]: BasePart } = {}
	local joints: { Joint } = {}
	local function pivotOf(name: string?): CFrame
		if name == nil then
			return CFrame.identity
		end
		local found = pivots[name]
		if found == nil then
			-- No part gave this joint a pivot: turn around its parent's pivot.
			found = pivotOf(parentJoint(name))
			pivots[name] = found
		end
		return found
	end
	for _, name in names do
		local parentName = parentJoint(name)
		local parentPart: BasePart = if parentName then jointParts[parentName] else root
		local pivot = pivotOf(name)
		local part = invisiblePart("Joint_" .. name)
		part.CFrame = HIDDEN * pivot
		part.Parent = model
		local motor = Instance.new("Motor6D")
		motor.Name = "Joint_" .. name
		motor.Part0 = parentPart
		motor.Part1 = part
		motor.C0 = pivotOf(parentName):Inverse() * pivot
		motor.C1 = CFrame.identity
		motor.Parent = part
		jointParts[name] = part
		local kind, side, phase = jointKind(name)
		if gait.together and kind == "limb" then
			phase = 0
		end
		table.insert(joints, { kind = kind, motor = motor, base = motor.C0, side = side, phase = phase })
	end

	-- Visible parts, welded to their joint (or the root).
	local lights: { Light } = {}
	for _, row in rows do
		local joint, isLight = parseAnim(row.anim)
		local part = makePart(row, scale)
		local offset = rowFrame(row, scale, lift)
		part.CFrame = HIDDEN * offset
		part.Parent = model
		local weld = Instance.new("Weld")
		weld.Part0 = if joint then jointParts[joint] else root
		weld.Part1 = part
		weld.C0 = pivotOf(joint):Inverse() * offset
		weld.C1 = CFrame.identity
		weld.Parent = part
		if isLight then
			table.insert(lights, {
				part = part,
				on = true,
				offset = random:NextNumber(0, BLINK_PERIOD),
				litTransparency = row.transparency,
			})
		end
	end

	model.Parent = petsFolder()
	return {
		id = id,
		model = model,
		root = root,
		joints = joints,
		lights = lights,
		gait = gait,
		placed = false,
		position = Vector3.zero,
		yaw = 0,
		hop = 0,
		walk = 0,
		still = 0,
		clock = random:NextNumber(0, 10), -- so two pets never move in step
		tailWave = 0,
		wiggleUntil = 0,
		nextWiggle = random:NextNumber(WIGGLE_GAP_MIN, WIGGLE_GAP_MAX),
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
-- Animating

local function deg(value: number): number
	return math.rad(value)
end

-- Turns every joint for this frame and blinks the lights.
local function animate(pet: Pet, dt: number)
	local t = pet.clock
	local walk = pet.walk
	local stand = 1 - walk

	if t >= pet.nextWiggle then
		pet.wiggleUntil = t + WIGGLE_SECONDS
		pet.nextWiggle = t + random:NextNumber(WIGGLE_GAP_MIN, WIGGLE_GAP_MAX)
	end
	local wiggling = t < pet.wiggleUntil
	pet.tailWave += dt * (7 + 7 * walk)

	for _, joint in pet.joints do
		local turn: CFrame
		if joint.kind == "head" then
			local nod = stand * 4 * math.sin(t * 0.9) + walk * 3 * math.sin(pet.hop * 2)
			local tilt = stand * 6 * math.sin(t * 0.6)
			turn = CFrame.Angles(deg(nod), 0, deg(tilt))
		elseif joint.kind == "tail" then
			local amount = 18 + 14 * walk
			turn = CFrame.Angles(0, deg(amount * math.sin(pet.tailWave)), 0)
		elseif joint.kind == "ear" then
			local wiggle = if wiggling then 14 * math.sin(t * 28) else 3 * math.sin(t * 2.2)
			local back = walk * (12 + 4 * math.sin(pet.hop * 2)) -- flop back while walking
			turn = CFrame.Angles(deg(back), 0, deg(joint.side * wiggle))
		elseif joint.kind == "limb" then
			local swing = walk * pet.gait.limbSwing * math.sin(pet.hop + joint.phase)
			turn = CFrame.Angles(deg(swing), 0, 0)
		elseif joint.kind == "antenna" then
			local pitch = 5 * math.sin(t * 3.1) + walk * 12 * math.sin(pet.hop * 2)
			local roll = 5 * math.sin(t * 2.3)
			turn = CFrame.Angles(deg(pitch), 0, deg(roll))
		else
			continue
		end
		joint.motor.C0 = joint.base * turn
	end

	for _, light in pet.lights do
		local on = (t + light.offset) % BLINK_PERIOD < BLINK_ON
		if on ~= light.on then
			light.on = on
			light.part.Transparency = if on then light.litTransparency else LIGHT_OFF_TRANSPARENCY
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

-- The yaw that makes a pet (which faces -Z) look along `direction`.
local function yawToward(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
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
	local walkAlpha = 1 - math.exp(-WALK_SMOOTHING * dt)
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
		pet.clock += dt

		local moved = pet.position - previous
		local flat = Vector3.new(moved.X, 0, moved.Z)
		local gait = pet.gait
		local targetYaw: number
		local moving = flat.Magnitude / dt > MOVE_SPEED_MIN
		if moving then
			targetYaw = yawToward(flat) -- face where it walks
			pet.hop += dt * gait.hopRate
			pet.still = 0
		else
			pet.still += dt
			local toOwner = rootFrame.Position - pet.position
			toOwner = Vector3.new(toOwner.X, 0, toOwner.Z)
			if pet.still > LOOK_AT_OWNER_AFTER and toOwner.Magnitude > 0.5 then
				targetYaw = yawToward(toOwner) -- standing: look up at its astronaut
			else
				targetYaw = pet.yaw
			end
			-- Land the current hop instead of freezing in the air.
			local wave = pet.hop % math.pi
			if wave > 0.05 then
				pet.hop += math.min(dt * gait.hopRate, math.pi - wave)
			end
		end
		pet.walk += ((if moving then 1 else 0) - pet.walk) * walkAlpha
		pet.yaw += angleDelta(pet.yaw, targetYaw) * turnAlpha

		local hopY = math.abs(math.sin(pet.hop)) * gait.hopHeight
		local breathe = (1 - pet.walk) * BREATHE_HEIGHT * (1 + math.sin(pet.clock * BREATHE_RATE)) / 2
		local waddle = pet.walk * gait.waddle * math.sin(pet.hop)
		pet.root.CFrame = CFrame.new(pet.position + Vector3.new(0, hopY + breathe, 0))
			* CFrame.Angles(0, pet.yaw, 0)
			* CFrame.Angles(0, 0, math.rad(waddle))
		animate(pet, dt)
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
