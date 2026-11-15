--!strict
-- Space Base Odyssey - server-authoritative mission loop: phases, actions, shift tasks and storms.
-- Briefing is the open base between missions (Stage 9: there is no mission menu at start; players
-- roam, build and follow the quests, and start a mission from the mission panel: the habitat's
-- mission console or the Missions button, both on the client, which send StartMission). A mission (src/shared/Missions.luau) sets the number of days,
-- the event schedule, which storms bring particles and the objectives counted here. Tutorials end as
-- soon as their objectives are done and never fail; story chapters and free play are scored when the
-- last day ends.
-- During a shift the snapshot carries live meters (Simulation.liveMeters): the day moving toward its
-- end-of-day values plus task effects at once, pushed at most about four times per second.
-- Stage 6 (build and grow the base): missions can need builds (Mission.needs) and training teaches
-- building (build_* objectives, read from BaseService's effective builds). Useful work pays credits
-- and XP through BaseService. Base mode: in Briefing the crater ice and the water machine stay open
-- for manual ice runs that only pay rewards (no mission, no simulation change). Prompts of structures
-- that are not built stay off. Build, skill, wardrobe, pet and silo actions go to BaseService.
-- Stage 7: players start in the arrival lander and build the habitat first; the water machine, the
-- leak and the mission console live in the habitat, so they only work once it stands. Shift tasks
-- need their tool in hand (ToolService, Missions.OBJECTIVE_TOOLS): the ice drill for crater ice, the
-- panel brush for dusty panels, the tablet to aim the antenna, the repair kit for leaks. Without it
-- C.A.R.L. says which tool to hold ("carl.tool.need_<id>") and nothing happens. deliverIce lets the
-- ice hauler (VehicleService) hand in several cores at once.
-- Stage 9: hooks for QuestService (onMissionCompleted, onIceDelivered, onIceDrilled, onPanelCleaned,
-- onBaseAction) and isMissionUnlocked. A higher antenna level adds BaseBuild.antennaBonus credits to
-- each alignment (BaseService.grantCredits).
-- Stage 10 fix (live playtest): storm exposure is counted second by second while particles are here
-- (accumulateExposure), so the radiation meter climbs live for the crew outside and the day ends on
-- the same value. A storm day has one storm for the whole crew; only the training drill repeats, after
-- STORM.RETRY_GAP_SECONDS and at most STORM.MAX_DRILLS times a shift. survive_storm counts per player.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Missions = require(Shared:WaitForChild("Missions"))
local Simulation = require(Shared:WaitForChild("Simulation"))
local SpaceWeatherArchive = require(Shared:WaitForChild("SpaceWeatherArchive"))
local Types = require(Shared:WaitForChild("Types"))

local SpaceWeatherService = require(script.Parent:WaitForChild("SpaceWeatherService"))
local ToolService = require(script.Parent:WaitForChild("ToolService"))

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
type Mission = Missions.Mission
type Objective = Missions.Objective
type ObjectiveId = Missions.ObjectiveId
type FlareWant = SpaceWeatherService.FlareWant

export type Remotes = {
	snapshot: RemoteEvent,
	playerStats: RemoteEvent,
	message: RemoteEvent,
	action: RemoteEvent,
	progress: RemoteEvent,
	collected: RemoteEvent,
}

-- The parts of CrewService this module uses.
export type Crew = {
	setShiftActive: (active: boolean) -> (),
	isPresent: (player: Player) -> boolean,
	isInside: (player: Player) -> boolean,
	isSheltered: (player: Player) -> boolean,
	isCarrying: (player: Player) -> boolean,
	setCarrying: (player: Player, carrying: boolean) -> (),
	takeRefillCount: () -> number,
	peekRefillCount: () -> number,
	onZoneChanged: (
		listener: (player: Player, inside: boolean, sheltered: boolean, wasInside: boolean, wasSheltered: boolean) -> ()
	) -> (),
	-- Stage 6: suits also drain outside between shifts (base mode); refills then are free.
	setRoamDrain: (active: boolean) -> (),
	-- Stage 7: "lander" | "habitat" | "shelter" | "outside" (optional: older crews only know inside).
	zoneOf: ((player: Player) -> string)?,
}

-- The parts of BaseService (Stage 6) this module uses.
export type BaseApi = {
	handleAction: (player: Player?, action: any, trusted: boolean) -> boolean,
	reward: (player: Player, kind: string, count: number?) -> (),
	rewardAll: (players: { Player }, kind: string, count: number?) -> (),
	effectiveBuilds: () -> { [string]: number },
	onBuildsChanged: (listener: (builds: { [string]: number }) -> ()) -> (),
	-- Stage 9 (optional until BaseService has it): exact credits and XP; skill bonuses apply.
	grantCredits: ((player: Player, credits: number, xp: number) -> ())?,
}

-- The parts of ProgressService this module uses.
export type ProgressApi = {
	get: (player: Player) -> Types.Progress?,
	completedUnion: () -> { [string]: boolean },
	markCompleted: (players: { Player }, missionId: string) -> (),
	grantCollectible: (player: Player, id: string) -> (),
	onChanged: (listener: () -> ()) -> (),
	-- Validates and redeems a code (RedeemCode action); replies to the player through C.A.R.L.
	redeemCode: (player: Player, code: any) -> (),
	-- Stage 9: true once the player's save slot is loaded (players on the start menu are not playing).
	isLoaded: ((player: Player) -> boolean)?,
}

type StormStage = "quiet" | "warning" | "storm" | "over"

type ShiftData = {
	startedAt: number,
	flareAt: number, -- server time when today's flare is spotted (storm days)
	arraysCleaned: number,
	leakRepaired: boolean,
	exposed: { [Player]: boolean }, -- outside while particles were here, at any time today (report cause)
	stormExposed: { [Player]: boolean }, -- exposed during the current storm (survive_storm)
	sheltered: { [Player]: boolean }, -- reached the shelter during the current warning or storm
	flare: ArchivedFlare?,
	stage: StormStage,
	falseAlarm: boolean,
	progress: number, -- 0..1, how much of the shift has passed (never goes back when a tutorial extends)
	-- Stage 10 fix: storms and radiation.
	drills: number, -- flares spotted this shift (training drills are capped at STORM.MAX_DRILLS)
	stormExposure: number, -- crew-average storm exposure so far today (Simulation.stormExposureStep)
	exposureClock: number?, -- server time up to which the current storm's exposure was counted
	outsideWarnedAt: { [Player]: number }, -- last "radiation rising" line sent to each player
}

type LiveMeters = Simulation.LiveMeters

local TICK_SECONDS = 0.25
local HINT_DELAY_SECONDS = 5 -- second C.A.R.L. line after the first one has been read
local DEPLETED_ICE_TRANSPARENCY = 0.7
local MAX_ACTIONS_PER_SECOND = 20
local MAX_SEED = 2147483646
local EVENTS: { EventId } = { "None", "Dust", "SolarStorm", "EquipmentFailure" }
-- GAME: in a tutorial the shift timer never ends the day before the objectives are done; it adds
-- this much time instead. A storm missed in a tutorial comes back after the mission's flare delay.
local TUTORIAL_EXTRA_SECONDS = 30
-- GAME: an extended tutorial shift can take many suit refills (each costs base air). Training counts
-- at most this many, the worst case tests/missions proves can never empty a meter in one day.
local TUTORIAL_MAX_REFILLS = 4
-- Stage 6 actions handled by BaseService.
local BASE_ACTIONS: { [string]: boolean } = {
	Build = true,
	LearnSkill = true,
	Equip = true,
	BuyPet = true,
	ClaimSilo = true,
	UpgradeTool = true, -- Stage 7, at the Lab
	BuyGear = true, -- Stage 8, at the Lab
	ToggleGear = true, -- Stage 8, anywhere (keys B / J)
	DebugMeteor = true, -- Stage 7, BaseService hands it to ExploreService
	DebugGrantCredits = true,
	DebugResetBase = true,
	DebugBuildNext = true,
	DebugMaxResources = true,
}
local BASE_DEBUG_ACTIONS: { [string]: boolean } = { DebugGrantCredits = true, DebugResetBase = true, DebugMeteor = true, DebugBuildNext = true, DebugMaxResources = true }
-- Stage 7: carrying a parts crate fills both hands (player attribute set by BaseService).
local CARRYING_CRATE_ATTRIBUTE = "SBO_CarryingCrate"
-- At most this many ice cores in one hauler delivery (a sanity cap, well above the hauler's cargo).
local MAX_ICE_PER_DELIVERY = 20

local MissionService = {}

local world: any = nil
local crew: Crew = nil :: any
local progress: ProgressApi? = nil
local baseApi: BaseApi? = nil -- nil = no build-and-grow: the whole base stands (Stage 5 behaviour)
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
local applied: { dusty: { [number]: boolean }, leak: boolean?, linked: boolean?, storm: string?, water: number? } =
	{ dusty = {} }
local appliedAllocation: Simulation.Allocation? = nil -- last plan shown on the base (setSystemVisuals)

local actionWindows: { [Player]: { start: number, count: number } } = {}

-- Mission being played (nil in Briefing) and its objective counters.
local missionDef: Mission? = nil
local objectiveProgress: { [string]: number } = {}
local wentOutside: { [Player]: boolean } = {} -- return_inside only counts after going out
local missionResult: Types.MissionResult? = nil
local unlockAll = false -- DebugUnlockAll, this server session only
local hintedBuild: string? = nil -- build the planning hint last asked for (training)
local pendingFirstEvent: EventId? = nil -- DebugForceEvent in Briefing, applied at StartMission
local finishing = false -- inside finishShift: auto-complete waits for the day to close
local autoCompleteQueued = false
local broadcastQueued = false
local lastLive: LiveMeters? = nil -- live meters in the last snapshot sent during a shift
local lastLivePushAt = -math.huge

-- Stage 9: QuestService listeners.
export type BaseActionStage = "before" | "after"
local missionListeners: { (players: { Player }, missionId: string) -> () } = {}
local iceDeliveredListeners: { (player: Player, count: number) -> () } = {}
local iceDrilledListeners: { (player: Player) -> () } = {}
local panelListeners: { (player: Player) -> () } = {}
local baseActionListeners: { (player: Player, kind: string, stage: BaseActionStage) -> () } = {}

local function fire(list: { any }, label: string, ...: any)
	for _, listener in list do
		local ok, err = pcall(listener, ...)
		if not ok then
			warn(`[SpaceBaseOdyssey] {label} listener failed: {err}`)
		end
	end
end

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
local function sayLater(key: string, params: Params?)
	local serial = phaseSerial
	task.delay(HINT_DELAY_SECONDS, function()
		if phaseSerial == serial then
			say(key, params)
		end
	end)
end

local function setPhase(newPhase: Phase)
	phase = newPhase
	phaseSerial += 1
	-- Base mode: suits drain outside while players roam between shifts (refills then are free).
	if crew ~= nil then
		crew.setRoamDrain(newPhase == "Briefing" or newPhase == "Planning")
	end
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

-- Stage 9: players still on the start menu (no save slot loaded, no character) are not in the crew.
local function activePlayers(): { Player }
	local api = progress
	local isLoaded = if api then api.isLoaded else nil
	if isLoaded == nil then
		return Players:GetPlayers()
	end
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		if isLoaded(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function countPlayers(): number
	return math.max(1, #activePlayers())
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
-- Stage 6: builds and rewards (BaseService)

-- Effective builds standing in the server, or nil without BaseService (then the whole base stands).
local function currentBuilds(): { [string]: number }?
	local api = baseApi
	if api == nil then
		return nil
	end
	local ok, builds = pcall(api.effectiveBuilds)
	if ok and type(builds) == "table" then
		return builds
	end
	return {}
end

local function buildLevel(id: string): number
	local builds = currentBuilds()
	if builds == nil then
		return math.huge
	end
	local value = builds[id]
	return if type(value) == "number" then value else 0
end

-- Is a structure standing? The world decides when it can tell (it shows the structure), else the
-- effective builds.
local function structureBuilt(id: string): boolean
	local isBuilt = world and world.isBuilt
	if type(isBuilt) == "function" then
		local ok, built = pcall(isBuilt, id)
		if ok then
			return built == true
		end
	end
	return buildLevel(id) >= 1
end

-- Solar arrays standing for a new mission: the effective solar level, at least 1.
local function solarArrays(): number
	return math.clamp(math.floor(buildLevel("solar")), 1, MissionData.POWER.ARRAYS)
end

-- C.A.R.L. line for "build this first" (only the builds missions need have their own line).
local BUILD_FIRST_KEYS: { [string]: string } = {
	habitat = "carl.build_first.habitat",
	solar = "carl.build_first.solar",
	greenhouse = "carl.build_first.greenhouse",
	antenna = "carl.build_first.antenna",
	shelter = "carl.build_first.shelter",
}
local function buildFirstKey(buildId: string): string
	return BUILD_FIRST_KEYS[buildId] or "carl.build_first"
end

-- Stage 7: the habitat holds the water machine, the leaky pipe and the mission console.
local function habitatBuilt(): boolean
	return structureBuilt("habitat")
end

-- Stage 7: true when the player holds the tool `toolId` in hand. Otherwise C.A.R.L. says which tool
-- to hold and the task does not happen. Without ToolService (it did not start) tasks need no tool.
local function hasToolInHand(player: Player, toolId: string): boolean
	if not ToolService.isActive() then
		return true
	end
	if ToolService.isHolding(player, toolId) then
		return true
	end
	sayTo(player, "carl.tool.need_" .. toolId)
	return false
end

-- Credits and XP for one player's work (kind = key of MissionData.BASE.REWARDS).
local function reward(player: Player?, kind: string, count: number?)
	local api = baseApi
	if api == nil or player == nil or player.Parent == nil then
		return
	end
	local ok, err = pcall(api.reward, player, kind, count)
	if not ok then
		warn(`[SpaceBaseOdyssey] BaseService.reward failed: {err}`)
	end
end

local function rewardPlayers(players: { Player }, kind: string, count: number?)
	local api = baseApi
	if api == nil or #players == 0 or (count ~= nil and count <= 0) then
		return
	end
	local ok, err = pcall(api.rewardAll, players, kind, count)
	if not ok then
		warn(`[SpaceBaseOdyssey] BaseService.rewardAll failed: {err}`)
	end
end

----------------------------------------------------------------------------------------------------
-- Objectives

local function isEarlyReturn(): boolean
	return state.outcome ~= "InProgress" and state.outcome ~= "Completed"
end

-- Stars the crew is on course for: science points only go up, so this never drops before the end.
local function projectedStars(): number
	if state.outcome == "InProgress" then
		local points = state.sciencePoints
		if points >= MissionData.SCIENCE.THREE_STARS then
			return 3
		elseif points >= MissionData.SCIENCE.TWO_STARS then
			return 2
		end
		return 1
	end
	return Simulation.stars(state, MissionData)
end

local function objectiveValue(objective: Objective): number
	if objective.id == "complete_days" then
		-- The day that sent the crew home early does not count as completed.
		return if isEarlyReturn() then math.max(0, #state.history - 1) else #state.history
	elseif objective.id == "stars_at_least" then
		return projectedStars()
	end
	local buildId = Missions.buildForObjective(objective.id)
	if buildId then
		-- build_*: done while that structure stands in the server (whoever built it).
		return if buildLevel(buildId) >= 1 then 1 else 0
	end
	return objectiveProgress[objective.id] or 0
end

local function objectiveDone(objective: Objective): boolean
	return objectiveValue(objective) >= objective.target
end

local function allObjectivesDone(except: ObjectiveId?): boolean
	local def = missionDef
	if def == nil then
		return false
	end
	for _, objective in def.objectives do
		if objective.id ~= except and not objectiveDone(objective) then
			return false
		end
	end
	return true
end

local function hasObjective(id: ObjectiveId): boolean
	local def = missionDef
	if def == nil then
		return false
	end
	for _, objective in def.objectives do
		if objective.id == id then
			return true
		end
	end
	return false
end

local function isTutorial(): boolean
	local def = missionDef
	return def ~= nil and def.kind == "Tutorial"
end

local function missionActive(): boolean
	return missionDef ~= nil and (phase == "Planning" or phase == "Shift")
end

-- True when every objective listed before `id` is done (training keeps its steps in order).
local function earlierObjectivesDone(id: ObjectiveId): boolean
	local def = missionDef
	if def == nil then
		return true
	end
	for _, objective in def.objectives do
		if objective.id == id then
			return true
		end
		if not objectiveDone(objective) then
			return false
		end
	end
	return true
end

-- The build of the first build_* objective of the running mission that is not done yet, or nil.
local function missingBuildObjective(): string?
	local def = missionDef
	if def == nil then
		return nil
	end
	for _, objective in def.objectives do
		local buildId = Missions.buildForObjective(objective.id)
		if buildId and not objectiveDone(objective) then
			return buildId
		end
	end
	return nil
end

-- Tutorials: the shift can only start once everything they teach to build stands, and once every
-- objective listed before start_shift is done (so "set the power" really comes first).
local function readyForShift(): boolean
	local def = missionDef
	if def == nil or def.kind ~= "Tutorial" then
		return true
	end
	if missingBuildObjective() ~= nil then
		return false
	end
	if not hasObjective("start_shift") then
		return true
	end
	return earlierObjectivesDone("start_shift")
end

local function buildMissionInfo(): Types.MissionInfo?
	local def = missionDef
	if def == nil or phase == "Briefing" then
		return nil
	end
	local objectives: { Types.ObjectiveState } = {}
	for _, objective in def.objectives do
		local value = objectiveValue(objective)
		table.insert(objectives, {
			id = objective.id,
			textKey = Missions.objectiveKey(objective.id),
			progress = math.min(value, objective.target),
			target = objective.target,
			done = value >= objective.target,
		})
	end
	return {
		id = def.id,
		kind = def.kind,
		titleKey = Missions.titleKey(def.id),
		objectives = objectives,
	}
end

local function completedMissions(): { [string]: boolean }
	local api = progress
	if api then
		return api.completedUnion()
	end
	return {}
end

-- Unlocked = every required mission done (by anyone here) and every needed build standing.
-- missingBuild is set only when the builds are the one thing still missing.
local function buildMissionCards(): { Types.MissionCard }
	local completed = completedMissions()
	local builds = currentBuilds()
	local cards: { Types.MissionCard } = {}
	for _, mission in Missions.LIST do
		local requiresDone = Missions.requiresDone(mission, completed)
		local missing = if builds ~= nil and requiresDone and not unlockAll
			then Missions.missingBuild(mission, builds)
			else nil
		table.insert(cards, {
			id = mission.id,
			kind = mission.kind,
			titleKey = Missions.titleKey(mission.id),
			icon = mission.icon,
			unlocked = unlockAll or (requiresDone and missing == nil),
			completed = completed[mission.id] == true,
			missingBuild = missing,
		})
	end
	return cards
end

----------------------------------------------------------------------------------------------------
-- Live meters

local function countExposed(data: ShiftData): number
	local count = 0
	for player in data.exposed do
		if player.Parent ~= nil then
			count += 1
		end
	end
	return count
end

-- What the running shift has done so far. `refills`: suit refills counted (peek while running, take
-- at the end). Training counts at most TUTORIAL_MAX_REFILLS, so a training day never empties a meter.
local function shiftResultNow(currentShift: ShiftState, data: ShiftData, refills: number): ShiftResult
	return {
		playerCount = countPlayers(),
		iceCores = currentShift.iceCoresDelivered,
		arraysCleaned = data.arraysCleaned,
		exposedAstronauts = countExposed(data),
		-- Stage 10 fix: exposure counted second by second, so the live meter and the day's end agree.
		stormExposure = data.stormExposure,
		leakRepaired = data.leakRepaired,
		suitRefills = if isTutorial() then math.min(refills, TUTORIAL_MAX_REFILLS) else refills,
		falseAlarm = if data.falseAlarm then true else nil,
		antennaLinked = currentShift.antennaLinked,
	}
end

local function roundTo(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

-- Live HUD values while a shift runs (nil otherwise).
local function computeLive(): LiveMeters?
	local currentShift, data = shift, shiftData
	if phase ~= "Shift" or currentShift == nil or data == nil or state.outcome ~= "InProgress" then
		return nil
	end
	local length = currentShift.endsAt - data.startedAt
	local p = if length > 0 then math.clamp((now() - data.startedAt) / length, 0, 1) else 1
	data.progress = math.max(data.progress, p)
	local result = shiftResultNow(currentShift, data, crew.peekRefillCount())
	local live = Simulation.liveMeters(state, MissionData, result, data.progress)
	local step = MissionData.LIVE.METER_STEP
	live.air = roundTo(live.air, step)
	live.food = roundTo(live.food, step)
	live.dose = roundTo(live.dose, step)
	live.water = roundTo(live.water, step)
	live.pendingScience = math.floor(live.pendingScience + 0.5)
	live.sciencePoints = math.floor(live.sciencePoints + 0.5)
	if isTutorial() then
		-- Training meters may move but never show the red zone.
		local red = MissionData.METERS.RED_ZONE
		live.air = math.max(live.air, math.min(state.air, red + 1))
		live.food = math.max(live.food, math.min(state.food, red + 1))
		live.dose = math.min(live.dose, math.max(state.dose, 100 - red - 1))
	end
	return live
end

local function sameLive(a: LiveMeters?, b: LiveMeters?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.air == b.air
		and a.food == b.food
		and a.dose == b.dose
		and a.water == b.water
		and a.pendingScience == b.pendingScience
		and a.sciencePoints == b.sciencePoints
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
	local live = computeLive()
	return {
		phase = phase,
		day = state.day,
		totalDays = state.totalDays,
		todayEvent = state.todayEvent,
		allocation = table.clone(state.allocation),
		cellsAvailable = state.cellsAvailable,
		air = if live then live.air else state.air,
		food = if live then live.food else state.food,
		dose = if live then live.dose else state.dose,
		water = if live then live.water else state.water,
		waterMax = MissionData.WATER.MAX,
		sciencePoints = if live then live.sciencePoints else state.sciencePoints,
		pendingScience = if live then live.pendingScience else state.pendingScience,
		stars = Simulation.stars(state, MissionData),
		outcome = state.outcome,
		history = deepCopy(state.history),
		shift = shiftCopy,
		spaceWeather = weatherCopy,
		liveWeather = SpaceWeatherService.getLive(),
		mission = buildMissionInfo(),
		missionResult = if missionResult then deepCopy(missionResult) else nil,
		missions = buildMissionCards(),
	}
end

local function broadcast()
	if remotes then
		local snapshot = buildSnapshot()
		remotes.snapshot:FireAllClients(snapshot)
		-- The water tank beside the processor shows the same level as the HUD.
		local fraction = math.clamp(snapshot.water / snapshot.waterMax, 0, 1)
		if applied.water == nil or math.abs((applied.water :: number) - fraction) >= 0.01 then
			applied.water = fraction
			worldCall("setWaterLevel", fraction)
		end
		lastLive = if phase == "Shift" and shift ~= nil
			then {
				air = snapshot.air,
				food = snapshot.food,
				dose = snapshot.dose,
				water = snapshot.water,
				pendingScience = snapshot.pendingScience,
				sciencePoints = snapshot.sciencePoints,
			}
			else nil
		lastLivePushAt = os.clock()
	end
end

-- Shift tick: pushes a snapshot when the live meters moved, at most every LIVE.PUSH_SECONDS.
local function pushLiveIfChanged()
	if os.clock() - lastLivePushAt < MissionData.LIVE.PUSH_SECONDS * 0.9 then
		return
	end
	if not sameLive(computeLive(), lastLive) then
		broadcast()
	end
end

-- One snapshot at the end of this frame, however many objective counters changed.
local function scheduleBroadcast()
	if broadcastQueued then
		return
	end
	broadcastQueued = true
	task.defer(function()
		broadcastQueued = false
		broadcast()
	end)
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

-- Keeps the dusty-array flags in line with Simulation's clean array count. Only the arrays standing
-- for this mission (state.arrays: arrays 1..n) can be dusty.
local function reconcileDust()
	local standing = state.arrays
	local wanted = standing - state.cleanArrays
	for i = 1, MissionData.POWER.ARRAYS do
		if dusty[i] == nil or i > standing then
			dusty[i] = false
		end
	end
	local current = countDusty()
	if current > wanted then
		for i = standing, 1, -1 do
			if current <= wanted then
				break
			end
			if dusty[i] then
				dusty[i] = false
				current -= 1
			end
		end
	elseif current < wanted then
		for i = 1, standing do
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
	-- Base mode (Stage 6): between missions the crater ice and the water machine stay open for
	-- manual ice runs. Ice carried from base mode can still be handed in while planning.
	local baseMode = phase == "Briefing"
	worldCall("setShiftPromptsEnabled", inShift)
	-- Set after the world's own prompt refresh: unbuilt structures keep their prompts off.
	local solarBuilt = structureBuilt("solar")
	local habitatStands = habitatBuilt()
	for i, ref in world.arrays do
		setPromptEnabled(ref.prompt, inShift and solarBuilt and i <= state.arrays and dusty[i] == true)
	end
	for i, node in world.iceNodes do
		setPromptEnabled(node.prompt, (inShift and not iceUsed[i]) or baseMode)
		if typeof(node.part) == "Instance" and node.part:IsA("BasePart") and iceTransparency[i] then
			node.part.Transparency = if inShift and iceUsed[i] then DEPLETED_ICE_TRANSPARENCY else iceTransparency[i]
		end
	end
	setPromptEnabled(world.processorPrompt, habitatStands and (inShift or baseMode or phase == "Planning"))
	setPromptEnabled(world.leak.prompt, habitatStands and inShift and leak)
	setPromptEnabled(world.antenna.prompt, inShift and not linked and structureBuilt("antenna"))
	setPromptEnabled(world.console.prompt, habitatStands and inShift)
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

local function resetMission(seed: number, def: Mission?)
	currentSeed = seed
	-- A mission runs with the solar arrays standing when it starts (Stage 6: the players build them).
	local config: Simulation.MissionConfig? = if def
		then { totalDays = def.days, schedule = def.schedule, arrays = solarArrays() }
		else nil
	state = Simulation.newMission(MissionData, seed, config)
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
	local missingBuild = missingBuildObjective()
	if missingBuild then
		return buildFirstKey(missingBuild) -- training: build it at its glowing pad first
	end
	if state.todayEvent == "Dust" then
		return "carl.dust"
	elseif state.todayEvent == "EquipmentFailure" then
		return "carl.leak"
	elseif state.water < MissionData.WATER.USE_PER_DAY then
		return "carl.no_water" -- the air maker will run short: fetch ice
	end
	return "carl.plan_hint"
end

local function enterPlanning()
	setPhase("Planning")
end

-- Scores the mission when it ends: success = the crew came home on time with every objective met.
local function evaluateMission(): Types.MissionResult
	local def = missionDef
	local missing: { string } = {}
	if def then
		for _, objective in def.objectives do
			if not objectiveDone(objective) then
				table.insert(missing, Missions.objectiveKey(objective.id))
			end
		end
	end
	return { success = state.outcome == "Completed" and #missing == 0, missingKeys = missing }
end

local function enterReport()
	local result = evaluateMission()
	missionResult = result
	setPhase("Report")
	local def = missionDef
	local api = progress
	local players = activePlayers()
	if def then
		-- Every star in the report pays every player here (an early return still earns 1 star).
		rewardPlayers(players, "star", Simulation.stars(state, MissionData))
	end
	if result.success and def then
		-- First completion pays more than a replay. Checked before saving the completion.
		local first: { Player } = {}
		local again: { Player } = {}
		for _, player in players do
			local saved = if api then api.get(player) else nil
			if saved and saved.completed[def.id] then
				table.insert(again, player)
			else
				table.insert(first, player)
			end
		end
		if api then
			api.markCompleted(players, def.id)
		end
		rewardPlayers(first, "mission_first")
		rewardPlayers(again, "mission_repeat")
		fire(missionListeners, "mission completed", players, def.id)
	end
end

-- Adds to an objective counter while a mission is running. Counters are shared by the whole crew.
local checkAutoComplete: () -> ()
local function addProgress(id: ObjectiveId, amount: number?)
	if not missionActive() then
		return
	end
	objectiveProgress[id] = (objectiveProgress[id] or 0) + (amount or 1)
	if hasObjective(id) then
		scheduleBroadcast()
		checkAutoComplete()
	end
end

-- Which flare today's storm needs. A mission's stormParticles decides (a chapter can ask for a real
-- false alarm); otherwise the first storm of a mission always brings particles and later ones may be
-- real false alarms. SpaceWeatherService prefers a strong flare from the live DONKI query, else the
-- archive, and the flare keeps its real particles value and its honest live / archive label.
local function flareWant(): FlareWant
	local def = missionDef
	local particles = def and def.stormParticles
	if def and particles then
		local wanted = particles[Missions.stormIndex(def, state.day)]
		if wanted ~= nil then
			return if wanted then "particles" else "none"
		end
	end
	return if stormFlaresUsed == 0 then "particles" else "any"
end

local function pickFlare(): (ArchivedFlare, "live" | "archive")
	local flare, source = SpaceWeatherService.pickFlare(flareWant(), random, flaresReplayed)
	stormFlaresUsed += 1
	flaresReplayed[flare.id] = true
	return flare, source
end

-- Counts storm exposure up to a time (defined with the storm loop below).
local accumulateExposure: (currentShift: ShiftState, data: ShiftData, t: number) -> ()

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

local function finishShift(forceComplete: boolean?)
	if phase ~= "Shift" or shift == nil or shiftData == nil then
		return
	end
	local currentShift = shift :: ShiftState
	local data = shiftData :: ShiftData
	shiftToken += 1

	-- The real end of the day replaces the live preview (same rules, so the values match). Storm
	-- exposure is counted up to this moment first (a shift ended early mid-storm).
	accumulateExposure(currentShift, data, now())
	local result = shiftResultNow(currentShift, data, crew.takeRefillCount())
	crew.setShiftActive(false)
	Simulation.endDay(state, MissionData, result)
	rewardPlayers(activePlayers(), "day_finished")

	finishing = true
	addProgress("finish_day")
	finishing = false
	if isTutorial() and isEarlyReturn() then
		state.outcome = "Completed" -- tutorials never fail (one day cannot empty a meter: tests/missions)
	end
	local def = missionDef
	if
		state.outcome == "InProgress"
		and (forceComplete or (def ~= nil and def.autoComplete and allObjectivesDone()))
	then
		state.outcome = "Completed"
	end

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
	data.drills += 1
	data.exposureClock = nil
	table.clear(data.stormExposed)
	table.clear(data.sheltered)
	table.clear(data.outsideWarnedAt)
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

-- Training only: a storm the crew did not survive (or that never came) comes back so they can
-- practise sheltering again. The dose already taken stays: radiation dose never goes down.
-- Stage 10 fix (live playtest: with three players the drill looped every ~50 s while anyone stayed
-- outside): the next flare waits STORM.RETRY_GAP_SECONDS of quiet, and after STORM.MAX_DRILLS drills
-- in one shift there are no more (Simulation.drillRetryAt). Returns true when a drill was re-armed.
local function rearmTutorialStorm(currentShift: ShiftState, data: ShiftData, t: number): boolean
	local def = missionDef
	if def == nil or def.kind ~= "Tutorial" or not hasObjective("survive_storm") then
		return false
	end
	local nextFlareAt = Simulation.drillRetryAt(MissionData, data.drills, t)
	if nextFlareAt == nil then
		return false -- the stage stays "over": the day can end (see shiftTick)
	end
	data.stage = "quiet"
	data.flare = nil
	data.falseAlarm = false
	data.flareAt = nextFlareAt
	currentShift.stormWarningAt = nil
	currentShift.stormArrivesAt = nil
	currentShift.stormEndsAt = nil
	spaceWeather = nil
	sayLater("carl.drill_again")
	return true
end

-- True while a training storm drill is still to come or running. A storm tutorial whose drills are
-- used up lets the shift end on the clock, so one teammate staying outside never keeps the others in
-- the drill forever.
local function stormDrillPending(data: ShiftData): boolean
	if not hasObjective("survive_storm") or state.todayEvent ~= "SolarStorm" then
		return true -- other tutorials: their tasks can still be done at any time
	end
	return data.stage ~= "over"
end

-- C.A.R.L. tells a player standing outside during the particle storm that their radiation is rising,
-- at most every STORM.OUTSIDE_REMINDER_SECONDS.
local function warnOutside(player: Player, data: ShiftData, t: number)
	local last = data.outsideWarnedAt[player]
	if last ~= nil and t - last < MissionData.STORM.OUTSIDE_REMINDER_SECONDS then
		return
	end
	data.outsideWarnedAt[player] = t
	sayTo(player, "carl.storm_outside")
end

-- Stage 10 fix: counts the particle storm's exposure up to time `t` (never past the storm's end),
-- second by second: each interval adds the share of the crew standing outside the shelter right now.
-- Only the real storm stage counts (a false alarm brings no particles, so no dose). The total feeds
-- the live dose meter and, unchanged, the end of the day (no double counting).
accumulateExposure = function(currentShift: ShiftState, data: ShiftData, t: number)
	if data.stage ~= "storm" then
		return
	end
	local arrivesAt = currentShift.stormArrivesAt
	local endsAt = currentShift.stormEndsAt
	if arrivesAt == nil or endsAt == nil then
		return
	end
	local from = math.max(data.exposureClock or arrivesAt, arrivesAt)
	local to = math.min(t, endsAt)
	if to <= from then
		return
	end
	data.exposureClock = to
	local players = activePlayers()
	local exposedNow = 0
	for _, player in players do
		if crew.isPresent(player) and not crew.isSheltered(player) then
			exposedNow += 1
			data.exposed[player] = true
			data.stormExposed[player] = true
			warnOutside(player, data, t)
		end
	end
	data.stormExposure += Simulation.stormExposureStep(MissionData, exposedNow, math.max(1, #players), to - from)
end

-- The particle storm has ended: survive_storm counts when at least one astronaut stayed safe in the
-- shelter the whole storm (Stage 10 fix, per player). In a cooperative crew a teammate who stays
-- outside does not take the objective away from the ones who sheltered: they pay for it in radiation
-- (the crew meter and the report). On the last training drill, reaching the shelter before the
-- storm ended is enough, so the training can still be completed.
local function stormSurvived(data: ShiftData): boolean
	local reachedShelter = false
	for _, player in activePlayers() do
		if crew.isPresent(player) and data.sheltered[player] then
			if not data.stormExposed[player] then
				return true
			end
			reachedShelter = reachedShelter or crew.isSheltered(player)
		end
	end
	return isTutorial() and data.drills >= MissionData.STORM.MAX_DRILLS and reachedShelter
end

local function shiftTick()
	if phase ~= "Shift" or shift == nil or shiftData == nil then
		return
	end
	local currentShift = shift :: ShiftState
	local data = shiftData :: ShiftData
	local t = now()

	-- One storm per storm day for the whole crew (never one per player); only training drills repeat.
	if state.todayEvent == "SolarStorm" then
		if data.stage == "quiet" and t >= data.flareAt then
			spotFlare(currentShift, data, t)
		end
		-- reach_shelter: in the shelter while a warning or a storm is on.
		if data.stage == "warning" or data.stage == "storm" then
			for _, player in activePlayers() do
				if not data.sheltered[player] and crew.isPresent(player) and crew.isSheltered(player) then
					data.sheltered[player] = true
					addProgress("reach_shelter")
				end
			end
		end
		local flare = data.flare
		local arrivesAt = currentShift.stormArrivesAt
		local endsAt = currentShift.stormEndsAt
		if flare and arrivesAt and endsAt then
			if data.stage == "warning" and t >= arrivesAt then
				if flare.particles then
					data.stage = "storm"
					data.exposureClock = arrivesAt
					-- Sheltered astronauts hear "stay in the shelter"; the ones outside hear that their
					-- radiation is rising (accumulateExposure, below).
					for _, player in Players:GetPlayers() do
						if not (crew.isPresent(player) and not crew.isSheltered(player)) then
							sayTo(player, "carl.storm_now")
						end
					end
				else
					-- Nothing arrives: a real big flare without a particle storm.
					data.stage = "over"
					data.falseAlarm = true
					currentShift.stormEndsAt = t
					say("carl.false_alarm", flareParams(flare))
					rearmTutorialStorm(currentShift, data, t)
				end
				refreshWorld()
				broadcast()
			end
			if data.stage == "storm" then
				accumulateExposure(currentShift, data, t)
				if t >= endsAt then
					data.stage = "over"
					say("carl.storm_over")
					if stormSurvived(data) then
						addProgress("survive_storm")
					end
					-- Training: while anything is still open the drill runs again (after a quiet break,
					-- at most STORM.MAX_DRILLS per shift) instead of leaving the crew with nothing to do.
					if isTutorial() and not allObjectivesDone("finish_day") then
						rearmTutorialStorm(currentShift, data, t)
					end
					refreshWorld()
					broadcast()
				end
			end
		end
	end

	if t >= currentShift.endsAt then
		if isTutorial() and not allObjectivesDone("finish_day") and stormDrillPending(data) then
			currentShift.endsAt = t + TUTORIAL_EXTRA_SECONDS
			broadcast()
		else
			finishShift()
			return
		end
	end
	pushLiveIfChanged()
end

local function startShift()
	local startedAt = now()
	shiftToken += 1
	local token = shiftToken
	table.clear(iceUsed)
	local def = missionDef
	local shiftSeconds = (def and def.shiftSeconds) or MissionData.MISSION.SHIFT_SECONDS
	local flareAtSeconds = (def and def.flareAtSeconds) or MissionData.STORM.FLARE_AT_SECONDS
	shift = {
		endsAt = startedAt + shiftSeconds,
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
		flareAt = startedAt + flareAtSeconds,
		arraysCleaned = 0,
		leakRepaired = false,
		exposed = {},
		stormExposed = {},
		sheltered = {},
		flare = nil,
		stage = "quiet",
		falseAlarm = false,
		progress = 0,
		drills = 0,
		stormExposure = 0,
		exposureClock = nil,
		outsideWarnedAt = {},
	}
	spaceWeather = nil
	setPhase("Shift")
	crew.setShiftActive(true)
	say("carl.shift_start")
	addProgress("start_shift")
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
-- Mission select and auto-complete

-- An auto-complete mission (the tutorials) ends as soon as every objective is done: mid-shift the
-- day closes normally first; in Planning the mission ends right away.
local function completeMissionNow()
	if missionDef == nil then
		return
	end
	if phase == "Shift" then
		finishShift(true)
	elseif phase == "Planning" then
		if state.outcome == "InProgress" then
			state.outcome = "Completed"
		end
		enterReport()
		refreshWorld()
		broadcast()
	end
end

checkAutoComplete = function()
	local def = missionDef
	if def == nil or not def.autoComplete or finishing or autoCompleteQueued or not allObjectivesDone() then
		return
	end
	autoCompleteQueued = true
	local serial = phaseSerial
	-- Deferred so the prompt or tick that finished the last objective completes first.
	task.defer(function()
		autoCompleteQueued = false
		if phaseSerial == serial and missionDef == def and allObjectivesDone() then
			completeMissionNow()
		end
	end)
end

local function isUnlocked(mission: Mission): boolean
	return unlockAll or Missions.isUnlocked(mission, completedMissions(), currentBuilds())
end

-- The build `mission` still needs when that is the only thing keeping it locked, else nil.
local function blockingBuild(mission: Mission, completed: { [string]: boolean }): string?
	local builds = currentBuilds()
	if unlockAll or builds == nil or not Missions.requiresDone(mission, completed) then
		return nil
	end
	return Missions.missingBuild(mission, builds)
end

-- missionId nil = the next mission: the first unlocked one nobody here has completed, else the last
-- unlocked one (free play once the story is done). A locked or unknown id gives nil; when the only
-- thing missing is a build, the second result names it (C.A.R.L. says "build it first").
local function resolveMission(missionId: any): (Mission?, string?)
	local completed = completedMissions()
	if missionId ~= nil then
		if type(missionId) ~= "string" then
			return nil, nil
		end
		local mission = Missions.get(missionId)
		if mission == nil then
			return nil, nil
		end
		if isUnlocked(mission) then
			return mission, nil
		end
		return nil, blockingBuild(mission, completed)
	end
	local lastUnlocked: Mission? = nil
	for _, mission in Missions.LIST do
		if isUnlocked(mission) then
			if not completed[mission.id] then
				return mission, nil
			end
			lastUnlocked = mission
		elseif not completed[mission.id] then
			-- The next new mission waits for a build: say which instead of replaying an old one.
			local missing = blockingBuild(mission, completed)
			if missing then
				return nil, missing
			end
		end
	end
	return lastUnlocked, nil
end

-- Prepares `def` without starting day 1 (shared by StartMission and DebugSkipToDay).
local function prepareMission(def: Mission, seed: number)
	missionDef = def
	missionResult = nil
	table.clear(objectiveProgress)
	table.clear(wentOutside)
	autoCompleteQueued = false
	resetMission(seed, def)
	hintedBuild = missingBuildObjective()
	if pendingFirstEvent then
		state.schedule[1] = pendingFirstEvent
		pendingFirstEvent = nil
	end
end

local function startMission(def: Mission)
	if phase == "Shift" then
		abortShift()
	end
	prepareMission(def, takeSeed())
	beginNextDay()
	enterPlanning()
	-- Zone changes only count transitions, and Briefing does not move anybody. A player who starts
	-- the mission already standing outside has gone out: count it, so coming back in counts too.
	for _, player in Players:GetPlayers() do
		if crew.isPresent(player) and not crew.isInside(player) then
			wentOutside[player] = true
			addProgress("go_outside")
		end
	end
	if def.order == 1 then
		say("carl.welcome")
		sayLater(planningHintKey())
	else
		say(planningHintKey())
	end
	refreshWorld()
	broadcast()
end

-- Back to the open base (no mission running) with a clean mission state.
local function returnToBriefing()
	if phase == "Shift" then
		abortShift()
	end
	missionDef = nil
	missionResult = nil
	hintedBuild = nil
	table.clear(objectiveProgress)
	table.clear(wentOutside)
	resetMission(newSeed())
	setPhase("Briefing")
	refreshWorld()
	broadcast()
end

-- Stage 7: the lander is a pressurized room too, but "go back inside" means the base: the habitat
-- (or the shelter). Crews that cannot tell the rooms apart count any inside.
local function inBase(player: Player): boolean
	local zoneOf = crew.zoneOf
	if zoneOf == nil then
		return crew.isInside(player)
	end
	local ok, zone = pcall(zoneOf, player)
	return ok and (zone == "habitat" or zone == "shelter")
end

-- go_outside / return_inside from CrewService zone changes (lander, habitat or shelter count as
-- inside). go_outside: leaving the lander counts.
local function onZoneChanged(player: Player, inside: boolean, _sheltered: boolean, wasInside: boolean, _wasSheltered: boolean)
	if inside == wasInside or not missionActive() then
		return
	end
	if not inside then
		wentOutside[player] = true
		addProgress("go_outside")
	elseif wentOutside[player] and inBase(player) and earlierObjectivesDone("return_inside") then
		-- First steps: coming back in counts once the steps before it (build the habitat and the
		-- panels) are done.
		addProgress("return_inside")
	end
end

-- First steps: a player already standing in the habitat when its last build finishes has come back
-- in (no zone change would tell).
local function catchUpReturnInside()
	if not missionActive() or not hasObjective("return_inside") or (objectiveProgress.return_inside or 0) >= 1 then
		return
	end
	if not earlierObjectivesDone("return_inside") then
		return
	end
	for _, player in Players:GetPlayers() do
		if wentOutside[player] and crew.isInside(player) and inBase(player) then
			addProgress("return_inside")
			return
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Shift task prompts

local function onArrayCleaned(player: Player, index: number)
	if phase ~= "Shift" or shift == nil or shiftData == nil or not dusty[index] then
		return
	end
	if not structureBuilt("solar") or index > state.arrays then
		return
	end
	if not hasToolInHand(player, "brush") then
		return
	end
	dusty[index] = false
	shiftData.arraysCleaned += 1
	shift.dustyArrays = countDusty()
	say("carl.panel_clean")
	addProgress("clean_panel")
	reward(player, "panel_cleaned")
	fire(panelListeners, "panel cleaned", player)
	refreshWorld()
	broadcast()
end

-- During a shift each ice spot gives one core. Base mode (Briefing): the crater is open for manual
-- ice runs; spots never run out, but each run still needs empty hands and a walk to the machine.
local function onIceDrilled(player: Player, index: number)
	if crew.isCarrying(player) then
		return
	end
	if phase ~= "Shift" and phase ~= "Briefing" then
		return
	end
	if phase == "Shift" and iceUsed[index] then
		return
	end
	if player:GetAttribute(CARRYING_CRATE_ATTRIBUTE) == true then
		sayTo(player, "carl.tool.hands_full") -- deliver the parts crate first
		return
	end
	if not hasToolInHand(player, "drill") then
		return
	end
	if phase == "Shift" and shift ~= nil then
		if iceUsed[index] then
			return
		end
		iceUsed[index] = true
		crew.setCarrying(player, true)
		sayTo(player, "carl.ice_picked")
		addProgress("drill_ice")
		refreshWorld()
		fire(iceDrilledListeners, "ice drilled", player)
	elseif phase == "Briefing" then
		crew.setCarrying(player, true)
		sayTo(player, "carl.ice_picked")
		fire(iceDrilledListeners, "ice drilled", player)
	end
end

-- During a shift ice fills the water tank (Simulation). Outside a shift (ice from base mode, handed
-- in from Briefing or while planning) it only pays credits and XP: no mission, no water change.
local function onIceDelivered(player: Player)
	if not crew.isCarrying(player) or not habitatBuilt() then
		return
	end
	if phase == "Shift" and shift ~= nil then
		crew.setCarrying(player, false)
		shift.iceCoresDelivered += 1
		say("carl.ice_delivered")
		addProgress("deliver_ice")
		addProgress("deliver_ice_total")
		reward(player, "ice_delivered")
		broadcast()
		fire(iceDeliveredListeners, "ice delivered", player, 1)
	elseif phase == "Briefing" or phase == "Planning" then
		crew.setCarrying(player, false)
		sayTo(player, "carl.ice_saved")
		reward(player, "ice_delivered")
		fire(iceDeliveredListeners, "ice delivered", player, 1)
	end
end

local function onLeakRepaired(player: Player)
	if phase ~= "Shift" or shift == nil or shiftData == nil or not leakActiveNow() or not habitatBuilt() then
		return
	end
	if not hasToolInHand(player, "repair_kit") then
		return
	end
	shiftData.leakRepaired = true
	shift.leakActive = false
	say("carl.leak_fixed")
	addProgress("repair_leak")
	reward(player, "leak_repaired")
	refreshWorld()
	broadcast()
end

local function onAntennaAligned(player: Player)
	if phase ~= "Shift" or shift == nil or shift.antennaLinked or not structureBuilt("antenna") then
		return
	end
	if not hasToolInHand(player, "tablet") then
		return
	end
	-- The science waiting on the HUD right now is sent to Earth (it counts for stars).
	local before = computeLive()
	local waiting = if before then before.pendingScience else state.pendingScience
	shift.antennaLinked = true
	say("carl.antenna_linked")
	if waiting > 0 then
		say("carl.data_sent", { n = waiting })
	end
	addProgress("align_antenna")
	reward(player, "antenna_aligned")
	-- Stage 9: a bigger dish (antenna level 2 and 3) sends more, so each alignment pays a bonus.
	local api = baseApi
	if api then
		local bonus = BaseBuild.antennaBonus(MissionData, api.effectiveBuilds())
		local grantCredits = api.grantCredits
		if bonus > 0 and grantCredits then
			local ok, err = pcall(grantCredits, player, bonus, 0)
			if not ok then
				warn(`[SpaceBaseOdyssey] antenna bonus failed: {err}`)
			end
		end
	end
	sayLater("carl.earth_delay", {
		moon = MissionData.REAL.MOON_EARTH_LIGHT_TIME_S,
		mars = MissionData.REAL.MARS_LIGHT_TIME_MAX_MIN,
	})
	refreshWorld()
	broadcast()
end

local function onConsole(player: Player)
	if phase ~= "Shift" or not habitatBuilt() then
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
		connectPrompt(ref.prompt, function(player)
			onArrayCleaned(player, i)
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
	connectPrompt(world.leak.prompt, onLeakRepaired)
	connectPrompt(world.antenna.prompt, onAntennaAligned)
	connectPrompt(world.console.prompt, onConsole)
end

----------------------------------------------------------------------------------------------------
-- Debug actions

local function assistedResult(): ShiftResult
	-- A skipped day counts as a calm, well-run shift: panels cleaned, leak fixed, nobody exposed.
	return {
		playerCount = countPlayers(),
		iceCores = 0,
		arraysCleaned = state.arrays - state.cleanArrays,
		exposedAstronauts = 0,
		leakRepaired = true,
		suitRefills = 0,
		falseAlarm = nil,
		antennaLinked = true,
	}
end

local function debugSkipToDay(target: number)
	if phase == "Shift" then
		abortShift()
	end
	if phase == "Briefing" or missionDef == nil or state.outcome ~= "InProgress" or target < state.day then
		-- From mission select: the next mission. Otherwise: replay the current one.
		local def = (if phase ~= "Briefing" then missionDef else nil) or resolveMission(nil) or Missions.LIST[1]
		local seed = if phase == "Briefing" then takeSeed() else currentSeed
		prepareMission(def, seed)
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
		pendingFirstEvent = event -- applied to day 1 of the next mission started
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

-- The next mission started uses this seed (event order in free play, flare picks).
local function debugSeed(seed: number)
	pendingSeed = seed
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

	-- Stage 6: builds, skills, wardrobe, pets and the silo belong to BaseService (it validates).
	if BASE_ACTIONS[kind] then
		local api = baseApi
		if api == nil or (BASE_DEBUG_ACTIONS[kind] and not isDebugAllowed(player, trusted)) then
			return
		end
		if player then
			fire(baseActionListeners, "base action", player, kind, "before")
		end
		api.handleAction(player, action, trusted)
		if player then
			fire(baseActionListeners, "base action", player, kind, "after")
		end
		return
	end

	if kind == "SetCells" then
		if phase ~= "Planning" then
			return
		end
		if not habitatBuilt() then
			sayTo(player, buildFirstKey("habitat")) -- the power board is in the habitat
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
		local before = state.allocation[system :: SystemId]
		local ok, errorKey = Simulation.setAllocation(state, MissionData, system :: SystemId, cells)
		if ok then
			syncSystemVisuals()
			if cells ~= before then
				addProgress("set_power")
			end
			broadcast()
		elseif errorKey then
			sayTo(player, errorKey)
		end
	elseif kind == "StartMission" then
		-- From the mission panel (console or Missions button), or "Try again" straight from the report.
		if phase ~= "Briefing" and phase ~= "Report" then
			return
		end
		local def, missingBuild = resolveMission(action.missionId)
		if def then
			startMission(def)
		elseif missingBuild then
			-- The mission needs a build that does not stand yet (Stage 6).
			sayTo(player, buildFirstKey(missingBuild))
		end
	elseif kind == "StartShift" then
		if phase ~= "Planning" then
			return
		end
		if not habitatBuilt() then
			sayTo(player, buildFirstKey("habitat"))
			return
		end
		if not readyForShift() then
			local missingBuild = missingBuildObjective()
			sayTo(player, if missingBuild then buildFirstKey(missingBuild) else "carl.plan_hint")
			return
		end
		startShift()
	elseif kind == "Restart" then
		if phase ~= "Report" then
			return
		end
		returnToBriefing()
	elseif kind == "SetLanguage" then
		local language = action.language
		if player and (language == "en" or language == "es") then
			player:SetAttribute("Language", language)
		end
	elseif kind == "RedeemCode" then
		local api = progress
		if player and api then
			api.redeemCode(player, action.code)
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
	elseif kind == "DebugEclipse" then
		local w: any = world
		if isDebugAllowed(player, trusted) and w and w.previewEclipse then
			pcall(w.previewEclipse)
		end
	elseif kind == "DebugUnlockAll" then
		if isDebugAllowed(player, trusted) then
			unlockAll = true
			broadcast()
		end
	elseif kind == "DebugGrantCollectible" then
		local api = progress
		if isDebugAllowed(player, trusted) and player and api and Missions.isCollectible(action.id) then
			api.grantCollectible(player, action.id :: string)
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
		progress = remote(names.PROGRESS),
		collected = remote(names.COLLECTED),
	}
	remotes = created
	return created
end

-- worldRefs: WorldBuilder.World; crewService: the CrewService module (already started);
-- progressService: the ProgressService module (already started), or nil to play without saving.
-- baseService (Stage 6): the BaseService module (already started), or nil to play with the whole
-- base standing and no credits or XP.
function MissionService.start(worldRefs: any, crewService: Crew, progressService: ProgressApi?, baseService: BaseApi?)
	assert(not started, "MissionService already started")
	started = true
	world = worldRefs
	crew = crewService
	progress = progressService
	baseApi = baseService
	local remoteEvents = MissionService.createRemotes()

	resetMission(newSeed())
	connectPrompts()
	crew.setRoamDrain(phase == "Briefing" or phase == "Planning")
	refreshWorld()

	crew.onZoneChanged(onZoneChanged)
	-- Saved progress decides which missions are unlocked: refresh the mission select cards.
	if progressService then
		progressService.onChanged(scheduleBroadcast)
	end
	-- Builds standing change mission cards, build_* objectives and which prompts work. Deferred so the
	-- world has shown the new structure (and refreshed its own prompts) first.
	if baseService then
		baseService.onBuildsChanged(function(_builds: { [string]: number })
			task.defer(function()
				refreshWorld()
				-- Training: once the build C.A.R.L. asked for stands, the next hint follows (the next
				-- build, or today's plan). First steps has no plan: the next build, then going inside.
				local before = hintedBuild
				hintedBuild = missingBuildObjective()
				if phase == "Planning" and before ~= nil and hintedBuild ~= before then
					if not hasObjective("return_inside") then
						sayLater(planningHintKey())
					elseif hintedBuild ~= nil then
						sayLater(buildFirstKey(hintedBuild :: string))
					else
						sayLater("carl.return_inside")
					end
				end
				catchUpReturnInside()
				checkAutoComplete()
				scheduleBroadcast()
			end)
		end)
	end

	-- The live DONKI query finishes in the background; push its result to everyone.
	SpaceWeatherService.onChanged(function(_: LiveWeather)
		broadcast()
	end)

	remoteEvents.action.OnServerEvent:Connect(function(player: Player, action: any)
		-- Stage 9: the start menu's slot actions belong to ProgressService (its own listener) and must
		-- not use up this player's action budget. Stage 10: so does SaveNow (ProgressService rate-limits it).
		if
			type(action) == "table"
			and (action.type == "ChooseSlot" or action.type == "RequestSlots" or action.type == "SaveNow"
				or action.type == "ListFriendWorlds" or action.type == "JoinWorld")
		then
			return
		end
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
		wentOutside[player] = nil
		if shiftData then
			shiftData.exposed[player] = nil
			shiftData.stormExposed[player] = nil
			shiftData.sheltered[player] = nil
			-- Their share of shiftData.stormExposure stays: radiation dose never goes down.
			shiftData.outsideWarnedAt[player] = nil
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

-- Stage 7: the ice hauler (VehicleService) hands in `count` ice cores for `player` at the water
-- machine. During a shift they fill the water tank and count for the ice objectives, like cores
-- carried by hand; between shifts (Briefing, Planning) they only pay credits and XP. Returns how many
-- were accepted (0 in the report, before the habitat stands, or for a bad count): keep the rest.
function MissionService.deliverIce(player: Player, count: number): number
	if not started or typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then
		return 0
	end
	if type(count) ~= "number" or count ~= count or count < 1 or not habitatBuilt() then
		return 0
	end
	local cores = math.min(math.floor(count), MAX_ICE_PER_DELIVERY)
	if phase == "Shift" and shift ~= nil then
		shift.iceCoresDelivered += cores
		say("carl.ice_delivered")
		addProgress("deliver_ice", cores)
		addProgress("deliver_ice_total", cores)
		reward(player, "ice_delivered", cores)
		broadcast()
		fire(iceDeliveredListeners, "ice delivered", player, cores)
		return cores
	elseif phase == "Briefing" or phase == "Planning" then
		sayTo(player, "carl.ice_saved")
		reward(player, "ice_delivered", cores)
		fire(iceDeliveredListeners, "ice delivered", player, cores)
		return cores
	end
	return 0
end

-- Stage 9: true when the mission can be started now (StartMission would accept it): its required
-- missions are done by someone here and its builds stand (or DebugUnlockAll).
function MissionService.isMissionUnlocked(missionId: string): boolean
	local def = Missions.get(missionId)
	return def ~= nil and isUnlocked(def)
end

-- Stage 9: called with every player in the server and the mission id when a mission is completed
-- (after markCompleted and its rewards).
function MissionService.onMissionCompleted(listener: (players: { Player }, missionId: string) -> ())
	table.insert(missionListeners, listener)
end

-- Stage 9: called when the water machine accepts ice cores for `player` (by hand: count 1; the ice
-- hauler: its whole load), in a shift and between shifts alike.
function MissionService.onIceDelivered(listener: (player: Player, count: number) -> ())
	table.insert(iceDeliveredListeners, listener)
end

-- Stage 9: called when a player drills an ice core in the crater (shift or base mode).
function MissionService.onIceDrilled(listener: (player: Player) -> ())
	table.insert(iceDrilledListeners, listener)
end

-- Stage 9: called when a player cleans a dusty solar array in a shift.
function MissionService.onPanelCleaned(listener: (player: Player) -> ())
	table.insert(panelListeners, listener)
end

-- Stage 9: called around every base action a client sends (Build, ClaimSilo, DebugResetBase...):
-- stage "before" just before BaseService handles it and "after" right after (both synchronous).
function MissionService.onBaseAction(listener: (player: Player, kind: string, stage: BaseActionStage) -> ())
	table.insert(baseActionListeners, listener)
end

-- A C.A.R.L. line for everyone, from other services (for example the eclipse, in Main).
function MissionService.announce(key: string, params: Params?)
	say(key, params)
end

return MissionService
