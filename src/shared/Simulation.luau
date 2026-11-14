--!strict
-- Space Base Odyssey - pure mission rules. No Roblox instances are touched here, so the module runs
-- unchanged in Roblox and in Lune (tests/balance.luau).
--
-- A mission is a list of days. Each day:
--   1. beginDay  - harvest yesterday's crops, apply the day's event, count available power cells.
--   2. planning  - players place power cells with setAllocation.
--   3. shift     - real-time play outside this module produces a ShiftResult.
--   4. endDay    - apply consumption and production, record what happened and why.
--
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type SystemId = "LifeSupport" | "Greenhouse" | "Science"
export type EventId = "None" | "Dust" | "SolarStorm" | "EquipmentFailure"
export type MeterId = "air" | "food" | "dose"
export type Outcome = "InProgress" | "Completed" | "EarlyReturnAir" | "EarlyReturnFood" | "EarlyReturnDose"

export type Allocation = {
	LifeSupport: number,
	Greenhouse: number,
	Science: number,
}

export type ShiftResult = {
	playerCount: number,
	iceCores: number, -- ice cores delivered to the water processor
	arraysCleaned: number, -- dusty solar arrays cleaned during the shift
	exposedAstronauts: number, -- players outside the shelter when particles arrived
	leakRepaired: boolean,
	suitRefills: number, -- full suit refills taken inside the habitat
}

export type DayRecord = {
	day: number,
	event: EventId,
	allocation: Allocation,
	cellsAvailable: number,
	air: number,
	food: number,
	dose: number,
	sciencePoints: number,
	causeKey: string, -- localization key of the one-line "why" shown in the report
}

export type MissionState = {
	day: number,
	totalDays: number,
	schedule: { EventId },
	todayEvent: EventId,
	allocation: Allocation,
	cellsAvailable: number,
	cleanArrays: number,
	air: number,
	food: number,
	dose: number,
	sciencePoints: number,
	pendingHarvest: number,
	leakActive: boolean,
	critical: { air: boolean, food: boolean },
	outcome: Outcome,
	history: { DayRecord },
}

local SYSTEMS: { SystemId } = { "LifeSupport", "Greenhouse", "Science" }
-- When power drops, cells are removed in this order: science first, life support last.
local TRIM_ORDER: { SystemId } = { "Science", "Greenhouse", "LifeSupport" }

local Simulation = {}
Simulation.SYSTEMS = SYSTEMS

local function clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

local function copyAllocation(allocation: Allocation): Allocation
	return { LifeSupport = allocation.LifeSupport, Greenhouse = allocation.Greenhouse, Science = allocation.Science }
end

local function allocated(allocation: Allocation): number
	return allocation.LifeSupport + allocation.Greenhouse + allocation.Science
end

-- Deterministic shuffle (linear congruential generator) so a seed always gives the same mission.
local function shuffled(list: { EventId }, seed: number): { EventId }
	local result = table.clone(list)
	local stateValue = (math.floor(seed) % 2147483647) + 1
	for i = #result, 2, -1 do
		stateValue = (stateValue * 48271) % 2147483647
		local j = (stateValue % i) + 1
		result[i], result[j] = result[j], result[i]
	end
	return result
end

local function cellsFor(data: any, cleanArrays: number): number
	return data.POWER.BATTERY_CELLS + cleanArrays
end

-- Remove cells, science first, until the allocation fits the available power.
local function trimToSupply(state: MissionState)
	for _, system in TRIM_ORDER do
		while allocated(state.allocation) > state.cellsAvailable and state.allocation[system] > 0 do
			state.allocation[system] -= 1
		end
	end
end

function Simulation.newMission(data: any, seed: number?): MissionState
	local schedule: { EventId } = {}
	for _, event in data.EVENTS.FIXED do
		table.insert(schedule, event)
	end
	local rest = if seed then shuffled(data.EVENTS.SHUFFLED, seed) else table.clone(data.EVENTS.SHUFFLED)
	for _, event in rest do
		table.insert(schedule, event)
	end

	local cleanArrays = data.POWER.ARRAYS
	return {
		day = 0,
		totalDays = data.MISSION.TOTAL_DAYS,
		schedule = schedule,
		todayEvent = "None",
		allocation = { LifeSupport = 2, Greenhouse = 1, Science = 1 },
		cellsAvailable = cellsFor(data, cleanArrays),
		cleanArrays = cleanArrays,
		air = data.METERS.START_AIR,
		food = data.METERS.START_FOOD,
		dose = data.METERS.START_DOSE,
		sciencePoints = 0,
		pendingHarvest = data.METERS.FOOD_PER_GREENHOUSE_CELL, -- crops planted before the crew arrived
		leakActive = false,
		critical = { air = false, food = false },
		outcome = "InProgress",
		history = {},
	}
end

function Simulation.beginDay(state: MissionState, data: any)
	assert(state.outcome == "InProgress", "mission already finished")
	state.day += 1
	state.todayEvent = state.schedule[state.day] or "None"

	-- Yesterday's greenhouse power becomes today's food: plants take time to grow.
	state.food = clamp(state.food + state.pendingHarvest, 0, 100)
	state.pendingHarvest = 0

	if state.todayEvent == "Dust" then
		state.cleanArrays = math.max(0, state.cleanArrays - data.EVENTS.DUST_ARRAYS_COVERED)
	elseif state.todayEvent == "EquipmentFailure" then
		state.leakActive = true
	end

	state.cellsAvailable = cellsFor(data, state.cleanArrays)
	trimToSupply(state)
end

-- Returns true when the change was applied, or false and a localization key explaining why not.
function Simulation.setAllocation(state: MissionState, data: any, system: SystemId, cells: number): (boolean, string?)
	if state.allocation[system] == nil then
		return false, "error.unknown_system"
	end
	if cells ~= math.floor(cells) or cells < 0 or cells > data.POWER.MAX_CELLS_PER_SYSTEM then
		return false, "error.cells_range"
	end
	local others = allocated(state.allocation) - state.allocation[system]
	if others + cells > state.cellsAvailable then
		return false, "error.no_power_left"
	end
	state.allocation[system] = cells
	return true, nil
end

local function pickCause(state: MissionState, data: any, result: ShiftResult, before: { air: number, food: number }): string
	if state.outcome == "EarlyReturnDose" then
		return "cause.dose_limit"
	elseif state.outcome == "EarlyReturnAir" then
		return "cause.air_empty"
	elseif state.outcome == "EarlyReturnFood" then
		return "cause.food_empty"
	end
	if state.todayEvent == "SolarStorm" then
		return if result.exposedAstronauts > 0 then "cause.storm_exposed" else "cause.storm_sheltered"
	end
	if state.leakActive then
		return "cause.leak_unrepaired"
	end
	if state.cleanArrays < data.POWER.ARRAYS then
		return "cause.dusty_panels"
	end
	if state.allocation.Greenhouse == 0 then
		return "cause.no_greenhouse"
	end
	if state.air < before.air and state.allocation.LifeSupport < 2 then
		return "cause.air_falling"
	end
	if result.iceCores > 0 then
		return "cause.ice_delivered"
	end
	if state.allocation.Science == data.POWER.MAX_CELLS_PER_SYSTEM then
		return "cause.big_science"
	end
	return "cause.smooth_day"
end

function Simulation.endDay(state: MissionState, data: any, result: ShiftResult)
	assert(state.outcome == "InProgress", "mission already finished")
	local meters = data.METERS
	local before = { air = state.air, food = state.food }

	-- Repairs and cleaning done during the shift.
	if result.leakRepaired then
		state.leakActive = false
	end
	state.cleanArrays = math.min(data.POWER.ARRAYS, state.cleanArrays + math.max(0, result.arraysCleaned))

	-- Air: electrolysis needs power; ice adds water to split; breathing, leaks and suit refills use it.
	local airChange = state.allocation.LifeSupport * meters.AIR_PER_LIFE_SUPPORT_CELL
		+ result.iceCores * meters.AIR_PER_ICE_CORE
		- meters.AIR_USE_PER_DAY
		- (if state.leakActive then meters.AIR_LEAK_PER_DAY else 0)
		- result.suitRefills * meters.SUIT_REFILL_AIR_COST
	state.air = clamp(state.air + airChange, 0, 100)

	-- Food: eaten today; today's greenhouse power is harvested tomorrow.
	state.food = clamp(state.food - meters.FOOD_USE_PER_DAY, 0, 100)
	state.pendingHarvest = state.allocation.Greenhouse * meters.FOOD_PER_GREENHOUSE_CELL

	-- Radiation dose only ever goes up. The meter is the crew average.
	local exposedShare = if result.playerCount > 0 then clamp(result.exposedAstronauts / result.playerCount, 0, 1) else 0
	local doseGain = meters.DOSE_BACKGROUND_PER_DAY
	if state.todayEvent == "SolarStorm" then
		doseGain += exposedShare * meters.DOSE_PER_EXPOSED_ASTRONAUT
	end
	state.dose = math.min(meters.DOSE_LIMIT, state.dose + doseGain)

	-- Science.
	state.sciencePoints += state.allocation.Science * data.SCIENCE.POINTS_PER_SCIENCE_CELL
		+ result.iceCores * data.SCIENCE.POINTS_PER_ICE_CORE

	-- End conditions. Air and food get one day of grace at zero; dose does not.
	if state.dose >= meters.DOSE_LIMIT then
		state.outcome = "EarlyReturnDose"
	else
		for _, meter in { "air", "food" } :: { "air" | "food" } do
			if state[meter] <= 0 then
				if state.critical[meter] then
					state.outcome = if meter == "air" then "EarlyReturnAir" else "EarlyReturnFood"
				else
					state.critical[meter] = true
				end
			else
				state.critical[meter] = false
			end
		end
	end
	if state.outcome == "InProgress" and state.day >= state.totalDays then
		state.outcome = "Completed"
	end

	table.insert(state.history, {
		day = state.day,
		event = state.todayEvent,
		allocation = copyAllocation(state.allocation),
		cellsAvailable = state.cellsAvailable,
		air = state.air,
		food = state.food,
		dose = state.dose,
		sciencePoints = state.sciencePoints,
		causeKey = pickCause(state, data, result, before),
	})
end

-- 1 star for bringing the crew home safely, more for science. An early return still earns 1 star:
-- the crew is safe, and the report explains what to try next time.
function Simulation.stars(state: MissionState, data: any): number
	if state.sciencePoints >= data.SCIENCE.THREE_STARS and state.outcome == "Completed" then
		return 3
	elseif state.sciencePoints >= data.SCIENCE.TWO_STARS and state.outcome == "Completed" then
		return 2
	end
	return 1
end

function Simulation.meterZone(value: number, meter: MeterId, data: any): "green" | "yellow" | "red"
	-- Dose is "good" when low; air and food are "good" when high.
	local level = if meter == "dose" then 100 - value else value
	if level <= data.METERS.RED_ZONE then
		return "red"
	elseif level <= data.METERS.YELLOW_ZONE then
		return "yellow"
	end
	return "green"
end

return Simulation
