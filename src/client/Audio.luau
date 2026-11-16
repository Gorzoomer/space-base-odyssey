--!strict
-- Space Base Odyssey - every sound and the music on this client (Stage 11: sound and music).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.
-- Sounds come from src/shared/AudioIds.luau (team-made audio; a few mix CC0 recordings). They live
-- under SoundService.SBO_Audio and play through the two SoundGroups that Settings.luau creates and
-- whose volume its sliders set: SBO_Music (music, stings) and SBO_SFX (effects). This module finds
-- those groups by name (it creates them only when Settings has not yet, with the same names, so
-- there are never two of each).
-- Science honesty: there is no sound in the vacuum of space. Effects marked `world` (things in the
-- world outside the helmet) play through SBO_SFX_World, a sub-group of SBO_SFX: while the player is
-- outside (player attribute SBO_Inside not true) it is quieter and muffled (an EqualizerSoundEffect
-- cuts the highs), as if felt through the suit and boots. Inside a pressurized module it is normal.
-- Radio, tablet and C.A.R.L. sounds are not `world`: they come through the helmet radio. Music is
-- not part of the world (non-diegetic). Roblox's default character sounds (Earth footsteps, jump
-- and landing) are muted, so nothing "clomps" in vacuum; footsteps play only inside modules.
-- API:
--   Audio.play(name, opts?)   one-shot (pooled; small pitch change for repeated effects). opts:
--                             volume (x default), pitch, at = Vector3 or Instance (3D sound there,
--                             heard only nearby: near / far studs).
--   Audio.loop(name, on, opts?) a 2D loop on or off (short fade). opts: volume, pitch.
--   Audio.hold(name, opts?)   keeps a loop on while it is called (stops ~0.2 s after the last call).
--   Audio.sting(name)         a music sting (victory, level up, fail) that ducks the music.
--   Audio.start(deps)         once from Main.client: the music state machine and the sounds that
--                             follow the Store (base state, stats, storms, eclipse, meteors, prompts,
--                             machine hums near the drills, conveyor and silo).
-- Every call is safe: a missing name warns once, a Roblox error never reaches the caller.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioIds = require(Shared:WaitForChild("AudioIds"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))

local Store = require(script.Parent.Store)

type Entry = AudioIds.Entry

export type PlayOptions = {
	volume: number?,
	pitch: number?,
	at: (Vector3 | Instance)?,
	near: number?, -- 3D: full volume within this many studs
	far: number?, -- 3D: silent past this many studs
}

export type LoopOptions = {
	volume: number?,
	pitch: number?,
}

export type StartDeps = {
	menuOpen: (() -> boolean)?, -- the start menu is on screen
}

-- Names shared with Settings.luau (its sliders set these groups' Volume).
local MUSIC_GROUP = "SBO_Music"
local SFX_GROUP = "SBO_SFX"
local WORLD_GROUP = "SBO_SFX_World" -- child of SBO_SFX
local HELMET_EQ = "SBO_HelmetMuffle"
local FOLDER_NAME = "SBO_Audio"
local INSIDE_ATTRIBUTE = "SBO_Inside"

-- Feel tuning (not gameplay numbers).
local POOL_SIZE = 3 -- copies of each one-shot that may overlap
local OUTSIDE_WORLD_VOLUME = 0.6 -- world sounds outside: felt through the suit, quieter
local OUTSIDE_HIGH_GAIN = -22 -- dB: outside, the highs are cut (muffled)
local OUTSIDE_MID_GAIN = -7
local CROSSFADE_SECONDS = 2.5
local DUCK_LEVEL = 0.3 -- music level under a sting
local DUCK_RELEASE_SECONDS = 1.2
local LOOP_FADE_SECONDS = 0.25
local HOLD_SECONDS = 0.2
local NEAR_DEFAULT = 10
local FAR_DEFAULT = 80
local BUILD_MUSIC_SECONDS = 60 -- build music keeps playing this long after the last build step
local HUM_SCAN_SECONDS = 2
local STORM_POLL_SECONDS = 0.25
local LOW_AIR_REPEAT_SECONDS = 6 -- the low-air beep repeats this often in the red zone
local STEP_STUDS = 5 -- studs walked per footstep inside
local SILO_PROMPT_SECONDS = 4 -- a silo drop this soon after the silo prompt is this player's claim

-- Music states -> track.
local MUSIC_TRACKS: { [string]: string } = {
	menu = "music_menu",
	base_day = "music_base_day",
	base_build = "music_base_build",
	mission = "music_mission",
	storm = "music_storm",
	night_eclipse = "music_night_eclipse",
}

-- Roblox's default character sounds (RbxCharacterSounds), muted: Earth-style footsteps outside
-- would be wrong in vacuum.
local CHARACTER_SOUNDS: { [string]: boolean } = {
	Climbing = true,
	Died = true,
	FreeFalling = true,
	GettingUp = true,
	Jumping = true,
	Landing = true,
	Running = true,
	Splash = true,
	Swimming = true,
}

local Audio = {}

type Pool = { sounds: { Sound }, nextIndex: number }
type LoopState = { sound: Sound, on: boolean, level: number, volume: number, holdUntil: number? }

local ready = false
local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local worldGroup: SoundGroup
local helmetEq: EqualizerSoundEffect
local folder: Folder
local pools: { [string]: Pool } = {}
local loops: { [string]: LoopState } = {}
local lastPlayed: { [string]: number } = {}
local warned: { [string]: boolean } = {}
local musicSounds: { [string]: Sound } = {}
local musicLevels: { [string]: number } = {}
local musicState: string? = nil
local duckUntil = 0
local duckLevel = 1
local insideNow = false
local random = Random.new()

local function findGroup(parent: Instance, name: string): SoundGroup
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = parent
	return group
end

local function applyInside()
	if not ready then
		return
	end
	helmetEq.Enabled = not insideNow
	worldGroup.Volume = if insideNow then 1 else OUTSIDE_WORLD_VOLUME
end

local function init(): boolean
	if ready then
		return true
	end
	local ok, err = pcall(function()
		musicGroup = findGroup(SoundService, MUSIC_GROUP)
		sfxGroup = findGroup(SoundService, SFX_GROUP)
		worldGroup = findGroup(sfxGroup, WORLD_GROUP)
		local eq = worldGroup:FindFirstChild(HELMET_EQ)
		if eq and eq:IsA("EqualizerSoundEffect") then
			helmetEq = eq
		else
			local newEq = Instance.new("EqualizerSoundEffect")
			newEq.Name = HELMET_EQ
			newEq.LowGain = 0
			newEq.MidGain = OUTSIDE_MID_GAIN
			newEq.HighGain = OUTSIDE_HIGH_GAIN
			newEq.Parent = worldGroup
			helmetEq = newEq
		end
		local existing = SoundService:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			local newFolder = Instance.new("Folder")
			newFolder.Name = FOLDER_NAME
			newFolder.Parent = SoundService
			folder = newFolder
		end
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] audio unavailable: {err}`)
		return false
	end
	ready = true
	local player = Players.LocalPlayer
	insideNow = player ~= nil and player:GetAttribute(INSIDE_ATTRIBUTE) == true
	applyInside()
	return true
end

local function entry(name: string): Entry?
	local def = AudioIds[name]
	if def == nil and not warned[name] then
		warned[name] = true
		warn(`[SpaceBaseOdyssey] unknown sound "{name}"`)
	end
	return def
end

local function groupFor(def: Entry): SoundGroup
	if def.group == "Music" then
		return musicGroup
	end
	return if def.world then worldGroup else sfxGroup
end

local function newSound(name: string, def: Entry, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.Looped = def.loop
	sound.SoundGroup = groupFor(def)
	sound.Parent = parent
	return sound
end

local function pitchFor(def: Entry, pitch: number?): number
	local jitter = if def.jitter > 0 then random:NextNumber(-def.jitter, def.jitter) else 0
	return math.max(0.1, (pitch or 1) * (1 + jitter))
end

local function setRollOff(sound: Sound, near: number?, far: number?)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = near or NEAR_DEFAULT
	sound.RollOffMaxDistance = far or FAR_DEFAULT
end

-- A 3D one-shot at a point or on an instance; removed when it ends.
local function playAt(name: string, def: Entry, at: Vector3 | Instance, opts: PlayOptions)
	local holder: Instance
	local attachment: Attachment? = nil
	if typeof(at) == "Vector3" then
		local point = Instance.new("Attachment")
		point.Name = "SBO_Sound_" .. name
		point.Position = at :: Vector3 -- Terrain sits at the origin, so this is the world position
		point.Parent = workspace.Terrain
		attachment = point
		holder = point
	else
		holder = at :: Instance
	end
	local sound = newSound(name, def, holder)
	setRollOff(sound, opts.near, opts.far)
	local speed = pitchFor(def, opts.pitch)
	sound.PlaybackSpeed = speed
	sound.Volume = def.volume * (opts.volume or 1)
	sound:Play()
	local cleanup: Instance = if attachment then attachment else sound
	task.delay(def.seconds / speed + 0.5, function()
		cleanup:Destroy()
	end)
end

local function playNow(name: string, opts: PlayOptions?)
	if not init() then
		return
	end
	local def = entry(name)
	if def == nil then
		return
	end
	local now = os.clock()
	local last = lastPlayed[name]
	if last ~= nil and now - last < def.cooldown then
		return
	end
	lastPlayed[name] = now
	local options: PlayOptions = opts or {}
	if options.at ~= nil then
		playAt(name, def, options.at :: any, options)
		return
	end
	local pool = pools[name]
	if pool == nil then
		pool = { sounds = {}, nextIndex = 1 }
		pools[name] = pool
	end
	local chosen: Sound? = nil
	for _, sound in pool.sounds do
		if not sound.IsPlaying then
			chosen = sound
			break
		end
	end
	if chosen == nil then
		if #pool.sounds < POOL_SIZE then
			chosen = newSound(name, def, folder)
			table.insert(pool.sounds, chosen :: Sound)
		else
			chosen = pool.sounds[pool.nextIndex]
			pool.nextIndex = pool.nextIndex % POOL_SIZE + 1
		end
	end
	local sound = chosen :: Sound
	sound.PlaybackSpeed = pitchFor(def, options.pitch)
	sound.Volume = def.volume * (options.volume or 1)
	sound.TimePosition = 0
	sound:Play()
end

function Audio.play(name: string, opts: PlayOptions?)
	local ok, err = pcall(playNow, name, opts)
	if not ok and not warned["!" .. name] then
		warned["!" .. name] = true
		warn(`[SpaceBaseOdyssey] sound {name} failed: {err}`)
	end
end

local function loopNow(name: string, on: boolean, opts: LoopOptions?)
	if not init() then
		return
	end
	local state = loops[name]
	if state == nil then
		if not on then
			return
		end
		local def = entry(name)
		if def == nil then
			return
		end
		state = { sound = newSound(name, def, folder), on = false, level = 0, volume = def.volume, holdUntil = nil }
		loops[name] = state
	end
	local current = state :: LoopState
	current.on = on
	current.holdUntil = nil
	local def = AudioIds[name]
	if opts and def then
		current.volume = def.volume * (opts.volume or 1)
		if opts.pitch then
			current.sound.PlaybackSpeed = opts.pitch
		end
	end
	if on and not current.sound.IsPlaying then
		current.sound:Play()
	end
end

function Audio.loop(name: string, on: boolean, opts: LoopOptions?)
	local ok, err = pcall(loopNow, name, on, opts)
	if not ok and not warned["!" .. name] then
		warned["!" .. name] = true
		warn(`[SpaceBaseOdyssey] loop {name} failed: {err}`)
	end
end

-- Keeps a loop on while it is called every frame (jetpack thrust); it fades out soon after.
function Audio.hold(name: string, opts: LoopOptions?)
	Audio.loop(name, true, opts)
	local state = loops[name]
	if state then
		state.holdUntil = os.clock() + HOLD_SECONDS
	end
end

-- A short music sting; the music ducks under it.
function Audio.sting(name: string)
	local def = AudioIds[name]
	if def then
		duckUntil = math.max(duckUntil, os.clock() + def.seconds)
	end
	Audio.play(name)
end

-- The music state: one of the MUSIC_TRACKS keys, or nil for silence. Crossfades.
function Audio.setMusic(state: string?)
	if state == musicState then
		return
	end
	musicState = state
	if state == nil or not init() then
		return
	end
	local track = MUSIC_TRACKS[state]
	local def = if track then AudioIds[track] else nil
	if track == nil or def == nil then
		return
	end
	local ok = pcall(function()
		local sound = musicSounds[state]
		if sound == nil then
			sound = newSound(track, def, folder)
			sound.Volume = 0
			musicSounds[state] = sound
			musicLevels[state] = 0
		end
		local music = sound :: Sound
		if music.IsPaused then
			music:Resume()
		elseif not music.IsPlaying then
			music:Play()
		end
	end)
	if not ok then
		warn("[SpaceBaseOdyssey] music failed to start")
	end
end

function Audio.musicState(): string?
	return musicState
end

-- A 3D loop on a part (machine hums). The caller keeps it and sets Playing.
function Audio.attachLoop(name: string, part: Instance, near: number?, far: number?): Sound?
	if not init() then
		return nil
	end
	local def = entry(name)
	if def == nil then
		return nil
	end
	local ok, result = pcall(function(): Sound
		local sound = newSound(name, def, part)
		setRollOff(sound, near, far)
		return sound
	end)
	return if ok then result else nil
end

-- Fades: music crossfades and ducking, loop fades, held loops.
local function step(dt: number)
	if not ready then
		return
	end
	local now = os.clock()
	local duckTarget = if now < duckUntil then DUCK_LEVEL else 1
	if duckLevel > duckTarget then
		duckLevel = math.max(duckTarget, duckLevel - dt / 0.15)
	else
		duckLevel = math.min(duckTarget, duckLevel + dt / DUCK_RELEASE_SECONDS)
	end
	for state, sound in musicSounds do
		local level = musicLevels[state] or 0
		local target = if state == musicState then 1 else 0
		if level < target then
			level = math.min(target, level + dt / CROSSFADE_SECONDS)
		elseif level > target then
			level = math.max(target, level - dt / CROSSFADE_SECONDS)
		end
		musicLevels[state] = level
		local def = AudioIds[MUSIC_TRACKS[state]]
		sound.Volume = (if def then def.volume else 0.4) * level * duckLevel
		if level <= 0 and sound.IsPlaying then
			sound:Pause()
		end
	end
	for _, state in loops do
		if state.holdUntil ~= nil and now > (state.holdUntil :: number) then
			state.on = false
			state.holdUntil = nil
		end
		local target = if state.on then 1 else 0
		if state.level < target then
			state.level = math.min(1, state.level + dt / LOOP_FADE_SECONDS)
		elseif state.level > target then
			state.level = math.max(0, state.level - dt / LOOP_FADE_SECONDS)
		end
		state.sound.Volume = state.volume * state.level
		if state.level <= 0 and state.sound.IsPlaying then
			state.sound:Stop()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Director: the music state machine and the sounds that follow the game state
----------------------------------------------------------------------------------------------------

local started = false
local menuOpen: () -> boolean = function(): boolean
	return false
end
local lastBuildAt = -math.huge
local lastSiloPromptAt = -math.huge

local function baseFolder(): Instance?
	return workspace:FindFirstChild("Base")
end

local function partOf(instance: Instance?): BasePart?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function chooseMusic(): string
	if menuOpen() or not Store.isSlotChosen() then
		return "menu"
	end
	if Store.stormStage() ~= "none" then
		return "storm"
	end
	local phase = Store.phase()
	if phase == "Shift" or phase == "Planning" then
		return "mission"
	end
	if workspace:GetAttribute("SBO_Eclipse") == true then
		return "night_eclipse"
	end
	local base = Store.getBase()
	if base and next(base.inProgress) ~= nil then
		return "base_build"
	end
	if os.clock() - lastBuildAt < BUILD_MUSIC_SECONDS then
		return "base_build"
	end
	return "base_day"
end

-- Base state changes: crates, build steps, finished builds, the silo, the cargo robot, pets.
local shownBase: Store.BaseState? = nil
local function onBase()
	local after = Store.getBase()
	local before = shownBase
	shownBase = if after then table.clone(after) else nil
	if after == nil or before == nil or not Store.isSlotChosen() then
		return
	end
	if after.carryingCrate and not before.carryingCrate then
		Audio.play("crate_pickup")
	elseif before.carryingCrate and not after.carryingCrate then
		Audio.play("crate_drop")
	end
	local stepped = false
	for id, progress in after.inProgress do
		local old = before.inProgress[id]
		if old == nil then
			lastBuildAt = os.clock() -- a build just started
		elseif progress.level == old.level and progress.stage > old.stage then
			stepped = true
		end
	end
	local finished = false
	for id, level in after.builds do
		if level > (before.builds[id] or 0) then
			finished = true
		end
	end
	if finished then
		lastBuildAt = os.clock()
		Audio.play("build_complete")
	elseif stepped then
		lastBuildAt = os.clock()
		Audio.play("build_step")
	end
	if after.siloIce < before.siloIce - 0.5 then
		if os.clock() - lastSiloPromptAt < SILO_PROMPT_SECONDS then
			Audio.play("silo_claim")
		elseif Store.buildLevel("cargo_bot") >= 1 then
			-- The cargo robot emptied the silo: a beep heard near the robot.
			local base = baseFolder()
			local robot = partOf(if base then base:FindFirstChild("CargoRobot", true) else nil)
			if robot then
				Audio.play("cargo_robot_beep", { at = robot, near = 12, far = 70 })
			end
		end
	end
	if after.equipped.pet ~= before.equipped.pet and after.equipped.pet ~= "none" then
		Audio.play("pet_happy")
	end
end

-- Player stats changes: ice, the shelter, suit air.
local shownStats: Store.PlayerStats? = nil
local lowAirAt = -math.huge
local lowZone = "green"
local function onStats()
	local after = Store.getStats()
	local before = shownStats
	shownStats = if after then table.clone(after) else nil
	if after == nil or before == nil or not Store.isSlotChosen() then
		return
	end
	if after.carryingIce and not before.carryingIce then
		Audio.play("ice_pickup")
	elseif before.carryingIce and not after.carryingIce then
		Audio.play("ice_deliver")
	end
	if after.sheltered and not before.sheltered then
		Audio.play("shelter_enter")
	end
	local rawMax: any = after.suitMax -- nil from an older server
	local suitMax: number = if type(rawMax) == "number" and rawMax > 0 then rawMax else MissionData.SUIT.MAX
	if after.inside and not before.inside and after.suitO2 < suitMax * 0.95 then
		Audio.play("suit_refill")
	end
	local percent = math.clamp(after.suitO2 / suitMax * 100, 0, 100)
	local zone = if after.inside then "green" else Simulation.meterZone(percent, "air", MissionData)
	local now = os.clock()
	if zone ~= "green" and (lowZone == "green" or (zone == "red" and lowZone ~= "red")) then
		lowAirAt = now
		Audio.play("suit_low_air")
	elseif zone == "red" and now - lowAirAt >= LOW_AIR_REPEAT_SECONDS then
		lowAirAt = now
		Audio.play("suit_low_air")
	end
	lowZone = zone
end

-- Phase changes: stings at the mission report.
local shownPhase: string? = nil
local function onSnapshot()
	local phase = Store.phase()
	if phase == shownPhase then
		return
	end
	local before = shownPhase
	shownPhase = phase
	if phase == "Report" and before ~= nil then
		local result = Store.missionResult()
		if result and result.success then
			Audio.sting("sting_victory")
		else
			Audio.sting("sting_mission_fail")
		end
	end
end

-- Collectibles found (the progress record grows).
local shownCollectibles: number? = nil
local function onProgress()
	local count = Store.collectibleCount()
	if shownCollectibles ~= nil and count > (shownCollectibles :: number) then
		Audio.play("coin_burst")
	end
	shownCollectibles = count
end

-- Storm stage: alarm at the warning and when particles arrive, radio static during the storm.
local shownStorm = "none"
local function pollStorm()
	local stage: string = Store.stormStage()
	local stats = Store.getStats()
	local sheltered = stats ~= nil and stats.sheltered
	if stage ~= shownStorm then
		if stage == "warning" or stage == "storm" then
			Audio.play("storm_alarm")
		elseif shownStorm ~= "none" then
			Audio.play("toast_pop") -- all clear
		end
		shownStorm = stage
	end
	if stage == "storm" then
		Audio.loop("storm_particles_loop", true, { volume = if sheltered then 0.4 else 1 })
	else
		Audio.loop("storm_particles_loop", false)
	end
end

-- Machine hums: 3D loops on the drills, the conveyor and the silo, heard only nearby.
type Hum = { model: Instance, sound: Sound }
local hums: { [string]: Hum } = {}
local function hum(key: string, name: string, modelName: string, on: boolean, pitch: number, volume: number)
	local current = hums[key]
	if current and (current.model.Parent == nil or current.sound.Parent == nil) then
		current.sound:Destroy()
		hums[key] = nil
		current = nil
	end
	if current == nil then
		if not on then
			return
		end
		local base = baseFolder()
		local model = if base then base:FindFirstChild(modelName, true) else nil
		local part = partOf(model)
		if model == nil or part == nil then
			return
		end
		local sound = Audio.attachLoop(name, part :: BasePart, 14, 75)
		if sound == nil then
			return
		end
		current = { model = model :: Instance, sound = sound :: Sound }
		hums[key] = current
	end
	local found = current :: Hum
	found.sound.PlaybackSpeed = pitch
	local def = AudioIds[name]
	found.sound.Volume = (if def then def.volume else 0.5) * volume
	if on and not found.sound.IsPlaying then
		found.sound:Play()
	elseif not on and found.sound.IsPlaying then
		found.sound:Stop()
	end
end

local function refreshHums()
	local drillOn = Store.buildLevel("drill_1") >= 1
	for index = 1, 3 do
		hum(`drill{index}`, "drill_loop", `IceDrill{index}`, Store.buildLevel(`drill_{index}`) >= 1, 0.94 + 0.05 * index, 1)
	end
	hum("conveyor", "conveyor_loop", "IceConveyor", drillOn, 1, 1)
	local base = Store.getBase()
	local filling = base ~= nil and base.siloIce < base.siloMax
	hum("silo", "conveyor_loop", "IceSilo", drillOn and filling, 0.8, 0.5)
end

-- Meteorite craters appear in Workspace.Base.Impacts: a radar tone, then the thud nearby.
local impactsWatched: Instance? = nil
local function watchImpacts()
	local base = baseFolder()
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
		Audio.play("meteor_whoosh") -- radar tracking tone on the helmet radio (no air, no whoosh)
		if position then
			local at = position :: Vector3
			task.delay(0.3, function()
				Audio.play("meteor_impact", { at = at, near = 25, far = 260 })
			end)
		end
	end)
end

-- Mutes Roblox's default character sounds on a character (see CHARACTER_SOUNDS).
local function muteSound(item: Instance)
	if not CHARACTER_SOUNDS[item.Name] or not (item:IsA("Sound") or item.ClassName == "AudioPlayer") then
		return
	end
	local parent = item.Parent
	if parent == nil or parent.Name ~= "HumanoidRootPart" then
		return
	end
	local target: any = item
	pcall(function()
		target.Volume = 0
	end)
	item:GetPropertyChangedSignal("Volume"):Connect(function()
		if target.Volume ~= 0 then
			target.Volume = 0
		end
	end)
end

local function watchCharacter(character: Model)
	for _, item in character:GetDescendants() do
		muteSound(item)
	end
	character.DescendantAdded:Connect(muteSound)
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
end

-- Footsteps inside pressurized modules (air carries sound there).
local stepProgress = 0.7
local function footsteps(dt: number)
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not insideNow or humanoid == nil or humanoid.Health <= 0 or humanoid.SeatPart ~= nil
		or humanoid.FloorMaterial == Enum.Material.Air or humanoid.MoveDirection.Magnitude < 0.1
	then
		stepProgress = 0.7 -- the first step of a walk comes quickly
		return
	end
	local root = humanoid.RootPart
	if root == nil then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed < 2 then
		return
	end
	stepProgress += dt * speed / STEP_STUDS
	if stepProgress >= 1 then
		stepProgress = 0
		Audio.play("footstep_inside")
	end
end

-- Prompts this player used: hold-to-finish tasks that have no state change of their own.
local PROMPT_SOUNDS: { [string]: string } = {
	["prompt.clean"] = "panel_clean",
	["prompt.antenna"] = "antenna_lock",
	["prompt.repair"] = "build_step",
}

function Audio.start(deps: StartDeps?)
	if started or not init() then
		return
	end
	started = true
	if deps and deps.menuOpen then
		menuOpen = deps.menuOpen
	end
	local player = Players.LocalPlayer

	player:GetAttributeChangedSignal(INSIDE_ATTRIBUTE):Connect(function()
		insideNow = player:GetAttribute(INSIDE_ATTRIBUTE) == true
		applyInside()
	end)
	-- A new save slot: forget the old state (no burst of sounds for the loaded base).
	local function forget()
		shownBase = nil
		shownStats = nil
		shownCollectibles = nil
	end
	player:GetAttributeChangedSignal("SBO_Slot"):Connect(forget)
	player:GetAttributeChangedSignal(Store.SLOT_CHOSEN_ATTRIBUTE):Connect(forget)
	workspace:GetAttributeChangedSignal("SBO_Eclipse"):Connect(function()
		if workspace:GetAttribute("SBO_Eclipse") == true and Store.isSlotChosen() then
			Audio.play("eclipse_swell")
		end
	end)

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "base" then
			onBase()
		elseif kind == "stats" then
			onStats()
		elseif kind == "explore" then
			Audio.play("scan_tablet")
		elseif kind == "progress" then
			onProgress()
		elseif kind == "snapshot" then
			onSnapshot()
		end
	end)
	shownBase = Store.getBase()
	shownStats = Store.getStats()
	shownPhase = Store.phase()

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player then
			return
		end
		if prompt.Name == "SiloPrompt" then
			lastSiloPromptAt = os.clock()
			return
		end
		local key = prompt:GetAttribute("TextKey")
		local name = if type(key) == "string" then PROMPT_SOUNDS[key] else nil
		if name then
			Audio.play(name)
		end
	end)

	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	local sinceStorm = 0
	local sinceScan = HUM_SCAN_SECONDS
	RunService.Heartbeat:Connect(function(dt: number)
		step(dt)
		footsteps(dt)
		sinceStorm += dt
		if sinceStorm >= STORM_POLL_SECONDS then
			sinceStorm = 0
			Audio.setMusic(chooseMusic())
			pollStorm()
		end
		sinceScan += dt
		if sinceScan >= HUM_SCAN_SECONDS then
			sinceScan = 0
			pcall(refreshHums)
			pcall(watchImpacts)
		end
	end)

	-- Preload the short effects so the first click is not silent (music streams when it starts).
	task.spawn(function()
		local sounds: { Instance } = {}
		for name, def in AudioIds do
			if def.group == "Effects" and not def.loop then
				local sound = Instance.new("Sound")
				sound.SoundId = def.id
				sound.Name = name
				table.insert(sounds, sound)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, sound in sounds do
			sound:Destroy()
		end
	end)
end

return Audio
