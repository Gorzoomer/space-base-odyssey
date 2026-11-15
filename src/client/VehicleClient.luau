--!strict
-- Space Base Odyssey - driving on this client (Stage 7). While the local player sits in a garage
-- vehicle (a model with the attribute SBO_VehicleId, built by the server's VehicleModels):
--   * as the driver, the wheel motors ("DriveMotor") and the steering ("SteerServo") follow the
--     VehicleSeat input every frame. The driver owns the vehicle's physics, so this is instant; the
--     server sets the same values from the same input (same formulas as VehicleModels.applyDrive,
--     read from the model attributes);
--   * the camera pulls back to a chase view (CameraMinZoomDistance), so first person never hides
--     the road, and widens a little with speed;
--   * a small panel shows the vehicle name, a speed bar, the hauler's ice and how to get out
--     (keys "ui.vehicle.*"). Everything is restored when the player gets out.
-- Main.client calls VehicleClient.start(root) once (root = the scaled UI root from Ui.createRoot;
-- without it this module finds PlayerGui.SpaceBaseOdysseyUi.Root itself).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))

local Client = script.Parent
local Store = require(Client:WaitForChild("Store"))
local Ui = require(Client:WaitForChild("Ui"))

-- Feel and layout (not gameplay numbers).
local CHASE_MIN_ZOOM = 16
local FOV_EXTRA = 8 -- degrees added at full speed
local FOV_SMOOTH = 4 -- per second
local PANEL_SIZE = UDim2.fromOffset(300, 84)
local PANEL_BOTTOM = -100 -- above the tool bar
local HINT_HEIGHT = 26
local ROOT_WAIT_SECONDS = 30

type Ride = {
	model: Model,
	seat: BasePart,
	driver: boolean,
	chassis: BasePart?,
	motors: { HingeConstraint },
	servos: { HingeConstraint },
	maxSpeed: number,
	wheelRadius: number,
	wheelbase: number,
	maxSteer: number,
	minSteer: number,
	turnAccel: number,
	reverse: number,
	driveSign: number,
	steerSign: number,
}

local VehicleClient = {}

local started = false

local function numberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" and value == value then value else fallback
end

local function vehicleModelOf(seat: Instance): Model?
	local current: Instance? = seat.Parent
	while current and current ~= workspace do
		if current:IsA("Model") and type(current:GetAttribute("SBO_VehicleId")) == "string" then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function newRide(model: Model, seat: BasePart): Ride
	local motors: { HingeConstraint } = {}
	local servos: { HingeConstraint } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("HingeConstraint") then
			if item.Name == "DriveMotor" then
				table.insert(motors, item)
			elseif item.Name == "SteerServo" then
				table.insert(servos, item)
			end
		end
	end
	return {
		model = model,
		seat = seat,
		driver = seat:IsA("VehicleSeat"),
		chassis = model.PrimaryPart,
		motors = motors,
		servos = servos,
		maxSpeed = math.max(1, numberAttribute(model, "SBO_MaxSpeed", 30)),
		wheelRadius = math.max(0.1, numberAttribute(model, "SBO_WheelRadius", 1.6)),
		wheelbase = numberAttribute(model, "SBO_Wheelbase", 9),
		maxSteer = numberAttribute(model, "SBO_MaxSteer", 30),
		minSteer = numberAttribute(model, "SBO_MinSteer", 6),
		turnAccel = numberAttribute(model, "SBO_TurnAccel", 20),
		reverse = numberAttribute(model, "SBO_Reverse", 0.45),
		driveSign = numberAttribute(model, "SBO_DriveSign", 1),
		steerSign = numberAttribute(model, "SBO_SteerSign", -1),
	}
end

local function forwardSpeed(ride: Ride): number
	local chassis = ride.chassis
	if chassis == nil then
		return 0
	end
	return chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
end

-- Same as VehicleModels.steerLimit on the server.
local function steerLimit(ride: Ride, speed: number): number
	local v = math.abs(speed)
	if v <= 1 then
		return ride.maxSteer
	end
	local safe = math.deg(math.atan(ride.wheelbase * ride.turnAccel / (v * v)))
	return math.clamp(safe, ride.minSteer, ride.maxSteer)
end

local function clean(value: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(value, -1, 1)
end

-- Same as VehicleModels.applyDrive on the server.
local function drive(ride: Ride)
	if not ride.seat:IsA("VehicleSeat") then
		return
	end
	local seat = ride.seat :: VehicleSeat
	local throttle = clean(seat.ThrottleFloat)
	local steer = clean(seat.SteerFloat)
	local scale = if throttle < 0 then ride.reverse else 1
	local wheelSpeed = ride.driveSign * throttle * scale * ride.maxSpeed / ride.wheelRadius
	for _, motor in ride.motors do
		motor.AngularVelocity = wheelSpeed
	end
	local angle = math.round(ride.steerSign * steer * steerLimit(ride, forwardSpeed(ride)) * 2) / 2
	for _, servo in ride.servos do
		servo.TargetAngle = angle
	end
end

local function findRoot(): Instance?
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("SpaceBaseOdysseyUi", ROOT_WAIT_SECONDS)
	local root = if gui then gui:WaitForChild("Root", ROOT_WAIT_SECONDS) else nil
	return root
end

-- root: the scaled UI root frame (optional).
function VehicleClient.start(root: Instance?)
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local parent = root or findRoot()
	if parent == nil then
		warn("[SpaceBaseOdyssey] VehicleClient: no UI root; the vehicle panel is off")
	end

	-- Panel: icon, name, speed bar, ice line; and an outlined hint under it.
	local panel: Frame? = nil
	local icon: ImageLabel? = nil
	local title: TextLabel? = nil
	local speedBar: Ui.Bar? = nil
	local cargoLine: TextLabel? = nil
	local hint: TextLabel? = nil
	if parent then
		local frame = Ui.panel(parent, {
			name = "VehiclePanel",
			size = PANEL_SIZE,
			position = UDim2.new(0.5, 0, 1, PANEL_BOTTOM),
			anchor = Vector2.new(0.5, 1),
			visible = false,
			zindex = 4,
		})
		panel = frame
		icon = Ui.icon(frame, Icons.car, {
			name = "Icon",
			size = UDim2.fromScale(0.18, 0.7),
			position = UDim2.fromScale(0.04, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = Ui.ROLE.accent,
			aspect = 1,
			zindex = 5,
		})
		title = Ui.label(frame, {
			name = "Title",
			size = UDim2.fromScale(0.72, 0.32),
			position = UDim2.fromScale(0.25, 0.06),
			alignX = Enum.TextXAlignment.Left,
			maxText = 24,
			zindex = 5,
		})
		speedBar = Ui.bar(frame, {
			name = "Speed",
			size = UDim2.fromScale(0.71, 0.28),
			position = UDim2.fromScale(0.25, 0.42),
			maxText = 16,
			zindex = 5,
		})
		cargoLine = Ui.body(frame, {
			name = "Cargo",
			size = UDim2.fromScale(0.71, 0.22),
			position = UDim2.fromScale(0.25, 0.74),
			textColor = Ui.ROLE.textDim,
			maxText = 16,
			zindex = 5,
		})
		hint = Ui.label(parent, {
			name = "VehicleHint",
			size = UDim2.new(0, PANEL_SIZE.X.Offset + 60, 0, HINT_HEIGHT),
			position = UDim2.new(0.5, 0, 1, PANEL_BOTTOM - PANEL_SIZE.Y.Offset - 6),
			anchor = Vector2.new(0.5, 1),
			font = Ui.BODY_FONT,
			outline = true,
			maxText = 20,
			visible = false,
			zindex = 4,
		})
	end

	local ride: Ride? = nil
	local savedMinZoom: number? = nil
	local savedFov: number? = nil
	local shownCargo = -1

	local function exitKey(): string
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			return "ui.vehicle.exit_touch"
		elseif string.sub(last.Name, 1, 7) == "Gamepad" then
			return "ui.vehicle.exit_pad"
		end
		return "ui.vehicle.exit_key"
	end

	local function renderText()
		local current = ride
		if current == nil then
			return
		end
		local id = current.model:GetAttribute("SBO_VehicleId")
		local name = if type(id) == "string" then id else "buggy"
		if title then
			title.Text = Store.t(`ui.vehicle.{name}`)
		end
		if icon then
			icon.Image = if name == "hauler" then Icons.truck else Icons.car
		end
		if hint then
			hint.Text = if current.driver then Store.t(exitKey()) else Store.t("ui.vehicle.passenger")
		end
		local max = numberAttribute(current.model, "SBO_CargoMax", 0)
		local cargo = numberAttribute(current.model, "SBO_Cargo", 0)
		shownCargo = cargo
		if cargoLine then
			cargoLine.Visible = max > 0
			cargoLine.Text = if max > 0 then Store.t("ui.vehicle.cargo", { n = cargo, max = max }) else ""
		end
	end

	local function renderSpeed()
		local current = ride
		if current == nil or speedBar == nil then
			return
		end
		local fraction = math.clamp(math.abs(forwardSpeed(current)) / current.maxSpeed, 0, 1)
		speedBar.set(fraction, Ui.ROLE.accent, Store.t("ui.vehicle.speed"))
	end

	local function restoreCamera()
		if savedMinZoom ~= nil then
			player.CameraMinZoomDistance = savedMinZoom
			savedMinZoom = nil
		end
		local camera = workspace.CurrentCamera
		if savedFov ~= nil and camera then
			camera.FieldOfView = savedFov
		end
		savedFov = nil
	end

	local function leave()
		ride = nil
		restoreCamera()
		if panel then
			panel.Visible = false
		end
		if hint then
			hint.Visible = false
		end
	end

	local function enter(seat: BasePart)
		local model = vehicleModelOf(seat)
		if model == nil then
			leave()
			return
		end
		ride = newRide(model, seat)
		if savedMinZoom == nil then
			savedMinZoom = player.CameraMinZoomDistance
			player.CameraMinZoomDistance = math.min(math.max(player.CameraMinZoomDistance, CHASE_MIN_ZOOM), player.CameraMaxZoomDistance)
		end
		local camera = workspace.CurrentCamera
		if savedFov == nil and camera then
			savedFov = camera.FieldOfView
		end
		renderText()
		renderSpeed()
		if panel then
			panel.Visible = true
		end
		if hint then
			hint.Visible = true
		end
	end

	local function onSeat(seatPart: BasePart?)
		if seatPart then
			enter(seatPart)
		else
			leave()
		end
	end

	local function onCharacter(character: Model)
		leave()
		local instance = character:WaitForChild("Humanoid", 10)
		if not instance or not instance:IsA("Humanoid") then
			return
		end
		local humanoid = instance :: Humanoid
		humanoid.Seated:Connect(function(active: boolean, seatPart: BasePart?)
			onSeat(if active then seatPart else nil)
		end)
		humanoid.Died:Connect(leave)
		if humanoid.SeatPart then
			onSeat(humanoid.SeatPart)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	UserInputService.LastInputTypeChanged:Connect(function()
		renderText()
	end)
	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "language" then
			renderText()
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local current = ride
		if current == nil then
			return
		end
		if current.model.Parent == nil or current.seat.Parent == nil then
			leave() -- the vehicle went back to the garage
			return
		end
		if current.driver then
			drive(current)
		end
		renderSpeed()
		if numberAttribute(current.model, "SBO_Cargo", 0) ~= shownCargo then
			renderText()
		end
		local camera = workspace.CurrentCamera
		local base = savedFov
		if camera and base then
			local fraction = math.clamp(math.abs(forwardSpeed(current)) / current.maxSpeed, 0, 1)
			local target = base + FOV_EXTRA * fraction
			local alpha = math.clamp(deltaTime * FOV_SMOOTH, 0, 1)
			camera.FieldOfView += (target - camera.FieldOfView) * alpha
		end
	end)
end

return table.freeze(VehicleClient)
