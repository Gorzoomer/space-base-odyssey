--!strict
-- Space Base Odyssey - gear worn on the suit (Stage 8), applied on this client (movement is owned by
-- the client in Roblox, so the double jump and the jetpack thrust are set here).
--   * Keys: B switches the air boots on or off, J the jetpack (MissionData.BASE.GEAR[i].key). Only
--     owned gear (BaseState.gear) can be switched: the client sends {type = "ToggleGear", id} and the
--     server validates it and sets the player attributes SBO_GearBoots / SBO_GearJetpack (the gear
--     level while it is switched on, else 0). Touch screens get small icon buttons near the jump
--     button. Keys are ignored while a TextBox (chat) is focused.
--   * Air boots: in the air, a NEW press of Jump (once per air time) gives a second jump: upward speed
--     = a normal jump * BASE.DOUBLE_JUMP_FRACTION. It costs BaseBuild.gasUse(boots) gas. Gas puffs from
--     both soles. The character gets the attribute SBO_DoubleJumpAt (server time), so C.A.R.L. hops.
--   * Jetpack: in the air, after a new press of Jump (if the boots are on, their double jump comes
--     first), HOLDING Jump fires cold-gas jets: upward speed grows by GAS.JETPACK_ACCEL per second,
--     never past GAS.JETPACK_MAX_RISE. It uses BaseBuild.gasUse(jetpack) gas per second of thrust and
--     stops when the tank is empty. Real science: on the Moon there is no air to push on, so only gas
--     thrust can lift you (NASA's MMU and SAFER jetpacks fly with cold nitrogen gas jets). No fire.
--   * Gas tank: one tank for both, simulated here. It starts full (GAS.MAX, also after a respawn) and
--     refills at GAS.REFILL_PER_SECOND while the server says the player is inside a pressurized
--     module (player attribute SBO_Inside).
-- Gear.gas() -> (current, max) and Gear.level / Gear.isOn feed the HUD gas bar and the gear row.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local Theme = require(Shared:WaitForChild("Theme"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio) -- Stage 11 audio

local GAS = MissionData.BASE.GAS
local INSIDE_ATTRIBUTE = "SBO_Inside"
local DOUBLE_JUMP_AT_ATTRIBUTE = "SBO_DoubleJumpAt"
-- Player attribute (set by the server) per gear id: the gear level while switched on, else 0.
local ON_ATTRIBUTES: { [string]: string } = {
	boots = "SBO_GearBoots",
	jetpack = "SBO_GearJetpack",
}
local RENDER_STEP_NAME = "SpaceBaseOdysseyGear"
-- After the default control script (Input) has set Humanoid.Jump for this frame.
local RENDER_PRIORITY = Enum.RenderPriority.Input.Value + 2
local TOUCH_ROW_NAME = "TouchActionRow" -- shared with Sprint.luau (the auto-run button)

-- Feel tuning (not gameplay numbers).
local MIN_AIR_SECONDS = 0.15 -- the first jump must leave the ground before a press in the air counts
local JET_AFTER_DOUBLE = 0.15 -- after a boots double jump, holding Jump starts the jetpack this much later
local JET_PUFF_EVERY = 0.06 -- seconds between jetpack puffs
local NEED_LAB_COOLDOWN = 6 -- seconds between "get this gear at the Lab" tips
local MAX_EMPTY_TIPS = 2 -- "gas empty" tips per session
local PUFF_SECONDS = 0.4
local PUFF_START_SIZE = 0.35
local PUFF_END_SIZE = 1.6

export type Deps = {
	showTip: ((ref: Store.TextRef) -> ())?,
}

local Gear = {}

local player = Players.LocalPlayer
local gas: number = GAS.MAX
local started = false

local function attributeNumber(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
end

-- Owned level of a piece of gear (0 = not owned). BaseState.gear; with a Store that does not carry it
-- yet, gear that is switched on (server attribute) still counts as owned.
function Gear.level(id: string): number
	local state: any = Store.getBase()
	local owned = if type(state) == "table" and type(state.gear) == "table" then state.gear[id] else nil
	local fromState = if type(owned) == "number" then math.max(0, math.floor(owned)) else 0
	local attribute = ON_ATTRIBUTES[id]
	local fromAttribute = if attribute then attributeNumber(attribute) else 0
	return math.max(fromState, fromAttribute)
end

-- Switched on and working: the server attribute is the truth (it says the level while on).
function Gear.activeLevel(id: string): number
	local attribute = ON_ATTRIBUTES[id]
	return if attribute then attributeNumber(attribute) else 0
end

function Gear.isOn(id: string): boolean
	return Gear.activeLevel(id) > 0
end

function Gear.ownsAny(): boolean
	for _, def in MissionData.BASE.GEAR do
		if Gear.level(def.id) > 0 then
			return true
		end
	end
	return false
end

function Gear.gas(): (number, number)
	return gas, GAS.MAX
end

local function inside(): boolean
	return player:GetAttribute(INSIDE_ATTRIBUTE) == true
end

-- Upward speed of a normal jump. JumpPower is a speed; with JumpHeight mode use v = sqrt(2 g h).
local function jumpSpeed(humanoid: Humanoid): number
	if humanoid.UseJumpPower then
		return humanoid.JumpPower
	end
	return math.sqrt(2 * workspace.Gravity * math.max(0, humanoid.JumpHeight))
end

-- Gas puffs (local parts only, cleaned up quickly): cream with a cyan tint, never fire.
local function puffAt(cframe: CFrame, push: Vector3, color: Color3)
	local ball = Instance.new("Part")
	ball.Name = "SBO_GasPuff"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.SmoothPlastic
	ball.Color = color
	ball.Transparency = 0.3
	ball.Size = Vector3.one * PUFF_START_SIZE
	ball.CFrame = cframe
	ball.Parent = workspace
	local tween = TweenService:Create(ball, TweenInfo.new(PUFF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * PUFF_END_SIZE,
		Transparency = 1,
		CFrame = cframe + push,
	})
	tween.Completed:Connect(function()
		ball:Destroy()
	end)
	tween:Play()
end

-- Bottom of a foot or leg part (R15 LeftFoot / RightFoot, R6 Left Leg / Right Leg).
local function soles(character: Model, root: BasePart): { CFrame }
	local result: { CFrame } = {}
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(result, part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0))
		end
		if #result >= 2 then
			break
		end
	end
	if #result == 0 then
		local feet = root.CFrame * CFrame.new(0, -3, 0)
		table.insert(result, feet * CFrame.new(-0.5, 0, 0))
		table.insert(result, feet * CFrame.new(0.5, 0, 0))
	end
	return result
end

local function bootPuff(character: Model, root: BasePart)
	for index, sole in soles(character, root) do
		local color = if index % 2 == 0 then Theme.PALETTE.cyan else Theme.PALETTE.cream
		puffAt(sole, Vector3.new(0, -2.2, 0), Theme.PALETTE.cream)
		puffAt(sole * CFrame.new(0, -0.3, 0), Vector3.new(0, -1.4, 0) + sole.LookVector * 0.4, color)
	end
end

-- Two nozzles low on the back (behind the root part), blowing down and back.
local function jetPuff(root: BasePart)
	local back = root.CFrame * CFrame.new(0, -0.9, 0.95)
	for _, side in { -0.45, 0.45 } do
		local nozzle = back * CFrame.new(side, 0, 0)
		local push = Vector3.new(0, -2.6, 0) - root.CFrame.LookVector * 0.6
		puffAt(nozzle, push, if side < 0 then Theme.PALETTE.cream else Theme.PALETTE.cyan)
	end
end

-- Keys and touch buttons ---------------------------------------------------------------------------

local KEY_TO_GEAR: { [Enum.KeyCode]: string } = {}
for _, def in MissionData.BASE.GEAR do
	local ok, keyCode = pcall(function(): Enum.KeyCode
		return (Enum.KeyCode :: any)[def.key]
	end)
	if ok and typeof(keyCode) == "EnumItem" then
		KEY_TO_GEAR[keyCode :: Enum.KeyCode] = def.id
	end
end

local function touchRow(root: Frame): Frame
	-- Stage 10: the start menu keeps the game UI in root.GameLayer while it is open.
	local holder = root:FindFirstChild("GameLayer")
	local existing = root:FindFirstChild(TOUCH_ROW_NAME) or (if holder then holder:FindFirstChild(TOUCH_ROW_NAME) else nil)
	if existing and existing:IsA("Frame") then
		return existing
	end
	-- Right side, under the Run button (Sprint.luau, y 0.43-0.57) and above the touch jump button.
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

function Gear.start(root: Frame, deps: Deps?)
	if started then
		return
	end
	started = true

	local lastNeedLab = -math.huge
	local function toggle(id: string)
		if Gear.level(id) < 1 then
			local now = os.clock()
			if deps and deps.showTip and now - lastNeedLab > NEED_LAB_COOLDOWN then
				lastNeedLab = now
				deps.showTip({ key = "tip.gear_need_lab" })
			end
			return
		end
		Store.send({ type = "ToggleGear", id = id })
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local id = KEY_TO_GEAR[input.KeyCode]
		if id then
			toggle(id)
		end
	end)

	-- Touch: one small icon button per owned gear, lit while it is on.
	local row = touchRow(root)
	type TouchButton = { button: TextButton, id: string }
	local buttons: { TouchButton } = {}
	for index, def in MissionData.BASE.GEAR do
		local id: string = def.id
		local button = Ui.button(row, {
			name = "Gear_" .. id,
			size = UDim2.fromScale(0.25, 1),
			order = 10 + index,
			color = Ui.COLORS.secondary,
			strokeColor = Theme.ROLE.stroke,
			icon = Ui.iconImage(def.icon),
			tint = Theme.ROLE.textDim,
			aspect = 1,
			zindex = 7,
			visible = false,
		}, function()
			toggle(id)
		end)
		table.insert(buttons, { button = button, id = id })
	end

	local function renderButtons()
		local touch = UserInputService.TouchEnabled
		for _, entry in buttons do
			local owned = Gear.level(entry.id) > 0
			entry.button.Visible = touch and owned -- the row itself is hidden by Sprint.luau off the field
			local on = Gear.isOn(entry.id)
			Ui.setButtonLook(entry.button, true, if on then Theme.ROLE.good else Ui.COLORS.secondary)
			local stroke = entry.button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if on then Theme.ROLE.text else Theme.ROLE.stroke
			end
		end
	end
	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "base" then
			renderButtons()
		end
	end)
	for _, attribute in ON_ATTRIBUTES do
		player:GetAttributeChangedSignal(attribute):Connect(renderButtons)
	end
	UserInputService.LastInputTypeChanged:Connect(renderButtons)
	renderButtons()

	-- Movement ---------------------------------------------------------------------------------------
	local humanoid: Humanoid? = nil
	local airborne = false
	local airborneAt = 0
	local released = false -- Jump was let go since leaving the ground
	local doubleUsed = false
	local jetArmed = false
	local jetReadyAt = 0
	local wasHeld = false
	local lastJetPuff = 0
	local emptyTips = 0
	local emptyWarned = false -- this tank already said "empty" (cleared once it refills)

	local AIR_STATES: { [Enum.HumanoidStateType]: boolean } = {
		[Enum.HumanoidStateType.Jumping] = true,
		[Enum.HumanoidStateType.Freefall] = true,
	}

	local function resetAir()
		airborne = false
		released = false
		doubleUsed = false
		jetArmed = false
	end

	local function onCharacter(character: Model)
		resetAir()
		gas = GAS.MAX -- a fresh suit after a respawn
		local instance = character:WaitForChild("Humanoid", 10)
		if not instance or not instance:IsA("Humanoid") then
			return
		end
		local found = instance :: Humanoid
		humanoid = found
		found.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if humanoid ~= found then
				return
			end
			if AIR_STATES[new] then
				if not airborne then
					airborne = true
					airborneAt = os.clock()
					released = false
					doubleUsed = false
					jetArmed = false
				end
			else
				resetAir()
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- Jump held this frame: the default control script sets Humanoid.Jump every frame from the
	-- keyboard, gamepad and the touch jump button; the keys are a backup.
	local function jumpHeld(current: Humanoid): boolean
		if current.Jump then
			return true
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return false
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			return true
		end
		local ok, down = pcall(function(): boolean
			return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
		end)
		return ok and down == true
	end

	-- "Gas tank empty! Go inside to refill." at most MAX_EMPTY_TIPS times per session.
	local function warnEmpty()
		if emptyWarned or emptyTips >= MAX_EMPTY_TIPS then
			return
		end
		emptyWarned = true
		emptyTips += 1
		if deps and deps.showTip then
			deps.showTip({ key = "tip.gas_empty" })
		end
	end

	local function spend(amount: number)
		gas = math.max(0, gas - amount)
		if gas <= 0 then
			warnEmpty()
		end
	end

	RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_PRIORITY, function(deltaTime: number)
		local dt = math.min(deltaTime, 0.1)
		if inside() and gas < GAS.MAX then
			gas = math.min(GAS.MAX, gas + GAS.REFILL_PER_SECOND * dt)
			if gas >= GAS.MAX then
				emptyWarned = false
			end
		end
		local current = humanoid
		if current == nil or current.Parent == nil or current.Health <= 0 or current.SeatPart ~= nil then
			wasHeld = false
			return
		end
		local held = jumpHeld(current)
		local press = held and not wasHeld
		wasHeld = held
		if not airborne then
			return
		end
		if not AIR_STATES[current:GetState()] then
			return
		end
		if not held then
			released = true
		end
		local character = current.Parent :: Instance
		local rootInstance = character:FindFirstChild("HumanoidRootPart")
		if not rootInstance or not rootInstance:IsA("BasePart") then
			return
		end
		local rootPart = rootInstance :: BasePart
		local now = os.clock()
		local bootsLevel = Gear.activeLevel("boots")
		local jetLevel = Gear.activeLevel("jetpack")

		-- A new press of Jump in the air.
		if press and released and now - airborneAt >= MIN_AIR_SECONDS then
			local bootsUse = BaseBuild.gasUse(MissionData, "boots", bootsLevel)
			if bootsLevel > 0 and not doubleUsed and bootsUse ~= nil and gas >= bootsUse then
				doubleUsed = true
				spend(bootsUse)
				local velocity = rootPart.AssemblyLinearVelocity
				local speed = jumpSpeed(current) * MissionData.BASE.DOUBLE_JUMP_FRACTION
				rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, speed), velocity.Z)
				if character:IsA("Model") then
					bootPuff(character, rootPart)
				end
				Audio.play("boots_puff") -- Stage 11 audio
				character:SetAttribute(DOUBLE_JUMP_AT_ATTRIBUTE, workspace:GetServerTimeNow())
				jetReadyAt = now + JET_AFTER_DOUBLE
			else
				if bootsLevel > 0 and not doubleUsed and bootsUse ~= nil and gas < bootsUse and jetLevel < 1 then
					warnEmpty() -- not enough gas for the boots (and no jetpack to try instead)
				end
				jetReadyAt = now
			end
			jetArmed = true
		end

		-- Jump held all the way from the ground: the jets start at the top of the jump, so "hold Jump to
		-- fly" also works without letting go first.
		if jetLevel > 0 and not jetArmed and not released and held and now - airborneAt >= MIN_AIR_SECONDS
			and rootPart.AssemblyLinearVelocity.Y <= 0
		then
			jetArmed = true
			jetReadyAt = now
		end

		-- Jetpack: hold Jump to thrust (the jets throttle off at the top climbing speed).
		if jetLevel > 0 and jetArmed and held and now >= jetReadyAt then
			local usePerSecond = BaseBuild.gasUse(MissionData, "jetpack", jetLevel)
			local velocity = rootPart.AssemblyLinearVelocity
			if usePerSecond ~= nil and gas > 0 and velocity.Y < GAS.JETPACK_MAX_RISE then
				spend(usePerSecond * dt)
				local rise = math.min(velocity.Y + GAS.JETPACK_ACCEL * dt, GAS.JETPACK_MAX_RISE)
				rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, rise, velocity.Z)
				Audio.hold("jetpack_loop") -- Stage 11 audio: on while the jets fire
				if now - lastJetPuff >= JET_PUFF_EVERY then
					lastJetPuff = now
					jetPuff(rootPart)
				end
			end
		end
	end)
end

return Gear
