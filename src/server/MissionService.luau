--!strict
-- Space Base Odyssey - server-authoritative mission loop: phases, actions, shift tasks and storms.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Simulation = require(Shared:WaitForChild("Simulation"))
local SpaceWeatherArchive = require(Shared:WaitForChild("SpaceWeatherArchive"))
local Types = require(Shared:WaitForChild("Types"))

local SpaceWeatherService = require(script.Parent:WaitForChild("SpaceWeatherService"))

type MissionState = Simulation.MissionState
type ShiftResult = Simulation.ShiftResult
type EventId = Simulation.EventId
type SystemId = Simulation.SystemId
type Phase = Types.Phase
type Snapshot = Types.Snapshot
type ShiftState = Types.ShiftState
type SpaceWeather = Types.SpaceWeather
type LiveWeather = Types.LiveWeather
type TextRef = Types.TextRef
type ArchivedFlare = SpaceWeatherArchive.ArchivedFlare
type Params = { [string]: string | number }

export type Remotes = {
	snapshot: RemoteEvent,
	playerStats: RemoteEvent,
	message: RemoteEvent,
	action: RemoteEvent,
}

-- The parts of CrewService this module uses.
export type Crew = {
	setShiftActive: (active: boolean) -> (),
	isPresent: (player: Player) -> boolean,
	isSheltered: (player: Player) -> boolean,
	isCarrying: (player: Player) -> boolean,
	setCarrying: (player: Player, carrying: boolean) -> (),
	takeRefillCount: () -> number,
}

type StormStage = "quiet" | "warning" | "storm" | "over"

type ShiftData = {
	startedAt: number,
	arraysCleaned: number,
	leakRepaired: boolean,
	exposed: { [Player]: boolean },
	flare: ArchivedFlare?,
	stage: StormStage,
	falseAlarm: boolean,
}

local TICK_SECONDS = 0.25
local HINT_DELAY_SECONDS = 5 -- second C.A.R.L. line after the first one has been read
local DEPLETED_ICE_TRANSPARENCY = 0.7
local MAX_ACTIONS_PER_SECOND = 20
local MAX_SEED = 2147483646
local EVENTS: { EventId } = { "None", "Dust", "SolarStorm", "EquipmentFailure" }

local MissionService = {}

local world: any = nil
local crew: Crew = nil :: any
local remotes: Remotes? = nil
local started = false

local phase: Phase = "Briefing"
local phaseSerial = 0 -- bumps on every phase change so delayed messages can tell they are stale
local state: MissionState = Simulation.newMission(MissionData)
local currentSeed = 0
local pendingSeed: number? = nil
local dayStartBackup: MissionState? = nil -- state just before today's beginDay (DebugForceEvent)
local random = Random.new()
local stormFlaresUsed = 0
local flaresReplayed: { [string]: boolean } = {} -- flare IDs already replayed this mission

local shift: ShiftState? = nil
local shiftData: ShiftData? = nil
local spaceWeather: SpaceWeather? = nil
local shiftToken = 0

local dusty: { boolean } = {}
local iceUsed: { boolean } = {}
local iceTransparency: { number } = {}
local applied: { dusty: { [number]: boolean }, leak: boolean?, linked: boolean?, storm: string? } = { dusty = {} }
local appliedAllocation: Simulation.Allocation? = nil -- last plan shown on the base (setSystemVisuals)

local actionWindows: { [Player]: { start: number, count: number } } = {}

----------------------------------------------------------------------------------------------------
-- Helpers

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = deepCopy(item)
	end
	return result
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value == math.floor(value) and math.abs(value) <= MAX_SEED
end

local function textRef(key: string, params: Params?): TextRef
	return { key = key, params = params }
end

local function say(key: string, params: Params?)
	if remotes then
		remotes.message:FireAllClients(textRef(key, params))
	end
end

local function sayTo(player: Player?, key: string, params: Params?)
	if remotes and player and player.Parent then
		remotes.message:FireClient(player, textRef(key, params))
	end
end

-- Sends a message after a short delay, unless the phase changed meanwhile.
local function sayLater(key: string)
	local serial = phaseSerial
	task.delay(HINT_DELAY_SECONDS, function()
		if phaseSerial == serial then
			say(key)
		end
	end)
end

local function setPhase(newPhase: Phase)
	phase = newPhase
	phaseSerial += 1
end

local function worldCall(name: string, ...: any)
	local fn = world and world[name]
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn(`[SpaceBaseOdyssey] WorldBuilder.{name} failed: {err}`)
	end
end

local function countPlayers(): number
	return math.max(1, #Players:GetPlayers())
end

local function countDusty(): number
	local count = 0
	for _, isDusty in dusty do
		if isDusty then
			count += 1
		end
	end
	return count
end

local function flareDate(flare: ArchivedFlare): string
	return string.sub(flare.date, 1, 10)
end

local function flareParams(flare: ArchivedFlare): Params
	return { class = flare.class, date = flareDate(flare) }
end

----------------------------------------------------------------------------------------------------
-- Snapshot

local function buildSnapshot(): Snapshot
	local shiftCopy: ShiftState? = nil
	if shift then
		shiftCopy = table.clone(shift)
	end
	local weatherCopy: SpaceWeather? = nil
	if spaceWeather then
		weatherCopy = table.clone(spaceWeather)
	end
	return {
		phase = phase,
		day = state.day,
		totalDays = state.totalDays,
		todayEvent = state.todayEvent,
		allocation = table.clone(state.allocation),
		cellsAvailable = state.cellsAvailable,
		air = state.air,
		food = state.food,
		dose = state.dose,
		sciencePoints = state.sciencePoints,
		stars = Simulation.stars(state, MissionData),
		outcome = state.outcome,
		history = deepCopy(state.history),
		shift = shiftCopy,
		spaceWeather = weatherCopy,
		liveWeather = SpaceWeatherService.getLive(),
	}
end

local function broadcast()
	if remotes then
		remotes.snapshot:FireAllClients(buildSnapshot())
	end
end

----------------------------------------------------------------------------------------------------
-- World sync

-- Shows today's power plan on the base (grow lights, air maker, rover). Only calls the world when
-- the plan changed, unless `force` (a mission starts or a day begins).
local function syncSystemVisuals(force: boolean?)
	if world == nil then
		return
	end
	local a = state.allocation
	local last = appliedAllocation
	if
		not force
		and last ~= nil
		and last.LifeSupport == a.LifeSupport
		and last.Greenhouse == a.Greenhouse
		and last.Science == a.Science
	then
		return
	end
	appliedAllocation = table.clone(a)
	worldCall("setSystemVisuals", table.clone(a))
end

-- Keeps the dusty-array flags in line with Simulation's clean array count.
local function reconcileDust()
	local wanted = MissionData.POWER.ARRAYS - state.cleanArrays
	for i = 1, MissionData.POWER.ARRAYS do
		if dusty[i] == nil then
			dusty[i] = false
		end
	end
	local current = countDusty()
	if current > wanted then
		for i = MissionData.POWER.ARRAYS, 1, -1 do
			if current <= wanted then
				break
			end
			if dusty[i] then
				dusty[i] = false
				current -= 1
			end
		end
	elseif current < wanted then
		for i = 1, MissionData.POWER.ARRAYS do
			if current >= wanted then
				break
			end
			if not dusty[i] then
				dusty[i] = true
				current += 1
			end
		end
	end
end

local function leakActiveNow(): boolean
	return state.leakActive and not (shiftData ~= nil and shiftData.leakRepaired)
end

local function stormVisualStage(): string
	if shiftData == nil then
		return "none"
	elseif shiftData.stage == "warning" then
		return "warning"
	elseif shiftData.stage == "storm" then
		return "storm"
	end
	return "none"
end

local function setPromptEnabled(prompt: any, enabled: boolean)
	if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

-- Pushes the current mission state to the world: visuals first, then which prompts are usable.
local function refreshWorld()
	if world == nil then
		return
	end
	for i = 1, #world.arrays do
		local isDusty = dusty[i] == true
		if applied.dusty[i] ~= isDusty then
			applied.dusty[i] = isDusty
			worldCall("setArrayDusty", i, isDusty)
		end
	end
	local leak = leakActiveNow()
	if applied.leak ~= leak then
		applied.leak = leak
		worldCall("setLeakActive", leak)
	end
	local linked = shift ~= nil and shift.antennaLinked
	if applied.linked ~= linked then
		applied.linked = linked
		worldCall("setAntennaLinked", linked)
	end
	local storm = stormVisualStage()
	if applied.storm ~= storm then
		applied.storm = storm
		worldCall("setStormVisuals", storm)
	end
	syncSystemVisuals()

	local inShift = phase == "Shift" and shift ~= nil
	worldCall("setShiftPromptsEnabled", inShift)
	for i, ref in world.arrays do
		setPromptEnabled(ref.prompt, inShift and dusty[i] == true)
	end
	for i, node in world.iceNodes do
		setPromptEnabled(node.prompt, inShift and not iceUsed[i])
		if typeof(node.part) == "Instance" and node.part:IsA("BasePart") and iceTransparency[i] then
			node.part.Transparency = if iceUsed[i] then DEPLETED_ICE_TRANSPARENCY else iceTransparency[i]
		end
	end
	setPromptEnabled(world.processorPrompt, inShift)
	setPromptEnabled(world.leak.prompt, inShift and leak)
	setPromptEnabled(world.antenna.prompt, inShift and not linked)
	setPromptEnabled(world.console.prompt, inShift)
end

----------------------------------------------------------------------------------------------------
-- Mission flow

local function newSeed(): number
	local seed = random:NextInteger(1, MAX_SEED)
	while seed == currentSeed do
		seed = random:NextInteger(1, MAX_SEED)
	end
	return seed
end

local function takeSeed(): number
	local seed = pendingSeed
	pendingSeed = nil
	if seed then
		return seed
	end
	return newSeed()
end

local function resetMission(seed: number)
	currentSeed = seed
	state = Simulation.newMission(MissionData, seed)
	random = Random.new(seed)
	stormFlaresUsed = 0
	table.clear(flaresReplayed)
	dayStartBackup = nil
	table.clear(dusty)
	reconcileDust()
	syncSystemVisuals(true)
end

local function beginNextDay()
	dayStartBackup = deepCopy(state)
	Simulation.beginDay(state, MissionData)
	reconcileDust()
	syncSystemVisuals(true)
end

local function planningHintKey(): string
	if state.todayEvent == "Dust" then
		return "carl.dust"
	elseif state.todayEvent == "EquipmentFailure" then
		return "carl.leak"
	end
	return "carl.plan_hint"
end

local function enterPlanning()
	setPhase("Planning")
end

local function enterReport()
	setPhase("Report")
end

-- The first storm of a mission always brings particles; later ones may be real false alarms.
-- SpaceWeatherService prefers a strong flare from today's live DONKI query, else the archive.
local function pickFlare(): (ArchivedFlare, "live" | "archive")
	local flare, source = SpaceWeatherService.pickFlare(stormFlaresUsed == 0, random, flaresReplayed)
	stormFlaresUsed += 1
	flaresReplayed[flare.id] = true
	return flare, source
end

-- Stops the running shift without scoring it (debug only).
local function abortShift()
	shiftToken += 1
	crew.takeRefillCount()
	crew.setShiftActive(false)
	shift = nil
	shiftData = nil
	spaceWeather = nil
	table.clear(iceUsed)
end

local function finishShift()
	if phase ~= "Shift" or shift == nil or shiftData == nil then
		return
	end
	local currentShift = shift :: ShiftState
	local data = shiftData :: ShiftData
	shiftToken += 1

	local exposedCount = 0
	for player in data.exposed do
		if player.Parent ~= nil then
			exposedCount += 1
		end
	end
	local refills = crew.takeRefillCount()
	crew.setShiftActive(false)

	local result: ShiftResult = {
		playerCount = countPlayers(),
		iceCores = currentShift.iceCoresDelivered,
		arraysCleaned = data.arraysCleaned,
		exposedAstronauts = exposedCount,
		leakRepaired = data.leakRepaired,
		suitRefills = refills,
		falseAlarm = if data.falseAlarm then true else nil,
	}
	Simulation.endDay(state, MissionData, result)

	shift = nil
	shiftData = nil
	spaceWeather = nil
	table.clear(iceUsed)
	say("carl.shift_over")

	if state.outcome == "InProgress" then
		beginNextDay()
		enterPlanning()
		sayLater(planningHintKey())
	else
		enterReport()
	end
	refreshWorld()
	broadcast()
end

local function spotFlare(currentShift: ShiftState, data: ShiftData, t: number)
	local flare, source = pickFlare()
	data.flare = flare
	data.stage = "warning"
	local lead = if currentShift.antennaLinked
		then MissionData.STORM.WARNING_SECONDS_WITH_LINK
		else MissionData.STORM.WARNING_SECONDS_NO_LINK
	currentShift.stormWarningAt = t
	currentShift.stormArrivesAt = t + lead
	currentShift.stormEndsAt = t + lead + MissionData.STORM.DURATION_SECONDS
	-- "live" only for a flare from this server's own live query; fetchedAt says when it ran.
	local fetchedAt = if source == "live" then SpaceWeatherService.getFetchedAt() else nil
	if source == "live" and fetchedAt == nil then
		source = "archive" -- cannot happen; never call data live without a query time
	end
	spaceWeather = {
		source = source,
		flareId = flare.id,
		flareClass = flare.class,
		flareDate = flare.date,
		particles = flare.particles,
		fetchedAt = fetchedAt,
	}
	say("carl.storm_warning", flareParams(flare))
	refreshWorld()
	broadcast()
end

local function shiftTick()
	if phase ~= "Shift" or shift == nil or shiftData == nil then
		return
	end
	local currentShift = shift :: ShiftState
	local data = shiftData :: ShiftData
	local t = now()

	if state.todayEvent == "SolarStorm" then
		if data.stage == "quiet" and t - data.startedAt >= MissionData.STORM.FLARE_AT_SECONDS then
			spotFlare(currentShift, data, t)
		end
		local flare = data.flare
		local arrivesAt = currentShift.stormArrivesAt
		local endsAt = currentShift.stormEndsAt
		if flare and arrivesAt and endsAt then
			if data.stage == "warning" and t >= arrivesAt then
				if flare.particles then
					data.stage = "storm"
					say("carl.storm_now")
				else
					-- Nothing arrives: a real big flare without a particle storm.
					data.stage = "over"
					data.falseAlarm = true
					currentShift.stormEndsAt = t
					say("carl.false_alarm", flareParams(flare))
				end
				refreshWorld()
				broadcast()
			end
			if data.stage == "storm" then
				for _, player in Players:GetPlayers() do
					if crew.isPresent(player) and not crew.isSheltered(player) then
						data.exposed[player] = true
					end
				end
				if t >= endsAt then
					data.stage = "over"
					say("carl.storm_over")
					refreshWorld()
					broadcast()
				end
			end
		end
	end

	if t >= currentShift.endsAt then
		finishShift()
	end
end

local function startShift()
	local startedAt = now()
	shiftToken += 1
	local token = shiftToken
	table.clear(iceUsed)
	shift = {
		endsAt = startedAt + MissionData.MISSION.SHIFT_SECONDS,
		antennaLinked = false,
		stormWarningAt = nil,
		stormArrivesAt = nil,
		stormEndsAt = nil,
		dustyArrays = countDusty(),
		leakActive = state.leakActive,
		iceCoresDelivered = 0,
	}
	shiftData = {
		startedAt = startedAt,
		arraysCleaned = 0,
		leakRepaired = false,
		exposed = {},
		flare = nil,
		stage = "quiet",
		falseAlarm = false,
	}
	spaceWeather = nil
	setPhase("Shift")
	crew.setShiftActive(true)
	say("carl.shift_start")
	refreshWorld()
	broadcast()

	task.spawn(function()
		while shiftToken == token do
			task.wait(TICK_SECONDS)
			if shiftToken ~= token then
				break
			end
			local ok, err = pcall(shiftTick)
			if not ok then
				warn(`[SpaceBaseOdyssey] shift tick failed: {err}`)
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Shift task prompts

local function onArrayCleaned(index: number)
	if phase ~= "Shift" or shift == nil or shiftData == nil or not dusty[index] then
		return
	end
	dusty[index] = false
	shiftData.arraysCleaned += 1
	shift.dustyArrays = countDusty()
	say("carl.panel_clean")
	refreshWorld()
	broadcast()
end

local function onIceDrilled(player: Player, index: number)
	if phase ~= "Shift" or shift == nil or iceUsed[index] or crew.isCarrying(player) then
		return
	end
	iceUsed[index] = true
	crew.setCarrying(player, true)
	sayTo(player, "carl.ice_picked")
	refreshWorld()
end

local function onIceDelivered(player: Player)
	if phase ~= "Shift" or shift == nil or not crew.isCarrying(player) then
		return
	end
	crew.setCarrying(player, false)
	shift.iceCoresDelivered += 1
	say("carl.ice_delivered")
	broadcast()
end

local function onLeakRepaired()
	if phase ~= "Shift" or shift == nil or shiftData == nil or not leakActiveNow() then
		return
	end
	shiftData.leakRepaired = true
	shift.leakActive = false
	say("carl.leak_fixed")
	refreshWorld()
	broadcast()
end

local function onAntennaAligned()
	if phase ~= "Shift" or shift == nil or shift.antennaLinked then
		return
	end
	shift.antennaLinked = true
	say("carl.antenna_linked")
	say("carl.earth_delay", {
		moon = MissionData.REAL.MOON_EARTH_LIGHT_TIME_S,
		mars = MissionData.REAL.MARS_LIGHT_TIME_MAX_MIN,
	})
	refreshWorld()
	broadcast()
end

local function onConsole(player: Player)
	if phase ~= "Shift" then
		return
	end
	sayTo(player, "carl.plan_hint")
end

local function connectPrompt(prompt: any, handler: (player: Player) -> ())
	if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player: Player)
			local ok, err = pcall(handler, player)
			if not ok then
				warn(`[SpaceBaseOdyssey] prompt handler failed: {err}`)
			end
		end)
	end
end

local function connectPrompts()
	for i, ref in world.arrays do
		connectPrompt(ref.prompt, function()
			onArrayCleaned(i)
		end)
	end
	for i, node in world.iceNodes do
		if typeof(node.part) == "Instance" and node.part:IsA("BasePart") then
			iceTransparency[i] = node.part.Transparency
		end
		connectPrompt(node.prompt, function(player)
			onIceDrilled(player, i)
		end)
	end
	connectPrompt(world.processorPrompt, onIceDelivered)
	connectPrompt(world.leak.prompt, function()
		onLeakRepaired()
	end)
	connectPrompt(world.antenna.prompt, function()
		onAntennaAligned()
	end)
	connectPrompt(world.console.prompt, onConsole)
end

----------------------------------------------------------------------------------------------------
-- Debug actions

local function assistedResult(): ShiftResult
	-- A skipped day counts as a calm, well-run shift: panels cleaned, leak fixed, nobody exposed.
	return {
		playerCount = countPlayers(),
		iceCores = 0,
		arraysCleaned = MissionData.POWER.ARRAYS - state.cleanArrays,
		exposedAstronauts = 0,
		leakRepaired = true,
		suitRefills = 0,
		falseAlarm = nil,
	}
end

local function debugSkipToDay(target: number)
	if phase == "Shift" then
		abortShift()
	end
	if phase == "Briefing" or state.outcome ~= "InProgress" or target < state.day then
		resetMission(currentSeed)
		beginNextDay()
	end
	while state.day < target and state.outcome == "InProgress" do
		Simulation.endDay(state, MissionData, assistedResult())
		table.clear(dusty)
		reconcileDust()
		if state.outcome == "InProgress" then
			beginNextDay()
		end
	end
	if state.outcome == "InProgress" then
		enterPlanning()
		say(planningHintKey())
	else
		enterReport()
	end
	refreshWorld()
	broadcast()
end

local function debugForceEvent(event: EventId)
	if phase == "Briefing" then
		state.schedule[1] = event
	elseif phase == "Planning" and dayStartBackup then
		local backup = dayStartBackup :: MissionState
		state = deepCopy(backup)
		state.schedule[backup.day + 1] = event
		Simulation.beginDay(state, MissionData)
		reconcileDust()
		syncSystemVisuals(true)
		enterPlanning()
		say(planningHintKey())
		refreshWorld()
	else
		return
	end
	broadcast()
end

local function debugSeed(seed: number)
	pendingSeed = seed
	if phase == "Briefing" then
		resetMission(takeSeed())
		refreshWorld()
	end
	broadcast()
end

----------------------------------------------------------------------------------------------------
-- Actions

local function isDebugAllowed(player: Player?, trusted: boolean): boolean
	if trusted or RunService:IsStudio() then
		return true
	end
	return player ~= nil and player.UserId == game.CreatorId
end

local function rateLimited(player: Player?): boolean
	if player == nil then
		return false
	end
	local t = os.clock()
	local window = actionWindows[player]
	if window == nil or t - window.start >= 1 then
		actionWindows[player] = { start = t, count = 1 }
		return false
	end
	window.count += 1
	return window.count > MAX_ACTIONS_PER_SECOND
end

local function handleAction(player: Player?, action: any, trusted: boolean)
	if type(action) ~= "table" or type(action.type) ~= "string" then
		return
	end
	local kind: string = action.type

	if kind == "SetCells" then
		if phase ~= "Planning" then
			return
		end
		local system = action.system
		if type(system) ~= "string" or table.find(Simulation.SYSTEMS, system :: any) == nil then
			sayTo(player, "error.unknown_system")
			return
		end
		local cells = action.cells
		if not isInteger(cells) or cells < 0 or cells > MissionData.POWER.MAX_CELLS_PER_SYSTEM then
			sayTo(player, "error.cells_range")
			return
		end
		local ok, errorKey = Simulation.setAllocation(state, MissionData, system :: SystemId, cells)
		if ok then
			syncSystemVisuals()
			broadcast()
		elseif errorKey then
			sayTo(player, errorKey)
		end
	elseif kind == "StartMission" then
		if phase ~= "Briefing" then
			return
		end
		beginNextDay()
		enterPlanning()
		say("carl.welcome")
		sayLater(planningHintKey())
		refreshWorld()
		broadcast()
	elseif kind == "StartShift" then
		if phase ~= "Planning" then
			return
		end
		startShift()
	elseif kind == "Restart" then
		if phase ~= "Report" then
			return
		end
		resetMission(takeSeed())
		setPhase("Briefing")
		refreshWorld()
		broadcast()
	elseif kind == "SetLanguage" then
		local language = action.language
		if player and (language == "en" or language == "es") then
			player:SetAttribute("Language", language)
		end
	elseif kind == "DebugForceEvent" then
		if isDebugAllowed(player, trusted) and table.find(EVENTS, action.event) ~= nil then
			debugForceEvent(action.event :: EventId)
		end
	elseif kind == "DebugSkipToDay" then
		local day = action.day
		if isDebugAllowed(player, trusted) and isInteger(day) and day >= 1 and day <= state.totalDays then
			debugSkipToDay(day)
		end
	elseif kind == "DebugSeed" then
		local seed = action.seed
		if isDebugAllowed(player, trusted) and isInteger(seed) and seed >= 0 and seed <= MAX_SEED then
			debugSeed(seed)
		end
	elseif kind == "DebugEndShift" then
		if isDebugAllowed(player, trusted) and phase == "Shift" then
			finishShift()
		end
	end
end

local function safeHandleAction(player: Player?, action: any, trusted: boolean)
	local ok, err = pcall(handleAction, player, action, trusted)
	if not ok then
		warn(`[SpaceBaseOdyssey] action failed: {err}`)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- Creates (or reuses) ReplicatedStorage.Remotes with every RemoteEvent named in Types.Remotes.
function MissionService.createRemotes(): Remotes
	if remotes then
		return remotes
	end
	local names = Types.Remotes
	local folder = ReplicatedStorage:FindFirstChild(names.FOLDER)
	if folder == nil then
		local newFolder = Instance.new("Folder")
		newFolder.Name = names.FOLDER
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end
	local function remote(name: string): RemoteEvent
		local existing = (folder :: Instance):FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	local created: Remotes = {
		snapshot = remote(names.SNAPSHOT),
		playerStats = remote(names.PLAYER_STATS),
		message = remote(names.MESSAGE),
		action = remote(names.ACTION),
	}
	remotes = created
	return created
end

-- worldRefs: WorldBuilder.World; crewService: the CrewService module (already started).
function MissionService.start(worldRefs: any, crewService: Crew)
	assert(not started, "MissionService already started")
	started = true
	world = worldRefs
	crew = crewService
	local remoteEvents = MissionService.createRemotes()

	resetMission(takeSeed())
	connectPrompts()
	refreshWorld()

	-- The live DONKI query finishes in the background; push its result to everyone.
	SpaceWeatherService.onChanged(function(_: LiveWeather)
		broadcast()
	end)

	remoteEvents.action.OnServerEvent:Connect(function(player: Player, action: any)
		if rateLimited(player) then
			return
		end
		safeHandleAction(player, action, false)
	end)

	local function sendSnapshotTo(player: Player)
		remoteEvents.snapshot:FireClient(player, buildSnapshot())
	end
	Players.PlayerAdded:Connect(sendSnapshotTo)
	for _, player in Players:GetPlayers() do
		sendSnapshotTo(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		actionWindows[player] = nil
		if shiftData then
			shiftData.exposed[player] = nil
		end
	end)

	if RunService:IsStudio() then
		local existing = ServerStorage:FindFirstChild("SBO_Debug")
		if existing then
			existing:Destroy()
		end
		local debugFunction = Instance.new("BindableFunction")
		debugFunction.Name = "SBO_Debug"
		debugFunction.OnInvoke = function(action: any): Snapshot
			safeHandleAction(Players:GetPlayers()[1], action, true)
			return buildSnapshot()
		end
		debugFunction.Parent = ServerStorage
	end

	broadcast()
end

function MissionService.getSnapshot(): Snapshot
	return buildSnapshot()
end

function MissionService.getPhase(): Phase
	return phase
end

return MissionService
