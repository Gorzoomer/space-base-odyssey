--!strict
-- Space Base Odyssey - build and grow the base (Stages 6 and 7), server side.
-- Every player arrives in the lander and builds the whole base with credits: first the habitat
-- (free), then solar arrays, greenhouse, Lab, antenna, shelter, automatic ice drills, the cargo
-- robot, the garage, the landing pad and the ship. Builds are SHARED in a server (a structure stands
-- at the highest level any present player has built, see BaseBuild.effective); credits, XP, skills,
-- tool upgrades, pets, scanned sites and what each player wears belong to that player and are saved
-- by ProgressService (Record.base).
--
-- Stage 7: building happens in STEPS. Triggering a build pad pays the credits and starts the level
-- (BaseBuild.stagesFor steps). Each step needs a parts crate carried from the lander's cargo bay
-- (world.crateDepot) to the pad, then "Assemble" (a longer hold) with the wrench IN HAND. The last
-- step completes the level (it rises in). Progress is per server: anyone present may carry crates
-- and assemble; the player who paid gets the build in their save. Pad prompt states are written as
-- attributes (prompt TextKey / TextParams; pad SBO_Phase "idle" | "crate" | "assemble", SBO_Stage,
-- SBO_Stages).
-- Stage 8 (team feedback: "after delivering, E with the wrench does nothing until I walk away"):
-- each pad has TWO prompts. "BuildPrompt" (WorldBuilder, short hold) pays and takes the crate;
-- "AssemblePrompt" (made here, next to it, hold ASSEMBLE_HOLD_SECONDS, attribute SBO_Tool "wrench")
-- assembles. Only one is enabled at a time and neither ever changes its HoldDuration: Roblox's
-- prompt UI keeps the hold time it had when the prompt appeared, so a shown prompt whose hold grew
-- from 0.6 to 2.5 seconds filled its ring at 0.6 and never triggered. A freshly enabled prompt is
-- shown again with its own hold. Every placeholder key gets its TextParams (written before the key).
-- Stage 8 (team feedback): GEAR worn on the suit, bought and upgraded at the Lab (BuyGear) and
-- switched on or off anywhere (ToggleGear, keys B / J): air boots (double jump) and a jetpack. Gear
-- levels and on/off are saved in the base record; the player attributes SBO_GearBoots and
-- SBO_GearJetpack are the gear level while it is on (0 = off or not owned), SBO_BuilderLevel the
-- "builder" skill (the client shortens the Assemble hold). The old "jump" skill is gone (saves get the
-- boots, ProgressService). Skills "credits" and "xp" add BaseBuild.bonusAmount (whole numbers) to every
-- credit and XP grant (rewards, silo, builds, collectibles); debug grants stay exact.
-- Skills, pets, gear and tool upgrades are only bought at the Lab (built, and standing near
-- its prompt). Tools the player may carry come from the builds standing (BaseBuild.toolsUnlocked);
-- ToolService gives them and reports what is in hand through setToolChecker.
--
-- Stage 9 (team feedback: a Clash-of-Clans-like tree): the habitat is the town hall. Its level is the
-- BASE LEVEL (1 to 5) and every structure level needs a minimum habitat level (BUILDS[*].hab,
-- BaseBuild.canBuild reason "habitat"). A pad whose next level needs a higher base level is locked
-- (pad attributes SBO_Locked = true, SBO_HabNeed = n) but its BuildPrompt stays on with the text
-- "prompt.need_habitat" {n}, so a kid who walks up learns what to do next. The habitat level also sets
-- the silo size (BaseBuild.siloMax), the greenhouse level the food time (BaseBuild.foodCooldown) and
-- the antenna level an extra align bonus (BaseService.antennaBonus, paid by MissionService).
-- Workspace attribute SBO_BaseLevel = the habitat level standing in the server.
-- QuestService (optional) adds BaseState.quest through setQuestProvider and listens to silo claims.
-- The rules live in src/shared/BaseBuild.luau and every number in MissionData.BASE. This module
-- validates every request (server authoritative), keeps the world (build pads, silo, cargo robot)
-- in sync, applies skill effects and sends each player their Types.BaseState (Remotes.BASE_STATE).
-- Stage 10 (cinematic start menu): while NO present player has a loaded save, the WORLD shows the
-- "showcase" base (BaseBuild.shownLevels: every build at its top level, builds in progress keep their
-- step view), so the menu's camera shots show a finished base. Only the structures change: the
-- effective builds (effectiveBuilds, onBuildsChanged, BaseState, prompts, silo, tools, quests, mission
-- rules, rewards and saves) never see it, and nothing announces a build. Workspace attribute
-- SBO_Showcase = true while it shows (the drills turn and the cargo robot drives for the cameras). As
-- soon as one player's save is loaded the world drops back to the real builds without animation.
-- The first player who arrives during a showcase also gets an eclipse preview (WorldSky via
-- world.previewEclipse) a moment later, so the menu's first shot shows the Earth about to hide the
-- Sun; it is not repeated until the showcase ends and starts again.
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
type BuildProgress = Types.BuildProgress
type Params = { [string]: string | number }

export type Remotes = {
	baseState: RemoteEvent,
	message: RemoteEvent,
}

-- What BaseService needs from CrewService (optional: without it crates ignore carried ice).
export type CrewApi = {
	isCarrying: (player: Player) -> boolean,
}

-- A build level being built in steps (server only; clients get Types.BuildProgress).
type Job = {
	level: number, -- the level being built
	stage: number, -- steps finished
	stages: number,
	crate: boolean, -- the parts crate for the next step is at the pad
	cost: number, -- credits paid (refunded if someone else's save already has this level)
	payer: Player?, -- nil while the payer is away (the job stays for the server session)
	payerId: number,
}

export type PadPhase = "idle" | "crate" | "assemble"

local BASE = MissionData.BASE

-- Technical settings (not gameplay numbers).
local ACTION_INTERVAL_SECONDS = 0.2 -- one base action per player this often (extra ones are dropped)
local STATE_PUSH_SECONDS = 0.25 -- at most four BaseState messages per second per player
local SILO_TICK_SECONDS = 1
local PROMPT_EXTRA_RANGE = 8 -- studs beyond the prompt's own range (lag), checked on the server
local LAB_RANGE_STUDS = 30 -- Lab purchases need the player this close to the Lab prompt (the panel closes at 30)
local DEBUG_MAX_GRANT = 100000
local HABITAT_TIER_LINE_DELAY = 4 -- seconds between "Base level N!" and what that level opens
local SHOWCASE_ECLIPSE_DELAY = 1 -- Stage 10: seconds after a menu player arrives before the eclipse preview

-- Action types this module handles (MissionService routes them here).
local ACTION_TYPES: { [string]: boolean } = {
	Build = true,
	LearnSkill = true,
	Equip = true,
	BuyPet = true,
	ClaimSilo = true,
	UpgradeTool = true,
	BuyGear = true,
	ToggleGear = true,
	DebugMeteor = true,
	DebugGrantCredits = true,
	DebugResetBase = true,
	DebugBuildNext = true,
	DebugMaxResources = true,
}

local BaseService = {}

local started = false
local world: any = nil
local remotes: Remotes? = nil
local progress: ProgressApi? = nil
local crew: CrewApi? = nil

local effective: Levels = {} -- builds standing in this server
local applied: { [string]: number } = {} -- build levels the world shows (the showcase while nobody is loaded)
local showcaseOn = false -- Stage 10: the world shows the showcase base (nobody loaded)
local showcaseEclipseDone = false -- the eclipse preview already ran during this showcase
local cargoShown: boolean? = nil
local siloEnabled: boolean? = nil
local silo = 0 -- ice waiting in the silo (shared by the server)
local siloSent = -1 -- floor(silo) last sent to clients
local cargoTimer = 0
local cargoTurn = 0 -- rotates the cargo robot between several owners

local jobs: { [string]: Job } = {} -- build id -> level being built (shared by the server)
local pendingOwner: { [number]: Levels } = {} -- UserId -> builds finished by others while they were away
local promptHold: { [string]: number } = {} -- each BuildPrompt's own HoldDuration (never changed)
local assemblePrompts: { [string]: ProximityPrompt } = {} -- build id -> its pad's AssemblePrompt
local carrying: { [Player]: boolean } = {} -- players carrying a parts crate
local foodReady: { [Player]: number } = {} -- server time when the greenhouse has food for the player
local toolsSent: { [Player]: string } = {} -- last tool set announced to onToolsChanged listeners
local toolChecker: ((Player, string) -> boolean)? = nil
local debugMeteorHook: ((Player, boolean?) -> ())? = nil
local questProvider: ((Player) -> any)? = nil -- Stage 9: BaseState.quest (QuestService)

local present: { [Player]: boolean } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local lastActionAt: { [Player]: number } = {}
local lastPromptAt: { [Player]: number } = {} -- prompts have their own limit: actions never swallow them
local lastSentAt: { [Player]: number } = {}
local sendScheduled: { [Player]: boolean } = {}

local buildListeners: { (Levels) -> () } = {}
local equippedListeners: { (Player) -> () } = {}
local toolsListeners: { (Player) -> () } = {}
local gearListeners: { (Player) -> () } = {}
local siloListeners: { (Player, number) -> () } = {} -- Stage 9: a player collected silo ice by hand
local buildDoneListeners: { (Player, string, number) -> () } = {} -- Stage 9: a build level was finished

-- Player attribute per gear id: the gear level while it is on, else 0 (Movement and SuitService read it).
local GEAR_ATTRIBUTES: { [string]: string } = {
	boots = "SBO_GearBoots",
	jetpack = "SBO_GearJetpack",
}

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

-- Stage 9: "this needs base level {n}" for level `level` of build `id` (the plain line when n is unknown).
local function rejectHabitat(player: Player, id: string, level: number)
	local need = BaseBuild.habitatNeeded(MissionData, id, level)
	if need then
		sayTo(player, "base.why.habitat_n", { n = need })
	else
		reject(player, "habitat")
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

local function fireListeners(list: { (any) -> () }, value: any, label: string)
	for _, listener in list do
		task.spawn(function()
			local ok, err = pcall(listener, value)
			if not ok then
				warn(`[SpaceBaseOdyssey] {label} listener failed: {err}`)
			end
		end)
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
	fireListeners(equippedListeners, player, "equipped")
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

-- Prompt triggers (they already need a hold) are limited apart from remote actions, so an action
-- sent just before (for example an Equip) never swallows a delivery or an assembly.
local function promptLimited(player: Player): boolean
	local t = os.clock()
	local last = lastPromptAt[player]
	if last and t - last < ACTION_INTERVAL_SECONDS then
		return true
	end
	lastPromptAt[player] = t
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

local function serverNow(): number
	return workspace:GetServerTimeNow()
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

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Prompts are triggered by the client; check the character really stands next to it.
local function closeEnough(player: Player, prompt: ProximityPrompt): boolean
	local root = rootOf(player)
	local position = promptPosition(prompt)
	if root == nil or position == nil then
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

local function buildPromptOf(id: string): ProximityPrompt?
	local prompts = world and world.buildPrompts
	return if type(prompts) == "table" then asPrompt(prompts[id]) else nil
end

-- Sets a prompt's localization key and its placeholder values. The params go first, so the client
-- (Prompts.luau re-renders on each attribute change) never shows a key with raw {n} placeholders.
local function setPromptText(prompt: ProximityPrompt, key: string, params: Params)
	local encoded = HttpService:JSONEncode(params)
	if prompt:GetAttribute("TextParams") ~= encoded then
		prompt:SetAttribute("TextParams", encoded)
	end
	if prompt:GetAttribute("TextKey") ~= key then
		prompt:SetAttribute("TextKey", key)
	end
end

local function setEnabled(prompt: ProximityPrompt?, on: boolean)
	if prompt and prompt.Enabled ~= on then
		prompt.Enabled = on
	end
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
-- Tools (Stage 7)

-- Tools this player may carry right now -> tool level (1 = basic; upgrades from the Lab).
local function toolLevelsOf(player: Player): { [string]: number }
	local result: { [string]: number } = {}
	if not present[player] then
		return result
	end
	local base = baseOf(player)
	local saved = if base then base.tools else nil
	for id in BaseBuild.toolsUnlocked(MissionData, effective) do
		local upgrade = (BASE.TOOL_UPGRADES :: any)[id]
		if upgrade then
			result[id] = math.clamp(BaseBuild.levelOf(saved, id), 1, upgrade.maxLevel)
		else
			result[id] = 1
		end
	end
	return result
end

local function toolSignature(levels: { [string]: number }): string
	local parts: { string } = {}
	for id, level in levels do
		table.insert(parts, `{id}={level}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

-- Tells onToolsChanged listeners when the tools a player may carry (or their levels) changed.
local function refreshTools(player: Player)
	if not present[player] then
		return
	end
	local signature = toolSignature(toolLevelsOf(player))
	if toolsSent[player] == signature then
		return
	end
	toolsSent[player] = signature
	fireListeners(toolsListeners, player, "tools")
end

local function refreshToolsAll()
	for player in present do
		refreshTools(player)
	end
end

-- True when the player holds tool `id` (no checker = ToolService is off: never block the game).
local function isHolding(player: Player, id: string): boolean
	local checker = toolChecker
	if checker == nil then
		return true
	end
	local ok, result = pcall(checker, player, id)
	if not ok then
		warn(`[SpaceBaseOdyssey] tool checker failed: {result}`)
		return true
	end
	return result == true
end

----------------------------------------------------------------------------------------------------
-- BaseState to each player

local function progressState(): { [string]: BuildProgress }
	local result: { [string]: BuildProgress } = {}
	for id, job in jobs do
		result[id] = { level = job.level, stage = job.stage, stages = job.stages, crate = job.crate }
	end
	return result
end

-- Scanned keys as saved ("poi:old_lander") plus the bare site id for "poi:" keys ("old_lander").
local function scannedState(base: BaseRecord): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for key in base.scanned or {} do
		result[key] = true
		local site = string.match(key, "^poi:(.+)$")
		if site then
			result[site] = true
		end
	end
	return result
end

-- Gear this player owns -> level (clamped to each def's maxLevel).
local function gearLevelsOf(base: BaseRecord): { [string]: number }
	local result: { [string]: number } = {}
	for _, def in BASE.GEAR do
		local level = math.clamp(BaseBuild.levelOf(base.gear, def.id), 0, def.maxLevel)
		if level > 0 then
			result[def.id] = level
		end
	end
	return result
end

-- Owned gear -> switched on (true) or off (false).
local function gearOnOf(base: BaseRecord): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for id in gearLevelsOf(base) do
		result[id] = base.gearOn ~= nil and base.gearOn[id] == true
	end
	return result
end

local function buildState(player: Player): BaseState?
	local base = baseOf(player)
	if base == nil then
		return nil
	end
	local level = levelOf(base)
	local greenhouse = BaseBuild.levelOf(effective, "greenhouse") >= 1
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
		siloMax = BaseBuild.siloMax(MissionData, effective),
		icePerMinute = BaseBuild.icePerMinute(MissionData, effective),
		inProgress = progressState(),
		carryingCrate = carrying[player] == true,
		tools = toolLevelsOf(player),
		foodReadyAt = if greenhouse then foodReady[player] or 0 else nil,
		scanned = scannedState(base),
		gear = gearLevelsOf(base),
		gearOn = gearOnOf(base),
	}
end

-- Stage 9: BaseState plus the quest tracker from QuestService (when one is set).
local function fullState(player: Player): BaseState?
	local state = buildState(player)
	local provider = questProvider
	if state and provider then
		local ok, quest = pcall(provider, player)
		if ok then
			(state :: any).quest = quest
		else
			warn(`[SpaceBaseOdyssey] quest provider failed: {quest}`)
		end
	end
	return state
end

local function sendNow(player: Player)
	local events = remotes
	if events == nil or player.Parent == nil or not present[player] then
		return
	end
	local state = fullState(player)
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

local function setPlayerAttribute(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- Gear attributes: the level of each piece while it is switched on, else 0.
local function applyGear(player: Player)
	local base = baseOf(player)
	local levels = if base then gearLevelsOf(base) else {}
	local on = if base then gearOnOf(base) else {}
	for id, attribute in GEAR_ATTRIBUTES do
		local level = levels[id] or 0
		setPlayerAttribute(player, attribute, if on[id] then level else 0)
	end
end

-- Player attributes read by the client (Sprint, gear, Assemble hold) and CrewService (suit). The
-- drill hold time (SBO_DrillLevel) comes from the drill TOOL level and is set by ToolService.
-- Stage 8: SBO_JumpLevel is retired (the air boots give the double jump: SBO_GearBoots).
local function applySkillEffects(player: Player)
	local base = baseOf(player)
	local skills = if base then base.skills else nil
	setPlayerAttribute(player, "SBO_SpeedBonus", BaseBuild.speedBonus(MissionData, skills))
	setPlayerAttribute(player, "SBO_SuitMax", BaseBuild.suitMax(MissionData, skills))
	setPlayerAttribute(player, "SBO_BuilderLevel", BaseBuild.levelOf(skills, "builder"))
	applyGear(player)
	local character = player.Character
	if character then
		applyHumanoid(player, character)
	end
end

----------------------------------------------------------------------------------------------------
-- World sync: structures, build pads, silo, cargo robot

local function setPadAttribute(pad: Instance?, name: string, value: any)
	if pad and pad:GetAttribute(name) ~= value then
		pad:SetAttribute(name, value)
	end
end

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
			local padValue = if type(pads) == "table" then pads[id] else nil
			local pad: Instance? = if typeof(padValue) == "Instance" then padValue else prompt.Parent
			local level = BaseBuild.levelOf(effective, def.id)
			local job = jobs[def.id]
			local hold = promptHold[def.id] or prompt.HoldDuration
			local assemble = assemblePrompts[def.id]
			if prompt.HoldDuration ~= hold then
				prompt.HoldDuration = hold -- never changes while shown (see the header)
			end
			local objectKey = `build.{def.id}.name`
			if def.id == "habitat" and level >= 1 and level < def.maxLevel then
				-- Stage 9: the habitat pad names the base level it builds next ("Science outpost").
				local nextTier = if job then job.level else level + 1
				objectKey = `habitat.tier.{nextTier}.name`
			end
			if prompt:GetAttribute("ObjectKey") ~= objectKey then
				prompt:SetAttribute("ObjectKey", objectKey)
			end
			-- Stage 10: the showcase base (nobody loaded) shows idle pads as finished (see below).
			local showcasePad = showcaseOn and job == nil
			setPadAttribute(pad, "SBO_Level", if showcasePad then math.max(1, applied[def.id] or def.maxLevel) else level)
			setPadAttribute(pad, "SBO_MaxLevel", def.maxLevel)

			if job then
				-- A level is being built: bring a crate (BuildPrompt), then assemble it with the wrench
				-- (AssemblePrompt). Only one of the two prompts is on.
				local phase: PadPhase = if job.crate then "assemble" else "crate"
				local stepParams: Params = { n = job.stage + 1, m = job.stages }
				if assemble then
					setPromptText(assemble, "prompt.assemble", stepParams)
					if job.crate then
						setEnabled(prompt, false)
						setEnabled(assemble, true)
					else
						setPromptText(prompt, "prompt.deliver_crate", stepParams)
						setEnabled(assemble, false)
						setEnabled(prompt, true)
					end
				else
					-- No AssemblePrompt (should not happen): the BuildPrompt does both, with its own hold.
					setPromptText(prompt, if job.crate then "prompt.assemble" else "prompt.deliver_crate", stepParams)
					setEnabled(prompt, true)
				end
				setPadAttribute(pad, "SBO_Phase", phase)
				setPadAttribute(pad, "SBO_Stage", job.stage)
				setPadAttribute(pad, "SBO_Stages", job.stages)
				setPadAttribute(pad, "SBO_BuildingLevel", job.level)
				setPadAttribute(pad, "SBO_Cost", nil)
				setPadAttribute(pad, "SBO_HabNeed", nil)
				setPadAttribute(pad, "SBO_Locked", false)
				continue
			end

			if showcasePad then
				-- Stage 10: every idle pad looks finished (small, no ring or icon) and has no prompt; the
				-- next recompute after a save loads writes the real state.
				setEnabled(assemble, false)
				setEnabled(prompt, false)
				setPadAttribute(pad, "SBO_Phase", "idle")
				setPadAttribute(pad, "SBO_Stage", 0)
				setPadAttribute(pad, "SBO_Stages", 0)
				setPadAttribute(pad, "SBO_BuildingLevel", nil)
				setPadAttribute(pad, "SBO_Cost", nil)
				setPadAttribute(pad, "SBO_HabNeed", nil)
				setPadAttribute(pad, "SBO_Locked", false)
				continue
			end

			local cost = BaseBuild.nextCost(MissionData, effective, def.id)
			local missing = false -- another build must stand first: the prompt is off
			local habNeed: number? = if cost ~= nil then def.hab[level + 1] else nil
			local habLocked = habNeed ~= nil and BaseBuild.habitatLevel(effective) < habNeed
			if cost ~= nil then
				for needId, needLevel in def.requires do
					if BaseBuild.levelOf(effective, needId) < needLevel then
						missing = true
					end
				end
			end
			local locked = missing or habLocked
			if cost ~= nil and habLocked and not missing and habNeed ~= nil then
				-- Stage 9: the base level is too low. The prompt stays on and says which level is needed
				-- (triggering it answers "base.why.habitat_n").
				setPromptText(prompt, "prompt.need_habitat", { n = habNeed })
			elseif cost ~= nil then
				local textKey = if level > 0 then "prompt.upgrade" elseif cost == 0 then "prompt.build_free" else "prompt.build"
				setPromptText(prompt, textKey, { n = cost })
			elseif prompt:GetAttribute("TextParams") == nil then
				-- At its top level the prompt is off; still never leave a key without its params.
				setPromptText(prompt, "prompt.upgrade", { n = 0 })
			end
			setEnabled(assemble, false)
			setEnabled(prompt, cost ~= nil and not missing)
			setPadAttribute(pad, "SBO_Phase", "idle")
			setPadAttribute(pad, "SBO_Stage", 0)
			setPadAttribute(pad, "SBO_Stages", if cost ~= nil then BaseBuild.stagesFor(MissionData, def.id, level + 1) else 0)
			setPadAttribute(pad, "SBO_BuildingLevel", nil)
			setPadAttribute(pad, "SBO_Cost", cost)
			setPadAttribute(pad, "SBO_HabNeed", habNeed)
			setPadAttribute(pad, "SBO_Locked", locked)
		end
	end

	local siloOn = BaseBuild.levelOf(effective, "drill_1") >= 1
	local siloPrompt = asPrompt(world and world.siloPrompt)
	if siloPrompt and siloEnabled ~= siloOn then
		siloEnabled = siloOn
		siloPrompt.Enabled = siloOn
	end
	-- Stage 10: the showcase drives the robot too (a visual only: ice still follows the real builds).
	local cargoOn = BaseBuild.levelOf(effective, "cargo_bot") >= 1 or showcaseOn
	if cargoShown ~= cargoOn then
		cargoShown = cargoOn
		worldCall("setCargoActive", cargoOn)
	end
end

local function showJob(id: string, job: Job)
	worldCall("setBuildProgress", id, job.level, job.stage, job.stages)
end

-- Recomputes the builds standing in the server from every present player whose data is loaded and
-- updates the world. animate = a player just finished a level (structures rise in).
-- Stage 10: the world shows BaseBuild.shownLevels (the showcase while nobody is loaded); `changed`
-- and everything that follows it (silo, tools, listeners, BaseState) use the effective builds.
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

	-- A job is pointless once a save present already has that level (someone joined with it).
	local cancelled: { string } = {}
	for id, job in jobs do
		if BaseBuild.levelOf(newEffective, id) >= job.level then
			jobs[id] = nil
			table.insert(cancelled, id)
			local payer = job.payer
			local api = progress
			if payer and present[payer] and api then
				api.updateBase(payer, function(saved: BaseRecord)
					saved.credits += job.cost
				end)
				sayTo(payer, "carl.base.build_cancelled")
			end
		end
	end

	local busy: { [string]: boolean } = {}
	for id in jobs do
		busy[id] = true
	end
	local shown, showcase = BaseBuild.shownLevels(MissionData, list, busy)
	local wasShowcase = showcaseOn
	showcaseOn = showcase
	if showcase ~= wasShowcase then
		workspace:SetAttribute("SBO_Showcase", showcase)
		if not showcase then
			showcaseEclipseDone = false -- the next showcase may preview an eclipse again
		end
	end
	-- Structures rise in only for a level really finished, never for the showcase coming or going.
	local rise = animate and not showcase and not wasShowcase

	local changed = false
	local levelChanged: { [string]: boolean } = {}
	for _, def in BASE.BUILDS do
		if BaseBuild.levelOf(newEffective, def.id) ~= BaseBuild.levelOf(effective, def.id) then
			changed = true
		end
		local level = BaseBuild.levelOf(shown, def.id)
		local before = applied[def.id]
		if before ~= level then
			applied[def.id] = level
			levelChanged[def.id] = true
			worldCall("setBuildLevel", def.id, level, rise and level > (before or 0))
			local job = jobs[def.id]
			if job then
				showJob(def.id, job) -- setBuildLevel shows the plain level; keep the steps on show
			end
		end
	end
	for _, id in cancelled do
		if not levelChanged[id] then
			worldCall("setBuildLevel", id, applied[id] or 0, false) -- drop the step view
		end
	end
	effective = newEffective
	refreshPrompts()
	if changed then
		-- Stage 9: the silo size follows the base level (after a player with a bigger base leaves,
		-- the silo keeps only what fits).
		local cap = BaseBuild.siloMax(MissionData, effective)
		silo = math.min(silo, cap)
		worldCall("setSilo", silo, cap)
		-- Stage 9: the base level for anything in the world that only needs that one number.
		local baseLevel = BaseBuild.habitatLevel(effective)
		if workspace:GetAttribute("SBO_BaseLevel") ~= baseLevel then
			workspace:SetAttribute("SBO_BaseLevel", baseLevel)
		end
		fireBuilds()
		refreshToolsAll()
	end
	if changed or #cancelled > 0 then
		scheduleSendAll()
	end
	return changed
end

----------------------------------------------------------------------------------------------------
-- Credits and XP

-- Adds credits and XP (either may be 0) and tells the player about a new level. The "credits" and
-- "xp" skills add their bonus (BaseBuild.bonusAmount: whole numbers) unless exact = true (debug).
-- Returns the credits and XP really given.
local function grant(player: Player, credits: number, xp: number, exact: boolean?): (number, number)
	local api = progress
	local before = baseOf(player)
	if api == nil or before == nil then
		return 0, 0
	end
	local levelBefore = levelOf(before)
	local addCredits = math.max(0, math.floor(credits))
	local addXp = math.max(0, math.floor(xp))
	if not exact then
		addCredits += BaseBuild.bonusAmount(MissionData, addCredits, BaseBuild.levelOf(before.skills, "credits"))
		addXp += BaseBuild.bonusAmount(MissionData, addXp, BaseBuild.levelOf(before.skills, "xp"))
	end
	api.updateBase(player, function(base: BaseRecord)
		base.credits += addCredits
		base.xp += addXp
	end)
	local after = baseOf(player)
	if after then
		local levelAfter = levelOf(after)
		if levelAfter > levelBefore then
			sayTo(player, "carl.base.level_up", { n = levelAfter })
		end
	end
	scheduleSend(player)
	return addCredits, addXp
end

local function rewardKind(player: Player, kind: string)
	local def = (BASE.REWARDS :: any)[kind]
	if def and present[player] then
		grant(player, def.credits, def.xp)
	end
end

----------------------------------------------------------------------------------------------------
-- Silo and cargo robot

-- Stage 9: the silo holds more ice at a higher base level (MissionData.BASE.SILO_MAX_BY_HABITAT).
local function siloCap(): number
	return BaseBuild.siloMax(MissionData, effective)
end

local function setSiloVisual()
	worldCall("setSilo", silo, siloCap())
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
	local credits = grant(player, ice * BASE.CREDITS_PER_SILO_ICE, ice * BASE.XP_PER_SILO_ICE)
	setSiloVisual()
	if not quiet then
		sayTo(player, "carl.base.silo_claimed", { n = credits })
		-- Stage 9: quests count silo ice collected by hand (not the cargo robot's trips).
		for _, listener in siloListeners do
			task.spawn(function()
				local ok, err = pcall(listener, player, ice)
				if not ok then
					warn(`[SpaceBaseOdyssey] silo listener failed: {err}`)
				end
			end)
		end
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
	local cap = siloCap()
	if perMinute > 0 and silo < cap then
		silo = math.min(cap, silo + perMinute / 60 * dt)
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
-- Parts crates (Stage 7)

local function setCarrying(player: Player, value: boolean)
	if value then
		carrying[player] = true
	else
		carrying[player] = nil
	end
	if player.Parent then
		player:SetAttribute("SBO_CarryingCrate", value)
	end
	local character = player.Character
	if character then
		worldCall("setCarryCrate", character, value)
	end
	scheduleSend(player)
end

local function anyJobNeedsCrate(): boolean
	for _, job in jobs do
		if not job.crate then
			return true
		end
	end
	return false
end

local function takeCrate(player: Player)
	if carrying[player] then
		sayTo(player, "carl.base.has_crate")
		return
	end
	local crewApi = crew
	if crewApi then
		local ok, holdsIce = pcall(crewApi.isCarrying, player)
		if ok and holdsIce then
			sayTo(player, "carl.base.hands_full")
			return
		end
	end
	if not anyJobNeedsCrate() then
		sayTo(player, "carl.base.no_crate_needed")
		return
	end
	setCarrying(player, true)
	sayTo(player, "carl.base.crate_taken")
end

----------------------------------------------------------------------------------------------------
-- Building in steps (Stage 7)

-- The last step is done: the level stands and goes into the payer's save (or the finisher's when the
-- payer is away; the payer then gets it too if they come back to this server).
local function completeJob(finisher: Player, id: string, job: Job)
	local api = progress
	jobs[id] = nil
	if api == nil then
		return
	end
	local payer = job.payer
	local owner = if payer and present[payer] then payer else finisher
	if owner ~= payer then
		local pending = pendingOwner[job.payerId] or {}
		pending[id] = math.max(BaseBuild.levelOf(pending, id), job.level)
		pendingOwner[job.payerId] = pending
	end
	api.updateBase(owner, function(saved: BaseRecord)
		saved.builds[id] = math.max(BaseBuild.levelOf(saved.builds, id), job.level)
	end)
	local before = applied[id]
	recompute(true)
	if applied[id] == before then
		-- The level did not change (no save record): still drop the step view.
		worldCall("setBuildLevel", id, applied[id] or 0, false)
	end

	local told: { [Player]: boolean } = {}
	if id == "habitat" and job.level >= 2 then
		-- Stage 9: a new base level opens new structures for everyone in the server.
		local tierKey = `habitat.tier.{job.level}.desc`
		for player in present do
			told[player] = true
			sayTo(player, "carl.base.habitat_up", { n = job.level })
			-- Then what the new base level opens ("Opens the Lab and the first ice drill.").
			task.delay(HABITAT_TIER_LINE_DELAY, function()
				if player.Parent ~= nil then
					sayTo(player, tierKey)
				end
			end)
		end
	end
	for _, player in { owner, finisher } do
		if not told[player] then
			told[player] = true
			if job.level == 1 then
				sayTo(player, `carl.base.built_{id}`)
			else
				sayTo(player, "carl.base.upgraded", { n = job.level })
			end
		end
	end
	grant(owner, 0, BaseBuild.buildXp(MissionData, job.cost))
	for _, listener in buildDoneListeners do
		task.spawn(function()
			local ok, err = pcall(listener, owner, id, job.level)
			if not ok then
				warn(`[SpaceBaseOdyssey] build listener failed: {err}`)
			end
		end)
	end
	scheduleSendAll()
end

-- Pays the credits and starts the next level of `id` (step 0: only the foundation outline shows).
local function startBuild(player: Player, id: string)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if jobs[id] then
		return
	end
	local ok, reason = BaseBuild.canBuild(MissionData, effective, levelOf(base), base.credits, id)
	local def = BaseBuild.buildDef(MissionData, id)
	local nextLevel = BaseBuild.levelOf(effective, id) + 1
	if reason == "habitat" then
		rejectHabitat(player, id, nextLevel) -- Stage 9: "this needs base level {n}"
		return
	end
	if not ok or def == nil then
		reject(player, reason or "unknown")
		return
	end
	local cost = def.costs[nextLevel]
	api.updateBase(player, function(saved: BaseRecord)
		saved.credits -= cost
	end)
	local job: Job = {
		level = nextLevel,
		stage = 0,
		stages = math.max(1, BaseBuild.stagesFor(MissionData, id, nextLevel)),
		crate = false,
		cost = cost,
		payer = player,
		payerId = player.UserId,
	}
	jobs[id] = job
	showJob(id, job)
	refreshPrompts()
	sayTo(player, "carl.base.build_started", { n = job.stages })
	scheduleSendAll()
end

local function deliverCrate(player: Player, id: string, job: Job)
	setCarrying(player, false)
	job.crate = true
	showJob(id, job)
	refreshPrompts()
	rewardKind(player, "crate_delivered")
	sayTo(player, "carl.base.crate_delivered")
	scheduleSendAll()
end

local function assembleStep(player: Player, id: string, job: Job)
	job.stage += 1
	job.crate = false
	rewardKind(player, "stage_done")
	if job.stage >= job.stages then
		completeJob(player, id, job)
		return
	end
	showJob(id, job)
	refreshPrompts()
	sayTo(player, "carl.base.step_done", { n = job.stage, m = job.stages })
	scheduleSendAll()
end

-- Assembles the step whose parts are at the pad of `id` (AssemblePrompt, or the BuildPrompt when a
-- trigger was already on its way as the prompts switched). Needs the wrench in hand.
local function assemblePad(player: Player, id: string)
	local job = jobs[id]
	if job == nil or not job.crate then
		refreshPrompts() -- a late trigger: make sure the right prompt shows
		return
	end
	if not isHolding(player, "wrench") then
		sayTo(player, "carl.base.need_wrench")
		return
	end
	assembleStep(player, id, job)
end

-- A player used the build pad of `id` (BuildPrompt or trusted Build action). force = trusted debug:
-- the crate and the wrench are not needed.
local function usePad(player: Player, id: string, force: boolean)
	local job = jobs[id]
	if job == nil then
		startBuild(player, id)
		return
	end
	if force then
		if not job.crate and carrying[player] then
			deliverCrate(player, id, job)
		end
		job.crate = true
		assembleStep(player, id, job)
		return
	end
	if job.crate then
		assemblePad(player, id)
	elseif carrying[player] then
		deliverCrate(player, id, job)
	else
		sayTo(player, "carl.base.need_crate")
	end
end

-- Debug (F3 in DemoKeys): finish the build in progress, or build the next structure in the order
-- C.A.R.L. follows: every build's first level in MissionData.BASE.BUILDS order, then the upgrades,
-- lowest level first. Free, with no player level needed, so testers can reach any stage fast.
-- Stage 9: it follows the habitat tree like a player would: everything the current base level allows
-- is built first, and only then the habitat goes up one level (a level whose base level is not
-- reached yet waits).
local function nextDebugBuild(): string?
	local bestId: string? = nil
	local bestLevel = math.huge
	local habLevel = BaseBuild.habitatLevel(effective)
	local habitatReady = false
	for _, def in MissionData.BASE.BUILDS do
		local level = BaseBuild.levelOf(effective, def.id)
		local ready = level < def.maxLevel and (def.hab[level + 1] or 0) <= habLevel
		if ready then
			for needId, needLevel in def.requires do
				if BaseBuild.levelOf(effective, needId) < needLevel then
					ready = false
					break
				end
			end
		end
		if ready and def.id == "habitat" and level >= 1 then
			habitatReady = true -- the next base level waits until this one is complete
		elseif ready and level < bestLevel then
			bestId = def.id
			bestLevel = level
		end
	end
	if bestId == nil and habitatReady then
		return "habitat"
	end
	return bestId
end

local function debugBuildNext(player: Player)
	local id: string? = nil
	for jobId in jobs do
		id = jobId -- a build already in progress is finished first
		break
	end
	if id == nil then
		id = nextDebugBuild()
		if id == nil then
			sayTo(player, "carl.base.debug_all_built")
			return
		end
		local nextLevel = BaseBuild.levelOf(effective, id) + 1
		local job: Job = {
			level = nextLevel,
			stage = 0,
			stages = math.max(1, BaseBuild.stagesFor(MissionData, id, nextLevel)),
			crate = false,
			cost = 0,
			payer = player,
			payerId = player.UserId,
		}
		jobs[id] = job
	end
	local buildId = id :: string
	local guard = 0
	while jobs[buildId] and guard < 20 do
		guard += 1
		local job = jobs[buildId] :: Job
		job.crate = true
		assembleStep(player, buildId, job)
	end
end

----------------------------------------------------------------------------------------------------
-- Actions

-- Build action: building happens at the pads, so the player must stand at that pad (no menu).
local function doBuild(player: Player, id: any, trusted: boolean)
	if type(id) ~= "string" or BaseBuild.buildDef(MissionData, id) == nil then
		reject(player, "unknown")
		return
	end
	if trusted then
		usePad(player, id, true)
		return
	end
	local prompt = buildPromptOf(id)
	if prompt == nil or not closeEnough(player, prompt) then
		reject(player, "pad_far")
		return
	end
	if jobs[id] == nil then
		startBuild(player, id) -- crates and assembly only through the pad prompt (it has the hold)
	end
end

-- Skills, pets and tool upgrades are only bought at the Lab.
local function atLab(player: Player, trusted: boolean): boolean
	if trusted then
		return true
	end
	if BaseBuild.levelOf(effective, "lab") < 1 then
		reject(player, "need_lab")
		return false
	end
	local prompt = asPrompt(world and world.labPrompt)
	local position = if prompt then promptPosition(prompt) else nil
	local root = rootOf(player)
	if position == nil or root == nil or (root.Position - position).Magnitude > LAB_RANGE_STUDS + PROMPT_EXTRA_RANGE then
		reject(player, "lab_far")
		return false
	end
	return true
end

local function doLearnSkill(player: Player, id: any, trusted: boolean)
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
	if not atLab(player, trusted) then
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

local function doUpgradeTool(player: Player, id: any, trusted: boolean)
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
	if not atLab(player, trusted) then
		return
	end
	local upgrade = (BASE.TOOL_UPGRADES :: any)[id]
	local current = if upgrade then math.clamp(BaseBuild.levelOf(base.tools, id), 1, upgrade.maxLevel) else 1
	local unlocked = BaseBuild.toolsUnlocked(MissionData, effective)
	local ok, reason = BaseBuild.canUpgradeTool(MissionData, id, current, levelOf(base), base.credits, unlocked)
	local cost = BaseBuild.toolUpgradeCost(MissionData, id, current)
	if not ok or cost == nil then
		reject(player, reason or "unknown")
		return
	end
	local nextLevel = current + 1
	api.updateBase(player, function(saved: BaseRecord)
		saved.credits -= cost
		saved.tools[id] = math.max(BaseBuild.levelOf(saved.tools, id), nextLevel)
	end)
	sayTo(player, "carl.base.tool_upgraded", { n = nextLevel })
	refreshTools(player)
	scheduleSend(player)
end

local function fireGear(player: Player)
	fireListeners(gearListeners, player, "gear")
end

-- Buys (level 1, switched on at once) or upgrades a piece of gear at the Lab.
local function doBuyGear(player: Player, id: any, trusted: boolean)
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
	if not atLab(player, trusted) then
		return
	end
	local def = BaseBuild.gearDef(MissionData, id)
	local current = BaseBuild.levelOf(gearLevelsOf(base), id)
	local ok, reason = BaseBuild.canBuyGear(MissionData, id, current, levelOf(base), base.credits)
	if not ok or def == nil then
		reject(player, reason or "unknown")
		return
	end
	local nextLevel = current + 1
	local cost = def.costs[nextLevel] :: number
	api.updateBase(player, function(saved: BaseRecord)
		saved.credits -= cost
		saved.gear[id] = math.max(BaseBuild.levelOf(saved.gear, id), nextLevel)
		if nextLevel == 1 then
			saved.gearOn[id] = true -- new gear is worn and working at once
		end
	end)
	if nextLevel == 1 then
		sayTo(player, "carl.base.gear_bought", { k = tostring(def.key) })
	else
		sayTo(player, "carl.base.gear_upgraded", { n = nextLevel })
	end
	applyGear(player)
	fireGear(player)
	scheduleSend(player)
end

-- Switches owned gear on or off (anywhere: keys B / J on the client).
local function doToggleGear(player: Player, id: any)
	local api = progress
	local base = baseOf(player)
	if api == nil or base == nil or not isLoaded(player) then
		reject(player, "wait")
		return
	end
	if type(id) ~= "string" or BaseBuild.gearDef(MissionData, id) == nil then
		reject(player, "unknown")
		return
	end
	if BaseBuild.levelOf(gearLevelsOf(base), id) < 1 then
		reject(player, "not_owned")
		return
	end
	local on = not (base.gearOn ~= nil and base.gearOn[id] == true)
	api.updateBase(player, function(saved: BaseRecord)
		saved.gearOn[id] = on
	end)
	applyGear(player)
	fireGear(player)
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

local function doBuyPet(player: Player, id: any, trusted: boolean)
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
	if not atLab(player, trusted) then
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

local function doResetBase(player: Player)
	local api = progress
	if api == nil then
		return
	end
	api.resetBase(player)
	-- Builds this player paid for are dropped (their credits were reset too).
	for id, job in jobs do
		if job.payerId == player.UserId then
			jobs[id] = nil
			worldCall("setBuildLevel", id, BaseBuild.levelOf(effective, id), false)
		end
	end
	pendingOwner[player.UserId] = nil
	foodReady[player] = nil
	if carrying[player] then
		setCarrying(player, false)
	end
	applySkillEffects(player)
	recompute(false)
	refreshPrompts()
	refreshTools(player)
	fireEquipped(player)
	fireGear(player)
	scheduleSendAll()
end

local function dispatch(player: Player, action: any, trusted: boolean)
	local kind = action.type
	if kind == "Build" then
		doBuild(player, action.id, trusted)
	elseif kind == "LearnSkill" then
		doLearnSkill(player, action.id, trusted)
	elseif kind == "Equip" then
		doEquip(player, action.slot, action.value)
	elseif kind == "BuyPet" then
		doBuyPet(player, action.id, trusted)
	elseif kind == "ClaimSilo" then
		doClaimSilo(player, trusted)
	elseif kind == "UpgradeTool" then
		doUpgradeTool(player, action.id, trusted)
	elseif kind == "BuyGear" then
		doBuyGear(player, action.id, trusted)
	elseif kind == "ToggleGear" then
		doToggleGear(player, action.id)
	elseif kind == "DebugMeteor" then
		local hook = debugMeteorHook
		if hook and isDebugAllowed(player, trusted) then
			task.spawn(function()
				local ok, err = pcall(hook, player, trusted)
				if not ok then
					warn(`[SpaceBaseOdyssey] debug meteor failed: {err}`)
				end
			end)
		end
	elseif kind == "DebugGrantCredits" then
		local amount = action.amount
		if not isDebugAllowed(player, trusted) or not isLoaded(player) then
			return
		end
		if type(amount) ~= "number" or amount ~= amount or amount < 1 then
			return
		end
		local whole = math.floor(math.min(amount, DEBUG_MAX_GRANT))
		grant(player, whole, whole, true)
	elseif kind == "DebugResetBase" then
		if not isDebugAllowed(player, trusted) or not isLoaded(player) then
			return
		end
		doResetBase(player)
	elseif kind == "DebugBuildNext" then
		if not isDebugAllowed(player, trusted) or not isLoaded(player) then
			return
		end
		debugBuildNext(player)
	elseif kind == "DebugMaxResources" then
		-- F6 (with DebugUnlockAll): just enough credits to buy every build level, tool upgrade, gear
		-- level and pet, and the XP for the top player level. Nothing is given twice.
		local base = baseOf(player)
		if not isDebugAllowed(player, trusted) or not isLoaded(player) or base == nil then
			return
		end
		local total = 0
		local function addCosts(costs: { number })
			for _, cost in costs do
				total += cost
			end
		end
		for _, def in MissionData.BASE.BUILDS do
			addCosts(def.costs)
		end
		for _, up in MissionData.BASE.TOOL_UPGRADES do
			addCosts(up.costs)
		end
		for _, def in MissionData.BASE.GEAR do
			addCosts(def.costs)
		end
		for _, def in MissionData.BASE.PETS do
			total += def.cost or 0
		end
		local topXp = MissionData.BASE.LEVEL_XP[#MissionData.BASE.LEVEL_XP]
		grant(player, math.max(0, total - base.credits), math.max(0, topXp - base.xp), true)
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
	-- Builds this player paid for and others finished while they were away (same server session).
	local pending = pendingOwner[player.UserId]
	if pending then
		pendingOwner[player.UserId] = nil
		api.updateBase(player, function(saved: BaseRecord)
			for id, level in pending do
				saved.builds[id] = math.max(BaseBuild.levelOf(saved.builds, id), level)
			end
		end)
	end
	for _, job in jobs do
		if job.payerId == player.UserId then
			job.payer = player
		end
	end
	applySkillEffects(player)
	recompute(false)
	refreshTools(player)
	fireEquipped(player)
	fireGear(player)
	sendNow(player)
end

-- Stage 10: a player arriving during the showcase (on the start menu) gets the eclipse preview a
-- moment later, once per showcase, so the menu's first shot shows the Earth about to hide the Sun.
local function previewShowcaseEclipse()
	if not showcaseOn or showcaseEclipseDone then
		return
	end
	-- A solo trip's reserved server picks the slot at once (no menu shots): no preview there.
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return
	end
	showcaseEclipseDone = true
	task.delay(SHOWCASE_ECLIPSE_DELAY, function()
		if not showcaseOn then
			return
		end
		-- A save already loading (Continue pressed at once): the eclipse would land in gameplay.
		for other in present do
			if other:GetAttribute("SBO_SlotLoading") == true then
				return
			end
		end
		worldCall("previewEclipse")
	end)
end

local function addPlayer(player: Player)
	if present[player] then
		return
	end
	present[player] = true
	applySkillEffects(player) -- defaults until the saved data is read
	player:SetAttribute("SBO_CarryingCrate", false)
	local list: { RBXScriptConnection } = {}
	table.insert(
		list,
		player.CharacterAdded:Connect(function(character: Model)
			-- A new character never carries the old one's crate.
			if carrying[player] then
				carrying[player] = nil
				player:SetAttribute("SBO_CarryingCrate", false)
				scheduleSend(player)
			end
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
	else
		previewShowcaseEclipse()
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
	lastPromptAt[player] = nil
	lastSentAt[player] = nil
	sendScheduled[player] = nil
	carrying[player] = nil
	foodReady[player] = nil
	toolsSent[player] = nil
	for _, job in jobs do
		if job.payer == player then
			job.payer = nil -- the job stays for this server session
		end
	end
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

local function guarded(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[SpaceBaseOdyssey] {label} failed: {err}`)
	end
end

-- The pad's second prompt, for assembling a step with the wrench: same place, range and key as the
-- BuildPrompt, its own long hold. Off until a crate is at the pad.
local function makeAssemblePrompt(id: string, buildPrompt: ProximityPrompt): ProximityPrompt?
	local parent = buildPrompt.Parent
	if parent == nil then
		return nil
	end
	local existing = parent:FindFirstChild("AssemblePrompt")
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AssemblePrompt"
	prompt.ActionText = "Assemble" -- the client replaces it from TextKey (src/client/Prompts.luau)
	prompt.ObjectText = ""
	prompt.HoldDuration = BASE.ASSEMBLE_HOLD_SECONDS
	prompt.MaxActivationDistance = buildPrompt.MaxActivationDistance
	prompt.RequiresLineOfSight = buildPrompt.RequiresLineOfSight
	prompt.KeyboardKeyCode = buildPrompt.KeyboardKeyCode
	prompt.GamepadKeyCode = buildPrompt.GamepadKeyCode
	prompt.Exclusivity = buildPrompt.Exclusivity
	prompt.UIOffset = buildPrompt.UIOffset
	prompt.Style = buildPrompt.Style
	prompt.Enabled = false
	prompt:SetAttribute("BuildId", id)
	prompt:SetAttribute("SBO_Tool", "wrench") -- the tool this prompt needs in hand (client cues)
	prompt:SetAttribute("ObjectKey", `build.{id}.name`)
	prompt:SetAttribute("TextParams", HttpService:JSONEncode({ n = 1, m = 1 }))
	prompt:SetAttribute("TextKey", "prompt.assemble")
	prompt.Parent = parent
	return prompt
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
			promptHold[buildId] = buildPrompt.HoldDuration
			buildPrompt.Triggered:Connect(function(player: Player)
				guarded("build prompt", function()
					if present[player] and not promptLimited(player) and closeEnough(player, buildPrompt) then
						usePad(player, buildId, false)
					end
				end)
			end)
			local assemble = makeAssemblePrompt(buildId, buildPrompt)
			if assemble then
				local assemblePrompt: ProximityPrompt = assemble
				assemblePrompts[buildId] = assemblePrompt
				assemblePrompt.Triggered:Connect(function(player: Player)
					guarded("assemble prompt", function()
						if present[player] and not promptLimited(player) and closeEnough(player, assemblePrompt) then
							assemblePad(player, buildId)
						end
					end)
				end)
			end
		end
	end
	local siloPrompt = asPrompt(world and world.siloPrompt)
	if siloPrompt then
		siloPrompt.Triggered:Connect(function(player: Player)
			guarded("silo prompt", function()
				if present[player] and not promptLimited(player) then
					doClaimSilo(player, false)
				end
			end)
		end)
	end
	local depot = world and world.crateDepot
	local crateValue = if type(depot) == "table" then depot.prompt else nil
	local cratePrompt = asPrompt(crateValue)
	if cratePrompt then
		local depotPrompt: ProximityPrompt = cratePrompt
		depotPrompt.Triggered:Connect(function(player: Player)
			guarded("crate prompt", function()
				if present[player] and not promptLimited(player) and closeEnough(player, depotPrompt) then
					takeCrate(player)
				end
			end)
		end)
	else
		warn("[SpaceBaseOdyssey] world has no crateDepot prompt; builds need force (debug) to finish")
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- worldRefs: WorldBuilder.World (setBuildLevel, setBuildProgress, previewEclipse, buildPads, buildPrompts,
-- siloPrompt, setSilo, setCargoActive, crateDepot, setCarryCrate, labPrompt);
-- remoteEvents.baseState = Remotes.BASE_STATE; progressService: ProgressService (already started);
-- crewService (optional): CrewService, so a player carrying ice cannot take a crate too.
function BaseService.start(worldRefs: any, remoteEvents: Remotes, progressService: ProgressApi, crewService: CrewApi?)
	assert(not started, "BaseService already started")
	started = true
	world = worldRefs
	remotes = remoteEvents
	progress = progressService
	crew = crewService

	-- Start from an empty Moon (only the lander stands; every structure is a hologram).
	for _, def in BASE.BUILDS do
		applied[def.id] = 0
		worldCall("setBuildLevel", def.id, 0, false)
	end
	connectPrompts()
	refreshPrompts()
	setSiloVisual()
	-- Stage 10: nobody is loaded yet, so the world shows the showcase base (start menu cameras).
	recompute(false)

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

-- Handles a base action (MissionService routes every action here first). Returns true when the
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

-- Stage 10: true while the world shows the showcase base (no present player has a loaded save).
function BaseService.isShowcase(): boolean
	return showcaseOn
end

-- Stage 10: the build levels the world shows right now (the showcase or the effective builds; a copy).
-- For visuals only: game rules use effectiveBuilds.
function BaseService.shownBuilds(): Levels
	return table.clone(applied)
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
	return fullState(player)
end

-- Stage 7: builds in progress (a copy: build id -> level, stage, stages, crate).
function BaseService.inProgress(): { [string]: BuildProgress }
	return progressState()
end

-- Stage 7: true while the player carries a parts crate (also player attribute SBO_CarryingCrate).
function BaseService.isCarryingCrate(player: Player): boolean
	return carrying[player] == true
end

-- Stage 7: the level of tool `id` this player may carry (0 = not unlocked yet; 1 = basic).
function BaseService.toolLevel(player: Player, id: string): number
	return toolLevelsOf(player)[id] or 0
end

-- Stage 7: every tool this player may carry -> level (a copy).
function BaseService.tools(player: Player): { [string]: number }
	return toolLevelsOf(player)
end

-- Stage 7: called (with the player) when the tools that player may carry or their levels changed
-- (a build unlocked one, a Lab upgrade, their data loaded, a reset).
function BaseService.onToolsChanged(listener: (player: Player) -> ())
	table.insert(toolsListeners, listener)
end

-- Stage 7: ToolService tells BaseService which tool a player holds (fn(player, toolId) -> boolean).
-- Without a checker every tool counts as held (the game never gets stuck).
function BaseService.setToolChecker(fn: (player: Player, toolId: string) -> boolean)
	toolChecker = fn
end

-- Stage 7: server time (workspace:GetServerTimeNow()) when the greenhouse has fresh food for the
-- player; nil while no greenhouse stands.
function BaseService.foodReadyAt(player: Player): number?
	if BaseBuild.levelOf(effective, "greenhouse") < 1 or not present[player] then
		return nil
	end
	return foodReady[player] or 0
end

-- Stage 7: picks the player's food in the greenhouse. True when food was ready (then the next one
-- grows for BaseBuild.foodCooldown seconds: plants take time; the second dome grows more of them).
-- ToolService checks the prompt and the hands.
function BaseService.takeFood(player: Player): boolean
	if not present[player] or BaseBuild.levelOf(effective, "greenhouse") < 1 then
		return false
	end
	local now = serverNow()
	if now < (foodReady[player] or 0) then
		return false
	end
	foodReady[player] = now + BaseBuild.foodCooldown(MissionData, effective)
	scheduleSend(player)
	return true
end

-- Stage 7: remembers that the player scanned `key` ("poi:<id>"). True the first time only (the
-- caller gives the reward with BaseService.reward). Saved in the player's base data.
function BaseService.markScanned(player: Player, key: string): boolean
	local api = progress
	if api == nil or not isLoaded(player) or not api.isScannedKey(key) then
		return false
	end
	local base = baseOf(player)
	if base == nil or base.scanned[key] then
		return false
	end
	api.updateBase(player, function(saved: BaseRecord)
		saved.scanned[key] = true
	end)
	scheduleSend(player)
	return true
end

-- Stage 7: true when the player already scanned `key`.
function BaseService.hasScanned(player: Player, key: string): boolean
	local base = baseOf(player)
	return base ~= nil and base.scanned[key] == true
end

-- Stage 8: gear this player wears and has switched on -> level (a copy; off or not owned = missing).
-- The same values are the player attributes SBO_GearBoots / SBO_GearJetpack.
function BaseService.gearOn(player: Player): { [string]: number }
	local result: { [string]: number } = {}
	local base = if present[player] then baseOf(player) else nil
	if base == nil then
		return result
	end
	local on = gearOnOf(base)
	for id, level in gearLevelsOf(base) do
		if on[id] then
			result[id] = level
		end
	end
	return result
end

-- Stage 8: called (with the player) when that player's gear or its on/off may have changed.
function BaseService.onGearChanged(listener: (player: Player) -> ())
	table.insert(gearListeners, listener)
end

-- Stage 7: ExploreService handles DebugMeteor (Studio / place owner only; checked here first).
function BaseService.setDebugMeteorHook(fn: (player: Player, trusted: boolean?) -> ())
	debugMeteorHook = fn
end

-- Stage 9: credits and XP for work that is not a REWARDS kind (the antenna align bonus, quest
-- rewards). The "credits" and "xp" skills add their bonus, as for every grant. Returns what was given.
function BaseService.grantCredits(player: Player, credits: number, xp: number?): (number, number)
	if not present[player] or not isLoaded(player) then
		return 0, 0
	end
	local addCredits = if type(credits) == "number" and credits == credits then credits else 0
	local addXp = if type(xp) == "number" and xp == xp then xp else 0
	if addCredits <= 0 and addXp <= 0 then
		return 0, 0
	end
	return grant(player, addCredits, addXp)
end

-- Stage 9: the base level (the habitat level standing in this server; 0 before it stands).
function BaseService.habitatLevel(): number
	return BaseBuild.habitatLevel(effective)
end

-- Stage 9: extra credits for aligning the antenna at its current level (MissionData
-- ANTENNA_ALIGN_BONUS). MissionService pays it with grantCredits after REWARDS.antenna_aligned.
function BaseService.antennaBonus(): number
	return BaseBuild.antennaBonus(MissionData, effective)
end

-- Stage 9: QuestService gives BaseState.quest for a player (nil = no tracker). It is called on every
-- BaseState push; errors are caught and logged.
function BaseService.setQuestProvider(fn: (player: Player) -> any)
	questProvider = fn
end

-- Stage 9: sends the player a fresh BaseState soon (for example after quest progress).
function BaseService.pushState(player: Player)
	scheduleSend(player)
end

-- Stage 9: called with (player, ice) when a player collects silo ice by hand (the quest step "silo";
-- the cargo robot's trips do not count).
function BaseService.onSiloClaimed(listener: (player: Player, ice: number) -> ())
	table.insert(siloListeners, listener)
end

-- Stage 9: called with (owner, build id, level) when a build level is finished (owner = the player
-- whose save got it).
function BaseService.onBuildCompleted(listener: (player: Player, id: string, level: number) -> ())
	table.insert(buildDoneListeners, listener)
end

return BaseService
