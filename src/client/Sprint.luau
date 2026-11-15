--!strict
-- Space Base Odyssey - Run toggle: LeftShift on PC or an on-screen button on touch sets the local WalkSpeed.
-- The "speed" skill (Stage 6) adds the player attribute SBO_SpeedBonus (set by the server's BaseService)
-- to both the walking and the running speed. Stage 7: eating greenhouse food sets the player attribute
-- SBO_FoodBoostUntil (server time, set by the server's ToolService); until then FOOD.BOOST_SPEED is
-- added as well.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local Sprint = {}

export type SprintView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
	isRunning: () -> boolean,
}

function Sprint.new(root: Frame): SprintView
	local player = Players.LocalPlayer
	local running = false
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
	local function render()
		Ui.setButton(button, Store.t("ui.run"), Ui.ICONS.run)
		Ui.setButtonLook(button, true, if running then Ui.COLORS.go else Ui.COLORS.secondary)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if running then Ui.ROLE.text else Ui.ROLE.stroke
		end
	end

	local function toggle()
		running = not running
		applySpeed()
		render()
	end

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
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			applySpeed()
			-- The server also sets the spawn speed: apply ours again once it has.
			task.delay(1, applySpeed)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	local function setVisible(visible: boolean)
		shown = visible
		-- The on-screen button is for touch screens; keyboards use LeftShift.
		button.Visible = shown and UserInputService.TouchEnabled
	end

	UserInputService.LastInputTypeChanged:Connect(function()
		button.Visible = shown and UserInputService.TouchEnabled
	end)

	render()
	return {
		setVisible = setVisible,
		render = render,
		isRunning = function(): boolean
			return running
		end,
	}
end

return Sprint
