--!strict
-- Space Base Odyssey - learning achievements (Stage 10, team request): small rewards for
-- UNDERSTANDING the science, each one tied to something the server really saw the player do.
-- Pure data and rules: no Roblox instances and no require, so it runs in Lune (tests/achievements)
-- as well as in Roblox. Numbers come from MissionData (passed in as `data`): the targets are GAME
-- values in MissionData.ACHIEVEMENTS, the facts quote REAL values from MissionData.REAL.
--
-- Texts are localization keys built from the ids:
--   "ach.<id>.title"  name (at most 8 words)
--   "ach.<id>.hint"   how to unlock it, shown while locked (at most 8 words; {n} = the target)
--   "ach.<id>.fact"   what you learned, shown once unlocked (one sentence, at most 16 words)
--
-- Kinds of rule (what the server checks, AchievementService.luau):
--   lesson   MissionService.onLearn sent this lesson to the player (a science moment)
--   count    a lifetime counter in the record reached data.ACHIEVEMENTS[target]
--   mission  every listed mission is completed in the player's save
--   level    the base (habitat) level standing in the world reached data.ACHIEVEMENTS[target]
--   build    a build stands in the world (level 1 or more)
--   sites    every exploration site of the world is scanned
--   action   the client opened the Sources screen (Action OpenSources, validated and rate-limited)
--
-- The saved record lives in the player's save slot (base field `achievements`, ProgressService):
--   { unlocked = { [id] = true }, counts = { ice = n, clean = n } }. A save without the field
--   loads as nothing unlocked (sanitizeRecord). Saves only grow: mergeRecord keeps every unlock and
--   the highest counter.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type Kind = "lesson" | "count" | "mission" | "level" | "build" | "sites" | "action"

export type Achievement = {
	id: string,
	icon: string, -- key in src/shared/Icons.luau
	kind: Kind,
	lesson: string?, -- lesson: MissionService.onLearn lesson id; action: the action name
	counter: string?, -- count: key in Record.counts
	target: string?, -- count / level: key in MissionData.ACHIEVEMENTS
	missions: { string }?, -- mission: ids in src/shared/Missions.luau
	build: string?, -- build: id in MissionData.BASE.BUILDS
	-- Placeholders: name -> key in MissionData.REAL (facts) or MissionData.ACHIEVEMENTS (hints).
	factParams: { [string]: string }?,
	hintParams: { [string]: string }?,
}

export type Record = {
	unlocked: { [string]: boolean },
	counts: { [string]: number },
}

-- What the server knows about one player right now (AchievementService builds it).
export type Facts = {
	lessons: { [string]: boolean }, -- lessons and actions seen just now
	missions: { [string]: boolean }, -- completed missions in the save
	baseLevel: number, -- habitat level standing in the world
	builds: { [string]: number }, -- builds standing in the world
	sitesScanned: number,
	siteTotal: number, -- 0 = unknown (the sites rule never unlocks then)
}

local COUNTERS: { string } = { "ice", "clean" }
local MAX_COUNT = 1000000

local LIST: { Achievement } = {
	{
		id = "air_from_water",
		icon = "drop",
		kind = "lesson",
		lesson = "air_from_water",
	},
	{
		id = "patient_farmer",
		icon = "greenhouse",
		kind = "lesson",
		lesson = "harvest",
		factParams = { days = "LETTUCE_DAYS_TO_HARVEST_ISS" },
	},
	{
		id = "mass_shield",
		icon = "shield",
		kind = "lesson",
		lesson = "storm_sheltered",
	},
	{
		id = "false_alarm",
		icon = "storm",
		kind = "lesson",
		lesson = "false_alarm",
	},
	{
		id = "hello_earth",
		icon = "antenna",
		kind = "lesson",
		lesson = "antenna_linked",
		factParams = { moon = "MOON_EARTH_LIGHT_TIME_S" },
	},
	{
		id = "ice_hunter",
		icon = "ice",
		kind = "count",
		counter = "ice",
		target = "ICE_TARGET",
		hintParams = { n = "ICE_TARGET" },
	},
	{
		id = "solar_cleaner",
		icon = "panel",
		kind = "count",
		counter = "clean",
		target = "PANEL_TARGET",
		hintParams = { n = "PANEL_TARGET" },
	},
	{
		id = "fact_finder",
		icon = "book",
		kind = "action",
		lesson = "OpenSources",
	},
	{
		id = "storm_ready",
		icon = "alert",
		kind = "mission",
		missions = { "t4_storm" },
		factParams = { min = "SEP_ARRIVAL_MINUTES" },
	},
	{
		id = "moon_builder",
		icon = "build",
		kind = "level",
		target = "BASE_LEVEL_TARGET",
		hintParams = { n = "BASE_LEVEL_TARGET" },
	},
	{
		id = "spaceport",
		icon = "rocket",
		kind = "build",
		build = "ship",
		factParams = { max = "MARS_LIGHT_TIME_MAX_MIN" },
	},
	{
		id = "explorer",
		icon = "explore",
		kind = "sites",
	},
	{
		id = "chapter_hero",
		icon = "flag",
		kind = "mission",
		missions = { "c1_arrival", "c2_storm", "c3_failure" },
	},
}

local byId: { [string]: Achievement } = {}
for _, def in LIST do
	if def.missions then
		table.freeze(def.missions)
	end
	if def.factParams then
		table.freeze(def.factParams)
	end
	if def.hintParams then
		table.freeze(def.hintParams)
	end
	table.freeze(def)
	byId[def.id] = def
end

local Achievements = {}

Achievements.LIST = table.freeze(LIST)
Achievements.COUNTERS = table.freeze(COUNTERS)

function Achievements.get(id: any): Achievement?
	return if type(id) == "string" then byId[id] else nil
end

function Achievements.isId(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function Achievements.isCounter(name: any): boolean
	return type(name) == "string" and table.find(COUNTERS, name) ~= nil
end

function Achievements.titleKey(id: string): string
	return "ach." .. id .. ".title"
end

function Achievements.hintKey(id: string): string
	return "ach." .. id .. ".hint"
end

function Achievements.factKey(id: string): string
	return "ach." .. id .. ".fact"
end

-- The number a count or level achievement waits for (0 when it has none).
function Achievements.targetOf(data: any, def: Achievement): number
	local key = def.target
	local config = data.ACHIEVEMENTS
	local value = if key and config then config[key] else nil
	return if type(value) == "number" then value else 0
end

local function params(source: any, map: { [string]: string }?): { [string]: number }?
	if map == nil or source == nil then
		return nil
	end
	local result: { [string]: number } = {}
	for name, key in map do
		local value = source[key]
		if type(value) == "number" then
			result[name] = value
		end
	end
	return result
end

-- Placeholder values for "ach.<id>.fact" (REAL values) and "ach.<id>.hint" (GAME targets).
function Achievements.factParams(data: any, def: Achievement): { [string]: number }?
	return params(data.REAL, def.factParams)
end

function Achievements.hintParams(data: any, def: Achievement): { [string]: number }?
	return params(data.ACHIEVEMENTS, def.hintParams)
end

-- Record helpers -----------------------------------------------------------------------------------

function Achievements.emptyRecord(): Record
	local counts: { [string]: number } = {}
	for _, name in COUNTERS do
		counts[name] = 0
	end
	return { unlocked = {}, counts = counts }
end

-- Any stored value -> a clean Record (unknown ids and counters dropped, counts whole and >= 0).
function Achievements.sanitizeRecord(value: any): Record
	local record = Achievements.emptyRecord()
	if type(value) ~= "table" then
		return record
	end
	if type(value.unlocked) == "table" then
		for id, flag in value.unlocked do
			if flag == true and Achievements.isId(id) then
				record.unlocked[id] = true
			end
		end
	end
	if type(value.counts) == "table" then
		for _, name in COUNTERS do
			local n = value.counts[name]
			if type(n) == "number" and n == n and n > 0 then
				record.counts[name] = math.min(math.floor(n), MAX_COUNT)
			end
		end
	end
	return record
end

function Achievements.cloneRecord(record: Record): Record
	return { unlocked = table.clone(record.unlocked), counts = table.clone(record.counts) }
end

-- Stored + this server's record (another server may have saved meanwhile): unlocks never go away
-- and each counter keeps its highest value.
function Achievements.mergeRecord(stored: any, current: any): Record
	local old = Achievements.sanitizeRecord(stored)
	local merged = Achievements.sanitizeRecord(current)
	for id in old.unlocked do
		merged.unlocked[id] = true
	end
	for name, n in old.counts do
		if n > (merged.counts[name] or 0) then
			merged.counts[name] = n
		end
	end
	return merged
end

-- Adds to a lifetime counter (unknown counters and bad amounts are ignored). Returns true if it changed.
function Achievements.addCount(record: Record, name: string, amount: number): boolean
	if not Achievements.isCounter(name) or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	local before = record.counts[name] or 0
	local after = math.min(before + math.floor(amount), MAX_COUNT)
	record.counts[name] = after
	return after ~= before
end

-- Rules ---------------------------------------------------------------------------------------------

-- True when the facts (and the record's counters) meet the achievement's rule.
function Achievements.isMet(data: any, def: Achievement, record: Record, facts: Facts): boolean
	local kind = def.kind
	if kind == "lesson" or kind == "action" then
		return def.lesson ~= nil and facts.lessons[def.lesson :: string] == true
	elseif kind == "count" then
		local target = Achievements.targetOf(data, def)
		return def.counter ~= nil and target > 0 and (record.counts[def.counter :: string] or 0) >= target
	elseif kind == "mission" then
		local missions = def.missions
		if missions == nil or #missions == 0 then
			return false
		end
		for _, id in missions do
			if facts.missions[id] ~= true then
				return false
			end
		end
		return true
	elseif kind == "level" then
		local target = Achievements.targetOf(data, def)
		return target > 0 and facts.baseLevel >= target
	elseif kind == "build" then
		local level = if def.build then facts.builds[def.build :: string] else nil
		return type(level) == "number" and level >= 1
	elseif kind == "sites" then
		return facts.siteTotal > 0 and facts.sitesScanned >= facts.siteTotal
	end
	return false
end

-- Ids (in list order) whose rule is met now and that the record has not unlocked yet. Does not
-- change the record.
function Achievements.newlyMet(data: any, record: Record, facts: Facts): { string }
	local result: { string } = {}
	for _, def in LIST do
		if not record.unlocked[def.id] and Achievements.isMet(data, def, record, facts) then
			table.insert(result, def.id)
		end
	end
	return result
end

-- Progress of a count or level achievement for the panel: (have, need); (0, 0) for other kinds.
function Achievements.progress(data: any, def: Achievement, record: Record, baseLevel: number?): (number, number)
	local need = Achievements.targetOf(data, def)
	if def.kind == "count" and def.counter then
		return math.min(record.counts[def.counter :: string] or 0, need), need
	elseif def.kind == "level" then
		return math.min(baseLevel or 0, need), need
	end
	return 0, 0
end

-- Ids unlocked in the record, in list order.
function Achievements.unlockedList(record: Record): { string }
	local result: { string } = {}
	for _, def in LIST do
		if record.unlocked[def.id] then
			table.insert(result, def.id)
		end
	end
	return result
end

return table.freeze(Achievements)
