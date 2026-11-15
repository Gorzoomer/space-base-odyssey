--!strict
-- Space Base Odyssey - learning achievement tests (Stage 10). Run with: lune run tests/achievements
-- Checks src/shared/Achievements.luau: ids are unique, every icon exists in Icons.luau, every text key
-- is in English and Spanish, fact placeholders quote REAL values (present in DATA_SOURCES.md) and
-- hint placeholders GAME targets, missions and builds named by the rules exist, every achievement
-- has a badge entry, the unlock rules (lessons, counters, missions, base level, build, sites), and
-- that old saves load (no field = nothing unlocked) and merged saves never lose an unlock.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local fs = require("@lune/fs")

local Achievements = require("../src/shared/Achievements")
local Localization = require("../src/shared/Localization")
local MissionData = require("../src/shared/MissionData")
local Missions = require("../src/shared/Missions")

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

-- Icons.luau needs no Roblox APIs: read its keys from the source (it returns a frozen table of strings).
local iconSource = fs.readFile("src/shared/Icons.luau")
local function iconExists(name: string): boolean
	return string.find(iconSource, "\n%s*" .. name .. "%s*=") ~= nil
		or string.find(iconSource, "Icons%." .. name .. "%s*=") ~= nil
end

local dataSources = fs.readFile("DATA_SOURCES.md")
local CONFIG = MissionData.ACHIEVEMENTS

local function facts(overrides: { [string]: any }?): Achievements.Facts
	local result: any = {
		lessons = {},
		missions = {},
		baseLevel = 0,
		builds = {},
		sitesScanned = 0,
		siteTotal = 5,
	}
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

-- A. The list.
do
	check(#Achievements.LIST >= 10 and #Achievements.LIST <= 16, "A: about a dozen achievements")
	local seen: { [string]: boolean } = {}
	for _, def in Achievements.LIST do
		check(not seen[def.id], "A: unique id " .. def.id)
		seen[def.id] = true
		check(string.match(def.id, "^[a-z_]+$") ~= nil, "A: plain id " .. def.id)
		check(Achievements.get(def.id) == def, "A: get " .. def.id)
		check(iconExists(def.icon), `A: {def.id} icon {def.icon} is in Icons.luau`)
		check(type(CONFIG.BADGES[def.id]) == "number" and CONFIG.BADGES[def.id] >= 0, "A: badge entry for " .. def.id)
		for _, lang in Localization.LANGUAGES do
			for _, key in { Achievements.titleKey(def.id), Achievements.hintKey(def.id), Achievements.factKey(def.id) } do
				local text = Localization.STRINGS[lang][key]
				check(type(text) == "string" and #text > 0, `A: {lang} has {key}`)
			end
		end
		-- Facts quote REAL values that DATA_SOURCES.md lists; hints quote GAME targets.
		for name, realKey in def.factParams or {} do
			local value = (MissionData.REAL :: any)[realKey]
			check(type(value) == "number", `A: {def.id} fact {name} is MissionData.REAL.{realKey}`)
			if type(value) == "number" then
				check(string.find(dataSources, tostring(value), 1, true) ~= nil, `A: {realKey} = {value} is in DATA_SOURCES.md`)
			end
		end
		for name, gameKey in def.hintParams or {} do
			check(type((CONFIG :: any)[gameKey]) == "number", `A: {def.id} hint {name} is MissionData.ACHIEVEMENTS.{gameKey}`)
		end
		if def.kind == "count" or def.kind == "level" then
			check(Achievements.targetOf(MissionData, def) > 0, "A: target for " .. def.id)
		end
		if def.kind == "count" then
			check(Achievements.isCounter(def.counter), "A: counter for " .. def.id)
		end
		for _, missionId in def.missions or {} do
			check(Missions.get(missionId) ~= nil, `A: {def.id} mission {missionId} exists`)
		end
		if def.build then
			local found = false
			for _, build in MissionData.BASE.BUILDS do
				if build.id == def.build then
					found = true
				end
			end
			check(found, `A: {def.id} build {def.build} exists`)
		end
	end
	for id in CONFIG.BADGES do
		check(Achievements.isId(id), "A: badge table only names achievements: " .. id)
	end
	check(CONFIG.XP_REWARD > 0 and CONFIG.XP_REWARD <= MissionData.BASE.LEVEL_XP[2], "A: the XP reward is small")
	-- The base level target can be reached.
	local habitatMax = 0
	for _, build in MissionData.BASE.BUILDS do
		if build.id == "habitat" then
			habitatMax = build.maxLevel
		end
	end
	check(CONFIG.BASE_LEVEL_TARGET <= habitatMax, "A: the base level target exists")
	-- Science: the storm and chapter rules use the real missions.
	check(has(Achievements.get("storm_ready").missions :: any, "t4_storm"), "A: storm_ready = the storm training")
	local chapters = 0
	for _, mission in Missions.LIST do
		if mission.kind == "Story" then
			chapters += 1
			check(has(Achievements.get("chapter_hero").missions :: any, mission.id), "A: chapter_hero needs " .. mission.id)
		end
	end
	check(#(Achievements.get("chapter_hero").missions :: any) == chapters, "A: chapter_hero = every chapter")
	-- c3_failure has a real false alarm, so false_alarm can be earned in the story.
	local c3 = Missions.get("c3_failure")
	local falseAlarm = false
	for _, particles in (c3 and c3.stormParticles) or {} do
		if particles == false then
			falseAlarm = true
		end
	end
	check(falseAlarm, "A: a story chapter has a real false alarm")
end

-- B. Records: old saves, cleaning, merging.
do
	local empty = Achievements.sanitizeRecord(nil)
	check(next(empty.unlocked) == nil, "B: no field = nothing unlocked")
	check(empty.counts.ice == 0 and empty.counts.clean == 0, "B: counters start at 0")
	local dirty = Achievements.sanitizeRecord({
		unlocked = { hello_earth = true, nope = true, ice_hunter = "yes" },
		counts = { ice = 3.7, clean = -2, other = 9 },
	})
	check(dirty.unlocked.hello_earth == true, "B: keeps a known unlock")
	check(dirty.unlocked.nope == nil and dirty.unlocked.ice_hunter == nil, "B: drops unknown ids and non-true flags")
	check(dirty.counts.ice == 3 and dirty.counts.clean == 0 and (dirty.counts :: any).other == nil, "B: counters whole, >= 0, known")
	check(Achievements.sanitizeRecord("broken").counts.ice == 0, "B: a broken value loads empty")

	local stored = { unlocked = { fact_finder = true }, counts = { ice = 8, clean = 1 } }
	local current = { unlocked = { hello_earth = true }, counts = { ice = 2, clean = 4 } }
	local merged = Achievements.mergeRecord(stored, current)
	check(merged.unlocked.fact_finder and merged.unlocked.hello_earth or false, "B: merge keeps every unlock")
	check(merged.counts.ice == 8 and merged.counts.clean == 4, "B: merge keeps the highest counters")

	local record = Achievements.emptyRecord()
	check(Achievements.addCount(record, "ice", 2), "B: addCount changes")
	check(not Achievements.addCount(record, "ice", -1), "B: addCount ignores negatives")
	check(not Achievements.addCount(record, "lava", 1), "B: addCount ignores unknown counters")
	check(not Achievements.addCount(record, "ice", 0 / 0), "B: addCount ignores NaN")
	check(record.counts.ice == 2, "B: counter value")
	local clone = Achievements.cloneRecord(record)
	clone.counts.ice = 99
	check(record.counts.ice == 2, "B: clone is a copy")
end

-- C. Unlock rules.
do
	local record = Achievements.emptyRecord()
	check(#Achievements.newlyMet(MissionData, record, facts()) == 0, "C: nothing without facts")

	local lessons: { [string]: string } = {
		air_from_water = "air_from_water",
		harvest = "patient_farmer",
		storm_sheltered = "mass_shield",
		false_alarm = "false_alarm",
		antenna_linked = "hello_earth",
		OpenSources = "fact_finder",
	}
	for lesson, id in lessons do
		local found = Achievements.newlyMet(MissionData, record, facts({ lessons = { [lesson] = true } }))
		check(#found == 1 and found[1] == id, `C: lesson {lesson} unlocks {id}`)
	end

	record.counts.ice = CONFIG.ICE_TARGET - 1
	check(not has(Achievements.newlyMet(MissionData, record, facts()), "ice_hunter"), "C: ice_hunter waits for the target")
	record.counts.ice = CONFIG.ICE_TARGET
	check(has(Achievements.newlyMet(MissionData, record, facts()), "ice_hunter"), "C: ice_hunter at the target")
	record.counts.clean = CONFIG.PANEL_TARGET
	check(has(Achievements.newlyMet(MissionData, record, facts()), "solar_cleaner"), "C: solar_cleaner at the target")

	check(has(Achievements.newlyMet(MissionData, record, facts({ missions = { t4_storm = true } })), "storm_ready"), "C: storm_ready")
	local twoChapters = facts({ missions = { c1_arrival = true, c2_storm = true } })
	check(not has(Achievements.newlyMet(MissionData, record, twoChapters), "chapter_hero"), "C: chapter_hero needs all three")
	local allChapters = facts({ missions = { c1_arrival = true, c2_storm = true, c3_failure = true } })
	check(has(Achievements.newlyMet(MissionData, record, allChapters), "chapter_hero"), "C: chapter_hero")

	check(not has(Achievements.newlyMet(MissionData, record, facts({ baseLevel = CONFIG.BASE_LEVEL_TARGET - 1 })), "moon_builder"), "C: moon_builder waits")
	check(has(Achievements.newlyMet(MissionData, record, facts({ baseLevel = CONFIG.BASE_LEVEL_TARGET })), "moon_builder"), "C: moon_builder")
	check(has(Achievements.newlyMet(MissionData, record, facts({ builds = { ship = 1 } })), "spaceport"), "C: spaceport")
	check(not has(Achievements.newlyMet(MissionData, record, facts({ builds = { landing_pad = 1 } })), "spaceport"), "C: spaceport needs the ship")

	check(not has(Achievements.newlyMet(MissionData, record, facts({ sitesScanned = 4 })), "explorer"), "C: explorer waits for every site")
	check(has(Achievements.newlyMet(MissionData, record, facts({ sitesScanned = 5 })), "explorer"), "C: explorer")
	check(not has(Achievements.newlyMet(MissionData, record, facts({ sitesScanned = 0, siteTotal = 0 })), "explorer"), "C: explorer never with no sites")

	-- Once unlocked, never again.
	record.unlocked.hello_earth = true
	check(not has(Achievements.newlyMet(MissionData, record, facts({ lessons = { antenna_linked = true } })), "hello_earth"), "C: unlocks once")
	check(#Achievements.unlockedList(record) == 1, "C: unlockedList")

	-- Progress for the panel.
	local def = Achievements.get("ice_hunter") :: Achievements.Achievement
	local have, need = Achievements.progress(MissionData, def, { unlocked = {}, counts = { ice = 3, clean = 0 } }, 0)
	check(have == 3 and need == CONFIG.ICE_TARGET, "C: ice progress")
	local levelDef = Achievements.get("moon_builder") :: Achievements.Achievement
	have, need = Achievements.progress(MissionData, levelDef, Achievements.emptyRecord(), 99)
	check(have == need and need == CONFIG.BASE_LEVEL_TARGET, "C: level progress is capped")

	-- Placeholders filled from MissionData.
	local earth = Achievements.factParams(MissionData, Achievements.get("hello_earth") :: any)
	check(earth ~= nil and earth.moon == MissionData.REAL.MOON_EARTH_LIGHT_TIME_S, "C: hello_earth quotes the real light time")
	local filled = Localization.t(Achievements.factKey("hello_earth"), earth :: any, "en")
	check(string.find(filled, "1.3", 1, true) ~= nil and string.find(filled, "{", 1, true) == nil, "C: the fact text is filled")
	local hint = Localization.t(Achievements.hintKey("ice_hunter"), Achievements.hintParams(MissionData, def) :: any, "es")
	check(string.find(hint, tostring(CONFIG.ICE_TARGET), 1, true) ~= nil, "C: the hint shows the target")
end

print(`achievements: {passes} passed, {failures} failed`)
if failures > 0 then
	error("achievements tests failed")
end
