--!strict
-- Space Base Odyssey - cinematic camera (Stage 10): plays a list of shots from
-- src/shared/CinematicShots.luau on workspace.CurrentCamera (Scriptable), with a black fade between
-- shots, looping. Used as the start menu's background (StartMenu.luau) and for recording the 30-second
-- video and promo material (DemoKeys: Ctrl+Shift+C plays, Ctrl+Shift+G grades; or the player attribute
-- SBO_Cinematic set by a Studio command, see DemoKeys).
-- While it plays:
--   * world clutter never seen in a cinematic is hidden: C.A.R.L.'s beams (CarlDrone.setCinematic),
--     task / lock / shelter markers (Markers.setSuppressed) and proximity prompts on this client;
--   * a cinematic grade is applied with client-side post effects in Lighting (names start with
--     "SBO_Cinematic"): more contrast, a little saturation and warmth, bloom, sun rays, and depth of
--     field only for shots that ask for it (CinematicShots blur; skipped on touch and low-quality
--     devices). The server's own bloom (SBO_Bloom) is switched off on this client meanwhile so the
--     two never stack. Lighting values themselves are never changed.
-- stop() puts everything back: CameraType Custom, FieldOfView 70, markers, beams, prompts, effects.
-- Cinematic.setGrade(true) keeps the grade on even without a shot playing (recording gameplay).
-- Lighting for the shots comes from the server sky (WorldSky); the menu's eclipse shot relies on the
-- eclipse preview BaseService triggers for menu players (showcase).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CinematicShots = require(Shared:WaitForChild("CinematicShots"))
local Theme = require(Shared:WaitForChild("Theme"))

local CarlDrone = require(script.Parent.CarlDrone)
local Markers = require(script.Parent.Markers)

type Shot = CinematicShots.Shot
type Key = CinematicShots.Key
type Vec = CinematicShots.Vec

export type PlayOptions = {
	-- A full-screen Frame to fade (its BackgroundTransparency). Default: Cinematic's own ScreenGui.
	fade: Frame?,
	loop: boolean?, -- default true
	blur: boolean?, -- allow depth of field (default: not on touch-only or low-quality devices)
	-- Hide every other ScreenGui in PlayerGui while playing (recording). Default false.
	cleanScreen: boolean?,
	-- Called when a shot starts (its id).
	onShot: ((id: string) -> ())?,
	-- Who started it ("menu" = the start menu, "debug" = DemoKeys recording); see owner().
	owner: string?,
}

-- Technical and visual tuning (not gameplay numbers).
local FADE_SECONDS = 0.6 -- black fade out at the end of a shot and in at the start of the next
local DEFAULT_FOV = 70
local RENDER_STEP = "SBO_Cinematic"
local WORLD_WAIT_SECONDS = 30 -- wait this long for the base before the first shot
local SHOWCASE_WAIT_SECONDS = 20 -- and this long for BaseService's showcase attribute (world built)
local EARTH_WAIT_SECONDS = 10 -- the Earth shot waits this long for the sky bodies, else it is skipped
local GROUND_CLEARANCE = 3 -- studs: the Earth shot's camera stays this far above what is below it
local LOW_QUALITY_LEVEL = 3 -- graphics quality at or below this skips depth of field
local EFFECT_PREFIX = "SBO_Cinematic"
local SERVER_BLOOM = "SBO_Bloom" -- WorldSky's bloom: off on this client while the grade is on
local FADE_ORDER = 100 -- the own fade ScreenGui draws above everything (recording)
local GRADE = {
	-- Checked in Studio while recording the trailer: lower bloom thresholds or stronger sun rays burn
	-- the sky to yellow when the Sun is in the frame.
	contrast = 0.14,
	saturation = 0.2,
	tint = Theme.PALETTE.cream:Lerp(Color3.new(1, 1, 1), 0.55), -- slight warm white
	bloomIntensity = 0.55,
	bloomSize = 28,
	bloomThreshold = 1.35,
	sunRays = 0.04,
	sunRaysSpread = 0.35,
}

local Cinematic = {}

local player = Players.LocalPlayer

local playToken = 0
local playing = false
local currentOwner: string? = nil
local cleanScreen = false
local gradeForced = false
local gradeApplied = false
local current: { shot: Shot, keys: { Key }, started: number }? = nil
local fadeFrame: Frame? = nil -- the frame faded now
local callerFade: Frame? = nil -- PlayOptions.fade (nil = the own fade)
local ownGui: ScreenGui? = nil
local blurAllowed = true
local promptsWereEnabled: boolean? = nil
local hiddenGuis: { ScreenGui } = {}
local serverBloomWasEnabled: boolean? = nil

local effects: {
	color: ColorCorrectionEffect?,
	bloom: BloomEffect?,
	rays: SunRaysEffect?,
	depth: DepthOfFieldEffect?,
} = {}

local function toVector(v: Vec): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

-- Touch-only devices and a low saved graphics quality skip depth of field.
local function lowEndDevice(): boolean
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	local ok, low = pcall(function(): boolean
		local settings = UserSettings():GetService("UserGameSettings")
		local level = settings.SavedQualityLevel
		if level == Enum.SavedQualitySetting.Automatic then
			return false
		end
		return level.Value <= LOW_QUALITY_LEVEL
	end)
	return ok and low == true
end

----------------------------------------------------------------------------------------------------
-- Grade (client-side post effects)

local function newEffect(className: string, name: string): any
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local effect = Instance.new(className :: any)
	effect.Name = name
	effect.Parent = Lighting
	return effect :: any
end

local function setServerBloom(on: boolean)
	local bloom = Lighting:FindFirstChild(SERVER_BLOOM)
	if bloom == nil or not bloom:IsA("BloomEffect") then
		return
	end
	if not on then
		if serverBloomWasEnabled == nil then
			serverBloomWasEnabled = bloom.Enabled
		end
		bloom.Enabled = false
	elseif serverBloomWasEnabled ~= nil then
		bloom.Enabled = serverBloomWasEnabled
		serverBloomWasEnabled = nil
	end
end

local function applyGrade(on: boolean)
	if on == gradeApplied then
		return
	end
	gradeApplied = on
	if on then
		local color = newEffect("ColorCorrectionEffect", EFFECT_PREFIX .. "Grade") :: ColorCorrectionEffect
		color.Contrast = GRADE.contrast
		color.Saturation = GRADE.saturation
		color.TintColor = GRADE.tint
		effects.color = color
		local bloom = newEffect("BloomEffect", EFFECT_PREFIX .. "Bloom") :: BloomEffect
		bloom.Intensity = GRADE.bloomIntensity
		bloom.Size = GRADE.bloomSize
		bloom.Threshold = GRADE.bloomThreshold
		effects.bloom = bloom
		local rays = newEffect("SunRaysEffect", EFFECT_PREFIX .. "SunRays") :: SunRaysEffect
		rays.Intensity = GRADE.sunRays
		rays.Spread = GRADE.sunRaysSpread
		effects.rays = rays
		setServerBloom(false)
	else
		local color, bloom, rays, depth = effects.color, effects.bloom, effects.rays, effects.depth
		if color then
			color:Destroy()
		end
		if bloom then
			bloom:Destroy()
		end
		if rays then
			rays:Destroy()
		end
		if depth then
			depth:Destroy()
		end
		effects = {}
		setServerBloom(true)
	end
end

local function refreshGrade()
	applyGrade(playing or gradeForced)
end

-- Depth of field for one shot (nil = none).
local function setBlur(blur: CinematicShots.Blur?)
	if blur == nil or not blurAllowed then
		local depth = effects.depth
		if depth then
			depth:Destroy()
			effects.depth = nil
		end
		return
	end
	local depth = effects.depth or newEffect("DepthOfFieldEffect", EFFECT_PREFIX .. "Depth") :: DepthOfFieldEffect
	depth.FocusDistance = blur.focus
	depth.InFocusRadius = blur.radius
	depth.FarIntensity = blur.far
	depth.NearIntensity = blur.near
	effects.depth = depth
end

----------------------------------------------------------------------------------------------------
-- Clutter that never belongs in a cinematic

-- Every other ScreenGui in PlayerGui off (true) or back (false), for recording.
local function setCleanScreenNow(on: boolean)
	if on then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			for _, gui in playerGui:GetChildren() do
				if gui:IsA("ScreenGui") and gui ~= ownGui and gui.Enabled then
					gui.Enabled = false
					table.insert(hiddenGuis, gui)
				end
			end
		end
	else
		for _, gui in hiddenGuis do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		hiddenGuis = {}
	end
end

local function hideClutter(on: boolean)
	pcall(Markers.setSuppressed, on)
	pcall(CarlDrone.setCinematic, on)
	if on then
		if promptsWereEnabled == nil then
			local ok, enabled = pcall(function(): boolean
				return ProximityPromptService.Enabled
			end)
			if ok then
				promptsWereEnabled = enabled
				pcall(function()
					ProximityPromptService.Enabled = false
				end)
			end
		end
	else
		local was = promptsWereEnabled
		if was ~= nil then
			promptsWereEnabled = nil
			pcall(function()
				ProximityPromptService.Enabled = was
			end)
		end
		setCleanScreenNow(false)
	end
end

----------------------------------------------------------------------------------------------------
-- Fade

local function ownFade(): Frame
	local gui = ownGui
	if gui == nil or gui.Parent == nil then
		local newGui = Instance.new("ScreenGui")
		newGui.Name = "SBO_CinematicFade"
		newGui.IgnoreGuiInset = true
		newGui.ResetOnSpawn = false
		newGui.DisplayOrder = FADE_ORDER
		local frame = Instance.new("Frame")
		frame.Name = "Fade"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Theme.ROLE.background -- night, the darkest Theme colour
		frame.BackgroundTransparency = 1
		frame.Parent = newGui
		newGui.Parent = player:WaitForChild("PlayerGui")
		ownGui = newGui
		gui = newGui
	end
	return (gui :: ScreenGui):FindFirstChild("Fade") :: Frame
end

-- 0 = clear, 1 = black.
local function setFade(black: number)
	local frame = fadeFrame
	if frame then
		frame.BackgroundTransparency = 1 - math.clamp(black, 0, 1)
	end
end

----------------------------------------------------------------------------------------------------
-- Shots

local function earthKeys(): { Key }?
	local sky = workspace:FindFirstChild("SkyBodies")
	local earth = if sky then sky:FindFirstChild("Earth") else nil
	if earth == nil or not earth:IsA("BasePart") then
		return nil
	end
	local p = earth.Position
	local keys = CinematicShots.earthKeys({ p.X, p.Y, p.Z })
	-- Never under the ground or inside a rock: a ray straight down from high above each key.
	for _, item in keys do
		local origin = Vector3.new(item.pos[1], item.pos[2] + 200, item.pos[3])
		local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0))
		if hit and hit.Position.Y + GROUND_CLEARANCE > item.pos[2] then
			item.pos[2] = hit.Position.Y + GROUND_CLEARANCE
		end
	end
	return keys
end

local function onRender()
	local shot = current
	local camera = workspace.CurrentCamera
	if shot == nil or camera == nil then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local duration = shot.shot.seconds
	local t = os.clock() - shot.started
	local pos, look, fov = CinematicShots.sample(shot.shot, math.clamp(t / duration, 0, 1), shot.keys)
	camera.CFrame = CFrame.lookAt(toVector(pos), toVector(look))
	camera.FieldOfView = fov
	local fade = 0
	if t < FADE_SECONDS then
		fade = 1 - t / FADE_SECONDS
	elseif t > duration - FADE_SECONDS then
		fade = (t - (duration - FADE_SECONDS)) / FADE_SECONDS
	end
	setFade(fade)
end

-- Waits for the base, BaseService's showcase decision and (for the first shot) the sky.
local function waitForWorld(token: number)
	local started = os.clock()
	while token == playToken and workspace:FindFirstChild("Base") == nil and os.clock() - started < WORLD_WAIT_SECONDS do
		task.wait(0.25)
	end
	started = os.clock()
	while token == playToken and workspace:GetAttribute("SBO_Showcase") == nil and os.clock() - started < SHOWCASE_WAIT_SECONDS do
		task.wait(0.25)
	end
end

local function run(token: number, ids: { string }, options: PlayOptions)
	setFade(1)
	waitForWorld(token)
	local loop = options.loop ~= false
	local index = 0
	local skippedInRow = 0
	local firstEarth = true
	while token == playToken do
		index += 1
		if index > #ids then
			if not loop then
				break
			end
			index = 1
		end
		local shot = CinematicShots.get(ids[index])
		local keys: { Key }? = if shot then shot.keys else nil
		if shot and shot.lookAtEarth then
			keys = earthKeys()
			if keys == nil and firstEarth then
				workspace:WaitForChild("SkyBodies", EARTH_WAIT_SECONDS)
				local sky = workspace:FindFirstChild("SkyBodies")
				if sky then
					sky:WaitForChild("Earth", EARTH_WAIT_SECONDS)
				end
				keys = earthKeys()
			end
			firstEarth = false
		end
		if token ~= playToken then
			break
		end
		if shot == nil or keys == nil or #keys == 0 then
			skippedInRow += 1
			if skippedInRow >= #ids then
				task.wait(1) -- nothing playable yet: try again later
				skippedInRow = 0
			end
			continue
		end
		skippedInRow = 0
		setBlur(shot.blur)
		current = { shot = shot, keys = keys, started = os.clock() }
		local onShot = options.onShot
		if onShot then
			task.spawn(onShot, shot.id)
		end
		task.wait(shot.seconds)
	end
	if token == playToken then
		-- A shot list that does not loop ended by itself.
		Cinematic.stop()
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- Plays the shots (ids from CinematicShots) on the camera until stop(). Calling it again restarts.
function Cinematic.play(ids: { string }, options: PlayOptions?)
	local opts: PlayOptions = options or {}
	if playing then
		Cinematic.stop()
	end
	playToken += 1
	playing = true
	currentOwner = opts.owner
	blurAllowed = if opts.blur ~= nil then opts.blur else not lowEndDevice()
	callerFade = opts.fade
	fadeFrame = opts.fade or ownFade()
	hideClutter(true)
	Cinematic.setCleanScreen(opts.cleanScreen == true)
	refreshGrade()
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, onRender)
	task.spawn(run, playToken, table.clone(ids), opts)
end

-- The start menu sequence (CinematicShots.MENU_ORDER).
function Cinematic.playMenu(options: PlayOptions?)
	Cinematic.play(CinematicShots.MENU_ORDER, options)
end

-- Stops the shots and puts the camera, the markers, the beams, the prompts and the effects back.
function Cinematic.stop()
	if not playing then
		return
	end
	playToken += 1
	playing = false
	currentOwner = nil
	cleanScreen = false
	current = nil
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_STEP)
	end)
	setFade(0)
	local own = ownGui
	if own then
		local ownFrame = own:FindFirstChild("Fade")
		if ownFrame and ownFrame:IsA("Frame") then
			ownFrame.BackgroundTransparency = 1
		end
	end
	fadeFrame = nil
	callerFade = nil
	setBlur(nil)
	hideClutter(false)
	refreshGrade()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function Cinematic.isPlaying(): boolean
	return playing
end

-- Who started the shots playing now (PlayOptions.owner), or nil.
function Cinematic.owner(): string?
	return if playing then currentOwner else nil
end

-- While shots play: every other ScreenGui hidden (true, recording) or shown (false). stop() always
-- shows them again.
function Cinematic.setCleanScreen(on: boolean)
	local wanted = on == true and playing
	if wanted == cleanScreen then
		return
	end
	cleanScreen = wanted
	-- The caller's fade lives in a ScreenGui that is hidden now: fade the own one (on top) instead.
	local before = fadeFrame
	local transparency = if before then before.BackgroundTransparency else 0
	fadeFrame = if wanted then ownFade() else (callerFade or ownFade())
	if before and before ~= fadeFrame then
		before.BackgroundTransparency = 1
	end
	if fadeFrame then
		fadeFrame.BackgroundTransparency = transparency
	end
	setCleanScreenNow(wanted)
end

function Cinematic.isCleanScreen(): boolean
	return cleanScreen
end

-- Keeps the cinematic grade on (true) even when no shot plays, for recording gameplay; false
-- leaves it only while shots play.
function Cinematic.setGrade(on: boolean)
	gradeForced = on == true
	refreshGrade()
end

function Cinematic.isGradeOn(): boolean
	return gradeApplied
end

return Cinematic
