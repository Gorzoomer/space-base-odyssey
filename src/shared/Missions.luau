--!strict
-- Space Base Odyssey - the mission list: a short training (tutorial) path, a three-chapter story with
-- a partial ending, and free play. Pure data: no Roblox instances, so it runs in Lune
-- (tests/missions.luau) as well as in Roblox.
--
-- Texts are localization keys built from the ids:
--   "mission.<id>.title", "mission.<id>.intro", "mission.<id>.outro", objective texts "obj.<ObjectiveId>".
-- Numbers here are GAME values (mission length, timings), chosen for playability.
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
		objectives = { obj("go_outside", 1), obj("return_inside", 1) },
		requires = {},
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
		objectives = { obj("set_power", 1), obj("start_shift", 1), obj("finish_day", 1) },
		requires = { "t1_steps" },
		autoComplete = true,
	},
	{
		id = "t3_tasks",
		kind = "Tutorial",
		order = 3,
		icon = "target",
		days = 1,
		schedule = { "Dust" },
		objectives = { obj("align_antenna", 1), obj("clean_panel", 1), obj("drill_ice", 1), obj("deliver_ice", 1) },
		requires = { "t2_power" },
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
		objectives = { obj("reach_shelter", 1), obj("survive_storm", 1) },
		requires = { "t3_tasks" },
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

-- A mission is unlocked when every mission it requires is in `completed`.
function Missions.isUnlocked(mission: Mission, completed: { [string]: boolean }): boolean
	for _, required in mission.requires do
		if not completed[required] then
			return false
		end
	end
	return true
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
