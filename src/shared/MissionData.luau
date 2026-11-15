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
	AIR_PER_ICE_CORE = 10, -- fresh ice water split into oxygen right away (needs the air maker powered)
	FOOD_PER_GREENHOUSE_CELL = 12, -- harvested the NEXT day: plants take time to grow
	DOSE_BACKGROUND_PER_DAY = 3, -- galactic cosmic rays never stop
	DOSE_PER_EXPOSED_ASTRONAUT = 18, -- caught outside the shelter during a particle storm
	DOSE_LIMIT = 100, -- reaching it sends the crew home early
	AIR_LEAK_PER_DAY = 10, -- equipment failure left unrepaired
	SUIT_REFILL_AIR_COST = 2, -- refilling suits inside the habitat uses base air
})

-- Water tank (GAME units, not litres). Real science (DATA_SOURCES.md, Life support row 9): the air
-- maker splits water into oxygen with electricity, so without water it cannot make air. Ice cores
-- from the crater melt into the tank.
MissionData.WATER = table.freeze({
	MAX = 10,
	START = 6,
	USE_PER_DAY = 2, -- the air maker uses this much each day it has power
	PER_ICE_CORE = 2,
	-- Without enough water the air maker makes only its share: 1 of 2 units = half the air.
})

-- Live meters during a shift (GAME). The HUD shows the day moving toward its end-of-day values.
MissionData.LIVE = table.freeze({
	PUSH_SECONDS = 0.25, -- at most four snapshots per second while meters move
	METER_STEP = 0.1, -- meters are sent rounded to this step
})

-- Science score (GAME). Science only counts once it is sent to Earth: on a day the antenna is
-- linked (real: rover data reaches scientists only through a radio link). Until then it waits.
MissionData.SCIENCE = table.freeze({
	POINTS_PER_SCIENCE_CELL = 1,
	POINTS_PER_ICE_CORE = 2,
	TWO_STARS = 10,
	THREE_STARS = 18,
})

-- Redeem codes (GAME). The codes themselves live only on the server (src/server/Codes.luau).
MissionData.CODES = table.freeze({
	MAX_LENGTH = 24,
	COOLDOWN_SECONDS = 2, -- one attempt every 2 seconds per player
})

-- Personal suit oxygen while outside (GAME).
MissionData.SUIT = table.freeze({
	MAX = 100,
	DRAIN_WALK_PER_SECOND = 1.0,
	DRAIN_RUN_PER_SECOND = 2.0,
	DRAIN_IDLE_PER_SECOND = 0.5,
	RUN_SPEED_THRESHOLD = 18, -- studs/s measured on the server; above this counts as running
	RESCUE_REFILL = 60, -- C.A.R.L. brings an astronaut with an empty suit back inside
	REFILL_PER_SECOND = 15,
})

-- Solar particle storm timing during a shift (GAME). An aligned antenna means Earth's forecasters
-- reach the base in time: the crew gets a longer warning.
MissionData.STORM = table.freeze({
	WARNING_SECONDS_WITH_LINK = 45,
	WARNING_SECONDS_NO_LINK = 15,
	DURATION_SECONDS = 25,
	FLARE_AT_SECONDS = 40, -- seconds into the shift when the flare is spotted
})

-- Build and grow the base (GAME, Stages 6-7). A new player lands in the arrival lander (the spawn)
-- and builds the whole base: the habitat first, then everything else. Credits come from useful work
-- (ice, repairs, days finished, data sent, exploring); experience (XP) raises the player level, which
-- unlocks bigger builds and gives skill points. Pure numbers; the rules live in BaseBuild.luau.
-- Build ids: "habitat" (the main module; the lander is the only shelter until it stands), "solar"
-- (level = solar arrays standing, 1 to POWER.ARRAYS), "greenhouse" (2 = second dome), "lab" (skills,
-- tool upgrades, pets), "antenna" (2 = bigger dish, 3 = laser link), "shelter", "drill_1".."drill_3"
-- (automatic ice drills; each needs one more solar array: machines need electricity), "cargo_bot"
-- (carries silo ice for you), "garage" (1 = moon buggy bay, 2 = ice hauler bay), "landing_pad",
-- "ship" (a ship for the future trip to Mars: decoration and the long-term goal).
-- costs[i] / minLevel[i] = credits and player level for level i of that build.
-- Building happens in STEPS (Stage 7, team feedback: not all at once). Paying starts the level; each
-- step needs one parts crate carried from the lander cargo bay to the build pad, then the player
-- holds "Assemble" with the wrench tool in hand. The structure rises a bit with every step.
MissionData.BASE = table.freeze({
	START_CREDITS = 25,
	BUILDS = table.freeze({
		table.freeze({ id = "habitat", icon = "home", maxLevel = 1, costs = table.freeze({ 0 }), minLevel = table.freeze({ 1 }), requires = table.freeze({}) }),
		table.freeze({ id = "solar", icon = "solar", maxLevel = 3, costs = table.freeze({ 0, 30, 60 }), minLevel = table.freeze({ 1, 2, 3 }), requires = table.freeze({ habitat = 1 }) }),
		table.freeze({ id = "greenhouse", icon = "plant", maxLevel = 2, costs = table.freeze({ 15, 120 }), minLevel = table.freeze({ 1, 4 }), requires = table.freeze({ solar = 1 }) }),
		table.freeze({ id = "lab", icon = "flask", maxLevel = 1, costs = table.freeze({ 40 }), minLevel = table.freeze({ 2 }), requires = table.freeze({ habitat = 1, solar = 1 }) }),
		table.freeze({ id = "antenna", icon = "antenna", maxLevel = 3, costs = table.freeze({ 20, 90, 200 }), minLevel = table.freeze({ 1, 4, 6 }), requires = table.freeze({ solar = 1 }) }),
		table.freeze({ id = "shelter", icon = "shield", maxLevel = 1, costs = table.freeze({ 40 }), minLevel = table.freeze({ 1 }), requires = table.freeze({ antenna = 1 }) }),
		table.freeze({ id = "drill_1", icon = "drill", maxLevel = 3, costs = table.freeze({ 60, 120, 240 }), minLevel = table.freeze({ 2, 3, 5 }), requires = table.freeze({ shelter = 1, solar = 1 }) }),
		table.freeze({ id = "drill_2", icon = "drill", maxLevel = 3, costs = table.freeze({ 150, 250, 400 }), minLevel = table.freeze({ 4, 5, 7 }), requires = table.freeze({ drill_1 = 1, solar = 2 }) }),
		table.freeze({ id = "drill_3", icon = "drill", maxLevel = 3, costs = table.freeze({ 300, 450, 650 }), minLevel = table.freeze({ 6, 7, 9 }), requires = table.freeze({ drill_2 = 1, solar = 3 }) }),
		table.freeze({ id = "cargo_bot", icon = "robot", maxLevel = 1, costs = table.freeze({ 250 }), minLevel = table.freeze({ 5 }), requires = table.freeze({ drill_1 = 1 }) }),
		table.freeze({ id = "garage", icon = "car", maxLevel = 2, costs = table.freeze({ 120, 220 }), minLevel = table.freeze({ 3, 5 }), requires = table.freeze({ lab = 1, shelter = 1 }) }),
		table.freeze({ id = "landing_pad", icon = "flag", maxLevel = 1, costs = table.freeze({ 300 }), minLevel = table.freeze({ 6 }), requires = table.freeze({ garage = 1 }) }),
		table.freeze({ id = "ship", icon = "rocket", maxLevel = 1, costs = table.freeze({ 800 }), minLevel = table.freeze({ 8 }), requires = table.freeze({ landing_pad = 1 }) }),
	}),
	-- Steps per build level: STAGES_FIRST for a new structure, STAGES_UPGRADE for an upgrade, unless
	-- STAGES_BY_ID says otherwise (the habitat and first panels are quick; the ship is a big project).
	STAGES_FIRST = 3,
	STAGES_UPGRADE = 2,
	STAGES_BY_ID = table.freeze({ habitat = 2, solar = 2, ship = 6 }),
	ASSEMBLE_HOLD_SECONDS = 2.5,
	-- Rewards: credits and XP for each kind of work (counted for the player who did it).
	REWARDS = table.freeze({
		ice_delivered = table.freeze({ credits = 5, xp = 8 }),
		panel_cleaned = table.freeze({ credits = 2, xp = 4 }),
		antenna_aligned = table.freeze({ credits = 3, xp = 4 }),
		leak_repaired = table.freeze({ credits = 5, xp = 8 }),
		day_finished = table.freeze({ credits = 5, xp = 10 }), -- every player present
		star = table.freeze({ credits = 5, xp = 5 }), -- per star in the report, every player present
		mission_first = table.freeze({ credits = 20, xp = 30 }), -- first time a mission is completed
		mission_repeat = table.freeze({ credits = 5, xp = 10 }),
		collectible = table.freeze({ credits = 10, xp = 20 }), -- first time only
		crate_delivered = table.freeze({ credits = 0, xp = 2 }),
		stage_done = table.freeze({ credits = 0, xp = 5 }),
		food_eaten = table.freeze({ credits = 0, xp = 3 }),
		poi_scanned = table.freeze({ credits = 10, xp = 20 }), -- first scan of each exploration site
		meteor_scanned = table.freeze({ credits = 15, xp = 25 }),
	}),
	BUILD_XP_BASE = 10, -- XP for finishing any build level ...
	BUILD_XP_PER_CREDIT = 0.25, -- ... plus a quarter of its cost (rounded down)
	-- Automatic drills fill the ice silo while at least one player is in the server.
	DRILL_ICE_PER_MINUTE = table.freeze({ 2, 4, 7 }), -- per drill, by drill level
	SILO_MAX = 40,
	CREDITS_PER_SILO_ICE = 2,
	XP_PER_SILO_ICE = 1,
	CARGO_BOT_SECONDS = 30, -- the cargo robot empties the silo for its owner this often
	-- Player level i needs LEVEL_XP[i] total XP. Each level above 1 gives one skill point.
	LEVEL_XP = table.freeze({ 0, 40, 100, 180, 280, 400, 550, 730, 940, 1200, 1500, 1850, 2250, 2700, 3200 }),
	-- Skills (learned at the Lab): each level costs one skill point and needs the player level in minLevel.
	SKILLS = table.freeze({
		table.freeze({ id = "speed", icon = "run", maxLevel = 3, minLevel = table.freeze({ 2, 4, 6 }) }),
		table.freeze({ id = "tank", icon = "lungs", maxLevel = 3, minLevel = table.freeze({ 2, 4, 6 }) }),
		table.freeze({ id = "jump", icon = "rocket", maxLevel = 3, minLevel = table.freeze({ 3, 5, 7 }) }),
	}),
	SPEED_BONUS_PER_LEVEL = 1.5, -- studs/s added to walking and running (and the running threshold)
	TANK_BONUS_PER_LEVEL = 25, -- suit air added to SUIT.MAX
	JUMP_POWER_BONUS = table.freeze({ 0, 4, 8 }), -- by jump level; level 1 already gives a double jump
	DOUBLE_JUMP_FRACTION = 0.8, -- the second jump (a backpack gas puff) is 80% of a normal jump
	-- Tools the player carries (Roblox Tools in the backpack bar). A task needs its tool IN HAND:
	-- no drill, no ice (team feedback). unlock = build id that must stand (nil = from the start).
	-- wrench: assemble build steps; drill: crater ice; brush: dusty panels; repair_kit: leaks;
	-- tablet: align the antenna, scan exploration sites and meteorite craters; food: from the greenhouse.
	TOOLS = table.freeze({
		table.freeze({ id = "wrench", icon = "failure" }),
		table.freeze({ id = "drill", icon = "drill" }),
		table.freeze({ id = "brush", icon = "brush", unlock = "solar" }),
		table.freeze({ id = "repair_kit", icon = "repairKit", unlock = "habitat" }),
		table.freeze({ id = "tablet", icon = "tablet", unlock = "antenna" }),
		table.freeze({ id = "food", icon = "food", unlock = "greenhouse", consumable = true }),
	}),
	-- Tool upgrades bought at the Lab with credits (level 1 comes with the tool).
	TOOL_UPGRADES = table.freeze({
		drill = table.freeze({ maxLevel = 3, costs = table.freeze({ 0, 80, 160 }), minLevel = table.freeze({ 1, 3, 5 }), holdFactor = table.freeze({ 1, 0.7, 0.5 }) }),
	}),
	-- Fresh food from the greenhouse: pick one every COOLDOWN_SECONDS, eat it for a short speed boost.
	FOOD = table.freeze({ COOLDOWN_SECONDS = 90, BOOST_SECONDS = 20, BOOST_SPEED = 4 }),
	-- Meteorite impacts (random event): a flash, a fresh small crater to scan with the tablet.
	METEOR = table.freeze({ MIN_SECONDS = 240, MAX_SECONDS = 420, LIFETIME_SECONDS = 300, RING_MIN = 120, RING_MAX = 420 }),
	-- Vehicles from the garage. cargo = ice cores the hauler carries.
	VEHICLES = table.freeze({
		table.freeze({ id = "buggy", garage = 1, maxSpeed = 45 }),
		table.freeze({ id = "hauler", garage = 2, maxSpeed = 32, cargo = 4 }),
	}),
	-- Pets that follow the player (cosmetic only). laika and cheese come from the hidden collectibles;
	-- rabbit and monkey (a space chimp) are adopted at the Lab with credits once the level is high enough.
	PETS = table.freeze({
		table.freeze({ id = "laika", collectible = "laika" }),
		table.freeze({ id = "cheese", collectible = "cheese" }),
		table.freeze({ id = "rabbit", cost = 120, minLevel = 3 }),
		table.freeze({ id = "monkey", cost = 200, minLevel = 5 }),
	}),
})

-- Event schedule (GAME). Days 1-2 are fixed for onboarding; days 3-7 are shuffled on replay.
MissionData.EVENTS = table.freeze({
	FIXED = table.freeze({ "None", "None" }),
	SHUFFLED = table.freeze({ "Dust", "SolarStorm", "EquipmentFailure", "SolarStorm", "Dust" }),
	DUST_ARRAYS_COVERED = 1,
})

return table.freeze(MissionData)
