--!strict
-- Space Base Odyssey - balance tests for the pure simulation. Run with: lune run tests/balance
-- They prove the challenge rule "no choice is free":
--   A. a passive player still reaches day 5 and leaves with 1 star (failure teaches, not punishes);
--   B. no fixed allocation without reacting to events earns 3 stars;
--   C. a player who reacts (shelter, clean, repair, fetch ice) can earn 3 stars;
--   D. cutting the greenhouse shows up as less food on a LATER day;
--   E. skipping life support ends the mission early, after one day of grace.
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

-- B. Every fixed allocation, sheltering perfectly but doing no tasks, earns at most 2 stars.
local bestStatic = 0
for ls = 0, 2 do
	for gh = 0, 2 do
		for sc = 0, 2 do
			for _, seed in SEEDS do
				local state = run({
					plan = function(s)
						place(s, { LifeSupport = ls, Greenhouse = gh, Science = sc })
					end,
					shift = idleShift(false),
				}, seed)
				local stars = Simulation.stars(state, MissionData)
				bestStatic = math.max(bestStatic, stars)
				check(stars <= 2, `B seed {seed}: static {ls}/{gh}/{sc} earned {stars} stars (needs <= 2)`)
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

print(`balance: {passes} passed, {failures} failed; best static allocation earned {bestStatic} stars`)
if failures > 0 then
	error("balance tests failed")
end
