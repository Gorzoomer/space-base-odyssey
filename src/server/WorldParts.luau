--!strict
-- Space Base Odyssey - shared pieces of the world builder: layout anchors, the Lunar Sunrise palette,
-- visual tuning, the shared build state and the part helpers (part, wedge, ball, cylinder, box,
-- prompts, zones, welds, Geo shapes). Used by WorldBuilder, WorldSky, WorldStructures and WorldSecrets.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

export type Style = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	shadow: boolean?,
}

local WorldParts = {}

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
-- Stage 7 layout (team feedback: a modern lunar base concept). The hub is a round module with a
-- white dome; a walk-through tube leads to the glass greenhouse dome; the game starts in the lander.
local HUB_SEGMENTS = 16
local HUB_APOTHEM = 31 -- inner wall face
local HUB_WALL = 2
local HUB_WALL_HEIGHT = 18
local HUB_DOME_RX = 32.5
local HUB_DOME_RY = 14
local HUB_ROOF_Y = 19.5
local HUB_ZONE_HALF = 23 -- the inside zone is the square that fits within the round wall
-- Stage 7 layout points (a table: Vector3 values would each take a register in this big module).
local S7 = {}
-- Stage 7 geometry and construction helpers (one table for the same reason).
local Geo = {}
S7.TANK_OFFSET = Vector3.new(24.5, 0, -13) -- water tank, from the hub centre
S7.GREENHOUSE_A = Vector3.new(-62, 0, 8)
local GREENHOUSE_A_RX = 16
local GREENHOUSE_A_RY = 14
S7.GREENHOUSE_B = Vector3.new(-66, 0, 44) -- level 2: a second dome north of the first
local GREENHOUSE_B_RX = 14
local GREENHOUSE_B_RY = 12
local TUBE_AXIS_Y = 4.5 -- walk-through tube: octagon around this axis
local TUBE_APOTHEM = 6.5
S7.LANDER_CENTRE = Vector3.new(40, 0, -130)
S7.LAB_CENTRE = Vector3.new(-55, 0, -35)
local LAB_TUBE_INSET = 12 -- the lab tube stops this far from the lab centre (its wall)
S7.GARAGE_CENTRE = Vector3.new(95, 0, 75)
S7.LANDING_PAD_CENTRE = Vector3.new(-110, 0, -180)
S7.SITE_SPOTS = {
	Vector3.new(330, 0, 260), -- old_lander
	Vector3.new(-380, 0, 280), -- impact_crater
	Vector3.new(400, 0, -230), -- boulder_tracks
	Vector3.new(-220, 0, -360), -- prospector_crash
	Vector3.new(160, 0, 430), -- sun_peak
}
local GROUND_HALF = 600
local GROUND_TILE = 150
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
	"LanderDoor", -- Stage 7: the foot of the lander ramp (objective go_outside)
	"CrateDepot", -- Stage 7: the parts crates at the lander's cargo bay
})

-- Stage 7 construction look (visual tuning): a build in progress shows a foundation outline in
-- construction orange, then its real parts appear from the bottom up, one step at a time.
local CONSTRUCTION_DROP = 2 -- newly revealed parts rise this far into place
local OUTLINE_MAX_SPAN = 90 -- long pieces (the ice conveyor) get no outline
local CARRY_CRATE_NAME = "SBO_CarriedCrate"
local MIN_LEVEL_ATTRIBUTE = "SBO_MinLevel" -- parts (or models) that only show from that build level on

-- Part counter: every part made counts, and the builder yields now and then (WorldBuilder.build
-- resets it with resetPartCounter).
local partCounter = 0

-- Stage 6: parts that are rising into place right now (the sun tracker, drill bits and the cargo
-- robot leave them alone until they arrive). WorldBuilder.build starts a new set; the set is a field
-- of buildState so every world module sees the current one.
local buildState: { risingParts: { [BasePart]: boolean } } = { risingParts = {} }

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

-- A box given by two corners in the local space of `frame` (for rotated structures like the lander).
function Geo.framedBox(parent: Instance, name: string, frame: CFrame, a: Vector3, b: Vector3, style: Style): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	return part(parent, name, maxV - minV, frame * CFrame.new((minV + maxV) / 2), style)
end

-- Stage 7: one flat wall segment of a round module (a regular polygon). cf sits at ground level in
-- the middle of the wall's thickness; its -Z points out of the module and X runs along the wall.
export type RingSegment = { index: number, angle: number, cf: CFrame, width: number }

function Geo.ringSegments(frame: CFrame, apothem: number, thickness: number, segments: number, rotation: number): { RingSegment }
	local list: { RingSegment } = {}
	local mid = apothem + thickness / 2
	for k = 0, segments - 1 do
		local angle = rotation + k * 2 * math.pi / segments
		local dir = dirFromAngle(angle)
		local at = dir * mid
		table.insert(list, {
			index = k,
			angle = angle,
			cf = frame * CFrame.lookAt(at, at + dir),
			width = 2 * (apothem + thickness) * math.tan(math.pi / segments) + 0.1,
		})
	end
	return list
end

-- A faceted dome (half ellipsoid) from flat panels: `bands` rings of `segments` panels from the ground
-- up to capAngle, then a flat cap disc. Panels listed in `skip` (band * 1000 + segment) are left out
-- (doorways). Segment i is centred on rotation + i * 2 pi / segments. Returns the panels and the cap.
type DomeOptions = {
	bands: number,
	segments: number,
	thickness: number,
	rotation: number?,
	capAngle: number?,
	skip: { [number]: boolean }?,
	capStyle: Style?,
}

function Geo.domeShell(parent: Instance, name: string, centre: Vector3, rx: number, ry: number, style: Style, opts: DomeOptions): ({ Part }, Part)
	local panels: { Part } = {}
	local n = opts.segments
	local rotation = opts.rotation or 0
	local capAngle = opts.capAngle or math.rad(72)
	local skip = opts.skip or {}
	for b = 1, opts.bands do
		local phi0 = (b - 1) / opts.bands * capAngle
		local phi1 = b / opts.bands * capAngle
		local r0, y0 = rx * math.cos(phi0), ry * math.sin(phi0)
		local r1, y1 = rx * math.cos(phi1), ry * math.sin(phi1)
		local width = 2 * r0 * math.tan(math.pi / n) + 0.15
		for i = 0, n - 1 do
			if skip[b * 1000 + i] then
				continue
			end
			local dir = dirFromAngle(rotation + i * 2 * math.pi / n)
			local bottom = centre + dir * r0 + Vector3.new(0, y0, 0)
			local top = centre + dir * r1 + Vector3.new(0, y1, 0)
			local up = (top - bottom).Unit
			local right = Vector3.new(dir.Z, 0, -dir.X)
			local outward = right:Cross(up)
			local mid = (bottom + top) / 2 - outward * (opts.thickness / 2)
			table.insert(
				panels,
				part(parent, name, Vector3.new(width, (top - bottom).Magnitude + 0.12, opts.thickness), CFrame.fromMatrix(mid, right, up), style)
			)
		end
	end
	local capRadius = rx * math.cos(capAngle)
	local capY = ry * math.sin(capAngle)
	local cap = vcylinder(parent, name .. "Cap", opts.thickness, capRadius * 2 + 0.6, centre + Vector3.new(0, capY - opts.thickness / 2, 0), opts.capStyle or style)
	return panels, cap
end

-- Skip keys for a doorway in a domeShell: the two segments on each side of `angle`, bands 1..maxBand.
-- The dome must use rotation = angle + pi / segments so a panel edge sits on the door's centre line.
function Geo.domeDoorway(segments: number, maxBand: number): { [number]: boolean }
	local skip: { [number]: boolean } = {}
	for b = 1, maxBand do
		skip[b * 1000 + 0] = true
		skip[b * 1000 + (segments - 1)] = true
	end
	return skip
end

-- World-space box around a part (works for rotated parts).
function Geo.partBounds(p: BasePart): (Vector3, Vector3)
	local cf = p.CFrame
	local half = p.Size / 2
	local r = cf.RightVector * half.X
	local u = cf.UpVector * half.Y
	local l = cf.LookVector * half.Z
	local e = Vector3.new(
		math.abs(r.X) + math.abs(u.X) + math.abs(l.X),
		math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y),
		math.abs(r.Z) + math.abs(u.Z) + math.abs(l.Z)
	)
	return cf.Position - e, cf.Position + e
end

-- Shared by the crater's cheese niche and the Stage 6 drills (they keep clear of it).
local CHEESE_NICHE_OFFSET = math.rad(220) -- from the ramp, between two ice nodes and far from both

-- The habitat's glass, also used by the lander's windows.
local GLASS: Style = { color = GLASS_COLOUR, material = Enum.Material.Glass, transparency = 0.4, shadow = false }

-- A wall segment with a doorway in the middle (door `doorWidth` wide, `doorTop` tall).
function Geo.doorSegment(parent: Instance, seg: RingSegment, doorWidth: number, doorTop: number, height: number, thickness: number, style: Style)
	local jamb = math.max(0.4, (seg.width - doorWidth) / 2)
	for _, side in { -1, 1 } do
		part(parent, "WallJamb", Vector3.new(jamb, height, thickness), seg.cf * CFrame.new(side * (doorWidth / 2 + jamb / 2), height / 2, 0), style)
	end
	part(parent, "WallLintel", Vector3.new(doorWidth + 0.2, height - doorTop, thickness), seg.cf * CFrame.new(0, (doorTop + height) / 2, 0), style)
end

-- A wall segment with a band of windows between lowTop and glassTop.
function Geo.windowSegment(parent: Instance, seg: RingSegment, height: number, thickness: number, lowTop: number, glassTop: number, style: Style, glass: Style)
	local w = seg.width
	part(parent, "WallLow", Vector3.new(w, lowTop, thickness), seg.cf * CFrame.new(0, lowTop / 2, 0), style)
	part(parent, "WallHigh", Vector3.new(w, height - glassTop, thickness), seg.cf * CFrame.new(0, (glassTop + height) / 2, 0), style)
	part(parent, "WallGlass", Vector3.new(w - 0.2, glassTop - lowTop, 0.5), seg.cf * CFrame.new(0, (lowTop + glassTop) / 2, 0), glass)
end

-- Cyan door frame and a lamp over a doorway, on the outside face of the segment (local -Z).
function Geo.doorDressing(parent: Instance, seg: RingSegment, doorWidth: number, doorTop: number, thickness: number): Part
	local frameStyle: Style = { color = ACCENT_SYSTEM, material = Enum.Material.SmoothPlastic, shadow = false } -- cyan = guidance
	local face = -(thickness / 2 + 0.3)
	for _, side in { -1, 1 } do
		part(parent, "DoorFrame", Vector3.new(0.8, doorTop + 0.8, 0.6), seg.cf * CFrame.new(side * (doorWidth / 2 + 0.4), (doorTop + 0.8) / 2, face), frameStyle)
	end
	part(parent, "DoorFrame", Vector3.new(doorWidth + 1.6, 0.8, 0.6), seg.cf * CFrame.new(0, doorTop + 0.4, face), frameStyle)
	local lamp = part(parent, "DoorLamp", Vector3.new(3, 0.5, 0.8), seg.cf * CFrame.new(0, doorTop + 1.45, face - 0.1), {
		color = Color3.fromRGB(255, 232, 190),
		material = Enum.Material.Neon,
		shadow = false,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 22
	light.Angle = 80
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 232, 200)
	light.Parent = lamp
	return lamp
end

-- Height of a dome's inside above its floor at horizontal distance d from its centre.
function Geo.domeHeightAt(rx: number, ry: number, d: number): number
	local t = math.clamp(d / rx, 0, 1)
	return ry * math.sqrt(1 - t * t)
end

-- Angles around the crater (the science rover's loop and the Stage 6 drills).
local function angleGap(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	return math.min(d, 2 * math.pi - d)
end

-- The rover's loop sits on the flat rim band, on the base's side of the crater, away from the ramp so
-- it never sits on the way down to the ice. Returns its angle around the crater.
local function roverSideAngle(rampAngle: number): number
	local sideA, sideB = math.pi - 0.6, math.pi + 0.6
	return if angleGap(sideA, rampAngle) >= angleGap(sideB, rampAngle) then sideA else sideB
end

function WorldParts.resetPartCounter()
	partCounter = 0
end

-- Everything above, for the other world modules.
WorldParts.HABITAT_CENTRE = HABITAT_CENTRE
WorldParts.SHELTER_CENTRE = SHELTER_CENTRE
WorldParts.CRATER_CENTRE = CRATER_CENTRE
WorldParts.CRATER_RADIUS = CRATER_RADIUS
WorldParts.CRATER_FLOOR_Y = CRATER_FLOOR_Y
WorldParts.CRATER_RIM_Y = CRATER_RIM_Y
WorldParts.RIDGE_CENTRE = RIDGE_CENTRE
WorldParts.RIDGE_TOP_Y = RIDGE_TOP_Y
WorldParts.ANTENNA_BASE = ANTENNA_BASE
WorldParts.HUB_SEGMENTS = HUB_SEGMENTS
WorldParts.HUB_APOTHEM = HUB_APOTHEM
WorldParts.HUB_WALL = HUB_WALL
WorldParts.HUB_WALL_HEIGHT = HUB_WALL_HEIGHT
WorldParts.HUB_DOME_RX = HUB_DOME_RX
WorldParts.HUB_DOME_RY = HUB_DOME_RY
WorldParts.HUB_ROOF_Y = HUB_ROOF_Y
WorldParts.HUB_ZONE_HALF = HUB_ZONE_HALF
WorldParts.S7 = S7
WorldParts.Geo = Geo
WorldParts.GREENHOUSE_A_RX = GREENHOUSE_A_RX
WorldParts.GREENHOUSE_A_RY = GREENHOUSE_A_RY
WorldParts.GREENHOUSE_B_RX = GREENHOUSE_B_RX
WorldParts.GREENHOUSE_B_RY = GREENHOUSE_B_RY
WorldParts.TUBE_AXIS_Y = TUBE_AXIS_Y
WorldParts.TUBE_APOTHEM = TUBE_APOTHEM
WorldParts.LAB_TUBE_INSET = LAB_TUBE_INSET
WorldParts.GROUND_HALF = GROUND_HALF
WorldParts.GROUND_TILE = GROUND_TILE
WorldParts.LOOKOUT_DISTANCE = LOOKOUT_DISTANCE
WorldParts.LOOKOUT_YAW = LOOKOUT_YAW
WorldParts.LAVA_TUBE_MIN = LAVA_TUBE_MIN
WorldParts.LAVA_TUBE_MAX = LAVA_TUBE_MAX
WorldParts.OBSERVATORY_HILL = OBSERVATORY_HILL
WorldParts.OBSERVATORY_HILL_Y = OBSERVATORY_HILL_Y
WorldParts.COLLECTIBLE_PROMPT_DISTANCE = COLLECTIBLE_PROMPT_DISTANCE
WorldParts.COLLECTIBLE_FLOAT = COLLECTIBLE_FLOAT
WorldParts.COLLECTIBLE_BOB = COLLECTIBLE_BOB
WorldParts.COLLECTIBLE_SPIN_RAD = COLLECTIBLE_SPIN_RAD
WorldParts.COLLECTIBLE_AWAKE_RANGE = COLLECTIBLE_AWAKE_RANGE
WorldParts.COLLECTIBLE_AWAKE_CHECK = COLLECTIBLE_AWAKE_CHECK
WorldParts.YIELD_EVERY = YIELD_EVERY
WorldParts.PROMPT_DISTANCE = PROMPT_DISTANCE
WorldParts.WHITE_HULL = WHITE_HULL
WorldParts.PALETTE = PALETTE
WorldParts.ACCENT_SYSTEM = ACCENT_SYSTEM
WorldParts.ACCENT_WARNING = ACCENT_WARNING
WorldParts.ACCENT_SECRET = ACCENT_SECRET
WorldParts.ACCENT_OK = ACCENT_OK
WorldParts.HULL_TRIM = HULL_TRIM
WorldParts.GLASS_COLOUR = GLASS_COLOUR
WorldParts.METAL = METAL
WorldParts.DARK_METAL = DARK_METAL
WorldParts.REGOLITH_LIGHT = REGOLITH_LIGHT
WorldParts.PANEL_CLEAN = PANEL_CLEAN
WorldParts.PANEL_DUSTY = PANEL_DUSTY
WorldParts.LINK_RED = LINK_RED
WorldParts.LINK_GREEN = LINK_GREEN
WorldParts.STORM_AMBER = STORM_AMBER
WorldParts.STORM_RED = STORM_RED
WorldParts.LAMP_OFF = LAMP_OFF
WorldParts.ICE_GLOW = ICE_GLOW
WorldParts.MARKER_GUIDE = MARKER_GUIDE
WorldParts.MARKER_SHELTER = MARKER_SHELTER
WorldParts.GROW_PINK = GROW_PINK
WorldParts.GROW_DIM = GROW_DIM
WorldParts.PLANT_GREEN = PLANT_GREEN
WorldParts.PLANT_GREY = PLANT_GREY
WorldParts.AIR_OK = AIR_OK
WorldParts.AIR_WINDOW_ON = AIR_WINDOW_ON
WorldParts.AIR_WINDOW_HIGH = AIR_WINDOW_HIGH
WorldParts.AIR_WINDOW_OFF = AIR_WINDOW_OFF
WorldParts.CHEESE_PAINT = CHEESE_PAINT
WorldParts.CHEESE_SPOT = CHEESE_SPOT
WorldParts.MARS_RED = MARS_RED
WorldParts.INTERIOR_LIGHT = INTERIOR_LIGHT
WorldParts.WATER_COLOUR = WATER_COLOUR
WorldParts.WATER_TWEEN = WATER_TWEEN
WorldParts.GROW_BRIGHTNESS = GROW_BRIGHTNESS
WorldParts.GROW_RANGE = GROW_RANGE
WorldParts.FAN_SPEED_RAD = FAN_SPEED_RAD
WorldParts.AIR_PULSE_PERIOD = AIR_PULSE_PERIOD
WorldParts.ROVER_SPEED = ROVER_SPEED
WorldParts.ROVER_LOOP_RADIUS = ROVER_LOOP_RADIUS
WorldParts.ROVER_RIM_RADIUS = ROVER_RIM_RADIUS
WorldParts.PULSE_UPDATE_SECONDS = PULSE_UPDATE_SECONDS
WorldParts.SILO_CENTRE = SILO_CENTRE
WorldParts.SILO_GLASS_HEIGHT = SILO_GLASS_HEIGHT
WorldParts.SILO_GLASS_DIAMETER = SILO_GLASS_DIAMETER
WorldParts.CARGO_DOCK = CARGO_DOCK
WorldParts.CARGO_RIDE_HEIGHT = CARGO_RIDE_HEIGHT
WorldParts.CARGO_SPEED = CARGO_SPEED
WorldParts.CARGO_WAIT_SECONDS = CARGO_WAIT_SECONDS
WorldParts.DRILL_FLOOR_RADIUS = DRILL_FLOOR_RADIUS
WorldParts.DRILL_SPREAD = DRILL_SPREAD
WorldParts.DRILL_PAD_RADIUS = DRILL_PAD_RADIUS
WorldParts.HOPPER_RADIUS = HOPPER_RADIUS
WorldParts.CONVEYOR_FOOT_RADIUS = CONVEYOR_FOOT_RADIUS
WorldParts.DRILL_SPIN_RAD = DRILL_SPIN_RAD
WorldParts.DRILL_AWAKE_RANGE = DRILL_AWAKE_RANGE
WorldParts.ICE_CUBE_COUNT = ICE_CUBE_COUNT
WorldParts.ICE_CUBE_SPEED = ICE_CUBE_SPEED
WorldParts.SPIN_UPDATE_SECONDS = SPIN_UPDATE_SECONDS
WorldParts.RISE_SECONDS = RISE_SECONDS
WorldParts.RISE_DROP = RISE_DROP
WorldParts.UPGRADE_DROP = UPGRADE_DROP
WorldParts.HOLOGRAM_TRANSPARENCY = HOLOGRAM_TRANSPARENCY
WorldParts.HOLOGRAM_MIN_PART = HOLOGRAM_MIN_PART
WorldParts.PAD_DIAMETER = PAD_DIAMETER
WorldParts.PAD_HEIGHT = PAD_HEIGHT
WorldParts.PAD_RING_DIAMETER = PAD_RING_DIAMETER
WorldParts.PAD_MAXED_DIAMETER = PAD_MAXED_DIAMETER
WorldParts.BUILD_PROMPT_HOLD = BUILD_PROMPT_HOLD
WorldParts.SILO_TWEEN = SILO_TWEEN
WorldParts.MARKER_NAMES = MARKER_NAMES
WorldParts.CONSTRUCTION_DROP = CONSTRUCTION_DROP
WorldParts.OUTLINE_MAX_SPAN = OUTLINE_MAX_SPAN
WorldParts.CARRY_CRATE_NAME = CARRY_CRATE_NAME
WorldParts.MIN_LEVEL_ATTRIBUTE = MIN_LEVEL_ATTRIBUTE
WorldParts.buildState = buildState
WorldParts.counted = counted
WorldParts.finish = finish
WorldParts.part = part
WorldParts.wedge = wedge
WorldParts.ball = ball
WorldParts.cylinder = cylinder
WorldParts.vcylinder = vcylinder
WorldParts.zcylinder = zcylinder
WorldParts.box = box
WorldParts.folder = folder
WorldParts.model = model
WorldParts.pointLight = pointLight
WorldParts.makePrompt = makePrompt
WorldParts.zone = zone
WorldParts.weldTo = weldTo
WorldParts.markerPart = markerPart
WorldParts.UPGRADE_ATTRIBUTE = UPGRADE_ATTRIBUTE
WorldParts.ALPHA_ATTRIBUTE = ALPHA_ATTRIBUTE
WorldParts.NO_RISE_ATTRIBUTE = NO_RISE_ATTRIBUTE
WorldParts.upgrade = upgrade
WorldParts.belt = belt
WorldParts.pipe = pipe
WorldParts.dirFromAngle = dirFromAngle
WorldParts.flatUnit = flatUnit
WorldParts.regolith = regolith
WorldParts.CHEESE_NICHE_OFFSET = CHEESE_NICHE_OFFSET
WorldParts.GLASS = GLASS
WorldParts.angleGap = angleGap
WorldParts.roverSideAngle = roverSideAngle

return WorldParts
