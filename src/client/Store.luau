--!strict
-- Space Base Odyssey - client state: latest Snapshot, PlayerStats and Progress (missions, hidden
-- collectibles and event cosmetics), the player's BaseState (Stage 6: credits, XP, builds, skills,
-- pets, what they wear; Stage 7: builds in progress, the parts crate, tools, greenhouse food, scanned
-- sites), chosen language, local settings, the screen mode (mission select open or base mode), the
-- last exploration scan (Stage 7) and the Action sender.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local Types = require(Shared:WaitForChild("Types"))

export type Snapshot = Types.Snapshot
export type PlayerStats = Types.PlayerStats
export type TextRef = Types.TextRef
export type Action = Types.Action
export type LiveWeather = Types.LiveWeather
export type Language = "en" | "es"
-- "base": a new BaseState arrived. "view": the mission select opened or closed (base mode changed).
-- "explore" (Stage 7): the server sent an ExploreEvent (a site or meteorite crater was scanned).
export type ChangeKind = "snapshot" | "stats" | "language" | "progress" | "settings" | "base" | "view" | "explore"
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

-- Local player settings (Settings panel). Kept on this client and mirrored as attributes of the
-- local player (Store.SETTING_ATTRIBUTES) so other client scripts can read them.
export type SettingName = "musicVolume" | "effectsVolume" | "funFacts" | "guidance"
Store.SETTING_ATTRIBUTES = table.freeze({
	musicVolume = "SBO_MusicVolume",
	effectsVolume = "SBO_EffectsVolume",
	funFacts = "SBO_FunFacts",
	guidance = "SBO_Guidance",
} :: { [string]: string })
-- UI defaults (not gameplay numbers): volumes 0..1, C.A.R.L. features on.
local settings: { [string]: number | boolean } = {
	musicVolume = 0.6,
	effectsVolume = 0.8,
	funFacts = true,
	guidance = true,
}

local snapshot: Snapshot? = nil
local stats: PlayerStats? = nil
local progress: Progress = { completed = {}, collectibles = {}, cosmetics = {} }
local progressReceived = false
local base: BaseState? = nil
local lastExplore: ExploreEvent? = nil
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

function Store.setSetting(name: SettingName, value: number | boolean)
	if settings[name] == value then
		return
	end
	settings[name] = value
	local attribute = Store.SETTING_ATTRIBUTES[name]
	local player = game:GetService("Players").LocalPlayer
	if attribute and player then
		player:SetAttribute(attribute, value)
	end
	emit("settings")
end

-- Read settings back from the local player's attributes (they survive a client script restart).
function Store.loadSettings()
	local player = game:GetService("Players").LocalPlayer
	if not player then
		return
	end
	for name, attribute in Store.SETTING_ATTRIBUTES do
		local value = player:GetAttribute(attribute)
		if type(value) == type(settings[name]) then
			settings[name] = value
		else
			player:SetAttribute(attribute, settings[name])
		end
	end
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
