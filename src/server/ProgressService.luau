--!strict
-- Space Base Odyssey - saved progress per player: completed missions, the four hidden collectibles
-- and event cosmetics from redeem codes.
-- Progress is saved with DataStoreService ("SBO_Progress_v1", key "u_" .. UserId). When DataStores
-- are not available (an unpublished place, or Studio without API access) progress lives in memory for
-- the session. A save only ever adds: it merges with what is already stored, so nothing is lost if two
-- servers save the same player.
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
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Missions = require(Shared:WaitForChild("Missions"))
local Types = require(Shared:WaitForChild("Types"))

local Codes = require(script.Parent:WaitForChild("Codes"))

type Progress = Types.Progress

export type Remotes = {
	progress: RemoteEvent,
	collected: RemoteEvent,
	message: RemoteEvent,
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
}

type Record = {
	completed: { [string]: boolean },
	collectibles: { [string]: boolean },
	cosmetics: { [string]: boolean },
	base: BaseRecord,
	loaded: boolean, -- the stored data was read (or could not be, and the defaults are kept)
	baseReset: boolean, -- DebugResetBase since the last save: the next save replaces, never merges
	canSave: boolean, -- false until the stored data was read (never overwrite what we could not read)
	dirty: boolean,
	saveScheduled: boolean,
	lastSaveAt: number,
	lastPickup: { [string]: number }, -- os.clock() of the last pickup per collectible (debounce)
	lastRedeemAt: number, -- os.clock() of the last redeem attempt (rate limit)
	connections: { RBXScriptConnection },
}

-- Technical settings (not gameplay numbers).
local STORE_NAME = "SBO_Progress_v1"
local KEY_PREFIX = "u_"
local DATA_VERSION = 2 -- 2 = Stage 6 "base" field (version 1 saves load with base defaults)
local MAX_STORED_NUMBER = 1e9 -- credits and XP are clamped to this when read from storage
local SAVE_INTERVAL_SECONDS = 8 -- DataStores allow one write per key about every 6 seconds
local LOAD_ATTEMPTS = 3
local LOAD_RETRY_SECONDS = 2
local CLOSE_BUDGET_SECONDS = 25 -- BindToClose has about 30 seconds
local PICKUP_DEBOUNCE_SECONDS = 1
local PICKUP_EXTRA_RANGE = 8 -- studs beyond the prompt's own range (lag), checked on the server

local ProgressService = {}

local started = false
local store: DataStore? = nil
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
-- Helpers

local function keyFor(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
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
	}
end

local function sanitizeNumber(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_STORED_NUMBER)
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

-- A stored "base" table (or nil for an old save) -> a clean BaseRecord.
local function sanitizeBase(value: any): BaseRecord
	if type(value) ~= "table" then
		return defaultBase()
	end
	return {
		credits = sanitizeNumber(value.credits),
		xp = sanitizeNumber(value.xp),
		builds = sanitizeLevels(value.builds, findBuild),
		skills = sanitizeLevels(value.skills, findSkill),
		pets = sanitizeSet(value.pets, isBuyablePet),
		equipped = sanitizeEquipped(value.equipped),
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
	}
end

-- What gets stored. `stored` = what is in the DataStore now (another server may have saved).
-- Credits and equipped: this server's values. XP, builds, skills, pets: never lower than stored,
-- unless the player reset their base in this server.
local function mergeBase(stored: any, current: BaseRecord, reset: boolean): any
	local merged = cloneBase(current)
	if not reset and type(stored) == "table" then
		local old = sanitizeBase(stored)
		merged.xp = math.max(merged.xp, old.xp)
		maxLevels(merged.builds, old.builds)
		maxLevels(merged.skills, old.skills)
		union(merged.pets, old.pets)
	end
	return merged
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
-- Saving

local function save(player: Player, record: Record)
	local dataStore = store
	if dataStore == nil or not record.canSave then
		return
	end
	record.dirty = false
	savesInFlight += 1
	local completed = table.clone(record.completed)
	local collectibles = table.clone(record.collectibles)
	local cosmetics = table.clone(record.cosmetics)
	local base = cloneBase(record.base)
	local reset = record.baseReset
	local ok, err = pcall(function()
		dataStore:UpdateAsync(keyFor(player), function(old: any): any
			local merged = {
				v = DATA_VERSION,
				completed = sanitizeSet(type(old) == "table" and old.completed, isMissionId),
				collectibles = sanitizeSet(type(old) == "table" and old.collectibles, Missions.isCollectible),
				cosmetics = sanitizeSet(type(old) == "table" and old.cosmetics, Codes.isCosmetic),
				base = mergeBase(type(old) == "table" and old.base, base, reset),
			}
			union(merged.completed, completed)
			union(merged.collectibles, collectibles)
			union(merged.cosmetics, cosmetics)
			return merged
		end)
	end)
	savesInFlight -= 1
	record.lastSaveAt = os.clock()
	if not ok then
		record.dirty = true
		warn(`[SpaceBaseOdyssey] could not save progress for {player.Name}: {err}`)
	elseif reset then
		record.baseReset = false
	end
end

-- Saves soon, at most once every SAVE_INTERVAL_SECONDS per player.
local function requestSave(player: Player, record: Record)
	record.dirty = true
	if record.saveScheduled or not record.canSave then
		return
	end
	record.saveScheduled = true
	local delay = math.max(0, record.lastSaveAt + SAVE_INTERVAL_SECONDS - os.clock())
	task.delay(delay, function()
		record.saveScheduled = false
		if records[player] == record and record.dirty then
			save(player, record)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Rewards

local function anyoneOwns(id: string): boolean
	for player, record in records do
		if player.Parent ~= nil and record.collectibles[id] then
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
		baseReset = false,
		canSave = false,
		dirty = false,
		saveScheduled = false,
		lastSaveAt = -math.huge,
		lastPickup = {},
		lastRedeemAt = -math.huge,
		connections = {},
	}
	records[player] = record

	task.spawn(function()
		local dataStore = store
		local storedBase: any = nil
		if dataStore ~= nil then
			local loaded = false
			for attempt = 1, LOAD_ATTEMPTS do
				local ok, data = pcall(function()
					return dataStore:GetAsync(keyFor(player))
				end)
				if ok then
					loaded = true
					if type(data) == "table" then
						union(record.completed, sanitizeSet(data.completed, isMissionId))
						union(record.collectibles, sanitizeSet(data.collectibles, Missions.isCollectible))
						union(record.cosmetics, sanitizeSet(data.cosmetics, Codes.isCosmetic))
						storedBase = data.base
					end
					break
				end
				warn(`[SpaceBaseOdyssey] progress load attempt {attempt} failed for {player.Name}: {data}`)
				local message = tostring(data)
				if string.find(message, "Studio", 1, true) or string.find(message, "publish", 1, true) then
					-- Studio without API access or an unpublished place: no DataStores this session.
					store = nil
					break
				end
				if attempt < LOAD_ATTEMPTS then
					task.wait(LOAD_RETRY_SECONDS)
				end
			end
			if records[player] ~= record then
				return -- left while loading
			end
			record.canSave = loaded
			if not loaded then
				warn(`[SpaceBaseOdyssey] progress for {player.Name} kept in memory for this session`)
			elseif record.dirty then
				requestSave(player, record) -- something was earned while loading
			end
		end
		if records[player] ~= record then
			return
		end
		-- Base actions wait for the load (BaseService checks isLoaded), but rewards may have come in
		-- meanwhile: keep what was earned on top of the stored base.
		local earned = record.base
		local base = sanitizeBase(storedBase)
		base.credits += math.max(0, earned.credits - MissionData.BASE.START_CREDITS)
		base.xp += earned.xp
		maxLevels(base.builds, earned.builds)
		maxLevels(base.skills, earned.skills)
		union(base.pets, earned.pets)
		if base.equipped == nil then
			base.equipped = earned.equipped
		end
		record.base = base
		record.loaded = true
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

-- worldRefs: WorldBuilder.World (collectibles, setRoverPaint, setTeamFlag).
function ProgressService.start(worldRefs: any, remoteEvents: Remotes)
	assert(not started, "ProgressService already started")
	started = true
	world = worldRefs
	remotes = remoteEvents

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
	else
		warn(`[SpaceBaseOdyssey] DataStores unavailable, progress kept in memory: {result}`)
	end

	connectCollectibles()
	refreshWorldRewards()

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	-- Save what is still unsaved, and wait for saves already running (PlayerRemoving starts them too).
	game:BindToClose(function()
		for player, record in records do
			if record.dirty and record.canSave then
				task.spawn(save, player, record)
			end
		end
		local deadline = os.clock() + CLOSE_BUDGET_SECONDS
		while savesInFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
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

-- Missions completed by any player currently in the server (decides what is unlocked).
function ProgressService.completedUnion(): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for player, record in records do
		if player.Parent ~= nil then
			union(result, record.completed)
		end
	end
	return result
end

function ProgressService.markCompleted(players: { Player }, missionId: string)
	if not isMissionId(missionId) then
		return
	end
	local changed = false
	for _, player in players do
		local record = records[player]
		if record and not record.completed[missionId] then
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
	if record == nil or not Missions.isCollectible(id) then
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

-- Gives `player` an event cosmetic. Returns false when they already had it.
function ProgressService.grantCosmetic(player: Player, id: string): boolean
	local record = records[player]
	if record == nil or not Codes.isCosmetic(id) or record.cosmetics[id] then
		return false
	end
	record.cosmetics[id] = true
	sendProgress(player, record)
	requestSave(player, record)
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

-- True once the player's stored data was read (or could not be, and the defaults are used).
-- BaseService ignores base actions until then.
function ProgressService.isLoaded(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.loaded
end

-- A copy of the player's base data (nil when the player has no record: not joined or left).
function ProgressService.getBase(player: Player): BaseRecord?
	local record = records[player]
	if record == nil then
		return nil
	end
	return cloneBase(record.base)
end

-- Changes the player's base data in place and saves soon. `change` gets the live table; it must keep
-- every field valid (BaseService checks the rules first). Returns false when there is no record.
function ProgressService.updateBase(player: Player, change: (base: BaseRecord) -> ()): boolean
	local record = records[player]
	if record == nil then
		return false
	end
	change(record.base)
	record.base.credits = sanitizeNumber(record.base.credits)
	record.base.xp = sanitizeNumber(record.base.xp)
	requestSave(player, record)
	return true
end

-- Puts the player's builds, skills, credits and XP back to the start (DebugResetBase). Bought pets
-- and what they wear are kept. The next save replaces the stored base instead of merging.
function ProgressService.resetBase(player: Player): boolean
	local record = records[player]
	if record == nil then
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

-- Called (with the player) when a player's stored data finished loading.
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
