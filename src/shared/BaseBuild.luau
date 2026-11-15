--!strict
-- Space Base Odyssey - rules for building and growing the base (Stage 6): credits, experience and
-- player level, builds and upgrades, skills, pets. Pure functions over MissionData.BASE (passed in as
-- `data`, the whole MissionData table) and plain tables: no Roblox instances, so it runs in Lune
-- (tests/base.luau) as well as on the server (BaseService) and the client (panels).
-- Builds are shared by everyone in a server: a structure stands at the HIGHEST level any present
-- player has built ("effective" builds). Credits, XP, skills and pets belong to each player.
-- Stage 9: the habitat is the town hall. Its level is the base level, and every structure level
-- needs a minimum habitat level (MissionData.BASE.BUILDS[*].hab); the player level gates only
-- skills, gear, tool upgrades and pets.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type Levels = { [string]: number } -- build or skill id -> level (missing = 0)

-- Why a build, upgrade, skill or pet is not available right now. Localization: "base.why.<reason>".
-- "habitat" (Stage 9) = the habitat (base level) is too low for that structure level.
export type Reason = "unknown" | "max" | "requires" | "habitat" | "level" | "credits" | "points" | "owned" | "collectible"

export type BuildDef = {
	id: string,
	icon: string,
	maxLevel: number,
	costs: { number },
	hab: { number }, -- habitat level needed for each level (Stage 9)
	requires: { [string]: number },
}

export type SkillDef = {
	id: string,
	icon: string,
	maxLevel: number,
	minLevel: { number },
}

export type PetDef = {
	id: string,
	collectible: string?,
	cost: number?,
	minLevel: number?,
}

local BaseBuild = {}

local function levelOf(levels: Levels?, id: string): number
	if levels == nil then
		return 0
	end
	local value = levels[id]
	return if type(value) == "number" then value else 0
end
BaseBuild.levelOf = levelOf

function BaseBuild.buildDef(data: any, id: string): BuildDef?
	for _, def in data.BASE.BUILDS do
		if def.id == id then
			return def
		end
	end
	return nil
end

function BaseBuild.skillDef(data: any, id: string): SkillDef?
	for _, def in data.BASE.SKILLS do
		if def.id == id then
			return def
		end
	end
	return nil
end

function BaseBuild.petDef(data: any, id: string): PetDef?
	for _, def in data.BASE.PETS do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- Player level (1..#LEVEL_XP) for a total XP.
function BaseBuild.levelForXp(data: any, xp: number): number
	local level = 1
	for i, need in data.BASE.LEVEL_XP do
		if xp >= need then
			level = i
		end
	end
	return level
end

-- Total XP needed to reach `level` (nil above the top level).
function BaseBuild.xpForLevel(data: any, level: number): number?
	return data.BASE.LEVEL_XP[level]
end

function BaseBuild.maxPlayerLevel(data: any): number
	return #data.BASE.LEVEL_XP
end

-- Skill points earned by a level (one per level, so the top level gives exactly enough points for
-- every skill at its top level; team playtest) minus the ones already spent. A point earned at level
-- 1 waits: every skill needs player level 2 or more.
function BaseBuild.skillPoints(level: number, skills: Levels?): number
	local spent = 0
	if skills then
		for _, value in skills do
			if type(value) == "number" then
				spent += value
			end
		end
	end
	return math.max(0, level - spent)
end

-- The highest level of each build across several players' saved builds.
function BaseBuild.effective(list: { Levels }): Levels
	local result: Levels = {}
	for _, builds in list do
		for id, value in builds do
			if type(value) == "number" and value > (result[id] or 0) then
				result[id] = value
			end
		end
	end
	return result
end

-- Stage 10 (cinematic start menu): the "showcase" base, every build at its top level, so the menu's
-- camera shots show a finished base while nobody in the server has loaded a save. Builds in `busy`
-- (a level being built in steps) keep their level in `standing` instead, so the step view stays.
-- Only the WORLD shows it: saves, quests, mission rules, rewards and BaseState use the effective
-- builds (BaseBuild.effective of the loaded players).
function BaseBuild.showcaseLevels(data: any, busy: { [string]: boolean }?, standing: Levels?): Levels
	local result: Levels = {}
	for _, def in data.BASE.BUILDS do
		if busy ~= nil and busy[def.id] then
			local level = levelOf(standing, def.id)
			if level > 0 then
				result[def.id] = level
			end
		else
			result[def.id] = def.maxLevel
		end
	end
	return result
end

-- Stage 10: the levels the world shows. `loaded` = the saved builds of every present player whose
-- save is loaded. Nobody loaded: the showcase (true); else the effective builds (false).
function BaseBuild.shownLevels(data: any, loaded: { Levels }, busy: { [string]: boolean }?): (Levels, boolean)
	local effective = BaseBuild.effective(loaded)
	if #loaded == 0 then
		return BaseBuild.showcaseLevels(data, busy, effective), true
	end
	return effective, false
end

-- Credits for the NEXT level of a build given the effective builds (nil when maxed or unknown).
function BaseBuild.nextCost(data: any, effective: Levels, id: string): number?
	local def = BaseBuild.buildDef(data, id)
	if def == nil then
		return nil
	end
	local nextLevel = levelOf(effective, id) + 1
	if nextLevel > def.maxLevel then
		return nil
	end
	return def.costs[nextLevel]
end

-- The base level: the habitat's level (0 before it stands).
function BaseBuild.habitatLevel(effective: Levels?): number
	return levelOf(effective, "habitat")
end

-- Habitat level needed for `level` of build `id` (nil for an unknown build or level).
function BaseBuild.habitatNeeded(data: any, id: string, level: number): number?
	local def = BaseBuild.buildDef(data, id)
	if def == nil or level < 1 or level > def.maxLevel then
		return nil
	end
	return def.hab[level]
end

-- Can this player build (or upgrade) `id` to its next level? effective = builds standing in the server.
-- Checks in order: known, not maxed, `requires` stand, the habitat level (reason "habitat"), credits.
-- playerLevel is kept in the signature for older callers; since Stage 9 it does not gate structures.
function BaseBuild.canBuild(data: any, effective: Levels, _playerLevel: number, credits: number, id: string): (boolean, Reason?)
	local def = BaseBuild.buildDef(data, id)
	if def == nil then
		return false, "unknown"
	end
	local nextLevel = levelOf(effective, id) + 1
	if nextLevel > def.maxLevel then
		return false, "max"
	end
	for needId, needLevel in def.requires do
		if levelOf(effective, needId) < needLevel then
			return false, "requires"
		end
	end
	if levelOf(effective, "habitat") < (def.hab[nextLevel] or 0) then
		return false, "habitat"
	end
	if credits < def.costs[nextLevel] then
		return false, "credits"
	end
	return true, nil
end

-- Structure levels that open at exactly habitat level `habLevel` (the "what is new" list for a
-- habitat upgrade), in MissionData.BASE.BUILDS order: { { id = "lab", level = 1 }, ... }. The
-- habitat's own next level is not listed.
function BaseBuild.unlocksAt(data: any, habLevel: number): { { id: string, level: number } }
	local list: { { id: string, level: number } } = {}
	for _, def in data.BASE.BUILDS do
		if def.id ~= "habitat" then
			for level = 1, def.maxLevel do
				if def.hab[level] == habLevel then
					table.insert(list, { id = def.id, level = level })
				end
			end
		end
	end
	return list
end

-- The highest level of build `id` allowed by habitat level `habLevel` (0 = none yet).
function BaseBuild.maxLevelAt(data: any, id: string, habLevel: number): number
	local def = BaseBuild.buildDef(data, id)
	if def == nil then
		return 0
	end
	local best = 0
	for level = 1, def.maxLevel do
		if def.hab[level] <= habLevel then
			best = level
		end
	end
	return best
end

-- The lowest habitat level that allows every structure level in `builds` (at least 1 once anything
-- stands). For old saves (Stage 8 and before, habitat max 1): raising the habitat to this level keeps
-- every structure the player already built valid under the habitat tree.
function BaseBuild.habitatForBuilds(data: any, builds: Levels?): number
	local need = 0
	if builds == nil then
		return 0
	end
	for _, def in data.BASE.BUILDS do
		local level = math.min(levelOf(builds, def.id), def.maxLevel)
		if level >= 1 then
			need = math.max(need, if def.id == "habitat" then level else def.hab[level], 1)
		end
	end
	return need
end

-- Ice the silo holds at the current habitat level (SILO_MAX_BY_HABITAT; SILO_MAX when missing).
function BaseBuild.siloMax(data: any, effective: Levels?): number
	local byHab = data.BASE.SILO_MAX_BY_HABITAT
	local hab = levelOf(effective, "habitat")
	if byHab and #byHab > 0 then
		return byHab[math.clamp(hab, 1, #byHab)]
	end
	return data.BASE.SILO_MAX
end

-- Extra credits for aligning the antenna at its current level (ANTENNA_ALIGN_BONUS; 0 without one).
function BaseBuild.antennaBonus(data: any, effective: Levels?): number
	local level = levelOf(effective, "antenna")
	local bonus = data.BASE.ANTENNA_ALIGN_BONUS
	if level < 1 or bonus == nil then
		return 0
	end
	return bonus[math.clamp(level, 1, #bonus)] or 0
end

-- Seconds between two fresh foods from the greenhouse at its current level.
function BaseBuild.foodCooldown(data: any, effective: Levels?): number
	local food = data.BASE.FOOD
	local level = levelOf(effective, "greenhouse")
	local byLevel = food.COOLDOWN_BY_GREENHOUSE
	if byLevel and level >= 1 then
		return byLevel[math.clamp(level, 1, #byLevel)]
	end
	return food.COOLDOWN_SECONDS
end

-- XP for building or upgrading something that cost `cost` credits.
function BaseBuild.buildXp(data: any, cost: number): number
	return data.BASE.BUILD_XP_BASE + math.floor(cost * data.BASE.BUILD_XP_PER_CREDIT)
end

function BaseBuild.canLearn(data: any, skills: Levels, playerLevel: number, id: string): (boolean, Reason?)
	local def = BaseBuild.skillDef(data, id)
	if def == nil then
		return false, "unknown"
	end
	local nextLevel = levelOf(skills, id) + 1
	if nextLevel > def.maxLevel then
		return false, "max"
	end
	if playerLevel < def.minLevel[nextLevel] then
		return false, "level"
	end
	if BaseBuild.skillPoints(playerLevel, skills) < 1 then
		return false, "points"
	end
	return true, nil
end

-- Pets this player owns: bought ones plus the ones their collectibles give.
function BaseBuild.ownedPets(data: any, bought: { [string]: boolean }?, collectibles: { [string]: boolean }?): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	for _, def in data.BASE.PETS do
		if def.collectible then
			if collectibles and collectibles[def.collectible] then
				owned[def.id] = true
			end
		elseif bought and bought[def.id] then
			owned[def.id] = true
		end
	end
	return owned
end

function BaseBuild.canBuyPet(data: any, owned: { [string]: boolean }, playerLevel: number, credits: number, id: string): (boolean, Reason?)
	local def = BaseBuild.petDef(data, id)
	if def == nil then
		return false, "unknown"
	end
	if owned[id] then
		return false, "owned"
	end
	if def.collectible or def.cost == nil then
		return false, "collectible" -- found, never bought
	end
	if playerLevel < (def.minLevel or 1) then
		return false, "level"
	end
	if credits < def.cost then
		return false, "credits"
	end
	return true, nil
end

-- Ice per minute from all automatic drills standing.
function BaseBuild.icePerMinute(data: any, effective: Levels): number
	local total = 0
	for _, id in { "drill_1", "drill_2", "drill_3" } do
		local level = levelOf(effective, id)
		if level > 0 then
			total += data.BASE.DRILL_ICE_PER_MINUTE[level]
		end
	end
	return total
end

-- Skill effects (all numbers from MissionData.BASE).
function BaseBuild.speedBonus(data: any, skills: Levels?): number
	return levelOf(skills, "speed") * data.BASE.SPEED_BONUS_PER_LEVEL
end

function BaseBuild.suitMax(data: any, skills: Levels?): number
	return data.SUIT.MAX + levelOf(skills, "tank") * data.BASE.TANK_BONUS_PER_LEVEL
end

-- Stage 8: there is no jump skill any more (the air boots give the double jump), so the jump power is
-- the normal Moon jump. The skills argument is kept so older callers still work.
function BaseBuild.jumpPower(data: any, _skills: Levels?): number
	return data.WORLD.JUMP_POWER
end

-- Extra credits or XP for a reward from the "credits" / "xp" skill: REWARD_BONUS_PER_LEVEL per level,
-- rounded UP to a whole number (0 when the skill is not learned or the reward is 0). No decimals.
function BaseBuild.bonusAmount(data: any, base: number, skillLevel: number): number
	if base <= 0 or skillLevel <= 0 then
		return 0
	end
	return math.ceil(base * data.BASE.REWARD_BONUS_PER_LEVEL * skillLevel - 1e-9)
end

-- Assemble hold factor from the "builder" skill.
function BaseBuild.builderHoldFactor(data: any, skills: Levels?): number
	local level = levelOf(skills, "builder")
	return if level > 0 then data.BASE.BUILDER_HOLD_FACTOR[level] else 1
end

function BaseBuild.gearDef(data: any, id: string): any
	for _, def in data.BASE.GEAR do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- Can this player buy (level 0 -> 1) or upgrade a piece of gear at the Lab?
function BaseBuild.canBuyGear(data: any, id: string, currentLevel: number, playerLevel: number, credits: number): (boolean, Reason?)
	local def = BaseBuild.gearDef(data, id)
	if def == nil then
		return false, "unknown"
	end
	local nextLevel = currentLevel + 1
	if nextLevel > def.maxLevel then
		return false, "max"
	end
	if playerLevel < def.minLevel[nextLevel] then
		return false, "level"
	end
	if credits < def.costs[nextLevel] then
		return false, "credits"
	end
	return true, nil
end

-- Gas used per double jump (boots) or per second of thrust (jetpack) at a gear level (0 = not owned).
function BaseBuild.gasUse(data: any, id: string, gearLevel: number): number?
	local def = BaseBuild.gearDef(data, id)
	if def == nil or gearLevel < 1 then
		return nil
	end
	return def.use[math.clamp(gearLevel, 1, def.maxLevel)]
end

-- Ice drilling hold factor for a drill TOOL level (Stage 7: the drill is a tool upgraded at the Lab).
function BaseBuild.drillHoldFactor(data: any, toolLevel: number?): number
	local up = data.BASE.TOOL_UPGRADES.drill
	local level = math.clamp(toolLevel or 1, 1, up.maxLevel)
	return up.holdFactor[level]
end

-- Steps needed to build `level` of build `id` (Stage 7: building happens in steps). Stage 9: a
-- habitat upgrade (a new base level) has its own step count, STAGES_UPGRADE_BY_ID.
function BaseBuild.stagesFor(data: any, id: string, level: number): number
	local byId = data.BASE.STAGES_BY_ID[id]
	if byId and level == 1 then
		return byId
	end
	if id == "ship" and byId then
		return byId
	end
	local upgradeById = data.BASE.STAGES_UPGRADE_BY_ID
	if level > 1 and upgradeById and upgradeById[id] then
		return upgradeById[id]
	end
	return if level <= 1 then data.BASE.STAGES_FIRST else data.BASE.STAGES_UPGRADE
end

function BaseBuild.toolDef(data: any, id: string): any
	for _, def in data.BASE.TOOLS do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- Tools the player may carry, given the builds standing in the server (a tool's unlock build).
function BaseBuild.toolsUnlocked(data: any, effective: Levels): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for _, def in data.BASE.TOOLS do
		if def.unlock == nil or levelOf(effective, def.unlock) >= 1 then
			result[def.id] = true
		end
	end
	return result
end

-- Credits for the next level of a tool upgrade (nil when maxed or unknown).
function BaseBuild.toolUpgradeCost(data: any, id: string, currentLevel: number): number?
	local up = data.BASE.TOOL_UPGRADES[id]
	if up == nil or currentLevel + 1 > up.maxLevel then
		return nil
	end
	return up.costs[currentLevel + 1]
end

function BaseBuild.canUpgradeTool(data: any, id: string, currentLevel: number, playerLevel: number, credits: number, unlocked: { [string]: boolean }): (boolean, Reason?)
	local up = data.BASE.TOOL_UPGRADES[id]
	if up == nil then
		return false, "unknown"
	end
	if not unlocked[id] then
		return false, "requires"
	end
	local nextLevel = currentLevel + 1
	if nextLevel > up.maxLevel then
		return false, "max"
	end
	if playerLevel < up.minLevel[nextLevel] then
		return false, "level"
	end
	if credits < up.costs[nextLevel] then
		return false, "credits"
	end
	return true, nil
end

-- True when every build a mission needs is standing (needs: build id -> minimum level).
function BaseBuild.meetsNeeds(effective: Levels, needs: { [string]: number }?): boolean
	if needs == nil then
		return true
	end
	for id, level in needs do
		if levelOf(effective, id) < level then
			return false
		end
	end
	return true
end

return table.freeze(BaseBuild)
