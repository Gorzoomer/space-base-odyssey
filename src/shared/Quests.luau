--!strict
-- Space Base Odyssey - quests (Stage 9, team feedback): the game is an open world. There is no
-- mission menu any more; an ordered line of MAIN quests guides a new player through every mechanic,
-- from the first habitat to the Mars ship, and SIDE quests open along the way. After the last main
-- quest there is still more to do: side quests, free play, hidden secrets, exploring.
-- Pure data and pure helpers: no Roblox instances, so it runs in Lune (tests/base.luau) as well as on
-- the server (which tracks progress) and the client (the quest tracker).
--
-- Texts are localization keys built from the ids:
--   "quest.<id>.title" and "quest.<id>.step<i>" (i = 1, 2, ... in step order; every step text gets the
--   param {n} = Quests.stepTarget(step)), plus "quest.main_done" once every main quest is done.
--   Stage 11: COUNTED step texts never contain {n} (the tracker adds "0/4" itself: "Bring ice home
--   0/4"); build and tool_upgrade texts keep {n} = the level ("Upgrade the antenna to level 2") and
--   show no fraction. Main quests also have "quest.<id>.praise": C.A.R.L.'s line when the quest is
--   done, naming the strategy that worked ("More panels made more power"), not the kid.
--
-- Step types (only these, so the server can track them):
--   build        { id, level }  the effective build level stands (any player in the server built it)
--   mission      { id }         the mission is completed (an id of src/shared/Missions.luau)
--   gear         { id }         the player owns that gear (any level)
--   tool_upgrade { id, level }  the player's tool is at that level or more
--   ice          { count }      ice cores the player delivered (by hand or by vehicle)
--   clean        { count }      dusty solar arrays the player cleaned
--   silo         { count }      times the player claimed the silo (the cargo robot does not count)
--   meteor       { count }      fresh meteorite craters the player scanned
--   eat          { count }      fresh foods the player ate
--   vehicle      {}             the player drove a vehicle
--   visit        { place }      the player went to "lab" | "greenhouse" | "crater" | "garage"
--   scan         { count }      exploration sites the player has scanned (lifetime total)
--   skill        { count }      skill levels the player has learned (lifetime total)
--   collectible  { count }      hidden collectibles the player owns (lifetime total)
--   crate        { count }      Stage 11: parts boxes the player carried to a build pad
-- Counting rule: ice, silo, meteor, eat, crate, vehicle and visit count what happens WHILE the quest
-- is active (a main quest is active when it is the next one; a side quest once it is open). scan,
-- skill and collectible are finite, so they use the player's lifetime totals (Quests.isLifetime).
-- Stage 11: clean is a lifetime total too (dusty panels ever cleaned), so a kid who cleaned a panel
-- in the Base chores mission before "Talk to Earth" opened is never stuck waiting for dust.
-- Every step of the active quest shows at once; the quest is done when every step is done, then
-- its reward (credits and XP) is paid once.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type StepType =
	"build"
	| "mission"
	| "ice"
	| "clean"
	| "silo"
	| "scan"
	| "meteor"
	| "skill"
	| "gear"
	| "tool_upgrade"
	| "vehicle"
	| "visit"
	| "eat"
	| "collectible"
	| "crate"

export type Place = "lab" | "greenhouse" | "crater" | "garage"

export type Step = {
	type: StepType,
	id: string?, -- build / mission / gear / tool id
	level: number?, -- build / tool_upgrade level
	count: number?, -- counted steps
	place: Place?, -- visit
}

export type QuestKind = "main" | "side"

export type Quest = {
	id: string,
	kind: QuestKind,
	order: number, -- position in LIST (main quests first, in play order)
	icon: string, -- key in src/shared/Icons.luau
	steps: { Step },
	reward: { credits: number, xp: number }, -- GAME values, counted by tests/economy
	after: string?, -- side quests: the main quest that opens it (nil = open from the start)
}

-- What the server knows about one player, passed to stepDone / stepProgress. Missing fields = none.
export type View = {
	builds: { [string]: number }?, -- effective builds standing in the server
	missions: { [string]: boolean }?, -- missions this player completed
	gear: { [string]: number }?, -- gear id -> level owned
	tools: { [string]: number }?, -- tool id -> upgrade level
	counts: { [string]: number }?, -- step type -> count (see the counting rule above)
	visited: { [string]: boolean }?, -- places visited while the quest is active
}

local STEP_TYPES: { StepType } = {
	"build",
	"mission",
	"ice",
	"clean",
	"silo",
	"scan",
	"meteor",
	"skill",
	"gear",
	"tool_upgrade",
	"vehicle",
	"visit",
	"eat",
	"collectible",
	"crate",
}

-- Steps that carry a count (vehicle counts drives, always 1).
local COUNT_TYPES: { [string]: boolean } = {
	ice = true,
	clean = true,
	silo = true,
	scan = true,
	meteor = true,
	skill = true,
	eat = true,
	collectible = true,
	crate = true,
}

-- Counted from the player's lifetime totals (finite things), not from when the quest opened.
local LIFETIME_TYPES: { [string]: boolean } = {
	scan = true,
	skill = true,
	collectible = true,
	clean = true, -- Stage 11
}

local PLACES: { Place } = { "lab", "greenhouse", "crater", "garage" }

local function build(id: string, level: number): Step
	return { type = "build", id = id, level = level }
end

local function mission(id: string): Step
	return { type = "mission", id = id }
end

local function count(stepType: StepType, n: number): Step
	return { type = stepType, count = n }
end

local function visit(place: Place): Step
	return { type = "visit", place = place }
end

local function gear(id: string): Step
	return { type = "gear", id = id }
end

local function toolUpgrade(id: string, level: number): Step
	return { type = "tool_upgrade", id = id, level = level }
end

local function vehicle(): Step
	return { type = "vehicle" }
end

local function reward(credits: number, xp: number): { credits: number, xp: number }
	return { credits = credits, xp = xp }
end

-- MAIN quests, in play order. Base level (habitat) in brackets: each quest only asks for what that
-- base level allows (tests/base walks the line with the habitat tree).
local MAIN: { Quest } = {
	-- [1] Landing camp: survive one day.
	-- Stage 11: a first reward within about a minute of landing (start the free habitat at its pad,
	-- take a parts box at the lander, carry it back). Saves from before Stage 11 skip it
	-- (QuestService.sanitizeRecord, record version 2).
	{ id = "m00_landing", kind = "main", order = 0, icon = "crate", steps = { count("crate", 1) }, reward = reward(10, 10) },
	{ id = "m01_home", kind = "main", order = 0, icon = "home", steps = { build("habitat", 1), build("solar", 1), mission("t1_steps") }, reward = reward(10, 20) },
	{ id = "m02_food", kind = "main", order = 0, icon = "plant", steps = { build("greenhouse", 1), mission("t2_power"), count("eat", 1) }, reward = reward(10, 20) },
	{ id = "m03_earth", kind = "main", order = 0, icon = "antenna", steps = { build("antenna", 1), mission("t3_tasks"), count("clean", 1) }, reward = reward(10, 20) },
	{ id = "m04_storm", kind = "main", order = 0, icon = "shield", steps = { build("shelter", 1), mission("t4_storm") }, reward = reward(15, 25) },
	{ id = "m05_ice", kind = "main", order = 0, icon = "ice", steps = { visit("crater"), count("ice", 4) }, reward = reward(10, 20) },
	{ id = "m06_panels", kind = "main", order = 0, icon = "solar", steps = { build("solar", 2), mission("c1_arrival") }, reward = reward(20, 30) },
	-- [2] Science outpost: the Lab and the first automatic drill.
	{ id = "m07_outpost", kind = "main", order = 0, icon = "home", steps = { build("habitat", 2), build("lab", 1), visit("lab") }, reward = reward(20, 30) },
	{ id = "m08_learn", kind = "main", order = 0, icon = "flask", steps = { count("skill", 1), toolUpgrade("drill", 2) }, reward = reward(15, 25) },
	{ id = "m09_drills", kind = "main", order = 0, icon = "drill", steps = { build("drill_1", 1), count("silo", 2) }, reward = reward(20, 30) },
	{ id = "m10_storm", kind = "main", order = 0, icon = "storm", steps = { build("solar", 3), mission("c2_storm") }, reward = reward(25, 40) },
	{ id = "m11_explore", kind = "main", order = 0, icon = "explore", steps = { count("scan", 2), count("meteor", 1) }, reward = reward(25, 40) },
	{ id = "m12_garden", kind = "main", order = 0, icon = "plant", steps = { build("greenhouse", 2), visit("greenhouse"), count("eat", 3) }, reward = reward(20, 30) },
	-- [3] Mining base: more drills, the cargo robot, the moon buggy.
	{ id = "m13_mining", kind = "main", order = 0, icon = "robot", steps = { build("habitat", 3), build("drill_2", 1), build("cargo_bot", 1) }, reward = reward(30, 50) },
	{ id = "m14_wheels", kind = "main", order = 0, icon = "car", steps = { build("garage", 1), visit("garage"), vehicle() }, reward = reward(30, 50) },
	{ id = "m15_repair", kind = "main", order = 0, icon = "repair", steps = { mission("c3_failure"), build("antenna", 2) }, reward = reward(40, 60) },
	{ id = "m16_gear", kind = "main", order = 0, icon = "boots", steps = { gear("boots"), count("skill", 4) }, reward = reward(30, 50) },
	-- [4] Explorer base: the ice hauler, the laser link, the landing pad.
	{ id = "m17_explorer", kind = "main", order = 0, icon = "truck", steps = { build("habitat", 4), build("garage", 2), count("ice", 8) }, reward = reward(50, 80) },
	{ id = "m18_laser", kind = "main", order = 0, icon = "satellite", steps = { build("antenna", 3), build("drill_3", 1) }, reward = reward(50, 80) },
	{ id = "m19_pad", kind = "main", order = 0, icon = "flag", steps = { build("landing_pad", 1), count("meteor", 3) }, reward = reward(60, 100) },
	-- [5] Moon spaceport: the Mars ship, then secrets and side quests.
	{ id = "m20_spaceport", kind = "main", order = 0, icon = "home", steps = { build("habitat", 5), build("drill_2", 3) }, reward = reward(80, 120) },
	{ id = "m21_mars", kind = "main", order = 0, icon = "rocket", steps = { build("ship", 1) }, reward = reward(100, 150) },
}

-- SIDE quests: optional, open after a main quest (`after`), done in any order.
local SIDE: { Quest } = {
	{ id = "s_treasure", kind = "side", order = 0, icon = "gift", steps = { count("collectible", 4) }, reward = reward(40, 60), after = "m04_storm" },
	-- Stage 11: was 10 silo claims, which fought the cargo robot (it empties the silo every minute
	-- after m13). Now it teaches that a bigger drill digs more ice by itself.
	{ id = "s_ice_master", kind = "side", order = 0, icon = "ice", steps = { count("ice", 40), build("drill_1", 2) }, reward = reward(40, 60), after = "m13_mining" },
	{ id = "s_scientist", kind = "side", order = 0, icon = "telescope", steps = { count("scan", 5) }, reward = reward(40, 60), after = "m11_explore" },
	{ id = "s_farmer", kind = "side", order = 0, icon = "food", steps = { count("eat", 10) }, reward = reward(25, 40), after = "m12_garden" },
	{ id = "s_free_week", kind = "side", order = 0, icon = "planet", steps = { mission("free_play") }, reward = reward(60, 100), after = "m15_repair" },
	{ id = "s_jetpack", kind = "side", order = 0, icon = "jetpack", steps = { gear("jetpack") }, reward = reward(40, 60), after = "m16_gear" },
	{ id = "s_meteors", kind = "side", order = 0, icon = "meteor", steps = { count("meteor", 10) }, reward = reward(60, 100), after = "m19_pad" },
	{ id = "s_brain", kind = "side", order = 0, icon = "skills", steps = { count("skill", 15) }, reward = reward(60, 100), after = "m08_learn" },
	{ id = "s_all_drills", kind = "side", order = 0, icon = "drill", steps = { build("drill_1", 3), build("drill_2", 3), build("drill_3", 3) }, reward = reward(80, 120), after = "m20_spaceport" },
}

local LIST: { Quest } = {}
local byId: { [string]: Quest } = {}
for _, group in { MAIN, SIDE } do
	for _, quest in group do
		table.insert(LIST, quest)
		quest.order = #LIST
		for _, step in quest.steps do
			table.freeze(step)
		end
		table.freeze(quest.steps)
		table.freeze(quest.reward)
		table.freeze(quest)
		byId[quest.id] = quest
	end
end

local Quests = {}

Quests.MAIN = table.freeze(MAIN)
Quests.SIDE = table.freeze(SIDE)
Quests.LIST = table.freeze(LIST)
Quests.STEP_TYPES = table.freeze(STEP_TYPES)
Quests.PLACES = table.freeze(PLACES)
Quests.FINALE_KEY = "quest.main_done" -- shown once every main quest is done

function Quests.byId(id: string): Quest?
	return byId[id]
end

function Quests.titleKey(id: string): string
	return "quest." .. id .. ".title"
end

function Quests.stepKey(id: string, index: number): string
	return "quest." .. id .. ".step" .. tostring(index)
end

function Quests.isStepType(value: any): boolean
	return type(value) == "string" and table.find(STEP_TYPES, value :: any) ~= nil
end

function Quests.isPlace(value: any): boolean
	return type(value) == "string" and table.find(PLACES, value :: any) ~= nil
end

-- True for step types that carry a count.
function Quests.isCounted(stepType: string): boolean
	return COUNT_TYPES[stepType] == true
end

-- True for step types counted from lifetime totals (scan, skill, collectible).
function Quests.isLifetime(stepType: string): boolean
	return LIFETIME_TYPES[stepType] == true
end

-- Position of a main quest in the line (1-based), nil for side or unknown quests.
function Quests.mainIndex(id: string): number?
	for index, quest in MAIN do
		if quest.id == id then
			return index
		end
	end
	return nil
end

-- The first main quest not in `done` (nil once the whole main line is done).
function Quests.nextMain(done: { [string]: boolean }): Quest?
	for _, quest in MAIN do
		if not done[quest.id] then
			return quest
		end
	end
	return nil
end

function Quests.allMainDone(done: { [string]: boolean }): boolean
	return Quests.nextMain(done) == nil
end

-- True when a side quest is open: its `after` main quest is done (or it has none).
function Quests.isOpen(quest: Quest, done: { [string]: boolean }): boolean
	if quest.kind == "main" then
		return Quests.nextMain(done) == quest
	end
	return quest.after == nil or done[quest.after] == true
end

-- Side quests open and not done yet, in LIST order.
function Quests.sideAvailable(done: { [string]: boolean }): { Quest }
	local list: { Quest } = {}
	for _, quest in SIDE do
		if not done[quest.id] and Quests.isOpen(quest, done) then
			table.insert(list, quest)
		end
	end
	return list
end

-- Every quest active right now: the next main quest (if any) first, then the open side quests.
function Quests.active(done: { [string]: boolean }): { Quest }
	local list: { Quest } = {}
	local main = Quests.nextMain(done)
	if main then
		table.insert(list, main)
	end
	for _, quest in Quests.sideAvailable(done) do
		table.insert(list, quest)
	end
	return list
end

-- The number a step waits for: its count, its level, or 1. Also the {n} param of the step text
-- (only build and tool_upgrade texts show it; counted texts show the "have/need" fraction instead).
function Quests.stepTarget(step: Step): number
	if step.count ~= nil then
		return step.count
	end
	if step.level ~= nil then
		return step.level
	end
	return 1
end

local function numberIn(map: { [string]: number }?, key: string?): number
	if map == nil or key == nil then
		return 0
	end
	local value = map[key]
	return if type(value) == "number" then value else 0
end

-- (have, need) for one step: have is capped at need, so a tracker can show "have / need".
function Quests.stepProgress(step: Step, view: View): (number, number)
	local need = Quests.stepTarget(step)
	local have = 0
	local kind = step.type
	if kind == "build" then
		have = numberIn(view.builds, step.id)
	elseif kind == "mission" then
		have = if view.missions and step.id and view.missions[step.id] then 1 else 0
	elseif kind == "gear" then
		have = if numberIn(view.gear, step.id) >= 1 then 1 else 0
	elseif kind == "tool_upgrade" then
		have = numberIn(view.tools, step.id)
	elseif kind == "visit" then
		have = if view.visited and step.place and view.visited[step.place] then 1 else 0
	else
		have = numberIn(view.counts, kind)
	end
	return math.min(have, need), need
end

function Quests.stepDone(step: Step, view: View): boolean
	local have, need = Quests.stepProgress(step, view)
	return have >= need
end

-- Stage 11: saved quest records carry a version (QuestService). Version 2 added m00_landing at the
-- front of MAIN, so an older record's index (a position in the old line) moves one along: that kid
-- landed long ago and skips the new first quest, and its progress array still fits its quest.
Quests.RECORD_VERSION = 2

function Quests.migrateIndex(index: number, version: any): number
	local result = math.floor(index)
	if version ~= Quests.RECORD_VERSION then
		result += 1
	end
	return math.clamp(result, 1, #MAIN + 1)
end

-- Stage 11: true when the tracker shows a "have/need" fraction for the step (counted steps with a
-- target above 1). Build and tool levels never show one: "level 2  1/2" reads as half done.
function Quests.showsFraction(step: Step): boolean
	return COUNT_TYPES[step.type] == true and Quests.stepTarget(step) > 1
end

-- Stage 11: C.A.R.L.'s line when main quest `id` is done (nil for side quests: the generic line).
function Quests.praiseKey(id: string): string?
	local quest = byId[id]
	return if quest and quest.kind == "main" then "quest." .. id .. ".praise" else nil
end

-- Stage 11: "Hidden treasures" hints. While s_treasure is open, C.A.R.L. gives one riddle-like hint
-- after a while with no new find (QuestService, MissionData.QUESTS.TREASURE_HINT_SECONDS). Hints go
-- through the secrets not found yet, nearest first; the first round is vague, later rounds clearer.
-- Keys: "carl.treasure.<id>.1" and "carl.treasure.<id>.2". Never a marker: it stays a discovery.
local TREASURE_ORDER: { string } = { "mars_potato", "mini_earth", "cheese", "laika" }
Quests.TREASURE_QUEST = "s_treasure"
Quests.TREASURE_ORDER = table.freeze(TREASURE_ORDER)

function Quests.treasureHintKey(id: string, level: number): string
	return "carl.treasure." .. id .. "." .. tostring(math.clamp(level, 1, 2))
end

-- The hint to give after `given` hints so far, for the collectibles `owned` (id -> true); nil once
-- every secret is found.
function Quests.treasureHint(owned: { [string]: boolean }, given: number): string?
	local missing: { string } = {}
	for _, id in TREASURE_ORDER do
		if owned[id] ~= true then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return nil
	end
	local round = math.max(0, math.floor(given))
	local level = math.min(2, round // #missing + 1)
	return Quests.treasureHintKey(missing[round % #missing + 1], level)
end

function Quests.questDone(quest: Quest, view: View): boolean
	for _, step in quest.steps do
		if not Quests.stepDone(step, view) then
			return false
		end
	end
	return true
end

return table.freeze(Quests)
