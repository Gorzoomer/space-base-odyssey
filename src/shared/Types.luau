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

-- Briefing: free roaming between missions (Stage 9: open world, no mission menu at start; missions
-- start from the mission console or the Missions button). Planning: power board, no clock. Shift: real-time work outside.
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

-- The mission being played (nil in Briefing, between missions).
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
	-- Builds standing in this world: the world OWNER's save (Stage 10 fix; before, the highest of all
	-- players present). The same for every player in the server.
	builds: { [string]: number },
	ownBuilds: { [string]: number }, -- this player's saved builds (a guest's own base, unchanged here)
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
	-- Stage 9: the quest tracker (QuestService, src/shared/Quests.luau). nil with an older server or
	-- before the player's data is loaded.
	quest: QuestState?,
	-- Stage 11 tycoon (the ice line, BaseService; nil with an older server):
	siloOwner: boolean?, -- true = this player may send the silo's ice (the world owner)
	lineStatus: string?, -- "off" | "run" | "full" (full = the belt stopped)
	plantLevel: number?, -- 0 none, 1 water plant (melter), 2 with the air maker
	airStatus: string?, -- "off" | "run" | "nopower" (the air maker needs solar arrays)
	product: string?, -- what the cargo robot delivers: "none" | "water" | "oxygen"
	machineCreditsPerMinute: number?, -- credits a minute the machines make now (before rounding per trip)
}

-- Stage 9: one step of a quest in the tracker. key = Quests.stepKey(id, i), shown with
-- Store.t(key, { n = target }). progress is capped at target.
export type QuestStepState = {
	key: string,
	progress: number,
	target: number,
	done: boolean,
	mission: string?, -- mission steps: the mission id (the client may offer to start it)
	-- Stage 11: true when the tracker should add "  progress/target" (counted steps with a target
	-- above 1, Quests.showsFraction). Build and tool levels say "level 2" in the text instead.
	counted: boolean?,
}

-- Stage 11 "C.A.R.L. asks" (QuestService, src/shared/Quiz.luau): the question card in
-- QuestState.quiz. The right answer is never sent; the client answers with Action AnswerQuiz.
export type QuizAnswer = {
	key: string, -- "quiz.<id>.a<i>"
	icon: string, -- key in src/shared/Icons.luau (picture answers for young readers)
}
export type QuizPrompt = {
	id: string,
	questionKey: string, -- "quiz.<id>.q"
	icon: string, -- card header icon (Icons)
	answers: { QuizAnswer }, -- 2 or 3, in button order (choice = index)
	xp: number, -- XP for the right answer (before the XP skill bonus)
}
-- How the last answer went (kept about 8 s so the card can show it). lineKey is what C.A.R.L.
-- said: "quiz.<id>.why" when right, "quiz.<id>.hint" when wrong (the question comes back later).
export type QuizResult = {
	id: string,
	right: boolean,
	xp: number, -- XP paid (0 when wrong)
	lineKey: string,
}

-- Stage 9: one quest as the tracker shows it. stepIndex = the first step not done (#steps + 1 when
-- every step is done).
export type QuestView = {
	id: string,
	kind: string, -- "main" | "side"
	titleKey: string, -- Quests.titleKey(id)
	icon: string, -- key in src/shared/Icons.luau
	stepIndex: number,
	steps: { QuestStepState },
	reward: { credits: number, xp: number },
}

-- Stage 9: BaseState.quest. The fields of QuestView describe the quest to show: the active main
-- quest, or once the main line is done the first open side quest (id = "" and no steps when none is
-- left; then show Quests.FINALE_KEY). sides lists every open side quest. mainCount / mainTotal: main
-- quests done and in the line.
export type QuestState = {
	id: string,
	kind: string,
	titleKey: string,
	icon: string,
	stepIndex: number,
	steps: { QuestStepState },
	reward: { credits: number, xp: number },
	mainDone: boolean,
	mainCount: number,
	mainTotal: number,
	sides: { QuestView },
	-- Stage 11: the "C.A.R.L. asks" question to show now (base mode only), and the last result.
	quiz: QuizPrompt?,
	quizResult: QuizResult?,
}

-- Stage 9 save slots: one row of the start menu (Remotes.SLOTS). used = false for an empty slot.
export type SlotMode = "solo" | "friends"
export type SlotInfo = {
	used: boolean,
	habitat: number?,
	level: number?,
	credits: number?,
	savedAt: number?, -- os.time() of the last save (0 = unknown: the save from before slots, now slot 1)
	mode: SlotMode?,
}

-- Stage 9: sent to one client before a slot is chosen and after it changes ("p_<userId>_meta"):
-- once the slot list is read, after RequestSlots, and after the slot is loaded. ProgressService
-- always fills every SlotInfo field. Until the player attribute SBO_SlotChosen is true the client
-- shows the start menu, or a loading card while SBO_SlotLoading is true (a solo trip, or a slot on
-- its way, or a reserved solo server choosing the slot from TeleportData).
export type SlotsMeta = {
	slots: { SlotInfo }, -- [1..3]
	last: number?, -- the slot played last
	current: number?, -- the slot this player plays in this server (nil on the start menu)
	offline: boolean?, -- true = saves could not be read: progress is kept only for this visit
	-- Stage 11: this player's saved settings (meta record; see PlayerSettings). nil = an older server.
	settings: PlayerSettings?,
}

-- Stage 11 "safer server": per-player settings kept in the player's meta record ("p_<userId>_meta",
-- field settings), so they survive the lobby-to-world teleport and rejoins. Sent in SlotsMeta.settings
-- and mirrored as player attributes the server sets: Language, SBO_MusicVolume, SBO_EffectsVolume,
-- SBO_FunFacts, SBO_Guidance (the client Store's SETTING_ATTRIBUTES). Changed with the SaveSettings
-- action (src/shared/ServerGuard.luau checks and clamps it).
export type PlayerSettings = {
	language: ("en" | "es")?, -- nil = never chosen: follow the device language
	musicVolume: number, -- 0..1 (steps of 0.01)
	effectsVolume: number, -- 0..1
	funFacts: boolean, -- C.A.R.L. fun facts on
	guidance: boolean, -- C.A.R.L. guidance beam on
	-- Stage 11 menu: accessibility (attributes SBO_BigText, SBO_ReduceMotion, SBO_ColourHelper,
	-- SBO_MessageSpeed). Optional so an older server's settings still type-check.
	bigText: boolean?, -- bigger text (Ui text helpers)
	reduceMotion: boolean?, -- no camera shake, no big tweens
	colourHelper: boolean?, -- icons and patterns next to colour-only signals
	messageSpeed: number?, -- ServerGuard.MESSAGE_SPEEDS: 1, 1.5 or 2 (C.A.R.L. bubbles stay longer)
}

-- Stage 10 fix: one open friends world on the "Join a friend" screen (src/shared/Worlds.luau View).
export type FriendWorld = {
	owner: number, -- the friend's UserId (JoinWorld.owner)
	name: string, -- the friend's display name
	baseLevel: number, -- their habitat level
	players: number, -- players in that world now
	max: number,
	full: boolean,
}

-- Stage 10 fix: the answer to ListFriendWorlds (Remotes.WORLDS). ok = false: the friends list could
-- not be read. here = true: this server is not a lobby (Studio), so there is no list to show.
export type FriendWorlds = {
	ok: boolean,
	worlds: { FriendWorld },
	here: boolean?,
}

-- Stage 10: sent to one player after each save of their slot (Remotes.SAVED).
-- Stage 11 tycoon: ice line moments for the client (Remotes.LINE, created by BaseService). "+N" pops
-- and cards are client work (wave 2); position = where the pop belongs in the world. mine = this
-- player got the credits (the world owner).
--   delivery: the cargo robot handed in a load at the hub's supply port (credits paid on arrival).
--   claim: ice sent to the base by hand at the silo (water).
--   away: sent once when the owner's slot loads: the drills dug `ice` for the silo while they were
--     away for `seconds` (capped = the silo filled up or OFFLINE_MAX_SECONDS ran out).
--   full: the silo is full and the belt stopped (once per fill, to the owner).
export type LineEvent = {
	kind: "delivery" | "claim" | "away" | "full",
	credits: number?,
	xp: number?,
	ice: number?,
	product: string?, -- "water" | "oxygen"
	position: Vector3?,
	mine: boolean?,
	seconds: number?,
	capped: boolean?,
	siloIce: number?,
	siloMax: number?,
}

export type SaveNotice = {
	ok: boolean, -- false only for a "Save now" that could not be written
	real: boolean, -- true = a DataStore (it stays); false = memory (only this test session)
	manual: boolean, -- true = the answer to a "Save now" (SaveNow action)
}

-- Stage 10: the player's learning achievements (Remotes.ACHIEVEMENTS), sent when their slot loads
-- and on every change. unlocked: ids of src/shared/Achievements.luau; counts: its lifetime counters.
-- new: the achievement that just unlocked (the client shows a toast), with the XP it paid.
export type AchievementState = {
	unlocked: { string },
	counts: { [string]: number },
	new: string?,
	xp: number?,
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

-- Stage 11 daily: the supply capsule and the Moon Logbook for one player (Remotes.DAILY, sent when
-- their slot loads, after every change and on RequestDaily). Rules in src/shared/Daily.luau.
--   calendar: the 7 days of the shown week (state "done" | "today" | "later"); ready = today's
--     capsule waits; factKey = the cargo fact on the card; nextIn = seconds to the next UTC day.
--   landing: where the capsule lands (beside the arrival lander's parts depot).
--   claimed / paid: the capsule just opened and what it paid (once, right after ClaimDaily).
--   stripes / wear: owned suit stripes (Daily.STRIPES ids) and the ones worn ("none").
--   logbook: found secrets, sites ({ id, found }), fresh craters scanned, unlocked achievements,
--     fun facts heard, entries / total, milestones ({ id, entries, stripe, claimed, ready }) and
--     `milestone` = the one just claimed (once).
export type DailyReward = {
	capsule: number,
	day: number,
	week: number,
	kind: "credits" | "xp" | "stripe",
	amount: number,
	stripe: string?,
	state: string?,
}
export type LogbookMilestone = { id: string, entries: number, stripe: string, claimed: boolean, ready: boolean }
export type LogbookState = {
	secrets: { string },
	sites: { { id: string, found: boolean } },
	meteors: number,
	meteorPage: number,
	achievements: { string },
	facts: { string },
	entries: number,
	total: number,
	milestones: { LogbookMilestone },
	milestone: string?,
}
export type DailyState = {
	ready: boolean,
	opened: number,
	week: number,
	calendar: { DailyReward },
	factKey: string,
	nextIn: number,
	landing: Vector3?,
	claimed: DailyReward?,
	paid: { credits: number, xp: number }?,
	stripes: { string },
	wear: string,
	logbook: LogbookState,
}

-- Client -> server requests.
export type Action =
	{ type: "SetCells", system: SystemId, cells: number }
	-- missionId nil = the next unlocked mission. Allowed in Briefing and Report ("Try again"); the
	-- client sends it from the mission panel (habitat console or Missions button).
	| { type: "StartMission", missionId: string? }
	| { type: "StartShift" }
	| { type: "Restart" } -- Report -> Briefing (back to the open base)
	| { type: "SetLanguage", language: "en" | "es" }
	-- Settings panel: at most 24 characters, trimmed, any case. The server replies through C.A.R.L.
	-- (carl.code_ok, carl.code_used, carl.code_bad); one attempt every 2 seconds per player.
	| { type: "RedeemCode", code: string }
	-- Stage 9 start menu: load save slot 1..3. Stage 10 fix: in the lobby both modes go to the owner's
	-- own reserved server ("solo" = nobody else, "friends" = up to 3 Roblox friends may join).
	-- fresh = New Game in that slot (wipes it). Accepted once per join, before a character exists.
	-- ProgressService validates slot, mode and fresh.
	| { type: "ChooseSlot", slot: number, mode: SlotMode, fresh: boolean }
	| { type: "RequestSlots" } -- send Remotes.SLOTS again (at most once a second)
	-- Stage 10 fix (private worlds; ProgressService validates both, lobby only): the open friends worlds
	-- of this player's Roblox friends (answer: FriendWorlds on Remotes.WORLDS, at most every 3 s), and
	-- joining one with one of this player's own slots (they keep their own explorer progress there).
	| { type: "ListFriendWorlds" }
	| { type: "JoinWorld", owner: number, slot: number }
	-- Stage 10, Settings panel "Save now": ProgressService saves the loaded slot as soon as the
	-- DataStore allows and answers on Remotes.SAVED (manual = true). Ignored before a slot is loaded.
	| { type: "SaveNow" }
	-- Stage 11: save this player's settings (any subset of PlayerSettings fields; bad fields are
	-- ignored, volumes clamped to 0..1). ProgressService accepts it on the start menu and in play, at
	-- most 5 a second, and keeps it in the meta record. SetLanguage also updates settings.language.
	-- Stage 11 menu: also bigText, reduceMotion, colourHelper (booleans) and messageSpeed (1 | 1.5 | 2).
	| { type: "SaveSettings", settings: { language: ("en" | "es")?, musicVolume: number?, effectsVolume: number?, funFacts: boolean?, guidance: boolean?, bigText: boolean?, reduceMotion: boolean?, colourHelper: boolean?, messageSpeed: number? } }
	-- Stage 10 achievements: the Sources screen ("Real NASA data") was opened. AchievementService
	-- accepts it only for a loaded slot, at most once every few seconds per player.
	| { type: "OpenSources" }
	-- Stage 11 "C.A.R.L. asks": answer the question in BaseState.quest.quiz. choice = 1..#answers, or
	-- 0 for "Not now". QuestService accepts only the question it offers right now, at most one answer
	-- a second; right = small XP bonus, wrong = a hint and the question comes back later.
	| { type: "AnswerQuiz", id: string, choice: number }
	-- Stage 11 daily (DailyService validates every one: a loaded slot, rate limits, the server's own
	-- day and logbook count). ClaimDaily opens today's supply capsule; RequestDaily asks for DailyState
	-- again; ClaimLogbook claims a logbook milestone; WearStripes picks owned suit stripes ("none" =
	-- off); HeardFact notes fun fact number `index` C.A.R.L. just shared (logbook facts page only).
	| { type: "ClaimDaily" }
	| { type: "RequestDaily" }
	| { type: "ClaimLogbook", id: string }
	| { type: "WearStripes", id: string }
	| { type: "HeardFact", index: number }
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
	SLOTS = "Slots", -- server -> one client: SlotsMeta (Stage 9 start menu)
	SAVED = "Saved", -- server -> one client: SaveNotice (Stage 10, after each save of their slot)
	WORLDS = "Worlds", -- server -> one client: FriendWorlds (Stage 10 fix, the "Join a friend" list)
	ACHIEVEMENTS = "Achievements", -- server -> one client: AchievementState (Stage 10 learning achievements)
	LINE = "IceLine", -- server -> one client: LineEvent (Stage 11 tycoon, created by BaseService)
	DAILY = "Daily", -- server -> one client: DailyState (Stage 11 daily, created by DailyService)
})

return table.freeze({
	Remotes = Remotes,
})
