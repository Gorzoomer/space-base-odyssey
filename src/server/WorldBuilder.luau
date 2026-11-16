--!strict
-- Space Base Odyssey - builds the Moon south-pole base from plain Parts and sets the lunar environment.
-- The code is split over sibling modules (Roblox limits a script's source size): WorldParts (layout,
-- palette and part helpers), WorldSky (lighting and the sky), WorldStructures (Stage 6 builds and the
-- Stage 7 lander and building in steps), WorldSecrets (hidden places and collectibles) and WorldSites
-- (the Stage 7 world sites).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local Theme = require(Shared:WaitForChild("Theme"))
local WorldParts = require(script.Parent:WaitForChild("WorldParts"))
local WorldSky = require(script.Parent:WaitForChild("WorldSky"))
local Six = require(script.Parent:WaitForChild("WorldStructures"))
local Secret = require(script.Parent:WaitForChild("WorldSecrets"))

export type ArrayRef = { model: Model, panel: BasePart, prompt: ProximityPrompt }
export type StormStage = "none" | "warning" | "storm"
export type SystemAllocation = { LifeSupport: number, Greenhouse: number, Science: number }
export type CollectibleRef = Secret.CollectibleRef
export type RoverPaint = "default" | "cheese"
-- Stage 8: one pressurized room. `part` is an invisible zone part (attribute SBO_ZoneShape: "box",
-- "cylinder" or "dome", see WorldParts.zoneContains); it counts as inside only while build `build`
-- stands at level `minLevel` (default 1) or more. No build = always (the lander).
export type InsideZone = { id: string, part: BasePart, build: string?, minLevel: number?, shape: string? }

export type World = {
	spawn: SpawnLocation, -- Stage 7: inside the arrival lander
	-- Stage 7: the habitat is a build; while it does not stand its zone sits far below the ground (like
	-- the shelter's), so it never counts as inside.
	habitatZone: BasePart,
	shelterZone: BasePart,
	-- Stage 8: every pressurized room (hub, greenhouse tube and domes, lab and its tube, lander). The
	-- shelter is not in it: it is a storm shelter (shelterZone), not a pressurized room.
	insideZones: { InsideZone },
	arrays: { ArrayRef },
	iceNodes: { { part: BasePart, prompt: ProximityPrompt } },
	processorPrompt: ProximityPrompt,
	leak: { part: BasePart, prompt: ProximityPrompt },
	antenna: { model: Model, dish: BasePart, prompt: ProximityPrompt },
	console: { part: BasePart, prompt: ProximityPrompt },
	-- Stage 9: the mission console in the hub. Its "MissionConsolePrompt" (TextKey "prompt.missions") is
	-- on while the habitat stands; the client opens the mission panel when it is triggered.
	missionConsole: { part: BasePart, prompt: ProximityPrompt },
	-- Workspace.Base.Markers: invisible guidance points (see MARKER_NAMES).
	markers: Folder?,
	setArrayDusty: (index: number, dusty: boolean) -> (),
	setLeakActive: (active: boolean) -> (),
	setAntennaLinked: (linked: boolean) -> (),
	setStormVisuals: (stage: StormStage) -> (),
	setShiftPromptsEnabled: (enabled: boolean) -> (),
	-- Shows today's power plan on the base: greenhouse grow lights, air maker, science rover.
	setSystemVisuals: (allocation: SystemAllocation) -> (),
	-- Secrets (Stage 4): four hidden collectibles, the sealed observatory door and two shared rewards.
	collectibles: { CollectibleRef },
	observatoryDoor: BasePart,
	setRoverPaint: (paint: RoverPaint) -> (),
	setTeamFlag: (visible: boolean) -> (),
	-- Stage 5: the water tank beside the processor shows the base's water (0 = empty, 1 = full).
	setWaterLevel: (fraction: number) -> (),
	-- Stage 5: the Sun circles the horizon and passes behind the Earth once per circle. The callback
	-- runs with true when the eclipse starts and false when it ends (also Workspace "SBO_Eclipse").
	onEclipse: (callback: (active: boolean) -> ()) -> (),
	isEclipse: () -> boolean,
	-- Demo helper: moves the Sun to a few seconds before the next eclipse.
	previewEclipse: () -> (),
	-- Stage 6: build and grow the base. Build ids come from MissionData.BASE.BUILDS. Level 0 shows only a
	-- cyan hologram (blueprint) of the structure; level >= 1 shows the real one (solar: that many arrays;
	-- antenna 2 = bigger dish, 3 = laser link; drills 2 and 3 = taller rig, more lights, a second bit).
	-- An unbuilt structure waits in ServerStorage, so its prompts cannot be used.
	setBuildLevel: (id: string, level: number, animate: boolean) -> (),
	isBuilt: (id: string) -> boolean,
	buildLevel: (id: string) -> number,
	-- Workspace.Base.BuildPads.<id> (attribute BuildId), each with one ProximityPrompt "BuildPrompt".
	buildPads: { [string]: BasePart },
	buildPrompts: { [string]: ProximityPrompt },
	-- The ice silo (filled by the automatic drills), its claim prompt "SiloPrompt". Stage 11: the
	-- fill shows ice / top (top = the biggest silo) and a cap ring the size `max` of this base level.
	siloPrompt: ProximityPrompt,
	setSilo: (ice: number, max: number, top: number?) -> (),
	-- Older callers: the cargo robot is built or shown (attribute SBO_CargoOn on the line folder).
	setCargoActive: (active: boolean) -> (),
	-- Stage 11 tycoon: Workspace.Base.ProductionLine, a Folder whose attributes describe the ice line
	-- for the clients (src/client/ProductionLine.luau animates cubes, drill bits, the robot and the air
	-- maker from them; the server moves none of it). Geometry: BeltCount + Belt1..n (the cubes' path,
	-- rim hopper to the silo's top), Lift1A/B..Lift3A/B (each drill's lift belt), RouteCount +
	-- Route1..n (the robot's drive), SBO_DriveSeconds / SBO_LoadSeconds / SBO_DropSeconds.
	productionLine: Folder,
	-- Status (see setLineState in build): icePerMinute, status, plantLevel, airStatus, product, drills.
	setLineState: (state: { [string]: any }) -> (),
	-- The robot's trip: phase, server start time, seconds, ice carried, product.
	setCargo: (phase: string, at: number, seconds: number, load: number, product: string) -> (),
	-- Seconds of each part of a robot trip (BaseService times the phases with them).
	cargoTimes: { drive: number, load: number, drop: number },
	-- Stage 7: building in steps. Shows level `level` of build `id` partly done: its blueprint plus the
	-- real parts revealed from the bottom up in proportion stage / stages (stage 0 = foundation outline
	-- only). BaseService calls setBuildLevel(id, level, true) when the last step is done (that clears it).
	setBuildProgress: (id: string, level: number, stage: number, stages: number) -> (),
	clearBuildProgress: (id: string) -> (), -- removes a build in progress (also done by setBuildLevel)
	-- Stage 7: the arrival lander. world.spawn is inside it; landerZone always counts as inside.
	landerZone: BasePart,
	-- The parts crate depot at the lander's cargo bay ("CratePrompt", TextKey "prompt.take_crate").
	crateDepot: { prompt: ProximityPrompt, position: Vector3 },
	-- Welds (true) or removes (false) the small parts crate a character carries in front of it.
	setCarryCrate: (character: Model, carrying: boolean) -> (),
	-- "FoodPrompt" in the greenhouse dome (TextKey "prompt.pick_food"); enabled while it is built.
	greenhouseFoodPrompt: ProximityPrompt,
	-- World sites (src/server/WorldSites.luau); nil / empty when that module is missing or broken.
	labPrompt: ProximityPrompt?, -- "LabPrompt", enabled only while the lab is built
	garageBays: { CFrame }, -- vehicle spawn points inside the garage, facing out
	pois: { { id: string, position: Vector3, prompt: ProximityPrompt } },
	spawnImpact: (position: Vector3) -> (Model, ProximityPrompt), -- a fresh meteorite crater
	clearImpact: (impact: Model) -> (),
	sitesLoaded: boolean, -- false when WorldSites failed (the lab, garage, pad and ship are missing)
}

type Style = WorldParts.Style
type RingSegment = WorldParts.RingSegment
type ArrayTrack = WorldSky.ArrayTrack
type DrillRefs = Six.DrillRefs
type ConstructionCopy = Six.ConstructionCopy
type CollectibleItem = Secret.CollectibleItem

local WorldBuilder = {}

-- Lighting, the sky bodies and the Sun's circle: see WorldSky.
WorldBuilder.applyEnvironment = WorldSky.applyEnvironment

-- Shared layout, palette, tuning and part helpers (WorldParts), and the sky helpers the build uses.
local HABITAT_CENTRE = WorldParts.HABITAT_CENTRE
local SHELTER_CENTRE = WorldParts.SHELTER_CENTRE
local CRATER_CENTRE = WorldParts.CRATER_CENTRE
local CRATER_RADIUS = WorldParts.CRATER_RADIUS
local CRATER_FLOOR_Y = WorldParts.CRATER_FLOOR_Y
local CRATER_RIM_Y = WorldParts.CRATER_RIM_Y
local RIDGE_CENTRE = WorldParts.RIDGE_CENTRE
local RIDGE_TOP_Y = WorldParts.RIDGE_TOP_Y
local ANTENNA_BASE = WorldParts.ANTENNA_BASE
local HUB_SEGMENTS = WorldParts.HUB_SEGMENTS
local HUB_APOTHEM = WorldParts.HUB_APOTHEM
local HUB_WALL = WorldParts.HUB_WALL
local HUB_WALL_HEIGHT = WorldParts.HUB_WALL_HEIGHT
local HUB_DOME_RX = WorldParts.HUB_DOME_RX
local HUB_DOME_RY = WorldParts.HUB_DOME_RY
local HUB_ROOF_Y = WorldParts.HUB_ROOF_Y
local HUB_ZONE_RADIUS = WorldParts.HUB_ZONE_RADIUS
local S7 = WorldParts.S7
local Geo = WorldParts.Geo
local GREENHOUSE_A_RX = WorldParts.GREENHOUSE_A_RX
local GREENHOUSE_A_RY = WorldParts.GREENHOUSE_A_RY
local GREENHOUSE_B_RX = WorldParts.GREENHOUSE_B_RX
local GREENHOUSE_B_RY = WorldParts.GREENHOUSE_B_RY
local TUBE_AXIS_Y = WorldParts.TUBE_AXIS_Y
local TUBE_APOTHEM = WorldParts.TUBE_APOTHEM
local LAB_TUBE_INSET = WorldParts.LAB_TUBE_INSET
local GROUND_HALF = WorldParts.GROUND_HALF
local GROUND_TILE = WorldParts.GROUND_TILE
local OBSERVATORY_HILL = WorldParts.OBSERVATORY_HILL
local COLLECTIBLE_BOB = WorldParts.COLLECTIBLE_BOB
local COLLECTIBLE_SPIN_RAD = WorldParts.COLLECTIBLE_SPIN_RAD
local COLLECTIBLE_AWAKE_RANGE = WorldParts.COLLECTIBLE_AWAKE_RANGE
local COLLECTIBLE_AWAKE_CHECK = WorldParts.COLLECTIBLE_AWAKE_CHECK
local PROMPT_DISTANCE = WorldParts.PROMPT_DISTANCE
local WHITE_HULL = WorldParts.WHITE_HULL
local PALETTE = WorldParts.PALETTE
local ACCENT_SYSTEM = WorldParts.ACCENT_SYSTEM
local ACCENT_WARNING = WorldParts.ACCENT_WARNING
local ACCENT_SECRET = WorldParts.ACCENT_SECRET
local ACCENT_OK = WorldParts.ACCENT_OK
local HULL_TRIM = WorldParts.HULL_TRIM
local METAL = WorldParts.METAL
local DARK_METAL = WorldParts.DARK_METAL
local PANEL_CLEAN = WorldParts.PANEL_CLEAN
local PANEL_DUSTY = WorldParts.PANEL_DUSTY
local LINK_RED = WorldParts.LINK_RED
local LINK_GREEN = WorldParts.LINK_GREEN
local STORM_AMBER = WorldParts.STORM_AMBER
local STORM_RED = WorldParts.STORM_RED
local LAMP_OFF = WorldParts.LAMP_OFF
local ICE_GLOW = WorldParts.ICE_GLOW
local MARKER_GUIDE = WorldParts.MARKER_GUIDE
local MARKER_SHELTER = WorldParts.MARKER_SHELTER
local GROW_PINK = WorldParts.GROW_PINK
local GROW_DIM = WorldParts.GROW_DIM
local PLANT_GREEN = WorldParts.PLANT_GREEN
local PLANT_GREY = WorldParts.PLANT_GREY
local AIR_OK = WorldParts.AIR_OK
local AIR_WINDOW_ON = WorldParts.AIR_WINDOW_ON
local AIR_WINDOW_HIGH = WorldParts.AIR_WINDOW_HIGH
local AIR_WINDOW_OFF = WorldParts.AIR_WINDOW_OFF
local CHEESE_PAINT = WorldParts.CHEESE_PAINT
local CHEESE_SPOT = WorldParts.CHEESE_SPOT
local INTERIOR_LIGHT = WorldParts.INTERIOR_LIGHT
local WATER_COLOUR = WorldParts.WATER_COLOUR
local WATER_TWEEN = WorldParts.WATER_TWEEN
local GROW_BRIGHTNESS = WorldParts.GROW_BRIGHTNESS
local GROW_RANGE = WorldParts.GROW_RANGE
local FAN_SPEED_RAD = WorldParts.FAN_SPEED_RAD
local AIR_PULSE_PERIOD = WorldParts.AIR_PULSE_PERIOD
local ROVER_SPEED = WorldParts.ROVER_SPEED
local ROVER_LOOP_RADIUS = WorldParts.ROVER_LOOP_RADIUS
local ROVER_RIM_RADIUS = WorldParts.ROVER_RIM_RADIUS
local PULSE_UPDATE_SECONDS = WorldParts.PULSE_UPDATE_SECONDS
local LINE = WorldParts.LINE -- Stage 11 tycoon
local CARGO_SPEED = WorldParts.CARGO_SPEED
local DRILL_FLOOR_RADIUS = WorldParts.DRILL_FLOOR_RADIUS
local DRILL_SPREAD = WorldParts.DRILL_SPREAD
local HOPPER_RADIUS = WorldParts.HOPPER_RADIUS
local RISE_DROP = WorldParts.RISE_DROP
local UPGRADE_DROP = WorldParts.UPGRADE_DROP
local HOLOGRAM_TRANSPARENCY = WorldParts.HOLOGRAM_TRANSPARENCY
local HOLOGRAM_MIN_PART = WorldParts.HOLOGRAM_MIN_PART
local SILO_TWEEN = WorldParts.SILO_TWEEN
local MARKER_NAMES = WorldParts.MARKER_NAMES
local CONSTRUCTION_DROP = WorldParts.CONSTRUCTION_DROP
local OUTLINE_MAX_SPAN = WorldParts.OUTLINE_MAX_SPAN
local CARRY_CRATE_NAME = WorldParts.CARRY_CRATE_NAME
local MIN_LEVEL_ATTRIBUTE = WorldParts.MIN_LEVEL_ATTRIBUTE
local buildState = WorldParts.buildState
local counted = WorldParts.counted
local part = WorldParts.part
local wedge = WorldParts.wedge
local ball = WorldParts.ball
local cylinder = WorldParts.cylinder
local vcylinder = WorldParts.vcylinder
local zcylinder = WorldParts.zcylinder
local box = WorldParts.box
local folder = WorldParts.folder
local model = WorldParts.model
local pointLight = WorldParts.pointLight
local makePrompt = WorldParts.makePrompt
local zone = WorldParts.zone
local shapedZone = WorldParts.shapedZone
local weldTo = WorldParts.weldTo
local markerPart = WorldParts.markerPart
local UPGRADE_ATTRIBUTE = WorldParts.UPGRADE_ATTRIBUTE
local ALPHA_ATTRIBUTE = WorldParts.ALPHA_ATTRIBUTE
local NO_RISE_ATTRIBUTE = WorldParts.NO_RISE_ATTRIBUTE
local upgrade = WorldParts.upgrade
local pipe = WorldParts.pipe
local dirFromAngle = WorldParts.dirFromAngle
local flatUnit = WorldParts.flatUnit
local regolith = WorldParts.regolith
local CHEESE_NICHE_OFFSET = WorldParts.CHEESE_NICHE_OFFSET
local GLASS = WorldParts.GLASS
local roverSideAngle = WorldParts.roverSideAngle
local resetPartCounter = WorldParts.resetPartCounter
local sunDirection = WorldSky.sunDirection
local defaultEarthPosition = WorldSky.defaultEarthPosition
local stormTint = WorldSky.stormTint
local startSky = WorldSky.startSky
local previewEclipse = WorldSky.previewEclipse
local COLLECTIBLE_IDS = Secret.COLLECTIBLE_IDS

-- Extra no-boulder circles around the new structures (Stage 6 and 7), filled by build.
local extraKeepouts: { { x: number, z: number, r: number } } = {}

-- Stage 11 world: nobody falls into the void or stays stuck in the ice crater. One table (this big
-- module is close to Luau's local limit). The layout rules are pure, in src/shared/WorldSafety.luau
-- (tests/feel.luau checks them).
local S11World: any = {}
S11World.rules = require(Shared:WaitForChild("WorldSafety"))

-- Two thin cyan guide strips (cyan = guidance) along the edges of a crater ramp. `cf` and `size`
-- are the wedge's: its slope rises from the front (-Z, low) to the back (+Z, rim height).
function S11World.rampGuides(parent: Instance, cf: CFrame, size: Vector3)
	local slope = math.atan2(size.Y, size.Z)
	local length = math.sqrt(size.Y * size.Y + size.Z * size.Z)
	local normal = Vector3.new(0, math.cos(slope), -math.sin(slope)) -- the slope's outward normal (local)
	for _, side in { -1, 1 } do
		local offset = Vector3.new(side * (size.X / 2 - 0.4), 0, 0) + normal * 0.12
		part(parent, "RampGuide", Vector3.new(0.5, 0.2, length - 1), cf * CFrame.new(offset) * CFrame.Angles(-slope, 0, 0), {
			color = MARKER_GUIDE,
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	end
end

-- Two more gentle ramps out of the crater floor (WorldSafety.exitAngles keeps them clear of the
-- drills, the cheese niche, the ice nodes and the lamps; the first faces the base as far as it can).
function S11World.craterExits(base: Instance, rampAngle: number, drillAngle: number)
	local rules = S11World.rules
	local crater = base:FindFirstChild("Crater") or base
	local inner = rules.EXIT.INNER
	local width = rules.EXIT.WIDTH
	local height = CRATER_RIM_Y - CRATER_FLOOR_Y
	local length = CRATER_RADIUS - inner
	for index, angle in rules.exitAngles(rampAngle, Six.nicheAngle(rampAngle), drillAngle) do
		local dir = dirFromAngle(angle)
		local pos = CRATER_CENTRE + dir * (inner + length / 2) + Vector3.new(0, CRATER_FLOOR_Y + height / 2, 0)
		local cf = CFrame.lookAt(pos, pos - dir)
		local size = Vector3.new(width, height, length)
		wedge(crater, "ExitRamp" .. index, size, cf, { color = Color3.fromRGB(112, 110, 106), material = Enum.Material.Sand })
		S11World.rampGuides(crater, cf, size)
	end
end

-- Invisible walls just inside the ground's edge (past +-GROUND_HALF is the void), so walking or the
-- moon buggy never falls off the world. Each has an orange warning band at its foot, hidden here:
-- the client fades it in when its player comes close (src/client/MapEdge.luau).
function S11World.mapEdge(base: Instance)
	local rules = S11World.rules
	local edge = rules.EDGE
	local edgeFolder = folder(base, "MapEdge")
	edgeFolder:SetAttribute("GroundHalf", GROUND_HALF)
	for _, wall in rules.wallBoxes(GROUND_HALF) do
		part(edgeFolder, "EdgeWall", Vector3.new(wall.sx, edge.WALL_HEIGHT, wall.sz), CFrame.new(wall.cx, edge.WALL_HEIGHT / 2 - 8, wall.cz), {
			color = PALETTE.night,
			transparency = 1,
			shadow = false,
		})
		local alongZ = wall.sx < wall.sz
		local inward = Vector3.new(if alongZ then -math.sign(wall.cx) else 0, 0, if alongZ then 0 else -math.sign(wall.cz))
		local glow = part(
			edgeFolder,
			"EdgeGlow",
			Vector3.new(if alongZ then 0.3 else wall.sx, edge.GLOW_HEIGHT, if alongZ then wall.sz else 0.3),
			CFrame.new(Vector3.new(wall.cx, edge.GLOW_HEIGHT / 2, wall.cz) + inward * (edge.WALL_THICKNESS / 2 + 0.2)),
			{ color = Theme.ROLE.warning, material = Enum.Material.Neon, transparency = 1, collide = false, shadow = false }
		)
		glow:SetAttribute("Side", wall.side)
	end
end

------------------------------------------------------------------------------------------------
-- Ground, crater, ridge and decoration
------------------------------------------------------------------------------------------------

local function fillGround(parent: Instance, rng: Random, x0: number, x1: number, z0: number, z1: number)
	local nx = math.max(1, math.ceil((x1 - x0) / GROUND_TILE))
	local nz = math.max(1, math.ceil((z1 - z0) / GROUND_TILE))
	local dx = (x1 - x0) / nx
	local dz = (z1 - z0) / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local ax = x0 + ix * dx
			local az = z0 + iz * dz
			box(parent, "Regolith", Vector3.new(ax, -8, az), Vector3.new(ax + dx, 0, az + dz), {
				color = regolith(rng, 128, 5),
				material = Enum.Material.Sand,
			})
		end
	end
end

local function buildGround(base: Instance, rng: Random): Folder
	local ground = folder(base, "Ground")
	local hx0 = CRATER_CENTRE.X - CRATER_RADIUS
	local hx1 = CRATER_CENTRE.X + CRATER_RADIUS
	local hz0 = CRATER_CENTRE.Z - CRATER_RADIUS
	local hz1 = CRATER_CENTRE.Z + CRATER_RADIUS
	-- Four rectangles around a square hole where the crater pit goes.
	fillGround(ground, rng, -GROUND_HALF, GROUND_HALF, -GROUND_HALF, hz0)
	fillGround(ground, rng, -GROUND_HALF, GROUND_HALF, hz1, GROUND_HALF)
	fillGround(ground, rng, -GROUND_HALF, hx0, hz0, hz1)
	fillGround(ground, rng, hx1, GROUND_HALF, hz0, hz1)
	return ground
end

-- A rim segment with a hidden niche: a narrow tunnel from the crater floor into a small dark room,
-- in the segment's own frame (-Z points out of the crater, +Z faces the floor). Every wall is at
-- least 4 studs thick so the camera cannot see in, and a rock fold hides the opening.
local function buildNicheSegment(crater: Instance, cf: CFrame, size: Vector3, style: Style): CFrame
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local floorY = -hy + 4 -- local height of the crater floor (the rim starts 4 below it)
	local roomTop = floorY + 8
	local function piece(name: string, a: Vector3, b: Vector3)
		local minV = a:Min(b)
		local maxV = a:Max(b)
		part(crater, name, maxV - minV, cf * CFrame.new((minV + maxV) / 2), style)
	end
	piece("Rim", Vector3.new(-hx, -hy, -hz), Vector3.new(hx, floorY, hz)) -- under the niche
	piece("Rim", Vector3.new(-hx, roomTop, -hz), Vector3.new(hx, hy, hz)) -- above it
	piece("Rim", Vector3.new(-hx, floorY, -hz), Vector3.new(hx, roomTop, -5)) -- behind the room
	piece("Rim", Vector3.new(-hx, floorY, -5), Vector3.new(-4.5, roomTop, hz))
	piece("Rim", Vector3.new(4.5, floorY, -5), Vector3.new(hx, roomTop, hz))
	piece("Rim", Vector3.new(-4.5, floorY, 5), Vector3.new(-2, roomTop, hz)) -- tunnel sides
	piece("Rim", Vector3.new(2, floorY, 5), Vector3.new(4.5, roomTop, hz))

	-- The rock fold: a slab leaning in front of the opening with a 4-stud gap behind it.
	local foldStyle: Style = { color = style.color, material = Enum.Material.Rock }
	part(crater, "RockFold", Vector3.new(11, 12, 3), cf * CFrame.new(0, floorY + 6, hz + 5.5) * CFrame.Angles(math.rad(-6), 0, 0), foldStyle)
	part(crater, "RockFold", Vector3.new(6, 7, 3.5), cf * CFrame.new(3.5, floorY + 3.5, hz + 7.5) * CFrame.Angles(0, math.rad(18), 0), foldStyle)

	-- Where the cheese floats: in the room, out of line of sight from the tunnel.
	return cf * CFrame.new(2.5, floorY + 2.6, -1.5)
end

-- Builds the crater pit with its rim, ramp and ice nodes; returns the model, the ice node refs,
-- the ramp's angle around the crater and where the hidden cheese floats.
local function buildCrater(base: Instance, rng: Random): (Model, { { part: BasePart, prompt: ProximityPrompt } }, number, CFrame)
	local crater = model(base, "Crater")
	local segments = 36
	local step = math.rad(360 / segments)
	local depth = 30 -- rim band from r = 70 to r = 100
	local outerR = CRATER_RADIUS + depth
	local width = 2 * outerR * math.tan(step / 2) + 0.5
	local rimBottom = CRATER_FLOOR_Y - 4
	local rimHeight = CRATER_RIM_Y - rimBottom
	local slopeDepth = 16
	local slopeWidth = 2 * (outerR + slopeDepth) * math.tan(step / 2) + 0.5

	-- The ramp goes down on the side facing away from the Sun so no light gets in through it.
	local sunH = flatUnit(sunDirection(), Vector3.new(0, 0, -1))
	local away = -sunH
	local rampAngle = math.floor(math.atan2(away.X, away.Z) / step + 0.5) * step
	local nicheSegment = math.floor((rampAngle + CHEESE_NICHE_OFFSET) / step + 0.5) % segments
	local cheeseSpot = CFrame.new(CRATER_CENTRE)

	for k = 0, segments - 1 do
		local n = dirFromAngle(k * step)
		local pos = CRATER_CENTRE + n * (CRATER_RADIUS + depth / 2) + Vector3.new(0, rimBottom + rimHeight / 2, 0)
		local rimStyle: Style = { color = regolith(rng, 122, 6), material = Enum.Material.Slate }
		if k == nicheSegment then
			cheeseSpot = buildNicheSegment(crater, CFrame.lookAt(pos, pos + n), Vector3.new(width, rimHeight, depth), rimStyle)
		else
			part(crater, "Rim", Vector3.new(width, rimHeight, depth), CFrame.lookAt(pos, pos + n), rimStyle)
		end
		local slopePos = CRATER_CENTRE + n * (outerR + slopeDepth / 2) + Vector3.new(0, CRATER_RIM_Y / 2, 0)
		wedge(crater, "RimSlope", Vector3.new(slopeWidth, CRATER_RIM_Y, slopeDepth), CFrame.lookAt(slopePos, slopePos + n), {
			color = regolith(rng, 132, 5),
			material = Enum.Material.Sand,
		})
	end

	-- Floor, permanently shadowed and very cold.
	local floorCf = CFrame.new(CRATER_CENTRE + Vector3.new(0, CRATER_FLOOR_Y - 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	cylinder(crater, "CraterFloor", 4, (CRATER_RADIUS + 3) * 2, floorCf, {
		color = Color3.fromRGB(84, 88, 96),
		material = Enum.Material.Slate,
	})

	local rampDir = dirFromAngle(rampAngle)
	local rampInner = 10
	local rampLength = CRATER_RADIUS - rampInner
	local rampHeight = CRATER_RIM_Y - CRATER_FLOOR_Y
	local rampPos = CRATER_CENTRE + rampDir * (rampInner + rampLength / 2) + Vector3.new(0, CRATER_FLOOR_Y + rampHeight / 2, 0)
	wedge(crater, "Ramp", Vector3.new(12, rampHeight, rampLength), CFrame.lookAt(rampPos, rampPos - rampDir), {
		color = Color3.fromRGB(112, 110, 106),
		material = Enum.Material.Sand,
	})
	S11World.rampGuides(crater, CFrame.lookAt(rampPos, rampPos - rampDir), Vector3.new(12, rampHeight, rampLength)) -- Stage 11 world

	-- Frost patches on the floor.
	local frostAngles = { 40, 150, 230, 300 }
	for i, deg in frostAngles do
		local p = CRATER_CENTRE + dirFromAngle(rampAngle + math.rad(deg)) * (18 + i * 6)
		local frostCf = CFrame.new(p + Vector3.new(0, CRATER_FLOOR_Y + 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		cylinder(crater, "Frost", 0.2, 10 + i * 2, frostCf, {
			color = Color3.fromRGB(196, 214, 230),
			material = Enum.Material.Ice,
			shadow = false,
		})
	end

	-- Work lamps on the crater floor.
	local side = Vector3.new(-rampDir.Z, 0, rampDir.X)
	local lampSpots = { CRATER_CENTRE + rampDir * 4 + side * 9, CRATER_CENTRE - rampDir * 26 + side * 6 }
	for i, spot in lampSpots do
		local poleTop = CRATER_FLOOR_Y + 10
		vcylinder(crater, "LampPole" .. i, 10, 0.6, spot + Vector3.new(0, CRATER_FLOOR_Y + 5, 0), {
			color = DARK_METAL,
			material = Enum.Material.Metal,
		})
		local head = box(crater, "LampHead" .. i, spot + Vector3.new(-1, poleTop, -1), spot + Vector3.new(1, poleTop + 0.8, 1), {
			color = Color3.fromRGB(255, 240, 215),
			material = Enum.Material.Neon,
		})
		pointLight(head, Color3.fromRGB(255, 236, 210), 40, 1, true)
	end

	-- Ice nodes: water ice that never sees the Sun.
	local iceNodes: { { part: BasePart, prompt: ProximityPrompt } } = {}
	local spots = { { 100, 38 }, { 180, 28 }, { 260, 42 } }
	for i, spot in spots do
		local p = CRATER_CENTRE + dirFromAngle(rampAngle + math.rad(spot[1])) * spot[2]
		local floorPos = p + Vector3.new(0, CRATER_FLOOR_Y, 0)
		local main = part(
			crater,
			"IceNode" .. i,
			Vector3.new(3.4, 4.2, 3.4),
			CFrame.new(floorPos + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(8), math.rad(30 * i), math.rad(-6)),
			{ color = ICE_GLOW, material = Enum.Material.Neon }
		)
		part(
			crater,
			"IceChunk",
			Vector3.new(2.4, 2.6, 2.2),
			CFrame.new(floorPos + Vector3.new(2.2, 1.1, 0.8)) * CFrame.Angles(math.rad(-12), math.rad(50), math.rad(14)),
			{ color = Color3.fromRGB(200, 230, 245), material = Enum.Material.Ice }
		)
		part(
			crater,
			"IceChunk",
			Vector3.new(2, 1.8, 2.4),
			CFrame.new(floorPos + Vector3.new(-1.8, 0.8, -1.6)) * CFrame.Angles(math.rad(10), math.rad(-20), math.rad(-10)),
			{ color = Color3.fromRGB(190, 222, 240), material = Enum.Material.Ice }
		)
		pointLight(main, ICE_GLOW, 18, 2, false)
		local prompt = makePrompt(main, "prompt.drill", "Drill ice", 2.5)
		table.insert(iceNodes, { part = main :: BasePart, prompt = prompt })
	end

	return crater, iceNodes, rampAngle, cheeseSpot
end

local function buildRidge(base: Instance, rng: Random): Model
	local ridge = model(base, "Ridge")
	local style = function(): Style
		return { color = regolith(rng, 146, 5), material = Enum.Material.Slate }
	end
	local c = RIDGE_CENTRE
	local halfX, halfZ = 35, 25
	box(ridge, "Plateau", Vector3.new(c.X - halfX, 0, c.Z - halfZ), Vector3.new(c.X + halfX, RIDGE_TOP_Y, c.Z + halfZ), style())

	local h = RIDGE_TOP_Y
	local function slope(name: string, centre: Vector3, look: Vector3, size: Vector3)
		wedge(ridge, name, size, CFrame.lookAt(centre, centre + look), style())
	end
	slope("SlopeNorth", Vector3.new(c.X, h / 2, c.Z - halfZ - 15), -Vector3.zAxis, Vector3.new(halfX * 2, h, 30))
	slope("SlopeSouth", Vector3.new(c.X, h / 2, c.Z + halfZ + 15), Vector3.zAxis, Vector3.new(halfX * 2, h, 30))
	slope("SlopeWest", Vector3.new(c.X - halfX - 15, h / 2, c.Z), -Vector3.xAxis, Vector3.new(halfZ * 2, h, 30))
	-- East side: a gentle ramp toward the base with two steeper slopes beside it.
	local rampHalf = 7
	local rampLength = 64
	slope(
		"Ramp",
		Vector3.new(c.X + halfX + rampLength / 2, h / 2, c.Z),
		Vector3.xAxis,
		Vector3.new(rampHalf * 2, h, rampLength)
	)
	local sideWidth = halfZ - rampHalf
	slope(
		"SlopeEastA",
		Vector3.new(c.X + halfX + 10, h / 2, c.Z - rampHalf - sideWidth / 2),
		Vector3.xAxis,
		Vector3.new(sideWidth, h, 20)
	)
	slope(
		"SlopeEastB",
		Vector3.new(c.X + halfX + 10, h / 2, c.Z + rampHalf + sideWidth / 2),
		Vector3.xAxis,
		Vector3.new(sideWidth, h, 20)
	)

	-- A few rocks along the plateau edges.
	local rocks = {
		Vector3.new(c.X - 30, h, c.Z - 20),
		Vector3.new(c.X - 28, h, c.Z + 21),
		Vector3.new(c.X + 26, h, c.Z - 21),
		Vector3.new(c.X + 28, h, c.Z + 19),
	}
	for _, rock in rocks do
		local s = rng:NextNumber(2.5, 4.5)
		part(
			ridge,
			"Rock",
			Vector3.new(s, s * 0.7, s * 1.1),
			CFrame.new(rock + Vector3.new(0, s * 0.25, 0))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
			{ color = regolith(rng, 112, 8), material = Enum.Material.Rock }
		)
	end
	return ridge
end

type Keepout = { x: number, z: number, r: number }

local KEEPOUTS: { Keepout } = {
	{ x = HABITAT_CENTRE.X, z = HABITAT_CENTRE.Z, r = 50 },
	{ x = SHELTER_CENTRE.X, z = SHELTER_CENTRE.Z + 10, r = 45 },
	{ x = CRATER_CENTRE.X, z = CRATER_CENTRE.Z, r = 130 },
	{ x = RIDGE_CENTRE.X, z = RIDGE_CENTRE.Z, r = 80 },
	{ x = -120, z = -60, r = 40 },
	{ x = ANTENNA_BASE.X, z = ANTENNA_BASE.Z, r = 18 },
	{ x = 0, z = 70, r = 30 },
	{ x = -55, z = -20, r = 25 },
	{ x = 40, z = 15, r = 22 },
	{ x = -30, z = 45, r = 18 },
	-- Secret places: random boulders must not block or give away an entrance.
	{ x = -73, z = 85, r = 24 }, -- lookout rock behind the antenna
	{ x = -298, z = -60, r = 48 }, -- lava tube hill
	{ x = OBSERVATORY_HILL.X, z = OBSERVATORY_HILL.Z, r = 62 },
}

local function isClear(x: number, z: number, margin: number): boolean
	for _, k in KEEPOUTS do
		local dx = x - k.x
		local dz = z - k.z
		if dx * dx + dz * dz < (k.r + margin) * (k.r + margin) then
			return false
		end
	end
	for _, k in extraKeepouts do
		local dx = x - k.x
		local dz = z - k.z
		if dx * dx + dz * dz < (k.r + margin) * (k.r + margin) then
			return false
		end
	end
	return true
end

local function randomClearSpot(rng: Random, margin: number): Vector3?
	for _ = 1, 30 do
		local x = rng:NextNumber(-GROUND_HALF + 20, GROUND_HALF - 20)
		local z = rng:NextNumber(-GROUND_HALF + 20, GROUND_HALF - 20)
		if isClear(x, z, margin) then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

local function buildDecor(base: Instance, rng: Random)
	local decor = folder(base, "Decor")

	-- Small impact craters: a dark bowl inside a lighter ejecta ring.
	for i = 1, 9 do
		local radius = rng:NextNumber(6, 16)
		local spot = randomClearSpot(rng, radius + 4)
		if spot then
			local flat = CFrame.Angles(0, 0, math.rad(90))
			cylinder(decor, "Ejecta" .. i, 0.5, radius * 2 + 8, CFrame.new(spot + Vector3.new(0, 0.25, 0)) * flat, {
				color = regolith(rng, 150, 6),
				material = Enum.Material.Sand,
			})
			cylinder(decor, "Bowl" .. i, 0.6, radius * 2, CFrame.new(spot + Vector3.new(0, 0.3, 0)) * flat, {
				color = regolith(rng, 98, 6),
				material = Enum.Material.Sand,
			})
		end
	end

	-- Boulders, half buried.
	for i = 1, 45 do
		local s = rng:NextNumber(2, 9)
		local spot = randomClearSpot(rng, s)
		if spot then
			part(
				decor,
				"Boulder" .. i,
				Vector3.new(s, s * rng:NextNumber(0.55, 0.9), s * rng:NextNumber(0.8, 1.2)),
				CFrame.new(spot + Vector3.new(0, s * 0.22, 0))
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5)),
				{ color = regolith(rng, 108, 14), material = Enum.Material.Rock }
			)
		end
	end

	-- Marker posts that show the way from the habitat door to each task site.
	local markers = {
		Vector3.new(8, 0, 42), Vector3.new(8, 0, 66), Vector3.new(8, 0, 90), -- crater
		Vector3.new(-22, 0, -50), Vector3.new(-48, 0, -64), Vector3.new(-76, 0, -66), -- ridge ramp (past the lab)
		Vector3.new(-22, 0, 40), Vector3.new(-42, 0, 58), -- antenna
		Vector3.new(24, 0, 28), Vector3.new(44, 0, 18), Vector3.new(62, 0, 4), -- shelter
	}
	local firstShelterMarker = #markers - 2 -- the last three posts lead to the shelter
	for i, spot in markers do
		vcylinder(decor, "MarkerPole" .. i, 4, 0.4, spot + Vector3.new(0, 2, 0), {
			color = DARK_METAL,
			material = Enum.Material.Metal,
		})
		box(decor, "MarkerLight" .. i, spot + Vector3.new(-0.5, 4, -0.5), spot + Vector3.new(0.5, 4.8, 0.5), {
			color = if i >= firstShelterMarker then MARKER_SHELTER else MARKER_GUIDE,
			material = Enum.Material.Neon,
			shadow = false,
		})
	end
end

------------------------------------------------------------------------------------------------
-- Habitat
------------------------------------------------------------------------------------------------

-- Stage 7 (team feedback, modern lunar base concept): the habitat is a round hub. Sixteen flat wall
-- segments carry a window band, a blue solar-cell wrap and a cyan trim line; a white faceted dome sits
-- on top. Doors: north (toward the crater), south (toward the lander) and a west doorway into the
-- walk-through tube to the greenhouse dome (a glass hatch closes it until the greenhouse stands);
-- Stage 10: a south-west doorway into the walk-through tube to the lab (hatch until the lab stands).
-- The room inside keeps the mission layout: power console, water processor, air maker, water tank.
-- Stage 9: the habitat is the base level (1 to 5). Levels 2 to 5 add their own parts outside the room
-- (Six.buildHabitatTiers), and a mission console on the east side starts missions (no start menu).
local HUB_DOOR_NORTH = 0
local HUB_DOOR_SOUTH = 8
local HUB_DOOR_WEST = 12
-- Stage 10: a doorway into the walk-through tube to the lab (south-west, where the lab's docking
-- doorway points; a glass hatch closes it until the lab stands). Width and height fit the tube.
local HUB_DOOR_LAB = 10
local HUB_LAB_DOOR_WIDTH = 10.4
local HUB_LAB_DOOR_TOP = 9.8

type HabitatRefs = {
	model: Model,
	zone: Part,
	console: Part,
	consolePrompt: ProximityPrompt,
	missionConsole: Part, -- Stage 9: opens the mission panel (client); no start menu any more
	missionConsolePrompt: ProximityPrompt,
	tierSolids: { Six.HabitatTierSolid }, -- Stage 9: habitat level parts that are solid once they stand
	processorPrompt: ProximityPrompt,
	leakPart: Part,
	leakPrompt: ProximityPrompt,
	leakEmitters: { ParticleEmitter },
	leakLight: PointLight,
	lifeSupport: LifeSupportRefs,
	rackLight: Part,
	rackPointLight: PointLight,
	rackPlants: { Part },
	processorInlet: Part,
	waterTank: WaterTankRefs,
	greenhouseHatch: Part, -- closes the west doorway while the greenhouse is not built
	labHatch: Part, -- Stage 10: closes the lab doorway while the lab is not built
}

type WaterTankRefs = { fill: Part, light: PointLight, gauge: Part, bottomY: number, height: number, centre: Vector3, diameter: number }

type LifeSupportRefs = {
	window: Part,
	windowLight: PointLight,
	status: Part,
	statusLight: PointLight,
	fanRoot: Part,
	fanCFrame: CFrame,
}

local function buildHabitat(base: Instance): HabitatRefs
	local hab = model(base, "Habitat")
	local o = HABITAT_CENTRE
	local function v(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	local trimBand: Style = { color = HULL_TRIM, material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
	local solarWrap: Style = { color = PANEL_CLEAN, material = Enum.Material.Glass, reflectance = 0.12, collide = false, shadow = false }
	local footLamp: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }

	-- Floor: round, and small enough to leave the crawl-space shaft east of the hub open.
	vcylinder(hab, "Floor", 0.5, (HUB_APOTHEM + 1) * 2, v(0, 0.25, 0), {
		color = Color3.fromRGB(170, 174, 180),
		material = Enum.Material.DiamondPlate,
	})

	-- Round wall: doorways 10 wide x 12 tall (north, south) so the default camera follows a player
	-- through without entering a wall; the west doorway matches the greenhouse tube.
	local segments = Geo.ringSegments(CFrame.new(o), HUB_APOTHEM, HUB_WALL, HUB_SEGMENTS, 0)
	local doorSegs: { [number]: RingSegment } = {}
	for _, seg in segments do
		local k = seg.index
		if k == HUB_DOOR_NORTH or k == HUB_DOOR_SOUTH then
			Geo.doorSegment(hab, seg, 10, 12, HUB_WALL_HEIGHT, HUB_WALL, hull)
			doorSegs[k] = seg
		elseif k == HUB_DOOR_WEST then
			Geo.doorSegment(hab, seg, 9, 11, HUB_WALL_HEIGHT, HUB_WALL, hull)
			doorSegs[k] = seg
		elseif k == HUB_DOOR_LAB then
			Geo.doorSegment(hab, seg, HUB_LAB_DOOR_WIDTH, HUB_LAB_DOOR_TOP, HUB_WALL_HEIGHT, HUB_WALL, hull)
			doorSegs[k] = seg
		else
			Geo.windowSegment(hab, seg, HUB_WALL_HEIGHT, HUB_WALL, 7, 11.5, hull, GLASS)
			part(hab, "SolarWrap", Vector3.new(seg.width - 0.8, 3.6, 0.2), seg.cf * CFrame.new(0, 14.4, -(HUB_WALL / 2 + 0.1)), solarWrap)
		end
		part(hab, "TrimBand", Vector3.new(seg.width, 0.5, 0.2), seg.cf * CFrame.new(0, 17.2, -(HUB_WALL / 2 + 0.12)), trimBand)
		-- Window frame pillar on the corner between this segment and the next one.
		local cornerDir = dirFromAngle(seg.angle + math.pi / HUB_SEGMENTS)
		local corner = o + cornerDir * ((HUB_APOTHEM + HUB_WALL / 2) / math.cos(math.pi / HUB_SEGMENTS)) + Vector3.new(0, 9.25, 0)
		part(hab, "Pillar", Vector3.new(1.1, 5, HUB_WALL + 0.3), CFrame.lookAt(corner, corner + cornerDir), hull)
		if k % 2 == 0 then
			local foot = o + cornerDir * ((HUB_APOTHEM + HUB_WALL) / math.cos(math.pi / HUB_SEGMENTS) + 0.25) + Vector3.new(0, 0.35, 0)
			part(hab, "FootLamp", Vector3.new(0.9, 0.5, 0.4), CFrame.lookAt(foot, foot + cornerDir), footLamp)
		end
	end

	-- Ceiling, a cyan ring and the white dome on top. The ceiling closes the room, so the dome's
	-- inside is never seen.
	local outerDiameter = (HUB_APOTHEM + HUB_WALL) * 2
	vcylinder(hab, "Ceiling", 1.5, outerDiameter + 1.4, v(0, HUB_WALL_HEIGHT + 0.75, 0), {
		color = Color3.fromRGB(205, 208, 214),
		material = Enum.Material.SmoothPlastic,
	})
	vcylinder(hab, "DomeRing", 0.5, outerDiameter + 2.2, v(0, HUB_ROOF_Y - 0.25, 0), {
		color = HULL_TRIM,
		material = Enum.Material.SmoothPlastic,
		shadow = false,
	})
	local _, cap = Geo.domeShell(hab, "Dome", v(0, HUB_ROOF_Y, 0), HUB_DOME_RX, HUB_DOME_RY, hull, {
		bands = 4,
		segments = HUB_SEGMENTS,
		thickness = 0.8,
		capAngle = math.rad(72),
	})
	local capTop = cap.Position.Y + 0.4
	vcylinder(hab, "Skylight", 0.4, 8, Vector3.new(o.X, capTop + 0.2, o.Z), {
		color = ACCENT_SYSTEM:Lerp(PALETTE.night, 0.4),
		material = Enum.Material.Glass,
		reflectance = 0.2,
		shadow = false,
	})
	vcylinder(hab, "RoofMast", 4, 0.5, Vector3.new(o.X + 6, capTop + 2, o.Z - 4), { color = METAL, material = Enum.Material.Metal })
	local beacon = ball(hab, "RoofBeacon", 1.2, Vector3.new(o.X + 6, capTop + 4.4, o.Z - 4), {
		color = ACCENT_SYSTEM,
		material = Enum.Material.Neon,
		shadow = false,
	})
	pointLight(beacon, ACCENT_SYSTEM, 10, 1, false)

	-- Stage 9: what each habitat level (base level 2 to 5) adds to the hub (WorldStructures).
	local tierSolids = Six.buildHabitatTiers(hab, o, capTop, {
		[HUB_DOOR_NORTH] = true,
		[HUB_DOOR_SOUTH] = true,
		[HUB_DOOR_WEST] = true,
		[HUB_DOOR_LAB] = true,
	})

	-- Door frames and lamps (north and south); the west doorway gets the greenhouse hatch.
	Geo.doorDressing(hab, doorSegs[HUB_DOOR_NORTH], 10, 12, HUB_WALL)
	Geo.doorDressing(hab, doorSegs[HUB_DOOR_SOUTH], 10, 12, HUB_WALL)
	local westSeg = doorSegs[HUB_DOOR_WEST]
	local greenhouseHatch = part(hab, "GreenhouseHatch", Vector3.new(9, 10.5, 0.4), westSeg.cf * CFrame.new(0, 0.5 + 5.25, 0), {
		color = Color3.fromRGB(205, 236, 232),
		material = Enum.Material.Glass,
		transparency = 0.6,
		shadow = false,
	})
	local hatchFrame: Style = { color = ACCENT_SECRET, material = Enum.Material.SmoothPlastic, shadow = false } -- magenta = greenhouse
	local inner = HUB_WALL / 2 + 0.3
	for _, side in { -1, 1 } do
		part(hab, "HatchFrame", Vector3.new(0.6, 11.3, 0.6), westSeg.cf * CFrame.new(side * 4.8, 5.65, inner), hatchFrame)
	end
	part(hab, "HatchFrame", Vector3.new(10.2, 0.6, 0.6), westSeg.cf * CFrame.new(0, 11.3, inner), hatchFrame)
	-- Stage 10: the lab doorway's hatch, framed in cyan (systems).
	local labSeg = doorSegs[HUB_DOOR_LAB]
	local labHatchHeight = HUB_LAB_DOOR_TOP - 0.5
	local labHatch = part(hab, "LabHatch", Vector3.new(HUB_LAB_DOOR_WIDTH, labHatchHeight, 0.4), labSeg.cf * CFrame.new(0, 0.5 + labHatchHeight / 2, 0), {
		color = Color3.fromRGB(205, 236, 232),
		material = Enum.Material.Glass,
		transparency = 0.6,
		shadow = false,
	})
	local labFrame: Style = { color = ACCENT_SYSTEM, material = Enum.Material.SmoothPlastic, shadow = false }
	for _, side in { -1, 1 } do
		local x = side * (HUB_LAB_DOOR_WIDTH / 2 + 0.3)
		part(hab, "HatchFrame", Vector3.new(0.6, HUB_LAB_DOOR_TOP + 0.3, 0.6), labSeg.cf * CFrame.new(x, (HUB_LAB_DOOR_TOP + 0.3) / 2, inner), labFrame)
	end
	part(hab, "HatchFrame", Vector3.new(HUB_LAB_DOOR_WIDTH + 1.2, 0.6, 0.6), labSeg.cf * CFrame.new(0, HUB_LAB_DOOR_TOP + 0.3, inner), labFrame)

	-- Ceiling lights. Players spend the planning phase in here, so the room must be bright. Every
	-- interior light casts shadows, so none of it leaks through the walls onto the ground outside.
	for _, z in { -8, 8 } do
		local strip = box(hab, "CeilingLight", v(-20, 17.4, z - 0.5), v(20, 18, z + 0.5), {
			color = Color3.fromRGB(255, 240, 215),
			material = Enum.Material.Neon,
			shadow = false,
		})
		pointLight(strip, INTERIOR_LIGHT, 40, 1.6, true)
		local wash = Instance.new("SurfaceLight")
		wash.Face = Enum.NormalId.Bottom
		wash.Angle = 120
		wash.Range = 20
		wash.Brightness = 1.4
		wash.Color = INTERIOR_LIGHT
		wash.Shadows = true
		wash.Parent = strip
	end
	-- Corner lamps fill the far ends of the room.
	for _, x in { -24, 24 } do
		for _, z in { -14, 14 } do
			local lamp = box(hab, "CornerLamp", v(x - 1, 17.2, z - 1), v(x + 1, 18, z + 1), {
				color = Color3.fromRGB(255, 240, 215),
				material = Enum.Material.Neon,
				shadow = false,
			})
			pointLight(lamp, INTERIOR_LIGHT, 20, 1, true)
		end
	end

	-- Power board console.
	local console = box(hab, "PowerConsole", v(-22, 0.5, -14), v(-14, 4, -10), { color = DARK_METAL, material = Enum.Material.Metal })
	part(
		hab,
		"ConsoleScreen",
		Vector3.new(7, 3, 0.3),
		CFrame.new(v(-18, 5.6, -13.2)) * CFrame.Angles(math.rad(-20), 0, 0),
		{ color = ACCENT_SYSTEM, material = Enum.Material.Neon, shadow = false }
	)
	local consolePrompt = makePrompt(console, "prompt.console", "Power board", 0)

	-- Stage 9: the mission console on the east side of the room. Missions start here (the client opens
	-- the mission panel on "MissionConsolePrompt"); it works whenever the habitat stands.
	local missionConsole = box(hab, "MissionConsole", v(24, 0.5, 1), v(27.5, 4, 7), { color = DARK_METAL, material = Enum.Material.Metal })
	local missionScreen = part(
		hab,
		"MissionScreen",
		Vector3.new(0.3, 3, 5.5),
		CFrame.new(v(24.8, 5.6, 4)) * CFrame.Angles(0, 0, math.rad(-20)),
		{ color = ACCENT_WARNING, material = Enum.Material.Neon, shadow = false }
	)
	local missionGui = Instance.new("SurfaceGui")
	missionGui.Name = "MissionIcon"
	missionGui.Face = Enum.NormalId.Left -- toward the middle of the room
	missionGui.LightInfluence = 0
	missionGui.CanvasSize = Vector2.new(110, 60)
	missionGui.Parent = missionScreen
	local missionIcon = Instance.new("ImageLabel")
	missionIcon.BackgroundTransparency = 1
	missionIcon.Size = UDim2.fromScale(0.5, 0.9)
	missionIcon.Position = UDim2.fromScale(0.25, 0.05)
	missionIcon.ScaleType = Enum.ScaleType.Fit
	missionIcon.Image = Icons.target
	missionIcon.ImageColor3 = PALETTE.night
	missionIcon.Parent = missionGui
	local missionConsolePrompt = makePrompt(missionConsole, "prompt.missions", "Missions", 0)
	missionConsolePrompt.Name = "MissionConsolePrompt"

	-- Water processor: melts ice and splits water into oxygen with electricity.
	box(hab, "ProcessorBase", v(14, 0.5, -17), v(22, 1.5, -10), { color = DARK_METAL, material = Enum.Material.Metal })
	vcylinder(hab, "ProcessorTank", 8, 5, v(18, 5.5, -14), { color = Color3.fromRGB(200, 205, 212), material = Enum.Material.Metal })
	local processorWindow = box(hab, "ProcessorWindow", v(17.2, 3.2, -11.6), v(18.8, 7.8, -11.3), {
		color = AIR_WINDOW_ON,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local processorGlow = pointLight(processorWindow, AIR_WINDOW_ON, 12, 1, false)

	-- Air maker beside it: electricity splits water into oxygen. Its fan and status light show
	-- how much power life support gets today.
	box(hab, "AirMaker", v(9.5, 0.5, -17), v(13.5, 7, -13), { color = Color3.fromRGB(214, 218, 224), material = Enum.Material.SmoothPlastic })
	local towardRoom = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis along world Z
	cylinder(hab, "FanHousing", 0.2, 3.4, CFrame.new(v(11.5, 4, -12.9)) * towardRoom, {
		color = DARK_METAL,
		material = Enum.Material.Metal,
	})
	local fanCFrame = CFrame.new(v(11.5, 4, -12.65))
	local bladeStyle: Style = { color = Color3.fromRGB(200, 204, 210), material = Enum.Material.Metal, collide = false, shadow = false }
	local fanRoot = part(hab, "FanBlades", Vector3.new(0.45, 3, 0.1), fanCFrame, bladeStyle)
	local fanCross = part(hab, "FanBlades", Vector3.new(3, 0.45, 0.1), fanCFrame, bladeStyle)
	local fanHub = cylinder(hab, "FanHub", 0.3, 0.8, fanCFrame * CFrame.new(0, 0, 0.1) * towardRoom, {
		color = HULL_TRIM,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	weldTo(fanRoot, { fanCross, fanHub })
	local airStatus = ball(hab, "AirStatusLight", 1, v(11.5, 7.5, -15), {
		color = AIR_OK,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local airStatusLight = pointLight(airStatus, AIR_OK, 10, 1.5, false)
	cylinder(hab, "AirMakerPipe", 2.6, 0.6, CFrame.new(v(14.6, 5.8, -15)), { color = METAL, material = Enum.Material.Metal })
	zcylinder(hab, "ProcessorPipe", 5, 0.8, v(18, 9.2, -16.5), { color = METAL, material = Enum.Material.Metal })
	local inlet = box(hab, "ProcessorInlet", v(16.5, 1.5, -11), v(19.5, 4, -9.4), {
		color = HULL_TRIM,
		material = Enum.Material.SmoothPlastic,
	})
	local processorPrompt = makePrompt(inlet, "prompt.deliver", "Deliver ice", 0.5)

	-- Water tank beside the processor: melted ice is stored here before the air maker splits it.
	-- Its glass shows how much water the base has (World.setWaterLevel).
	local tankCentre = o + S7.TANK_OFFSET
	local tankHeight = 7
	local tankDiameter = 3.6
	local tankBottom = 1.5
	vcylinder(hab, "WaterTankBase", 1, tankDiameter + 0.8, tankCentre + Vector3.new(0, 1, 0), {
		color = DARK_METAL,
		material = Enum.Material.Metal,
	})
	vcylinder(hab, "WaterTankGlass", tankHeight, tankDiameter, tankCentre + Vector3.new(0, tankBottom + tankHeight / 2, 0), {
		color = Color3.fromRGB(210, 230, 240),
		material = Enum.Material.Glass,
		transparency = 0.7,
		shadow = false,
	})
	vcylinder(hab, "WaterTankCap", 0.6, tankDiameter + 0.4, tankCentre + Vector3.new(0, tankBottom + tankHeight + 0.3, 0), {
		color = METAL,
		material = Enum.Material.Metal,
	})
	local fillDiameter = tankDiameter - 0.4
	local fillHeight = tankHeight - 0.2
	local waterFill = vcylinder(hab, "WaterFill", fillHeight, fillDiameter, tankCentre + Vector3.new(0, tankBottom + fillHeight / 2, 0), {
		color = WATER_COLOUR,
		material = Enum.Material.SmoothPlastic,
		transparency = 0.15,
		collide = false,
		shadow = false,
	})
	local waterLight = pointLight(waterFill, WATER_COLOUR, 9, 0.8, false)
	-- Pipe from the tank to the processor, and a level light on the front (lime, orange, red).
	cylinder(hab, "WaterPipe", 2.6, 0.6, CFrame.new(tankCentre + Vector3.new(-2.9, 7, -0.5)), { color = METAL, material = Enum.Material.Metal })
	local gaugeZ = tankCentre.Z + tankDiameter / 2 + 0.2
	local gauge = box(hab, "WaterGauge", Vector3.new(tankCentre.X - 0.7, 2.6, gaugeZ - 0.1), Vector3.new(tankCentre.X + 0.7, 3.4, gaugeZ + 0.1), {
		color = ACCENT_OK,
		material = Enum.Material.Neon,
		shadow = false,
	})
	-- Water sign hanging above the tank, facing the room.
	local signZ = gaugeZ + 0.1
	box(hab, "SignHanger", Vector3.new(tankCentre.X - 0.05, 14, signZ - 0.15), Vector3.new(tankCentre.X + 0.05, 18, signZ - 0.05), {
		color = DARK_METAL,
		material = Enum.Material.Metal,
		collide = false,
		shadow = false,
	})
	local sign = box(hab, "WaterSign", Vector3.new(tankCentre.X - 1, 12, signZ - 0.2), Vector3.new(tankCentre.X + 1, 14, signZ), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "WaterIcon"
	signGui.Face = Enum.NormalId.Back
	signGui.LightInfluence = 0
	signGui.CanvasSize = Vector2.new(64, 64)
	signGui.Parent = sign
	local signIcon = Instance.new("ImageLabel")
	signIcon.BackgroundTransparency = 1
	signIcon.Size = UDim2.fromScale(0.8, 0.8)
	signIcon.Position = UDim2.fromScale(0.1, 0.1)
	signIcon.Image = Icons.drop
	signIcon.ImageColor3 = PALETTE.cyan
	signIcon.Parent = signGui

	-- Plant rack under a grow light (north-west, out of the way of the back door).
	box(hab, "PlantRack", v(-24, 0.5, 11), v(-10, 3, 13.8), { color = Color3.fromRGB(235, 235, 240), material = Enum.Material.SmoothPlastic })
	local rackPlants: { Part } = {}
	for i = 0, 3 do
		local x = -22.5 + i * 3.7
		table.insert(
			rackPlants,
			box(hab, "Plant", v(x - 1.2, 3, 11.5), v(x + 1.2, 4.6, 13.3), {
				color = PLANT_GREEN,
				material = Enum.Material.Grass,
			})
		)
	end
	local grow = box(hab, "GrowLight", v(-24, 7.5, 11.4), v(-10, 7.9, 13.4), {
		color = GROW_PINK,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local growPoint = pointLight(grow, GROW_PINK, 10, 1, false)

	-- Crew table.
	box(hab, "TableLeg", v(-1, 0.5, -5), v(1, 3, -3), { color = METAL, material = Enum.Material.Metal })
	box(hab, "TableTop", v(-5, 3, -7), v(5, 3.4, -1), { color = Color3.fromRGB(235, 236, 240), material = Enum.Material.SmoothPlastic })

	-- Air pipe on the outer east wall, where the leak appears.
	local eastX = o.X + HUB_APOTHEM + HUB_WALL
	zcylinder(hab, "AirPipe", 11, 1.2, Vector3.new(eastX + 1.2, 4, o.Z), { color = METAL, material = Enum.Material.Metal })
	local leakPart = box(hab, "AirPipeJoint", Vector3.new(eastX, 3, o.Z + 3), Vector3.new(eastX + 2.4, 5, o.Z + 5), {
		color = METAL,
		material = Enum.Material.Metal,
	})
	local attachment = Instance.new("Attachment")
	attachment.Name = "LeakVent"
	attachment.Position = Vector3.new(1.2, 0, 0)
	attachment.Parent = leakPart
	local gas = Instance.new("ParticleEmitter")
	gas.Name = "LeakGas"
	gas.Color = ColorSequence.new(Color3.fromRGB(235, 240, 245))
	gas.Size = NumberSequence.new(0.6, 2.2)
	gas.Transparency = NumberSequence.new(0.3, 1)
	gas.Lifetime = NumberRange.new(0.5, 0.9)
	gas.Rate = 40
	gas.Speed = NumberRange.new(8, 12)
	gas.SpreadAngle = Vector2.new(20, 20)
	gas.EmissionDirection = Enum.NormalId.Right
	gas.Enabled = false
	gas.Parent = attachment
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "LeakSparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Rate = 25
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(45, 45)
	sparks.EmissionDirection = Enum.NormalId.Right
	sparks.Acceleration = Vector3.new(0, -20, 0)
	sparks.Enabled = false
	sparks.Parent = attachment
	local leakLight = pointLight(leakPart, ACCENT_WARNING, 14, 2, false)
	leakLight.Enabled = false
	local leakPrompt = makePrompt(leakPart, "prompt.repair", "Fix leak", 2)

	-- Stage 8: the whole round room, floor to ceiling (the doorways' inner half counts too).
	local zonePart = shapedZone(
		base,
		"HabitatZone",
		CFrame.new(v(0, 9.25, 0)),
		Vector3.new(HUB_ZONE_RADIUS * 2, 17.5, HUB_ZONE_RADIUS * 2),
		"cylinder"
	)

	return {
		model = hab,
		zone = zonePart,
		console = console,
		consolePrompt = consolePrompt,
		missionConsole = missionConsole,
		missionConsolePrompt = missionConsolePrompt,
		tierSolids = tierSolids,
		processorPrompt = processorPrompt,
		leakPart = leakPart,
		leakPrompt = leakPrompt,
		leakEmitters = { gas, sparks },
		leakLight = leakLight,
		lifeSupport = {
			window = processorWindow,
			windowLight = processorGlow,
			status = airStatus,
			statusLight = airStatusLight,
			fanRoot = fanRoot,
			fanCFrame = fanCFrame,
		},
		rackLight = grow,
		rackPointLight = growPoint,
		rackPlants = rackPlants,
		processorInlet = inlet,
		waterTank = {
			fill = waterFill,
			light = waterLight,
			gauge = gauge,
			bottomY = tankCentre.Y + tankBottom,
			height = fillHeight,
			centre = tankCentre,
			diameter = fillDiameter,
		},
		greenhouseHatch = greenhouseHatch,
		labHatch = labHatch,
	}
end

------------------------------------------------------------------------------------------------
-- Greenhouse: glass domes linked to the hub by a walk-through tube
------------------------------------------------------------------------------------------------

type GreenhouseRefs = {
	model: Model, -- level 1: dome A and the tube from the hub's west doorway
	model2: Model, -- level 2: dome B and the short walk-through tube from dome A
	strips: { Part },
	stripLights: { PointLight },
	plants: { Part },
	centre: Vector3,
	foodPrompt: ProximityPrompt,
	-- Stage 8: pressurized zones (the hub tube, dome A, dome B).
	tubeZone: Part,
	domeZone: Part,
	dome2Zone: Part,
	-- Stage 10: the walk-through link tube between the domes (its zone counts from level 2) and the
	-- glass panels that close dome A's doorway toward it until then.
	linkZone: Part,
	linkHatch: { Part },
}

local GREENHOUSE_GLASS: Style = {
	color = Color3.fromRGB(205, 236, 232),
	material = Enum.Material.Glass,
	transparency = 0.62,
	shadow = false,
}

-- Stage 10 (playtest: every tube between modules is walkable): optional shape of a walk tube.
-- startAt / endAt give, for a line parallel to the tube axis (origin at the tube's start, unit
-- direction), the distance along it where a hull slat starts or ends (default: 0 and the length), so
-- the hull can meet a round wall or a glass dome without a gap. floorFrom / floorTo do the same for the
-- floor plate. ribs are fractions of the tube where a trim ring goes round the outside.
type WalkTubeOptions = {
	apothem: number?, -- inner half-width of the octagon (default TUBE_APOTHEM)
	axisHeight: number?, -- axis above the floor's bottom face (default TUBE_AXIS_Y)
	floorWidth: number?,
	glass: Style?,
	startAt: ((origin: Vector3, dir: Vector3) -> number?)?,
	endAt: ((origin: Vector3, dir: Vector3) -> number?)?,
	floorFrom: number?,
	floorTo: number?,
	ribs: { number }?,
	ribStyle: Style?,
	hood: Style?, -- hull reaching past a or b (into a dome) is built in this style (dome glass)
}

-- Where a line (origin + dir * t) crosses a plane through `point` with normal `normal`.
function Geo.planeTrim(point: Vector3, normal: Vector3): (Vector3, Vector3) -> number?
	return function(origin: Vector3, dir: Vector3): number?
		local along = normal:Dot(dir)
		if math.abs(along) < 1e-4 then
			return nil
		end
		return normal:Dot(point - origin) / along
	end
end

-- Where a line meets an upright half ellipsoid (radius rx, height ry) standing at `centre`: the far
-- crossing when `leaving` (the tube starts inside it), else the near one. ry = math.huge is a round
-- wall (an upright cylinder).
function Geo.domeTrim(centre: Vector3, rx: number, ry: number, leaving: boolean): (Vector3, Vector3) -> number?
	return function(origin: Vector3, dir: Vector3): number?
		local p = origin - centre
		local iy = if ry == math.huge then 0 else 1 / (ry * ry)
		local ix = 1 / (rx * rx)
		local qa = (dir.X * dir.X + dir.Z * dir.Z) * ix + dir.Y * dir.Y * iy
		local qb = 2 * ((p.X * dir.X + p.Z * dir.Z) * ix + p.Y * dir.Y * iy)
		local qc = (p.X * p.X + p.Z * p.Z) * ix + p.Y * p.Y * iy - 1
		local disc = qb * qb - 4 * qa * qc
		if qa < 1e-9 or disc < 0 then
			return nil
		end
		local root = math.sqrt(disc)
		return if leaving then (-qb + root) / (2 * qa) else (-qb - root) / (2 * qa)
	end
end

-- A pressurized walk-through tube from a to b (points on the floor's bottom face, so a.Y = b.Y = 0
-- is flat ground; a different height makes a gentle ramp): an octagon of hull slats around the axis
-- with glass windows on the upper sides, a floor with cyan guide strips and a blue solar strip on top.
function Geo.walkTube(parent: Instance, a: Vector3, b: Vector3, opts: WalkTubeOptions?)
	local o: WalkTubeOptions = opts or {}
	local apothem = o.apothem or TUBE_APOTHEM
	local axisHeight = o.axisHeight or TUBE_AXIS_Y
	local floorWidth = o.floorWidth or 10.6
	local flat = flatUnit(b - a, Vector3.xAxis)
	local rise = b.Y - a.Y
	local run = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	local dir = if math.abs(rise) > 1e-3 then (flat * run + Vector3.new(0, rise, 0)).Unit else flat
	local length = math.sqrt(run * run + rise * rise)
	local up = (Vector3.yAxis - dir * dir.Y).Unit
	local side = dir:Cross(up) -- flat tubes: (-dir.Z, 0, dir.X), as before Stage 10
	local axis0 = a + up * axisHeight -- the axis at the tube's start
	local function along(t: number): Vector3
		return dir * t
	end
	-- Slat k's span along the axis (trimmed at the ends where options ask for it).
	local function span(lineOrigins: { Vector3 }): (number, number)
		local t0, t1 = 0, length
		if o.startAt then
			local best: number? = nil
			for _, origin in lineOrigins do
				local t = o.startAt(origin, dir)
				if t and (best == nil or t < best) then
					best = t
				end
			end
			t0 = best or t0
		end
		if o.endAt then
			local best: number? = nil
			for _, origin in lineOrigins do
				local t = o.endAt(origin, dir)
				if t and (best == nil or t > best) then
					best = t
				end
			end
			t1 = best or t1
		end
		return t0, t1
	end
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	local glass = o.glass or GREENHOUSE_GLASS
	local slatRadius = apothem + 0.3
	local slatWidth = 2 * slatRadius * math.tan(math.pi / 8) + 0.15
	local topFrom, topTo = 0, length
	for k = 0, 7 do
		if k == 4 then
			continue -- the bottom side is the floor plate
		end
		local alpha = k * math.pi / 4
		local normal = up * math.cos(alpha) + side * math.sin(alpha)
		local tangent = up * -math.sin(alpha) + side * math.cos(alpha)
		local offset = normal * slatRadius
		-- Trim along the slat's middle line, so it meets a round wall or dome right where it crosses.
		local t0, t1 = span({ axis0 + offset })
		if t1 - t0 < 0.2 then
			continue
		end
		local style = if k == 1 or k == 7 then glass else hull
		local hood = o.hood
		if hood then
			-- The stretch past each end (inside a dome) is a glass hood; the hull stays between a and b.
			local c0, c1 = math.max(t0, 0), math.min(t1, length)
			for _, piece in { { t0, c0 }, { c1, t1 } } do
				if piece[2] - piece[1] > 0.1 then
					local mid = axis0 + offset + along((piece[1] + piece[2]) / 2)
					part(parent, "TubeHood", Vector3.new(piece[2] - piece[1], slatWidth, 0.6), CFrame.fromMatrix(mid, dir, tangent), hood)
				end
			end
			t0, t1 = c0, c1
			if t1 - t0 < 0.2 then
				continue
			end
		end
		if k == 0 then
			topFrom, topTo = t0, t1
		end
		local centre = axis0 + offset + along((t0 + t1) / 2)
		part(parent, "TubeShell", Vector3.new(t1 - t0, slatWidth, 0.6), CFrame.fromMatrix(centre, dir, tangent), style)
	end
	local floorFrom = o.floorFrom or 0
	local floorTo = o.floorTo or length
	part(parent, "TubeFloor", Vector3.new(floorTo - floorFrom, 0.5, floorWidth), CFrame.fromMatrix(a + up * 0.25 + along((floorFrom + floorTo) / 2), dir, up), {
		color = Color3.fromRGB(176, 180, 186),
		material = Enum.Material.DiamondPlate,
	})
	local guide: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }
	local guideFrom, guideTo = math.max(floorFrom, 0), math.min(floorTo, length)
	for _, s in { -1, 1 } do
		part(
			parent,
			"TubeGuide",
			Vector3.new(guideTo - guideFrom - 1, 0.06, 0.3),
			CFrame.fromMatrix(a + up * 0.53 + side * (s * (floorWidth / 2 - 0.7)) + along((guideFrom + guideTo) / 2), dir, up),
			guide
		)
	end
	local topMid = (topFrom + topTo) / 2
	local topLength = topTo - topFrom
	part(parent, "TubeSolar", Vector3.new(topLength - 1, 0.15, 3.4), CFrame.fromMatrix(axis0 + up * (apothem + 0.7) + along(topMid), dir, up), {
		color = PANEL_CLEAN,
		material = Enum.Material.Glass,
		reflectance = 0.12,
		collide = false,
		shadow = false,
	})
	local lamp = part(parent, "TubeLight", Vector3.new(math.max(1, topLength - 4), 0.2, 0.8), CFrame.fromMatrix(axis0 + up * (apothem - 0.1) + along(topMid), dir, up), {
		color = Color3.fromRGB(255, 240, 215),
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	pointLight(lamp, INTERIOR_LIGHT, 14, 0.6, true)
	-- Trim rings round the outside (no collisions, so they never catch a player).
	local ribs = o.ribs
	if ribs then
		local ribStyle: Style = o.ribStyle or { color = HULL_TRIM, material = Enum.Material.SmoothPlastic, shadow = false }
		local ribRadius = apothem + 0.85
		local ribWidth = 2 * ribRadius * math.tan(math.pi / 8) + 0.2
		for _, f in ribs do
			local at = topFrom + f * topLength
			for k = 0, 7 do
				if k == 4 then
					continue
				end
				local alpha = k * math.pi / 4
				local normal = up * math.cos(alpha) + side * math.sin(alpha)
				local tangent = up * -math.sin(alpha) + side * math.cos(alpha)
				part(parent, "TubeRib", Vector3.new(0.8, ribWidth, 0.5), CFrame.fromMatrix(axis0 + normal * ribRadius + along(at), dir, tangent), {
					color = ribStyle.color,
					material = ribStyle.material,
					collide = false,
					shadow = false,
				})
			end
		end
	end
end

type PlanterRefs = { strips: { Part }, lights: { PointLight }, plants: { Part } }

-- A planter row along world Z (x, from z0 to z1) on a dome floor, under a hanging grow light.
function Geo.planterRow(parent: Instance, rng: Random, dome: Vector3, rx: number, ry: number, x: number, z0: number, z1: number, refs: PlanterRefs)
	box(parent, "Planter", Vector3.new(x - 1.3, 0.5, z0), Vector3.new(x + 1.3, 1.6, z1), {
		color = Color3.fromRGB(236, 236, 240),
		material = Enum.Material.SmoothPlastic,
	})
	box(parent, "Soil", Vector3.new(x - 1.1, 1.6, z0 + 0.2), Vector3.new(x + 1.1, 1.8, z1 - 0.2), {
		color = Color3.fromRGB(92, 70, 52),
		material = Enum.Material.Ground,
	})
	local count = math.max(2, math.floor((z1 - z0) / 3.3))
	for i = 0, count - 1 do
		local d = rng:NextNumber(1.5, 1.95)
		local pz = z0 + (i + 0.5) * (z1 - z0) / count + rng:NextNumber(-0.3, 0.3)
		table.insert(
			refs.plants,
			ball(parent, "Plant", d, Vector3.new(x + rng:NextNumber(-0.2, 0.2), 1.8 + d * 0.32, pz), {
				color = PLANT_GREEN,
				material = Enum.Material.Grass,
				collide = false,
			})
		)
	end
	local stripY = 7
	local strip = box(parent, "GrowLight", Vector3.new(x - 0.35, stripY, z0 + 0.5), Vector3.new(x + 0.35, stripY + 0.3, z1 - 0.5), {
		color = GROW_PINK,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	table.insert(refs.strips, strip)
	table.insert(refs.lights, pointLight(strip, GROW_PINK, GROW_RANGE[3], GROW_BRIGHTNESS[3], false))
	for _, hz in { z0 + 2, z1 - 2 } do
		local d = (Vector3.new(x, 0, hz) - Vector3.new(dome.X, 0, dome.Z)).Magnitude
		local top = math.max(stripY + 0.6, Geo.domeHeightAt(rx, ry, d) - 0.4)
		box(parent, "Hanger", Vector3.new(x - 0.05, stripY + 0.3, hz - 0.05), Vector3.new(x + 0.05, top, hz + 0.05), {
			color = DARK_METAL,
			material = Enum.Material.Metal,
			collide = false,
			shadow = false,
		})
	end
end

local function buildGreenhouse(base: Instance): GreenhouseRefs
	local gh = model(base, "Greenhouse")
	local gh2 = model(base, "GreenhouseDome2")
	-- Own random stream so the rest of the base keeps its layout.
	local rng = Random.new(2015)
	local refs: PlanterRefs = { strips = {}, lights = {}, plants = {} }
	local metal: Style = { color = METAL, material = Enum.Material.Metal }
	local floorStyle: Style = { color = Color3.fromRGB(176, 180, 186), material = Enum.Material.DiamondPlate }

	-- Dome A and the walk-through tube from the hub's west doorway (along the hub's centre line).
	local a = S7.GREENHOUSE_A
	local lineZ = HABITAT_CENTRE.Z
	local hubX = HABITAT_CENTRE.X - (HUB_APOTHEM + HUB_WALL / 2)
	local entryX = a.X + math.sqrt(GREENHOUSE_A_RX * GREENHOUSE_A_RX - (lineZ - a.Z) * (lineZ - a.Z))
	local tubeFrom = Vector3.new(hubX, 0, lineZ)
	local tubeTo = Vector3.new(entryX - 3, 0, lineZ)
	-- Stage 10 (playtest: "dome A has a hole"): the hull is trimmed where it meets dome A's glass, and
	-- the upper slats reach on into the dome as glass, so the doorway's top panels leave no opening.
	Geo.walkTube(gh, tubeFrom, tubeTo, {
		-- 1.5 studs inside the glass: the top slat then runs under the doorway's top panels, leaving no
		-- sliver beside it (0.6 left 1-stud gaps at the slat's corners).
		endAt = Geo.domeTrim(a, GREENHOUSE_A_RX - 1.5, GREENHOUSE_A_RY - 1.5, false),
		hood = GREENHOUSE_GLASS,
	})
	vcylinder(gh, "Floor", 0.5, GREENHOUSE_A_RX * 2, a + Vector3.new(0, 0.25, 0), floorStyle)
	local entryAngle = math.atan2(entryX - a.X, lineZ - a.Z)
	local segmentsA = 14
	-- Stage 10: a second doorway toward dome B, on the panel edge nearest to it (dome A's panels are
	-- lined up with the hub tube's doorway). Until level 2 its glass panels stand as a hatch.
	local b = S7.GREENHOUSE_B
	local stepA = 2 * math.pi / segmentsA
	local towardB = math.atan2(b.X - a.X, b.Z - a.Z)
	local linkEdge = math.floor((towardB - entryAngle) / stepA + 0.5)
	local linkAngle = entryAngle + linkEdge * stepA
	local skipA = Geo.domeDoorway(segmentsA, 4)
	local linkKeys: { [number]: boolean } = {}
	for band = 1, 4 do
		for _, i in { linkEdge - 1, linkEdge } do
			linkKeys[band * 1000 + i % segmentsA] = true
			skipA[band * 1000 + i % segmentsA] = true
		end
	end
	local _, capA = Geo.domeShell(gh, "DomeGlass", a, GREENHOUSE_A_RX, GREENHOUSE_A_RY, GREENHOUSE_GLASS, {
		bands = 5,
		segments = segmentsA,
		thickness = 0.4,
		rotation = entryAngle + math.pi / segmentsA,
		capAngle = math.rad(75),
		skip = skipA,
		capStyle = metal,
	})
	local hatchSkip: { [number]: boolean } = {}
	for band = 1, 5 do
		for i = 0, segmentsA - 1 do
			if not linkKeys[band * 1000 + i] then
				hatchSkip[band * 1000 + i] = true
			end
		end
	end
	local linkHatch, hatchCap = Geo.domeShell(gh, "LinkHatch", a, GREENHOUSE_A_RX, GREENHOUSE_A_RY, GREENHOUSE_GLASS, {
		bands = 5,
		segments = segmentsA,
		thickness = 0.4,
		rotation = entryAngle + math.pi / segmentsA,
		capAngle = math.rad(75),
		skip = hatchSkip,
	})
	hatchCap:Destroy()
	ball(gh, "DomeBeacon", 0.9, capA.Position + Vector3.new(0, 0.6, 0), {
		color = ACCENT_SECRET,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	-- Planter rows; the third row is short so the path from the tube stays open. Stage 10: they stop
	-- at a.Z + 6, leaving a walkway along the north side to the link tube toward dome B.
	Geo.planterRow(gh, rng, a, GREENHOUSE_A_RX, GREENHOUSE_A_RY, a.X - 8, a.Z - 9, a.Z + 6, refs)
	Geo.planterRow(gh, rng, a, GREENHOUSE_A_RX, GREENHOUSE_A_RY, a.X - 3.5, a.Z - 9, a.Z + 6, refs)
	Geo.planterRow(gh, rng, a, GREENHOUSE_A_RX, GREENHOUSE_A_RY, a.X + 1, a.Z - 2, a.Z + 6, refs)

	-- Harvest table: fresh salad heads on a tray. Players pick food here (ToolService, BaseService).
	local tableAt = a + Vector3.new(7, 0, 5)
	for _, dx in { -1.6, 1.6 } do
		for _, dz in { -0.9, 0.9 } do
			box(gh, "TableLeg", tableAt + Vector3.new(dx - 0.15, 0.5, dz - 0.15), tableAt + Vector3.new(dx + 0.15, 3, dz + 0.15), metal)
		end
	end
	box(gh, "HarvestTable", tableAt + Vector3.new(-2, 3, -1.2), tableAt + Vector3.new(2, 3.3, 1.2), {
		color = Color3.fromRGB(236, 236, 240),
		material = Enum.Material.SmoothPlastic,
	})
	local tray = box(gh, "HarvestTray", tableAt + Vector3.new(-1.5, 3.3, -0.8), tableAt + Vector3.new(1.5, 3.6, 0.8), {
		color = ACCENT_OK,
		material = Enum.Material.SmoothPlastic,
		shadow = false,
	})
	for i, dx in { -0.9, 0, 0.9 } do
		ball(gh, "Lettuce", 0.9 + i * 0.05, tableAt + Vector3.new(dx, 4, (i - 2) * 0.25), {
			color = PLANT_GREEN:Lerp(ACCENT_OK, 0.3),
			material = Enum.Material.Grass,
			collide = false,
			shadow = false,
		})
	end
	local foodPrompt = Instance.new("ProximityPrompt")
	foodPrompt.Name = "FoodPrompt"
	foodPrompt.ActionText = "Pick food"
	foodPrompt.ObjectText = ""
	foodPrompt.HoldDuration = 0.5
	foodPrompt.MaxActivationDistance = PROMPT_DISTANCE
	foodPrompt.RequiresLineOfSight = false
	foodPrompt.Enabled = false
	foodPrompt:SetAttribute("TextKey", "prompt.pick_food")
	foodPrompt.Parent = tray
	-- A small nutrient tank by the wall (plants drink water too).
	local tankAt = a + Vector3.new(-2, 0, -11)
	vcylinder(gh, "NutrientTank", 4, 2.4, tankAt + Vector3.new(0, 2.5, 0), {
		color = WATER_COLOUR,
		material = Enum.Material.Glass,
		transparency = 0.3,
		shadow = false,
	})
	vcylinder(gh, "NutrientCap", 0.4, 2.8, tankAt + Vector3.new(0, 4.7, 0), metal)

	-- Level 2: dome B north of dome A. Stage 10: joined by a short walk-through tube from dome A's
	-- second doorway, aimed at dome B's centre; dome B's panels line up with it for its doorway.
	local linkFrom = a + dirFromAngle(linkAngle) * GREENHOUSE_A_RX
	local toB = flatUnit(b - linkFrom, Vector3.zAxis)
	local linkTo = b - toB * GREENHOUSE_B_RX
	local segmentsB = 12
	local arrivalB = math.atan2(-toB.X, -toB.Z)
	vcylinder(gh2, "Floor", 0.5, GREENHOUSE_B_RX * 2, b + Vector3.new(0, 0.25, 0), floorStyle)
	local _, capB = Geo.domeShell(gh2, "DomeGlass", b, GREENHOUSE_B_RX, GREENHOUSE_B_RY, GREENHOUSE_GLASS, {
		bands = 5,
		segments = segmentsB,
		thickness = 0.4,
		rotation = arrivalB + math.pi / segmentsB,
		capAngle = math.rad(75),
		skip = Geo.domeDoorway(segmentsB, 4),
		capStyle = metal,
	})
	ball(gh2, "DomeBeacon", 0.9, capB.Position + Vector3.new(0, 0.6, 0), {
		color = ACCENT_SECRET,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	Geo.planterRow(gh2, rng, b, GREENHOUSE_B_RX, GREENHOUSE_B_RY, b.X - 4, b.Z - 7, b.Z + 7, refs)
	Geo.planterRow(gh2, rng, b, GREENHOUSE_B_RX, GREENHOUSE_B_RY, b.X + 3, b.Z - 7, b.Z + 7, refs)
	-- The hull meets both glass shells (trimmed just inside them); the floor runs onto both dome floors.
	local linkLength = (linkTo - linkFrom).Magnitude
	Geo.walkTube(gh2, linkFrom, linkTo, {
		-- Dome A: 2 studs inside its glass, so the hood runs under the doorway's top panels with no
		-- sliver beside the upper slats (checked by rays from above). Dome B is lower (RY 12): its trim
		-- stays 0.6 inside, else the top slat (axis + apothem, about 11.3 high) misses the trim shell
		-- and stops at the doorway.
		startAt = Geo.domeTrim(a, GREENHOUSE_A_RX - 2, GREENHOUSE_A_RY - 2, true),
		endAt = Geo.domeTrim(b, GREENHOUSE_B_RX - 0.6, GREENHOUSE_B_RY - 0.6, false),
		-- Far enough onto both round dome floors that the plate's corners leave no ground showing
		-- (the hub tube overlaps dome A's floor the same way).
		floorFrom = -1.4,
		floorTo = linkLength + 1.2,
		ribs = { 0.5 },
		ribStyle = { color = ACCENT_SECRET, material = Enum.Material.SmoothPlastic }, -- magenta = greenhouse
		hood = GREENHOUSE_GLASS,
	})

	-- Stage 8: pressurized zones. The tube's zone runs 3 studs into the hub and 2 more into dome A, so
	-- walking through the doorways never reads as outside.
	local tubeDir = flatUnit(tubeTo - tubeFrom, -Vector3.xAxis)
	local zoneFrom = tubeFrom - tubeDir * 3
	local zoneTo = tubeTo + tubeDir * 2
	local zoneMid = Vector3.new((zoneFrom.X + zoneTo.X) / 2, TUBE_AXIS_Y, (zoneFrom.Z + zoneTo.Z) / 2)
	local tubeRadius = TUBE_APOTHEM - 0.1 -- the round inside of the octagon (its corners are hull)
	local tubeZone = shapedZone(
		base,
		"GreenhouseTubeZone",
		CFrame.fromMatrix(zoneMid, Vector3.new(-tubeDir.Z, 0, tubeDir.X), tubeDir),
		Vector3.new(tubeRadius * 2, (zoneTo - zoneFrom).Magnitude, tubeRadius * 2),
		"cylinder"
	)
	-- Stage 10: the link tube's zone runs 4 studs into each dome past the glass line.
	local linkZoneFrom = linkFrom - toB * 4
	local linkZoneTo = linkTo + toB * 4
	local linkZone = shapedZone(
		base,
		"GreenhouseLinkZone",
		CFrame.fromMatrix(
			Vector3.new((linkZoneFrom.X + linkZoneTo.X) / 2, TUBE_AXIS_Y, (linkZoneFrom.Z + linkZoneTo.Z) / 2),
			Vector3.new(-toB.Z, 0, toB.X),
			toB
		),
		Vector3.new(tubeRadius * 2, (linkZoneTo - linkZoneFrom).Magnitude, tubeRadius * 2),
		"cylinder"
	)
	local function domeZone(name: string, centre: Vector3, rx: number, ry: number): Part
		local r = rx - 0.4 -- inner face of the glass
		local h = ry - 0.4
		return shapedZone(base, name, CFrame.new(centre + Vector3.new(0, h / 2, 0)), Vector3.new(r * 2, h, r * 2), "dome")
	end

	return {
		model = gh,
		model2 = gh2,
		strips = refs.strips,
		stripLights = refs.lights,
		plants = refs.plants,
		centre = a + Vector3.new(0, 3, 0),
		foodPrompt = foodPrompt,
		tubeZone = tubeZone,
		linkZone = linkZone,
		linkHatch = linkHatch,
		domeZone = domeZone("GreenhouseZone", a, GREENHOUSE_A_RX, GREENHOUSE_A_RY),
		dome2Zone = domeZone("GreenhouseDome2Zone", b, GREENHOUSE_B_RX, GREENHOUSE_B_RY),
	}
end

------------------------------------------------------------------------------------------------
-- Science rover (drives a loop on the crater rim while Science has power)
------------------------------------------------------------------------------------------------

type RoverRefs = {
	root: Part,
	paintParts: { Part },
	cheeseSpots: { Part },
	centre: Vector3,
	headlights: { Part },
	spot: SpotLight,
	beacon: Part,
	startAngle: number,
}

local ROVER_RIDE_HEIGHT = 1.5 -- body centre above the ground (wheel radius plus half the body)

-- Where the rover is on its loop at `angle`, facing along the loop.
local function roverPose(centre: Vector3, angle: number): CFrame
	local position = centre + Vector3.new(math.sin(angle), 0, math.cos(angle)) * ROVER_LOOP_RADIUS
	local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
	return CFrame.lookAt(position, position + tangent)
end

local function buildRover(base: Instance, rampAngle: number): RoverRefs
	local rover = model(base, "ScienceRover")
	local side = roverSideAngle(rampAngle)
	local centre = CRATER_CENTRE + dirFromAngle(side) * ROVER_RIM_RADIUS + Vector3.new(0, CRATER_RIM_Y + ROVER_RIDE_HEIGHT, 0)
	local startAngle = side -- the point of the loop nearest the crater's outer edge
	local cf = roverPose(centre, startAngle)

	local function style(color: Color3, material: Enum.Material): Style
		return { color = color, material = material, collide = false }
	end
	local root = part(rover, "Body", Vector3.new(3.4, 1, 5.4), cf, style(WHITE_HULL, Enum.Material.SmoothPlastic))
	local attached: { BasePart } = {}
	local function add(p: BasePart)
		table.insert(attached, p)
	end
	local wheelStyle = style(Color3.fromRGB(44, 46, 52), Enum.Material.Rubber)
	for _, wx in { -2.05, 2.05 } do
		for _, wz in { -2, 0, 2 } do
			add(cylinder(rover, "Wheel", 0.6, 1.5, cf * CFrame.new(wx, -0.75, wz), wheelStyle))
		end
		add(part(rover, "Bogie", Vector3.new(0.2, 0.2, 5.2), cf * CFrame.new(wx * 0.85, -0.35, 0), style(DARK_METAL, Enum.Material.Metal)))
	end
	add(part(rover, "SolarDeck", Vector3.new(3.8, 0.15, 4.2), cf * CFrame.new(0, 0.6, 0.5), {
		color = PANEL_CLEAN,
		material = Enum.Material.Glass,
		reflectance = 0.1,
		collide = false,
	}))
	add(part(rover, "Trim", Vector3.new(3.5, 0.3, 0.3), cf * CFrame.new(0, 0.2, -2.75), style(HULL_TRIM, Enum.Material.SmoothPlastic)))
	add(part(rover, "Mast", Vector3.new(0.3, 2.2, 0.3), cf * CFrame.new(0, 1.7, -1.9), style(METAL, Enum.Material.Metal)))
	local cameraHead = part(rover, "CameraHead", Vector3.new(1.3, 0.6, 0.7), cf * CFrame.new(0, 3, -1.9), style(WHITE_HULL, Enum.Material.SmoothPlastic))
	add(cameraHead)
	-- Cheese "holes" for the secret paint job: invisible until someone has found the cheese.
	local cheeseSpots: { Part } = {}
	local spotStyle: Style = { color = CHEESE_SPOT, material = Enum.Material.SmoothPlastic, transparency = 1, collide = false, shadow = false }
	for _, offset in { Vector3.new(-1.72, 0, -1.2), Vector3.new(1.72, 0.1, 0.7), Vector3.new(-1.72, -0.1, 1.5), Vector3.new(1.72, -0.05, -1.6) } do
		local hole = ball(rover, "CheeseSpot", 0.7, (cf * CFrame.new(offset)).Position, spotStyle)
		add(hole)
		table.insert(cheeseSpots, hole)
	end
	local beacon = ball(rover, "Beacon", 0.4, (cf * CFrame.new(0, 3.5, -1.9)).Position, style(LAMP_OFF, Enum.Material.SmoothPlastic))
	add(beacon)
	local headlights: { Part } = {}
	for _, hx in { -1, 1 } do
		local lamp = part(rover, "Headlight", Vector3.new(0.6, 0.35, 0.1), cf * CFrame.new(hx, 0, -2.75), style(LAMP_OFF, Enum.Material.SmoothPlastic))
		add(lamp)
		table.insert(headlights, lamp)
	end
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 18
	spot.Angle = 70
	spot.Brightness = 2
	spot.Color = Color3.fromRGB(255, 240, 215)
	spot.Shadows = false
	spot.Enabled = false
	spot.Parent = root
	weldTo(root, attached)

	return {
		root = root,
		paintParts = { root, cameraHead },
		cheeseSpots = cheeseSpots,
		centre = centre,
		headlights = headlights,
		spot = spot,
		beacon = beacon,
		startAngle = startAngle,
	}
end

------------------------------------------------------------------------------------------------
-- Regolith shelter
------------------------------------------------------------------------------------------------

type ShelterRefs = { model: Model, zone: Part, lamp: Part, lampLight: PointLight }

local function buildShelter(base: Instance): ShelterRefs
	local shelter = model(base, "Shelter")
	local o = SHELTER_CENTRE
	local function v(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	local wall: Style = { color = Color3.fromRGB(128, 124, 116), material = Enum.Material.Concrete }

	-- Room: inner 18 x 10 x 14, walls 2 thick, doorway facing +Z into a tunnel.
	box(shelter, "Floor", v(-11, 0, -9), v(11, 0.4, 9), { color = Color3.fromRGB(110, 108, 104), material = Enum.Material.Concrete })
	box(shelter, "Roof", v(-11, 10, -9), v(11, 12, 9), wall)
	box(shelter, "WallBack", v(-11, 0, -9), v(11, 10, -7), wall)
	box(shelter, "WallWest", v(-11, 0, -7), v(-9, 10, 7), wall)
	box(shelter, "WallEast", v(9, 0, -7), v(11, 10, 7), wall)
	-- The doorway and tunnel are the full room height (10) so the camera does not dip into the roof.
	box(shelter, "WallFrontWest", v(-11, 0, 7), v(-3.5, 10, 9), wall)
	box(shelter, "WallFrontEast", v(3.5, 0, 7), v(11, 10, 9), wall)

	-- Tunnel out through the mound.
	local tunnelEnd = 29
	local tunnelTop = 10
	box(shelter, "TunnelFloor", v(-5.5, 0, 9), v(5.5, 0.4, tunnelEnd), { color = Color3.fromRGB(110, 108, 104), material = Enum.Material.Concrete })
	box(shelter, "TunnelWest", v(-5.5, 0, 9), v(-3.5, tunnelTop, tunnelEnd), wall)
	box(shelter, "TunnelEast", v(3.5, 0, 9), v(5.5, tunnelTop, tunnelEnd), wall)
	box(shelter, "TunnelRoof", v(-5.5, tunnelTop, 9), v(5.5, tunnelTop + 2, tunnelEnd), wall)
	box(shelter, "MouthWest", v(-6.5, 0, tunnelEnd), v(-3.5, tunnelTop + 3, tunnelEnd + 1), wall)
	box(shelter, "MouthEast", v(3.5, 0, tunnelEnd), v(6.5, tunnelTop + 3, tunnelEnd + 1), wall)
	box(shelter, "MouthTop", v(-3.5, tunnelTop, tunnelEnd), v(3.5, tunnelTop + 3, tunnelEnd + 1), wall)
	-- Orange frame: orange always means "shelter" in this base.
	local shelterFrame: Style = { color = ACCENT_WARNING, material = Enum.Material.SmoothPlastic }
	box(shelter, "MouthFrame", v(-4.3, 0.4, tunnelEnd + 1), v(-3.5, tunnelTop + 0.8, tunnelEnd + 1.4), shelterFrame)
	box(shelter, "MouthFrame", v(3.5, 0.4, tunnelEnd + 1), v(4.3, tunnelTop + 0.8, tunnelEnd + 1.4), shelterFrame)
	box(shelter, "MouthFrame", v(-3.5, tunnelTop, tunnelEnd + 1), v(3.5, tunnelTop + 0.8, tunnelEnd + 1.4), shelterFrame)

	-- Storm lamp above the shelter door.
	local lamp = box(shelter, "StormLamp", v(-1.5, tunnelTop + 3, tunnelEnd), v(1.5, tunnelTop + 4, tunnelEnd + 1.2), {
		color = LAMP_OFF,
		material = Enum.Material.SmoothPlastic,
		shadow = false,
	})
	local lampLight = pointLight(lamp, STORM_RED, 30, 3, false)
	lampLight.Enabled = false

	-- Inside: water tanks along the back wall (water and regolith both block particles), benches, light.
	for i = 0, 2 do
		vcylinder(shelter, "WaterTank", 6, 3, v(-6 + i * 6, 3.4, -5), {
			color = Color3.fromRGB(70, 140, 220),
			material = Enum.Material.SmoothPlastic,
		})
	end
	box(shelter, "Bench", v(-8.5, 0.4, -1), v(-6.5, 2, 6), { color = METAL, material = Enum.Material.Metal })
	box(shelter, "Bench", v(6.5, 0.4, -1), v(8.5, 2, 6), { color = METAL, material = Enum.Material.Metal })
	local ceiling = box(shelter, "ShelterLight", v(-4, 9.5, -1), v(4, 10, 1), {
		color = Color3.fromRGB(255, 240, 215),
		material = Enum.Material.Neon,
		shadow = false,
	})
	pointLight(ceiling, Color3.fromRGB(255, 236, 210), 22, 1.2, true)

	-- The big rounded regolith mound (visual only; the room walls and an invisible ring do the colliding).
	local moundRadius = 30
	local moundCentre = v(0, -12, 0)
	ball(shelter, "RegolithMound", moundRadius * 2, moundCentre, {
		color = Color3.fromRGB(124, 121, 114),
		material = Enum.Material.Sand,
		collide = false,
	})
	-- Stage 7 look: regolith bags piled around the foot of the mound and two lumps on top, so it reads
	-- as a pile of Moon dirt (the shelter protects by its mass, not by power).
	local bagRng = Random.new(1972)
	local footR = math.sqrt(moundRadius * moundRadius - 12 * 12) + 0.6
	for k = 1, 17 do -- leave the tunnel side (+Z) open
		local angle = k * math.rad(20)
		local n = dirFromAngle(angle)
		local at = Vector3.new(o.X, 0.7, o.Z) + n * footR
		cylinder(shelter, "RegolithBag", 5.6, 1.6, CFrame.lookAt(at, at + n), {
			color = regolith(bagRng, 112, 6),
			material = Enum.Material.Sand,
			collide = false,
			shadow = false,
		})
	end
	for _, lump in { Vector3.new(-9, 13.5, -6), Vector3.new(8, 14.5, 4) } do
		ball(shelter, "RegolithLump", 11, o + lump, { color = regolith(bagRng, 118, 5), material = Enum.Material.Sand, collide = false })
	end
	local ringR = 26
	local ringCount = 20
	local stepAngle = math.rad(360 / ringCount)
	local ringWidth = 2 * ringR * math.tan(stepAngle / 2) + 0.2
	for k = 1, ringCount - 1 do -- k = 0 points along +Z where the tunnel leaves the mound
		local n = dirFromAngle(k * stepAngle)
		local pos = Vector3.new(o.X, 11, o.Z) + n * ringR
		local blocker = Instance.new("Part")
		blocker.Name = "MoundBlocker"
		blocker.Anchored = true
		blocker.Transparency = 1
		blocker.CastShadow = false
		blocker.CanTouch = false
		blocker.Size = Vector3.new(ringWidth, 22, 2)
		blocker.CFrame = CFrame.lookAt(pos, pos + n)
		blocker.Parent = shelter
		counted()
	end

	local zonePart = zone(base, "ShelterZone", v(-9, 0.4, -7), v(9, 10, 7))
	return { model = shelter, zone = zonePart, lamp = lamp, lampLight = lampLight }
end

------------------------------------------------------------------------------------------------
-- Solar arrays and antenna
------------------------------------------------------------------------------------------------

type ArrayVisual = { panels: { Part }, lines: { Part } }

-- Stage 7 look: the arrays stand in tidy rows on the ridge top. Array i (solar build level i) is one
-- row of ARRAY_SECTIONS panel sections; each section tracks the Sun on its own mast. The middle
-- section carries the cleaning prompt; a dusty array greys every section of its row.
local ARRAY_SECTIONS = 3
local ARRAY_SECTION_SPACING = 15 -- along a row (world X); a panel needs 12 to turn
local ARRAY_ROW_SPACING = 14 -- between rows (world Z)

local function buildArrays(base: Instance, data: any): ({ ArrayRef }, { ArrayVisual }, { ArrayTrack })
	local arraysFolder = folder(base, "SolarArrays")
	local sun = sunDirection()
	local sunH = flatUnit(sun, Vector3.new(0, 0, -1))
	local face = if sun.Y > 0 then sun else sunH
	face = Vector3.new(face.X, math.clamp(face.Y, 0, math.sin(math.rad(30))), face.Z).Unit
	local count: number = data.POWER.ARRAYS
	local centre = Vector3.new(RIDGE_CENTRE.X - 6, RIDGE_TOP_Y, RIDGE_CENTRE.Z)

	local refs: { ArrayRef } = {}
	local visuals: { ArrayVisual } = {}
	local tracks: { ArrayTrack } = {}
	local baseAngle = math.atan2(sunH.X, sunH.Z)
	local lineStyle: Style = { color = Color3.fromRGB(190, 195, 205), material = Enum.Material.Metal, collide = false, shadow = false }
	for i = 1, count do
		local m = model(arraysFolder, "SolarArray" .. i)
		local rowZ = centre.Z + (i - (count + 1) / 2) * ARRAY_ROW_SPACING
		local visual: ArrayVisual = { panels = {}, lines = {} }
		local mainPanel: Part? = nil
		local mainPrompt: ProximityPrompt? = nil
		local firstX, lastX = math.huge, -math.huge
		for s = 1, ARRAY_SECTIONS do
			local footPos = Vector3.new(centre.X + (s - (ARRAY_SECTIONS + 1) / 2) * ARRAY_SECTION_SPACING, centre.Y, rowZ)
			firstX = math.min(firstX, footPos.X)
			lastX = math.max(lastX, footPos.X)
			box(m, "Foot", footPos + Vector3.new(-1.5, 0, -1.5), footPos + Vector3.new(1.5, 0.6, 1.5), {
				color = DARK_METAL,
				material = Enum.Material.Metal,
			})
			local panelCentre = footPos + Vector3.new(0, 6, 0)
			local mast = vcylinder(m, "Mast", 6, 0.7, footPos - sunH * 0.6 + Vector3.new(0, 3, 0), { color = METAL, material = Enum.Material.Metal })
			local panelCf = CFrame.lookAt(panelCentre, panelCentre + face)
			local frame = part(m, "Frame", Vector3.new(12.6, 8.6, 0.3), panelCf * CFrame.new(0, 0, 0.35), { color = METAL, material = Enum.Material.Metal })
			local panel = part(m, "Panel", Vector3.new(12, 8, 0.4), panelCf, {
				color = PANEL_CLEAN,
				material = Enum.Material.Glass,
				reflectance = 0.1,
			})
			local lineH = part(m, "GridLine", Vector3.new(12, 0.15, 0.1), panelCf * CFrame.new(0, 0, -0.22), lineStyle)
			local lineV = part(m, "GridLine", Vector3.new(0.15, 8, 0.1), panelCf * CFrame.new(0, 0, -0.22), lineStyle)
			-- The panel stays the anchored root; mast, frame and grid lines turn with it.
			weldTo(panel, { mast, frame, lineH, lineV })
			table.insert(visual.panels, panel)
			table.insert(visual.lines, lineH)
			table.insert(visual.lines, lineV)
			table.insert(tracks, {
				panel = panel :: BasePart,
				pivot = panelCentre,
				offset = CFrame.new(-panelCentre) * panelCf,
				baseAngle = baseAngle,
				yaw = 0,
			})
			if s == math.ceil(ARRAY_SECTIONS / 2) then
				local attachment = Instance.new("Attachment")
				attachment.Name = "PromptPoint"
				attachment.Position = Vector3.new(0, -3.6, -0.4)
				attachment.Parent = panel
				mainPanel = panel
				mainPrompt = makePrompt(attachment, "prompt.clean", "Clean panel", 1.5)
			end
		end
		-- A cable tray along the row and a power box at its end with a cyan status light.
		box(m, "CableTray", Vector3.new(firstX, centre.Y, rowZ - 0.4), Vector3.new(lastX + 6, centre.Y + 0.35, rowZ + 0.4), {
			color = DARK_METAL,
			material = Enum.Material.Metal,
			shadow = false,
		})
		box(m, "PowerBox", Vector3.new(lastX + 6, centre.Y, rowZ - 1), Vector3.new(lastX + 8, centre.Y + 2.4, rowZ + 1), {
			color = WHITE_HULL,
			material = Enum.Material.SmoothPlastic,
		})
		box(m, "PowerLight", Vector3.new(lastX + 8, centre.Y + 1.6, rowZ - 0.4), Vector3.new(lastX + 8.15, centre.Y + 2.1, rowZ + 0.4), {
			color = ACCENT_SYSTEM,
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
		table.insert(refs, { model = m, panel = mainPanel :: Part, prompt = mainPrompt :: ProximityPrompt })
		table.insert(visuals, visual)
	end
	return refs, visuals, tracks
end

type AntennaRefs = {
	model: Model,
	dishModel: Model,
	dish: Part,
	prompt: ProximityPrompt,
	lights: { Part },
	pointLights: { PointLight },
	hubPosition: Vector3,
	misaligned: CFrame,
	laserBeam: Beam,
}

local function buildAntenna(base: Instance): AntennaRefs
	local antenna = model(base, "Antenna")
	local o = ANTENNA_BASE
	local metal: Style = { color = METAL, material = Enum.Material.Metal }
	for _, sx in { -2.5, 2.5 } do
		for _, sz in { -2.5, 2.5 } do
			box(antenna, "Leg", o + Vector3.new(sx - 0.5, 0, sz - 0.5), o + Vector3.new(sx + 0.5, 30, sz + 0.5), metal)
		end
	end
	for _, y in { 8, 16, 24 } do
		for _, s in { -2.5, 2.5 } do
			box(antenna, "Brace", o + Vector3.new(-2.5, y - 0.25, s - 0.25), o + Vector3.new(2.5, y + 0.25, s + 0.25), metal)
			box(antenna, "Brace", o + Vector3.new(s - 0.25, y - 0.25, -2.5), o + Vector3.new(s + 0.25, y + 0.25, 2.5), metal)
		end
	end
	box(antenna, "Platform", o + Vector3.new(-3.5, 30, -3.5), o + Vector3.new(3.5, 30.6, 3.5), { color = DARK_METAL, material = Enum.Material.DiamondPlate })
	vcylinder(antenna, "DishMount", 6.6, 1, o + Vector3.new(0, 33.9, 0), metal)

	local hubPosition = o + Vector3.new(0, 37.5, 0)
	local earth = WorldSky.getEarthPosition() or defaultEarthPosition()
	local towardEarth = flatUnit(earth - hubPosition, Vector3.new(1, 0, 0))
	local earthAngle = math.atan2(towardEarth.X, towardEarth.Z)
	local wrongDir = dirFromAngle(earthAngle + math.rad(140)) * math.cos(math.rad(25)) + Vector3.new(0, math.sin(math.rad(25)), 0)
	local misaligned = CFrame.lookAt(hubPosition, hubPosition + wrongDir)

	local dishModel = model(antenna, "Dish")
	local axis = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis along the dish's look direction
	local white: Style = { color = Color3.fromRGB(238, 240, 244), material = Enum.Material.SmoothPlastic, collide = false }
	local dark: Style = { color = DARK_METAL, material = Enum.Material.Metal, collide = false }
	cylinder(dishModel, "DishBack", 1.6, 5, misaligned * CFrame.new(0, 0, 0.9) * axis, dark)
	local dish = cylinder(dishModel, "DishReflector", 0.8, 13, misaligned * axis, white)
	cylinder(dishModel, "DishInner", 0.2, 10, misaligned * CFrame.new(0, 0, -0.45) * axis, {
		color = Color3.fromRGB(205, 208, 214),
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	cylinder(dishModel, "FeedStrut", 5, 0.35, misaligned * CFrame.new(0, 0, -2.9) * axis, dark)
	ball(dishModel, "Feed", 1.2, (misaligned * CFrame.new(0, 0, -5.6)).Position, dark)
	-- Level 2: a bigger dish behind the first one (a wider dish catches a weaker signal).
	upgrade(cylinder(dishModel, "DishBig", 0.5, 17.5, misaligned * CFrame.new(0, 0, 0.6) * axis, white), 2)
	upgrade(cylinder(dishModel, "DishBigBack", 1.2, 7.5, misaligned * CFrame.new(0, 0, 1.7) * axis, dark), 2)
	dishModel.WorldPivot = misaligned
	-- The dish has its own animation (setAntennaLinked); the rise-in animation moves it as one piece.
	for _, item in dishModel:GetDescendants() do
		if item:IsA("BasePart") then
			item:SetAttribute(NO_RISE_ATTRIBUTE, true)
		end
	end

	-- Level 3: a laser link terminal on the platform that always points at the Earth. Real laser links
	-- use invisible infrared light; the game draws the beam so players can see the link.
	local laserPos = o + Vector3.new(-2.4, 32.9, -2.4)
	local laserLook = CFrame.lookAt(laserPos, earth)
	upgrade(box(antenna, "LaserBase", o + Vector3.new(-3.1, 30.6, -3.1), o + Vector3.new(-1.7, 31.4, -1.7), dark), 3)
	upgrade(box(antenna, "LaserGimbal", o + Vector3.new(-2.6, 31.4, -2.6), o + Vector3.new(-2.2, 32.6, -2.2), metal), 3)
	upgrade(cylinder(antenna, "LaserHead", 1.6, 1, laserLook * axis, {
		color = WHITE_HULL,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	}), 3)
	local lens = cylinder(antenna, "LaserLens", 0.15, 0.8, laserLook * CFrame.new(0, 0, -0.85) * axis, {
		color = ACCENT_SYSTEM,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	local beamStart = Instance.new("Attachment")
	beamStart.Name = "LaserStart"
	beamStart.Parent = lens
	upgrade(lens, 3)
	local beamTarget = part(antenna, "LaserTarget", Vector3.one, laserLook * CFrame.new(0, 0, -400), {
		color = ACCENT_SYSTEM,
		transparency = 1,
		collide = false,
		shadow = false,
	})
	local beamEnd = Instance.new("Attachment")
	beamEnd.Name = "LaserEnd"
	beamEnd.Parent = beamTarget
	local laserBeam = Instance.new("Beam")
	laserBeam.Name = "LaserBeam"
	laserBeam.Attachment0 = beamStart
	laserBeam.Attachment1 = beamEnd
	laserBeam.Color = ColorSequence.new(ACCENT_SYSTEM)
	laserBeam.LightEmission = 1
	laserBeam.LightInfluence = 0
	laserBeam.Width0 = 0.25
	laserBeam.Width1 = 0.25
	laserBeam.FaceCamera = true
	laserBeam.Segments = 1
	laserBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	laserBeam.Enabled = false
	laserBeam.Parent = beamTarget

	local towerLight = ball(antenna, "LinkLight", 1.4, o + Vector3.new(3, 31.4, 3), {
		color = LINK_RED,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local towerPoint = pointLight(towerLight, LINK_RED, 16, 2, false)

	local control = box(antenna, "ControlBox", o + Vector3.new(6, 0, -1.5), o + Vector3.new(9, 4, 1.5), {
		color = DARK_METAL,
		material = Enum.Material.Metal,
	})
	local controlLight = box(antenna, "ControlLight", o + Vector3.new(7, 4, -0.5), o + Vector3.new(8, 4.8, 0.5), {
		color = LINK_RED,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local controlPoint = pointLight(controlLight, LINK_RED, 8, 1, false)
	local prompt = makePrompt(control, "prompt.antenna", "Aim antenna", 1.5)

	return {
		model = antenna,
		dishModel = dishModel,
		dish = dish,
		prompt = prompt,
		lights = { towerLight, controlLight },
		pointLights = { towerPoint, controlPoint },
		hubPosition = hubPosition,
		misaligned = misaligned,
		laserBeam = laserBeam,
	}
end

------------------------------------------------------------------------------------------------
-- Public build
------------------------------------------------------------------------------------------------

function WorldBuilder.build(data: any): World
	resetPartCounter()
	WorldSky.resetEclipseListeners()
	local old = Workspace:FindFirstChild("Base")
	if old then
		old:Destroy()
	end
	local base = Instance.new("Folder")
	base.Name = "Base"
	base.Parent = Workspace

	buildState.risingParts = {}
	extraKeepouts = {}
	local hidden = Six.hiddenStore()

	local rng = Random.new(42)
	local ground = buildGround(base, rng)
	local habitat = buildHabitat(base)
	local shelter = buildShelter(base)
	local _, iceNodes, rampAngle, cheeseSpot = buildCrater(base, rng)
	buildRidge(base, rng)
	local arrays, arrayVisuals, arrayTracks = buildArrays(base, data)
	local antenna = buildAntenna(base)
	local lander = Geo.buildLander(base)

	-- Stage 6 layout first, so random boulders keep clear of the belt, the robot's route and the pads.
	-- Stage 11 tycoon: the silo, water plant and air maker stand between the hub and the crater
	-- (Six.worksLayout), so the whole line, drills to habitat, can be seen.
	local drillAngle = Six.chooseDrillAngle(rampAngle)
	-- Stage 11 world: more ways out of the ice crater, and walls at the map edge.
	S11World.craterExits(base, rampAngle, drillAngle)
	S11World.mapEdge(base)
	local works = Six.worksLayout(drillAngle)
	local conveyorFoot = works.beltStart
	local cargoPoints = works.route
	local pads = Six.padSpots(drillAngle)
	Six.keepoutsAlong({ works.beltStart, works.beltEnd }, 5, 12, extraKeepouts)
	Six.keepoutsAlong(cargoPoints, 6, 12, extraKeepouts)
	for _, spot in { works.silo, works.plant, works.air } do
		table.insert(extraKeepouts, { x = spot.X, z = spot.Z, r = 9 })
	end
	-- Stage 7: the lander, the greenhouse domes and every world site keep their surroundings clear.
	for _, keep in {
		{ at = S7.LANDER_CENTRE, r = 45 },
		{ at = S7.GREENHOUSE_A, r = GREENHOUSE_A_RX + 8 },
		{ at = S7.GREENHOUSE_B, r = GREENHOUSE_B_RX + 8 },
		{ at = S7.LAB_CENTRE, r = 32 },
		{ at = S7.GARAGE_CENTRE, r = 42 },
		{ at = S7.LANDING_PAD_CENTRE, r = 46 },
	} do
		table.insert(extraKeepouts, { x = keep.at.X, z = keep.at.Z, r = keep.r })
	end
	for _, spot in S7.SITE_SPOTS do
		table.insert(extraKeepouts, { x = spot.X, z = spot.Z, r = 50 })
	end

	-- Stage 7: the world sites (lab, garage, landing pad, ship, exploration sites, meteorite craters)
	-- live in WorldSites.luau. A missing or broken module never stops the world: those builds are
	-- left out and a simple crater stands in for the meteorite event.
	local sites: any = nil
	local sitesHelpers = {
		-- WorldSites calls onPart for every part it makes: the shared counter yields now and then.
		onPart = function(_: BasePart)
			counted()
		end,
		addKeepout = function(x: number, z: number, r: number)
			table.insert(extraKeepouts, { x = x, z = z, r = r })
		end,
		isClear = isClear,
		dustPuff = function(position: Vector3)
			Six.dustPuff(base, position)
		end,
		theme = Theme,
		icons = Icons,
	}
	local sitesModule = script.Parent:FindFirstChild("WorldSites")
	if sitesModule and sitesModule:IsA("ModuleScript") then
		local okRequire, loaded = pcall(function()
			return (require :: any)(sitesModule)
		end)
		if okRequire and type(loaded) == "table" and type(loaded.build) == "function" then
			local okBuild, result = pcall(loaded.build, base, sitesHelpers)
			if okBuild and type(result) == "table" then
				sites = result
			else
				warn(`[SpaceBaseOdyssey] WorldSites.build failed: {result}`)
			end
		else
			warn(`[SpaceBaseOdyssey] WorldSites could not load: {loaded}`)
		end
	else
		warn("[SpaceBaseOdyssey] WorldSites module missing: no lab, garage, landing pad or ship")
	end
	if sites and type(sites.keepouts) == "table" then
		for _, keep in sites.keepouts do
			if type(keep) == "table" and type(keep.x) == "number" and type(keep.z) == "number" and type(keep.r) == "number" then
				table.insert(extraKeepouts, { x = keep.x, z = keep.z, r = keep.r })
			end
		end
	end
	local siteBuilds: { [string]: { model: Instance, padPosition: Vector3? } } = {}
	if sites and type(sites.builds) == "table" then
		for _, id in { "lab", "garage", "landing_pad", "ship" } do
			local entry = sites.builds[id]
			if type(entry) == "table" and typeof(entry.model) == "Instance" then
				local padPosition = if typeof(entry.padPosition) == "Vector3" then entry.padPosition else nil
				siteBuilds[id] = { model = entry.model, padPosition = padPosition }
				if padPosition then
					pads[id] = padPosition
				end
			end
		end
	end
	for id in pads do
		if (id == "lab" or id == "garage" or id == "landing_pad" or id == "ship") and siteBuilds[id] == nil then
			pads[id] = nil -- no structure, no pad
		end
	end
	for _, spot in pads do
		table.insert(extraKeepouts, { x = spot.X, z = spot.Z, r = 7 })
	end
	-- Rover tracks between the buildings: lander -> hub, hub -> crater, garage, shelter, lander ->
	-- landing pad, hub -> ridge ramp (past the lab).
	local trackPaths: { { Vector3 } } = {
		{ lander.door, Vector3.new(8, 0, -60), HABITAT_CENTRE + Vector3.new(0, 0, -38) },
		{ HABITAT_CENTRE + Vector3.new(0, 0, 38), Vector3.new(8, 0, 60), Vector3.new(8, 0, 108) },
		{ HABITAT_CENTRE + Vector3.new(10, 0, 44), Vector3.new(60, 0, 62), S7.GARAGE_CENTRE + Vector3.new(-26, 0, 0) },
		{ HABITAT_CENTRE + Vector3.new(14, 0, 37), Vector3.new(45, 0, 16), SHELTER_CENTRE + Vector3.new(0, 0, 36) },
		{ lander.door, S7.LANDING_PAD_CENTRE + flatUnit(HABITAT_CENTRE - S7.LANDING_PAD_CENTRE, Vector3.zAxis) * 44 },
		{ HABITAT_CENTRE + Vector3.new(-4, 0, -40), Vector3.new(-30, 0, -60), Vector3.new(-78, 0, -66), Vector3.new(-92, 0, -60) },
	}
	for _, path in trackPaths do
		Six.keepoutsAlong(path, 6, 12, extraKeepouts)
	end

	buildDecor(base, rng)
	local greenhouse = buildGreenhouse(base)
	local rover = buildRover(base, rampAngle)

	-- The tube corridor from the hub to the lab's docking doorway (shown with the lab). Stage 10
	-- (playtest): it is a walk-through tube like the greenhouse one. It leaves the hub's lab doorway
	-- (HUB_DOOR_LAB) and ends at the lab's dock doorway, its floor ramping gently from the hub floor up
	-- to the lab floor. Without a dock from WorldSites it stops LAB_TUBE_INSET from the lab centre.
	local labTube: Model? = nil
	local labTubeZone: Part? = nil
	if siteBuilds.lab then
		local tube = model(base, "LabTube")
		local dockCf = if sites and typeof(sites.labDock) == "CFrame" then sites.labDock :: CFrame else nil
		local interior = sites and sites.labInterior
		local labCentre = if type(interior) == "table" and typeof(interior.centre) == "Vector3" then interior.centre :: Vector3 else S7.LAB_CENTRE
		local labWall = if type(interior) == "table" and type(interior.radius) == "number" then interior.radius :: number else LAB_TUBE_INSET - 0.6
		local hubFloorTop = 0.5
		local labFloorTop = hubFloorTop
		local to: Vector3
		if dockCf then
			labFloorTop = dockCf.Position.Y
			to = Vector3.new(dockCf.Position.X, 0, dockCf.Position.Z)
		else
			local toLab = flatUnit(labCentre - HABITAT_CENTRE, -Vector3.xAxis)
			local labDistance = (Vector3.new(labCentre.X, 0, labCentre.Z) - Vector3.new(HABITAT_CENTRE.X, 0, HABITAT_CENTRE.Z)).Magnitude
			to = HABITAT_CENTRE + toLab * (labDistance - LAB_TUBE_INSET)
		end
		local hubNormal = dirFromAngle(HUB_DOOR_LAB * 2 * math.pi / HUB_SEGMENTS)
		local hubOuter = HUB_APOTHEM + HUB_WALL
		local from = HABITAT_CENTRE + hubNormal * hubOuter
		-- Floor-bottom points: the floor's top is the hub floor at `from` and the lab floor at `to`.
		local a = Vector3.new(from.X, hubFloorTop - 0.5, from.Z)
		local b = Vector3.new(to.X, labFloorTop - 0.5, to.Z)
		local flatDir = flatUnit(b - a, -Vector3.xAxis)
		local run = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		local slope = (b.Y - a.Y) / math.max(run, 1)
		local lengthScale = math.sqrt(1 + slope * slope) -- distance along the tube per stud of run
		-- Where the floor's corners cross the hub's inner wall face, measured along the floor.
		-- (flatDir and hubNormal both point out of the hub, so their dot is the cosine of the slant.)
		local cosHub = math.max(0.2, flatDir:Dot(hubNormal))
		local sinHub = math.sqrt(math.max(0, 1 - cosHub * cosHub))
		local labApothem = 5
		local floorWidth = 6.6
		local floorFrom = -(HUB_WALL / cosHub + (floorWidth / 2) * sinHub / cosHub + 0.6) * lengthScale
		local floorTo = (run + 0.8) * lengthScale -- onto the lab floor, past the doorway
		Geo.walkTube(tube, a, b, {
			apothem = labApothem,
			axisHeight = 4.6,
			floorWidth = floorWidth,
			glass = GLASS,
			startAt = Geo.planeTrim(from, hubNormal),
			endAt = Geo.domeTrim(labCentre, labWall + 0.4, math.huge, false),
			floorFrom = floorFrom,
			floorTo = floorTo,
			ribs = { 0.25, 0.5, 0.75, 0.97 },
		})
		labTube = tube
		-- Stage 8: its pressurized zone, the round inside of the corridor (a little into both modules).
		-- Stage 10: it starts well inside the hub (the tube meets the hub wall at a slant).
		local axisFrom = a + Vector3.new(0, 4.6, 0)
		local axisTo = b + Vector3.new(0, 4.6, 0)
		local axis = (axisTo - axisFrom).Unit
		local across = axis:Cross(Vector3.yAxis)
		across = if across.Magnitude > 1e-3 then across.Unit else Vector3.xAxis
		local zoneFrom = axisFrom - axis * 6
		local zoneTo = axisTo + axis * 3
		local zoneDiameter = (labApothem - 0.1) * 2
		labTubeZone = shapedZone(
			base,
			"LabTubeZone",
			CFrame.fromMatrix((zoneFrom + zoneTo) / 2, across, axis),
			Vector3.new(zoneDiameter, (zoneTo - zoneFrom).Magnitude, zoneDiameter),
			"cylinder"
		)
	end

	-- Rover tracks between the buildings (laid out above, so boulders keep off them).
	Geo.buildTracks(base, trackPaths, { [1] = true, [5] = true })

	-- Stage 6: automatic ice drills on the crater floor, the conveyor, the silo and the cargo robot.
	local outward = dirFromAngle(drillAngle)
	local across = Vector3.new(-outward.Z, 0, outward.X)
	local drillsFolder = folder(base, "IceDrills")
	local drills: { DrillRefs } = {}
	for i = 1, 3 do
		local beltEnd = Six.craterPoint(drillAngle, HOPPER_RADIUS - 2, CRATER_RIM_Y + 0.6) + across * ((i - 2) * 0.9)
		table.insert(drills, Six.buildDrill(drillsFolder, i, drillAngle + (i - 2) * DRILL_SPREAD, beltEnd))
	end
	-- Stage 11 tycoon: the silo first (the belt's lift reaches its top), the water plant, the air maker
	-- and the hub's supply port, and the line folder the clients animate from.
	local silo = Six.buildSilo(base, works)
	local conveyor = Six.buildConveyor(base, drillAngle, works, silo.top)
	local cargo = Six.buildCargoBot(base, Six.polyline(cargoPoints))
	local line = {
		plant = Six.buildWaterPlant(base, works),
		air = Six.buildAirMaker(base, works),
		port = Six.buildSupplyPort(base, works),
		folder = folder(base, "ProductionLine"),
		times = {
			drive = math.max(1, cargo.route.total / CARGO_SPEED),
			load = LINE.LOAD_SECONDS,
			drop = LINE.DROP_SECONDS,
		},
	}
	do
		local f = line.folder
		f:SetAttribute("BeltCount", #conveyor.cubeLine)
		for i, point in conveyor.cubeLine do
			f:SetAttribute("Belt" .. i, point)
		end
		for i, drill in drills do
			f:SetAttribute("Lift" .. i .. "A", drill.liftA)
			f:SetAttribute("Lift" .. i .. "B", drill.liftB)
		end
		f:SetAttribute("RouteCount", #cargo.route.points)
		for i, point in cargo.route.points do
			f:SetAttribute("Route" .. i, point)
		end
		f:SetAttribute("SBO_DriveSeconds", line.times.drive)
		f:SetAttribute("SBO_LoadSeconds", line.times.load)
		f:SetAttribute("SBO_DropSeconds", line.times.drop)
		f:SetAttribute("SiloCentre", silo.centre)
		f:SetAttribute("SiloBottomY", silo.bottomY)
		f:SetAttribute("SiloHeight", silo.height)
		f:SetAttribute("SBO_CargoPhase", "off")
	end

	-- Secrets come last and use their own random streams, so the rest of the base keeps its layout.
	local secretSpots: { [string]: CFrame } = {
		mars_potato = Secret.buildCrawlSpace(base, ground),
		mini_earth = Secret.buildLookoutRock(base),
		laika = Secret.buildLavaTube(base),
		cheese = cheeseSpot,
	}
	local observatory = Secret.buildObservatory(base)
	local teamFlag = Secret.buildTeamFlag(base)
	local collectiblesFolder = folder(base, "Collectibles")
	local collectibleItems: { CollectibleItem } = {}
	local collectibleRefs: { CollectibleRef } = {}
	for i, id in COLLECTIBLE_IDS do
		local item = Secret.buildCollectible(collectiblesFolder, id, secretSpots[id], i * 1.7)
		table.insert(collectibleItems, item)
		table.insert(collectibleRefs, item.ref)
	end

	-- Keep the habitat interior readable: many overlapping long-range lights burned it to white.
	local habitatFolder = base:FindFirstChild("Habitat")
	if habitatFolder then
		for _, item in habitatFolder:GetDescendants() do
			if item:IsA("PointLight") then
				item.Range = math.min(item.Range, 16)
				item.Brightness = math.min(item.Brightness, 0.9)
			elseif item:IsA("SurfaceLight") then
				item.Brightness = 0.5
				item.Range = 14
			elseif item:IsA("SpotLight") then
				item.Brightness = math.min(item.Brightness, 1.2)
			end
		end
	end

	-- Guidance markers for the client (C.A.R.L.'s beam, task arrows, tips).
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	local markerPositions: { [string]: Vector3 } = {
		ShelterDoor = SHELTER_CENTRE + Vector3.new(0, 3, 33), -- tunnel mouth is at +30
		HabitatDoor = HABITAT_CENTRE + Vector3.new(0, 3, HUB_APOTHEM + HUB_WALL + 3),
		Antenna = ANTENNA_BASE + Vector3.new(0, 1, 0),
		IceSite = CRATER_CENTRE + Vector3.new(0, CRATER_FLOOR_Y + 1, 0),
		Processor = habitat.processorInlet.Position + Vector3.new(0, 0, 1.5),
		Console = habitat.console.Position + Vector3.new(0, 0, 3),
		MissionConsole = habitat.missionConsole.Position + Vector3.new(-3, 0, 0),
		Leak = habitat.leakPart.Position + Vector3.new(2, 0, 0),
		Greenhouse = greenhouse.centre,
		Arrays = Vector3.new(RIDGE_CENTRE.X, RIDGE_TOP_Y + 1, RIDGE_CENTRE.Z),
		Silo = silo.marker, -- Stage 11: the silo's side toward the hub (the claim prompt)
		LanderDoor = lander.door + Vector3.new(0, 3, 0),
		CrateDepot = lander.cratePosition + Vector3.new(0, 2, 0),
	}
	for _, name in MARKER_NAMES do
		markerPart(markers, name, markerPositions[name])
	end
	markers.Parent = base

	-- Live state behind the setters.
	local shiftEnabled = false
	local dusty: { boolean } = table.create(#arrays, false)
	local leakActive = false
	local antennaLinked = false
	local antennaLevel = 0 -- Stage 6 build level (3 = laser link terminal)
	local dishToken = 0
	local stormToken = 0

	-- The laser beam shows only on a level 3 antenna while the link to Earth is up.
	local function refreshLaser()
		antenna.laserBeam.Enabled = antennaLinked and antennaLevel >= 3
	end

	-- Where the dish points right now: at the Earth when linked, else knocked off.
	local function dishTarget(): CFrame
		return if antennaLinked
			then CFrame.lookAt(antenna.hubPosition, WorldSky.getEarthPosition() or defaultEarthPosition())
			else antenna.misaligned
	end

	local function refreshPrompts()
		for i, ref in arrays do
			ref.prompt.Enabled = shiftEnabled and dusty[i] == true
		end
		for _, node in iceNodes do
			node.prompt.Enabled = shiftEnabled
		end
		habitat.processorPrompt.Enabled = shiftEnabled
		habitat.leakPrompt.Enabled = shiftEnabled and leakActive
		habitat.consolePrompt.Enabled = shiftEnabled
		antenna.prompt.Enabled = shiftEnabled and not antennaLinked
	end

	local function setArrayDusty(index: number, isDusty: boolean)
		local visual = arrayVisuals[index]
		if not visual then
			return
		end
		dusty[index] = isDusty
		for _, panel in visual.panels do
			if isDusty then
				panel.Color = PANEL_DUSTY
				panel.Material = Enum.Material.Sand
				panel.Reflectance = 0
			else
				panel.Color = PANEL_CLEAN
				panel.Material = Enum.Material.Glass
				panel.Reflectance = 0.1
			end
		end
		for _, line in visual.lines do
			line.Transparency = if isDusty then 1 else 0
		end
		refreshPrompts()
	end

	local function setLeakActive(active: boolean)
		leakActive = active
		for _, emitter in habitat.leakEmitters do
			emitter.Enabled = active
		end
		habitat.leakLight.Enabled = active
		habitat.leakPart.Color = if active then PALETTE.red else METAL
		refreshPrompts()
	end

	local function setAntennaLinked(linked: boolean)
		antennaLinked = linked
		local colour = if linked then LINK_GREEN else LINK_RED
		for _, light in antenna.lights do
			light.Color = colour
		end
		for _, light in antenna.pointLights do
			light.Color = colour
		end
		refreshPrompts()
		refreshLaser()

		local target = dishTarget()
		dishToken += 1
		local token = dishToken
		local start = antenna.dishModel:GetPivot()
		local duration = 1.5
		local elapsed = 0
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function(dt: number)
			if token ~= dishToken or antenna.dishModel.Parent == nil then
				if connection then
					connection:Disconnect()
				end
				return
			end
			elapsed += dt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			antenna.dishModel:PivotTo(start:Lerp(target, eased))
			if alpha >= 1 and connection then
				connection:Disconnect()
			end
		end)
	end

	local function setStormVisuals(stage: StormStage)
		stormToken += 1
		local token = stormToken
		local tint = stormTint()
		if stage == "none" then
			tint.Enabled = false
			shelter.lamp.Color = LAMP_OFF
			shelter.lamp.Material = Enum.Material.SmoothPlastic
			shelter.lamp.Transparency = 0
			shelter.lampLight.Enabled = false
			return
		end
		local colour = if stage == "storm" then STORM_RED else STORM_AMBER
		tint.Enabled = true
		if stage == "storm" then
			tint.TintColor = Color3.fromRGB(255, 185, 170)
			tint.Contrast = 0.08
			tint.Saturation = -0.1
		else
			tint.TintColor = Color3.fromRGB(255, 228, 195)
			tint.Contrast = 0.03
			tint.Saturation = -0.05
		end
		shelter.lamp.Color = colour
		shelter.lamp.Material = Enum.Material.Neon
		shelter.lampLight.Color = colour
		shelter.lampLight.Enabled = true
		local period = if stage == "storm" then 0.35 else 0.6
		task.spawn(function()
			local bright = true
			while token == stormToken and shelter.lamp.Parent ~= nil do
				shelter.lampLight.Brightness = if bright then 4 else 1
				shelter.lamp.Transparency = if bright then 0 else 0.5
				bright = not bright
				task.wait(period)
			end
		end)
	end

	local function setShiftPromptsEnabled(enabled: boolean)
		shiftEnabled = enabled
		refreshPrompts()
	end

	-- Today's power plan, shown on the base. Each system gets a step: 0 (off), 1 or 2.
	local maxCells: number = math.max(1, (data.POWER and data.POWER.MAX_CELLS_PER_SYSTEM) or 2)
	local growStrips = table.clone(greenhouse.strips)
	table.insert(growStrips, habitat.rackLight)
	local growLights = table.clone(greenhouse.stripLights)
	table.insert(growLights, habitat.rackPointLight)
	local plants = table.clone(greenhouse.plants)
	for _, plant in habitat.rackPlants do
		table.insert(plants, plant)
	end
	local life = habitat.lifeSupport
	local lifeStep = 0
	local scienceStep = 0

	local function stepOf(allocation: any, key: string): number
		local value = if type(allocation) == "table" then allocation[key] else nil
		if type(value) ~= "number" or value ~= value or value <= 0 then
			return 0
		end
		return math.clamp(math.ceil(value / maxCells * 2), 1, 2)
	end

	local function setSystemVisuals(allocation: SystemAllocation)
		local grow = stepOf(allocation, "Greenhouse")
		lifeStep = stepOf(allocation, "LifeSupport")
		scienceStep = stepOf(allocation, "Science")

		-- Greenhouse: grow lights at 0, 1 or 2 steps; plants look tired without light.
		for _, strip in growStrips do
			strip.Material = if grow > 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			strip.Color = if grow >= 2 then GROW_PINK elseif grow == 1 then GROW_DIM else LAMP_OFF
		end
		for _, light in growLights do
			light.Enabled = grow > 0
			light.Brightness = GROW_BRIGHTNESS[grow + 1]
			light.Range = GROW_RANGE[grow + 1]
		end
		for _, plant in plants do
			plant.Color = if grow > 0 then PLANT_GREEN else PLANT_GREY
		end

		-- Life support: the processor glows and the air maker's light turns red without power.
		life.window.Material = if lifeStep > 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		life.window.Color = if lifeStep >= 2 then AIR_WINDOW_HIGH elseif lifeStep == 1 then AIR_WINDOW_ON else AIR_WINDOW_OFF
		life.windowLight.Enabled = lifeStep > 0
		life.windowLight.Brightness = lifeStep
		local statusColour = if lifeStep > 0 then AIR_OK else STORM_RED
		life.status.Color = statusColour
		life.status.Transparency = 0
		life.statusLight.Color = statusColour
		life.statusLight.Brightness = 1.5

		-- Science: the rover drives with its lights on, or parks dark.
		local driving = scienceStep > 0
		for _, lamp in rover.headlights do
			lamp.Material = if driving then Enum.Material.Neon else Enum.Material.SmoothPlastic
			lamp.Color = if driving then Color3.fromRGB(255, 240, 215) else LAMP_OFF
		end
		rover.spot.Enabled = driving
		rover.beacon.Material = if driving then Enum.Material.Neon else Enum.Material.SmoothPlastic
		rover.beacon.Color = if driving then HULL_TRIM else LAMP_OFF
	end

	-- Shared rewards in the world (the server decides who owns them; see ProgressService).
	local function setRoverPaint(paint: RoverPaint)
		local cheese = paint == "cheese"
		for _, p in rover.paintParts do
			p.Color = if cheese then CHEESE_PAINT else WHITE_HULL
		end
		for _, hole in rover.cheeseSpots do
			hole.Transparency = if cheese then 0 else 1
		end
	end

	-- The flag stands on the hub's dome, so it only shows while the habitat is built (Stage 7).
	local teamFlagWanted = false
	local habitatStanding = false
	local function refreshTeamFlag()
		teamFlag.Parent = if teamFlagWanted and habitatStanding then base else nil
	end
	local function setTeamFlag(visible: boolean)
		teamFlagWanted = visible == true
		refreshTeamFlag()
	end

	-- Water tank level: the water column grows or shrinks, and the gauge turns orange, then red.
	local tank = habitat.waterTank
	local waterFraction = -1
	local function setWaterLevel(fraction: number)
		if type(fraction) ~= "number" or fraction ~= fraction then
			return
		end
		local f = math.clamp(fraction, 0, 1)
		if math.abs(f - waterFraction) < 1e-3 then
			return
		end
		waterFraction = f
		local height = math.max(0.05, tank.height * f)
		local centre = Vector3.new(tank.centre.X, tank.bottomY + height / 2, tank.centre.Z)
		TweenService:Create(tank.fill, WATER_TWEEN, {
			Size = Vector3.new(height, tank.diameter, tank.diameter),
			CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = if f <= 0 then 1 else 0.15,
		}):Play()
		tank.light.Enabled = f > 0
		tank.light.Brightness = 0.3 + 0.6 * f
		tank.gauge.Color = if f >= 0.5 then ACCENT_OK elseif f >= 0.2 then ACCENT_WARNING else PALETTE.red
	end
	local startWater = 1
	local waterData = if type(data) == "table" then data.WATER else nil
	if type(waterData) == "table" and type(waterData.START) == "number" and type(waterData.MAX) == "number" and waterData.MAX > 0 then
		startWater = waterData.START / waterData.MAX
	end
	setWaterLevel(startWater)

	local function onEclipse(callback: (active: boolean) -> ())
		if type(callback) == "function" then
			WorldSky.addEclipseListener(callback)
		end
	end

	local function isEclipse(): boolean
		return WorldSky.isEclipseActive()
	end

	-- Stage 6: build levels. Every structure was built above; each build id lists the models it shows
	-- from which level, and its blueprint copies. setBuildLevel(id, 0) is applied to all of them below,
	-- so the base starts with only the lander, the blueprints and their pads (Stage 7: the habitat is a
	-- build too).
	type BuildUnit = { level: number, instance: Instance, home: Instance, hologram: Instance, shown: boolean, dust: Vector3? }
	type UpgradeEntry = { part: BasePart, level: number, alpha: number }
	type UpgradeLight = { light: Light, level: number }
	type BuildEntry = {
		units: { BuildUnit },
		upgrades: { UpgradeEntry },
		lights: { UpgradeLight },
		level: number,
		maxLevel: number,
		pad: BasePart?,
		onLevel: ((level: number) -> ())?,
		onRiseStep: ((offset: number) -> ())?,
		onRiseDone: (() -> ())?,
	}
	type UnitSpec = { level: number, instance: Instance, dust: Vector3? }

	local blueprints = folder(base, "Blueprints")
	local constructionFolder = folder(base, "Construction")
	local entries: { [string]: BuildEntry } = {}
	local buildData = if type(data) == "table" and type(data.BASE) == "table" then data.BASE.BUILDS else nil
	local function maxLevelOf(id: string, fallback: number): number
		if type(buildData) == "table" then
			for _, def in buildData do
				if type(def) == "table" and def.id == id and type(def.maxLevel) == "number" then
					return def.maxLevel
				end
			end
		end
		return fallback
	end

	-- SBO_MinLevel convention (WorldSites, and any model): a part, or every part in a model or folder,
	-- with the attribute SBO_MinLevel = n (n >= 2) only shows from build level n on, like upgrade().
	local function applyMinLevel(root: Instance)
		local function tag(item: Instance, level: number)
			if item:IsA("BasePart") and item:GetAttribute(UPGRADE_ATTRIBUTE) == nil then
				upgrade(item, level)
			end
		end
		local all = root:GetDescendants()
		table.insert(all, root)
		for _, item in all do
			local level = item:GetAttribute(MIN_LEVEL_ATTRIBUTE)
			if type(level) == "number" and level >= 2 then
				tag(item, math.floor(level))
				for _, inner in item:GetDescendants() do
					tag(inner, math.floor(level))
				end
			end
		end
	end

	local function register(id: string, fallbackMax: number, specs: { UnitSpec }): BuildEntry
		local entry: BuildEntry = {
			units = {},
			upgrades = {},
			lights = {},
			level = 1, -- as built: every unit standing, upgrade parts hidden
			maxLevel = maxLevelOf(id, fallbackMax),
		}
		for _, spec in specs do
			if spec.instance.Parent == nil then
				spec.instance.Parent = base
			end
			applyMinLevel(spec.instance)
			local home = spec.instance.Parent :: Instance
			table.insert(entry.units, {
				level = spec.level,
				instance = spec.instance,
				home = home,
				hologram = Six.makeHologram(spec.instance, hidden),
				shown = true,
				dust = spec.dust,
			})
			for _, item in spec.instance:GetDescendants() do
				local upgradeLevel = item:GetAttribute(UPGRADE_ATTRIBUTE)
				if item:IsA("BasePart") and type(upgradeLevel) == "number" then
					local alpha = item:GetAttribute(ALPHA_ATTRIBUTE)
					table.insert(entry.upgrades, { part = item, level = upgradeLevel, alpha = if type(alpha) == "number" then alpha else 0 })
					for _, light in item:GetDescendants() do
						if light:IsA("Light") then
							table.insert(entry.lights, { light = light, level = upgradeLevel })
						end
					end
				end
			end
		end
		entries[id] = entry
		return entry
	end

	local habitatEntry = register("habitat", 1, { { level = 1, instance = habitat.model, dust = HABITAT_CENTRE } })
	local solarSpecs: { UnitSpec } = {}
	for i, ref in arrays do
		table.insert(solarSpecs, { level = i, instance = ref.model })
	end
	register("solar", #arrays, solarSpecs)
	local greenhouseEntry = register("greenhouse", 2, {
		{ level = 1, instance = greenhouse.model, dust = S7.GREENHOUSE_A },
		{ level = 2, instance = greenhouse.model2, dust = S7.GREENHOUSE_B },
	})
	local antennaEntry = register("antenna", 3, { { level = 1, instance = antenna.model, dust = ANTENNA_BASE } })
	local shelterEntry = register("shelter", 1, { { level = 1, instance = shelter.model, dust = SHELTER_CENTRE + Vector3.new(0, 0, 31) } })
	local function drillFloor(i: number): Vector3
		return Six.craterPoint(drillAngle + (i - 2) * DRILL_SPREAD, DRILL_FLOOR_RADIUS, CRATER_FLOOR_Y)
	end
	register("drill_1", 3, {
		{ level = 1, instance = drills[1].model, dust = drillFloor(1) },
		{ level = 1, instance = conveyor.model, dust = conveyorFoot },
		{ level = 1, instance = silo.model, dust = works.silo },
		{ level = 1, instance = line.plant.model, dust = works.plant }, -- Stage 11: the water plant
	})
	register("drill_2", 3, { { level = 1, instance = drills[2].model, dust = drillFloor(2) } })
	register("drill_3", 3, { { level = 1, instance = drills[3].model, dust = drillFloor(3) } })
	register("cargo_bot", 1, {
		{ level = 1, instance = cargo.model },
		{ level = 1, instance = line.air.model, dust = works.air }, -- Stage 11: the air maker ...
		{ level = 1, instance = line.port.model }, -- ... and the hub's supply port
	})

	-- Stage 7: the world sites' structures (each model fully built by WorldSites).
	local fallbackMax: { [string]: number } = { lab = 1, garage = 2, landing_pad = 1, ship = 1 }
	local labEntry: BuildEntry? = nil
	for _, id in { "lab", "garage", "landing_pad", "ship" } do
		local site = siteBuilds[id]
		if site then
			local specs: { UnitSpec } = { { level = 1, instance = site.model } }
			if id == "lab" and labTube then
				table.insert(specs, { level = 1, instance = labTube })
			end
			local ok, result = pcall(register, id, fallbackMax[id], specs)
			if ok then
				if id == "lab" then
					labEntry = result
				end
			else
				warn(`[SpaceBaseOdyssey] could not register the {id} build: {result}`)
			end
		end
	end
	local labPrompt: ProximityPrompt? = nil
	if sites and typeof(sites.labPrompt) == "Instance" and sites.labPrompt:IsA("ProximityPrompt") then
		labPrompt = sites.labPrompt
	end
	-- Stage 10: the hub's lab doorway stays closed by its glass hatch until the lab and its tube stand.
	local labHatch = habitat.labHatch
	local labHatchAlpha = labHatch.Transparency
	local function setLabHatch(open: boolean)
		labHatch.Transparency = if open then 1 else labHatchAlpha
		labHatch.CanCollide = not open
		labHatch.CanQuery = not open
	end
	if labEntry then
		labEntry.onLevel = function(level: number)
			if labPrompt then
				labPrompt.Enabled = level >= 1
			end
			setLabHatch(level >= 1 and labTube ~= nil)
		end
	elseif labPrompt then
		labPrompt.Enabled = false
	end

	-- Stage 8: every pressurized room (CrewService: inside = any active zone). The lab's comes from
	-- WorldSites (its round room, floor to roof).
	local insideZones: { InsideZone } = {
		{ id = "hub", part = habitat.zone, build = "habitat", minLevel = 1, shape = "cylinder" },
		{ id = "greenhouse_tube", part = greenhouse.tubeZone, build = "greenhouse", minLevel = 1, shape = "cylinder" },
		{ id = "greenhouse_a", part = greenhouse.domeZone, build = "greenhouse", minLevel = 1, shape = "dome" },
		{ id = "greenhouse_b", part = greenhouse.dome2Zone, build = "greenhouse", minLevel = 2, shape = "dome" },
		-- Stage 10: the walk-through tube between dome A and dome B (a greenhouse tube, like the hub's).
		{ id = "greenhouse_tube", part = greenhouse.linkZone, build = "greenhouse", minLevel = 2, shape = "cylinder" },
		{ id = "lander", part = lander.zone :: BasePart, shape = "box" },
	}
	if labEntry then
		local interior = sites and sites.labInterior
		if type(interior) == "table" and typeof(interior.centre) == "Vector3" and type(interior.radius) == "number"
			and type(interior.bottomY) == "number" and type(interior.topY) == "number"
		then
			local height = interior.topY - interior.bottomY
			local labZone = shapedZone(
				base,
				"LabZone",
				CFrame.new(Vector3.new(interior.centre.X, interior.bottomY + height / 2, interior.centre.Z)),
				Vector3.new(interior.radius * 2, height, interior.radius * 2),
				"cylinder"
			)
			table.insert(insideZones, { id = "lab", part = labZone, build = "lab", minLevel = 1, shape = "cylinder" })
		end
		if labTubeZone then
			table.insert(insideZones, { id = "lab_tube", part = labTubeZone, build = "lab", minLevel = 1, shape = "cylinder" })
		end
	end

	-- The habitat only counts as inside once it stands: its zone moves far below the ground until
	-- then (CrewService reads the zone's CFrame through WorldBuilder.isInZone). The team flag rides
	-- on its dome.
	local habitatZoneHome = habitat.zone.CFrame
	habitatEntry.onLevel = function(level: number)
		habitatStanding = level >= 1
		habitat.zone.CFrame = if habitatStanding then habitatZoneHome else habitatZoneHome - Vector3.new(0, 2000, 0)
		habitat.missionConsolePrompt.Enabled = habitatStanding
		-- Stage 9: base level parts that stand (the side module, the mast) are solid again.
		for _, item in habitat.tierSolids do
			local solid = level >= item.level
			item.part.CanCollide = solid
			item.part.CanQuery = solid
		end
		refreshTeamFlag()
	end

	-- The greenhouse: its glass hatch closes the hub's west doorway until the dome and tube stand, and
	-- fresh food can only be picked once it is built.
	local hatch = habitat.greenhouseHatch
	local hatchAlpha = hatch.Transparency
	greenhouseEntry.onLevel = function(level: number)
		local open = level >= 1
		hatch.Transparency = if open then 1 else hatchAlpha
		hatch.CanCollide = not open
		hatch.CanQuery = not open
		greenhouse.foodPrompt.Enabled = open
		-- Stage 10: dome A's doorway toward dome B opens once the link tube stands (level 2).
		local linkOpen = level >= 2
		for _, panel in greenhouse.linkHatch do
			panel.Transparency = if linkOpen then 1 else GREENHOUSE_GLASS.transparency or 0
			panel.CanCollide = not linkOpen
			panel.CanQuery = not linkOpen
		end
	end

	-- A blueprint shelter has no mass, so it protects nobody: its zone moves far below the ground
	-- until the shelter is built (CrewService reads the zone's CFrame through WorldBuilder.isInZone).
	local shelterZoneHome = shelter.zone.CFrame
	shelterEntry.onLevel = function(level: number)
		shelter.zone.CFrame = if level >= 1 then shelterZoneHome else shelterZoneHome - Vector3.new(0, 2000, 0)
	end

	-- The dish has its own animation: during the rise it moves with the tower, then settles on its
	-- current target (a link change during the rise is not lost).
	antennaEntry.onLevel = function(level: number)
		antennaLevel = level
		refreshLaser()
	end
	antennaEntry.onRiseStep = function(offset: number)
		dishToken += 1 -- stops a running dish turn
		antenna.dishModel:PivotTo(dishTarget() + Vector3.new(0, offset, 0))
	end
	antennaEntry.onRiseDone = function()
		dishToken += 1
		antenna.dishModel:PivotTo(dishTarget())
	end

	-- Build pads: Workspace.Base.BuildPads.<id>.
	local padsFolder = folder(base, "BuildPads")
	local buildPads: { [string]: BasePart } = {}
	local buildPrompts: { [string]: ProximityPrompt } = {}
	local padIcons: { [string]: string } = {
		habitat = "home",
		solar = "solar",
		greenhouse = "plant",
		lab = "flask",
		antenna = "antenna",
		shelter = "shield",
		drill_1 = "drill",
		drill_2 = "drill",
		drill_3 = "drill",
		cargo_bot = "robot",
		garage = "car",
		landing_pad = "flag",
		ship = "rocket",
	}
	if type(buildData) == "table" then
		for _, def in buildData do
			if type(def) == "table" and type(def.id) == "string" and type(def.icon) == "string" then
				padIcons[def.id] = def.icon
			end
		end
	end
	for id, entry in entries do
		local spot = pads[id]
		if spot then
			local iconName = padIcons[id] or "build"
			local icon = (Icons :: any)[iconName] or Icons.build
			local refs = Six.buildPad(padsFolder, id, spot, icon)
			buildPads[id] = refs.pad
			buildPrompts[id] = refs.prompt
			entry.pad = refs.pad
		end
	end

	local function dustSpot(unit: BuildUnit): Vector3?
		if unit.dust then
			return unit.dust
		end
		local instance = unit.instance
		if instance:IsA("Model") then
			local cf, size = instance:GetBoundingBox()
			return cf.Position - Vector3.new(0, size.Y / 2, 0)
		end
		return nil
	end

	-- Stage 7: builds in progress (one per build id; shared by the server, see BaseService).
	type ProgressUpgrade = { up: UpgradeEntry, ghost: BasePart?, bottom: number, shown: boolean }
	type ProgressState = {
		level: number,
		fraction: number,
		copies: { ConstructionCopy },
		upgrades: { ProgressUpgrade },
		upMinY: number,
		upMaxY: number,
		extras: { Instance }, -- outlines and blueprint ghosts, removed with the state
	}
	local progressStates: { [string]: ProgressState } = {}

	local function clearBuildProgress(id: string)
		local state = if type(id) == "string" then progressStates[id] else nil
		if state == nil then
			return
		end
		progressStates[id] = nil
		for _, copy in state.copies do
			copy.instance:Destroy()
		end
		for _, extra in state.extras do
			extra:Destroy()
		end
		local entry = entries[id]
		for _, item in state.upgrades do
			if entry == nil or entry.level < item.up.level then
				item.up.part.Transparency = 1
			end
		end
	end

	local function newProgressState(id: string, entry: BuildEntry, level: number): ProgressState
		local state: ProgressState = {
			level = level,
			fraction = -1,
			copies = {},
			upgrades = {},
			upMinY = math.huge,
			upMaxY = -math.huge,
			extras = {},
		}
		local holder = folder(constructionFolder, id)
		table.insert(state.extras, holder)
		-- New structures at this level: a construction copy over the blueprint, and a foundation outline.
		for _, unit in entry.units do
			if unit.level == level and not unit.shown then
				local copy = Geo.makeConstructionCopy(unit.instance, holder)
				table.insert(state.copies, copy)
				local span = math.max(copy.maxV.X - copy.minV.X, copy.maxV.Z - copy.minV.Z)
				if #copy.parts > 0 and span <= OUTLINE_MAX_SPAN then
					Geo.constructionOutline(holder, copy.minV, copy.maxV, copy.minY + 0.05)
				end
			end
		end
		-- Upgrade parts of this level: a cyan ghost until their step reveals the real part.
		for _, up in entry.upgrades do
			if up.level == level then
				local lo, hi = Geo.partBounds(up.part)
				state.upMinY = math.min(state.upMinY, lo.Y)
				state.upMaxY = math.max(state.upMaxY, hi.Y)
				local ghost: BasePart? = nil
				if math.max(up.part.Size.X, up.part.Size.Y, up.part.Size.Z) >= HOLOGRAM_MIN_PART then
					local clone = up.part:Clone()
					clone:ClearAllChildren()
					clone.Anchored = true
					clone.CanCollide = false
					clone.CanQuery = false
					clone.CanTouch = false
					clone.CastShadow = false
					clone.Material = Enum.Material.ForceField
					clone.Color = ACCENT_SYSTEM
					clone.Transparency = HOLOGRAM_TRANSPARENCY
					clone.Reflectance = 0
					clone.Parent = holder
					ghost = clone
				end
				table.insert(state.upgrades, { up = up, ghost = ghost, bottom = lo.Y, shown = false })
			end
		end
		return state
	end

	local function setBuildProgress(id: string, level: number, stage: number, stages: number)
		local entry = if type(id) == "string" then entries[id] else nil
		if entry == nil or type(level) ~= "number" or level ~= level then
			return
		end
		local target = math.floor(level)
		if target <= entry.level or target > entry.maxLevel then
			clearBuildProgress(id)
			return
		end
		local total = if type(stages) == "number" and stages == stages and stages >= 1 then stages else 1
		local done = if type(stage) == "number" and stage == stage then math.clamp(stage, 0, total) else 0
		local fraction = done / total
		local state = progressStates[id]
		if state and state.level ~= target then
			clearBuildProgress(id)
			state = nil
		end
		local fresh = state == nil
		local current: ProgressState = state or newProgressState(id, entry, target)
		progressStates[id] = current
		if not fresh and math.abs(fraction - current.fraction) < 1e-6 then
			return
		end
		local advanced = fraction > current.fraction
		current.fraction = fraction

		-- Real parts from the bottom up: a part shows once the step height passes its lowest point.
		local risen: { BasePart } = {}
		for _, copy in current.copies do
			local threshold = copy.minY + fraction * (copy.maxY - copy.minY) + 1e-3
			for _, item in copy.parts do
				local show = fraction > 0 and item.bottom <= threshold
				if show ~= item.shown then
					item.shown = show
					item.part.Transparency = if show then item.alpha else 1
					if show and not fresh then
						table.insert(risen, item.part)
					end
				end
			end
		end
		local upThreshold = current.upMinY + fraction * (current.upMaxY - current.upMinY) + 1e-3
		for _, item in current.upgrades do
			local show = fraction > 0 and item.bottom <= upThreshold
			if show ~= item.shown then
				item.shown = show
				item.up.part.Transparency = if show then item.up.alpha else 1
				local ghost = item.ghost
				if ghost then
					ghost.Transparency = if show then 1 else HOLOGRAM_TRANSPARENCY
				end
			end
		end
		if #risen > 0 then
			Six.riseIn(risen, CONSTRUCTION_DROP, nil, nil)
		end
		if advanced or fresh then
			-- Dust where the work happens: the unit's dust spot, else the middle of the new parts, else the pad.
			local spot: Vector3? = nil
			for _, unit in entry.units do
				if unit.level == target and unit.dust then
					spot = unit.dust
					break
				end
			end
			local first = current.copies[1]
			if spot == nil and first and #first.parts > 0 then
				spot = Vector3.new((first.minV.X + first.maxV.X) / 2, first.minY, (first.minV.Z + first.maxV.Z) / 2)
			end
			local pad = entry.pad
			if spot == nil and pad then
				spot = pad.Position
			end
			if spot then
				Six.dustPuff(base, spot)
			end
		end
	end

	local function setBuildLevel(id: string, level: number, animate: boolean)
		local entry = if type(id) == "string" then entries[id] else nil
		if entry == nil or type(level) ~= "number" or level ~= level then
			return
		end
		local newLevel = math.clamp(math.floor(level), 0, entry.maxLevel)
		-- A finished (or reset) level ends its build in progress; restores the upgrade parts first so
		-- they rise in below like any upgrade.
		local progress = progressStates[id]
		if progress and (newLevel >= progress.level or newLevel ~= entry.level) then
			clearBuildProgress(id)
		end
		local raised: { Instance } = {}
		local raisedUnits: { BuildUnit } = {}
		for _, unit in entry.units do
			local show = newLevel >= unit.level
			if show ~= unit.shown then
				unit.shown = show
				if show then
					unit.hologram.Parent = hidden
					unit.instance.Parent = unit.home
					table.insert(raised, unit.instance)
					table.insert(raisedUnits, unit)
				else
					unit.instance.Parent = hidden
					unit.hologram.Parent = blueprints
				end
			end
		end
		local upgraded: { Instance } = {}
		for _, up in entry.upgrades do
			local visible = newLevel >= up.level
			local target = if visible then up.alpha else 1
			if up.part.Transparency ~= target then
				up.part.Transparency = target
				if visible then
					table.insert(upgraded, up.part)
				end
			end
		end
		for _, item in entry.lights do
			item.light.Enabled = newLevel >= item.level
		end
		entry.level = newLevel
		if entry.onLevel then
			entry.onLevel(newLevel)
		end
		if animate ~= true then
			return
		end
		if #raised > 0 then
			Six.riseIn(Six.risableParts(raised), RISE_DROP, entry.onRiseStep, entry.onRiseDone)
			for _, unit in raisedUnits do
				local spot = dustSpot(unit)
				if spot then
					Six.dustPuff(base, spot)
				end
			end
		end
		if #upgraded > 0 then
			Six.riseIn(Six.risableParts(upgraded), UPGRADE_DROP, nil, nil)
			local pad = entry.pad
			if pad and #raised == 0 then
				Six.dustPuff(base, pad.Position)
			end
		end
	end

	local function buildLevel(id: string): number
		local entry = if type(id) == "string" then entries[id] else nil
		return if entry then entry.level else 0
	end

	local function isBuilt(id: string): boolean
		return buildLevel(id) >= 1
	end

	-- Stage 7: the parts crate a player carries (BaseService decides who carries one).
	local function setCarryCrate(character: Model, carrying: boolean)
		if typeof(character) ~= "Instance" or not character:IsA("Model") then
			return
		end
		local existing = character:FindFirstChild(CARRY_CRATE_NAME)
		if carrying ~= true then
			if existing then
				existing:Destroy()
			end
			return
		end
		if existing then
			return
		end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			Geo.carriedCrate(character, rootPart)
		end
	end

	-- Stage 7: meteorite craters (WorldSites, or the simple fallback) in Workspace.Base.Impacts.
	local impactsFolder = base:FindFirstChild("Impacts") or folder(base, "Impacts")
	local sitesSpawnImpact = if sites and type(sites.spawnImpact) == "function" then sites.spawnImpact else nil
	local sitesClearImpact = if sites and type(sites.clearImpact) == "function" then sites.clearImpact else nil
	local fallbackCraters: { [Instance]: boolean } = {}
	local function spawnImpact(position: Vector3): (Model, ProximityPrompt)
		if sitesSpawnImpact then
			local ok, impactModel, impactPrompt = pcall(sitesSpawnImpact, position)
			if ok and typeof(impactModel) == "Instance" and typeof(impactPrompt) == "Instance" then
				return impactModel :: any, impactPrompt :: any
			end
			warn(`[SpaceBaseOdyssey] WorldSites.spawnImpact failed, using the simple crater: {impactModel}`)
		end
		local crater, cratePrompt = Geo.fallbackImpact(impactsFolder, position)
		fallbackCraters[crater] = true
		return crater, cratePrompt
	end
	local function clearImpact(impact: Model)
		if typeof(impact) ~= "Instance" then
			return
		end
		if fallbackCraters[impact] then
			fallbackCraters[impact] = nil
		elseif sitesClearImpact then
			local ok, err = pcall(sitesClearImpact, impact)
			if ok then
				return
			end
			warn(`[SpaceBaseOdyssey] WorldSites.clearImpact failed: {err}`)
		end
		impact:Destroy()
	end
	local garageBays: { CFrame } = {}
	if sites and type(sites.garageBays) == "table" then
		for _, bay in sites.garageBays do
			if typeof(bay) == "CFrame" then
				table.insert(garageBays, bay)
			end
		end
	end
	local pois: { { id: string, position: Vector3, prompt: ProximityPrompt } } = {}
	if sites and type(sites.pois) == "table" then
		for _, poi in sites.pois do
			if type(poi) == "table" and type(poi.id) == "string" and typeof(poi.position) == "Vector3" and typeof(poi.prompt) == "Instance" then
				table.insert(pois, { id = poi.id, position = poi.position, prompt = poi.prompt })
			end
		end
	end

	-- Silo fill (Stage 11): the ice column shows ice / top (top = MissionData.BASE.SILO_MAX, the biggest
	-- silo) and the gold cap ring shows how much this base level may hold, so a bigger base raises the
	-- ring instead of making the ice drop. The belt's status colours the top ring (setLineState).
	-- Stage 11 review: the fill moves in quarter-ice steps (each step is a short server tween that
	-- replicates), and the cap ring only when the silo size changes.
	local siloShown = { step = -1, max = -1, scale = -1 }
	local function setSilo(ice: number, max: number, top: number?)
		if type(ice) ~= "number" or type(max) ~= "number" or ice ~= ice or max <= 0 then
			return
		end
		local scale = if type(top) == "number" and top >= max then top else max
		local stepNow = math.floor(math.max(0, ice) * 4 + 1e-6)
		if stepNow == siloShown.step and max == siloShown.max and scale == siloShown.scale then
			return
		end
		local grew = siloShown.max > 0 and max > siloShown.max
		local capChanged = max ~= siloShown.max or scale ~= siloShown.scale
		siloShown.step = stepNow
		siloShown.max = max
		siloShown.scale = scale
		local f = math.clamp(ice / scale, 0, 1)
		local height = math.max(0.05, silo.height * f)
		local centre = Vector3.new(silo.centre.X, silo.bottomY + height / 2, silo.centre.Z)
		TweenService:Create(silo.fill, SILO_TWEEN, {
			Size = Vector3.new(height, silo.diameter, silo.diameter),
			CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = if f <= 0 then 1 else 0.05,
		}):Play()
		silo.light.Enabled = f > 0
		local capY = silo.bottomY + silo.height * math.clamp(max / scale, 0, 1)
		local capCf = CFrame.new(Vector3.new(silo.centre.X, capY, silo.centre.Z)) * CFrame.Angles(0, 0, math.rad(90))
		if capChanged then
			TweenService:Create(silo.capRing, if grew then TweenInfo.new(1.6, Enum.EasingStyle.Back) else SILO_TWEEN, { CFrame = capCf }):Play()
		end
		line.folder:SetAttribute("SBO_SiloIce", ice)
		line.folder:SetAttribute("SBO_SiloMax", max)
		line.folder:SetAttribute("SBO_SiloTop", scale)
	end
	setSilo(0, 1)

	-- Stage 11 tycoon: the line's state for every client (ProductionLine.luau animates from it) and the
	-- status lamps (Theme roles: good = running, danger = silo full, warning = no power; dim = off).
	-- state: icePerMinute, status ("off" | "run" | "full"), plantLevel (0-2), airStatus ("off" | "run" |
	-- "nopower"), product ("none" | "water" | "oxygen"), drills ({ level of drill 1, 2, 3 } as shown).
	local function lampColour(lamp: BasePart, colour: Color3?)
		local on = colour ~= nil
		lamp.Color = if colour then colour else LAMP_OFF
		local glow = lamp:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Color = if colour then colour else LAMP_OFF
			glow.Brightness = if on then 1.2 else 0
		end
	end
	local function setLineState(state: { [string]: any })
		if type(state) ~= "table" then
			return
		end
		local folderRef = line.folder
		for _, key in { "icePerMinute", "status", "plantLevel", "airStatus", "product" } do
			local value = state[key]
			if type(value) == "number" or type(value) == "string" then
				local name = "SBO_" .. string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
				if folderRef:GetAttribute(name) ~= value then
					folderRef:SetAttribute(name, value)
				end
			end
		end
		if type(state.drills) == "table" then
			for i = 1, 3 do
				local level = state.drills[i]
				folderRef:SetAttribute("SBO_Drill" .. i, if type(level) == "number" then level else 0)
			end
		end
		local status = state.status
		silo.ring.Color = if status == "full" then Theme.ROLE.danger elseif status == "run" then Theme.ROLE.good else ACCENT_SYSTEM
		lampColour(line.plant.lamp, if status == "full" then Theme.ROLE.danger elseif status == "run" then Theme.ROLE.good else nil)
		local air = state.airStatus
		lampColour(line.air.lamp, if air == "run" then Theme.ROLE.good elseif air == "nopower" then Theme.ROLE.warning else nil)
		lampColour(line.port.lamp, if air == "run" or air == "nopower" then Theme.ROLE.accent else nil)
	end

	-- Stage 11 tycoon: the cargo robot's trip, as attributes for the clients (BaseService runs the trip
	-- and pays on arrival). phase: "off" | "dock" | "rest" | "load" | "go" | "drop" | "back" | "loop"
	-- (the start menu's showcase: back and forth, nothing paid); at = server time the phase started,
	-- seconds = how long it lasts, load = ice carried, product = "water" | "oxygen".
	local function setCargo(phase: string, at: number, seconds: number, load: number, product: string)
		local folderRef = line.folder
		folderRef:SetAttribute("SBO_CargoPhase", phase)
		folderRef:SetAttribute("SBO_CargoAt", at)
		folderRef:SetAttribute("SBO_CargoSeconds", seconds)
		folderRef:SetAttribute("SBO_CargoLoad", load)
		folderRef:SetAttribute("SBO_CargoProduct", product)
	end
	-- Older callers: on = the robot is built (or shown); BaseService sets the phases.
	local function setCargoActive(active: boolean)
		line.folder:SetAttribute("SBO_CargoOn", active == true)
	end

	-- Collectibles only bob and spin while someone is near, so idle servers replicate nothing.
	local awake: { boolean } = table.create(#collectibleItems, false)
	local awakeTimer = COLLECTIBLE_AWAKE_CHECK
	local secretClock = 0
	local function refreshAwake()
		local positions: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if rootPart and rootPart:IsA("BasePart") then
				table.insert(positions, rootPart.Position)
			end
		end
		for i, item in collectibleItems do
			local near = false
			for _, position in positions do
				if (position - item.home.Position).Magnitude <= COLLECTIBLE_AWAKE_RANGE then
					near = true
					break
				end
			end
			awake[i] = near
		end
		-- Stage 11 tycoon: the drill bits, ice cubes and cargo robot are animated by the clients now.
	end

	-- One cheap Heartbeat drives every animation (systems and collectibles); it stops when the base
	-- is rebuilt.
	local fanAngle = 0
	local roverAngle = rover.startAngle
	local pulseClock = 0
	local pulseAccumulator = 0
	local animation: RBXScriptConnection? = nil
	animation = RunService.Heartbeat:Connect(function(rawDt: number)
		if base.Parent == nil then
			if animation then
				animation:Disconnect()
			end
			return
		end
		local dt = math.min(rawDt, 0.1)
		if lifeStep > 0 then
			fanAngle = (fanAngle + FAN_SPEED_RAD[lifeStep + 1] * dt) % (2 * math.pi)
			life.fanRoot.CFrame = life.fanCFrame * CFrame.Angles(0, 0, fanAngle)
			pulseClock += dt
			pulseAccumulator += dt
			if pulseAccumulator >= PULSE_UPDATE_SECONDS then
				pulseAccumulator = 0
				local wave = 0.5 + 0.5 * math.sin(pulseClock * 2 * math.pi / AIR_PULSE_PERIOD[lifeStep + 1])
				life.statusLight.Brightness = 0.6 + 1.6 * wave
				life.status.Transparency = 0.35 * (1 - wave)
			end
		end
		if scienceStep > 0 then
			roverAngle = (roverAngle + ROVER_SPEED[scienceStep + 1] / ROVER_LOOP_RADIUS * dt) % (2 * math.pi)
			rover.root.CFrame = roverPose(rover.centre, roverAngle)
		end
		awakeTimer += dt
		if awakeTimer >= COLLECTIBLE_AWAKE_CHECK then
			awakeTimer = 0
			refreshAwake()
		end
		secretClock += dt
		for i, item in collectibleItems do
			if awake[i] then
				local t = secretClock + item.phase
				local bob = math.sin(t * 2) * COLLECTIBLE_BOB
				item.root.CFrame = item.home * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * COLLECTIBLE_SPIN_RAD, 0)
			end
		end
		-- Stage 11 tycoon: drill bits, ice cubes and the cargo robot move on the clients
		-- (src/client/ProductionLine.luau), so nothing of the ice line replicates every frame.
	end)

	refreshPrompts()
	setSystemVisuals({ LifeSupport = 0, Greenhouse = 0, Science = 0 })
	startSky(base, arrayTracks)
	-- Start from an empty base: only the lander and the blueprints stand (BaseService then applies
	-- the builds of the players present).
	for id in entries do
		setBuildLevel(id, 0, false)
	end

	return {
		spawn = lander.spawn,
		habitatZone = habitat.zone,
		shelterZone = shelter.zone,
		insideZones = insideZones,
		arrays = arrays,
		iceNodes = iceNodes,
		processorPrompt = habitat.processorPrompt,
		leak = { part = habitat.leakPart :: BasePart, prompt = habitat.leakPrompt },
		antenna = { model = antenna.model, dish = antenna.dish :: BasePart, prompt = antenna.prompt },
		console = { part = habitat.console :: BasePart, prompt = habitat.consolePrompt },
		missionConsole = { part = habitat.missionConsole :: BasePart, prompt = habitat.missionConsolePrompt },
		markers = markers,
		setArrayDusty = setArrayDusty,
		setLeakActive = setLeakActive,
		setAntennaLinked = setAntennaLinked,
		setStormVisuals = setStormVisuals,
		setShiftPromptsEnabled = setShiftPromptsEnabled,
		setSystemVisuals = setSystemVisuals,
		collectibles = collectibleRefs,
		observatoryDoor = observatory.door :: BasePart,
		setRoverPaint = setRoverPaint,
		setTeamFlag = setTeamFlag,
		setWaterLevel = setWaterLevel,
		onEclipse = onEclipse,
		isEclipse = isEclipse,
		previewEclipse = previewEclipse,
		setBuildLevel = setBuildLevel,
		isBuilt = isBuilt,
		buildLevel = buildLevel,
		buildPads = buildPads,
		buildPrompts = buildPrompts,
		siloPrompt = silo.prompt,
		setSilo = setSilo,
		setCargoActive = setCargoActive,
		productionLine = line.folder,
		setLineState = setLineState,
		setCargo = setCargo,
		cargoTimes = line.times,
		setBuildProgress = setBuildProgress,
		clearBuildProgress = clearBuildProgress,
		landerZone = lander.zone :: BasePart,
		crateDepot = { prompt = lander.cratePrompt, position = lander.cratePosition },
		setCarryCrate = setCarryCrate,
		greenhouseFoodPrompt = greenhouse.foodPrompt,
		labPrompt = labPrompt,
		garageBays = garageBays,
		pois = pois,
		spawnImpact = spawnImpact,
		clearImpact = clearImpact,
		sitesLoaded = sites ~= nil,
	}
end

-- Point-in-zone test for the zone parts (works for rotated parts too). Stage 8: shaped zones
-- (attribute SBO_ZoneShape "cylinder" or "dome") test their round solid, the others their box.
function WorldBuilder.isInZone(zonePart: BasePart, position: Vector3): boolean
	return WorldParts.zoneContains(zonePart, position)
end

return WorldBuilder
