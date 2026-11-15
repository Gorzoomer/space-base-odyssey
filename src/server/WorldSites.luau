--!strict
-- Space Base Odyssey - Stage 7 world sites: the Lab, the rover garage, the landing pad and the ship
-- (build models), five exploration sites with scan points, and fresh meteorite impacts.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.
--
-- Contract (world-core registers the build models into its build machinery):
--   WorldSites.build(baseFolder, helpers?) -> Sites
--   Sites.builds.<id> = { model, padPosition } for lab, garage, landing_pad and ship. Each model is
--     fully built (every part visible). Garage bay 2 parts carry the attribute SBO_MinLevel = 2.
--     padPosition.Y is the bottom of the build pad (the ship's pad stands on the landing pad surface).
--   Sites.labPrompt: ProximityPrompt "LabPrompt" (TextKey "prompt.lab"), disabled until world-core
--     enables it when the lab is built. It sits on the kiosk screen beside the lab door.
--   Sites.labDock: CFrame at the outer face of the lab's docking collar; LookVector points out toward
--     the habitat. The habitat tube corridor attaches here (tube diameter up to LAB_DOCK_DIAMETER).
--   Sites.garageBays: two CFrames on the garage bay floors, facing out of the doors (-X).
--   Sites.pois: { id, position, prompt } for the five exploration sites. The prompt ("ScanPrompt",
--     TextKey "prompt.scan", ObjectKey "poi.<id>.name", hold 1.5) is enabled; its part has PoiId.
--   Sites.impacts: the Workspace.Base.Impacts folder. spawnImpact(groundPoint) builds a fresh small
--     crater there (flash, dust, glowing rock that cools) and returns (model, prompt); the model and
--     the rock carry ImpactId. clearImpact(model) fades it out and destroys it.
--   Sites.keepouts: circles { x, z, r } that random boulders and craters must avoid.
-- All numbers here are visual layout and animation tuning (not gameplay or science numbers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local Theme = require(Shared:WaitForChild("Theme"))

export type BuildSite = { model: Model, padPosition: Vector3 }
export type PoiRef = { id: string, position: Vector3, prompt: ProximityPrompt }
export type Keepout = { x: number, z: number, r: number }
export type Sites = {
	builds: { [string]: BuildSite },
	labPrompt: ProximityPrompt,
	labDock: CFrame,
	garageBays: { CFrame },
	pois: { PoiRef },
	impacts: Folder,
	spawnImpact: (position: Vector3) -> (Model, ProximityPrompt),
	clearImpact: (impact: Model) -> (),
	keepouts: { Keepout },
}
-- onPart runs for every part made during build (world-core can pass its own counter, which yields).
export type Helpers = { onPart: ((part: BasePart) -> ())? }

type Style = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	shadow: boolean?,
}

local WorldSites = {}

------------------------------------------------------------------------------------------------
-- Layout (studs; ground top Y = 0; +Z points to the crater)
------------------------------------------------------------------------------------------------

local HABITAT_CENTRE = Vector3.new(0, 0, 0)
local LAB_CENTRE = Vector3.new(-55, 0, -35)
local LAB_PAD = Vector3.new(-70, 0, -18)
local GARAGE_CENTRE = Vector3.new(95, 0, 75)
local GARAGE_PAD = Vector3.new(70, 0, 44) -- in front of bay 1, clear of the larger bays
local LANDING_PAD_CENTRE = Vector3.new(-110, 0, -180)
local LANDING_PAD_RADIUS = 28

local SITE_ORDER = { "old_lander", "impact_crater", "boulder_tracks", "prospector_crash", "sun_peak" }
local SITE_POSITIONS: { [string]: Vector3 } = {
	old_lander = Vector3.new(330, 0, 260),
	impact_crater = Vector3.new(-380, 0, 280),
	boulder_tracks = Vector3.new(400, 0, -230),
	prospector_crash = Vector3.new(-220, 0, -360),
	sun_peak = Vector3.new(160, 0, 430),
}

-- Lab: a round module of LAB_SEGMENTS flat wall panels; panel 0 (the door) faces +Z.
local LAB_SEGMENTS = 16
local LAB_RADIUS = 12 -- outer wall
local LAB_FOUNDATION_DIAMETER = 28
local LAB_FLOOR_TOP = 1.15
local LAB_WALL_BOTTOM = 1
local LAB_WALL_TOP = 11
local LAB_DOOR_TOP = 8.2
local LAB_WINDOW_BOTTOM = 6.2
local LAB_WINDOW_TOP = 8.6
local LAB_DOCK_HEIGHT = 5.6 -- centre of the docking collar above the ground
local LAB_DOCK_DIAMETER = 7.8
local LAB_PROMPT_HOLD = 0
local LAB_PROMPT_DISTANCE = 10

-- Garage: two arched bays side by side along Z, doors facing -X (the road to the crater).
local GARAGE_FRONT_X = GARAGE_CENTRE.X - 12
local GARAGE_BACK_X = GARAGE_CENTRE.X + 12
local BAY_OFFSETS = { -14, 14 } -- bay centres along Z from the garage centre (bays 27 wide)
local BAY_RADIUS = 13.5 -- outer radius of the arch shell (the ice hauler with its dish is about 11 tall)
local BAY_ARCH_SEGMENTS = 9
local BAY_FLOOR_TOP = 0.3
local BAY_DOOR_HALF_WIDTH = 6.6
local BAY_DOOR_TOP = 10.4 -- under the arch at the door posts; the hauler cab and dish pass below

-- Landing pad and ship.
local LANDING_PAD_TOP = 0.7 -- the sintered pad surface the ship's feet stand on
local BERM_SEGMENTS = 20
local BERM_INNER = 31
local BERM_DEPTH = 8
local BERM_HEIGHT = 4
local EDGE_LIGHTS = 12
local SHIP_PAD_RADIUS = 19 -- the ship's build pad on the landing pad, on the road side

-- Exploration and impacts.
local SCAN_HOLD = 1.5
local SCAN_DISTANCE = 12
local IMPACT_FLASH_SECONDS = 0.5
local IMPACT_DUST_SECONDS = 1.6
local IMPACT_COOL_SECONDS = 20
local IMPACT_GLOW_SECONDS = 8 -- the rock stops glowing (Neon) after this, then keeps cooling to grey
local IMPACT_FADE_SECONDS = 1
local IMPACT_DUST_PARTICLES = 80

local YIELD_EVERY = 40

------------------------------------------------------------------------------------------------
-- Palette (Theme "Lunar Sunrise"; the Moon itself stays grey)
------------------------------------------------------------------------------------------------

local PALETTE = Theme.PALETTE
local ACCENT = Theme.ROLE.accent
local WARNING = Theme.ROLE.warning
local GOOD = Theme.ROLE.good
local REWARD = Theme.ROLE.reward
local STAR = Theme.ROLE.star
local NIGHT = PALETTE.night
local NIGHT_LIGHT = PALETTE.nightLight
local CREAM = PALETTE.cream

local WHITE_HULL = Color3.fromRGB(226, 228, 232)
local HULL_SHADE = Color3.fromRGB(206, 209, 214)
local METAL = Color3.fromRGB(150, 155, 162)
local DARK_METAL = Color3.fromRGB(70, 74, 82)
local ENGINE_DARK = Color3.fromRGB(48, 50, 56)
local CONCRETE = Color3.fromRGB(104, 102, 99)
local SINTER = Color3.fromRGB(90, 88, 86) -- regolith baked hard into a pad
local SINTER_DARK = Color3.fromRGB(78, 76, 74)
local BERM_COLOUR = Color3.fromRGB(124, 121, 116)
local GLASS_COLOUR = Color3.fromRGB(255, 214, 160)
local INTERIOR_LIGHT = Color3.fromRGB(255, 238, 214)
local PANEL_BLUE = Color3.fromRGB(30, 56, 128)
local FOIL_GOLD = PALETTE.gold:Lerp(Color3.fromRGB(150, 100, 20), 0.3)
local REGOLITH = Color3.fromRGB(128, 127, 123)
local REGOLITH_BRIGHT = Color3.fromRGB(190, 188, 182) -- fresh ejecta is brighter than old ground
local RAY_BRIGHT = Color3.fromRGB(212, 210, 204)
local REGOLITH_DARK = Color3.fromRGB(100, 98, 95)
local SHADOW_FLOOR = Color3.fromRGB(56, 58, 64)
local DENT_COLOUR = Color3.fromRGB(92, 90, 87)
local ROCK = Color3.fromRGB(106, 104, 100)
local SUNLIT_ROCK = Color3.fromRGB(186, 183, 175)
local ICE_COLOUR = Color3.fromRGB(196, 214, 230)
local HOT_ROCK = WARNING
local COOL_ROCK = Color3.fromRGB(112, 110, 106)

local GLASS: Style = { color = GLASS_COLOUR, material = Enum.Material.Glass, transparency = 0.4, shadow = false }
local HULL: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
local METAL_STYLE: Style = { color = METAL, material = Enum.Material.Metal }
local DARK_STYLE: Style = { color = DARK_METAL, material = Enum.Material.Metal }

local function neon(color: Color3): Style
	return { color = color, material = Enum.Material.Neon, shadow = false, collide = false }
end

local function flat(color: Color3, material: Enum.Material?): Style
	-- Flat ground decoration: no collisions (players walk on the ground under it) and no queries
	-- (ground raycasts for meteor spots pass through it).
	return { color = color, material = material or Enum.Material.Sand, shadow = false, collide = false }
end

------------------------------------------------------------------------------------------------
-- Part helpers (own copies: no dependency on WorldBuilder internals)
------------------------------------------------------------------------------------------------

local building = false
local partHook: ((BasePart) -> ())? = nil
local partCount = 0

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
	if building then
		local hook = partHook
		if hook then
			hook(p)
		else
			partCount += 1
			if partCount % YIELD_EVERY == 0 then
				task.wait()
			end
		end
	end
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

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ALONG_LOOK = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis onto a lookAt frame's look

-- Upright cylinder centred on `centre`.
local function vcyl(parent: Instance, name: string, height: number, diameter: number, centre: Vector3, style: Style): Part
	return cylinder(parent, name, height, diameter, CFrame.new(centre) * UPRIGHT, style)
end

-- Upright disc lying on the ground at `ground` with its top at ground.Y + top.
local function disc(parent: Instance, name: string, diameter: number, ground: Vector3, top: number, style: Style): Part
	return vcyl(parent, name, top, diameter, ground + Vector3.new(0, top / 2, 0), style)
end

-- Axis-aligned box given by two corners.
local function box(parent: Instance, name: string, a: Vector3, b: Vector3, style: Style): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	return part(parent, name, maxV - minV, CFrame.new((minV + maxV) / 2), style)
end

-- A cylinder from a to b (an upright one when a -> b is vertical, where lookAt has no clear "up").
local function pipe(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, style: Style): Part
	local span = b - a
	local length = span.Magnitude
	if math.abs(span.Unit.Y) > 0.999 then
		return cylinder(parent, name, length, diameter, CFrame.new((a + b) / 2) * UPRIGHT, style)
	end
	return cylinder(parent, name, length, diameter, CFrame.lookAt((a + b) / 2, b) * ALONG_LOOK, style)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function pointLight(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

local function dirFromAngle(angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

-- Horizontal unit vector at a right angle to dirFromAngle(angle).
local function sideFromAngle(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, -math.sin(angle))
end

local function angleOf(v: Vector3): number
	return math.atan2(v.X, v.Z)
end

local function angleGap(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	return math.min(d, 2 * math.pi - d)
end

local function flatUnit(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return Vector3.zAxis
	end
	return f.Unit
end

-- A flat panel at `centre` whose front (-Z) faces `outward` (horizontal).
local function facing(centre: Vector3, outward: Vector3): CFrame
	return CFrame.lookAt(centre, centre + outward)
end

-- A dark panel showing one Tabler icon on its front face, tinted with a Theme colour.
local function iconSign(parent: Instance, name: string, size: Vector3, cf: CFrame, icon: string, tint: Color3): Part
	local p = part(parent, name, size, cf, { color = NIGHT })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Icon"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(100, 100)
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(0.8, 0.8)
	image.Position = UDim2.fromScale(0.1, 0.1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = icon
	image.ImageColor3 = tint
	image.Parent = gui
	gui.Parent = p
	return p
end

local function rock(parent: Instance, name: string, ground: Vector3, size: number, seed: number, color: Color3): Part
	local rng = Random.new(seed)
	return part(
		parent,
		name,
		Vector3.new(size, size * rng:NextNumber(0.55, 0.85), size * rng:NextNumber(0.8, 1.2)),
		CFrame.new(ground + Vector3.new(0, size * 0.22, 0))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4)),
		{ color = color, material = Enum.Material.Rock }
	)
end

-- A crater with a raised rim on flat ground: each rim segment is an outer wedge (low side out) and an
-- inner wedge (low side in) meeting at the crest. gapAngle leaves one opening to walk in.
type CraterSpec = {
	centre: Vector3,
	crest: number,
	height: number,
	outSlope: number,
	inSlope: number,
	segments: number,
	outColor: Color3,
	inColor: Color3,
	material: Enum.Material,
	gapAngle: number?,
	collide: boolean?,
}

local function raisedCrater(parent: Instance, name: string, spec: CraterSpec)
	local step = 2 * math.pi / spec.segments
	local halfTan = math.tan(step / 2)
	local up = Vector3.new(0, spec.height / 2, 0)
	for k = 0, spec.segments - 1 do
		local angle = k * step
		local gap = spec.gapAngle
		if gap ~= nil and angleGap(angle, gap) < step * 0.75 then
			continue
		end
		local n = dirFromAngle(angle)
		local outPos = spec.centre + n * (spec.crest + spec.outSlope / 2) + up
		wedge(
			parent,
			name .. "Out",
			Vector3.new(2 * (spec.crest + spec.outSlope) * halfTan + 0.3, spec.height, spec.outSlope),
			CFrame.lookAt(outPos, outPos + n),
			{ color = spec.outColor, material = spec.material, collide = spec.collide }
		)
		local inPos = spec.centre + n * (spec.crest - spec.inSlope / 2) + up
		wedge(
			parent,
			name .. "In",
			Vector3.new(2 * spec.crest * halfTan + 0.3, spec.height, spec.inSlope),
			CFrame.lookAt(inPos, inPos - n),
			{ color = spec.inColor, material = spec.material, collide = spec.collide }
		)
	end
end

-- Survey post with a glowing head: the scan point of an exploration site.
local function scanMarker(parent: Instance, id: string, ground: Vector3): (BasePart, ProximityPrompt)
	local m = model(parent, "ScanPoint")
	disc(m, "Base", 2.6, ground, 0.4, DARK_STYLE)
	for i = 0, 2 do
		local foot = ground + dirFromAngle(i * 2 * math.pi / 3) * 1.7 + Vector3.new(0, 0.1, 0)
		pipe(m, "Leg", foot, ground + Vector3.new(0, 2.6, 0), 0.22, METAL_STYLE)
	end
	vcyl(m, "Pole", 3.6, 0.36, ground + Vector3.new(0, 2.2, 0), METAL_STYLE)
	vcyl(m, "Ring", 0.3, 1.9, ground + Vector3.new(0, 3.85, 0), neon(ACCENT))
	local head = box(m, "ScanHead", ground + Vector3.new(-0.7, 4, -0.7), ground + Vector3.new(0.7, 5, 0.7), { color = NIGHT })
	vcyl(m, "Lens", 0.2, 0.9, ground + Vector3.new(0, 5.1, 0), neon(ACCENT))
	head:SetAttribute("PoiId", id)
	pointLight(head, ACCENT, 10, 0.8)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScanPrompt"
	prompt.ActionText = "Scan"
	prompt.ObjectText = ""
	prompt.HoldDuration = SCAN_HOLD
	prompt.MaxActivationDistance = SCAN_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt:SetAttribute("TextKey", "prompt.scan")
	prompt:SetAttribute("ObjectKey", `poi.{id}.name`)
	prompt.Parent = head
	return head, prompt
end

------------------------------------------------------------------------------------------------
-- Lab: a white round module with windows, a workbench with the team's tools and an upgrade station
------------------------------------------------------------------------------------------------

local function buildLab(parent: Instance): (Model, ProximityPrompt, CFrame)
	local m = model(parent, "Lab")
	local c = LAB_CENTRE
	local function at(x: number, y: number, z: number): Vector3
		return c + Vector3.new(x, y, z)
	end

	disc(m, "Foundation", LAB_FOUNDATION_DIAMETER, c, LAB_WALL_BOTTOM, { color = CONCRETE, material = Enum.Material.Concrete })
	vcyl(m, "FoundationGlow", 0.2, LAB_FOUNDATION_DIAMETER + 0.6, at(0, 0.5, 0), neon(ACCENT))
	vcyl(m, "Floor", 0.2, (LAB_RADIUS - 0.7) * 2, at(0, LAB_FLOOR_TOP - 0.1, 0), { color = NIGHT_LIGHT })

	-- Walls: flat panels around the circle; odd panels have a window band.
	local step = 2 * math.pi / LAB_SEGMENTS
	local width = 2 * LAB_RADIUS * math.tan(step / 2) + 0.15
	local centreRadius = LAB_RADIUS - 0.5
	local hubAngle = angleOf(HABITAT_CENTRE - c)
	local dockSegment = math.floor(hubAngle / step + 0.5) % LAB_SEGMENTS
	for k = 0, LAB_SEGMENTS - 1 do
		local angle = k * step
		local n = dirFromAngle(angle)
		local function wall(name: string, y0: number, y1: number, style: Style): Part
			local pos = c + n * centreRadius + Vector3.new(0, (y0 + y1) / 2, 0)
			return part(m, name, Vector3.new(width, y1 - y0, 1), facing(pos, n), style)
		end
		if k == 0 then
			wall("DoorLintel", LAB_DOOR_TOP, LAB_WALL_TOP, HULL)
			local t = sideFromAngle(angle)
			for s = -1, 1, 2 do
				local pos = c + n * (centreRadius + 0.1) + t * (s * (width / 2 - 0.25)) + Vector3.new(0, (LAB_WALL_BOTTOM + LAB_DOOR_TOP) / 2, 0)
				part(m, "DoorFrame", Vector3.new(0.5, LAB_DOOR_TOP - LAB_WALL_BOTTOM, 1.2), facing(pos, n), neon(ACCENT))
			end
			local stepPos = c + n * (LAB_FOUNDATION_DIAMETER / 2 + 0.7) + Vector3.new(0, 0.25, 0)
			part(m, "DoorStep", Vector3.new(4, 0.5, 1.6), facing(stepPos, n), { color = CONCRETE, material = Enum.Material.Concrete })
		elseif k == dockSegment then
			wall("DockWall", LAB_WALL_BOTTOM, LAB_WALL_TOP, HULL)
		elseif k % 2 == 1 then
			wall("Wall", LAB_WALL_BOTTOM, LAB_WINDOW_BOTTOM, HULL)
			wall("Window", LAB_WINDOW_BOTTOM, LAB_WINDOW_TOP, GLASS)
			wall("WallTop", LAB_WINDOW_TOP, LAB_WALL_TOP, HULL)
		else
			wall("Wall", LAB_WALL_BOTTOM, LAB_WALL_TOP, { color = HULL_SHADE, material = Enum.Material.SmoothPlastic })
		end
	end

	-- Roof: a shallow stepped dome with a glowing rim, a skylight, a radiator and a beacon mast.
	vcyl(m, "Roof", 0.8, LAB_RADIUS * 2 + 1, at(0, LAB_WALL_TOP + 0.4, 0), HULL)
	vcyl(m, "RoofGlow", 0.25, LAB_RADIUS * 2 + 1.5, at(0, LAB_WALL_TOP + 0.2, 0), neon(ACCENT))
	vcyl(m, "RoofDome", 1, 20, at(0, LAB_WALL_TOP + 1.3, 0), HULL)
	vcyl(m, "RoofCap", 1, 13, at(0, LAB_WALL_TOP + 2.3, 0), HULL)
	vcyl(m, "Skylight", 0.2, 6, at(0, LAB_WALL_TOP + 2.85, 0), GLASS)
	box(m, "Radiator", at(2, LAB_WALL_TOP + 1.8, -8), at(7, LAB_WALL_TOP + 2.1, -4), METAL_STYLE)
	vcyl(m, "Mast", 4, 0.3, at(-5, LAB_WALL_TOP + 3.8, 4), METAL_STYLE)
	ball(m, "MastBeacon", 0.8, at(-5, LAB_WALL_TOP + 6, 4), neon(WARNING))
	local ceiling = vcyl(m, "CeilingLight", 0.2, 6, at(0, LAB_WALL_TOP - 0.1, 0), neon(INTERIOR_LIGHT))
	pointLight(ceiling, INTERIOR_LIGHT, 26, 1.2)

	-- Workbench on the back wall (opposite the door), with the tools the Lab improves.
	local top = 4.5
	box(m, "BenchTop", at(-4, top - 0.4, -9.9), at(4, top, -7.3), METAL_STYLE)
	box(m, "BenchLeg", at(-3.8, LAB_FLOOR_TOP, -9.6), at(-3.2, top - 0.4, -7.6), DARK_STYLE)
	box(m, "BenchCabinet", at(1.5, LAB_FLOOR_TOP, -9.7), at(3.7, top - 0.4, -7.5), { color = NIGHT_LIGHT })
	box(m, "CabinetHandle", at(2.2, 3.2, -7.5), at(3.0, 3.35, -7.4), neon(ACCENT))
	-- wrench
	box(m, "WrenchHandle", at(-3.4, top, -8.9), at(-1.6, top + 0.25, -8.5), METAL_STYLE)
	box(m, "WrenchHead", at(-1.7, top, -9.1), at(-1.1, top + 0.25, -8.3), METAL_STYLE)
	-- ice drill
	cylinder(m, "DrillBody", 1.6, 0.8, CFrame.new(at(-0.2, top + 0.45, -8.6)), { color = WARNING })
	cylinder(m, "DrillBit", 1.4, 0.28, CFrame.new(at(1.3, top + 0.45, -8.6)), METAL_STYLE)
	box(m, "DrillGrip", at(-0.7, top, -8.8), at(-0.3, top + 0.1, -8.4), DARK_STYLE)
	-- tablet on a little stand, screen toward the room
	local tabletCf = CFrame.new(at(3, top + 0.55, -9.4)) * CFrame.Angles(math.rad(-15), 0, 0)
	part(m, "Tablet", Vector3.new(1.4, 1, 0.12), tabletCf, { color = NIGHT })
	part(m, "TabletScreen", Vector3.new(1.2, 0.8, 0.04), tabletCf * CFrame.new(0, 0, 0.08), neon(ACCENT))
	-- repair kit on the floor beside the bench
	box(m, "RepairKit", at(-6.2, LAB_FLOOR_TOP, -8.6), at(-4.6, LAB_FLOOR_TOP + 0.95, -7.4), { color = WARNING })
	box(m, "RepairKitStripe", at(-6.25, LAB_FLOOR_TOP + 0.4, -8.65), at(-4.55, LAB_FLOOR_TOP + 0.6, -7.35), { color = CREAM })
	-- pegboard with the panel brush and a spare wrench
	box(m, "Pegboard", at(-4, 5.4, -10.75), at(4, 8.2, -10.45), { color = NIGHT_LIGHT })
	box(m, "PegboardLight", at(-4, 8.3, -10.7), at(4, 8.5, -10.5), neon(ACCENT))
	box(m, "BrushHandle", at(-3, 6, -10.45), at(-2.7, 7.8, -10.2), { color = PALETTE.creamDim })
	box(m, "BrushHead", at(-3.5, 5.6, -10.45), at(-2.2, 6.1, -10.15), { color = GOOD })
	box(m, "SpareWrench", at(2.4, 5.8, -10.45), at(2.8, 7.8, -10.25), METAL_STYLE)

	-- Upgrade station in the middle: a pedestal with a glowing ring and a floating holo ring.
	vcyl(m, "Station", 2.2, 3, at(0, LAB_FLOOR_TOP + 1.1, 0), { color = NIGHT })
	vcyl(m, "StationRing", 0.2, 3.4, at(0, LAB_FLOOR_TOP + 2.1, 0), neon(GOOD))
	ball(m, "HoloCore", 0.9, at(0, LAB_FLOOR_TOP + 3.3, 0), neon(ACCENT))
	vcyl(m, "HoloRing", 0.12, 3.6, at(0, LAB_FLOOR_TOP + 4.2, 0), {
		color = ACCENT,
		material = Enum.Material.ForceField,
		transparency = 0.2,
		shadow = false,
		collide = false,
	})

	-- Sample shelf on the west wall with coloured flasks.
	box(m, "ShelfBack", at(-10.6, LAB_FLOOR_TOP, -2.5), at(-10.3, 6, 2.5), { color = NIGHT_LIGHT })
	for i, y in { 2.2, 3.7, 5.2 } do
		box(m, "Shelf" .. i, at(-10.3, y, -2.5), at(-9.1, y + 0.2, 2.5), METAL_STYLE)
	end
	local flasks: { { y: number, z: number, color: Color3 } } = {
		{ y = 2.4, z = -1.5, color = REWARD },
		{ y = 2.4, z = 0.5, color = ACCENT },
		{ y = 3.9, z = -0.5, color = GOOD },
		{ y = 3.9, z = 1.6, color = STAR },
	}
	for _, f in flasks do
		vcyl(m, "Flask", 1, 0.6, at(-9.7, f.y + 0.5, f.z), {
			color = f.color,
			material = Enum.Material.Glass,
			transparency = 0.25,
			shadow = false,
		})
	end

	-- Docking collar facing the habitat: the tube corridor from the hub attaches here.
	local dockAngle = dockSegment * step
	local dn = dirFromAngle(dockAngle)
	local function dockCf(radius: number): CFrame
		local pos = c + dn * radius + Vector3.new(0, LAB_DOCK_HEIGHT, 0)
		return CFrame.lookAt(pos, pos + dn) * ALONG_LOOK
	end
	cylinder(m, "DockCollar", 2.6, LAB_DOCK_DIAMETER - 0.8, dockCf(LAB_RADIUS + 1), METAL_STYLE)
	cylinder(m, "DockRing", 0.6, LAB_DOCK_DIAMETER, dockCf(LAB_RADIUS + 2), { color = ACCENT })
	cylinder(m, "DockHatch", 0.2, 5, dockCf(LAB_RADIUS + 2.4), DARK_STYLE)
	cylinder(m, "InnerHatch", 0.2, 5, dockCf(LAB_RADIUS - 1.1), DARK_STYLE)
	local dockPos = c + dn * (LAB_RADIUS + 2.5) + Vector3.new(0, LAB_DOCK_HEIGHT, 0)
	local labDock = CFrame.lookAt(dockPos, dockPos + dn)

	-- Sign over the door and the kiosk that opens the Lab.
	local doorN = dirFromAngle(0)
	iconSign(m, "LabSign", Vector3.new(3.4, 2.2, 0.3), facing(c + doorN * (LAB_RADIUS + 0.25) + Vector3.new(0, 9.7, 0), doorN), Icons.flask, ACCENT)
	part(m, "LabSignGlow", Vector3.new(3.4, 0.2, 0.25), facing(c + doorN * (LAB_RADIUS + 0.2) + Vector3.new(0, 8.45, 0), doorN), neon(ACCENT))
	local kioskAngle = step * 1.3
	local kn = dirFromAngle(kioskAngle)
	local kioskBase = c + kn * (LAB_RADIUS + 1.3)
	part(m, "KioskPost", Vector3.new(0.8, 3.2, 0.6), facing(kioskBase + Vector3.new(0, LAB_WALL_BOTTOM + 1.6, 0), kn), { color = NIGHT_LIGHT })
	local screen = part(
		m,
		"LabKiosk",
		Vector3.new(1.8, 1.2, 0.3),
		facing(kioskBase + Vector3.new(0, LAB_WALL_BOTTOM + 3.6, 0), kn) * CFrame.Angles(math.rad(20), 0, 0),
		neon(ACCENT)
	)
	screen.CanCollide = true -- solid so players do not walk through the kiosk
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LabPrompt"
	prompt.ActionText = "Open the Lab"
	prompt.ObjectText = ""
	prompt.HoldDuration = LAB_PROMPT_HOLD
	prompt.MaxActivationDistance = LAB_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("TextKey", "prompt.lab")
	prompt:SetAttribute("ObjectKey", "build.lab.name")
	prompt.Parent = screen

	-- Supply crates on the west side (away from the corridor).
	box(m, "Crate", at(-14.2, 0, 7), at(-12, 2.2, 9.2), { color = WARNING })
	box(m, "CrateBand", at(-14.25, 0.9, 7), at(-11.95, 1.3, 9.2), DARK_STYLE)
	box(m, "Crate", at(-14.6, 0, 9.8), at(-12.4, 2.2, 12), HULL)

	return m, prompt, labDock
end

------------------------------------------------------------------------------------------------
-- Garage: two arched vehicle bays; bay 2 (SBO_MinLevel = 2) opens at garage level 2
------------------------------------------------------------------------------------------------

local MIN_LEVEL_ATTRIBUTE = "SBO_MinLevel"

local function buildBay(parent: Instance, index: number, zc: number): (Model, CFrame)
	local bay = model(parent, "Bay" .. index)
	local x0 = GARAGE_FRONT_X
	local x1 = GARAGE_BACK_X
	local mx = (x0 + x1) / 2
	local depth = x1 - x0

	box(bay, "Floor", Vector3.new(x0, 0, zc - (BAY_RADIUS - 0.6)), Vector3.new(x1, BAY_FLOOR_TOP, zc + (BAY_RADIUS - 0.6)), {
		color = CONCRETE,
		material = Enum.Material.Concrete,
	})
	box(bay, "Apron", Vector3.new(x0 - 12, 0, zc - 7), Vector3.new(x0, BAY_FLOOR_TOP, zc + 7), {
		color = SINTER,
		material = Enum.Material.Concrete,
	})

	-- Arch shell (half circle of flat panels) with a cyan front rib and a dark back rib.
	local stepA = math.pi / BAY_ARCH_SEGMENTS
	local shellRadius = BAY_RADIUS - 0.5
	local segLength = 2 * BAY_RADIUS * math.tan(stepA / 2) + 0.2
	local ribRadius = BAY_RADIUS + 0.1
	local ribLength = 2 * (ribRadius + 0.6) * math.tan(stepA / 2) + 0.2
	for i = 0, BAY_ARCH_SEGMENTS - 1 do
		local theta = (i + 0.5) * stepA
		local turn = CFrame.Angles(math.pi / 2 - theta, 0, 0)
		local y = math.sin(theta)
		local z = math.cos(theta)
		part(bay, "Arch", Vector3.new(depth, 1, segLength), CFrame.new(mx, shellRadius * y, zc + shellRadius * z) * turn, {
			color = if i % 2 == 0 then WHITE_HULL else HULL_SHADE,
		})
		part(bay, "FrontRib", Vector3.new(1.2, 1.2, ribLength), CFrame.new(x0 + 0.5, ribRadius * y, zc + ribRadius * z) * turn, {
			color = ACCENT,
		})
		part(bay, "BackRib", Vector3.new(1.2, 1.2, ribLength), CFrame.new(x1 - 0.5, ribRadius * y, zc + ribRadius * z) * turn, DARK_STYLE)
	end
	-- Back wall: a disc whose lower half is hidden in the ground, so it fills the half circle exactly.
	cylinder(bay, "BackWall", 1, (BAY_RADIUS - 0.6) * 2, CFrame.new(x1 - 1.2, 0, zc), METAL_STYLE)

	-- Door frame with a rolled-up door and a glowing strip.
	for s = -1, 1, 2 do
		box(bay, "DoorPost", Vector3.new(x0 + 0.2, BAY_FLOOR_TOP, zc + s * BAY_DOOR_HALF_WIDTH), Vector3.new(x0 + 1, BAY_DOOR_TOP, zc + s * (BAY_DOOR_HALF_WIDTH - 0.6)), DARK_STYLE)
	end
	box(bay, "DoorLintel", Vector3.new(x0 + 0.2, BAY_DOOR_TOP, zc - BAY_DOOR_HALF_WIDTH), Vector3.new(x0 + 1, BAY_DOOR_TOP + 0.8, zc + BAY_DOOR_HALF_WIDTH), DARK_STYLE)
	box(bay, "DoorGlow", Vector3.new(x0 - 0.05, BAY_DOOR_TOP - 0.3, zc - BAY_DOOR_HALF_WIDTH + 0.6), Vector3.new(x0 + 0.2, BAY_DOOR_TOP, zc + BAY_DOOR_HALF_WIDTH - 0.6), neon(ACCENT))
	cylinder(bay, "DoorRoll", 11.4, 0.9, CFrame.new(x0 + 1.6, BAY_DOOR_TOP + 0.5, zc) * ALONG_LOOK, METAL_STYLE)

	-- Hazard stripes across the entrance.
	for s = 0, 3 do
		local z0 = zc - 6 + s * 3
		box(bay, "Stripe", Vector3.new(x0 + 0.2, BAY_FLOOR_TOP, z0), Vector3.new(x0 + 1.4, BAY_FLOOR_TOP + 0.05, z0 + 3), flat(if s % 2 == 0 then WARNING else NIGHT, Enum.Material.SmoothPlastic))
	end
	-- Bay number as painted bars (one bar = bay 1, two bars = bay 2).
	for b = 1, index do
		local z0 = zc - 1.8 + (b - 1) * 1.4
		box(bay, "BayMark", Vector3.new(x1 - 6.6, BAY_FLOOR_TOP, z0), Vector3.new(x1 - 3, BAY_FLOOR_TOP + 0.05, z0 + 0.8), flat(GOOD, Enum.Material.SmoothPlastic))
	end

	-- Charging post at the back corner with a cable to the parking spot.
	local cz = zc + 5
	box(bay, "ChargerBase", Vector3.new(x1 - 3.7, BAY_FLOOR_TOP, cz - 0.7), Vector3.new(x1 - 2.3, BAY_FLOOR_TOP + 0.3, cz + 0.7), DARK_STYLE)
	box(bay, "ChargerPost", Vector3.new(x1 - 3.35, BAY_FLOOR_TOP + 0.3, cz - 0.35), Vector3.new(x1 - 2.65, 4.2, cz + 0.35), HULL)
	box(bay, "ChargerHead", Vector3.new(x1 - 3.6, 4.2, cz - 0.6), Vector3.new(x1 - 2.4, 5.4, cz + 0.6), { color = NIGHT })
	box(bay, "ChargerScreen", Vector3.new(x1 - 3.4, 4.5, cz - 0.7), Vector3.new(x1 - 2.6, 5.1, cz - 0.6), neon(GOOD))
	pipe(bay, "ChargerCable", Vector3.new(x1 - 3, 4.4, cz - 0.65), Vector3.new(x1 - 6, BAY_FLOOR_TOP + 0.15, cz - 2), 0.25, DARK_STYLE)

	-- Ceiling lamp.
	local lamp = box(bay, "Lamp", Vector3.new(mx - 2, BAY_RADIUS - 2.3, zc - 0.5), Vector3.new(mx + 2, BAY_RADIUS - 2, zc + 0.5), neon(INTERIOR_LIGHT))
	pointLight(lamp, INTERIOR_LIGHT, 22, 1.4)

	local spot = Vector3.new(mx, BAY_FLOOR_TOP, zc)
	return bay, CFrame.lookAt(spot, spot - Vector3.xAxis)
end

local function buildGarage(parent: Instance): (Model, { CFrame })
	local m = model(parent, "Garage")
	local bays: { CFrame } = {}
	for index, offset in BAY_OFFSETS do
		local bay, spot = buildBay(m, index, GARAGE_CENTRE.Z + offset)
		table.insert(bays, spot)
		if index >= 2 then
			for _, item in bay:GetDescendants() do
				if item:IsA("BasePart") then
					item:SetAttribute(MIN_LEVEL_ATTRIBUTE, index)
				end
			end
		end
	end

	-- Sign post between the two doors and a power unit behind the bays.
	local x0 = GARAGE_FRONT_X
	local zc = GARAGE_CENTRE.Z
	vcyl(m, "SignPole", 8, 0.5, Vector3.new(x0 - 1, 4, zc), DARK_STYLE)
	iconSign(m, "GarageSign", Vector3.new(2.8, 2.8, 0.3), facing(Vector3.new(x0 - 1.2, 9.4, zc), -Vector3.xAxis), Icons.car, ACCENT)
	local power = box(m, "PowerUnit", Vector3.new(GARAGE_BACK_X + 0.5, 0, zc - 3), Vector3.new(GARAGE_BACK_X + 3, 3, zc + 3), DARK_STYLE)
	box(m, "PowerLight", Vector3.new(GARAGE_BACK_X + 3, 2, zc - 2), Vector3.new(GARAGE_BACK_X + 3.1, 2.5, zc + 2), neon(GOOD))
	pointLight(power, GOOD, 8, 0.6)
	return m, bays
end

------------------------------------------------------------------------------------------------
-- Landing pad (sintered regolith, blast berm, lights) and the ship that stands on it
------------------------------------------------------------------------------------------------

local function accessDirection(): Vector3
	return flatUnit(HABITAT_CENTRE - LANDING_PAD_CENTRE)
end

local function buildLandingPad(parent: Instance): Model
	local m = model(parent, "LandingPad")
	local c = LANDING_PAD_CENTRE
	local diameter = LANDING_PAD_RADIUS * 2
	local sinter: Style = { color = SINTER, material = Enum.Material.Concrete }
	disc(m, "PadSurface", diameter, c, 0.6, sinter)
	disc(m, "PadRingPaint", diameter - 6, c, 0.65, { color = WARNING })
	disc(m, "PadInner", diameter - 9, c, LANDING_PAD_TOP, sinter)
	disc(m, "TargetPaint", 15, c, 0.75, { color = WARNING })
	disc(m, "TargetInner", 11, c, 0.8, { color = SINTER_DARK, material = Enum.Material.Concrete })
	for i = 0, 3 do
		local n = dirFromAngle(i * math.pi / 2)
		local pos = c + n * 11 + Vector3.new(0, LANDING_PAD_TOP + 0.03, 0)
		part(m, "Tick", Vector3.new(0.8, 0.06, 4), facing(pos, n), flat(CREAM, Enum.Material.SmoothPlastic))
	end

	-- Edge lights: cyan guide lights with an orange one every quarter.
	for i = 0, EDGE_LIGHTS - 1 do
		local n = dirFromAngle(i * 2 * math.pi / EDGE_LIGHTS)
		local colour = if i % 3 == 0 then WARNING else ACCENT
		local lightPart = part(m, "EdgeLight", Vector3.new(0.9, 0.4, 0.9), facing(c + n * (LANDING_PAD_RADIUS - 1.4) + Vector3.new(0, 0.8, 0), n), neon(colour))
		if i % 3 == 0 then
			pointLight(lightPart, colour, 12, 1)
		end
	end

	-- Blast berm: piled regolith with a steep face toward the pad, open toward the base road.
	local access = accessDirection()
	local accessAngle = angleOf(access)
	local step = 2 * math.pi / BERM_SEGMENTS
	local outer = BERM_INNER + BERM_DEPTH
	local bermWidth = 2 * outer * math.tan(step / 2) + 0.4
	for k = 0, BERM_SEGMENTS - 1 do
		local angle = k * step
		if angleGap(angle, accessAngle) < step * 0.8 then
			continue
		end
		local n = dirFromAngle(angle)
		local pos = c + n * (BERM_INNER + BERM_DEPTH / 2) + Vector3.new(0, BERM_HEIGHT / 2, 0)
		wedge(m, "Berm", Vector3.new(bermWidth, BERM_HEIGHT, BERM_DEPTH), CFrame.lookAt(pos, pos + n), {
			color = BERM_COLOUR,
			material = Enum.Material.Sand,
		})
	end

	-- Floodlight masts on both sides of the road opening.
	for s = -1, 1, 2 do
		local n = dirFromAngle(accessAngle + s * math.rad(26))
		local foot = c + n * (outer + 2)
		box(m, "MastBase", foot + Vector3.new(-0.9, 0, -0.9), foot + Vector3.new(0.9, 0.5, 0.9), DARK_STYLE)
		vcyl(m, "MastPole", 10, 0.6, foot + Vector3.new(0, 5.5, 0), METAL_STYLE)
		local headPos = foot + Vector3.new(0, 10.8, 0)
		local head = part(m, "Floodlight", Vector3.new(1.8, 1, 1.2), CFrame.lookAt(headPos, c), neon(INTERIOR_LIGHT))
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 60
		spot.Range = 55
		spot.Brightness = 1.5
		spot.Color = INTERIOR_LIGHT
		spot.Shadows = false
		spot.Parent = head
	end
	return m
end

local function buildShip(parent: Instance): Model
	local m = model(parent, "Ship")
	local o = Vector3.new(LANDING_PAD_CENTRE.X, LANDING_PAD_TOP, LANDING_PAD_CENTRE.Z)
	local function v(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	local white: Style = HULL

	-- Landing legs between the hatch side and the radiators (45 degrees off each).
	for i = 0, 3 do
		local n = dirFromAngle(math.rad(45 + 90 * i))
		local foot = o + n * 10.5
		disc(m, "FootPad", 3, foot, 0.6, DARK_STYLE)
		local knee = foot + Vector3.new(0, 0.6, 0)
		local hip = o + n * 5.6 + Vector3.new(0, 9.5, 0)
		pipe(m, "Leg", knee, hip, 0.9, METAL_STYLE)
		pipe(m, "LegSleeve", knee:Lerp(hip, 0.55), knee:Lerp(hip, 0.9), 1.4, white)
		pipe(m, "LegBrace", knee, o + n * 5.4 + Vector3.new(0, 5.5, 0), 0.6, METAL_STYLE)
	end

	-- Engines: a big main bell and two smaller ones beside it.
	local engine: Style = { color = ENGINE_DARK, material = Enum.Material.Metal }
	vcyl(m, "EngineBell", 1.2, 6, v(0, 2.2, 0), engine)
	vcyl(m, "EngineBellMid", 1.2, 4.8, v(0, 3.4, 0), engine)
	vcyl(m, "EngineThroat", 1.2, 3.4, v(0, 4.6, 0), DARK_STYLE)
	for s = -1, 1, 2 do
		vcyl(m, "SideEngine", 1.4, 2.4, v(s * 3.6, 3.3, 0), engine)
		vcyl(m, "SideEngineThroat", 1, 1.5, v(s * 3.6, 4.5, 0), DARK_STYLE)
	end
	vcyl(m, "ThrustFrame", 3, 11, v(0, 6.6, 0), DARK_STYLE)
	vcyl(m, "Skirt", 0.9, 12.4, v(0, 8.55, 0), METAL_STYLE)

	-- Fuel and oxygen tanks.
	vcyl(m, "LowerTank", 14, 12, v(0, 16, 0), white)
	vcyl(m, "BandCyan", 0.8, 12.3, v(0, 13, 0), { color = ACCENT })
	vcyl(m, "BandOrange", 0.8, 12.3, v(0, 20, 0), { color = WARNING })
	vcyl(m, "Intertank", 1.4, 12.5, v(0, 23.7, 0), DARK_STYLE)
	vcyl(m, "UpperTank", 10, 12, v(0, 29.4, 0), white)
	for s = -1, 1, 2 do
		box(m, "Radiator", v(s * 6, 25.6, -2.2), v(s * 6.5, 33.2, 2.2), { color = HULL_SHADE })
		box(m, "RadiatorLine", v(s * 6.45, 25.6, -0.15), v(s * 6.6, 33.2, 0.15), DARK_STYLE)
	end

	-- Crew cabin with a window band, frames, a hatch and thrusters.
	vcyl(m, "CabinRing", 0.8, 12.4, v(0, 34.8, 0), { color = ACCENT })
	vcyl(m, "Cabin", 7, 11.4, v(0, 38.7, 0), white)
	local windows = vcyl(m, "CabinWindows", 1.6, 11.7, v(0, 39.2, 0), {
		color = ACCENT:Lerp(NIGHT, 0.55),
		material = Enum.Material.Glass,
		transparency = 0.2,
		reflectance = 0.15,
	})
	pointLight(windows, INTERIOR_LIGHT, 12, 0.9)
	for i = 0, 5 do
		local n = dirFromAngle(math.rad(30 + 60 * i))
		part(m, "WindowFrame", Vector3.new(0.4, 1.8, 0.5), facing(v(0, 39.2, 0) + n * 5.8, n), white)
	end
	local hatchN = Vector3.zAxis -- toward the base road, between two legs
	part(m, "Hatch", Vector3.new(2.4, 2.6, 0.4), facing(v(0, 36.9, 0) + hatchN * 5.75, hatchN), DARK_STYLE)
	part(m, "HatchLight", Vector3.new(2.4, 0.2, 0.3), facing(v(0, 38.35, 0) + hatchN * 5.85, hatchN), neon(ACCENT))
	for i = 0, 3 do
		local n = dirFromAngle(math.rad(45 + 90 * i))
		part(m, "Thruster", Vector3.new(1, 1.2, 0.8), facing(v(0, 41, 0) + n * 5.9, n), METAL_STYLE)
	end

	-- Ladder from the pad up to the hatch.
	local side = sideFromAngle(0)
	local ladderBase = o + hatchN * 6.8
	for s = -1, 1, 2 do
		pipe(m, "LadderRail", ladderBase + side * (s * 0.8) + Vector3.new(0, 0.1, 0), ladderBase + side * (s * 0.8) + Vector3.new(0, 35.6, 0), 0.3, METAL_STYLE)
	end
	for i = 1, 8 do
		part(m, "LadderRung", Vector3.new(1.9, 0.25, 0.25), facing(ladderBase + Vector3.new(0, i * 4.3, 0), hatchN), METAL_STYLE)
	end

	-- Nose and the beacon on top (highest parts: they appear last when the ship is built step by step).
	vcyl(m, "Nose", 3, 10, v(0, 43.7, 0), white)
	vcyl(m, "NoseUpper", 3, 7.6, v(0, 46.7, 0), white)
	vcyl(m, "NoseBand", 2.4, 5, v(0, 49.4, 0), { color = WARNING })
	ball(m, "NoseTip", 3.4, v(0, 51.1, 0), white)
	vcyl(m, "TipMast", 3, 0.3, v(0, 54, 0), METAL_STYLE)
	ball(m, "TipBeacon", 0.9, v(0, 55.8, 0), neon(ACCENT))
	return m
end

------------------------------------------------------------------------------------------------
-- Exploration sites
------------------------------------------------------------------------------------------------

type SiteResult = { head: BasePart, prompt: ProximityPrompt, ground: Vector3 }

-- A small robotic lander that tipped onto its side, in a little crater.
local function buildOldLander(parent: Instance, id: string, p: Vector3): SiteResult
	local m = model(parent, id)
	disc(m, "Ejecta", 30, p, 0.3, flat(REGOLITH_BRIGHT))
	disc(m, "Bowl", 20, p, 0.36, flat(REGOLITH_DARK))
	raisedCrater(m, "Rim", {
		centre = p,
		crest = 10.5,
		height = 1.2,
		outSlope = 4,
		inSlope = 2.5,
		segments = 10,
		outColor = REGOLITH_BRIGHT,
		inColor = REGOLITH,
		material = Enum.Material.Sand,
	})

	local frame = CFrame.new(p + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(0, 0, math.rad(-78))
	local foil: Style = { color = FOIL_GOLD, material = Enum.Material.Foil }
	local function lp(name: string, size: Vector3, x: number, y: number, z: number, style: Style): Part
		return part(m, name, size, frame * CFrame.new(x, y, z), style)
	end
	lp("Body", Vector3.new(5.2, 3.6, 5.2), 0, 0, 0, foil)
	lp("Deck", Vector3.new(5.6, 0.4, 5.6), 0, 2, 0, HULL)
	lp("FuelTank", Vector3.new(1.6, 1.2, 1.6), -1.6, 2.6, 1.4, METAL_STYLE)
	cylinder(m, "Nozzle", 1.2, 1.6, frame * CFrame.new(0, -2.4, 0) * UPRIGHT, DARK_STYLE)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local hip = (frame * CFrame.new(sx * 2.2, -1.2, sz * 2.2)).Position
			local foot = (frame * CFrame.new(sx * 4, -3.6, sz * 4)).Position
			pipe(m, "Leg", hip, foot, 0.35, METAL_STYLE)
			cylinder(m, "Foot", 0.25, 1.3, frame * CFrame.new(sx * 4, -3.7, sz * 4) * UPRIGHT, METAL_STYLE)
		end
	end
	for sx = -1, 1, 2 do
		lp("SolarPanel", Vector3.new(0.15, 3, 4.6), sx * 2.7, 0, 0, { color = PANEL_BLUE, reflectance = 0.2 })
	end
	local mastFoot = (frame * CFrame.new(1.6, 2.2, -1.6)).Position
	local mastTop = frame * CFrame.new(1.6, 3.8, -1.6)
	pipe(m, "Mast", mastFoot, mastTop.Position, 0.3, METAL_STYLE)
	cylinder(m, "Dish", 0.25, 2.2, mastTop * UPRIGHT, HULL)
	lp("Camera", Vector3.new(0.9, 0.7, 0.7), -1.8, 2.6, -1.6, DARK_STYLE)
	-- Scrape in the dust where a foot dragged.
	part(m, "Scuff", Vector3.new(2.2, 0.04, 7), CFrame.new(p + Vector3.new(-4, 0.38, 2)) * CFrame.Angles(0, math.rad(35), 0), flat(SHADOW_FLOOR))

	local ground = p + Vector3.new(-5.5, 0.36, 5.5)
	local head, prompt = scanMarker(m, id, ground)
	return { head = head, prompt = prompt, ground = ground }
end

-- A fresh impact crater with bright rays and a frosty glint on its floor.
local function buildImpactCrater(parent: Instance, id: string, p: Vector3): SiteResult
	local m = model(parent, id)
	disc(m, "Ejecta", 46, p, 0.3, flat(REGOLITH_BRIGHT))
	for i = 0, 9 do
		local n = dirFromAngle(math.rad(i * 36 + (i % 3) * 7))
		local length = 30 + (i * 13) % 26
		local r0 = 20
		local nearLength = length * 0.55
		local farLength = length * 0.45
		local h = 0.32 + (i % 2) * 0.02
		local nearPos = p + n * (r0 + nearLength / 2) + Vector3.new(0, h / 2, 0)
		part(m, "Ray", Vector3.new(3.2, h, nearLength), facing(nearPos, n), flat(RAY_BRIGHT))
		local farPos = p + n * (r0 + nearLength + farLength / 2) + Vector3.new(0, h / 2, 0)
		part(m, "RayTip", Vector3.new(1.6, h, farLength), facing(farPos, n), flat(RAY_BRIGHT))
	end
	raisedCrater(m, "Rim", {
		centre = p,
		crest = 15,
		height = 3.2,
		outSlope = 7,
		inSlope = 6,
		segments = 14,
		outColor = Color3.fromRGB(178, 176, 170),
		inColor = Color3.fromRGB(166, 164, 158),
		material = Enum.Material.Sand,
	})
	disc(m, "Floor", 19, p, 0.4, flat(Color3.fromRGB(150, 148, 144)))
	part(m, "Frost", Vector3.new(3, 0.15, 2.2), CFrame.new(p + Vector3.new(2, 0.45, -1.5)) * CFrame.Angles(0, 0.6, 0), {
		color = ICE_COLOUR,
		material = Enum.Material.Ice,
		shadow = false,
		collide = false,
	})
	part(m, "Frost", Vector3.new(2, 0.15, 1.6), CFrame.new(p + Vector3.new(-2.5, 0.45, 2)) * CFrame.Angles(0, -0.4, 0), {
		color = ICE_COLOUR,
		material = Enum.Material.Ice,
		shadow = false,
		collide = false,
	})
	for i, a in { 40, 150, 260 } do
		rock(m, "RimRock", p + dirFromAngle(math.rad(a)) * 19, 2 + i * 0.5, 100 + i, Color3.fromRGB(160, 158, 152))
	end

	local toBase = flatUnit(HABITAT_CENTRE - p)
	local ground = p + toBase * 25 + Vector3.new(0, 0.3, 0)
	local head, prompt = scanMarker(m, id, ground)
	return { head = head, prompt = prompt, ground = ground }
end

-- A round hill with a boulder at its foot and the chain of dents it left rolling down.
local BOULDER_HILL_RADIUS = 150 -- sphere radius (studs); only its cap shows above the ground
local BOULDER_HILL_DEPTH = 125 -- sphere centre below the ground

local function buildBoulderTracks(parent: Instance, id: string, p: Vector3): SiteResult
	local m = model(parent, id)
	local hill = Vector3.new(p.X + 70, -BOULDER_HILL_DEPTH, p.Z + 5)
	ball(m, "Hill", BOULDER_HILL_RADIUS * 2, hill, { color = Color3.fromRGB(134, 132, 127), material = Enum.Material.Slate })
	local function surface(x: number, z: number): (Vector3, Vector3)
		local dx = x - hill.X
		local dz = z - hill.Z
		local d2 = dx * dx + dz * dz
		local r2 = BOULDER_HILL_RADIUS * BOULDER_HILL_RADIUS
		if d2 < r2 then
			local y = hill.Y + math.sqrt(r2 - d2)
			if y > 0 then
				local pos = Vector3.new(x, y, z)
				return pos, (pos - hill).Unit
			end
		end
		return Vector3.new(x, 0, z), Vector3.yAxis
	end

	-- Where the boulder broke off near the top, and where it stopped.
	local start = Vector3.new(hill.X - 18, 0, hill.Z - 8)
	local stop = Vector3.new(p.X - 20, 0, p.Z - 2)
	for i, offset in { Vector3.new(-2, 0, -3), Vector3.new(3, 0, 2), Vector3.new(4, 0, -4) } do
		local pos = surface(start.X + offset.X, start.Z + offset.Z)
		rock(m, "Outcrop", pos, 3 + i, 200 + i, ROCK)
	end
	local route = stop - start
	local count = math.floor(route.Magnitude / 2.4)
	for i = 1, count - 3 do
		local t = i / count
		local wobble = math.sin(i * 0.9) * 0.6
		local across = Vector3.new(-route.Unit.Z, 0, route.Unit.X)
		local flatPos = start + route * t + across * wobble
		local pos, normal = surface(flatPos.X, flatPos.Z)
		local size = 1.4 + (i % 3) * 0.2
		local cf = if normal.Y > 0.999
			then CFrame.new(pos) * UPRIGHT
			else CFrame.lookAt(pos, pos + normal) * ALONG_LOOK
		cylinder(m, "Dent", 0.3, size, cf, flat(DENT_COLOUR))
	end
	part(m, "Boulder", Vector3.new(7, 6, 7.5), CFrame.new(stop + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0.2, 0.7, -0.15), {
		color = ROCK,
		material = Enum.Material.Rock,
	})
	part(m, "BoulderChunk", Vector3.new(4.5, 4, 5), CFrame.new(stop + Vector3.new(2.2, 3.6, 1.4)) * CFrame.Angles(-0.3, 1.2, 0.25), {
		color = Color3.fromRGB(98, 96, 92),
		material = Enum.Material.Rock,
	})
	for i, offset in { Vector3.new(-5, 0, 3), Vector3.new(-4, 0, -4), Vector3.new(5, 0, 5) } do
		rock(m, "Rubble", stop + offset, 0.9 + i * 0.3, 300 + i, ROCK)
	end

	local ground = Vector3.new(p.X - 16, 0, p.Z - 16)
	local head, prompt = scanMarker(m, id, ground)
	return { head = head, prompt = prompt, ground = ground }
end

-- A small dark crater inside a deep, shadowed pit with one way in.
local function buildProspectorCrash(parent: Instance, id: string, p: Vector3): SiteResult
	local m = model(parent, id)
	local toBase = flatUnit(HABITAT_CENTRE - p)
	local gapAngle = angleOf(toBase)
	raisedCrater(m, "PitWall", {
		centre = p,
		crest = 11,
		height = 6.5,
		outSlope = 10,
		inSlope = 4.5,
		segments = 12,
		outColor = Color3.fromRGB(116, 114, 110),
		inColor = Color3.fromRGB(88, 88, 90),
		material = Enum.Material.Slate,
		gapAngle = gapAngle,
	})
	disc(m, "PitFloor", 14, p, 0.3, flat(SHADOW_FLOOR, Enum.Material.Slate))
	local mark = p + Vector3.new(1.5, 0, -1)
	disc(m, "ImpactMark", 4, mark, 0.36, flat(Color3.fromRGB(38, 40, 46), Enum.Material.Slate))
	for i = 0, 5 do
		rock(m, "MarkRim", mark + dirFromAngle(i * math.pi / 3) * 2.4 + Vector3.new(0, 0.3, 0), 0.9, 400 + i, Color3.fromRGB(70, 70, 74))
	end
	for i, offset in { Vector3.new(-4, 0, 3), Vector3.new(3, 0, 4), Vector3.new(-2, 0, -5) } do
		rock(m, "PitRock", p + offset + Vector3.new(0, 0.3, 0), 1.6 + i * 0.4, 500 + i, Color3.fromRGB(76, 76, 80))
	end

	local ground = p + toBase * 5 + Vector3.new(0, 0.3, 0)
	local head, prompt = scanMarker(m, id, ground)
	return { head = head, prompt = prompt, ground = ground }
end

-- A tall round hill with a bright flat top: a lookout with a scope and a test solar panel.
local SUN_HILL_RADIUS = 120
local SUN_HILL_DEPTH = 96
local SUN_PLATEAU_TOP = 24.05

local function buildSunPeak(parent: Instance, id: string, p: Vector3): SiteResult
	local m = model(parent, id)
	ball(m, "Hill", SUN_HILL_RADIUS * 2, Vector3.new(p.X, -SUN_HILL_DEPTH, p.Z), {
		color = Color3.fromRGB(150, 148, 143),
		material = Enum.Material.Slate,
	})
	local topY = SUN_PLATEAU_TOP
	local plateau = Vector3.new(p.X, topY, p.Z)
	vcyl(m, "Plateau", 2.1, 30, plateau - Vector3.new(0, 1.05, 0), { color = SUNLIT_ROCK, material = Enum.Material.Slate })
	-- Viewing platform with a gold rim and a scope that looks back at the base.
	vcyl(m, "PlatformRim", 0.2, 8.6, plateau + Vector3.new(0, 0.1, 0), neon(STAR))
	vcyl(m, "Platform", 0.4, 8, plateau + Vector3.new(0, 0.2, 0), { color = NIGHT })
	local deck = plateau + Vector3.new(0, 0.4, 0)
	local toBase = flatUnit(HABITAT_CENTRE - p)
	local scopePos = deck + Vector3.new(0, 3.4, 0)
	for i = 0, 2 do
		pipe(m, "ScopeLeg", deck + dirFromAngle(i * 2 * math.pi / 3) * 1.3, scopePos - Vector3.new(0, 0.3, 0), 0.22, METAL_STYLE)
	end
	cylinder(m, "Scope", 2.6, 0.7, CFrame.lookAt(scopePos, scopePos + toBase) * ALONG_LOOK, HULL)
	local lensPos = scopePos + toBase * 1.35
	cylinder(m, "ScopeLens", 0.1, 0.6, CFrame.lookAt(lensPos, lensPos + toBase) * ALONG_LOOK, neon(ACCENT))
	-- At the pole the Sun stays low, so this test panel stands upright to catch it.
	local mastFoot = plateau + Vector3.new(-6, 0, 2)
	vcyl(m, "PanelMast", 5, 0.4, mastFoot + Vector3.new(0, 2.5, 0), METAL_STYLE)
	part(m, "SunPanel", Vector3.new(3, 3.4, 0.2), facing(mastFoot + Vector3.new(0, 5.4, 0), flatUnit(mastFoot - plateau)), {
		color = PANEL_BLUE,
		reflectance = 0.2,
	})
	for i, offset in { Vector3.new(11, 0, -6), Vector3.new(-10, 0, -8), Vector3.new(4, 0, 12) } do
		rock(m, "PeakRock", plateau + offset, 2 + i * 0.6, 600 + i, SUNLIT_ROCK:Lerp(ROCK, 0.4))
	end

	local ground = plateau + Vector3.new(6.5, 0, 6.5)
	local head, prompt = scanMarker(m, id, ground)
	return { head = head, prompt = prompt, ground = ground }
end

local SITE_BUILDERS: { [string]: (Instance, string, Vector3) -> SiteResult } = {
	old_lander = buildOldLander,
	impact_crater = buildImpactCrater,
	boulder_tracks = buildBoulderTracks,
	prospector_crash = buildProspectorCrash,
	sun_peak = buildSunPeak,
}

-- Circles random boulders and craters must avoid (lab, garage, pad, and each site with its marks).
local function siteKeepouts(): { Keepout }
	local list: { Keepout } = {
		{ x = LAB_CENTRE.X, z = LAB_CENTRE.Z, r = 20 },
		{ x = LAB_PAD.X, z = LAB_PAD.Z, r = 6 },
		{ x = GARAGE_CENTRE.X - 6, z = GARAGE_CENTRE.Z, r = 40 },
		{ x = GARAGE_PAD.X, z = GARAGE_PAD.Z, r = 6 },
		{ x = LANDING_PAD_CENTRE.X, z = LANDING_PAD_CENTRE.Z, r = BERM_INNER + BERM_DEPTH + 6 },
	}
	local access = accessDirection()
	local road = LANDING_PAD_CENTRE + access * (BERM_INNER + BERM_DEPTH + 10)
	table.insert(list, { x = road.X, z = road.Z, r = 10 })
	local p = SITE_POSITIONS
	table.insert(list, { x = p.old_lander.X, z = p.old_lander.Z, r = 22 })
	table.insert(list, { x = p.impact_crater.X, z = p.impact_crater.Z, r = 80 })
	table.insert(list, { x = p.boulder_tracks.X + 70, z = p.boulder_tracks.Z + 5, r = 90 })
	table.insert(list, { x = p.boulder_tracks.X - 18, z = p.boulder_tracks.Z - 8, r = 16 })
	table.insert(list, { x = p.prospector_crash.X, z = p.prospector_crash.Z, r = 28 })
	table.insert(list, { x = p.sun_peak.X, z = p.sun_peak.Z, r = 76 })
	return list
end

------------------------------------------------------------------------------------------------
-- Meteorite impacts: no air on the Moon, so no fiery streak; only a flash when the rock hits
------------------------------------------------------------------------------------------------

local impactCount = 0

local function tween(item: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(item, info, goals):Play()
end

local function impactEffects(parent: Instance, p: Vector3)
	-- Flash: a bright ball and light that grow and vanish in half a second.
	local flash = ball(parent, "Flash", 2, p + Vector3.new(0, 1, 0), neon(CREAM))
	local flashLight = pointLight(flash, CREAM, 60, 10)
	tween(flash, IMPACT_FLASH_SECONDS, { Size = Vector3.new(24, 24, 24), Transparency = 1 })
	tween(flashLight, IMPACT_FLASH_SECONDS, { Brightness = 0 })
	-- Dust: a flat ring that spreads out, plus grains that fly in arcs and fall straight back down.
	local ring = vcyl(parent, "DustRing", 0.2, 4, p + Vector3.new(0, 0.2, 0), {
		color = REGOLITH_BRIGHT,
		material = Enum.Material.SmoothPlastic,
		transparency = 0.35,
		shadow = false,
		collide = false,
	})
	tween(ring, IMPACT_DUST_SECONDS, { Size = Vector3.new(0.2, 46, 46), Transparency = 1 })
	local holder = part(parent, "DustSource", Vector3.new(3, 0.2, 3), CFrame.new(p + Vector3.new(0, 0.4, 0)), {
		color = REGOLITH,
		transparency = 1,
		shadow = false,
		collide = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(REGOLITH_BRIGHT)
	emitter.Size = NumberSequence.new(0.6, 1.6)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(1.4, 2.2)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -Workspace.Gravity, 0)
	emitter.Drag = 0
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(IMPACT_DUST_PARTICLES)
	task.delay(math.max(IMPACT_FLASH_SECONDS, IMPACT_DUST_SECONDS) + 2.5, function()
		flash:Destroy()
		ring:Destroy()
		holder:Destroy()
	end)
end

local function spawnImpactAt(impacts: Folder, p: Vector3): (Model, ProximityPrompt)
	impactCount += 1
	local impactId = "impact" .. impactCount
	local m = model(nil, "Impact_" .. impactCount)
	m:SetAttribute("ImpactId", impactId)

	disc(m, "Ejecta", 20, p, 0.2, flat(REGOLITH_BRIGHT))
	for i = 0, 5 do
		local n = dirFromAngle(math.rad(i * 60 + (i % 2) * 17))
		local length = 9 + (i * 5) % 6
		local pos = p + n * (8 + length / 2) + Vector3.new(0, 0.12, 0)
		part(m, "Ray", Vector3.new(1.4, 0.24, length), facing(pos, n), flat(RAY_BRIGHT))
	end
	raisedCrater(m, "Rim", {
		centre = p,
		crest = 4.5,
		height = 1.1,
		outSlope = 2.6,
		inSlope = 1.6,
		segments = 10,
		outColor = Color3.fromRGB(176, 174, 168),
		inColor = Color3.fromRGB(150, 148, 142),
		material = Enum.Material.Sand,
		collide = false,
	})
	disc(m, "Bowl", 6.4, p, 0.3, flat(Color3.fromRGB(92, 90, 88)))

	local rockStyle: Style = { color = HOT_ROCK, material = Enum.Material.Neon }
	local hot = part(m, "HotRock", Vector3.new(1.8, 1.4, 1.6), CFrame.new(p + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0.4, 0.8, -0.3), rockStyle)
	local chip = part(m, "HotRockChip", Vector3.new(1.2, 1, 1.3), CFrame.new(p + Vector3.new(0.9, 0.7, 0.5)) * CFrame.Angles(-0.5, 0.3, 0.6), rockStyle)
	hot:SetAttribute("ImpactId", impactId)
	local glow = pointLight(hot, HOT_ROCK, 18, 3)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScanPrompt"
	prompt.ActionText = "Scan"
	prompt.ObjectText = ""
	prompt.HoldDuration = SCAN_HOLD
	prompt.MaxActivationDistance = SCAN_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt:SetAttribute("TextKey", "prompt.scan")
	prompt:SetAttribute("ObjectKey", "meteor.name")
	prompt.Parent = hot

	m.Parent = impacts
	impactEffects(m, p)

	-- The rock glows, then cools from orange to grey.
	for _, piece in { hot, chip } do
		tween(piece, IMPACT_COOL_SECONDS, { Color = COOL_ROCK }, Enum.EasingStyle.Sine)
	end
	tween(glow, IMPACT_COOL_SECONDS, { Brightness = 0 }, Enum.EasingStyle.Sine)
	task.delay(IMPACT_GLOW_SECONDS, function()
		if m.Parent ~= nil then
			hot.Material = Enum.Material.Basalt
			chip.Material = Enum.Material.Basalt
		end
	end)
	return m, prompt
end

local function clearImpact(impact: Model)
	if impact.Parent == nil then
		return
	end
	for _, item in impact:GetDescendants() do
		if item:IsA("ProximityPrompt") then
			item.Enabled = false
		elseif item:IsA("Light") then
			item.Enabled = false
		elseif item:IsA("BasePart") then
			tween(item, IMPACT_FADE_SECONDS, { Transparency = 1 })
		end
	end
	task.delay(IMPACT_FADE_SECONDS, function()
		impact:Destroy()
	end)
end

------------------------------------------------------------------------------------------------
-- Entry point
------------------------------------------------------------------------------------------------

function WorldSites.build(baseFolder: Instance, helpers: Helpers?): Sites
	building = true
	partHook = if helpers then helpers.onPart else nil

	local sites = folder(baseFolder, "Sites")
	local existing = baseFolder:FindFirstChild("Impacts")
	local impacts: Folder
	if existing ~= nil and existing:IsA("Folder") then
		impacts = existing :: Folder
	else
		impacts = folder(baseFolder, "Impacts")
	end

	local lab, labPrompt, labDock = buildLab(sites)
	local garage, garageBays = buildGarage(sites)
	local landingPad = buildLandingPad(sites)
	local ship = buildShip(sites)

	local access = accessDirection()
	local landingPadPos = LANDING_PAD_CENTRE + access * (BERM_INNER + BERM_DEPTH + 7)
	local shipPadPos = Vector3.new(LANDING_PAD_CENTRE.X, LANDING_PAD_TOP, LANDING_PAD_CENTRE.Z) + access * SHIP_PAD_RADIUS

	local explore = folder(sites, "Explore")
	local pois: { PoiRef } = {}
	for _, id in SITE_ORDER do
		local result = SITE_BUILDERS[id](explore, id, SITE_POSITIONS[id])
		table.insert(pois, { id = id, position = result.ground, prompt = result.prompt })
	end

	building = false
	partHook = nil

	return {
		builds = {
			lab = { model = lab, padPosition = LAB_PAD },
			garage = { model = garage, padPosition = GARAGE_PAD },
			landing_pad = { model = landingPad, padPosition = landingPadPos },
			ship = { model = ship, padPosition = shipPadPos },
		},
		labPrompt = labPrompt,
		labDock = labDock,
		garageBays = garageBays,
		pois = pois,
		impacts = impacts,
		spawnImpact = function(position: Vector3): (Model, ProximityPrompt)
			return spawnImpactAt(impacts, position)
		end,
		clearImpact = clearImpact,
		keepouts = siteKeepouts(),
	}
end

return WorldSites
