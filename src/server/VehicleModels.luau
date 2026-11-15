--!strict
-- Space Base Odyssey - part models and physics rigs for the two garage vehicles (Stage 7).
--   * "buggy": an open two-seat moon buggy inspired by the Apollo Lunar Roving Vehicle (driven on
--     Apollo 15, 16 and 17): wire-mesh wheels with chevron treads, fenders against flying dust, a
--     high-gain dish, a TV camera and a gold-foil electronics box at the front, a hand controller
--     between the seats and a tool pallet at the back. No logos or insignia.
--   * "hauler": a pressurized-cab cargo hauler (big windows, suitports on the back of the cab, roof
--     radiator, headlights) with an open bed that shows up to four ice cores.
-- Physics (Workspace.Gravity 32.4, the Moon's 1/6): a heavy, low, invisible ballast keeps the centre
-- of mass low; each wheel hangs on a PrismaticConstraint slider with a SpringConstraint whose
-- stiffness comes from the real vehicle mass (so it never bottoms out); the front wheels steer with
-- a Servo HingeConstraint and every wheel is driven by a Motor HingeConstraint. Wheels are grippy
-- (friction 1.5, FrictionWeight 100): with 1/6 gravity little weight presses them on the ground.
-- Steering narrows with speed so a turn can never tip the vehicle over (VehicleModels.steerLimit).
-- What the client reads (src/client/VehicleClient.luau): HingeConstraints named "DriveMotor" and
-- "SteerServo"; the VehicleSeat "DriverSeat" and Seat "PassengerSeat"; model attributes
-- SBO_VehicleId, SBO_MaxSpeed, SBO_WheelRadius, SBO_Wheelbase, SBO_MaxSteer, SBO_MinSteer,
-- SBO_TurnAccel, SBO_Reverse, SBO_DriveSign, SBO_SteerSign, SBO_Cargo, SBO_CargoMax.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local PALETTE = Theme.PALETTE
local ROLE = Theme.ROLE

export type Rig = {
	id: string,
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	seats: { BasePart }, -- every seat (driver first)
	motors: { HingeConstraint },
	servos: { HingeConstraint },
	cargoPart: BasePart?, -- the hauler's tailgate (load / unload prompts)
	cargoCores: { BasePart },
	cargoMax: number,
	maxSpeed: number,
	wheelRadius: number,
	wheelbase: number,
	maxSteerDeg: number,
	minSteerDeg: number,
	turnAccel: number, -- sideways acceleration (studs/s^2) a turn may ask for
	reverseFraction: number,
	rideHeight: number, -- chassis centre above the ground at rest
	length: number,
}

export type Options = {
	maxSpeed: number,
	cargo: number?,
}

local VehicleModels = {}

-- Look (not gameplay numbers). Neutral hull colours match WorldBuilder; accents are Theme colours.
local WHITE_HULL = Color3.fromRGB(226, 228, 232)
local METAL = Color3.fromRGB(150, 155, 162)
local DARK_METAL = Color3.fromRGB(70, 74, 82)
local WIRE_MESH = Color3.fromRGB(184, 188, 194)
local SEAT_WEB = Color3.fromRGB(54, 58, 66)
local GLASS = Color3.fromRGB(170, 215, 235)
local ICE_GLOW = Color3.fromRGB(170, 232, 255)
local ACCENT = ROLE.accent -- cyan trim and screens
local FOIL = PALETTE.gold -- thermal blanket over the electronics
local LAMP = PALETTE.cream
local TAIL = ROLE.warning
local STATUS = ROLE.good
local CORE_SHOWN = 0.2 -- ice core transparency when it is on the bed

-- Physics tuning (technical settings, not gameplay numbers).
local RIDER_MASS = 15 -- allowance per seat for a sitting astronaut
local SAG = 0.35 -- studs each spring is squeezed at rest
local DAMPING_RATIO = 0.55 -- of critical damping
local DRIVE_ACCEL = 20 -- studs/s^2 on flat ground ...
local SLOPE_GRADE = 0.6 -- ... plus enough torque to climb this grade (rise / run)
local RAMP_SECONDS = 1.6 -- from stop to full wheel speed
local STEER_SPEED = 3 -- rad/s the front wheels turn
local STEER_TORQUE_ARM = 4 -- servo torque = corner weight * this
local TURN_SAFETY = 0.5 -- fraction of the tip-over sideways acceleration a turn may use
local MAX_STEER_DEG = 30
local MIN_STEER_DEG = 6
local REVERSE_FRACTION = 0.45
-- Directions (HingeConstraint right-hand rule): with the axle attachment's X axis pointing to the
-- vehicle's left, a positive motor speed rolls it forward; a positive servo angle turns it left
-- (the VehicleSeat says +1 for right). If a test in Studio shows a wrong direction, flip one sign.
local DRIVE_SIGN = 1
local STEER_SIGN = -1
local WHEEL_FRICTION = 1.5
local GRIP_WEIGHT = 100
local CHASSIS_FRICTION = 0.3
local CHASSIS_DENSITY = 2
local BALLAST_DENSITY = 8
local HUB_DENSITY = 40
local WHEEL_DENSITY = 1.5

-- Orientations: Roblox cylinders and constraint axes run along a part's / attachment's X axis.
local AXIS_UP = CFrame.Angles(0, 0, math.rad(90)) -- X axis points up
local AXIS_FORWARD = CFrame.Angles(0, math.rad(90), 0) -- X axis points forward (-Z)
local AXLE = CFrame.Angles(0, math.rad(180), 0) -- X axis points left

type Look = { color: Color3, material: Enum.Material?, transparency: number?, shadow: boolean? }

type Ctx = {
	origin: CFrame,
	model: Model,
	chassis: BasePart,
	unsprung: { [BasePart]: boolean },
	springs: { { spring: SpringConstraint, height: number } },
	motors: { HingeConstraint },
	servos: { HingeConstraint },
}

type Gear = {
	radius: number,
	width: number,
	wheelbase: number,
	track: number,
	knuckle: Vector3,
	steerSize: number,
	springHeight: number,
	travelUp: number,
	travelDown: number,
	tire: Look,
	hub: Look,
	tread: Look,
	treads: number,
	treadLength: number,
}

type Fittings = {
	seat: VehicleSeat,
	seats: { BasePart },
	seatHeight: number,
	cargoPart: BasePart?,
	cargoCores: { BasePart },
}

type Spec = {
	modelName: string,
	length: number,
	chassisSize: Vector3,
	chassisY: number,
	ballastSize: Vector3,
	ballastY: number,
	gear: Gear,
	fit: (ctx: Ctx, gear: Gear) -> Fittings,
}

local function look(color: Color3, material: Enum.Material?, transparency: number?): Look
	return { color = color, material = material, transparency = transparency }
end

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, l: Look, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = l.color
	p.Material = l.material or Enum.Material.SmoothPlastic
	p.Transparency = l.transparency or 0
	p.CastShadow = l.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weld(anchor: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = part
	w.Parent = part
end

-- A decoration welded to `anchor`: no mass, no collisions, invisible to raycasts (the camera never
-- pops in on it).
local function deco(ctx: Ctx, anchor: BasePart, name: string, size: Vector3, localCF: CFrame, l: Look, shape: Enum.PartType?): Part
	local p = newPart(ctx.model, name, size, ctx.origin * localCF, l, shape)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	weld(anchor, p)
	return p
end

-- A part that carries mass (and maybe collides).
local function body(ctx: Ctx, name: string, size: Vector3, localCF: CFrame, l: Look, density: number, friction: number, collide: boolean, shape: Enum.PartType?): Part
	local p = newPart(ctx.model, name, size, ctx.origin * localCF, l, shape)
	p.CanCollide = collide
	p.CanTouch = collide
	p.CanQuery = collide
	p.CustomPhysicalProperties = PhysicalProperties.new(density, friction, 0, 1, 1)
	return p
end

local function attach(part: BasePart, name: string, worldCF: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = worldCF
	return a
end

local function light(parent: BasePart, kind: "Point" | "Spot", color: Color3, range: number, brightness: number)
	if kind == "Spot" then
		local spot = Instance.new("SpotLight")
		spot.Color = color
		spot.Brightness = brightness
		spot.Shadows = false
		spot.Range = range
		spot.Angle = 70
		spot.Face = Enum.NormalId.Front
		spot.Parent = parent
	else
		local point = Instance.new("PointLight")
		point.Color = color
		point.Brightness = brightness
		point.Shadows = false
		point.Range = range
		point.Parent = parent
	end
end

local function newSeat(ctx: Ctx, className: "VehicleSeat" | "Seat", name: string, size: Vector3, localCF: CFrame): BasePart
	local seat: BasePart
	if className == "VehicleSeat" then
		local vehicleSeat = Instance.new("VehicleSeat")
		vehicleSeat.HeadsUpDisplay = false -- VehicleClient shows its own panel
		seat = vehicleSeat
	else
		seat = Instance.new("Seat")
	end
	seat.Name = name
	seat.Size = size
	seat.CFrame = ctx.origin * localCF
	seat.Anchored = true
	seat.Color = SEAT_WEB
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.CanCollide = false
	seat.CanTouch = true -- sitting down by touch still works
	seat.CanQuery = false
	seat.Massless = true
	seat.Parent = ctx.model
	weld(ctx.chassis, seat)
	return seat
end

----------------------------------------------------------------------------------------------------
-- Running gear: four sprung wheels, the front two steer, all four drive.

local function buildWheels(ctx: Ctx, gear: Gear)
	local radius = gear.radius
	local halfTrack = gear.track / 2
	local halfBase = gear.wheelbase / 2
	local corners = {
		{ x = -halfTrack, z = -halfBase, front = true, name = "FL" },
		{ x = halfTrack, z = -halfBase, front = true, name = "FR" },
		{ x = -halfTrack, z = halfBase, front = false, name = "RL" },
		{ x = halfTrack, z = halfBase, front = false, name = "RR" },
	}
	for _, corner in corners do
		local side = if corner.x < 0 then -1 else 1
		local wheelPos = Vector3.new(corner.x, radius, corner.z)
		local knuckleX = corner.x - side * (gear.width / 2 + gear.knuckle.X / 2 + 0.02)
		local knucklePos = Vector3.new(knuckleX, radius, corner.z)
		local pivotCF = ctx.origin * CFrame.new(knucklePos) * AXIS_UP

		-- Slider + spring between the chassis and the knuckle.
		local knuckle = body(ctx, "Knuckle" .. corner.name, gear.knuckle, CFrame.new(knucklePos), look(DARK_METAL, Enum.Material.Metal), HUB_DENSITY, 0.3, false)
		ctx.unsprung[knuckle] = true
		local slide = Instance.new("PrismaticConstraint")
		slide.Name = "Suspension"
		slide.Attachment0 = attach(ctx.chassis, "Slide" .. corner.name, pivotCF)
		slide.Attachment1 = attach(knuckle, "Slide" .. corner.name, pivotCF)
		slide.LimitsEnabled = true
		slide.LowerLimit = -gear.travelDown
		slide.UpperLimit = gear.travelUp
		slide.Restitution = 0
		slide.Parent = knuckle

		local spring = Instance.new("SpringConstraint")
		spring.Name = "Spring"
		spring.Attachment0 = attach(ctx.chassis, "SpringTop" .. corner.name, ctx.origin * CFrame.new(knucklePos + Vector3.new(0, gear.springHeight, 0)))
		spring.Attachment1 = attach(knuckle, "SpringBottom" .. corner.name, ctx.origin * CFrame.new(knucklePos))
		spring.Visible = true
		spring.Coils = 6
		spring.Radius = 0.22
		spring.Thickness = 0.08
		spring.Color = BrickColor.new(ACCENT)
		spring.Parent = knuckle
		table.insert(ctx.springs, { spring = spring, height = gear.springHeight })
		deco(ctx, ctx.chassis, "ShockTower", Vector3.new(0.6, 0.3, 0.6), CFrame.new(knucklePos + Vector3.new(0, gear.springHeight + 0.15, 0)), look(DARK_METAL, Enum.Material.Metal))

		-- Steering (front only): a servo hinge with a vertical axis.
		local hub: BasePart = knuckle
		if corner.front then
			local steer = body(ctx, "Steer" .. corner.name, Vector3.one * gear.steerSize, CFrame.new(knucklePos), look(METAL, Enum.Material.Metal), HUB_DENSITY, 0.3, false)
			ctx.unsprung[steer] = true
			local servo = Instance.new("HingeConstraint")
			servo.Name = "SteerServo"
			servo.Attachment0 = attach(knuckle, "Steer" .. corner.name, pivotCF)
			servo.Attachment1 = attach(steer, "Steer" .. corner.name, pivotCF)
			servo.ActuatorType = Enum.ActuatorType.Servo
			servo.AngularSpeed = STEER_SPEED
			servo.LimitsEnabled = true
			servo.LowerAngle = -(MAX_STEER_DEG + 5)
			servo.UpperAngle = MAX_STEER_DEG + 5
			servo.TargetAngle = 0
			servo.Parent = steer
			table.insert(ctx.servos, servo)
			hub = steer
		end

		-- The wheel and its drive motor.
		local wheel = body(ctx, "Wheel" .. corner.name, Vector3.new(gear.width, radius * 2, radius * 2), CFrame.new(wheelPos), gear.tire, WHEEL_DENSITY, WHEEL_FRICTION, true, Enum.PartType.Cylinder)
		wheel.CustomPhysicalProperties = PhysicalProperties.new(WHEEL_DENSITY, WHEEL_FRICTION, 0, GRIP_WEIGHT, GRIP_WEIGHT)
		ctx.unsprung[wheel] = true
		local axleCF = ctx.origin * CFrame.new(wheelPos) * AXLE
		local motor = Instance.new("HingeConstraint")
		motor.Name = "DriveMotor"
		motor.Attachment0 = attach(hub, "Axle" .. corner.name, axleCF)
		motor.Attachment1 = attach(wheel, "Axle" .. corner.name, axleCF)
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.AngularVelocity = 0
		motor.Parent = wheel
		table.insert(ctx.motors, motor)
		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = wheel
		noCollide.Part1 = ctx.chassis
		noCollide.Parent = wheel

		-- Wheel look: a hub cap and tread bars that turn with the wheel.
		local outside = Vector3.new(side * (gear.width / 2 + 0.06), 0, 0)
		deco(ctx, wheel, "HubCap", Vector3.new(0.12, radius * 1.05, radius * 1.05), CFrame.new(wheelPos + outside), gear.hub, Enum.PartType.Cylinder)
		for index = 1, gear.treads do
			local angle = (index - 1) * 2 * math.pi / gear.treads
			deco(
				ctx,
				wheel,
				"Tread",
				Vector3.new(gear.width * 0.92, 0.12, gear.treadLength),
				CFrame.new(wheelPos) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius - 0.05, 0),
				gear.tread
			)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Moon buggy (inspired by the Apollo Lunar Roving Vehicle). Forward is -Z, origin on the ground.

local function fitBuggy(ctx: Ctx, gear: Gear): Fittings
	local c = ctx.chassis
	local metal = look(METAL, Enum.Material.Metal)
	local dark = look(DARK_METAL, Enum.Material.Metal)
	local hull = look(WHITE_HULL, Enum.Material.SmoothPlastic)
	local neon = look(ACCENT, Enum.Material.Neon)

	-- Frame and floor.
	deco(ctx, c, "FloorPan", Vector3.new(4.2, 0.12, 6), CFrame.new(0, 2.56, 0.5), look(DARK_METAL, Enum.Material.DiamondPlate))
	for _, x in { -2.25, 2.25 } do
		deco(ctx, c, "FrameRail", Vector3.new(0.3, 0.3, 10.6), CFrame.new(x, 2.35, 0), metal)
		deco(ctx, c, "TrimStripe", Vector3.new(0.06, 0.12, 8), CFrame.new(x + (if x < 0 then -0.17 else 0.17), 2.35, 0), neon)
	end

	-- Fenders over the wheels: wheels throw up fine Moon dust.
	for _, x in { -gear.track / 2, gear.track / 2 } do
		for _, z in { -gear.wheelbase / 2, gear.wheelbase / 2 } do
			deco(ctx, c, "Fender", Vector3.new(1.3, 0.12, 3.6), CFrame.new(x, gear.radius * 2 + 0.75, z), hull)
		end
	end

	-- Two seats side by side and the T-shaped hand controller between them.
	local seatY = 2.85
	local seat = newSeat(ctx, "VehicleSeat", "DriverSeat", Vector3.new(1.6, 0.4, 1.6), CFrame.new(-1, seatY, 0.6)) :: VehicleSeat
	local passenger = newSeat(ctx, "Seat", "PassengerSeat", Vector3.new(1.6, 0.4, 1.6), CFrame.new(1, seatY, 0.6))
	for _, x in { -1, 1 } do
		deco(ctx, c, "SeatBack", Vector3.new(1.6, 1.6, 0.22), CFrame.new(x, seatY + 0.85, 1.45) * CFrame.Angles(math.rad(10), 0, 0), look(SEAT_WEB, Enum.Material.Fabric))
	end
	deco(ctx, c, "ControllerPost", Vector3.new(0.2, 0.9, 0.2), CFrame.new(0, 3.0, -0.3), dark)
	deco(ctx, c, "ControllerGrip", Vector3.new(0.8, 0.2, 0.2), CFrame.new(0, 3.5, -0.3), look(ACCENT, Enum.Material.SmoothPlastic))

	-- Display and control console with a cyan screen and a lime status light.
	deco(ctx, c, "ConsolePost", Vector3.new(0.25, 1.0, 0.25), CFrame.new(0, 3.0, -1.7), dark)
	local consoleCF = CFrame.new(0, 3.75, -1.7) * CFrame.Angles(math.rad(-25), 0, 0) -- face (+Z) tipped up toward the driver
	deco(ctx, c, "Console", Vector3.new(1.8, 1.0, 0.3), consoleCF, hull)
	local screen = deco(ctx, c, "ConsoleScreen", Vector3.new(1.3, 0.6, 0.05), consoleCF * CFrame.new(0, 0, 0.17), neon)
	light(screen, "Point", ACCENT, 6, 0.6)
	deco(ctx, c, "StatusLight", Vector3.one * 0.3, CFrame.new(0.75, 4.25, -1.75), look(STATUS, Enum.Material.Neon), Enum.PartType.Ball)

	-- Electronics box under a gold thermal blanket, with the dish, the radio mast and the TV camera.
	deco(ctx, c, "ElectronicsBox", Vector3.new(3.2, 0.9, 2.2), CFrame.new(0, 2.95, -3.9), hull)
	deco(ctx, c, "FoilBlanket", Vector3.new(3.0, 0.1, 2.0), CFrame.new(0, 3.45, -3.9), look(FOIL, Enum.Material.Foil))
	deco(ctx, c, "DishMast", Vector3.new(0.15, 3, 0.15), CFrame.new(-1.3, 4.9, -3.3), metal)
	deco(ctx, c, "HighGainDish", Vector3.new(0.15, 2.4, 2.4), CFrame.new(-1.3, 6.6, -3.3) * CFrame.Angles(0, math.rad(-30), math.rad(55)), look(WHITE_HULL, Enum.Material.Fabric), Enum.PartType.Cylinder)
	deco(ctx, c, "DishFeed", Vector3.one * 0.35, CFrame.new(-1.3, 6.6, -3.3) * CFrame.Angles(0, math.rad(-30), math.rad(55)) * CFrame.new(0.5, 0, 0), dark, Enum.PartType.Ball)
	deco(ctx, c, "RadioMast", Vector3.new(2.4, 0.18, 0.18), CFrame.new(1.3, 4.6, -3.6) * AXIS_UP, metal, Enum.PartType.Cylinder)
	deco(ctx, c, "RadioTip", Vector3.one * 0.3, CFrame.new(1.3, 5.85, -3.6), neon, Enum.PartType.Ball)
	deco(ctx, c, "TvCamera", Vector3.new(0.6, 0.6, 0.9), CFrame.new(0.6, 4.2, -2.9), hull)
	deco(ctx, c, "TvLens", Vector3.new(0.3, 0.4, 0.4), CFrame.new(0.6, 4.2, -3.5) * AXIS_FORWARD, dark, Enum.PartType.Cylinder)

	-- Tool pallet and a sample box at the back.
	deco(ctx, c, "ToolPallet", Vector3.new(3.6, 1.0, 1.6), CFrame.new(0, 3.0, 4.6), metal)
	deco(ctx, c, "SampleBox", Vector3.new(1.0, 0.6, 0.8), CFrame.new(0.9, 3.8, 4.6), look(PALETTE.cream, Enum.Material.SmoothPlastic))

	return { seat = seat, seats = { seat, passenger }, seatHeight = seatY, cargoPart = nil, cargoCores = {} }
end

----------------------------------------------------------------------------------------------------
-- Ice hauler: a pressurized cab at the front, an ice bed at the back. Forward is -Z.

local function fitHauler(ctx: Ctx, gear: Gear): Fittings
	local c = ctx.chassis
	local metal = look(METAL, Enum.Material.Metal)
	local dark = look(DARK_METAL, Enum.Material.Metal)
	local hull = look(WHITE_HULL, Enum.Material.SmoothPlastic)
	local glass = look(GLASS, Enum.Material.Glass, 0.55)
	local neon = look(ACCENT, Enum.Material.Neon)

	-- Pressurized cab: walls, big windows and a roof.
	deco(ctx, c, "CabFront", Vector3.new(6.2, 1.8, 0.3), CFrame.new(0, 4.2, -7.35), hull)
	deco(ctx, c, "Windshield", Vector3.new(5.8, 2.2, 0.15), CFrame.new(0, 6.2, -7.3), glass)
	for _, x in { -3.05, 3.05 } do
		deco(ctx, c, "CabSide", Vector3.new(0.3, 1.8, 5.4), CFrame.new(x, 4.2, -4.75), hull)
		deco(ctx, c, "CabWindow", Vector3.new(0.12, 2.2, 5.0), CFrame.new(x, 6.2, -4.75), glass)
		deco(ctx, c, "CabStripe", Vector3.new(0.06, 0.2, 5.4), CFrame.new(x + (if x < 0 then -0.17 else 0.17), 3.6, -4.75), neon)
	end
	deco(ctx, c, "CabRoof", Vector3.new(6.4, 0.4, 5.8), CFrame.new(0, 7.5, -4.75), hull)
	deco(ctx, c, "CabRear", Vector3.new(6.2, 4.2, 0.3), CFrame.new(0, 5.4, -2.05), hull)
	deco(ctx, c, "Bumper", Vector3.new(6.8, 0.5, 0.5), CFrame.new(0, 3.0, -7.85), dark)

	-- Inside: dashboard with a cyan screen, two seats.
	deco(ctx, c, "Dashboard", Vector3.new(5.6, 0.8, 0.9), CFrame.new(0, 4.6, -6.75), dark)
	local screen = deco(ctx, c, "DashScreen", Vector3.new(1.6, 0.7, 0.06), CFrame.new(-1.3, 5.3, -6.5) * CFrame.Angles(math.rad(-20), 0, 0), neon)
	light(screen, "Point", ACCENT, 6, 0.6)
	local seatY = 3.5
	local seat = newSeat(ctx, "VehicleSeat", "DriverSeat", Vector3.new(1.6, 0.4, 1.6), CFrame.new(-1.3, seatY, -4.5)) :: VehicleSeat
	local passenger = newSeat(ctx, "Seat", "PassengerSeat", Vector3.new(1.6, 0.4, 1.6), CFrame.new(1.3, seatY, -4.5))
	for _, x in { -1.3, 1.3 } do
		deco(ctx, c, "SeatBack", Vector3.new(1.6, 1.8, 0.3), CFrame.new(x, seatY + 1.1, -3.6), look(SEAT_WEB, Enum.Material.Fabric))
	end

	-- Lights: cream headlamps, orange tail lights, a cyan roof beacon.
	for _, x in { -2.2, 2.2 } do
		local lamp = deco(ctx, c, "Headlight", Vector3.new(0.9, 0.45, 0.12), CFrame.new(x, 3.9, -7.56), look(LAMP, Enum.Material.Neon))
		light(lamp, "Spot", LAMP, 34, 2)
	end
	local beacon = deco(ctx, c, "Beacon", Vector3.one * 0.5, CFrame.new(0, 7.95, -3.0), neon, Enum.PartType.Ball)
	light(beacon, "Point", ACCENT, 10, 1)

	-- Roof radiator (gets rid of heat: no air to cool things), radio mast and a small dish.
	deco(ctx, c, "Radiator", Vector3.new(4.0, 0.15, 2.6), CFrame.new(-0.4, 7.78, -5.6), metal)
	deco(ctx, c, "Mast", Vector3.new(0.15, 2.2, 0.15), CFrame.new(2.4, 8.8, -3.2), metal)
	deco(ctx, c, "Dish", Vector3.new(0.12, 1.4, 1.4), CFrame.new(2.4, 9.9, -3.2) * CFrame.Angles(0, 0, math.rad(50)), hull, Enum.PartType.Cylinder)

	-- Suitports on the back of the cab: astronauts climb into their suits from inside.
	for _, x in { -1.4, 1.4 } do
		deco(ctx, c, "Suitport", Vector3.new(0.12, 1.7, 1.7), CFrame.new(x, 5.1, -1.86) * AXIS_FORWARD, metal, Enum.PartType.Cylinder)
	end

	-- Fenders.
	for _, x in { -gear.track / 2, gear.track / 2 } do
		for _, z in { -gear.wheelbase / 2, gear.wheelbase / 2 } do
			deco(ctx, c, "Fender", Vector3.new(1.9, 0.15, 4.6), CFrame.new(x, gear.radius * 2 + 0.85, z), hull)
		end
	end

	-- Ice bed: floor, low walls, tailgate (the prompts live here), a rack and four ice cores.
	deco(ctx, c, "BedFloor", Vector3.new(6.0, 0.12, 8.9), CFrame.new(0, 3.36, 2.95), look(DARK_METAL, Enum.Material.DiamondPlate))
	for _, x in { -3.05, 3.05 } do
		deco(ctx, c, "BedSide", Vector3.new(0.3, 1.2, 9.1), CFrame.new(x, 3.9, 2.95), metal)
	end
	deco(ctx, c, "BedFront", Vector3.new(6.2, 1.2, 0.3), CFrame.new(0, 3.9, -1.5), metal)
	local tailgate = deco(ctx, c, "Tailgate", Vector3.new(6.2, 1.2, 0.3), CFrame.new(0, 3.9, 7.4), metal)
	deco(ctx, c, "TailStripe", Vector3.new(5.6, 0.14, 0.06), CFrame.new(0, 4.25, 7.57), look(TAIL, Enum.Material.Neon))
	for _, x in { -2.7, 2.7 } do
		deco(ctx, c, "TailLight", Vector3.new(0.6, 0.35, 0.1), CFrame.new(x, 3.6, 7.58), look(TAIL, Enum.Material.Neon))
	end
	deco(ctx, c, "CoreRack", Vector3.new(5.6, 0.3, 0.3), CFrame.new(0, 4.3, 3.05), dark)
	local cores: { BasePart } = {}
	for _, z in { 1.2, 4.9 } do
		for _, x in { -1.4, 1.4 } do
			local core = deco(ctx, c, "IceCore", Vector3.new(2.2, 1.3, 1.3), CFrame.new(x, 4.52, z) * AXIS_UP, look(ICE_GLOW, Enum.Material.Glass, 1), Enum.PartType.Cylinder)
			core.CastShadow = false
			table.insert(cores, core)
		end
	end

	return { seat = seat, seats = { seat, passenger }, seatHeight = seatY, cargoPart = tailgate, cargoCores = cores }
end

----------------------------------------------------------------------------------------------------
-- Specs

local SPECS: { [string]: Spec } = {
	buggy = {
		modelName = "MoonBuggy",
		length = 12.6,
		chassisSize = Vector3.new(4.4, 0.6, 10.4),
		chassisY = 2.2,
		ballastSize = Vector3.new(3.6, 0.5, 6.4),
		ballastY = 1.65,
		gear = {
			radius = 1.6,
			width = 1.0,
			wheelbase = 9,
			track = 6.6,
			knuckle = Vector3.new(0.5, 0.8, 0.5),
			steerSize = 0.6,
			springHeight = 1.4,
			travelUp = 0.6,
			travelDown = 0.7,
			tire = look(WIRE_MESH, Enum.Material.DiamondPlate),
			hub = look(DARK_METAL, Enum.Material.Metal),
			tread = look(METAL, Enum.Material.Metal),
			treads = 4,
			treadLength = 0.7,
		},
		fit = fitBuggy,
	},
	hauler = {
		modelName = "IceHauler",
		length = 16,
		chassisSize = Vector3.new(6.4, 0.8, 15),
		chassisY = 2.9,
		ballastSize = Vector3.new(5.4, 0.6, 11),
		ballastY = 2.2,
		gear = {
			radius = 2.0,
			width = 1.4,
			wheelbase = 12,
			track = 8.6,
			knuckle = Vector3.new(0.4, 1.0, 0.7),
			steerSize = 0.7,
			springHeight = 1.6,
			travelUp = 0.7,
			travelDown = 0.8,
			tire = look(DARK_METAL, Enum.Material.DiamondPlate),
			hub = look(WHITE_HULL, Enum.Material.Metal),
			tread = look(METAL, Enum.Material.Metal),
			treads = 2,
			treadLength = 1.0,
		},
		fit = fitHauler,
	},
}

----------------------------------------------------------------------------------------------------
-- Tuning from the real mass

local function tune(ctx: Ctx, spec: Spec, fittings: Fittings, options: Options): (number, number)
	local gravity = Workspace.Gravity
	local gear = spec.gear
	local total, unsprung, moment = 0, 0, 0
	for _, item in ctx.model:GetDescendants() do
		if item:IsA("BasePart") and not item.Massless then
			local mass = item:GetMass()
			total += mass
			moment += mass * ctx.origin:PointToObjectSpace(item.Position).Y
			if ctx.unsprung[item] then
				unsprung += mass
			end
		end
	end
	local riders = #fittings.seats * RIDER_MASS
	moment += riders * (fittings.seatHeight + 1.5)
	local loaded = total + riders
	local comHeight = math.max(0.5, moment / loaded)
	local corner = math.max(1, (loaded - unsprung) / 4)
	local cornerWeight = corner * gravity

	local stiffness = cornerWeight / SAG
	local damping = DAMPING_RATIO * 2 * math.sqrt(stiffness * corner)
	for _, entry in ctx.springs do
		entry.spring.Stiffness = stiffness
		entry.spring.Damping = damping
		entry.spring.FreeLength = entry.height + SAG
	end

	local torque = loaded / 4 * (DRIVE_ACCEL + gravity * SLOPE_GRADE) * gear.radius
	local acceleration = (options.maxSpeed / gear.radius) / RAMP_SECONDS
	for _, motor in ctx.motors do
		motor.MotorMaxTorque = torque
		motor.MotorMaxAcceleration = acceleration
	end
	for _, servo in ctx.servos do
		servo.ServoMaxTorque = cornerWeight * STEER_TORQUE_ARM
	end

	-- A turn pushes sideways by v^2 / r; the vehicle would tip at g * (half track) / (centre height).
	local turnAccel = gravity * (gear.track / 2) / comHeight * TURN_SAFETY
	return turnAccel, comHeight
end

----------------------------------------------------------------------------------------------------
-- Public API

-- True when a model exists for this vehicle id.
function VehicleModels.has(id: string): boolean
	return SPECS[id] ~= nil
end

-- Bumper-to-bumper length (studs) of a vehicle, for placing prompts at a bay entrance.
function VehicleModels.lengthOf(id: string): number
	local spec = SPECS[id]
	return if spec then spec.length else 12
end

-- Builds the vehicle with its ground centre at `origin` (facing origin.LookVector), parents it to
-- `parent` and unanchors it. The caller owns the returned rig.
function VehicleModels.build(id: string, options: Options, origin: CFrame, parent: Instance): Rig
	local spec = SPECS[id]
	assert(spec ~= nil, `no vehicle model for {id}`)

	local model = Instance.new("Model")
	model.Name = spec.modelName
	local chassis = newPart(model, "Chassis", spec.chassisSize, origin * CFrame.new(0, spec.chassisY, 0), look(METAL, Enum.Material.Metal))
	chassis.CanCollide = true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(CHASSIS_DENSITY, CHASSIS_FRICTION, 0, 1, 1)
	model.PrimaryPart = chassis

	local ctx: Ctx = {
		origin = origin,
		model = model,
		chassis = chassis,
		unsprung = {},
		springs = {},
		motors = {},
		servos = {},
	}

	-- Heavy and low: the ballast is invisible and never collides.
	local ballast = body(ctx, "Ballast", spec.ballastSize, CFrame.new(0, spec.ballastY, 0), look(DARK_METAL, Enum.Material.Metal, 1), BALLAST_DENSITY, 0.3, false)
	ballast.CastShadow = false
	weld(chassis, ballast)

	buildWheels(ctx, spec.gear)
	local fittings = spec.fit(ctx, spec.gear)
	local turnAccel, _ = tune(ctx, spec, fittings, options)

	local cargoMax = if fittings.cargoPart then math.max(0, math.floor(options.cargo or #fittings.cargoCores)) else 0
	cargoMax = math.min(cargoMax, #fittings.cargoCores)

	local rig: Rig = {
		id = id,
		model = model,
		chassis = chassis,
		seat = fittings.seat,
		seats = fittings.seats,
		motors = ctx.motors,
		servos = ctx.servos,
		cargoPart = fittings.cargoPart,
		cargoCores = fittings.cargoCores,
		cargoMax = cargoMax,
		maxSpeed = options.maxSpeed,
		wheelRadius = spec.gear.radius,
		wheelbase = spec.gear.wheelbase,
		maxSteerDeg = MAX_STEER_DEG,
		minSteerDeg = MIN_STEER_DEG,
		turnAccel = turnAccel,
		reverseFraction = REVERSE_FRACTION,
		rideHeight = spec.chassisY,
		length = spec.length,
	}

	model:SetAttribute("SBO_VehicleId", id)
	model:SetAttribute("SBO_MaxSpeed", rig.maxSpeed)
	model:SetAttribute("SBO_WheelRadius", rig.wheelRadius)
	model:SetAttribute("SBO_Wheelbase", rig.wheelbase)
	model:SetAttribute("SBO_MaxSteer", rig.maxSteerDeg)
	model:SetAttribute("SBO_MinSteer", rig.minSteerDeg)
	model:SetAttribute("SBO_TurnAccel", rig.turnAccel)
	model:SetAttribute("SBO_Reverse", rig.reverseFraction)
	model:SetAttribute("SBO_DriveSign", DRIVE_SIGN)
	model:SetAttribute("SBO_SteerSign", STEER_SIGN)
	model:SetAttribute("SBO_Cargo", 0)
	model:SetAttribute("SBO_CargoMax", cargoMax)

	model.Parent = parent
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
		end
	end
	return rig
end

-- Forward speed in studs/s (negative when reversing).
function VehicleModels.forwardSpeed(rig: Rig): number
	local chassis = rig.chassis
	return chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
end

-- Largest steering angle (degrees) that keeps the sideways push of a turn safe at this speed:
-- v^2 / r <= turnAccel with r = wheelbase / tan(angle).
function VehicleModels.steerLimit(rig: Rig, speed: number): number
	local v = math.abs(speed)
	if v <= 1 then
		return rig.maxSteerDeg
	end
	local safe = math.deg(math.atan(rig.wheelbase * rig.turnAccel / (v * v)))
	return math.clamp(safe, rig.minSteerDeg, rig.maxSteerDeg)
end

local function clean(value: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(value, -1, 1)
end

-- Sets the motors and the steering from a throttle and steer input (-1..1, like VehicleSeat).
function VehicleModels.applyDrive(rig: Rig, throttle: number, steer: number)
	local t = clean(throttle)
	local s = clean(steer)
	local scale = if t < 0 then rig.reverseFraction else 1
	local wheelSpeed = DRIVE_SIGN * t * scale * rig.maxSpeed / rig.wheelRadius
	for _, motor in rig.motors do
		if math.abs(motor.AngularVelocity - wheelSpeed) > 1e-3 then
			motor.AngularVelocity = wheelSpeed
		end
	end
	-- Rounded to half degrees so a steady turn does not resend the angle every frame.
	local angle = math.round(STEER_SIGN * s * VehicleModels.steerLimit(rig, VehicleModels.forwardSpeed(rig)) * 2) / 2
	for _, servo in rig.servos do
		if math.abs(servo.TargetAngle - angle) > 0.01 then
			servo.TargetAngle = angle
		end
	end
end

-- Shows `count` ice cores on the hauler bed (0..cargoMax).
function VehicleModels.setCargo(rig: Rig, count: number)
	local shown = math.clamp(math.floor(count), 0, rig.cargoMax)
	for index, core in rig.cargoCores do
		core.Transparency = if index <= shown then CORE_SHOWN else 1
	end
	rig.model:SetAttribute("SBO_Cargo", shown)
end

return table.freeze(VehicleModels)
