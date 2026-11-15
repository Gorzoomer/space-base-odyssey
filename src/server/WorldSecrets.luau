--!strict
-- Space Base Odyssey - the secrets: hidden places (crawl space, lookout rock, lava tube, the sealed
-- observatory), the four collectible figures and the team flag.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local Theme = require(Shared:WaitForChild("Theme"))
local WorldParts = require(script.Parent:WaitForChild("WorldParts"))
local WorldSky = require(script.Parent:WaitForChild("WorldSky"))

type Style = WorldParts.Style
export type CollectibleRef = { id: string, model: Model, prompt: ProximityPrompt }

local HABITAT_CENTRE = WorldParts.HABITAT_CENTRE
local ANTENNA_BASE = WorldParts.ANTENNA_BASE
local HUB_DOME_RX = WorldParts.HUB_DOME_RX
local HUB_DOME_RY = WorldParts.HUB_DOME_RY
local HUB_ROOF_Y = WorldParts.HUB_ROOF_Y
local Geo = WorldParts.Geo
local LOOKOUT_DISTANCE = WorldParts.LOOKOUT_DISTANCE
local LOOKOUT_YAW = WorldParts.LOOKOUT_YAW
local LAVA_TUBE_MIN = WorldParts.LAVA_TUBE_MIN
local LAVA_TUBE_MAX = WorldParts.LAVA_TUBE_MAX
local OBSERVATORY_HILL = WorldParts.OBSERVATORY_HILL
local OBSERVATORY_HILL_Y = WorldParts.OBSERVATORY_HILL_Y
local COLLECTIBLE_PROMPT_DISTANCE = WorldParts.COLLECTIBLE_PROMPT_DISTANCE
local COLLECTIBLE_FLOAT = WorldParts.COLLECTIBLE_FLOAT
local WHITE_HULL = WorldParts.WHITE_HULL
local PALETTE = WorldParts.PALETTE
local ACCENT_SYSTEM = WorldParts.ACCENT_SYSTEM
local ACCENT_WARNING = WorldParts.ACCENT_WARNING
local ACCENT_SECRET = WorldParts.ACCENT_SECRET
local ACCENT_OK = WorldParts.ACCENT_OK
local METAL = WorldParts.METAL
local DARK_METAL = WorldParts.DARK_METAL
local PLANT_GREEN = WorldParts.PLANT_GREEN
local CHEESE_PAINT = WorldParts.CHEESE_PAINT
local CHEESE_SPOT = WorldParts.CHEESE_SPOT
local MARS_RED = WorldParts.MARS_RED
local INTERIOR_LIGHT = WorldParts.INTERIOR_LIGHT
local counted = WorldParts.counted
local finish = WorldParts.finish
local part = WorldParts.part
local wedge = WorldParts.wedge
local ball = WorldParts.ball
local cylinder = WorldParts.cylinder
local vcylinder = WorldParts.vcylinder
local box = WorldParts.box
local model = WorldParts.model
local pointLight = WorldParts.pointLight
local weldTo = WorldParts.weldTo
local dirFromAngle = WorldParts.dirFromAngle
local flatUnit = WorldParts.flatUnit
local regolith = WorldParts.regolith
local defaultMarsPosition = WorldSky.defaultMarsPosition

local Secret = {}

------------------------------------------------------------------------------------------------
-- Secrets: four hidden collectibles, the sealed observatory and the team flag
------------------------------------------------------------------------------------------------

-- Every secret place is closed by walls at least 4 studs thick, so the default camera cannot slide
-- into it and nobody sees the item from the base, the paths or the crater floor. Entrances carry no
-- marker (players took the old magenta pebbles for a bug); magenta still means "secret" on the items.

-- Cuts a rectangular hole (in X and Z) out of the ground tiles, keeping each tile's colour.
function Secret.carveGround(ground: Instance, x0: number, x1: number, z0: number, z1: number)
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
function Secret.buildCrawlSpace(base: Instance, ground: Instance): CFrame
	local crawl = model(base, "CrawlSpace")
	local o = HABITAT_CENTRE
	local function v(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	Secret.carveGround(ground, o.X + 8, o.X + 42, o.Z - 24, o.Z - 8)

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
	box(crawl, "VentHousing", v(31, 0, -12), v(42, 11, -8), hull) -- starts at 31: the round hub wall
	-- Stage 7: the hub is round, so this slab closes the shaft's west side (also before the hub stands).
	box(crawl, "VentHousing", v(29.5, 0, -20), v(31, 11, -12), hull)
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
function Secret.buildLookoutRock(base: Instance): CFrame
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
function Secret.buildLavaTube(base: Instance): CFrame
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
function Secret.buildObservatory(base: Instance): ObservatoryRefs
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
	local mars = WorldSky.getMarsPosition() or defaultMarsPosition()
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
function Secret.buildTeamFlag(base: Instance): Model
	local flag = model(base, "TeamFlag")
	-- Stage 7: on the hub's dome (its surface height at this spot, a little sunk in).
	local spot = Vector3.new(10, 0, 6)
	local foot = HABITAT_CENTRE + spot + Vector3.new(0, HUB_ROOF_Y + Geo.domeHeightAt(HUB_DOME_RX, HUB_DOME_RY, spot.Magnitude) - 0.6, 0)
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

function Secret.shapesFor(id: string): { Shape }
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

export type CollectibleItem = { ref: CollectibleRef, root: Part, home: CFrame, phase: number }

function Secret.buildCollectible(parent: Instance, id: string, spot: CFrame, phase: number): CollectibleItem
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
	for i, s in Secret.shapesFor(id) do
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

Secret.COLLECTIBLE_IDS = COLLECTIBLE_IDS

return Secret
