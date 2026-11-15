--!strict
-- Space Base Odyssey - world structures: the Stage 6 build-and-grow pieces (ice drills, conveyor,
-- ice silo, cargo robot, build pads, blueprints, rise-in and dust) and the Stage 7 arrival lander,
-- ground tracks, construction copies (building in steps) and the carried parts crate.
-- Returns the Six table; the Stage 7 helpers are added to WorldParts.Geo.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local WorldParts = require(script.Parent:WaitForChild("WorldParts"))

type Style = WorldParts.Style

local HABITAT_CENTRE = WorldParts.HABITAT_CENTRE
local SHELTER_CENTRE = WorldParts.SHELTER_CENTRE
local CRATER_CENTRE = WorldParts.CRATER_CENTRE
local CRATER_FLOOR_Y = WorldParts.CRATER_FLOOR_Y
local CRATER_RIM_Y = WorldParts.CRATER_RIM_Y
local RIDGE_CENTRE = WorldParts.RIDGE_CENTRE
local RIDGE_TOP_Y = WorldParts.RIDGE_TOP_Y
local ANTENNA_BASE = WorldParts.ANTENNA_BASE
local S7 = WorldParts.S7
local Geo = WorldParts.Geo
local PROMPT_DISTANCE = WorldParts.PROMPT_DISTANCE
local WHITE_HULL = WorldParts.WHITE_HULL
local PALETTE = WorldParts.PALETTE
local ACCENT_SYSTEM = WorldParts.ACCENT_SYSTEM
local ACCENT_WARNING = WorldParts.ACCENT_WARNING
local HULL_TRIM = WorldParts.HULL_TRIM
local METAL = WorldParts.METAL
local DARK_METAL = WorldParts.DARK_METAL
local REGOLITH_LIGHT = WorldParts.REGOLITH_LIGHT
local PANEL_CLEAN = WorldParts.PANEL_CLEAN
local ICE_GLOW = WorldParts.ICE_GLOW
local INTERIOR_LIGHT = WorldParts.INTERIOR_LIGHT
local PULSE_UPDATE_SECONDS = WorldParts.PULSE_UPDATE_SECONDS
local SILO_CENTRE = WorldParts.SILO_CENTRE
local SILO_GLASS_HEIGHT = WorldParts.SILO_GLASS_HEIGHT
local SILO_GLASS_DIAMETER = WorldParts.SILO_GLASS_DIAMETER
local CARGO_DOCK = WorldParts.CARGO_DOCK
local CARGO_RIDE_HEIGHT = WorldParts.CARGO_RIDE_HEIGHT
local DRILL_FLOOR_RADIUS = WorldParts.DRILL_FLOOR_RADIUS
local DRILL_SPREAD = WorldParts.DRILL_SPREAD
local DRILL_PAD_RADIUS = WorldParts.DRILL_PAD_RADIUS
local HOPPER_RADIUS = WorldParts.HOPPER_RADIUS
local CONVEYOR_FOOT_RADIUS = WorldParts.CONVEYOR_FOOT_RADIUS
local ICE_CUBE_COUNT = WorldParts.ICE_CUBE_COUNT
local RISE_SECONDS = WorldParts.RISE_SECONDS
local HOLOGRAM_TRANSPARENCY = WorldParts.HOLOGRAM_TRANSPARENCY
local HOLOGRAM_MIN_PART = WorldParts.HOLOGRAM_MIN_PART
local PAD_DIAMETER = WorldParts.PAD_DIAMETER
local PAD_HEIGHT = WorldParts.PAD_HEIGHT
local PAD_RING_DIAMETER = WorldParts.PAD_RING_DIAMETER
local PAD_MAXED_DIAMETER = WorldParts.PAD_MAXED_DIAMETER
local BUILD_PROMPT_HOLD = WorldParts.BUILD_PROMPT_HOLD
local CARRY_CRATE_NAME = WorldParts.CARRY_CRATE_NAME
local buildState = WorldParts.buildState
local finish = WorldParts.finish
local part = WorldParts.part
local wedge = WorldParts.wedge
local ball = WorldParts.ball
local cylinder = WorldParts.cylinder
local vcylinder = WorldParts.vcylinder
local box = WorldParts.box
local folder = WorldParts.folder
local model = WorldParts.model
local pointLight = WorldParts.pointLight
local zone = WorldParts.zone
local weldTo = WorldParts.weldTo
local UPGRADE_ATTRIBUTE = WorldParts.UPGRADE_ATTRIBUTE
local NO_RISE_ATTRIBUTE = WorldParts.NO_RISE_ATTRIBUTE
local upgrade = WorldParts.upgrade
local belt = WorldParts.belt
local pipe = WorldParts.pipe
local dirFromAngle = WorldParts.dirFromAngle
local flatUnit = WorldParts.flatUnit
local CHEESE_NICHE_OFFSET = WorldParts.CHEESE_NICHE_OFFSET
local GLASS = WorldParts.GLASS
local angleGap = WorldParts.angleGap
local roverSideAngle = WorldParts.roverSideAngle

-- Stage 6 build-and-grow helpers, grouped in one table (a table keeps the module's local count low).
local Six = {}

------------------------------------------------------------------------------------------------
-- Stage 6: automatic ice drills, conveyor, ice silo, cargo robot, build pads and blueprints
------------------------------------------------------------------------------------------------

local DRILL_WARM = PALETTE.gold:Lerp(PALETTE.orange, 0.35) -- warm work lights on the drills
local ICE_LOAD = Color3.fromRGB(205, 236, 250)
local HIDDEN_FOLDER = "SBO_HiddenBuilds"

type Keepout6 = { x: number, z: number, r: number }

-- A point around the crater: angle (see dirFromAngle), distance from its centre, height.
function Six.craterPoint(angle: number, radius: number, y: number): Vector3
	return CRATER_CENTRE + dirFromAngle(angle) * radius + Vector3.new(0, y, 0)
end

-- Angle of the rim segment that hides the cheese niche (same rule as buildCrater: 36 segments).
function Six.nicheAngle(rampAngle: number): number
	local step = math.rad(10)
	return (math.floor((rampAngle + CHEESE_NICHE_OFFSET) / step + 0.5) % 36) * step
end

-- The drills stand on the base's side of the crater, clear of the ramp, the cheese niche and the
-- science rover's loop. Returns the angle of the middle drill.
function Six.chooseDrillAngle(rampAngle: number): number
	local rover = roverSideAngle(rampAngle)
	local niche = Six.nicheAngle(rampAngle)
	local sign = if rover > math.pi then -1 else 1 -- try the side away from the rover first
	for _, offset in { 0, 0.55, -0.55, 0.9, -0.9, 1.25, -1.25 } do
		local angle = math.pi + offset * sign
		if angleGap(angle, rampAngle) >= 0.6 and angleGap(angle, niche) >= 0.6 and angleGap(angle, rover) >= 0.75 then
			return angle
		end
	end
	return math.pi + 1.25 * sign
end

-- Build pad spots: near each structure, beside (not on) the paths and doors. The world sites (lab,
-- garage, landing pad, ship) bring their own pad spots; these are the fallbacks.
function Six.padSpots(drillAngle: number): { [string]: Vector3 }
	return {
		habitat = HABITAT_CENTRE + Vector3.new(-12, 0, -46), -- behind the hub, beside the path from the lander
		solar = Vector3.new(RIDGE_CENTRE.X + 29, RIDGE_TOP_Y, RIDGE_CENTRE.Z + 11), -- ridge top, beside the ramp
		greenhouse = HABITAT_CENTRE + Vector3.new(-37, 0, 18), -- in front of the greenhouse module
		antenna = ANTENNA_BASE + Vector3.new(11, 0, -10), -- between the path and the tower
		shelter = SHELTER_CENTRE + Vector3.new(13, 0, 35), -- beside the tunnel mouth
		drill_1 = Six.craterPoint(drillAngle - DRILL_SPREAD, DRILL_PAD_RADIUS, CRATER_RIM_Y), -- rim, above each drill
		drill_2 = Six.craterPoint(drillAngle + 0.09, DRILL_PAD_RADIUS, CRATER_RIM_Y), -- (next to the rim belt)
		drill_3 = Six.craterPoint(drillAngle + DRILL_SPREAD, DRILL_PAD_RADIUS, CRATER_RIM_Y),
		cargo_bot = SILO_CENTRE + Vector3.new(2, 0, -19), -- behind the silo, off the robot's route
		lab = S7.LAB_CENTRE + Vector3.new(18, 0, -16),
		garage = S7.GARAGE_CENTRE + Vector3.new(-26, 0, -22),
		landing_pad = S7.LANDING_PAD_CENTRE + Vector3.new(36, 0, 14),
		ship = S7.LANDING_PAD_CENTRE + Vector3.new(36, 0, -6),
	}
end

-- The cargo robot's route from its dock by the silo to the conveyor's foot at the crater: east of
-- the hub, through the gap between the crawl-space vent and the shelter mound, out to the crater, then
-- around it on flat ground (r = 140). (Stage 7: the lab now stands west of the hub.)
function Six.cargoRoutePoints(drillAngle: number): { Vector3 }
	local y = CARGO_RIDE_HEIGHT
	local points: { Vector3 } = {
		Vector3.new(CARGO_DOCK.X, y, CARGO_DOCK.Z),
		Vector3.new(24, y, -42),
		Vector3.new(38, y, -36),
		Vector3.new(44.8, y, -24),
		Vector3.new(46, y, -6),
		Vector3.new(36, y, 40),
	}
	local arcRadius = 140
	local steps = math.ceil(math.abs(drillAngle - math.pi) / 0.2)
	for k = 0, steps do
		local angle = if steps > 0 then math.pi + (drillAngle - math.pi) * k / steps else math.pi
		table.insert(points, Six.craterPoint(angle, arcRadius, y))
	end
	local outward = dirFromAngle(drillAngle)
	local side = Vector3.new(-outward.Z, 0, outward.X)
	table.insert(points, Six.craterPoint(drillAngle, CONVEYOR_FOOT_RADIUS + 4.5, y) + side * 3.5)
	return points
end

function Six.keepoutsAlong(points: { Vector3 }, radius: number, spacing: number, into: { Keepout6 })
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

function Six.polyline(points: { Vector3 }): Polyline
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
function Six.alongPolyline(line: Polyline, distance: number): (Vector3, Vector3)
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
export type DrillRefs = { model: Model, bits: { DrillBit } }

-- One automatic ice drill on the crater floor. Its lift belt carries the ice up the rim wall to
-- `beltEnd`. Level 2 adds a taller rig and a second light, level 3 a second bit and a power pack.
function Six.buildDrill(parent: Instance, index: number, angle: number, beltEnd: Vector3): DrillRefs
	local m = model(parent, "IceDrill" .. index)
	local floorPos = Six.craterPoint(angle, DRILL_FLOOR_RADIUS, CRATER_FLOOR_Y)
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
function Six.buildConveyor(base: Instance, angle: number): ConveyorRefs
	local m = model(base, "IceConveyor")
	local outward = dirFromAngle(angle)
	local dark: Style = { color = DARK_METAL, material = Enum.Material.Metal }
	local beltStyle: Style = { color = DARK_METAL, material = Enum.Material.Metal, collide = false }
	local stripe: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }

	local hopperPos = Six.craterPoint(angle, HOPPER_RADIUS, CRATER_RIM_Y + 1.3)
	part(m, "RimHopper", Vector3.new(3.4, 2.6, 3.4), CFrame.lookAt(hopperPos, hopperPos + outward), dark)
	local trimPos = hopperPos + Vector3.new(0, 0.95, 0)
	part(m, "RimHopperTrim", Vector3.new(3.5, 0.35, 3.5), CFrame.lookAt(trimPos, trimPos + outward), stripe)

	local a = Six.craterPoint(angle, HOPPER_RADIUS + 1.7, CRATER_RIM_Y + 0.2)
	local b = Six.craterPoint(angle, 100, CRATER_RIM_Y + 0.2)
	local c = Six.craterPoint(angle, 116.5, 0.2)
	local up = Vector3.new(0, 0.22, 0)
	belt(m, "RimBelt", a, b, 2, 0.4, beltStyle)
	belt(m, "SlopeBelt", b, c, 2, 0.4, beltStyle)
	belt(m, "BeltStripe", a + up, b + up, 0.3, 0.05, stripe)
	belt(m, "BeltStripe", b + up, c + up, 0.3, 0.05, stripe)

	local foot = Six.craterPoint(angle, CONVEYOR_FOOT_RADIUS, 0)
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
	local cubeLine = Six.polyline({ a + lift, b + lift, c + lift })
	local cubes: { BasePart } = {}
	for k = 1, ICE_CUBE_COUNT do
		local position, dir = Six.alongPolyline(cubeLine, (k - 1) * cubeLine.total / ICE_CUBE_COUNT)
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
function Six.buildSilo(base: Instance, pipeEnd: Vector3): SiloRefs
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
	local tankTop = HABITAT_CENTRE + S7.TANK_OFFSET + Vector3.new(0, 9.1, 0)
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
function Six.buildCargoBot(base: Instance, route: Polyline): CargoRefs
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
function Six.buildPad(parent: Instance, id: string, position: Vector3, icon: string): PadRefs
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
function Six.makeHologram(source: Instance, parent: Instance): Instance
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
function Six.risableParts(roots: { Instance }): { BasePart }
	local list: { BasePart } = {}
	local function consider(item: Instance)
		if item:IsA("BasePart") and item.Anchored and item:GetAttribute(NO_RISE_ATTRIBUTE) ~= true and not buildState.risingParts[item] then
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
function Six.riseIn(parts: { BasePart }, drop: number, onStep: ((offset: number) -> ())?, onDone: (() -> ())?)
	local finals: { CFrame } = table.create(#parts)
	for i, p in parts do
		finals[i] = p.CFrame
		buildState.risingParts[p] = true
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
				buildState.risingParts[p] = nil
			end
			if onDone then
				onDone()
			end
		end
	end)
end

-- Dust kicked up where something is built. With no air on the Moon, the dust flies out in arcs and
-- falls straight back down instead of hanging in a cloud.
function Six.dustPuff(parent: Instance, position: Vector3)
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

function Six.hiddenStore(): Folder
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
-- Stage 7: the arrival lander (spawn), ground tracks, building in steps, the carried crate
------------------------------------------------------------------------------------------------

type LanderRefs = {
	model: Model,
	spawn: SpawnLocation,
	zone: Part,
	cratePrompt: ProximityPrompt,
	cratePosition: Vector3,
	door: Vector3, -- ground point at the foot of the ramp
}

-- The lander the crew arrived in: a gold-foil descent stage on four legs with an engine bell, a round
-- crew cabin with a hatch, a porch and a ramp down to the ground. Players spawn inside (its zone
-- always counts as inside: suits refill there). The parts crates for every build wait on a pallet at
-- its cargo bay, on the side facing the base. Built in the lander's own frame: -Z faces the hub.
function Geo.buildLander(base: Instance): LanderRefs
	local m = model(base, "Lander")
	local lc = CFrame.lookAt(S7.LANDER_CENTRE, Vector3.new(HABITAT_CENTRE.X, S7.LANDER_CENTRE.Y, HABITAT_CENTRE.Z))
	local function at(x: number, y: number, z: number): CFrame
		return lc * CFrame.new(x, y, z)
	end
	local function upright(x: number, y: number, z: number): CFrame
		return at(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	end
	local function lb(name: string, a: Vector3, b: Vector3, style: Style): Part
		return Geo.framedBox(m, name, lc, a, b, style)
	end
	local foil: Style = { color = PALETTE.gold:Lerp(Color3.fromRGB(150, 110, 40), 0.35), material = Enum.Material.Foil }
	local hull: Style = { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }
	local dark: Style = { color = DARK_METAL, material = Enum.Material.Metal }
	local metal: Style = { color = METAL, material = Enum.Material.Metal }
	local plate: Style = { color = Color3.fromRGB(150, 154, 160), material = Enum.Material.DiamondPlate }
	local cyan: Style = { color = ACCENT_SYSTEM, material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
	local glow: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }
	local floorY = 10.6

	-- The rocket exhaust blew the dust away when it landed: a darker swept patch inside a brighter ring.
	cylinder(m, "BlastRing", 0.1, 72, upright(0, 0.05, 0), { color = Color3.fromRGB(150, 147, 141), material = Enum.Material.Sand, collide = false, shadow = false })
	cylinder(m, "BlastZone", 0.1, 56, upright(0, 0.08, 0), { color = Color3.fromRGB(102, 100, 96), material = Enum.Material.Sand, collide = false, shadow = false })

	-- Descent stage, deck and engine bell.
	cylinder(m, "DescentStage", 6, 26, upright(0, 7, 0), foil)
	cylinder(m, "Deck", 0.6, 27, upright(0, 10.3, 0), dark)
	cylinder(m, "BottomPlate", 0.4, 24, upright(0, 3.8, 0), dark)
	cylinder(m, "EngineThroat", 1.2, 4.5, upright(0, 3, 0), dark)
	cylinder(m, "EngineBell", 1, 6, upright(0, 1.9, 0), dark)
	cylinder(m, "EngineSkirt", 0.8, 7.5, upright(0, 1, 0), { color = Color3.fromRGB(58, 60, 66), material = Enum.Material.Metal })
	for k = 0, 3 do
		local angle = k * math.pi / 2
		local d = Vector3.new(math.sin(angle), 0, math.cos(angle))
		lb("Thruster", d * 13 + Vector3.new(-0.6, 8.2, -0.6), d * 13.6 + Vector3.new(0.6, 9.4, 0.6), dark)
	end

	-- Four legs with shock struts and round foot pads.
	for k = 0, 3 do
		local angle = math.pi / 4 + k * math.pi / 2
		local d = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local top = (lc * CFrame.new(d * 12.5 + Vector3.new(0, 8, 0))).Position
		local foot = (lc * CFrame.new(d * 19 + Vector3.new(0, 0.9, 0))).Position
		pipe(m, "Leg", top, foot, 0.9, metal)
		local strutTop = (lc * CFrame.new(d * 12 + Vector3.new(0, 4.5, 0))).Position
		local strutFoot = (lc * CFrame.new(d * 18.4 + Vector3.new(0, 1.2, 0))).Position
		pipe(m, "LegStrut", strutTop, strutFoot, 0.6, dark)
		cylinder(m, "FootPad", 0.6, 3.6, upright(d.X * 19, 0.3, d.Z * 19), foil)
	end

	-- Crew cabin: ten wall segments (side windows, a blue solar band), a hatch facing the hub (k = 5).
	local cabinFrame = lc * CFrame.new(0, floorY, 0)
	local segments = Geo.ringSegments(cabinFrame, 11, 1.2, 10, 0)
	local doorSeg = segments[6]
	for _, seg in segments do
		local k = seg.index
		if k == 5 then
			Geo.doorSegment(m, seg, 7, 8.6, 10, 1.2, hull)
		elseif k == 2 or k == 3 or k == 7 or k == 8 then
			Geo.windowSegment(m, seg, 10, 1.2, 4.2, 6.6, hull, GLASS)
		else
			part(m, "Wall", Vector3.new(seg.width, 10, 1.2), seg.cf * CFrame.new(0, 5, 0), hull)
		end
		if k ~= 5 then
			part(m, "SolarBand", Vector3.new(seg.width - 0.5, 1.6, 0.2), seg.cf * CFrame.new(0, 8.4, -0.7), {
				color = PANEL_CLEAN,
				material = Enum.Material.Glass,
				reflectance = 0.12,
				collide = false,
				shadow = false,
			})
		end
	end
	Geo.doorDressing(m, doorSeg, 7, 8.6, 1.2)
	-- The hatch stands open: a door panel swung out on its hinge.
	local hinge = at(-3.5, floorY + 4.3, -12.4)
	part(m, "HatchDoor", Vector3.new(7, 8.6, 0.4), hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(3.5, 0, 0), {
		color = WHITE_HULL,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	cylinder(m, "CabinRoof", 0.8, 25, upright(0, floorY + 10.4, 0), { color = Color3.fromRGB(205, 208, 214), material = Enum.Material.SmoothPlastic })
	local _, cabinCap = Geo.domeShell(m, "CabinDome", at(0, floorY + 10.8, 0).Position, 11.5, 5, hull, {
		bands = 3,
		segments = 10,
		thickness = 0.6,
		capAngle = math.rad(70),
	})
	local capTop = cabinCap.Position.Y + 0.3
	local mastFoot = at(4, 0, 3).Position
	vcylinder(m, "AntennaMast", 4, 0.35, Vector3.new(mastFoot.X, capTop + 1.5, mastFoot.Z), metal)
	cylinder(m, "AntennaDish", 0.3, 2.6, CFrame.new(Vector3.new(mastFoot.X, capTop + 3.6, mastFoot.Z)) * CFrame.Angles(0, 0, math.rad(60)), {
		color = WHITE_HULL,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	ball(m, "Beacon", 0.8, at(-3, 0, -2).Position + Vector3.new(0, capTop + 0.4, 0), glow)

	-- Porch, rails and the ramp down to the ground (a wedge: low end away from the lander).
	lb("Porch", Vector3.new(-4.5, floorY - 0.6, -16.6), Vector3.new(4.5, floorY, -11.4), plate)
	for _, sx in { -4.3, 4.3 } do
		lb("RailPost", Vector3.new(sx - 0.2, floorY, -16.6), Vector3.new(sx + 0.2, floorY + 3, -16.2), cyan)
		lb("Rail", Vector3.new(sx - 0.2, floorY + 2.6, -16.6), Vector3.new(sx + 0.2, floorY + 3, -12.6), cyan)
	end
	wedge(m, "Ramp", Vector3.new(8, floorY, 20), at(0, floorY / 2, -26.6), plate)
	for _, sx in { -4.2, 4.2 } do
		belt(m, "RampRail", at(sx, floorY + 1.2, -16.6).Position, at(sx, 1.2, -36.4).Position, 0.25, 0.25, cyan)
		for i = 1, 3 do
			local z = -16.6 - i * 5
			local y = floorY * (1 - (i * 5) / 20) + 0.15
			part(m, "RampLight", Vector3.new(0.4, 0.2, 0.8), at(sx * 0.93, y, z), glow)
		end
	end

	-- Inside: spawn pad, seats, a console, the suit station (suits refill in here), lockers, a light.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Enabled = true
	spawnPad.AllowTeamChangeOnTouch = false
	finish(spawnPad, m, "LanderSpawn", Vector3.new(6, 0.4, 6), at(0, floorY + 0.2, 3.5), {
		color = ACCENT_SYSTEM:Lerp(PALETTE.night, 0.35),
		material = Enum.Material.SmoothPlastic,
	})
	for _, sx in { -5.5, 5.5 } do
		lb("Seat", Vector3.new(sx - 1.2, floorY, 5), Vector3.new(sx + 1.2, floorY + 1.6, 7.4), { color = PALETTE.nightLight, material = Enum.Material.Fabric })
		lb("SeatBack", Vector3.new(sx - 1.2, floorY + 1.6, 7), Vector3.new(sx + 1.2, floorY + 4.6, 7.5), { color = PALETTE.nightLight, material = Enum.Material.Fabric })
	end
	lb("CabinConsole", Vector3.new(-8.5, floorY, -5), Vector3.new(-5.5, floorY + 2.8, -1), dark)
	lb("CabinScreen", Vector3.new(-5.6, floorY + 2.8, -4.6), Vector3.new(-5.4, floorY + 4.6, -1.4), glow)
	lb("SuitStation", Vector3.new(5.8, floorY, -6), Vector3.new(8.4, floorY + 5.4, -2.5), hull)
	lb("SuitStationGlow", Vector3.new(5.6, floorY + 1.4, -5.5), Vector3.new(5.8, floorY + 4.9, -3), glow)
	lb("Locker", Vector3.new(-3, floorY, 8.6), Vector3.new(3, floorY + 5.9, 10.2), metal)
	lb("LockerStripe", Vector3.new(-3.05, floorY + 4.6, 8.5), Vector3.new(3.05, floorY + 5, 8.6), { color = ACCENT_WARNING, material = Enum.Material.SmoothPlastic, collide = false, shadow = false })
	local cabinLight = lb("CabinLight", Vector3.new(-3, floorY + 9.5, -0.6), Vector3.new(3, floorY + 10, 0.6), {
		color = Color3.fromRGB(255, 240, 215),
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	pointLight(cabinLight, INTERIOR_LIGHT, 16, 0.9, true)

	-- Inside zone (rotated with the lander; WorldBuilder.isInZone handles that).
	local zonePart = Instance.new("Part")
	zonePart.Name = "LanderZone"
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.CanQuery = false
	zonePart.CanTouch = false
	zonePart.CastShadow = false
	zonePart.Transparency = 1
	zonePart.Size = Vector3.new(16, 9.4, 16)
	zonePart.CFrame = at(0, floorY + 0.2 + 4.7, 0)
	zonePart.Parent = base

	-- Cargo bay: the parts crates on a pallet beside the ramp, a small crane arm and a floodlight.
	local pallet = lb("DepotPallet", Vector3.new(10.5, 0, -24.5), Vector3.new(17.5, 0.6, -17.5), dark)
	for _, cx in { 10.7, 17.3 } do
		for _, cz in { -24.3, -17.7 } do
			lb("DepotPost", Vector3.new(cx - 0.25, 0.6, cz - 0.25), Vector3.new(cx + 0.25, 6.6, cz + 0.25), metal)
		end
	end
	lb("DepotBeam", Vector3.new(10.45, 6.6, -24.55), Vector3.new(17.55, 7.1, -24.05), metal)
	lb("DepotBeam", Vector3.new(10.45, 6.6, -17.95), Vector3.new(17.55, 7.1, -17.45), metal)
	local crateStyle: Style = { color = Color3.fromRGB(90, 96, 108), material = Enum.Material.Metal }
	local crateStripe: Style = { color = ACCENT_SYSTEM, material = Enum.Material.SmoothPlastic, shadow = false }
	local crateSpots = {
		Vector3.new(12, 0.6, -23), Vector3.new(14.2, 0.6, -23), Vector3.new(16.2, 0.6, -21.6),
		Vector3.new(12.4, 0.6, -20.4), Vector3.new(13.1, 2.6, -22.4), Vector3.new(15.4, 2.6, -21.8),
	}
	for i, spot in crateSpots do
		local turn = CFrame.Angles(0, math.rad((i * 23) % 40 - 20), 0)
		part(m, "PartsCrate", Vector3.new(1.9, 1.9, 1.9), at(spot.X, spot.Y + 0.95, spot.Z) * turn, crateStyle)
		part(m, "CrateStripe", Vector3.new(1.95, 0.35, 1.95), at(spot.X, spot.Y + 1.3, spot.Z) * turn, crateStripe)
	end
	belt(m, "CraneArm", at(9, 9.6, -9).Position, at(14, 9.6, -21).Position, 0.6, 0.6, metal)
	lb("CraneCable", Vector3.new(13.95, 6.6, -21.05), Vector3.new(14.05, 9.4, -20.95), { color = DARK_METAL, material = Enum.Material.Metal, collide = false, shadow = false })
	local sign = part(m, "DepotSign", Vector3.new(2.4, 2.4, 0.2), at(14, 8.4, -24.7), {
		color = PALETTE.night,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "CrateIcon"
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.CanvasSize = Vector2.new(64, 64)
	signGui.Parent = sign
	local signIcon = Instance.new("ImageLabel")
	signIcon.BackgroundTransparency = 1
	signIcon.Size = UDim2.fromScale(0.8, 0.8)
	signIcon.Position = UDim2.fromScale(0.1, 0.1)
	signIcon.Image = Icons.crate
	signIcon.ImageColor3 = ACCENT_SYSTEM
	signIcon.Parent = signGui
	local palletCentre = at(14, 0.6, -21).Position
	local lampPos = at(19, 8, -26).Position
	lb("FloodPole", Vector3.new(18.8, 0, -26.2), Vector3.new(19.2, 7.6, -25.8), metal)
	local flood = part(m, "FloodLamp", Vector3.new(1.2, 0.8, 0.6), CFrame.lookAt(lampPos, palletCentre), {
		color = Color3.fromRGB(255, 240, 215),
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	local floodLight = Instance.new("SpotLight")
	floodLight.Face = Enum.NormalId.Front
	floodLight.Range = 22
	floodLight.Angle = 70
	floodLight.Brightness = 1.4
	floodLight.Color = Color3.fromRGB(255, 240, 215)
	floodLight.Shadows = false
	floodLight.Parent = flood

	-- Take-a-crate prompt (BaseService gives the crate; it is always on).
	local promptPoint = Instance.new("Attachment")
	promptPoint.Name = "PromptPoint"
	promptPoint.Position = Vector3.new(0, 2.4, 0)
	promptPoint.Parent = pallet
	local cratePrompt = Instance.new("ProximityPrompt")
	cratePrompt.Name = "CratePrompt"
	cratePrompt.ActionText = "Take parts"
	cratePrompt.ObjectText = ""
	cratePrompt.HoldDuration = 0.5
	cratePrompt.MaxActivationDistance = PROMPT_DISTANCE
	cratePrompt.RequiresLineOfSight = false
	cratePrompt.Enabled = true
	cratePrompt:SetAttribute("TextKey", "prompt.take_crate")
	cratePrompt.Parent = promptPoint

	for _, item in m:GetDescendants() do
		if item:IsA("SpotLight") and item ~= floodLight then
			item.Brightness = math.min(item.Brightness, 1.2)
		end
	end

	return {
		model = m,
		spawn = spawnPad,
		zone = zonePart,
		cratePrompt = cratePrompt,
		cratePosition = palletCentre,
		door = at(0, 0, -38).Position,
	}
end

-- Rover tracks on the ground between buildings: two dusty ruts along each path (no collisions).
function Geo.buildTracks(base: Instance, paths: { { Vector3 } }, lightPaths: { [number]: boolean })
	local tracks = folder(base, "Tracks")
	local rut: Style = { color = Color3.fromRGB(100, 98, 94), material = Enum.Material.Sand, collide = false, shadow = false }
	local pole: Style = { color = DARK_METAL, material = Enum.Material.Metal, shadow = false }
	local cap: Style = { color = ACCENT_SYSTEM, material = Enum.Material.Neon, collide = false, shadow = false }
	for index, points in paths do
		local sinceLight = 0
		for i = 1, #points - 1 do
			local a = Vector3.new(points[i].X, 0.16, points[i].Z)
			local b = Vector3.new(points[i + 1].X, 0.16, points[i + 1].Z)
			local dir = flatUnit(b - a, Vector3.zAxis)
			local side = Vector3.new(-dir.Z, 0, dir.X)
			for _, s in { -1.9, 1.9 } do
				belt(tracks, "Track", a + side * s, b + side * s, 1, 0.06, rut)
			end
			-- Small path lights beside the busy paths (neon caps, no light sources).
			if lightPaths[index] then
				local length = (b - a).Magnitude
				local d = 24 - sinceLight
				while d < length do
					local spot = a + dir * d + side * 4.5
					vcylinder(tracks, "PathLightPole", 2, 0.3, Vector3.new(spot.X, 1, spot.Z), pole)
					box(tracks, "PathLight", Vector3.new(spot.X - 0.3, 2, spot.Z - 0.3), Vector3.new(spot.X + 0.3, 2.4, spot.Z + 0.3), cap)
					d += 24
				end
				sinceLight = length - (d - 24)
			end
		end
	end
end

-- Construction copy of a structure for a build in progress: the real look (colours and materials)
-- with nothing that works (no collisions, lights, prompts, GUIs, effects, joints). Upgrade parts and
-- invisible parts are left out. Returns the copy, its parts with their own transparency and their
-- bottom height, and the copy's lowest and highest points.
type CopyPart = { part: BasePart, alpha: number, bottom: number, shown: boolean }
export type ConstructionCopy = { instance: Instance, parts: { CopyPart }, minY: number, maxY: number, minV: Vector3, maxV: Vector3 }

function Geo.makeConstructionCopy(source: Instance, parent: Instance): ConstructionCopy
	local copy = source:Clone()
	copy.Name = source.Name .. "Construction"
	local parts: { CopyPart } = {}
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	local candidates: { Instance } = copy:GetDescendants()
	table.insert(candidates, copy)
	for _, item in candidates do
		if item.Parent == nil and item ~= copy then
			continue
		end
		if item:IsA("BasePart") then
			local upgradeLevel = item:GetAttribute(UPGRADE_ATTRIBUTE)
			local isUpgrade = type(upgradeLevel) == "number" and upgradeLevel > 1
			local invisible = upgradeLevel == nil and item.Transparency >= 0.95
			if isUpgrade or invisible then
				item:Destroy()
			else
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.CastShadow = false
				local lo, hi = Geo.partBounds(item)
				minV = minV:Min(lo)
				maxV = maxV:Max(hi)
				table.insert(parts, { part = item, alpha = item.Transparency, bottom = lo.Y, shown = false })
				item.Transparency = 1
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
			or item:IsA("Sound")
		then
			item:Destroy()
		end
	end
	copy.Parent = parent
	if #parts == 0 then
		minV, maxV = Vector3.zero, Vector3.zero
	end
	return { instance = copy, parts = parts, minY = minV.Y, maxY = maxV.Y, minV = minV, maxV = maxV }
end

-- Foundation outline of a build in progress: construction-orange strips around its footprint and a
-- short post at each corner.
function Geo.constructionOutline(parent: Instance, minV: Vector3, maxV: Vector3, y: number)
	local tape: Style = { color = PALETTE.orange, material = Enum.Material.Neon, collide = false, shadow = false }
	local post: Style = { color = DARK_METAL, material = Enum.Material.Metal, collide = false, shadow = false }
	local x0, x1, z0, z1 = minV.X - 0.6, maxV.X + 0.6, minV.Z - 0.6, maxV.Z + 0.6
	local w = 0.45
	box(parent, "Outline", Vector3.new(x0, y, z0), Vector3.new(x1, y + 0.12, z0 + w), tape)
	box(parent, "Outline", Vector3.new(x0, y, z1 - w), Vector3.new(x1, y + 0.12, z1), tape)
	box(parent, "Outline", Vector3.new(x0, y, z0), Vector3.new(x0 + w, y + 0.12, z1), tape)
	box(parent, "Outline", Vector3.new(x1 - w, y, z0), Vector3.new(x1, y + 0.12, z1), tape)
	for _, cx in { x0, x1 } do
		for _, cz in { z0, z1 } do
			box(parent, "OutlinePost", Vector3.new(cx - 0.3, y, cz - 0.3), Vector3.new(cx + 0.3, y + 3, cz + 0.3), post)
			box(parent, "OutlineTop", Vector3.new(cx - 0.35, y + 3, cz - 0.35), Vector3.new(cx + 0.35, y + 3.5, cz + 0.35), tape)
		end
	end
end

-- Fallback meteorite crater when WorldSites is missing: a dark bowl inside bright fresh ejecta with
-- rays, a hot glowing rock and a scan prompt. No fiery streak: the Moon has no air to burn the rock.
function Geo.fallbackImpact(impacts: Instance, position: Vector3): (Model, ProximityPrompt)
	local m = Instance.new("Model")
	m.Name = "Impact"
	local ground = Vector3.new(position.X, 0, position.Z)
	local flat = CFrame.Angles(0, 0, math.rad(90))
	local fresh: Style = { color = Color3.fromRGB(196, 194, 188), material = Enum.Material.Sand, collide = false, shadow = false }
	cylinder(m, "Ejecta", 0.12, 22, CFrame.new(ground + Vector3.new(0, 0.2, 0)) * flat, fresh)
	cylinder(m, "Bowl", 0.14, 11, CFrame.new(ground + Vector3.new(0, 0.24, 0)) * flat, {
		color = Color3.fromRGB(78, 76, 72),
		material = Enum.Material.Sand,
		collide = false,
		shadow = false,
	})
	for k = 0, 5 do
		local dir = dirFromAngle(k * math.pi / 3 + 0.3)
		belt(m, "Ray", ground + dir * 9 + Vector3.new(0, 0.18, 0), ground + dir * (20 + k % 3 * 5) + Vector3.new(0, 0.18, 0), 1.4, 0.08, fresh)
	end
	local rock = ball(m, "HotRock", 2.2, ground + Vector3.new(0, 0.9, 0), {
		color = PALETTE.orange,
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	local glowLight = pointLight(rock, PALETTE.orange, 14, 1.6, false)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScanPrompt"
	prompt.ActionText = "Scan"
	prompt.ObjectText = ""
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt:SetAttribute("TextKey", "prompt.scan")
	prompt.Parent = rock
	m.PrimaryPart = rock
	m.Parent = impacts
	-- The flash when it hits, then dust that flies out and falls straight back down (no air).
	glowLight.Brightness = 8
	glowLight.Range = 40
	TweenService:Create(glowLight, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 1.6, Range = 14 }):Play()
	Six.dustPuff(m, ground)
	return m, prompt
end

-- The parts crate a player carries from the lander to a build pad: a small Massless model welded in
-- front of the character (no collisions, so it never trips anyone).
function Geo.carriedCrate(character: Model, rootPart: BasePart)
	local m = Instance.new("Model")
	m.Name = CARRY_CRATE_NAME
	local cf = rootPart.CFrame * CFrame.new(0, 0.2, -1.9)
	local list: { BasePart } = {}
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		table.insert(list, p)
	end
	piece("Crate", Vector3.new(2, 1.6, 1.6), CFrame.new(), Color3.fromRGB(90, 96, 108), Enum.Material.Metal)
	piece("Stripe", Vector3.new(2.05, 0.3, 1.65), CFrame.new(0, 0.3, 0), ACCENT_SYSTEM, Enum.Material.SmoothPlastic)
	piece("Lid", Vector3.new(1.8, 0.15, 1.4), CFrame.new(0, 0.85, 0), METAL, Enum.Material.Metal)
	for _, x in { -1.08, 1.08 } do
		piece("Handle", Vector3.new(0.15, 0.3, 0.9), CFrame.new(x, 0.1, 0), DARK_METAL, Enum.Material.Metal)
	end
	piece("Label", Vector3.new(0.7, 0.5, 0.05), CFrame.new(0, -0.25, -0.81), PALETTE.gold, Enum.Material.SmoothPlastic)
	m.PrimaryPart = list[1]
	m.Parent = character
	for i = 2, #list do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = list[1]
		weld.Part1 = list[i]
		weld.Parent = list[i]
	end
	local holdWeld = Instance.new("WeldConstraint")
	holdWeld.Part0 = rootPart
	holdWeld.Part1 = list[1]
	holdWeld.Parent = list[1]
	for _, p in list do
		p.Anchored = false
	end
end

------------------------------------------------------------------------------------------------
-- Stage 9: the habitat is the base level (the "town hall", 1 to 5). Each habitat level adds its own
-- visible parts to the hub, tagged with upgrade(p, level) so they only show (and rise in, step by
-- step, with crates and the wrench) from that level on:
--   2 Science outpost: a second ring of lit windows on the dome and a small dish on the roof.
--   3 Mining base: a side module (below the window band) with an orange work beacon.
--   4 Explorer base: a bigger dome cap (glass lookout) and a solar wrap around the dome.
--   5 Moon spaceport: a tall comms mast with a gold beacon and gold trim on the hub.
-- None of these parts closes a doorway or touches the inside zone. Returns the parts that should be
-- solid once their level stands (upgrade() makes every tagged part non-solid; WorldBuilder turns
-- these back on in the habitat's onLevel).
------------------------------------------------------------------------------------------------

export type HabitatTierSolid = { part: BasePart, level: number }

function Six.buildHabitatTiers(hab: Instance, centre: Vector3, capTop: number, doorSegments: { [number]: boolean }): { HabitatTierSolid }
	local rx = WorldParts.HUB_DOME_RX
	local ry = WorldParts.HUB_DOME_RY
	local roofY = WorldParts.HUB_ROOF_Y
	local segments = WorldParts.HUB_SEGMENTS
	local outer = WorldParts.HUB_APOTHEM + WorldParts.HUB_WALL
	local gold = PALETTE.gold
	local solids: { HabitatTierSolid } = {}
	local function tier(p: BasePart, level: number, solid: boolean?): BasePart
		upgrade(p, level)
		if solid then
			table.insert(solids, { part = p, level = level })
		end
		return p
	end
	-- A frame on the dome's outer surface at distance r from the centre, facing out along the normal
	-- (local -Z = out, local Y = up the slope), lifted `lift` studs off the surface.
	local function onDome(r: number, angle: number, lift: number): CFrame
		local h = Geo.domeHeightAt(rx, ry, r)
		local dir = dirFromAngle(angle)
		local normal = (dir * (r / (rx * rx)) + Vector3.yAxis * (h / (ry * ry))).Unit
		local at = centre + dir * r + Vector3.new(0, roofY + h, 0) + normal * lift
		return CFrame.lookAt(at, at + normal, Vector3.yAxis)
	end
	local function roofFoot(x: number, z: number): Vector3
		local r = Vector3.new(x, 0, z).Magnitude
		return centre + Vector3.new(x, roofY + Geo.domeHeightAt(rx, ry, r) - 0.3, z)
	end
	local noShadow = function(color: Color3, material: Enum.Material): Style
		return { color = color, material = material, collide = false, shadow = false }
	end

	-- Level 2: lit windows around the lower dome (warm light from the rooms) and a small dish.
	local windowStyle: Style = { color = PALETTE.cream, material = Enum.Material.Neon, transparency = 0.15, collide = false, shadow = false }
	for k = 0, segments - 1 do
		local angle = (k + 0.5) * 2 * math.pi / segments
		tier(part(hab, "Tier2Window", Vector3.new(3.4, 1.5, 0.3), onDome(30.3, angle, 0.45), windowStyle), 2)
	end
	local dishFoot = roofFoot(-8, -6)
	tier(vcylinder(hab, "Tier2DishMast", 3.4, 0.45, dishFoot + Vector3.new(0, 1.7, 0), noShadow(METAL, Enum.Material.Metal)), 2)
	tier(cylinder(hab, "Tier2Dish", 0.35, 3.4, CFrame.new(dishFoot + Vector3.new(0, 3.8, 0)) * CFrame.Angles(0, math.rad(35), math.rad(55)), noShadow(WHITE_HULL, Enum.Material.SmoothPlastic)), 2)
	tier(ball(hab, "Tier2DishTip", 0.85, dishFoot + Vector3.new(0.5, 4.6, -0.35), noShadow(ACCENT_SYSTEM, Enum.Material.Neon)), 2)

	-- Level 3: a side module on the north-west wall (segment 14: no door, path or pad there), below
	-- the window band so the room keeps its view, and an orange work beacon on its roof.
	local moduleSegment = 14
	local moduleAngle = moduleSegment * 2 * math.pi / segments
	local moduleDir = dirFromAngle(moduleAngle)
	local depth = 7
	local moduleFrame = CFrame.lookAt(centre + moduleDir * (outer + depth / 2), centre + moduleDir * (outer + depth + 1))
	local function onModule(x: number, y: number, z: number): CFrame
		return moduleFrame * CFrame.new(x, y, z)
	end
	tier(part(hab, "Tier3Module", Vector3.new(12, 6, depth), onModule(0, 3.5, 0), { color = WHITE_HULL, material = Enum.Material.SmoothPlastic }), 3, true)
	tier(part(hab, "Tier3ModuleRoof", Vector3.new(12.6, 0.5, depth + 0.6), onModule(0, 6.75, 0), noShadow(HULL_TRIM, Enum.Material.SmoothPlastic)), 3)
	tier(part(hab, "Tier3ModuleStripe", Vector3.new(12.1, 0.5, 0.2), onModule(0, 1.4, -(depth / 2 + 0.1)), noShadow(ACCENT_WARNING, Enum.Material.Neon)), 3)
	tier(part(hab, "Tier3ModuleWindow", Vector3.new(6, 1.6, 0.2), onModule(0, 4.2, -(depth / 2 + 0.1)), {
		color = ACCENT_SYSTEM:Lerp(PALETTE.night, 0.45),
		material = Enum.Material.Glass,
		reflectance = 0.2,
		collide = false,
		shadow = false,
	}), 3)
	tier(part(hab, "Tier3BeaconMast", Vector3.new(0.4, 2.2, 0.4), onModule(4.5, 8.1, 1.5), noShadow(METAL, Enum.Material.Metal)), 3)
	local beacon = ball(hab, "Tier3Beacon", 1.3, onModule(4.5, 9.6, 1.5).Position, noShadow(ACCENT_WARNING, Enum.Material.Neon))
	pointLight(beacon, ACCENT_WARNING, 12, 1, false)
	tier(beacon, 3)

	-- Level 4: a glass lookout on top of the dome (bigger cap) and blue solar cells around the dome.
	tier(vcylinder(hab, "Tier4CapRing", 0.6, 12, Vector3.new(centre.X, capTop + 0.4, centre.Z), noShadow(HULL_TRIM, Enum.Material.SmoothPlastic)), 4)
	tier(ball(hab, "Tier4Lookout", 9, Vector3.new(centre.X, capTop + 0.7, centre.Z), {
		color = ACCENT_SYSTEM:Lerp(PALETTE.night, 0.3),
		material = Enum.Material.Glass,
		transparency = 0.35,
		reflectance = 0.25,
		collide = false,
		shadow = false,
	}), 4)
	local solarStyle: Style = { color = PANEL_CLEAN, material = Enum.Material.Glass, reflectance = 0.15, collide = false, shadow = false }
	for k = 0, segments - 1 do
		local angle = k * 2 * math.pi / segments
		tier(part(hab, "Tier4SolarWrap", Vector3.new(7, 3.4, 0.25), onDome(25.5, angle, 0.45), solarStyle), 4)
	end

	-- Level 5: a tall comms mast with a gold beacon, and gold trim on the walls, the roof edge and the
	-- lookout (the side module's segment keeps its own roof line).
	local mastFoot = roofFoot(-7, 9)
	tier(box(hab, "Tier5MastBase", mastFoot + Vector3.new(-1.3, -0.4, -1.3), mastFoot + Vector3.new(1.3, 0.8, 1.3), { color = DARK_METAL, material = Enum.Material.Metal }), 5, true)
	tier(vcylinder(hab, "Tier5Mast", 20, 0.8, mastFoot + Vector3.new(0, 10.8, 0), { color = METAL, material = Enum.Material.Metal }), 5, true)
	for i, y in { 7, 13, 18 } do
		local width = 4.4 - i
		tier(part(hab, "Tier5MastBar", Vector3.new(width, 0.25, 0.25), CFrame.new(mastFoot + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(30 * i), 0), noShadow(METAL, Enum.Material.Metal)), 5)
	end
	tier(vcylinder(hab, "Tier5MastRing", 0.35, 1.5, mastFoot + Vector3.new(0, 10, 0), noShadow(gold, Enum.Material.Neon)), 5)
	local topBeacon = ball(hab, "Tier5Beacon", 1.5, mastFoot + Vector3.new(0, 21.4, 0), noShadow(gold, Enum.Material.Neon))
	pointLight(topBeacon, gold, 16, 1, false)
	tier(topBeacon, 5)
	tier(vcylinder(hab, "Tier5GoldEdge", 0.3, outer * 2 + 3, centre + Vector3.new(0, WorldParts.HUB_WALL_HEIGHT + 0.35, 0), noShadow(gold, Enum.Material.SmoothPlastic)), 5)
	tier(vcylinder(hab, "Tier5GoldCap", 0.3, 12.8, Vector3.new(centre.X, capTop + 0.15, centre.Z), noShadow(gold, Enum.Material.SmoothPlastic)), 5)
	for _, seg in Geo.ringSegments(CFrame.new(centre), WorldParts.HUB_APOTHEM, WorldParts.HUB_WALL, segments, 0) do
		if not doorSegments[seg.index] and seg.index ~= moduleSegment then
			tier(part(hab, "Tier5GoldTrim", Vector3.new(seg.width, 0.4, 0.2), seg.cf * CFrame.new(0, 6.6, -(WorldParts.HUB_WALL / 2 + 0.14)), noShadow(gold, Enum.Material.SmoothPlastic)), 5)
		end
	end
	return solids
end

return Six
