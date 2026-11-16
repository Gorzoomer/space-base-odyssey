--!strict
-- Space Base Odyssey - camera feel on this client (Stage 11 juice).
--   * A gentle, short camera shake when a meteorite lands nearby: on the Moon there is no air to
--     carry a blast, so it is the ground that shakes, and only close by (Feel.meteorTrauma).
--   * A soft orange pulse at the screen edges when a solar storm's flare warning comes and when
--     its particles arrive. The camera never shakes for a storm: radiation is silent and pushes
--     nothing (science rule). A flare with no particle storm only gets the warning pulse.
-- With "reduce motion" (Store.reduceMotion, the player attribute SBO_ReduceMotion, or the
-- setting of that name, whichever exists) there is no shake; the edge pulse stays (it does not move).
-- The shake never fights other camera code: it only runs with CameraType Custom (the cinematic
-- camera is Scriptable), never touches FieldOfView (VehicleClient owns it), and removes its own
-- offset again before the camera scripts run each frame, so nothing drifts.
-- API: CameraFx.start(), CameraFx.shake(trauma), CameraFx.pulse(strength), CameraFx.motionReduced().
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local Theme = require(Shared:WaitForChild("Theme"))

local Store = require(script.Parent.Store)

local UNDO_STEP = "SBO_CameraFxUndo"
local SHAKE_STEP = "SBO_CameraFxShake"
local REDUCE_ATTRIBUTE = "SBO_ReduceMotion"
local IMPACT_DELAY = 0.3 -- matches the impact sound (Audio.luau)
local STORM_POLL_SECONDS = 0.25
local PULSE_SECONDS = 1.4
local EDGE_DEPTH = 0.16 -- screen fraction each edge glow reaches inward

local CameraFx = {}

local trauma = 0
local clock = 0
local applied: CFrame? = nil
local started = false
local edgeFrames: { Frame } = {}

-- True when the player asked for less motion (any of the ways that may exist; never errors).
function CameraFx.motionReduced(): boolean
	local ok, result = pcall(function(): boolean
		local store: any = Store
		local value = store.reduceMotion
		if type(value) == "function" then
			return value() == true
		elseif type(value) == "boolean" then
			return value
		end
		if type(store.getSetting) == "function" then
			local setting = store.getSetting("reduceMotion")
			if type(setting) == "boolean" then
				return setting
			end
		end
		local player = Players.LocalPlayer
		return player ~= nil and player:GetAttribute(REDUCE_ATTRIBUTE) == true
	end)
	return ok and result == true
end

-- Adds trauma (0..1); the shake fades by itself. Ignored with reduce motion.
function CameraFx.shake(amount: number)
	if amount ~= amount or amount <= 0 or CameraFx.motionReduced() then
		return
	end
	trauma = math.clamp(math.max(trauma, amount), 0, 1)
end

local function ensureEdges()
	if #edgeFrames > 0 and edgeFrames[1].Parent ~= nil then
		return
	end
	table.clear(edgeFrames)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SBO_CameraFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None -- a full-screen layer (the notch strips too)
	gui.DisplayOrder = 4 -- under the game UI, so the HUD stays readable
	gui.Parent = playerGui
	-- One glow per edge: a warning-coloured strip that fades toward the middle of the screen.
	local edges = {
		{ size = UDim2.fromScale(1, EDGE_DEPTH), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, EDGE_DEPTH), position = UDim2.fromScale(0, 1 - EDGE_DEPTH), rotation = -90 },
		{ size = UDim2.fromScale(EDGE_DEPTH * 0.6, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(EDGE_DEPTH * 0.6, 1), position = UDim2.fromScale(1 - EDGE_DEPTH * 0.6, 0), rotation = 180 },
	}
	for index, spec in edges do
		local frame = Instance.new("Frame")
		frame.Name = "Edge" .. index
		frame.Size = spec.size
		frame.Position = spec.position
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Theme.ROLE.warning
		frame.BackgroundTransparency = 1
		frame.Active = false
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(edgeFrames, frame)
	end
end

-- A soft warning-colour pulse at the screen edges (strength 0..1). Never moves the camera.
function CameraFx.pulse(strength: number)
	pcall(function()
		ensureEdges()
		local start = 1 - math.clamp(strength, 0, 1) * 0.55
		for _, frame in edgeFrames do
			frame.BackgroundTransparency = start
			TweenService:Create(frame, TweenInfo.new(PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end

-- Before the camera scripts: take back last frame's offset, so the camera's own look never drifts.
local function undo()
	local offset = applied
	if offset == nil then
		return
	end
	applied = nil
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = camera.CFrame * offset:Inverse()
	end
end

-- After the camera scripts: add this frame's shake.
local function apply(dt: number)
	if trauma <= 0 then
		return
	end
	trauma = Feel.decay(trauma, dt)
	local camera = workspace.CurrentCamera
	if camera == nil or camera.CameraType ~= Enum.CameraType.Custom or CameraFx.motionReduced() then
		trauma = 0
		return
	end
	clock += dt
	local amount = Feel.shakeAmount(trauma)
	local shake = Feel.SHAKE
	local t = clock * shake.FREQUENCY
	local offset = CFrame.new(
		shake.MAX_OFFSET * amount * math.noise(t, 1.7),
		shake.MAX_OFFSET * amount * math.noise(t, 5.3),
		0
	) * CFrame.Angles(
		math.rad(shake.MAX_ANGLE_DEG) * amount * math.noise(t, 9.1),
		math.rad(shake.MAX_ANGLE_DEG) * amount * math.noise(t, 13.9),
		math.rad(shake.MAX_ANGLE_DEG) * 0.5 * amount * math.noise(t, 17.3)
	)
	camera.CFrame = camera.CFrame * offset
	applied = offset
end

-- Meteorites land as new children of Workspace.Base.Impacts (same signal as Audio.luau).
local impactsWatched: Instance? = nil
local function watchImpacts()
	local base = workspace:FindFirstChild("Base")
	local impacts = if base then base:FindFirstChild("Impacts") else nil
	if impacts == nil or impacts == impactsWatched then
		return
	end
	impactsWatched = impacts
	impacts.ChildAdded:Connect(function(child: Instance)
		if not Store.isSlotChosen() then
			return
		end
		local position: Vector3? = nil
		if child:IsA("Model") then
			position = child:GetPivot().Position
		elseif child:IsA("BasePart") then
			position = child.Position
		end
		if position == nil then
			return
		end
		local at = position :: Vector3
		task.delay(IMPACT_DELAY, function()
			local character = Players.LocalPlayer.Character
			local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if rootPart and rootPart:IsA("BasePart") then
				CameraFx.shake(Feel.meteorTrauma((rootPart.Position - at).Magnitude))
			end
		end)
	end)
end

function CameraFx.start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep(UNDO_STEP, Enum.RenderPriority.Camera.Value - 1, undo)
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 2, apply)
	local shownStorm = "none"
	local sinceStorm = 0
	local sinceScan = 2
	RunService.Heartbeat:Connect(function(dt: number)
		sinceStorm += dt
		if sinceStorm >= STORM_POLL_SECONDS then
			sinceStorm = 0
			local stage: string = Store.stormStage()
			if stage ~= shownStorm then
				if stage == "warning" then
					CameraFx.pulse(0.55) -- the flare is seen: particles may follow
				elseif stage == "storm" then
					CameraFx.pulse(1) -- particles are here: get to the shelter
				end
				shownStorm = stage
			end
		end
		sinceScan += dt
		if sinceScan >= 2 then
			sinceScan = 0
			pcall(watchImpacts)
		end
	end)
end

return CameraFx
