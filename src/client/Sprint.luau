--!strict
-- Space Base Odyssey - Run toggle: LeftShift on PC or an on-screen button on touch sets the local WalkSpeed.
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

	local function applySpeed()
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.WalkSpeed = if running then MissionData.WORLD.RUN_SPEED else MissionData.WORLD.WALK_SPEED
		end
	end

	local button: TextButton
	local function render()
		local glyph = if running then Ui.ICONS.run else Ui.ICONS.walk
		button.Text = `{glyph} {Store.t("ui.run")}`
		Ui.setButtonLook(button, true, if running then Ui.COLORS.go else Ui.COLORS.panelLight)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if running then Color3.fromRGB(255, 255, 255) else Ui.COLORS.outline
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
		color = Ui.COLORS.panelLight,
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
