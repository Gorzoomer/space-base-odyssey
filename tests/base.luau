--!strict
-- Space Base Odyssey - build-and-grow rules tests (Stage 6). Run with: lune run tests/base
-- Checks MissionData.BASE is well formed and that src/shared/BaseBuild.luau follows it:
--   A. data: build / skill / pet ids unique, levels match their lists, requirements point to real
--      builds and never to themselves, icons exist, rewards are positive;
--   B. player level from XP, skill points;
--   C. build costs, requirements, level gates and the "max" stop;
--   D. effective builds take the highest level of every present player;
--   E. skills: points, level gates, effects (speed, suit, jump, drill);
--   F. pets: collectible pets are found, never bought; bought pets need level and credits;
--   G. automatic drills: ice per minute, silo pay;
--   H. a new player can reach the first builds with START_CREDITS and simple work (no dead end).
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

local EXPECTED_BUILDS = { "solar", "greenhouse", "antenna", "shelter", "drill_1", "drill_2", "drill_3", "cargo_bot" }
local EXPECTED_SKILLS = { "speed", "tank", "jump", "drill" }

do
	local seen: { [string]: boolean } = {}
	for _, def in BASE.BUILDS do
		check(not seen[def.id], `A: build id {def.id} unique`)
		seen[def.id] = true
		check(isWhole(def.maxLevel, 1), `A: {def.id} maxLevel is a whole number >= 1`)
		check(#def.costs == def.maxLevel, `A: {def.id} has one cost per level`)
		check(#def.minLevel == def.maxLevel, `A: {def.id} has one player level per level`)
		for i = 1, def.maxLevel do
			check(isWhole(def.costs[i], 0), `A: {def.id} cost {i} is a whole number`)
			check(isWhole(def.minLevel[i], 1) and def.minLevel[i] <= #BASE.LEVEL_XP, `A: {def.id} minLevel {i} is a real player level`)
			if i > 1 then
				check(def.costs[i] > def.costs[i - 1], `A: {def.id} level {i} costs more than level {i - 1}`)
				check(def.minLevel[i] >= def.minLevel[i - 1], `A: {def.id} level {i} needs at least the level of {i - 1}`)
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
	check(#BASE.JUMP_POWER_BONUS >= 3 and #BASE.DRILL_HOLD_FACTOR >= 3, "A: jump and drill tables cover 3 levels")
	check(#BASE.DRILL_ICE_PER_MINUTE >= 3, "A: drill ice table covers 3 levels")

	local petSeen: { [string]: boolean } = {}
	for _, def in BASE.PETS do
		check(not petSeen[def.id], `A: pet id {def.id} unique`)
		petSeen[def.id] = true
		check((def.collectible ~= nil) ~= (def.cost ~= nil), `A: pet {def.id} is found OR bought, not both`)
	end

	for kind, reward in BASE.REWARDS do
		check(isWhole(reward.credits, 1) and isWhole(reward.xp, 1), `A: reward {kind} gives credits and XP`)
	end
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
	check(BaseBuild.maxPlayerLevel(MissionData) == 10, "B: player levels 1 to 10")
	check(BaseBuild.xpForLevel(MissionData, 3) == BASE.LEVEL_XP[3], "B: xpForLevel reads LEVEL_XP")
	check(BaseBuild.xpForLevel(MissionData, #BASE.LEVEL_XP + 1) == nil, "B: no XP for a level above the top")
	for level = 1, #BASE.LEVEL_XP do
		check(BaseBuild.levelForXp(MissionData, BASE.LEVEL_XP[level]) == level, `B: exact XP of level {level}`)
	end
	check(BaseBuild.skillPoints(1, {}) == 0, "B: level 1 has no skill points")
	check(BaseBuild.skillPoints(4, {}) == 3, "B: level 4 has 3 points")
	check(BaseBuild.skillPoints(4, { speed = 2 }) == 1, "B: spent points are taken away")
	check(BaseBuild.skillPoints(2, { speed = 3 }) == 0, "B: points never go below 0")
	check(BaseBuild.skillPoints(3, nil) == 2, "B: nil skills = none spent")
end

----------------------------------------------------------------------------------------------------
-- C. Building

do
	local empty: BaseBuild.Levels = {}
	local ok, reason = BaseBuild.canBuild(MissionData, empty, 1, 0, "solar")
	check(ok and reason == nil, "C: the first solar array is free at level 1")
	check(BaseBuild.nextCost(MissionData, empty, "solar") == 0, "C: first solar costs 0")

	ok, reason = BaseBuild.canBuild(MissionData, empty, 10, 10 ^ 6, "greenhouse")
	check(not ok and reason == "requires", "C: greenhouse needs solar first")

	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1 }, 1, 0, "greenhouse")
	check(not ok and reason == "credits", "C: greenhouse without credits says credits")
	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1 }, 1, 15, "greenhouse")
	check(ok, "C: greenhouse with 15 credits and solar 1")

	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1 }, 1, 10 ^ 6, "solar")
	check(not ok and reason == "level", "C: a second solar array needs player level 2")
	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1 }, 2, 30, "solar")
	check(ok, "C: second solar array at level 2 with 30 credits")
	check(BaseBuild.nextCost(MissionData, { solar = 2 }, "solar") == 60, "C: third solar array costs 60")

	ok, reason = BaseBuild.canBuild(MissionData, { solar = 3 }, 10, 10 ^ 6, "solar")
	check(not ok and reason == "max", "C: no fourth solar array")
	check(BaseBuild.nextCost(MissionData, { solar = 3 }, "solar") == nil, "C: maxed build has no cost")

	ok, reason = BaseBuild.canBuild(MissionData, {}, 10, 10 ^ 6, "rocket_pad")
	check(not ok and reason == "unknown", "C: unknown build id")
	check(BaseBuild.nextCost(MissionData, {}, "rocket_pad") == nil, "C: unknown build has no cost")

	-- Requirements check the EFFECTIVE builds: drill_1 needs the shelter and power.
	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1, antenna = 1 }, 10, 10 ^ 6, "drill_1")
	check(not ok and reason == "requires", "C: drill_1 needs the shelter")
	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1, antenna = 1, shelter = 1 }, 2, 60, "drill_1")
	check(ok, "C: drill_1 at level 2 with 60 credits")
	ok, reason = BaseBuild.canBuild(MissionData, { solar = 1, antenna = 1, shelter = 1, drill_1 = 1 }, 10, 10 ^ 6, "drill_2")
	check(not ok and reason == "requires", "C: drill_2 needs a second solar array")

	-- Requirement checks come before level and credit checks (the lock shows what to build first).
	ok, reason = BaseBuild.canBuild(MissionData, {}, 1, 0, "cargo_bot")
	check(not ok and reason == "requires", "C: cargo_bot locked by requirements first")

	check(BaseBuild.buildXp(MissionData, 0) == BASE.BUILD_XP_BASE, "C: free build gives the base XP")
	check(BaseBuild.buildXp(MissionData, 60) == BASE.BUILD_XP_BASE + math.floor(60 * BASE.BUILD_XP_PER_CREDIT), "C: XP grows with cost")
	check(BaseBuild.buildXp(MissionData, 15) == BASE.BUILD_XP_BASE + 3, "C: XP rounds down")

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
	ok, reason = BaseBuild.canLearn(MissionData, { tank = 1 }, 2, "speed")
	check(not ok and reason == "points", "E: one point at level 2, already spent")
	ok, reason = BaseBuild.canLearn(MissionData, { speed = 1 }, 3, "speed")
	check(not ok and reason == "level", "E: speed 2 needs level 4")
	ok, reason = BaseBuild.canLearn(MissionData, { speed = 3 }, 10, "speed")
	check(not ok and reason == "max", "E: speed stops at 3")
	ok, reason = BaseBuild.canLearn(MissionData, {}, 10, "fly")
	check(not ok and reason == "unknown", "E: unknown skill")
	ok, reason = BaseBuild.canLearn(MissionData, {}, 2, "jump")
	check(not ok and reason == "level", "E: double jump needs level 3")

	check(BaseBuild.speedBonus(MissionData, nil) == 0, "E: no speed skill, no bonus")
	check(BaseBuild.speedBonus(MissionData, { speed = 2 }) == 2 * BASE.SPEED_BONUS_PER_LEVEL, "E: speed bonus per level")
	check(BaseBuild.suitMax(MissionData, {}) == MissionData.SUIT.MAX, "E: suit max without tank skill")
	check(BaseBuild.suitMax(MissionData, { tank = 3 }) == MissionData.SUIT.MAX + 3 * BASE.TANK_BONUS_PER_LEVEL, "E: bigger air tank")
	check(BaseBuild.jumpPower(MissionData, {}) == MissionData.WORLD.JUMP_POWER, "E: normal Moon jump")
	check(BaseBuild.jumpPower(MissionData, { jump = 3 }) == MissionData.WORLD.JUMP_POWER + BASE.JUMP_POWER_BONUS[3], "E: jump bonus")
	check(not BaseBuild.hasDoubleJump({}) and BaseBuild.hasDoubleJump({ jump = 1 }), "E: jump 1 gives the double jump")
	check(BaseBuild.drillHoldFactor(MissionData, {}) == 1, "E: normal drill time")
	check(BaseBuild.drillHoldFactor(MissionData, { drill = 2 }) == BASE.DRILL_HOLD_FACTOR[2], "E: faster drill")
	for i = 2, #BASE.DRILL_HOLD_FACTOR do
		check(BASE.DRILL_HOLD_FACTOR[i] < BASE.DRILL_HOLD_FACTOR[i - 1], `E: drill level {i} is faster`)
	end
	check(BASE.DRILL_HOLD_FACTOR[1] < 1, "E: drill level 1 is faster than none")
	check(BASE.DOUBLE_JUMP_FRACTION > 0 and BASE.DOUBLE_JUMP_FRACTION <= 1, "E: second jump is smaller")

	-- A player at the top level cannot max every skill: choices cost something.
	local totalSkillLevels = 0
	for _, def in BASE.SKILLS do
		totalSkillLevels += def.maxLevel
	end
	check(BaseBuild.skillPoints(#BASE.LEVEL_XP, {}) < totalSkillLevels, "E: not enough points for every skill (choose!)")
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
	-- Plan: build solar (free), deliver ice by hand, build greenhouse, antenna, shelter.
	local credits = BASE.START_CREDITS
	local xp = 0
	local builds: BaseBuild.Levels = {}
	local deliveries = 0
	local order = { "solar", "greenhouse", "antenna", "shelter", "drill_1" }
	for _, id in order do
		local guard = 0
		while true do
			local ok, reason = BaseBuild.canBuild(MissionData, builds, BaseBuild.levelForXp(MissionData, xp), credits, id)
			if ok then
				local cost = BaseBuild.nextCost(MissionData, builds, id) :: number
				credits -= cost
				xp += BaseBuild.buildXp(MissionData, cost)
				builds[id] = BaseBuild.levelOf(builds, id) + 1
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
	check(BaseBuild.canBuild(MissionData, {}, 1, BASE.START_CREDITS, "solar"), "H: a new player can build solar at once")
	check(BASE.START_CREDITS >= 15, "H: START_CREDITS pays the greenhouse after the free solar array")
end

print(`base: {passes} passed, {failures} failed`)
if failures > 0 then
	error("base tests failed")
end
