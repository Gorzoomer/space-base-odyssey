--!strict
-- Space Base Odyssey - mission list tests. Run with: lune run tests/missions
-- Checks every mission in src/shared/Missions.luau: ids unique, requires valid, schedule length equals
-- days, one stormParticles entry per SolarStorm day, objectives valid, icons exist. Then plays each
-- mission with the pure simulation: a careful crew can finish every story chapter, and a training
-- day can never empty a meter. Stage 6: every build a mission needs is a real build that can be
-- built in order, training builds what later missions need, a new player can pay for it all from
-- mission rewards alone, and each mission is played with only the solar arrays it needs.
-- Stage 7: first steps builds the habitat (every later mission needs it), BUILD_ORDER follows
-- MissionData.BASE.BUILDS, and every task that needs a tool in hand comes after the build that
-- unlocks that tool.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local BaseBuild = require("../src/shared/BaseBuild")
local Icons = require("../src/shared/Icons")
local Localization = require("../src/shared/Localization")
local MissionData = require("../src/shared/MissionData")
local Missions = require("../src/shared/Missions")
local Simulation = require("../src/shared/Simulation")

type Mission = Missions.Mission
type MissionState = Simulation.MissionState

local failures = 0
local passes = 0

local function check(condition: boolean, label: string)
	if condition then
		passes += 1
	else
		failures += 1
		print("FAIL  " .. label)
	end
end

local KINDS = { Tutorial = true, Story = true, Free = true }
local EVENTS = { None = true, Dust = true, SolarStorm = true, EquipmentFailure = true }
-- Fixed by the Stage 4 contract.
local EXPECTED_IDS = { "t1_steps", "t2_power", "t3_tasks", "t4_storm", "c1_arrival", "c2_storm", "c3_failure", "free_play" }

local function isWhole(value: any, low: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= low
end

-- 1. Structure.
check(#Missions.LIST == #EXPECTED_IDS, `mission count {#Missions.LIST} (expected {#EXPECTED_IDS})`)
for i, id in EXPECTED_IDS do
	local mission = Missions.LIST[i]
	check(mission ~= nil and mission.id == id, `mission {i} should be {id}`)
	check(Missions.get(id) == mission, `Missions.get("{id}") returns the listed mission`)
end
check(Missions.get("nope") == nil, "Missions.get returns nil for an unknown id")

local seen: { [string]: number } = {}
local freeCount = 0
local lastOrder = -math.huge
for index, mission in Missions.LIST do
	local id = mission.id
	check(type(id) == "string" and string.match(id, "^[%l%d_]+$") ~= nil, `mission {index}: id "{id}" is lower_snake_case`)
	check(seen[id] == nil, `mission {id}: id is unique`)
	seen[id] = index
	check(KINDS[mission.kind] == true, `mission {id}: kind {mission.kind} is valid`)
	if mission.kind == "Free" then
		freeCount += 1
	end
	check(isWhole(mission.order, 1) and mission.order > lastOrder, `mission {id}: order increases`)
	lastOrder = mission.order
	check(type(mission.icon) == "string" and (Icons :: any)[mission.icon] ~= nil, `mission {id}: icon "{mission.icon}" exists in Icons`)
	check(isWhole(mission.days, 1), `mission {id}: days is a whole number >= 1`)

	-- Requires: known, earlier in the list (so there are no cycles), not repeated.
	local requiredSeen: { [string]: boolean } = {}
	for _, required in mission.requires do
		check(seen[required] ~= nil and seen[required] < index, `mission {id}: requires "{required}" is an earlier mission`)
		check(not requiredSeen[required], `mission {id}: requires "{required}" only once`)
		requiredSeen[required] = true
	end
	if index > 1 then
		check(#mission.requires >= 1, `mission {id}: needs an earlier mission (only the first is open)`)
	else
		check(#mission.requires == 0, `mission {id}: the first mission is open`)
	end

	-- Schedule and storms.
	local storms = 0
	if mission.schedule then
		local schedule = mission.schedule :: { Missions.EventId }
		check(#schedule == mission.days, `mission {id}: schedule length {#schedule} == days {mission.days}`)
		for day, event in schedule do
			check(EVENTS[event] == true, `mission {id}: day {day} event {event} is valid`)
			if event == "SolarStorm" then
				storms += 1
			end
		end
	else
		check(mission.kind == "Free", `mission {id}: only free play uses the random schedule`)
		check(mission.days == MissionData.MISSION.TOTAL_DAYS, `mission {id}: random schedule needs the default length`)
	end
	local particles = mission.stormParticles
	if particles then
		check(#particles == storms, `mission {id}: stormParticles count {#particles} == SolarStorm days {storms}`)
		for i, value in particles do
			check(type(value) == "boolean", `mission {id}: stormParticles[{i}] is a boolean`)
		end
	else
		check(storms == 0 or mission.schedule == nil, `mission {id}: storm days need stormParticles`)
	end
	if mission.flareAtSeconds then
		check(isWhole(mission.flareAtSeconds, 1) and storms > 0, `mission {id}: flareAtSeconds is set only for storm missions`)
	end
	local shiftSeconds = mission.shiftSeconds or MissionData.MISSION.SHIFT_SECONDS
	check(isWhole(shiftSeconds, 10), `mission {id}: shiftSeconds is sensible`)
	if storms > 0 then
		-- The storm must fit in the shift even with the short (no antenna) warning.
		local flareAt = mission.flareAtSeconds or MissionData.STORM.FLARE_AT_SECONDS
		local stormEnd = flareAt + MissionData.STORM.WARNING_SECONDS_WITH_LINK + MissionData.STORM.DURATION_SECONDS
		check(stormEnd < shiftSeconds, `mission {id}: storm ends ({stormEnd} s) before the shift ({shiftSeconds} s)`)
	end

	-- Objectives.
	check(#mission.objectives >= 1, `mission {id}: has objectives`)
	local objectiveSeen: { [string]: boolean } = {}
	for _, objective in mission.objectives do
		check(Missions.isObjectiveId(objective.id), `mission {id}: objective "{objective.id}" is a known ObjectiveId`)
		check(not objectiveSeen[objective.id], `mission {id}: objective "{objective.id}" only once`)
		objectiveSeen[objective.id] = true
		check(isWhole(objective.target, 1), `mission {id}: objective "{objective.id}" target >= 1`)
		if objective.id == "complete_days" then
			check(objective.target == mission.days, `mission {id}: complete_days target == days`)
		elseif objective.id == "stars_at_least" then
			check(objective.target <= 3, `mission {id}: stars_at_least target <= 3`)
		elseif objective.id == "survive_storm" or objective.id == "reach_shelter" then
			check(storms > 0, `mission {id}: "{objective.id}" needs a storm day`)
		elseif objective.id == "repair_leak" then
			check(mission.schedule ~= nil and table.find(mission.schedule, "EquipmentFailure") ~= nil, `mission {id}: repair_leak needs a failure day`)
		elseif objective.id == "clean_panel" then
			check(mission.schedule ~= nil and table.find(mission.schedule, "Dust") ~= nil, `mission {id}: clean_panel needs a dust day`)
		end
	end
	-- Needs (Stage 6): real build ids and levels; build_* objectives teach a build the mission does
	-- not already need, and that build can be built once the needs stand.
	local needs = mission.needs or {}
	for buildId, level in needs do
		local def = BaseBuild.buildDef(MissionData, buildId)
		check(def ~= nil, `mission {id}: needs "{buildId}" is a build in MissionData.BASE.BUILDS`)
		if def then
			check(isWhole(level, 1) and level <= def.maxLevel, `mission {id}: needs {buildId} level {level} is 1..{def.maxLevel}`)
		end
		check(table.find(Missions.BUILD_ORDER, buildId) ~= nil, `mission {id}: needs "{buildId}" is in BUILD_ORDER`)
	end
	-- Stage 7: a mission can teach two builds in a row (first steps: habitat, then solar), so each one
	-- is checked against the needs plus the builds taught before it.
	local standing: { [string]: number } = table.clone(needs)
	for _, objective in mission.objectives do
		local buildId = Missions.buildForObjective(objective.id)
		if buildId then
			check(objective.target == 1, `mission {id}: "{objective.id}" target is 1`)
			check(BaseBuild.buildDef(MissionData, buildId) ~= nil, `mission {id}: "{objective.id}" names a real build`)
			check((needs[buildId] or 0) < 1, `mission {id}: "{objective.id}" is not already needed`)
			local ok, reason = BaseBuild.canBuild(MissionData, standing, 1, math.huge, buildId)
			check(ok, `mission {id}: "{objective.id}" can be built by a level 1 player once the needs and earlier builds stand ({reason})`)
			check(mission.kind == "Tutorial", `mission {id}: only training teaches building`)
			standing[buildId] = math.max(standing[buildId] or 0, 1)
		end
		-- Tools (Stage 7): a task that needs a tool in hand comes after the build that unlocks it.
		local toolId = Missions.toolForObjective(objective.id)
		if toolId then
			local tool = BaseBuild.toolDef(MissionData, toolId)
			check(tool ~= nil, `mission {id}: "{objective.id}" needs a real tool ({toolId})`)
			check(
				BaseBuild.toolsUnlocked(MissionData, standing)[toolId] == true,
				`mission {id}: the {toolId} for "{objective.id}" is unlocked by the builds standing by then`
			)
		end
	end
	-- Every mission after first steps happens at a standing habitat (Stage 7: the lander comes first).
	if index > 1 then
		check((needs.habitat or 0) >= 1, `mission {id}: needs the habitat`)
	end
	if mission.kind == "Tutorial" then
		check(mission.autoComplete, `mission {id}: tutorials end as soon as objectives are done`)
		check(mission.days == 1, `mission {id}: tutorials last one day`)
	else
		check(not mission.autoComplete, `mission {id}: story and free play run every day`)
		check(objectiveSeen.complete_days == true, `mission {id}: story and free play need complete_days`)
	end
end
check(freeCount == 1, "exactly one free play mission")

-- Every mission is reachable from the first one (requires only point backwards, so walk in order).
do
	local completed: { [string]: boolean } = {}
	for _, mission in Missions.LIST do
		check(Missions.isUnlocked(mission, completed), `mission {mission.id}: unlocked once earlier missions are done`)
		completed[mission.id] = true
	end
	check(Missions.isUnlocked(Missions.LIST[1], {}), "first mission is unlocked from the start")
	check(not Missions.isUnlocked(Missions.get("c1_arrival") :: Mission, {}), "story is locked at the start")
	check(Missions.isUnlocked(Missions.LIST[1], {}, {}), "first mission is unlocked with an empty base")
end

-- Needs: a completed chain is still locked while a needed build is missing, and missingBuild names
-- the first missing build in BUILD_ORDER.
do
	local allDone: { [string]: boolean } = {}
	for _, mission in Missions.LIST do
		allDone[mission.id] = true
	end
	local c1 = Missions.get("c1_arrival") :: Mission
	local c2 = Missions.get("c2_storm") :: Mission
	local t2 = Missions.get("t2_power") :: Mission
	check(not Missions.isUnlocked(t2, allDone, {}), "t2 needs the habitat and solar panels")
	check(not Missions.isUnlocked(t2, allDone, { solar = 1 }), "t2 needs the habitat")
	check(Missions.isUnlocked(t2, allDone, { habitat = 1, solar = 1 }), "t2 opens once the habitat and solar stand")
	check(Missions.isUnlocked(t2, allDone), "no builds given: needs are not checked")
	check(Missions.missingBuild(t2, {}) == "habitat", "t2 is missing the habitat first")
	check(Missions.missingBuild(t2, { habitat = 1 }) == "solar", "t2 is missing solar")
	check(Missions.missingBuild(t2, { habitat = 1, solar = 1 }) == nil, "t2 is missing nothing")
	local fullBase = { habitat = 1, solar = 3, greenhouse = 1, antenna = 1, shelter = 1 }
	local twoArrays = { habitat = 1, solar = 2, greenhouse = 1, antenna = 1, shelter = 1 }
	check(Missions.isUnlocked(c2, allDone, fullBase), "c2 opens with the full base")
	check(not Missions.isUnlocked(c2, allDone, twoArrays), "c2 needs three solar arrays")
	check(Missions.missingBuild(c2, twoArrays) == "solar", "c2 is missing solar")
	check(Missions.missingBuild(c1, { habitat = 1, solar = 2, greenhouse = 1 }) == "antenna", "c1 without antenna is missing antenna")
	check(Missions.missingBuild(c1, { habitat = 1, solar = 1, antenna = 1 }) == "solar", "missingBuild follows BUILD_ORDER")
	check(Missions.meetsNeeds(Missions.LIST[1], {}), "the first mission needs nothing")
	check(Missions.buildForObjective("build_habitat") == "habitat", "build_habitat waits for the habitat")
	-- BUILD_ORDER is the order of MissionData.BASE.BUILDS (duplicated so Missions needs no require).
	check(#Missions.BUILD_ORDER == #MissionData.BASE.BUILDS, `BUILD_ORDER has every build ({#Missions.BUILD_ORDER})`)
	for i, def in MissionData.BASE.BUILDS do
		check(Missions.BUILD_ORDER[i] == def.id, `BUILD_ORDER[{i}] is {def.id}`)
	end
	-- Tools named by objectives exist; tasks without a tool name none.
	for objectiveId, toolId in Missions.OBJECTIVE_TOOLS do
		check(Missions.isObjectiveId(objectiveId), `OBJECTIVE_TOOLS: "{objectiveId}" is an objective`)
		check(BaseBuild.toolDef(MissionData, toolId) ~= nil, `OBJECTIVE_TOOLS: "{toolId}" is a tool`)
	end
	check(Missions.toolForObjective("drill_ice") == "drill", "drilling ice needs the drill")
	check(Missions.toolForObjective("deliver_ice") == nil, "delivering ice needs no tool")
	for _, mission in Missions.LIST do
		-- Same answer as BaseBuild.meetsNeeds (Missions duplicates it to stay require-free).
		for _, builds in { {}, { solar = 1 }, { habitat = 1, solar = 1 }, twoArrays, fullBase } :: { { [string]: number } } do
			check(
				Missions.meetsNeeds(mission, builds) == BaseBuild.meetsNeeds(builds, mission.needs),
				`mission {mission.id}: meetsNeeds matches BaseBuild`
			)
		end
	end
	check(Missions.buildForObjective("build_solar") == "solar", "build_solar waits for solar")
	check(Missions.buildForObjective("drill_ice") == nil, "drill_ice is not a build objective")
end

-- Economy walk (Stage 6): a brand-new player plays the missions in order and earns only the smallest
-- rewards (first completion, one star, each day finished) plus build XP. Training builds what it
-- teaches; the rest of each mission's needs is bought before it starts. Credits never go below zero
-- and the player level is always high enough.
do
	local base = MissionData.BASE
	local credits = base.START_CREDITS
	local xp = 0
	local builds: { [string]: number } = {}
	local function earn(kind: string, count: number)
		local reward = (base.REWARDS :: any)[kind]
		credits += reward.credits * count
		xp += reward.xp * count
	end
	local function build(buildId: string, label: string)
		local level = BaseBuild.levelForXp(MissionData, xp)
		local cost = BaseBuild.nextCost(MissionData, builds, buildId)
		local ok, reason = BaseBuild.canBuild(MissionData, builds, level, credits, buildId)
		check(ok, `economy {label}: can build {buildId} (level {level}, {credits} credits, cost {cost}, {reason})`)
		if ok and cost then
			credits -= cost
			xp += BaseBuild.buildXp(MissionData, cost)
			builds[buildId] = (builds[buildId] or 0) + 1
		end
	end
	for _, mission in Missions.LIST do
		local needs = mission.needs or {}
		for _, buildId in Missions.BUILD_ORDER do
			local guard = 0
			while (builds[buildId] or 0) < (needs[buildId] or 0) and guard < 5 do
				build(buildId, `before {mission.id}`)
				guard += 1
			end
		end
		check(Missions.meetsNeeds(mission, builds), `economy: {mission.id} needs met before it starts`)
		local hasShift = false
		for _, objective in mission.objectives do
			local buildId = Missions.buildForObjective(objective.id)
			if buildId and (builds[buildId] or 0) < 1 then
				build(buildId, `during {mission.id}`)
			end
			hasShift = hasShift or not (objective.id == "go_outside" or objective.id == "return_inside" or buildId ~= nil)
		end
		-- First steps never starts a work shift, so it finishes no day.
		earn("day_finished", if hasShift then mission.days else 0)
		earn("star", 1)
		earn("mission_first", 1)
		check(credits >= 0, `economy after {mission.id}: credits {credits} >= 0`)
	end
	print(`economy walk: {credits} credits and {xp} XP left (level {BaseBuild.levelForXp(MissionData, xp)})`)
end

-- Collectibles.
check(#Missions.COLLECTIBLES == 4, "four collectibles")
for _, id in { "mini_earth", "laika", "cheese", "mars_potato" } do
	check(Missions.isCollectible(id), `collectible {id} is listed`)
end
check(not Missions.isCollectible("nope"), "unknown collectible rejected")

-- Key helpers.
check(Missions.titleKey("t1_steps") == "mission.t1_steps.title", "titleKey")
check(Missions.introKey("t1_steps") == "mission.t1_steps.intro", "introKey")
check(Missions.outroKey("c3_failure") == "mission.c3_failure.outro", "outroKey")
check(Missions.objectiveKey("drill_ice") == "obj.drill_ice", "objectiveKey")
check(Missions.stormIndex(Missions.get("c3_failure") :: Mission, 4) == 2, "stormIndex counts storm days")
check(Missions.stormIndex(Missions.get("c3_failure") :: Mission, 1) == 0, "stormIndex before the first storm")

-- 2. Play each mission with the pure simulation.
local function place(state: MissionState, wanted: { LifeSupport: number, Greenhouse: number, Science: number })
	for _, system in Simulation.SYSTEMS do
		Simulation.setAllocation(state, MissionData, system, 0)
	end
	for _, system in { "LifeSupport", "Greenhouse", "Science" } :: { Simulation.SystemId } do
		local cells = wanted[system]
		while cells > 0 do
			if Simulation.setAllocation(state, MissionData, system, cells) then
				break
			end
			cells -= 1
		end
	end
end

-- Played with only the solar arrays the mission needs (at least one): the fewest a crew can have.
local function arraysOf(mission: Mission): number
	local needs = mission.needs
	return math.max(1, if needs and needs.solar then needs.solar else 1)
end

local function configOf(mission: Mission): Simulation.MissionConfig
	return { totalDays = mission.days, schedule = mission.schedule, arrays = arraysOf(mission) }
end

for _, mission in Missions.LIST do
	-- A careful crew (shelters, cleans, repairs, one ice core a day) finishes every mission.
	local state = Simulation.newMission(MissionData, 2026, configOf(mission))
	local ice = 0
	while state.outcome == "InProgress" do
		Simulation.beginDay(state, MissionData)
		local lifeSupport = if state.air < 60 or state.leakActive then 2 else 1
		local greenhouse = if state.food < 45 then 2 else 1
		place(state, { LifeSupport = lifeSupport, Greenhouse = greenhouse, Science = 2 })
		ice += 1
		Simulation.endDay(state, MissionData, {
			playerCount = 1,
			iceCores = 1,
			arraysCleaned = state.arrays - state.cleanArrays,
			exposedAstronauts = 0,
			leakRepaired = state.leakActive,
			suitRefills = 2,
			antennaLinked = true,
		})
	end
	check(state.outcome == "Completed", `play {mission.id}: careful crew outcome {state.outcome}`)
	check(#state.history == mission.days, `play {mission.id}: lasted {#state.history} days (expected {mission.days})`)
	for _, objective in mission.objectives do
		if objective.id == "stars_at_least" then
			local stars = Simulation.stars(state, MissionData)
			check(stars >= objective.target, `play {mission.id}: careful crew earned {stars} stars (needs {objective.target})`)
		elseif objective.id == "deliver_ice_total" then
			check(ice >= objective.target, `play {mission.id}: enough days to deliver {objective.target} ice`)
		end
	end

	-- Training never fails: a day with no power plan, no tasks and everyone caught outside still
	-- leaves every meter above zero.
	if mission.kind == "Tutorial" then
		local worst = Simulation.newMission(MissionData, 1, configOf(mission))
		Simulation.beginDay(worst, MissionData)
		place(worst, { LifeSupport = 0, Greenhouse = 0, Science = 0 })
		Simulation.endDay(worst, MissionData, {
			playerCount = 1,
			iceCores = 0,
			arraysCleaned = 0,
			exposedAstronauts = 1,
			-- Stage 10 fix: every storm drill of the shift (at most STORM.MAX_DRILLS), all of it outside.
			stormExposure = MissionData.STORM.MAX_DRILLS,
			leakRepaired = false,
			suitRefills = 4,
			antennaLinked = false,
		})
		check(worst.outcome == "Completed", `tutorial {mission.id}: worst day still completes ({worst.outcome})`)
		check(worst.air > 0 and worst.food > 0, `tutorial {mission.id}: air {worst.air} and food {worst.food} stay above zero`)
		check(worst.dose < MissionData.METERS.DOSE_LIMIT, `tutorial {mission.id}: dose {worst.dose} stays under the limit`)
		-- The live HUD of a training shift never shows a meter in the red (MissionService also clamps).
		local red = MissionData.METERS.RED_ZONE
		check(worst.air > red and worst.food > red, `tutorial {mission.id}: worst day stays out of the red zone`)
		check(100 - worst.dose > red, `tutorial {mission.id}: worst dose stays out of the red zone`)
	end
end

-- Stage 10 fix: storms and radiation. Live playtest: storms felt "very, very frequent" with three
-- players. Storms come from the schedule, one event per day for the whole crew (never per player);
-- only the storm drill repeats, with a quiet break and a cap, so the longest drill still ends.
do
	local storm = MissionData.STORM
	for _, mission in Missions.LIST do
		local schedule = mission.schedule
		if schedule and mission.kind == "Story" then
			-- Never two storm days in a row in the story: a break between storms.
			for day = 2, #schedule do
				check(
					not (schedule[day] == "SolarStorm" and schedule[day - 1] == "SolarStorm"),
					`mission {mission.id}: no storms on two days in a row`
				)
			end
		end
	end
	local free = 0
	for _, event in MissionData.EVENTS.SHUFFLED do
		if event == "SolarStorm" then
			free += 1
		end
	end
	check(free <= 2, `free play: at most 2 storm days a week ({free})`)

	-- The storm drill: worst case, every drill runs (long warning with the antenna linked).
	local drill = Missions.get("t4_storm") :: Mission
	check(drill.flareAtSeconds ~= nil, "t4_storm: the first flare comes quickly")
	local cycle = storm.WARNING_SECONDS_WITH_LINK + storm.DURATION_SECONDS
	local longest = (drill.flareAtSeconds or storm.FLARE_AT_SECONDS) + storm.MAX_DRILLS * cycle
		+ (storm.MAX_DRILLS - 1) * storm.RETRY_GAP_SECONDS
	check(longest <= 6 * 60, `t4_storm: even with every drill the shift ends within 6 minutes ({longest} s)`)
	check(storm.RETRY_GAP_SECONDS > (drill.flareAtSeconds or 0), "t4_storm: a retry waits longer than the first flare")
	check(storm.OUTSIDE_REMINDER_SECONDS > 0 and storm.OUTSIDE_REMINDER_SECONDS < storm.DURATION_SECONDS, "storm: C.A.R.L. reminds players outside during a storm")
	-- The drill objectives survive a teammate who stays outside: survive_storm counts per player
	-- (MissionService), and the drill teaches reach_shelter first.
	local order: { string } = {}
	for _, objective in drill.objectives do
		table.insert(order, objective.id)
	end
	check(
		(table.find(order, "reach_shelter") or 99) < (table.find(order, "survive_storm") or 0),
		"t4_storm: reach the shelter comes before staying safe"
	)
end

-- Localization: every key the game builds at run time from these ids exists in every language
-- (the localization test only sees keys written out in full). Counted objectives carry {n}.
for _, language in Localization.LANGUAGES do
	local strings = Localization.STRINGS[language]
	for _, mission in Missions.LIST do
		for _, key in { Missions.titleKey(mission.id), Missions.introKey(mission.id), Missions.outroKey(mission.id) } do
			check(type(strings[key]) == "string", `{language}: {key} exists`)
		end
	end
	for _, objectiveId in Missions.OBJECTIVE_IDS do
		local text = strings[Missions.objectiveKey(objectiveId)]
		check(type(text) == "string", `{language}: obj.{objectiveId} exists`)
		if type(text) == "string" then
			local hasCount = string.find(text, "{n}", 1, true) ~= nil
			check(hasCount == Missions.objectiveHasCount(objectiveId), `{language}: obj.{objectiveId} uses {"{n}"} only when counted`)
		end
	end
	for _, id in Missions.COLLECTIBLES do
		for _, key in { `collect.{id}.name`, `card.{id}.myth`, `card.{id}.science`, `card.{id}.reward` } do
			check(type(strings[key]) == "string", `{language}: {key} exists`)
		end
	end
end

print(`missions: {passes} passed, {failures} failed`)
if failures > 0 then
	error("mission tests failed")
end
