--!strict
-- Space Base Odyssey - client state: latest Snapshot, PlayerStats and Progress (missions and hidden
-- collectibles), chosen language and the Action sender.
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
export type ChangeKind = "snapshot" | "stats" | "language" | "progress"
export type StormStage = "none" | "warning" | "storm"

-- Stage 4 parts of the Snapshot (see Types.luau). Read through the helpers below.
export type MissionObjective = Types.ObjectiveState
export type MissionInfo = Types.MissionInfo
export type MissionResult = Types.MissionResult
export type MissionCard = Types.MissionCard
export type Progress = Types.Progress

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

local snapshot: Snapshot? = nil
local stats: PlayerStats? = nil
local progress: Progress = { completed = {}, collectibles = {} }
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
	progress = { completed = completed, collectibles = collectibles }
	emit("progress")
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
