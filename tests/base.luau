--!strict
-- Space Base Odyssey - build-and-grow rules tests (Stages 6 to 8). Run with: lune run tests/base
-- Checks MissionData.BASE is well formed and that src/shared/BaseBuild.luau follows it:
--   A. data: build / skill / pet ids unique, levels match their lists, requirements point to real
--      builds and never to themselves, icons exist, rewards give something; the habitat comes first;
--   B. player level from XP (15 levels), skill points;
--   C. build costs, requirements, level gates and the "max" stop;
--   D. effective builds take the highest level of every present player;
--   E. skills: points, level gates, effects (speed, suit, credits, xp, builder); the drill is a tool
--      and the jump skill is the air boots now;
--   F. pets: collectible pets are found, never bought; bought pets need level and credits;
--   G. automatic drills: ice per minute, silo pay;
--   H. a new player can reach the first builds with START_CREDITS and simple work (no dead end);
--   I. building in steps: steps per level, assemble hold;
--   J. tools: unlocks, the drill tool upgrade (hold time, costs, gates);
--   K. food, meteorites and vehicles data;
--   L. gear (Stage 8): air boots and jetpack, buying, gas use, the gas tank; bonuses are whole numbers;
--   M. save migration (Stage 8): the old jump skill becomes air boots, its points come back.
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
local EXPECTED_GEAR = { "boots", "jetpack" }
local EXPECTED_TOOLS = { "wrench", "drill", "brush", "repair_kit", "tablet", "food" }

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
	check(habitat ~= nil and habitat.minLevel[1] == 1, "A: habitat at player level 1")
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
	check(not ok and reason == "max", "C: only one habitat")

	ok, reason = BaseBuild.canBuild(MissionData, home, 10, 10 ^ 6, "greenhouse")
	check(not ok and reason == "requires", "C: greenhouse needs solar first")

	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 1, 0, "greenhouse")
	check(not ok and reason == "credits", "C: greenhouse without credits says credits")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 1, 15, "greenhouse")
	check(ok, "C: greenhouse with 15 credits and solar 1")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1, greenhouse = 1 }, 3, 10 ^ 6, "greenhouse")
	check(not ok and reason == "level", "C: a bigger greenhouse needs level 4")

	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 1, 10 ^ 6, "solar")
	check(not ok and reason == "level", "C: a second solar array needs player level 2")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 2, 30, "solar")
	check(ok, "C: second solar array at level 2 with 30 credits")
	check(BaseBuild.nextCost(MissionData, { solar = 2 }, "solar") == 60, "C: third solar array costs 60")

	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 3 }, 10, 10 ^ 6, "solar")
	check(not ok and reason == "max", "C: no fourth solar array")
	check(BaseBuild.nextCost(MissionData, { solar = 3 }, "solar") == nil, "C: maxed build has no cost")

	ok, reason = BaseBuild.canBuild(MissionData, {}, 10, 10 ^ 6, "rocket_pad")
	check(not ok and reason == "unknown", "C: unknown build id")
	check(BaseBuild.nextCost(MissionData, {}, "rocket_pad") == nil, "C: unknown build has no cost")

	-- Requirements check the EFFECTIVE builds: drill_1 needs the shelter and power.
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1, antenna = 1 }, 10, 10 ^ 6, "drill_1")
	check(not ok and reason == "requires", "C: drill_1 needs the shelter")
	local sheltered: BaseBuild.Levels = { habitat = 1, solar = 1, antenna = 1, shelter = 1 }
	ok, reason = BaseBuild.canBuild(MissionData, sheltered, 2, 60, "drill_1")
	check(ok, "C: drill_1 at level 2 with 60 credits")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1, antenna = 1, shelter = 1, drill_1 = 1 }, 10, 10 ^ 6, "drill_2")
	check(not ok and reason == "requires", "C: drill_2 needs a second solar array")

	-- The Lab, the garage (two bays), the landing pad and the ship.
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 1, 10 ^ 6, "lab")
	check(not ok and reason == "level", "C: the Lab needs level 2")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1 }, 2, 40, "lab")
	check(ok, "C: the Lab at level 2 with 40 credits")
	ok, reason = BaseBuild.canBuild(MissionData, { habitat = 1, solar = 1, lab = 1 }, 10, 10 ^ 6, "garage")
	check(not ok and reason == "requires", "C: the garage needs the shelter too")
	ok, reason = BaseBuild.canBuild(MissionData, {}, 15, 10 ^ 9, "ship")
	check(not ok and reason == "requires", "C: the ship needs the landing pad")
	local padReady: BaseBuild.Levels = { habitat = 1, solar = 1, lab = 1, antenna = 1, shelter = 1, garage = 1, landing_pad = 1 }
	ok, reason = BaseBuild.canBuild(MissionData, padReady, 7, 10 ^ 9, "ship")
	check(not ok and reason == "level", "C: the ship is a late goal (level 8)")
	ok, reason = BaseBuild.canBuild(MissionData, padReady, 8, 10 ^ 9, "ship")
	check(ok, "C: the ship at level 8")

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
	-- shelter, the first drill. Every step of a build gives its crate and assembly XP.
	local function stepXp(id: string, level: number): number
		local stages = BaseBuild.stagesFor(MissionData, id, level)
		return stages * (BASE.REWARDS.crate_delivered.xp + BASE.REWARDS.stage_done.xp)
	end
	local credits = BASE.START_CREDITS
	local xp = 0
	local builds: BaseBuild.Levels = {}
	local deliveries = 0
	local order = { "habitat", "solar", "greenhouse", "antenna", "shelter", "drill_1" }
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

print(`base: {passes} passed, {failures} failed`)
if failures > 0 then
	error("base tests failed")
end
