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
	-- A whole particle storm spent outside the shelter. Stage 10 fix: counted second by second while
	-- the particles are here (half the storm outside = half of this), crew average like the meter.
	DOSE_PER_EXPOSED_ASTRONAUT = 22,
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
	-- Riding a vehicle: the astronaut sits still, so the suit uses the resting rate, however fast the
	-- vehicle goes (Stage 10 playtest: speed alone used to count as running).
	DRAIN_SEATED_PER_SECOND = 0.5,
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
	-- Stage 10 fix (live playtest: storms came "very, very often"). The storm drill (training) runs
	-- again when nobody stayed safe, but only after this many quiet seconds since the last one ended,
	-- and at most MAX_DRILLS times in one shift. After that the day can end. Story days have one
	-- storm for the whole crew (never one per player).
	RETRY_GAP_SECONDS = 45,
	MAX_DRILLS = 3,
	-- C.A.R.L. reminds a player standing outside during a particle storm at most this often.
	OUTSIDE_REMINDER_SECONDS = 8,
})

-- Build and grow the base (GAME, Stages 6-9). A new player lands in the arrival lander (the spawn)
-- and builds the whole base: the habitat first, then everything else. Credits come from useful work
-- (ice, repairs, days finished, data sent, exploring, quests); experience (XP) raises the player
-- level, which gives skill points and opens skills, gear and pets. Pure numbers; the rules live in
-- BaseBuild.luau.
--
-- Stage 9 (team feedback): the HABITAT is the "town hall". Its level (1 to 5) is the BASE LEVEL, and
-- every level of every structure needs a minimum habitat level (hab[i] for level i). The player level
-- no longer gates structures. The tree below is the design; tests/base and tests/economy check it.
--
--   Habitat | Name             | Opens (new structure levels)                     | What changes vs. before
--   --------+------------------+--------------------------------------------------+---------------------------------------------
--   1       | Landing camp     | solar 1-3, greenhouse 1, antenna 1, shelter 1    | everything one mission day needs: power
--           | (free)           |                                                  | cells, food, a radio link, a storm shelter
--   2       | Science outpost  | lab, drill_1 L1 (+ the ice silo), greenhouse 2   | skills, tool upgrades, gear and pets; the
--           |                  |                                                  | first automatic ice; dome 2 grows food faster
--   3       | Mining base      | drill_1 L2, drill_2 L1, cargo_bot, garage 1,     | more ice per minute, the robot empties the
--           |                  | antenna 2                                        | silo for you, the moon buggy, bigger dish
--   4       | Explorer base    | drill_1 L3, drill_2 L2, drill_3 L1, garage 2,    | the ice hauler (4 cores a trip), laser link,
--           |                  | antenna 3, landing_pad                           | a pad for ships; the silo grows again
--   5       | Moon spaceport   | drill_2 L3, drill_3 L2-3, ship                   | the Mars ship (the long goal); biggest silo
--
-- Per-level effects (data below, read through BaseBuild):
--   habitat  : the base level itself (gates the table above) and the silo size, SILO_MAX_BY_HABITAT.
--   solar    : level = solar arrays standing = power cells on the board (POWER.ARRAYS).
--   greenhouse: 2 = second dome; fresh food grows faster, FOOD.COOLDOWN_BY_GREENHOUSE.
--   antenna  : 2 = bigger dish, 3 = laser link; a wider link sends more data, so aligning it pays
--              ANTENNA_ALIGN_BONUS extra credits (by antenna level).
--   drill_n  : ice per minute into the silo, DRILL_ICE_PER_MINUTE (by drill level).
--   cargo_bot: empties the silo for its owner every CARGO_BOT_SECONDS.
--   garage   : 1 = moon buggy bay, 2 = ice hauler bay (VEHICLES).
--   lab, shelter, landing_pad, ship: one level each (lab = skills/gear/pets; pad = needed for the ship).
-- Build ids: "habitat" (the main module; the lander is the only shelter until it stands), "solar"
-- (level = solar arrays standing, 1 to POWER.ARRAYS), "greenhouse" (2 = second dome), "lab" (skills,
-- tool upgrades, pets), "antenna" (2 = bigger dish, 3 = laser link), "shelter", "drill_1".."drill_3"
-- (automatic ice drills; each needs one more solar array: machines need electricity), "cargo_bot"
-- (carries silo ice for you), "garage" (1 = moon buggy bay, 2 = ice hauler bay), "landing_pad",
-- "ship" (a ship for the future trip to Mars: decoration and the long-term goal).
-- costs[i] / hab[i] = credits and habitat level (base level) needed for level i of that build.
-- requires = other builds that must stand (any level of this build). Habitat level i needs habitat i-1.
-- Costs are tuned with tests/economy (a simulated kid player): habitat 2 in about 7 minutes, the Lab
-- in about 15, habitat 3 in about 35, habitat 4 in about 90, habitat 5 in about 3 hours and the ship
-- in about 4 hours of play, with income growing step by step (never a jump that skips a tier).
-- Building happens in STEPS (Stage 7, team feedback: not all at once). Paying starts the level; each
-- step needs one parts crate carried from the lander cargo bay to the build pad, then the player
-- holds "Assemble" with the wrench tool in hand. The structure rises a bit with every step.
MissionData.BASE = table.freeze({
	START_CREDITS = 25,
	BUILDS = table.freeze({
		table.freeze({ id = "habitat", icon = "home", maxLevel = 5, costs = table.freeze({ 0, 15, 60, 300, 800 }), hab = table.freeze({ 0, 1, 2, 3, 4 }), requires = table.freeze({}) }),
		table.freeze({ id = "solar", icon = "solar", maxLevel = 3, costs = table.freeze({ 0, 25, 35 }), hab = table.freeze({ 1, 1, 1 }), requires = table.freeze({ habitat = 1 }) }),
		table.freeze({ id = "greenhouse", icon = "plant", maxLevel = 2, costs = table.freeze({ 10, 50 }), hab = table.freeze({ 1, 2 }), requires = table.freeze({ solar = 1 }) }),
		table.freeze({ id = "lab", icon = "flask", maxLevel = 1, costs = table.freeze({ 30 }), hab = table.freeze({ 2 }), requires = table.freeze({ habitat = 1, solar = 1 }) }),
		table.freeze({ id = "antenna", icon = "antenna", maxLevel = 3, costs = table.freeze({ 10, 90, 200 }), hab = table.freeze({ 1, 3, 4 }), requires = table.freeze({ solar = 1 }) }),
		table.freeze({ id = "shelter", icon = "shield", maxLevel = 1, costs = table.freeze({ 15 }), hab = table.freeze({ 1 }), requires = table.freeze({ antenna = 1 }) }),
		table.freeze({ id = "drill_1", icon = "drill", maxLevel = 3, costs = table.freeze({ 40, 100, 220 }), hab = table.freeze({ 2, 3, 4 }), requires = table.freeze({ shelter = 1, solar = 1 }) }),
		table.freeze({ id = "drill_2", icon = "drill", maxLevel = 3, costs = table.freeze({ 120, 200, 350 }), hab = table.freeze({ 3, 4, 5 }), requires = table.freeze({ drill_1 = 1, solar = 2 }) }),
		table.freeze({ id = "drill_3", icon = "drill", maxLevel = 3, costs = table.freeze({ 250, 400, 500 }), hab = table.freeze({ 4, 5, 5 }), requires = table.freeze({ drill_2 = 1, solar = 3 }) }),
		table.freeze({ id = "cargo_bot", icon = "robot", maxLevel = 1, costs = table.freeze({ 140 }), hab = table.freeze({ 3 }), requires = table.freeze({ drill_1 = 1 }) }),
		table.freeze({ id = "garage", icon = "car", maxLevel = 2, costs = table.freeze({ 90, 220 }), hab = table.freeze({ 3, 4 }), requires = table.freeze({ lab = 1, shelter = 1 }) }),
		table.freeze({ id = "landing_pad", icon = "flag", maxLevel = 1, costs = table.freeze({ 300 }), hab = table.freeze({ 4 }), requires = table.freeze({ garage = 1, antenna = 2 }) }),
		table.freeze({ id = "ship", icon = "rocket", maxLevel = 1, costs = table.freeze({ 1000 }), hab = table.freeze({ 5 }), requires = table.freeze({ landing_pad = 1 }) }),
	}),
	-- Steps per build level: STAGES_FIRST for a new structure, STAGES_UPGRADE for an upgrade, unless
	-- STAGES_BY_ID (level 1; the ship: every level) or STAGES_UPGRADE_BY_ID (levels 2+) say otherwise:
	-- the habitat and first panels are quick, a habitat upgrade (a new base level) and the ship are big.
	STAGES_FIRST = 3,
	STAGES_UPGRADE = 2,
	STAGES_BY_ID = table.freeze({ habitat = 2, solar = 2, ship = 6 }),
	STAGES_UPGRADE_BY_ID = table.freeze({ habitat = 4 }),
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
	-- Automatic drills fill the ice silo while at least one player is in the server. Silo ice pays
	-- less than ice carried by hand (REWARDS.ice_delivered): the drills help, but playing matters
	-- most, so waiting in the server never unlocks the base (tests/economy caps it per base level).
	DRILL_ICE_PER_MINUTE = table.freeze({ 1, 2, 3 }), -- per drill, by drill level
	-- The silo holds SILO_MAX_BY_HABITAT[habitat level] ice (BaseBuild.siloMax); a bigger base has a
	-- bigger silo. SILO_MAX is the biggest one (habitat 5), kept for older readers.
	SILO_MAX = 60,
	SILO_MAX_BY_HABITAT = table.freeze({ 20, 20, 30, 45, 60 }),
	CREDITS_PER_SILO_ICE = 1,
	XP_PER_SILO_ICE = 1,
	CARGO_BOT_SECONDS = 60, -- the cargo robot empties the silo for its owner this often
	-- Extra credits on top of REWARDS.antenna_aligned, by antenna level (BaseBuild.antennaBonus): the
	-- bigger dish and the laser link send more data each time they are linked.
	ANTENNA_ALIGN_BONUS = table.freeze({ 0, 3, 6 }),
	-- Player level i needs LEVEL_XP[i] total XP. Each level gives one skill point: at the top
	-- level a player has exactly enough points for every skill at its top level (team playtest).
	-- Stage 9: the upper levels need more XP, so the top level comes after about 2 hours, with the
	-- base growing alongside (tests/economy).
	LEVEL_XP = table.freeze({ 0, 40, 100, 180, 280, 400, 550, 750, 1000, 1350, 1800, 2400, 3100, 3900, 4800 }),
	-- Skills (learned at the Lab): each level costs one skill point and needs the player level in minLevel.
	-- Stage 8 (team feedback): the jump skill became the air boots (GEAR); three new skills took its place.
	-- speed: faster walking/running; tank: bigger suit air tank; credits: more credits from every reward;
	-- xp: more experience from every reward; builder: shorter "Assemble" hold at build pads.
	SKILLS = table.freeze({
		table.freeze({ id = "speed", icon = "run", maxLevel = 3, minLevel = table.freeze({ 2, 4, 6 }) }),
		table.freeze({ id = "tank", icon = "lungs", maxLevel = 3, minLevel = table.freeze({ 2, 4, 6 }) }),
		table.freeze({ id = "credits", icon = "coin", maxLevel = 3, minLevel = table.freeze({ 3, 6, 9 }) }),
		table.freeze({ id = "xp", icon = "xp", maxLevel = 3, minLevel = table.freeze({ 3, 6, 9 }) }),
		table.freeze({ id = "builder", icon = "build", maxLevel = 3, minLevel = table.freeze({ 2, 5, 8 }) }),
	}),
	SPEED_BONUS_PER_LEVEL = 1.5, -- studs/s added to walking and running (and the running threshold)
	TANK_BONUS_PER_LEVEL = 25, -- suit air added to SUIT.MAX
	-- credits / xp skills: each level adds this share of a reward, ROUNDED UP to a whole number, so a
	-- kid never sees decimals and every level adds at least 1 (BaseBuild.bonusAmount).
	REWARD_BONUS_PER_LEVEL = 0.1,
	BUILDER_HOLD_FACTOR = table.freeze({ 0.8, 0.65, 0.5 }), -- Assemble hold time, by builder level
	DOUBLE_JUMP_FRACTION = 0.8, -- the air boots' second jump is 80% of a normal jump
	-- Gear (Stage 8): accessories worn on the suit, bought and upgraded at the Lab, switched on and off
	-- with a key (not in the tool bar). Both run on compressed gas from one GAS tank (real: NASA's MMU
	-- and SAFER jetpacks fly with cold nitrogen gas jets). The tank refills inside pressurized modules.
	-- boots: a second jump in the air, gas puffing from the soles; jetpack: hold Jump in the air to fly.
	-- use[i] = gas per double jump (boots) or per second of thrust (jetpack) at gear level i (upgrades
	-- make it last longer). costs[i] / minLevel[i] for gear level i (level 1 = buying it).
	GEAR = table.freeze({
		table.freeze({ id = "boots", icon = "boots", key = "B", maxLevel = 3, costs = table.freeze({ 60, 100, 160 }), minLevel = table.freeze({ 3, 5, 7 }), use = table.freeze({ 25, 18, 12 }) }),
		table.freeze({ id = "jetpack", icon = "jetpack", key = "J", maxLevel = 3, costs = table.freeze({ 200, 300, 400 }), minLevel = table.freeze({ 8, 10, 12 }), use = table.freeze({ 30, 22, 15 }) }),
	}),
	GAS = table.freeze({
		MAX = 100,
		REFILL_PER_SECOND = 40, -- inside a pressurized module (habitat, tubes, greenhouse, lab, lander)
		JETPACK_ACCEL = 60, -- studs/s^2 of upward push while thrusting (Moon gravity is 32.4)
		JETPACK_MAX_RISE = 22, -- studs/s: the jetpack never climbs faster than this
	}),
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
		drill = table.freeze({ maxLevel = 3, costs = table.freeze({ 0, 60, 150 }), minLevel = table.freeze({ 1, 3, 5 }), holdFactor = table.freeze({ 1, 0.7, 0.5 }) }),
	}),
	-- Fresh food from the greenhouse: pick one every COOLDOWN_SECONDS, eat it for a short speed boost.
	-- Stage 9: COOLDOWN_BY_GREENHOUSE[greenhouse level] (BaseBuild.foodCooldown): the second dome grows
	-- more plants, so food is ready sooner. Plants still take time to grow.
	FOOD = table.freeze({ COOLDOWN_SECONDS = 90, COOLDOWN_BY_GREENHOUSE = table.freeze({ 90, 60 }), BOOST_SECONDS = 20, BOOST_SPEED = 4 }),
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
		table.freeze({ id = "monkey", cost = 200, minLevel = 7 }),
	}),
})

-- Event schedule (GAME). Days 1-2 are fixed for onboarding; days 3-7 are shuffled on replay.
MissionData.EVENTS = table.freeze({
	FIXED = table.freeze({ "None", "None" }),
	SHUFFLED = table.freeze({ "Dust", "SolarStorm", "EquipmentFailure", "SolarStorm", "Dust" }),
	DUST_ARRAYS_COVERED = 1,
})

return table.freeze(MissionData)
