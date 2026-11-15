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
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

type Record = {
	completed: { [string]: boolean },
	collectibles: { [string]: boolean },
	cosmetics: { [string]: boolean },
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
local DATA_VERSION = 1
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
	local ok, err = pcall(function()
		dataStore:UpdateAsync(keyFor(player), function(old: any): any
			local merged = {
				v = DATA_VERSION,
				completed = sanitizeSet(type(old) == "table" and old.completed, isMissionId),
				collectibles = sanitizeSet(type(old) == "table" and old.collectibles, Missions.isCollectible),
				cosmetics = sanitizeSet(type(old) == "table" and old.cosmetics, Codes.isCosmetic),
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
		sendProgress(player, record)
		refreshWorldRewards()
		notifyChanged()
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

return ProgressService
