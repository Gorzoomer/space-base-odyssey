--!strict
-- Space Base Odyssey - Run toggle: LeftShift on PC or an on-screen button on touch sets the local WalkSpeed.
-- The "speed" skill (Stage 6) adds the player attribute SBO_SpeedBonus (set by the server's BaseService)
-- to both the walking and the running speed. Stage 7: eating greenhouse food sets the player attribute
-- SBO_FoodBoostUntil (server time, set by the server's ToolService); until then FOOD.BOOST_SPEED is
-- added as well.
-- Stage 8 auto-run (team feedback): X (or a small touch button) keeps the astronaut walking forward
-- without holding W. Every frame, right after the camera has moved, the Humanoid is moved along the
-- camera's forward direction flattened on the ground: in first person that is where you look, in
-- third person the camera's forward, so turning the camera steers. Shift still switches run / walk
-- without stopping. It stops on X again, on any W/A/S/D or arrow key, on any thumbstick or gamepad
-- move, while a panel is open, in a vehicle seat, on death and off the field screens. The HUD shows an
-- "Auto-run (X)" pill while it is on (Hud.luau reads isAutoRunning).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ACTION_NAME = "SpaceBaseOdysseyRun"
local SPEED_BONUS_ATTRIBUTE = "SBO_SpeedBonus"
local FOOD_BOOST_ATTRIBUTE = "SBO_FoodBoostUntil"
-- Above the default player scripts, so LeftShift toggles running instead of shift lock.
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 10
local AUTO_RUN_KEY = Enum.KeyCode.X
local AUTO_RUN_STEP_NAME = "SpaceBaseOdysseyAutoRun"
-- After the default control script (Input) and the camera (Camera) for this frame.
local AUTO_RUN_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local TOUCH_ROW_NAME = "TouchActionRow" -- shared with Gear.luau (the gear buttons)
-- Keys that cancel auto-run (the player steers by hand again).
local CANCEL_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
}
local STICK_DEADZONE = 0.2 -- thumbstick / gamepad move that counts as steering by hand

local Sprint = {}

export type Deps = {
	panelOpen: (() -> boolean)?, -- a full-screen panel is open (auto-run stops)
}

export type SprintView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
	isRunning: () -> boolean,
	isAutoRunning: () -> boolean,
}

-- The default PlayerModule's controls (for the thumbstick / gamepad move vector), or nil.
local function controlModule(player: Player): any
	local ok, controls = pcall(function(): any
		local scripts = player:WaitForChild("PlayerScripts", 5)
		local module = if scripts then scripts:WaitForChild("PlayerModule", 5) else nil
		if module == nil or not module:IsA("ModuleScript") then
			return nil
		end
		local playerModule: any = require(module :: any)
		return playerModule:GetControls()
	end)
	return if ok then controls else nil
end

local function touchRow(root: Frame): Frame
	-- Stage 10: the start menu keeps the game UI in root.GameLayer while it is open.
	local holder = root:FindFirstChild("GameLayer")
	local existing = root:FindFirstChild(TOUCH_ROW_NAME) or (if holder then holder:FindFirstChild(TOUCH_ROW_NAME) else nil)
	if existing and existing:IsA("Frame") then
		return existing
	end
	-- Right side, under the Run button (y 0.43-0.57) and above the touch jump button.
	local row = Ui.frame(root, {
		name = TOUCH_ROW_NAME,
		size = UDim2.fromScale(0.4, 0.11),
		position = UDim2.fromScale(0.97, 0.59),
		anchor = Vector2.new(1, 0),
		zindex = 6,
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.015, 0)
	layout.Parent = row
	return row
end

function Sprint.new(root: Frame, deps: Deps?): SprintView
	local player = Players.LocalPlayer
	local running = false
	local autoRunning = false
	local shown = false

	local function speedBonus(): number
		local value = player:GetAttribute(SPEED_BONUS_ATTRIBUTE)
		return if type(value) == "number" and value == value then math.max(0, value) else 0
	end

	-- Server time when the food boost ends (0 = no boost).
	local function boostUntil(): number
		local value = player:GetAttribute(FOOD_BOOST_ATTRIBUTE)
		return if type(value) == "number" and value == value then value else 0
	end

	local function foodBonus(): number
		return if boostUntil() > workspace:GetServerTimeNow() then MissionData.BASE.FOOD.BOOST_SPEED else 0
	end

	local function applySpeed()
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			local speed = if running then MissionData.WORLD.RUN_SPEED else MissionData.WORLD.WALK_SPEED
			humanoid.WalkSpeed = speed + speedBonus() + foodBonus()
		end
	end
	player:GetAttributeChangedSignal(SPEED_BONUS_ATTRIBUTE):Connect(applySpeed)
	-- A new boost: speed up now and slow down again right after it ends.
	local boostToken = 0
	player:GetAttributeChangedSignal(FOOD_BOOST_ATTRIBUTE):Connect(function()
		boostToken += 1
		local token = boostToken
		applySpeed()
		local left = boostUntil() - workspace:GetServerTimeNow()
		if left > 0 then
			task.delay(left + 0.05, function()
				if token == boostToken then
					applySpeed()
				end
			end)
		end
	end)

	local button: TextButton
	local autoButton: TextButton
	local row = touchRow(root)

	local function render()
		Ui.setButton(button, Store.t("ui.run"), Ui.ICONS.run)
		Ui.setButtonLook(button, true, if running then Ui.COLORS.go else Ui.COLORS.secondary)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if running then Ui.ROLE.text else Ui.ROLE.stroke
		end
		Ui.setButtonLook(autoButton, true, if autoRunning then Ui.COLORS.go else Ui.COLORS.secondary)
		local autoStroke = autoButton:FindFirstChildOfClass("UIStroke")
		if autoStroke then
			autoStroke.Color = if autoRunning then Ui.ROLE.text else Ui.ROLE.stroke
		end
	end

	local function toggle()
		running = not running
		applySpeed()
		render()
	end

	-- Auto-run ---------------------------------------------------------------------------------------
	local controls: any = nil
	task.spawn(function()
		controls = controlModule(player)
	end)

	local function handMove(): Vector3
		local current = controls
		if current == nil or type(current.GetMoveVector) ~= "function" then
			return Vector3.zero
		end
		local ok, vector = pcall(function(): any
			return current:GetMoveVector()
		end)
		return if ok and typeof(vector) == "Vector3" then vector else Vector3.zero
	end

	local function setAutoRun(on: boolean)
		if autoRunning == on then
			return
		end
		autoRunning = on
		if not on then
			-- Stop now; the control script takes over again on the next frame.
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid and handMove().Magnitude < STICK_DEADZONE then
				humanoid:Move(Vector3.zero, false)
			end
		end
		render()
	end

	local function canAutoRun(): boolean
		if not shown then
			return false
		end
		if deps and deps.panelOpen and deps.panelOpen() then
			return false
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		return humanoid ~= nil and humanoid.Health > 0 and humanoid.SeatPart == nil
	end

	local function toggleAutoRun()
		if autoRunning then
			setAutoRun(false)
		elseif canAutoRun() then
			setAutoRun(true)
		end
	end

	-- After the control script (which moves by the keys) and the camera: walk along the camera's
	-- forward direction flattened on the ground.
	RunService:BindToRenderStep(AUTO_RUN_STEP_NAME, AUTO_RUN_PRIORITY, function()
		if not autoRunning then
			return
		end
		if not canAutoRun() then
			setAutoRun(false)
			return
		end
		-- A thumbstick, gamepad or key move means the player steers by hand (keys are caught below too).
		if handMove().Magnitude >= STICK_DEADZONE then
			setAutoRun(false)
			return
		end
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if camera == nil or humanoid == nil then
			return
		end
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then
			-- Looking straight down or up: use the camera's up vector (its top points forward then).
			local up = camera.CFrame.UpVector
			flat = Vector3.new(up.X, 0, up.Z) * (if look.Y < 0 then 1 else -1)
		end
		if flat.Magnitude < 0.05 then
			return
		end
		humanoid:Move(flat.Unit, false)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if UserInputService:GetFocusedTextBox() ~= nil then
			return -- typing in the chat
		end
		if input.KeyCode == AUTO_RUN_KEY then
			if not gameProcessed then
				toggleAutoRun()
			end
		elseif autoRunning and CANCEL_KEYS[input.KeyCode] then
			setAutoRun(false)
		end
	end)

	-- Placed on the right, above the touch jump button.
	button = Ui.button(root, {
		name = "RunButton",
		size = UDim2.fromScale(0.2, 0.14),
		position = UDim2.fromScale(0.97, 0.5),
		anchor = Vector2.new(1, 0.5),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.run,
		maxText = 40,
		zindex = 6,
		visible = false,
	}, toggle)

	-- Touch: a small square auto-run button in the row under the Run button (gear buttons beside it).
	autoButton = Ui.button(row, {
		name = "AutoRunButton",
		size = UDim2.fromScale(0.25, 1),
		order = 1,
		color = Ui.COLORS.secondary,
		icon = Ui.Icons.autorun,
		aspect = 1,
		zindex = 7,
		visible = false,
	}, toggleAutoRun)

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				toggle()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.LeftShift
	)

	local function onCharacter(character: Model)
		setAutoRun(false)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			applySpeed()
			-- The server also sets the spawn speed: apply ours again once it has.
			task.delay(1, applySpeed)
			humanoid.Died:Connect(function()
				setAutoRun(false)
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	local function refreshTouch()
		-- The on-screen buttons are for touch screens; keyboards use LeftShift and X.
		local touch = UserInputService.TouchEnabled
		button.Visible = shown and touch
		autoButton.Visible = touch
		row.Visible = shown
	end

	local function setVisible(visible: boolean)
		shown = visible
		refreshTouch()
		if not shown then
			setAutoRun(false)
		end
	end

	UserInputService.LastInputTypeChanged:Connect(refreshTouch)

	render()
	refreshTouch()
	return {
		setVisible = setVisible,
		render = render,
		isRunning = function(): boolean
			return running
		end,
		isAutoRunning = function(): boolean
			return autoRunning
		end,
	}
end

return Sprint
