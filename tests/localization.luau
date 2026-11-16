--!strict
-- Space Base Odyssey - localization tests. Run with: lune run tests/localization
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.
-- Fails if a key is missing in English or Spanish, a string has too many words (after removing
-- {placeholders}: 8 for gameplay text, 10 for "fact." and "src." lines on the Sources screen, 16
-- for "card.", "mission.", "story." cards, "funfact." lines and "poi.", "meteor.", "ach." facts),
-- placeholders differ between
-- languages, a string contains emoji or symbols outside Latin text, gameplay text uses technical
-- jargon, a fun fact repeats or quotes a number missing from DATA_SOURCES.md, a source file uses
-- an unknown key, or the API misbehaves.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Localization = require("../src/shared/Localization")

local MAX_WORDS = 8
-- Longer limits by key prefix: Sources screen lines, then mission and collectible cards.
local PREFIX_MAX_WORDS: { [string]: number } = {
	fact = 10,
	src = 10,
	card = 16,
	mission = 16,
	story = 16,
	funfact = 16,
	petfact = 16,
}

-- Stage 7: exploration site and meteorite facts ("poi.<id>.fact", "meteor.fact") are cards too.
-- Stage 10: learning achievement facts ("ach.<id>.fact") are one-sentence cards too.
local FACT_CARD_PREFIXES: { [string]: boolean } = { poi = true, meteor = true, ach = true }
local FACT_CARD_MAX_WORDS = 16

local function maxWords(key: string): number
	local prefix = string.match(key, "^([%a_]+)%.")
	if prefix and FACT_CARD_PREFIXES[prefix] and string.sub(key, -5) == ".fact" then
		return FACT_CARD_MAX_WORDS
	end
	if prefix and PREFIX_MAX_WORDS[prefix] then
		return PREFIX_MAX_WORDS[prefix]
	end
	return MAX_WORDS
end

-- The agreed key list with the placeholders each key must carry.
local EXPECTED: { [string]: { string } } = {
	["ui.title"] = {},
	["ui.pitch"] = {},
	["ui.start_mission"] = {},
	["ui.start_shift"] = {},
	["ui.day"] = { "day", "total" },
	["ui.power_left"] = { "n" },
	["ui.shift_time"] = { "seconds" },
	["ui.system.LifeSupport"] = {},
	["ui.system.Greenhouse"] = {},
	["ui.system.Science"] = {},
	["ui.system_hint.LifeSupport"] = {},
	["ui.system_hint.Greenhouse"] = {},
	["ui.system_hint.Science"] = {},
	["ui.meter.air"] = {},
	["ui.meter.food"] = {},
	["ui.meter.dose"] = {},
	["ui.meter.suit"] = {},
	["ui.carrying_ice"] = {},
	["ui.run"] = {},
	["ui.stars"] = { "n" },
	["ui.restart"] = {},
	["ui.report_title"] = {},
	["ui.language"] = {},
	["ui.storm_in"] = { "seconds" },
	["ui.storm_now"] = {},
	["ui.assistant_name"] = {},
	["ui.outcome.Completed"] = {},
	["ui.outcome.EarlyReturnAir"] = {},
	["ui.outcome.EarlyReturnFood"] = {},
	["ui.outcome.EarlyReturnDose"] = {},
	["ui.outcome.InProgress"] = {},
	["ui.sources_button"] = {},
	["ui.sources_title"] = {},
	["ui.close"] = {},
	["ui.weather_live"] = { "n" },
	["ui.weather_latest"] = { "class", "date" },
	["ui.weather_offline"] = {},
	["ui.weather_archive"] = { "date" },
	["ui.weather_checked"] = { "time" },
	["ui.flare_source_live"] = { "date" },
	["ui.flare_source_archive"] = { "date" },
	["ui.earth_link_on"] = {},
	["ui.earth_link_off"] = {},
	["event.None"] = {},
	["event.Dust"] = {},
	["event.SolarStorm"] = {},
	["event.EquipmentFailure"] = {},
	["carl.welcome"] = {},
	["carl.plan_hint"] = {},
	["carl.shift_start"] = {},
	["carl.dust"] = {},
	["carl.leak"] = {},
	["carl.leak_fixed"] = {},
	["carl.panel_clean"] = {},
	["carl.antenna_linked"] = {},
	["carl.earth_delay"] = { "moon", "mars" },
	["carl.storm_warning"] = { "class", "date" },
	["carl.storm_now"] = {},
	["carl.storm_over"] = {},
	-- Stage 10 fix: storms and radiation.
	["carl.storm_outside"] = {},
	["carl.drill_again"] = {},
	["ui.storm_outside"] = {},
	["carl.false_alarm"] = { "class", "date" },
	["carl.suit_low"] = {},
	["carl.rescued"] = {},
	["carl.ice_picked"] = {},
	["carl.ice_delivered"] = {},
	["carl.shift_over"] = {},
	["cause.dose_limit"] = {},
	["cause.air_empty"] = {},
	["cause.food_empty"] = {},
	["cause.storm_exposed"] = {},
	["cause.storm_sheltered"] = {},
	["cause.false_alarm"] = {},
	["cause.leak_unrepaired"] = {},
	["cause.dusty_panels"] = {},
	["cause.no_greenhouse"] = {},
	["cause.air_falling"] = {},
	["cause.ice_delivered"] = {},
	["cause.big_science"] = {},
	["cause.smooth_day"] = {},
	["error.unknown_system"] = {},
	["error.cells_range"] = {},
	["error.no_power_left"] = {},
	["prompt.clean"] = {},
	["prompt.drill"] = {},
	["prompt.deliver"] = {},
	["prompt.repair"] = {},
	["prompt.antenna"] = {},
	["prompt.console"] = {},
	["tip.day1_plan"] = {},
	["tip.day1_science"] = {},
	["tip.greenhouse_tomorrow"] = {},
	["tip.day1_shift"] = {},
	["tip.find_ice"] = {},
	["tip.antenna"] = {},
	["tip.day2_greenhouse"] = {},
	["tip.storm_follow"] = {},
	["tip.suit_home"] = {},
	["marker.task"] = {},
	["fact.gravity"] = { "percent" },
	["fact.light_delay"] = { "moon" },
	["fact.mars_delay"] = { "min", "max" },
	["fact.oxygen"] = { "kg" },
	["fact.water"] = { "kg" },
	["fact.food"] = { "kcal" },
	["fact.lettuce"] = { "days" },
	["fact.dose_moon"] = { "msv" },
	["fact.dose_earth"] = { "msv" },
	["fact.shelter"] = {},
	["fact.sep"] = { "min" },
	["fact.sunlight"] = { "days" },
	["fact.cold"] = { "k" },
	["fact.ice"] = { "percent" },
	["fact.flare_vs_storm"] = {},
	["fact.career_limit"] = { "msv" },
	["fact.sky_sun"] = { "days" },
	["fact.sky_earth"] = {},
	["src.donki"] = {},
	["src.bvad"] = {},
	["src.lro"] = {},
	["src.lcross"] = {},
	["src.veggie"] = {},
	["src.change4"] = {},
	["src.nasa_std"] = {},
	["src.nasa_science"] = {},
	["src.epa"] = {},
	["src.list"] = {},
	-- Stage 4: missions, objectives, mission select, collection and secrets.
	["mission.t1_steps.title"] = {},
	["mission.t1_steps.intro"] = {},
	["mission.t1_steps.outro"] = {},
	["mission.t2_power.title"] = {},
	["mission.t2_power.intro"] = {},
	["mission.t2_power.outro"] = {},
	["mission.t3_tasks.title"] = {},
	["mission.t3_tasks.intro"] = {},
	["mission.t3_tasks.outro"] = {},
	["mission.t4_storm.title"] = {},
	["mission.t4_storm.intro"] = {},
	["mission.t4_storm.outro"] = {},
	["mission.c1_arrival.title"] = {},
	["mission.c1_arrival.intro"] = {},
	["mission.c1_arrival.outro"] = {},
	["mission.c2_storm.title"] = {},
	["mission.c2_storm.intro"] = {},
	["mission.c2_storm.outro"] = {},
	["mission.c3_failure.title"] = {},
	["mission.c3_failure.intro"] = {},
	["mission.c3_failure.outro"] = {},
	["mission.free_play.title"] = {},
	["mission.free_play.intro"] = {},
	["mission.free_play.outro"] = {},
	["obj.go_outside"] = {},
	["obj.return_inside"] = {},
	["obj.set_power"] = {},
	["obj.start_shift"] = {},
	["obj.clean_panel"] = {},
	["obj.drill_ice"] = {},
	["obj.deliver_ice"] = {},
	["obj.align_antenna"] = {},
	["obj.repair_leak"] = {},
	["obj.reach_shelter"] = {},
	["obj.survive_storm"] = {},
	["obj.finish_day"] = {},
	["obj.complete_days"] = { "n" },
	["obj.deliver_ice_total"] = { "n" },
	["obj.stars_at_least"] = { "n" },
	["ui.missions_title"] = {},
	["ui.training"] = {},
	["ui.story"] = {},
	["ui.free_play"] = {},
	["ui.locked"] = {},
	["ui.completed"] = {},
	["ui.start"] = {},
	["ui.continue"] = {},
	["ui.try_again"] = {},
	["ui.objectives"] = {},
	["ui.mission_success"] = {},
	["ui.mission_failed"] = {},
	["ui.missing"] = {},
	["ui.collection_button"] = {},
	["ui.collection_title"] = {},
	["ui.secrets_found"] = { "n", "total" },
	["ui.observatory_slot"] = {},
	["ui.observatory_locked"] = {},
	["ui.observatory_open"] = {},
	["ui.reward_label"] = {},
	["ui.new_find"] = {},
	["collect.mini_earth.name"] = {},
	["collect.laika.name"] = {},
	["collect.cheese.name"] = {},
	["collect.mars_potato.name"] = {},
	["card.mini_earth.myth"] = {},
	["card.mini_earth.science"] = {},
	["card.mini_earth.reward"] = {},
	["card.laika.myth"] = {},
	["card.laika.science"] = {},
	["card.laika.reward"] = {},
	["card.cheese.myth"] = {},
	["card.cheese.science"] = {},
	["card.cheese.reward"] = {},
	["card.mars_potato.myth"] = {},
	["card.mars_potato.science"] = {},
	["card.mars_potato.reward"] = {},
	["prompt.collect"] = {},
	["carl.secret_found"] = {},
	["carl.all_secrets"] = {},
	["observatory.teaser"] = {},
	["story.secrets_hint"] = {},
	-- Stage 5: settings, codes, water, antenna data, eclipse, meter hints, event cosmetic.
	["ui.settings"] = {},
	["ui.music_volume"] = {},
	["ui.effects_volume"] = {},
	["ui.funfacts_toggle"] = {},
	["ui.guidance_toggle"] = {},
	["ui.redeem_title"] = {},
	["ui.redeem_placeholder"] = {},
	["ui.redeem_button"] = {},
	["ui.on"] = {},
	["ui.off"] = {},
	["ui.meter.water"] = {},
	["ui.meter_hint.air"] = {},
	["ui.meter_hint.food"] = {},
	["ui.meter_hint.dose"] = {},
	["ui.meter_hint.water"] = {},
	["ui.data_waiting"] = { "n" },
	["carl.data_sent"] = { "n" },
	["carl.no_water"] = {},
	["carl.code_ok"] = {},
	["carl.code_used"] = {},
	["carl.code_bad"] = {},
	["carl.eclipse_start"] = {},
	["carl.eclipse_end"] = {},
	["cause.no_water"] = {},
	["cause.data_waiting"] = {},
	["cosmetic.explorer26.name"] = {},
	-- Stage 6: build and grow the base, skills, pets, wardrobe, C.A.R.L. rover.
	["base.why.unknown"] = {},
	["base.why.max"] = {},
	["base.why.requires"] = {},
	["base.why.level"] = {},
	["base.why.credits"] = {},
	["base.why.points"] = {},
	["base.why.owned"] = {},
	["base.why.collectible"] = {},
	["base.why.not_owned"] = {},
	["base.why.empty"] = {},
	["base.why.far"] = {},
	["base.why.wait"] = {},
	["carl.base.built_solar"] = {},
	["carl.base.built_greenhouse"] = {},
	["carl.base.built_antenna"] = {},
	["carl.base.built_shelter"] = {},
	["carl.base.built_drill_1"] = {},
	["carl.base.built_drill_2"] = {},
	["carl.base.built_drill_3"] = {},
	["carl.base.built_cargo_bot"] = {},
	["carl.base.upgraded"] = {"n"},
	["carl.base.level_up"] = {"n"},
	["carl.base.debug_all_built"] = {},
	["carl.base.skill_learned"] = {},
	["carl.base.pet_bought"] = {},
	["carl.base.silo_claimed"] = {"n"},
	["obj.build_solar"] = {},
	["obj.build_greenhouse"] = {},
	["obj.build_antenna"] = {},
	["obj.build_shelter"] = {},
	["ui.needs_build"] = {"name"},
	["carl.build_first.solar"] = {},
	["carl.build_first.greenhouse"] = {},
	["carl.build_first.antenna"] = {},
	["carl.build_first.shelter"] = {},
	["carl.build_first"] = {},
	["carl.ice_saved"] = {},
	["prompt.build"] = {"n"},
	["prompt.build_free"] = {},
	["prompt.upgrade"] = {"n"},
	["prompt.claim_silo"] = {},
	["ui.level"] = {"n"},
	["ui.top_wardrobe"] = {},
	["ui.top_missions"] = {},
	["ui.explore_base"] = {},
	["ui.base_hint"] = {},
	["tip.base_start"] = {},
	["tip.base_ice"] = {},
	["tip.build_solar"] = {},
	["tip.build_greenhouse"] = {},
	["tip.build_antenna"] = {},
	["tip.build_shelter"] = {},
	["panel.tab_skills"] = {},
	["panel.tab_pets"] = {},
	["panel.level"] = {"n"},
	["panel.xp"] = {"n", "max"},
	["panel.level_top"] = {},
	["panel.waiting"] = {},
	["panel.free"] = {},
	["panel.max"] = {},
	["panel.upgrade"] = {},
	["panel.learn"] = {},
	["panel.skill_points"] = {"n"},
	["panel.skill_hint"] = {},
	["panel.pets_hint"] = {},
	["panel.pet_secret"] = {},
	["panel.pet_price"] = {"n", "level"},
	["panel.use"] = {},
	["panel.in_use"] = {},
	["panel.owned"] = {},
	["panel.needs_level"] = {"n"},
	["panel.needs_credits"] = {"n"},
	["panel.needs_build"] = {"name"},
	["build.solar.name"] = {},
	["build.solar.desc"] = {},
	["build.greenhouse.name"] = {},
	["build.greenhouse.desc"] = {},
	["build.antenna.name"] = {},
	["build.antenna.desc"] = {},
	["build.shelter.name"] = {},
	["build.shelter.desc"] = {},
	["build.drill_1.name"] = {},
	["build.drill_1.desc"] = {},
	["build.drill_2.name"] = {},
	["build.drill_2.desc"] = {},
	["build.drill_3.name"] = {},
	["build.drill_3.desc"] = {},
	["build.cargo_bot.name"] = {},
	["build.cargo_bot.desc"] = {},
	["skill.speed.name"] = {},
	["skill.speed.desc"] = {"n"},
	["skill.tank.name"] = {},
	["skill.tank.desc"] = {"n"},
	["pet.laika.name"] = {},
	["pet.cheese.name"] = {},
	["pet.rabbit.name"] = {},
	["pet.monkey.name"] = {},
	["wardrobe.title"] = {},
	["wardrobe.hint"] = {},
	["wardrobe.slot.helmet"] = {},
	["wardrobe.slot.backpack"] = {},
	["wardrobe.slot.carl"] = {},
	["wardrobe.slot.pet"] = {},
	["wardrobe.item.helmet.standard"] = {},
	["wardrobe.item.helmet.explorer26"] = {},
	["wardrobe.item.backpack.standard"] = {},
	["wardrobe.item.backpack.laika"] = {},
	["wardrobe.item.carl.classic"] = {},
	["wardrobe.item.carl.earth"] = {},
	["wardrobe.item.pet.none"] = {},
	["wardrobe.wearing"] = {},
	["wardrobe.tap"] = {},
	["wardrobe.how_secret"] = {},
	["wardrobe.how_code"] = {},
	["wardrobe.how_buy"] = {},
	["petfact.laika"] = {},
	["petfact.cheese"] = {},
	["petfact.rabbit"] = {},
	["petfact.monkey"] = {},
	-- Stage 7: lander start, building in steps, tools, Lab, vehicles, exploration, meteorites.
	["prompt.pick_food"] = {},
	["prompt.lab"] = {},
	["prompt.scan"] = {},
	["prompt.take_crate"] = {},
	["prompt.deliver_crate"] = {"n", "m"},
	["prompt.assemble"] = {"n", "m"},
	["carl.base.build_started"] = {"n"},
	["carl.base.crate_taken"] = {},
	["carl.base.crate_delivered"] = {},
	["carl.base.step_done"] = {"n", "m"},
	["carl.base.need_crate"] = {},
	["carl.base.need_wrench"] = {},
	["carl.base.has_crate"] = {},
	["carl.base.hands_full"] = {},
	["carl.base.no_crate_needed"] = {},
	["carl.base.build_cancelled"] = {},
	["carl.base.tool_upgraded"] = {"n"},
	["carl.base.built_habitat"] = {},
	["carl.base.built_lab"] = {},
	["carl.base.built_garage"] = {},
	["carl.base.built_landing_pad"] = {},
	["carl.base.built_ship"] = {},
	["base.why.need_lab"] = {},
	["base.why.lab_far"] = {},
	["base.why.pad_far"] = {},
	["tool.wrench.name"] = {},
	["tool.drill.name"] = {},
	["tool.brush.name"] = {},
	["tool.repair_kit.name"] = {},
	["tool.tablet.name"] = {},
	["tool.food.name"] = {},
	["carl.tool.need_drill"] = {},
	["carl.tool.need_brush"] = {},
	["carl.tool.need_tablet"] = {},
	["carl.tool.need_repair_kit"] = {},
	["carl.tool.need_tablet_scan"] = {},
	["carl.tool.hands_full"] = {},
	["carl.tool.eat_inside"] = {},
	["carl.tool.food_eaten"] = {},
	["carl.tool.food_picked"] = {},
	["carl.tool.food_full"] = {},
	["carl.tool.food_growing"] = {},
	["obj.build_habitat"] = {},
	["carl.build_first.habitat"] = {},
	["carl.return_inside"] = {},
	["prompt.take_vehicle"] = {},
	["prompt.return_vehicle"] = {},
	["prompt.load_ice"] = {},
	["prompt.unload_ice"] = {},
	["ui.vehicle.buggy"] = {},
	["ui.vehicle.hauler"] = {},
	["ui.vehicle.speed"] = {},
	["ui.vehicle.cargo"] = {"n", "max"},
	["ui.vehicle.exit_key"] = {},
	["ui.vehicle.exit_touch"] = {},
	["ui.vehicle.exit_pad"] = {},
	["ui.vehicle.passenger"] = {},
	["carl.vehicle.busy"] = {},
	["carl.vehicle.returned"] = {},
	["carl.vehicle.righted"] = {},
	["carl.vehicle.need_ice"] = {},
	["carl.vehicle.full"] = {},
	["carl.vehicle.loaded"] = {"n", "max"},
	["carl.vehicle.unloaded"] = {"n"},
	["carl.vehicle.unload_later"] = {},
	["carl.vehicle.gone"] = {},
	["carl.meteor.hit"] = {},
	["carl.meteor.no_air"] = {},
	["carl.explore.all_sites"] = {},
	["tip.lander_start"] = {},
	["tip.build_habitat"] = {},
	["tip.take_crate"] = {},
	["tip.deliver_crate"] = {},
	["tip.use_wrench"] = {},
	["tip.tool_brush"] = {},
	["tip.tool_repair_kit"] = {},
	["tip.tool_tablet"] = {},
	["tip.tool_food"] = {},
	["tip.lab_built"] = {},
	["tip.garage_built"] = {},
	["tip.meteor_scan"] = {},
	["build.habitat.name"] = {},
	["build.habitat.desc"] = {},
	["build.lab.name"] = {},
	["build.lab.desc"] = {},
	["build.garage.name"] = {},
	["build.garage.desc"] = {},
	["build.landing_pad.name"] = {},
	["build.landing_pad.desc"] = {},
	["build.ship.name"] = {},
	["build.ship.desc"] = {},
	["panel.lab_title"] = {},
	["panel.lab_hint"] = {},
	["panel.tab_tools"] = {},
	["panel.tools_hint"] = {},
	["panel.tool_use.wrench"] = {},
	["panel.tool_use.drill"] = {},
	["panel.tool_use.brush"] = {},
	["panel.tool_use.repair_kit"] = {},
	["panel.tool_use.tablet"] = {},
	["panel.tool_use.food"] = {},
	["panel.tool_ready"] = {},
	["panel.tool_food"] = {},
	["panel.drill_effect"] = {"n"},
	["panel.adopt"] = {},
	["ui.carrying_parts"] = {},
	["ui.food_boost"] = {"seconds"},
	["ui.build_step"] = {"n", "max"},
	["ui.build_need_crate"] = {},
	["ui.build_need_deliver"] = {},
	["ui.build_need_assemble"] = {},
	["explore.new_site"] = {},
	["explore.new_meteor"] = {},
	["explore.kind_site"] = {},
	["explore.kind_meteor"] = {},
	["explore.reward"] = {"credits", "xp"},
	["explore.seen"] = {},
	["explore.count"] = {"n", "max"},
	["poi.old_lander.name"] = {},
	["poi.old_lander.fact"] = {},
	["poi.impact_crater.name"] = {},
	["poi.impact_crater.fact"] = {},
	["poi.boulder_tracks.name"] = {},
	["poi.boulder_tracks.fact"] = {},
	["poi.prospector_crash.name"] = {},
	["poi.prospector_crash.fact"] = {},
	["poi.sun_peak.name"] = {},
	["poi.sun_peak.fact"] = {},
	["meteor.name"] = {},
	["meteor.fact"] = {},
	-- Stage 8: gear, gas tank, auto-run, new skills.
	["ui.autorun"] = {},
	["ui.autorun_key"] = {},
	["tip.autorun"] = {},
	["tip.autorun_touch"] = {},
	["tip.gear_boots"] = {},
	["tip.gear_boots_touch"] = {},
	["tip.gear_jetpack"] = {},
	["tip.gear_jetpack_touch"] = {},
	["tip.gas_empty"] = {},
	["tip.gear_need_lab"] = {},
	["carl.base.gear_bought"] = {"k"},
	["carl.base.gear_upgraded"] = {"n"},
	["panel.tab_gear"] = {},
	["panel.gear_hint"] = {},
	["panel.gear_key"] = {"key"},
	["panel.gear_use_jump"] = {"n"},
	["panel.gear_use_fly"] = {"n"},
	["panel.gear_next"] = {"n"},
	["panel.buy"] = {},
	["panel.gear_on"] = {},
	["panel.gear_off"] = {},
	["gear.boots.name"] = {},
	["gear.boots.desc"] = {},
	["gear.jetpack.name"] = {},
	["gear.jetpack.desc"] = {},
	["skill.credits.name"] = {},
	["skill.credits.desc"] = {"n", "per"},
	["skill.xp.name"] = {},
	["skill.xp.desc"] = {"n", "per"},
	["skill.builder.name"] = {},
	["skill.builder.desc"] = {"n"},
	-- Stage 9: habitat tree, quests, save slots and the start menu.
	["base.why.habitat"] = {},
	["base.why.habitat_n"] = {"n"},
	["prompt.need_habitat"] = {"n"},
	["prompt.missions"] = {},
	["ui.base_level"] = {"n"},
	["carl.base.habitat_up"] = {"n"},
	["habitat.tier.1.name"] = {},
	["habitat.tier.1.desc"] = {},
	["habitat.tier.2.name"] = {},
	["habitat.tier.2.desc"] = {},
	["habitat.tier.3.name"] = {},
	["habitat.tier.3.desc"] = {},
	["habitat.tier.4.name"] = {},
	["habitat.tier.4.desc"] = {},
	["habitat.tier.5.name"] = {},
	["habitat.tier.5.desc"] = {},
	["ui.quests"] = {},
	["ui.quest_main"] = {},
	["ui.quest_side"] = {},
	["ui.quest_done"] = {},
	["ui.quest_reward"] = {"credits", "xp"},
	["quest.main_done"] = {},
	["carl.quest.new"] = {},
	["carl.quest.done"] = {"credits", "xp"},
	["carl.quest.mission"] = {},
	["carl.quest.side"] = {},
	["carl.solo_here"] = {},
	["tip.quest_intro"] = {},
	["tip.mission_console"] = {},
	["tip.side_quest"] = {},
	["quest.m01_home.title"] = {},
	["quest.m01_home.step1"] = {},
	["quest.m01_home.step2"] = {},
	["quest.m01_home.step3"] = {},
	["quest.m02_food.title"] = {},
	["quest.m02_food.step1"] = {},
	["quest.m02_food.step2"] = {},
	["quest.m02_food.step3"] = {"n"},
	["quest.m03_earth.title"] = {},
	["quest.m03_earth.step1"] = {},
	["quest.m03_earth.step2"] = {},
	["quest.m03_earth.step3"] = {"n"},
	["quest.m04_storm.title"] = {},
	["quest.m04_storm.step1"] = {},
	["quest.m04_storm.step2"] = {},
	["quest.m05_ice.title"] = {},
	["quest.m05_ice.step1"] = {},
	["quest.m05_ice.step2"] = {"n"},
	["quest.m06_panels.title"] = {},
	["quest.m06_panels.step1"] = {},
	["quest.m06_panels.step2"] = {},
	["quest.m07_outpost.title"] = {},
	["quest.m07_outpost.step1"] = {"n"},
	["quest.m07_outpost.step2"] = {},
	["quest.m07_outpost.step3"] = {},
	["quest.m08_learn.title"] = {},
	["quest.m08_learn.step1"] = {"n"},
	["quest.m08_learn.step2"] = {"n"},
	["quest.m09_drills.title"] = {},
	["quest.m09_drills.step1"] = {},
	["quest.m09_drills.step2"] = {"n"},
	["quest.m10_storm.title"] = {},
	["quest.m10_storm.step1"] = {},
	["quest.m10_storm.step2"] = {},
	["quest.m11_explore.title"] = {},
	["quest.m11_explore.step1"] = {"n"},
	["quest.m11_explore.step2"] = {"n"},
	["quest.m12_garden.title"] = {},
	["quest.m12_garden.step1"] = {},
	["quest.m12_garden.step2"] = {},
	["quest.m12_garden.step3"] = {"n"},
	["quest.m13_mining.title"] = {},
	["quest.m13_mining.step1"] = {"n"},
	["quest.m13_mining.step2"] = {},
	["quest.m13_mining.step3"] = {},
	["quest.m14_wheels.title"] = {},
	["quest.m14_wheels.step1"] = {},
	["quest.m14_wheels.step2"] = {},
	["quest.m14_wheels.step3"] = {},
	["quest.m15_repair.title"] = {},
	["quest.m15_repair.step1"] = {},
	["quest.m15_repair.step2"] = {"n"},
	["quest.m16_gear.title"] = {},
	["quest.m16_gear.step1"] = {},
	["quest.m16_gear.step2"] = {"n"},
	["quest.m17_explorer.title"] = {},
	["quest.m17_explorer.step1"] = {"n"},
	["quest.m17_explorer.step2"] = {},
	["quest.m17_explorer.step3"] = {"n"},
	["quest.m18_laser.title"] = {},
	["quest.m18_laser.step1"] = {"n"},
	["quest.m18_laser.step2"] = {},
	["quest.m19_pad.title"] = {},
	["quest.m19_pad.step1"] = {},
	["quest.m19_pad.step2"] = {"n"},
	["quest.m20_spaceport.title"] = {},
	["quest.m20_spaceport.step1"] = {"n"},
	["quest.m20_spaceport.step2"] = {"n"},
	["quest.m21_mars.title"] = {},
	["quest.m21_mars.step1"] = {},
	["quest.s_treasure.title"] = {},
	["quest.s_treasure.step1"] = {"n"},
	["quest.s_ice_master.title"] = {},
	["quest.s_ice_master.step1"] = {"n"},
	["quest.s_ice_master.step2"] = {"n"},
	["quest.s_scientist.title"] = {},
	["quest.s_scientist.step1"] = {"n"},
	["quest.s_farmer.title"] = {},
	["quest.s_farmer.step1"] = {"n"},
	["quest.s_free_week.title"] = {},
	["quest.s_free_week.step1"] = {},
	["quest.s_jetpack.title"] = {},
	["quest.s_jetpack.step1"] = {},
	["quest.s_meteors.title"] = {},
	["quest.s_meteors.step1"] = {"n"},
	["quest.s_brain.title"] = {},
	["quest.s_brain.step1"] = {"n"},
	["quest.s_all_drills.title"] = {},
	["quest.s_all_drills.step1"] = {"n"},
	["quest.s_all_drills.step2"] = {"n"},
	["quest.s_all_drills.step3"] = {"n"},
	["ui.menu_new_game"] = {},
	["ui.menu_load_game"] = {},
	["ui.menu_credits"] = {},
	["ui.menu_loading"] = {},
	["ui.menu_world"] = {"n"},
	["ui.menu_pick_new"] = {},
	["ui.menu_pick_load"] = {},
	["ui.menu_empty"] = {},
	["ui.menu_empty_hint"] = {},
	["ui.menu_last_time"] = {},
	["ui.menu_saved_now"] = {},
	["ui.menu_saved_min"] = {"n"},
	["ui.menu_saved_hour"] = {},
	["ui.menu_saved_hours"] = {"n"},
	["ui.menu_saved_day"] = {},
	["ui.menu_saved_days"] = {"n"},
	["ui.menu_mode_solo"] = {},
	["ui.menu_mode_friends"] = {},
	["ui.menu_mode_title"] = {},
	["ui.menu_solo_desc"] = {},
	["ui.menu_friends_desc"] = {},
	["ui.menu_wipe_title"] = {},
	["ui.menu_wipe_text"] = {},
	["ui.menu_wipe_yes"] = {},
	["ui.menu_wipe_no"] = {},
	["ui.menu_wait"] = {},
	["ui.menu_wait_solo"] = {},
	["ui.menu_wait_fail"] = {},
	["ui.menu_back"] = {},
	["ui.menu_credits_team"] = {},
	["ui.menu_team_1"] = {},
	["ui.menu_team_2"] = {},
	["ui.menu_team_3"] = {},
	["ui.menu_team_4"] = {},
	["ui.menu_credits_event"] = {},
	["ui.menu_credits_data"] = {},
	["ui.menu_credit_earth"] = {},
	["ui.menu_credit_icons"] = {},
	["ui.menu_credit_sounds"] = {}, -- Stage 11 audio
	["ui.menu_credits_help"] = {},
	["ui.menu_credit_ai"] = {},
	["ui.menu_quest_badge"] = {},
	-- Stage 10: quest toasts.
	["ui.toast.quest_new"] = {},
	["ui.toast.side_new"] = {},
	["ui.toast.quest_done"] = {},
	["ui.toast.quest_already"] = {},
	["ui.toast.step_done"] = {"step"},
	["ui.toast.step_already"] = {"step"},
	["ui.toast.current"] = {},
	-- Stage 10: always-on vitals panel and the low air pill (Hud.luau).
	["ui.low_air"] = {},
	["ui.vitals.food"] = {},
	["ui.vitals.boost"] = {},
	["ui.vitals.ready"] = {},
	["ui.vitals.seconds"] = { "seconds" },
	["ui.vitals.silo"] = {},
	-- Stage 10: save feedback.
	["ui.save_done"] = {},
	["ui.save_test_only"] = {},
	["ui.save_failed"] = {},
	["ui.save_now"] = {},
	["ui.save_auto"] = {},
}

-- Stage 10 fix: private worlds (start menu Join a friend, world notices, C.A.R.L. in friends worlds).
for key, params in {
	["ui.menu_join_friend"] = {},
	["ui.menu_friends_title"] = {},
	["ui.menu_friends_loading"] = {},
	["ui.menu_friends_none"] = {},
	["ui.menu_friends_hint"] = {},
	["ui.menu_friends_error"] = {},
	["ui.menu_friends_refresh"] = {},
	["ui.menu_friend_players"] = { "m", "n" },
	["ui.menu_friend_full"] = {},
	["ui.menu_pick_join"] = {},
	["ui.menu_empty_join"] = {},
	["ui.menu_wait_join"] = {},
	["ui.menu_notice_host_left"] = {},
	["ui.menu_notice_private"] = {},
	["ui.menu_notice_full"] = {},
	["ui.menu_notice_closed"] = {},
	["ui.menu_notice_not_friend"] = {},
	["ui.world_kick"] = {},
	["carl.world.host_left"] = {},
	["carl.world.private"] = {},
	["carl.world.full"] = {},
	["carl.world.closed"] = {},
	["carl.world.not_friend"] = {},
	["carl.world.guest_welcome"] = { "name" },
	["carl.world.friend_joined"] = { "name" },
	["carl.world.friend_left"] = { "name" },
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Stage 10: learning achievements. Each achievement's title, hint and fact, with the placeholders its
-- hintParams / factParams fill (tests/achievements checks that those values exist in MissionData).
for key, params in {
	["ui.top_achievements"] = {},
	["ui.ach_title"] = {},
	["ui.ach_count"] = { "n", "total" },
	["ui.ach_hint"] = {},
	["ui.toast.achievement"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end
do
	local Achievements = require("../src/shared/Achievements")
	local function names(map: { [string]: string }?): { string }
		local list: { string } = {}
		for name in map or {} do
			table.insert(list, name)
		end
		return list
	end
	for _, def in Achievements.LIST do
		EXPECTED[Achievements.titleKey(def.id)] = {}
		EXPECTED[Achievements.hintKey(def.id)] = names(def.hintParams)
		EXPECTED[Achievements.factKey(def.id)] = names(def.factParams)
	end
end

-- Every notice a world can send back has its menu line and its C.A.R.L. line.
do
	local Worlds = require("../src/shared/Worlds")
	for notice in Worlds.NOTICES do
		assert(EXPECTED["ui.menu_notice_" .. notice] ~= nil, "no menu line for world notice " .. notice)
		assert(EXPECTED["carl.world." .. notice] ~= nil, "no C.A.R.L. line for world notice " .. notice)
	end
end

-- Stage 11 "safer server": C.A.R.L.'s lines for the server checks.
for key, params in {
	["carl.ice_wait"] = {},
	["carl.rescued_ice"] = {},
	["carl.dust_roam"] = {},
	["carl.drill_rest"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Stage 11 tycoon: the ice line's new lines (reworded older keys keep their entries).
for key, params in {
	["carl.base.silo_full"] = {},
	["carl.base.silo_bigger"] = { "n" },
	["carl.base.delivery_water"] = { "n" },
	["carl.base.delivery_oxygen"] = { "n" },
	["carl.base.air_no_power"] = {},
	["carl.base.away"] = { "n" },
	["base.why.not_your_silo"] = {},
	["ui.line.title"] = {},
	["ui.line.rate"] = { "n" },
	["ui.line.credits"] = { "n" },
	["ui.line.status_run"] = {},
	["ui.line.status_full"] = {},
	["ui.line.status_off"] = {},
	["ui.line.air_nopower"] = {},
	["ui.line.chain"] = {},
	["ui.line.away_title"] = {},
	["ui.line.away"] = { "n" },
	["ui.line.delivery"] = { "n" },
	["ui.line.water"] = {},
	["ui.line.air"] = {},
	["ui.line.robot_rest"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Stage 11 tycoon client: world signs, machine income, the "While you were away" card, silo tip.
for key, params in {
	["ui.line.ice"] = { "n", "max" },
	["ui.line.machines"] = { "n" },
	["ui.line.friend_silo"] = {},
	["ui.line.away_worth"] = { "n" },
	["ui.line.away_robot"] = {},
	["ui.line.away_silo"] = {},
	["ui.line.collect"] = {},
	["ui.line.ok"] = {},
	["carl.line.silo_upgrade"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Stage 11 "quests that teach". Quest step placeholders follow the step type: COUNTED steps have
-- no {n} (the tracker adds "0/4", so "Bring ice home: 4  0/4" cannot come back); build and tool
-- levels keep {n} = the level. Every main quest has a praise line; C.A.R.L. asks questions, the
-- Hidden treasures hints and the picture glossary are listed by their modules.
do
	local Quests = require("../src/shared/Quests")
	local Quiz = require("../src/shared/Quiz")
	local Glossary = require("../src/shared/Glossary")
	for _, quest in Quests.LIST do
		EXPECTED[Quests.titleKey(quest.id)] = {}
		for index, step in quest.steps do
			local levelled = (step.type == "build" or step.type == "tool_upgrade") and (step.level or 1) > 1
			EXPECTED[Quests.stepKey(quest.id, index)] = if levelled then { "n" } else {}
		end
		local praise = Quests.praiseKey(quest.id)
		if praise then
			EXPECTED[praise] = {}
		end
	end
	for _, id in Quests.TREASURE_ORDER do
		EXPECTED[Quests.treasureHintKey(id, 1)] = {}
		EXPECTED[Quests.treasureHintKey(id, 2)] = {}
	end
	for _, question in Quiz.LIST do
		EXPECTED[Quiz.questionKey(question.id)] = {}
		EXPECTED[Quiz.hintKey(question.id)] = {}
		EXPECTED[Quiz.whyKey(question.id)] = {}
		for index = 1, #question.answers do
			EXPECTED[Quiz.answerKey(question.id, index)] = {}
		end
	end
	for _, term in Glossary.LIST do
		EXPECTED[Glossary.wordKey(term.id)] = {}
		EXPECTED[Glossary.defKey(term.id)] = {}
	end
	for key, params in {
		["carl.quest.skill_build_lab"] = {},
		["carl.quest.skill_lab_ready"] = {},
		["carl.quest.skill_point"] = {},
		["carl.quest.break"] = {},
		["ui.quiz.title"] = {},
		["ui.quiz.later"] = {},
		["ui.quiz.right"] = { "xp" },
		["ui.quiz.try_again"] = {},
	} :: { [string]: { string } } do
		EXPECTED[key] = params
	end
end

-- Stage 11 menu: the start menu without "Load game" and the Settings "Helpers" page.
for key, params in {
	["ui.menu_worlds"] = {},
	["ui.menu_continue_none"] = {},
	["ui.menu_start_over"] = {},
	["ui.menu_choice_text"] = {},
	["ui.menu_wait_slow"] = {},
	["ui.menu_back_lobby"] = {},
	["ui.settings_tab_game"] = {},
	["ui.settings_tab_help"] = {},
	["ui.help_text"] = {},
	["ui.help_text_normal"] = {},
	["ui.help_text_big"] = {},
	["ui.help_text_hint"] = {},
	["ui.help_motion"] = {},
	["ui.help_motion_hint"] = {},
	["ui.help_speed"] = {},
	["ui.help_speed_normal"] = {},
	["ui.help_speed_long"] = {},
	["ui.help_speed_longer"] = {},
	["ui.help_speed_hint"] = {},
	["ui.help_colour"] = {},
	["ui.help_colour_hint"] = {},
	["ui.help_sample"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Stage 11 daily: the supply capsule card, suit stripe names (one per Daily.STRIPES), the Moon
-- Logbook and the cargo facts (one per Daily.CARGO_FACTS; tests/daily checks they quote no number).
do
	local Daily = require("../src/shared/Daily")
	for _, stripe in Daily.STRIPES do
		EXPECTED[Daily.stripeNameKey(stripe.id)] = {}
	end
	for _, key in Daily.CARGO_FACTS do
		EXPECTED[key] = {}
	end
	for key, params in {
		["ui.daily.title"] = {},
		["ui.daily.note"] = {},
		["ui.daily.week"] = { "n" },
		["ui.daily.day"] = { "n" },
		["ui.daily.open"] = {},
		["ui.daily.opened"] = {},
		["ui.daily.next_hours"] = { "n" },
		["ui.daily.next_minutes"] = { "n" },
		["ui.daily.forgiving"] = {},
		["ui.daily.fact_title"] = {},
		["ui.daily.credits"] = { "n" },
		["ui.daily.xp"] = { "n" },
		["ui.daily.stripes"] = {},
		["ui.daily.got_credits"] = { "n" },
		["ui.daily.got_xp"] = { "n" },
		["ui.daily.got_stripes"] = { "name" },
		["ui.daily.logbook"] = {},
		["prompt.daily_capsule"] = {},
		["carl.daily.landed"] = {},
		["ui.logbook.title"] = {},
		["ui.logbook.entries"] = { "n", "total" },
		["ui.logbook.tab_secrets"] = {},
		["ui.logbook.tab_sites"] = {},
		["ui.logbook.tab_rocks"] = {},
		["ui.logbook.tab_achievements"] = {},
		["ui.logbook.tab_facts"] = {},
		["ui.logbook.tab_stripes"] = {},
		["ui.logbook.locked"] = {},
		["ui.logbook.site_hint"] = {},
		["ui.logbook.rock"] = { "n" },
		["ui.logbook.rock_hint"] = {},
		["ui.logbook.facts_count"] = { "n" },
		["ui.logbook.facts_none"] = {},
		["ui.logbook.cargo"] = { "n" },
		["ui.logbook.milestone"] = { "n" },
		["ui.logbook.claim"] = {},
		["ui.logbook.claimed"] = {},
		["ui.logbook.wear"] = {},
		["ui.logbook.wearing"] = {},
		["ui.logbook.no_stripes"] = {},
		["ui.logbook.how_daily"] = {},
		["ui.logbook.how_logbook"] = {},
		["ui.logbook.calendar"] = {},
		["ui.logbook.capsules"] = { "n" },
		["carl.logbook.ready"] = {},
		["carl.logbook.milestone"] = {},
	} :: { [string]: { string } } do
		EXPECTED[key] = params
	end
end

-- Stage 11 readable UI: C.A.R.L.'s history, the big main-quest card, Achievements pages, the glossary
-- card and the extra glossary word forms (tests/reading checks that every form is found in text).
for key, params in {
	["ui.history.title"] = {},
	["ui.history.empty"] = {},
	["ui.toast.main_done"] = {},
	["ui.ach_page"] = { "n", "total" },
	["ui.glossary.title"] = {},
	["ui.glossary.tap"] = {},
	["glossary.parts_box.forms"] = {},
	["glossary.solar_panel.forms"] = {},
	["glossary.ice_crater.forms"] = {},
	["glossary.solar_flare.forms"] = {},
	["glossary.base_level.forms"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Stage 11 juice and world safety: C.A.R.L. at the map edge and the report timeline's header.
for key, params in {
	["carl.map_edge"] = {},
	["ui.report.cause_effect"] = {},
} :: { [string]: { string } } do
	EXPECTED[key] = params
end

-- Fun facts: "funfact.01" .. "funfact.NN" with N = Localization.FUNFACT_COUNT, no placeholders.
local MIN_FUNFACTS = 45
local funFactCount: number = Localization.FUNFACT_COUNT
for index = 1, funFactCount do
	EXPECTED[string.format("funfact.%02d", index)] = {}
end

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

-- Sorted, de-duplicated placeholder names in a string, joined by commas.
local function placeholders(text: string): string
	local seen: { [string]: boolean } = {}
	local names: { string } = {}
	for name in string.gmatch(text, "{([%w_]+)}") do
		if not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end
	table.sort(names)
	return table.concat(names, ",")
end

-- Words left after removing placeholders; tokens made only of punctuation do not count.
local function wordCount(text: string): number
	local stripped = string.gsub(text, "{[%w_]+}", " ")
	local count = 0
	for token in string.gmatch(stripped, "%S+") do
		if string.find(token, "%w") or string.find(token, "[\128-\255]") then
			count += 1
		end
	end
	return count
end

local function sortedJoin(list: { string }): string
	local copy = table.clone(list)
	table.sort(copy)
	return table.concat(copy, ",")
end

-- 1. KEYS matches the agreed list exactly, with no duplicates.
local inKeys: { [string]: boolean } = {}
for _, key in Localization.KEYS do
	check(not inKeys[key], "duplicate key in KEYS: " .. key)
	inKeys[key] = true
	check(EXPECTED[key] ~= nil, "KEYS has a key outside the agreed list: " .. key)
end
for key in EXPECTED do
	check(inKeys[key] == true, "KEYS is missing: " .. key)
end
check(table.isfrozen(Localization.KEYS), "KEYS is frozen")

-- 2. Every key exists in every language, nothing extra, within the word limit, same placeholders.
for _, lang in Localization.LANGUAGES do
	local strings = Localization.STRINGS[lang]
	for key, expectedParams in EXPECTED do
		local text = strings[key]
		check(type(text) == "string" and #text > 0, lang .. " is missing key: " .. key)
		if type(text) == "string" then
			local words = wordCount(text)
			check(
				words >= 1 and words <= maxWords(key),
				string.format("%s %s has %d words (max %d): %s", lang, key, words, maxWords(key), text)
			)
			check(
				placeholders(text) == sortedJoin(expectedParams),
				string.format("%s %s placeholders {%s} expected {%s}", lang, key, placeholders(text), sortedJoin(expectedParams))
			)
		end
	end
	for key in strings do
		check(EXPECTED[key] ~= nil, lang .. " has an unknown key: " .. key)
	end
end

for key in EXPECTED do
	local en = Localization.STRINGS.en[key]
	local es = Localization.STRINGS.es[key]
	if en and es then
		check(placeholders(en) == placeholders(es), "placeholders differ between en and es: " .. key)
	end
end

-- 2b. No emoji or pictographs: only Latin letters, digits and plain punctuation (the UI uses icons).
-- Allowed: ASCII plus Latin-1 and Latin Extended-A (accents, n with tilde, inverted marks).
for _, lang in Localization.LANGUAGES do
	for key, text in Localization.STRINGS[lang] do
		local ok, bad = true, 0
		for _, codepoint in utf8.codes(text) do
			if codepoint > 0x017F then
				ok, bad = false, codepoint
				break
			end
		end
		check(ok, string.format("%s %s has a non-Latin symbol U+%04X (no emoji): %s", lang, key, bad, text))
	end
end

-- 2c. Plain language: gameplay text avoids technical words. Only the Sources screen ("fact." and
-- "src.") may keep real terms such as millisieverts, kelvin or the BVAD document name.
local JARGON: { string } = {
	"allocation",
	"allocate",
	"telemetry",
	"sep",
	"mev",
	"dose",
	"life support",
	"life-support",
	"millisievert",
	"kelvin",
	"flare class",
	"asignación",
	"telemetría",
	"dosis",
	"soporte vital",
	"milisievert",
}

local function sourcesScreenKey(key: string): boolean
	return string.sub(key, 1, 5) == "fact." or string.sub(key, 1, 4) == "src."
end

for _, lang in Localization.LANGUAGES do
	for key, text in Localization.STRINGS[lang] do
		if not sourcesScreenKey(key) then
			local lower = string.lower(text)
			for _, word in JARGON do
				-- Whole words only: frontier patterns stop "sep" matching inside "separate".
				local pattern = "%f[%w]" .. string.gsub(word, "%-", "%%-") .. "%f[%W]"
				check(
					string.find(lower, pattern) == nil,
					string.format("%s %s uses the technical word '%s': %s", lang, key, word, text)
				)
			end
		end
	end
end

-- 2d. Fun facts: enough of them, the API matches, no line repeats, and every number they quote is
-- written somewhere in DATA_SOURCES.md (no invented numbers).
check(type(funFactCount) == "number" and funFactCount >= MIN_FUNFACTS, "at least 45 fun facts")
check(Localization.funFactKey(1) == "funfact.01", "funFactKey(1)")
check(Localization.funFactKey(funFactCount) == string.format("funfact.%02d", funFactCount), "funFactKey(last)")
check(Localization.STRINGS.en[string.format("funfact.%02d", funFactCount + 1)] == nil, "no fun fact past the count")

local dataSources = fs.readFile("DATA_SOURCES.md")
for _, lang in Localization.LANGUAGES do
	local seen: { [string]: string } = {}
	for index = 1, funFactCount do
		local key = string.format("funfact.%02d", index)
		local text = Localization.STRINGS[lang][key]
		if type(text) == "string" then
			check(seen[text] == nil, string.format("%s %s repeats %s", lang, key, seen[text] or ""))
			seen[text] = key
			for number in string.gmatch(text, "%d[%d,.]*") do
				local clean = string.gsub(number, "[,.]+$", "")
				check(
					string.find(dataSources, clean, 1, true) ~= nil,
					string.format("%s %s quotes %s, not found in DATA_SOURCES.md", lang, key, clean)
				)
			end
		end
	end
end

-- 2e. Stage 11: question cards and glossary cards quote no numbers (nothing can drift from
-- DATA_SOURCES.md), a glossary word is at most 3 words, counted quest steps never show the target in
-- the text, and the level-up line no longer promises a skill point before the Lab exists.
do
	for _, lang in Localization.LANGUAGES do
		for key, text in Localization.STRINGS[lang] do
			if string.sub(key, 1, 5) == "quiz." or string.sub(key, 1, 9) == "glossary." or string.sub(key, 1, 14) == "carl.treasure." then
				check(string.find(text, "%d") == nil, `{lang} {key} quotes no number: {text}`)
			end
			if string.sub(key, 1, 9) == "glossary." and string.sub(key, -5) == ".word" then
				check(wordCount(text) <= 3, `{lang} {key} is a short word: {text}`)
			end
		end
		check(
			string.find(string.lower(Localization.STRINGS[lang]["carl.base.level_up"]), "skill") == nil
				and string.find(string.lower(Localization.STRINGS[lang]["carl.base.level_up"]), "habilidad") == nil,
			`{lang} carl.base.level_up does not mention skill points`
		)
	end
	local Quests = require("../src/shared/Quests")
	for _, quest in Quests.LIST do
		for index, step in quest.steps do
			if Quests.isCounted(step.type) then
				local key = Quests.stepKey(quest.id, index)
				check(string.find(Localization.STRINGS.en[key] or "", "{n}", 1, true) == nil, `{key}: a counted step shows its target once (no n in the text)`)
			end
		end
	end
end

-- 3. Every full key quoted in the game source exists (scan src/ for quoted keys). Keys built at
-- run time from a quoted prefix ending in "." or "_" (for example "ui.system." .. name or
-- "carl.tool.need_" .. toolId) are skipped.
local KEY_PREFIXES = {
	"cause",
	"error",
	"event",
	"carl",
	"ui",
	"prompt",
	"fact",
	"src",
	"tip",
	"marker",
	"mission",
	"obj",
	"collect",
	"card",
	"story",
	"observatory",
	"cosmetic",
	"funfact",
	"base",
	"build",
	"skill",
	"pet",
	"petfact",
	"panel",
	"wardrobe",
	"tool",
	"poi",
	"meteor",
	"explore",
	"gear",
	"quest",
	"habitat",
	"ach",
}

local function luauFiles(dir: string, out: { string })
	if not fs.isDir(dir) then
		return
	end
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" and name ~= "Localization.luau" then
			table.insert(out, path)
		end
	end
end

local sourceFiles: { string } = {}
luauFiles("src", sourceFiles)
table.sort(sourceFiles)
check(table.find(sourceFiles, "src/shared/Simulation.luau") ~= nil, "source scan finds Simulation.luau")
for _, file in sourceFiles do
	-- Comments may name key patterns such as "funfact.NN"; only code counts.
	local source = string.gsub(fs.readFile(file), "%-%-[^\n]*", "")
	for quoted in string.gmatch(source, '"([%a_]+%.[%w_.]+)"') do
		local prefix = string.match(quoted, "^([%a_]+)%.")
		if prefix and table.find(KEY_PREFIXES, prefix) and string.sub(quoted, -1) ~= "." and string.sub(quoted, -1) ~= "_" then
			check(inKeys[quoted] == true, file .. " uses a key that is not localized: " .. quoted)
		end
	end
end

-- 3b. Keys the game builds at run time from data ids (they never appear quoted in full).
local MissionData = require("../src/shared/MissionData")
local DYNAMIC: { string } = {}
for _, def in MissionData.BASE.BUILDS do
	table.insert(DYNAMIC, "build." .. def.id .. ".name")
	table.insert(DYNAMIC, "build." .. def.id .. ".desc")
	table.insert(DYNAMIC, "carl.base.built_" .. def.id)
end
for _, def in MissionData.BASE.TOOLS do
	table.insert(DYNAMIC, "tool." .. def.id .. ".name")
	table.insert(DYNAMIC, "panel.tool_use." .. def.id)
end
for _, toolId in { "drill", "brush", "repair_kit", "tablet" } do
	table.insert(DYNAMIC, "carl.tool.need_" .. toolId)
end
for _, def in MissionData.BASE.SKILLS do
	table.insert(DYNAMIC, "skill." .. def.id .. ".name")
	table.insert(DYNAMIC, "skill." .. def.id .. ".desc")
end
for _, def in MissionData.BASE.PETS do
	table.insert(DYNAMIC, "pet." .. def.id .. ".name")
end
for _, def in MissionData.BASE.GEAR do
	table.insert(DYNAMIC, "gear." .. def.id .. ".name")
	table.insert(DYNAMIC, "gear." .. def.id .. ".desc")
end
for _, def in MissionData.BASE.VEHICLES do
	table.insert(DYNAMIC, "ui.vehicle." .. def.id)
end
for _, siteId in { "old_lander", "impact_crater", "boulder_tracks", "prospector_crash", "sun_peak" } do
	table.insert(DYNAMIC, "poi." .. siteId .. ".name")
	table.insert(DYNAMIC, "poi." .. siteId .. ".fact")
end
-- Stage 9: quest titles and steps, habitat tiers, build-gate reasons and the team credits.
local Quests = require("../src/shared/Quests")
for _, quest in Quests.LIST do
	table.insert(DYNAMIC, Quests.titleKey(quest.id))
	for index = 1, #quest.steps do
		table.insert(DYNAMIC, Quests.stepKey(quest.id, index))
	end
end
table.insert(DYNAMIC, Quests.FINALE_KEY)
for tier = 1, 5 do
	table.insert(DYNAMIC, `habitat.tier.{tier}.name`)
	table.insert(DYNAMIC, `habitat.tier.{tier}.desc`)
end
for _, reason in { "habitat", "habitat_n" } do
	table.insert(DYNAMIC, "base.why." .. reason)
end
for index = 1, 4 do
	table.insert(DYNAMIC, `ui.menu_team_{index}`)
end
for _, key in DYNAMIC do
	check(inKeys[key] == true, "dynamic key is not localized: " .. key)
end

-- 4. API behaviour.
check(Localization.t("ui.day", { day = 2, total = 5 }, "en") == "Day 2 of 5", "t fills placeholders (en)")
check(Localization.t("ui.day", { day = 2, total = 5 }, "es") == "Día 2 de 5", "t fills placeholders (es)")
check(Localization.t("ui.day", nil, "en") == "Day {day} of {total}", "t leaves placeholders without params")
check(Localization.t("ui.day", { day = 3 }, "en") == "Day 3 of {total}", "t keeps unknown placeholders")
check(Localization.t("ui.power_left", { n = "50%" }, "en") == "50% power left", "t inserts values literally")
check(Localization.t("no.such.key", nil, "es") == "no.such.key", "t falls back to the key")
check(
	Localization.t("carl.earth_delay", { moon = 1.3, mars = 22 }, "en")
		== "Signal to Earth: 1.3 seconds. Mars: up to 22 minutes!",
	"t fills carl.earth_delay"
)
check(
	Localization.t("fact.gravity", { percent = 16.5 }, "en") == "Moon gravity is only 16.5% of Earth's.",
	"t fills fact.gravity"
)
check(Localization.t("ui.run", nil, "fr" :: any) == Localization.t("ui.run"), "t ignores unknown languages")

check(Localization.detect("es-mx") == "es", "detect es-mx")
check(Localization.detect("es_ES") == "es", "detect es_ES")
check(Localization.detect("ES") == "es", "detect ES")
check(Localization.detect("en-us") == "en", "detect en-us")
check(Localization.detect("pt-br") == "en", "detect pt-br")
check(Localization.detect("") == "en", "detect empty")
check(Localization.detect(nil) == "en", "detect nil")

check(Localization.getLanguage() == "en", "default language is en")
Localization.setLanguage("es")
check(Localization.getLanguage() == "es", "setLanguage es")
check(Localization.t("ui.run") == "Correr", "t uses the current language")
Localization.setLanguage("xx" :: any)
check(Localization.getLanguage() == "es", "setLanguage ignores unknown languages")
Localization.setLanguage("en")
check(Localization.t("ui.run") == "Run", "t back to English")

print(string.format("localization: %d passed, %d failed", passes, failures))
if failures > 0 then
	process.exit(1)
end
