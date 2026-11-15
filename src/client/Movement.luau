--!strict
-- Space Base Odyssey - movement skills (Stage 6), applied on this client:
--   * Double jump: with player attribute SBO_JumpLevel >= 1 (the "jump" skill, set by the server's
--     BaseService), pressing jump once more while falling gives a second, smaller jump: a puff of gas
--     from the life-support backpack. Upward speed = Humanoid.JumpPower * BASE.DOUBLE_JUMP_FRACTION.
--     Once per air time. Real science: on the Moon there is no air to push on, so only gas thrust
--     could do this.
--   * Faster drilling (Stage 7): the player attribute SBO_DrillLevel is the level of the ice drill
--     TOOL (set by the server's ToolService; upgraded at the Lab). The ice drill prompts need a
--     shorter hold: original HoldDuration * BaseBuild.drillHoldFactor(data, level). The original
--     value is kept in the prompt attribute SBO_BaseHold so the factor never compounds. Prompt hold
--     times cannot be set per player on the server, so this local change is the only place it happens.
-- The character gets the attribute SBO_DoubleJumpAt (server time) on every double jump, so other
-- client scripts (C.A.R.L.) can react.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local Theme = require(Shared:WaitForChild("Theme"))

local JUMP_LEVEL_ATTRIBUTE = "SBO_JumpLevel"
local DRILL_LEVEL_ATTRIBUTE = "SBO_DrillLevel"
local BASE_HOLD_ATTRIBUTE = "SBO_BaseHold"
local DOUBLE_JUMP_AT_ATTRIBUTE = "SBO_DoubleJumpAt"
-- Prompts whose TextKey is one of these are ice drill prompts (WorldBuilder: makePrompt "prompt.drill").
local DRILL_KEYS: { [string]: boolean } = { ["prompt.drill"] = true }

-- Feel tuning (not gameplay numbers).
local MIN_AIR_SECONDS = 0.15 -- the first jump must leave the ground before the second one counts
local NEW_PRESS_GAP = 0.12 -- a held jump key repeats JumpRequest; a real new press comes after a gap
local PUFF_PARTS = 3
local PUFF_SECONDS = 0.45
local PUFF_START_SIZE = 0.5
local PUFF_END_SIZE = 2

local Movement = {}

local started = false

local function attributeLevel(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
end

-- Upward speed of the second jump. JumpPower is a speed; with JumpHeight mode use v = sqrt(2 g h).
local function doubleJumpSpeed(humanoid: Humanoid): number
	local fraction: number = MissionData.BASE.DOUBLE_JUMP_FRACTION
	if humanoid.UseJumpPower then
		return humanoid.JumpPower * fraction
	end
	return math.sqrt(2 * workspace.Gravity * math.max(0, humanoid.JumpHeight)) * fraction
end

-- A small cream gas puff below the backpack (local parts only, cleaned up quickly).
local function puff(root: BasePart)
	local origin = root.CFrame * CFrame.new(0, -0.6, 0.9) -- behind and below: the backpack nozzles
	for index = 1, PUFF_PARTS do
		local ball = Instance.new("Part")
		ball.Name = "SBO_JumpPuff"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.Material = Enum.Material.SmoothPlastic
		ball.Color = Theme.PALETTE.cream
		ball.Transparency = 0.35
		ball.Size = Vector3.one * PUFF_START_SIZE
		local spread = (index - (PUFF_PARTS + 1) / 2) * 0.5
		ball.CFrame = origin * CFrame.new(spread, 0, 0)
		ball.Parent = workspace
		local tween = TweenService:Create(ball, TweenInfo.new(PUFF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * PUFF_END_SIZE,
			Transparency = 1,
			CFrame = origin * CFrame.new(spread * 2, -1.6, 0.4),
		})
		tween.Completed:Connect(function()
			ball:Destroy()
		end)
		tween:Play()
	end
end

-- Double jump -----------------------------------------------------------------------------------

local function startDoubleJump(player: Player)
	local humanoid: Humanoid? = nil
	local airborneAt: number? = nil
	local used = false
	local lastRequest = 0

	local GROUND_STATES: { [Enum.HumanoidStateType]: boolean } = {
		[Enum.HumanoidStateType.Landed] = true,
		[Enum.HumanoidStateType.Running] = true,
		[Enum.HumanoidStateType.RunningNoPhysics] = true,
		[Enum.HumanoidStateType.Climbing] = true,
		[Enum.HumanoidStateType.Swimming] = true,
		[Enum.HumanoidStateType.Seated] = true,
		[Enum.HumanoidStateType.Dead] = true,
	}

	local function onCharacter(character: Model)
		local instance = character:WaitForChild("Humanoid", 10)
		if not instance or not instance:IsA("Humanoid") then
			return
		end
		local found = instance :: Humanoid
		humanoid = found
		airborneAt = nil
		used = false
		found.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if humanoid ~= found then
				return
			end
			if GROUND_STATES[new] then
				airborneAt = nil
				used = false
			elseif new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
				airborneAt = airborneAt or os.clock()
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local gap = now - lastRequest
		lastRequest = now
		local current = humanoid
		if current == nil or used or airborneAt == nil then
			return
		end
		if attributeLevel(player, JUMP_LEVEL_ATTRIBUTE) < 1 or current.Health <= 0 then
			return
		end
		if gap < NEW_PRESS_GAP or now - (airborneAt :: number) < MIN_AIR_SECONDS then
			return
		end
		local state = current:GetState()
		if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
			return
		end
		local character = current.Parent
		local rootInstance = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not rootInstance or not rootInstance:IsA("BasePart") then
			return
		end
		local root = rootInstance :: BasePart
		used = true
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, doubleJumpSpeed(current), velocity.Z)
		puff(root)
		if character then
			character:SetAttribute(DOUBLE_JUMP_AT_ATTRIBUTE, workspace:GetServerTimeNow())
		end
	end)
end

-- Faster ice drilling (drill tool level) -------------------------------------------------------

local function startDrillTool(player: Player)
	local drillPrompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function factor(): number
		-- Level 0 (no drill yet) and 1 (basic drill) both use the normal hold time.
		local level = math.max(1, attributeLevel(player, DRILL_LEVEL_ATTRIBUTE))
		return BaseBuild.drillHoldFactor(MissionData, level)
	end

	local function apply(prompt: ProximityPrompt, value: number)
		local original = prompt:GetAttribute(BASE_HOLD_ATTRIBUTE)
		if type(original) ~= "number" then
			original = prompt.HoldDuration
			prompt:SetAttribute(BASE_HOLD_ATTRIBUTE, original)
		end
		prompt.HoldDuration = (original :: number) * value
	end

	local function consider(instance: Instance)
		if not instance:IsA("ProximityPrompt") or drillPrompts[instance :: any] then
			return
		end
		local key = instance:GetAttribute("TextKey")
		if type(key) == "string" and DRILL_KEYS[key] then
			local prompt = instance :: ProximityPrompt
			drillPrompts[prompt] = true
			apply(prompt, factor())
		end
	end

	local function applyAll()
		local value = factor()
		for prompt in drillPrompts do
			if prompt.Parent then
				apply(prompt, value)
			end
		end
	end

	workspace.DescendantAdded:Connect(consider)
	for _, descendant in workspace:GetDescendants() do
		consider(descendant)
	end
	player:GetAttributeChangedSignal(DRILL_LEVEL_ATTRIBUTE):Connect(applyAll)
end

function Movement.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	startDoubleJump(player)
	startDrillTool(player)
end

return table.freeze(Movement)
