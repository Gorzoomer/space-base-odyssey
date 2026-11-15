--!strict
-- Space Base Odyssey - mission list tests. Run with: lune run tests/missions
-- Checks every mission in src/shared/Missions.luau: ids unique, requires valid, schedule length equals
-- days, one stormParticles entry per SolarStorm day, objectives valid, icons exist. Then plays each
-- mission with the pure simulation: a careful crew can finish every story chapter, and a training
-- day can never empty a meter.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

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

local function configOf(mission: Mission): Simulation.MissionConfig
	return { totalDays = mission.days, schedule = mission.schedule }
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
			arraysCleaned = MissionData.POWER.ARRAYS - state.cleanArrays,
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
