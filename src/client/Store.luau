--!strict
-- Space Base Odyssey - client state: latest Snapshot, PlayerStats and Progress (missions, hidden
-- collectibles and event cosmetics), the player's BaseState (Stage 6: credits, XP, builds, skills,
-- pets, what they wear; Stage 7: builds in progress, the parts crate, tools, greenhouse food, scanned
-- sites), chosen language, local settings, the screen mode (mission select open or base mode), the
-- last exploration scan (Stage 7) and the Action sender.
-- Stage 9: the three save slots ("worlds") from the "Slots" remote (start menu), the ChooseSlot
-- action, and the player's active quest (BaseState.quest, read with Store.quest()).
-- Stage 10 fix (private worlds): the "Join a friend" list (Remotes.WORLDS, Store.friendWorlds) and the
-- ListFriendWorlds / JoinWorld actions.
-- Stage 11 menu: settings saved on the server (SaveSettings, see "Local settings"), the accessibility
-- helpers other modules read (Store.textScale, Store.reduceMotion, Store.colourHelper,
-- Store.messageSeconds) and the start-menu-open flag (Store.isMenuOpen / Store.onMenuChanged: C.A.R.L.
-- holds his lines while the menu hides the HUD).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))
local Worlds = require(Shared:WaitForChild("Worlds"))
local ServerGuard = require(Shared:WaitForChild("ServerGuard")) -- Stage 11 menu: settings rules

export type Snapshot = Types.Snapshot
export type PlayerStats = Types.PlayerStats
export type TextRef = Types.TextRef
export type Action = Types.Action
export type LiveWeather = Types.LiveWeather
export type Language = "en" | "es"
-- "base": a new BaseState arrived. "view": the mission select opened or closed (base mode changed).
-- "explore" (Stage 7): the server sent an ExploreEvent (a site or meteorite crater was scanned).
-- "slots" (Stage 9): the save slot list arrived (start menu).
export type ChangeKind =
	"snapshot"
	| "stats"
	| "language"
	| "progress"
	| "settings"
	| "base"
	| "view"
	| "explore"
	| "slots"
export type StormStage = "none" | "warning" | "storm"

-- Stage 4 parts of the Snapshot (see Types.luau). Read through the helpers below.
export type MissionObjective = Types.ObjectiveState
export type MissionInfo = Types.MissionInfo
export type MissionResult = Types.MissionResult
export type MissionCard = Types.MissionCard
export type Progress = Types.Progress
export type BaseState = Types.BaseState
export type Equipped = Types.Equipped
export type BuildProgress = Types.BuildProgress
export type ExploreEvent = Types.ExploreEvent

-- Stage 9 save slots: one entry per slot from the server's meta record ("p_<userId>_meta").
export type SlotMode = "solo" | "friends"
export type SlotInfo = {
	used: boolean,
	habitat: number, -- base level (habitat level, 0 = nothing built)
	level: number, -- player level
	credits: number,
	savedAt: number?, -- os.time() of the last save (nil = never saved)
	mode: SlotMode,
}
export type SlotsMeta = {
	slots: { SlotInfo }, -- always Store.SLOT_COUNT entries
	last: number?, -- the slot used last time (nil = none yet)
	offline: boolean?, -- Stage 10: true = saves could not be read, nothing is saved this visit
}

-- Stage 9 quests: the active quest as the server sends it in BaseState.quest.
export type QuestStepView = {
	key: string, -- localization key of the step text (takes {n})
	progress: number,
	target: number,
	done: boolean,
}
export type QuestView = {
	id: string?, -- nil once there is no active quest
	kind: string, -- "main" | "side"
	stepIndex: number,
	steps: { QuestStepView },
	mainDone: boolean,
}

local Store = {}

-- The four hidden collectibles, in display order (ids fixed by the Stage 4 contract).
Store.COLLECTIBLES = table.freeze({ "mini_earth", "laika", "cheese", "mars_potato" })
-- Icons.luau key per collectible.
Store.COLLECTIBLE_ICONS = table.freeze({
	mini_earth = "planet",
	laika = "paw",
	cheese = "cheese",
	mars_potato = "potato",
} :: { [string]: string })

-- Player settings (Settings panel). Kept on this client; Stage 11 menu: saved on the server with the
-- SaveSettings action (debounced) and read back from the slot list (SlotsMeta.settings), the trip's
-- TeleportData.prefs and the player attributes the server sets (Store.SETTING_ATTRIBUTES, "Language"),
-- so they survive teleports and rejoins. The client never writes these attributes itself.
-- Stage 11 menu: bigText, reduceMotion, colourHelper and messageSpeed are the accessibility page.
export type SettingName =
	"musicVolume"
	| "effectsVolume"
	| "funFacts"
	| "guidance"
	| "bigText"
	| "reduceMotion"
	| "colourHelper"
	| "messageSpeed"
Store.SETTING_ATTRIBUTES = table.freeze({
	musicVolume = "SBO_MusicVolume",
	effectsVolume = "SBO_EffectsVolume",
	funFacts = "SBO_FunFacts",
	guidance = "SBO_Guidance",
	bigText = "SBO_BigText", -- Stage 11 menu
	reduceMotion = "SBO_ReduceMotion",
	colourHelper = "SBO_ColourHelper",
	messageSpeed = "SBO_MessageSpeed",
} :: { [string]: string })
-- UI defaults (not gameplay numbers), the same as ServerGuard's: volumes 0..1, C.A.R.L. features
-- on, accessibility off, messages at normal speed.
local settings: { [string]: number | boolean } = {
	musicVolume = 0.6,
	effectsVolume = 0.8,
	funFacts = true,
	guidance = true,
	bigText = false,
	reduceMotion = false,
	colourHelper = false,
	messageSpeed = 1,
}

local snapshot: Snapshot? = nil
local stats: PlayerStats? = nil
local progress: Progress = { completed = {}, collectibles = {}, cosmetics = {} }
local progressReceived = false
local base: BaseState? = nil
local lastExplore: ExploreEvent? = nil
local slotsMeta: SlotsMeta? = nil
local quest: QuestView? = nil
local missionSelectOpen = false
local language: Language = "en"
local actionRemote: RemoteEvent? = nil
local listeners: { (kind: ChangeKind) -> () } = {}

local function emit(kind: ChangeKind)
	for _, listener in listeners do
		task.spawn(listener, kind)
	end
end

function Store.onChanged(listener: (kind: ChangeKind) -> ())
	table.insert(listeners, listener)
end

function Store.getSnapshot(): Snapshot?
	return snapshot
end

function Store.setSnapshot(value: Snapshot)
	snapshot = value
	emit("snapshot")
end

function Store.getStats(): PlayerStats?
	return stats
end

function Store.setStats(value: PlayerStats)
	stats = value
	emit("stats")
end

function Store.getLanguage(): Language
	return language
end

function Store.setLanguage(value: Language)
	language = value
	Localization.setLanguage(value)
	emit("language")
end

-- Translate a key in the current language.
function Store.t(key: string, params: { [string]: string | number }?): string
	return Localization.t(key, params, language)
end

function Store.setActionRemote(remote: RemoteEvent)
	actionRemote = remote
end

-- Send an Action to the server (ignored until the remote exists). The server validates everything.
function Store.send(action: Action)
	if actionRemote then
		actionRemote:FireServer(action)
	end
end

-- Start a mission by id (nil = the next unlocked one). The server accepts it in Briefing (mission
-- select) and in Report ("Try again").
function Store.startMission(missionId: string?)
	Store.send({ type = "StartMission", missionId = missionId })
end

function Store.phase(): string
	return if snapshot then snapshot.phase else "Briefing"
end

-- Current mission (nil outside a mission, or with an older server).
function Store.mission(): MissionInfo?
	local snap = snapshot
	if snap and type(snap.mission) == "table" then
		return snap.mission
	end
	return nil
end

-- "Tutorial" | "Story" | "Free" | nil.
function Store.missionKind(): string?
	local mission = Store.mission()
	return if mission then mission.kind else nil
end

function Store.missionResult(): MissionResult?
	local snap = snapshot
	if snap and type(snap.missionResult) == "table" then
		return snap.missionResult
	end
	return nil
end

-- Mission select cards (empty until the first Snapshot arrives).
function Store.missionCards(): { MissionCard }
	local snap = snapshot
	if snap and type(snap.missions) == "table" then
		return snap.missions
	end
	return {}
end

function Store.getProgress(): Progress
	return progress
end

function Store.setProgress(value: Progress)
	local completed: { [string]: boolean } = {}
	local collectibles: { [string]: boolean } = {}
	local cosmetics: { [string]: boolean } = {}
	local raw: any = value
	if type(raw.cosmetics) == "table" then
		for id, owned in raw.cosmetics do
			if type(id) == "string" and owned == true then
				cosmetics[id] = true
			end
		end
	end
	if type(value.completed) == "table" then
		for id, done in value.completed do
			if type(id) == "string" and done == true then
				completed[id] = true
			end
		end
	end
	if type(value.collectibles) == "table" then
		for id, found in value.collectibles do
			if type(id) == "string" and found == true then
				collectibles[id] = true
			end
		end
	end
	progress = { completed = completed, collectibles = collectibles, cosmetics = cosmetics }
	progressReceived = true
	emit("progress")
end

-- True once the server has sent this player's saved Progress.
function Store.hasProgress(): boolean
	return progressReceived
end

-- Number of missions this player has completed (0 for a new player).
function Store.completedCount(): number
	local count = 0
	for _ in progress.completed do
		count += 1
	end
	return count
end

-- Event cosmetics unlocked with a code (e.g. "explorer26"), from the saved Progress.
function Store.hasCosmetic(id: string): boolean
	local cosmetics: any = (progress :: any).cosmetics
	return type(cosmetics) == "table" and cosmetics[id] == true
end

function Store.cosmeticIds(): { string }
	local ids: { string } = {}
	local cosmetics: any = (progress :: any).cosmetics
	if type(cosmetics) == "table" then
		for id, owned in cosmetics do
			if type(id) == "string" and owned == true then
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids
end

-- Stage 6: build and grow the base --------------------------------------------------------------

-- What a player wears before choosing anything (Types.Equipped contract).
Store.EQUIPPED_DEFAULTS = table.freeze({
	helmet = "standard",
	backpack = "standard",
	carl = "classic",
	pet = "none",
} :: { [string]: string })

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

local function levelMap(value: any): { [string]: number }
	local result: { [string]: number } = {}
	if type(value) == "table" then
		for id, level in value do
			if type(id) == "string" and type(level) == "number" then
				result[id] = level
			end
		end
	end
	return result
end

local function equippedFrom(value: any): Equipped
	local result: { [string]: string } = table.clone(Store.EQUIPPED_DEFAULTS :: any)
	if type(value) == "table" then
		for slot in Store.EQUIPPED_DEFAULTS do
			if type(value[slot]) == "string" then
				result[slot] = value[slot]
			end
		end
	end
	return {
		helmet = result.helmet,
		backpack = result.backpack,
		carl = result.carl,
		pet = result.pet,
	}
end

-- Latest BaseState from the server (nil until it arrives, or with an older server).
function Store.getBase(): BaseState?
	return base
end

-- Store a BaseState from the server. Fields are checked so a partial table never breaks the UI.
function Store.setBase(value: BaseState)
	local raw: any = value
	if type(raw) ~= "table" then
		return
	end
	local pets: { [string]: boolean } = {}
	if type(raw.pets) == "table" then
		for id, owned in raw.pets do
			if type(id) == "string" and owned == true then
				pets[id] = true
			end
		end
	end
	local inProgress: { [string]: BuildProgress } = {}
	if type(raw.inProgress) == "table" then
		for id, entry in raw.inProgress do
			if type(id) == "string" and type(entry) == "table" and type(entry.stages) == "number" then
				inProgress[id] = {
					level = math.max(1, numberOr(entry.level, 1)),
					stage = math.max(0, numberOr(entry.stage, 0)),
					stages = math.max(1, entry.stages),
					crate = entry.crate == true,
				}
			end
		end
	end
	local scanned: { [string]: boolean } = {}
	if type(raw.scanned) == "table" then
		for id, done in raw.scanned do
			if type(id) == "string" and done == true then
				scanned[id] = true
			end
		end
	end
	local gearOn: { [string]: boolean } = {}
	if type(raw.gearOn) == "table" then
		for id, on in raw.gearOn do
			if type(id) == "string" and type(on) == "boolean" then
				gearOn[id] = on
			end
		end
	end
	quest = Store.parseQuest(raw.quest)
	local xp = numberOr(raw.xp, 0)
	base = {
		credits = numberOr(raw.credits, 0),
		xp = xp,
		level = math.max(1, numberOr(raw.level, 1)),
		levelXp = numberOr(raw.levelXp, 0),
		nextLevelXp = if type(raw.nextLevelXp) == "number" then raw.nextLevelXp else nil,
		skillPoints = numberOr(raw.skillPoints, 0),
		builds = levelMap(raw.builds),
		ownBuilds = levelMap(raw.ownBuilds),
		skills = levelMap(raw.skills),
		pets = pets,
		equipped = equippedFrom(raw.equipped),
		siloIce = numberOr(raw.siloIce, 0),
		siloMax = numberOr(raw.siloMax, 0),
		icePerMinute = numberOr(raw.icePerMinute, 0),
		inProgress = inProgress,
		carryingCrate = raw.carryingCrate == true,
		tools = levelMap(raw.tools),
		foodReadyAt = if type(raw.foodReadyAt) == "number" then raw.foodReadyAt else nil,
		scanned = scanned,
		gear = levelMap(raw.gear), -- Stage 8
		gearOn = gearOn,
	}
	emit("base")
end

-- Stage 9: the active quest from a BaseState (nil when the server sends none). Checked field by
-- field so a partial table never breaks the UI.
function Store.parseQuest(value: any): QuestView?
	if type(value) ~= "table" then
		return nil
	end
	local steps: { QuestStepView } = {}
	if type(value.steps) == "table" then
		for index = 1, #value.steps do
			local step = value.steps[index]
			if type(step) == "table" and type(step.key) == "string" then
				local target = math.max(1, numberOr(step.target, 1))
				table.insert(steps, {
					key = step.key,
					progress = math.clamp(numberOr(step.progress, 0), 0, target),
					target = target,
					done = step.done == true,
				})
			end
		end
	end
	return {
		id = if type(value.id) == "string" and value.id ~= "" then value.id else nil,
		kind = if value.kind == "side" then "side" else "main",
		stepIndex = math.max(1, numberOr(value.stepIndex, 1)),
		steps = steps,
		mainDone = value.mainDone == true,
	}
end

-- Stage 9: the player's active quest (nil until a BaseState with a quest arrives).
function Store.quest(): QuestView?
	return quest
end

-- What this player wears (defaults until a BaseState arrives).
function Store.equipped(): Equipped
	local state = base
	if state then
		return state.equipped
	end
	return equippedFrom(nil)
end

-- Effective level of a build standing in this server (0 = not built, or no BaseState yet).
function Store.buildLevel(id: string): number
	local state = base
	if state then
		return state.builds[id] or 0
	end
	return 0
end

-- Stage 7: a build being built in steps (nil when none is in progress).
function Store.buildProgress(id: string): BuildProgress?
	local state = base
	if state then
		return state.inProgress[id]
	end
	return nil
end

-- Stage 7: this player carries a parts crate from the lander.
function Store.carryingCrate(): boolean
	local state = base
	return state ~= nil and state.carryingCrate
end

-- Stage 7: level of a tool this player can carry (0 = not unlocked yet, or no BaseState yet).
function Store.toolLevel(id: string): number
	local state = base
	if state then
		return state.tools[id] or 0
	end
	return 0
end

-- Stage 7: this player already scanned an exploration site ("poi:<id>" keys; a bare id also counts).
function Store.isScanned(id: string): boolean
	local state = base
	if state == nil then
		return false
	end
	return state.scanned["poi:" .. id] == true or state.scanned[id] == true
end

-- Stage 7: the last exploration scan the server reported (ExploreCard shows it).
function Store.lastExplore(): ExploreEvent?
	return lastExplore
end

function Store.setExplore(value: ExploreEvent)
	lastExplore = value
	emit("explore")
end

-- The builds every mission needs (habitat, solar, greenhouse, antenna, shelter) all stand.
Store.CORE_BUILDS = table.freeze({ "habitat", "solar", "greenhouse", "antenna", "shelter" })
function Store.coreBuilt(): boolean
	if base == nil then
		return true -- older server: the base is already complete
	end
	for _, id in Store.CORE_BUILDS do
		if Store.buildLevel(id) < 1 then
			return false
		end
	end
	return true
end

-- Screen mode: the mission select can be closed in Briefing to explore and build ("base mode").
function Store.isMissionSelectOpen(): boolean
	return missionSelectOpen
end

function Store.setMissionSelectOpen(open: boolean)
	if missionSelectOpen == open then
		return
	end
	missionSelectOpen = open
	emit("view")
end

-- Briefing with the mission select closed: the player roams the base, builds and gathers ice.
function Store.isBaseMode(): boolean
	return Store.phase() == "Briefing" and not missionSelectOpen
end

-- Stage 9: save slots ("worlds") and the start menu ------------------------------------------

Store.SLOT_COUNT = 3 -- contract with ProgressService: slots 1..3
Store.SLOT_CHOSEN_ATTRIBUTE = "SBO_SlotChosen" -- player attribute, true once a slot is loaded

local function slotFrom(value: any): SlotInfo
	if type(value) ~= "table" then
		return { used = false, habitat = 0, level = 1, credits = 0, savedAt = nil, mode = "solo" }
	end
	return {
		used = value.used == true,
		habitat = math.max(0, math.floor(numberOr(value.habitat, 0))),
		level = math.max(1, math.floor(numberOr(value.level, 1))),
		credits = math.max(0, math.floor(numberOr(value.credits, 0))),
		savedAt = if type(value.savedAt) == "number" and value.savedAt > 0 then value.savedAt else nil,
		mode = if value.mode == "friends" then "friends" else "solo",
	}
end

-- Store the meta table from the "Slots" remote. A sparse table can arrive with string keys
-- ("2"), so both spellings are read.
function Store.setSlots(value: any)
	if type(value) ~= "table" then
		return
	end
	local raw: any = if type(value.slots) == "table" then value.slots else {}
	local slots: { SlotInfo } = {}
	for index = 1, Store.SLOT_COUNT do
		local entry = raw[index]
		if entry == nil then
			entry = raw[tostring(index)]
		end
		slots[index] = slotFrom(entry)
	end
	local last = tonumber(value.last)
	if last ~= nil and (last ~= math.floor(last) or last < 1 or last > Store.SLOT_COUNT) then
		last = nil
	end
	-- Stage 10: offline is kept so the start menu never says "saves by itself" when it cannot.
	slotsMeta = { slots = slots, last = last, offline = if value.offline == true then true else nil }
	-- Stage 11 menu: the player's saved settings travel with the slot list.
	if type(value.settings) == "table" then
		Store.applyServerSettings(value.settings)
	end
	emit("slots")
end

-- The slot list (nil until the server sends it).
function Store.getSlots(): SlotsMeta?
	return slotsMeta
end

function Store.slotInfo(slot: number): SlotInfo?
	local meta = slotsMeta
	return if meta then meta.slots[slot] else nil
end

-- The slot "Continue" loads: the last one used, if it still holds a world.
function Store.continueSlot(): number?
	local meta = slotsMeta
	if meta == nil then
		return nil
	end
	local last = meta.last
	if last and meta.slots[last] and meta.slots[last].used then
		return last
	end
	return nil
end

-- True once the server has loaded a slot for this player (the start menu then closes).
function Store.isSlotChosen(): boolean
	local player = game:GetService("Players").LocalPlayer
	return player ~= nil and player:GetAttribute(Store.SLOT_CHOSEN_ATTRIBUTE) == true
end

-- Ask the server to load a slot. fresh = New Game in that slot (the server wipes it).
-- Stage 10 fix: from the lobby both modes teleport the player to their own world server.
function Store.chooseSlot(slot: number, mode: SlotMode, fresh: boolean)
	local action: any = { type = "ChooseSlot", slot = slot, mode = mode, fresh = fresh }
	Store.send(action)
end

-- Stage 10 fix: private worlds, "Join a friend" -------------------------------------------------

-- The list as the start menu shows it. status "loading" until the server answers (or
-- FRIEND_WORLDS_TIMEOUT passes: "error"); here = this server is not a lobby (Studio), so no list.
export type FriendWorld = Types.FriendWorld
export type FriendWorldsStatus = "loading" | "ready" | "error"
export type FriendWorldsView = {
	status: FriendWorldsStatus,
	worlds: { FriendWorld },
	here: boolean,
}

local FRIEND_WORLDS_TIMEOUT = 12 -- seconds without an answer before the list says "try again"
local friendWorlds: FriendWorldsView? = nil
local friendWorldsToken = 0
local friendWorldsConnected = false
local friendWorldsListeners: { () -> () } = {}

local function emitFriendWorlds()
	for _, listener in friendWorldsListeners do
		task.spawn(listener)
	end
end

local function setFriendWorlds(value: any)
	if type(value) ~= "table" then
		return
	end
	friendWorldsToken += 1
	friendWorlds = {
		status = if value.ok == false then "error" else "ready",
		worlds = Worlds.sanitizeViews(value.worlds, MissionData.MISSION.PLAYERS_MAX, Worlds.LIST_LIMIT),
		here = value.here == true,
	}
	emitFriendWorlds()
end

-- Remotes.WORLDS is connected the first time the list is asked for (the start menu owns this screen).
local function connectFriendWorlds()
	if friendWorldsConnected then
		return
	end
	friendWorldsConnected = true
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER, 10)
		local remote = if folder then folder:WaitForChild(Types.Remotes.WORLDS, 10) else nil
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(setFriendWorlds)
		else
			warn("[SpaceBaseOdyssey] no Worlds remote: the Join a friend list stays empty")
		end
	end)
end

-- The latest "Join a friend" list (nil before the first request).
function Store.friendWorlds(): FriendWorldsView?
	return friendWorlds
end

-- Called whenever the "Join a friend" list changes (loading, an answer, a timeout).
function Store.onFriendWorlds(listener: () -> ())
	table.insert(friendWorldsListeners, listener)
end

-- Ask the server for the open worlds of this player's Roblox friends (the server rate-limits it).
function Store.requestFriendWorlds()
	connectFriendWorlds()
	friendWorldsToken += 1
	local token = friendWorldsToken
	local previous = friendWorlds
	friendWorlds = { status = "loading", worlds = if previous then previous.worlds else {}, here = false }
	emitFriendWorlds()
	local action: any = { type = "ListFriendWorlds" }
	Store.send(action)
	task.delay(FRIEND_WORLDS_TIMEOUT, function()
		local current = friendWorlds
		if token == friendWorldsToken and current and current.status == "loading" then
			current.status = "error"
			emitFriendWorlds()
		end
	end)
end

-- Join a friend's open world with one of this player's own slots (their explorer progress comes
-- along; the server checks the friendship and the room).
function Store.joinWorld(owner: number, slot: number)
	local action: any = { type = "JoinWorld", owner = owner, slot = slot }
	Store.send(action)
end

-- Local settings ------------------------------------------------------------------------------

function Store.getSetting(name: SettingName): number | boolean
	return settings[name]
end

function Store.settingOn(name: SettingName): boolean
	return settings[name] == true
end

function Store.settingNumber(name: SettingName): number
	local value = settings[name]
	return if type(value) == "number" then value else 0
end

-- Stage 11 menu: saving on the server -----------------------------------------------------------
-- A change is sent SAVE_DEBOUNCE seconds after the last one (a slider drag sends once; the server
-- takes at most 5 a second). For LOCAL_WINS_SECONDS after a change the server's older copy (an
-- attribute, the slot list) cannot undo it; after that, a field the server still has wrong is sent
-- again (at most SAVE_RETRIES times).
local SAVE_DEBOUNCE = 0.6
local LOCAL_WINS_SECONDS = 6
local SAVE_RETRIES = 2
local LANGUAGE_ATTRIBUTE = "Language"
local pendingSave: { [string]: any } = {} -- fields waiting for the debounce
local changedAt: { [string]: number } = {} -- os.clock() of the last local change per field ("language" too)
local saveToken = 0
local syncStarted = false

local function serverValue(name: string): any
	local player = game:GetService("Players").LocalPlayer
	if player == nil then
		return nil
	end
	if name == "language" then
		return player:GetAttribute(LANGUAGE_ATTRIBUTE)
	end
	local attribute = Store.SETTING_ATTRIBUTES[name]
	return if attribute then player:GetAttribute(attribute) else nil
end

local function localValue(name: string): any
	return if name == "language" then language else settings[name]
end

-- Equal, or numbers within the server's rounding (volumes are kept in steps of 0.01).
local function sameValue(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 0.005
	end
	return a == b
end

local flushSave: (attempt: number) -> ()
flushSave = function(attempt: number)
	if next(pendingSave) == nil then
		return
	end
	if actionRemote == nil then
		task.delay(1, flushSave, attempt) -- the remote is not there yet
		return
	end
	local patch = pendingSave
	pendingSave = {}
	local action: any = { type = "SaveSettings", settings = patch }
	Store.send(action)
	-- Check later that the server took it (its attributes follow); resend what it still has wrong.
	task.delay(LOCAL_WINS_SECONDS * 0.5, function()
		if attempt >= SAVE_RETRIES then
			return
		end
		local again = false
		for name in patch do
			local server = serverValue(name)
			-- nil = an older server without settings: nothing to retry.
			if server ~= nil and not sameValue(server, localValue(name)) and pendingSave[name] == nil then
				pendingSave[name] = localValue(name)
				again = true
			end
		end
		if again then
			flushSave(attempt + 1)
		end
	end)
end

local function queueSave(name: string, value: any)
	changedAt[name] = os.clock()
	pendingSave[name] = value
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DEBOUNCE, function()
		if token == saveToken then
			flushSave(0)
		end
	end)
end

-- A local change: shown at once and saved on the server (debounced).
function Store.setSetting(name: SettingName, value: number | boolean)
	if settings[name] == value then
		return
	end
	settings[name] = value
	queueSave(name, value)
	emit("settings")
end

-- Stage 11 menu: the player picked a language in Settings. Shown at once; SetLanguage saves it on
-- the server (MissionService and ProgressService both read it).
function Store.chooseLanguage(value: Language)
	if value ~= "en" and value ~= "es" then
		return
	end
	changedAt.language = os.clock()
	if language ~= value then
		Store.setLanguage(value)
	end
	Store.send({ type = "SetLanguage", language = value })
end

local function recentlyChanged(name: string): boolean
	local at = changedAt[name]
	return pendingSave[name] ~= nil or (at ~= nil and os.clock() - at < LOCAL_WINS_SECONDS)
end

-- Settings the server sent (SlotsMeta.settings, TeleportData.prefs or the attributes): a field
-- replaces the local value unless the player changed it in the last few seconds. Bad values are
-- ignored (the same ServerGuard rules as the server).
function Store.applyServerSettings(raw: any)
	if type(raw) ~= "table" then
		return
	end
	-- Only the fields the server actually sent (a missing field must not reset a local choice).
	local present: { [string]: boolean } = {}
	for _, name in ServerGuard.SETTING_NAMES do
		if raw[name] ~= nil then
			present[name] = true
		end
	end
	local clean: any = ServerGuard.applySettings(ServerGuard.defaultSettings(), raw)
	local changed = false
	for name in Store.SETTING_ATTRIBUTES do
		if present[name] and not recentlyChanged(name) then
			local value = clean[name]
			if type(value) == type(settings[name]) and not sameValue(settings[name], value) then
				settings[name] = value
				changed = true
			end
		end
	end
	local saved = clean.language
	if present.language and saved ~= nil and saved ~= language and not recentlyChanged("language") then
		Store.setLanguage(saved)
	end
	if changed then
		emit("settings")
	end
end

-- The language this player saved, if the trip or the server already says (nil = never chosen:
-- Main.client then follows the device language).
function Store.savedLanguage(): Language?
	local ok, data = pcall(function(): any
		return game:GetService("TeleportService"):GetLocalPlayerTeleportData()
	end)
	local prefs = if ok and type(data) == "table" then data.prefs else nil
	if type(prefs) == "table" and (prefs.language == "en" or prefs.language == "es") then
		return prefs.language
	end
	local attribute = serverValue("language")
	if attribute == "en" or attribute == "es" then
		return attribute
	end
	return nil
end

local function readAttributes()
	local raw: { [string]: any } = {}
	for name in Store.SETTING_ATTRIBUTES do
		local value = serverValue(name)
		if value ~= nil then
			raw[name] = value
		end
	end
	local saved = serverValue("language")
	if saved ~= nil then
		raw.language = saved
	end
	Store.applyServerSettings(raw)
end

-- Read the saved settings (trip prefs, then the server's attributes) and follow later changes.
-- Safe to call more than once.
function Store.loadSettings()
	if syncStarted then
		return
	end
	syncStarted = true
	local player = game:GetService("Players").LocalPlayer
	if not player then
		return
	end
	local ok, data = pcall(function(): any
		return game:GetService("TeleportService"):GetLocalPlayerTeleportData()
	end)
	if ok and type(data) == "table" and type(data.prefs) == "table" then
		Store.applyServerSettings(data.prefs)
	end
	readAttributes()
	for _, attribute in Store.SETTING_ATTRIBUTES do
		player:GetAttributeChangedSignal(attribute):Connect(readAttributes)
	end
	player:GetAttributeChangedSignal(LANGUAGE_ATTRIBUTE):Connect(readAttributes)
end

-- Stage 11 menu: accessibility helpers for other modules ------------------------------------------

Store.BIG_TEXT_SCALE = 1.25 -- UI choice: text size with "Big text" on
Store.MESSAGE_SPEEDS = ServerGuard.MESSAGE_SPEEDS -- the "Message time" choices (1 = normal)

-- Text size factor for Ui's text helpers (1 = normal).
function Store.textScale(): number
	return if settings.bigText == true then Store.BIG_TEXT_SCALE else 1
end

-- True: no camera shake and no big tweens (small fades are fine).
function Store.reduceMotion(): boolean
	return settings.reduceMotion == true
end

-- True: add icons or patterns wherever a signal is only a colour.
function Store.colourHelper(): boolean
	return settings.colourHelper == true
end

-- How many times longer C.A.R.L.'s bubbles stay (1, 1.5 or 2).
function Store.messageFactor(): number
	local value = settings.messageSpeed
	return if type(value) == "number" and value >= 1 then value else 1
end

-- The shortest time a C.A.R.L. line stays (Reading.MIN_SECONDS; read once, 4 if that module is missing).
local readingMinimum = 4
do
	local ok, minimum = pcall(function(): any
		local module = Shared:FindFirstChild("Reading")
		return if module and module:IsA("ModuleScript") then (require :: any)(module).MIN_SECONDS else nil
	end)
	if ok and type(minimum) == "number" and minimum > 0 then
		readingMinimum = minimum
	end
end

-- Message time. With `seconds`: that time at the chosen speed. Without (Messages.luau calls it so):
-- the shortest time a line stays at the chosen speed, or nil at normal speed (no change).
function Store.messageSeconds(seconds: number?): number?
	local factor = Store.messageFactor()
	if seconds ~= nil then
		return seconds * factor
	end
	return if factor > 1 then readingMinimum * factor else nil
end

-- Stage 11 menu: the start menu is open (it hides the HUD; C.A.R.L. waits) -------------------------

local menuOpen = false
local menuListeners: { (open: boolean) -> () } = {}

function Store.isMenuOpen(): boolean
	return menuOpen
end

function Store.setMenuOpen(open: boolean)
	if menuOpen == open then
		return
	end
	menuOpen = open
	for _, listener in menuListeners do
		task.spawn(listener, open)
	end
end

function Store.onMenuChanged(listener: (open: boolean) -> ())
	table.insert(menuListeners, listener)
end

-- Water and data waiting (Stage 5 Snapshot fields; 0 with an older server).
function Store.water(): (number, number)
	local snap: any = snapshot
	local water = if snap and type(snap.water) == "number" then snap.water else 0
	local waterMax = if snap and type(snap.waterMax) == "number" and snap.waterMax > 0 then snap.waterMax else 0
	return water, waterMax
end

function Store.pendingScience(): number
	local snap: any = snapshot
	return if snap and type(snap.pendingScience) == "number" then snap.pendingScience else 0
end

function Store.hasCollectible(id: string): boolean
	return progress.collectibles[id] == true
end

function Store.collectibleCount(): number
	local count = 0
	for _, id in Store.COLLECTIBLES do
		if progress.collectibles[id] then
			count += 1
		end
	end
	return count
end

function Store.allCollectibles(): boolean
	return Store.collectibleCount() >= #Store.COLLECTIBLES
end

-- Storm stage of the current shift, from server time: "warning" between the flare and the arrival
-- of particles, "storm" while particles are here. A false-alarm flare never reaches "storm".
function Store.stormStage(): StormStage
	local snap = snapshot
	if not snap or snap.phase ~= "Shift" or not snap.shift then
		return "none"
	end
	local shift = snap.shift
	local now = workspace:GetServerTimeNow()
	local warningAt = shift.stormWarningAt
	local arrivesAt = shift.stormArrivesAt
	local endsAt = shift.stormEndsAt
	if warningAt ~= nil and arrivesAt ~= nil and now >= warningAt and now < arrivesAt then
		return "warning"
	end
	local particlesExpected = not (snap.spaceWeather ~= nil and snap.spaceWeather.particles == false)
	if particlesExpected and arrivesAt ~= nil and endsAt ~= nil and now >= arrivesAt and now < endsAt then
		return "storm"
	end
	return "none"
end

-- A guidance marker Part built by the server in Workspace.Base.Markers (nil until it exists).
function Store.findMarker(name: string): BasePart?
	local base = workspace:FindFirstChild("Base")
	local folder = if base then base:FindFirstChild("Markers") else nil
	local marker = if folder then folder:FindFirstChild(name) else nil
	if marker and marker:IsA("BasePart") then
		return marker
	end
	return nil
end

return Store
