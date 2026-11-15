--!strict
-- Space Base Odyssey - C.A.R.L., the helper drone: a client-only model that floats beside the local
-- astronaut's right shoulder. Its core glows cyan when all is well, orange when the suit air is low,
-- a task is urgent or a storm warning is on, red while storm particles are here (Theme "Lunar
-- Sunrise" roles). In a storm an orange beam (the shelter colour) points from C.A.R.L. to the
-- shelter door until the player is safe inside.
-- Guidance (Settings: on by default): a cyan beam points to where the next unfinished objective
-- happens (Workspace.Base.Markers); with no such objective during a shift it points to the most
-- useful task (ice to deliver, leak, dusty arrays, antenna, ice). It hides within 8 studs.
-- Reward: a player who found the hidden mini Earth gets C.A.R.L.'s "Earth skin": the body shows the
-- real Earth (NASA Blue Marble map, Icons.earthMap) slowly turning; it is local to that player.
-- Anchored Parts moved every frame (no physics); it never collides, blocks clicks or casts shadows.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Store = require(script.Parent.Store)
local Theme = require(Shared:WaitForChild("Theme"))
local Icons = require(Shared:WaitForChild("Icons"))

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

local PALETTE = Theme.PALETTE
local ROLE = Theme.ROLE
local COLOR_BODY = PALETTE.cream
local COLOR_VISOR = PALETTE.night
local COLOR_EYE = PALETTE.cyan
local COLOR_METAL = PALETTE.creamDim
local CORE_NORMAL = ROLE.accent -- cyan: systems and guidance
local CORE_ALERT = ROLE.warning -- orange: warnings
local CORE_STORM = ROLE.danger -- red: particles are here
local BEAM_COLOR = ROLE.warning -- orange: the way to the shelter
local GUIDE_COLOR = ROLE.accent -- cyan: C.A.R.L.'s guidance
local GUIDE_HIDE_DISTANCE = 8 -- studs: close enough, the task marker and prompt take over

-- Earth skin (reward for the hidden mini Earth): the Blue Marble map in a turning disc.
local EARTH_OCEAN = PALETTE.cyan:Lerp(PALETTE.night, 0.55) -- shows while the map image loads
local EARTH_COLLECTIBLE = "mini_earth"
local EARTH_DISC_STUDS = 1.62
local EARTH_TURN_SECONDS = 40 -- one turn of the little Earth (decoration only)

local SHELTER_MARKER = "ShelterDoor"

-- Where each objective happens (marker names in Workspace.Base.Markers). Objectives that are not
-- in one place (finish_day, complete_days, survive_storm, stars_at_least) are skipped.
local OBJECTIVE_MARKERS: { [string]: string } = {
	go_outside = "HabitatDoor",
	return_inside = "HabitatDoor",
	align_antenna = "Antenna",
	clean_panel = "Arrays",
	drill_ice = "IceSite",
	repair_leak = "Leak",
	reach_shelter = "ShelterDoor",
	set_power = "Console",
	start_shift = "Console",
}
-- Objectives that can be done while planning (the rest need the shift: the console starts it).
local PLANNING_OBJECTIVES: { [string]: boolean } = {
	go_outside = true,
	return_inside = true,
	set_power = true,
	start_shift = true,
}

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
	if stage == "storm" then
		return CORE_STORM
	elseif stage == "warning" then
		return CORE_ALERT
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

local function carryingIce(): boolean
	local stats = Store.getStats()
	return stats ~= nil and stats.carryingIce
end

-- Marker for one objective, or nil when it is not done in one place (or not now).
local function objectiveMarker(id: string, phase: string): string?
	if phase == "Planning" and not PLANNING_OBJECTIVES[id] then
		return nil
	end
	if id == "deliver_ice" or id == "deliver_ice_total" then
		return if carryingIce() then "Processor" else "IceSite"
	end
	return OBJECTIVE_MARKERS[id]
end

-- The most useful task right now during a shift (free play, or objectives with no place).
local function usefulTaskMarker(): string?
	local snap = Store.getSnapshot()
	local shift = if snap then snap.shift else nil
	if not shift then
		return nil
	end
	if carryingIce() then
		return "Processor"
	elseif shift.leakActive then
		return "Leak"
	elseif shift.dustyArrays > 0 then
		return "Arrays"
	elseif not shift.antennaLinked then
		return "Antenna"
	end
	return "IceSite"
end

-- Where C.A.R.L.'s guidance beam should point now (marker name), or nil.
local function guidanceMarker(): string?
	if not Store.settingOn("guidance") then
		return nil
	end
	local phase = Store.phase()
	if phase ~= "Planning" and phase ~= "Shift" then
		return nil
	end
	local mission = Store.mission()
	local objectives = if mission then mission.objectives else nil
	local hasShiftTask = false
	if type(objectives) == "table" then
		for _, objective in objectives do
			if objective.done then
				continue
			end
			local marker = objectiveMarker(objective.id, phase)
			if marker then
				return marker
			end
			if phase == "Planning" then
				hasShiftTask = true
			end
		end
	end
	if phase == "Planning" then
		-- Shift tasks wait: the shift starts at the console.
		return if hasShiftTask then "Console" else nil
	end
	return usefulTaskMarker()
end

-- A small Earth for C.A.R.L.'s body: a round CanvasGroup with two copies of the Blue Marble map
-- side by side, scrolled left to right (Earth turns west to east), a soft shade on one side and a
-- thin cyan atmosphere ring. Returns the gui and its scrolling strip.
local function makeEarthSkin(adornee: BasePart): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EarthSkin"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(EARTH_DISC_STUDS, EARTH_DISC_STUDS)
	gui.LightInfluence = 0.3
	gui.MaxDistance = 150
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local group = Instance.new("CanvasGroup")
	group.Name = "Globe"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = EARTH_OCEAN
	group.BorderSizePixel = 0
	group.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = group

	-- The disc shows half of the map's width (180 degrees of longitude): each copy is 2 discs wide.
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Size = UDim2.fromScale(4, 1)
	strip.Position = UDim2.fromScale(-2, 0)
	strip.Parent = group
	for copy = 0, 1 do
		local map = Instance.new("ImageLabel")
		map.Name = "Map" .. tostring(copy + 1)
		map.BackgroundTransparency = 1
		map.BorderSizePixel = 0
		map.Image = Icons.earthMap
		map.ScaleType = Enum.ScaleType.Stretch
		map.Size = UDim2.fromScale(0.5, 1)
		map.Position = UDim2.fromScale(copy * 0.5, 0)
		map.Parent = strip
	end

	-- Round look: darker towards the right edge (night side) and a little at the left limb.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = PALETTE.night
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 2
	shade.Parent = group
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	gradient.Rotation = 15
	gradient.Parent = shade

	local ring = Instance.new("UIStroke")
	ring.Color = PALETTE.cyan
	ring.Thickness = 1.5
	ring.Transparency = 0.35
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = group

	gui.Parent = adornee
	return gui, strip
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
	-- Guidance beam (cyan): same start, ends inside the target marker.
	local guide = Instance.new("Beam")
	guide.Name = "GuideBeam"
	guide.Attachment0 = beamStart
	guide.Color = ColorSequence.new(GUIDE_COLOR)
	guide.LightEmission = 1
	guide.LightInfluence = 0
	guide.Brightness = 3
	guide.FaceCamera = true
	guide.Width0 = 0.25
	guide.Width1 = 0.6
	guide.Segments = 1
	guide.Enabled = false
	guide.Parent = model

	model.PrimaryPart = body
	model.Parent = workspace

	-- One local attachment per marker, created on first use (markers can be rebuilt).
	local markerAttachments: { [string]: Attachment } = {}
	local function markerAttachment(name: string): Attachment?
		local existing = markerAttachments[name]
		local marker = Store.findMarker(name)
		if existing and existing.Parent ~= nil and existing.Parent == marker then
			return existing
		end
		if existing then
			existing:Destroy()
			markerAttachments[name] = nil
		end
		if not marker then
			return nil
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "CarlBeamEnd_Local"
		attachment.Parent = marker
		markerAttachments[name] = attachment
		return attachment
	end

	local earthGui, earthStrip = makeEarthSkin(body)
	local earthSkin: boolean? = nil
	local function applySkin()
		local wanted = Store.hasCollectible(EARTH_COLLECTIBLE)
		if wanted == earthSkin then
			return
		end
		earthSkin = wanted
		-- The map disc replaces the plain body; visor, eyes, core ring and fins stay in front.
		body.Transparency = if wanted then 1 else 0
		earthGui.Enabled = wanted
	end
	applySkin()
	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "progress" then
			applySkin()
		end
	end)

	local parts: { BasePart } = {}
	for _, piece in pieces do
		table.insert(parts, piece.part)
	end
	local cframes: { CFrame } = table.create(#pieces, CFrame.identity)

	local current: CFrame? = nil
	local coreColor = CORE_NORMAL
	local spin = 0

	local function shelterAttachment(): Attachment?
		local attachment = markerAttachment(SHELTER_MARKER)
		beam.Attachment1 = attachment
		return attachment
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local root = rootPart()
		if not root then
			-- Between characters (respawn): no beam; the next character gets a fresh snap.
			current = nil
			beam.Enabled = false
			guide.Enabled = false
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
		-- Task guidance, unless the storm beam is on (it always wins).
		local guideTarget: BasePart? = nil
		if not guiding then
			local name = guidanceMarker()
			local marker = if name then Store.findMarker(name) else nil
			if name and marker and (marker.Position - root.Position).Magnitude > GUIDE_HIDE_DISTANCE then
				guideTarget = marker
				guide.Attachment1 = markerAttachment(name)
			end
		end
		local facing = door or guideTarget
		if facing then
			local toTarget = facing.Position - anchor
			if toTarget.Magnitude > 0.1 then
				look = toTarget.Unit
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

		-- Guidance beam: calmer pulse, fading toward the target.
		local showGuide = guideTarget ~= nil and guide.Attachment1 ~= nil
		guide.Enabled = showGuide
		if showGuide then
			local wave = (math.sin(t * 2.5) + 1) / 2
			local near = 0.15 + 0.3 * wave
			guide.Transparency = NumberSequence.new(near, math.min(0.9, near + 0.35))
		end

		-- Earth skin: turn the little Earth (one turn every EARTH_TURN_SECONDS).
		if earthSkin then
			local turn = (t / EARTH_TURN_SECONDS) % 1
			earthStrip.Position = UDim2.fromScale(-2 + turn * 2, 0)
		end
	end)
end

return CarlDrone
