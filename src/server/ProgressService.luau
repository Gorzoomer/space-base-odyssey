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
-- ChooseSlot { slot 1-3, mode "solo" | "friends", fresh } (fresh = New Game: the slot is wiped). Since
-- the Stage 10 fix "private worlds" (see the end of this header) every world runs in its owner's own
-- reserved server, for both modes; the public server is only a lobby.
-- Player attributes: SBO_SlotLoading = true while a slot is on its way (teleport or load),
-- SBO_SlotChosen = true and SBO_Slot = n once it is loaded. Remotes.SLOTS sends Types.SlotsMeta.
-- When DataStores are not available (Studio, an unpublished place, or no API access) every slot lives
-- in memory for this server session. Studio: see Stage 10 below (a published place tries a separate
-- Studio DataStore, so debug credits never reach live saves).
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
-- Stage 10 adds base.achievements (Achievements.Record: unlocked ids and two lifetime counters; an
-- older save without it loads as nothing unlocked; a debug base reset keeps it).
-- Stage 9 adds base.quest (QuestService's own table, saved as it is; plain numbers, booleans, short
-- strings and tables only). Migration of saves from before Stage 9: the habitat (the base level) rises
-- to what the structures already built need under the habitat tree (BaseBuild.habitatForBuilds), so
-- nothing built before stops being valid. Skills already learned stay even if the longer level table
-- shows a lower level now.
-- Stage 10 (playtest: "I pressed Leave and it did not save"):
--   * Studio backend. workspace attribute SBO_StudioDataStores:
--       false -> memory (lost when Play stops), as before;
--       true  -> the live DataStore "SBO_Progress_v1" (the old opt-in, unchanged);
--       unset -> a published place (game.PlaceId ~= 0) tries real DataStores in a separate store
--                "SBO_Progress_v1_Studio" (so debug credits never reach live saves). A probe read
--                decides; if it fails (API access off) memory is used exactly as before.
--     One log line says which backend this server uses.
--   * After each successful save of a player's slot, Remotes.SAVED tells that player
--     (Types.SaveNotice: real save or memory only, autosave or "Save now"). The client shows a small
--     pill (src/client/SaveIndicator.luau).
--   * Action SaveNow (Settings panel): validated here (a loaded slot), at most one request per
--     second; the write happens at the earliest moment the DataStore allows (one write per key
--     every MANUAL_SAVE_SPACING seconds) and its notice says manual = true.
--   * Leaving (PlayerRemoving) counts as a save in flight from the first moment, so BindToClose
--     (a reserved solo server closes when its only player leaves) always waits for it.
-- Stage 10 fix "private worlds" (live playtest: a friend pressed New game in the public server and
-- landed in another player's base, because builds were the highest of everyone present). Rules in
-- src/shared/Worlds.luau (tests/worlds.luau). This server has a ROLE (workspace attribute SBO_WorldRole):
--   lobby (a public server): only the start menu; no slot ever loads here, so nobody spawns. ChooseSlot
--     reserves a new server (TeleportService:ReserveServer) and teleports the player there with
--     TeleportData { owner = their UserId, slot, mode, fresh, code = the access code }. JoinWorld
--     { owner, slot } (Join a friend) checks that the requester is a Roblox friend of the owner and
--     that the owner's world is open (MemoryStore hash map "SBO_Worlds", key = owner UserId), is a
--     friends world and has room, then teleports them into it with TeleportData { owner, guest = true,
--     slot, fresh }. ListFriendWorlds answers on Remotes.WORLDS (Types.FriendWorlds): the player's
--     Roblox friends who host an open friends world now. A failed trip puts the player back on the
--     menu (attributes SBO_TripFailedReason, then SBO_TripFailed = a counter); it never loads here.
--   world (a reserved server): the first valid owner trip fixes the world's owner, slot and mode. The
--     owner's slot is the base. "solo": nobody else may stay. "friends": Roblox friends of the owner,
--     at most MissionData.MISSION.PLAYERS_MAX players in all. Every arrival is checked again here;
--     anyone refused hears C.A.R.L. (carl.world.<reason>, attribute SBO_WorldNotice) and goes back to
--     the lobby (TeleportData { notice }); if that teleport fails they are kicked. A friends world
--     writes its registry entry { owner, code, mode, slot, players, max, baseLevel, name, updatedAt }
--     every WORLD_REFRESH_SECONDS (it expires after WORLD_ENTRY_EXPIRY_SECONDS) and removes it when
--     the owner leaves or the server closes. When the owner leaves, every guest's slot is saved and
--     they go back to the lobby (notice host_left).
--   local (Studio, an unpublished place, a VIP server): slots load in this server as before. The
--     first player whose slot loads owns the world; later players are guests; when the owner leaves
--     the next in line owns it. Join a friend lists nothing here.
-- Guests keep their own slot (credits, XP, skills, gear, tools, pets, wardrobe, quests, collectibles,
-- missions); what they build goes into the OWNER's save (BaseService), so a guest's own builds never
-- change in a friend's world. worldOwner / worldOwnerId / isGuest / onOwnerChanged tell BaseService
-- who owns the world. Player attribute SBO_Guest; workspace attribute SBO_WorldOwner (UserId).
-- Stage 11 "safer server" (rules in src/shared/ServerGuard.luau, tests/worlds):
--   * Session lock. A slot loads only after this server takes its lock: an UpdateAsync writes
--     lock = { job = this server, token = this visit, at = os.time() } into the slot record. A fresh
--     lock of another visit (a server the player just left, still saving) makes the load wait (every
--     LOCK_RETRY_SECONDS, at most LOCK_WAIT_SECONDS), then the lock is stolen; a lock older than
--     LOCK_TIMEOUT_SECONDS is stale and taken at once. Every save checks the lock first and refreshes
--     `at` (an idle player's slot is re-saved every LOCK_REFRESH_SECONDS or so); the last save on
--     leave (or BindToClose) releases it. A save from a visit that lost its lock is refused: saving
--     stops for that visit (and a player still here is asked to join again), so a quick server hop
--     can never duplicate or overwrite credits.
--   * Continue never wipes. Only an explicit New game (ChooseSlot fresh = true) replaces a slot. A
--     slot the meta lists as unused is read like any other: an empty record starts a new explorer, a
--     record with data is loaded and the meta summary repaired.
--   * Settings. Each player's settings (Types.PlayerSettings: language, musicVolume, effectsVolume,
--     funFacts, guidance) live in the meta record (settings, settingsAt) and come back in
--     SlotsMeta.settings and as player attributes (Language, SBO_MusicVolume, SBO_EffectsVolume,
--     SBO_FunFacts, SBO_Guidance). Action SaveSettings (and SetLanguage) changes them, at most
--     SETTINGS_PER_SECOND a second. A trip to a world server carries them in TeleportData.prefs, so
--     the world has them even before the lobby's meta write lands.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local Localization = require(Shared:WaitForChild("Localization"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Missions = require(Shared:WaitForChild("Missions"))
local Types = require(Shared:WaitForChild("Types"))
local Worlds = require(Shared:WaitForChild("Worlds"))
local Achievements = require(Shared:WaitForChild("Achievements"))
local ServerGuard = require(Shared:WaitForChild("ServerGuard")) -- Stage 11
local Daily = require(Shared:WaitForChild("Daily")) -- Stage 11 daily: base.daily record rules

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
	action: RemoteEvent?, -- Stage 9: ChooseSlot / RequestSlots (Stage 10: SaveNow) arrive here (MissionService ignores them)
	slots: RemoteEvent?, -- Stage 9: Types.SlotsMeta to one client
	saved: RemoteEvent?, -- Stage 10: Types.SaveNotice to one client (created here when missing)
	worlds: RemoteEvent?, -- Stage 10 fix: Types.FriendWorlds to one client (created here when missing)
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
	-- Stage 10: learning achievements (src/shared/Achievements.luau Record). A save without the field
	-- loads as nothing unlocked; unlocks and counters never go down (Achievements.mergeRecord).
	achievements: Achievements.Record,
	-- Stage 11 tycoon: the ice in this player's silo when they last played as the world owner, and
	-- os.time() of that write (BaseService adds what the drills dug while they were away). nil = none.
	silo: { ice: number, at: number }?,
	-- Stage 11 daily: supply capsules opened, suit stripes and the Moon Logbook (src/shared/Daily.luau
	-- Record; DailyService writes it). nil = never written; saves only grow (Daily.mergeRecord).
	daily: Daily.Record?,
}

-- What the start menu shows about this player's slots (meta key), plus account-wide cosmetics.
type Meta = {
	slots: { SlotSummary },
	last: number?,
	cosmetics: { [string]: boolean },
	-- Stage 11: the player's settings and os.time() of their last change (0 = never saved).
	settings: ServerGuard.Settings,
	settingsAt: number,
}

type SlotState = "menu" | "teleporting" | "loading" | "loaded"

type Choice = {
	slot: number,
	mode: SlotMode,
	fresh: boolean,
	guest: boolean?, -- Stage 10 fix: a friend joining someone else's world with this slot
}

-- Stage 10 fix: a trip from the lobby to a world server (the reserved server and what it is told).
type Trip = {
	code: string, -- ReservedServerAccessCode
	data: { [string]: any }, -- TeleportData (Worlds.Arrival)
	attempts: number,
	join: boolean, -- true = into a friend's world (failures then mean the world is closed)
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
	manualPending: boolean, -- Stage 10: a SaveNow is waiting; the next save's notice says manual
	lastSaveNowAt: number, -- os.clock() of the last SaveNow request (rate limit)
	-- Stage 10 fix: private worlds.
	trip: Trip?, -- the lobby's trip to a world server, while state == "teleporting"
	guest: boolean, -- plays in someone else's world (their builds go into the owner's save)
	accepted: boolean, -- world servers: this player may stay (owner, or a friend with room)
	rejected: boolean, -- world servers: refused, on the way back to the lobby
	lastWorldsRequestAt: number, -- ListFriendWorlds rate limit
	lastJoinAt: number, -- JoinWorld rate limit
	connections: { RBXScriptConnection },
	-- Stage 11: the session lock of the loaded slot (see the header).
	lockToken: string, -- this visit's token (new for every load)
	lockHeld: boolean, -- this visit took the slot's lock
	lockLost: boolean, -- another visit took it: saving stopped
	lockAt: number, -- os.time() of the last write that refreshed the lock
	savingNow: number, -- slot writes running right now (a lock release waits for them)
	quietSave: boolean, -- the next write only refreshes the lock: no save notice
	-- Stage 11: settings (the newest of this visit's changes, the meta's and the trip's).
	settings: ServerGuard.Settings,
	settingsAt: number, -- os.time() of the last change known here (0 = defaults)
	settingsTimes: { number }, -- SaveSettings rate limit (os.clock() of recent requests)
	arrivalPrefs: { settings: ServerGuard.Settings, at: number }?, -- world servers: TeleportData.prefs
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
local STUDIO_DATASTORE_ATTRIBUTE = "SBO_StudioDataStores" -- workspace attribute: false = memory, true = live store
local STUDIO_STORE_NAME = "SBO_Progress_v1_Studio" -- Stage 10: Studio saves of a published place (attribute unset)
local PROBE_KEY = "probe" -- Stage 10: read once in Studio to see whether DataStores answer
local PROBE_TIMEOUT_SECONDS = 8 -- no answer by then: memory for this session
local MANUAL_SAVE_SPACING = 6 -- Stage 10: DataStores allow one write per key about every 6 seconds
local SAVE_NOW_REQUEST_INTERVAL = 1 -- SaveNow rate limit per player (requests, not writes)
local CLOSE_BUDGET_STUDIO_SECONDS = 5 -- Studio waits only a short time when Play stops
local MAX_STORED_NUMBER = 1e9 -- credits and XP are clamped to this when read from storage
local MAX_STORED_TIME = 1e11 -- os.time() values (savedAt)
local SAVE_INTERVAL_SECONDS = 10 -- DataStores allow one write per key about every 6 seconds
local META_SAVE_INTERVAL_SECONDS = 60 -- the start menu summary is saved less often
local AUTOSAVE_CHECK_SECONDS = 60 -- safety net: anything still unsaved is scheduled again
local BUDGET_WAIT_SECONDS = 5 -- wait at most this for DataStore write budget before trying later
local LOAD_ATTEMPTS = 3
local LOAD_RETRY_SECONDS = 2
local CLOSE_BUDGET_SECONDS = 25 -- BindToClose has about 30 seconds
local TELEPORT_TIMEOUT_SECONDS = 30 -- still here after this: the trip failed, back to the menu
-- Stage 10 fix: private worlds (technical settings; the player limit is MissionData.MISSION.PLAYERS_MAX).
local WORLDS_MAP_NAME = "SBO_Worlds" -- MemoryStore hash map: owner UserId -> open world entry
local WORLD_ENTRY_EXPIRY_SECONDS = 120 -- an entry the world server stops refreshing disappears
local WORLD_REFRESH_SECONDS = 30 -- a friends world refreshes its entry this often
local WORLD_WRITE_DEBOUNCE_SECONDS = 2 -- player count changes are written at most this often
local RETRY_ATTEMPTS = 3 -- MemoryStore, friends list and teleport calls
local RETRY_SECONDS = 1 -- wait before retry n: RETRY_SECONDS * n
local WORLDS_REQUEST_INTERVAL = 10 -- ListFriendWorlds rate limit per player (MemoryStore quota)
local JOIN_REQUEST_INTERVAL = 2 -- JoinWorld rate limit per player
local MAX_FRIEND_PAGES = 5 -- friends list pages read (about 50 friends each)
local MAX_FRIEND_LOOKUPS = 40 -- registry reads per list (online friends first)
local BACK_TO_LOBBY_SECONDS = 4 -- a refused player reads C.A.R.L.'s line, then goes back to the menu
local SLOTS_REQUEST_INTERVAL = 1 -- RequestSlots rate limit per player
local PICKUP_DEBOUNCE_SECONDS = 1
local PICKUP_EXTRA_RANGE = 8 -- studs beyond the prompt's own range (lag), checked on the server
local MAX_SCANNED_KEYS = 200 -- damaged saves cannot grow without limit
local MAX_SCANNED_KEY_LENGTH = 48
local MAX_DATA_DEPTH = 4 -- base.quest nesting
local MAX_DATA_KEYS = 128 -- entries per table inside base.quest
local MAX_DATA_STRING = 64
local MAX_DATA_INDEX = 9999
-- Stage 11: session lock and settings (technical settings, not gameplay numbers).
local LOCK_TIMEOUT_SECONDS = 180 -- a lock not refreshed for this long is stale (its server is gone)
local LOCK_REFRESH_SECONDS = 45 -- an idle loaded slot is re-saved about this often (keeps its lock fresh)
local LOCK_WAIT_SECONDS = 20 -- a fresh lock of another visit: wait this long for its release, then steal it
local LOCK_RETRY_SECONDS = 2
local RELEASE_WAIT_SECONDS = 10 -- a lock release waits at most this for a slot write still running
local SETTINGS_PER_SECOND = 5 -- SaveSettings / SetLanguage requests per player
-- This server's id in session locks (game.JobId is empty in Studio).
local SERVER_ID: string = if game.JobId ~= "" then string.sub(game.JobId, 1, 64) else "studio-" .. HttpService:GenerateGUID(false)

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

-- Stage 10 fix: private worlds (see the header).
local MAX_WORLD_PLAYERS: number = MissionData.MISSION.PLAYERS_MAX
local role: Worlds.Role = "local"
local worldOwnerId: number? = nil -- world: fixed by the owner's trip; local: follows currentOwner
local worldMode: SlotMode = "friends"
local worldSlot: number? = nil
local worldCode: string? = nil -- world: the reserved server access code (owner's TeleportData)
local hostLeft = false -- world: the owner left; guests go back to the lobby
local closing = false
local currentOwner: Player? = nil -- the owner, while present with a loaded slot
local loadOrder: { Player } = {} -- local: players in the order their slots loaded
local ownerListeners: { () -> () } = {}
local worldStore: any = nil -- MemoryStoreHashMap (or a sorted map)
local worldStoreTried = false
local registryRunning = false
local registryWriteScheduled = false

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
-- Stage 10: false while the Studio probe read is running (readKey waits for it, at most
-- PROBE_TIMEOUT_SECONDS). Once decided the backend never switches to a DataStore again.
local backendDecided = true

local function waitForBackend()
	if backendDecided then
		return
	end
	local deadline = os.clock() + PROBE_TIMEOUT_SECONDS
	while not backendDecided and os.clock() < deadline do
		task.wait(0.1)
	end
	if not backendDecided then
		backendDecided = true -- a late probe answer is ignored: this session keeps memory
		print("[SpaceBaseOdyssey] Studio: DataStores did not answer in time; saves are in memory (lost when Play stops)")
	end
end

-- Studio, published place: one read decides between the DataStore and memory.
local function probeStudioBackend(dataStore: DataStore, storeName: string)
	backendDecided = false
	task.spawn(function()
		local ok, err = pcall(function()
			return dataStore:GetAsync(PROBE_KEY)
		end)
		if backendDecided then
			return -- timed out: memory was chosen already
		end
		if ok then
			backend = dataStoreBackend(dataStore)
			print(`[SpaceBaseOdyssey] Studio: saves use the DataStore "{storeName}" (they stay after Play stops)`)
		else
			print(`[SpaceBaseOdyssey] Studio: DataStores unavailable ({err}); saves are in memory (lost when Play stops)`)
		end
		backendDecided = true
	end)
end

-- Reads one key, with retries. Returns false when it could not be read. Studio without API access or
-- an unpublished place: DataStores are off for this session and memory is used from now on.
local function readKey(key: string, who: string): (boolean, any)
	waitForBackend()
	for attempt = 1, LOAD_ATTEMPTS do
		local source = backend
		local ok, data = pcall(source.get, key)
		if ok then
			return true, data
		end
		warn(`[SpaceBaseOdyssey] progress load attempt {attempt} failed for {who}: {data}`)
		local message = string.lower(tostring(data))
		if source.persistent and (string.find(message, "studio", 1, true) or string.find(message, "publish", 1, true)) then
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
		achievements = Achievements.emptyRecord(),
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
		achievements = Achievements.sanitizeRecord(value.achievements),
		silo = BaseBuild.sanitizeSiloSave(MissionData, value.silo, os.time()), -- Stage 11 tycoon
		daily = if value.daily ~= nil then Daily.sanitizeRecord(value.daily) else nil, -- Stage 11 daily
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
		achievements = Achievements.sanitizeRecord(base.achievements),
		silo = if base.silo then table.clone(base.silo) else nil, -- Stage 11 tycoon
		daily = if base.daily then Daily.cloneRecord(base.daily) else nil, -- Stage 11 daily
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
		merged.achievements = Achievements.mergeRecord(old.achievements, merged.achievements)
		-- Stage 11 tycoon: a silo this server never wrote (a guest in a friend's world) stays as stored.
		if merged.silo == nil then
			merged.silo = old.silo
		end
		-- Stage 11 daily: capsules, stripes and logbook entries never go back.
		if old.daily ~= nil or merged.daily ~= nil then
			merged.daily = Daily.mergeRecord(old.daily, merged.daily)
		end
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

-- params (Stage 10 fix): values for the text's {placeholders} (the world lines name a friend).
local function sayTo(player: Player, key: string, params: { [string]: string | number }?)
	if remotes and player.Parent then
		local text: Types.TextRef = { key = key, params = params }
		remotes.message:FireClient(player, text)
	end
end

-- Stage 10: tells one player their slot was saved (or that a "Save now" could not be).
local function sendSaved(player: Player, record: Record, ok: boolean, real: boolean, manual: boolean)
	local events = remotes
	local event = events and events.saved
	if event == nil or player.Parent == nil or records[player] ~= record then
		return -- a player who already left gets nothing
	end
	local notice: Types.SaveNotice = { ok = ok, real = real, manual = manual }
	event:FireClient(player, notice)
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
	return { slots = slots, last = nil, cosmetics = {}, settings = ServerGuard.defaultSettings(), settingsAt = 0 }
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
	-- Stage 11: settings (an older meta has none: defaults, never saved).
	meta.settings = ServerGuard.sanitizeSettings(value.settings)
	meta.settingsAt = if type(value.settingsAt) == "number" and value.settingsAt == value.settingsAt
		then math.clamp(math.floor(value.settingsAt), 0, MAX_STORED_TIME)
		else 0
	return meta
end

local function cloneMeta(meta: Meta): Meta
	local slots: { SlotSummary } = {}
	for i = 1, SLOT_COUNT do
		slots[i] = table.clone(meta.slots[i])
	end
	return {
		slots = slots,
		last = meta.last,
		cosmetics = table.clone(meta.cosmetics),
		settings = table.clone(meta.settings),
		settingsAt = meta.settingsAt,
	}
end

-- Another server may have saved another slot meanwhile: per slot, the newest summary wins.
-- Stage 11: the newest settings win too.
local function mergeMeta(old: Meta, ours: Meta): Meta
	local result = cloneMeta(ours)
	result.last = ours.last or old.last
	union(result.cosmetics, old.cosmetics)
	if old.settingsAt > ours.settingsAt then
		result.settings = table.clone(old.settings)
		result.settingsAt = old.settingsAt
	end
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
		settings = table.clone(record.settings), -- Stage 11
	}
	event:FireClient(player, view)
end

----------------------------------------------------------------------------------------------------
-- Stage 11: settings (see the header)

local SETTING_ATTRIBUTES: { [string]: string } = {
	musicVolume = "SBO_MusicVolume",
	effectsVolume = "SBO_EffectsVolume",
	funFacts = "SBO_FunFacts",
	guidance = "SBO_Guidance",
	-- Stage 11 menu: accessibility settings (same names as the client Store's SETTING_ATTRIBUTES).
	bigText = "SBO_BigText",
	reduceMotion = "SBO_ReduceMotion",
	colourHelper = "SBO_ColourHelper",
	messageSpeed = "SBO_MessageSpeed",
}

-- Mirrors the settings as player attributes (the client Store reads the same names). The language
-- attribute is only set once the player chose one.
local function publishSettings(player: Player, settings: ServerGuard.Settings)
	if player.Parent == nil then
		return
	end
	for name, attribute in SETTING_ATTRIBUTES do
		local value = (settings :: any)[name]
		if player:GetAttribute(attribute) ~= value then
			player:SetAttribute(attribute, value)
		end
	end
	if settings.language ~= nil and player:GetAttribute("Language") ~= settings.language then
		player:SetAttribute("Language", settings.language)
	end
end

-- Uses `settings` when they are newer than what this visit has (the meta read, or a trip's prefs).
local function adoptSettings(record: Record, settings: ServerGuard.Settings, at: number): boolean
	if at <= record.settingsAt then
		return false
	end
	record.settings = table.clone(settings)
	record.settingsAt = at
	return true
end

----------------------------------------------------------------------------------------------------
-- Saving

-- Stage 11: this visit lost its slot's lock (another server took it). Saving stops; a player still
-- here is asked to join again, so they play on the newest save.
local function onLockLost(player: Player, record: Record)
	if record.lockLost then
		return
	end
	record.lockLost = true
	record.lockHeld = false
	record.canSave = false
	record.dirty = false
	warn(`[SpaceBaseOdyssey] {player.Name}'s slot {record.slot} is locked by another server; this server stops saving it`)
	if records[player] == record and player.Parent ~= nil then
		local kickText = `{Localization.t("ui.world_kick", nil, "en")} / {Localization.t("ui.world_kick", nil, "es")}`
		task.defer(function()
			if player.Parent ~= nil then
				player:Kick(kickText)
			end
		end)
	end
end

-- Saves the chosen slot. `closing` = the server is closing (or the player left and the caller already
-- waited): no waiting for write budget here. Stage 11: the write only happens while this visit holds
-- the slot's lock (it refreshes the lock's time); `release` = the last save, it frees the lock.
local function save(player: Player, record: Record, closing: boolean?, release: boolean?)
	local slot = record.slot
	if slot == nil or record.state ~= "loaded" or not record.canSave or record.lockLost or not record.lockHeld then
		return -- Stage 11: no lock (lost, or freed by the last save): nothing more is written
	end
	if not closing and not waitForBudget(BUDGET_WAIT_SECONDS) then
		return -- still dirty: the autosave check schedules it again
	end
	record.dirty = false
	-- A SaveNow that arrives while this write runs waits for the next write (it may hold newer data).
	local manual = record.manualPending
	record.manualPending = false
	local quiet = record.quietSave and not manual
	record.quietSave = false
	savesInFlight += 1
	local completed = table.clone(record.completed)
	local collectibles = table.clone(record.collectibles)
	local cosmetics = table.clone(record.cosmetics)
	local base = cloneBase(record.base)
	local reset = record.baseReset
	local replaceAll = record.replaceAll
	local source = backend
	-- Stage 10: also stamped when the write starts, so a SaveNow during a running write waits
	-- MANUAL_SAVE_SPACING from this write instead of writing the same key again at once.
	record.lastSaveAt = os.clock()
	local token = record.lockToken
	local stamp = os.time()
	local lost = false
	record.savingNow += 1
	-- Stage 11 review: a regular save of a player still here may take a missing lock back (an older
	-- server version saved the slot without one); a final save never does (ServerGuard.canWrite).
	local allowFree = not release and records[player] == record and player.Parent ~= nil
	local ok, err = pcall(source.update, slotKey(player, slot), function(old: any): any
		-- Stage 11: never write a slot whose lock another visit holds now.
		if not ServerGuard.canWrite(if type(old) == "table" then old.lock else nil, SERVER_ID, token, allowFree) then
			lost = true
			return nil -- cancels the write
		end
		lost = false
		local stored = if replaceAll or type(old) ~= "table" then nil else old
		local merged = {
			v = DATA_VERSION,
			completed = sanitizeSet(stored and stored.completed, isMissionId),
			collectibles = sanitizeSet(stored and stored.collectibles, Missions.isCollectible),
			cosmetics = sanitizeSet(stored and stored.cosmetics, Codes.isCosmetic),
			base = storableBase(
				mergeBase(stored and stored.base, base, reset or replaceAll, versionOf(stored) < HABITAT_TREE_VERSION)
			),
			lock = if release then nil else { job = SERVER_ID, token = token, at = stamp },
		}
		union(merged.completed, completed)
		union(merged.collectibles, collectibles)
		union(merged.cosmetics, cosmetics)
		return merged
	end)
	savesInFlight -= 1
	record.savingNow -= 1
	record.lastSaveAt = os.clock()
	if ok and lost then
		onLockLost(player, record)
		if manual then
			sendSaved(player, record, false, source.persistent, true)
		end
		return
	end
	if ok then
		record.lockAt = stamp
		if release then
			record.lockHeld = false
		end
	end
	if not ok then
		record.dirty = true
		warn(`[SpaceBaseOdyssey] could not save slot {slot} for {player.Name}: {err}`)
		if manual then
			sendSaved(player, record, false, source.persistent, true)
		end
		return
	end
	if reset then
		record.baseReset = false
	end
	if replaceAll then
		record.replaceAll = false
	end
	if quiet then
		return -- a lock refresh: the start menu summary and the save pill stay as they are
	end
	record.meta.slots[slot] = summaryOf(record.base, record.mode or "solo")
	record.metaDirty = true
	sendSaved(player, record, true, source.persistent, manual)
end

-- Stage 11: the player left (or the server closes) with nothing left to save: free the slot's lock so
-- their next server loads it at once. Only this visit's own lock is removed.
local function releaseLock(player: Player, record: Record)
	-- A slot write still running must land first (it needs the lock; it may hold the newest data).
	local deadline = os.clock() + RELEASE_WAIT_SECONDS
	while record.savingNow > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	local slot = record.slot
	if slot == nil or not record.lockHeld or record.lockLost or record.savingNow > 0 then
		return
	end
	record.lockHeld = false
	local token = record.lockToken
	savesInFlight += 1
	local ok, err = pcall(backend.update, slotKey(player, slot), function(old: any): any
		if type(old) ~= "table" or not ServerGuard.canWrite(old.lock, SERVER_ID, token) then
			return nil
		end
		old.lock = nil
		return old
	end)
	savesInFlight -= 1
	if not ok then
		warn(`[SpaceBaseOdyssey] could not release the lock of slot {slot} for {player.Name}: {err}`)
	end
end

-- Stage 11: the last write for a record (leaving, or the server closing): the slot when it changed
-- (that write frees the lock), else only the lock. A failed write keeps the lock: the next server
-- waits LOCK_WAIT_SECONDS for it, then takes it.
local function finalSave(player: Player, record: Record)
	if record.dirty and record.slot ~= nil and record.state == "loaded" and record.canSave and not record.lockLost then
		save(player, record, true, true)
	elseif record.lockHeld then
		releaseLock(player, record)
	end
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

-- Saves soon, at most once every SAVE_INTERVAL_SECONDS per player (`spacing` overrides it: SaveNow
-- uses MANUAL_SAVE_SPACING, the DataStore's own limit).
local function requestSave(player: Player, record: Record, spacing: number?)
	record.dirty = true
	record.quietSave = false -- Stage 11: real changes: this write is a normal save
	if record.saveScheduled or not record.canSave or record.state ~= "loaded" then
		return
	end
	record.saveScheduled = true
	local delay = math.max(0, record.lastSaveAt + (spacing or SAVE_INTERVAL_SECONDS) - os.clock())
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

-- Stage 10: the SaveNow action. Only for a loaded slot; extra requests within
-- SAVE_NOW_REQUEST_INTERVAL are ignored. The write happens as soon as the DataStore allows (an
-- autosave already on its way, at most SAVE_INTERVAL_SECONDS away, carries it instead); the notice of
-- that write says manual = true. A slot that could not be read is never written: the player is told.
local function requestSaveNow(player: Player, record: Record)
	local t = os.clock()
	if t - record.lastSaveNowAt < SAVE_NOW_REQUEST_INTERVAL then
		return
	end
	record.lastSaveNowAt = t
	if record.slot == nil or record.state ~= "loaded" then
		return -- start menu, a solo trip or a slot still loading: nothing to save yet
	end
	if not record.canSave then
		sendSaved(player, record, false, backend.persistent, true)
		return
	end
	record.manualPending = true
	requestSave(player, record, MANUAL_SAVE_SPACING)
end

-- Stage 11: SaveSettings (and SetLanguage) on the start menu or in play. At most SETTINGS_PER_SECOND
-- requests a second per player; bad fields are dropped and volumes clamped (ServerGuard). Kept in the
-- meta record (saved within MANUAL_SAVE_SPACING, and on leave) and mirrored as player attributes.
local function requestSettings(player: Player, record: Record, patch: any)
	if not ServerGuard.allowInWindow(record.settingsTimes, os.clock(), 1, SETTINGS_PER_SECOND) then
		return
	end
	local settings, changed = ServerGuard.applySettings(record.settings, patch)
	if not changed then
		return
	end
	record.settings = settings
	record.settingsAt = math.max(os.time(), record.settingsAt + 1)
	publishSettings(player, settings)
	if record.metaReady then
		record.meta.settings = table.clone(settings)
		record.meta.settingsAt = record.settingsAt
		requestMetaSave(player, record, MANUAL_SAVE_SPACING)
	end -- not read yet: the meta read keeps these (they are newer)
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
-- Player attributes and retries

local function setAttribute(player: Player, name: string, value: any)
	if player.Parent then
		player:SetAttribute(name, value)
	end
end

-- Runs `fn` up to RETRY_ATTEMPTS times (waiting a little longer each time). Every failure is logged.
local function retry(label: string, fn: () -> ...any): (boolean, any)
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[SpaceBaseOdyssey] {label}: attempt {attempt} of {RETRY_ATTEMPTS} failed: {result}`)
		if attempt < RETRY_ATTEMPTS then
			task.wait(RETRY_SECONDS * attempt)
		end
	end
	return false, nil
end

----------------------------------------------------------------------------------------------------
-- Stage 10 fix: world owner, registry and trips

local function playerById(userId: number?): Player?
	if userId == nil then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	return if player and records[player] then player else nil
end

-- Players who may stay in this world (owner and accepted friends). Lobby and local servers count
-- every player with a loaded or loading slot.
local function playersInWorld(except: Player?): number
	local count = 0
	for player, record in records do
		if player ~= except and player.Parent ~= nil and not record.rejected then
			if role == "world" then
				if record.accepted then
					count += 1
				end
			elseif record.state == "loading" or record.state == "loaded" then
				count += 1
			end
		end
	end
	return count
end

-- The owner now: world servers, the player of the owner's trip once their slot is loaded; local
-- servers, the first player in load order who is still here (Worlds.pickOwner).
local function ownerCandidate(): Player?
	if role == "world" then
		local owner = playerById(worldOwnerId)
		local record = if owner then records[owner] else nil
		return if owner and record and record.loaded then owner else nil
	end
	local ids: { number } = {}
	for _, player in loadOrder do
		local record = records[player]
		if record and record.loaded and player.Parent ~= nil then
			table.insert(ids, player.UserId)
		end
	end
	return playerById(Worlds.pickOwner(if currentOwner then currentOwner.UserId else nil, ids))
end

local function refreshOwner()
	local owner = ownerCandidate()
	if role ~= "world" then
		worldOwnerId = if owner then owner.UserId else nil
	end
	for player, record in records do
		record.guest = record.loaded and owner ~= nil and player ~= owner
		setAttribute(player, "SBO_Guest", record.guest)
	end
	workspace:SetAttribute("SBO_WorldOwner", worldOwnerId)
	if owner == currentOwner then
		return
	end
	currentOwner = owner
	if owner then
		print(`[SpaceBaseOdyssey] world owner: {owner.Name} ({role} server)`)
	end
	for _, listener in ownerListeners do
		task.spawn(function()
			local ok, err = pcall(listener)
			if not ok then
				warn(`[SpaceBaseOdyssey] world owner listener failed: {err}`)
			end
		end)
	end
end

-- The registry (MemoryStore hash map; a sorted map has the same calls we use). nil when MemoryStores
-- are not available: then nobody can find friends worlds, everything else works.
local function getWorldStore(): any
	if worldStore == nil and not worldStoreTried then
		worldStoreTried = true
		local ok, map = pcall(function(): any
			return (MemoryStoreService :: any):GetHashMap(WORLDS_MAP_NAME)
		end)
		if not ok or map == nil then
			warn(`[SpaceBaseOdyssey] MemoryStore hash map unavailable ({map}); trying a sorted map`)
			ok, map = pcall(function(): any
				return MemoryStoreService:GetSortedMap(WORLDS_MAP_NAME)
			end)
		end
		if ok and map ~= nil then
			worldStore = map
		else
			warn(`[SpaceBaseOdyssey] MemoryStores unavailable, friends cannot find open worlds: {map}`)
		end
	end
	return worldStore
end

-- The open world of `ownerId` (nil when closed, stale or unreadable). quick = one attempt only (the
-- friends list reads many keys; a join retries).
local function readWorld(ownerId: number, quick: boolean?): Worlds.Entry?
	local store = getWorldStore()
	if store == nil then
		return nil
	end
	local function read(): any
		return (store.GetAsync(store, tostring(ownerId)))
	end
	local ok, value
	if quick then
		ok, value = pcall(read)
		if not ok then
			warn(`[SpaceBaseOdyssey] read world of {ownerId} failed: {value}`)
		end
	else
		ok, value = retry(`read world of {ownerId}`, read)
	end
	if not ok then
		return nil
	end
	return Worlds.sanitizeEntry(value, os.time(), MAX_WORLD_PLAYERS)
end

local function writeRegistry()
	if role ~= "world" or worldMode ~= "friends" or hostLeft or closing or worldCode == nil or worldOwnerId == nil then
		return
	end
	local owner = currentOwner
	local record = if owner then records[owner] else nil
	if owner == nil or record == nil or owner.UserId ~= worldOwnerId then
		return
	end
	local store = getWorldStore()
	if store == nil then
		return
	end
	local entry: Worlds.Entry = {
		owner = worldOwnerId :: number,
		code = worldCode :: string,
		mode = worldMode,
		slot = worldSlot or 1,
		players = playersInWorld(nil),
		max = MAX_WORLD_PLAYERS,
		baseLevel = BaseBuild.levelOf(record.base.builds, "habitat"),
		name = string.sub(owner.DisplayName, 1, Worlds.MAX_NAME_LENGTH),
		updatedAt = os.time(),
	}
	local key = tostring(worldOwnerId)
	retry("register the friends world", function()
		store.SetAsync(store, key, entry, WORLD_ENTRY_EXPIRY_SECONDS)
	end)
end

local function unregisterWorld()
	if role ~= "world" or worldMode ~= "friends" or worldOwnerId == nil or worldStore == nil then
		return
	end
	local store = worldStore
	local key = tostring(worldOwnerId)
	retry("remove the friends world", function()
		store.RemoveAsync(store, key)
	end)
end

-- A player count change: write the entry soon (at most every WORLD_WRITE_DEBOUNCE_SECONDS).
local function requestRegistryWrite()
	if not registryRunning or registryWriteScheduled then
		return
	end
	registryWriteScheduled = true
	task.delay(WORLD_WRITE_DEBOUNCE_SECONDS, function()
		registryWriteScheduled = false
		writeRegistry()
	end)
end

-- The owner's friends world is loaded: keep its entry fresh until the owner leaves or it closes.
local function startRegistry()
	if registryRunning or role ~= "world" or worldMode ~= "friends" then
		return
	end
	if worldCode == nil then
		warn("[SpaceBaseOdyssey] friends world without its access code: friends cannot join it")
		return
	end
	registryRunning = true
	task.spawn(function()
		while not hostLeft and not closing do
			writeRegistry()
			task.wait(WORLD_REFRESH_SECONDS)
		end
	end)
end

-- Sends a player back to the lobby (a public server) with a notice the start menu shows. C.A.R.L.
-- says why first; `before` (optional) runs just before the teleport (saving a guest's slot). If the
-- teleport keeps failing the player is kicked: a refused player must never stay in a private world.
local function sendToLobby(player: Player, notice: string, before: (() -> ())?)
	local record = records[player]
	if record then
		record.rejected = true
	end
	sayTo(player, `carl.world.{notice}`)
	setAttribute(player, "SBO_WorldNotice", notice)
	task.delay(BACK_TO_LOBBY_SECONDS, function()
		if before then
			local ok, err = pcall(before)
			if not ok then
				warn(`[SpaceBaseOdyssey] before going back to the lobby: {err}`)
			end
		end
		if player.Parent == nil then
			return
		end
		local ok = retry(`send {player.Name} back to the lobby`, function()
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({ notice = notice })
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		local kickText = `{Localization.t("ui.world_kick", nil, "en")} / {Localization.t("ui.world_kick", nil, "es")}`
		if not ok then
			if player.Parent ~= nil then
				player:Kick(kickText)
			end
			return
		end
		-- The teleport can still fail after it started (TeleportInitFailed): still here later = kicked.
		task.delay(TELEPORT_TIMEOUT_SECONDS, function()
			if player.Parent ~= nil then
				warn(`[SpaceBaseOdyssey] {player.Name} is still in this world after being sent back; kicking`)
				player:Kick(kickText)
			end
		end)
	end)
end

-- World servers: may this arrival stay? Fixes the world's owner from the first owner trip. Yields
-- (the friends check). Returns false and a Worlds reason (or "private") when refused.
local function admit(player: Player, record: Record, arrival: Worlds.Arrival?): (boolean, string?)
	if arrival == nil then
		return false, "private" -- no valid trip: nobody walks into a private world
	end
	if not arrival.guest then
		if worldOwnerId == nil then
			worldOwnerId = arrival.owner
			worldMode = arrival.mode
			worldSlot = arrival.slot
			worldCode = arrival.code
			workspace:SetAttribute("SBO_WorldOwner", worldOwnerId)
			workspace:SetAttribute("SBO_WorldMode", worldMode)
			print(`[SpaceBaseOdyssey] world of {player.Name}: slot {arrival.slot}, {arrival.mode}`)
		elseif worldOwnerId ~= player.UserId then
			return false, "private"
		end
		if hostLeft then
			return false, "closed"
		end
		record.accepted = true
		return true, nil
	end
	if worldOwnerId == nil or arrival.owner ~= worldOwnerId then
		return false, "closed"
	end
	local ownerId = worldOwnerId :: number
	local ok, friend = retry(`friends check for {player.Name}`, function(): any
		return player:IsFriendsWith(ownerId)
	end)
	if records[player] ~= record then
		return false, nil -- left meanwhile
	end
	if hostLeft then
		return false, "host_left"
	end
	-- Counted after the yield, then marked at once: two friends arriving together never both take the
	-- last place.
	local allowed, reason = Worlds.canJoin(
		{ owner = ownerId, mode = worldMode, players = playersInWorld(player) },
		player.UserId,
		ok and friend == true,
		MAX_WORLD_PLAYERS
	)
	if allowed then
		record.accepted = true
	end
	return allowed, reason
end

-- The TeleportData this player arrived with (world servers only), checked.
local function arrivalOf(player: Player): Worlds.Arrival?
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
	return Worlds.sanitizeArrival(joinData.TeleportData, player.UserId, SLOT_COUNT)
end

-- Stage 11: the settings a trip carried (TeleportData.prefs), checked; nil when there are none.
local function arrivalPrefsOf(player: Player): { settings: ServerGuard.Settings, at: number }?
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
	local prefs = if type(data) == "table" then data.prefs else nil
	if type(prefs) ~= "table" or type(prefs.at) ~= "number" or prefs.at ~= prefs.at then
		return nil
	end
	-- A time far in the future would keep these settings forever: at most now.
	local at = math.clamp(math.floor(prefs.at), 0, os.time())
	if at <= 0 then
		return nil
	end
	return { settings = ServerGuard.sanitizeSettings(prefs), at = at }
end

----------------------------------------------------------------------------------------------------
-- Loading a slot, and trips from the lobby

-- Stage 11: one UpdateAsync with retries (like readKey). False when it could not be written.
local function updateKey(key: string, who: string, transform: (old: any) -> any): boolean
	waitForBackend()
	for attempt = 1, LOAD_ATTEMPTS do
		local source = backend
		local ok, err = pcall(source.update, key, transform)
		if ok then
			return true
		end
		warn(`[SpaceBaseOdyssey] slot lock attempt {attempt} failed for {who}: {err}`)
		local message = string.lower(tostring(err))
		if source.persistent and (string.find(message, "studio", 1, true) or string.find(message, "publish", 1, true)) then
			backend = memoryBackend
			warn("[SpaceBaseOdyssey] DataStores unavailable, progress kept in memory for this session")
			local memoryOk = pcall(memoryBackend.update, key, transform)
			return memoryOk
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_SECONDS)
		end
	end
	return false
end

-- Stage 11: reads the slot and takes its session lock in the same write. Waits while another visit
-- holds a fresh lock (its last save may still be on its way), at most LOCK_WAIT_SECONDS, then steals
-- it. Returns false when the slot could not be read, else true and the stored record (nil when empty;
-- the lock itself is not data).
local function acquireSlot(player: Player, record: Record, slot: number): (boolean, any)
	local key = slotKey(player, slot)
	local token = HttpService:GenerateGUID(false)
	record.lockToken = token
	local deadline = os.clock() + LOCK_WAIT_SECONDS
	local waitedLogged = false
	while true do
		local force = os.clock() >= deadline
		local seen: any = nil
		local waiting = false
		local stamp = os.time()
		local ok = updateKey(key, player.Name, function(old: any): any
			seen = old
			local stored = if type(old) == "table" then old else nil
			local decision = ServerGuard.lockDecision(stored and stored.lock, SERVER_ID, token, stamp, LOCK_TIMEOUT_SECONDS)
			if decision == "wait" and not force then
				waiting = true
				return nil -- no write: try again in a moment
			end
			waiting = false
			local new = stored or { v = DATA_VERSION }
			new.lock = { job = SERVER_ID, token = token, at = stamp }
			return new
		end)
		if records[player] ~= record then
			-- Left while loading. Stage 11 review: a lock this visit just wrote is freed again, so the
			-- player's next server does not wait LOCK_WAIT_SECONDS for it.
			if ok and not waiting then
				record.lockHeld = true
				task.spawn(releaseLock, player, record)
			end
			return false, nil
		end
		if not ok then
			return false, nil
		end
		if not waiting then
			if force then
				warn(`[SpaceBaseOdyssey] slot {slot} of {player.Name} was still locked by another server; lock taken over`)
			end
			record.lockHeld = true
			record.lockAt = stamp
			local data = if type(seen) == "table" then seen else nil
			if data and ServerGuard.isEmptySlotRecord(data) then
				data = nil
			end
			return true, data
		end
		if not waitedLogged then
			waitedLogged = true
			print(`[SpaceBaseOdyssey] slot {slot} of {player.Name} is still saving on another server; waiting`)
		end
		task.wait(LOCK_RETRY_SECONDS)
		if records[player] ~= record then
			return false, nil
		end
	end
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
	record.trip = nil
	setAttribute(player, "SBO_SlotLoading", true)

	local stored: any = nil
	local canSave = false
	local fromLegacy = false
	-- Stage 11: every load (New game too) takes the slot's session lock first; that write also reads
	-- the slot.
	local lockOk, data = acquireSlot(player, record, slot)
	if records[player] ~= record then
		return -- left while loading
	end
	if choice.fresh then
		-- New Game (only an explicit fresh = true): what was read is dropped, the first save replaces
		-- the slot.
		canSave = lockOk
		record.replaceAll = true
	else
		local ok = lockOk
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
	base.achievements = Achievements.mergeRecord(base.achievements, earned.achievements)
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

	-- Stage 10 fix: who owns this world (before anyone hears about the load).
	if role ~= "world" then
		table.insert(loadOrder, player)
	end
	refreshOwner()
	if role == "world" and player.UserId == worldOwnerId then
		startRegistry()
	end
	requestRegistryWrite()

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
	local owner = currentOwner
	if record.guest and owner then
		sayTo(player, "carl.world.guest_welcome", { name = owner.DisplayName })
		sayTo(owner, "carl.world.friend_joined", { name = player.DisplayName })
	end
end

-- A trip from the lobby did not happen: back to the start menu (it never loads in the lobby, where
-- anybody could walk in). The client shows `reason` (attributes SBO_TripFailedReason, SBO_TripFailed).
local function tripFailed(player: Player, record: Record, token: number, reason: string)
	if records[player] ~= record or record.state ~= "teleporting" or record.teleportToken ~= token then
		return
	end
	record.state = "menu"
	record.teleportChoice = nil
	record.trip = nil
	setAttribute(player, "SBO_SlotLoading", false)
	setAttribute(player, "SBO_TripFailedReason", reason)
	setAttribute(player, "SBO_TripFailed", (tonumber(player:GetAttribute("SBO_TripFailed")) or 0) + 1)
	sendSlots(player, record)
end

-- One teleport attempt of the current trip (retried on errors, up to RETRY_ATTEMPTS).
local function teleportTrip(player: Player, record: Record, token: number)
	local trip = record.trip
	if records[player] ~= record or record.state ~= "teleporting" or record.teleportToken ~= token or trip == nil then
		return
	end
	trip.attempts += 1
	local attempt = trip.attempts
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = trip.code
		options:SetTeleportData(trip.data)
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] world trip for {player.Name}: attempt {attempt} of {RETRY_ATTEMPTS} failed: {err}`)
		if attempt < RETRY_ATTEMPTS then
			task.delay(RETRY_SECONDS * attempt, teleportTrip, player, record, token)
		else
			tripFailed(player, record, token, if trip.join then "closed" else "failed")
		end
		return
	end
	task.delay(TELEPORT_TIMEOUT_SECONDS, function()
		if record.trip == trip and trip.attempts == attempt then
			warn(`[SpaceBaseOdyssey] world trip for {player.Name} timed out`)
			tripFailed(player, record, token, "failed")
		end
	end)
end

-- Lobby: takes the player to a world server. join = into a friend's open world; otherwise a new
-- reserved server for the player's own world.
local function startTrip(player: Player, record: Record, choice: Choice, join: { owner: number, code: string }?)
	record.state = "teleporting"
	record.teleportChoice = choice
	record.teleportToken += 1
	local token = record.teleportToken
	setAttribute(player, "SBO_SlotLoading", true)
	local code: string
	local data: { [string]: any }
	if join then
		code = join.code
		data = { owner = join.owner, guest = true, slot = choice.slot, mode = "friends", fresh = choice.fresh }
	else
		local ok, reserved = retry(`reserve a world server for {player.Name}`, function(): any
			return (TeleportService:ReserveServer(game.PlaceId))
		end)
		if records[player] ~= record or record.teleportToken ~= token then
			return
		end
		if not ok or type(reserved) ~= "string" then
			tripFailed(player, record, token, "failed")
			return
		end
		code = reserved
		data = { owner = player.UserId, slot = choice.slot, mode = choice.mode, fresh = choice.fresh, code = reserved }
	end
	-- Stage 11: the player's settings travel along (the meta write may land after the world reads it).
	if record.settingsAt > 0 then
		local prefs: { [string]: any } = table.clone(record.settings) :: any
		prefs.at = record.settingsAt
		data.prefs = prefs
	end
	record.trip = { code = code, data = data, attempts = 0, join = join ~= nil }
	teleportTrip(player, record, token)
end

local function applyChoice(player: Player, record: Record, choice: Choice)
	if record.state ~= "menu" then
		return
	end
	if not record.metaReady then
		record.pendingChoice = choice -- handled once the slot list is read
		return
	end
	-- Stage 11: only an explicit New game wipes a slot. "Continue" on a slot the meta lists as unused
	-- reads it like any other (an empty record starts a new explorer; data the meta missed is kept and
	-- the summary repaired), because the meta key is written less often than the slot.
	local final: Choice = { slot = choice.slot, mode = choice.mode, fresh = choice.fresh == true, guest = choice.guest }
	if role == "lobby" then
		startTrip(player, record, final, nil) -- Stage 10 fix: never load a world in the public lobby
		return
	end
	if role == "local" and playersInWorld(player) >= MAX_WORLD_PLAYERS then
		sayTo(player, "carl.world.full")
		record.state = "teleporting" -- tripFailed's own checks: back to the menu with the reason
		record.teleportToken += 1
		tripFailed(player, record, record.teleportToken, "full")
		return
	end
	loadSlot(player, record, final)
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
		pendingChoice = nil,
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
		manualPending = false,
		lastSaveNowAt = -math.huge,
		trip = nil,
		guest = false,
		accepted = role ~= "world",
		rejected = false,
		lastWorldsRequestAt = -math.huge,
		lastJoinAt = -math.huge,
		connections = {},
		lockToken = "",
		lockHeld = false,
		lockLost = false,
		lockAt = 0,
		savingNow = 0,
		quietSave = false,
		settings = ServerGuard.defaultSettings(),
		settingsAt = 0,
		settingsTimes = {},
		arrivalPrefs = nil,
	}
	records[player] = record
	-- Stage 10 fix: a world server only takes players its owner's trip allows (see the header).
	local arrival = if role == "world" then arrivalOf(player) else nil
	-- Stage 11: settings from the trip (shown at once; the meta read below may have newer ones).
	if role == "world" then
		local prefs = arrivalPrefsOf(player)
		if prefs and adoptSettings(record, prefs.settings, prefs.at) then
			record.arrivalPrefs = prefs
			publishSettings(player, record.settings)
		end
	end
	if role == "world" then
		setAttribute(player, "SBO_SlotLoading", true) -- arrived for a world: no start menu here
		setAttribute(player, "SBO_Guest", arrival ~= nil and arrival.guest)
	end

	task.spawn(function()
		if role == "world" then
			local allowed, reason = admit(player, record, arrival)
			if records[player] ~= record then
				return
			end
			if not allowed or arrival == nil then
				warn(`[SpaceBaseOdyssey] {player.Name} may not stay in this world ({reason or "left"}); back to the lobby`)
				sendToLobby(player, reason or "private")
				return
			end
			record.pendingChoice = { slot = arrival.slot, mode = arrival.mode, fresh = arrival.fresh, guest = arrival.guest }
			requestRegistryWrite()
		end
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
		-- Stage 11: the newest settings win (the meta's, or ones changed or carried here meanwhile).
		local settingsNewerHere = record.settingsAt > meta.settingsAt
		if not settingsNewerHere then
			adoptSettings(record, meta.settings, meta.settingsAt)
		else
			meta.settings = table.clone(record.settings)
			meta.settingsAt = record.settingsAt
		end
		record.meta = meta
		record.metaCanSave = canSave
		record.metaReady = true
		publishSettings(player, record.settings)
		if not canSave then
			warn(`[SpaceBaseOdyssey] slot list for {player.Name} could not be read; saving is off this session`)
		end
		if migrated or next(record.cosmetics) ~= nil or settingsNewerHere then
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
	local index = table.find(loadOrder, player)
	if index then
		table.remove(loadOrder, index)
	end
	-- Stage 10 fix: the owner left their world server. Nobody may stay without them: every guest's
	-- slot is saved and they go back to the lobby (the server then closes).
	local ownerLeft = role == "world" and record.accepted and player.UserId == worldOwnerId and not hostLeft
	if ownerLeft then
		hostLeft = true
		task.spawn(unregisterWorld)
		for other, otherRecord in records do
			if not otherRecord.rejected then
				sendToLobby(other, "host_left", function()
					if records[other] == otherRecord and otherRecord.dirty then
						save(other, otherRecord)
					end
					if records[other] == otherRecord and otherRecord.metaDirty then
						saveMeta(other, otherRecord)
					end
				end)
			end
		end
	end
	refreshOwner()
	if not ownerLeft and record.guest then
		local owner = currentOwner
		if owner and record.loaded then
			sayTo(owner, "carl.world.friend_left", { name = player.DisplayName })
		end
	end
	requestRegistryWrite()
	refreshWorldRewards()
	notifyChanged()
	-- Stage 10: counted as a save in flight from the start (save() may first wait for write budget),
	-- so BindToClose never lets the server close before the leaving player's slot is written. This is
	-- what keeps a reserved solo server's save: it closes as soon as its only player leaves.
	savesInFlight += 1
	-- No autosave retries this record any more: wait a little for write budget, then write anyway
	-- (a DataStore queues a request without budget instead of dropping it).
	-- Budget is only waited for when save() / saveMeta() will really write (a player leaving from the
	-- start menu or during a solo teleport has no loaded slot, and must not hold a closing server).
	local ok, err = pcall(function()
		-- Stage 11: the last write also frees the slot's session lock (a lock-only write when nothing
		-- changed), so the player's next server loads the slot at once.
		if record.lockHeld or (record.dirty and record.slot ~= nil and record.state == "loaded" and record.canSave) then
			waitForBudget(BUDGET_WAIT_SECONDS)
			finalSave(player, record)
		end
		if record.metaDirty and record.metaReady and record.metaCanSave then
			waitForBudget(BUDGET_WAIT_SECONDS)
			saveMeta(player, record)
		end
	end)
	savesInFlight -= 1
	if not ok then
		warn(`[SpaceBaseOdyssey] saving on leave failed for {player.Name}: {err}`)
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

	-- Stage 10: which backend this server uses (see the header). One log line says which.
	local studio = RunService:IsStudio()
	local studioSetting = workspace:GetAttribute(STUDIO_DATASTORE_ATTRIBUTE)
	local storeName: string? = STORE_NAME
	if studio then
		if studioSetting == false then
			storeName = nil
			print(`[SpaceBaseOdyssey] Studio: {STUDIO_DATASTORE_ATTRIBUTE} = false, saves are in memory (lost when Play stops)`)
		elseif studioSetting == true then
			storeName = STORE_NAME
			-- Stage 11: debug keys work in Studio, so their credits would reach real saves.
			warn(`[SpaceBaseOdyssey] Studio is using the LIVE DataStore "{STORE_NAME}": debug keys change real saves`)
		elseif game.PlaceId == 0 then
			storeName = nil
			print("[SpaceBaseOdyssey] Studio: place not published, saves are in memory (lost when Play stops)")
		else
			storeName = STUDIO_STORE_NAME
		end
	end
	if storeName then
		local name = storeName
		local ok, result = pcall(function(): DataStore
			return DataStoreService:GetDataStore(name)
		end)
		if not ok or result == nil then
			warn(`[SpaceBaseOdyssey] DataStores unavailable, saves are in memory for this session: {result}`)
		elseif studio then
			probeStudioBackend(result, name) -- decides before the first slot is read
		else
			backend = dataStoreBackend(result)
			print(`[SpaceBaseOdyssey] saves use the DataStore "{name}"`)
		end
	end

	-- Stage 10: Remotes.SAVED (Types.SaveNotice) and, Stage 10 fix, Remotes.WORLDS (Types.FriendWorlds).
	-- Main.server may pass them; otherwise they are made here, in the same folder as the other remotes.
	local function ensureRemote(name: string, purpose: string): RemoteEvent?
		local folder = ReplicatedStorage:FindFirstChild(Types.Remotes.FOLDER)
		if folder == nil then
			warn(`[SpaceBaseOdyssey] no Remotes folder: {purpose}`)
			return nil
		end
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing :: RemoteEvent
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	if remoteEvents.saved == nil then
		remoteEvents.saved = ensureRemote(Types.Remotes.SAVED, "players are not told when their game is saved")
	end
	if remoteEvents.worlds == nil then
		remoteEvents.worlds = ensureRemote(Types.Remotes.WORLDS, "the Join a friend list is off")
	end

	-- Stage 10 fix: this server's role (lobby, world or local; see the header).
	role = Worlds.serverRole(studio, game.PlaceId, game.PrivateServerId, game.PrivateServerOwnerId)
	workspace:SetAttribute("SBO_WorldRole", role)
	print(`[SpaceBaseOdyssey] server role: {role} (worlds hold at most {MAX_WORLD_PLAYERS} players)`)

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
			elseif action.type == "SaveNow" then
				local record = records[player]
				if record then
					requestSaveNow(player, record)
				end
			elseif action.type == "SaveSettings" or action.type == "SetLanguage" then
				-- Stage 11: settings kept in the meta record (SetLanguage: MissionService also sets the
				-- Language attribute, as before).
				local record = records[player]
				if record then
					local patch = if action.type == "SetLanguage" then { language = action.language } else action.settings
					local ok, err = pcall(requestSettings, player, record, patch)
					if not ok then
						warn(`[SpaceBaseOdyssey] SaveSettings failed: {err}`)
					end
				end
			elseif action.type == "ListFriendWorlds" then
				task.spawn(function()
					local ok, err = pcall(ProgressService.listFriendWorlds, player)
					if not ok then
						warn(`[SpaceBaseOdyssey] ListFriendWorlds failed: {err}`)
					end
				end)
			elseif action.type == "JoinWorld" then
				task.spawn(function()
					local ok, err = pcall(ProgressService.joinWorld, player, action.owner, action.slot)
					if not ok then
						warn(`[SpaceBaseOdyssey] JoinWorld failed: {err}`)
					end
				end)
			end
		end)
	end

	-- Stage 10 fix: a world trip Roblox could not start. A full world is said so; other failures are
	-- retried (RETRY_ATTEMPTS in all), then the player is back on the start menu.
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		local record = records[player]
		local trip = if record then record.trip else nil
		if record == nil or record.state ~= "teleporting" or trip == nil then
			return
		end
		warn(`[SpaceBaseOdyssey] world trip for {player.Name} failed ({result.Name}): {message}`)
		local token = record.teleportToken
		if result == Enum.TeleportResult.GameFull then
			tripFailed(player, record, token, "full")
		elseif trip.attempts < RETRY_ATTEMPTS then
			task.delay(RETRY_SECONDS * trip.attempts, teleportTrip, player, record, token)
		else
			tripFailed(player, record, token, if trip.join then "closed" else "failed")
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
				elseif record.lockHeld and record.canSave and not record.saveScheduled
					and os.time() - record.lockAt >= LOCK_REFRESH_SECONDS
				then
					requestSave(player, record) -- Stage 11: keeps an idle player's slot lock fresh
					record.quietSave = true
				end
				if record.metaDirty and not record.metaSaveScheduled then
					requestMetaSave(player, record)
				end
			end
		end
	end)

	-- Save what is still unsaved, and wait for saves already running (PlayerRemoving starts them too).
	game:BindToClose(function()
		closing = true
		if role == "world" and not hostLeft then
			savesInFlight += 1 -- the registry entry goes too (friends stop seeing a closed world)
			task.spawn(function()
				pcall(unregisterWorld)
				savesInFlight -= 1
			end)
		end
		for player, record in records do
			task.spawn(function()
				finalSave(player, record) -- Stage 11: frees the session lock too
				if record.metaDirty then
					saveMeta(player, record)
				end
			end)
		end
		-- Studio: Stop must not hang (memory saves are instant; a DataStore write takes well under a
		-- second). Live servers have about 30 seconds.
		local budget = if RunService:IsStudio() then CLOSE_BUDGET_STUDIO_SECONDS else CLOSE_BUDGET_SECONDS
		local deadline = os.clock() + budget
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
	if role == "world" then
		return false -- Stage 10 fix: a world server plays only the slot its trip brought
	end
	applyChoice(player, record, { slot = slot :: number, mode = mode :: SlotMode, fresh = fresh == true })
	return true
end

-- Stage 10 fix: the player's Roblox friends (online ones first), at most MAX_FRIEND_LOOKUPS. nil when
-- the friends list could not be read.
local function friendIds(userId: number): { number }?
	local ok, pages = retry("read the friends list", function(): any
		return Players:GetFriendsAsync(userId)
	end)
	if not ok or pages == nil then
		return nil
	end
	local online: { number } = {}
	local others: { number } = {}
	for page = 1, MAX_FRIEND_PAGES do
		local readOk, items = pcall(function(): any
			return pages:GetCurrentPage()
		end)
		if not readOk or type(items) ~= "table" then
			break
		end
		for _, item in items do
			if type(item) == "table" and Worlds.isUserId(item.Id) then
				table.insert(if item.IsOnline == false then others else online, item.Id)
			end
		end
		if pages.IsFinished or page == MAX_FRIEND_PAGES then
			break
		end
		local nextOk, err = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not nextOk then
			warn(`[SpaceBaseOdyssey] friends list page {page + 1} failed: {err}`)
			break
		end
	end
	local result: { number } = {}
	for _, list in { online, others } do
		for _, id in list do
			if #result >= MAX_FRIEND_LOOKUPS then
				return result
			end
			table.insert(result, id)
		end
	end
	return result
end

-- Stage 10 fix: ListFriendWorlds action (start menu "Join a friend"). At most one request every
-- WORLDS_REQUEST_INTERVAL seconds per player; the answer is a Types.FriendWorlds on Remotes.WORLDS.
-- Only the lobby looks for worlds (a world or a local server answers with an empty list, here = true).
function ProgressService.listFriendWorlds(player: Player)
	local record = records[player]
	local events = remotes
	local event = events and events.worlds
	if record == nil or event == nil then
		return
	end
	local t = os.clock()
	if t - record.lastWorldsRequestAt < WORLDS_REQUEST_INTERVAL then
		return
	end
	record.lastWorldsRequestAt = t
	local answer: Types.FriendWorlds = { ok = true, worlds = {}, here = role ~= "lobby" }
	if role == "lobby" then
		local friends = friendIds(player.UserId)
		if friends == nil then
			answer.ok = false
		else
			local entries: { [number]: Worlds.Entry } = {}
			for _, id in friends do
				local entry = readWorld(id, true)
				if entry then
					entries[id] = entry
				end
			end
			answer.worlds = Worlds.friendWorlds(friends, entries, Worlds.LIST_LIMIT)
		end
	end
	if records[player] == record and player.Parent ~= nil then
		event:FireClient(player, answer)
	end
end

-- Stage 10 fix: JoinWorld action { owner, slot } (start menu: a friend's world, then which of the
-- player's own slots to bring). Lobby only, from the start menu, at most once every
-- JOIN_REQUEST_INTERVAL seconds. Checked here (the world server checks again on arrival): owner is a
-- Roblox friend of the player, their world is open, a friends world, and has room. Returns false
-- when the request itself is invalid (a refused join tells the client through SBO_TripFailed).
function ProgressService.joinWorld(player: Player, owner: any, slot: any): boolean
	local record = records[player]
	if record == nil or record.state ~= "menu" or not record.metaReady or role ~= "lobby" then
		return false
	end
	if not Worlds.isUserId(owner) or owner == player.UserId or not isSlot(slot) then
		return false
	end
	local t = os.clock()
	if t - record.lastJoinAt < JOIN_REQUEST_INTERVAL then
		return false
	end
	record.lastJoinAt = t
	local ownerId = owner :: number
	-- Busy from now on (no ChooseSlot meanwhile); tripFailed puts the menu back.
	record.state = "teleporting"
	record.teleportToken += 1
	local token = record.teleportToken
	setAttribute(player, "SBO_SlotLoading", true)
	local friendOk, friend = retry(`friends check for {player.Name}`, function(): any
		return player:IsFriendsWith(ownerId)
	end)
	local entry = readWorld(ownerId)
	if records[player] ~= record or record.teleportToken ~= token then
		return false
	end
	local allowed, reason = Worlds.canJoin(entry, player.UserId, friendOk and friend == true, MAX_WORLD_PLAYERS)
	if not allowed or entry == nil then
		tripFailed(player, record, token, reason or "closed")
		return true
	end
	-- A used slot is played as it is; an empty one starts a new explorer (never a wipe from here).
	-- Stage 11: never fresh: the world server reads the slot (an empty record is a new explorer).
	record.state = "menu" -- startTrip starts the trip itself
	startTrip(player, record, { slot = slot :: number, mode = "friends", fresh = false, guest = true }, {
		owner = ownerId,
		code = entry.code,
	})
	return true
end

-- Stage 10 fix: this server's role ("lobby" | "world" | "local").
function ProgressService.role(): Worlds.Role
	return role
end

-- Stage 10 fix: the world owner while they are here with a loaded slot (nil otherwise). The base
-- (builds standing, builds in progress) is this player's save.
function ProgressService.worldOwner(): Player?
	local owner = currentOwner
	if owner and owner.Parent ~= nil and records[owner] ~= nil then
		return owner
	end
	return nil
end

-- Stage 10 fix: the world owner's UserId (world servers know it even after the owner left).
function ProgressService.worldOwnerId(): number?
	return worldOwnerId
end

-- Stage 10 fix: true while `player` plays in someone else's world.
function ProgressService.isGuest(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.guest
end

-- Stage 10 fix: called whenever the world owner changes (their slot loaded, they left, or in a local
-- server the next player in line took over).
function ProgressService.onOwnerChanged(listener: () -> ())
	table.insert(ownerListeners, listener)
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

-- Stage 11: a copy of the player's settings (Types.PlayerSettings; defaults until anything is known).
function ProgressService.settingsOf(player: Player): ServerGuard.Settings?
	local record = records[player]
	return if record then table.clone(record.settings) else nil
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
	fresh.achievements = Achievements.cloneRecord(record.base.achievements) -- what was learned stays
	fresh.daily = record.base.daily -- Stage 11 daily: capsules, stripes and the logbook stay too
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
