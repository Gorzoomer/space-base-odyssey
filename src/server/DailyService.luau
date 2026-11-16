--!strict
-- Space Base Odyssey - Stage 11: the daily supply capsule and the Moon Logbook, server side.
-- src/shared/Daily.luau holds the pure rules (tests/daily). This module is the authority:
--   * The day is the server's own UTC day (os.time()); the client clock never matters.
--   * ClaimDaily opens today's capsule once: the fixed calendar reward is paid with
--     BaseService.grantCredits (credits or XP; the skill bonus applies as for every grant) or the suit
--     stripes are added. The record is changed and saved BEFORE paying, so a failure can never pay
--     twice. The client only plays the landing animation and shows the card.
--   * ClaimLogbook claims a milestone only when the server's own logbook count reaches its target:
--     found secrets (ProgressService.get), scanned exploration sites (saved base.scanned against
--     ExploreService.siteIds), fresh craters scanned for the first time (ExploreService.onScan, counted
--     here) and unlocked learning achievements (saved base.achievements).
--   * WearStripes picks owned stripes; HeardFact remembers a fun fact for the logbook facts page (it
--     never counts for a milestone, because the server cannot see what was heard).
--   * Suit stripes: two coloured bands (Theme.PALETTE colours) welded around each upper arm, built from
--     plain Parts (no assets), seen by everyone. Rebuilt on every spawn and when the choice changes.
-- Saved in the player's own slot (base field `daily`, ProgressService.updateBase), like the learning
-- achievements: a guest in a friend's world keeps their own capsules and logbook. Players on the start
-- menu (no slot) get nothing; the lobby never loads a slot, so nothing happens there.
-- Remotes.DAILY (made here) sends Types.DailyState to one client: when the slot loads, after every
-- change, on RequestDaily, and when a refresh finds something new (a new UTC day, a new entry).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local Daily = require(Shared:WaitForChild("Daily"))
local Localization = require(Shared:WaitForChild("Localization"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Missions = require(Shared:WaitForChild("Missions"))
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

type Record = Daily.Record

export type Remotes = {
	action: RemoteEvent?,
	message: RemoteEvent?,
	daily: RemoteEvent?, -- made in ReplicatedStorage.Remotes when nil
}

-- Technical settings (not gameplay numbers).
local REFRESH_SECONDS = 5 -- new day, new logbook entries: checked this often per loaded player
local MIN_GAP: { [string]: number } = { -- seconds between two accepted actions of one kind
	ClaimDaily = 1,
	RequestDaily = 1,
	ClaimLogbook = 1,
	WearStripes = 0.5,
	HeardFact = 5,
}
local LANDING_OFFSET = 14 -- studs from the parts depot, away from the lander
local STRIPE_MODEL = "SBO_Stripes"
local BAND_LENGTH = 0.22 -- studs along the arm
local BAND_PAD = 0.12 -- studs wider than the arm
local CHARACTER_WAIT_SECONDS = 10
local REMOTE_NAME: string = (Types.Remotes :: any).DAILY or "Daily"
local ARM_NAMES = { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }

local DailyService = {}

type PlayerData = {
	record: Record,
	loaded: boolean,
	lastAt: { [string]: number },
	signature: string,
	announced: { [string]: boolean }, -- milestones C.A.R.L. already called ready this visit
	connections: { RBXScriptConnection },
}

local started = false
local world: any = nil
local base: any = nil -- BaseService
local progress: any = nil -- ProgressService
local explore: any = nil -- ExploreService (optional)
local remotes: Remotes? = nil
local dailyRemote: RemoteEvent? = nil
local players: { [Player]: PlayerData } = {}
local landingCache: Vector3? = nil

----------------------------------------------------------------------------------------------------
-- Helpers

local function call(target: any, name: string, ...: any): (boolean, any, any)
	local fn = if type(target) == "table" then target[name] else nil
	if type(fn) ~= "function" then
		return false, nil, nil
	end
	local ok, result, second = pcall(fn, ...)
	if not ok then
		warn(`[SpaceBaseOdyssey] DailyService: {name} failed: {result}`)
		return false, nil, nil
	end
	return true, result, second
end

local function sayTo(player: Player, key: string, params: { [string]: string | number }?)
	local events = remotes
	local message = events and events.message
	if message and player.Parent then
		local ref: Types.TextRef = { key = key, params = params }
		message:FireClient(player, ref)
	end
end

local function findRemote(): RemoteEvent
	local events = remotes
	if events and events.daily then
		return events.daily
	end
	local folder = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
	local existing = folder:FindFirstChild(REMOTE_NAME)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = REMOTE_NAME
	event.Parent = folder
	return event
end

-- Where the capsule lands: beside the arrival lander's parts depot (where every new explorer starts
-- and supplies already arrive), on the side away from the lander. nil = the world has no depot.
local function landingSpot(): Vector3?
	if landingCache then
		return landingCache
	end
	local depot = if type(world) == "table" then world.crateDepot else nil
	local position = if type(depot) == "table" then depot.position else nil
	if typeof(position) ~= "Vector3" then
		return nil
	end
	local depotPosition = position :: Vector3
	local away = Vector3.new(1, 0, 0)
	local lander = if type(world) == "table" then world.landerZone else nil
	if typeof(lander) == "Instance" and (lander :: Instance):IsA("BasePart") then
		local offset = depotPosition - (lander :: BasePart).Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.5 then
			away = flat.Unit
		end
	end
	landingCache = depotPosition + away * LANDING_OFFSET
	return landingCache
end

local function allowed(data: PlayerData, kind: string): boolean
	local now = os.clock()
	local gap = MIN_GAP[kind] or 1
	if now - (data.lastAt[kind] or -math.huge) < gap then
		return false
	end
	data.lastAt[kind] = now
	return true
end

----------------------------------------------------------------------------------------------------
-- The logbook count (only what the server knows)

type LogbookCount = {
	facts: Daily.LogbookFacts,
	secrets: { string },
	sites: { { id: string, found: boolean } },
	achievements: { string },
}

local function logbookCount(player: Player, record: Record): LogbookCount
	local _, saveProgress = call(progress, "get", player)
	local collectibles: { [string]: boolean } = if type(saveProgress) == "table" and type(saveProgress.collectibles) == "table"
		then saveProgress.collectibles
		else {}
	local secrets: { string } = {}
	for _, id in Missions.COLLECTIBLES do
		if collectibles[id] == true then
			table.insert(secrets, id)
		end
	end

	local _, saved = call(progress, "getBase", player)
	local scanned: { [string]: boolean } = if type(saved) == "table" and type(saved.scanned) == "table" then saved.scanned else {}
	local okIds, ids = call(explore, "siteIds")
	local siteIds: { string } = if okIds and type(ids) == "table" then ids else {}
	local sites: { { id: string, found: boolean } } = {}
	local sitesFound = 0
	for _, id in siteIds do
		local found = scanned["poi:" .. id] == true or scanned[id] == true -- same keys as ExploreService
		if found then
			sitesFound += 1
		end
		table.insert(sites, { id = id, found = found })
	end

	local unlocked: { [string]: boolean } = {}
	if type(saved) == "table" and type(saved.achievements) == "table" and type(saved.achievements.unlocked) == "table" then
		unlocked = saved.achievements.unlocked
	end
	local achievements: { string } = {}
	for _, def in Achievements.LIST do
		if unlocked[def.id] == true then
			table.insert(achievements, def.id)
		end
	end

	return {
		facts = {
			secrets = #secrets,
			secretTotal = #Missions.COLLECTIBLES,
			sites = sitesFound,
			siteTotal = #siteIds,
			meteors = record.meteors,
			achievements = #achievements,
			achievementTotal = #Achievements.LIST,
		},
		secrets = secrets,
		sites = sites,
		achievements = achievements,
	}
end

local function entriesOf(player: Player, record: Record): (number, number, LogbookCount)
	local count = logbookCount(player, record)
	local entries, total = Daily.logbookEntries(MissionData, count.facts)
	return entries, total, count
end

----------------------------------------------------------------------------------------------------
-- State for the client

type Extra = {
	claimed: Daily.Reward?,
	paid: { credits: number, xp: number }?,
	milestone: string?,
}

local function buildState(player: Player, data: PlayerData, extra: Extra?): (Types.DailyState, string)
	local record = data.record
	local now = os.time()
	local calendar = Daily.calendar(MissionData, record, now)
	local entries, total, count = entriesOf(player, record)
	local milestones: { Types.LogbookMilestone } = {}
	local readyCount = 0
	for _, milestone in Daily.MILESTONES do
		local ready = Daily.milestoneReady(MissionData, record, milestone.id, entries)
		if ready then
			readyCount += 1
		end
		table.insert(milestones, {
			id = milestone.id,
			entries = Daily.milestoneTarget(MissionData, milestone.id),
			stripe = milestone.stripe,
			claimed = record.milestones[milestone.id] == true,
			ready = ready,
		})
	end
	local days: { Types.DailyReward } = {}
	for _, day in calendar.days do
		table.insert(days, {
			capsule = day.capsule,
			day = day.day,
			week = day.week,
			kind = day.kind,
			amount = day.amount,
			stripe = day.stripe,
			state = day.state,
		})
	end
	local claimed: Types.DailyReward? = nil
	if extra and extra.claimed then
		local reward = extra.claimed
		claimed = {
			capsule = reward.capsule,
			day = reward.day,
			week = reward.week,
			kind = reward.kind,
			amount = reward.amount,
			stripe = reward.stripe,
			state = "done",
		}
	end
	local state: Types.DailyState = {
		ready = calendar.ready,
		opened = record.opened,
		week = calendar.week,
		calendar = days,
		factKey = calendar.factKey,
		nextIn = Daily.secondsToNextDay(now),
		landing = landingSpot(),
		claimed = claimed,
		paid = if extra then extra.paid else nil,
		stripes = Daily.stripeList(record),
		wear = record.wear,
		logbook = {
			secrets = count.secrets,
			sites = count.sites,
			meteors = record.meteors,
			meteorPage = MissionData.LOGBOOK.METEOR_PAGE,
			achievements = count.achievements,
			facts = Daily.factList(record),
			entries = entries,
			total = total,
			milestones = milestones,
			milestone = if extra then extra.milestone else nil,
		},
	}
	local signature = table.concat({
		tostring(calendar.ready),
		tostring(record.opened),
		record.wear,
		tostring(entries),
		tostring(total),
		tostring(readyCount),
		tostring(#state.logbook.facts),
		tostring(record.meteors),
		tostring(#state.stripes),
	}, "|")
	return state, signature
end

local function send(player: Player, data: PlayerData, extra: Extra?)
	local event = dailyRemote
	if event == nil or player.Parent == nil or not data.loaded then
		return
	end
	local state, signature = buildState(player, data, extra)
	data.signature = signature
	event:FireClient(player, state)
end

local function save(player: Player, data: PlayerData)
	local snapshot = Daily.cloneRecord(data.record)
	call(progress, "updateBase", player, function(saved: any)
		saved.daily = snapshot
	end)
end

----------------------------------------------------------------------------------------------------
-- Suit stripes on the character

local function clearStripes(character: Model)
	local old = character:FindFirstChild(STRIPE_MODEL)
	if old then
		old:Destroy()
	end
end

local function applyStripes(player: Player, data: PlayerData)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end
	clearStripes(character)
	local stripe = Daily.stripe(data.record.wear)
	if stripe == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = STRIPE_MODEL
	for _, name in ARM_NAMES do
		local arm = character:FindFirstChild(name)
		if arm == nil or not arm:IsA("BasePart") then
			continue
		end
		local armPart = arm :: BasePart
		local size = armPart.Size
		local diameter = math.max(size.X, size.Z) + BAND_PAD
		local spacing = math.max(BAND_LENGTH * 1.3, size.Y * 0.16)
		for index, colourName in stripe.colors do
			local band = Instance.new("Part")
			band.Name = `Stripe{index}`
			band.Shape = Enum.PartType.Cylinder -- the round side is the part's X axis, turned along the arm
			band.Size = Vector3.new(BAND_LENGTH, diameter, diameter)
			band.Color = (Theme.PALETTE :: any)[colourName] or Theme.ROLE.accent
			band.Material = Enum.Material.SmoothPlastic
			band.TopSurface = Enum.SurfaceType.Smooth
			band.BottomSurface = Enum.SurfaceType.Smooth
			band.Anchored = false
			band.CanCollide = false
			band.CanQuery = false
			band.CanTouch = false
			band.Massless = true
			band.CastShadow = false
			local y = size.Y * 0.22 - (index - 1) * spacing -- the upper part of the arm, near the shoulder
			band.CFrame = armPart.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = armPart
			weld.Part1 = band
			weld.Parent = band
			band.Parent = model
		end
	end
	model.Parent = character
end

local function dressWhenReady(player: Player, character: Model)
	task.spawn(function()
		-- The arms come with the avatar; wait for one, then build.
		local deadline = os.clock() + CHARACTER_WAIT_SECONDS
		while os.clock() < deadline and character.Parent ~= nil do
			if character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm") then
				break
			end
			task.wait(0.25)
		end
		local data = players[player]
		if data and data.loaded and player.Character == character then
			local ok, err = pcall(applyStripes, player, data)
			if not ok then
				warn(`[SpaceBaseOdyssey] suit stripes failed: {err}`)
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Actions

local function onClaimDaily(player: Player, data: PlayerData)
	local reward = Daily.claim(MissionData, data.record, os.time())
	if reward == nil then
		send(player, data, nil) -- not today: the client shows the right calendar again
		return
	end
	save(player, data) -- first: the capsule counts as opened even if paying fails
	local paid = { credits = 0, xp = 0 }
	if reward.kind == "credits" and reward.amount > 0 then
		local ok, credits, xp = call(base, "grantCredits", player, reward.amount, 0)
		if ok then
			paid.credits = if type(credits) == "number" then credits else 0
			paid.xp = if type(xp) == "number" then xp else 0
		end
	elseif reward.kind == "xp" and reward.amount > 0 then
		local ok, credits, xp = call(base, "grantCredits", player, 0, reward.amount)
		if ok then
			paid.credits = if type(credits) == "number" then credits else 0
			paid.xp = if type(xp) == "number" then xp else 0
		end
	elseif reward.kind == "stripe" then
		pcall(applyStripes, player, data)
	end
	send(player, data, { claimed = reward, paid = paid })
end

local function onClaimLogbook(player: Player, data: PlayerData, id: any)
	local entries = entriesOf(player, data.record)
	local stripe = Daily.claimMilestone(MissionData, data.record, id, entries)
	if stripe == nil then
		send(player, data, nil)
		return
	end
	save(player, data)
	pcall(applyStripes, player, data)
	sayTo(player, "carl.logbook.milestone")
	send(player, data, { milestone = id :: string })
end

local function onWear(player: Player, data: PlayerData, id: any)
	if id == data.record.wear then
		return
	end
	if Daily.wear(data.record, id) then
		save(player, data)
		pcall(applyStripes, player, data)
	end
	send(player, data, nil)
end

local function onHeardFact(player: Player, data: PlayerData, index: any)
	local count = (Localization :: any).FUNFACT_COUNT
	if type(count) ~= "number" then
		return
	end
	if Daily.addFact(data.record, index, count) then
		save(player, data)
		send(player, data, nil)
	end
end

local function onAction(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.type) ~= "string" or MIN_GAP[payload.type] == nil then
		return
	end
	local data = players[player]
	if data == nil or not data.loaded or player.Parent == nil then
		return
	end
	local kind: string = payload.type
	if not allowed(data, kind) then
		return
	end
	if kind == "ClaimDaily" then
		onClaimDaily(player, data)
	elseif kind == "RequestDaily" then
		send(player, data, nil)
	elseif kind == "ClaimLogbook" then
		onClaimLogbook(player, data, payload.id)
	elseif kind == "WearStripes" then
		onWear(player, data, payload.id)
	elseif kind == "HeardFact" then
		onHeardFact(player, data, payload.index)
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
	data.record = Daily.sanitizeRecord(if type(saved) == "table" then saved.daily else nil)
	data.loaded = true
	data.announced = {}
	-- Milestones already ready when the slot loads are shown in the logbook, not announced.
	local entries = entriesOf(player, data.record)
	for _, id in Daily.readyMilestones(MissionData, data.record, entries) do
		data.announced[id] = true
	end
	send(player, data, nil)
	if player.Character then
		dressWhenReady(player, player.Character)
	end
end

local function addPlayer(player: Player)
	if players[player] then
		return
	end
	local data: PlayerData = {
		record = Daily.emptyRecord(),
		loaded = false,
		lastAt = {},
		signature = "",
		announced = {},
		connections = {},
	}
	players[player] = data
	table.insert(
		data.connections,
		player.CharacterAdded:Connect(function(character: Model)
			dressWhenReady(player, character)
		end)
	)
	table.insert(
		data.connections,
		player.CharacterAppearanceLoaded:Connect(function(character: Model)
			dressWhenReady(player, character)
		end)
	)
	local _, loaded = call(progress, "isLoaded", player)
	if loaded == true then
		load(player)
	end
end

local function removePlayer(player: Player)
	local data = players[player]
	players[player] = nil
	if data then
		for _, connection in data.connections do
			connection:Disconnect()
		end
	end
end

-- A new UTC day or a new logbook entry: tell the client; a milestone that just became ready is
-- announced once by C.A.R.L.
local function refresh(player: Player, data: PlayerData)
	if not data.loaded or player.Parent == nil then
		return
	end
	local entries = entriesOf(player, data.record)
	for _, id in Daily.readyMilestones(MissionData, data.record, entries) do
		if not data.announced[id] then
			data.announced[id] = true
			sayTo(player, "carl.logbook.ready")
		end
	end
	local _, signature = buildState(player, data, nil)
	if signature ~= data.signature then
		send(player, data, nil)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- worldRefs: WorldBuilder.World (crateDepot, landerZone: where the capsule lands); baseService:
-- BaseService (grantCredits); progressService: ProgressService (getBase, updateBase, get, isLoaded,
-- onLoaded); remoteEvents.action: the Action remote; remoteEvents.message: C.A.R.L.'s remote;
-- remoteEvents.daily: Remotes.DAILY (made here when nil). ExploreService is found next to this module.
function DailyService.start(worldRefs: any, baseService: any, progressService: any, remoteEvents: Remotes)
	assert(not started, "DailyService already started")
	started = true
	world = worldRefs
	base = baseService
	progress = progressService
	remotes = remoteEvents
	if progress == nil then
		warn("[SpaceBaseOdyssey] DailyService has no ProgressService; daily capsules are off")
		return
	end
	dailyRemote = findRemote()
	local module = script.Parent:FindFirstChild("ExploreService")
	explore = if module and module:IsA("ModuleScript") then (require :: any)(module) else nil

	call(progress, "onLoaded", function(player: Player)
		if players[player] == nil then
			addPlayer(player)
		else
			load(player)
		end
	end)
	-- Fresh craters: the first scan of each one is a logbook entry (ExploreService pays the reward).
	call(explore, "onScan", function(player: Player, kind: string, _id: string, isNew: boolean)
		local data = players[player]
		if kind ~= "meteor" or not isNew or data == nil or not data.loaded then
			return
		end
		if Daily.addMeteor(data.record) then
			save(player, data)
			send(player, data, nil)
		end
	end)

	local action = remoteEvents.action
	if action then
		action.OnServerEvent:Connect(function(player: Player, payload: any)
			local ok, err = pcall(onAction, player, payload)
			if not ok then
				warn(`[SpaceBaseOdyssey] daily action failed: {err}`)
			end
		end)
	else
		warn("[SpaceBaseOdyssey] DailyService has no Action remote; capsules cannot be opened")
	end

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for player, data in players do
				local ok, err = pcall(refresh, player, data)
				if not ok then
					warn(`[SpaceBaseOdyssey] daily refresh failed: {err}`)
				end
			end
		end
	end)
end

-- The player's stripes worn now ("none" when none, or before their slot loads).
function DailyService.wearing(player: Player): string
	local data = players[player]
	return if data and data.loaded then data.record.wear else "none"
end

return DailyService
