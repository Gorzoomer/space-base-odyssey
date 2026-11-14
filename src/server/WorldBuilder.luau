--!strict
-- Space Base Odyssey - builds the Moon south-pole base from plain Parts and sets the lunar environment.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

export type ArrayRef = { model: Model, panel: BasePart, prompt: ProximityPrompt }
export type StormStage = "none" | "warning" | "storm"

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
	setArrayDusty: (index: number, dusty: boolean) -> (),
	setLeakActive: (active: boolean) -> (),
	setAntennaLinked: (linked: boolean) -> (),
	setStormVisuals: (stage: StormStage) -> (),
	setShiftPromptsEnabled: (enabled: boolean) -> (),
}

type Style = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	shadow: boolean?,
}

type Cap = { a: number, b: number, s: number, c: Color3 }

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
local EARTH_DIAMETER = 130
local YIELD_EVERY = 40

-- Sun search window: low enough that crater rims shade the floor, high enough to light the ground.
local SUN_TARGET_ELEVATION = math.rad(8)
local SUN_MIN_ELEVATION = math.rad(5)
local SUN_MAX_ELEVATION = math.rad(11)

-- Activation distance from the world contract.
local PROMPT_DISTANCE = 10

-- Palette.
local WHITE_HULL = Color3.fromRGB(226, 228, 232)
local HULL_TRIM = Color3.fromRGB(240, 128, 40)
local GLASS_COLOUR = Color3.fromRGB(255, 214, 160)
local METAL = Color3.fromRGB(150, 155, 162)
local DARK_METAL = Color3.fromRGB(70, 74, 82)
local REGOLITH_LIGHT = Color3.fromRGB(150, 147, 141)
local PANEL_CLEAN = Color3.fromRGB(30, 56, 128)
local PANEL_DUSTY = Color3.fromRGB(146, 134, 116)
local LINK_RED = Color3.fromRGB(255, 70, 60)
local LINK_GREEN = Color3.fromRGB(70, 255, 120)
local STORM_AMBER = Color3.fromRGB(255, 170, 40)
local STORM_RED = Color3.fromRGB(255, 40, 40)
local LAMP_OFF = Color3.fromRGB(60, 60, 64)
local ICE_GLOW = Color3.fromRGB(170, 232, 255)
local MARKER_AMBER = Color3.fromRGB(255, 180, 60)

-- Module state shared between applyEnvironment and build.
local earthPosition: Vector3? = nil
local partCounter = 0

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
	local sunH = flatUnit(sunDirection(), Vector3.new(0, 0, -1))
	local sunAngle = math.atan2(sunH.X, sunH.Z)
	local dir = dirFromAngle(sunAngle + math.rad(110))
	return dir * EARTH_DISTANCE + Vector3.new(0, EARTH_DISTANCE * math.tan(math.rad(7)), 0)
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

local function buildSkyBodies()
	local old = Workspace:FindFirstChild("SkyBodies")
	if old then
		old:Destroy()
	end
	local sky = Instance.new("Model")
	sky.Name = "SkyBodies"
	sky.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local glow: Style = { color = Color3.fromRGB(60, 120, 225), material = Enum.Material.Neon, collide = false, shadow = false }
	local position = earthPosition or defaultEarthPosition()
	local centre = position
	ball(sky, "Earth", EARTH_DIAMETER, centre, glow)
	ball(sky, "EarthHalo", EARTH_DIAMETER * 1.06, centre, {
		color = Color3.fromRGB(150, 200, 255),
		material = Enum.Material.Neon,
		transparency = 0.82,
		collide = false,
		shadow = false,
	})

	-- Clouds and continents: small spheres poking out of the side that faces the base.
	local toBase = (Vector3.zero - centre).Unit
	local right = toBase:Cross(Vector3.yAxis).Unit
	local up = right:Cross(toBase).Unit
	local radius = EARTH_DIAMETER / 2
	local caps: { Cap } = {
		{ a = 0.15, b = 0.35, s = 0.34, c = Color3.fromRGB(245, 248, 255) },
		{ a = -0.45, b = 0.1, s = 0.30, c = Color3.fromRGB(240, 245, 255) },
		{ a = 0.4, b = -0.3, s = 0.28, c = Color3.fromRGB(245, 248, 255) },
		{ a = -0.1, b = -0.45, s = 0.24, c = Color3.fromRGB(235, 242, 255) },
		{ a = -0.3, b = 0.45, s = 0.30, c = Color3.fromRGB(110, 150, 90) },
		{ a = 0.35, b = 0.05, s = 0.32, c = Color3.fromRGB(120, 160, 95) },
		{ a = -0.05, b = -0.1, s = 0.26, c = Color3.fromRGB(150, 140, 100) },
	}
	for i, cap in caps do
		local dir = (toBase + right * cap.a + up * cap.b).Unit
		local size = EARTH_DIAMETER * cap.s
		local capCentre = centre + dir * (radius - size * 0.42)
		ball(sky, "EarthDetail" .. i, size, capCentre, {
			color = cap.c,
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	end

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

function WorldBuilder.applyEnvironment(data: any)
	Workspace.Gravity = data.WORLD.MOON_GRAVITY_STUDS
	StarterPlayer.CharacterUseJumpPower = true
	StarterPlayer.CharacterJumpPower = data.WORLD.JUMP_POWER
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
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 9
	sky.MoonAngularSize = 0
	sky.Parent = Lighting

	local latitude, clock = chooseSun()
	Lighting.GeographicLatitude = latitude
	Lighting.ClockTime = clock
	Lighting.Brightness = 3.5
	Lighting.ExposureCompensation = 0.6
	Lighting.Ambient = Color3.fromRGB(46, 46, 54)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 78, 88)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.03
	Lighting.FogColor = Color3.new(0, 0, 0)
	Lighting.FogStart = 100000
	Lighting.FogEnd = 100000

	local bloom = Lighting:FindFirstChild("SBO_Bloom")
	if not bloom then
		local newBloom = Instance.new("BloomEffect")
		newBloom.Name = "SBO_Bloom"
		newBloom.Intensity = 0.6
		newBloom.Size = 28
		newBloom.Threshold = 1.5
		newBloom.Parent = Lighting
	end

	local tint = Lighting:FindFirstChild("SBO_StormTint")
	if not tint then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "SBO_StormTint"
		correction.Enabled = false
		correction.Parent = Lighting
	end

	earthPosition = defaultEarthPosition()
	buildSkyBodies()
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

local function buildGround(base: Instance, rng: Random)
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
end

-- Builds the crater pit with its rim, ramp and ice nodes; returns the model and the ice node refs.
local function buildCrater(base: Instance, rng: Random): (Model, { { part: BasePart, prompt: ProximityPrompt } })
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

	for k = 0, segments - 1 do
		local n = dirFromAngle(k * step)
		local pos = CRATER_CENTRE + n * (CRATER_RADIUS + depth / 2) + Vector3.new(0, rimBottom + rimHeight / 2, 0)
		part(crater, "Rim", Vector3.new(width, rimHeight, depth), CFrame.lookAt(pos, pos + n), {
			color = regolith(rng, 122, 6),
			material = Enum.Material.Slate,
		})
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

	-- The ramp goes down on the side facing away from the Sun so no light gets in through it.
	local sunH = flatUnit(sunDirection(), Vector3.new(0, 0, -1))
	local away = -sunH
	local rampAngle = math.floor(math.atan2(away.X, away.Z) / step + 0.5) * step
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

	return crater, iceNodes
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
}

local function isClear(x: number, z: number, margin: number): boolean
	for _, k in KEEPOUTS do
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
	for i, spot in markers do
		vcylinder(decor, "MarkerPole" .. i, 4, 0.4, spot + Vector3.new(0, 2, 0), {
			color = DARK_METAL,
			material = Enum.Material.Metal,
		})
		box(decor, "MarkerLight" .. i, spot + Vector3.new(-0.5, 4, -0.5), spot + Vector3.new(0.5, 4.8, 0.5), {
			color = MARKER_AMBER,
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
	windowWall(hab, "WallWest", v(-30, 0, -18), v(-28, 18, 18), 3, hull)
	windowWall(hab, "WallEast", v(28, 0, -18), v(30, 18, 18), 3, hull)
	windowWall(hab, "WallFrontWest", v(-30, 0, 18), v(-4, 18, 20), 2, hull)
	windowWall(hab, "WallFrontEast", v(4, 0, 18), v(30, 18, 20), 2, hull)
	box(hab, "Lintel", v(-4, 10, 18), v(4, 18, 20), hull)
	box(hab, "Roof", v(-31, 18, -21), v(31, 19.5, 21), { color = Color3.fromRGB(205, 208, 214), material = Enum.Material.SmoothPlastic })

	-- Orange trim band and roof gear.
	local trim: Style = { color = HULL_TRIM, material = Enum.Material.SmoothPlastic }
	box(hab, "Trim", v(-30.2, 15, -20.2), v(30.2, 16, -20), trim)
	box(hab, "Trim", v(-30.2, 15, 20), v(-4, 16, 20.2), trim)
	box(hab, "Trim", v(4, 15, 20), v(30.2, 16, 20.2), trim)
	box(hab, "Trim", v(-4, 15, 20), v(4, 16, 20.2), trim)
	box(hab, "Trim", v(-30.2, 15, -20), v(-30, 16, 20), trim)
	box(hab, "Trim", v(30, 15, -20), v(30.2, 16, 20), trim)
	box(hab, "Radiator", v(-22, 19.5, -14), v(-6, 20.1, 14), { color = Color3.fromRGB(235, 236, 240), material = Enum.Material.Metal })
	vcylinder(hab, "RoofMast", 6, 0.5, v(16, 22.5, -10), { color = METAL, material = Enum.Material.Metal })
	local beacon = ball(hab, "RoofBeacon", 1.2, v(16, 25.8, -10), { color = STORM_RED, material = Enum.Material.Neon })
	pointLight(beacon, STORM_RED, 10, 1, false)

	-- Doorway frame and lamp.
	local frame: Style = { color = Color3.fromRGB(245, 200, 40), material = Enum.Material.SmoothPlastic }
	box(hab, "DoorFrame", v(-4.8, 0, 20), v(-4, 10.8, 20.6), frame)
	box(hab, "DoorFrame", v(4, 0, 20), v(4.8, 10.8, 20.6), frame)
	box(hab, "DoorFrame", v(-4, 10, 20), v(4, 10.8, 20.6), frame)
	local doorLamp = box(hab, "DoorLamp", v(-1.5, 11.2, 20), v(1.5, 11.7, 20.8), {
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

	-- Ceiling lights.
	for _, z in { -8, 8 } do
		local strip = box(hab, "CeilingLight", v(-20, 17.4, z - 0.5), v(20, 18, z + 0.5), {
			color = Color3.fromRGB(255, 240, 215),
			material = Enum.Material.Neon,
			shadow = false,
		})
		pointLight(strip, Color3.fromRGB(255, 236, 210), 40, 1.3, true)
	end

	-- Power board console.
	local console = box(hab, "PowerConsole", v(-22, 0.5, -14), v(-14, 4, -10), { color = DARK_METAL, material = Enum.Material.Metal })
	part(
		hab,
		"ConsoleScreen",
		Vector3.new(7, 3, 0.3),
		CFrame.new(v(-18, 5.6, -13.2)) * CFrame.Angles(math.rad(-20), 0, 0),
		{ color = Color3.fromRGB(80, 220, 255), material = Enum.Material.Neon, shadow = false }
	)
	local consolePrompt = makePrompt(console, "prompt.console", "Power board", 0)

	-- Water processor: melts ice and splits water into oxygen with electricity.
	box(hab, "ProcessorBase", v(14, 0.5, -17), v(22, 1.5, -10), { color = DARK_METAL, material = Enum.Material.Metal })
	vcylinder(hab, "ProcessorTank", 8, 5, v(18, 5.5, -14), { color = Color3.fromRGB(200, 205, 212), material = Enum.Material.Metal })
	box(hab, "ProcessorWindow", v(17.2, 3.2, -11.6), v(18.8, 7.8, -11.3), {
		color = Color3.fromRGB(70, 170, 255),
		material = Enum.Material.Neon,
		shadow = false,
	})
	zcylinder(hab, "ProcessorPipe", 5, 0.8, v(18, 9.2, -16.5), { color = METAL, material = Enum.Material.Metal })
	local inlet = box(hab, "ProcessorInlet", v(16.5, 1.5, -11), v(19.5, 4, -9.4), {
		color = HULL_TRIM,
		material = Enum.Material.SmoothPlastic,
	})
	local processorPrompt = makePrompt(inlet, "prompt.deliver", "Deliver ice", 0.5)

	-- Greenhouse rack under a grow light.
	box(hab, "PlantRack", v(-7, 0.5, -17.8), v(7, 3, -15), { color = Color3.fromRGB(235, 235, 240), material = Enum.Material.SmoothPlastic })
	for i = 0, 3 do
		local x = -5.5 + i * 3.7
		box(hab, "Plant", v(x - 1.2, 3, -17.3), v(x + 1.2, 4.6, -15.5), {
			color = Color3.fromRGB(80, 190, 90),
			material = Enum.Material.Grass,
		})
	end
	local grow = box(hab, "GrowLight", v(-7, 7.5, -17.4), v(7, 7.9, -15.4), {
		color = Color3.fromRGB(255, 110, 220),
		material = Enum.Material.Neon,
		shadow = false,
	})
	pointLight(grow, Color3.fromRGB(255, 120, 220), 10, 1, false)

	-- Crew table.
	box(hab, "TableLeg", v(-1, 0.5, -5), v(1, 3, -3), { color = METAL, material = Enum.Material.Metal })
	box(hab, "TableTop", v(-5, 3, -7), v(5, 3.4, -1), { color = Color3.fromRGB(235, 236, 240), material = Enum.Material.SmoothPlastic })

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Enabled = true
	spawnPad.AllowTeamChangeOnTouch = false
	finish(spawnPad, hab, "BaseSpawn", Vector3.new(8, 0.4, 8), CFrame.new(v(0, 0.7, 8)), {
		color = Color3.fromRGB(120, 170, 220),
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
	local leakLight = pointLight(leakPart, Color3.fromRGB(255, 150, 60), 14, 2, false)
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
	}
end

------------------------------------------------------------------------------------------------
-- Regolith shelter
------------------------------------------------------------------------------------------------

type ShelterRefs = { zone: Part, lamp: Part, lampLight: PointLight }

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
	box(shelter, "WallFrontWest", v(-11, 0, 7), v(-3.5, 10, 9), wall)
	box(shelter, "WallFrontEast", v(3.5, 0, 7), v(11, 10, 9), wall)
	box(shelter, "WallFrontLintel", v(-3.5, 9, 7), v(3.5, 10, 9), wall)

	-- Tunnel out through the mound.
	local tunnelEnd = 29
	box(shelter, "TunnelFloor", v(-5.5, 0, 9), v(5.5, 0.4, tunnelEnd), { color = Color3.fromRGB(110, 108, 104), material = Enum.Material.Concrete })
	box(shelter, "TunnelWest", v(-5.5, 0, 9), v(-3.5, 9, tunnelEnd), wall)
	box(shelter, "TunnelEast", v(3.5, 0, 9), v(5.5, 9, tunnelEnd), wall)
	box(shelter, "TunnelRoof", v(-5.5, 9, 9), v(5.5, 11, tunnelEnd), wall)
	box(shelter, "MouthWest", v(-6.5, 0, tunnelEnd), v(-3.5, 12, tunnelEnd + 1), wall)
	box(shelter, "MouthEast", v(3.5, 0, tunnelEnd), v(6.5, 12, tunnelEnd + 1), wall)
	box(shelter, "MouthTop", v(-3.5, 9, tunnelEnd), v(3.5, 12, tunnelEnd + 1), wall)

	-- Storm lamp above the shelter door.
	local lamp = box(shelter, "StormLamp", v(-1.5, 12, tunnelEnd), v(1.5, 13, tunnelEnd + 1.2), {
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
	return { zone = zonePart, lamp = lamp, lampLight = lampLight }
end

------------------------------------------------------------------------------------------------
-- Solar arrays and antenna
------------------------------------------------------------------------------------------------

type ArrayVisual = { panel: Part, lines: { Part } }

local function buildArrays(base: Instance, data: any): ({ ArrayRef }, { ArrayVisual })
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
	for i = 1, count do
		local m = model(arraysFolder, "SolarArray" .. i)
		local footPos = centre + perp * ((i - (count + 1) / 2) * spacing)
		box(m, "Foot", footPos + Vector3.new(-1.5, 0, -1.5), footPos + Vector3.new(1.5, 0.6, 1.5), {
			color = DARK_METAL,
			material = Enum.Material.Metal,
		})
		local panelCentre = footPos + Vector3.new(0, 6, 0)
		vcylinder(m, "Mast", 6, 0.7, footPos - sunH * 0.6 + Vector3.new(0, 3, 0), { color = METAL, material = Enum.Material.Metal })
		local panelCf = CFrame.lookAt(panelCentre, panelCentre + face)
		part(m, "Frame", Vector3.new(12.6, 8.6, 0.3), panelCf * CFrame.new(0, 0, 0.35), { color = METAL, material = Enum.Material.Metal })
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
		table.insert(refs, { model = m, panel = panel :: BasePart, prompt = prompt })
		table.insert(visuals, { panel = panel, lines = { lineH, lineV } })
	end
	return refs, visuals
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
	dishModel.WorldPivot = misaligned

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
	}
end

------------------------------------------------------------------------------------------------
-- Public build
------------------------------------------------------------------------------------------------

function WorldBuilder.build(data: any): World
	partCounter = 0
	local old = Workspace:FindFirstChild("Base")
	if old then
		old:Destroy()
	end
	local base = Instance.new("Folder")
	base.Name = "Base"
	base.Parent = Workspace

	local rng = Random.new(42)
	buildGround(base, rng)
	local habitat = buildHabitat(base)
	local shelter = buildShelter(base)
	local _, iceNodes = buildCrater(base, rng)
	buildRidge(base, rng)
	local arrays, arrayVisuals = buildArrays(base, data)
	local antenna = buildAntenna(base)
	buildDecor(base, rng)

	-- Live state behind the setters.
	local shiftEnabled = false
	local dusty: { boolean } = table.create(#arrays, false)
	local leakActive = false
	local antennaLinked = false
	local dishToken = 0
	local stormToken = 0

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
		habitat.leakPart.Color = if active then Color3.fromRGB(200, 80, 50) else METAL
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

		local target = if linked
			then CFrame.lookAt(antenna.hubPosition, earthPosition or defaultEarthPosition())
			else antenna.misaligned
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

	refreshPrompts()

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
		setArrayDusty = setArrayDusty,
		setLeakActive = setLeakActive,
		setAntennaLinked = setAntennaLinked,
		setStormVisuals = setStormVisuals,
		setShiftPromptsEnabled = setShiftPromptsEnabled,
	}
end

-- Point-in-box test for the zone parts (works for rotated parts too).
function WorldBuilder.isInZone(zonePart: BasePart, position: Vector3): boolean
	local localPos = zonePart.CFrame:PointToObjectSpace(position)
	local half = zonePart.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

return WorldBuilder
