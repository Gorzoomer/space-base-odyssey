--!strict
-- Space Base Odyssey - quests (Stage 9, team feedback), server side.
-- The game is an open world: no mission menu at start. An ordered line of MAIN quests guides every
-- player through the mechanics (src/shared/Quests.luau holds the data and the pure rules); SIDE quests
-- open along the way, and after the last main quest there is still more to do (side quests, free
-- play, secrets). This module tracks each player's quests from real events, pays each quest's reward
-- once, keeps the progress in the player's save (base record field `quest`, a QuestRecord) and gives
-- BaseService the tracker state for Types.BaseState.quest.
--
-- Where each step type comes from:
--   build        BaseService.effectiveBuilds (builds standing in this server)
--   mission      ProgressService.get(player).completed (MissionService.onMissionCompleted re-checks)
--   gear         the saved gear levels; tool_upgrade: BaseService.tools(player)
--   ice          MissionService.onIceDelivered (by hand and the ice hauler, shift and base mode)
--   clean        MissionService.onPanelCleaned
--   silo         BaseService.onSiloClaimed (not the cargo robot) when BaseService has it; otherwise the
--                ClaimSilo action (MissionService.onBaseAction) and the silo prompt, seen as the silo
--                emptying right after the player asked
--   meteor       ExploreService.onScan, a fresh crater scanned for the first time by this player
--   eat          ToolService.onEat
--   vehicle      VehicleService.onDrive (a driver seat)
--   visit        CrewService rooms (lab, lab_tube -> "lab"; greenhouse_a, greenhouse_b,
--                greenhouse_tube -> "greenhouse"), the crater (standing in it or drilling its ice) and
--                the garage (VehicleService.nearGarage), checked on events and once a second
--   scan, skill, collectible: lifetime totals (sites in base.scanned, the sum of skill levels,
--                collectibles owned), read once a second
-- Counted steps (ice, clean, silo, meteor, eat, vehicle, visit) count only while their quest is
-- active (Quests counting rule). Several quests that finish at once pay together with one C.A.R.L.
-- line. Debug builds (F12, F6) move quests like real play does.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local Types = require(Shared:WaitForChild("Types"))

type Quest = Quests.Quest
type Step = Quests.Step
type View = Quests.View
type QuestState = Types.QuestState
type QuestView = Types.QuestView
type QuestStepState = Types.QuestStepState
type Params = { [string]: string | number }

-- Saved in the player's base record (field `quest`). progress and side[id] are dense arrays, one
-- number per step (step order of the quest), so they store cleanly in a DataStore.
export type QuestRecord = {
	index: number, -- position in Quests.MAIN of the active main quest (#MAIN + 1 once all are done)
	progress: { number }, -- counted steps of the active main quest
	sideDone: { [string]: boolean },
	side: { [string]: { number } }, -- counted steps of open side quests
}

export type Remotes = {
	message: RemoteEvent,
}

-- Technical settings (not gameplay numbers).
local TICK_SECONDS = 1 -- lifetime totals, positions and the tracker are checked this often
local NEW_QUEST_DELAY_SECONDS = 4 -- the "new quest" line follows the "quest done" line
local FIRST_HINT_DELAY_SECONDS = 8 -- a brand-new player hears about the quest list after landing
local CRATER_MARGIN_STUDS = 8 -- standing this far past the crater rim still counts as "in the crater"
local MAX_COUNT = 1000000

local MAIN = Quests.MAIN
local MAIN_COUNT = #MAIN

-- Inside zone ids (CrewService.roomOf) -> quest places.
local ROOM_PLACES: { [string]: string } = {
	lab = "lab",
	lab_tube = "lab",
	greenhouse_a = "greenhouse",
	greenhouse_b = "greenhouse",
	greenhouse_tube = "greenhouse",
}

local QuestService = {}

type PlayerData = {
	record: QuestRecord,
	loaded: boolean,
	state: QuestState?,
	signature: string,
	missionHinted: { [string]: boolean }, -- quest ids whose mission step C.A.R.L. already pointed to
	siloBefore: number?, -- silo ice just before this player's ClaimSilo action
	scheduled: boolean,
}

local started = false
local world: any = nil
local base: any = nil -- BaseService
local missionApi: any = nil -- MissionService
local crew: any = nil -- CrewService
local progress: any = nil -- ProgressService
local vehicles: any = nil -- VehicleService (optional)
local remotes: Remotes? = nil
local craterCentre: Vector3? = nil
local craterRadius = 0
local siloSample = 0 -- the silo's ice at the last tick (silo prompt fallback)
local siloHook = false -- BaseService.onSiloClaimed counts silo claims (fallbacks off)
local warnedReward = false

local players: { [Player]: PlayerData } = {}

----------------------------------------------------------------------------------------------------
-- Records (pure: ProgressService may call these to clean and merge saves)

local function cleanCounts(value: any, length: number): { number }
	local result: { number } = table.create(length, 0)
	if type(value) == "table" then
		for i = 1, length do
			local n = value[i]
			if type(n) == "number" and n == n and n > 0 then
				result[i] = math.min(math.floor(n), MAX_COUNT)
			end
		end
	end
	return result
end

local function stepCount(index: number): number
	local quest = MAIN[index]
	return if quest then #quest.steps else 0
end

local function defaultRecord(): QuestRecord
	return { index = 1, progress = cleanCounts(nil, stepCount(1)), sideDone = {}, side = {} }
end

local function sanitizeRecord(value: any): QuestRecord
	if type(value) ~= "table" then
		return defaultRecord()
	end
	local index = value.index
	if type(index) ~= "number" or index ~= index then
		index = 1
	end
	index = math.clamp(math.floor(index), 1, MAIN_COUNT + 1)
	local sideDone: { [string]: boolean } = {}
	if type(value.sideDone) == "table" then
		for id, flag in value.sideDone do
			local quest = if type(id) == "string" then Quests.byId(id) else nil
			if flag == true and quest and quest.kind == "side" then
				sideDone[quest.id] = true
			end
		end
	end
	local side: { [string]: { number } } = {}
	if type(value.side) == "table" then
		for id, counts in value.side do
			local quest = if type(id) == "string" then Quests.byId(id) else nil
			if quest and quest.kind == "side" and not sideDone[quest.id] then
				side[quest.id] = cleanCounts(counts, #quest.steps)
			end
		end
	end
	return {
		index = index,
		progress = cleanCounts(value.progress, stepCount(index)),
		sideDone = sideDone,
		side = side,
	}
end

local function cloneRecord(record: QuestRecord): QuestRecord
	local side: { [string]: { number } } = {}
	for id, counts in record.side do
		side[id] = table.clone(counts)
	end
	return {
		index = record.index,
		progress = table.clone(record.progress),
		sideDone = table.clone(record.sideDone),
		side = side,
	}
end

local function maxCounts(a: { number }, b: { number }): { number }
	local result = table.clone(a)
	for i, n in b do
		if n > (result[i] or 0) then
			result[i] = n
		end
	end
	return result
end

-- What to store when another server may have saved meanwhile: quests never go back (the further
-- main quest wins, side quests done stay done, counters keep the highest value).
local function mergeRecord(stored: any, current: QuestRecord): QuestRecord
	local old = sanitizeRecord(stored)
	local now = sanitizeRecord(current)
	local merged: QuestRecord
	if old.index > now.index then
		merged = cloneRecord(old)
	elseif old.index < now.index then
		merged = cloneRecord(now)
	else
		merged = cloneRecord(now)
		merged.progress = maxCounts(now.progress, old.progress)
	end
	for id in old.sideDone do
		merged.sideDone[id] = true
	end
	for id in now.sideDone do
		merged.sideDone[id] = true
	end
	local side: { [string]: { number } } = {}
	for _, source in { old.side, now.side } do
		for id, counts in source do
			if not merged.sideDone[id] then
				side[id] = if side[id] then maxCounts(side[id], counts) else table.clone(counts)
			end
		end
	end
	merged.side = side
	return merged
end

-- Quest ids this record has finished (main quests before index, side quests done).
local function doneSet(record: QuestRecord): { [string]: boolean }
	local done: { [string]: boolean } = {}
	for i = 1, math.min(record.index - 1, MAIN_COUNT) do
		done[MAIN[i].id] = true
	end
	for id in record.sideDone do
		done[id] = true
	end
	return done
end

-- The counters of an active quest (created for an open side quest on first use).
local function countsFor(record: QuestRecord, quest: Quest): { number }
	if quest.kind == "main" then
		return record.progress
	end
	local counts = record.side[quest.id]
	if counts == nil then
		counts = cleanCounts(nil, #quest.steps)
		record.side[quest.id] = counts
	end
	return counts
end

-- True for steps counted by events while the quest is active (stored in the record).
local function isEventStep(step: Step): boolean
	if step.type == "visit" or step.type == "vehicle" then
		return true
	end
	return Quests.isCounted(step.type) and not Quests.isLifetime(step.type)
end

----------------------------------------------------------------------------------------------------
-- Helpers

local function sayTo(player: Player, key: string, params: Params?)
	local events = remotes
	if events and player.Parent then
		local text: Types.TextRef = { key = key, params = params }
		events.message:FireClient(player, text)
	end
end

local function call(target: any, name: string, ...: any): (boolean, any)
	local fn = if type(target) == "table" then target[name] else nil
	if type(fn) ~= "function" then
		return false, nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(`[SpaceBaseOdyssey] QuestService: {name} failed: {result}`)
		return false, nil
	end
	return true, result
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function siloNow(): number?
	for player, data in players do
		if data.loaded and player.Parent then
			local ok, state = call(base, "getState", player)
			if ok and type(state) == "table" and type(state.siloIce) == "number" then
				return state.siloIce
			end
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- What the server knows about one player (Quests.View pieces)

type Context = {
	builds: { [string]: number },
	missions: { [string]: boolean },
	gear: { [string]: number },
	tools: { [string]: number },
	lifetime: { [string]: number },
}

local function contextOf(player: Player): Context?
	local okBase, saved = call(progress, "getBase", player)
	if not okBase or type(saved) ~= "table" then
		return nil
	end
	local _, builds = call(base, "effectiveBuilds")
	local _, tools = call(base, "tools", player)
	local _, saveProgress = call(progress, "get", player)
	local missions: { [string]: boolean } = {}
	local collectibles = 0
	if type(saveProgress) == "table" then
		if type(saveProgress.completed) == "table" then
			missions = saveProgress.completed
		end
		if type(saveProgress.collectibles) == "table" then
			for _, owned in saveProgress.collectibles do
				if owned == true then
					collectibles += 1
				end
			end
		end
	end
	local skills = 0
	if type(saved.skills) == "table" then
		for _, level in saved.skills do
			if type(level) == "number" and level > 0 then
				skills += level
			end
		end
	end
	local sites = 0
	if type(saved.scanned) == "table" then
		for key, flag in saved.scanned do
			if flag == true and type(key) == "string" and string.sub(key, 1, 4) == "poi:" then
				sites += 1
			end
		end
	end
	return {
		builds = if type(builds) == "table" then builds else {},
		missions = missions,
		gear = if type(saved.gear) == "table" then saved.gear else {},
		tools = if type(tools) == "table" then tools else {},
		lifetime = { scan = sites, skill = skills, collectible = collectibles },
	}
end

local function viewFor(context: Context, quest: Quest, counts: { number }): View
	local stepCounts: { [string]: number } = {}
	local visited: { [string]: boolean } = {}
	for i, step in quest.steps do
		if Quests.isLifetime(step.type) then
			stepCounts[step.type] = context.lifetime[step.type] or 0
		elseif step.type == "visit" then
			if (counts[i] or 0) >= 1 and step.place then
				visited[step.place] = true
			end
		elseif isEventStep(step) then
			stepCounts[step.type] = counts[i] or 0
		end
	end
	return {
		builds = context.builds,
		missions = context.missions,
		gear = context.gear,
		tools = context.tools,
		counts = stepCounts,
		visited = visited,
	}
end

local function questView(context: Context, quest: Quest, counts: { number }): QuestView
	local view = viewFor(context, quest, counts)
	local steps: { QuestStepState } = {}
	local stepIndex = #quest.steps + 1
	for i, step in quest.steps do
		local have, need = Quests.stepProgress(step, view)
		local done = have >= need
		if not done and stepIndex > #quest.steps then
			stepIndex = i
		end
		steps[i] = {
			key = Quests.stepKey(quest.id, i),
			progress = have,
			target = need,
			done = done,
			mission = if step.type == "mission" then step.id else nil,
		}
	end
	return {
		id = quest.id,
		kind = quest.kind,
		titleKey = Quests.titleKey(quest.id),
		icon = quest.icon,
		stepIndex = stepIndex,
		steps = steps,
		reward = { credits = quest.reward.credits, xp = quest.reward.xp },
	}
end

local function stateOf(context: Context, record: QuestRecord): QuestState
	local done = doneSet(record)
	local sides: { QuestView } = {}
	for _, quest in Quests.sideAvailable(done) do
		table.insert(sides, questView(context, quest, countsFor(record, quest)))
	end
	local main = MAIN[record.index]
	local shown: QuestView? = if main then questView(context, main, record.progress) else sides[1]
	local state: QuestState = {
		id = "",
		kind = "main",
		titleKey = Quests.FINALE_KEY,
		icon = "flag",
		stepIndex = 1,
		steps = {},
		reward = { credits = 0, xp = 0 },
		mainDone = main == nil,
		mainCount = math.min(record.index - 1, MAIN_COUNT),
		mainTotal = MAIN_COUNT,
		sides = sides,
	}
	if shown then
		state.id = shown.id
		state.kind = shown.kind
		state.titleKey = shown.titleKey
		state.icon = shown.icon
		state.stepIndex = shown.stepIndex
		state.steps = shown.steps
		state.reward = shown.reward
	end
	return state
end

----------------------------------------------------------------------------------------------------
-- Saving, paying and telling the client

local function save(player: Player, data: PlayerData)
	local snapshot = cloneRecord(data.record)
	call(progress, "updateBase", player, function(saved: any)
		saved.quest = snapshot
	end)
end

-- Pays a quest reward with the skill bonuses (BaseService.grantCredits). Returns what was given.
local function pay(player: Player, credits: number, xp: number): (number, number)
	local fn = if type(base) == "table" then base.grantCredits else nil
	if type(fn) == "function" then
		local ok, givenCredits, givenXp = pcall(fn, player, credits, xp)
		if ok then
			return if type(givenCredits) == "number" then givenCredits else credits,
				if type(givenXp) == "number" then givenXp else xp
		end
		warn(`[SpaceBaseOdyssey] quest reward failed: {givenCredits}`)
		return 0, 0
	end
	-- Older BaseService: add the reward to the save directly (no skill bonus, no level-up line).
	if not warnedReward then
		warnedReward = true
		warn("[SpaceBaseOdyssey] BaseService has no grantCredits; quest rewards skip the skill bonus")
	end
	local ok = call(progress, "updateBase", player, function(saved: any)
		saved.credits += credits
		saved.xp += xp
	end)
	return (if ok then credits else 0), (if ok then xp else 0)
end

local function push(player: Player, data: PlayerData, context: Context)
	local state = stateOf(context, data.record)
	local ok, signature = pcall(HttpService.JSONEncode, HttpService, state)
	local key = if ok then signature else tostring(os.clock())
	data.state = state
	if key ~= data.signature then
		data.signature = key
		if type(base) == "table" and type(base.pushState) == "function" then
			call(base, "pushState", player)
		else
			call(base, "refresh", player)
		end
	end
end

-- C.A.R.L. points to the mission panel when the next step of the main quest is a mission that can
-- start now (between missions only), once per quest and server visit.
local function hintMission(player: Player, data: PlayerData)
	local state = data.state
	local main = MAIN[data.record.index]
	if state == nil or main == nil or state.id ~= main.id or data.missionHinted[main.id] then
		return
	end
	local step = state.steps[state.stepIndex]
	local missionId = if step then step.mission else nil
	if missionId == nil then
		return
	end
	local _, phase = call(missionApi, "getPhase")
	local _, unlocked = call(missionApi, "isMissionUnlocked", missionId)
	if phase == "Briefing" and unlocked == true then
		data.missionHinted[main.id] = true
		sayTo(player, "carl.quest.mission")
	end
end

----------------------------------------------------------------------------------------------------
-- Checking quests

local function sideIds(done: { [string]: boolean }): { [string]: boolean }
	local ids: { [string]: boolean } = {}
	for _, quest in Quests.sideAvailable(done) do
		ids[quest.id] = true
	end
	return ids
end

-- Finishes every active quest whose steps are all done (one after another: finishing a main quest
-- makes the next one active), pays them, saves and refreshes the tracker.
local function evaluate(player: Player)
	local data = players[player]
	if data == nil or not data.loaded or player.Parent == nil then
		return
	end
	local context = contextOf(player)
	if context == nil then
		return
	end
	local record = data.record
	local sidesBefore = sideIds(doneSet(record))
	local mainBefore = record.index
	local credits, xp, finished = 0, 0, 0
	for _ = 1, #Quests.LIST + 1 do
		local finishedOne = false
		for _, quest in Quests.active(doneSet(record)) do
			local counts = countsFor(record, quest)
			if Quests.questDone(quest, viewFor(context, quest, counts)) then
				if quest.kind == "main" then
					record.index += 1
					record.progress = cleanCounts(nil, stepCount(record.index))
				else
					record.sideDone[quest.id] = true
					record.side[quest.id] = nil
				end
				local givenCredits, givenXp = pay(player, quest.reward.credits, quest.reward.xp)
				credits += givenCredits
				xp += givenXp
				finished += 1
				finishedOne = true
				break -- the active list changed
			end
		end
		if not finishedOne then
			break
		end
	end
	if finished > 0 then
		save(player, data)
		sayTo(player, "carl.quest.done", { credits = credits, xp = xp })
		if record.index > mainBefore then
			local finale = record.index > MAIN_COUNT
			task.delay(NEW_QUEST_DELAY_SECONDS, function()
				if players[player] == data then
					sayTo(player, if finale then Quests.FINALE_KEY else "carl.quest.new")
				end
			end)
		end
		local opened = false
		for id in sideIds(doneSet(record)) do
			if not sidesBefore[id] then
				opened = true
			end
		end
		if opened then
			task.delay(NEW_QUEST_DELAY_SECONDS * 2, function()
				if players[player] == data then
					sayTo(player, "carl.quest.side")
				end
			end)
		end
		-- Rewards changed credits and XP (and maybe the level): read the context again for the tracker.
		context = contextOf(player) or context
	end
	push(player, data, context)
	hintMission(player, data)
end

-- Checks soon (once per frame at most, however many events arrive).
local function schedule(player: Player)
	local data = players[player]
	if data == nil or data.scheduled then
		return
	end
	data.scheduled = true
	task.defer(function()
		data.scheduled = false
		if players[player] == data then
			local ok, err = pcall(evaluate, player)
			if not ok then
				warn(`[SpaceBaseOdyssey] quest check failed: {err}`)
			end
		end
	end)
end

local function scheduleAll()
	for player in players do
		schedule(player)
	end
end

-- Adds `amount` to every unfinished step of type `stepType` in the player's active quests.
local function addCount(player: Player, stepType: string, amount: number)
	local data = players[player]
	if data == nil or not data.loaded or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local record = data.record
	local changed = false
	for _, quest in Quests.active(doneSet(record)) do
		for i, step in quest.steps do
			if step.type == stepType and isEventStep(step) then
				local counts = countsFor(record, quest)
				local target = Quests.stepTarget(step)
				local value = math.min(target, (counts[i] or 0) + math.floor(amount))
				if value > (counts[i] or 0) then
					counts[i] = value
					changed = true
				end
			end
		end
	end
	if changed then
		save(player, data)
		schedule(player)
	end
end

-- Marks `place` visited in the player's active quests that ask for it.
local function visit(player: Player, place: string)
	local data = players[player]
	if data == nil or not data.loaded then
		return
	end
	local record = data.record
	local changed = false
	for _, quest in Quests.active(doneSet(record)) do
		for i, step in quest.steps do
			if step.type == "visit" and step.place == place then
				local counts = countsFor(record, quest)
				if (counts[i] or 0) < 1 then
					counts[i] = 1
					changed = true
				end
			end
		end
	end
	if changed then
		save(player, data)
		schedule(player)
	end
end

-- Places still to visit in the player's active quests.
local function wantedPlaces(data: PlayerData): { [string]: boolean }
	local wanted: { [string]: boolean } = {}
	local record = data.record
	for _, quest in Quests.active(doneSet(record)) do
		local counts = if quest.kind == "main" then record.progress else record.side[quest.id] or {}
		for i, step in quest.steps do
			if step.type == "visit" and step.place and (counts[i] or 0) < 1 then
				wanted[step.place] = true
			end
		end
	end
	return wanted
end

local function inCrater(player: Player): boolean
	local centre = craterCentre
	local root = rootOf(player)
	if centre == nil or root == nil then
		return false
	end
	local offset = root.Position - centre
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= craterRadius + CRATER_MARGIN_STUDS
end

-- Visits seen from where the player stands now (a player already in the lab when the quest opens).
local function checkPlaces(player: Player, data: PlayerData)
	local wanted = wantedPlaces(data)
	if next(wanted) == nil then
		return
	end
	if wanted.lab or wanted.greenhouse then
		local _, room = call(crew, "roomOf", player)
		local place = if type(room) == "string" then ROOM_PLACES[room] else nil
		if place and wanted[place] then
			visit(player, place)
		end
	end
	if wanted.crater and inCrater(player) then
		visit(player, "crater")
	end
	if wanted.garage then
		local _, near = call(vehicles, "nearGarage", player)
		if near == true then
			visit(player, "garage")
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Players

local function load(player: Player)
	local data = players[player]
	if data == nil then
		return
	end
	local _, saved = call(progress, "getBase", player)
	local stored = if type(saved) == "table" then saved.quest else nil
	data.record = sanitizeRecord(stored)
	data.loaded = true
	data.signature = ""
	data.state = nil
	table.clear(data.missionHinted)
	local fresh = stored == nil
	schedule(player)
	if fresh then
		task.delay(FIRST_HINT_DELAY_SECONDS, function()
			if players[player] == data and data.record.index == 1 then
				sayTo(player, "carl.quest.new")
			end
		end)
	end
end

local function addPlayer(player: Player)
	if players[player] then
		return
	end
	players[player] = {
		record = defaultRecord(),
		loaded = false,
		state = nil,
		signature = "",
		missionHinted = {},
		siloBefore = nil,
		scheduled = false,
	}
	local _, loaded = call(progress, "isLoaded", player)
	if loaded == true then
		load(player)
	end
end

local function removePlayer(player: Player)
	players[player] = nil
end

local function tick()
	local sample = siloNow()
	if sample then
		siloSample = sample
	end
	for player, data in players do
		if data.loaded and player.Parent then
			checkPlaces(player, data)
			schedule(player)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Event hooks

local function onSiloAsked(player: Player, before: number)
	-- The claim empties the silo down to its fraction of a core (the cargo robot does too, but
	-- only every CARGO_BOT_SECONDS; this check runs right after the player asked).
	task.defer(function()
		local after = siloNow()
		if after and before >= 1 and after < 1 and after < before then
			addCount(player, "silo", 1)
		end
		if after then
			siloSample = after
		end
	end)
end

local function connectHooks()
	-- Silo claims: BaseService tells (best), or the fallbacks below.
	if type(base) == "table" and type(base.onSiloClaimed) == "function" then
		siloHook = true
		-- Called for claims by hand only (the cargo robot's trips never count).
		base.onSiloClaimed(function(player: Player, _ice: number?, quiet: boolean?)
			if quiet ~= true then
				addCount(player, "silo", 1)
			end
		end)
	end

	call(base, "onBuildsChanged", function()
		task.defer(scheduleAll)
	end)
	call(base, "onToolsChanged", schedule)
	call(base, "onGearChanged", schedule)
	call(progress, "onChanged", function()
		scheduleAll()
	end)
	call(progress, "onLoaded", function(player: Player)
		if players[player] == nil then
			addPlayer(player)
		else
			load(player)
		end
	end)
	call(progress, "onCollectible", function(player: Player)
		schedule(player)
	end)

	call(missionApi, "onMissionCompleted", function(list: { Player })
		for _, player in list do
			schedule(player)
		end
	end)
	call(missionApi, "onIceDelivered", function(player: Player, count: number)
		addCount(player, "ice", count)
	end)
	call(missionApi, "onPanelCleaned", function(player: Player)
		addCount(player, "clean", 1)
	end)
	call(missionApi, "onIceDrilled", function(player: Player)
		visit(player, "crater")
	end)
	call(missionApi, "onBaseAction", function(player: Player, kind: string, stage: string)
		local data = players[player]
		if data == nil then
			return
		end
		if kind == "DebugResetBase" and stage == "after" then
			-- The base went back to the start: so do the quests (ProgressService.resetBase).
			data.record = defaultRecord()
			data.signature = ""
			table.clear(data.missionHinted)
			save(player, data)
			schedule(player)
		elseif kind == "ClaimSilo" and not siloHook then
			if stage == "before" then
				data.siloBefore = siloNow()
			else
				local before = data.siloBefore
				data.siloBefore = nil
				if before then
					onSiloAsked(player, before)
				end
			end
		else
			schedule(player)
		end
	end)

	local siloPrompt = world and world.siloPrompt
	if not siloHook and typeof(siloPrompt) == "Instance" and siloPrompt:IsA("ProximityPrompt") then
		siloPrompt.Triggered:Connect(function(player: Player)
			-- BaseService may have handled the prompt already: the last tick's sample is "before".
			local before = math.max(siloSample, siloNow() or 0)
			onSiloAsked(player, before)
		end)
	end

	call(crew, "onRoomChanged", function(player: Player, room: string?)
		local place = if room then ROOM_PLACES[room] else nil
		if place then
			visit(player, place)
		end
	end)

	local explore = script.Parent:FindFirstChild("ExploreService")
	local tool = script.Parent:FindFirstChild("ToolService")
	local vehicle = script.Parent:FindFirstChild("VehicleService")
	local exploreApi = if explore and explore:IsA("ModuleScript") then (require :: any)(explore) else nil
	local toolApi = if tool and tool:IsA("ModuleScript") then (require :: any)(tool) else nil
	vehicles = if vehicle and vehicle:IsA("ModuleScript") then (require :: any)(vehicle) else nil

	call(exploreApi, "onScan", function(player: Player, kind: string, _id: string, isNew: boolean)
		if kind == "meteor" and isNew then
			addCount(player, "meteor", 1)
		else
			schedule(player)
		end
	end)
	call(toolApi, "onEat", function(player: Player)
		addCount(player, "eat", 1)
	end)
	call(vehicles, "onDrive", function(player: Player)
		addCount(player, "vehicle", 1)
	end)
end

----------------------------------------------------------------------------------------------------
-- Public API

-- worldRefs: WorldBuilder.World (siloPrompt); baseService: BaseService (effectiveBuilds, tools,
-- getState, onBuildsChanged, onToolsChanged, onGearChanged, grantCredits, setQuestProvider, pushState,
-- onSiloClaimed: the last four Stage 9); missionService: MissionService (Stage 9 hooks, getPhase,
-- isMissionUnlocked); crewService: CrewService (roomOf, onRoomChanged); remoteEvents.message: C.A.R.L.;
-- progressService: ProgressService (getBase, updateBase, get, isLoaded, onLoaded, onChanged), found
-- next to this module when nil. ExploreService, ToolService and VehicleService are found next to this
-- module (each optional). Start it after all of them.
function QuestService.start(worldRefs: any, baseService: any, missionService: any, crewService: any, remoteEvents: Remotes, progressService: any?)
	assert(not started, "QuestService already started")
	started = true
	world = worldRefs
	base = baseService
	missionApi = missionService
	crew = crewService
	remotes = remoteEvents
	if progressService then
		progress = progressService
	else
		local module = script.Parent:FindFirstChild("ProgressService")
		progress = if module and module:IsA("ModuleScript") then (require :: any)(module) else nil
	end
	if progress == nil then
		warn("[SpaceBaseOdyssey] QuestService has no ProgressService; quests are off")
		return
	end

	local worldParts = script.Parent:FindFirstChild("WorldParts")
	local parts = if worldParts and worldParts:IsA("ModuleScript") then (require :: any)(worldParts) else nil
	if type(parts) == "table" and typeof(parts.CRATER_CENTRE) == "Vector3" and type(parts.CRATER_RADIUS) == "number" then
		craterCentre = parts.CRATER_CENTRE
		craterRadius = parts.CRATER_RADIUS
	else
		warn("[SpaceBaseOdyssey] QuestService: no crater position; crater visits count from drilling only")
	end

	if type(base) == "table" and type(base.setQuestProvider) == "function" then
		base.setQuestProvider(function(player: Player): QuestState?
			return QuestService.getState(player)
		end)
	else
		warn("[SpaceBaseOdyssey] BaseService has no setQuestProvider; the quest tracker gets no state")
	end

	connectHooks()

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[SpaceBaseOdyssey] quest tick failed: {err}`)
			end
		end
	end)
end

-- The tracker state for Types.BaseState.quest (nil before the player's data is loaded). Never calls
-- BaseService (BaseService calls this while it builds the state).
function QuestService.getState(player: Player): QuestState?
	local data = players[player]
	if data == nil or not data.loaded then
		return nil
	end
	return data.state
end

-- True when the player finished quest `id`.
function QuestService.isDone(player: Player, id: string): boolean
	local data = players[player]
	return data ~= nil and data.loaded and doneSet(data.record)[id] == true
end

-- Adds to a counted step type for the player's active quests (for services without a hook here; the
-- type must be one of Quests.STEP_TYPES; lifetime types are read from the save and ignore this).
function QuestService.count(player: Player, stepType: string, amount: number?)
	if Quests.isStepType(stepType) then
		addCount(player, stepType, amount or 1)
	end
end

-- Marks a quest place ("lab" | "greenhouse" | "crater" | "garage") visited for the player.
function QuestService.visit(player: Player, place: string)
	if Quests.isPlace(place) then
		visit(player, place)
	end
end

-- Reads the player's quests from their save again (after a save slot was loaded, when
-- ProgressService.onLoaded does not fire for it).
function QuestService.reload(player: Player)
	if players[player] then
		load(player)
	end
end

-- Pure record helpers for ProgressService (sanitizeBase, defaultBase, mergeBase, cloneBase).
function QuestService.defaultRecord(): QuestRecord
	return defaultRecord()
end

function QuestService.sanitizeRecord(value: any): QuestRecord
	return sanitizeRecord(value)
end

function QuestService.mergeRecord(stored: any, current: QuestRecord): QuestRecord
	return mergeRecord(stored, current)
end

function QuestService.cloneRecord(record: QuestRecord): QuestRecord
	return cloneRecord(record)
end

return QuestService
