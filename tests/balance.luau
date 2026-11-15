--!strict
-- Space Base Odyssey - balance tests for the pure simulation. Run with: lune run tests/balance
-- They prove the challenge rule "no choice is free":
--   A. a passive player still reaches day 5 and leaves with 1 star (failure teaches, not punishes);
--   B. no fixed allocation without reacting to events earns 3 stars;
--   C. a player who reacts (shelter, clean, repair, fetch ice) can earn 3 stars;
--   D. cutting the greenhouse shows up as less food on a LATER day;
--   E. skipping life support ends the mission early, after one day of grace;
--   G. skipping ice makes air fall faster than fetching ice (the air maker needs water);
--   H. never linking the antenna earns 1 star: science waits and is sent on the next linked day;
--   I. live meters during a shift never change the state and end exactly at the endDay values.
--   K. fewer solar arrays built (Stage 6) means less power: never more stars than more arrays.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local MissionData = require("../src/shared/MissionData")
local Simulation = require("../src/shared/Simulation")

type MissionState = Simulation.MissionState
type ShiftResult = Simulation.ShiftResult

local SEEDS = { 1, 2, 3, 7, 42, 99, 2026, 31337 }
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

type Policy = {
	plan: (state: MissionState) -> (),
	shift: (state: MissionState) -> ShiftResult,
}

local function run(policy: Policy, seed: number): MissionState
	local state = Simulation.newMission(MissionData, seed)
	while state.outcome == "InProgress" do
		Simulation.beginDay(state, MissionData)
		policy.plan(state)
		Simulation.endDay(state, MissionData, policy.shift(state))
	end
	return state
end

local function place(state: MissionState, wanted: { LifeSupport: number, Greenhouse: number, Science: number })
	-- Clear first, then fill in priority order so the request never exceeds available power.
	for _, system in Simulation.SYSTEMS do
		Simulation.setAllocation(state, MissionData, system, 0)
	end
	for _, system in { "LifeSupport", "Greenhouse", "Science" } :: { Simulation.SystemId } do
		local cells = wanted[system]
		while cells > 0 do
			local ok = Simulation.setAllocation(state, MissionData, system, cells)
			if ok then
				break
			end
			cells -= 1
		end
	end
end

local function idleShift(exposed: boolean): (state: MissionState) -> ShiftResult
	return function(state: MissionState): ShiftResult
		return {
			playerCount = 1,
			iceCores = 0,
			arraysCleaned = 0,
			exposedAstronauts = if exposed and state.todayEvent == "SolarStorm" then 1 else 0,
			leakRepaired = false,
			suitRefills = 0,
			antennaLinked = false,
		}
	end
end

-- A. Passive: never touches the board, never reacts, gets caught outside in storms.
for _, seed in SEEDS do
	local state = run({ plan = function() end, shift = idleShift(true) }, seed)
	local daysPlayed = #state.history
	check(daysPlayed >= 5, `A seed {seed}: passive player reached day {daysPlayed} (needs >= 5)`)
	check(Simulation.stars(state, MissionData) == 1, `A seed {seed}: passive player earned {Simulation.stars(state, MissionData)} stars (needs 1)`)
end

-- B. Every fixed allocation, sheltering perfectly but doing no tasks, earns at most 2 stars, even
-- when the antenna is linked every day (so science really reaches Earth).
local bestStatic = 0
for ls = 0, 2 do
	for gh = 0, 2 do
		for sc = 0, 2 do
			for _, seed in SEEDS do
				for _, linked in { false, true } do
					local state = run({
						plan = function(s)
							place(s, { LifeSupport = ls, Greenhouse = gh, Science = sc })
						end,
						shift = function(s)
							local result = idleShift(false)(s)
							result.antennaLinked = linked
							return result
						end,
					}, seed)
					local stars = Simulation.stars(state, MissionData)
					bestStatic = math.max(bestStatic, stars)
					check(stars <= 2, `B seed {seed}: static {ls}/{gh}/{sc} (antenna {linked}) earned {stars} stars (needs <= 2)`)
				end
			end
		end
	end
end

-- C. Reactive: shelters, cleans dust, repairs the leak, fetches one ice core a day, adapts power.
local reactive: Policy = {
	plan = function(state)
		local lifeSupport = if state.air < 60 or state.leakActive then 2 else 1
		local greenhouse = if state.food < 45 then 2 else 1
		place(state, { LifeSupport = lifeSupport, Greenhouse = greenhouse, Science = 2 })
	end,
	shift = function(state)
		return {
			playerCount = 1,
			iceCores = 1,
			arraysCleaned = MissionData.POWER.ARRAYS - state.cleanArrays,
			exposedAstronauts = 0,
			leakRepaired = state.leakActive,
			suitRefills = 2,
			antennaLinked = true,
		}
	end,
}
for _, seed in SEEDS do
	local state = run(reactive, seed)
	check(state.outcome == "Completed", `C seed {seed}: reactive outcome {state.outcome}`)
	check(Simulation.stars(state, MissionData) == 3, `C seed {seed}: reactive earned {Simulation.stars(state, MissionData)} stars (needs 3), points {state.sciencePoints}`)
end

-- D. Greenhouse cut on day 1: food is still fine on day 1 but lower than the control from day 2 on.
do
	local function foodTrack(greenhouse: number): { number }
		local state = run({
			plan = function(s)
				place(s, { LifeSupport = 2, Greenhouse = if s.day == 1 then greenhouse else 1, Science = 1 })
			end,
			shift = idleShift(false),
		}, 1)
		local track = {}
		for _, record in state.history do
			table.insert(track, record.food)
		end
		return track
	end
	local cut, control = foodTrack(0), foodTrack(1)
	check(cut[1] == control[1], `D: day-1 food should match (cut {cut[1]}, control {control[1]})`)
	check(cut[2] < control[2], `D: day-2 food should be lower after the cut (cut {cut[2]}, control {control[2]})`)
end

-- E. No life support at all: the crew returns early, but not on the first day air hits zero.
do
	local state = run({
		plan = function(s)
			place(s, { LifeSupport = 0, Greenhouse = 2, Science = 2 })
		end,
		shift = idleShift(false),
	}, 1)
	local firstZero: number? = nil
	for _, record in state.history do
		if record.air <= 0 and firstZero == nil then
			firstZero = record.day
		end
	end
	check(state.outcome == "EarlyReturnAir", `E: outcome should be EarlyReturnAir, got {state.outcome}`)
	check(firstZero ~= nil and #state.history == (firstZero :: number) + 1, `E: grace day expected (air hit zero on day {firstZero}, mission ended on day {#state.history})`)
end

-- F. Mission config: default behaviour unchanged; totalDays and schedule override it.
do
	local default = Simulation.newMission(MissionData, 7)
	local same = Simulation.newMission(MissionData, 7, nil)
	check(default.totalDays == MissionData.MISSION.TOTAL_DAYS, `F: default totalDays {default.totalDays}`)
	check(#default.schedule == #MissionData.EVENTS.FIXED + #MissionData.EVENTS.SHUFFLED, "F: default schedule length")
	local identical = #default.schedule == #same.schedule
	for i, event in default.schedule do
		identical = identical and same.schedule[i] == event
	end
	check(identical, "F: nil config gives the same schedule as no config")
	local empty = Simulation.newMission(MissionData, 7, {})
	check(empty.totalDays == default.totalDays and #empty.schedule == #default.schedule, "F: empty config changes nothing")

	local wanted: { Simulation.EventId } = { "EquipmentFailure", "SolarStorm", "Dust" }
	local custom = Simulation.newMission(MissionData, 7, { totalDays = 3, schedule = wanted })
	check(custom.totalDays == 3, `F: custom totalDays {custom.totalDays}`)
	check(#custom.schedule == 3 and custom.schedule[1] == "EquipmentFailure" and custom.schedule[3] == "Dust", "F: custom schedule kept in order")
	check(custom.schedule ~= wanted, "F: custom schedule is copied, not shared")

	local onlyDays = Simulation.newMission(MissionData, 7, { totalDays = 2 })
	check(onlyDays.totalDays == 2 and onlyDays.schedule[1] == default.schedule[1], "F: totalDays alone keeps the default schedule")

	local state = Simulation.newMission(MissionData, 1, { totalDays = 3, schedule = wanted })
	local events = {}
	while state.outcome == "InProgress" do
		Simulation.beginDay(state, MissionData)
		table.insert(events, state.todayEvent)
		reactive.plan(state)
		Simulation.endDay(state, MissionData, reactive.shift(state))
	end
	check(state.outcome == "Completed" and #state.history == 3, `F: 3-day mission ends Completed after 3 days ({state.outcome}, {#state.history})`)
	check(events[1] == "EquipmentFailure" and events[2] == "SolarStorm" and events[3] == "Dust", "F: days follow the custom schedule")
end

-- Same careful crew as C, with one thing changed in every shift.
local function reactiveWith(change: (state: MissionState, result: ShiftResult) -> ()): Policy
	return {
		plan = reactive.plan,
		shift = function(state)
			local result = reactive.shift(state)
			change(state, result)
			return result
		end,
	}
end

local function airTrack(state: MissionState): { number }
	local track = {}
	for _, record in state.history do
		table.insert(track, record.air)
	end
	return track
end

-- G. Skipping ice: the water tank runs dry, the air maker slows and air falls faster.
for _, seed in SEEDS do
	local withIce = run(reactive, seed)
	local noIce = run(
		reactiveWith(function(_, result)
			result.iceCores = 0
		end),
		seed
	)
	local iceAir, dryAir = airTrack(withIce), airTrack(noIce)
	local never = true
	local lower = false
	for day, air in dryAir do
		never = never and air <= iceAir[day]
		lower = lower or air < iceAir[day]
	end
	check(never and lower, `G seed {seed}: air without ice should stay below air with ice`)
	local dry = false
	for _, record in noIce.history do
		dry = dry or record.causeKey == "cause.no_water"
	end
	check(dry, `G seed {seed}: the report says the tank ran dry (cause.no_water)`)
	check(noIce.water == 0, `G seed {seed}: water tank empty without ice ({noIce.water})`)
	check(withIce.water > 0, `G seed {seed}: water left with ice ({withIce.water})`)
	local days = math.min(#iceAir, #dryAir)
	local function drop(track: { number }): number
		return (MissionData.METERS.START_AIR - track[days]) / days
	end
	check(drop(dryAir) > drop(iceAir), `G seed {seed}: air falls faster without ice`)
end

-- H. Antenna: never linked = every science point waits = 1 star. Linked only on the last day sends
-- everything that waited, so the stars come back.
for _, seed in SEEDS do
	local never = run(
		reactiveWith(function(_, result)
			result.antennaLinked = false
		end),
		seed
	)
	check(never.outcome == "Completed", `H seed {seed}: no-antenna crew still completes ({never.outcome})`)
	check(
		never.sciencePoints == 0 and never.pendingScience > 0,
		`H seed {seed}: science waits (sent {never.sciencePoints}, waiting {never.pendingScience})`
	)
	check(
		Simulation.stars(never, MissionData) == 1,
		`H seed {seed}: never linking the antenna earned {Simulation.stars(never, MissionData)} stars (needs 1)`
	)
	local waiting = false
	for _, record in never.history do
		waiting = waiting or record.causeKey == "cause.data_waiting"
	end
	check(waiting, `H seed {seed}: the report says data is waiting (cause.data_waiting)`)

	local always = run(reactive, seed)
	local lastOnly = run(
		reactiveWith(function(state, result)
			result.antennaLinked = state.day == state.totalDays
		end),
		seed
	)
	check(
		lastOnly.sciencePoints == always.sciencePoints,
		`H seed {seed}: waiting science is sent later ({lastOnly.sciencePoints} vs {always.sciencePoints})`
	)
	check(lastOnly.pendingScience == 0, `H seed {seed}: nothing left waiting after the last link`)
	local lastRecord = lastOnly.history[#lastOnly.history]
	check(lastRecord.scienceSent == lastOnly.sciencePoints, `H seed {seed}: the last day sent all of it ({lastRecord.scienceSent})`)
end

-- I. Live meters: pure, start at the start-of-day values, end at the endDay values.
do
	local state = Simulation.newMission(MissionData, 3)
	Simulation.beginDay(state, MissionData)
	place(state, { LifeSupport = 1, Greenhouse = 1, Science = 2 })
	state.leakActive = true
	state.todayEvent = "SolarStorm"
	local result: ShiftResult = {
		playerCount = 2,
		iceCores = 1,
		arraysCleaned = 0,
		exposedAstronauts = 1,
		leakRepaired = false,
		suitRefills = 3,
		antennaLinked = true,
	}
	local before = { air = state.air, water = state.water, points = state.sciencePoints, days = #state.history }
	local preview = Simulation.previewEndDay(state, MissionData, result)
	check(
		state.air == before.air and state.water == before.water and #state.history == before.days and state.day == 1,
		"I: previewEndDay does not change the state"
	)
	check(#preview.history == before.days + 1, "I: previewEndDay returns the ended day")

	local idle: ShiftResult = table.clone(result)
	idle.iceCores, idle.suitRefills, idle.exposedAstronauts, idle.antennaLinked = 0, 0, 0, false
	local start = Simulation.liveMeters(state, MissionData, idle, 0)
	check(math.abs(start.air - state.air) < 1e-9 and math.abs(start.food - state.food) < 1e-9, "I: a shift starts at the start-of-day meters")
	check(start.water == state.water and start.dose == state.dose, "I: a shift starts at the start-of-day water and dose")

	local early = Simulation.liveMeters(state, MissionData, result, 0.1)
	check(early.water > state.water, "I: ice delivered raises water at once")
	check(early.dose > state.dose, "I: storm exposure raises the dose at once")
	check(early.pendingScience == 0, "I: a linked antenna sends the waiting science")

	local mid = Simulation.liveMeters(state, MissionData, idle, 0.5)
	local later = Simulation.liveMeters(state, MissionData, idle, 0.9)
	check(mid.air < state.air and later.air < mid.air, `I: a leak drains air steadily ({state.air} > {mid.air} > {later.air})`)
	local finalLive = Simulation.liveMeters(state, MissionData, result, 1)
	Simulation.endDay(state, MissionData, result)
	for _, key in { "air", "food", "dose", "water", "pendingScience", "sciencePoints" } do
		local a, b = (finalLive :: any)[key] :: number, (state :: any)[key] :: number
		check(math.abs(a - b) < 1e-6, `I: live {key} at the end ({a}) equals endDay ({b})`)
	end
	check(state.sciencePoints > before.points, "I: endDay sent the science")
end

-- J. Water rules: ice fills the tank (up to MAX), the air maker uses it, no power uses none.
do
	local state = Simulation.newMission(MissionData, 1)
	check(state.water == MissionData.WATER.START, "J: tank starts at WATER.START")
	Simulation.beginDay(state, MissionData)
	place(state, { LifeSupport = 0, Greenhouse = 2, Science = 2 })
	Simulation.endDay(state, MissionData, idleShift(false)(state))
	check(state.water == MissionData.WATER.START, "J: no air maker, no water used")
	Simulation.beginDay(state, MissionData)
	place(state, { LifeSupport = 1, Greenhouse = 1, Science = 1 })
	local result = idleShift(false)(state)
	result.iceCores = 20
	Simulation.endDay(state, MissionData, result)
	check(
		state.water == MissionData.WATER.MAX - MissionData.WATER.USE_PER_DAY,
		`J: tank capped at MAX before the day's use ({state.water})`
	)
end

-- K. Solar arrays built (Stage 6): power cells = clean arrays + battery. Fewer arrays never give
-- more stars, dust and cleaning stay within the arrays standing, and the default is unchanged.
do
	local default = Simulation.newMission(MissionData, 5)
	check(default.arrays == MissionData.POWER.ARRAYS, `K: default arrays {default.arrays}`)
	local clampedHigh = Simulation.newMission(MissionData, 5, { arrays = MissionData.POWER.ARRAYS + 4 })
	check(clampedHigh.arrays == MissionData.POWER.ARRAYS, "K: arrays capped at POWER.ARRAYS")
	local clampedLow = Simulation.newMission(MissionData, 5, { arrays = 0 })
	check(clampedLow.arrays == 1, "K: at least one array")

	local function runArrays(arrays: number, seed: number): MissionState
		local state = Simulation.newMission(MissionData, seed, { arrays = arrays })
		while state.outcome == "InProgress" do
			Simulation.beginDay(state, MissionData)
			reactive.plan(state)
			local result = reactive.shift(state)
			result.arraysCleaned = state.arrays - state.cleanArrays
			Simulation.endDay(state, MissionData, result)
		end
		return state
	end

	for _, arrays in { 1, 2 } do
		local state = Simulation.newMission(MissionData, 1, { arrays = arrays, schedule = { "None", "Dust" }, totalDays = 2 })
		check(state.arrays == arrays and state.cleanArrays == arrays, `K{arrays}: starts with {arrays} clean arrays`)
		check(
			state.cellsAvailable == arrays + MissionData.POWER.BATTERY_CELLS,
			`K{arrays}: cells {state.cellsAvailable} = arrays + battery`
		)
		Simulation.beginDay(state, MissionData)
		check(state.cellsAvailable == arrays + MissionData.POWER.BATTERY_CELLS, `K{arrays}: day 1 cells match`)
		place(state, { LifeSupport = 2, Greenhouse = 2, Science = 2 })
		local used = state.allocation.LifeSupport + state.allocation.Greenhouse + state.allocation.Science
		check(used <= state.cellsAvailable, `K{arrays}: allocation {used} fits the power`)
		local result = idleShift(false)(state)
		result.arraysCleaned = 5 -- more than stand: cleaning never makes extra arrays
		Simulation.endDay(state, MissionData, result)
		check(state.cleanArrays == arrays, `K{arrays}: cleaning capped at the arrays standing ({state.cleanArrays})`)
		Simulation.beginDay(state, MissionData) -- dust day
		check(state.cleanArrays == arrays - 1, `K{arrays}: dust covers one array ({state.cleanArrays})`)
		check(state.cellsAvailable == arrays - 1 + MissionData.POWER.BATTERY_CELLS, `K{arrays}: dust costs one cell`)
		local dusty = idleShift(false)(state)
		Simulation.endDay(state, MissionData, dusty)
		check(state.history[2].causeKey == "cause.dusty_panels", `K{arrays}: the report blames the dusty panel ({state.history[2].causeKey})`)
	end

	for _, seed in SEEDS do
		local one, two, three = runArrays(1, seed), runArrays(2, seed), runArrays(3, seed)
		local s1, s2, s3 = Simulation.stars(one, MissionData), Simulation.stars(two, MissionData), Simulation.stars(three, MissionData)
		check(s1 <= s2 and s2 <= s3, `K seed {seed}: more arrays never earn fewer stars ({s1}, {s2}, {s3})`)
		check(one.sciencePoints <= three.sciencePoints, `K seed {seed}: one array gathers less science`)
		check(#two.history >= 5, `K seed {seed}: a careful crew with two arrays reaches day {#two.history} (needs >= 5)`)
		check(s3 == 3, `K seed {seed}: three arrays still allow 3 stars ({s3})`)
	end
end

print(`balance: {passes} passed, {failures} failed; best static allocation earned {bestStatic} stars`)
if failures > 0 then
	error("balance tests failed")
end
