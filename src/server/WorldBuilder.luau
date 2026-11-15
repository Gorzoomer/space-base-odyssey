--!strict
-- Space Base Odyssey - builds the Moon south-pole base from plain Parts and sets the lunar environment.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local Theme = require(Shared:WaitForChild("Theme"))

export type ArrayRef = { model: Model, panel: BasePart, prompt: ProximityPrompt }
export type StormStage = "none" | "warning" | "storm"
export type SystemAllocation = { LifeSupport: number, Greenhouse: number, Science: number }
export type CollectibleRef = { id: string, model: Model, prompt: ProximityPrompt }
export type RoverPaint = "default" | "cheese"

export type World = {
	spawn: SpawnLocation,
	habitatZone: BasePart,
	shelterZone: BasePart,
	arrays: { ArrayRef },
	iceNodes: { { part: BasePart, prompt: ProximityPrompt } },
	processorPrompt: ProximityPrompt,
	leak: { part: BasePart, prompt: ProximityPrompt },
	antenna: { model: Model, dish: BasePart, prompt: ProximityPrompt },
	console: { part: BasePart, prompt: ProximityPrompt },
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
	-- The ice silo behind the habitat (filled by the automatic drills), its claim prompt "SiloPrompt".
	siloPrompt: ProximityPrompt,
	setSilo: (ice: number, max: number) -> (),
	-- The cargo robot drives between the drills' conveyor and the silo while active (cosmetic).
	setCargoActive: (active: boolean) -> (),
}

type Style = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	shadow: boolean?,
}

local WorldBuilder = {}

-- Layout anchors (studs). Ground top is at Y = 0.
local HABITAT_CENTRE = Vector3.new(0, 0, 0)
local SHELTER_CENTRE = Vector3.new(70, 0, -40)
local CRATER_CENTRE = Vector3.new(0, 0, 230)
local CRATER_RADIUS = 70
local CRATER_FLOOR_Y = -24
local CRATER_RIM_Y = 8
local RIDGE_CENTRE = Vector3.new(-190, 0, -60)
local RIDGE_TOP_Y = 30
local ANTENNA_BASE = Vector3.new(-60, 0, 70)
local GROUND_HALF = 600
local GROUND_TILE = 150
local EARTH_DISTANCE = 900
-- Visual sizes (not science numbers): the Earth disc is a little wider than the game's Sun disc
-- (Sky.SunAngularSize 9 degrees) so it can hide the Sun completely during an eclipse.
local EARTH_DIAMETER = 150
local EARTH_GUI_SCALE = 1.3 -- the billboard is larger than the disc to leave room for the eclipse glow
-- Compressed sky clock (GAME pacing, not real): the real Earth turns once in 24 hours and the Sun
-- circles the lunar south-pole horizon once in about 29.5 days.
local EARTH_TURN_SECONDS = 240
local SUN_CIRCLE_SECONDS = 720
local SKY_UPDATE_SECONDS = 0.1
local ARRAY_UPDATE_SECONDS = 0.5
local ARRAY_MIN_TURN = math.rad(0.25)
-- Eclipse: starts when the Sun centre is within the Earth disc radius plus this margin (~20 s).
local ECLIPSE_MARGIN = math.rad(0.25)
local ECLIPSE_FADE_SECONDS = 3
local ECLIPSE_PREVIEW_LEAD_SECONDS = 6
-- Earth placement relative to the Sun at start (the antenna aims there), and the sun-circle checks.
local EARTH_FROM_SUN = math.rad(110)
local SUN_CIRCLE_MAX_SPREAD = math.rad(4)
local SUN_CIRCLE_MIN_ELEVATION = math.rad(2)
local SUN_SAMPLE_STEP_HOURS = 0.05
-- Lighting levels (normal and full eclipse).
local LIGHT_BRIGHTNESS = 4.5
local LIGHT_EXPOSURE = 0.45
local LIGHT_OUTDOOR_AMBIENT = Color3.fromRGB(118, 118, 132)
local ECLIPSE_BRIGHTNESS = 0.6
local ECLIPSE_EXPOSURE = 0.05
local ECLIPSE_OUTDOOR_AMBIENT = Color3.fromRGB(44, 44, 60)
-- Earth disc shading (transparency of the dark overlays).
local EARTH_NIGHT_TRANSPARENCY = 0.1
local EARTH_TERMINATOR_SOFTNESS = 0.04
-- Mars is a small red dot in the black sky: the teaser for the next mission.
local MARS_DISTANCE = 950
local MARS_DIAMETER = 16
local MARS_ELEVATION = math.rad(16)
local MARS_FROM_SUN = math.rad(-100) -- Earth sits at +110 degrees from the Sun's direction
-- Secret places (see buildSecrets). Each is enclosed by walls at least 4 studs thick.
local LOOKOUT_DISTANCE = 20 -- the rock spire behind the antenna
local LOOKOUT_YAW = math.rad(-30) -- turns its niche away from the crater rim as well as the base
local LAVA_TUBE_MIN = Vector3.new(-320, 0, -85) -- hill west of the ridge
local LAVA_TUBE_MAX = Vector3.new(-270, 24, -35)
local OBSERVATORY_HILL = Vector3.new(230, 0, 60)
local OBSERVATORY_HILL_Y = 14
local COLLECTIBLE_PROMPT_DISTANCE = 8
local COLLECTIBLE_FLOAT = 2.6 -- item centre above the floor
local COLLECTIBLE_BOB = 0.25
local COLLECTIBLE_SPIN_RAD = 0.9
local COLLECTIBLE_AWAKE_RANGE = 90 -- only animate items someone is near
local COLLECTIBLE_AWAKE_CHECK = 0.5
local YIELD_EVERY = 40

-- Sun search window: low enough that crater rims shade the floor, high enough to light the ground.
local SUN_TARGET_ELEVATION = math.rad(8)
local SUN_MIN_ELEVATION = math.rad(5)
local SUN_MAX_ELEVATION = math.rad(11)

-- Activation distance from the world contract.
local PROMPT_DISTANCE = 10

-- Palette.
local WHITE_HULL = Color3.fromRGB(226, 228, 232)
-- Lunar Sunrise accents (Theme): cyan = systems and guidance, orange = warnings and the shelter,
-- magenta = greenhouse and secrets, lime = go / ok. The Moon itself stays grey.
local PALETTE = Theme.PALETTE
local ACCENT_SYSTEM = PALETTE.cyan
local ACCENT_WARNING = PALETTE.orange
local ACCENT_SECRET = PALETTE.magenta
local ACCENT_OK = PALETTE.lime
local HULL_TRIM = ACCENT_SYSTEM
local GLASS_COLOUR = Color3.fromRGB(255, 214, 160)
local METAL = Color3.fromRGB(150, 155, 162)
local DARK_METAL = Color3.fromRGB(70, 74, 82)
local REGOLITH_LIGHT = Color3.fromRGB(150, 147, 141)
local PANEL_CLEAN = Color3.fromRGB(30, 56, 128)
local PANEL_DUSTY = Color3.fromRGB(146, 134, 116)
local LINK_RED = PALETTE.red
local LINK_GREEN = ACCENT_OK
local STORM_AMBER = ACCENT_WARNING
local STORM_RED = PALETTE.red
local LAMP_OFF = Color3.fromRGB(60, 60, 64)
local ICE_GLOW = Color3.fromRGB(170, 232, 255)
local MARKER_GUIDE = ACCENT_SYSTEM
local MARKER_SHELTER = ACCENT_WARNING
-- Real plant LEDs mix red and blue, so they look magenta-pink.
local GROW_PINK = ACCENT_SECRET
local GROW_DIM = ACCENT_SECRET:Lerp(Color3.new(0, 0, 0), 0.35)
local PLANT_GREEN = Color3.fromRGB(78, 188, 88)
local PLANT_GREY = Color3.fromRGB(124, 140, 116)
local AIR_OK = ACCENT_OK
local AIR_WINDOW_ON = ACCENT_SYSTEM:Lerp(Color3.new(0, 0, 0), 0.25)
local AIR_WINDOW_HIGH = ACCENT_SYSTEM
local AIR_WINDOW_OFF = PALETTE.nightLight
local CHEESE_PAINT = PALETTE.gold
local CHEESE_SPOT = PALETTE.gold:Lerp(Color3.fromRGB(150, 100, 20), 0.45)
local MARS_RED = Color3.fromRGB(214, 86, 48)
local INTERIOR_LIGHT = Color3.fromRGB(255, 238, 214)
local WATER_COLOUR = PALETTE.cyan:Lerp(Color3.fromRGB(40, 110, 230), 0.4)
local WATER_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Visual tuning for the system animations (not gameplay numbers). Index = brightness step + 1.
local GROW_BRIGHTNESS = { 0, 1.2, 2.4 }
local GROW_RANGE = { 8, 11, 15 }
local FAN_SPEED_RAD = { 0, 7, 19 }
local AIR_PULSE_PERIOD = { 0, 2.2, 0.9 }
local ROVER_SPEED = { 0, 2.5, 5 } -- studs per second along its loop
local ROVER_LOOP_RADIUS = 11
local ROVER_RIM_RADIUS = 85 -- middle of the flat rim band (70 to 100)
local PULSE_UPDATE_SECONDS = 0.05

-- Stage 6 build-and-grow layout and animation (visual tuning, not gameplay numbers; the gameplay
-- numbers live in MissionData.BASE).
local SILO_CENTRE = Vector3.new(22, 0, -29) -- behind the habitat, right outside the water tank's corner
local SILO_GLASS_HEIGHT = 11
local SILO_GLASS_DIAMETER = 6
local CARGO_DOCK = Vector3.new(12, 0, -35)
local CARGO_RIDE_HEIGHT = 1.3
local CARGO_SPEED = 9 -- studs per second
local CARGO_WAIT_SECONDS = 2 -- loading or unloading at each end
local DRILL_FLOOR_RADIUS = 56 -- drills stand on the crater floor near the rim wall (floor ends at 70)
local DRILL_SPREAD = 0.3 -- radians between neighbouring drills
local DRILL_PAD_RADIUS = 84 -- their build pads are on the rim above them
local HOPPER_RADIUS = 73 -- the rim hopper where the three lift belts meet
local CONVEYOR_FOOT_RADIUS = 117.5 -- just past the bottom of the rim's outer slope (r = 116)
local DRILL_SPIN_RAD = { 3, 5, 8 } -- bit spin by drill level
local DRILL_AWAKE_RANGE = 220 -- drills spin and ice cubes move only while someone is this close
local ICE_CUBE_COUNT = 5
local ICE_CUBE_SPEED = 5
local SPIN_UPDATE_SECONDS = 1 / 15
local RISE_SECONDS = 1.2
local RISE_DROP = 6 -- a new structure rises this far out of the ground
local UPGRADE_DROP = 3
local HOLOGRAM_TRANSPARENCY = 0.45
local HOLOGRAM_MIN_PART = 0.8 -- tiny parts are left out of blueprints
local PAD_DIAMETER = 6.4
local PAD_HEIGHT = 0.3
local PAD_RING_DIAMETER = 7.2
local PAD_MAXED_DIAMETER = 2.6
local BUILD_PROMPT_HOLD = 0.6
local SILO_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Invisible guidance points in Workspace.Base.Markers (client contract).
local MARKER_NAMES = table.freeze({
	"ShelterDoor",
	"HabitatDoor",
	"Antenna",
	"IceSite",
	"Processor",
	"Console",
	"Leak",
	"Greenhouse",
	"Arrays",
	"Silo", -- Stage 6: the ice silo's claim side (C.A.R.L. guides here when it is full)
})

-- Module state shared between applyEnvironment and build.
local earthPosition: Vector3? = nil
local marsPosition: Vector3? = nil
local partCounter = 0

-- Sky state (Stage 5): the Sun circling the horizon, the turning Earth and the eclipse.
type EarthGui = {
	mapA: ImageLabel,
	mapB: ImageLabel,
	nightPivot: Frame,
	nightGradient: UIGradient,
	eclipseGlow: Frame,
	eclipseStroke: UIStroke,
}
local earthGui: EarthGui? = nil
local earthPhaseEdge = math.huge -- last day/night line sent to the Earth disc (forces the first update)
local EARTH_PHASE_MIN_EDGE = 0.002 -- skip smaller phase changes (not visible, saves replication)
local EARTH_PHASE_MIN_DEGREES = 0.2
local sunClockStart = 12 -- ClockTime when the base was built
local sunClockAtEarth: number? = nil -- ClockTime when the Sun sits right behind the Earth
local sunCircleEnabled = false
-- Roblox's Sun model does not keep a constant height at the pole, so the Sun's path around the horizon
-- is a precomputed track: for each compass degree, the (latitude, clock) pair that puts the Sun there at
-- the target height. Stepping through it moves the Sun around the horizon like at the real south pole.
local sunTrackMode = false
local sunTrack: { { lat: number, clock: number } }? = nil
local sunTrackAzimuth = 0 -- radians, compass direction of the Sun (atan2(x, z))
local sunTrackIndex = -1
local EARTH_TRACK_AZIMUTH_DEG = 20 -- Earth hangs over the crater side, the open part of the sky
local skyConnection: RBXScriptConnection? = nil
local eclipseActive = false
local eclipseAmount = 0
local eclipseListeners: { (active: boolean) -> () } = {}

-- Stage 6: parts that are rising into place right now (the sun tracker, drill bits and the cargo
-- robot leave them alone until they arrive), and extra no-boulder circles around the new structures.
local risingParts: { [BasePart]: boolean } = {}
local extraKeepouts: { { x: number, z: number, r: number } } = {}

------------------------------------------------------------------------------------------------
-- Part helpers
------------------------------------------------------------------------------------------------

local function counted()
	partCounter += 1
	if partCounter % YIELD_EVERY == 0 then
		task.wait()
	end
end

local function finish(p: BasePart, parent: Instance, name: string, size: Vector3, cf: CFrame, style: Style)
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = style.color
	p.Material = style.material or Enum.Material.SmoothPlastic
	p.Transparency = style.transparency or 0
	p.Reflectance = style.reflectance or 0
	p.CastShadow = if style.shadow == nil then true else style.shadow
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if style.collide == false then
		p.CanCollide = false
		p.CanQuery = false
	else
		p.CanCollide = true
	end
	p.Parent = parent
	counted()
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, style: Style): Part
	local p = Instance.new("Part")
	finish(p, parent, name, size, cf, style)
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, style: Style): WedgePart
	local p = Instance.new("WedgePart")
	finish(p, parent, name, size, cf, style)
	return p
end

local function ball(parent: Instance, name: string, diameter: number, position: Vector3, style: Style): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	finish(p, parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), style)
	return p
end

-- Cylinder whose axis follows the X axis of `cf`.
local function cylinder(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, style: Style): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	finish(p, parent, name, Vector3.new(length, diameter, diameter), cf, style)
	return p
end

local function vcylinder(parent: Instance, name: string, height: number, diameter: number, centre: Vector3, style: Style): Part
	return cylinder(parent, name, height, diameter, CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)), style)
end

-- Cylinder lying along world Z.
local function zcylinder(parent: Instance, name: string, length: number, diameter: number, centre: Vector3, style: Style): Part
	return cylinder(parent, name, length, diameter, CFrame.new(centre) * CFrame.Angles(0, math.rad(90), 0), style)
end

-- Axis-aligned box given by two corners.
local function box(parent: Instance, name: string, a: Vector3, b: Vector3, style: Style): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	return part(parent, name, maxV - minV, CFrame.new((minV + maxV) / 2), style)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function pointLight(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows
	light.Parent = parent
	return light
end

local function makePrompt(parent: Instance, key: string, fallback: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TaskPrompt"
	prompt.ActionText = fallback
	prompt.ObjectText = ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("TextKey", key)
	prompt.Parent = parent
	return prompt
end

local function zone(parent: Instance, name: string, a: Vector3, b: Vector3): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = maxV - minV
	p.CFrame = CFrame.new((minV + maxV) / 2)
	p.Parent = parent
	return p
end

-- Welds parts to an anchored root so moving the root's CFrame moves the whole group (no physics:
-- the assembly stays anchored, and only the root's CFrame has to replicate).
local function weldTo(root: BasePart, parts: { BasePart })
	for _, p in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Massless = true
		p.Anchored = false
	end
end

local function markerPart(parent: Instance, name: string, position: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	p.Parent = parent
	return p
end

-- Stage 6 build levels. A part tagged with upgrade(p, level) only shows from that build level on
-- (lights inside it switch on with it); SBO_NoRise parts are moved by their own code, not by the
-- rise-in animation.
local UPGRADE_ATTRIBUTE = "SBO_Upgrade"
local ALPHA_ATTRIBUTE = "SBO_Alpha"
local NO_RISE_ATTRIBUTE = "SBO_NoRise"

local function upgrade(p: BasePart, level: number)
	p:SetAttribute(UPGRADE_ATTRIBUTE, level)
	p:SetAttribute(ALPHA_ATTRIBUTE, p.Transparency)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	for _, item in p:GetDescendants() do
		if item:IsA("Light") then
			item.Enabled = false
		elseif item:IsA("Beam") then
			item.Enabled = false
		end
	end
end

-- A flat belt (or beam) from a to b: width across, thickness up, length along a -> b.
local function belt(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, thickness: number, style: Style): Part
	local length = (b - a).Magnitude
	return part(parent, name, Vector3.new(width, thickness, length), CFrame.lookAt((a + b) / 2, b), style)
end

-- A cylinder from a to b.
local function pipe(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, style: Style): Part
	local length = (b - a).Magnitude
	return cylinder(parent, name, length, diameter, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), style)
end

local function dirFromAngle(angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-3 then
		return fallback
	end
	return flat.Unit
end

local function regolith(rng: Random, base: number, spread: number): Color3
	local g = math.clamp(base + rng:NextInteger(-spread, spread), 0, 255)
	return Color3.fromRGB(g, math.max(g - 1, 0), math.max(g - 5, 0))
end

local function sunDirection(): Vector3
	local dir = Lighting:GetSunDirection()
	if dir.Magnitude < 1e-3 then
		return Vector3.new(0, math.sin(SUN_TARGET_ELEVATION), -math.cos(SUN_TARGET_ELEVATION))
	end
	return dir.Unit
end

local function defaultEarthPosition(): Vector3
	local sun = sunDirection()
	local sunH = flatUnit(sun, Vector3.new(0, 0, -1))
	local sunAngle = math.atan2(sunH.X, sunH.Z)
	-- Same height above the horizon as the Sun, so the Sun can pass behind the Earth.
	local elevation = math.asin(math.clamp(sun.Y, -1, 1))
	local dir = dirFromAngle(sunAngle + EARTH_FROM_SUN) * math.cos(elevation) + Vector3.new(0, math.sin(elevation), 0)
	return dir * EARTH_DISTANCE
end

local function defaultMarsPosition(): Vector3
	local sunH = flatUnit(sunDirection(), Vector3.new(0, 0, -1))
	local sunAngle = math.atan2(sunH.X, sunH.Z)
	local dir = dirFromAngle(sunAngle + MARS_FROM_SUN) * math.cos(MARS_ELEVATION) + Vector3.new(0, math.sin(MARS_ELEVATION), 0)
	return dir * MARS_DISTANCE
end

------------------------------------------------------------------------------------------------
-- Environment
------------------------------------------------------------------------------------------------

-- Finds a latitude closest to the south pole and a clock time where the Sun skims the horizon.
local function chooseSun(): (number, number)
	local targetY = math.sin(SUN_TARGET_ELEVATION)
	local minY = math.sin(SUN_MIN_ELEVATION)
	local maxY = math.sin(SUN_MAX_ELEVATION)
	local latitude = -89.5
	while latitude <= -45 do
		Lighting.GeographicLatitude = latitude
		local bestTime: number? = nil
		local bestError = math.huge
		for step = 0, 95 do
			local clock = step * 0.25
			Lighting.ClockTime = clock
			local y = Lighting:GetSunDirection().Y
			if y >= minY and y <= maxY then
				local err = math.abs(y - targetY)
				if err < bestError then
					bestError = err
					bestTime = clock
				end
			end
		end
		if bestTime ~= nil then
			return latitude, bestTime
		end
		latitude += 0.5
	end
	return -89.5, 12
end

-- Round frame helper for the Earth billboard.
local function roundFrame(parent: Instance, name: string, scale: number, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(scale, scale)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function ringStroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent
	return stroke
end

-- A dark overlay whose UIGradient fades at both ends (limb darkening, gives the flat map a round look).
local function limbShade(parent: Instance, rotation: number)
	local f = Instance.new("Frame")
	f.Name = "LimbShade"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	f.ZIndex = 3
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.16, 0.72),
		NumberSequenceKeypoint.new(0.34, 1),
		NumberSequenceKeypoint.new(0.66, 1),
		NumberSequenceKeypoint.new(0.84, 0.72),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	gradient.Parent = f
	f.Parent = parent
end

-- The Earth: a camera-facing billboard with the NASA Blue Marble map (Icons.earthMap) clipped to a
-- circle by a CanvasGroup. Two copies of the map scroll side by side so the Earth turns; a dark
-- overlay with a soft edge shows its phase (the half that faces the Sun is lit). One part, a few
-- GUI objects and no meshes, so it is cheap to draw.
local function buildEarth(sky: Instance, position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Earth"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = sky

	local gui = Instance.new("BillboardGui")
	gui.Name = "EarthGui"
	gui.Size = UDim2.fromScale(EARTH_DIAMETER * EARTH_GUI_SCALE, EARTH_DIAMETER * EARTH_GUI_SCALE)
	gui.LightInfluence = 0
	gui.Brightness = 1.1
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Adornee = anchor
	gui.Parent = anchor

	local disc = 1 / EARTH_GUI_SCALE
	-- Behind the disc: the red-orange eclipse glow (sunlight bent through Earth's air). It only shows
	-- during an eclipse; the rest of the time the Earth has no outline (team feedback, Stage 6).
	local eclipseGlow = roundFrame(gui, "EclipseGlow", disc * 1.16, PALETTE.orange, 1, 1)

	local group = Instance.new("CanvasGroup")
	group.Name = "Disc"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(disc, disc)
	group.BackgroundColor3 = PALETTE.night
	group.BackgroundTransparency = 0
	group.BorderSizePixel = 0
	group.ZIndex = 3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = group
	group.Parent = gui

	-- The map is 2:1, so one copy is two discs wide: the disc shows half of the globe at a time.
	local function map(name: string, x: number): ImageLabel
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.Image = Icons.earthMap
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Size = UDim2.fromScale(2, 1)
		image.Position = UDim2.fromScale(x, 0)
		image.ScaleType = Enum.ScaleType.Stretch
		image.ZIndex = 1
		image.Parent = group
		return image
	end
	local mapA = map("MapA", -2)
	local mapB = map("MapB", 0)

	limbShade(group, 0)
	limbShade(group, 90)

	-- Night side: the pivot turns toward the Sun and the gradient moves the day/night line.
	local nightPivot = Instance.new("Frame")
	nightPivot.Name = "NightPivot"
	nightPivot.AnchorPoint = Vector2.new(0.5, 0.5)
	nightPivot.Position = UDim2.fromScale(0.5, 0.5)
	nightPivot.Size = UDim2.fromScale(1.5, 1.5)
	nightPivot.BackgroundTransparency = 1
	nightPivot.BorderSizePixel = 0
	nightPivot.ZIndex = 4
	nightPivot.Parent = group
	local night = Instance.new("Frame")
	night.Name = "Night"
	night.Size = UDim2.fromScale(1, 1)
	night.BackgroundColor3 = PALETTE.night
	night.BackgroundTransparency = 0
	night.BorderSizePixel = 0
	night.ZIndex = 4
	night.Parent = nightPivot
	local nightGradient = Instance.new("UIGradient")
	nightGradient.Transparency = NumberSequence.new(1)
	nightGradient.Parent = night

	-- Thin ring on top that lights up only during an eclipse.
	local eclipseRing = roundFrame(gui, "EclipseRing", disc * 1.01, PALETTE.orange, 1, 6)
	local eclipseStroke = ringStroke(eclipseRing, PALETTE.orange:Lerp(PALETTE.red, 0.35), 3, 1)

	earthPhaseEdge = math.huge
	earthGui = {
		mapA = mapA,
		mapB = mapB,
		nightPivot = nightPivot,
		nightGradient = nightGradient,
		eclipseGlow = eclipseGlow,
		eclipseStroke = eclipseStroke,
	}
end

local function buildSkyBodies()
	local old = Workspace:FindFirstChild("SkyBodies")
	if old then
		old:Destroy()
	end
	local sky = Instance.new("Model")
	sky.Name = "SkyBodies"
	sky.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	buildEarth(sky, earthPosition or defaultEarthPosition())

	-- Mars: a small reddish disc, the next destination. The observatory telescope points at it.
	ball(sky, "Mars", MARS_DIAMETER, marsPosition or defaultMarsPosition(), {
		color = MARS_RED,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})

	-- A sprinkle of stars: there is no air to hide them.
	local rng = Random.new(1969)
	for i = 1, 70 do
		local azimuth = rng:NextNumber(0, math.pi * 2)
		local elevation = math.asin(rng:NextNumber(math.sin(math.rad(4)), 0.97))
		local dir = Vector3.new(
			math.cos(elevation) * math.sin(azimuth),
			math.sin(elevation),
			math.cos(elevation) * math.cos(azimuth)
		)
		local brightness = rng:NextInteger(200, 255)
		ball(sky, "Star" .. i, rng:NextNumber(2.2, 4.4), dir * 950, {
			color = Color3.fromRGB(brightness, brightness, math.min(255, brightness + 10)),
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	end

	sky.Parent = Workspace
end

-- At the lunar south pole the Sun does not rise and set: it circles just above the horizon. Changing
-- ClockTime at latitude -89.5 turns it around the horizon at an almost constant height. This samples
-- one full circle, checks that the Sun stays low, and puts the Earth on the Sun's path so the Sun
-- passes behind it once per circle. If the circle is not flat (other latitude), the Sun stays still.
local function buildSunTrack(elevation: number): boolean
	local target = math.sin(elevation)
	local best: { [number]: { lat: number, clock: number, err: number } } = {}
	local rows = 0
	local lat = -89.5
	while lat <= 89.5 do
		Lighting.GeographicLatitude = lat
		local clock = 0
		while clock < 24 do
			Lighting.ClockTime = clock
			local d = Lighting:GetSunDirection()
			local err = math.abs(d.Y - target)
			if err < 0.02 then
				local index = math.floor(math.deg(math.atan2(d.X, d.Z)) % 360) + 1
				local current = best[index]
				if current == nil or err < current.err then
					best[index] = { lat = lat, clock = clock, err = err }
				end
			end
			clock += 0.05
		end
		lat += 0.5
		rows += 1
		if rows % 24 == 0 then
			task.wait()
		end
	end
	local found = 0
	for i = 1, 360 do
		if best[i] then
			found += 1
		end
	end
	if found < 180 then
		return false
	end
	local track: { { lat: number, clock: number } } = {}
	for i = 1, 360 do
		local entry = best[i]
		local offset = 1
		while entry == nil and offset < 180 do
			entry = best[((i - 1 + offset) % 360) + 1] or best[((i - 1 - offset) % 360) + 1]
			offset += 1
		end
		local chosen = entry :: { lat: number, clock: number, err: number }
		track[i] = { lat = chosen.lat, clock = chosen.clock }
	end
	sunTrack = track
	return true
end

local function applySunTrack(azimuth: number)
	local track = sunTrack
	if not track then
		return
	end
	local index = math.floor(math.deg(azimuth) % 360) + 1
	if index == sunTrackIndex then
		return
	end
	sunTrackIndex = index
	Lighting.GeographicLatitude = track[index].lat
	Lighting.ClockTime = track[index].clock
end

local function planSunCircle(startClock: number)
	Lighting.ClockTime = startClock
	local startSun = sunDirection()
	local startH = flatUnit(startSun, Vector3.new(0, 0, -1))
	local target = math.atan2(startH.X, startH.Z) + EARTH_FROM_SUN
	local minElevation, maxElevation = math.huge, -math.huge
	local bestClock: number? = nil
	local bestDir = startSun
	local bestGap = math.huge
	local steps = math.floor(24 / SUN_SAMPLE_STEP_HOURS + 0.5)
	for k = 0, steps - 1 do
		local clock = k * SUN_SAMPLE_STEP_HOURS
		Lighting.ClockTime = clock
		local dir = sunDirection()
		local elevation = math.asin(math.clamp(dir.Y, -1, 1))
		minElevation = math.min(minElevation, elevation)
		maxElevation = math.max(maxElevation, elevation)
		local h = flatUnit(dir, startH)
		local gap = math.abs((math.atan2(h.X, h.Z) - target + math.pi) % (2 * math.pi) - math.pi)
		if gap < bestGap then
			bestGap = gap
			bestClock = clock
			bestDir = dir
		end
	end
	Lighting.ClockTime = startClock
	sunCircleEnabled = maxElevation - minElevation <= SUN_CIRCLE_MAX_SPREAD and minElevation >= SUN_CIRCLE_MIN_ELEVATION
	if sunCircleEnabled and bestClock ~= nil then
		sunClockAtEarth = bestClock
		earthPosition = bestDir * EARTH_DISTANCE
	elseif buildSunTrack(SUN_TARGET_ELEVATION) then
		sunTrackMode = true
		sunCircleEnabled = true
		sunClockAtEarth = nil
		local elevation = SUN_TARGET_ELEVATION
		local earthAzimuth = math.rad(EARTH_TRACK_AZIMUTH_DEG)
		earthPosition = Vector3.new(
			math.sin(earthAzimuth) * math.cos(elevation),
			math.sin(elevation),
			math.cos(earthAzimuth) * math.cos(elevation)
		) * EARTH_DISTANCE
		-- Start with the Sun opposite the Earth (full Earth); it reaches the Earth half a circle later.
		sunTrackAzimuth = earthAzimuth + math.pi
		sunTrackIndex = -1
		applySunTrack(sunTrackAzimuth)
	else
		warn(
			`[SpaceBaseOdyssey] Sun does not circle the horizon here (elevation {math.deg(minElevation)} to {math.deg(maxElevation)} deg); the Sun stays still`
		)
		sunClockAtEarth = nil
		earthPosition = defaultEarthPosition()
	end
end

function WorldBuilder.applyEnvironment(data: any)
	Workspace.Gravity = data.WORLD.MOON_GRAVITY_STUDS
	StarterPlayer.CharacterUseJumpPower = true
	StarterPlayer.CharacterJumpPower = data.WORLD.JUMP_POWER
	-- LeftShift is the Run key; turn off Shift Lock so the two do not fight.
	StarterPlayer.EnableMouseLockOption = false
	StarterPlayer.CharacterWalkSpeed = data.WORLD.WALK_SPEED

	-- No atmosphere and no clouds on the Moon.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("Clouds") then
			child:Destroy()
		end
	end
	for _, child in Workspace.Terrain:GetChildren() do
		if child:IsA("Clouds") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "MoonSky"
	sky.SkyboxBk = ""
	sky.SkyboxDn = ""
	sky.SkyboxFt = ""
	sky.SkyboxLf = ""
	sky.SkyboxRt = ""
	sky.SkyboxUp = ""
	sky.StarCount = 0 -- stars are Parts in SkyBodies; the built-in field would jump with the Sun track
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 9
	sky.MoonAngularSize = 0
	-- A plain near-black skybox: Roblox otherwise paints a blue day sky for some Sun-track positions,
	-- and the Moon has no air to make the sky blue.
	for _, face in { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" } do
		(sky :: any)[face] = Icons.skyBlack
	end
	sky.Parent = Lighting

	local latitude, clock = chooseSun()
	Lighting.GeographicLatitude = latitude
	Lighting.ClockTime = clock
	Lighting.Brightness = LIGHT_BRIGHTNESS
	Lighting.ExposureCompensation = LIGHT_EXPOSURE
	-- Ambient only lights places the sky cannot see (habitat, shelter), so it brightens the rooms
	-- without washing out the sunlit ground or the shadowed crater floor (OutdoorAmbient).
	Lighting.Ambient = Color3.fromRGB(38, 38, 46)
	Lighting.OutdoorAmbient = LIGHT_OUTDOOR_AMBIENT
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.03
	Lighting.FogColor = Color3.new(0, 0, 0)
	Lighting.FogStart = 100000
	Lighting.FogEnd = 100000

	-- The Baseplate template ships its own Bloom; two blooms together washed the habitat out.
	local templateBloom = Lighting:FindFirstChild("Bloom")
	if templateBloom and templateBloom:IsA("BloomEffect") then
		templateBloom.Enabled = false
	end
	local templateBlur = Lighting:FindFirstChild("DepthOfField")
	if templateBlur and templateBlur:IsA("DepthOfFieldEffect") then
		templateBlur.Enabled = false
	end

	local bloom = Lighting:FindFirstChild("SBO_Bloom")
	if not bloom then
		local newBloom = Instance.new("BloomEffect")
		newBloom.Name = "SBO_Bloom"
		newBloom.Intensity = 0.35
		newBloom.Size = 20
		newBloom.Threshold = 2.2
		newBloom.Parent = Lighting
	end

	-- Roblox tints a low Sun orange as if light crossed an atmosphere. The Moon has none: sunlight
	-- is white and the regolith grey, so desaturate and cool the image slightly.
	local grade = Lighting:FindFirstChild("SBO_MoonGrade")
	if not grade then
		local newGrade = Instance.new("ColorCorrectionEffect")
		newGrade.Name = "SBO_MoonGrade"
		newGrade.Saturation = -0.45
		newGrade.TintColor = Color3.fromRGB(228, 234, 255)
		newGrade.Contrast = 0.08
		newGrade.Parent = Lighting
	end

	local tint = Lighting:FindFirstChild("SBO_StormTint")
	if not tint then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "SBO_StormTint"
		correction.Enabled = false
		correction.Parent = Lighting
	end

	sunClockStart = clock
	planSunCircle(clock)
	marsPosition = defaultMarsPosition()
	buildSkyBodies()
	eclipseActive = false
	eclipseAmount = 0
	Workspace:SetAttribute("SBO_Eclipse", false)
end

local function stormTint(): ColorCorrectionEffect
	local existing = Lighting:FindFirstChild("SBO_StormTint")
	if existing and existing:IsA("ColorCorrectionEffect") then
		return existing
	end
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "SBO_StormTint"
	correction.Enabled = false
	correction.Parent = Lighting
	return correction
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
local CHEESE_NICHE_OFFSET = math.rad(220) -- from the ramp, between two ice nodes and far from both
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
		Vector3.new(-40, 0, 24), Vector3.new(-56, 0, -14), Vector3.new(-74, 0, -42), -- ridge ramp
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

local GLASS: Style = { color = GLASS_COLOUR, material = Enum.Material.Glass, transparency = 0.4, shadow = false }

-- A wall with a band of windows between y = 7 and y = 11.5.
local function windowWall(parent: Instance, name: string, a: Vector3, b: Vector3, windows: number, style: Style)
	local minV = a:Min(b)
	local maxV = a:Max(b)
	local lowTop, glassTop = 7, 11.5
	box(parent, name .. "Low", minV, Vector3.new(maxV.X, lowTop, maxV.Z), style)
	box(parent, name .. "High", Vector3.new(minV.X, glassTop, minV.Z), maxV, style)
	local alongX = (maxV.X - minV.X) >= (maxV.Z - minV.Z)
	if alongX then
		local mid = (minV.Z + maxV.Z) / 2
		box(parent, name .. "Glass", Vector3.new(minV.X, lowTop, mid - 0.3), Vector3.new(maxV.X, glassTop, mid + 0.3), GLASS)
	else
		local mid = (minV.X + maxV.X) / 2
		box(parent, name .. "Glass", Vector3.new(mid - 0.3, lowTop, minV.Z), Vector3.new(mid + 0.3, glassTop, maxV.Z), GLASS)
	end
	local startC = if alongX then minV.X else minV.Z
	local stopC = if alongX then maxV.X else maxV.Z
	for i = 0, windows do
		local c = startC + (stopC - startC) * (i / windows)
		local p0 = math.max(startC, c - 1)
		local p1 = math.min(stopC, c + 1)
		if alongX then
			box(parent, name .. "Pillar", Vector3.new(p0, lowTop, minV.Z), Vector3.new(p1, glassTop, maxV.Z), style)
		else
			box(parent, name .. "Pillar", Vector3.new(minV.X, lowTop, p0), Vector3.new(maxV.X, glassTop, p1), style)
		end
	end
end

type HabitatRefs = {
	spawn: SpawnLocation,
	zone: Part,
	console: Part,
	consolePrompt: ProximityPrompt,
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

	box(hab, "Floor", v(-30, 0, -20), v(30, 0.5, 20), { color = Color3.fromRGB(170, 174, 180), material = Enum.Material.DiamondPlate })
	windowWall(hab, "WallBack", v(-30, 0, -20), v(30, 18, -18), 4, hull)
	-- West wall: a glass hatch looks into the greenhouse module next door.
	windowWall(hab, "WallWestSouth", v(-30, 0, -18), v(-28, 18, -4), 1, hull)
	windowWall(hab, "WallWestNorth", v(-30, 0, 4), v(-28, 18, 18), 1, hull)
	box(hab, "WallWestLintel", v(-30, 10, -4), v(-28, 18, 4), hull)
	box(hab, "GreenhouseHatch", v(-29.3, 0.5, -4), v(-28.7, 10, 4), {
		color = Color3.fromRGB(205, 236, 232),
		material = Enum.Material.Glass,
		transparency = 0.6,
		shadow = false,
	})
	local hatchFrame: Style = { color = ACCENT_SECRET, material = Enum.Material.SmoothPlastic } -- magenta = greenhouse
	box(hab, "HatchFrame", v(-28, 0.5, -4.8), v(-27.4, 10.8, -4), hatchFrame)
	box(hab, "HatchFrame", v(-28, 0.5, 4), v(-27.4, 10.8, 4.8), hatchFrame)
	box(hab, "HatchFrame", v(-28, 10, -4), v(-27.4, 10.8, 4), hatchFrame)
	windowWall(hab, "WallEast", v(28, 0, -18), v(30, 18, 18), 3, hull)
	-- Doorway 10 wide x 12 tall so the default camera follows a player through without entering a wall.
	local doorHalf, doorTop = 5, 12
	windowWall(hab, "WallFrontWest", v(-30, 0, 18), v(-doorHalf, 18, 20), 2, hull)
	windowWall(hab, "WallFrontEast", v(doorHalf, 0, 18), v(30, 18, 20), 2, hull)
	box(hab, "Lintel", v(-doorHalf, doorTop, 18), v(doorHalf, 18, 20), hull)
	box(hab, "Roof", v(-31, 18, -21), v(31, 19.5, 21), { color = Color3.fromRGB(205, 208, 214), material = Enum.Material.SmoothPlastic })

	-- Orange trim band and roof gear.
	local trim: Style = { color = HULL_TRIM, material = Enum.Material.SmoothPlastic }
	box(hab, "Trim", v(-30.2, 15, -20.2), v(30.2, 16, -20), trim)
	box(hab, "Trim", v(-30.2, 15, 20), v(30.2, 16, 20.2), trim)
	box(hab, "Trim", v(-30.2, 15, -20), v(-30, 16, 20), trim)
	box(hab, "Trim", v(30, 15, -20), v(30.2, 16, 20), trim)
	box(hab, "Radiator", v(-22, 19.5, -14), v(-6, 20.1, 14), { color = Color3.fromRGB(235, 236, 240), material = Enum.Material.Metal })
	vcylinder(hab, "RoofMast", 6, 0.5, v(16, 22.5, -10), { color = METAL, material = Enum.Material.Metal })
	local beacon = ball(hab, "RoofBeacon", 1.2, v(16, 25.8, -10), { color = ACCENT_SYSTEM, material = Enum.Material.Neon })
	pointLight(beacon, ACCENT_SYSTEM, 10, 1, false)

	-- Doorway frame and lamp.
	local frame: Style = { color = ACCENT_SYSTEM, material = Enum.Material.SmoothPlastic } -- cyan = guidance
	box(hab, "DoorFrame", v(-doorHalf - 0.8, 0, 20), v(-doorHalf, doorTop + 0.8, 20.6), frame)
	box(hab, "DoorFrame", v(doorHalf, 0, 20), v(doorHalf + 0.8, doorTop + 0.8, 20.6), frame)
	box(hab, "DoorFrame", v(-doorHalf, doorTop, 20), v(doorHalf, doorTop + 0.8, 20.6), frame)
	local doorLamp = box(hab, "DoorLamp", v(-1.5, doorTop + 1.2, 20), v(1.5, doorTop + 1.7, 20.8), {
		color = Color3.fromRGB(255, 232, 190),
		material = Enum.Material.Neon,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Range = 24
	spot.Angle = 80
	spot.Brightness = 2
	spot.Color = Color3.fromRGB(255, 232, 200)
	spot.Parent = doorLamp

	-- Ceiling lights. Players spawn in here, so the room must be bright. Every interior light casts
	-- shadows, so none of it leaks through the walls onto the ground outside.
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
	local tankCentre = v(25, 0, -15)
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
	cylinder(hab, "WaterPipe", 3, 0.6, CFrame.new(v(21.9, 7, -15)), { color = METAL, material = Enum.Material.Metal })
	local gauge = box(hab, "WaterGauge", v(24.3, 2.6, -13.1), v(25.7, 3.4, -12.9), {
		color = ACCENT_OK,
		material = Enum.Material.Neon,
		shadow = false,
	})
	-- Water sign on the solid wall above the window band.
	local sign = box(hab, "WaterSign", v(24, 12, -18), v(26, 14, -17.8), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
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

	-- Greenhouse rack under a grow light.
	box(hab, "PlantRack", v(-7, 0.5, -17.8), v(7, 3, -15), { color = Color3.fromRGB(235, 235, 240), material = Enum.Material.SmoothPlastic })
	local rackPlants: { Part } = {}
	for i = 0, 3 do
		local x = -5.5 + i * 3.7
		table.insert(
			rackPlants,
			box(hab, "Plant", v(x - 1.2, 3, -17.3), v(x + 1.2, 4.6, -15.5), {
				color = PLANT_GREEN,
				material = Enum.Material.Grass,
			})
		)
	end
	local grow = box(hab, "GrowLight", v(-7, 7.5, -17.4), v(7, 7.9, -15.4), {
		color = GROW_PINK,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local growPoint = pointLight(grow, GROW_PINK, 10, 1, false)

	-- Crew table.
	box(hab, "TableLeg", v(-1, 0.5, -5), v(1, 3, -3), { color = METAL, material = Enum.Material.Metal })
	box(hab, "TableTop", v(-5, 3, -7), v(5, 3.4, -1), { color = Color3.fromRGB(235, 236, 240), material = Enum.Material.SmoothPlastic })

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Enabled = true
	spawnPad.AllowTeamChangeOnTouch = false
	finish(spawnPad, hab, "BaseSpawn", Vector3.new(8, 0.4, 8), CFrame.new(v(0, 0.7, 8)), {
		color = ACCENT_SYSTEM:Lerp(PALETTE.night, 0.35),
		material = Enum.Material.SmoothPlastic,
	})

	-- Air pipe on the outer east wall, where the leak appears.
	zcylinder(hab, "AirPipe", 24, 1.2, v(31, 4, 0), { color = METAL, material = Enum.Material.Metal })
	local leakPart = box(hab, "AirPipeJoint", v(30, 3, 3), v(32.2, 5, 5), { color = METAL, material = Enum.Material.Metal })
	local attachment = Instance.new("Attachment")
	attachment.Name = "LeakVent"
	attachment.Position = Vector3.new(1.1, 0, 0)
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

	local zonePart = zone(base, "HabitatZone", v(-28, 0.5, -18), v(28, 17.5, 18))

	return {
		spawn = spawnPad,
		zone = zonePart,
		console = console,
		consolePrompt = consolePrompt,
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
	}
end

------------------------------------------------------------------------------------------------
-- Greenhouse module (glass, attached to the habitat's west wall)
------------------------------------------------------------------------------------------------

type GreenhouseRefs = { model: Model, strips: { Part }, stripLights: { PointLight }, plants: { Part }, centre: Vector3 }

local GREENHOUSE_GLASS: Style = {
	color = Color3.fromRGB(205, 236, 232),
	material = Enum.Material.Glass,
	transparency = 0.62,
	shadow = false,
}

local function buildGreenhouse(base: Instance): GreenhouseRefs
	local gh = model(base, "Greenhouse")
	local o = HABITAT_CENTRE
	local function v(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	-- Own random stream so the rest of the base keeps its layout.
	local rng = Random.new(2015)
	local x0, x1 = -44, -30 -- x1 is the habitat's outer west wall
	local z0, z1 = -12, 12
	local eaveY, ridgeY = 9, 12.5
	local ridgeX = (x0 + x1) / 2
	local halfSpan = (x1 - x0) / 2
	local rise = ridgeY - eaveY
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	local frame: Style = { color = METAL, material = Enum.Material.Metal }

	box(gh, "Floor", v(x0, 0, z0), v(x1, 0.5, z1), { color = Color3.fromRGB(176, 180, 186), material = Enum.Material.DiamondPlate })
	box(gh, "KerbWest", v(x0, 0.5, z0), v(x0 + 0.6, 2, z1), hull)
	box(gh, "KerbSouth", v(x0 + 0.6, 0.5, z0), v(x1, 2, z0 + 0.6), hull)
	box(gh, "KerbNorth", v(x0 + 0.6, 0.5, z1 - 0.6), v(x1, 2, z1), hull)
	box(gh, "GlassWest", v(x0 + 0.1, 2, z0 + 0.6), v(x0 + 0.5, eaveY, z1 - 0.6), GREENHOUSE_GLASS)
	box(gh, "GlassSouth", v(x0 + 0.6, 2, z0 + 0.1), v(x1, eaveY, z0 + 0.5), GREENHOUSE_GLASS)
	box(gh, "GlassNorth", v(x0 + 0.6, 2, z1 - 0.5), v(x1, eaveY, z1 - 0.1), GREENHOUSE_GLASS)

	local posts = {
		Vector2.new(x0 + 0.3, z0 + 0.3),
		Vector2.new(x0 + 0.3, z1 - 0.3),
		Vector2.new(x0 + 0.3, -6),
		Vector2.new(x0 + 0.3, 0),
		Vector2.new(x0 + 0.3, 6),
		Vector2.new(ridgeX, z0 + 0.3),
		Vector2.new(ridgeX, z1 - 0.3),
	}
	for _, post in posts do
		box(gh, "Post", v(post.X - 0.3, 0.5, post.Y - 0.3), v(post.X + 0.3, eaveY, post.Y + 0.3), frame)
	end
	box(gh, "Eave", v(x0, eaveY - 0.3, z0), v(x0 + 0.8, eaveY + 0.3, z1), frame)
	box(gh, "WallTop", v(x0, eaveY - 0.3, z0), v(x1, eaveY + 0.3, z0 + 0.6), frame)
	box(gh, "WallTop", v(x0, eaveY - 0.3, z1 - 0.6), v(x1, eaveY + 0.3, z1), frame)
	box(gh, "RidgeBeam", v(ridgeX - 0.3, ridgeY - 0.2, z0), v(ridgeX + 0.3, ridgeY + 0.3, z1), frame)

	-- Pitched glass roof and its two triangular gable ends.
	local slopeLength = math.sqrt(halfSpan * halfSpan + rise * rise)
	local tilt = math.atan2(rise, halfSpan)
	local roofSize = Vector3.new(slopeLength, 0.3, z1 - z0)
	part(gh, "RoofWest", roofSize, CFrame.new(v(x0 + halfSpan / 2, eaveY + rise / 2, 0)) * CFrame.Angles(0, 0, tilt), GREENHOUSE_GLASS)
	part(gh, "RoofEast", roofSize, CFrame.new(v(x1 - halfSpan / 2, eaveY + rise / 2, 0)) * CFrame.Angles(0, 0, -tilt), GREENHOUSE_GLASS)
	for _, gz in { z0 + 0.15, z1 - 0.15 } do
		local westPos = v(x0 + halfSpan / 2, eaveY + rise / 2, gz)
		wedge(gh, "Gable", Vector3.new(0.3, rise, halfSpan), CFrame.lookAt(westPos, westPos - Vector3.xAxis), GREENHOUSE_GLASS)
		local eastPos = v(x1 - halfSpan / 2, eaveY + rise / 2, gz)
		wedge(gh, "Gable", Vector3.new(0.3, rise, halfSpan), CFrame.lookAt(eastPos, eastPos + Vector3.xAxis), GREENHOUSE_GLASS)
	end

	-- Three planter rows, each under a hanging grow light.
	local strips: { Part } = {}
	local stripLights: { PointLight } = {}
	local plants: { Part } = {}
	local function roofHeightAt(x: number): number
		return eaveY + rise * (1 - math.abs(x - ridgeX) / halfSpan)
	end
	for _, bx in { x0 + 3.2, ridgeX, x1 - 3.2 } do
		box(gh, "Planter", v(bx - 1.3, 0.5, -10), v(bx + 1.3, 1.6, 10), {
			color = Color3.fromRGB(236, 236, 240),
			material = Enum.Material.SmoothPlastic,
		})
		box(gh, "Soil", v(bx - 1.1, 1.6, -9.8), v(bx + 1.1, 1.8, 9.8), {
			color = Color3.fromRGB(92, 70, 52),
			material = Enum.Material.Ground,
		})
		for i = 0, 5 do
			local d = rng:NextNumber(1.5, 1.95)
			local pz = -8.4 + i * 3.36 + rng:NextNumber(-0.3, 0.3)
			table.insert(
				plants,
				ball(gh, "Plant", d, v(bx + rng:NextNumber(-0.2, 0.2), 1.8 + d * 0.32, pz), {
					color = PLANT_GREEN,
					material = Enum.Material.Grass,
					collide = false,
				})
			)
		end
		local stripY = 7.6
		local strip = box(gh, "GrowLight", v(bx - 0.35, stripY, -9.5), v(bx + 0.35, stripY + 0.3, 9.5), {
			color = GROW_PINK,
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
		table.insert(strips, strip)
		table.insert(stripLights, pointLight(strip, GROW_PINK, GROW_RANGE[3], GROW_BRIGHTNESS[3], false))
		local top = roofHeightAt(bx) - 0.1
		for _, hz in { -6, 6 } do
			box(gh, "Hanger", v(bx - 0.05, stripY + 0.3, hz - 0.05), v(bx + 0.05, top, hz + 0.05), {
				color = DARK_METAL,
				material = Enum.Material.Metal,
				collide = false,
				shadow = false,
			})
		end
	end

	return { model = gh, strips = strips, stripLights = stripLights, plants = plants, centre = v(ridgeX, 3, 0) }
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

local function angleGap(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	return math.min(d, 2 * math.pi - d)
end

-- Where the rover is on its loop at `angle`, facing along the loop.
local function roverPose(centre: Vector3, angle: number): CFrame
	local position = centre + Vector3.new(math.sin(angle), 0, math.cos(angle)) * ROVER_LOOP_RADIUS
	local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
	return CFrame.lookAt(position, position + tangent)
end

-- The rover's loop sits on the flat rim band, on the base's side of the crater, away from the ramp so
-- it never sits on the way down to the ice. Returns its angle around the crater.
local function roverSideAngle(rampAngle: number): number
	local sideA, sideB = math.pi - 0.6, math.pi + 0.6
	return if angleGap(sideA, rampAngle) >= angleGap(sideB, rampAngle) then sideA else sideB
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
	local ringR = 26
	local ringSegments = 20
	local stepAngle = math.rad(360 / ringSegments)
	local ringWidth = 2 * ringR * math.tan(stepAngle / 2) + 0.2
	for k = 1, ringSegments - 1 do -- k = 0 points along +Z where the tunnel leaves the mound
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

type ArrayVisual = { panel: Part, lines: { Part } }
-- Each array turns around its mast to follow the Sun as it circles the horizon.
type ArrayTrack = { panel: BasePart, pivot: Vector3, offset: CFrame, baseAngle: number, yaw: number }

local function buildArrays(base: Instance, data: any): ({ ArrayRef }, { ArrayVisual }, { ArrayTrack })
	local arraysFolder = folder(base, "SolarArrays")
	local sun = sunDirection()
	local sunH = flatUnit(sun, Vector3.new(0, 0, -1))
	local face = if sun.Y > 0 then sun else sunH
	face = Vector3.new(face.X, math.clamp(face.Y, 0, math.sin(math.rad(30))), face.Z).Unit
	local perp = Vector3.new(-sunH.Z, 0, sunH.X)
	local count: number = data.POWER.ARRAYS
	local spacing = if count > 1 then math.min(16, 44 / (count - 1)) else 0
	local centre = Vector3.new(RIDGE_CENTRE.X - 2, RIDGE_TOP_Y, RIDGE_CENTRE.Z)

	local refs: { ArrayRef } = {}
	local visuals: { ArrayVisual } = {}
	local tracks: { ArrayTrack } = {}
	local baseAngle = math.atan2(sunH.X, sunH.Z)
	for i = 1, count do
		local m = model(arraysFolder, "SolarArray" .. i)
		local footPos = centre + perp * ((i - (count + 1) / 2) * spacing)
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
		local lineStyle: Style = { color = Color3.fromRGB(190, 195, 205), material = Enum.Material.Metal, collide = false, shadow = false }
		local lineH = part(m, "GridLine", Vector3.new(12, 0.15, 0.1), panelCf * CFrame.new(0, 0, -0.22), lineStyle)
		local lineV = part(m, "GridLine", Vector3.new(0.15, 8, 0.1), panelCf * CFrame.new(0, 0, -0.22), lineStyle)
		local attachment = Instance.new("Attachment")
		attachment.Name = "PromptPoint"
		attachment.Position = Vector3.new(0, -3.6, -0.4)
		attachment.Parent = panel
		local prompt = makePrompt(attachment, "prompt.clean", "Clean panel", 1.5)
		-- The panel stays the anchored root; mast, frame and grid lines turn with it.
		weldTo(panel, { mast, frame, lineH, lineV })
		table.insert(refs, { model = m, panel = panel :: BasePart, prompt = prompt })
		table.insert(visuals, { panel = panel, lines = { lineH, lineV } })
		table.insert(tracks, {
			panel = panel :: BasePart,
			pivot = panelCentre,
			offset = CFrame.new(-panelCentre) * panelCf,
			baseAngle = baseAngle,
			yaw = 0,
		})
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
	local earth = earthPosition or defaultEarthPosition()
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
-- Stage 6: automatic ice drills, conveyor, ice silo, cargo robot, build pads and blueprints
------------------------------------------------------------------------------------------------

local DRILL_WARM = PALETTE.gold:Lerp(PALETTE.orange, 0.35) -- warm work lights on the drills
local ICE_LOAD = Color3.fromRGB(205, 236, 250)
local HIDDEN_FOLDER = "SBO_HiddenBuilds"

type Keepout6 = { x: number, z: number, r: number }

-- A point around the crater: angle (see dirFromAngle), distance from its centre, height.
local function craterPoint(angle: number, radius: number, y: number): Vector3
	return CRATER_CENTRE + dirFromAngle(angle) * radius + Vector3.new(0, y, 0)
end

-- Angle of the rim segment that hides the cheese niche (same rule as buildCrater: 36 segments).
local function nicheAngle(rampAngle: number): number
	local step = math.rad(10)
	return (math.floor((rampAngle + CHEESE_NICHE_OFFSET) / step + 0.5) % 36) * step
end

-- The drills stand on the base's side of the crater, clear of the ramp, the cheese niche and the
-- science rover's loop. Returns the angle of the middle drill.
local function chooseDrillAngle(rampAngle: number): number
	local rover = roverSideAngle(rampAngle)
	local niche = nicheAngle(rampAngle)
	local sign = if rover > math.pi then -1 else 1 -- try the side away from the rover first
	for _, offset in { 0, 0.55, -0.55, 0.9, -0.9, 1.25, -1.25 } do
		local angle = math.pi + offset * sign
		if angleGap(angle, rampAngle) >= 0.6 and angleGap(angle, niche) >= 0.6 and angleGap(angle, rover) >= 0.75 then
			return angle
		end
	end
	return math.pi + 1.25 * sign
end

-- Build pad spots: near each structure, beside (not on) the paths and doors.
local function padSpots(drillAngle: number): { [string]: Vector3 }
	return {
		solar = Vector3.new(RIDGE_CENTRE.X + 29, RIDGE_TOP_Y, RIDGE_CENTRE.Z + 11), -- ridge top, beside the ramp
		greenhouse = HABITAT_CENTRE + Vector3.new(-37, 0, 18), -- in front of the greenhouse module
		antenna = ANTENNA_BASE + Vector3.new(11, 0, -10), -- between the path and the tower
		shelter = SHELTER_CENTRE + Vector3.new(13, 0, 35), -- beside the tunnel mouth
		drill_1 = craterPoint(drillAngle - DRILL_SPREAD, DRILL_PAD_RADIUS, CRATER_RIM_Y), -- rim, above each drill
		drill_2 = craterPoint(drillAngle + 0.09, DRILL_PAD_RADIUS, CRATER_RIM_Y), -- (next to the rim belt)
		drill_3 = craterPoint(drillAngle + DRILL_SPREAD, DRILL_PAD_RADIUS, CRATER_RIM_Y),
		cargo_bot = SILO_CENTRE + Vector3.new(-14, 0, 2), -- beside the silo and the robot's dock
	}
end

-- The cargo robot's route from its dock by the silo to the conveyor's foot at the crater: behind the
-- habitat, past the greenhouse, out to the crater, then around it on flat ground (r = 140).
local function cargoRoutePoints(drillAngle: number): { Vector3 }
	local y = CARGO_RIDE_HEIGHT
	local points: { Vector3 } = {
		Vector3.new(CARGO_DOCK.X, y, CARGO_DOCK.Z),
		Vector3.new(-48, y, -35),
		Vector3.new(-50, y, 26),
	}
	local arcRadius = 140
	local steps = math.ceil(math.abs(drillAngle - math.pi) / 0.2)
	for k = 0, steps do
		local angle = if steps > 0 then math.pi + (drillAngle - math.pi) * k / steps else math.pi
		table.insert(points, craterPoint(angle, arcRadius, y))
	end
	local outward = dirFromAngle(drillAngle)
	local side = Vector3.new(-outward.Z, 0, outward.X)
	table.insert(points, craterPoint(drillAngle, CONVEYOR_FOOT_RADIUS + 4.5, y) + side * 3.5)
	return points
end

local function keepoutsAlong(points: { Vector3 }, radius: number, spacing: number, into: { Keepout6 })
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / spacing))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			table.insert(into, { x = p.X, z = p.Z, r = radius })
		end
	end
end

-- A path made of straight pieces, walked by distance.
type Polyline = { points: { Vector3 }, lengths: { number }, total: number }

local function polyline(points: { Vector3 }): Polyline
	local lengths: { number } = {}
	local total = 0
	for i = 1, #points - 1 do
		local length = (points[i + 1] - points[i]).Magnitude
		lengths[i] = length
		total += length
	end
	return { points = points, lengths = lengths, total = total }
end

-- Position and unit direction at `distance` along the path.
local function alongPolyline(line: Polyline, distance: number): (Vector3, Vector3)
	local d = math.clamp(distance, 0, line.total)
	for i, length in line.lengths do
		if d <= length or i == #line.lengths then
			local a, b = line.points[i], line.points[i + 1]
			local t = if length > 0 then math.clamp(d / length, 0, 1) else 0
			local dir = if length > 0 then (b - a) / length else Vector3.zAxis
			return a:Lerp(b, t), dir
		end
		d -= length
	end
	return line.points[1], Vector3.zAxis
end

type DrillBit = { root: BasePart, base: CFrame, level: number }
type DrillRefs = { model: Model, bits: { DrillBit } }

-- One automatic ice drill on the crater floor. Its lift belt carries the ice up the rim wall to
-- `beltEnd`. Level 2 adds a taller rig and a second light, level 3 a second bit and a power pack.
local function buildDrill(parent: Instance, index: number, angle: number, beltEnd: Vector3): DrillRefs
	local m = model(parent, "IceDrill" .. index)
	local floorPos = craterPoint(angle, DRILL_FLOOR_RADIUS, CRATER_FLOOR_Y)
	local cf = CFrame.lookAt(floorPos, floorPos + dirFromAngle(angle)) -- local -Z faces the rim wall
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local metal: Style = { color = METAL, material = Enum.Material.Metal }
	local dark: Style = { color = DARK_METAL, material = Enum.Material.Metal }
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	local trim: Style = { color = HULL_TRIM, material = Enum.Material.SmoothPlastic, collide = false }
	local lampStyle: Style = { color = DRILL_WARM, material = Enum.Material.Neon, collide = false, shadow = false }
	local bitStyle: Style = { color = METAL, material = Enum.Material.Metal, collide = false, shadow = false }
	local fluteStyle: Style = { color = DARK_METAL, material = Enum.Material.Metal, collide = false, shadow = false }

	part(m, "Skid", Vector3.new(7, 1, 7), at(0, 0.5, 0), dark)
	part(m, "Deck", Vector3.new(6.2, 0.3, 6.2), at(0, 1.15, 0), { color = METAL, material = Enum.Material.DiamondPlate })
	for _, x in { -2.4, 2.4 } do
		part(m, "Post", Vector3.new(0.7, 9, 0.7), at(x, 5.8, 0), metal)
	end
	part(m, "Beam", Vector3.new(5.5, 0.7, 0.9), at(0, 10.65, 0), metal)
	part(m, "Motor", Vector3.new(2.2, 2, 2.2), at(0, 9.2, 0), hull)
	part(m, "MotorTrim", Vector3.new(2.3, 0.35, 2.3), at(0, 8.35, 0), trim)
	local lamp = part(m, "WorkLamp", Vector3.new(1.2, 0.5, 0.8), at(0, 11.25, 0.6), lampStyle)
	pointLight(lamp, DRILL_WARM, 26, 2, false)
	-- Beacon mast: the drill sits on the dark crater floor (ice hides in shadow), so playtesters could
	-- not see it from the rim. A thin mast with a warm light pokes up above the rim.
	local mastTop = 40 -- studs above the crater floor; the rim is about 32 above it
	vcylinder(m, "BeaconMast", mastTop - 11, 0.35, at(2.4, 11 + (mastTop - 11) / 2, 0).Position, metal)
	local beacon = ball(m, "Beacon", 1.1, at(2.4, mastTop + 0.4, 0).Position, lampStyle)
	pointLight(beacon, DRILL_WARM, 16, 1.5, false)
	part(m, "Hopper", Vector3.new(2.6, 2.2, 2.6), at(0, 2.4, -3.2), dark)
	part(m, "HopperIce", Vector3.new(2.2, 0.3, 2.2), at(0, 3.55, -3.2), {
		color = ICE_GLOW,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	part(m, "Chute", Vector3.new(0.8, 0.25, 2.4), at(0, 3.1, -1.6) * CFrame.Angles(math.rad(-15), 0, 0), {
		color = DARK_METAL,
		material = Enum.Material.Metal,
		collide = false,
	})

	-- Drill bits: an anchored shaft with two welded flutes, spun around the world Y axis.
	local bits: { DrillBit } = {}
	local function addBit(name: string, z: number, length: number, diameter: number, level: number)
		local centre = at(0, 0.3 + length / 2, z).Position
		local bitCf = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
		local root = cylinder(m, name, length, diameter, bitCf, bitStyle)
		local fluteA = part(m, name .. "Flute", Vector3.new(0.2, length - 1.6, diameter + 0.7), CFrame.new(centre), fluteStyle)
		local fluteB = part(m, name .. "Flute", Vector3.new(diameter + 0.7, length - 1.6, 0.2), CFrame.new(centre), fluteStyle)
		if level > 1 then
			upgrade(root, level)
			upgrade(fluteA, level)
			upgrade(fluteB, level)
		end
		weldTo(root, { fluteA, fluteB })
		table.insert(bits, { root = root :: BasePart, base = bitCf, level = level })
	end
	addBit("Bit", 0, 8.4, 0.9, 1)

	-- Level 2: a taller rig with a second work light.
	for _, x in { -2.4, 2.4 } do
		upgrade(part(m, "PostTop", Vector3.new(0.7, 4, 0.7), at(x, 13, 0), metal), 2)
	end
	upgrade(part(m, "BeamTop", Vector3.new(5.5, 0.7, 0.9), at(0, 15.35, 0), metal), 2)
	local lampTop = part(m, "WorkLampTop", Vector3.new(1.2, 0.5, 0.8), at(0, 15.95, 0.6), lampStyle)
	pointLight(lampTop, DRILL_WARM, 18, 1, false)
	upgrade(lampTop, 2)

	-- Level 3: a second, smaller bit with its own motor, and a power pack.
	addBit("Bit2", 2.3, 6, 0.7, 3)
	upgrade(part(m, "Motor2", Vector3.new(1.6, 1.4, 1.6), at(0, 7.4, 2.3), hull), 3)
	upgrade(part(m, "PowerPack", Vector3.new(1.4, 2.6, 2.4), at(3.6, 2.6, 0), dark), 3)
	upgrade(part(m, "PowerStripe", Vector3.new(1.5, 0.35, 2.5), at(3.6, 3.4, 0), trim), 3)

	-- Lift belt up the rim wall, with one strut down to the floor.
	local beltStart = at(0, 3.75, -3.2).Position
	belt(m, "LiftBelt", beltStart, beltEnd, 1.6, 0.35, { color = DARK_METAL, material = Enum.Material.Metal, collide = false })
	local mid = beltStart:Lerp(beltEnd, 0.4)
	local strutHeight = mid.Y - CRATER_FLOOR_Y
	vcylinder(m, "LiftStrut", strutHeight, 0.5, Vector3.new(mid.X, CRATER_FLOOR_Y + strutHeight / 2, mid.Z), metal)

	return { model = m, bits = bits }
end

type ConveyorRefs = { model: Model, cubes: { BasePart }, cubeLine: Polyline, pipeEnd: Vector3 }

-- The rim hopper, the open belt over the rim and down its outer slope, and the half-buried ice pipe
-- from there to the silo behind the habitat (it runs under the habitat floor).
local function buildConveyor(base: Instance, angle: number): ConveyorRefs
	local m = model(base, "IceConveyor")
	local outward = dirFromAngle(angle)
	local dark: Style = { color = DARK_METAL, material = Enum.Material.Metal }
	local beltStyle: Style = { color = DARK_METAL, material = Enum.Material.Metal, collide = false }
	local stripe: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }

	local hopperPos = craterPoint(angle, HOPPER_RADIUS, CRATER_RIM_Y + 1.3)
	part(m, "RimHopper", Vector3.new(3.4, 2.6, 3.4), CFrame.lookAt(hopperPos, hopperPos + outward), dark)
	local trimPos = hopperPos + Vector3.new(0, 0.95, 0)
	part(m, "RimHopperTrim", Vector3.new(3.5, 0.35, 3.5), CFrame.lookAt(trimPos, trimPos + outward), stripe)

	local a = craterPoint(angle, HOPPER_RADIUS + 1.7, CRATER_RIM_Y + 0.2)
	local b = craterPoint(angle, 100, CRATER_RIM_Y + 0.2)
	local c = craterPoint(angle, 116.5, 0.2)
	local up = Vector3.new(0, 0.22, 0)
	belt(m, "RimBelt", a, b, 2, 0.4, beltStyle)
	belt(m, "SlopeBelt", b, c, 2, 0.4, beltStyle)
	belt(m, "BeltStripe", a + up, b + up, 0.3, 0.05, stripe)
	belt(m, "BeltStripe", b + up, c + up, 0.3, 0.05, stripe)

	local foot = craterPoint(angle, CONVEYOR_FOOT_RADIUS, 0)
	local inletPos = foot + Vector3.new(0, 0.7, 0)
	part(m, "PipeInlet", Vector3.new(1.8, 1.4, 1.8), CFrame.lookAt(inletPos, inletPos + outward), dark)
	local towardFoot = flatUnit(foot - SILO_CENTRE, Vector3.zAxis)
	local pipeEnd = SILO_CENTRE + towardFoot * (SILO_GLASS_DIAMETER / 2 + 1.4)
	pipe(m, "IcePipe", Vector3.new(foot.X, 0, foot.Z), Vector3.new(pipeEnd.X, 0, pipeEnd.Z), 0.9, {
		color = METAL,
		material = Enum.Material.Metal,
		collide = false,
		shadow = false,
	})

	-- Ice cubes riding the open belt (a small pool, moved only while someone is near).
	local lift = Vector3.new(0, 0.65, 0)
	local cubeLine = polyline({ a + lift, b + lift, c + lift })
	local cubes: { BasePart } = {}
	for k = 1, ICE_CUBE_COUNT do
		local position, dir = alongPolyline(cubeLine, (k - 1) * cubeLine.total / ICE_CUBE_COUNT)
		table.insert(
			cubes,
			part(m, "IceCube", Vector3.new(0.9, 0.9, 0.9), CFrame.lookAt(position, position + dir), {
				color = ICE_LOAD,
				material = Enum.Material.Ice,
				collide = false,
				shadow = false,
			})
		)
	end
	return { model = m, cubes = cubes, cubeLine = cubeLine, pipeEnd = pipeEnd }
end

type SiloRefs = {
	model: Model,
	fill: Part,
	light: PointLight,
	ring: Part,
	prompt: ProximityPrompt,
	bottomY: number,
	height: number,
	diameter: number,
}

-- The ice silo behind the habitat: a glass column that shows how much ice the drills have stored,
-- a lift pipe from the conveyor, and a pipe through the back wall into the water tank.
local function buildSilo(base: Instance, pipeEnd: Vector3): SiloRefs
	local m = model(base, "IceSilo")
	local c = SILO_CENTRE
	local metal: Style = { color = METAL, material = Enum.Material.Metal }
	local glassBottom = 1
	local top = glassBottom + SILO_GLASS_HEIGHT
	local siloBase = vcylinder(m, "SiloBase", 1, SILO_GLASS_DIAMETER + 1.6, c + Vector3.new(0, 0.5, 0), {
		color = DARK_METAL,
		material = Enum.Material.Metal,
	})
	vcylinder(m, "SiloGlass", SILO_GLASS_HEIGHT, SILO_GLASS_DIAMETER, c + Vector3.new(0, glassBottom + SILO_GLASS_HEIGHT / 2, 0), {
		color = Color3.fromRGB(210, 230, 240),
		material = Enum.Material.Glass,
		transparency = 0.65,
		shadow = false,
	})
	local fillHeight = SILO_GLASS_HEIGHT - 0.3
	local fillDiameter = SILO_GLASS_DIAMETER - 0.5
	local fill = vcylinder(m, "SiloFill", fillHeight, fillDiameter, c + Vector3.new(0, glassBottom + fillHeight / 2, 0), {
		color = ICE_LOAD,
		material = Enum.Material.Ice,
		transparency = 1,
		collide = false,
		shadow = false,
	})
	fill:SetAttribute(NO_RISE_ATTRIBUTE, true) -- setSilo tweens it
	local light = pointLight(fill, ICE_GLOW, 10, 0.8, false)
	light.Enabled = false
	for _, y in { 4.7, 8.4 } do
		vcylinder(m, "SiloBand", 0.4, SILO_GLASS_DIAMETER + 0.3, c + Vector3.new(0, y, 0), metal)
	end
	local ring = vcylinder(m, "SiloRing", 0.35, SILO_GLASS_DIAMETER + 0.5, c + Vector3.new(0, top - 0.4, 0), {
		color = ACCENT_SYSTEM,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	vcylinder(m, "SiloCap", 0.8, SILO_GLASS_DIAMETER + 0.6, c + Vector3.new(0, top + 0.4, 0), metal)
	vcylinder(m, "SiloHatch", 0.6, 2.4, c + Vector3.new(0, top + 1.1, 0), { color = WHITE_HULL, material = Enum.Material.SmoothPlastic })

	-- Lift pipe from the ice pipe up the silo's side and over into the top.
	local side = flatUnit(pipeEnd - c, Vector3.zAxis)
	local liftAt = c + side * (SILO_GLASS_DIAMETER / 2 + 0.9)
	vcylinder(m, "IceLift", top + 1.4, 1.1, Vector3.new(liftAt.X, (top + 1.4) / 2, liftAt.Z), metal)
	pipe(m, "IceLiftTop", liftAt + Vector3.new(0, top + 0.9, 0), c + Vector3.new(0, top + 0.9, 0), 0.8, metal)

	-- Melted ice goes on to the water tank inside (habitat corner), through the back wall up high.
	local tankTop = HABITAT_CENTRE + Vector3.new(25, 9.1, -15)
	local pipeY = 16.6
	local pipeStyle: Style = { color = METAL, material = Enum.Material.Metal, collide = false, shadow = false }
	local capTop = top + 0.8
	vcylinder(m, "TankPipe", pipeY - capTop, 0.7, Vector3.new(c.X, (pipeY + capTop) / 2, c.Z), pipeStyle)
	pipe(m, "TankPipe", Vector3.new(c.X, pipeY, c.Z), Vector3.new(c.X, pipeY, tankTop.Z), 0.7, pipeStyle)
	pipe(m, "TankPipe", Vector3.new(c.X, pipeY, tankTop.Z), Vector3.new(tankTop.X, pipeY, tankTop.Z), 0.7, pipeStyle)
	vcylinder(m, "TankPipe", pipeY - tankTop.Y, 0.7, Vector3.new(tankTop.X, (pipeY + tankTop.Y) / 2, tankTop.Z), pipeStyle)
	for _, corner in { Vector3.new(c.X, pipeY, c.Z), Vector3.new(c.X, pipeY, tankTop.Z), Vector3.new(tankTop.X, pipeY, tankTop.Z) } do
		ball(m, "TankPipeJoint", 0.85, corner, pipeStyle)
	end

	-- Ice sign facing away from the habitat (where players walk up to it).
	local sign = part(m, "SiloSign", Vector3.new(2.4, 2.4, 0.2), CFrame.new(c + Vector3.new(0, 6.5, -(SILO_GLASS_DIAMETER / 2 + 0.2))), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SiloIcon"
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.CanvasSize = Vector2.new(64, 64)
	signGui.Parent = sign
	local signIcon = Instance.new("ImageLabel")
	signIcon.BackgroundTransparency = 1
	signIcon.Size = UDim2.fromScale(0.8, 0.8)
	signIcon.Position = UDim2.fromScale(0.1, 0.1)
	signIcon.Image = Icons.ice
	signIcon.ImageColor3 = ACCENT_SYSTEM
	signIcon.Parent = signGui

	-- Claim prompt (BaseService decides when it is usable).
	local promptPoint = Instance.new("Attachment")
	promptPoint.Name = "PromptPoint"
	promptPoint.Position = Vector3.new(2.5, 0, 0) -- the base's X axis points up
	promptPoint.Parent = siloBase
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SiloPrompt"
	prompt.ActionText = "Collect ice"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("TextKey", "prompt.claim_silo")
	prompt.Parent = promptPoint

	return {
		model = m,
		fill = fill,
		light = light,
		ring = ring,
		prompt = prompt,
		bottomY = c.Y + glassBottom,
		height = fillHeight,
		diameter = fillDiameter,
	}
end

type CargoRefs = { model: Model, root: Part, load: Part, route: Polyline }

-- The cargo robot: a small wheeled cart with an ice bin, parked at its dock by the silo.
local function buildCargoBot(base: Instance, route: Polyline): CargoRefs
	local m = model(base, "CargoRobot")
	local start = route.points[1]
	local cf = CFrame.lookAt(start, start + flatUnit(route.points[2] - start, -Vector3.xAxis))
	local function style(color: Color3, material: Enum.Material): Style
		return { color = color, material = material, collide = false }
	end
	local glow: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }
	local root = part(m, "Body", Vector3.new(3, 1.2, 4.2), cf, style(WHITE_HULL, Enum.Material.SmoothPlastic))
	local attached: { BasePart } = {}
	local function add(p: BasePart)
		table.insert(attached, p)
	end
	add(part(m, "Bin", Vector3.new(2.8, 1, 2.8), cf * CFrame.new(0, 1.05, 0.5), style(DARK_METAL, Enum.Material.Metal)))
	local load = part(m, "IceLoad", Vector3.new(2.3, 0.45, 2.3), cf * CFrame.new(0, 1.65, 0.5), {
		color = ICE_LOAD,
		material = Enum.Material.Ice,
		transparency = 1,
		collide = false,
		shadow = false,
	})
	add(load)
	local wheelStyle = style(Color3.fromRGB(44, 46, 52), Enum.Material.Rubber)
	for _, wx in { -1.7, 1.7 } do
		for _, wz in { -1.4, 1.4 } do
			add(cylinder(m, "Wheel", 0.5, 1.2, cf * CFrame.new(wx, -0.7, wz), wheelStyle))
		end
	end
	add(part(m, "Trim", Vector3.new(3.05, 0.25, 4.25), cf * CFrame.new(0, 0.2, 0), style(HULL_TRIM, Enum.Material.SmoothPlastic)))
	for _, ex in { -0.7, 0.7 } do
		add(part(m, "Eye", Vector3.new(0.5, 0.35, 0.1), cf * CFrame.new(ex, 0.25, -2.12), glow))
	end
	add(part(m, "Mast", Vector3.new(0.2, 1.2, 0.2), cf * CFrame.new(1.1, 1.2, -1.6), style(METAL, Enum.Material.Metal)))
	add(ball(m, "Beacon", 0.45, (cf * CFrame.new(1.1, 1.9, -1.6)).Position, glow))
	weldTo(root, attached)
	return { model = m, root = root, load = load, route = route }
end

type PadRefs = { pad: Part, prompt: ProximityPrompt }

-- A round glowing build pad with the structure's icon and a hold prompt. BaseService sets the
-- prompt text and the pad attributes SBO_Level, SBO_Cost (nil at the top level) and SBO_Locked;
-- the pad dims while locked and shrinks once the structure is at its top level.
local function buildPad(parent: Instance, id: string, position: Vector3, icon: string): PadRefs
	local pad = vcylinder(parent, id, PAD_HEIGHT, PAD_DIAMETER, position + Vector3.new(0, PAD_HEIGHT / 2, 0), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
		shadow = false,
	})
	pad:SetAttribute("BuildId", id)
	local ring = vcylinder(pad, "Ring", PAD_HEIGHT * 0.8, PAD_RING_DIAMETER, position + Vector3.new(0, PAD_HEIGHT * 0.4, 0), {
		color = ACCENT_SYSTEM,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PadIcon"
	gui.Face = Enum.NormalId.Right -- the pad's X axis points up
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(100, 100)
	gui.Parent = pad
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(0.6, 0.6)
	image.Position = UDim2.fromScale(0.2, 0.2)
	image.Image = icon
	image.ImageColor3 = ACCENT_SYSTEM
	image.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuildPrompt"
	prompt.ActionText = "Build"
	prompt.ObjectText = ""
	prompt.HoldDuration = BUILD_PROMPT_HOLD
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("TextKey", "prompt.build")
	prompt:SetAttribute("ObjectKey", `build.{id}.name`)
	prompt.Parent = pad

	local function refresh()
		local level = pad:GetAttribute("SBO_Level")
		local cost = pad:GetAttribute("SBO_Cost")
		local locked = pad:GetAttribute("SBO_Locked") == true
		local maxed = cost == nil and type(level) == "number" and level > 0
		local diameter = if maxed then PAD_MAXED_DIAMETER else PAD_DIAMETER
		pad.Size = Vector3.new(PAD_HEIGHT, diameter, diameter)
		pad.Transparency = if maxed then 0.7 else 0
		ring.Transparency = if maxed then 1 else 0
		gui.Enabled = not maxed
		ring.Material = if locked then Enum.Material.SmoothPlastic else Enum.Material.Neon
		ring.Color = if locked then ACCENT_SYSTEM:Lerp(PALETTE.night, 0.6) else ACCENT_SYSTEM
		image.ImageColor3 = if locked then PALETTE.creamDim else ACCENT_SYSTEM
		image.ImageTransparency = if locked then 0.55 else 0
	end
	for _, name in { "SBO_Level", "SBO_Cost", "SBO_Locked" } do
		pad:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	return { pad = pad, prompt = prompt }
end

-- Blueprint of a structure: the same shape in see-through cyan force field. Nothing in it works:
-- no collisions, lights, prompts, GUIs, effects or joints; tiny parts and upgrade parts are left out.
local function makeHologram(source: Instance, parent: Instance): Instance
	local copy = source:Clone()
	copy.Name = source.Name .. "Blueprint"
	for _, item in copy:GetDescendants() do
		if item.Parent == nil then
			continue -- inside something already removed
		end
		if item:IsA("BasePart") then
			local upgradeLevel = item:GetAttribute(UPGRADE_ATTRIBUTE)
			local isUpgrade = type(upgradeLevel) == "number" and upgradeLevel > 1
			local invisible = upgradeLevel == nil and item.Transparency >= 0.95
			local tiny = math.max(item.Size.X, item.Size.Y, item.Size.Z) < HOLOGRAM_MIN_PART
			if isUpgrade or invisible or tiny then
				item:Destroy()
			else
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.CastShadow = false
				item.Material = Enum.Material.ForceField
				item.Color = ACCENT_SYSTEM
				item.Transparency = HOLOGRAM_TRANSPARENCY
				item.Reflectance = 0
			end
		elseif
			item:IsA("Light")
			or item:IsA("ProximityPrompt")
			or item:IsA("ParticleEmitter")
			or item:IsA("Beam")
			or item:IsA("SurfaceGui")
			or item:IsA("BillboardGui")
			or item:IsA("Decal")
			or item:IsA("JointInstance")
			or item:IsA("WeldConstraint")
			or item:IsA("Constraint")
			or item:IsA("LuaSourceContainer")
		then
			item:Destroy()
		end
	end
	copy.Parent = parent
	return copy
end

-- Anchored parts in these instances (and their descendants) that the rise-in animation may move.
local function risableParts(roots: { Instance }): { BasePart }
	local list: { BasePart } = {}
	local function consider(item: Instance)
		if item:IsA("BasePart") and item.Anchored and item:GetAttribute(NO_RISE_ATTRIBUTE) ~= true and not risingParts[item] then
			table.insert(list, item)
		end
	end
	for _, root in roots do
		consider(root)
		for _, item in root:GetDescendants() do
			consider(item)
		end
	end
	return list
end

-- Lifts parts up out of the ground into place over RISE_SECONDS (CFrames sent at most every
-- PULSE_UPDATE_SECONDS). onStep(offsetY) moves anything that has its own animation.
local function riseIn(parts: { BasePart }, drop: number, onStep: ((offset: number) -> ())?, onDone: (() -> ())?)
	local finals: { CFrame } = table.create(#parts)
	for i, p in parts do
		finals[i] = p.CFrame
		risingParts[p] = true
		p.CFrame = finals[i] - Vector3.new(0, drop, 0)
	end
	if onStep then
		onStep(-drop)
	end
	local elapsed = 0
	local sinceSend = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		sinceSend += dt
		local alpha = math.clamp(elapsed / RISE_SECONDS, 0, 1)
		if sinceSend < PULSE_UPDATE_SECONDS and alpha < 1 then
			return
		end
		sinceSend = 0
		local eased = 1 - (1 - alpha) ^ 3
		local offset = -drop * (1 - eased)
		for i, p in parts do
			p.CFrame = finals[i] + Vector3.new(0, offset, 0)
		end
		if onStep then
			onStep(offset)
		end
		if alpha >= 1 then
			if connection then
				connection:Disconnect()
			end
			for _, p in parts do
				risingParts[p] = nil
			end
			if onDone then
				onDone()
			end
		end
	end)
end

-- Dust kicked up where something is built. With no air on the Moon, the dust flies out in arcs and
-- falls straight back down instead of hanging in a cloud.
local function dustPuff(parent: Instance, position: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "BuildDust"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(4, 0.2, 4)
	holder.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(REGOLITH_LIGHT)
	emitter.Size = NumberSequence.new(0.8, 2)
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.3)
	emitter.Speed = NumberRange.new(7, 12)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Drag = 0
	emitter.Rate = 70
	emitter.Parent = holder
	holder.Parent = parent
	task.delay(0.35, function()
		emitter.Enabled = false
	end)
	task.delay(2.5, function()
		holder:Destroy()
	end)
end

local function hiddenStore(): Folder
	local old = ServerStorage:FindFirstChild(HIDDEN_FOLDER)
	if old then
		old:Destroy()
	end
	local store = Instance.new("Folder")
	store.Name = HIDDEN_FOLDER
	store.Parent = ServerStorage
	return store
end

------------------------------------------------------------------------------------------------
-- Secrets: four hidden collectibles, the sealed observatory and the team flag
------------------------------------------------------------------------------------------------

-- Every secret place is closed by walls at least 4 studs thick, so the default camera cannot slide
-- into it and nobody sees the item from the base, the paths or the crater floor. Entrances carry no
-- marker (players took the old magenta pebbles for a bug); magenta still means "secret" on the items.

-- Cuts a rectangular hole (in X and Z) out of the ground tiles, keeping each tile's colour.
local function carveGround(ground: Instance, x0: number, x1: number, z0: number, z1: number)
	for _, child in ground:GetChildren() do
		if child:IsA("BasePart") then
			local half = child.Size / 2
			local c = child.CFrame.Position
			local tx0, tx1, tz0, tz1 = c.X - half.X, c.X + half.X, c.Z - half.Z, c.Z + half.Z
			local ix0, ix1 = math.max(tx0, x0), math.min(tx1, x1)
			local iz0, iz1 = math.max(tz0, z0), math.min(tz1, z1)
			if ix0 < ix1 and iz0 < iz1 then
				local y0, y1 = c.Y - half.Y, c.Y + half.Y
				local style: Style = { color = child.Color, material = child.Material }
				local name = child.Name
				local function strip(ax: number, bx: number, az: number, bz: number)
					if bx - ax > 0.01 and bz - az > 0.01 then
						box(ground, name, Vector3.new(ax, y0, az), Vector3.new(bx, y1, bz), style)
					end
				end
				strip(tx0, tx1, tz0, iz0)
				strip(tx0, tx1, iz1, tz1)
				strip(tx0, ix0, iz0, iz1)
				strip(ix1, tx1, iz0, iz1)
				child:Destroy()
			end
		end
	end
end

-- mars_potato: a maintenance crawl space under the habitat. A vent hatch on the shelter side (east)
-- opens onto a shaft; the room runs west under the habitat floor, out of sight of the hatch.
local function buildCrawlSpace(base: Instance, ground: Instance): CFrame
	local crawl = model(base, "CrawlSpace")
	local o = HABITAT_CENTRE
	local function v(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	carveGround(ground, o.X + 8, o.X + 42, o.Z - 24, o.Z - 8)

	-- Room: x 12..38, z -20..-12, floor at -12, ceiling at -4 (4 thick, then the habitat floor).
	local fill: Style = { color = Color3.fromRGB(128, 124, 116), material = Enum.Material.Concrete }
	box(crawl, "Fill", v(8, -16, -24), v(42, 0, -20), fill)
	box(crawl, "Fill", v(8, -16, -12), v(42, 0, -8), fill)
	box(crawl, "Fill", v(8, -16, -20), v(12, 0, -12), fill)
	box(crawl, "Fill", v(38, -16, -20), v(42, 0, -12), fill)
	box(crawl, "CrawlFloor", v(12, -16, -20), v(38, -12, -12), fill)
	box(crawl, "CrawlCeiling", v(12, -4, -20), v(30, 0, -12), fill)

	-- Vent housing against the habitat's east wall. Its roof stays below the window band.
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	box(crawl, "VentHousing", v(30, 0, -12), v(42, 11, -8), hull)
	box(crawl, "VentHousing", v(30, 0, -24), v(42, 11, -20), hull)
	box(crawl, "VentHousing", v(30, 7, -20), v(38, 11, -12), hull)
	box(crawl, "VentHousing", v(38, 0, -20), v(42, 11, -19), hull)
	box(crawl, "VentHousing", v(38, 0, -13), v(42, 11, -12), hull)
	box(crawl, "VentHousing", v(38, 7, -19), v(42, 11, -13), hull)
	-- The hatch flap hangs open above the 6 x 7 opening.
	part(
		crawl,
		"VentHatch",
		Vector3.new(0.3, 5, 6),
		CFrame.new(v(42.2, 7, -16)) * CFrame.Angles(0, 0, math.rad(70)) * CFrame.new(0, -2.5, 0),
		{ color = DARK_METAL, material = Enum.Material.DiamondPlate, collide = false }
	)

	-- Inside: a crate to climb back out (two 6-stud hops), a pipe and a dim cyan service lamp.
	box(crawl, "Crate", v(33, -12, -20), v(38, -6, -15), { color = DARK_METAL, material = Enum.Material.Metal })
	box(crawl, "CrateStripe", v(32.9, -7, -20), v(38, -6.6, -14.9), {
		color = ACCENT_SYSTEM,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	cylinder(crawl, "CrawlPipe", 18, 0.9, CFrame.new(v(21, -5, -13)), {
		color = METAL,
		material = Enum.Material.Metal,
		collide = false,
	})
	local lamp = box(crawl, "ServiceLamp", v(37.6, -3.5, -17), v(38, -2.7, -15), {
		color = ACCENT_SYSTEM,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	pointLight(lamp, ACCENT_SYSTEM, 10, 0.5, true)

	return CFrame.new(v(16, -12 + COLLECTIBLE_FLOAT, -16))
end

-- mini_earth: a rock spire behind the antenna. A chain of ledges on its far side leads up to a
-- niche at height 24; the niche faces away from the base, the paths and the crater.
local function buildLookoutRock(base: Instance): CFrame
	local rockModel = model(base, "LookoutRock")
	local rng = Random.new(1961)
	local away = flatUnit(ANTENNA_BASE - HABITAT_CENTRE, Vector3.new(0, 0, 1))
	local centre = ANTENNA_BASE + away * LOOKOUT_DISTANCE
	local facing = dirFromAngle(math.atan2(away.X, away.Z) + LOOKOUT_YAW)
	local cf = CFrame.lookAt(centre, centre + facing) -- local -Z (the niche side) faces away from the base
	local function piece(name: string, a: Vector3, b: Vector3, material: Enum.Material)
		local minV = a:Min(b)
		local maxV = a:Max(b)
		part(rockModel, name, maxV - minV, cf * CFrame.new((minV + maxV) / 2), {
			color = regolith(rng, 118, 6),
			material = material,
		})
	end
	local slate = Enum.Material.Slate
	local rock = Enum.Material.Rock
	-- Spire 24 wide, 36 tall, 14 deep. Niche: 6 wide, 7 tall, 6 deep; walls 4 to 14 thick, roof 5.
	piece("Spire", Vector3.new(-12, 0, -7), Vector3.new(12, 24, 7), slate)
	piece("Spire", Vector3.new(-12, 31, -7), Vector3.new(12, 36, 7), slate)
	piece("Spire", Vector3.new(-12, 24, -7), Vector3.new(-8, 31, 7), slate)
	piece("Spire", Vector3.new(-2, 24, -7), Vector3.new(12, 31, 7), slate)
	piece("Spire", Vector3.new(-8, 24, -1), Vector3.new(-2, 31, 7), slate)
	-- Ledges 6 studs apart, an easy hop each in Moon gravity. None hangs over another.
	piece("Ledge", Vector3.new(8, 0, -11), Vector3.new(12, 6, -7), rock)
	piece("Ledge", Vector3.new(8, 9, -15), Vector3.new(12, 12, -11), rock)
	piece("Ledge", Vector3.new(3, 15, -15), Vector3.new(7, 18, -11), rock)
	piece("Ledge", Vector3.new(-12, 21, -11), Vector3.new(2, 24, -7), rock)
	-- Loose boulders so it reads as a rock, not a box.
	local loose: Style = { color = regolith(rng, 108, 8), material = rock }
	part(rockModel, "Boulder", Vector3.new(7, 5, 6), cf * CFrame.new(-13, 2, 3) * CFrame.Angles(0.2, 0.5, -0.1), loose)
	part(rockModel, "Boulder", Vector3.new(6, 4, 7), cf * CFrame.new(5, 37.5, 2) * CFrame.Angles(0.1, 0.8, 0.15), loose)
	part(rockModel, "Boulder", Vector3.new(5, 4, 5), cf * CFrame.new(13, 1.5, 4) * CFrame.Angles(-0.15, 1.1, 0.1), loose)

	return cf * CFrame.new(-5, 24 + COLLECTIBLE_FLOAT, -4)
end

-- laika: a small lava tube (LRO has imaged pits that open into lunar lava tubes). A narrow crack in
-- the hill's west cliff, hidden behind boulders, opens into a dark chamber. The dog sits in a
-- corner that cannot be seen through the crack.
local function buildLavaTube(base: Instance): CFrame
	local hill = model(base, "LavaTubeHill")
	local rng = Random.new(2009)
	local lo, hi = LAVA_TUBE_MIN, LAVA_TUBE_MAX
	local function rockStyle(): Style
		return { color = regolith(rng, 114, 5), material = Enum.Material.Slate }
	end
	local function piece(a: Vector3, b: Vector3)
		box(hill, "Rock", a, b, rockStyle())
	end
	-- Crack: 4 wide, 9 tall, 12 deep. Chamber: 20 x 20, 11 tall. Walls 9 to 21 thick, roof 13.
	local crackZ0, crackZ1, crackTop = -62, -58, 9
	local crackX1 = lo.X + 12
	local roomX1 = crackX1 + 20
	local roomZ0, roomZ1, roomTop = -76, -56, 11
	piece(Vector3.new(lo.X, roomTop, lo.Z), Vector3.new(hi.X, hi.Y, hi.Z))
	piece(Vector3.new(lo.X, crackTop, crackZ0), Vector3.new(crackX1, roomTop, crackZ1))
	piece(Vector3.new(roomX1, 0, lo.Z), Vector3.new(hi.X, roomTop, hi.Z))
	piece(Vector3.new(lo.X, 0, lo.Z), Vector3.new(roomX1, roomTop, roomZ0))
	piece(Vector3.new(lo.X, 0, roomZ1), Vector3.new(roomX1, roomTop, hi.Z))
	piece(Vector3.new(lo.X, 0, roomZ0), Vector3.new(crackX1, roomTop, crackZ0))
	piece(Vector3.new(lo.X, 0, crackZ1), Vector3.new(crackX1, roomTop, roomZ1))

	-- Slopes on three sides; the west side stays a cliff.
	local h = hi.Y
	local cx, cz = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
	local function slope(centre: Vector3, look: Vector3, size: Vector3)
		wedge(hill, "Slope", size, CFrame.lookAt(centre, centre + look), rockStyle())
	end
	slope(Vector3.new(cx, h / 2, hi.Z + 10), Vector3.zAxis, Vector3.new(hi.X - lo.X, h, 20))
	slope(Vector3.new(cx, h / 2, lo.Z - 10), -Vector3.zAxis, Vector3.new(hi.X - lo.X, h, 20))
	slope(Vector3.new(hi.X + 10, h / 2, cz), Vector3.xAxis, Vector3.new(hi.Z - lo.Z, h, 20))

	-- Boulders in front of the crack, with a 4.5-stud gap behind them to slip through.
	local loose: Style = { color = regolith(rng, 104, 8), material = Enum.Material.Rock }
	local crackMid = (crackZ0 + crackZ1) / 2
	part(hill, "Boulder", Vector3.new(5, 8, 11), CFrame.new(lo.X - 7, 4, crackMid), loose)
	part(hill, "Boulder", Vector3.new(4, 3, 5), CFrame.new(lo.X - 7.5, 9.2, crackMid + 1.5) * CFrame.Angles(0.1, 0.5, 0.2), loose)
	part(hill, "Boulder", Vector3.new(6, 5, 6), CFrame.new(lo.X - 9, 2.2, crackMid - 11) * CFrame.Angles(0.2, 0.9, -0.1), loose)

	return CFrame.new(roomX1 - 4, COLLECTIBLE_FLOAT, roomZ0 + 5)
end

type ObservatoryRefs = { model: Model, door: Part }

-- The observatory: a small sealed dome on a far hill. Its door only opens (on the client) for a
-- player who found all four secrets. Inside, a telescope points at Mars and a sign shows the teaser.
local function buildObservatory(base: Instance): ObservatoryRefs
	local obs = model(base, "Observatory")
	-- Always streamed in, so a client can open the door as soon as it joins.
	obs.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local rng = Random.new(1976)
	local c = OBSERVATORY_HILL
	local hillTop = OBSERVATORY_HILL_Y
	local half = 22
	local function hillStyle(): Style
		return { color = regolith(rng, 140, 5), material = Enum.Material.Slate }
	end
	box(obs, "Hill", Vector3.new(c.X - half, 0, c.Z - half), Vector3.new(c.X + half, hillTop, c.Z + half), hillStyle())
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local slopeCentre = Vector3.new(c.X, hillTop / 2, c.Z) + dir * (half + 13)
		wedge(obs, "HillSlope", Vector3.new(half * 2, hillTop, 26), CFrame.lookAt(slopeCentre, slopeCentre + dir), hillStyle())
	end

	local top = Vector3.new(c.X, hillTop, c.Z)
	local towardBase = flatUnit(HABITAT_CENTRE - top, Vector3.new(-1, 0, 0))
	local cf = CFrame.lookAt(top, top + towardBase) -- local -Z faces the base: the door side
	local function piece(name: string, a: Vector3, b: Vector3, style: Style): Part
		local minV = a:Min(b)
		local maxV = a:Max(b)
		return part(obs, name, maxV - minV, cf * CFrame.new((minV + maxV) / 2), style)
	end
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	-- Sealed room: inside 16 x 12 x 16, walls 4 thick, roof 8 thick. The only way in is the door.
	piece("Wall", Vector3.new(-12, 0, 8), Vector3.new(12, 12, 12), hull)
	piece("Wall", Vector3.new(-12, 0, -8), Vector3.new(-8, 12, 8), hull)
	piece("Wall", Vector3.new(8, 0, -8), Vector3.new(12, 12, 8), hull)
	piece("Wall", Vector3.new(-12, 0, -12), Vector3.new(-4, 12, -8), hull)
	piece("Wall", Vector3.new(4, 0, -12), Vector3.new(12, 12, -8), hull)
	piece("Wall", Vector3.new(-4, 10, -12), Vector3.new(4, 12, -8), hull)
	piece("Roof", Vector3.new(-12, 12, -12), Vector3.new(12, 20, 12), hull)
	piece("Floor", Vector3.new(-8, 0, -8), Vector3.new(8, 0.4, 8), {
		color = Color3.fromRGB(170, 174, 180),
		material = Enum.Material.DiamondPlate,
	})
	-- Dome: its lowest point just touches the ceiling, so nothing pokes into the room.
	local domeCentre = (cf * CFrame.new(0, 22, 0)).Position
	ball(obs, "Dome", 20, domeCentre, { color = Color3.fromRGB(238, 240, 244), material = Enum.Material.SmoothPlastic })

	-- The door: opaque and solid for everyone on the server.
	local door = piece("Door", Vector3.new(-4, 0, -10.5), Vector3.new(4, 10, -9.5), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
	})
	local secretTrim: Style = { color = ACCENT_SECRET, material = Enum.Material.SmoothPlastic, collide = false }
	piece("DoorFrame", Vector3.new(-4.8, 0, -12.4), Vector3.new(-4, 10.8, -12), secretTrim)
	piece("DoorFrame", Vector3.new(4, 0, -12.4), Vector3.new(4.8, 10.8, -12), secretTrim)
	piece("DoorFrame", Vector3.new(-4, 10, -12.4), Vector3.new(4, 10.8, -12), secretTrim)
	-- A plaque with the telescope icon beside the door.
	local plaque = piece("DoorPlaque", Vector3.new(5.5, 4.5, -12.3), Vector3.new(8.5, 7.5, -12), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	local plaqueGui = Instance.new("SurfaceGui")
	plaqueGui.Name = "PlaqueGui"
	plaqueGui.Face = Enum.NormalId.Front
	plaqueGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	plaqueGui.PixelsPerStud = 40
	plaqueGui.LightInfluence = 0
	plaqueGui.MaxDistance = 120
	plaqueGui.Parent = plaque
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.8, 0.8)
	icon.Image = Icons.telescope
	icon.ImageColor3 = ACCENT_SECRET
	icon.Parent = plaqueGui

	-- Telescope on a mount, aimed at Mars in the sky.
	local mars = marsPosition or defaultMarsPosition()
	local sky = Workspace:FindFirstChild("SkyBodies")
	local marsPart = if sky then sky:FindFirstChild("Mars") else nil
	if marsPart and marsPart:IsA("BasePart") then
		mars = marsPart.Position
	end
	local mount = cf * CFrame.new(0, 0, -1)
	local pivot = (mount * CFrame.new(0, 5.8, 0)).Position
	local white: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic, collide = false }
	local dark: Style = { color = DARK_METAL, material = Enum.Material.Metal, collide = false }
	vcylinder(obs, "TelescopeMount", 5.4, 0.8, (mount * CFrame.new(0, 3.1, 0)).Position, dark)
	cylinder(obs, "TelescopeFoot", 0.4, 3.2, mount * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), dark)
	local aim = (mars - pivot).Unit
	local axis = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis along the look direction
	local function along(distance: number): CFrame
		local at = pivot + aim * distance
		return CFrame.lookAt(at, at + aim) * axis
	end
	cylinder(obs, "TelescopeTube", 8, 1.5, along(1.5), white)
	cylinder(obs, "TelescopeBand", 0.5, 1.8, along(5), {
		color = ACCENT_SECRET,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	cylinder(obs, "TelescopeEyepiece", 1, 0.6, along(-3), dark)
	-- A dark slit painted on the dome where the telescope looks out.
	local toMars = (mars - domeCentre).Unit
	if toMars.Y > 0.05 and toMars.Y < 0.95 then
		local surface = domeCentre + toMars * 9.75
		local meridian = (Vector3.yAxis - toMars * toMars.Y).Unit
		part(obs, "DomeSlit", Vector3.new(1.8, 0.6, 6), CFrame.lookAt(surface, surface + meridian, toMars), {
			color = PALETTE.night,
			material = Enum.Material.SmoothPlastic,
			collide = false,
			shadow = false,
		})
	end

	-- Teaser sign on the back wall. The client localizes the label through its TextKey attribute.
	local sign = piece("TeaserSign", Vector3.new(-6, 5.5, 7.6), Vector3.new(6, 10.5, 8), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
	})
	ball(obs, "MarsPicture", 3, (cf * CFrame.new(3.6, 8, 7.4)).Position, {
		color = MARS_RED,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "TeaserGui"
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.LightInfluence = 0
	signGui.MaxDistance = 80
	signGui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Teaser"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.36, 0.08)
	label.Size = UDim2.fromScale(0.6, 0.84)
	label.Font = Theme.FONT.display
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Theme.ROLE.text
	label.Text = "Next mission: Mars"
	label:SetAttribute("TextKey", "observatory.teaser")
	label.Parent = signGui

	-- Light: a warm ceiling lamp (shadowed, so nothing leaks outside) and magenta floor strips.
	local lamp = piece("Lamp", Vector3.new(-1.5, 11.6, -1.5), Vector3.new(1.5, 12, 1.5), {
		color = Color3.fromRGB(255, 240, 215),
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	pointLight(lamp, INTERIOR_LIGHT, 18, 0.8, true)
	local strip: Style = { color = ACCENT_SECRET, material = Enum.Material.Neon, collide = false, shadow = false }
	piece("GlowStrip", Vector3.new(-8, 0.4, -8), Vector3.new(-7.7, 0.7, 8), strip)
	piece("GlowStrip", Vector3.new(7.7, 0.4, -8), Vector3.new(8, 0.7, 8), strip)

	return { model = obs, door = door }
end

-- The team flag on the habitat roof (reward for the Mars potato). Built hidden, out of the world.
local function buildTeamFlag(base: Instance): Model
	local flag = model(base, "TeamFlag")
	local foot = HABITAT_CENTRE + Vector3.new(24, 19.5, 12)
	vcylinder(flag, "FlagPole", 12, 0.5, foot + Vector3.new(0, 6, 0), { color = METAL, material = Enum.Material.Metal })
	ball(flag, "FlagTop", 0.9, foot + Vector3.new(0, 12.3, 0), {
		color = ACCENT_OK,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	-- Three Lunar Sunrise stripes and a little cream Moon. No agency logos or insignia.
	for i, colour in { ACCENT_SYSTEM, ACCENT_WARNING, ACCENT_SECRET } do
		local stripeTop = 11.6 - (i - 1) * 1.4
		box(flag, "FlagStripe", foot + Vector3.new(-6.3, stripeTop - 1.4, -0.1), foot + Vector3.new(-0.25, stripeTop, 0.1), {
			color = colour,
			material = Enum.Material.SmoothPlastic,
			collide = false,
		})
	end
	ball(flag, "FlagMoon", 1, foot + Vector3.new(-1.6, 10.9, 0), {
		color = PALETTE.cream,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	flag.Parent = nil
	return flag
end

-- Collectible models: small Parts-only figures welded to an invisible root that bobs and spins.
type ShapeKind = "ball" | "box" | "wedge" | "cylinder"
type Shape = {
	kind: ShapeKind,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
}

local COLLECTIBLE_IDS = table.freeze({ "mini_earth", "laika", "cheese", "mars_potato" })

local function shape(kind: ShapeKind, size: Vector3, at: CFrame, color: Color3): Shape
	return { kind = kind, size = size, at = at, color = color }
end

local function uniform(d: number): Vector3
	return Vector3.new(d, d, d)
end

local function shapesFor(id: string): { Shape }
	local black = Color3.fromRGB(28, 28, 34)
	if id == "mini_earth" then
		local land = Color3.fromRGB(96, 160, 84)
		return {
			shape("ball", uniform(2.3), CFrame.new(), Color3.fromRGB(38, 92, 196)),
			shape("ball", uniform(1), CFrame.new(0.55, 0.35, 0.55), land),
			shape("ball", uniform(0.9), CFrame.new(-0.62, -0.15, 0.5), land),
			shape("ball", uniform(0.8), CFrame.new(0.15, -0.55, -0.7), Color3.fromRGB(170, 150, 100)),
			shape("ball", uniform(0.9), CFrame.new(0, 0.9, 0), Color3.fromRGB(245, 248, 255)),
			-- A tiny Moon keeps it company as it spins.
			shape("ball", uniform(0.55), CFrame.new(1.9, 0.4, 0), Color3.fromRGB(184, 182, 176)),
		}
	elseif id == "laika" then
		local fur = Color3.fromRGB(200, 160, 118)
		local ear = Color3.fromRGB(120, 82, 52)
		local helmet = shape("ball", uniform(1.8), CFrame.new(0, 0.82, 1.2), Color3.fromRGB(225, 240, 255))
		helmet.material = Enum.Material.Glass
		helmet.transparency = 0.72
		local shapes = {
			shape("box", Vector3.new(1.2, 1.1, 2), CFrame.new(), WHITE_HULL),
			shape("box", Vector3.new(1.26, 0.28, 2.06), CFrame.new(0, 0.15, 0), ACCENT_SYSTEM),
			shape("box", Vector3.new(0.9, 0.7, 0.8), CFrame.new(0, 0.75, -0.4), ACCENT_SECRET),
			shape("ball", uniform(1.05), CFrame.new(0, 0.8, 1.15), fur),
			shape("box", Vector3.new(0.55, 0.42, 0.55), CFrame.new(0, 0.62, 1.7), Color3.fromRGB(225, 195, 160)),
			shape("ball", uniform(0.24), CFrame.new(0, 0.76, 1.98), black),
			shape("box", Vector3.new(0.24, 0.5, 0.22), CFrame.new(0.34, 1.32, 1.05) * CFrame.Angles(0, 0, -0.25), ear),
			shape("box", Vector3.new(0.24, 0.5, 0.22), CFrame.new(-0.34, 1.32, 1.05) * CFrame.Angles(0, 0, 0.25), ear),
			shape("box", Vector3.new(0.2, 0.2, 0.75), CFrame.new(0, 0.45, -1.25) * CFrame.Angles(math.rad(35), 0, 0), fur),
			helmet,
		}
		for _, lx in { -0.38, 0.38 } do
			for _, lz in { -0.62, 0.62 } do
				table.insert(shapes, shape("box", Vector3.new(0.36, 0.6, 0.36), CFrame.new(lx, -0.8, lz), WHITE_HULL))
			end
		end
		return shapes
	elseif id == "cheese" then
		local visor = shape("ball", uniform(0.7), CFrame.new(0.35, 1.08, 0.3), PALETTE.night)
		visor.reflectance = 0.25
		return {
			-- Wedge on its side: a flat triangle of cheese, holes on top, a mini helmet riding it.
			shape("wedge", Vector3.new(1, 1.7, 2.4), CFrame.Angles(0, 0, math.rad(90)), CHEESE_PAINT),
			shape("ball", uniform(0.42), CFrame.new(0.55, 0.5, -0.5), CHEESE_SPOT),
			shape("ball", uniform(0.42), CFrame.new(0.1, 0.5, 0.8), CHEESE_SPOT),
			shape("ball", uniform(0.45), CFrame.new(-0.3, 0, 1.2), CHEESE_SPOT),
			shape("ball", uniform(1), CFrame.new(0.35, 1.05, 0.6), WHITE_HULL),
			visor,
		}
	else -- mars_potato
		local potato = Color3.fromRGB(176, 112, 74)
		return {
			shape("ball", uniform(1.9), CFrame.new(), potato),
			shape("ball", uniform(1.6), CFrame.new(0.75, 0.12, 0.05), potato),
			shape("ball", uniform(1.4), CFrame.new(-0.8, -0.1, 0), potato),
			shape("ball", uniform(0.34), CFrame.new(0.32, 0.32, 0.83), black),
			shape("ball", uniform(0.34), CFrame.new(-0.32, 0.32, 0.83), black),
			shape("box", Vector3.new(0.55, 0.12, 0.2), CFrame.new(0, -0.22, 0.92), Color3.fromRGB(70, 40, 30)),
			shape("ball", uniform(0.45), CFrame.new(0.15, 1, 0), PLANT_GREEN),
			shape("box", Vector3.new(0.5, 0.1, 0.25), CFrame.new(0.4, 1.18, 0) * CFrame.Angles(0, 0, 0.5), PLANT_GREEN),
		}
	end
end

type CollectibleItem = { ref: CollectibleRef, root: Part, home: CFrame, phase: number }

local function buildCollectible(parent: Instance, id: string, spot: CFrame, phase: number): CollectibleItem
	local m = model(parent, id)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("CollectibleId", id)
	local home = CFrame.new(spot.Position)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.one
	root.CFrame = home
	root.Parent = m
	counted()
	m.PrimaryPart = root

	local pieces: { BasePart } = {}
	for i, s in shapesFor(id) do
		local p: BasePart
		if s.kind == "wedge" then
			p = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			if s.kind == "ball" then
				block.Shape = Enum.PartType.Ball
			elseif s.kind == "cylinder" then
				block.Shape = Enum.PartType.Cylinder
			end
			p = block
		end
		finish(p, m, "Piece" .. i, s.size, home * s.at, {
			color = s.color,
			material = s.material,
			transparency = s.transparency,
			reflectance = s.reflectance,
			collide = false,
			shadow = false,
		})
		table.insert(pieces, p)
	end
	weldTo(root, pieces)

	-- Soft magenta glow: a pad under the item and a shadowed light, so it never shines through rock.
	local floorY = spot.Position.Y - COLLECTIBLE_FLOAT
	local padCf = CFrame.new(spot.Position.X, floorY + 0.08, spot.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	local pad = cylinder(m, "GlowPad", 0.16, 2.8, padCf, {
		color = ACCENT_SECRET,
		material = Enum.Material.Neon,
		transparency = 0.4,
		collide = false,
		shadow = false,
	})
	local glowPoint = Instance.new("Attachment")
	glowPoint.Name = "GlowPoint"
	glowPoint.Position = Vector3.new(1.5, 0, 0) -- the pad's X axis points up
	glowPoint.Parent = pad
	pointLight(glowPoint, ACCENT_SECRET, 12, 1.2, true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = COLLECTIBLE_PROMPT_DISTANCE
	-- Every spot is more than 8 studs from any point outside its walls, so no line-of-sight check
	-- is needed (and narrow tunnels cannot hide the prompt from the camera).
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt:SetAttribute("TextKey", "prompt.collect")
	prompt:SetAttribute("CollectibleId", id)
	prompt.Parent = root

	return { ref = { id = id, model = m, prompt = prompt }, root = root, home = home, phase = phase }
end

------------------------------------------------------------------------------------------------
-- Sky clock: the Sun circling the horizon, the turning Earth, its phases and the eclipse
------------------------------------------------------------------------------------------------

local EARTH_RADIUS_ANGLE = math.atan((EARTH_DIAMETER / 2) / EARTH_DISTANCE)
local skyElapsed = 0 -- seconds of Sun motion since the base was built
local earthTurnElapsed = 0 -- seconds of Earth rotation

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function sunAngleNow(): number
	local h = flatUnit(sunDirection(), Vector3.new(0, 0, -1))
	return math.atan2(h.X, h.Z)
end

local function setEclipse(active: boolean)
	if active == eclipseActive then
		return
	end
	eclipseActive = active
	Workspace:SetAttribute("SBO_Eclipse", active)
	for _, listener in eclipseListeners do
		task.spawn(function()
			local ok, err = pcall(listener, active)
			if not ok then
				warn(`[SpaceBaseOdyssey] eclipse listener failed: {err}`)
			end
		end)
	end
end

-- a = 0 normal light, 1 full eclipse: the base dims and the Earth gets its red-orange ring.
local function applyEclipseLook(a: number)
	local t = a * a * (3 - 2 * a)
	Lighting.Brightness = lerp(LIGHT_BRIGHTNESS, ECLIPSE_BRIGHTNESS, t)
	Lighting.ExposureCompensation = lerp(LIGHT_EXPOSURE, ECLIPSE_EXPOSURE, t)
	Lighting.OutdoorAmbient = LIGHT_OUTDOOR_AMBIENT:Lerp(ECLIPSE_OUTDOOR_AMBIENT, t)
	local g = earthGui
	if g then
		g.eclipseGlow.BackgroundTransparency = lerp(1, 0.7, t)
		g.eclipseStroke.Transparency = lerp(1, 0, t)
	end
end

-- Turns the map and moves the day/night line. Seen from the base, the Earth is full when the Sun is
-- behind us and new (dark) when the Sun is right behind the Earth.
local function updateEarthDisc(sun: Vector3, earthDir: Vector3)
	local g = earthGui
	if not g then
		return
	end
	local u = (earthTurnElapsed / EARTH_TURN_SECONDS * 2) % 2
	g.mapA.Position = UDim2.fromScale(u - 2, 0)
	g.mapB.Position = UDim2.fromScale(u, 0)

	local right = earthDir:Cross(Vector3.yAxis)
	right = if right.Magnitude < 1e-4 then Vector3.xAxis else right.Unit
	local up = right:Cross(earthDir).Unit
	local sx, sy = sun:Dot(right), sun:Dot(up)
	if sx * sx + sy * sy > 1e-6 then
		local rotation = math.deg(math.atan2(-sy, sx))
		-- Replicated property: only send a visible change (the Sun moves about 0.05 deg per update).
		if math.abs(rotation - g.nightPivot.Rotation) >= EARTH_PHASE_MIN_DEGREES then
			g.nightPivot.Rotation = rotation
		end
	end
	-- Day/night line across the disc (-1 = far edge, all lit; +1 = Sun side, all dark).
	local edge = math.clamp(sun:Dot(earthDir), -1, 1)
	if math.abs(edge - earthPhaseEdge) < EARTH_PHASE_MIN_EDGE then
		return -- a new NumberSequence would replicate to every client for no visible change
	end
	earthPhaseEdge = edge
	local soft = EARTH_TERMINATOR_SOFTNESS
	local centre = 0.5 + edge * (1 / 3 + soft)
	local a = math.clamp(centre - soft, 0.001, 0.997)
	local b = math.clamp(centre + soft, a + 0.001, 0.998)
	g.nightGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, EARTH_NIGHT_TRANSPARENCY),
		NumberSequenceKeypoint.new(a, EARTH_NIGHT_TRANSPARENCY),
		NumberSequenceKeypoint.new(b, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function updateArrays(tracks: { ArrayTrack })
	local angle = sunAngleNow()
	for _, track in tracks do
		local yaw = wrapAngle(angle - track.baseAngle)
		if math.abs(wrapAngle(yaw - track.yaw)) >= ARRAY_MIN_TURN and track.panel.Parent ~= nil and not risingParts[track.panel] then
			track.yaw = yaw
			track.panel.CFrame = CFrame.new(track.pivot) * CFrame.Angles(0, yaw, 0) * track.offset
		end
	end
end

-- One Heartbeat at SKY_UPDATE_SECONDS drives the whole sky, so few properties replicate.
local function startSky(base: Instance, tracks: { ArrayTrack })
	if skyConnection then
		skyConnection:Disconnect()
		skyConnection = nil
	end
	skyElapsed = 0
	earthTurnElapsed = 0
	local earthDir = (earthPosition or defaultEarthPosition()).Unit
	local accumulator = SKY_UPDATE_SECONDS
	local arrayAccumulator = 0
	local lookApplied = -1
	skyConnection = RunService.Heartbeat:Connect(function(rawDt: number)
		if base.Parent == nil then
			if skyConnection then
				skyConnection:Disconnect()
				skyConnection = nil
			end
			return
		end
		local dt = math.min(rawDt, 0.25)
		accumulator += dt
		if accumulator < SKY_UPDATE_SECONDS then
			return
		end
		local step = accumulator
		accumulator = 0
		earthTurnElapsed += step
		if sunCircleEnabled then
			skyElapsed += step
			if sunTrackMode then
				sunTrackAzimuth += step * 2 * math.pi / SUN_CIRCLE_SECONDS
				applySunTrack(sunTrackAzimuth)
			else
				Lighting.ClockTime = (sunClockStart + skyElapsed * 24 / SUN_CIRCLE_SECONDS) % 24
			end
		end
		local sun = sunDirection()
		updateEarthDisc(sun, earthDir)

		local separation = math.acos(math.clamp(sun:Dot(earthDir), -1, 1))
		setEclipse(sunCircleEnabled and separation < EARTH_RADIUS_ANGLE + ECLIPSE_MARGIN)
		local target = if eclipseActive then 1 else 0
		if eclipseAmount ~= target then
			local change = step / ECLIPSE_FADE_SECONDS
			eclipseAmount = if target > eclipseAmount
				then math.min(target, eclipseAmount + change)
				else math.max(target, eclipseAmount - change)
		end
		if eclipseAmount ~= lookApplied then
			lookApplied = eclipseAmount
			applyEclipseLook(eclipseAmount)
		end

		arrayAccumulator += step
		if arrayAccumulator >= ARRAY_UPDATE_SECONDS then
			arrayAccumulator = 0
			updateArrays(tracks)
		end
	end)
end

local function previewEclipse()
	if sunTrackMode then
		-- Put the Sun a few seconds before the Earth on its track.
		local secondsPerRadian = SUN_CIRCLE_SECONDS / (2 * math.pi)
		local lead = EARTH_RADIUS_ANGLE + ECLIPSE_MARGIN + ECLIPSE_PREVIEW_LEAD_SECONDS / secondsPerRadian
		sunTrackAzimuth = math.rad(EARTH_TRACK_AZIMUTH_DEG) - lead
		sunTrackIndex = -1
		applySunTrack(sunTrackAzimuth)
		return
	end
	local atEarth = sunClockAtEarth
	if not sunCircleEnabled or atEarth == nil then
		return
	end
	local secondsPerRadian = SUN_CIRCLE_SECONDS / (2 * math.pi)
	local leadSeconds = (EARTH_RADIUS_ANGLE + ECLIPSE_MARGIN) * secondsPerRadian + ECLIPSE_PREVIEW_LEAD_SECONDS
	local clock = atEarth - leadSeconds * 24 / SUN_CIRCLE_SECONDS
	skyElapsed = ((clock - sunClockStart) % 24) * SUN_CIRCLE_SECONDS / 24
end

------------------------------------------------------------------------------------------------
-- Public build
------------------------------------------------------------------------------------------------

function WorldBuilder.build(data: any): World
	partCounter = 0
	eclipseListeners = {}
	local old = Workspace:FindFirstChild("Base")
	if old then
		old:Destroy()
	end
	local base = Instance.new("Folder")
	base.Name = "Base"
	base.Parent = Workspace

	risingParts = {}
	extraKeepouts = {}
	local hidden = hiddenStore()

	local rng = Random.new(42)
	local ground = buildGround(base, rng)
	local habitat = buildHabitat(base)
	local shelter = buildShelter(base)
	local _, iceNodes, rampAngle, cheeseSpot = buildCrater(base, rng)
	buildRidge(base, rng)
	local arrays, arrayVisuals, arrayTracks = buildArrays(base, data)
	local antenna = buildAntenna(base)

	-- Stage 6 layout first, so random boulders keep clear of the pipe, the robot's route and the pads.
	local drillAngle = chooseDrillAngle(rampAngle)
	local conveyorFoot = craterPoint(drillAngle, CONVEYOR_FOOT_RADIUS, 0)
	local cargoPoints = cargoRoutePoints(drillAngle)
	local pads = padSpots(drillAngle)
	keepoutsAlong({ conveyorFoot, SILO_CENTRE }, 5, 12, extraKeepouts)
	keepoutsAlong(cargoPoints, 6, 12, extraKeepouts)
	table.insert(extraKeepouts, { x = SILO_CENTRE.X, z = SILO_CENTRE.Z, r = 9 })
	for _, spot in pads do
		table.insert(extraKeepouts, { x = spot.X, z = spot.Z, r = 7 })
	end

	buildDecor(base, rng)
	local greenhouse = buildGreenhouse(base)
	local rover = buildRover(base, rampAngle)

	-- Stage 6: automatic ice drills on the crater floor, the conveyor, the silo and the cargo robot.
	local outward = dirFromAngle(drillAngle)
	local across = Vector3.new(-outward.Z, 0, outward.X)
	local drillsFolder = folder(base, "IceDrills")
	local drills: { DrillRefs } = {}
	for i = 1, 3 do
		local beltEnd = craterPoint(drillAngle, HOPPER_RADIUS - 2, CRATER_RIM_Y + 0.6) + across * ((i - 2) * 0.9)
		table.insert(drills, buildDrill(drillsFolder, i, drillAngle + (i - 2) * DRILL_SPREAD, beltEnd))
	end
	local conveyor = buildConveyor(base, drillAngle)
	local silo = buildSilo(base, conveyor.pipeEnd)
	local cargo = buildCargoBot(base, polyline(cargoPoints))
	local drillCentre = craterPoint(drillAngle, DRILL_FLOOR_RADIUS, 0)

	-- Secrets come last and use their own random streams, so the rest of the base keeps its layout.
	local secretSpots: { [string]: CFrame } = {
		mars_potato = buildCrawlSpace(base, ground),
		mini_earth = buildLookoutRock(base),
		laika = buildLavaTube(base),
		cheese = cheeseSpot,
	}
	local observatory = buildObservatory(base)
	local teamFlag = buildTeamFlag(base)
	local collectiblesFolder = folder(base, "Collectibles")
	local collectibleItems: { CollectibleItem } = {}
	local collectibleRefs: { CollectibleRef } = {}
	for i, id in COLLECTIBLE_IDS do
		local item = buildCollectible(collectiblesFolder, id, secretSpots[id], i * 1.7)
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
		HabitatDoor = HABITAT_CENTRE + Vector3.new(0, 3, 23),
		Antenna = ANTENNA_BASE + Vector3.new(0, 1, 0),
		IceSite = CRATER_CENTRE + Vector3.new(0, CRATER_FLOOR_Y + 1, 0),
		Processor = habitat.processorInlet.Position + Vector3.new(0, 0, 1.5),
		Console = habitat.console.Position + Vector3.new(0, 0, 3),
		Leak = habitat.leakPart.Position + Vector3.new(2, 0, 0),
		Greenhouse = greenhouse.centre,
		Arrays = Vector3.new(RIDGE_CENTRE.X, RIDGE_TOP_Y + 1, RIDGE_CENTRE.Z),
		Silo = SILO_CENTRE + Vector3.new(0, 3, -(SILO_GLASS_DIAMETER / 2 + 2)),
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
			then CFrame.lookAt(antenna.hubPosition, earthPosition or defaultEarthPosition())
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
		if isDusty then
			visual.panel.Color = PANEL_DUSTY
			visual.panel.Material = Enum.Material.Sand
			visual.panel.Reflectance = 0
		else
			visual.panel.Color = PANEL_CLEAN
			visual.panel.Material = Enum.Material.Glass
			visual.panel.Reflectance = 0.1
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

	local function setTeamFlag(visible: boolean)
		teamFlag.Parent = if visible then base else nil
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
			table.insert(eclipseListeners, callback)
		end
	end

	local function isEclipse(): boolean
		return eclipseActive
	end

	-- Stage 6: build levels. Every structure was built above; each build id lists the models it shows
	-- from which level, and its blueprint copies. setBuildLevel(id, 0) is applied to all of them below,
	-- so the base starts with only the habitat, its water tank and blueprints.
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

	local function register(id: string, fallbackMax: number, specs: { UnitSpec }): BuildEntry
		local entry: BuildEntry = {
			units = {},
			upgrades = {},
			lights = {},
			level = 1, -- as built: every unit standing, upgrade parts hidden
			maxLevel = maxLevelOf(id, fallbackMax),
		}
		for _, spec in specs do
			local home = spec.instance.Parent :: Instance
			table.insert(entry.units, {
				level = spec.level,
				instance = spec.instance,
				home = home,
				hologram = makeHologram(spec.instance, hidden),
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

	local solarSpecs: { UnitSpec } = {}
	for i, ref in arrays do
		table.insert(solarSpecs, { level = i, instance = ref.model })
	end
	register("solar", #arrays, solarSpecs)
	register("greenhouse", 1, { { level = 1, instance = greenhouse.model } })
	local antennaEntry = register("antenna", 3, { { level = 1, instance = antenna.model, dust = ANTENNA_BASE } })
	local shelterEntry = register("shelter", 1, { { level = 1, instance = shelter.model, dust = SHELTER_CENTRE + Vector3.new(0, 0, 31) } })
	local function drillFloor(i: number): Vector3
		return craterPoint(drillAngle + (i - 2) * DRILL_SPREAD, DRILL_FLOOR_RADIUS, CRATER_FLOOR_Y)
	end
	register("drill_1", 3, {
		{ level = 1, instance = drills[1].model, dust = drillFloor(1) },
		{ level = 1, instance = conveyor.model, dust = conveyorFoot },
		{ level = 1, instance = silo.model, dust = SILO_CENTRE },
	})
	register("drill_2", 3, { { level = 1, instance = drills[2].model, dust = drillFloor(2) } })
	register("drill_3", 3, { { level = 1, instance = drills[3].model, dust = drillFloor(3) } })
	register("cargo_bot", 1, { { level = 1, instance = cargo.model } })

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
		solar = "solar",
		greenhouse = "plant",
		antenna = "antenna",
		shelter = "shield",
		drill_1 = "drill",
		drill_2 = "drill",
		drill_3 = "drill",
		cargo_bot = "robot",
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
			local refs = buildPad(padsFolder, id, spot, icon)
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

	local function setBuildLevel(id: string, level: number, animate: boolean)
		local entry = if type(id) == "string" then entries[id] else nil
		if entry == nil or type(level) ~= "number" or level ~= level then
			return
		end
		local newLevel = math.clamp(math.floor(level), 0, entry.maxLevel)
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
			riseIn(risableParts(raised), RISE_DROP, entry.onRiseStep, entry.onRiseDone)
			for _, unit in raisedUnits do
				local spot = dustSpot(unit)
				if spot then
					dustPuff(base, spot)
				end
			end
		end
		if #upgraded > 0 then
			riseIn(risableParts(upgraded), UPGRADE_DROP, nil, nil)
			local pad = entry.pad
			if pad and #raised == 0 then
				dustPuff(base, pad.Position)
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

	-- Silo fill: the ice column grows, and the top ring turns lime when the silo is full.
	local siloFraction = -1
	local function setSilo(ice: number, max: number)
		if type(ice) ~= "number" or type(max) ~= "number" or ice ~= ice or max <= 0 then
			return
		end
		local f = math.clamp(ice / max, 0, 1)
		if math.abs(f - siloFraction) < 1e-3 then
			return
		end
		siloFraction = f
		local height = math.max(0.05, silo.height * f)
		local centre = Vector3.new(SILO_CENTRE.X, silo.bottomY + height / 2, SILO_CENTRE.Z)
		TweenService:Create(silo.fill, SILO_TWEEN, {
			Size = Vector3.new(height, silo.diameter, silo.diameter),
			CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = if f <= 0 then 1 else 0.05,
		}):Play()
		silo.light.Enabled = f > 0
		silo.ring.Color = if f >= 1 then ACCENT_OK else ACCENT_SYSTEM
	end
	setSilo(0, 1)

	-- Cargo robot: drives the route (dock -> conveyor foot -> back) while active, parked otherwise.
	local cargoActive = false
	local cargoDistance = 0
	local cargoDirection = 1
	local cargoWait = 0
	local cargoAccumulator = 0
	local function cargoPose(distance: number, direction: number, smooth: boolean): CFrame
		local position, dir = alongPolyline(cargo.route, distance)
		local facing = flatUnit(dir * direction, Vector3.zAxis)
		local target = CFrame.lookAt(position, position + facing)
		if not smooth then
			return target
		end
		local current = cargo.root.CFrame
		return CFrame.new(position) * current.Rotation:Lerp(target.Rotation, 0.35)
	end
	local function setCargoActive(active: boolean)
		cargoActive = active == true
		if not cargoActive then
			cargoDistance = 0
			cargoDirection = 1
			cargoWait = 0
			cargo.load.Transparency = 1
			if not risingParts[cargo.root] then
				cargo.root.CFrame = cargoPose(0, 1, false)
			end
		end
	end

	-- Drill bits and ice cubes (only while someone is near the drills).
	local drillsAwake = false
	local drillSpin: { number } = { 0, 0, 0 }
	local spinAccumulator = 0
	local cubeClock = 0
	local cubeSpacing = conveyor.cubeLine.total / math.max(1, #conveyor.cubes)
	local function animateDrills(step: number)
		for i, drill in drills do
			local level = buildLevel("drill_" .. i)
			if level < 1 then
				continue
			end
			drillSpin[i] = (drillSpin[i] + DRILL_SPIN_RAD[math.min(level, #DRILL_SPIN_RAD)] * step) % (2 * math.pi)
			local turn = CFrame.Angles(0, drillSpin[i], 0)
			for _, bit in drill.bits do
				if level >= bit.level and not risingParts[bit.root] then
					bit.root.CFrame = CFrame.new(bit.base.Position) * turn * bit.base.Rotation
				end
			end
		end
		if buildLevel("drill_1") >= 1 then
			cubeClock += step
			for k, cube in conveyor.cubes do
				if not risingParts[cube] then
					local d = (cubeClock * ICE_CUBE_SPEED + (k - 1) * cubeSpacing) % conveyor.cubeLine.total
					local position, dir = alongPolyline(conveyor.cubeLine, d)
					cube.CFrame = CFrame.lookAt(position, position + dir)
				end
			end
		end
	end

	local function animateCargo(step: number)
		if not cargoActive or buildLevel("cargo_bot") < 1 or risingParts[cargo.root] then
			return
		end
		if cargoWait > 0 then
			cargoWait -= step
			return
		end
		cargoDistance += cargoDirection * CARGO_SPEED * step
		if cargoDistance >= cargo.route.total then
			cargoDistance = cargo.route.total
			cargoDirection = -1
			cargoWait = CARGO_WAIT_SECONDS
			cargo.load.Transparency = 0 -- loaded at the conveyor
		elseif cargoDistance <= 0 then
			cargoDistance = 0
			cargoDirection = 1
			cargoWait = CARGO_WAIT_SECONDS
			cargo.load.Transparency = 1 -- unloaded at the silo
		end
		cargo.root.CFrame = cargoPose(cargoDistance, cargoDirection, true)
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
		local drillsNear = false
		for _, position in positions do
			if (position - drillCentre).Magnitude <= DRILL_AWAKE_RANGE then
				drillsNear = true
				break
			end
		end
		drillsAwake = drillsNear
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
		-- Stage 6: drill bits and ice cubes (15 times a second, only near the drills), cargo robot.
		spinAccumulator += dt
		if spinAccumulator >= SPIN_UPDATE_SECONDS then
			local step = spinAccumulator
			spinAccumulator = 0
			if drillsAwake then
				animateDrills(step)
			end
		end
		cargoAccumulator += dt
		if cargoAccumulator >= PULSE_UPDATE_SECONDS then
			local step = cargoAccumulator
			cargoAccumulator = 0
			animateCargo(step)
		end
	end)

	refreshPrompts()
	setSystemVisuals({ LifeSupport = 0, Greenhouse = 0, Science = 0 })
	startSky(base, arrayTracks)
	-- Start from an almost empty base: only the habitat and its water tank stand (BaseService then
	-- applies the builds of the players present).
	for id in entries do
		setBuildLevel(id, 0, false)
	end

	return {
		spawn = habitat.spawn,
		habitatZone = habitat.zone,
		shelterZone = shelter.zone,
		arrays = arrays,
		iceNodes = iceNodes,
		processorPrompt = habitat.processorPrompt,
		leak = { part = habitat.leakPart :: BasePart, prompt = habitat.leakPrompt },
		antenna = { model = antenna.model, dish = antenna.dish :: BasePart, prompt = antenna.prompt },
		console = { part = habitat.console :: BasePart, prompt = habitat.consolePrompt },
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
	}
end

-- Point-in-box test for the zone parts (works for rotated parts too).
function WorldBuilder.isInZone(zonePart: BasePart, position: Vector3): boolean
	local localPos = zonePart.CFrame:PointToObjectSpace(position)
	local half = zonePart.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

return WorldBuilder
