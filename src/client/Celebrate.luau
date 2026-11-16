--!strict
-- Space Base Odyssey - celebrations on this client (Stage 11 juice). Big moments get a short burst of
-- confetti in the Lunar Sunrise palette, a soft screen flash, a big title for levels and (for a base
-- level up) a sting and star sparkles at the habitat:
--   quest        a quest finished (main or side)          confetti by the quest cards
--   achievement  a learning achievement unlocked          confetti by the cards
--   level        the player levelled up                   "Level 4" title + confetti
--   base         the habitat (base level) went up         "Base level 2" title + confetti, sparkles at
--                                                         the habitat, the level-up sting
--   mission      a mission was completed (Report.luau)    confetti rain after the stars
--   build        a building finished rising               star sparkles at its pad (no screen flash)
-- Celebrate.play(kind, opts?) shows one; Celebrate.onBaseState(raw) finds them in a BaseState from the
-- server (Feel.detect: base / level / quest / build) and Main.client calls it. Moments that come
-- together play one after another. Every moment lasts under 2 s and never blocks a tap. The rules and
-- styles are pure, in src/shared/Feel.luau (tests/feel.luau).
-- Sounds: QuestToasts, Hud and Audio already play the quest, achievement, level-up and victory
-- sounds, so only the base level up adds a sting here (Feel.STYLES.sting) and stars add their notes
-- in Report.luau. With "reduce motion" there is no confetti or sparkles, only a very soft flash and
-- a title that fades in place.
-- Images: none (the sparks use Roblox's default soft particle, tinted with Theme colours). No emoji.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local Theme = require(Shared:WaitForChild("Theme"))

local Store = require(script.Parent.Store)
local Audio = require(script.Parent.Audio)
local CameraFx = require(script.Parent.CameraFx)

local SLOT_ATTRIBUTE = "SBO_Slot"
local SLOT_LOADING_ATTRIBUTE = "SBO_SlotLoading"
local TITLE_HOLD_SECONDS = 1.1
local WORLD_SPARKLES = 26

export type PlayOptions = {
	n: number?, -- the new level (level / base titles)
	at: Vector3?, -- where the world sparkles burst (defaults: the habitat, the build's pad)
	id: string?, -- the build id (build)
}

type Piece = {
	frame: Frame,
	x: number,
	y: number,
	vx: number,
	vy: number,
	spin: number,
	age: number,
	life: number,
}

local Celebrate = {}

local gui: ScreenGui? = nil
local layer: Frame? = nil
local flash: Frame? = nil
local pieces: { Piece } = {}
local stepConnection: RBXScriptConnection? = nil
local random = Random.new()
local queue: { Feel.Moment } = {}
local playing = false
local started = false

local function color(name: string): Color3
	local value = (Theme.PALETTE :: any)[name]
	return if typeof(value) == "Color3" then value else Theme.ROLE.star
end

local function ensureGui(): boolean
	if gui ~= nil and (gui :: ScreenGui).Parent ~= nil then
		return true
	end
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return false
	end
	local newGui = Instance.new("ScreenGui")
	newGui.Name = "SBO_Celebrate"
	newGui.ResetOnSpawn = false
	newGui.IgnoreGuiInset = true
	newGui.ScreenInsets = Enum.ScreenInsets.None -- a full-screen layer
	newGui.DisplayOrder = 6 -- over the game UI (5), under nothing the player must tap
	newGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local newLayer = Instance.new("Frame")
	newLayer.Name = "Layer"
	newLayer.BackgroundTransparency = 1
	newLayer.Size = UDim2.fromScale(1, 1)
	newLayer.Active = false
	newLayer.Parent = newGui
	local newFlash = Instance.new("Frame")
	newFlash.Name = "Flash"
	newFlash.BorderSizePixel = 0
	newFlash.Size = UDim2.fromScale(1, 1)
	newFlash.BackgroundTransparency = 1
	newFlash.Active = false
	newFlash.ZIndex = 1
	newFlash.Parent = newLayer
	newGui.Parent = playerGui
	gui = newGui
	layer = newLayer
	flash = newFlash
	return true
end

-- Confetti --------------------------------------------------------------------------------------------

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local aspect = if camera and camera.ViewportSize.Y > 0 then camera.ViewportSize.X / camera.ViewportSize.Y else 16 / 9
	for index = #pieces, 1, -1 do
		local piece = pieces[index]
		piece.age += dt
		if piece.age >= piece.life or piece.frame.Parent == nil then
			piece.frame:Destroy()
			table.remove(pieces, index)
		else
			piece.vy += Feel.GRAVITY * dt
			piece.vx *= math.max(0, 1 - 0.9 * dt) -- a little drag, so the burst slows and drifts
			-- Speeds are in screen heights; x moves in screen widths.
			piece.x += piece.vx * dt / aspect
			piece.y += piece.vy * dt
			local frame = piece.frame
			frame.Position = UDim2.fromScale(piece.x, piece.y)
			frame.Rotation += piece.spin * dt
			local fade = math.clamp((piece.life - piece.age) / 0.35, 0, 1)
			frame.BackgroundTransparency = 1 - fade
		end
	end
	if #pieces == 0 and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function burst(style: Feel.Style)
	local parent = layer
	if parent == nil or style.count <= 0 then
		return
	end
	for _ = 1, style.count do
		if #pieces >= Feel.MAX_PARTICLES then
			local oldest = table.remove(pieces, 1)
			if oldest then
				oldest.frame:Destroy()
			end
		end
		local frame = Instance.new("Frame")
		frame.Name = "Confetti"
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Active = false
		frame.ZIndex = 3
		frame.BackgroundColor3 = color(style.colors[random:NextInteger(1, #style.colors)])
		local long = random:NextNumber(0.016, 0.026)
		frame.Size = UDim2.fromScale(long * 0.35, long)
		frame.Rotation = random:NextNumber(0, 360)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = frame
		local x: number, y: number, vx: number, vy: number
		if style.rain then
			x = random:NextNumber(0.05, 0.95)
			y = random:NextNumber(-0.12, -0.02)
			vx = random:NextNumber(-0.15, 0.15)
			vy = random:NextNumber(style.speed[1], style.speed[2])
		else
			x = style.origin[1] + random:NextNumber(-0.02, 0.02)
			y = style.origin[2] + random:NextNumber(-0.02, 0.02)
			local angle = random:NextNumber(-1.1, 1.1) -- around straight up
			local speed = random:NextNumber(style.speed[1], style.speed[2])
			vx = math.sin(angle) * speed
			vy = -math.cos(angle) * speed
		end
		frame.Position = UDim2.fromScale(x, y)
		frame.Parent = parent
		table.insert(pieces, {
			frame = frame,
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			spin = random:NextNumber(-360, 360),
			age = 0,
			life = style.seconds * random:NextNumber(0.75, 1),
		})
	end
	if stepConnection == nil then
		stepConnection = RunService.RenderStepped:Connect(step)
	end
end

-- Flash and title -------------------------------------------------------------------------------------

local function flashScreen(style: Feel.Style, reduced: boolean)
	local start = Feel.flashFor(style, reduced)
	local frame = flash
	if start == nil or frame == nil then
		return
	end
	frame.BackgroundColor3 = color(style.flashColor)
	frame.BackgroundTransparency = start
	TweenService:Create(frame, TweenInfo.new(Feel.FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

local function showTitle(text: string, reduced: boolean)
	local parent = layer
	if parent == nil then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.56, 0.13)
	label.BackgroundTransparency = 1
	label.Active = false
	label.ZIndex = 4
	label.Font = Theme.FONT.display
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Theme.ROLE.star
	label.TextTransparency = if reduced then 1 else 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Theme.ROLE.background
	stroke.Transparency = label.TextTransparency
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = if reduced then 1 else 0.4
	scale.Parent = label
	label.Parent = parent
	if reduced then
		TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	else
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(TITLE_HOLD_SECONDS, function()
		local out = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, out, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		task.delay(0.4, function()
			label:Destroy()
		end)
	end)
end

-- World sparkles ----------------------------------------------------------------------------------------

local function padPosition(id: string): Vector3?
	local base = workspace:FindFirstChild("Base")
	local pads = if base then base:FindFirstChild("BuildPads") else nil
	local pad = if pads then pads:FindFirstChild(id) else nil
	if pad and pad:IsA("BasePart") then
		return pad.Position + Vector3.new(0, 4, 0)
	end
	return nil
end

local function sparkles(at: Vector3, colors: { string })
	local holder = Instance.new("Attachment")
	holder.Name = "SBO_CelebrateSparkles"
	holder.Position = at -- Terrain sits at the origin, so this is the world position
	holder.Parent = workspace.Terrain
	for index, name in colors do
		local emitter = Instance.new("ParticleEmitter")
		-- Stage 11 test: the star icon is a UI image with no 3D texture version (Studio warned "No
		-- asset content representation"), so the sparks keep Roblox's default soft particle.
		emitter.Color = ColorSequence.new(color(name))
		emitter.LightEmission = 0.7
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Speed = NumberRange.new(9, 17)
		emitter.SpreadAngle = Vector2.new(55, 55)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, -5, 0) -- they drift down slowly (low gravity)
		emitter.Drag = 1.2
		emitter.RotSpeed = NumberRange.new(-120, 120)
		emitter.Rate = 0
		emitter.Parent = holder
		emitter:Emit(math.max(1, math.floor(WORLD_SPARKLES / #colors)) + (if index == 1 then 2 else 0))
	end
	task.delay(2.5, function()
		holder:Destroy()
	end)
end

-- Playing ----------------------------------------------------------------------------------------------

local function title(kind: string, n: number?): string?
	local style = Feel.STYLES[kind]
	local key = style and style.title
	if key == nil then
		return nil
	end
	return Store.t(key, { n = n or 1 })
end

local function show(moment: Feel.Moment, opts: PlayOptions?)
	local style = Feel.STYLES[moment.kind]
	if style == nil or not ensureGui() then
		return
	end
	local reduced = CameraFx.motionReduced()
	flashScreen(style, reduced)
	if not reduced then
		burst(style)
	end
	local text = title(moment.kind, moment.n)
	if text then
		showTitle(text, reduced)
	end
	if style.sting then
		Audio.sting(style.sting)
	end
	if style.world and not reduced then
		local at: Vector3? = if opts then opts.at else nil
		if at == nil and moment.kind == "base" then
			local door = Store.findMarker("HabitatDoor")
			at = padPosition("habitat") or (if door then door.Position + Vector3.new(0, 6, 0) else nil)
		elseif at == nil and moment.kind == "build" and moment.id then
			at = padPosition(moment.id :: string)
		end
		if at then
			sparkles(at :: Vector3, style.colors)
		end
	end
end

local function pump()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local moment = table.remove(queue, 1) :: Feel.Moment
			local ok, err = pcall(show, moment, nil)
			if not ok then
				warn(`[SpaceBaseOdyssey] celebration failed: {err}`)
			end
			task.wait(Feel.GAP_SECONDS)
		end
		playing = false
	end)
end

-- Shows one celebration (kinds: see the header). Safe to call any time; never errors.
function Celebrate.play(kind: string, opts: PlayOptions?)
	if Feel.STYLES[kind] == nil then
		return
	end
	local moment: Feel.Moment = { kind = kind :: any, n = if opts then opts.n else nil, id = if opts then opts.id else nil }
	if opts and opts.at then
		-- A moment with its own place plays at once (it is not merged with others).
		local ok, err = pcall(show, moment, opts)
		if not ok then
			warn(`[SpaceBaseOdyssey] celebration failed: {err}`)
		end
		return
	end
	Feel.enqueue(queue, moment)
	pump()
end

-- BaseState watching ------------------------------------------------------------------------------------

local previous: Feel.BaseSnap? = nil
local settleUntil = 0

local function forget()
	previous = nil
	settleUntil = os.clock() + Feel.SETTLE_SECONDS
	table.clear(queue)
end

-- A BaseState from the server (Main.client's BaseState listener calls this with the raw table).
function Celebrate.onBaseState(raw: any)
	local ok, err = pcall(function()
		local snap = Feel.snap(raw)
		if snap == nil then
			return
		end
		local before = previous
		previous = snap
		if not Store.isSlotChosen() or os.clock() < settleUntil then
			return
		end
		for _, moment in Feel.detect(before, snap) do
			Feel.enqueue(queue, moment)
		end
		pump()
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] celebration check failed: {err}`)
	end
end

-- A new save slot (or the start menu again): forget the old base so its load is not celebrated.
function Celebrate.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	forget()
	player:GetAttributeChangedSignal(SLOT_ATTRIBUTE):Connect(forget)
	player:GetAttributeChangedSignal(SLOT_LOADING_ATTRIBUTE):Connect(forget)
	player:GetAttributeChangedSignal(Store.SLOT_CHOSEN_ATTRIBUTE):Connect(forget)
end

return Celebrate
