--!strict
-- Space Base Odyssey - learning achievements (Stage 10, team request), server side.
-- src/shared/Achievements.luau holds the list and the pure rules; this module watches real events,
-- unlocks each achievement once per save slot, saves it in the slot (base field `achievements`,
-- ProgressService), pays MissionData.ACHIEVEMENTS.XP_REWARD XP (BaseService.grantCredits, so the
-- XP skill bonus applies), tells the client (Remotes.ACHIEVEMENTS: the panel and the toast) and,
-- when the team has created one, awards the Roblox badge.
--
-- Where each rule's facts come from:
--   lessons   MissionService.onLearn (air_from_water, harvest, storm_sheltered, false_alarm,
--             antenna_linked); the OpenSources action (Sources screen opened)
--   counts    MissionService.onIceDelivered (ice, by hand and the hauler, any phase) and
--             MissionService.onPanelCleaned (clean)
--   missions  ProgressService.get(player).completed (checked after onMissionCompleted)
--   level     BaseService.habitatLevel(); build: BaseService.effectiveBuilds() (onBuildsChanged).
--             Owner only: in a friend's private world the base is the owner's save, so a guest
--             earns these in their own world (ProgressService.isGuest).
--   sites     "poi:<id>" keys in the saved base.scanned against ExploreService.siteIds() (onScan)
-- Everything is checked again when a slot loads, so an achievement already earned in an older save
-- (base level, ship, chapters, sites) unlocks then. Players on the start menu (no slot) get nothing;
-- the lobby never loads a slot, so nothing happens there.
--
-- Roblox badges: MissionData.ACHIEVEMENTS.BADGES[id] > 0 is awarded with BadgeService (pcall, once
-- UserHasBadgeAsync says the player does not have it, one retry). How the team creates the badges:
--   1. Creator Hub (create.roblox.com) > Creations > Space Base Odyssey > Associated Items > Badges.
--   2. Create a Badge: image (512x512, no logos), name and description (use the en title and fact).
--      A few badges per day are free; more cost Robux (Roblox shows the price before creating it).
--   3. Copy the badge id (the number in its URL) into MissionData.ACHIEVEMENTS.BADGES[<id>].
--   4. Publish. A badge is awarded the next time the achievement unlocks; players who unlocked it
--      before get it when their slot loads (load below).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

type Record = Achievements.Record
type Facts = Achievements.Facts

export type Remotes = {
	achievements: RemoteEvent,
	action: RemoteEvent?,
}

-- Technical settings (not gameplay numbers).
local OPEN_SOURCES_INTERVAL = 5 -- OpenSources is accepted at most this often per player (seconds)
local BADGE_RETRY_SECONDS = 5
local CHECK_SECONDS = 2 -- builds and base level are also checked this often (a friend builds)

local AchievementService = {}

type PlayerData = {
	record: Record,
	loaded: boolean,
	scheduled: boolean,
	lastSourcesAt: number,
}

local started = false
local base: any = nil -- BaseService
local missionApi: any = nil -- MissionService
local progress: any = nil -- ProgressService
local explore: any = nil -- ExploreService (optional)
local remotes: Remotes? = nil
local players: { [Player]: PlayerData } = {}

----------------------------------------------------------------------------------------------------
-- Helpers

local function call(target: any, name: string, ...: any): (boolean, any)
	local fn = if type(target) == "table" then target[name] else nil
	if type(fn) ~= "function" then
		return false, nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(`[SpaceBaseOdyssey] AchievementService: {name} failed: {result}`)
		return false, nil
	end
	return true, result
end

local function badgeId(id: string): number
	local badges: any = MissionData.ACHIEVEMENTS.BADGES
	local value = if type(badges) == "table" then badges[id] else nil
	return if type(value) == "number" and value > 0 and value == math.floor(value) then value else 0
end

-- Awards the Roblox badge of an achievement (if the team made one). Never yields the caller.
local function awardBadge(player: Player, id: string)
	local badge = badgeId(id)
	if badge == 0 then
		return
	end
	task.spawn(function()
		for attempt = 1, 2 do
			if player.Parent == nil then
				return
			end
			local okHas, has = pcall(function(): boolean
				return BadgeService:UserHasBadgeAsync(player.UserId, badge)
			end)
			if okHas and has == true then
				return
			end
			local okAward, err = pcall(function()
				BadgeService:AwardBadge(player.UserId, badge)
			end)
			if okAward and okHas then
				return
			end
			if attempt == 1 then
				task.wait(BADGE_RETRY_SECONDS)
			else
				warn(`[SpaceBaseOdyssey] badge {badge} for {id} not awarded: {if okAward then has else err}`)
			end
		end
	end)
end

-- Private worlds: the base standing in a friend's world is the OWNER's save, so a guest never earns
-- the base level or ship achievements there (they earn them in their own world).
local function isGuest(player: Player): boolean
	local _, guest = call(progress, "isGuest", player)
	return guest == true
end

-- The base level this player's achievements count (0 for a guest in a friend's world).
local function countedLevel(player: Player): number
	if isGuest(player) then
		return 0
	end
	local _, level = call(base, "habitatLevel")
	return if type(level) == "number" then level else 0
end

local function send(player: Player, data: PlayerData, newId: string?, xp: number?)
	local events = remotes
	if events == nil or player.Parent == nil then
		return
	end
	local state: Types.AchievementState = {
		unlocked = Achievements.unlockedList(data.record),
		counts = table.clone(data.record.counts),
		new = newId,
		xp = xp,
	}
	events.achievements:FireClient(player, state)
end

local function save(player: Player, data: PlayerData)
	local snapshot = Achievements.cloneRecord(data.record)
	call(progress, "updateBase", player, function(saved: any)
		saved.achievements = snapshot
	end)
end

local function sitesScanned(player: Player, ids: { string }): number
	local _, saved = call(progress, "getBase", player)
	local scanned = if type(saved) == "table" then saved.scanned else nil
	if type(scanned) ~= "table" then
		return 0
	end
	local count = 0
	for _, id in ids do
		if scanned["poi:" .. id] == true or scanned[id] == true then -- same keys as ExploreService
			count += 1
		end
	end
	return count
end

local function factsOf(player: Player, lessons: { [string]: boolean }?): Facts
	local _, saveProgress = call(progress, "get", player)
	local missions: { [string]: boolean } = {}
	if type(saveProgress) == "table" and type(saveProgress.completed) == "table" then
		missions = saveProgress.completed
	end
	local guest = isGuest(player)
	local builds: any = nil
	if not guest then
		local _, effective = call(base, "effectiveBuilds")
		builds = effective
	end
	local ok, ids = call(explore, "siteIds")
	local siteIds: { string } = if ok and type(ids) == "table" then ids else {}
	return {
		lessons = lessons or {},
		missions = missions,
		baseLevel = countedLevel(player),
		builds = if type(builds) == "table" then builds else {},
		sitesScanned = sitesScanned(player, siteIds),
		siteTotal = #siteIds,
	}
end

----------------------------------------------------------------------------------------------------
-- Unlocking

-- Unlocks every achievement whose rule is met now (lessons: the ones seen just now).
local function evaluate(player: Player, lessons: { [string]: boolean }?)
	local data = players[player]
	if data == nil or not data.loaded or player.Parent == nil then
		return
	end
	local found = Achievements.newlyMet(MissionData, data.record, factsOf(player, lessons))
	if #found == 0 then
		return
	end
	for _, id in found do
		data.record.unlocked[id] = true
	end
	save(player, data)
	for _, id in found do
		-- XP only (no credits): grantCredits adds the XP skill bonus and returns what it paid.
		local paid = 0
		local grant = if type(base) == "table" then base.grantCredits else nil
		if type(grant) == "function" then
			local ok, _credits, xp = pcall(grant, player, 0, MissionData.ACHIEVEMENTS.XP_REWARD)
			if ok and type(xp) == "number" then
				paid = xp
			elseif not ok then
				warn(`[SpaceBaseOdyssey] achievement reward failed: {_credits}`)
			end
		end
		send(player, data, id, paid)
		awardBadge(player, id)
	end
end

local function schedule(player: Player)
	local data = players[player]
	if data == nil or data.scheduled then
		return
	end
	data.scheduled = true
	task.defer(function()
		data.scheduled = false
		if players[player] == data then
			local ok, err = pcall(evaluate, player, nil)
			if not ok then
				warn(`[SpaceBaseOdyssey] achievement check failed: {err}`)
			end
		end
	end)
end

local function learn(player: Player, lesson: string)
	local ok, err = pcall(evaluate, player, { [lesson] = true })
	if not ok then
		warn(`[SpaceBaseOdyssey] achievement lesson {lesson} failed: {err}`)
	end
end

local function addCount(player: Player, name: string, amount: number)
	local data = players[player]
	if data == nil or not data.loaded then
		return
	end
	if Achievements.addCount(data.record, name, amount) then
		save(player, data)
		send(player, data, nil, nil)
		schedule(player)
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
	data.record = Achievements.sanitizeRecord(if type(saved) == "table" then saved.achievements else nil)
	data.loaded = true
	send(player, data, nil, nil)
	schedule(player)
	-- Badges the team created after the player unlocked the achievement.
	for _, id in Achievements.unlockedList(data.record) do
		awardBadge(player, id)
	end
end

local function addPlayer(player: Player)
	if players[player] then
		return
	end
	players[player] = {
		record = Achievements.emptyRecord(),
		loaded = false,
		scheduled = false,
		lastSourcesAt = -math.huge,
	}
	local _, loaded = call(progress, "isLoaded", player)
	if loaded == true then
		load(player)
	end
end

local function connectHooks()
	call(progress, "onLoaded", function(player: Player)
		if players[player] == nil then
			addPlayer(player)
		else
			load(player)
		end
	end)
	call(progress, "onChanged", function()
		for player in players do
			schedule(player)
		end
	end)
	call(base, "onBuildsChanged", function()
		task.defer(function()
			for player in players do
				schedule(player)
			end
		end)
	end)
	call(missionApi, "onLearn", function(list: { Player }, lesson: string)
		if type(list) ~= "table" or type(lesson) ~= "string" then
			return
		end
		for _, player in list do
			learn(player, lesson)
		end
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
	call(missionApi, "onBaseAction", function(player: Player, kind: string, stage: string)
		if stage == "after" then
			schedule(player)
		end
	end)
	call(explore, "onScan", function(player: Player)
		schedule(player)
	end)

	-- OpenSources (client, Sources screen): validated here; a loaded slot, rate-limited.
	local action = if remotes then remotes.action else nil
	if action then
		action.OnServerEvent:Connect(function(player: Player, payload: any)
			if type(payload) ~= "table" or payload.type ~= "OpenSources" then
				return
			end
			local data = players[player]
			local t = os.clock()
			if data == nil or not data.loaded or t - data.lastSourcesAt < OPEN_SOURCES_INTERVAL then
				return
			end
			data.lastSourcesAt = t
			learn(player, "OpenSources")
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- baseService: BaseService (habitatLevel, effectiveBuilds, grantCredits, onBuildsChanged);
-- missionService: MissionService (onLearn, onMissionCompleted, onIceDelivered, onPanelCleaned,
-- onBaseAction); progressService: ProgressService (getBase, updateBase, get, isLoaded, onLoaded,
-- onChanged); remoteEvents.achievements: Remotes.ACHIEVEMENTS; remoteEvents.action: the Action
-- remote (OpenSources). ExploreService is found next to this module (optional).
function AchievementService.start(baseService: any, missionService: any, progressService: any, remoteEvents: Remotes)
	assert(not started, "AchievementService already started")
	started = true
	base = baseService
	missionApi = missionService
	progress = progressService
	remotes = remoteEvents
	if progress == nil then
		warn("[SpaceBaseOdyssey] AchievementService has no ProgressService; achievements are off")
		return
	end
	local module = script.Parent:FindFirstChild("ExploreService")
	explore = if module and module:IsA("ModuleScript") then (require :: any)(module) else nil

	connectHooks()

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		players[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	-- A friend can raise the base level or build the ship while this player stands in the world.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for player, data in players do
				if data.loaded and player.Parent then
					schedule(player)
				end
			end
		end
	end)
end

-- True when the player has unlocked achievement `id` in their loaded slot.
function AchievementService.has(player: Player, id: string): boolean
	local data = players[player]
	return data ~= nil and data.loaded and data.record.unlocked[id] == true
end

return AchievementService
