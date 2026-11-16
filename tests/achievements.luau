--!strict
-- Space Base Odyssey - learning achievement tests (Stage 10; Stage 11 adds where-hints, C.A.R.L. asks
-- (src/shared/Quiz.luau) and the picture glossary). Run with: lune run tests/achievements
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

----------------------------------------------------------------------------------------------------
-- D. Stage 11: achievement hints say WHERE they can be done. The lessons below fire only in a
--    mission shift (MissionService), so their hints name the mission; the Sources screen hint names
--    the Missions panel button (the open-world HUD has no "Real NASA data" button).

do
	local MISSION_WORDS = { en = { "mission", "chapter" }, es = { "misión", "capítulo" } }
	for _, id in { "air_from_water", "patient_farmer", "mass_shield", "false_alarm", "hello_earth" } do
		for lang, words in MISSION_WORDS do
			local text = string.lower(Localization.STRINGS[lang :: any][Achievements.hintKey(id)] or "")
			local named = false
			for _, word in words do
				named = named or string.find(text, word, 1, true) ~= nil
			end
			check(named, `D: {lang} hint of {id} says it happens in a mission: {text}`)
		end
	end
	local sourcesButton = Localization.STRINGS.en["ui.sources_button"]
	check(string.find(Localization.STRINGS.en[Achievements.hintKey("fact_finder")], sourcesButton, 1, true) ~= nil, "D: fact_finder hint names the Real NASA data button")
	check(string.find(Localization.STRINGS.en[Achievements.hintKey("fact_finder")], Localization.STRINGS.en["prompt.missions"], 1, true) ~= nil, "D: fact_finder hint names the Missions panel")
end

----------------------------------------------------------------------------------------------------
-- E. Stage 11 "C.A.R.L. asks" (src/shared/Quiz.luau): every question has 2-3 answers with exactly
--    one right one, an icon per answer, every text in en and es, a real quest that queues it, and the
--    record rules (right = answered, wrong / later = asked again, saves only grow).

do
	local Quiz = require("../src/shared/Quiz")
	local Quests = require("../src/shared/Quests")
	local Glossary = require("../src/shared/Glossary")
	local seen: { [string]: boolean } = {}
	local quests: { [string]: boolean } = {}
	check(#Quiz.LIST >= 8, `E: a real question bank ({#Quiz.LIST} questions)`)
	for _, question in Quiz.LIST do
		local id = question.id
		check(not seen[id], `E: question id {id} is unique`)
		seen[id] = true
		check(string.match(id, "^[%l_]+$") ~= nil, `E: question id {id} is lower case`)
		check(Quiz.get(id) == question and Quiz.isId(id), `E: get finds {id}`)
		check(iconExists(question.icon), `E: {id} icon {question.icon} exists`)
		check(#question.answers >= 2 and #question.answers <= 3, `E: {id} has 2 or 3 answers`)
		-- Exactly one right answer: check() says "right" for one index only.
		local rights = 0
		for index, icon in question.answers do
			check(iconExists(icon), `E: {id} answer {index} icon {icon} exists`)
			if Quiz.check(id, index) == "right" then
				rights += 1
			else
				check(Quiz.check(id, index) == "wrong", `E: {id} answer {index} is wrong when not right`)
			end
		end
		check(rights == 1 and question.correct >= 1 and question.correct <= #question.answers, `E: {id} has exactly one right answer`)
		-- Answers are different texts in both languages, so the right one is a real choice.
		for _, lang in Localization.LANGUAGES do
			local texts: { [string]: boolean } = {}
			for index = 1, #question.answers do
				local text = Localization.STRINGS[lang][Quiz.answerKey(id, index)]
				check(type(text) == "string" and not texts[text], `E: {lang} {id} answer {index} is its own text`)
				if type(text) == "string" then
					texts[text] = true
				end
			end
			for _, key in { Quiz.questionKey(id), Quiz.hintKey(id), Quiz.whyKey(id) } do
				check(type(Localization.STRINGS[lang][key]) == "string", `E: {lang} has {key}`)
			end
		end
		-- Queued by a real quest, one question per quest at most.
		local quest = Quests.byId(question.after)
		check(quest ~= nil, `E: {id} is asked after a real quest ({question.after})`)
		check(not quests[question.after], `E: one question per quest ({question.after})`)
		quests[question.after] = true
		check(#Quiz.forQuest(question.after) == 1 and Quiz.forQuest(question.after)[1] == question, `E: forQuest finds {id}`)
	end
	-- Answers that are not a whole choice in range are refused; 0 is "Not now".
	local any = Quiz.LIST[1]
	check(Quiz.check(any.id, 0) == "later", "E: choice 0 = not now")
	check(Quiz.check(any.id, #any.answers + 1) == "invalid", "E: a choice past the answers is refused")
	check(Quiz.check(any.id, 1.5) == "invalid" and Quiz.check(any.id, -1) == "invalid", "E: odd choices are refused")
	check(Quiz.check(any.id, 0 / 0) == "invalid" and Quiz.check(any.id, "1") == "invalid", "E: NaN and strings are refused")
	check(Quiz.check("nope", 1) == "invalid", "E: an unknown question is refused")
	-- Science checks: the right answers say what CLAUDE.md says.
	local function rightText(id: string): string
		local question = Quiz.get(id) :: Quiz.Question
		return string.lower(Localization.STRINGS.en[Quiz.answerKey(id, question.correct)])
	end
	check(string.find(rightText("shelter"), "walls", 1, true) ~= nil, "E: the shelter protects by mass (walls), not power")
	check(string.find(rightText("shelter"), "electric", 1, true) == nil, "E: electricity is not the shelter answer")
	check(string.find(rightText("air"), "water", 1, true) ~= nil and string.find(rightText("air"), "electric", 1, true) ~= nil, "E: oxygen comes from water plus electricity")
	check(string.find(rightText("radiation"), "no", 1, true) ~= nil, "E: radiation never goes down")
	check(string.find(rightText("flare"), "not always", 1, true) ~= nil, "E: a big flare does not always bring a storm")
	check(string.find(rightText("plants"), "time", 1, true) ~= nil, "E: plants take time to grow")
	-- The radio answer agrees with the REAL light time (about a second, DATA_SOURCES.md).
	local light = MissionData.REAL.MOON_EARTH_LIGHT_TIME_S
	check(light >= 1 and light < 2 and string.find(rightText("radio"), "second", 1, true) ~= nil, "E: radio reaches Earth in just over a second")
	check(string.find(dataSources, tostring(light), 1, true) ~= nil, "E: the light time is in DATA_SOURCES.md")
	-- The XP bonus is a small GAME value.
	local rules = MissionData.QUESTS
	check(type(rules.QUIZ_XP) == "number" and rules.QUIZ_XP >= 1 and rules.QUIZ_XP <= CONFIG.XP_REWARD, "E: the quiz bonus is small (at most an achievement's XP)")
	check(rules.QUIZ_RETRY_SECONDS > rules.QUIZ_GAP_SECONDS and rules.QUIZ_GAP_SECONDS > 0, "E: a missed question comes back later than the next one")
	check(rules.TREASURE_HINT_SECONDS >= 60 and rules.BREAK_AFTER_MINUTES >= 30, "E: hints and breaks are not nagging")

	-- Record rules.
	local record = Quiz.emptyRecord()
	check(Quiz.queueAfterQuest(record, "m01_home") == 1 and record.queue[1] == "power", "E: finishing a quest queues its question")
	check(Quiz.queueAfterQuest(record, "m01_home") == 0, "E: a waiting question is not queued twice")
	check(Quiz.queueAfterQuest(record, "m00_landing") == 0, "E: quests without a question queue nothing")
	local power = Quiz.get("power") :: Quiz.Question
	local wrongChoice = if power.correct == 1 then 2 else 1
	record = Quiz.emptyRecord()
	Quiz.queueAfterQuest(record, "m01_home")
	Quiz.queueAfterQuest(record, "m04_storm")
	check(Quiz.answer(record, "power", wrongChoice) == "wrong", "E: a wrong answer is wrong")
	check(record.queue[1] == "shelter" and record.queue[2] == "power" and not record.done.power, "E: a wrong answer goes to the back and comes back")
	check(Quiz.answer(record, "power", 0) == "later" and record.queue[#record.queue] == "power", "E: not now keeps it waiting")
	check(Quiz.answer(record, "power", 9) == "invalid" and #record.queue == 2, "E: a bad choice changes nothing")
	check(Quiz.answer(record, "power", power.correct) == "right", "E: the right answer is right")
	check(record.done.power == true and table.find(record.queue, "power") == nil, "E: a right answer is done and leaves the queue")
	check(Quiz.answer(record, "power", power.correct) == "invalid", "E: an answered question cannot pay twice")
	check(Quiz.queueAfterQuest(record, "m01_home") == 0, "E: an answered question is never queued again")
	check(Quiz.answer(record, "mars", 1) == "invalid", "E: a question that is not waiting is refused")
	-- Saves: old saves (no field) are empty, garbage is cleaned, merges only grow.
	local clean = Quiz.sanitizeRecord(nil)
	check(next(clean.done) == nil and #clean.queue == 0, "E: no quiz field = nothing answered")
	clean = Quiz.sanitizeRecord({ done = { power = true, nope = true, ice = 1 }, queue = { "power", "ice", "ice", "nope", 3 } })
	check(clean.done.power == true and clean.done.nope == nil and clean.done.ice == nil, "E: sanitize keeps real answered questions")
	check(#clean.queue == 1 and clean.queue[1] == "ice", "E: sanitize drops done, unknown and repeated ids from the queue")
	local merged = Quiz.mergeRecord({ done = { dust = true }, queue = { "ice", "air" } }, { done = { ice = true }, queue = { "shelter" } })
	check(merged.done.dust and merged.done.ice, "E: merge keeps every answer")
	check(merged.queue[1] == "shelter" and merged.queue[2] == "air" and #merged.queue == 2, "E: merge keeps waiting questions, this server's first")
	local copy = Quiz.cloneRecord(merged)
	copy.queue[1] = "mars"
	check(merged.queue[1] == "shelter", "E: clone is a copy")

	-- F. Picture glossary: one word per thing, a real icon, en and es.
	local terms: { [string]: boolean } = {}
	for _, term in Glossary.LIST do
		check(not terms[term.id], `F: glossary term {term.id} is unique`)
		terms[term.id] = true
		check(iconExists(term.icon), `F: glossary {term.id} icon {term.icon} exists`)
		check(Glossary.get(term.id) == term, `F: get finds {term.id}`)
		for _, lang in Localization.LANGUAGES do
			check(type(Localization.STRINGS[lang][Glossary.wordKey(term.id)]) == "string", `F: {lang} word for {term.id}`)
			check(type(Localization.STRINGS[lang][Glossary.defKey(term.id)]) == "string", `F: {lang} meaning of {term.id}`)
		end
	end
	-- The words the quests use are the glossary words (one name per thing).
	local box = string.lower(Localization.STRINGS.en[Glossary.wordKey("parts_box")])
	check(string.find(string.lower(Localization.STRINGS.en["prompt.take_crate"]), box, 1, true) ~= nil, "F: the crate prompt says parts box")
	check(string.find(string.lower(Localization.STRINGS.en[Quests.stepKey("m00_landing", 1)]), box, 1, true) ~= nil, "F: the first quest says parts box")
	check(string.find(string.lower(Localization.STRINGS.en["build.habitat.name"]), string.lower(Localization.STRINGS.en[Glossary.wordKey("habitat")]), 1, true) ~= nil, "F: the habitat pad uses the glossary word")
	local buggy = string.lower(Localization.STRINGS.en["ui.vehicle.buggy"])
	check(string.find(string.lower(Localization.STRINGS.en[Quests.stepKey("m14_wheels", 3)]), buggy, 1, true) ~= nil, "F: the drive quest names the moon buggy")
	-- Stage 11 review: treasure hints name landmarks a kid can see (the game has no compass).
	for _, id in Quests.TREASURE_ORDER do
		for level = 1, 2 do
			for _, lang in Localization.LANGUAGES do
				local text = string.lower(Localization.STRINGS[lang][Quests.treasureHintKey(id, level)] or "")
				for _, word in { "west", "east", "north", "south", "oeste", "este ", "norte", "sur " } do
					check(string.find(text .. " ", word, 1, true) == nil, `F: {lang} hint {id}.{level} uses no compass word ({word})`)
				end
			end
		end
	end
	for _, key in { "quest.m06_panels.step1", "quest.m12_garden.step1", "quest.m17_explorer.step2" } do
		check(string.find(Localization.STRINGS.en[key], "Upgrade", 1, true) ~= nil, `F: {key} says Upgrade like the pad prompt`)
	end
end

print(`achievements: {passes} passed, {failures} failed`)
if failures > 0 then
	error("achievements tests failed")
end
