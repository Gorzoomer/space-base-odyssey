--!strict
-- Space Base Odyssey - economy and pacing test (Stage 9). Run with: lune run tests/economy
-- A pure simulator of a reasonable kid player (no Roblox): it lands, follows the main quests, plays
-- one mission day about every 5 minutes, makes ice trips by hand (about 40 s each; faster with the
-- speed skill and the vehicles), cleans panels and aligns the antenna in shifts, claims the silo,
-- scans sites and meteorites, finds the collectibles, learns skills and buys the CHEAPEST useful
-- structure level the habitat (base level) allows. It never stands still to farm (no AFK).
-- Every number about the GAME comes from MissionData (BASE costs and rewards) and Quests (quest
-- rewards); the numbers here only describe how a kid plays (seconds per trip and so on).
-- It prints a timeline (minute of each habitat level and key build, credits per minute in 10-minute
-- windows) and fails when the pacing targets of the team feedback are missed:
--   habitat 2 in 4-10 min, lab in 8-20, habitat 3 in 20-40, garage in 35-70, habitat 4 in 60-110,
--   habitat 5 and the ship in 150-300; income never jumps more than 2.5x from one 10-minute window
--   to the next; the silo never holds more than its habitat level allows, and the drills of each base
--   level never pay more than that level's passive cap.
-- Stage 11 tycoon: the silo and the cargo robot are paid as BaseService pays them (water by hand,
-- oxygen from the robot with a powered air maker, loads of at least CARGO_MIN_LOAD, no skill bonus on
-- machine income), and from the cargo robot to the ship the machines earn 30-50% of play income.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local BaseBuild = require("../src/shared/BaseBuild")
local MissionData = require("../src/shared/MissionData")
local Missions = require("../src/shared/Missions")
local Quests = require("../src/shared/Quests")

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

----------------------------------------------------------------------------------------------------
-- How a kid plays (behaviour model, seconds). Not game data: the game numbers come from MissionData.

export type Profile = {
	name: string,
	funShare: number, -- extra idle time after each task, as a share of that task (looking around, chatting)
	meteorEvery: number, -- scans one meteorite out of this many
	scanEverySeconds: number, -- time between two exploration site visits
	stars: number, -- stars in a typical mission report
}

local TYPICAL: Profile = { name = "typical kid", funShare = 0.3, meteorEvery = 2, scanEverySeconds = 480, stars = 2 }
local FAST: Profile = { name = "fast kid", funShare = 0.05, meteorEvery = 1, scanEverySeconds = 300, stars = 3 }
local SLOW: Profile = { name = "slow kid", funShare = 0.6, meteorEvery = 3, scanEverySeconds = 720, stars = 1 }

local TRIP_WALK_SECONDS = 37 -- running from the crater to the air maker and back (RUN_SPEED)
local TRIP_FIXED_SECONDS = 0.5 -- deliver hold; the drill hold is added from the tool level
local DRILL_HOLD_SECONDS = 2.5 -- the crater ice prompt (WorldBuilder)
local VEHICLE_MOUNT_SECONDS = 6 -- getting in and out of a vehicle
local CRATE_WALK_SECONDS = 20 -- one parts crate from the lander cargo bay to a build pad
local DAY_EVERY_SECONDS = 300 -- one mission day about every 5 minutes
local PLANNING_SECONDS = 30
local SHIFT_TASK_SECONDS = 50 -- in a shift: cleaning, aligning, repairs, waiting out a storm
local SILO_VISIT_SECONDS = 240 -- passes by the silo this often
local FOOD_EVERY_SECONDS = 180 -- eats a fresh food at most this often (when it is ready)
local SILO_CLAIM_SECONDS = 10
local SCAN_SECONDS = 60 -- walk to a site and scan it (half with a vehicle)
local METEOR_PERIOD_SECONDS = (BASE.METEOR.MIN_SECONDS + BASE.METEOR.MAX_SECONDS) // 2
local METEOR_SECONDS = 40
local SITES = 5 -- exploration sites (WorldSites SITE_ORDER)
local COLLECTIBLE_MINUTES = { 20, 50, 90, 140 } -- when a typical kid finds each hidden collectible
local SKILL_ORDER = { "speed", "credits", "builder", "xp", "tank" }
local END_MINUTES = 360

local HAULER = BASE.VEHICLES[2]
local BUGGY = BASE.VEHICLES[1]

----------------------------------------------------------------------------------------------------
-- Pacing targets (team feedback, Stage 9) and passive caps per base level (credits per minute the
-- drills may pay at most when every drill the habitat level allows is at its allowed top level).

local TARGETS: { { label: string, id: string, level: number, low: number, high: number } } = {
	{ label = "habitat 2", id = "habitat", level = 2, low = 4, high = 10 },
	{ label = "lab", id = "lab", level = 1, low = 8, high = 20 },
	{ label = "habitat 3", id = "habitat", level = 3, low = 20, high = 40 },
	{ label = "garage", id = "garage", level = 1, low = 35, high = 70 },
	{ label = "habitat 4", id = "habitat", level = 4, low = 60, high = 110 },
	{ label = "habitat 5", id = "habitat", level = 5, low = 150, high = 300 },
	{ label = "ship", id = "ship", level = 1, low = 150, high = 300 },
}
local PASSIVE_CAP_PER_MINUTE = { 0, 3, 6, 12, 18 } -- by habitat level
local MAX_WINDOW_JUMP = 2.5

----------------------------------------------------------------------------------------------------
-- Simulator

type Result = {
	reached: { [string]: number }, -- "id:level" -> minute
	quests: { [string]: number }, -- quest id -> minute done
	windows: { number }, -- credits earned in each 10-minute window
	passiveWindows: { number }, -- of which from the silo (drills)
	levels: { [number]: number }, -- player level -> minute reached
	siloOk: boolean,
	siloPeak: { [number]: number }, -- habitat level -> most ice seen in the silo
	credits: number,
	xp: number,
	builds: BaseBuild.Levels,
	firstAffordable: { [string]: number }, -- gear / pet id -> minute the kid could first pay it at its gate
}

local function simulate(profile: Profile): Result
	local t = 0
	local credits = BASE.START_CREDITS
	local xp = 0
	local builds: BaseBuild.Levels = {}
	local skills: BaseBuild.Levels = {}
	local tools: { [string]: number } = { drill = 1 }
	local gear: { [string]: number } = {}
	local completed: { [string]: boolean } = {}
	local silo = 0
	local siloOk = true
	local siloPeak: { [number]: number } = {}
	local cargoTimer = 0
	local lastSiloVisit = 0
	local lastScan = 0
	local scanned = 0
	local nextMeteor = METEOR_PERIOD_SECONDS
	local meteorCount = 0
	local nextFood = 0
	local collectiblesFound = 0
	local nextDayAt = 0
	local missionIndex = 1
	local missionDay = 0 -- days done in the current mission
	local reached: { [string]: number } = {}
	local questDoneAt: { [string]: number } = {}
	local windows: { number } = {}
	local passiveWindows: { number } = {}
	local levels: { [number]: number } = { [1] = 0 }
	local firstAffordable: { [string]: number } = {}
	local job: { id: string, level: number, stepsLeft: number, cost: number }? = nil

	-- Quests: done set, per-quest counters since active, lifetime counters, visits.
	local questDone: { [string]: boolean } = {}
	local questCounts: { [string]: { [string]: number } } = {}
	local questVisits: { [string]: { [string]: boolean } } = {}
	local lifetime: { [string]: number } = {}

	local function minute(): number
		return t / 60
	end

	local function playerLevel(): number
		return BaseBuild.levelForXp(MissionData, xp)
	end

	local function windowAdd(list: { number }, amount: number)
		local index = math.floor(t / 600) + 1
		for i = #list + 1, index do
			list[i] = 0
		end
		list[index] += amount
	end

	-- Stage 11 tycoon: silo and cargo robot payouts (passive) get the skill bonus rounded down
	-- (BaseBuild.passiveBonus), exactly as BaseService pays them.
	local function grant(addCredits: number, addXp: number, passive: boolean?)
		local c = math.max(0, math.floor(addCredits))
		local x = math.max(0, math.floor(addXp))
		local bonus = if passive then BaseBuild.passiveBonus else BaseBuild.bonusAmount
		c += bonus(MissionData, c, BaseBuild.levelOf(skills, "credits"))
		x += bonus(MissionData, x, BaseBuild.levelOf(skills, "xp"))
		credits += c
		local before = playerLevel()
		xp += x
		local after = playerLevel()
		for level = before + 1, after do
			levels[level] = minute()
		end
		windowAdd(windows, c)
		windowAdd(passiveWindows, if passive then c else 0)
	end

	local function rewardKind(kind: string, times: number?)
		local def = (BASE.REWARDS :: any)[kind]
		local n = times or 1
		grant(def.credits * n, def.xp * n)
	end

	local function view(quest: Quests.Quest): Quests.View
		local counts: { [string]: number } = {}
		for stepType, value in questCounts[quest.id] or {} do
			counts[stepType] = value
		end
		for stepType, value in lifetime do
			if Quests.isLifetime(stepType) then
				counts[stepType] = value
			end
		end
		return {
			builds = builds,
			missions = completed,
			gear = gear,
			tools = tools,
			counts = counts,
			visited = questVisits[quest.id] or {},
		}
	end

	local function checkQuests()
		local changed = true
		while changed do
			changed = false
			for _, quest in Quests.active(questDone) do
				if Quests.questDone(quest, view(quest)) then
					questDone[quest.id] = true
					questDoneAt[quest.id] = minute()
					grant(quest.reward.credits, quest.reward.xp)
					changed = true
				end
			end
		end
	end

	local function event(stepType: string, n: number?, place: string?)
		local amount = n or 1
		lifetime[stepType] = (lifetime[stepType] or 0) + amount
		for _, quest in Quests.active(questDone) do
			if stepType == "visit" and place then
				local visits = questVisits[quest.id] or {}
				visits[place] = true
				questVisits[quest.id] = visits
			else
				local counts = questCounts[quest.id] or {}
				counts[stepType] = (counts[stepType] or 0) + amount
				questCounts[quest.id] = counts
			end
		end
	end

	-- Stage 11 tycoon: a claim by hand at the silo sends the ice to the water plant (water); the cargo
	-- robot delivers the plant's best product (oxygen with a powered air maker). Both count for the
	-- silo quest steps (the robot is the kid's own machine).
	local function claimSilo(manual: boolean)
		local ice = math.floor(silo)
		if ice < 1 or (not manual and not BaseBuild.cargoReady(MissionData, silo)) then
			return
		end
		silo -= ice
		local product = if manual then "water" else BaseBuild.plantProduct(MissionData, builds)
		grant(BaseBuild.productCredits(MissionData, ice, product), BaseBuild.productXp(MissionData, ice), true)
		event("silo")
	end

	-- Time passes: the drills fill the silo, the cargo robot empties it, food grows.
	local function advance(seconds: number)
		local left = seconds
		while left > 0 do
			local dt = math.min(1, left)
			left -= dt
			t += dt
			local perMinute = BaseBuild.icePerMinute(MissionData, builds)
			local cap = BaseBuild.siloMax(MissionData, builds)
			if perMinute > 0 then
				silo = math.min(cap, silo + perMinute / 60 * dt)
			end
			local hab = BaseBuild.habitatLevel(builds)
			siloPeak[hab] = math.max(siloPeak[hab] or 0, silo)
			if silo > cap + 1e-9 then
				siloOk = false
			end
			if BaseBuild.levelOf(builds, "cargo_bot") >= 1 then
				cargoTimer += dt
				if cargoTimer >= BASE.CARGO_BOT_SECONDS then
					cargoTimer = 0
					claimSilo(false)
				end
			end
		end
	end

	local function busy(seconds: number)
		advance(seconds * (1 + profile.funShare))
	end

	local function finishLevel(id: string, level: number, cost: number)
		builds[id] = level
		reached[`{id}:{level}`] = minute()
		grant(0, BaseBuild.buildXp(MissionData, cost))
		if id == "lab" then
			event("visit", 1, "lab")
		elseif id == "greenhouse" then
			event("visit", 1, "greenhouse")
		end
	end

	local function buildStep()
		local current = job
		if current == nil then
			return
		end
		busy(CRATE_WALK_SECONDS + BASE.ASSEMBLE_HOLD_SECONDS * BaseBuild.builderHoldFactor(MissionData, skills))
		rewardKind("crate_delivered")
		event("crate") -- Stage 11 quest step type (parts boxes carried to a pad)
		rewardKind("stage_done")
		current.stepsLeft -= 1
		if current.stepsLeft <= 0 then
			job = nil
			finishLevel(current.id, current.level, current.cost)
		end
	end

	local function learnSkills()
		local learned = true
		while learned do
			learned = false
			if BaseBuild.levelOf(builds, "lab") < 1 then
				return
			end
			for _, id in SKILL_ORDER do
				if BaseBuild.canLearn(MissionData, skills, playerLevel(), id) then
					skills[id] = BaseBuild.levelOf(skills, id) + 1
					event("skill")
					learned = true
					break
				end
			end
		end
	end

	-- Gear or tools an active quest asks for.
	local function questWants(stepType: string, id: string): boolean
		for _, quest in Quests.active(questDone) do
			for _, step in quest.steps do
				if step.type == stepType and step.id == id then
					return true
				end
			end
		end
		return false
	end

	local function shop()
		learnSkills()
		local unlocked = BaseBuild.toolsUnlocked(MissionData, builds)
		local hasLab = BaseBuild.levelOf(builds, "lab") >= 1
		-- Candidates: every structure level allowed now (only one build at a time), the drill tool
		-- upgrade, and gear an active quest asks for. The cheapest one is bought when affordable.
		local bestKind, bestId, bestCost = nil :: string?, nil :: string?, math.huge
		if job == nil then
			for _, def in BASE.BUILDS do
				local ok = BaseBuild.canBuild(MissionData, builds, playerLevel(), math.huge, def.id)
				local cost = BaseBuild.nextCost(MissionData, builds, def.id)
				if ok and cost and cost < bestCost then
					bestKind, bestId, bestCost = "build", def.id, cost
				end
			end
		end
		if hasLab then
			local level = tools.drill or 1
			local ok = BaseBuild.canUpgradeTool(MissionData, "drill", level, playerLevel(), math.huge, unlocked)
			local cost = BaseBuild.toolUpgradeCost(MissionData, "drill", level)
			if ok and cost and cost < bestCost then
				bestKind, bestId, bestCost = "tool", "drill", cost
			end
			for _, def in BASE.GEAR do
				local level = gear[def.id] or 0
				if level == 0 and questWants("gear", def.id) then
					local okGear = BaseBuild.canBuyGear(MissionData, def.id, 0, playerLevel(), math.huge)
					if okGear and def.costs[1] < bestCost then
						bestKind, bestId, bestCost = "gear", def.id, def.costs[1]
					end
				end
			end
			-- When could this kid first pay each gear level 1 and each pet (for the price check)?
			for _, def in BASE.GEAR do
				if firstAffordable[def.id] == nil and playerLevel() >= def.minLevel[1] and credits >= def.costs[1] then
					firstAffordable[def.id] = minute()
				end
			end
			for _, def in BASE.PETS do
				if def.cost and firstAffordable[def.id] == nil and playerLevel() >= (def.minLevel or 1) and credits >= def.cost then
					firstAffordable[def.id] = minute()
				end
			end
		end
		if bestKind == nil or credits < bestCost then
			return
		end
		credits -= bestCost
		local id = bestId :: string
		if bestKind == "build" then
			local level = BaseBuild.levelOf(builds, id) + 1
			job = { id = id, level = level, stepsLeft = BaseBuild.stagesFor(MissionData, id, level), cost = bestCost }
		elseif bestKind == "tool" then
			tools[id] = (tools[id] or 1) + 1
			reached[`tool_{id}:{tools[id]}`] = minute()
		else
			gear[id] = 1
			reached[`gear_{id}:1`] = minute()
		end
	end

	local function drillFactor(): number
		return BaseBuild.drillHoldFactor(MissionData, tools.drill)
	end

	-- Seconds and ice cores of one ice trip (by hand, buggy or hauler).
	local function tripShape(): (number, number)
		local garage = BaseBuild.levelOf(builds, "garage")
		local run = MissionData.WORLD.RUN_SPEED
		local hold = DRILL_HOLD_SECONDS * drillFactor() + TRIP_FIXED_SECONDS
		if garage >= 2 then
			local cores = HAULER.cargo or 1
			return cores * (hold + 3) + TRIP_WALK_SECONDS * run / HAULER.maxSpeed + VEHICLE_MOUNT_SECONDS, cores
		elseif garage >= 1 then
			return hold + TRIP_WALK_SECONDS * run / BUGGY.maxSpeed + VEHICLE_MOUNT_SECONDS, 1
		end
		return hold + TRIP_WALK_SECONDS * run / (run + BaseBuild.speedBonus(MissionData, skills)), 1
	end

	local function iceTrip()
		local garage = BaseBuild.levelOf(builds, "garage")
		local seconds, cores = tripShape()
		busy(seconds)
		if garage >= 1 then
			event("vehicle")
			event("visit", 1, "garage")
		end
		event("visit", 1, "crater")
		rewardKind("ice_delivered", cores)
		event("ice", cores)
	end

	local function shiftSeconds(mission: Missions.Mission): number
		return mission.shiftSeconds or MissionData.MISSION.SHIFT_SECONDS
	end

	local function hasShift(mission: Missions.Mission): boolean
		for _, objective in mission.objectives do
			local id = objective.id
			if not (id == "go_outside" or id == "return_inside" or Missions.buildForObjective(id) ~= nil) then
				return true
			end
		end
		return false
	end

	local function currentMission(): Missions.Mission?
		local mission = Missions.LIST[missionIndex] or Missions.get("free_play")
		if mission == nil then
			return nil
		end
		if not Missions.isUnlocked(mission, completed, builds) then
			return nil
		end
		for _, objective in mission.objectives do
			local buildId = Missions.buildForObjective(objective.id)
			if buildId and BaseBuild.levelOf(builds, buildId) < 1 then
				return nil -- the kid builds it first (it is cheap and the quest asks for it)
			end
		end
		return mission
	end

	local function finishMission(mission: Missions.Mission)
		rewardKind("star", profile.stars)
		rewardKind(if completed[mission.id] then "mission_repeat" else "mission_first")
		completed[mission.id] = true
		missionDay = 0
		if missionIndex <= #Missions.LIST then
			missionIndex += 1
		end
	end

	local function playDay(mission: Missions.Mission)
		nextDayAt = t + DAY_EVERY_SECONDS
		if BaseBuild.levelOf(builds, "lab") >= 1 then
			event("visit", 1, "lab") -- the kid walks through the Lab on the way to the day's planning
		end
		if not hasShift(mission) then
			finishMission(mission)
			return
		end
		missionDay += 1
		local schedule = mission.schedule or { "None", "None", "Dust", "SolarStorm", "EquipmentFailure", "SolarStorm", "Dust" }
		local event_ = schedule[missionDay] or "None"
		advance(PLANNING_SECONDS)
		local shift = shiftSeconds(mission)
		-- Ice trips in the time the shift tasks leave free (same trips as outside a shift).
		local tripSeconds, tripCores = tripShape()
		local cores = math.floor(math.max(0, shift - SHIFT_TASK_SECONDS) / (tripSeconds * (1 + profile.funShare))) * tripCores
		advance(shift)
		if cores > 0 then
			rewardKind("ice_delivered", cores)
			event("ice", cores)
			event("visit", 1, "crater")
		end
		if event_ == "Dust" then
			rewardKind("panel_cleaned", MissionData.EVENTS.DUST_ARRAYS_COVERED)
			event("clean", MissionData.EVENTS.DUST_ARRAYS_COVERED)
		end
		if BaseBuild.levelOf(builds, "antenna") >= 1 then
			local def = BASE.REWARDS.antenna_aligned
			grant(def.credits + BaseBuild.antennaBonus(MissionData, builds), def.xp)
		end
		if event_ == "EquipmentFailure" then
			rewardKind("leak_repaired")
		end
		rewardKind("day_finished")
		if missionDay >= mission.days then
			finishMission(mission)
		end
	end

	while t < END_MINUTES * 60 do
		shop()
		checkQuests()
		-- A collectible found?
		local nextCollectible = COLLECTIBLE_MINUTES[collectiblesFound + 1]
		if nextCollectible and minute() >= nextCollectible then
			collectiblesFound += 1
			rewardKind("collectible")
			event("collectible")
		end
		local mission = if t >= nextDayAt and BaseBuild.habitatLevel(builds) >= 1 then currentMission() else nil
		if mission == nil and BaseBuild.habitatLevel(builds) < 1 and Missions.LIST[1] then
			mission = nil -- the habitat comes first
		end
		if mission then
			playDay(mission)
		elseif job then
			buildStep()
		elseif BaseBuild.levelOf(builds, "greenhouse") >= 1 and t >= nextFood then
			nextFood = t + math.max(FOOD_EVERY_SECONDS, BaseBuild.foodCooldown(MissionData, builds))
			busy(10)
			rewardKind("food_eaten")
			event("eat")
			event("visit", 1, "greenhouse")
		elseif BaseBuild.levelOf(builds, "drill_1") >= 1 and t - lastSiloVisit >= SILO_VISIT_SECONDS and silo >= 1 then
			lastSiloVisit = t
			busy(SILO_CLAIM_SECONDS)
			claimSilo(true)
		elseif BaseBuild.levelOf(builds, "antenna") >= 1 and scanned < SITES and t - lastScan >= profile.scanEverySeconds then
			lastScan = t
			busy(if BaseBuild.levelOf(builds, "garage") >= 1 then SCAN_SECONDS / 2 else SCAN_SECONDS)
			scanned += 1
			rewardKind("poi_scanned")
			event("scan")
		elseif BaseBuild.levelOf(builds, "antenna") >= 1 and t >= nextMeteor then
			meteorCount += 1
			nextMeteor = t + METEOR_PERIOD_SECONDS
			if meteorCount % profile.meteorEvery == 0 then
				busy(METEOR_SECONDS)
				rewardKind("meteor_scanned")
				event("meteor")
			end
		elseif BaseBuild.habitatLevel(builds) >= 1 then
			iceTrip()
		else
			advance(1) -- waiting for the first job to start (the habitat is free)
		end
	end
	checkQuests()

	return {
		reached = reached,
		quests = questDoneAt,
		windows = windows,
		passiveWindows = passiveWindows,
		levels = levels,
		siloOk = siloOk,
		siloPeak = siloPeak,
		credits = credits,
		xp = xp,
		builds = builds,
		firstAffordable = firstAffordable,
	}
end

----------------------------------------------------------------------------------------------------
-- Report

local function fmt(value: number?): string
	if value == nil then
		return "never"
	end
	return string.format("%5.1f min", value)
end

local function printTimeline(profile: Profile, result: Result)
	print(`\n== {profile.name} ==`)
	print("Base levels and key builds:")
	local keys = {
		{ "habitat 2", "habitat:2" },
		{ "lab", "lab:1" },
		{ "drill 1", "drill_1:1" },
		{ "greenhouse 2", "greenhouse:2" },
		{ "habitat 3", "habitat:3" },
		{ "cargo robot", "cargo_bot:1" },
		{ "drill 2", "drill_2:1" },
		{ "garage (buggy)", "garage:1" },
		{ "antenna 2", "antenna:2" },
		{ "habitat 4", "habitat:4" },
		{ "garage 2 (hauler)", "garage:2" },
		{ "drill 3", "drill_3:1" },
		{ "antenna 3", "antenna:3" },
		{ "landing pad", "landing_pad:1" },
		{ "habitat 5", "habitat:5" },
		{ "ship", "ship:1" },
		{ "drill tool 2", "tool_drill:2" },
		{ "drill tool 3", "tool_drill:3" },
		{ "air boots", "gear_boots:1" },
	}
	for _, pair in keys do
		print(string.format("  %-18s %s", pair[1], fmt(result.reached[pair[2]])))
	end
	print("Credits per minute (10-minute windows; passive = silo):")
	local line = {}
	for i, amount in result.windows do
		local passive = result.passiveWindows[i] or 0
		table.insert(line, string.format("%3d-%3d: %5.1f (%4.1f)", (i - 1) * 10, i * 10, amount / 10, passive / 10))
		if #line == 4 then
			print("  " .. table.concat(line, "   "))
			line = {}
		end
	end
	if #line > 0 then
		print("  " .. table.concat(line, "   "))
	end
	local lv = {}
	for level = 2, BaseBuild.maxPlayerLevel(MissionData) do
		local at = result.levels[level]
		table.insert(lv, `L{level} {if at then string.format("%.0f", at) else "-"}`)
	end
	print("Player level reached (minute): " .. table.concat(lv, ", "))
	local q = {}
	for _, quest in Quests.MAIN do
		local at = result.quests[quest.id]
		table.insert(q, `{quest.id} {if at then string.format("%.0f", at) else "-"}`)
	end
	print("Main quests done (minute): " .. table.concat(q, ", "))
	local s = {}
	for _, quest in Quests.SIDE do
		local at = result.quests[quest.id]
		table.insert(s, `{quest.id} {if at then string.format("%.0f", at) else "-"}`)
	end
	print("Side quests done (minute): " .. table.concat(s, ", "))
end

local function minuteOf(result: Result, id: string, level: number): number?
	return result.reached[`{id}:{level}`]
end

----------------------------------------------------------------------------------------------------
-- 1. The typical kid meets every pacing target.

local typical = simulate(TYPICAL)
printTimeline(TYPICAL, typical)

for _, target in TARGETS do
	local at = minuteOf(typical, target.id, target.level)
	check(at ~= nil and at >= target.low and at <= target.high, `pacing: {target.label} at {fmt(at)} (target {target.low}-{target.high} min)`)
end

-- Income grows smoothly: no 10-minute window earns more than MAX_WINDOW_JUMP times the one before.
-- Only windows before the ship count (afterwards the kid keeps playing side quests and free play).
do
	local shipAt = minuteOf(typical, "ship", 1) or END_MINUTES
	for i = 2, #typical.windows do
		if (i - 1) * 10 > shipAt then
			break
		end
		local before = typical.windows[i - 1]
		local now = typical.windows[i]
		if before > 0 then
			check(now <= before * MAX_WINDOW_JUMP, `income: window {i} earns {now} credits, at most {MAX_WINDOW_JUMP}x the {before} before`)
		end
	end
end

-- Every main quest is done before the simulation ends; the last one is the ship.
do
	for _, quest in Quests.MAIN do
		check(typical.quests[quest.id] ~= nil, `quests: main quest {quest.id} done by the typical kid`)
	end
	local last = Quests.MAIN[#Quests.MAIN]
	local lastStep = last.steps[#last.steps]
	check(lastStep.type == "build" and lastStep.id == "ship", "quests: the last main quest builds the ship")
	-- Main quests finish in order (each one opens when the one before is done).
	local previous = -1
	for _, quest in Quests.MAIN do
		local at = typical.quests[quest.id] or math.huge
		check(at >= previous, `quests: {quest.id} done after the quest before it`)
		previous = at
	end
end

----------------------------------------------------------------------------------------------------
-- 2. The silo and cargo line never go past what the base level allows.

check(typical.siloOk, "silo: never holds more ice than SILO_MAX_BY_HABITAT allows")
for hab = 1, 5 do
	-- The most the drills can make at this base level: every drill at the top level allowed.
	local best: BaseBuild.Levels = { habitat = hab }
	for _, id in { "drill_1", "drill_2", "drill_3" } do
		local level = BaseBuild.maxLevelAt(MissionData, id, hab)
		if level > 0 then
			best[id] = level
		end
	end
	-- Stage 11 tycoon: with the best product the plant can make at this level (oxygen once the
	-- cargo robot and its air maker may stand, with every solar array up).
	if BaseBuild.maxLevelAt(MissionData, "cargo_bot", hab) >= 1 then
		best.cargo_bot = 1
	end
	best.solar = BaseBuild.maxLevelAt(MissionData, "solar", hab)
	local product = BaseBuild.plantProduct(MissionData, best)
	local perMinute = BaseBuild.productCredits(MissionData, BaseBuild.icePerMinute(MissionData, best), product)
	check(perMinute <= PASSIVE_CAP_PER_MINUTE[hab], `silo: habitat {hab} drills pay at most {PASSIVE_CAP_PER_MINUTE[hab]} credits/min ({perMinute})`)
	-- A full silo is worth at most a few minutes of drilling, so leaving the game never pays a lot.
	local siloCredits = BaseBuild.productCredits(MissionData, BaseBuild.siloMax(MissionData, best), if product == "none" then "water" else product)
	check(siloCredits <= 150, `silo: a full silo at habitat {hab} pays {siloCredits} credits (at most 150)`)
	print(string.format("habitat %d: drills up to %2d credits/min, silo %2d ice (peak seen %.1f)", hab, perMinute, BaseBuild.siloMax(MissionData, best), typical.siloPeak[hab] or 0))
end
-- Passive income stays a helper: the silo never earns most of a 10-minute window before the ship.
do
	local shipAt = minuteOf(typical, "ship", 1) or END_MINUTES
	for i, amount in typical.windows do
		if (i - 1) * 10 > shipAt then
			break
		end
		local passive = typical.passiveWindows[i] or 0
		check(amount == 0 or passive <= amount * 0.5, `silo: window {i} passive {passive} of {amount} credits (at most half)`)
	end
end

-- Stage 11 tycoon: from the cargo robot (full automation) to the ship, the machines earn about 30-50%
-- of what playing earns (team: "meaningful, never more than half").
do
	local robotAt = minuteOf(typical, "cargo_bot", 1) or END_MINUTES
	local shipAt = minuteOf(typical, "ship", 1) or END_MINUTES
	local passiveSum, activeSum = 0, 0
	for i, amount in typical.windows do
		local from = (i - 1) * 10
		if from >= robotAt and from + 10 <= shipAt then
			local passive = typical.passiveWindows[i] or 0
			passiveSum += passive
			activeSum += amount - passive
		end
	end
	local share = passiveSum / math.max(1, activeSum)
	print(string.format("tycoon: cargo robot to ship, machines earn %.2f of what playing earns", share))
	check(share >= 0.3 and share <= 0.5, `tycoon: machines earn 30-50% of play income after the cargo robot ({share})`)
	-- The first drill pays itself back quickly (it used to take 40 minutes).
	local drill = BaseBuild.buildDef(MissionData, "drill_1")
	if drill then
		local minutes = drill.costs[1] / BaseBuild.productCredits(MissionData, BASE.DRILL_ICE_PER_MINUTE[1], "water")
		check(minutes <= 25, `tycoon: drill_1 pays itself back within 25 minutes ({minutes})`)
	end
	-- Every drill upgrade digs at least one more ice a minute (upgrades you can see).
	for level = 2, #BASE.DRILL_ICE_PER_MINUTE do
		check(BASE.DRILL_ICE_PER_MINUTE[level] >= BASE.DRILL_ICE_PER_MINUTE[level - 1] + 1, `tycoon: drill level {level} digs at least 1 more ice a minute`)
	end
	-- Oxygen (water plus electricity) pays more than water; water pays at least 1 per ice.
	check(BaseBuild.productCredits(MissionData, 10, "oxygen") > BaseBuild.productCredits(MissionData, 10, "water"), "tycoon: oxygen pays more than water")
	check(BaseBuild.productCredits(MissionData, 1, "water") >= 1, "tycoon: one ice of water pays at least 1 credit")
	-- While you were away: at most one full silo, so leaving the game never pays more than playing.
	for hab = 2, 5 do
		local builds: BaseBuild.Levels = { habitat = hab, drill_1 = BaseBuild.maxLevelAt(MissionData, "drill_1", hab) }
		local cap = BaseBuild.siloMax(MissionData, builds)
		local after, gained = BaseBuild.offlineIce(MissionData, builds, 0, 30 * 24 * 3600)
		check(after <= cap and gained <= cap, `tycoon: habitat {hab} offline ice stays within the silo ({gained} of {cap})`)
	end
	for _, value in { BASE.OXYGEN_BONUS_PERCENT, BASE.CARGO_MIN_LOAD, BASE.OFFLINE_MAX_SECONDS, BASE.CARGO_IDLE_AFTER_SECONDS } do
		check(type(value) == "number" and value == math.floor(value) and value >= 0, "tycoon: whole numbers")
	end
end

----------------------------------------------------------------------------------------------------
-- 3. Other kids: a fast kid never jumps far ahead, a slow kid still gets there.

local fast = simulate(FAST)
printTimeline(FAST, fast)
local slow = simulate(SLOW)
printTimeline(SLOW, slow)
do
	local fastShip = minuteOf(fast, "ship", 1)
	check(fastShip ~= nil and fastShip >= 120, `fast kid: the ship no sooner than 120 min ({fmt(fastShip)})`)
	local fastHab3 = minuteOf(fast, "habitat", 3)
	check(fastHab3 ~= nil and fastHab3 >= 15, `fast kid: habitat 3 no sooner than 15 min ({fmt(fastHab3)})`)
	local slowShip = minuteOf(slow, "ship", 1)
	check(slowShip ~= nil and slowShip <= END_MINUTES, `slow kid: the ship within {END_MINUTES} min ({fmt(slowShip)})`)
end

----------------------------------------------------------------------------------------------------
-- 4. Lab prices (gear, tool upgrades, pets) fit the new economy: once a typical kid has the player
-- level for one, it costs some minutes of play, never nothing and never hours.

do
	for _, def in BASE.GEAR do
		local at = typical.firstAffordable[def.id]
		local gate = typical.levels[def.minLevel[1]]
		check(at ~= nil, `prices: {def.id} is affordable at some point`)
		for i = 2, def.maxLevel do
			check(def.costs[i] > def.costs[i - 1], `prices: {def.id} level {i} costs more`)
		end
	end
	for _, def in BASE.PETS do
		if def.cost then
			local at = typical.firstAffordable[def.id]
			check(at ~= nil, `prices: pet {def.id} is affordable at some point`)
		end
	end
	-- Each gear or pet costs at least 2 minutes of income at the minute its level opens.
	local function incomeAt(minuteValue: number): number
		local index = math.clamp(math.floor(minuteValue / 10) + 1, 1, #typical.windows)
		return typical.windows[index] / 10
	end
	-- Each gear level and pet costs 2 to 25 minutes of the income a typical kid has when its player
	-- level opens it: never nothing, never hours.
	local function priceCheck(label: string, cost: number, level: number)
		local gate = typical.levels[level]
		if gate == nil then
			check(false, `prices: {label} needs player level {level}, which a typical kid reaches`)
			return
		end
		local perMinute = incomeAt(math.max(gate, minuteOf(typical, "lab", 1) or 0))
		local minutes = cost / math.max(perMinute, 1)
		print(string.format("prices: %-10s %4d credits at level %2d (minute %5.1f): %4.1f minutes of income", label, cost, level, gate, minutes))
		check(minutes >= 2 and minutes <= 25, `prices: {label} costs 2-25 minutes of income ({minutes})`)
	end
	for _, def in BASE.GEAR do
		for i = 1, def.maxLevel do
			priceCheck(`{def.id} {i}`, def.costs[i], def.minLevel[i])
		end
	end
	for _, def in BASE.PETS do
		if def.cost and def.minLevel then
			priceCheck(`pet {def.id}`, def.cost, def.minLevel)
		end
	end
	local drillUp = BASE.TOOL_UPGRADES.drill
	for i = 2, drillUp.maxLevel do
		priceCheck(`drill tool {i}`, drillUp.costs[i], drillUp.minLevel[i])
	end
	local drillTool = BASE.TOOL_UPGRADES.drill
	for i = 2, drillTool.maxLevel do
		check(typical.reached[`tool_drill:{i}`] ~= nil, `prices: drill tool level {i} is bought by a typical kid`)
	end
	-- The top player level comes late, not in the first hour (skills grow with the base).
	local top = typical.levels[BaseBuild.maxPlayerLevel(MissionData)]
	check(top == nil or top >= 90, `levels: top player level not before 90 min ({fmt(top)})`)
end

-- Every number the economy uses is whole (no decimals shown to kids).
do
	local function whole(value: any): boolean
		return type(value) == "number" and value == math.floor(value) and value >= 0
	end
	for _, def in BASE.BUILDS do
		for i = 1, def.maxLevel do
			check(whole(def.costs[i]), `whole: {def.id} cost {i}`)
		end
	end
	for kind, def in BASE.REWARDS do
		check(whole(def.credits) and whole(def.xp), `whole: reward {kind}`)
	end
	for _, value in BASE.DRILL_ICE_PER_MINUTE do
		check(whole(value), "whole: DRILL_ICE_PER_MINUTE")
	end
	for _, value in BASE.SILO_MAX_BY_HABITAT do
		check(whole(value), "whole: SILO_MAX_BY_HABITAT")
	end
	for _, value in BASE.ANTENNA_ALIGN_BONUS do
		check(whole(value), "whole: ANTENNA_ALIGN_BONUS")
	end
	check(whole(BASE.CREDITS_PER_SILO_ICE) and whole(BASE.CARGO_BOT_SECONDS), "whole: silo pay and cargo robot time")
	for _, quest in Quests.LIST do
		check(whole(quest.reward.credits) and whole(quest.reward.xp), `whole: quest {quest.id} reward`)
	end
end

print(`\neconomy: {passes} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} economy check(s) failed`)
end
