--!strict
-- Space Base Odyssey - network contract between server and clients.
-- The server owns the mission. It sends a full Snapshot on every change (and to each player who
-- joins late). Clients only send Actions; the server validates every one.
-- All player-facing text travels as localization keys; clients translate (see Localization).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Missions = require(script.Parent.Missions)
local Simulation = require(script.Parent.Simulation)

export type SystemId = Simulation.SystemId
export type EventId = Simulation.EventId
export type MeterId = Simulation.MeterId
export type Outcome = Simulation.Outcome
export type Allocation = Simulation.Allocation
export type DayRecord = Simulation.DayRecord
export type ShiftResult = Simulation.ShiftResult
export type LiveMeters = Simulation.LiveMeters
export type MissionKind = Missions.MissionKind
export type ObjectiveId = Missions.ObjectiveId

-- Briefing: lobby and guided intro. Planning: power board, no clock. Shift: real-time work outside.
-- Report: timeline of the mission with causes and stars.
export type Phase = "Briefing" | "Planning" | "Shift" | "Report"

export type TextRef = {
	key: string,
	params: { [string]: string | number }?,
}

-- What Earth knows about today's solar event. Shown on the Command Center screen and the
-- Sources screen. `source` says honestly whether it came from a live query or the archive.
export type SpaceWeather = {
	source: "live" | "archive",
	flareId: string,
	flareClass: string,
	flareDate: string,
	particles: boolean, -- false = big flare, no particle storm reached Earth (false alarm)
	fetchedAt: string?, -- ISO time of the live query, when source == "live"
}

-- Summary of the server's live NASA / CCMC DONKI query (last 30 days), shown on the Sources screen.
-- nil in a Snapshot while the query is still running. "unavailable": HTTP is off, the request
-- failed or timed out; the game then uses only the saved archive.
export type LiveWeather = {
	status: "live" | "unavailable",
	fetchedAt: string?, -- ISO time of the query (UTC), when status == "live"
	flaresLast30Days: number?,
	strongestClass: string?,
	strongestDate: string?, -- YYYY-MM-DD
	latestClass: string?,
	latestDate: string?, -- YYYY-MM-DD
}

-- Live state of the current shift (nil outside the Shift phase).
export type ShiftState = {
	endsAt: number, -- workspace:GetServerTimeNow() value
	antennaLinked: boolean,
	stormWarningAt: number?, -- when the warning was given
	stormArrivesAt: number?, -- when particles arrive; players outside the shelter are exposed
	stormEndsAt: number?,
	dustyArrays: number,
	leakActive: boolean,
	iceCoresDelivered: number,
}

-- One objective of the running mission. textKey is "obj.<id>"; objectives whose text shows the
-- target ("Finish {n} days": complete_days, deliver_ice_total, stars_at_least) take target as {n}.
export type ObjectiveState = {
	id: string,
	textKey: string,
	progress: number,
	target: number,
	done: boolean,
}

-- The mission being played (nil in Briefing, the mission select screen).
export type MissionInfo = {
	id: string,
	kind: string, -- MissionKind
	titleKey: string, -- "mission.<id>.title"
	objectives: { ObjectiveState },
}

-- Set in Report. missingKeys are the textKeys ("obj.<id>") of objectives that were not met.
export type MissionResult = {
	success: boolean,
	missingKeys: { string },
}

-- One card on the mission select screen. Unlocked / completed use every player in the server.
export type MissionCard = {
	id: string,
	kind: string, -- MissionKind
	titleKey: string,
	icon: string, -- key in Icons
	unlocked: boolean,
	completed: boolean,
	-- Stage 6: set when every required mission is done but a build it needs does not stand yet
	-- (a build id such as "solar"; lock text "ui.needs_build" with {name}). nil otherwise.
	missingBuild: string?,
}

export type Snapshot = {
	phase: Phase,
	day: number,
	totalDays: number,
	todayEvent: EventId,
	allocation: Allocation,
	cellsAvailable: number,
	-- During a Shift air, food, dose, water, pendingScience and sciencePoints are LIVE values: the day
	-- moving toward its end, plus task effects at once (Simulation.liveMeters). Sent at most about
	-- four times per second while they change. Meters are rounded to 0.1, science to whole points.
	air: number,
	food: number,
	dose: number,
	water: number, -- water tank, 0..waterMax (the air maker needs it)
	waterMax: number,
	sciencePoints: number, -- science sent to Earth (counts for stars)
	pendingScience: number, -- science waiting for the antenna to send it
	stars: number,
	outcome: Outcome,
	history: { DayRecord },
	shift: ShiftState?,
	spaceWeather: SpaceWeather?,
	liveWeather: LiveWeather?,
	mission: MissionInfo?,
	missionResult: MissionResult?,
	missions: { MissionCard },
}

-- Saved progress of one player, sent only to that player (Remotes.PROGRESS).
export type Progress = {
	completed: { [string]: boolean }, -- mission ids
	collectibles: { [string]: boolean }, -- "mini_earth" | "laika" | "cheese" | "mars_potato"
	cosmetics: { [string]: boolean }, -- event cosmetics from redeem codes: "explorer26"
}

-- Sent to one player right after a collectible pickup (Remotes.COLLECTED).
export type Collected = {
	id: string,
	isNew: boolean,
	allFound: boolean, -- the player now owns all four
}

-- Per-player data, sent only to that player.
export type PlayerStats = {
	suitO2: number,
	inside: boolean, -- inside a pressurized module
	sheltered: boolean, -- inside the regolith shelter
	carryingIce: boolean,
	suitMax: number, -- SUIT.MAX plus the "tank" skill (Stage 6)
}

-- Stage 6: what a player wears and shows. Values: helmet "standard" | "explorer26" (event code);
-- backpack "standard" | "laika" (collectible); carl "classic" | "earth" (mini Earth collectible);
-- pet "none" | "laika" | "cheese" | "rabbit" | "monkey". The server checks ownership on Equip.
export type Equipped = {
	helmet: string,
	backpack: string,
	carl: string,
	pet: string,
}

-- Stage 6: build-and-grow state, sent only to that player (Remotes.BASE_STATE) on join and change.
export type BaseState = {
	credits: number,
	xp: number,
	level: number,
	levelXp: number, -- total XP where this level started
	nextLevelXp: number?, -- total XP for the next level (nil at the top level)
	skillPoints: number,
	builds: { [string]: number }, -- EFFECTIVE builds standing in this server (highest of all players)
	ownBuilds: { [string]: number }, -- this player's saved builds
	skills: { [string]: number },
	pets: { [string]: boolean }, -- owned pets (bought + from collectibles)
	equipped: Equipped,
	siloIce: number, -- ice waiting in the silo (shared by the server)
	siloMax: number,
	icePerMinute: number, -- from every automatic drill standing
	-- Stage 7: builds being built in steps (shared by the server): build id -> the level being built,
	-- steps done, steps needed, and whether the current step's parts crate is already at the pad.
	inProgress: { [string]: BuildProgress },
	carryingCrate: boolean, -- this player carries a parts crate from the lander
	tools: { [string]: number }, -- tools this player can carry -> tool level (1 = basic)
	foodReadyAt: number?, -- workspace:GetServerTimeNow() when the greenhouse has fresh food for this player
	scanned: { [string]: boolean }, -- exploration sites this player has scanned
	gear: { [string]: number }, -- Stage 8: gear owned -> level ("boots", "jetpack"); missing = not owned
	gearOn: { [string]: boolean }, -- Stage 8: gear switched on (worn and working)
}

export type BuildProgress = {
	level: number, -- the level being built (current level + 1)
	stage: number, -- steps finished (0..stages)
	stages: number,
	crate: boolean, -- the parts for the next step are at the pad (only "Assemble" is left)
}

-- Stage 7: sent to one player when they scan an exploration site or a meteorite crater (card UI).
-- Text keys: "poi.<id>.name" / "poi.<id>.fact" for sites, "meteor.name" / "meteor.fact" for craters.
export type ExploreEvent = {
	kind: "poi" | "meteor",
	id: string, -- site id ("" for a meteorite)
	isNew: boolean, -- first time for this player (reward given)
}

-- Client -> server requests.
export type Action =
	{ type: "SetCells", system: SystemId, cells: number }
	-- missionId nil = the next unlocked mission. Allowed in Briefing and Report ("Try again").
	| { type: "StartMission", missionId: string? }
	| { type: "StartShift" }
	| { type: "Restart" } -- Report -> Briefing (mission select)
	| { type: "SetLanguage", language: "en" | "es" }
	-- Settings panel: at most 24 characters, trimmed, any case. The server replies through C.A.R.L.
	-- (carl.code_ok, carl.code_used, carl.code_bad); one attempt every 2 seconds per player.
	| { type: "RedeemCode", code: string }
	-- Stage 6 (BaseService validates: level, credits, requirements, ownership, distance for prompts).
	| { type: "Build", id: string } -- build or upgrade to the next level (also from the world prompt)
	| { type: "LearnSkill", id: string }
	| { type: "Equip", slot: "helmet" | "backpack" | "carl" | "pet", value: string }
	| { type: "BuyPet", id: string }
	| { type: "ClaimSilo" } -- also from the silo prompt
	| { type: "UpgradeTool", id: string } -- Stage 7, at the Lab (credits)
	| { type: "BuyGear", id: string } -- Stage 8, at the Lab: buy (level 1) or upgrade boots / jetpack
	| { type: "ToggleGear", id: string } -- Stage 8, anywhere: switch owned gear on or off (keys B / J)
	| { type: "DebugMeteor" } -- Stage 7, Studio / place owner only: a meteorite lands now
	| { type: "DebugBuildNext" } -- Studio / place owner only: finish or build the next structure, free
	| { type: "DebugMaxResources" } -- Studio / place owner only: credits and XP to unlock everything
	| { type: "DebugGrantCredits", amount: number } -- Studio / place owner only; also grants XP = amount
	| { type: "DebugResetBase" } -- Studio / place owner only: this player's builds, skills, credits, XP back to the start
	-- Owner-only, Studio or the place owner: deterministic testing and video recording.
	| { type: "DebugForceEvent", event: EventId }
	| { type: "DebugSkipToDay", day: number }
	| { type: "DebugSeed", seed: number }
	| { type: "DebugEndShift" }
	| { type: "DebugEclipse" }
	| { type: "DebugUnlockAll" } -- every mission unlocked for this server session (not saved)
	| { type: "DebugGrantCollectible", id: string }

-- Names of the RemoteEvents the server creates in ReplicatedStorage.Remotes.
local Remotes = table.freeze({
	FOLDER = "Remotes",
	SNAPSHOT = "Snapshot", -- server -> client: Snapshot
	PLAYER_STATS = "PlayerStats", -- server -> one client: PlayerStats
	MESSAGE = "AssistantMessage", -- server -> client: TextRef from the C.A.R.L. assistant
	ACTION = "Action", -- client -> server: Action
	PROGRESS = "Progress", -- server -> one client: Progress (on join and on change)
	COLLECTED = "Collected", -- server -> one client: Collected (right after a pickup)
	BASE_STATE = "BaseState", -- server -> one client: BaseState (Stage 6)
	EXPLORE = "Explore", -- server -> one client: ExploreEvent (Stage 7)
})

return table.freeze({
	Remotes = Remotes,
})
