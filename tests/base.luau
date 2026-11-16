--!strict
-- Space Base Odyssey - build-and-grow rules tests (Stages 6 to 9). Run with: lune run tests/base
-- Checks MissionData.BASE is well formed and that src/shared/BaseBuild.luau follows it:
--   A. data: build / skill / pet ids unique, levels match their lists, requirements point to real
--      builds and never to themselves, icons exist, rewards give something; the habitat comes first;
--   B. player level from XP (15 levels), skill points;
--   C. build costs, requirements, habitat gates (Stage 9) and the "max" stop;
--   D. effective builds take the highest level of every present player;
--   E. skills: points, level gates, effects (speed, suit, credits, xp, builder); the drill is a tool
--      and the jump skill is the air boots now;
--   F. pets: collectible pets are found, never bought; bought pets need level and credits;
--   G. automatic drills: ice per minute, silo pay;
--   Q. Stage 11 tycoon: water plant, air maker power, delivery pay, offline ice, silo saves;
--   H. a new player can reach the first builds with START_CREDITS and simple work (no dead end);
--   I. building in steps: steps per level, assemble hold;
--   J. tools: unlocks, the drill tool upgrade (hold time, costs, gates);
--   K. food, meteorites and vehicles data;
--   L. gear (Stage 8): air boots and jetpack, buying, gas use, the gas tank; bonuses are whole numbers;
--   M. save migration (Stage 8): the old jump skill becomes air boots, its points come back;
--   N. the habitat tree (Stage 9): every structure level opens at one habitat level, per-level effects;
--   O. quests (Stage 9): step types, mission ids, builds reachable in order with the habitat tree;
--   P. the showcase base (Stage 10): every build at its top level while nobody has loaded a save;
--   R. Stage 11 tycoon client: sign lights, income rate, "+N" pops, the away card, the silo guide.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local BaseBuild = require("../src/shared/BaseBuild")
local Icons = require("../src/shared/Icons")
local MissionData = require("../src/shared/MissionData")

local BASE = MissionData.BASE

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

local function isWhole(value: any, low: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= low
end

local function iconExists(name: string): boolean
	local ok, value = pcall(function()
		return (Icons :: any)[name]
	end)
	if ok and value ~= nil then
		return true
	end
	local get = (Icons :: any).get
	if type(get) == "function" then
		local okGet, result = pcall(get, name)
		return okGet and result ~= nil and result ~= ""
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- A. Data

local EXPECTED_BUILDS = {
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
local EXPECTED_SKILLS = { "speed", "tank", "credits", "xp", "builder" }
local HABITAT_MAX = 5 -- Stage 9: the habitat (base level) goes from 1 to 5
local EXPECTED_GEAR = { "boots", "jetpack" }
local EXPECTED_TOOLS = { "wrench", "drill", "brush", "repair_kit", "tablet", "food" }

do
	local seen: { [string]: boolean } = {}
	for _, def in BASE.BUILDS do
		check(not seen[def.id], `A: build id {def.id} unique`)
		seen[def.id] = true
		check(isWhole(def.maxLevel, 1), `A: {def.id} maxLevel is a whole number >= 1`)
		check(#def.costs == def.maxLevel, `A: {def.id} has one cost per level`)
		-- Stage 9: structures are gated by the habitat level (hab), not by the player level.
		check(type(def.hab) == "table" and #def.hab == def.maxLevel, `A: {def.id} has one habitat level per level`)
		check((def :: any).minLevel == nil, `A: {def.id} has no player-level gate any more (hab replaces minLevel)`)
		for i = 1, def.maxLevel do
			check(isWhole(def.costs[i], 0), `A: {def.id} cost {i} is a whole number`)
			local hab = def.hab and def.hab[i]
			if def.id == "habitat" then
				check(hab == i - 1, `A: habitat level {i} needs habitat level {i - 1}`)
			else
				check(isWhole(hab, 1) and hab <= HABITAT_MAX, `A: {def.id} level {i} needs a real habitat level ({hab})`)
			end
			if i > 1 then
				check(def.costs[i] > def.costs[i - 1], `A: {def.id} level {i} costs more than level {i - 1}`)
				check(def.hab[i] >= def.hab[i - 1], `A: {def.id} level {i} needs at least the habitat of level {i - 1}`)
			end
		end
		for needId, needLevel in def.requires do
			local need = BaseBuild.buildDef(MissionData, needId)
			check(need ~= nil, `A: {def.id} requires a real build ({needId})`)
			check(needId ~= def.id, `A: {def.id} does not require itself`)
			if need then
				check(isWhole(needLevel, 1) and needLevel <= need.maxLevel, `A: {def.id} requires a reachable level of {needId}`)
			end
		end
		check(iconExists(def.icon), `A: {def.id} icon "{def.icon}" exists in Icons`)
	end
	for _, id in EXPECTED_BUILDS do
		check(seen[id] == true, `A: build {id} exists`)
	end
	check(#BASE.BUILDS == #EXPECTED_BUILDS, `A: {#BASE.BUILDS} builds (expected {#EXPECTED_BUILDS})`)

	-- Machines need electricity: drill_N needs N solar arrays.
	for n = 1, 3 do
		local def = BaseBuild.buildDef(MissionData, `drill_{n}`)
		check(def ~= nil and (def.requires.solar or 0) >= n, `A: drill_{n} needs {n} solar arrays`)
	end
	local solar = BaseBuild.buildDef(MissionData, "solar")
	check(solar ~= nil and solar.maxLevel == MissionData.POWER.ARRAYS, "A: solar levels = POWER.ARRAYS")

	local skillSeen: { [string]: boolean } = {}
	for _, def in BASE.SKILLS do
		check(not skillSeen[def.id], `A: skill id {def.id} unique`)
		skillSeen[def.id] = true
		check(#def.minLevel == def.maxLevel, `A: skill {def.id} has one player level per level`)
		check(iconExists(def.icon), `A: skill {def.id} icon "{def.icon}" exists in Icons`)
	end
	for _, id in EXPECTED_SKILLS do
		check(skillSeen[id] == true, `A: skill {id} exists`)
	end
	check(#BASE.SKILLS == #EXPECTED_SKILLS, `A: {#BASE.SKILLS} skills (expected {#EXPECTED_SKILLS})`)
	check(skillSeen.drill == nil, "A: the drill is a tool now, not a skill")
	check(skillSeen.jump == nil, "A: the jump skill became the air boots")
	check((BASE :: any).JUMP_POWER_BONUS == nil, "A: JUMP_POWER_BONUS is gone")
	check((BaseBuild :: any).hasDoubleJump == nil, "A: hasDoubleJump is gone (the boots give it)")
	check(#BASE.TOOL_UPGRADES.drill.holdFactor >= 3, "A: drill table covers 3 levels")
	local builderSkill = BaseBuild.skillDef(MissionData, "builder")
	check(builderSkill ~= nil and #BASE.BUILDER_HOLD_FACTOR == builderSkill.maxLevel, "A: one builder hold factor per level")
	check((BASE :: any).DRILL_HOLD_FACTOR == nil, "A: DRILL_HOLD_FACTOR moved to TOOL_UPGRADES.drill")
	check(#BASE.DRILL_ICE_PER_MINUTE >= 3, "A: drill ice table covers 3 levels")

	local petSeen: { [string]: boolean } = {}
	for _, def in BASE.PETS do
		check(not petSeen[def.id], `A: pet id {def.id} unique`)
		petSeen[def.id] = true
		check((def.collectible ~= nil) ~= (def.cost ~= nil), `A: pet {def.id} is found OR bought, not both`)
	end

	for kind, reward in BASE.REWARDS do
		check(isWhole(reward.credits, 0) and isWhole(reward.xp, 1), `A: reward {kind} gives XP (and credits >= 0)`)
	end
	for _, kind in { "crate_delivered", "stage_done", "food_eaten", "poi_scanned", "meteor_scanned" } do
		check((BASE.REWARDS :: any)[kind] ~= nil, `A: Stage 7 reward {kind} exists`)
	end

	-- The habitat is the first build: free, needs nothing, and every other build needs it (directly or
	-- through what it needs), because the game starts in the lander.
	local habitat = BaseBuild.buildDef(MissionData, "habitat")
	check(habitat ~= nil and habitat.costs[1] == 0 and next(habitat.requires) == nil, "A: habitat is free and needs nothing")
	check(habitat ~= nil and habitat.maxLevel == HABITAT_MAX, `A: the habitat (base level) goes up to {HABITAT_MAX}`)
	check(BASE.BUILDS[1].id == "habitat", "A: habitat is listed first")
	local function needsHabitat(id: string, depth: number): boolean
		local def = BaseBuild.buildDef(MissionData, id)
		if def == nil or depth > #BASE.BUILDS then
			return false
		end
		for needId in def.requires do
			if needId == "habitat" or needsHabitat(needId, depth + 1) then
				return true
			end
		end
		return false
	end
	for _, def in BASE.BUILDS do
		if def.id ~= "habitat" then
			check(needsHabitat(def.id, 0), `A: {def.id} needs the habitat first`)
		end
	end
	local garage = BaseBuild.buildDef(MissionData, "garage")
	check(garage ~= nil and garage.maxLevel == #BASE.VEHICLES, "A: one garage level per vehicle bay")
	for i = 2, #BASE.LEVEL_XP do
		check(BASE.LEVEL_XP[i] > BASE.LEVEL_XP[i - 1], `A: LEVEL_XP grows at level {i}`)
	end
	check(BASE.LEVEL_XP[1] == 0, "A: level 1 needs no XP")
end

----------------------------------------------------------------------------------------------------
-- B. Levels and skill points

do
	check(BaseBuild.levelForXp(MissionData, 0) == 1, "B: 0 XP is level 1")
	check(BaseBuild.levelForXp(MissionData, BASE.LEVEL_XP[2] - 1) == 1, "B: one XP short stays level 1")
	check(BaseBuild.levelForXp(MissionData, BASE.LEVEL_XP[2]) == 2, "B: LEVEL_XP[2] is level 2")
	check(BaseBuild.levelForXp(MissionData, 10 ^ 9) == #BASE.LEVEL_XP, "B: huge XP stops at the top level")
	check(BaseBuild.maxPlayerLevel(MissionData) == 15, "B: player levels 1 to 15")
	check(BaseBuild.xpForLevel(MissionData, 3) == BASE.LEVEL_XP[3], "B: xpForLevel reads LEVEL_XP")
	check(BaseBuild.xpForLevel(MissionData, #BASE.LEVEL_XP + 1) == nil, "B: no XP for a level above the top")
	for level = 1, #BASE.LEVEL_XP do
		check(BaseBuild.levelForXp(MissionData, BASE.LEVEL_XP[level]) == level, `B: exact XP of level {level}`)
	end
	check(BaseBuild.skillPoints(1, {}) == 1, "B: level 1 has one (waiting) skill point")
	check(BaseBuild.skillPoints(4, {}) == 4, "B: level 4 has 4 points")
	check(BaseBuild.skillPoints(4, { speed = 2 }) == 2, "B: spent points are taken away")
	check(BaseBuild.skillPoints(2, { speed = 3 }) == 0, "B: points never go below 0")
	check(BaseBuild.skillPoints(3, nil) == 3, "B: nil skills = none spent")
end

----------------------------------------------------------------------------------------------------
-- C. Building

do
	local empty: BaseBuild.Levels = {}
	local ok, reason = BaseBuild.canBuild(MissionData, empty, 1, 0, "habitat")
	check(ok and reason == nil, "C: the habitat is free at level 1")
	check(BaseBuild.nextCost(MissionData, empty, "habitat") == 0, "C: habitat costs 0")
	ok, reason = BaseBuild.canBuild(MissionData, empty, 10, 10 ^ 6, "solar")
	check(not ok and reason == "requires", "C: solar needs the habitat first")

	local home: BaseBuild.Levels = { habitat = 1 }
	ok, reason = BaseBuild.canBuild(MissionData, home, 1, 0, "solar")
	check(ok and reason == nil, "C: the first solar array is free at level 1")
	check(BaseBuild.nextCost(MissionData, home, "solar") == 0, "C: first solar costs 0")
	ok, reason = BaseBuild.canBuild(MissionData, home, 1, 10 ^ 6, "habitat")
	check(ok, "C: the habitat can grow to level 2 (the base level)")

	ok, reason = BaseBuild.canBuild(MissionData, home, 10, 10 ^ 6, "greenhouse")
	check(not ok and reason == "requires", "C: greenhouse needs solar first")

	local camp: BaseBuild.Levels = { habitat = 1, solar = 1 }
	local greenhouseCost = BaseBuild.nextCost(MissionData, camp, "greenhouse") :: number
	ok, reason = BaseBuild.canBuild(MissionData, camp, 1, 0, "greenhouse")
	check(not ok and reason == "credits", "C: greenhouse without credits says credits")
	ok, reason = BaseBuild.canBuild(MissionData, camp, 1, greenhouseCost, "greenhouse")
	check(ok, `C: greenhouse with {greenhouseCost} credits and solar 1`)
	-- Stage 9: the habitat is the town hall. The player level never gates a structure any more.
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1, greenhouse = 1 }, 15, 10 ^ 6, "greenhouse")
	check(not ok and reason == "habitat", "C: a bigger greenhouse needs habitat 2 (reason habitat)")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 2, solar = 1, greenhouse = 1 }, 1, 10 ^ 6, "greenhouse")
	check(ok, "C: greenhouse 2 at habitat 2, even at player level 1")

	-- Habitat 1 (landing camp): all three solar arrays, the greenhouse, the antenna and the shelter.
	ok, reason = BaseBuild.canBuild(MissionData, camp, 1, 10 ^ 6, "solar")
	check(ok, "C: a second solar array at habitat 1")
	local solarDef = BaseBuild.buildDef(MissionData, "solar") :: BaseBuild.BuildDef
	check(BaseBuild.nextCost(MissionData, { solar = 2 }, "solar") == solarDef.costs[3], "C: third solar array cost")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 3 }, 10, 10 ^ 6, "solar")
	check(not ok and reason == "max", "C: no fourth solar array")
	check(BaseBuild.nextCost(MissionData, { solar = 3 }, "solar") == nil, "C: maxed build has no cost")

	ok, reason = BaseBuild.canBuild(MissionData, {}, 10, 10 ^ 6, "rocket_pad")
	check(not ok and reason == "unknown", "C: unknown build id")
	check(BaseBuild.nextCost(MissionData, {}, "rocket_pad") == nil, "C: unknown build has no cost")

	-- Requirements check the EFFECTIVE builds: drill_1 needs the shelter and power, then habitat 2.
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 2, solar = 1, antenna = 1 }, 10, 10 ^ 6, "drill_1")
	check(not ok and reason == "requires", "C: drill_1 needs the shelter")
	local sheltered: BaseBuild.Levels = { habitat = 1, solar = 1, antenna = 1, shelter = 1 }
	ok, reason = BaseBuild.canBuild(MissionData, sheltered, 15, 10 ^ 6, "drill_1")
	check(not ok and reason == "habitat", "C: drill_1 needs habitat 2")
	sheltered.habitat = 2
	local drillCost = BaseBuild.nextCost(MissionData, sheltered, "drill_1") :: number
	ok, reason = BaseBuild.canBuild(MissionData, sheltered, 1, drillCost, "drill_1")
	check(ok, `C: drill_1 at habitat 2 with {drillCost} credits`)
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 5, solar = 1, antenna = 1, shelter = 1, drill_1 = 1 }, 10, 10 ^ 6, "drill_2")
	check(not ok and reason == "requires", "C: drill_2 needs a second solar array")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 2, solar = 2, antenna = 1, shelter = 1, drill_1 = 1 }, 10, 10 ^ 6, "drill_2")
	check(not ok and reason == "habitat", "C: drill_2 needs habitat 3")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 2, solar = 1, antenna = 1, shelter = 1, drill_1 = 1 }, 10, 10 ^ 6, "drill_1")
	check(not ok and reason == "habitat", "C: drill_1 level 2 needs habitat 3")

	-- The Lab, the garage (two bays), the landing pad and the ship.
	ok, reason = BaseBuild.canBuild(MissionData, camp, 15, 10 ^ 6, "lab")
	check(not ok and reason == "habitat", "C: the Lab needs habitat 2")
	local labCost = BaseBuild.nextCost(MissionData, camp, "lab") :: number
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 2, solar = 1 }, 1, labCost, "lab")
	check(ok, `C: the Lab at habitat 2 with {labCost} credits`)
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 5, solar = 1, lab = 1 }, 10, 10 ^ 6, "garage")
	check(not ok and reason == "requires", "C: the garage needs the shelter too")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 2, solar = 1, lab = 1, antenna = 1, shelter = 1 }, 15, 10 ^ 6, "garage")
	check(not ok and reason == "habitat", "C: the garage needs habitat 3")
	ok, reason = BaseBuild.canBuild(MissionData, {}, 15, 10 ^ 9, "ship")
	check(not ok and reason == "requires", "C: the ship needs the landing pad")
	local padReady: BaseBuild.Levels = { habitat = 4, solar = 1, lab = 1, antenna = 2, shelter = 1, garage = 1, landing_pad = 1 }
	ok, reason = BaseBuild.canBuild(MissionData, padReady, 15, 10 ^ 9, "ship")
	check(not ok and reason == "habitat", "C: the ship needs habitat 5 (the last base level)")
	padReady.habitat = 5
	ok, reason = BaseBuild.canBuild(MissionData, padReady, 1, 10 ^ 9, "ship")
	check(ok, "C: the ship at habitat 5")

	-- Habitat upgrades: one at a time, each costs more, the player level does not matter.
	for level = 2, HABITAT_MAX do
		ok, reason = BaseBuild.canBuild(MissionData, { habitat = level - 1 }, 1, 10 ^ 9, "habitat")
		check(ok, `C: habitat {level - 1} can grow to {level}`)
	end
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = HABITAT_MAX }, 15, 10 ^ 9, "habitat")
	check(not ok and reason == "max", `C: the habitat stops at {HABITAT_MAX}`)

	-- Requirement checks come before habitat and credit checks (the lock shows what to build first).
	ok, reason = BaseBuild.canBuild(MissionData, {}, 1, 0, "cargo_bot")
	check(not ok and reason == "requires", "C: cargo_bot locked by requirements first")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 1, 0, "lab")
	check(not ok and reason == "habitat", "C: the habitat check comes before credits")

	check(BaseBuild.buildXp(MissionData, 0) == BASE.BUILD_XP_BASE, "C: free build gives the base XP")
	check(BaseBuild.buildXp(MissionData, 60) == BASE.BUILD_XP_BASE + math.floor(60 * BASE.BUILD_XP_PER_CREDIT), "C: XP grows with cost")
	check(BaseBuild.buildXp(MissionData, 15) == BASE.BUILD_XP_BASE + math.floor(15 * BASE.BUILD_XP_PER_CREDIT), "C: XP rounds down")

	-- Every build at every level is reachable at the top player level with enough credits.
	local all: BaseBuild.Levels = {}
	local progressMade = true
	while progressMade do
		progressMade = false
		for _, def in BASE.BUILDS do
			local canDo = BaseBuild.canBuild(MissionData, all, #BASE.LEVEL_XP, 10 ^ 9, def.id)
			if canDo then
				all[def.id] = BaseBuild.levelOf(all, def.id) + 1
				progressMade = true
			end
		end
	end
	for _, def in BASE.BUILDS do
		check(BaseBuild.levelOf(all, def.id) == def.maxLevel, `C: {def.id} can reach level {def.maxLevel}`)
	end
end

----------------------------------------------------------------------------------------------------
-- D. Effective builds

do
	local a = { solar = 2, greenhouse = 1 }
	local b = { solar = 3, antenna = 1 }
	local c = {}
	local eff = BaseBuild.effective({ a, b, c })
	check(eff.solar == 3, "D: highest solar wins")
	check(eff.greenhouse == 1 and eff.antenna == 1, "D: builds from different players add up")
	check(eff.shelter == nil, "D: nobody built the shelter")
	check(next(BaseBuild.effective({})) == nil, "D: empty server = nothing built")
	check(a.solar == 2 and b.solar == 3, "D: effective does not change the inputs")
	check(BaseBuild.levelOf(nil, "solar") == 0 and BaseBuild.levelOf({}, "solar") == 0, "D: missing = level 0")
	check(BaseBuild.meetsNeeds({ solar = 2 }, { solar = 2 }), "D: needs met")
	check(not BaseBuild.meetsNeeds({ solar = 1 }, { solar = 2 }), "D: needs not met")
	check(BaseBuild.meetsNeeds({}, nil), "D: no needs = always met")
end

----------------------------------------------------------------------------------------------------
-- E. Skills

do
	local ok, reason = BaseBuild.canLearn(MissionData, {}, 1, "speed")
	check(not ok and reason == "level", "E: no skills at level 1")
	ok, reason = BaseBuild.canLearn(MissionData, {}, 2, "speed")
	check(ok, "E: speed 1 at level 2")
	ok, reason = BaseBuild.canLearn(MissionData, { tank = 1, builder = 1 }, 2, "speed")
	check(not ok and reason == "points", "E: both points at level 2 already spent")
	ok, reason = BaseBuild.canLearn(MissionData, { speed = 1 }, 3, "speed")
	check(not ok and reason == "level", "E: speed 2 needs level 4")
	ok, reason = BaseBuild.canLearn(MissionData, { speed = 3 }, 10, "speed")
	check(not ok and reason == "max", "E: speed stops at 3")
	ok, reason = BaseBuild.canLearn(MissionData, {}, 10, "fly")
	check(not ok and reason == "unknown", "E: unknown skill")
	ok, reason = BaseBuild.canLearn(MissionData, {}, 10, "drill")
	check(not ok and reason == "unknown", "E: the old drill skill is gone (it is a tool upgrade)")
	ok, reason = BaseBuild.canLearn(MissionData, {}, 10, "jump")
	check(not ok and reason == "unknown", "E: the old jump skill is gone (air boots)")
	for _, id in { "credits", "xp", "builder" } do
		local def = BaseBuild.skillDef(MissionData, id)
		if def then
			ok, reason = BaseBuild.canLearn(MissionData, {}, def.minLevel[1] - 1, id)
			check(not ok and reason == "level", `E: {id} 1 needs level {def.minLevel[1]}`)
			ok, reason = BaseBuild.canLearn(MissionData, {}, def.minLevel[1], id)
			check(ok, `E: {id} 1 at level {def.minLevel[1]}`)
			ok, reason = BaseBuild.canLearn(MissionData, { [id] = def.maxLevel }, 15, id)
			check(not ok and reason == "max", `E: {id} stops at {def.maxLevel}`)
		end
	end
	-- Old saves: ProgressService keeps only known skills, so drill points come back as free points.
	check(BaseBuild.skillDef(MissionData, "drill") == nil, "E: no drill skill def")

	check(BaseBuild.speedBonus(MissionData, nil) == 0, "E: no speed skill, no bonus")
	check(BaseBuild.speedBonus(MissionData, { speed = 2 }) == 2 * BASE.SPEED_BONUS_PER_LEVEL, "E: speed bonus per level")
	check(BaseBuild.suitMax(MissionData, {}) == MissionData.SUIT.MAX, "E: suit max without tank skill")
	check(BaseBuild.suitMax(MissionData, { tank = 3 }) == MissionData.SUIT.MAX + 3 * BASE.TANK_BONUS_PER_LEVEL, "E: bigger air tank")
	-- Stage 10 playtest: riding a vehicle must not drain the suit like running.
	check(MissionData.SUIT.DRAIN_SEATED_PER_SECOND ~= nil and MissionData.SUIT.DRAIN_SEATED_PER_SECOND <= MissionData.SUIT.DRAIN_WALK_PER_SECOND, "E: a seated rider uses no more air than walking")
	check(BaseBuild.jumpPower(MissionData, {}) == MissionData.WORLD.JUMP_POWER, "E: normal Moon jump")
	check(BaseBuild.jumpPower(MissionData, { jump = 3 }) == MissionData.WORLD.JUMP_POWER, "E: an old jump level adds nothing")
	check(BASE.DOUBLE_JUMP_FRACTION > 0 and BASE.DOUBLE_JUMP_FRACTION <= 1, "E: second jump is smaller")

	-- Builder: a shorter Assemble hold per level, never zero.
	check(BaseBuild.builderHoldFactor(MissionData, nil) == 1 and BaseBuild.builderHoldFactor(MissionData, {}) == 1, "E: no builder skill, normal hold")
	local lastFactor = 1
	for level = 1, #BASE.BUILDER_HOLD_FACTOR do
		local factor = BaseBuild.builderHoldFactor(MissionData, { builder = level })
		check(factor == BASE.BUILDER_HOLD_FACTOR[level], `E: builder {level} hold factor`)
		check(factor < lastFactor and factor > 0, `E: builder {level} is faster, never instant`)
		lastFactor = factor
	end

	-- Credits / XP skills: the bonus is ALWAYS a whole number (no decimals for kids), at least 1 for
	-- any reward above 0 with the skill learned, 0 without the skill, and it grows with the level.
	check(isWhole(BASE.REWARD_BONUS_PER_LEVEL * 10, 1), "E: bonus share is a simple tenth")
	local allWhole, allAtLeastOne, allGrow, noneWithout = true, true, true, true
	for base = 0, 500 do
		local previous = 0
		for level = 0, 3 do
			local bonus = BaseBuild.bonusAmount(MissionData, base, level)
			if bonus ~= math.floor(bonus) or bonus < 0 then
				allWhole = false
			end
			if base > 0 and level > 0 and bonus < 1 then
				allAtLeastOne = false
			end
			if (base == 0 or level == 0) and bonus ~= 0 then
				noneWithout = false
			end
			if bonus < previous then
				allGrow = false
			end
			previous = bonus
		end
	end
	check(allWhole, "E: reward bonus is always a whole number")
	check(allAtLeastOne, "E: reward bonus is at least 1 when the skill is learned")
	check(noneWithout, "E: no bonus without the skill or for a 0 reward")
	check(allGrow, "E: a higher skill level never gives less")
	check(BaseBuild.bonusAmount(MissionData, 10, 1) == 1, "E: 10 credits at level 1 -> +1")
	check(BaseBuild.bonusAmount(MissionData, 10, 3) == 3, "E: 10 credits at level 3 -> +3 (no float drift)")
	check(BaseBuild.bonusAmount(MissionData, 30, 3) == 9, "E: 30 credits at level 3 -> +9 (no float drift)")
	check(BaseBuild.bonusAmount(MissionData, 5, 1) == 1, "E: 5 credits at level 1 -> +1 (rounded up)")
	check(BaseBuild.bonusAmount(MissionData, 1, 1) == 1, "E: even 1 credit gets +1")
	check(BaseBuild.bonusAmount(MissionData, -5, 2) == 0, "E: no bonus for a negative amount")
	-- Every reward in the game with every bonus level stays whole.
	for kind, reward in BASE.REWARDS do
		for level = 1, 3 do
			check(isWhole(reward.credits + BaseBuild.bonusAmount(MissionData, reward.credits, level), 0), `E: {kind} credits + bonus {level} is whole`)
			check(isWhole(reward.xp + BaseBuild.bonusAmount(MissionData, reward.xp, level), 1), `E: {kind} XP + bonus {level} is whole`)
		end
	end

	-- Skills are a choice during the game: when the last skill level unlocks, the player still has
	-- fewer points than every skill level together.
	local totalSkillLevels = 0
	local lastUnlock = 1
	for _, def in BASE.SKILLS do
		totalSkillLevels += def.maxLevel
		for _, need in def.minLevel do
			lastUnlock = math.max(lastUnlock, need)
		end
	end
	check(BaseBuild.skillPoints(lastUnlock, {}) < totalSkillLevels, "E: not enough points for every skill yet (choose!)")
	-- Team playtest: at the top level every skill can be maxed (no skill stays locked forever).
	local topLevel = BaseBuild.maxPlayerLevel(MissionData)
	check(BaseBuild.skillPoints(topLevel, {}) >= totalSkillLevels, "E: the top level gives enough points for every skill")
end

----------------------------------------------------------------------------------------------------
-- F. Pets

do
	local owned = BaseBuild.ownedPets(MissionData, nil, { laika = true })
	check(owned.laika == true and owned.cheese == nil, "F: laika comes from the collectible")
	owned = BaseBuild.ownedPets(MissionData, { rabbit = true, laika = true }, nil)
	check(owned.rabbit == true and owned.laika == nil, "F: a collectible pet cannot be 'bought' in a save")

	local ok, reason = BaseBuild.canBuyPet(MissionData, {}, 10, 10 ^ 6, "laika")
	check(not ok and reason == "collectible", "F: laika is found, not bought")
	ok, reason = BaseBuild.canBuyPet(MissionData, {}, 2, 10 ^ 6, "rabbit")
	check(not ok and reason == "level", "F: rabbit needs level 3")
	ok, reason = BaseBuild.canBuyPet(MissionData, {}, 3, 119, "rabbit")
	check(not ok and reason == "credits", "F: rabbit costs 120")
	ok, reason = BaseBuild.canBuyPet(MissionData, {}, 3, 120, "rabbit")
	check(ok, "F: rabbit at level 3 with 120 credits")
	ok, reason = BaseBuild.canBuyPet(MissionData, { rabbit = true }, 10, 10 ^ 6, "rabbit")
	check(not ok and reason == "owned", "F: no second rabbit")
	ok, reason = BaseBuild.canBuyPet(MissionData, {}, 10, 10 ^ 6, "dragon")
	check(not ok and reason == "unknown", "F: unknown pet")
end

----------------------------------------------------------------------------------------------------
-- G. Automatic drills and the silo

do
	check(BaseBuild.icePerMinute(MissionData, {}) == 0, "G: no drills, no ice")
	check(BaseBuild.icePerMinute(MissionData, { drill_1 = 1 }) == BASE.DRILL_ICE_PER_MINUTE[1], "G: one drill level 1")
	check(
		BaseBuild.icePerMinute(MissionData, { drill_1 = 3, drill_2 = 2, drill_3 = 1 })
			== BASE.DRILL_ICE_PER_MINUTE[3] + BASE.DRILL_ICE_PER_MINUTE[2] + BASE.DRILL_ICE_PER_MINUTE[1],
		"G: drills add up"
	)
	check(BaseBuild.icePerMinute(MissionData, { solar = 3 }) == 0, "G: other builds make no ice")
	for i = 2, #BASE.DRILL_ICE_PER_MINUTE do
		check(BASE.DRILL_ICE_PER_MINUTE[i] > BASE.DRILL_ICE_PER_MINUTE[i - 1], `G: drill level {i} drills more`)
	end
	check(isWhole(BASE.SILO_MAX, 1), "G: silo holds a whole number of ice")
	check(isWhole(BASE.CARGO_BOT_SECONDS, 1), "G: cargo robot timer is whole seconds")
	-- The silo is worth emptying: a full silo pays at least one greenhouse.
	check(BASE.SILO_MAX * BASE.CREDITS_PER_SILO_ICE >= 15, "G: a full silo pays something useful")
	-- Upgrading a drill pays for itself in a reasonable time (under 2 hours of play).
	local drill = BaseBuild.buildDef(MissionData, "drill_1")
	if drill then
		local minutes = drill.costs[1] / (BASE.DRILL_ICE_PER_MINUTE[1] * BASE.CREDITS_PER_SILO_ICE)
		check(minutes <= 120, `G: drill_1 pays for itself in {minutes} minutes`)
	end
end

----------------------------------------------------------------------------------------------------
-- H. A new player is never stuck

do
	-- Plan: build the habitat and solar (free), deliver ice by hand, build greenhouse, antenna,
	-- shelter, grow the habitat to level 2 (Stage 9), the first drill. Every step of a build gives
	-- its crate and assembly XP.
	local function stepXp(id: string, level: number): number
		local stages = BaseBuild.stagesFor(MissionData, id, level)
		return stages * (BASE.REWARDS.crate_delivered.xp + BASE.REWARDS.stage_done.xp)
	end
	local credits = BASE.START_CREDITS
	local xp = 0
	local builds: BaseBuild.Levels = {}
	local deliveries = 0
	local order = { "habitat", "solar", "greenhouse", "antenna", "shelter", "habitat", "drill_1" }
	for _, id in order do
		local guard = 0
		while true do
			local ok, reason = BaseBuild.canBuild(MissionData, builds, BaseBuild.levelForXp(MissionData, xp), credits, id)
			if ok then
				local cost = BaseBuild.nextCost(MissionData, builds, id) :: number
				local level = BaseBuild.levelOf(builds, id) + 1
				credits -= cost
				xp += BaseBuild.buildXp(MissionData, cost) + stepXp(id, level)
				builds[id] = level
				break
			end
			check(reason == "credits" or reason == "level", `H: {id} only waits for credits or XP ({reason})`)
			if reason ~= "credits" and reason ~= "level" then
				break
			end
			-- One manual ice delivery.
			credits += BASE.REWARDS.ice_delivered.credits
			xp += BASE.REWARDS.ice_delivered.xp
			deliveries += 1
			guard += 1
			if guard > 100 then
				check(false, `H: {id} reachable with manual ice`)
				break
			end
		end
	end
	check(builds.drill_1 == 1, "H: the first automatic drill is reachable by hand")
	check(deliveries <= 40, `H: {deliveries} manual ice deliveries to reach the first drill (at most 40)`)
	check(BaseBuild.canBuild(MissionData, {}, 1, BASE.START_CREDITS, "habitat"), "H: a new player can build the habitat at once")
	check(BaseBuild.canBuild(MissionData, { habitat = 1 }, 1, BASE.START_CREDITS, "solar"), "H: then solar at once")
	check(BASE.START_CREDITS >= 15, "H: START_CREDITS pays the greenhouse after the free builds")
end

----------------------------------------------------------------------------------------------------
-- I. Building in steps

do
	check(isWhole(BASE.STAGES_FIRST, 1) and isWhole(BASE.STAGES_UPGRADE, 1), "I: default steps are whole numbers >= 1")
	check(type(BASE.ASSEMBLE_HOLD_SECONDS) == "number" and BASE.ASSEMBLE_HOLD_SECONDS > 0, "I: assembling takes a hold")
	for id, stages in BASE.STAGES_BY_ID do
		check(BaseBuild.buildDef(MissionData, id) ~= nil, `I: STAGES_BY_ID names a real build ({id})`)
		check(isWhole(stages, 1), `I: {id} steps are a whole number >= 1`)
	end
	for _, def in BASE.BUILDS do
		for level = 1, def.maxLevel do
			local stages = BaseBuild.stagesFor(MissionData, def.id, level)
			check(isWhole(stages, 1), `I: {def.id} level {level} has {stages} steps (>= 1)`)
			check(stages <= 10, `I: {def.id} level {level} is not endless ({stages} steps)`)
		end
	end
	check(BaseBuild.stagesFor(MissionData, "habitat", 1) == BASE.STAGES_BY_ID.habitat, "I: habitat uses its own steps")
	check(BaseBuild.stagesFor(MissionData, "greenhouse", 1) == BASE.STAGES_FIRST, "I: a new build uses STAGES_FIRST")
	check(BaseBuild.stagesFor(MissionData, "greenhouse", 2) == BASE.STAGES_UPGRADE, "I: an upgrade uses STAGES_UPGRADE")
	check(BaseBuild.stagesFor(MissionData, "solar", 2) == BASE.STAGES_UPGRADE, "I: a second array is an upgrade")
	check(BaseBuild.stagesFor(MissionData, "ship", 1) == BASE.STAGES_BY_ID.ship, "I: the ship is a big project")
	check(BaseBuild.stagesFor(MissionData, "ship", 1) > BASE.STAGES_FIRST, "I: the ship takes more steps than a normal build")
	check(BaseBuild.stagesFor(MissionData, "habitat", 1) <= BASE.STAGES_FIRST, "I: the first build is quick")
end

----------------------------------------------------------------------------------------------------
-- J. Tools

do
	local seen: { [string]: boolean } = {}
	for _, def in BASE.TOOLS do
		check(not seen[def.id], `J: tool id {def.id} unique`)
		seen[def.id] = true
		check(iconExists(def.icon), `J: tool {def.id} icon "{def.icon}" exists in Icons`)
		if def.unlock ~= nil then
			check(BaseBuild.buildDef(MissionData, def.unlock) ~= nil, `J: tool {def.id} unlocks with a real build ({def.unlock})`)
		end
		check(BaseBuild.toolDef(MissionData, def.id) == def, `J: toolDef finds {def.id}`)
	end
	for _, id in EXPECTED_TOOLS do
		check(seen[id] == true, `J: tool {id} exists`)
	end
	check(#BASE.TOOLS == #EXPECTED_TOOLS, `J: {#BASE.TOOLS} tools (expected {#EXPECTED_TOOLS})`)
	check(BaseBuild.toolDef(MissionData, "laser") == nil, "J: unknown tool")

	-- What each tool waits for (team feedback: no drill = no ice, so the drill comes from the start).
	local start = BaseBuild.toolsUnlocked(MissionData, {})
	check(start.wrench == true and start.drill == true, "J: wrench and ice drill from the start")
	check(start.brush == nil and start.tablet == nil and start.food == nil and start.repair_kit == nil, "J: other tools wait for builds")
	local home = BaseBuild.toolsUnlocked(MissionData, { habitat = 1 })
	check(home.repair_kit == true and home.brush == nil, "J: repair kit with the habitat")
	local powered = BaseBuild.toolsUnlocked(MissionData, { habitat = 1, solar = 1 })
	check(powered.brush == true, "J: panel brush with the solar arrays")
	local linked = BaseBuild.toolsUnlocked(MissionData, { habitat = 1, solar = 1, antenna = 1 })
	check(linked.tablet == true and linked.food == nil, "J: tablet with the antenna")
	local green = BaseBuild.toolsUnlocked(MissionData, { habitat = 1, solar = 1, greenhouse = 1 })
	check(green.food == true, "J: food with the greenhouse")
	local food = BaseBuild.toolDef(MissionData, "food")
	check(food ~= nil and food.consumable == true, "J: food is eaten (consumable)")

	-- Tool upgrades (the Lab): only tools that exist, level 1 is free and comes with the tool.
	for id, up in BASE.TOOL_UPGRADES do
		check(seen[id] == true, `J: upgrade {id} is a real tool`)
		check(isWhole(up.maxLevel, 2), `J: upgrade {id} has at least 2 levels`)
		check(#up.costs == up.maxLevel and #up.minLevel == up.maxLevel, `J: upgrade {id} has one cost and level per level`)
		check(up.costs[1] == 0 and up.minLevel[1] == 1, `J: upgrade {id} level 1 is free`)
		for i = 2, up.maxLevel do
			check(up.costs[i] > up.costs[i - 1], `J: upgrade {id} level {i} costs more`)
			check(up.minLevel[i] >= up.minLevel[i - 1] and up.minLevel[i] <= #BASE.LEVEL_XP, `J: upgrade {id} level {i} gate is real`)
		end
	end
	local drill = BASE.TOOL_UPGRADES.drill
	check(#drill.holdFactor == drill.maxLevel, "J: one hold factor per drill level")
	check(drill.holdFactor[1] == 1, "J: the basic drill takes the normal time")
	for i = 2, #drill.holdFactor do
		check(drill.holdFactor[i] < drill.holdFactor[i - 1] and drill.holdFactor[i] > 0, `J: drill level {i} is faster`)
	end
	check(BaseBuild.drillHoldFactor(MissionData, nil) == 1, "J: no level = basic drill")
	check(BaseBuild.drillHoldFactor(MissionData, 0) == 1, "J: level 0 counts as basic")
	check(BaseBuild.drillHoldFactor(MissionData, 2) == drill.holdFactor[2], "J: drill level 2 hold factor")
	check(BaseBuild.drillHoldFactor(MissionData, 99) == drill.holdFactor[drill.maxLevel], "J: above the top = top level")

	check(BaseBuild.toolUpgradeCost(MissionData, "drill", 1) == drill.costs[2], "J: next drill level cost")
	check(BaseBuild.toolUpgradeCost(MissionData, "drill", drill.maxLevel) == nil, "J: maxed drill has no cost")
	check(BaseBuild.toolUpgradeCost(MissionData, "wrench", 1) == nil, "J: the wrench has no upgrades")

	local all = BaseBuild.toolsUnlocked(MissionData, { habitat = 1, solar = 1, antenna = 1, greenhouse = 1 })
	local ok, reason = BaseBuild.canUpgradeTool(MissionData, "wrench", 1, 15, 10 ^ 6, all)
	check(not ok and reason == "unknown", "J: no upgrade for the wrench")
	ok, reason = BaseBuild.canUpgradeTool(MissionData, "drill", 1, 15, 10 ^ 6, {})
	check(not ok and reason == "requires", "J: a locked tool cannot be upgraded")
	ok, reason = BaseBuild.canUpgradeTool(MissionData, "drill", 1, drill.minLevel[2] - 1, 10 ^ 6, all)
	check(not ok and reason == "level", "J: drill level 2 needs the player level")
	ok, reason = BaseBuild.canUpgradeTool(MissionData, "drill", 1, drill.minLevel[2], drill.costs[2] - 1, all)
	check(not ok and reason == "credits", "J: drill level 2 needs the credits")
	ok, reason = BaseBuild.canUpgradeTool(MissionData, "drill", 1, drill.minLevel[2], drill.costs[2], all)
	check(ok and reason == nil, "J: drill level 2 with level and credits")
	ok, reason = BaseBuild.canUpgradeTool(MissionData, "drill", drill.maxLevel, 15, 10 ^ 6, all)
	check(not ok and reason == "max", "J: the drill stops at its top level")
end

----------------------------------------------------------------------------------------------------
-- K. Food, meteorites, vehicles

do
	local food = BASE.FOOD
	check(food.COOLDOWN_SECONDS > 0 and food.BOOST_SECONDS > 0 and food.BOOST_SPEED > 0, "K: food values are positive")
	check(food.BOOST_SECONDS < food.COOLDOWN_SECONDS, "K: a food boost ends before the next food grows")

	local meteor = BASE.METEOR
	check(meteor.MIN_SECONDS > 0 and meteor.MIN_SECONDS <= meteor.MAX_SECONDS, "K: meteorite wait range")
	check(meteor.LIFETIME_SECONDS > 0, "K: a meteorite crater stays a while")
	check(meteor.RING_MIN > 0 and meteor.RING_MIN < meteor.RING_MAX, "K: meteorite ring around the habitat")
	check(meteor.RING_MAX <= 600, "K: meteorites land inside the map")

	local garage = BaseBuild.buildDef(MissionData, "garage")
	local seen: { [string]: boolean } = {}
	for _, def in BASE.VEHICLES do
		check(not seen[def.id], `K: vehicle id {def.id} unique`)
		seen[def.id] = true
		check(garage ~= nil and isWhole(def.garage, 1) and def.garage <= garage.maxLevel, `K: {def.id} needs a real garage level`)
		check(type(def.maxSpeed) == "number" and def.maxSpeed > 0, `K: {def.id} has a top speed`)
	end
	check(seen.buggy == true and seen.hauler == true, "K: buggy and hauler exist")
	local hauler = BASE.VEHICLES[2]
	check(hauler.id == "hauler" and isWhole(hauler.cargo, 1), "K: the hauler carries ice cores")

	for _, def in BASE.PETS do
		if def.cost then
			check(isWhole(def.cost, 1) and isWhole(def.minLevel, 1), `K: adopted pet {def.id} has a cost and a level`)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- L. Gear (Stage 8)

do
	local seen: { [string]: boolean } = {}
	local keys: { [string]: boolean } = {}
	for _, def in BASE.GEAR do
		check(not seen[def.id], `L: gear id {def.id} unique`)
		seen[def.id] = true
		check(BaseBuild.gearDef(MissionData, def.id) == def, `L: gearDef finds {def.id}`)
		check(BaseBuild.skillDef(MissionData, def.id) == nil, `L: {def.id} is gear, not a skill`)
		check(BaseBuild.toolDef(MissionData, def.id) == nil, `L: {def.id} is gear, not a hotbar tool`)
		check(iconExists(def.icon), `L: gear {def.id} icon "{def.icon}" exists in Icons`)
		check(type(def.key) == "string" and #def.key == 1 and string.upper(def.key) == def.key, `L: {def.id} has a one-letter key`)
		check(not keys[def.key], `L: {def.id} key {def.key} is not shared`)
		keys[def.key] = true
		check(not ({ W = true, A = true, S = true, D = true, X = true, E = true })[def.key], `L: {def.id} key is free (not WASD, X or E)`)
		check(isWhole(def.maxLevel, 1), `L: {def.id} maxLevel is whole`)
		check(#def.costs == def.maxLevel and #def.minLevel == def.maxLevel and #def.use == def.maxLevel, `L: {def.id} has one cost, level and use per level`)
		for i = 1, def.maxLevel do
			check(isWhole(def.costs[i], 1), `L: {def.id} level {i} costs whole credits`)
			check(isWhole(def.minLevel[i], 1) and def.minLevel[i] <= #BASE.LEVEL_XP, `L: {def.id} level {i} gate is a real level`)
			check(isWhole(def.use[i], 1) and def.use[i] <= BASE.GAS.MAX, `L: {def.id} level {i} gas use fits the tank`)
			if i > 1 then
				check(def.costs[i] > def.costs[i - 1], `L: {def.id} level {i} costs more`)
				check(def.minLevel[i] >= def.minLevel[i - 1], `L: {def.id} level {i} needs at least the level before`)
				check(def.use[i] < def.use[i - 1], `L: {def.id} level {i} makes the gas last longer`)
			end
		end
	end
	for _, id in EXPECTED_GEAR do
		check(seen[id] == true, `L: gear {id} exists`)
	end
	check(#BASE.GEAR == #EXPECTED_GEAR, `L: {#BASE.GEAR} gear pieces (expected {#EXPECTED_GEAR})`)
	check(BaseBuild.gearDef(MissionData, "rocket_boots") == nil, "L: unknown gear")

	-- Buying and upgrading.
	local boots = BaseBuild.gearDef(MissionData, "boots")
	if boots then
		local ok, reason = BaseBuild.canBuyGear(MissionData, "boots", 0, boots.minLevel[1] - 1, 10 ^ 6)
		check(not ok and reason == "level", "L: boots need the player level")
		ok, reason = BaseBuild.canBuyGear(MissionData, "boots", 0, boots.minLevel[1], boots.costs[1] - 1)
		check(not ok and reason == "credits", "L: boots need the credits")
		ok, reason = BaseBuild.canBuyGear(MissionData, "boots", 0, boots.minLevel[1], boots.costs[1])
		check(ok and reason == nil, "L: boots with level and credits")
		ok, reason = BaseBuild.canBuyGear(MissionData, "boots", 1, boots.minLevel[2], boots.costs[2])
		check(ok, "L: boots upgrade to level 2")
		ok, reason = BaseBuild.canBuyGear(MissionData, "boots", 1, boots.minLevel[2] - 1, 10 ^ 6)
		check(not ok and reason == "level", "L: boots level 2 needs the player level")
		ok, reason = BaseBuild.canBuyGear(MissionData, "boots", boots.maxLevel, 15, 10 ^ 9)
		check(not ok and reason == "max", "L: boots stop at their top level")
	end
	local ok, reason = BaseBuild.canBuyGear(MissionData, "cape", 0, 15, 10 ^ 9)
	check(not ok and reason == "unknown", "L: unknown gear cannot be bought")
	local jetpack = BaseBuild.gearDef(MissionData, "jetpack")
	if boots and jetpack then
		check(jetpack.minLevel[1] > boots.minLevel[1], "L: the jetpack comes after the boots")
		check(jetpack.costs[1] > boots.costs[1], "L: the jetpack costs more than the boots")
	end
	-- Every level of every piece of gear can be reached at the top player level.
	for _, def in BASE.GEAR do
		for current = 0, def.maxLevel - 1 do
			check(BaseBuild.canBuyGear(MissionData, def.id, current, #BASE.LEVEL_XP, 10 ^ 9), `L: {def.id} level {current + 1} reachable`)
		end
	end

	-- Gas use.
	for _, def in BASE.GEAR do
		check(BaseBuild.gasUse(MissionData, def.id, 0) == nil, `L: {def.id} not owned uses no gas`)
		for level = 1, def.maxLevel do
			check(BaseBuild.gasUse(MissionData, def.id, level) == def.use[level], `L: {def.id} level {level} gas use`)
		end
		check(BaseBuild.gasUse(MissionData, def.id, def.maxLevel + 5) == def.use[def.maxLevel], `L: {def.id} above the top = top level`)
	end
	check(BaseBuild.gasUse(MissionData, "cape", 1) == nil, "L: unknown gear uses no gas")
	if boots then
		-- A full tank gives more than one double jump, even with the basic boots.
		check(BASE.GAS.MAX / boots.use[1] >= 2, "L: a full tank gives at least two double jumps")
	end
	if jetpack then
		-- The jetpack flies for a few seconds, not forever.
		local seconds = BASE.GAS.MAX / jetpack.use[1]
		check(seconds >= 2 and seconds <= 15, `L: a full tank flies the basic jetpack {seconds} s`)
	end

	-- The gas tank.
	local gas = BASE.GAS
	check(isWhole(gas.MAX, 1), "L: the gas tank holds a whole amount")
	check(gas.REFILL_PER_SECOND > 0 and gas.MAX / gas.REFILL_PER_SECOND <= 10, "L: the tank refills inside in under 10 s")
	-- The jetpack must beat Moon gravity to climb, and its climb is capped.
	check(gas.JETPACK_ACCEL > MissionData.WORLD.MOON_GRAVITY_STUDS, "L: jetpack push beats Moon gravity")
	check(gas.JETPACK_MAX_RISE > 0, "L: jetpack climb speed is capped")
end

----------------------------------------------------------------------------------------------------
-- M. Save migration (Stage 8, done by ProgressService.sanitizeBase on the server)
-- The old "jump" skill level becomes the air boots at that level (at most boots.maxLevel) for free.
-- The skills keep only known ids, so "jump" drops out and its points come back. This mirrors those
-- rules with BaseBuild (ProgressService needs Roblox and cannot run in Lune).

do
	local boots = BaseBuild.gearDef(MissionData, "boots")
	check(boots ~= nil and boots.maxLevel >= 3, "M: boots have room for every old jump level (3)")
	check(BaseBuild.skillDef(MissionData, "jump") == nil, "M: no jump skill def, so saves drop it")
	-- The same filter ProgressService uses: known skill ids only.
	local function keepKnown(skills: { [string]: number }): { [string]: number }
		local kept: { [string]: number } = {}
		for id, level in skills do
			if BaseBuild.skillDef(MissionData, id) then
				kept[id] = level
			end
		end
		return kept
	end
	local oldSkills = { speed = 1, jump = 2 }
	local playerLevel = 5
	local before = BaseBuild.skillPoints(playerLevel, oldSkills)
	local after = BaseBuild.skillPoints(playerLevel, keepKnown(oldSkills))
	check(after == before + 2, "M: the 2 jump points come back")
	check(keepKnown(oldSkills).speed == 1, "M: other skills stay")
	if boots then
		for jump = 1, 5 do
			local migrated = math.clamp(jump, 1, boots.maxLevel)
			check(migrated >= 1 and migrated <= boots.maxLevel, `M: jump {jump} -> boots {migrated}`)
			check(BaseBuild.gasUse(MissionData, "boots", migrated) ~= nil, `M: migrated boots level {migrated} works`)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- N. The habitat tree (Stage 9): the habitat is the town hall, every structure level opens at one
-- habitat level, and the per-level effects are well formed.

do
	-- Every structure level opens at exactly one habitat level; print the tree.
	local opened: { [string]: boolean } = {}
	print("habitat tree (structure levels that open at each base level):")
	for hab = 1, HABITAT_MAX do
		local names = {}
		for _, entry in BaseBuild.unlocksAt(MissionData, hab) do
			local key = `{entry.id}:{entry.level}`
			check(not opened[key], `N: {key} opens only once`)
			opened[key] = true
			table.insert(names, `{entry.id} {entry.level}`)
		end
		print(`  habitat {hab}: {table.concat(names, ", ")}`)
		if hab > 1 then
			check(#names >= 2, `N: habitat {hab} opens something new (at least 2 levels)`)
		end
	end
	for _, def in BASE.BUILDS do
		if def.id ~= "habitat" then
			for level = 1, def.maxLevel do
				check(opened[`{def.id}:{level}`] == true, `N: {def.id} level {level} opens at some habitat level`)
			end
			-- A structure never opens before what it requires can open.
			for needId, needLevel in def.requires do
				local needHab = BaseBuild.habitatNeeded(MissionData, needId, needLevel) or 0
				check(needHab <= def.hab[1], `N: {def.id} opens no sooner than its requirement {needId} {needLevel}`)
			end
		end
	end
	-- Habitat 1 (landing camp) has what the training missions build and one mission day needs.
	for _, id in { "solar", "greenhouse", "antenna", "shelter" } do
		check(BaseBuild.habitatNeeded(MissionData, id, 1) == 1, `N: {id} opens at habitat 1`)
	end
	check(BaseBuild.maxLevelAt(MissionData, "solar", 1) == MissionData.POWER.ARRAYS, "N: every solar array at habitat 1 (the story needs them)")
	check(BaseBuild.habitatNeeded(MissionData, "lab", 1) == 2, "N: the Lab opens at habitat 2")
	check(BaseBuild.habitatNeeded(MissionData, "greenhouse", 2) == 2, "N: greenhouse 2 opens at habitat 2")
	check(BaseBuild.habitatNeeded(MissionData, "ship", 1) == HABITAT_MAX, "N: the ship needs the top habitat level")
	check(BaseBuild.habitatNeeded(MissionData, "habitat", 3) == 2, "N: habitat 3 needs habitat 2")
	check(BaseBuild.habitatNeeded(MissionData, "lab", 2) == nil, "N: no habitat level for a level that does not exist")
	check(BaseBuild.habitatNeeded(MissionData, "rocket_pad", 1) == nil, "N: no habitat level for an unknown build")
	check(BaseBuild.habitatLevel({}) == 0 and BaseBuild.habitatLevel({ habitat = 3 }) == 3, "N: habitatLevel reads the habitat")
	check(BaseBuild.maxLevelAt(MissionData, "drill_1", 1) == 0, "N: no drill at habitat 1")
	check(BaseBuild.maxLevelAt(MissionData, "drill_1", HABITAT_MAX) == 3, "N: every drill level by the top habitat")
	check(BaseBuild.maxLevelAt(MissionData, "rocket_pad", 5) == 0, "N: unknown build has no level")
	-- Old saves: the habitat they need for what they already built (save migration helper).
	check(BaseBuild.habitatForBuilds(MissionData, {}) == 0, "N: nothing built needs no habitat")
	check(BaseBuild.habitatForBuilds(MissionData, { habitat = 1, solar = 3, shelter = 1 }) == 1, "N: a landing camp needs habitat 1")
	check(BaseBuild.habitatForBuilds(MissionData, { habitat = 1, lab = 1, garage = 2 }) == 4, "N: an old save with the hauler bay needs habitat 4")
	check(BaseBuild.habitatForBuilds(MissionData, { habitat = 1, ship = 1 }) == HABITAT_MAX, "N: an old save with the ship needs the top habitat")
	check(BaseBuild.habitatForBuilds(MissionData, { habitat = 3, solar = 1 }) == 3, "N: a higher habitat is kept")
	-- A habitat upgrade is a big project; the first habitat is quick.
	check(BaseBuild.stagesFor(MissionData, "habitat", 1) == BASE.STAGES_BY_ID.habitat, "N: the first habitat uses STAGES_BY_ID")
	for level = 2, HABITAT_MAX do
		check(BaseBuild.stagesFor(MissionData, "habitat", level) == BASE.STAGES_UPGRADE_BY_ID.habitat, `N: habitat {level} uses STAGES_UPGRADE_BY_ID`)
	end
	check(BaseBuild.stagesFor(MissionData, "antenna", 2) == BASE.STAGES_UPGRADE, "N: other upgrades keep STAGES_UPGRADE")
	check(BaseBuild.stagesFor(MissionData, "ship", 1) == BASE.STAGES_BY_ID.ship, "N: the ship keeps its steps")

	-- Silo size by habitat level.
	local silo = BASE.SILO_MAX_BY_HABITAT
	check(#silo == HABITAT_MAX, "N: one silo size per habitat level")
	for i = 1, #silo do
		check(isWhole(silo[i], 1), `N: silo size {i} is a whole number`)
		if i > 1 then
			check(silo[i] >= silo[i - 1], `N: the silo never shrinks at habitat {i}`)
		end
	end
	check(BASE.SILO_MAX == silo[#silo], "N: SILO_MAX is the biggest silo")
	check(BaseBuild.siloMax(MissionData, { habitat = 1 }) == silo[1], "N: siloMax at habitat 1")
	check(BaseBuild.siloMax(MissionData, { habitat = 4 }) == silo[4], "N: siloMax at habitat 4")
	check(BaseBuild.siloMax(MissionData, {}) == silo[1], "N: siloMax with no habitat uses the smallest")
	check(BaseBuild.siloMax(MissionData, { habitat = 99 }) == silo[#silo], "N: siloMax is clamped")

	-- Antenna bonus by antenna level.
	local antenna = BaseBuild.buildDef(MissionData, "antenna") :: BaseBuild.BuildDef
	local bonus = BASE.ANTENNA_ALIGN_BONUS
	check(#bonus == antenna.maxLevel, "N: one antenna bonus per antenna level")
	check(bonus[1] == 0, "N: the first antenna pays the normal reward")
	for i = 1, #bonus do
		check(isWhole(bonus[i], 0), `N: antenna bonus {i} is whole`)
		if i > 1 then
			check(bonus[i] > bonus[i - 1], `N: antenna {i} sends more data than antenna {i - 1}`)
		end
	end
	check(BaseBuild.antennaBonus(MissionData, {}) == 0, "N: no antenna, no bonus")
	check(BaseBuild.antennaBonus(MissionData, { antenna = 3 }) == bonus[3], "N: laser link bonus")

	-- Food grows faster with the second dome (plants still take time to grow).
	local greenhouse = BaseBuild.buildDef(MissionData, "greenhouse") :: BaseBuild.BuildDef
	local cooldown = BASE.FOOD.COOLDOWN_BY_GREENHOUSE
	check(#cooldown == greenhouse.maxLevel, "N: one food cooldown per greenhouse level")
	check(cooldown[1] == BASE.FOOD.COOLDOWN_SECONDS, "N: greenhouse 1 keeps COOLDOWN_SECONDS")
	for i = 2, #cooldown do
		check(cooldown[i] < cooldown[i - 1] and cooldown[i] >= 30, `N: greenhouse {i} grows food sooner, but not at once`)
	end
	check(BaseBuild.foodCooldown(MissionData, {}) == BASE.FOOD.COOLDOWN_SECONDS, "N: food cooldown without a greenhouse")
	check(BaseBuild.foodCooldown(MissionData, { greenhouse = 2 }) == cooldown[2], "N: food cooldown with dome 2")
end

----------------------------------------------------------------------------------------------------
-- O. Quests (Stage 9): the main quest line teaches every mechanic in order, side quests open along
-- the way. Every step type is valid, every mission id exists, every build is reachable in order.

do
	local Missions = require("../src/shared/Missions")
	local Quests = require("../src/shared/Quests")
	local SITES = 5 -- exploration sites (WorldSites SITE_ORDER)
	local skillTotal = 0
	for _, def in BASE.SKILLS do
		skillTotal += def.maxLevel
	end

	local seen: { [string]: boolean } = {}
	local typesUsed: { [string]: boolean } = {}
	local missionsUsed: { [string]: boolean } = {}
	check(#Quests.MAIN >= 10, `O: a real main quest line ({#Quests.MAIN} quests)`)
	check(#Quests.SIDE >= 3, `O: some side quests ({#Quests.SIDE})`)
	check(#Quests.LIST == #Quests.MAIN + #Quests.SIDE, "O: LIST is main plus side")
	for index, quest in Quests.LIST do
		check(not seen[quest.id], `O: quest id {quest.id} unique`)
		seen[quest.id] = true
		check(string.match(quest.id, "^[%l%d_]+$") ~= nil, `O: quest id {quest.id} is lower case`)
		check(quest.order == index, `O: {quest.id} order is its place in LIST`)
		check(Quests.byId(quest.id) == quest, `O: byId finds {quest.id}`)
		check(quest.kind == "main" or quest.kind == "side", `O: {quest.id} kind is main or side`)
		check(iconExists(quest.icon), `O: {quest.id} icon "{quest.icon}" exists in Icons`)
		check(isWhole(quest.reward.credits, 0) and isWhole(quest.reward.xp, 1), `O: {quest.id} reward is whole credits and XP`)
		check(#quest.steps >= 1 and #quest.steps <= 4, `O: {quest.id} has 1 to 4 steps`)
		check(Quests.titleKey(quest.id) == `quest.{quest.id}.title`, `O: {quest.id} title key`)
		if quest.kind == "main" then
			check(quest.after == nil, `O: main quest {quest.id} has no after (the line orders it)`)
		else
			local after = quest.after and Quests.byId(quest.after)
			check(quest.after == nil or (after ~= nil and after.kind == "main"), `O: side quest {quest.id} opens after a main quest`)
		end
		for i, step in quest.steps do
			typesUsed[step.type] = true
			check(Quests.isStepType(step.type), `O: {quest.id} step {i} type "{step.type}" is valid`)
			check(Quests.stepKey(quest.id, i) == `quest.{quest.id}.step{i}`, `O: {quest.id} step {i} key`)
			check(isWhole(Quests.stepTarget(step), 1), `O: {quest.id} step {i} has a whole target`)
			local kind = step.type
			if kind == "build" then
				local def = step.id and BaseBuild.buildDef(MissionData, step.id)
				check(def ~= nil, `O: {quest.id} step {i} builds a real structure ({step.id})`)
				if def then
					check(isWhole(step.level, 1) and (step.level :: number) <= def.maxLevel, `O: {quest.id} step {i} level is 1..{def.maxLevel}`)
				end
			elseif kind == "mission" then
				check(step.id ~= nil and Missions.get(step.id) ~= nil, `O: {quest.id} step {i} mission {step.id} exists`)
				if step.id then
					missionsUsed[step.id] = true
				end
			elseif kind == "gear" then
				check(step.id ~= nil and BaseBuild.gearDef(MissionData, step.id) ~= nil, `O: {quest.id} step {i} gear {step.id} exists`)
			elseif kind == "tool_upgrade" then
				local up = step.id and (BASE.TOOL_UPGRADES :: any)[step.id]
				check(up ~= nil, `O: {quest.id} step {i} tool {step.id} can be upgraded`)
				if up then
					check(isWhole(step.level, 2) and (step.level :: number) <= up.maxLevel, `O: {quest.id} step {i} tool level is 2..{up.maxLevel}`)
				end
			elseif kind == "visit" then
				check(Quests.isPlace(step.place), `O: {quest.id} step {i} place "{step.place}" is valid`)
			elseif kind == "vehicle" then
				check(step.count == nil and step.id == nil, `O: {quest.id} step {i} vehicle needs nothing else`)
			else
				check(Quests.isCounted(kind) and isWhole(step.count, 1), `O: {quest.id} step {i} {kind} has a count >= 1`)
			end
			-- Finite things: never ask for more than exist.
			if kind == "scan" then
				check((step.count or 0) <= SITES, `O: {quest.id} scans at most {SITES} sites`)
			elseif kind == "collectible" then
				check((step.count or 0) <= #Missions.COLLECTIBLES, `O: {quest.id} asks at most {#Missions.COLLECTIBLES} collectibles`)
			elseif kind == "skill" then
				check((step.count or 0) <= skillTotal, `O: {quest.id} asks at most {skillTotal} skill levels`)
			end
		end
	end
	for _, stepType in Quests.STEP_TYPES do
		check(typesUsed[stepType] == true, `O: some quest teaches "{stepType}"`)
	end
	for _, mission in Missions.LIST do
		check(missionsUsed[mission.id] == true, `O: mission {mission.id} is a quest step`)
	end

	-- What a step needs standing before a kid can do it (tools and places come from builds).
	local NEEDS: { [string]: string } = {
		ice = "habitat",
		clean = "solar",
		silo = "drill_1",
		scan = "antenna",
		meteor = "antenna",
		skill = "lab",
		gear = "lab",
		tool_upgrade = "lab",
		vehicle = "garage",
		eat = "greenhouse",
		collectible = "habitat",
	}
	local PLACE_NEEDS: { [string]: string } = { lab = "lab", greenhouse = "greenhouse", garage = "garage", crater = "habitat" }

	-- Walk one quest with the builds standing: build steps go up one level at a time and must be
	-- allowed by the habitat tree and requirements; missions need earlier missions and their builds.
	local function walk(quest: Quests.Quest, standing: BaseBuild.Levels, completed: { [string]: boolean })
		for i, step in quest.steps do
			local kind = step.type
			if kind == "build" and step.id and step.level then
				while BaseBuild.levelOf(standing, step.id) < step.level do
					local ok, reason = BaseBuild.canBuild(MissionData, standing, 15, math.huge, step.id)
					check(ok, `O: {quest.id} step {i}: {step.id} {BaseBuild.levelOf(standing, step.id) + 1} can be built by then ({reason})`)
					if not ok then
						break
					end
					standing[step.id] = BaseBuild.levelOf(standing, step.id) + 1
				end
			elseif kind == "mission" and step.id then
				local mission = Missions.get(step.id)
				if mission then
					check(Missions.requiresDone(mission, completed), `O: {quest.id} step {i}: missions before {step.id} are done by then`)
					-- Training missions build what they teach; the needs must already stand.
					check(Missions.meetsNeeds(mission, standing), `O: {quest.id} step {i}: {step.id} needs stand by then ({Missions.missingBuild(mission, standing)})`)
					for _, objective in mission.objectives do
						local buildId = Missions.buildForObjective(objective.id)
						if buildId then
							check(BaseBuild.levelOf(standing, buildId) >= 1, `O: {quest.id} step {i}: {step.id} teaches {buildId}, built in an earlier step`)
						end
					end
					completed[step.id] = true
				end
			elseif kind == "visit" and step.place then
				local need = PLACE_NEEDS[step.place]
				check(need == nil or BaseBuild.levelOf(standing, need) >= 1, `O: {quest.id} step {i}: {step.place} stands by then`)
			else
				local need = NEEDS[kind]
				check(need == nil or BaseBuild.levelOf(standing, need) >= 1, `O: {quest.id} step {i}: {kind} needs {need} built by then`)
			end
		end
	end

	local standing: BaseBuild.Levels = {}
	local completed: { [string]: boolean } = {}
	local afterState: { [string]: { builds: BaseBuild.Levels, missions: { [string]: boolean } } } = {}
	local habitatAt: { [number]: number } = {}
	for index, quest in Quests.MAIN do
		walk(quest, standing, completed)
		afterState[quest.id] = { builds = table.clone(standing), missions = table.clone(completed) }
		local hab = BaseBuild.habitatLevel(standing)
		if habitatAt[hab] == nil then
			habitatAt[hab] = index
		end
	end
	-- The main line reaches every base level and every structure (each at least level 1).
	for hab = 1, HABITAT_MAX do
		check(habitatAt[hab] ~= nil, `O: the main line reaches habitat {hab}`)
	end
	for _, def in BASE.BUILDS do
		check(BaseBuild.levelOf(standing, def.id) >= 1, `O: the main line builds {def.id}`)
	end
	local last = Quests.MAIN[#Quests.MAIN]
	local lastStep = last.steps[#last.steps]
	check(lastStep.type == "build" and lastStep.id == "ship", "O: the last main quest builds the Mars ship")
	-- Missions in the main line come in the order of Missions.LIST.
	local lastOrder = 0
	for _, quest in Quests.MAIN do
		for _, step in quest.steps do
			if step.type == "mission" and step.id then
				local mission = Missions.get(step.id)
				if mission then
					check(mission.order > lastOrder, `O: main mission {step.id} comes after the missions before it`)
					lastOrder = mission.order
				end
			end
		end
	end
	-- Side quests are reachable once their main quest is done.
	for _, quest in Quests.SIDE do
		local state = if quest.after then afterState[quest.after] else { builds = {}, missions = {} }
		if state then
			walk(quest, table.clone(state.builds), table.clone(state.missions))
		end
	end

	-- Helpers.
	local done: { [string]: boolean } = {}
	check(Quests.nextMain(done) == Quests.MAIN[1], "O: the first main quest comes first")
	check(Quests.mainIndex(Quests.MAIN[2].id) == 2, "O: mainIndex")
	check(Quests.mainIndex(Quests.SIDE[1].id) == nil, "O: side quests have no main index")
	check(Quests.byId("nope") == nil, "O: unknown quest")
	local openAtStart = Quests.sideAvailable(done)
	for _, quest in openAtStart do
		check(quest.after == nil, `O: {quest.id} is open from the start only without after`)
	end
	local active = Quests.active(done)
	check(active[1] == Quests.MAIN[1], "O: active lists the next main quest first")
	check(Quests.isOpen(Quests.MAIN[1], done) and not Quests.isOpen(Quests.MAIN[2], done), "O: only the next main quest is open")
	done[Quests.MAIN[1].id] = true
	check(Quests.nextMain(done) == Quests.MAIN[2], "O: then the second")
	for _, quest in Quests.MAIN do
		done[quest.id] = true
	end
	check(Quests.nextMain(done) == nil and Quests.allMainDone(done), "O: the main line ends")
	check(#Quests.sideAvailable(done) == #Quests.SIDE, "O: after the main line every side quest is open")
	check(Quests.FINALE_KEY == "quest.main_done", "O: finale key")
	check(Quests.isLifetime("scan") and Quests.isLifetime("skill") and Quests.isLifetime("collectible"), "O: finite steps use lifetime totals")
	check(not Quests.isLifetime("ice") and not Quests.isLifetime("meteor"), "O: repeatable steps count while active")
	check(not Quests.isStepType("fly") and not Quests.isStepType(nil), "O: unknown step types are rejected")
	-- stepProgress / stepDone / questDone on views.
	local buildStep: Quests.Step = { type = "build", id = "solar", level = 2 }
	local have, need = Quests.stepProgress(buildStep, { builds = { solar = 1 } })
	check(have == 1 and need == 2, "O: build progress is the level standing")
	check(Quests.stepDone(buildStep, { builds = { solar = 3 } }), "O: a higher level counts")
	have, need = Quests.stepProgress({ type = "ice", count = 4 }, { counts = { ice = 9 } })
	check(have == 4 and need == 4, "O: counts are capped at the target")
	check(not Quests.stepDone({ type = "ice", count = 4 }, {}), "O: an empty view has nothing")
	check(Quests.stepDone({ type = "mission", id = "t1_steps" }, { missions = { t1_steps = true } }), "O: mission step")
	check(Quests.stepDone({ type = "gear", id = "boots" }, { gear = { boots = 2 } }), "O: gear step (any level)")
	check(not Quests.stepDone({ type = "tool_upgrade", id = "drill", level = 2 }, { tools = { drill = 1 } }), "O: tool level 1 is not 2")
	check(Quests.stepDone({ type = "visit", place = "lab" }, { visited = { lab = true } }), "O: visit step")
	check(Quests.stepDone({ type = "vehicle" }, { counts = { vehicle = 1 } }), "O: vehicle step")
	local first = Quests.MAIN[1]
	check(not Quests.questDone(first, {}), "O: the first quest is not done at the start")

	-- Stage 11 "quests that teach".
	-- A first reward within about a minute: one parts box carried to a pad (the free habitat's).
	check(first.id == "m00_landing", "O11: the main line starts with the landing quest")
	check(#first.steps == 1 and first.steps[1].type == "crate" and first.steps[1].count == 1, "O11: the landing quest asks for one parts box")
	check(Quests.questDone(first, { counts = { crate = 1 } }), "O11: one parts box finishes the landing quest")
	check(Quests.isCounted("crate") and not Quests.isLifetime("crate"), "O11: parts boxes count while the quest is active")
	check(BaseBuild.nextCost(MissionData, {}, "habitat") == 0, "O11: the habitat (the first pad with parts to carry) is free")
	-- Cleaned panels are a lifetime total: a kid who cleaned one in Base chores before Talk to Earth
	-- opened is not stuck waiting for dust.
	check(Quests.isLifetime("clean"), "O11: cleaned panels are a lifetime total")
	local m03 = Quests.byId("m03_earth")
	check(
		m03 ~= nil and Quests.questDone(m03, { builds = { antenna = 1 }, missions = { t3_tasks = true }, counts = { clean = 1 } }),
		"O11: Talk to Earth finishes with a panel cleaned earlier"
	)
	-- The tracker shows "have/need" only for counted steps with a target above 1.
	check(Quests.showsFraction({ type = "ice", count = 4 }), "O11: Bring ice home shows 0/4")
	check(not Quests.showsFraction({ type = "eat", count = 1 }), "O11: a count of 1 shows no fraction")
	check(not Quests.showsFraction({ type = "build", id = "solar", level = 2 }), "O11: a build level shows no fraction")
	check(not Quests.showsFraction({ type = "tool_upgrade", id = "drill", level = 2 }), "O11: a tool level shows no fraction")
	-- Praise lines for main quests only.
	for _, quest in Quests.MAIN do
		check(Quests.praiseKey(quest.id) == `quest.{quest.id}.praise`, `O11: {quest.id} has a praise line`)
	end
	for _, quest in Quests.SIDE do
		check(Quests.praiseKey(quest.id) == nil, `O11: side quest {quest.id} uses the generic done line`)
	end
	-- Once the cargo robot can stand, no quest counts silo claims (the robot empties the silo every
	-- CARGO_BOT_SECONDS, so a hand claim would feel random).
	local robotAt: number? = nil
	for index, quest in Quests.MAIN do
		for _, step in quest.steps do
			if step.type == "build" and step.id == "cargo_bot" then
				robotAt = robotAt or index
			end
		end
	end
	check(robotAt ~= nil, "O11: the main line builds the cargo robot")
	for index, quest in Quests.LIST do
		local opensAt = if quest.kind == "main" then index else (if quest.after then Quests.mainIndex(quest.after) else 1)
		if robotAt and opensAt and opensAt >= robotAt then
			for i, step in quest.steps do
				check(step.type ~= "silo", `O11: {quest.id} step {i} does not count silo claims after the cargo robot`)
			end
		end
	end
	-- Saves from before Stage 11 skip the new first quest (QuestService record version 2).
	check(Quests.migrateIndex(1, nil) == 2 and Quests.MAIN[Quests.migrateIndex(1, nil)].id == "m01_home", "O11: an old save on Build your Moon home stays on it")
	check(Quests.migrateIndex(5, nil) == 6, "O11: an old save index moves one along")
	check(Quests.migrateIndex(#Quests.MAIN, nil) == #Quests.MAIN + 1, "O11: an old save with every quest done stays done")
	check(Quests.migrateIndex(999, nil) == #Quests.MAIN + 1, "O11: migrated index is clamped")
	check(Quests.migrateIndex(1, Quests.RECORD_VERSION) == 1, "O11: a new save is not moved")
	check(Quests.migrateIndex(7, Quests.RECORD_VERSION) == 7, "O11: a version 2 save keeps its index")
	-- Hidden treasures hints: every collectible once, nearest first, vague then clearer, none once found.
	check(#Quests.TREASURE_ORDER == #Missions.COLLECTIBLES, "O11: one hint line per collectible")
	for _, id in Missions.COLLECTIBLES do
		check(table.find(Quests.TREASURE_ORDER, id) ~= nil, `O11: collectible {id} has hints`)
	end
	local treasure = Quests.byId(Quests.TREASURE_QUEST)
	check(treasure ~= nil and treasure.kind == "side" and treasure.steps[1].type == "collectible", "O11: the hints belong to Hidden treasures")
	local firstId = Quests.TREASURE_ORDER[1]
	local secondId = Quests.TREASURE_ORDER[2]
	check(Quests.treasureHint({}, 0) == `carl.treasure.{firstId}.1`, "O11: the first hint is vague, for the nearest secret")
	check(Quests.treasureHint({}, 1) == `carl.treasure.{secondId}.1`, "O11: the next hint is the next secret")
	check(Quests.treasureHint({}, #Quests.TREASURE_ORDER) == `carl.treasure.{firstId}.2`, "O11: the second round is clearer")
	check(Quests.treasureHint({}, 99) ~= nil and string.sub(Quests.treasureHint({}, 99) :: string, -2) == ".2", "O11: later hints stay clear")
	check(Quests.treasureHint({ [firstId] = true }, 0) == `carl.treasure.{secondId}.1`, "O11: a found secret gets no hint")
	local all: { [string]: boolean } = {}
	for _, id in Quests.TREASURE_ORDER do
		all[id] = true
	end
	check(Quests.treasureHint(all, 0) == nil, "O11: no hint once every secret is found")
end

----------------------------------------------------------------------------------------------------
-- P. The showcase base (Stage 10, cinematic start menu): while nobody has loaded a save the world
--    shows every build at its top level; one loaded player brings back the normal rule.

do
	local show = BaseBuild.showcaseLevels(MissionData)
	for _, def in BASE.BUILDS do
		check(show[def.id] == def.maxLevel, `P: showcase {def.id} at its top level`)
	end
	check(BaseBuild.habitatLevel(show) == BaseBuild.buildDef(MissionData, "habitat").maxLevel, "P: showcase base level is the top")
	-- A level being built in steps keeps what stands, so the step view is not hidden.
	local busy = BaseBuild.showcaseLevels(MissionData, { solar = true, garage = true }, { solar = 1 })
	check(busy.solar == 1, "P: a build in progress keeps its standing level")
	check(busy.garage == nil, "P: a build in progress from nothing stays a blueprint")
	check(busy.ship == BaseBuild.buildDef(MissionData, "ship").maxLevel, "P: other builds still show finished")

	local shown, showcase = BaseBuild.shownLevels(MissionData, {})
	check(showcase, "P: nobody loaded = showcase")
	check(shown.habitat == BaseBuild.buildDef(MissionData, "habitat").maxLevel, "P: nobody loaded = finished base")
	local newPlayer: BaseBuild.Levels = {}
	shown, showcase = BaseBuild.shownLevels(MissionData, { newPlayer })
	check(not showcase, "P: one loaded player ends the showcase")
	check(next(shown) == nil, "P: a new player's empty base is shown as it is")
	local a: BaseBuild.Levels = { habitat = 2, solar = 1 }
	local b: BaseBuild.Levels = { habitat = 1, solar = 3 }
	shown, showcase = BaseBuild.shownLevels(MissionData, { a, b })
	local eff = BaseBuild.effective({ a, b })
	check(not showcase and shown.habitat == eff.habitat and shown.solar == eff.solar and shown.ship == nil, "P: loaded players = effective builds")
	check(a.habitat == 2 and b.solar == 3, "P: shownLevels does not change the inputs")
	shown = BaseBuild.shownLevels(MissionData, {}, { habitat = true })
	check(shown.habitat == nil, "P: busy builds with nobody loaded show what stands (nothing)")
end

----------------------------------------------------------------------------------------------------
-- Q. Stage 11 tycoon: the ice line (drills -> belt -> silo -> water plant -> cargo robot -> hub).

do
	-- The water plant stands with the first drill; the cargo robot adds the air maker.
	check(BaseBuild.plantLevel({}) == 0, "Q: no drill, no water plant")
	check(BaseBuild.plantLevel({ drill_1 = 1 }) == 1, "Q: the first drill brings the water plant")
	check(BaseBuild.plantLevel({ drill_1 = 1, cargo_bot = 1 }) == 2, "Q: the cargo robot adds the air maker")
	-- Oxygen comes from water plus electricity: no power, no air.
	local powered = { drill_1 = 1, cargo_bot = 1, solar = BASE.AIR_MAKER_SOLAR }
	local unpowered = { drill_1 = 1, cargo_bot = 1, solar = BASE.AIR_MAKER_SOLAR - 1 }
	check(BaseBuild.plantProduct(MissionData, {}) == "none", "Q: nothing to deliver without a plant")
	check(BaseBuild.plantProduct(MissionData, { drill_1 = 1, solar = 3 }) == "water", "Q: the plant alone makes water")
	check(BaseBuild.plantProduct(MissionData, powered) == "oxygen", "Q: a powered air maker makes air")
	check(BaseBuild.plantProduct(MissionData, unpowered) == "water", "Q: the air maker without power makes no air")
	check(BaseBuild.airStatus(MissionData, powered) == "run", "Q: air lamp green with power")
	check(BaseBuild.airStatus(MissionData, unpowered) == "nopower", "Q: air lamp amber without power")
	check(BaseBuild.airStatus(MissionData, { drill_1 = 1 }) == "off", "Q: no air maker, no air lamp")
	check(BASE.AIR_MAKER_SOLAR >= 1 and BASE.AIR_MAKER_SOLAR <= BaseBuild.buildDef(MissionData, "solar").maxLevel, "Q: the air maker's power can be built")
	-- The belt's status light.
	check(BaseBuild.lineStatus(0, 20, 0) == "off", "Q: no drills, belt off")
	check(BaseBuild.lineStatus(5, 20, 2) == "run", "Q: belt runs while the silo has room")
	check(BaseBuild.lineStatus(20, 20, 2) == "full", "Q: belt stops when the silo is full")
	-- What a delivery pays: whole numbers, oxygen more than water, nothing for no ice.
	check(BaseBuild.productCredits(MissionData, 0, "water") == 0, "Q: no ice, no credits")
	check(BaseBuild.productCredits(MissionData, 3.7, "water") == 3 * BASE.CREDITS_PER_SILO_ICE, "Q: only whole ice pays")
	check(BaseBuild.productCredits(MissionData, 5, "none") == 0, "Q: nothing made, nothing paid")
	for ice = 1, 60 do
		local water = BaseBuild.productCredits(MissionData, ice, "water")
		local oxygen = BaseBuild.productCredits(MissionData, ice, "oxygen")
		check(isWhole(water, 1) and isWhole(oxygen, 1) and oxygen >= water, `Q: {ice} ice pays whole credits, air at least water`)
		check(oxygen <= water * (100 + BASE.OXYGEN_BONUS_PERCENT) / 100 + 1e-9, `Q: {ice} ice of air pays at most the bonus`)
	end
	check(BaseBuild.productXp(MissionData, 4) == 4 * BASE.XP_PER_SILO_ICE, "Q: XP per ice")
	-- Machine income: never the rounding-up bonus (a 1-ice claim used to pay double).
	for credits = 1, 30 do
		for level = 1, 3 do
			local bonus = BaseBuild.passiveBonus(MissionData, credits, level)
			check(bonus >= 0 and bonus <= credits * BASE.REWARD_BONUS_PER_LEVEL * level + 1e-9, `Q: machine bonus on {credits} at skill {level} is never rounded up`)
			if credits >= 3 then
				check(bonus <= credits * 0.34, `Q: machine bonus on {credits} at skill {level} stays under a third`)
			end
		end
	end
	check(BaseBuild.passiveBonus(MissionData, 1, 1) == 0, "Q: a 1-ice claim is never doubled")
	-- The cargo robot waits for a real load.
	check(not BaseBuild.cargoReady(MissionData, BASE.CARGO_MIN_LOAD - 0.01), "Q: the robot waits below its load")
	check(BaseBuild.cargoReady(MissionData, BASE.CARGO_MIN_LOAD), "Q: the robot leaves with a full load")
	check(BASE.CARGO_MIN_LOAD <= BASE.SILO_MAX_BY_HABITAT[1], "Q: the smallest silo holds a robot load")
	-- While you were away: capped by the silo and by OFFLINE_MAX_SECONDS, never for bad times.
	local drills = { habitat = 2, drill_1 = 1 }
	local cap = BaseBuild.siloMax(MissionData, drills)
	local rate = BaseBuild.icePerMinute(MissionData, drills)
	local after, gained = BaseBuild.offlineIce(MissionData, drills, 0, 60)
	check(math.abs(gained - rate) < 1e-9 and math.abs(after - rate) < 1e-9, "Q: one minute away = one minute of drilling")
	after, gained = BaseBuild.offlineIce(MissionData, drills, 2, 365 * 24 * 3600)
	check(after == cap and math.abs(gained - (cap - 2)) < 1e-9, "Q: a long time away fills the silo, no more")
	after, gained = BaseBuild.offlineIce(MissionData, drills, 3, -500)
	check(after == 3 and gained == 0, "Q: a clock in the past gives nothing")
	after, gained = BaseBuild.offlineIce(MissionData, drills, 0 / 0, 0 / 0)
	check(after == 0 and gained == 0, "Q: broken numbers give nothing")
	after, gained = BaseBuild.offlineIce(MissionData, {}, 5, 3600)
	check(gained == 0, "Q: no drills, nothing dug while away")
	after = BaseBuild.offlineIce(MissionData, drills, 999, 60)
	check(after == cap, "Q: a stored silo above the silo size is clamped")
	local bigCap = BaseBuild.siloMax(MissionData, { habitat = 5 })
	local bigRate = BaseBuild.icePerMinute(MissionData, { habitat = 5, drill_1 = 3, drill_2 = 3, drill_3 = 3 })
	check(bigRate * BASE.OFFLINE_MAX_SECONDS / 60 >= bigCap, "Q: the offline time can fill the biggest silo")
	check(BASE.OFFLINE_MAX_SECONDS <= 24 * 3600, "Q: offline time is capped at a day or less")
	-- Silo saves.
	local now = 1_800_000_000
	check(BaseBuild.sanitizeSiloSave(MissionData, nil, now) == nil, "Q: no silo save")
	check(BaseBuild.sanitizeSiloSave(MissionData, { ice = "x", at = 1 }, now) == nil, "Q: broken silo save")
	local clean = BaseBuild.sanitizeSiloSave(MissionData, { ice = 999, at = now + 1000 }, now)
	check(clean ~= nil and clean.ice == BASE.SILO_MAX and clean.at == now, "Q: silo save clamped (ice and future time)")
	clean = BaseBuild.sanitizeSiloSave(MissionData, { ice = -4, at = -10 }, now)
	check(clean ~= nil and clean.ice == 0 and clean.at == 0, "Q: negative silo save clamped")
	clean = BaseBuild.sanitizeSiloSave(MissionData, { ice = 12.3456, at = now - 60 }, now)
	check(clean ~= nil and math.abs(clean.ice - 12.35) < 1e-9 and clean.at == now - 60, "Q: silo save keeps two decimals")
	-- Every drill upgrade adds ice; machines never pay past the passive cap of tests/economy.
	for level = 2, #BASE.DRILL_ICE_PER_MINUTE do
		check(BASE.DRILL_ICE_PER_MINUTE[level] > BASE.DRILL_ICE_PER_MINUTE[level - 1], `Q: drill level {level} digs more ice`)
	end
	for _, value in { BASE.OXYGEN_BONUS_PERCENT, BASE.CARGO_MIN_LOAD, BASE.CARGO_IDLE_AFTER_SECONDS, BASE.OFFLINE_MAX_SECONDS, BASE.AIR_MAKER_SOLAR } do
		check(isWhole(value, 0), "Q: tycoon numbers are whole")
	end
	check(BASE.MACHINE_SKILL_BONUS == false or BASE.MACHINE_SKILL_BONUS == true, "Q: MACHINE_SKILL_BONUS is a switch")
end

----------------------------------------------------------------------------------------------------
-- R. Stage 11 tycoon client (src/shared/IceLineView.luau): what the signs, pops, the away card and
-- C.A.R.L. show from what the server sent.

do
	local View = require("../src/shared/IceLineView")
	-- Sign lights and their reasons.
	local s = View.siloStatus({ lineStatus = "run", airStatus = "off", icePerMinute = 2 })
	check(s.light == "run" and s.reasonKey == "ui.line.status_run", "R: running silo")
	s = View.siloStatus({ lineStatus = "full", airStatus = "run", icePerMinute = 2 })
	check(s.light == "full" and s.reasonKey == "ui.line.status_full", "R: full silo stops the belt")
	s = View.siloStatus({ lineStatus = "run", icePerMinute = 0 })
	check(s.light == "off" and s.reasonKey == "ui.line.status_off", "R: no drills: off")
	s = View.siloStatus({})
	check(s.light == "off", "R: an older server (no fields): off")
	s = View.plantStatus({ lineStatus = "run", airStatus = "nopower", icePerMinute = 3 })
	check(s.light == "nopower" and s.reasonKey == "ui.line.air_nopower", "R: plant without power says so")
	s = View.plantStatus({ lineStatus = "full", airStatus = "nopower", icePerMinute = 3 })
	check(s.light == "nopower", "R: no power comes before full on the plant (the fix is solar panels)")
	s = View.plantStatus({ lineStatus = "off", airStatus = "nopower", icePerMinute = 0 })
	check(s.light == "off", "R: no drills: the plant is off too")
	s = View.plantStatus({ lineStatus = "full", airStatus = "run", icePerMinute = 3 })
	check(s.light == "full", "R: a powered plant behind a full silo shows full")

	-- Credits a minute: the server's number first, else the same rule as BaseService.
	check(View.creditsPerMinute(MissionData, 7.5, 2, "water") == 7.5, "R: the server's machineCreditsPerMinute wins")
	check(View.creditsPerMinute(MissionData, nil, 4, "water") == 4 * BASE.CREDITS_PER_SILO_ICE, "R: water rate")
	local oxygen = View.creditsPerMinute(MissionData, nil, 4, "oxygen")
	check(math.abs(oxygen - 4 * BASE.CREDITS_PER_SILO_ICE * (100 + BASE.OXYGEN_BONUS_PERCENT) / 100) < 1e-9, "R: oxygen rate")
	check(oxygen > View.creditsPerMinute(MissionData, nil, 4, "water"), "R: air pays more than water")
	check(View.creditsPerMinute(MissionData, nil, 0, "water") == 0, "R: no drills, no income")
	check(View.creditsPerMinute(MissionData, nil, 3, "none") == 0, "R: no plant, no income")
	-- Same rule as the server's BaseState field.
	for _, levels in { { drill_1 = 1 }, { drill_1 = 2, drill_2 = 1, cargo_bot = 1, solar = 3 }, { drill_1 = 3, cargo_bot = 1, solar = 1 } } do
		local perMinute = BaseBuild.icePerMinute(MissionData, levels)
		local product = BaseBuild.plantProduct(MissionData, levels)
		local server = perMinute * BASE.CREDITS_PER_SILO_ICE * (if product == "oxygen" then (100 + BASE.OXYGEN_BONUS_PERCENT) / 100 else 1)
		check(math.abs(View.creditsPerMinute(MissionData, nil, perMinute, product) - server) < 1e-9, "R: client rate matches BaseService")
	end
	check(View.formatRate(2) == "2" and View.formatRate(2.5) == "2.5" and View.formatRate(3.75) == "3.8", "R: rate text")
	check(View.formatRate(0) == "0" and View.formatRate(-1) == "0" and View.formatRate(0 / 0) == "0", "R: bad rates show 0")
	check(View.formatRate(4.96) == "5", "R: rounding up to a whole number drops the decimal")

	-- "+N" pops: only credits that went to this player.
	check(View.popCredits({ kind = "delivery", credits = 6, mine = true }) == 6, "R: own delivery pops +6")
	check(View.popCredits({ kind = "claim", credits = 3.7, mine = true }) == 3, "R: whole credits")
	check(View.popCredits({ kind = "delivery", credits = 6, mine = false }) == nil, "R: a friend's delivery has no number")
	check(View.popCredits({ kind = "delivery", credits = 6 }) == nil, "R: mine must be true")
	check(View.popCredits({ kind = "delivery", credits = 0, mine = true }) == nil, "R: nothing for 0 credits")
	check(View.popCredits({ kind = "away", ice = 5, mine = true }) == nil, "R: away is a card, not a pop")
	check(View.popCredits({ kind = "full", mine = true }) == nil, "R: full is a cue, not a pop")
	check(View.popCredits(nil) == nil and View.popCredits("x") == nil, "R: junk events are ignored")

	-- "While you were away": the ice waits in the silo; the robot (if any) carries it.
	check(View.awayCard(MissionData, BaseBuild, { kind = "away", ice = 0 }, {}) == nil, "R: no card for no ice")
	check(View.awayCard(MissionData, BaseBuild, { kind = "delivery", ice = 5 }, {}) == nil, "R: only the away kind")
	local card = View.awayCard(MissionData, BaseBuild, { kind = "away", ice = 12.9, capped = true }, { drill_1 = 1 })
	check(card ~= nil and card.ice == 12 and not card.robot and card.capped, "R: card without a robot (whole ice)")
	check(card ~= nil and card.credits == BaseBuild.productCredits(MissionData, 12, "water"), "R: sent by hand it is water")
	card = View.awayCard(MissionData, BaseBuild, { kind = "away", ice = 20 }, { drill_1 = 1, cargo_bot = 1, solar = BASE.AIR_MAKER_SOLAR })
	check(card ~= nil and card.robot and card.credits == BaseBuild.productCredits(MissionData, 20, "oxygen"), "R: the robot brings air")
	card = View.awayCard(MissionData, BaseBuild, { kind = "away", ice = 20 }, { drill_1 = 1, cargo_bot = 1, solar = BASE.AIR_MAKER_SOLAR - 1 })
	check(card ~= nil and card.robot and card.credits == BaseBuild.productCredits(MissionData, 20, "water"), "R: no power: the robot brings water")
	check(card ~= nil and not card.capped, "R: capped only when the server says so")

	-- C.A.R.L. sends the player to the silo only when it is theirs and has enough ice.
	local need = MissionData.TYCOON_CLIENT.CARL_SILO_MIN_ICE
	check(isWhole(need, 1), "R: CARL_SILO_MIN_ICE is a whole number")
	check(View.siloWorthAVisit(MissionData, true, need), "R: own silo with enough ice")
	check(View.siloWorthAVisit(MissionData, nil, need + 0.5), "R: an older server (no siloOwner) counts as the owner")
	check(not View.siloWorthAVisit(MissionData, true, need - 0.01), "R: too little ice: the crater instead")
	check(not View.siloWorthAVisit(MissionData, false, BASE.SILO_MAX), "R: never a friend's silo")
	check(not View.siloWorthAVisit(MissionData, true, nil), "R: no silo ice")

	-- Silo full: "upgrade the habitat" only when the next habitat level really holds more.
	local maxByHab = BASE.SILO_MAX_BY_HABITAT
	for hab = 1, #maxByHab do
		local bigger = View.biggerSiloNext(MissionData, BaseBuild, { habitat = hab })
		local expected = hab < #maxByHab and maxByHab[hab + 1] > maxByHab[hab]
		check(bigger == expected, `R: habitat {hab}: upgrade hint only when the silo grows`)
	end
	check(not View.biggerSiloNext(MissionData, BaseBuild, nil) or maxByHab[2] > maxByHab[1], "R: no builds")
end

----------------------------------------------------------------------------------------------------

print(`base: {passes} passed, {failures} failed`)
if failures > 0 then
	error("base tests failed")
end
