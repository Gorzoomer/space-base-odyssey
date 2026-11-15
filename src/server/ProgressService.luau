--!strict
-- Space Base Odyssey - saved progress per player: completed missions, the four hidden collectibles
-- and event cosmetics from redeem codes.
-- Stage 9 (team feedback): every player has THREE SAVE SLOTS, picked on the start menu ("Continue /
-- New Game"). Until a slot is chosen and loaded the player has no character (Main.server waits for
-- ProgressService.onLoaded) and nothing is saved for them. Keys in the DataStore "SBO_Progress_v1":
--   "p_<userId>_s<slot>"  one slot: the record below (completed, collectibles, cosmetics, base)
--   "p_<userId>_meta"     { slots = { [1..3] = { used, habitat, level, credits, savedAt, mode } },
--                           last = slot, cosmetics } (the start menu reads it; cosmetics are account-wide)
--   "u_<userId>"          the save from before slots: it is never deleted and becomes slot 1 (the
--                         first meta lists it as slot 1; loading slot 1 with no slot key reads it).
-- ChooseSlot { slot 1-3, mode "solo" | "friends", fresh } (fresh = New Game: the slot is wiped):
--   solo, in a public server outside Studio: the player is teleported to a new reserved server with
--     TeleportData { slot, mode = "solo", fresh }; there the slot is chosen at once (no menu). If the
--     teleport fails, the slot loads in this server instead.
--   friends (or solo in Studio, a reserved or a private server): the slot loads in this server; friends
--     join with Roblox's Join button and builds stay shared (the highest of present players).
-- Player attributes: SBO_SlotLoading = true while a slot is on its way (teleport or load),
-- SBO_SlotChosen = true and SBO_Slot = n once it is loaded. Remotes.SLOTS sends Types.SlotsMeta.
-- When DataStores are not available (Studio, an unpublished place, or no API access) every slot lives
-- in memory for this server session. Studio uses memory unless workspace attribute
-- SBO_StudioDataStores = true, so debug credits never reach real saves.
-- A save only ever adds: it merges with what is already stored, so nothing is lost if two servers save
-- the same slot. Exceptions: New Game (fresh) and DebugResetBase replace instead of merging.
--
-- Collectibles and their rewards (team decision; each reward is a visual surprise, never a gameplay
-- advantage, so the mission stays fair for every player):
--   mini_earth  -> C.A.R.L. "Earth skin" (client side, the player's own drone)
--   laika       -> the suit backpack turns magenta (SuitService, seen by everyone)
--   cheese      -> the science rover gets a cheese-yellow paint job (world, if any present player owns it)
--   mars_potato -> a team flag on the habitat roof (world, if any present player owns it)
--   all four    -> the hidden Observatory opens for that player (client side)
-- Cosmetics (Progress.cosmetics) come from redeem codes (src/server/Codes.luau, server only):
--   explorer26  -> gold visor and gold suit bands (SuitService)
-- Stage 6 adds the build-and-grow data (Record.base, saved under "base"): credits, XP, the player's
-- own builds, skills, bought pets and what they wear (equipped). BaseService owns the rules and
-- changes it through ProgressService.updateBase. Credits and equipped are saved as they are (they
-- can go down); XP, builds and skills only grow between saves unless the player reset their base.
-- Old saves without "base" start with MissionData.BASE.START_CREDITS.
-- Stage 7 adds base.tools (tool upgrade levels bought at the Lab, e.g. drill = 1..3) and base.scanned
-- (exploration sites scanned with the tablet, keys like "poi:old_lander"). Both only grow between
-- saves. Migration of Stage 6 saves: a save with any build but no habitat gets habitat = 1 (the
-- habitat became a build in Stage 7, nobody loses their base); the removed "drill" skill becomes
-- drill tool level skill + 1 (its skill points come back too, because spent points are counted).
-- Stage 8 adds base.gear (air boots / jetpack levels bought at the Lab, only grow between saves) and
-- base.gearOn (which owned gear is switched on; saved as it is). Migration of Stage 7 saves: the
-- removed "jump" skill becomes air boots at that level (at most the boots' maxLevel), switched on, for
-- free; the jump levels drop out of the skills, so their skill points come back.
-- Stage 9 adds base.quest (QuestService's own table, saved as it is; plain numbers, booleans, short
-- strings and tables only). Migration of saves from before Stage 9: the habitat (the base level) rises
-- to what the structures already built need under the habitat tree (BaseBuild.habitatForBuilds), so
-- nothing built before stops being valid. Skills already learned stay even if the longer level table
-- shows a lower level now.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Missions = require(Shared:WaitForChild("Missions"))
local Types = require(Shared:WaitForChild("Types"))

local Codes = require(script.Parent:WaitForChild("Codes"))

-- QuestService's pure record helpers (sanitizeRecord, mergeRecord) for base.quest. Optional: without
-- the module, base.quest is kept as plain data.
local questRecords: any = nil
do
	local module = script.Parent:FindFirstChild("QuestService")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		if ok and type(result) == "table" and type(result.sanitizeRecord) == "function" and type(result.mergeRecord) == "function" then
			questRecords = result
		else
			warn(`[SpaceBaseOdyssey] QuestService record helpers unavailable: {if ok then "missing" else result}`)
		end
	end
end

type Progress = Types.Progress
type SlotMode = Types.SlotMode
-- One row of the start menu (Types.SlotInfo with every field filled).
type SlotSummary = {
	used: boolean,
	habitat: number,
	level: number,
	credits: number,
	savedAt: number,
	mode: SlotMode,
}

export type Remotes = {
	progress: RemoteEvent,
	collected: RemoteEvent,
	message: RemoteEvent,
	action: RemoteEvent?, -- Stage 9: ChooseSlot / RequestSlots arrive here (MissionService ignores them)
	slots: RemoteEvent?, -- Stage 9: Types.SlotsMeta to one client
}

-- Stage 6 build-and-grow data of one player. equipped nil = never chosen (an old save, or a new
-- player): BaseService fills it from what the player owns when they join.
export type BaseRecord = {
	credits: number,
	xp: number,
	builds: { [string]: number }, -- this player's own build levels
	skills: { [string]: number },
	pets: { [string]: boolean }, -- bought pets (pets from collectibles come from Progress.collectibles)
	equipped: Types.Equipped?,
	tools: { [string]: number }, -- Stage 7: tool upgrade levels (ids of MissionData.BASE.TOOL_UPGRADES)
	scanned: { [string]: boolean }, -- Stage 7: scanned exploration keys ("poi:<id>")
	gear: { [string]: number }, -- Stage 8: gear levels (ids of MissionData.BASE.GEAR; missing = not owned)
	gearOn: { [string]: boolean }, -- Stage 8: owned gear switched on (true) or off (false)
	-- Stage 9: QuestService's table (for example { index, progress = { [step] = n }, sideDone = {} }).
	-- nil = no quest started. Kept as it is (numbers, booleans, short strings, tables; 4 levels deep).
	quest: { [any]: any }?,
}

-- What the start menu shows about this player's slots (meta key), plus account-wide cosmetics.
type Meta = {
	slots: { SlotSummary },
	last: number?,
	cosmetics: { [string]: boolean },
}

type SlotState = "menu" | "teleporting" | "loading" | "loaded"

type Choice = {
	slot: number,
	mode: SlotMode,
	fresh: boolean,
}

type Record = {
	completed: { [string]: boolean },
	collectibles: { [string]: boolean },
	cosmetics: { [string]: boolean },
	base: BaseRecord,
	loaded: boolean, -- the chosen slot was read (or could not be, and the defaults are kept)
	state: SlotState,
	slot: number?, -- the chosen slot (nil on the start menu or while teleporting)
	mode: SlotMode?,
	pendingChoice: Choice?, -- chosen before the meta was read (or from TeleportData)
	teleportChoice: Choice?,
	teleportToken: number,
	replaceAll: boolean, -- New Game in this slot: the next save replaces it, never merges
	baseReset: boolean, -- DebugResetBase since the last save: the next save replaces the base
	canSave: boolean, -- false until the stored slot was read (never overwrite what we could not read)
	dirty: boolean,
	saveScheduled: boolean,
	lastSaveAt: number,
	meta: Meta,
	metaReady: boolean, -- the meta key was read (or could not be)
	metaCanSave: boolean, -- false when the meta (or the old save) could not be read
	metaDirty: boolean,
	metaSaveScheduled: boolean,
	metaLastSaveAt: number,
	lastSlotsRequestAt: number,
	lastPickup: { [string]: number }, -- os.clock() of the last pickup per collectible (debounce)
	lastRedeemAt: number, -- os.clock() of the last redeem attempt (rate limit)
	connections: { RBXScriptConnection },
}

-- Where records are read and written: a DataStore, or memory for this server session.
type Backend = {
	persistent: boolean,
	get: (key: string) -> any, -- errors when the read fails
	update: (key: string, transform: (old: any) -> any) -> (), -- errors when the write fails
}

-- Technical settings (not gameplay numbers).
local STORE_NAME = "SBO_Progress_v1"
local LEGACY_KEY_PREFIX = "u_" -- the one save from before slots
local KEY_PREFIX = "p_"
local LEGACY_SLOT = 1 -- the old save becomes this slot
local SLOT_COUNT = 3
local DATA_VERSION = 5 -- 2 = Stage 6 "base", 3 = Stage 7, 4 = Stage 8 gear, 5 = Stage 9 slots, quest, habitat tree
local HABITAT_TREE_VERSION = 5 -- saves older than this get the habitat migration
local STUDIO_DATASTORE_ATTRIBUTE = "SBO_StudioDataStores" -- workspace attribute: real saves in Studio
local MAX_STORED_NUMBER = 1e9 -- credits and XP are clamped to this when read from storage
local MAX_STORED_TIME = 1e11 -- os.time() values (savedAt)
local SAVE_INTERVAL_SECONDS = 10 -- DataStores allow one write per key about every 6 seconds
local META_SAVE_INTERVAL_SECONDS = 60 -- the start menu summary is saved less often
local AUTOSAVE_CHECK_SECONDS = 60 -- safety net: anything still unsaved is scheduled again
local BUDGET_WAIT_SECONDS = 5 -- wait at most this for DataStore write budget before trying later
local LOAD_ATTEMPTS = 3
local LOAD_RETRY_SECONDS = 2
local CLOSE_BUDGET_SECONDS = 25 -- BindToClose has about 30 seconds
local TELEPORT_TIMEOUT_SECONDS = 30 -- still here after this: the solo trip failed, load here
local SLOTS_REQUEST_INTERVAL = 1 -- RequestSlots rate limit per player
local PICKUP_DEBOUNCE_SECONDS = 1
local PICKUP_EXTRA_RANGE = 8 -- studs beyond the prompt's own range (lag), checked on the server
local MAX_SCANNED_KEYS = 200 -- damaged saves cannot grow without limit
local MAX_SCANNED_KEY_LENGTH = 48
local MAX_DATA_DEPTH = 4 -- base.quest nesting
local MAX_DATA_KEYS = 128 -- entries per table inside base.quest
local MAX_DATA_STRING = 64
local MAX_DATA_INDEX = 9999

local ProgressService = {}

local started = false
local remotes: Remotes? = nil
local world: any = nil
local records: { [Player]: Record } = {}
local listeners: { () -> () } = {}
local loadedListeners: { (Player) -> () } = {}
local collectibleListeners: { (Player, string, boolean) -> () } = {}
local cosmeticListeners: { (Player, string) -> () } = {}
local appliedPaint: string? = nil
local appliedFlag: boolean? = nil
local savesInFlight = 0

----------------------------------------------------------------------------------------------------
-- Storage backends

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local memoryData: { [string]: any } = {}

local memoryBackend: Backend = {
	persistent = false,
	get = function(key: string): any
		return deepCopy(memoryData[key])
	end,
	update = function(key: string, transform: (old: any) -> any)
		local new = transform(deepCopy(memoryData[key]))
		if new ~= nil then
			memoryData[key] = deepCopy(new)
		end
	end,
}

local function dataStoreBackend(dataStore: DataStore): Backend
	return {
		persistent = true,
		get = function(key: string): any
			return dataStore:GetAsync(key)
		end,
		update = function(key: string, transform: (old: any) -> any)
			dataStore:UpdateAsync(key, function(old: any): any
				return transform(old)
			end)
		end,
	}
end

local backend: Backend = memoryBackend

-- Reads one key, with retries. Returns false when it could not be read. Studio without API access or
-- an unpublished place: DataStores are off for this session and memory is used from now on.
local function readKey(key: string, who: string): (boolean, any)
	for attempt = 1, LOAD_ATTEMPTS do
		local source = backend
		local ok, data = pcall(source.get, key)
		if ok then
			return true, data
		end
		warn(`[SpaceBaseOdyssey] progress load attempt {attempt} failed for {who}: {data}`)
		local message = tostring(data)
		if source.persistent and (string.find(message, "Studio", 1, true) or string.find(message, "publish", 1, true)) then
			backend = memoryBackend
			warn("[SpaceBaseOdyssey] DataStores unavailable, progress kept in memory for this session")
			return true, memoryBackend.get(key)
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_SECONDS)
		end
	end
	return false, nil
end

-- Waits (at most `seconds`) until a DataStore write is allowed. Memory never waits.
local function waitForBudget(seconds: number): boolean
	if not backend.persistent then
		return true
	end
	local deadline = os.clock() + seconds
	while true do
		local ok, budget = pcall(function(): number
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end)
		if not ok or (budget :: number) >= 1 then
			return true
		end
		if os.clock() >= deadline then
			return false
		end
		task.wait(1)
	end
end

----------------------------------------------------------------------------------------------------
-- Helpers

local function slotKey(player: Player, slot: number): string
	return `{KEY_PREFIX}{player.UserId}_s{slot}`
end

local function metaKey(player: Player): string
	return `{KEY_PREFIX}{player.UserId}_meta`
end

local function legacyKey(player: Player): string
	return LEGACY_KEY_PREFIX .. tostring(player.UserId)
end

local function isSlot(value: any): boolean
	return type(value) == "number" and value == math.floor(value) and value >= 1 and value <= SLOT_COUNT
end

local function isMissionId(id: any): boolean
	return type(id) == "string" and Missions.get(id) ~= nil
end

-- Keeps only known ids set to true. Accepts anything (stored data may be old or damaged).
local function sanitizeSet(value: any, isValid: (any) -> boolean): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if type(value) == "table" then
		for id, flag in value do
			if flag == true and isValid(id) then
				result[id :: string] = true
			end
		end
	end
	return result
end

local function union(into: { [string]: boolean }, from: { [string]: boolean })
	for id in from do
		into[id] = true
	end
end

-- Every value a wardrobe slot can hold (the first one is the default). Ownership is checked by
-- BaseService; this list only keeps damaged saves out.
local EQUIP_OPTIONS: { [string]: { string } } = {
	helmet = { "standard", "explorer26" },
	backpack = { "standard", "laika" },
	carl = { "classic", "earth" },
	pet = { "none" },
}
for _, def in MissionData.BASE.PETS do
	table.insert(EQUIP_OPTIONS.pet, def.id)
end
local EQUIP_SLOTS = { "helmet", "backpack", "carl", "pet" }

local function defaultEquipped(): Types.Equipped
	return { helmet = "standard", backpack = "standard", carl = "classic", pet = "none" }
end

local function defaultBase(): BaseRecord
	return {
		credits = MissionData.BASE.START_CREDITS,
		xp = 0,
		builds = {},
		skills = {},
		pets = {},
		equipped = nil,
		tools = {},
		scanned = {},
		gear = {},
		gearOn = {},
		quest = nil,
	}
end

local function sanitizeNumber(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_STORED_NUMBER)
end

-- True for a list with no gaps (keys 1..#value only); a DataStore stores those as they are.
local function isDenseList(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if type(key) ~= "number" then
			return false
		end
		count += 1
	end
	return count == #value
end

-- Plain data only (QuestService's table): finite numbers, booleans, short strings and tables up to
-- MAX_DATA_DEPTH levels. Lists with no gaps stay lists. Other whole-number keys are stored as strings
-- ("3"), because a DataStore cannot hold a table with gaps or mixed keys, and read back as numbers.
local function cleanData(value: any, depth: number, toStorage: boolean): any
	if toStorage and type(value) == "table" and depth < MAX_DATA_DEPTH and #value <= MAX_DATA_KEYS and isDenseList(value) then
		local list: { any } = {}
		local complete = true
		for i, item in value do
			local cleanItem = cleanData(item, depth + 1, true)
			if cleanItem == nil then
				complete = false -- a gap would appear: store it with string keys below
				break
			end
			list[i] = cleanItem
		end
		if complete then
			return list
		end
	end
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return math.clamp(value, -MAX_STORED_NUMBER, MAX_STORED_NUMBER)
	elseif kind == "boolean" then
		return value
	elseif kind == "string" then
		return if #value <= MAX_DATA_STRING then value else nil
	elseif kind == "table" then
		if depth >= MAX_DATA_DEPTH then
			return nil
		end
		local result: { [any]: any } = {}
		local count = 0
		for key, item in value do
			if count >= MAX_DATA_KEYS then
				break
			end
			local cleanKey: any = nil
			if type(key) == "number" then
				if key == math.floor(key) and key >= 0 and key <= MAX_DATA_INDEX then
					cleanKey = if toStorage then tostring(key) else key
				end
			elseif type(key) == "string" and #key > 0 and #key <= MAX_SCANNED_KEY_LENGTH then
				local asNumber = if string.match(key, "^%d+$") then tonumber(key) else nil
				if not toStorage and asNumber ~= nil and asNumber <= MAX_DATA_INDEX then
					cleanKey = asNumber
				else
					cleanKey = key
				end
			end
			if cleanKey ~= nil then
				local cleanItem = cleanData(item, depth + 1, toStorage)
				if cleanItem ~= nil then
					result[cleanKey] = cleanItem
					count += 1
				end
			end
		end
		return result
	end
	return nil
end

-- base.quest: plain data, then QuestService's own rules when that module is there.
local function sanitizeQuest(value: any): { [any]: any }?
	if type(value) ~= "table" then
		return nil
	end
	local data = cleanData(value, 0, false)
	local helpers = questRecords
	if helpers then
		local ok, record = pcall(helpers.sanitizeRecord, data)
		if ok and type(record) == "table" then
			return record
		end
	end
	return data
end

-- Stored quest + this server's quest (another server may have saved meanwhile). QuestService's rule
-- when it is there (quests never go back); otherwise this server's record wins.
local function mergeQuest(stored: { [any]: any }?, current: { [any]: any }?): { [any]: any }?
	if current == nil then
		return stored -- quests never started here (QuestService off) keep their save
	end
	local helpers = questRecords
	if stored ~= nil and helpers then
		local ok, record = pcall(helpers.mergeRecord, stored, current)
		if ok and type(record) == "table" then
			return record
		end
	end
	return current
end

-- Keeps only known ids with whole levels from 1 to that def's maxLevel.
local function sanitizeLevels(value: any, find: (id: string) -> { maxLevel: number }?): { [string]: number }
	local result: { [string]: number } = {}
	if type(value) == "table" then
		for id, level in value do
			if type(id) == "string" and type(level) == "number" and level == level then
				local def = find(id)
				if def then
					local clamped = math.clamp(math.floor(level), 0, def.maxLevel)
					if clamped > 0 then
						result[id] = clamped
					end
				end
			end
		end
	end
	return result
end

local function findBuild(id: string): { maxLevel: number }?
	return BaseBuild.buildDef(MissionData, id)
end

local function findSkill(id: string): { maxLevel: number }?
	return BaseBuild.skillDef(MissionData, id)
end

local function findToolUpgrade(id: string): { maxLevel: number }?
	return (MissionData.BASE.TOOL_UPGRADES :: any)[id]
end

local function findGear(id: string): { maxLevel: number }?
	return BaseBuild.gearDef(MissionData, id)
end

-- On/off of known gear ids (booleans only).
local function sanitizeGearOn(value: any): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if type(value) == "table" then
		for id, flag in value do
			if type(id) == "string" and type(flag) == "boolean" and findGear(id) ~= nil then
				result[id] = flag
			end
		end
	end
	return result
end

-- A scanned key: short, letters, digits, "_", "-" and ":" only (for example "poi:old_lander").
local function isScannedKey(id: any): boolean
	return type(id) == "string"
		and #id > 0
		and #id <= MAX_SCANNED_KEY_LENGTH
		and string.match(id, "^[%w_:%-]+$") ~= nil
end

local function sanitizeScanned(value: any): { [string]: boolean }
	local result: { [string]: boolean } = {}
	local count = 0
	if type(value) == "table" then
		for id, flag in value do
			if flag == true and isScannedKey(id) and count < MAX_SCANNED_KEYS then
				result[id :: string] = true
				count += 1
			end
		end
	end
	return result
end

local function isBuyablePet(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	local def = BaseBuild.petDef(MissionData, id)
	return def ~= nil and def.collectible == nil and def.cost ~= nil
end

local function sanitizeEquipped(value: any): Types.Equipped?
	if type(value) ~= "table" then
		return nil
	end
	local result = defaultEquipped()
	for _, slot in EQUIP_SLOTS do
		local item = value[slot]
		if type(item) == "string" and table.find(EQUIP_OPTIONS[slot], item) then
			(result :: any)[slot] = item
		end
	end
	return result
end

-- The version a stored record was written with (0 for the oldest saves).
local function versionOf(stored: any): number
	if type(stored) == "table" and type(stored.v) == "number" then
		return stored.v
	end
	return 0
end

-- A stored "base" table (or nil for an old save) -> a clean BaseRecord. Also migrates old saves (see
-- the header): habitat = 1 for a base that already has builds, the old drill skill -> drill tool, the
-- old jump skill -> air boots and, when `habitatTree` is true (a save from before Stage 9), the
-- habitat rises to what the standing structures need.
local function sanitizeBase(value: any, habitatTree: boolean?): BaseRecord
	if type(value) ~= "table" then
		return defaultBase()
	end
	local builds = sanitizeLevels(value.builds, findBuild)
	if next(builds) ~= nil and (builds.habitat or 0) < 1 then
		builds.habitat = 1
	end
	if habitatTree and next(builds) ~= nil then
		local need = BaseBuild.habitatForBuilds(MissionData, builds)
		local habitat = findBuild("habitat")
		if habitat then
			need = math.min(need, habitat.maxLevel)
		end
		builds.habitat = math.max(builds.habitat or 0, need)
	end
	local tools = sanitizeLevels(value.tools, findToolUpgrade)
	local oldSkills = value.skills
	local oldDrill = if type(oldSkills) == "table" then oldSkills.drill else nil
	local drillUpgrade = findToolUpgrade("drill")
	if type(oldDrill) == "number" and oldDrill == oldDrill and oldDrill >= 1 and drillUpgrade then
		local migrated = math.clamp(math.floor(oldDrill) + 1, 1, drillUpgrade.maxLevel)
		tools.drill = math.max(tools.drill or 0, migrated)
	end
	-- Stage 8: the old "jump" skill -> air boots at that level, switched on (sanitizeLevels below drops
	-- "jump" from the skills, so its points come back).
	local gear = sanitizeLevels(value.gear, findGear)
	local gearOn = sanitizeGearOn(value.gearOn)
	local oldJump = if type(oldSkills) == "table" then oldSkills.jump else nil
	local boots = findGear("boots")
	if type(oldJump) == "number" and oldJump == oldJump and oldJump >= 1 and boots then
		local migrated = math.clamp(math.floor(oldJump), 1, boots.maxLevel)
		if migrated > (gear.boots or 0) then
			gear.boots = migrated
		end
		if gearOn.boots == nil then
			gearOn.boots = true
		end
	end
	return {
		credits = sanitizeNumber(value.credits),
		xp = sanitizeNumber(value.xp),
		builds = builds,
		skills = sanitizeLevels(value.skills, findSkill),
		pets = sanitizeSet(value.pets, isBuyablePet),
		equipped = sanitizeEquipped(value.equipped),
		tools = tools,
		scanned = sanitizeScanned(value.scanned),
		gear = gear,
		gearOn = gearOn,
		quest = sanitizeQuest(value.quest),
	}
end

local function maxLevels(into: { [string]: number }, from: { [string]: number })
	for id, level in from do
		if level > (into[id] or 0) then
			into[id] = level
		end
	end
end

local function cloneBase(base: BaseRecord): BaseRecord
	return {
		credits = base.credits,
		xp = base.xp,
		builds = table.clone(base.builds),
		skills = table.clone(base.skills),
		pets = table.clone(base.pets),
		equipped = if base.equipped then table.clone(base.equipped) else nil,
		tools = table.clone(base.tools),
		scanned = table.clone(base.scanned),
		gear = table.clone(base.gear),
		gearOn = table.clone(base.gearOn),
		quest = sanitizeQuest(base.quest),
	}
end

-- What gets stored. `stored` = what is in the DataStore now (another server may have saved).
-- Credits, equipped, gearOn and quest: this server's values. XP, builds, skills, pets, tools, gear:
-- never lower than stored, unless the player reset their base (or started a New Game) here.
local function mergeBase(stored: any, current: BaseRecord, reset: boolean, habitatTree: boolean): BaseRecord
	local merged = cloneBase(current)
	if not reset and type(stored) == "table" then
		local old = sanitizeBase(stored, habitatTree)
		merged.xp = math.max(merged.xp, old.xp)
		maxLevels(merged.builds, old.builds)
		maxLevels(merged.skills, old.skills)
		union(merged.pets, old.pets)
		maxLevels(merged.tools, old.tools)
		union(merged.scanned, old.scanned)
		merged.scanned = sanitizeScanned(merged.scanned)
		maxLevels(merged.gear, old.gear)
		for id, on in old.gearOn do
			if merged.gearOn[id] == nil then
				merged.gearOn[id] = on -- gear another server bought (or migrated) keeps its switch
			end
		end
		merged.quest = mergeQuest(old.quest, merged.quest)
	end
	return merged
end

-- A base ready for the DataStore (quest number keys become strings).
local function storableBase(base: BaseRecord): any
	local out: any = cloneBase(base)
	out.quest = if base.quest then cleanData(base.quest, 0, true) else nil
	return out
end

local function progressOf(record: Record): Progress
	return {
		completed = table.clone(record.completed),
		collectibles = table.clone(record.collectibles),
		cosmetics = table.clone(record.cosmetics),
	}
end

local function ownsAll(record: Record): boolean
	for _, id in Missions.COLLECTIBLES do
		if not record.collectibles[id] then
			return false
		end
	end
	return true
end

local function notifyChanged()
	for _, listener in listeners do
		task.spawn(function()
			local ok, err = pcall(listener)
			if not ok then
				warn(`[SpaceBaseOdyssey] progress listener failed: {err}`)
			end
		end)
	end
end

local function sendProgress(player: Player, record: Record)
	if remotes and player.Parent then
		remotes.progress:FireClient(player, progressOf(record))
	end
end

local function sayTo(player: Player, key: string)
	if remotes and player.Parent then
		local text: Types.TextRef = { key = key }
		remotes.message:FireClient(player, text)
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

----------------------------------------------------------------------------------------------------
-- Slot summaries (the meta key)

local function emptySummary(): SlotSummary
	return { used = false, habitat = 0, level = 1, credits = 0, savedAt = 0, mode = "solo" }
end

local function emptyMeta(): Meta
	local slots: { SlotSummary } = {}
	for i = 1, SLOT_COUNT do
		slots[i] = emptySummary()
	end
	return { slots = slots, last = nil, cosmetics = {} }
end

local function sanitizeSummary(value: any): SlotSummary
	if type(value) ~= "table" then
		return emptySummary()
	end
	local savedAt = if type(value.savedAt) == "number" and value.savedAt == value.savedAt
		then math.clamp(math.floor(value.savedAt), 0, MAX_STORED_TIME)
		else 0
	return {
		used = value.used == true,
		habitat = sanitizeNumber(value.habitat),
		level = math.max(1, sanitizeNumber(value.level)),
		credits = sanitizeNumber(value.credits),
		savedAt = savedAt,
		mode = if value.mode == "friends" then "friends" else "solo",
	}
end

local function sanitizeMeta(value: any): Meta
	local meta = emptyMeta()
	if type(value) ~= "table" then
		return meta
	end
	if type(value.slots) == "table" then
		for i = 1, SLOT_COUNT do
			meta.slots[i] = sanitizeSummary(value.slots[i])
		end
	end
	meta.last = if isSlot(value.last) then value.last else nil
	meta.cosmetics = sanitizeSet(value.cosmetics, Codes.isCosmetic)
	return meta
end

local function cloneMeta(meta: Meta): Meta
	local slots: { SlotSummary } = {}
	for i = 1, SLOT_COUNT do
		slots[i] = table.clone(meta.slots[i])
	end
	return { slots = slots, last = meta.last, cosmetics = table.clone(meta.cosmetics) }
end

-- Another server may have saved another slot meanwhile: per slot, the newest summary wins.
local function mergeMeta(old: Meta, ours: Meta): Meta
	local result = cloneMeta(ours)
	result.last = ours.last or old.last
	union(result.cosmetics, old.cosmetics)
	for i = 1, SLOT_COUNT do
		if old.slots[i].savedAt > ours.slots[i].savedAt then
			result.slots[i] = table.clone(old.slots[i])
		end
	end
	return result
end

local function summaryOf(base: BaseRecord, mode: SlotMode): SlotSummary
	return {
		used = true,
		habitat = BaseBuild.levelOf(base.builds, "habitat"),
		level = BaseBuild.levelForXp(MissionData, base.xp),
		credits = base.credits,
		savedAt = os.time(),
		mode = mode,
	}
end

local function sendSlots(player: Player, record: Record)
	local events = remotes
	local event = events and events.slots
	if event == nil or player.Parent == nil then
		return
	end
	local slots: { Types.SlotInfo } = {}
	for i = 1, SLOT_COUNT do
		slots[i] = table.clone(record.meta.slots[i])
	end
	local view: Types.SlotsMeta = {
		slots = slots,
		last = record.meta.last,
		current = record.slot,
		offline = if record.metaReady and not record.metaCanSave then true else nil,
	}
	event:FireClient(player, view)
end

----------------------------------------------------------------------------------------------------
-- Saving

-- Saves the chosen slot. `closing` = the server is closing: no waiting for write budget.
local function save(player: Player, record: Record, closing: boolean?)
	local slot = record.slot
	if slot == nil or record.state ~= "loaded" or not record.canSave then
		return
	end
	if not closing and not waitForBudget(BUDGET_WAIT_SECONDS) then
		return -- still dirty: the autosave check schedules it again
	end
	record.dirty = false
	savesInFlight += 1
	local completed = table.clone(record.completed)
	local collectibles = table.clone(record.collectibles)
	local cosmetics = table.clone(record.cosmetics)
	local base = cloneBase(record.base)
	local reset = record.baseReset
	local replaceAll = record.replaceAll
	local source = backend
	local ok, err = pcall(source.update, slotKey(player, slot), function(old: any): any
		local stored = if replaceAll or type(old) ~= "table" then nil else old
		local merged = {
			v = DATA_VERSION,
			completed = sanitizeSet(stored and stored.completed, isMissionId),
			collectibles = sanitizeSet(stored and stored.collectibles, Missions.isCollectible),
			cosmetics = sanitizeSet(stored and stored.cosmetics, Codes.isCosmetic),
			base = storableBase(
				mergeBase(stored and stored.base, base, reset or replaceAll, versionOf(stored) < HABITAT_TREE_VERSION)
			),
		}
		union(merged.completed, completed)
		union(merged.collectibles, collectibles)
		union(merged.cosmetics, cosmetics)
		return merged
	end)
	savesInFlight -= 1
	record.lastSaveAt = os.clock()
	if not ok then
		record.dirty = true
		warn(`[SpaceBaseOdyssey] could not save slot {slot} for {player.Name}: {err}`)
		return
	end
	if reset then
		record.baseReset = false
	end
	if replaceAll then
		record.replaceAll = false
	end
	record.meta.slots[slot] = summaryOf(record.base, record.mode or "solo")
	record.metaDirty = true
end

local function saveMeta(player: Player, record: Record)
	if not record.metaReady or not record.metaCanSave then
		return
	end
	record.metaDirty = false
	savesInFlight += 1
	local ours = cloneMeta(record.meta)
	local source = backend
	local ok, err = pcall(source.update, metaKey(player), function(old: any): any
		return mergeMeta(sanitizeMeta(old), ours)
	end)
	savesInFlight -= 1
	record.metaLastSaveAt = os.clock()
	if not ok then
		record.metaDirty = true
		warn(`[SpaceBaseOdyssey] could not save the slot list for {player.Name}: {err}`)
	end
end

-- Saves the start menu summary soon: within `interval` of the last meta save.
local function requestMetaSave(player: Player, record: Record, interval: number?)
	record.metaDirty = true
	if record.metaSaveScheduled or not record.metaCanSave or not record.metaReady then
		return
	end
	record.metaSaveScheduled = true
	local spacing = interval or META_SAVE_INTERVAL_SECONDS
	local delay = math.max(0, record.metaLastSaveAt + spacing - os.clock())
	task.delay(delay, function()
		record.metaSaveScheduled = false
		if records[player] == record and record.metaDirty and waitForBudget(BUDGET_WAIT_SECONDS) then
			saveMeta(player, record)
		end
	end)
end

-- Saves soon, at most once every SAVE_INTERVAL_SECONDS per player.
local function requestSave(player: Player, record: Record)
	record.dirty = true
	if record.saveScheduled or not record.canSave or record.state ~= "loaded" then
		return
	end
	record.saveScheduled = true
	local delay = math.max(0, record.lastSaveAt + SAVE_INTERVAL_SECONDS - os.clock())
	task.delay(delay, function()
		record.saveScheduled = false
		if records[player] == record and record.dirty then
			save(player, record)
			if record.metaDirty then
				requestMetaSave(player, record)
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Rewards

local function anyoneOwns(id: string): boolean
	for player, record in records do
		if player.Parent ~= nil and record.loaded and record.collectibles[id] then
			return true
		end
	end
	return false
end

-- World rewards are shared by everyone in the server: shown while any present player owns them.
local function refreshWorldRewards()
	local paint = if anyoneOwns("cheese") then "cheese" else "default"
	if appliedPaint ~= paint then
		appliedPaint = paint
		worldCall("setRoverPaint", paint)
	end
	local flag = anyoneOwns("mars_potato")
	if appliedFlag ~= flag then
		appliedFlag = flag
		worldCall("setTeamFlag", flag)
	end
end

----------------------------------------------------------------------------------------------------
-- Choosing and loading a slot

local function setAttribute(player: Player, name: string, value: any)
	if player.Parent then
		player:SetAttribute(name, value)
	end
end

local function isReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- Solo worlds get their own reserved server, but only from a public server outside Studio.
local function canTeleportSolo(): boolean
	return not RunService:IsStudio() and game.PrivateServerId == "" and game.PlaceId ~= 0
end

-- The slot a solo trip brought this player here for (reserved servers only).
local function joinChoice(player: Player): Choice?
	if not isReservedServer() then
		return nil
	end
	local ok, joinData = pcall(function(): any
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return nil
	end
	local source = joinData.SourcePlaceId
	if source ~= nil and source ~= game.PlaceId then
		return nil
	end
	local data = joinData.TeleportData
	if type(data) ~= "table" or data.mode ~= "solo" or not isSlot(data.slot) then
		return nil
	end
	return { slot = data.slot, mode = "solo", fresh = data.fresh == true }
end

local function loadSlot(player: Player, record: Record, choice: Choice)
	if record.state ~= "menu" and record.state ~= "teleporting" then
		return
	end
	local slot = choice.slot
	record.state = "loading"
	record.slot = slot
	record.mode = choice.mode
	record.teleportChoice = nil
	setAttribute(player, "SBO_SlotLoading", true)

	local stored: any = nil
	local canSave = false
	local fromLegacy = false
	if choice.fresh then
		-- New Game: nothing to read, the first save replaces the slot. Only when the slot list could
		-- be read, so a slot we know nothing about is never overwritten.
		canSave = record.metaCanSave
		record.replaceAll = true
	else
		local ok, data = readKey(slotKey(player, slot), player.Name)
		if ok and data == nil and slot == LEGACY_SLOT then
			ok, data = readKey(legacyKey(player), player.Name)
			fromLegacy = ok and type(data) == "table"
		end
		canSave = ok
		if ok and type(data) == "table" then
			stored = data
		end
	end
	if records[player] ~= record then
		return -- left while loading
	end
	if not canSave then
		warn(`[SpaceBaseOdyssey] slot {slot} for {player.Name} kept in memory for this session`)
	end
	if stored then
		union(record.completed, sanitizeSet(stored.completed, isMissionId))
		union(record.collectibles, sanitizeSet(stored.collectibles, Missions.isCollectible))
		union(record.cosmetics, sanitizeSet(stored.cosmetics, Codes.isCosmetic))
	end
	union(record.cosmetics, record.meta.cosmetics) -- event codes count in every slot

	-- Rewards may have come in while loading: keep what was earned on top of the stored base.
	local earned = record.base
	local base = sanitizeBase(stored and stored.base, stored ~= nil and versionOf(stored) < HABITAT_TREE_VERSION)
	base.credits += math.max(0, earned.credits - MissionData.BASE.START_CREDITS)
	base.xp += earned.xp
	maxLevels(base.builds, earned.builds)
	maxLevels(base.skills, earned.skills)
	union(base.pets, earned.pets)
	maxLevels(base.tools, earned.tools)
	union(base.scanned, earned.scanned)
	maxLevels(base.gear, earned.gear)
	for id, on in earned.gearOn do
		base.gearOn[id] = on
	end
	if base.equipped == nil then
		base.equipped = earned.equipped
	end
	if base.quest == nil then
		base.quest = earned.quest
	end
	record.base = base
	record.canSave = canSave
	record.loaded = true
	record.state = "loaded"

	record.meta.slots[slot] = summaryOf(base, choice.mode)
	record.meta.last = slot
	if record.metaLastSaveAt + SAVE_INTERVAL_SECONDS < os.clock() then
		task.spawn(saveMeta, player, record)
	else
		requestMetaSave(player, record, SAVE_INTERVAL_SECONDS)
	end
	if choice.fresh or fromLegacy or record.dirty then
		requestSave(player, record) -- wipe the slot now, copy the old save into it, or keep what was earned
	end

	setAttribute(player, "SBO_Slot", slot)
	setAttribute(player, "SBO_SlotLoading", false)
	setAttribute(player, "SBO_SlotChosen", true)
	sendSlots(player, record)
	sendProgress(player, record)
	refreshWorldRewards()
	notifyChanged()
	for _, listener in loadedListeners do
		task.spawn(function()
			local ok, err = pcall(listener, player)
			if not ok then
				warn(`[SpaceBaseOdyssey] progress load listener failed: {err}`)
			end
		end)
	end
end

-- The solo trip did not happen: play the slot in this server.
local function teleportFailed(player: Player, record: Record, token: number)
	local choice = record.teleportChoice
	if records[player] ~= record or record.state ~= "teleporting" or record.teleportToken ~= token or choice == nil then
		return
	end
	sayTo(player, "carl.solo_here")
	loadSlot(player, record, choice)
end

local function startSoloTrip(player: Player, record: Record, choice: Choice)
	record.state = "teleporting"
	record.teleportChoice = choice
	record.teleportToken += 1
	local token = record.teleportToken
	setAttribute(player, "SBO_SlotLoading", true)
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		options:SetTeleportData({ slot = choice.slot, mode = "solo", fresh = choice.fresh })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] solo teleport failed for {player.Name}, loading here: {err}`)
		teleportFailed(player, record, token)
		return
	end
	task.delay(TELEPORT_TIMEOUT_SECONDS, function()
		teleportFailed(player, record, token)
	end)
end

local function applyChoice(player: Player, record: Record, choice: Choice)
	if record.state ~= "menu" then
		return
	end
	if not record.metaReady then
		record.pendingChoice = choice -- handled once the slot list is read
		return
	end
	local fresh = choice.fresh
	if record.metaCanSave and not record.meta.slots[choice.slot].used then
		fresh = true -- "Continue" on an empty slot starts a new game there
	end
	local final: Choice = { slot = choice.slot, mode = choice.mode, fresh = fresh }
	if final.mode == "solo" and canTeleportSolo() then
		startSoloTrip(player, record, final)
	else
		loadSlot(player, record, final)
	end
end

----------------------------------------------------------------------------------------------------
-- Players

local function addPlayer(player: Player)
	if records[player] then
		return
	end
	local record: Record = {
		completed = {},
		collectibles = {},
		cosmetics = {},
		base = defaultBase(),
		loaded = false,
		state = "menu",
		slot = nil,
		mode = nil,
		pendingChoice = joinChoice(player),
		teleportChoice = nil,
		teleportToken = 0,
		replaceAll = false,
		baseReset = false,
		canSave = false,
		dirty = false,
		saveScheduled = false,
		lastSaveAt = -math.huge,
		meta = emptyMeta(),
		metaReady = false,
		metaCanSave = false,
		metaDirty = false,
		metaSaveScheduled = false,
		metaLastSaveAt = -math.huge,
		lastSlotsRequestAt = -math.huge,
		lastPickup = {},
		lastRedeemAt = -math.huge,
		connections = {},
	}
	records[player] = record
	if record.pendingChoice then
		setAttribute(player, "SBO_SlotLoading", true) -- a solo trip: no start menu here
	end

	task.spawn(function()
		local ok, data = readKey(metaKey(player), player.Name)
		local meta = emptyMeta()
		local canSave = ok
		local migrated = false
		if ok and type(data) == "table" then
			meta = sanitizeMeta(data)
		elseif ok then
			-- No slot list yet: the save from before slots (if any) becomes slot 1.
			local legacyOk, legacy = readKey(legacyKey(player), player.Name)
			if not legacyOk then
				canSave = false -- never write a slot list that could hide the old save
			elseif type(legacy) == "table" then
				local base = sanitizeBase(legacy.base, versionOf(legacy) < HABITAT_TREE_VERSION)
				local summary = summaryOf(base, "friends")
				summary.savedAt = 0 -- unknown
				meta.slots[LEGACY_SLOT] = summary
				meta.last = LEGACY_SLOT
				meta.cosmetics = sanitizeSet(legacy.cosmetics, Codes.isCosmetic)
				migrated = true
			end
		end
		if records[player] ~= record then
			return -- left while loading
		end
		union(meta.cosmetics, record.cosmetics) -- a code redeemed on the start menu meanwhile
		record.meta = meta
		record.metaCanSave = canSave
		record.metaReady = true
		if not canSave then
			warn(`[SpaceBaseOdyssey] slot list for {player.Name} could not be read; saving is off this session`)
		end
		if migrated or next(record.cosmetics) ~= nil then
			requestMetaSave(player, record, SAVE_INTERVAL_SECONDS)
		end
		local pending = record.pendingChoice
		record.pendingChoice = nil
		if pending then
			applyChoice(player, record, pending)
		else
			sendSlots(player, record)
		end
	end)
end

local function removePlayer(player: Player)
	local record = records[player]
	if record == nil then
		return
	end
	records[player] = nil
	for _, connection in record.connections do
		connection:Disconnect()
	end
	refreshWorldRewards()
	notifyChanged()
	if record.dirty then
		save(player, record)
	end
	if record.metaDirty and waitForBudget(BUDGET_WAIT_SECONDS) then
		saveMeta(player, record)
	end
end

----------------------------------------------------------------------------------------------------
-- Collectible prompts

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

-- The prompt is triggered by the client; check the character really stands next to it.
local function closeEnough(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = promptPosition(prompt)
	if root == nil or not root:IsA("BasePart") or position == nil then
		return false
	end
	return (root.Position - position).Magnitude <= prompt.MaxActivationDistance + PICKUP_EXTRA_RANGE
end

local function connectCollectibles()
	local list = world and world.collectibles
	if type(list) ~= "table" then
		warn("[SpaceBaseOdyssey] world has no collectibles list")
		return
	end
	for _, entry in list do
		local prompt = type(entry) == "table" and entry.prompt
		if typeof(prompt) ~= "Instance" or not (prompt :: Instance):IsA("ProximityPrompt") then
			continue
		end
		local proximity = prompt :: ProximityPrompt
		local id = entry.id
		if not Missions.isCollectible(id) then
			id = proximity:GetAttribute("CollectibleId")
		end
		if not Missions.isCollectible(id) then
			warn(`[SpaceBaseOdyssey] collectible prompt with unknown id {tostring(id)}`)
			continue
		end
		local collectibleId = id :: string
		proximity.Triggered:Connect(function(player: Player)
			local ok, err = pcall(function()
				if closeEnough(player, proximity) then
					ProgressService.grantCollectible(player, collectibleId)
				end
			end)
			if not ok then
				warn(`[SpaceBaseOdyssey] collectible pickup failed: {err}`)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

ProgressService.SLOT_COUNT = SLOT_COUNT

-- worldRefs: WorldBuilder.World (collectibles, setRoverPaint, setTeamFlag).
-- remoteEvents.action (optional): the Action remote, for ChooseSlot and RequestSlots.
-- remoteEvents.slots (optional): Remotes.SLOTS, the start menu's slot list (Types.SlotsMeta).
function ProgressService.start(worldRefs: any, remoteEvents: Remotes)
	assert(not started, "ProgressService already started")
	started = true
	world = worldRefs
	remotes = remoteEvents

	local useDataStores = not RunService:IsStudio() or workspace:GetAttribute(STUDIO_DATASTORE_ATTRIBUTE) == true
	if useDataStores then
		local ok, result = pcall(function(): DataStore
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok and result then
			backend = dataStoreBackend(result)
		else
			warn(`[SpaceBaseOdyssey] DataStores unavailable, progress kept in memory: {result}`)
		end
	else
		print("[SpaceBaseOdyssey] Studio: save slots are kept in memory for this session")
	end

	connectCollectibles()
	refreshWorldRewards()

	local actionEvent = remoteEvents.action
	if actionEvent then
		actionEvent.OnServerEvent:Connect(function(player: Player, action: any)
			if type(action) ~= "table" then
				return
			end
			if action.type == "ChooseSlot" then
				task.spawn(function()
					local ok, err = pcall(ProgressService.chooseSlot, player, action.slot, action.mode, action.fresh)
					if not ok then
						warn(`[SpaceBaseOdyssey] ChooseSlot failed: {err}`)
					end
				end)
			elseif action.type == "RequestSlots" then
				local record = records[player]
				local t = os.clock()
				if record and record.metaReady and t - record.lastSlotsRequestAt >= SLOTS_REQUEST_INTERVAL then
					record.lastSlotsRequestAt = t
					sendSlots(player, record)
				end
			end
		end)
	end

	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result: Enum.TeleportResult, message: string)
		local record = records[player]
		if record and record.state == "teleporting" then
			warn(`[SpaceBaseOdyssey] solo teleport failed for {player.Name}, loading here: {message}`)
			teleportFailed(player, record, record.teleportToken)
		end
	end)

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	-- Safety net: anything still unsaved (a save that had no budget, or failed) is scheduled again.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_CHECK_SECONDS)
			for player, record in records do
				if record.dirty and not record.saveScheduled then
					requestSave(player, record)
				end
				if record.metaDirty and not record.metaSaveScheduled then
					requestMetaSave(player, record)
				end
			end
		end
	end)

	-- Save what is still unsaved, and wait for saves already running (PlayerRemoving starts them too).
	game:BindToClose(function()
		for player, record in records do
			task.spawn(function()
				if record.dirty then
					save(player, record, true)
				end
				if record.metaDirty then
					saveMeta(player, record)
				end
			end)
		end
		local deadline = os.clock() + CLOSE_BUDGET_SECONDS
		while savesInFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- ChooseSlot action (validated here): slot 1..SLOT_COUNT, mode "solo" | "friends", fresh boolean
-- (New Game: wipes that slot). Only once per visit, from the start menu. Returns false when rejected.
function ProgressService.chooseSlot(player: Player, slot: any, mode: any, fresh: any): boolean
	local record = records[player]
	if record == nil or record.state ~= "menu" then
		return false
	end
	if not isSlot(slot) or (mode ~= "solo" and mode ~= "friends") then
		return false
	end
	if fresh ~= nil and type(fresh) ~= "boolean" then
		return false
	end
	applyChoice(player, record, { slot = slot :: number, mode = mode :: SlotMode, fresh = fresh == true })
	return true
end

-- The slot this player plays (nil on the start menu or while teleporting) and its mode.
function ProgressService.slotOf(player: Player): number?
	local record = records[player]
	return if record then record.slot else nil
end

function ProgressService.modeOf(player: Player): string?
	local record = records[player]
	return if record then record.mode else nil
end

-- Called after any progress change (a load, a completed mission, a collectible).
function ProgressService.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

function ProgressService.get(player: Player): Progress?
	local record = records[player]
	if record == nil then
		return nil
	end
	return progressOf(record)
end

-- Missions completed by any player currently playing a slot in the server (decides what is unlocked).
function ProgressService.completedUnion(): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for player, record in records do
		if player.Parent ~= nil and record.loaded then
			union(result, record.completed)
		end
	end
	return result
end

-- Players still on the start menu (no slot chosen) get nothing.
function ProgressService.markCompleted(players: { Player }, missionId: string)
	if not isMissionId(missionId) then
		return
	end
	local changed = false
	for _, player in players do
		local record = records[player]
		if record and record.slot ~= nil and not record.completed[missionId] then
			record.completed[missionId] = true
			changed = true
			sendProgress(player, record)
			requestSave(player, record)
		end
	end
	if changed then
		notifyChanged()
	end
end

-- Gives `player` a collectible, tells their client (Remotes.COLLECTED, then PROGRESS) and applies
-- the rewards. Picking up one already owned just shows the card again (isNew = false).
function ProgressService.grantCollectible(player: Player, id: string)
	local record = records[player]
	if record == nil or record.slot == nil or not Missions.isCollectible(id) then
		return
	end
	local t = os.clock()
	local last = record.lastPickup[id]
	if last and t - last < PICKUP_DEBOUNCE_SECONDS then
		return
	end
	record.lastPickup[id] = t

	local isNew = not record.collectibles[id]
	record.collectibles[id] = true
	local allFound = ownsAll(record)
	if remotes and player.Parent then
		local collected: Types.Collected = { id = id, isNew = isNew, allFound = allFound }
		remotes.collected:FireClient(player, collected)
	end
	if not isNew then
		return
	end
	sendProgress(player, record)
	requestSave(player, record)
	sayTo(player, if allFound then "carl.all_secrets" else "carl.secret_found")
	refreshWorldRewards()
	notifyChanged()
	for _, listener in collectibleListeners do
		task.spawn(function()
			local ok, err = pcall(listener, player, id, isNew)
			if not ok then
				warn(`[SpaceBaseOdyssey] collectible listener failed: {err}`)
			end
		end)
	end
end

-- Gives `player` an event cosmetic (in every slot: it is also kept in the slot list). Returns false
-- when they already had it.
function ProgressService.grantCosmetic(player: Player, id: string): boolean
	local record = records[player]
	if record == nil or not Codes.isCosmetic(id) or record.cosmetics[id] then
		return false
	end
	record.cosmetics[id] = true
	record.meta.cosmetics[id] = true
	sendProgress(player, record)
	requestSave(player, record)
	requestMetaSave(player, record, SAVE_INTERVAL_SECONDS)
	notifyChanged()
	for _, listener in cosmeticListeners do
		task.spawn(function()
			local ok, err = pcall(listener, player, id)
			if not ok then
				warn(`[SpaceBaseOdyssey] cosmetic listener failed: {err}`)
			end
		end)
	end
	return true
end

function ProgressService.hasCosmetic(player: Player, id: string): boolean
	local record = records[player]
	return record ~= nil and record.cosmetics[id] == true
end

-- RedeemCode action: one attempt every CODES.COOLDOWN_SECONDS per player (extra attempts are
-- ignored). Replies through C.A.R.L.: carl.code_ok, carl.code_used or carl.code_bad.
function ProgressService.redeemCode(player: Player, code: any)
	local record = records[player]
	if record == nil then
		return
	end
	local t = os.clock()
	if t - record.lastRedeemAt < MissionData.CODES.COOLDOWN_SECONDS then
		return
	end
	record.lastRedeemAt = t
	local normalized = Codes.normalize(code, MissionData.CODES.MAX_LENGTH)
	local cosmetic = if normalized then Codes.lookup(normalized) else nil
	if cosmetic == nil then
		sayTo(player, "carl.code_bad")
	elseif record.cosmetics[cosmetic] then
		sayTo(player, "carl.code_used")
	else
		ProgressService.grantCosmetic(player, cosmetic)
		sayTo(player, "carl.code_ok")
	end
end

----------------------------------------------------------------------------------------------------
-- Stage 6: build-and-grow data (rules in BaseService and BaseBuild)

-- Every value each wardrobe slot can hold; the first one is the default.
ProgressService.EQUIP_OPTIONS = EQUIP_OPTIONS
ProgressService.EQUIP_SLOTS = EQUIP_SLOTS

function ProgressService.defaultEquipped(): Types.Equipped
	return defaultEquipped()
end

-- True once the player chose a slot and its stored data was read (or could not be, and the defaults
-- are used). BaseService ignores base actions until then; Main.server spawns the character then.
function ProgressService.isLoaded(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.loaded
end

-- A copy of the player's base data in the chosen slot (nil when the player has no record, or is still
-- on the start menu).
function ProgressService.getBase(player: Player): BaseRecord?
	local record = records[player]
	if record == nil or record.slot == nil then
		return nil
	end
	return cloneBase(record.base)
end

-- Changes the player's base data in place and saves soon. `change` gets the live table; it must keep
-- every field valid (BaseService checks the rules first). Returns false when there is no record or
-- no slot is chosen yet.
function ProgressService.updateBase(player: Player, change: (base: BaseRecord) -> ()): boolean
	local record = records[player]
	if record == nil or record.slot == nil then
		return false
	end
	change(record.base)
	record.base.credits = sanitizeNumber(record.base.credits)
	record.base.xp = sanitizeNumber(record.base.xp)
	requestSave(player, record)
	return true
end

-- Puts the player's builds, skills, credits, XP, tool upgrades, gear, scanned sites and quests back to
-- the start (DebugResetBase). Bought pets and what they wear are kept. The next save replaces the
-- stored base instead of merging.
function ProgressService.resetBase(player: Player): boolean
	local record = records[player]
	if record == nil or record.slot == nil then
		return false
	end
	local fresh = defaultBase()
	fresh.pets = record.base.pets
	fresh.equipped = record.base.equipped
	record.base = fresh
	record.baseReset = true
	requestSave(player, record)
	return true
end

-- True for a key BaseService may store in base.scanned (short; letters, digits, "_", "-", ":").
function ProgressService.isScannedKey(key: any): boolean
	return isScannedKey(key)
end

-- Called (with the player) when a player's chosen slot finished loading.
function ProgressService.onLoaded(listener: (player: Player) -> ())
	table.insert(loadedListeners, listener)
end

-- Called the first time a player picks up a collectible (isNew is then always true; repeat pickups
-- only show the card again and do not call it).
function ProgressService.onCollectible(listener: (player: Player, id: string, isNew: boolean) -> ())
	table.insert(collectibleListeners, listener)
end

-- Called when a player gets a new event cosmetic (redeem code).
function ProgressService.onCosmetic(listener: (player: Player, id: string) -> ())
	table.insert(cosmeticListeners, listener)
end

return ProgressService
