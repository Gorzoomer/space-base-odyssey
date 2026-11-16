--!strict
-- Space Base Odyssey - reading rules tests (Stage 11 readable UI). Run with: lune run tests/reading
-- Checks src/shared/Reading.luau: reading time grows with words and never drops under the minimum;
-- the C.A.R.L. queue merges repeats and drops the least useful line in a notice storm; quest toasts
-- never drop an achievement card; counted steps (only) show a fraction; glossary words are found in
-- English and Spanish quest and achievement texts (plurals and extra forms) and marked up safely; and
-- the Achievements panel's page maths.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Reading = require("../src/shared/Reading")
local Glossary = require("../src/shared/Glossary")
local Quests = require("../src/shared/Quests")
local Localization = require("../src/shared/Localization")

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

-- A. Reading time.
do
	check(Reading.wordCount("Bring ice home") == 3, "A: three words")
	check(Reading.wordCount("¡Sí! Los paneles - limpios.") == 4, "A: Spanish words count, a lone dash does not")
	check(Reading.wordCount("") == 0, "A: empty text has no words")
	check(Reading.seconds("Hi") == Reading.MIN_SECONDS, "A: a short line still gets the minimum")
	check(Reading.seconds("Hi", { busy = true }) == Reading.MIN_SECONDS, "A: busy never goes under the minimum")
	local eight = "one two three four five six seven eight"
	check(Reading.seconds(eight) >= 7.5, "A: an 8-word line stays about 8 s for a young reader")
	check(Reading.seconds(eight, { busy = true }) < Reading.seconds(eight), "A: busy lines are a little shorter")
	local long = string.rep("word ", 40)
	check(Reading.seconds(long) == Reading.MAX_SECONDS, "A: a normal line is capped")
	check(Reading.seconds(long, { fact = true }) == Reading.FACT_MAX_SECONDS, "A: facts have a longer cap")
	check(Reading.seconds("Hi", { minimum = 7 }) == 7, "A: a setting can raise the minimum")
	check(Reading.seconds("Hi", { minimum = 0 / 0 }) == Reading.MIN_SECONDS, "A: a broken minimum is ignored")
	check(Reading.MIN_SECONDS >= 4, "A: no line shorter than 4 s")
end

-- B. C.A.R.L. queue in a notice storm.
do
	type Ref = { key: string, n: number? }
	local function keyOf(ref: Ref): string
		return ref.key
	end
	local queue: { Ref } = {}
	local dropped: { Ref } = {}
	local function add(ref: Ref)
		for _, gone in Reading.enqueue(queue, ref, keyOf, 4) do
			table.insert(dropped, gone)
		end
	end
	add({ key = "quest.m01_home.praise" })
	add({ key = "carl.quest.done", n = 1 })
	add({ key = "carl.quest.new" })
	add({ key = "carl.base.level_up" })
	check(#queue == 4 and #dropped == 0, "B: four lines fit")
	add({ key = "carl.quest.done", n = 2 })
	check(#queue == 4 and #dropped == 0, "B: a repeated key merges instead of adding")
	check(queue[2].n == 2, "B: the merged line keeps the newer numbers")
	add({ key = "base.why.credits" })
	check(#queue == 4 and #dropped == 1, "B: a fifth line pushes one out")
	check(dropped[1].key == "carl.quest.done", "B: the oldest low-priority line goes first (the toast shows it)")
	add({ key = "carl.tip.something" })
	check(dropped[2].key == "carl.quest.new", "B: then the next low-priority line")
	local keep = false
	for _, ref in queue do
		if ref.key == "quest.m01_home.praise" then
			keep = true
		end
	end
	check(keep, "B: praise (it teaches) is kept")
	check(Reading.priority("base.why.credits") > Reading.priority("carl.base.level_up"), "B: a refusal beats a normal line")
	check(Reading.priority("quiz.power.why") > Reading.priority("carl.quest.new"), "B: quiz lines beat quest news")
end

-- C. Quest toasts never drop an achievement.
do
	check(Reading.toastDropIndex({ "achievement", "new", "step", "main_done" }) == 3, "C: a step line goes first")
	check(Reading.toastDropIndex({ "achievement", "new", "current", "main_done" }) == 3, "C: then 'your quest right now'")
	check(Reading.toastDropIndex({ "main_done", "new", "side_done" }) == 2, "C: then a new quest card")
	check(Reading.toastDropIndex({ "main_done", "side_done", "achievement" }) == 2, "C: a main completion outranks a side one")
	check(Reading.toastDropIndex({ "achievement", "achievement" }) == nil, "C: achievement cards are never dropped")
	check(Reading.toastDropIndex({ "step", "step" }) == 1, "C: the oldest of the same rank goes")
end

-- D. Quest step fractions: counted steps only, never "level 2  1/2".
do
	check(Reading.stepShowsFraction(true, nil, 4, false), "D: a counted step shows 0/4")
	check(not Reading.stepShowsFraction(false, true, 2, false), "D: the server's 'not counted' wins")
	check(not Reading.stepShowsFraction(true, true, 4, true), "D: a done step shows its tick only")
	check(not Reading.stepShowsFraction(true, true, 1, false), "D: a target of 1 shows no fraction")
	check(not Reading.stepShowsFraction(nil, false, 2, false), "D: a level step (Quests.showsFraction false) has none")
	check(Reading.stepShowsFraction(nil, nil, 3, false), "D: an unknown step with a target shows it")
	local levelSteps, countedSteps = 0, 0
	for _, quest in Quests.LIST do
		for _, step in quest.steps do
			local shows = Reading.stepShowsFraction(nil, Quests.showsFraction(step), Quests.stepTarget(step), false)
			if (step.type == "build" or step.type == "tool_upgrade") and (step.level or 1) > 1 then
				levelSteps += 1
				check(not shows, `D: {quest.id} level step shows no fraction`)
			elseif shows then
				countedSteps += 1
			end
		end
	end
	check(levelSteps > 0 and countedSteps > 0, "D: the quest list has both level and counted steps")
end

-- E. Glossary words in text.
do
	local terms: { Reading.Term } = {
		{ id = "silo", word = "silo" },
		{ id = "solar_panel", word = "solar panel" },
		{ id = "solar_flare", word = "solar flare" },
		{ id = "habitat", word = "Hábitat" },
	}
	local found = Reading.findTerms("Clean the Solar panels, then the silos.", terms)
	check(#found == 2 and found[1].id == "solar_panel" and found[2].id == "silo", "E: plural words are found in reading order")
	check(found[1].first == 11 and string.sub("Clean the Solar panels, then the silos.", found[1].first, found[1].last) == "Solar panels", "E: the match covers the plural")
	check(#Reading.findTerms("A silom is not a silo", terms) == 1, "E: a longer word is not a match")
	check(#Reading.findTerms("Bigsilo", terms) == 0, "E: a word must start at a word start")
	local es = Reading.findTerms("¡Construye el hábitat!", terms)
	check(#es == 1 and es[1].id == "habitat", "E: a Spanish word after punctuation is found")
	check(#Reading.findTerms("¿Silo lleno?", terms) == 1, "E: a word right after an inverted mark is found")
	local overlap = Reading.findTerms("solar panel", { { id = "a", word = "solar" }, { id = "b", word = "solar panel" } })
	check(#overlap == 1 and overlap[1].id == "b", "E: the longer form wins at the same place")

	local rich = Reading.markup("Fill <the> silo & more", Reading.findTerms("Fill <the> silo & more", terms), "F5C542")
	check(rich == 'Fill &lt;the&gt; <font color="#F5C542"><u>silo</u></font> &amp; more', "E: markup escapes text and paints the word")
	check(Reading.markup("a < b", {}, "FFFFFF") == "a &lt; b", "E: no match: only escaped")

	local forms = Reading.forms("Panel solar", " paneles solares, ,paneles ")
	check(#forms == 3 and forms[1] == "Panel solar" and forms[2] == "paneles solares" and forms[3] == "paneles", "E: forms are trimmed, empty ones skipped")
	check(#Reading.forms("Silo", nil) == 1, "E: no extra forms")
end

-- F. Every glossary word (and form) is found in its own language, and the quest tracker shows some.
do
	local function termsFor(lang: string): { Reading.Term }
		local list: { Reading.Term } = {}
		for _, term in Glossary.LIST do
			local word = Localization.t(Glossary.wordKey(term.id), nil, lang :: any)
			local formsKey = "glossary." .. term.id .. ".forms"
			local extra = Localization.t(formsKey, nil, lang :: any)
			for _, form in Reading.forms(word, if extra ~= formsKey then extra else nil) do
				table.insert(list, { id = term.id, word = form })
			end
		end
		return list
	end
	for _, lang in { "en", "es" } do
		local terms = termsFor(lang)
		for _, term in terms do
			local found = Reading.findTerms(`Look: {term.word}.`, terms)
			check(#found >= 1 and found[1].id == term.id, `F: {lang} form "{term.word}" is found`)
		end
		local stepsWithWords = 0
		for _, quest in Quests.LIST do
			for index = 1, #quest.steps do
				local text = Localization.t(Quests.stepKey(quest.id, index), { n = 2 }, lang :: any)
				if #Reading.findTerms(text, terms) > 0 then
					stepsWithWords += 1
				end
			end
		end
		check(stepsWithWords >= 5, `F: {lang} quest steps show glossary words ({stepsWithWords})`)
	end
	-- The Spanish tracker says "paneles solares": it must be one solar panel match, not two words.
	local es = termsFor("es")
	local panels = Reading.findTerms("Construye los paneles solares", es)
	check(#panels == 1 and panels[1].id == "solar_panel", "F: 'paneles solares' is one solar panel word")
end

-- G. Pages.
do
	check(Reading.pageCount(13, 6) == 3, "G: 13 achievements make 3 pages of 6")
	check(Reading.pageCount(13, 4) == 4, "G: 4 pages of 4 on small screens")
	check(Reading.pageCount(0, 6) == 1, "G: there is always one page")
	local first, last, page = Reading.pageRange(13, 6, 3)
	check(first == 13 and last == 13 and page == 3, "G: the last page holds the rest")
	first, last, page = Reading.pageRange(13, 6, 9)
	check(page == 3 and first == 13, "G: a page past the end is clamped")
	first, last, page = Reading.pageRange(13, 6, 0)
	check(page == 1 and first == 1 and last == 6, "G: a page before the start is clamped")
end

print(`reading: {passes} passed, {failures} failed`)
if failures > 0 then
	error("reading tests failed")
end
