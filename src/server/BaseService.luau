--!strict
-- Space Base Odyssey - build and grow the base (Stage 6), server side.
-- Every player starts with only the habitat and its water tank and builds the rest with credits:
-- solar arrays, greenhouse, antenna, shelter, automatic ice drills and the cargo robot. Builds are
-- SHARED in a server (a structure stands at the highest level any present player has built, see
-- BaseBuild.effective); credits, XP, skills, pets and what each player wears belong to that player
-- and are saved by ProgressService (Record.base).
-- The rules live in src/shared/BaseBuild.luau and every number in MissionData.BASE. This module
-- validates every request (server authoritative), keeps the world (build pads, silo, cargo robot)
-- in sync, applies skill effects and sends each player their Types.BaseState (Remotes.BASE_STATE).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local ProgressServiceModule = require(script.Parent:WaitForChild("ProgressService"))

type ProgressApi = typeof(ProgressServiceModule)
type BaseRecord = ProgressServiceModule.BaseRecord
type Levels = BaseBuild.Levels
type Equipped = Types.Equipped
type BaseState = Types.BaseState
type Params = { [string]: string | number }

export type Remotes = {
	baseState: RemoteEvent,
	message: RemoteEvent,
}

local BASE = MissionData.BASE

-- Technical settings (not gameplay numbers).
local ACTION_INTERVAL_SECONDS = 0.2 -- one Stage 6 action per player this often (extra ones are dropped)
local STATE_PUSH_SECONDS = 0.25 -- at most four BaseState messages per second per player
local SILO_TICK_SECONDS = 1
local PROMPT_EXTRA_RANGE = 8 -- studs beyond the prompt's own range (lag), checked on the server
local DEBUG_MAX_GRANT = 100000

-- Action types this module handles (MissionService routes them here).
local ACTION_TYPES: { [string]: boolean } = {
	Build = true,
	LearnSkill = true,
	Equip = true,
	BuyPet = true,
	ClaimSilo = true,
	DebugGrantCredits = true,
	DebugResetBase = true,
}

local BaseService = {}

local started = false
local world: any = nil
local remotes: Remotes? = nil
local progress: ProgressApi? = nil

local effective: Levels = {} -- builds standing in this server
local applied: { [string]: number } = {} -- build levels the world shows
local cargoShown: boolean? = nil
local siloEnabled: boolean? = nil
local silo = 0 -- ice waiting in the silo (shared by the server)
local siloSent = -1 -- floor(silo) last sent to clients
local cargoTimer = 0
local cargoTurn = 0 -- rotates the cargo robot between several owners

local present: { [Player]: boolean } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local lastActionAt: { [Player]: number } = {}
local lastSentAt: { [Player]: number } = {}
local sendScheduled: { [Player]: boolean } = {}

local buildListeners: { (Levels) -> () } = {}
local equippedListeners: { (Player) -> () } = {}

----------------------------------------------------------------------------------------------------
-- Helpers

local function sayTo(player: Player, key: string, params: Params?)
	local events = remotes
	if events and player.Parent then
		local text: Types.TextRef = { key = key, params = params }
		events.message:FireClient(player, text)
	end
end

local function reject(player: Player, reason: string)
	sayTo(player, "base.why." .. reason)
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

local function fireBuilds()
	for _, listener in buildListeners do
		local copy = table.clone(effective)
		task.spawn(function()
			local ok, err = pcall(listener, copy)
			if not ok then
				warn(`[SpaceBaseOdyssey] builds listener failed: {err}`)
			end
		end)
	end
end

local function fireEquipped(player: Player)
	for _, listener in equippedListeners do
		task.spawn(function()
			local ok, err = pcall(listener, player)
			if not ok then
				warn(`[SpaceBaseOdyssey] equipped listener failed: {err}`)
			end
		end)
	end
end

local function isDebugAllowed(player: Player, trusted: boolean): boolean
	if trusted or RunService:IsStudio() then
		return true
	end
	return player.UserId == game.CreatorId
end

local function rateLimited(player: Player): boolean
	local t = os.clock()
	local last = lastActionAt[player]
	if last and t - last < ACTION_INTERVAL_SECONDS then
		return true
	end
	lastActionAt[player] = t
	return false
end

local function isLoaded(player: Player): boolean
	local api = progress
	return api ~= nil and present[player] == true and api.isLoaded(player)
end

local function baseOf(player: Player): BaseRecord?
	local api = progress
	if api == nil then
		return nil
	end
	return api.getBase(player)
end

local function levelOf(base: BaseRecord): number
	return BaseBuild.levelForXp(MissionData, base.xp)
end

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

-- Prompts are triggered by the client; check the character really stands next to it.
local function closeEnough(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = promptPosition(prompt)
	if root == nil or not root:IsA("BasePart") or position == nil then
		return false
	end
	return (root.Position - position).Magnitude <= prompt.MaxActivationDistance + PROMPT_EXTRA_RANGE
end

local function asPrompt(value: any): ProximityPrompt?
	if typeof(value) == "Instance" and (value :: Instance):IsA("ProximityPrompt") then
		return value :: ProximityPrompt
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Wardrobe: what each player owns and wears

local function progressOf(player: Player): Types.Progress?
	local api = progress
	return if api then api.get(player) else nil
end

local function ownedPets(player: Player, base: BaseRecord): { [string]: boolean }
	local saved = progressOf(player)
	return BaseBuild.ownedPets(MissionData, base.pets, if saved then saved.collectibles else nil)
end

-- True when `player` may wear `value` in `slot`. The first option of every slot is free.
local function ownsItem(player: Player, base: BaseRecord, slot: string, value: string): boolean
	local api = progress
	if api == nil then
		return false
	end
	local options = api.EQUIP_OPTIONS[slot]
	if options == nil or table.find(options, value) == nil then
		return false
	end
	if value == options[1] then
		return true
	end
	local saved = progressOf(player)
	if saved == nil then
		return false
	end
	if slot == "helmet" then
		return saved.cosmetics[value] == true -- "explorer26" from the event code
	elseif slot == "backpack" then
		return value == "laika" and saved.collectibles.laika == true
	elseif slot == "carl" then
		return value == "earth" and saved.collectibles.mini_earth == true
	elseif slot == "pet" then
		return ownedPets(player, base)[value] == true
	end
	return false
end

-- What an old save (from before the wardrobe) wears: every reward it owns, as before Stage 6.
local function autoEquipped(player: Player, base: BaseRecord): Equipped
	local api = progress :: ProgressApi
	local result = api.defaultEquipped()
	if ownsItem(player, base, "helmet", "explorer26") then
		result.helmet = "explorer26"
	end
	if ownsItem(player, base, "backpack", "laika") then
		result.backpack = "laika"
	end
	if ownsItem(player, base, "carl", "earth") then
		result.carl = "earth"
	end
	if ownsItem(player, base, "pet", "laika") then
		result.pet = "laika"
	elseif ownsItem(player, base, "pet", "cheese") then
		result.pet = "cheese"
	end
	return result
end

-- What the player wears, with anything they do not own (any more) swapped for the default.
local function equippedOf(player: Player, base: BaseRecord): Equipped
	local api = progress :: ProgressApi
	local chosen = base.equipped or autoEquipped(player, base)
	local result = api.defaultEquipped()
	for _, slot in api.EQUIP_SLOTS do
		local value = (chosen :: any)[slot]
		if type(value) == "string" and ownsItem(player, base, slot, value) then
			(result :: any)[slot] = value
		end
	end
	return result
end

----------------------------------------------------------------------------------------------------
-- BaseState to each player

local function buildState(player: Player): BaseState?
	local base = baseOf(player)
	if base == nil then
		return nil
	end
	local level = levelOf(base)
	return {
		credits = base.credits,
		xp = base.xp,
		level = level,
		levelXp = BaseBuild.xpForLevel(MissionData, level) or 0,
		nextLevelXp = BaseBuild.xpForLevel(MissionData, level + 1),
		skillPoints = BaseBuild.skillPoints(level, base.skills),
		builds = table.clone(effective),
		ownBuilds = table.clone(base.builds),
		skills = table.clone(base.skills),
		pets = ownedPets(player, base),
		equipped = equippedOf(player, base),
		siloIce = math.floor(silo),
		siloMax = BASE.SILO_MAX,
		icePerMinute = BaseBuild.icePerMinute(MissionData, effective),
	}
end

local function sendNow(player: Player)
	local events = remotes
	if events == nil or player.Parent == nil or not present[player] then
		return
	end
	local state = buildState(player)
	if state then
		lastSentAt[player] = os.clock()
		events.baseState:FireClient(player, state)
	end
end

-- Sends soon, at most once every STATE_PUSH_SECONDS per player.
local function scheduleSend(player: Player)
	if sendScheduled[player] or not present[player] then
		return
	end
	sendScheduled[player] = true
	local last = lastSentAt[player] or -math.huge
	task.delay(math.max(0, last + STATE_PUSH_SECONDS - os.clock()), function()
		sendScheduled[player] = nil
		sendNow(player)
	end)
end

local function scheduleSendAll()
	for player in present do
		scheduleSend(player)
	end
end

----------------------------------------------------------------------------------------------------
-- Skill effects

local function applyHumanoid(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local base = baseOf(player)
	local skills = if base then base.skills else nil
	humanoid.WalkSpeed = MissionData.WORLD.WALK_SPEED + BaseBuild.speedBonus(MissionData, skills)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = BaseBuild.jumpPower(MissionData, skills)
end

-- Player attributes read by the client (Sprint, double jump, drill hold time) and CrewService (suit).
local function applySkillEffects(player: Player)
	local base = baseOf(player)
	local skills = if base then base.skills else nil
	player:SetAttribute("SBO_SpeedBonus", BaseBuild.speedBonus(MissionData, skills))
	player:SetAttribute("SBO_SuitMax", BaseBuild.suitMax(MissionData, skills))
	player:SetAttribute("SBO_JumpLevel", BaseBuild.levelOf(skills, "jump"))
	player:SetAttribute("SBO_DrillLevel", BaseBuild.levelOf(skills, "drill"))
	local character = player.Character
	if character then
		applyHumanoid(player, character)
	end
end

----------------------------------------------------------------------------------------------------
-- World sync: structures, build pads, silo, cargo robot

local function refreshPrompts()
	local prompts = world and world.buildPrompts
	local pads = world and world.buildPads
	if type(prompts) == "table" then
		for id, value in prompts do
			local prompt = asPrompt(value)
			local def = if type(id) == "string" then BaseBuild.buildDef(MissionData, id) else nil
			if prompt == nil or def == nil then
				continue
			end
			local level = BaseBuild.levelOf(effective, def.id)
			local cost = BaseBuild.nextCost(MissionData, effective, def.id)
			local locked = false
			if cost ~= nil then
				for needId, needLevel in def.requires do
					if BaseBuild.levelOf(effective, needId) < needLevel then
						locked = true
					end
				end
			end
			prompt:SetAttribute("ObjectKey", `build.{def.id}.name`)
			if cost ~= nil then
				local textKey = if level > 0 then "prompt.upgrade" elseif cost == 0 then "prompt.build_free" else "prompt.build"
				prompt:SetAttribute("TextKey", textKey)
				prompt:SetAttribute("TextParams", HttpService:JSONEncode({ n = cost }))
			end
			prompt.Enabled = cost ~= nil and not locked

			local padValue = if type(pads) == "table" then pads[id] else nil
			local pad: Instance? = if typeof(padValue) == "Instance" then padValue else prompt.Parent
			if pad then
				pad:SetAttribute("SBO_Level", level)
				pad:SetAttribute("SBO_MaxLevel", def.maxLevel)
				pad:SetAttribute("SBO_Cost", cost)
				pad:SetAttribute("SBO_MinLevel", if cost ~= nil then def.minLevel[level + 1] else nil)
				pad:SetAttribute("SBO_Locked", locked)
			end
		end
	end

	local siloOn = BaseBuild.levelOf(effective, "drill_1") >= 1
	local siloPrompt = asPrompt(world and world.siloPrompt)
	if siloPrompt and siloEnabled ~= siloOn then
		siloEnabled = siloOn
		siloPrompt.Enabled = siloOn
	end
	local cargoOn = BaseBuild.levelOf(effective, "cargo_bot") >= 1
	if cargoShown ~= cargoOn then
		cargoShown = cargoOn
		worldCall("setCargoActive", cargoOn)
	end
end

-- Recomputes the builds standing in the server from every present player whose data is loaded and
-- updates the world. animate = a player just built something (structures rise in).
local function recompute(animate: boolean): boolean
	local list: { Levels } = {}
	for player in present do
		if isLoaded(player) then
			local base = baseOf(player)
			if base then
				table.insert(list, base.builds)
			end
		end
	end
	local newEffective = BaseBuild.effective(list)
	local changed = false
	for _, def in BASE.BUILDS do
		local level = BaseBuild.levelOf(newEffective, def.id)
		local before = applied[def.id]
		if before ~= level then
			applied[def.id] = level
			changed = true
			worldCall("setBuildLevel", def.id, level, animate and level > (before or 0))
		end
	end
	effective = newEffective
	refreshPrompts()
	if changed then
		fireBuilds()
		scheduleSendAll()
	end
	return changed
end

----------------------------------------------------------------------------------------------------
-- Credits and XP

-- Adds credits and XP (either may be 0) and tells the player about a new level.
local function grant(player: Player, credits: number, xp: number)
	local api = progress
	local before = baseOf(player)
	if api == nil or before == nil then
		return
	end
	local levelBefore = levelOf(before)
	api.updateBase(player, function(base: BaseRecord)
		base.credits += math.max(0, credits)
		base.xp += math.max(0, xp)
	end)
	local after = baseOf(player)
	if after then
		local levelAfter = levelOf(after)
		if levelAfter > levelBefore then
			sayTo(player, "carl.base.level_up", { n = levelAfter })
		end
	end
	scheduleSend(player)
end

----------------------------------------------------------------------------------------------------
-- Silo and cargo robot

local function setSiloVisual()
	worldCall("setSilo", silo, BASE.SILO_MAX)
	local whole = math.floor(silo)
	if whole ~= siloSent then
		siloSent = whole
		scheduleSendAll()
	end
end

-- Gives the whole ice in the silo to `player`. quiet = the cargo robot did it (no C.A.R.L. line).
local function claimSiloFor(player: Player, quiet: boolean): boolean
	local ice = math.floor(silo)
	if ice < 1 then
		if not quiet then
			reject(player, "empty")
		end
		return false
	end
	silo -= ice
	local credits = ice * BASE.CREDITS_PER_SILO_ICE
	grant(player, credits, ice * BASE.XP_PER_SILO_ICE)
	setSiloVisual()
	if not quiet then
		sayTo(player, "carl.base.silo_claimed", { n = credits })
	end
	return true
end

local function siloTick(dt: number)
	local anyone = false
	for player in present do
		if isLoaded(player) then
			anyone = true
			break
		end
	end
	if not anyone then
		return
	end
	local perMinute = BaseBuild.icePerMinute(MissionData, effective)
	if perMinute > 0 and silo < BASE.SILO_MAX then
		silo = math.min(BASE.SILO_MAX, silo + perMinute / 60 * dt)
		setSiloVisual()
	end

	cargoTimer += dt
	if cargoTimer < BASE.CARGO_BOT_SECONDS then
		return
	end
	cargoTimer = 0
	local owners: { Player } = {}
	for player in present do
		local base = if isLoaded(player) then baseOf(player) else nil
		if base and BaseBuild.levelOf(base.builds, "cargo_bot") >= 1 then
			table.insert(owners, player)
		end
	end
	if #owners == 0 or silo < 1 then
		return
	end
	table.sort(owners, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	cargoTurn = cargoTurn % #owners + 1
	claimSiloFor(owners[cargoTurn], true)
end

----------------------------------------------------------------------------------------------------
-- Actions

local function doBuild(player: Player, id: any)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if type(id) ~= "string" then
		reject(player, "unknown")
		return
	end
	local ok, reason = BaseBuild.canBuild(MissionData, effective, levelOf(base), base.credits, id)
	local def = BaseBuild.buildDef(MissionData, id)
	if not ok or def == nil then
		reject(player, reason or "unknown")
		return
	end
	local nextLevel = BaseBuild.levelOf(effective, id) + 1
	local cost = def.costs[nextLevel]
	api.updateBase(player, function(saved: BaseRecord)
		saved.credits -= cost
		saved.builds[id] = math.max(BaseBuild.levelOf(saved.builds, id), nextLevel)
	end)
	recompute(true)
	if nextLevel == 1 then
		sayTo(player, `carl.base.built_{id}`)
	else
		sayTo(player, "carl.base.upgraded", { n = nextLevel })
	end
	grant(player, 0, BaseBuild.buildXp(MissionData, cost))
end

local function doLearnSkill(player: Player, id: any)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if type(id) ~= "string" then
		reject(player, "unknown")
		return
	end
	local ok, reason = BaseBuild.canLearn(MissionData, base.skills, levelOf(base), id)
	if not ok then
		reject(player, reason or "unknown")
		return
	end
	api.updateBase(player, function(saved: BaseRecord)
		saved.skills[id] = BaseBuild.levelOf(saved.skills, id) + 1
	end)
	applySkillEffects(player)
	sayTo(player, "carl.base.skill_learned")
	scheduleSend(player)
end

local function doEquip(player: Player, slot: any, value: any)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if type(slot) ~= "string" or type(value) ~= "string" or api.EQUIP_OPTIONS[slot] == nil then
		reject(player, "unknown")
		return
	end
	if not ownsItem(player, base, slot, value) then
		reject(player, "not_owned")
		return
	end
	local current = equippedOf(player, base)
	if (current :: any)[slot] == value and base.equipped ~= nil then
		return
	end
	(current :: any)[slot] = value
	api.updateBase(player, function(saved: BaseRecord)
		saved.equipped = current
	end)
	fireEquipped(player)
	scheduleSend(player)
end

local function doBuyPet(player: Player, id: any)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if type(id) ~= "string" then
		reject(player, "unknown")
		return
	end
	local ok, reason = BaseBuild.canBuyPet(MissionData, ownedPets(player, base), levelOf(base), base.credits, id)
	local def = BaseBuild.petDef(MissionData, id)
	if not ok or def == nil or def.cost == nil then
		reject(player, reason or "unknown")
		return
	end
	local cost = def.cost :: number
	local wearing = equippedOf(player, base)
	wearing.pet = id -- a new pet comes along at once (the Wardrobe can switch it off)
	api.updateBase(player, function(saved: BaseRecord)
		saved.credits -= cost
		saved.pets[id] = true
		saved.equipped = wearing
	end)
	sayTo(player, "carl.base.pet_bought")
	fireEquipped(player)
	scheduleSend(player)
end

local function doClaimSilo(player: Player, trusted: boolean)
	if not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if BaseBuild.levelOf(effective, "drill_1") < 1 then
		reject(player, "requires")
		return
	end
	local siloPrompt = asPrompt(world and world.siloPrompt)
	if not trusted and siloPrompt and not closeEnough(player, siloPrompt) then
		reject(player, "far")
		return
	end
	claimSiloFor(player, false)
end

local function dispatch(player: Player, action: any, trusted: boolean)
	local kind = action.type
	if kind == "Build" then
		doBuild(player, action.id)
	elseif kind == "LearnSkill" then
		doLearnSkill(player, action.id)
	elseif kind == "Equip" then
		doEquip(player, action.slot, action.value)
	elseif kind == "BuyPet" then
		doBuyPet(player, action.id)
	elseif kind == "ClaimSilo" then
		doClaimSilo(player, trusted)
	elseif kind == "DebugGrantCredits" then
		local amount = action.amount
		if not isDebugAllowed(player, trusted) or not isLoaded(player) then
			return
		end
		if type(amount) ~= "number" or amount ~= amount or amount < 1 then
			return
		end
		local whole = math.floor(math.min(amount, DEBUG_MAX_GRANT))
		grant(player, whole, whole)
	elseif kind == "DebugResetBase" then
		local api = progress
		if not isDebugAllowed(player, trusted) or not isLoaded(player) or api == nil then
			return
		end
		api.resetBase(player)
		applySkillEffects(player)
		recompute(false)
		fireEquipped(player)
		scheduleSend(player)
	end
end

----------------------------------------------------------------------------------------------------
-- Players

local function onLoaded(player: Player)
	local api = progress
	if api == nil or not present[player] then
		return
	end
	local base = baseOf(player)
	if base and base.equipped == nil then
		-- First visit since the wardrobe exists: wear every reward already owned.
		local wearing = autoEquipped(player, base)
		api.updateBase(player, function(saved: BaseRecord)
			saved.equipped = wearing
		end)
	end
	applySkillEffects(player)
	recompute(false)
	fireEquipped(player)
	sendNow(player)
end

local function addPlayer(player: Player)
	if present[player] then
		return
	end
	present[player] = true
	applySkillEffects(player) -- defaults until the saved data is read
	local list: { RBXScriptConnection } = {}
	table.insert(
		list,
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and present[player] then
				applyHumanoid(player, character)
			end
		end)
	)
	connections[player] = list
	local character = player.Character
	if character then
		applyHumanoid(player, character)
	end
	local api = progress
	if api and api.isLoaded(player) then
		onLoaded(player)
	end
end

local function removePlayer(player: Player)
	if not present[player] then
		return
	end
	present[player] = nil
	for _, connection in connections[player] or {} do
		connection:Disconnect()
	end
	connections[player] = nil
	lastActionAt[player] = nil
	lastSentAt[player] = nil
	sendScheduled[player] = nil
	recompute(false)
end

-- First-time collectible: credits and XP, and its item is worn at once (the Wardrobe can undo it).
local function onCollectible(player: Player, id: string, isNew: boolean)
	if not isNew then
		return
	end
	local reward = BASE.REWARDS.collectible
	grant(player, reward.credits, reward.xp)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil then
		return
	end
	local wearing = equippedOf(player, base)
	if id == "laika" then
		wearing.backpack = "laika"
		wearing.pet = "laika"
	elseif id == "mini_earth" then
		wearing.carl = "earth"
	elseif id == "cheese" then
		wearing.pet = "cheese"
	else
		scheduleSend(player)
		return
	end
	api.updateBase(player, function(saved: BaseRecord)
		saved.equipped = wearing
	end)
	fireEquipped(player)
	scheduleSend(player)
end

-- The event code helmet is worn at once.
local function onCosmetic(player: Player, id: string)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or id ~= "explorer26" then
		return
	end
	local wearing = equippedOf(player, base)
	wearing.helmet = "explorer26"
	api.updateBase(player, function(saved: BaseRecord)
		saved.equipped = wearing
	end)
	fireEquipped(player)
	scheduleSend(player)
end

local function connectPrompts()
	local prompts = world and world.buildPrompts
	if type(prompts) ~= "table" then
		warn("[SpaceBaseOdyssey] world has no buildPrompts; build pads are off")
	else
		for id, value in prompts do
			local prompt = asPrompt(value)
			if prompt == nil or type(id) ~= "string" then
				continue
			end
			local buildId = id :: string
			local buildPrompt: ProximityPrompt = prompt
			buildPrompt.Triggered:Connect(function(player: Player)
				local ok, err = pcall(function()
					if present[player] and not rateLimited(player) and closeEnough(player, buildPrompt) then
						doBuild(player, buildId)
					end
				end)
				if not ok then
					warn(`[SpaceBaseOdyssey] build prompt failed: {err}`)
				end
			end)
		end
	end
	local siloPrompt = asPrompt(world and world.siloPrompt)
	if siloPrompt then
		siloPrompt.Triggered:Connect(function(player: Player)
			local ok, err = pcall(function()
				if present[player] and not rateLimited(player) then
					doClaimSilo(player, false)
				end
			end)
			if not ok then
				warn(`[SpaceBaseOdyssey] silo prompt failed: {err}`)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- worldRefs: WorldBuilder.World (setBuildLevel, buildPads, buildPrompts, siloPrompt, setSilo,
-- setCargoActive); remoteEvents.baseState = Remotes.BASE_STATE; progressService: ProgressService
-- (already started).
function BaseService.start(worldRefs: any, remoteEvents: Remotes, progressService: ProgressApi)
	assert(not started, "BaseService already started")
	started = true
	world = worldRefs
	remotes = remoteEvents
	progress = progressService

	-- Start from an empty base (only the habitat and its water tank stand).
	for _, def in BASE.BUILDS do
		applied[def.id] = 0
		worldCall("setBuildLevel", def.id, 0, false)
	end
	refreshPrompts()
	worldCall("setSilo", silo, BASE.SILO_MAX)
	connectPrompts()

	progressService.onLoaded(onLoaded)
	progressService.onCollectible(onCollectible)
	progressService.onCosmetic(onCosmetic)
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(SILO_TICK_SECONDS)
			local t = os.clock()
			local ok, err = pcall(siloTick, t - last)
			last = t
			if not ok then
				warn(`[SpaceBaseOdyssey] silo tick failed: {err}`)
			end
		end
	end)
end

-- Handles a Stage 6 action (MissionService routes every action here first). Returns true when the
-- action type belongs to this module, even when it was rejected or rate-limited.
function BaseService.handleAction(player: Player?, action: any, trusted: boolean): boolean
	if type(action) ~= "table" or type(action.type) ~= "string" or not ACTION_TYPES[action.type] then
		return false
	end
	if player == nil or not started or not present[player] then
		return true
	end
	if not trusted and rateLimited(player) then
		return true
	end
	local ok, err = pcall(dispatch, player, action, trusted)
	if not ok then
		warn(`[SpaceBaseOdyssey] base action {action.type} failed: {err}`)
	end
	return true
end

-- Credits and XP for one piece of work (kind = key of MissionData.BASE.REWARDS; count multiplies).
function BaseService.reward(player: Player, kind: string, count: number?)
	local def = (BASE.REWARDS :: any)[kind]
	if def == nil then
		warn(`[SpaceBaseOdyssey] unknown base reward {tostring(kind)}`)
		return
	end
	local times = count or 1
	if type(times) ~= "number" or times ~= times or times <= 0 then
		return
	end
	times = math.floor(times)
	if times < 1 or not present[player] then
		return
	end
	grant(player, def.credits * times, def.xp * times)
end

-- The same reward for every player in the list (for example everyone present when a day ends).
function BaseService.rewardAll(players: { Player }, kind: string, count: number?)
	for _, player in players do
		BaseService.reward(player, kind, count)
	end
end

-- Builds standing in this server right now (a copy).
function BaseService.effectiveBuilds(): Levels
	return table.clone(effective)
end

-- Called with the new effective builds whenever a structure appears, grows or falls back.
function BaseService.onBuildsChanged(listener: (builds: Levels) -> ())
	table.insert(buildListeners, listener)
end

-- What the player wears (helmet, backpack, C.A.R.L. skin, pet), or nil before their data is loaded.
function BaseService.equipped(player: Player): Equipped?
	if not isLoaded(player) then
		return nil
	end
	local base = baseOf(player)
	return if base then equippedOf(player, base) else nil
end

-- Called (with the player) whenever what that player wears may have changed.
function BaseService.onEquippedChanged(listener: (player: Player) -> ())
	table.insert(equippedListeners, listener)
end

-- The player's BaseState right now (also used by tests in Studio).
function BaseService.getState(player: Player): BaseState?
	return buildState(player)
end

return BaseService
