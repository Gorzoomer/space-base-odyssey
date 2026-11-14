--!strict
-- Space Base Odyssey - C.A.R.L., the helper drone: a client-only model that floats beside the local
-- astronaut's right shoulder. Its core glows cyan when all is well, yellow when the suit air is low
-- or a task is urgent, red-purple during a storm warning or storm. In a storm a bright beam points
-- from C.A.R.L. to the shelter door until the player is safe inside.
-- Anchored Parts moved every frame (no physics); it never collides, blocks clicks or casts shadows.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Store = require(script.Parent.Store)

-- Suit air below the meters' yellow zone counts as low (same 0-100 scale as the HUD bar).
local SUIT_LOW = MissionData.METERS.YELLOW_ZONE * MissionData.SUIT.MAX / 100

-- Visual tuning (not gameplay numbers).
local SHOULDER_OFFSET = Vector3.new(3.4, 2.8, 1.2) -- right, up, slightly behind the root part
local FOLLOW_RATE = 6 -- higher = snappier follow
local TURN_RATE = 4
local SNAP_DISTANCE = 40 -- teleports (rescue, respawn) snap instead of flying across the map
local BOB_HEIGHT = 0.25
local BOB_SPEED = 2.2
local PROPELLER_SPEED = 18 -- radians per second
local COLOR_RATE = 4

local COLOR_BODY = Color3.fromRGB(236, 240, 248)
local COLOR_VISOR = Color3.fromRGB(24, 30, 48)
local COLOR_EYE = Color3.fromRGB(220, 250, 255)
local COLOR_METAL = Color3.fromRGB(150, 156, 170)
local CORE_NORMAL = Color3.fromRGB(0, 220, 255)
local CORE_ALERT = Color3.fromRGB(255, 210, 30)
local CORE_STORM = Color3.fromRGB(225, 40, 150)
local BEAM_COLOR = Color3.fromRGB(255, 240, 140)

local SHELTER_MARKER = "ShelterDoor"

local CarlDrone = {}

type Piece = { part: BasePart, offset: CFrame, spin: boolean }

local player = Players.LocalPlayer
local started = false

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function coreTarget(stage: Store.StormStage): Color3
	if stage ~= "none" then
		return CORE_STORM
	end
	local stats = Store.getStats()
	if stats and stats.suitO2 < SUIT_LOW then
		return CORE_ALERT
	end
	local snap = Store.getSnapshot()
	local shift = if snap and snap.phase == "Shift" then snap.shift else nil
	if shift and (shift.leakActive or shift.dustyArrays > 0) then
		return CORE_ALERT
	end
	return CORE_NORMAL
end

function CarlDrone.start()
	if started then
		return
	end
	started = true

	local model = Instance.new("Model")
	model.Name = "CarlDrone_Local"

	local pieces: { Piece } = {}
	local function add(part: BasePart, offset: CFrame, spin: boolean?)
		table.insert(pieces, { part = part, offset = offset, spin = spin == true })
	end

	local plastic = Enum.Material.SmoothPlastic
	local neon = Enum.Material.Neon
	-- Front of the drone is -Z (its LookVector), like a character.
	local body = newPart(model, "Body", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), COLOR_BODY, plastic)
	add(body, CFrame.identity)
	add(
		newPart(model, "Visor", Enum.PartType.Block, Vector3.new(1.0, 0.55, 0.3), COLOR_VISOR, Enum.Material.Glass),
		CFrame.new(0, 0.12, -0.6)
	)
	add(newPart(model, "EyeLeft", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), COLOR_EYE, neon), CFrame.new(-0.22, 0.14, -0.76))
	add(newPart(model, "EyeRight", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), COLOR_EYE, neon), CFrame.new(0.22, 0.14, -0.76))
	-- Core: a glowing band around the middle plus a glowing bulb underneath.
	local ring = newPart(model, "CoreRing", Enum.PartType.Cylinder, Vector3.new(0.22, 1.58, 1.58), CORE_NORMAL, neon)
	add(ring, CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local bulb = newPart(model, "CoreBulb", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), CORE_NORMAL, neon)
	add(bulb, CFrame.new(0, -0.72, 0))
	-- Fins and propeller.
	add(newPart(model, "FinLeft", Enum.PartType.Block, Vector3.new(0.1, 0.4, 0.55), COLOR_METAL, plastic), CFrame.new(-0.78, -0.05, 0.25))
	add(newPart(model, "FinRight", Enum.PartType.Block, Vector3.new(0.1, 0.4, 0.55), COLOR_METAL, plastic), CFrame.new(0.78, -0.05, 0.25))
	add(
		newPart(model, "Mast", Enum.PartType.Cylinder, Vector3.new(0.35, 0.12, 0.12), COLOR_METAL, plastic),
		CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	add(newPart(model, "BladeA", Enum.PartType.Block, Vector3.new(1.7, 0.05, 0.18), COLOR_METAL, plastic), CFrame.new(0, 1.04, 0), true)
	add(
		newPart(model, "BladeB", Enum.PartType.Block, Vector3.new(1.7, 0.05, 0.18), COLOR_METAL, plastic),
		CFrame.new(0, 1.04, 0) * CFrame.Angles(0, math.rad(90), 0),
		true
	)

	local light = Instance.new("PointLight")
	light.Color = CORE_NORMAL
	light.Range = 7
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = bulb

	-- Storm guide beam: from the core bulb to an attachment inside the shelter door marker.
	local beamStart = Instance.new("Attachment")
	beamStart.Name = "BeamStart"
	beamStart.Parent = bulb
	local beam = Instance.new("Beam")
	beam.Name = "ShelterBeam"
	beam.Attachment0 = beamStart
	beam.Color = ColorSequence.new(BEAM_COLOR)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 4
	beam.FaceCamera = true
	beam.Width0 = 0.35
	beam.Width1 = 0.8
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = model
	local beamEnd: Attachment? = nil

	model.PrimaryPart = body
	model.Parent = workspace

	local parts: { BasePart } = {}
	for _, piece in pieces do
		table.insert(parts, piece.part)
	end
	local cframes: { CFrame } = table.create(#pieces, CFrame.identity)

	local current: CFrame? = nil
	local coreColor = CORE_NORMAL
	local spin = 0

	local function shelterAttachment(): Attachment?
		if beamEnd and beamEnd.Parent then
			return beamEnd
		end
		local door = Store.findMarker(SHELTER_MARKER)
		if not door then
			return nil
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "CarlBeamEnd_Local"
		attachment.Parent = door
		beamEnd = attachment
		beam.Attachment1 = attachment
		return attachment
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local root = rootPart()
		if not root then
			-- Between characters (respawn): no beam; the next character gets a fresh snap.
			current = nil
			beam.Enabled = false
			return
		end
		local t = os.clock()
		local stage = Store.stormStage()
		local stats = Store.getStats()
		local sheltered = stats ~= nil and stats.sheltered

		-- Where to float: by the right shoulder, bobbing gently.
		local rootCf = root.CFrame
		local anchor = (rootCf * CFrame.new(SHOULDER_OFFSET)).Position + Vector3.new(0, math.sin(t * BOB_SPEED) * BOB_HEIGHT, 0)
		local look = rootCf.LookVector
		local guiding = stage ~= "none" and not sheltered
		local door = if guiding then Store.findMarker(SHELTER_MARKER) else nil
		if door then
			local toDoor = door.Position - anchor
			if toDoor.Magnitude > 0.1 then
				look = toDoor.Unit
			end
		end
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude < 0.01 then
			flatLook = Vector3.new(0, 0, -1)
		end
		local target = CFrame.lookAt(anchor, anchor + flatLook.Unit)

		local previous = current
		if previous == nil or (previous.Position - anchor).Magnitude > SNAP_DISTANCE then
			current = target
		else
			local followAlpha = 1 - math.exp(-deltaTime * FOLLOW_RATE)
			local turnAlpha = 1 - math.exp(-deltaTime * TURN_RATE)
			local position = previous.Position:Lerp(target.Position, followAlpha)
			local rotation = previous.Rotation:Lerp(target.Rotation, turnAlpha)
			current = CFrame.new(position) * rotation
		end
		local cf = current :: CFrame

		spin = (spin + deltaTime * PROPELLER_SPEED) % (math.pi * 2)
		for index, piece in pieces do
			cframes[index] = if piece.spin then cf * piece.offset * CFrame.Angles(0, spin, 0) else cf * piece.offset
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

		-- Core colour eases toward the state colour.
		coreColor = coreColor:Lerp(coreTarget(stage), 1 - math.exp(-deltaTime * COLOR_RATE))
		ring.Color = coreColor
		bulb.Color = coreColor
		light.Color = coreColor

		-- Shelter beam, pulsing so it catches the eye.
		local showBeam = guiding and shelterAttachment() ~= nil
		beam.Enabled = showBeam
		if showBeam then
			local wave = (math.sin(t * 6) + 1) / 2
			beam.Transparency = NumberSequence.new(0.05 + 0.35 * wave)
		end
	end)
end

return CarlDrone
