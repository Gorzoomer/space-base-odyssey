--!strict
-- Space Base Odyssey - the mission list: a short training (tutorial) path, a three-chapter story with
-- a partial ending, and free play. Pure data: no Roblox instances, so it runs in Lune
-- (tests/missions.luau) as well as in Roblox.
--
-- Texts are localization keys built from the ids:
--   "mission.<id>.title", "mission.<id>.intro", "mission.<id>.outro", objective texts "obj.<ObjectiveId>".
-- Numbers here are GAME values (mission length, timings), chosen for playability.
-- Stage 6: the base starts almost empty. A mission can need builds (`needs`: build id -> minimum
-- level, the ids of MissionData.BASE.BUILDS) and the training missions teach building with the
-- build_* objectives (done once that structure stands in the server).
-- Stage 7: a new player lands in the arrival lander and builds the whole base, the habitat first, so
-- every mission after first steps needs the habitat. Shift tasks need a tool in hand (OBJECTIVE_TOOLS:
-- ids of MissionData.BASE.TOOLS); MissionService checks it and tests/missions proves each tool is
-- unlocked by the builds a mission needs or teaches before that task.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

-- Same values as Simulation.EventId (duplicated so this module needs no require).
export type EventId = "None" | "Dust" | "SolarStorm" | "EquipmentFailure"

export type MissionKind = "Tutorial" | "Story" | "Free"

export type ObjectiveId =
	"go_outside"
	| "return_inside"
	| "set_power"
	| "start_shift"
	| "clean_panel"
	| "drill_ice"
	| "deliver_ice"
	| "align_antenna"
	| "repair_leak"
	| "reach_shelter"
	| "survive_storm"
	| "finish_day"
	| "complete_days"
	| "deliver_ice_total"
	| "stars_at_least"
	| "build_habitat"
	| "build_solar"
	| "build_greenhouse"
	| "build_antenna"
	| "build_shelter"

export type Objective = { id: ObjectiveId, target: number }

export type Mission = {
	id: string,
	kind: MissionKind,
	order: number,
	icon: string, -- key in src/shared/Icons.luau
	days: number,
	schedule: { EventId }?, -- nil = the random schedule of Simulation.newMission
	stormParticles: { boolean }?, -- one entry per SolarStorm in the schedule: true = particles arrive
	flareAtSeconds: number?, -- seconds into a storm shift when the flare is spotted (default MissionData)
	shiftSeconds: number?, -- shift length (default MissionData)
	objectives: { Objective },
	requires: { string }, -- mission ids that must be completed first
	-- Builds that must stand in the server to start (build id -> minimum level; nil = none). The
	-- training missions build what they teach, so they need only what earlier missions built.
	needs: { [string]: number }?,
	autoComplete: boolean, -- true = the mission ends as soon as every objective is done
}

local OBJECTIVE_IDS: { ObjectiveId } = {
	"go_outside",
	"return_inside",
	"set_power",
	"start_shift",
	"clean_panel",
	"drill_ice",
	"deliver_ice",
	"align_antenna",
	"repair_leak",
	"reach_shelter",
	"survive_storm",
	"finish_day",
	"complete_days",
	"deliver_ice_total",
	"stars_at_least",
	"build_habitat",
	"build_solar",
	"build_greenhouse",
	"build_antenna",
	"build_shelter",
}

-- build_* objectives and the build each one waits for (progress 1 once its level is at least 1).
local BUILD_OBJECTIVES: { [string]: string } = {
	build_habitat = "habitat",
	build_solar = "solar",
	build_greenhouse = "greenhouse",
	build_antenna = "antenna",
	build_shelter = "shelter",
}

-- Stable order for "build this first" (same order as MissionData.BASE.BUILDS; duplicated so this
-- module needs no require). Unknown ids come after these, sorted by name.
local BUILD_ORDER: { string } = {
	"habitat",
	"solar",
	"greenhouse",
	"lab",
	"antenna",
	"shelter",
	"drill_1",
	"drill_2",
	"drill_3",
	"cargo_bot",
	"garage",
	"landing_pad",
	"ship",
}

-- Shift tasks and the tool each one needs in hand (ids of MissionData.BASE.TOOLS).
local OBJECTIVE_TOOLS: { [string]: string } = {
	drill_ice = "drill",
	clean_panel = "brush",
	align_antenna = "tablet",
	repair_leak = "repair_kit",
}

-- Objective texts that show the target as {n} ("Finish {n} days").
local COUNTED_OBJECTIVES: { [string]: boolean } = {
	complete_days = true,
	deliver_ice_total = true,
	stars_at_least = true,
}

-- The four hidden collectibles (team decision). Owning all four opens the Observatory.
local COLLECTIBLES: { string } = { "mini_earth", "laika", "cheese", "mars_potato" }

local function obj(id: ObjectiveId, target: number): Objective
	return { id = id, target = target }
end

local LIST: { Mission } = {
	-- Training: one idea at a time. Tutorials never fail.
	{
		id = "t1_steps",
		kind = "Tutorial",
		order = 1,
		icon = "home",
		days = 1,
		schedule = { "None" },
		-- Step out of the lander, build the habitat and the first solar array (crates and the wrench),
		-- then go inside the new habitat.
		objectives = { obj("go_outside", 1), obj("build_habitat", 1), obj("build_solar", 1), obj("return_inside", 1) },
		requires = {},
		needs = nil,
		autoComplete = true,
	},
	{
		id = "t2_power",
		kind = "Tutorial",
		order = 2,
		icon = "power",
		days = 1,
		schedule = { "None" },
		shiftSeconds = 45, -- GAME: a short first shift
		objectives = { obj("build_greenhouse", 1), obj("set_power", 1), obj("start_shift", 1), obj("finish_day", 1) },
		requires = { "t1_steps" },
		needs = { habitat = 1, solar = 1 },
		autoComplete = true,
	},
	{
		id = "t3_tasks",
		kind = "Tutorial",
		order = 3,
		icon = "target",
		days = 1,
		schedule = { "Dust" },
		objectives = {
			obj("build_antenna", 1),
			obj("align_antenna", 1),
			obj("clean_panel", 1),
			obj("drill_ice", 1),
			obj("deliver_ice", 1),
		},
		requires = { "t2_power" },
		needs = { habitat = 1, solar = 1, greenhouse = 1 },
		autoComplete = true,
	},
	{
		id = "t4_storm",
		kind = "Tutorial",
		order = 4,
		icon = "shield",
		days = 1,
		schedule = { "SolarStorm" },
		stormParticles = { true },
		flareAtSeconds = 12, -- GAME: the warning comes quickly in training
		objectives = { obj("build_shelter", 1), obj("reach_shelter", 1), obj("survive_storm", 1) },
		requires = { "t3_tasks" },
		needs = { habitat = 1, solar = 1, greenhouse = 1, antenna = 1 },
		autoComplete = true,
	},
	-- Story: three chapters, ending with a partial ending (Mars is next, secrets remain).
	{
		id = "c1_arrival",
		kind = "Story",
		order = 5,
		icon = "rocket",
		days = 3,
		schedule = { "None", "Dust", "None" },
		objectives = { obj("complete_days", 3), obj("deliver_ice_total", 2) },
		requires = { "t4_storm" },
		needs = { habitat = 1, solar = 2, greenhouse = 1, antenna = 1, shelter = 1 }, -- more panels, more power
		autoComplete = false,
	},
	{
		id = "c2_storm",
		kind = "Story",
		order = 6,
		icon = "storm",
		days = 3,
		schedule = { "None", "SolarStorm", "Dust" },
		stormParticles = { true },
		objectives = { obj("complete_days", 3), obj("survive_storm", 1) },
		requires = { "c1_arrival" },
		needs = { habitat = 1, solar = 3, greenhouse = 1, antenna = 1, shelter = 1 }, -- the full base
		autoComplete = false,
	},
	{
		id = "c3_failure",
		kind = "Story",
		order = 7,
		icon = "repair",
		days = 4,
		schedule = { "EquipmentFailure", "SolarStorm", "Dust", "SolarStorm" },
		-- The second storm is a real big flare that brought no particle storm (a false alarm).
		stormParticles = { true, false },
		objectives = { obj("complete_days", 4), obj("repair_leak", 1), obj("stars_at_least", 2) },
		requires = { "c2_storm" },
		needs = { habitat = 1, solar = 3, greenhouse = 1, antenna = 1, shelter = 1 },
		autoComplete = false,
	},
	-- Free play: the original random week, unlocked after the story.
	{
		id = "free_play",
		kind = "Free",
		order = 8,
		icon = "planet",
		days = 7,
		schedule = nil,
		objectives = { obj("complete_days", 7) },
		requires = { "c3_failure" },
		needs = { habitat = 1, solar = 3, greenhouse = 1, antenna = 1, shelter = 1 },
		autoComplete = false,
	},
}

local byId: { [string]: Mission } = {}
for _, mission in LIST do
	table.freeze(mission.objectives)
	for _, objective in mission.objectives do
		table.freeze(objective)
	end
	table.freeze(mission.requires)
	if mission.needs then
		table.freeze(mission.needs)
	end
	if mission.schedule then
		table.freeze(mission.schedule)
	end
	if mission.stormParticles then
		table.freeze(mission.stormParticles)
	end
	table.freeze(mission)
	byId[mission.id] = mission
end

local Missions = {}

Missions.LIST = table.freeze(LIST)
Missions.OBJECTIVE_IDS = table.freeze(OBJECTIVE_IDS)
Missions.COLLECTIBLES = table.freeze(COLLECTIBLES)
Missions.BUILD_ORDER = table.freeze(BUILD_ORDER)
Missions.OBJECTIVE_TOOLS = table.freeze(OBJECTIVE_TOOLS)

function Missions.get(id: string): Mission?
	return byId[id]
end

function Missions.titleKey(id: string): string
	return "mission." .. id .. ".title"
end

function Missions.introKey(id: string): string
	return "mission." .. id .. ".intro"
end

function Missions.outroKey(id: string): string
	return "mission." .. id .. ".outro"
end

function Missions.objectiveKey(id: string): string
	return "obj." .. id
end

-- True when the objective text carries the target as the {n} placeholder.
function Missions.objectiveHasCount(id: string): boolean
	return COUNTED_OBJECTIVES[id] == true
end

function Missions.isObjectiveId(id: any): boolean
	return type(id) == "string" and table.find(OBJECTIVE_IDS, id :: any) ~= nil
end

function Missions.isCollectible(id: any): boolean
	return type(id) == "string" and table.find(COLLECTIBLES, id) ~= nil
end

local function buildLevel(builds: { [string]: number }, id: string): number
	local value = builds[id]
	return if type(value) == "number" then value else 0
end

-- The build a build_* objective waits for ("build_solar" -> "solar"), or nil for other objectives.
function Missions.buildForObjective(id: string): string?
	return BUILD_OBJECTIVES[id]
end

-- The tool a shift task needs in hand ("drill_ice" -> "drill"), or nil when it needs none.
function Missions.toolForObjective(id: string): string?
	return OBJECTIVE_TOOLS[id]
end

-- True when every build the mission needs stands (same rule as BaseBuild.meetsNeeds).
function Missions.meetsNeeds(mission: Mission, builds: { [string]: number }): boolean
	local needs = mission.needs
	if needs == nil then
		return true
	end
	for id, level in needs do
		if buildLevel(builds, id) < level then
			return false
		end
	end
	return true
end

-- The first build (in BUILD_ORDER) the mission needs that does not stand yet, or nil.
function Missions.missingBuild(mission: Mission, builds: { [string]: number }): string?
	local needs = mission.needs
	if needs == nil then
		return nil
	end
	for _, id in BUILD_ORDER do
		local level = needs[id]
		if level ~= nil and buildLevel(builds, id) < level then
			return id
		end
	end
	local others: { string } = {}
	for id, level in needs do
		if table.find(BUILD_ORDER, id) == nil and buildLevel(builds, id) < level then
			table.insert(others, id)
		end
	end
	table.sort(others)
	return others[1]
end

-- True when every mission it requires is in `completed`, ignoring builds.
function Missions.requiresDone(mission: Mission, completed: { [string]: boolean }): boolean
	for _, required in mission.requires do
		if not completed[required] then
			return false
		end
	end
	return true
end

-- A mission is unlocked when every mission it requires is in `completed` and, when `builds` (the
-- effective builds standing in the server) is given, every build it needs stands.
function Missions.isUnlocked(mission: Mission, completed: { [string]: boolean }, builds: { [string]: number }?): boolean
	if not Missions.requiresDone(mission, completed) then
		return false
	end
	return builds == nil or Missions.meetsNeeds(mission, builds)
end

-- How many SolarStorm days come before or on `day` (1-based index into stormParticles).
function Missions.stormIndex(mission: Mission, day: number): number
	local schedule = mission.schedule
	if schedule == nil then
		return 0
	end
	local count = 0
	for i = 1, math.min(day, #schedule) do
		if schedule[i] == "SolarStorm" then
			count += 1
		end
	end
	return count
end

return table.freeze(Missions)
