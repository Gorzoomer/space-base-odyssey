--!strict
-- Space Base Odyssey - every number the game uses lives here.
-- Each value is tagged REAL (with the DATA_SOURCES.md section it comes from) or GAME (a tuning
-- parameter chosen for playability). REAL values are only shown to players on the Sources screen.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local MissionData = {}

-- REAL facts shown on the Sources screen (values copied from DATA_SOURCES.md).
MissionData.REAL = table.freeze({
	MOON_GRAVITY_MS2 = 1.62, -- Power and surface environment: Moon surface gravity, ratio 0.165
	EARTH_GRAVITY_MS2 = 9.81,
	MOON_EARTH_LIGHT_TIME_S = 1.3, -- Communications: Earth-Moon one-way light time
	MARS_LIGHT_TIME_MIN_MIN = 3, -- Communications: Earth-Mars one-way light time, minimum
	MARS_LIGHT_TIME_MAX_MIN = 22, -- Communications: Earth-Mars one-way light time, maximum
	SHACKLETON_RIM_SUNLIT_DAYS_PER_YEAR = 240, -- Power: south-pole illumination, Shackleton rim
	CONNECTING_RIDGE_SUNLIT_PERCENT = 88, -- Power: connecting ridge, panels 2 m above ground
	COLDEST_LUNAR_TEMP_K = 25, -- Power: Hermite crater floor (north pole), LRO Diviner
	LUNAR_DAY_EARTH_DAYS = 29.5, -- Power: synodic period, about 14 days light + 14 dark
	O2_PER_CREW_KG_DAY = 0.895, -- Life support: NASA BVAD Rev2 Table 3-31
	WATER_PER_CREW_KG_DAY = 2.5, -- Life support: BVAD Rev2 Table 4-20 (drink + food)
	FOOD_PER_CREW_KG_DAY = 2.39, -- Life support: BVAD Rev2, as packaged
	FOOD_KCAL_PER_DAY = 3000, -- Life support: NASA requirement, about 12.7 MJ
	LETTUCE_DAYS_TO_HARVEST_ISS = 33, -- Life support: Veggie, first lettuce eaten 10 Aug 2015
	RADISH_DAYS_TO_HARVEST_ISS = 27, -- Life support: Advanced Plant Habitat, Nov 2020
	ISS_WATER_RECOVERY_PERCENT = 98, -- Life support: ISS ECLSS milestone, June 2023
	LCROSS_WATER_ICE_PERCENT = 5.6, -- Life support: LCROSS, Cabeus crater, by mass
	LUNAR_SURFACE_DOSE_MSV_DAY = 1.37, -- Radiation: Chang'e-4 LND
	EARTH_SURFACE_DOSE_MSV_YEAR = 6.2, -- Radiation: US average
	CAREER_DOSE_LIMIT_MSV = 600, -- Radiation: NASA career limit
	SHELTER_WATER_EQ_CM = 10, -- Radiation: storm shelter, 1-in-100-year event
	SHELTER_BUILD_MINUTES = 60, -- Radiation: Orion crews build the shelter within 1 hour
	SEP_ARRIVAL_MINUTES = 30, -- Radiation: solar energetic particles arrive in about 30 min or less
	FLARE_LIGHT_ARRIVAL_MINUTES = 8, -- Radiation: flare light reaches Earth in about 8 min
	LUNAR_HABITAT_POWER_KW = 20, -- Power: lunar habitat need while crewed
})

-- Roblox physics. Workspace.Gravity 196.2 represents Earth; the Moon keeps the real ratio.
MissionData.WORLD = table.freeze({
	MOON_GRAVITY_STUDS = 32.4, -- GAME, derived: 196.2 * (1.62 / 9.81)
	JUMP_POWER = 30, -- GAME: about 1.9x an Earth jump so kids still fit through doors
	WALK_SPEED = 14, -- GAME
	RUN_SPEED = 22, -- GAME
})

-- Mission structure (GAME).
MissionData.MISSION = table.freeze({
	TOTAL_DAYS = 7,
	GUIDED_DAYS = 2, -- days 1 and 2 introduce one system at a time
	SHIFT_SECONDS = 150, -- real-time work shift after each planning phase
	PLAYERS_MAX = 4,
})

-- Power budget (GAME). Each clean, sunlit solar array gives one cell, plus one battery cell.
MissionData.POWER = table.freeze({
	ARRAYS = 3,
	BATTERY_CELLS = 1,
	MAX_CELLS_PER_SYSTEM = 2,
})

-- Meters run from 0 to 100 (GAME). The Sources screen explains the real values behind them.
MissionData.METERS = table.freeze({
	START_AIR = 70,
	START_FOOD = 60,
	START_DOSE = 0,
	RED_ZONE = 25,
	YELLOW_ZONE = 50,
	AIR_USE_PER_DAY = 20, -- crew breathing
	FOOD_USE_PER_DAY = 15, -- crew eating
	AIR_PER_LIFE_SUPPORT_CELL = 15, -- electrolysis turns water into oxygen with power
	AIR_PER_ICE_CORE = 10, -- ice melted into water, then split into oxygen
	FOOD_PER_GREENHOUSE_CELL = 12, -- harvested the NEXT day: plants take time to grow
	DOSE_BACKGROUND_PER_DAY = 3, -- galactic cosmic rays never stop
	DOSE_PER_EXPOSED_ASTRONAUT = 18, -- caught outside the shelter during a particle storm
	DOSE_LIMIT = 100, -- reaching it sends the crew home early
	AIR_LEAK_PER_DAY = 10, -- equipment failure left unrepaired
	SUIT_REFILL_AIR_COST = 2, -- refilling suits inside the habitat uses base air
})

-- Science score (GAME).
MissionData.SCIENCE = table.freeze({
	POINTS_PER_SCIENCE_CELL = 1,
	POINTS_PER_ICE_CORE = 2,
	TWO_STARS = 10,
	THREE_STARS = 18,
})

-- Personal suit oxygen while outside (GAME).
MissionData.SUIT = table.freeze({
	MAX = 100,
	DRAIN_WALK_PER_SECOND = 1.0,
	DRAIN_RUN_PER_SECOND = 2.0,
	REFILL_PER_SECOND = 15,
})

-- Solar particle storm timing during a shift (GAME). An aligned antenna means Earth's forecasters
-- reach the base in time: the crew gets a longer warning.
MissionData.STORM = table.freeze({
	WARNING_SECONDS_WITH_LINK = 45,
	WARNING_SECONDS_NO_LINK = 15,
	DURATION_SECONDS = 25,
})

-- Event schedule (GAME). Days 1-2 are fixed for onboarding; days 3-7 are shuffled on replay.
MissionData.EVENTS = table.freeze({
	FIXED = table.freeze({ "None", "None" }),
	SHUFFLED = table.freeze({ "Dust", "SolarStorm", "EquipmentFailure", "SolarStorm", "Dust" }),
	DUST_ARRAYS_COVERED = 1,
})

return table.freeze(MissionData)
