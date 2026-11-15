--!strict
-- Space Base Odyssey - the lunar environment: gravity and jump, lighting, the Earth, Mars and the
-- stars, the Sun circling the south-pole horizon and the eclipse when it passes behind the Earth.
-- WorldBuilder.applyEnvironment is WorldSky.applyEnvironment; WorldBuilder.build starts the sky clock.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local WorldParts = require(script.Parent:WaitForChild("WorldParts"))

local PALETTE = WorldParts.PALETTE
local MARS_RED = WorldParts.MARS_RED
local buildState = WorldParts.buildState
local ball = WorldParts.ball
local dirFromAngle = WorldParts.dirFromAngle
local flatUnit = WorldParts.flatUnit

local WorldSky = {}

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

-- Sun search window: low enough that crater rims shade the floor, high enough to light the ground.
local SUN_TARGET_ELEVATION = math.rad(8)
local SUN_MIN_ELEVATION = math.rad(5)
local SUN_MAX_ELEVATION = math.rad(11)

-- Module state shared between applyEnvironment and build (read with getEarthPosition and
-- getMarsPosition).
local earthPosition: Vector3? = nil
local marsPosition: Vector3? = nil

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

-- Each panel section turns around its mast to follow the Sun as it circles the horizon.
export type ArrayTrack = { panel: BasePart, pivot: Vector3, offset: CFrame, baseAngle: number, yaw: number }

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

function WorldSky.applyEnvironment(data: any)
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
		if math.abs(wrapAngle(yaw - track.yaw)) >= ARRAY_MIN_TURN and track.panel.Parent ~= nil and not buildState.risingParts[track.panel] then
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

function WorldSky.getEarthPosition(): Vector3?
	return earthPosition
end

function WorldSky.getMarsPosition(): Vector3?
	return marsPosition
end

-- WorldBuilder.build starts a new listener list; world.onEclipse adds to it.
function WorldSky.resetEclipseListeners()
	eclipseListeners = {}
end

function WorldSky.addEclipseListener(callback: (active: boolean) -> ())
	table.insert(eclipseListeners, callback)
end

function WorldSky.isEclipseActive(): boolean
	return eclipseActive
end

WorldSky.sunDirection = sunDirection
WorldSky.defaultEarthPosition = defaultEarthPosition
WorldSky.defaultMarsPosition = defaultMarsPosition
WorldSky.stormTint = stormTint
WorldSky.startSky = startSky
WorldSky.previewEclipse = previewEclipse

return WorldSky
