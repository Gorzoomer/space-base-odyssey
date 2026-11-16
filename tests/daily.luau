--!strict
-- Space Base Odyssey - daily supply capsule and Moon Logbook tests (Stage 11). Run with:
-- lune run tests/daily
-- Checks src/shared/Daily.luau and MissionData.DAILY / LOGBOOK: the calendar is fixed and shown in
-- advance (no randomness), one capsule per UTC day, a missed day only pauses the calendar, day 7
-- gives the week's suit stripes and then credits, the rewards stay small next to playing, cargo
-- facts exist in both languages and quote no number, stripes use Theme colours, the logbook count
-- and milestones (server-validated targets, cosmetic rewards), old saves load and merges never lose
-- anything, and the record fits a DataStore (string keys only).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local fs = require("@lune/fs")

local Daily = require("../src/shared/Daily")
local Localization = require("../src/shared/Localization")
local MissionData = require("../src/shared/MissionData")

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

local DAY = Daily.DAY_SECONDS
local DAILY = MissionData.DAILY
local LOGBOOK = MissionData.LOGBOOK
local LENGTH = #DAILY.CALENDAR
-- A fixed Unix time in the middle of a UTC day (14 Nov 2026, 15:00 UTC).
local T0 = 1794668400
check(T0 % DAY == 15 * 3600, "T0 is 15:00 UTC")

----------------------------------------------------------------------------------------------------
-- A. Data: calendar, stripes, facts
check(LENGTH == 7, "A: the calendar has 7 days")
for day, entry in DAILY.CALENDAR do
	check(entry.kind == "credits" or entry.kind == "xp" or entry.kind == "stripe", `A: day {day} has a known kind`)
	if entry.kind ~= "stripe" then
		check(type(entry.amount) == "number" and entry.amount > 0 and entry.amount == math.floor(entry.amount), `A: day {day} pays a whole amount`)
	end
end
check(DAILY.CALENDAR[LENGTH].kind == "stripe", "A: day 7 gives a cosmetic")
for day = 1, LENGTH - 1 do
	check(DAILY.CALENDAR[day].kind ~= "stripe", `A: only day 7 gives stripes (day {day})`)
end
check(type(DAILY.STRIPE_DONE_CREDITS) == "number" and DAILY.STRIPE_DONE_CREDITS > 0, "A: day 7 credits once every stripe is owned")
for week, id in DAILY.WEEK_STRIPES do
	local stripe = Daily.stripe(id)
	check(stripe ~= nil and stripe.source == "daily", `A: week {week} stripe {id} is a daily stripe`)
end
-- Small rewards: a whole week pays no more than three fresh-crater scans, so playing beats waiting;
-- a later day 7 (every weekly stripe owned) pays at most two crater scans of credits.
do
	local credits, xp = 0, 0
	for day = 1, LENGTH do
		local reward = Daily.rewardFor(MissionData, day)
		if reward.kind == "credits" then
			credits += reward.amount
		elseif reward.kind == "xp" then
			xp += reward.amount
		end
	end
	local meteor = MissionData.BASE.REWARDS.meteor_scanned
	check(credits <= meteor.credits * 3, `A: a week pays at most 3 crater scans of credits ({credits})`)
	check(xp <= meteor.xp * 3, `A: a week pays at most 3 crater scans of XP ({xp})`)
	check(DAILY.STRIPE_DONE_CREDITS <= meteor.credits * 2, "A: a later day 7 pays at most 2 crater scans")
end

local themeSource = fs.readFile("src/shared/Theme.luau")
local seenStripe: { [string]: boolean } = {}
for _, stripe in Daily.STRIPES do
	check(not seenStripe[stripe.id], "A: unique stripe id " .. stripe.id)
	seenStripe[stripe.id] = true
	check(#stripe.colors == 2, `A: {stripe.id} has two bands`)
	for _, colour in stripe.colors do
		check(string.find(themeSource, "\n%s*" .. colour .. "%s*=%s*hex") ~= nil, `A: {stripe.id} colour {colour} is a Theme.PALETTE colour`)
	end
	local key = Daily.stripeNameKey(stripe.id)
	check(Localization.STRINGS.en[key] ~= nil and Localization.STRINGS.es[key] ~= nil, `A: {key} in en and es`)
end
-- Every stripe can be earned: the weekly ones by capsules, the others by one logbook milestone.
for _, stripe in Daily.STRIPES do
	local earned = false
	if stripe.source == "daily" then
		earned = table.find(DAILY.WEEK_STRIPES, stripe.id) ~= nil
	else
		for _, milestone in Daily.MILESTONES do
			if milestone.stripe == stripe.id then
				earned = true
			end
		end
	end
	check(earned, `A: stripe {stripe.id} can be earned`)
end

check(#Daily.CARGO_FACTS >= LENGTH, "A: at least one cargo fact per calendar day")
for _, key in Daily.CARGO_FACTS do
	for _, lang in Localization.LANGUAGES do
		local text = Localization.STRINGS[lang][key]
		check(type(text) == "string", `A: {lang} {key} exists`)
		-- No invented statistics: cargo facts quote no number at all.
		check(type(text) == "string" and string.find(text, "%d") == nil, `A: {lang} {key} quotes no number`)
	end
end
-- Science rules the cargo facts touch (CLAUDE.md): air comes from water plus power.
check(string.find(string.lower(Localization.STRINGS.en["daily.fact.3"]), "power", 1, true) ~= nil
	and string.find(string.lower(Localization.STRINGS.en["daily.fact.3"]), "water", 1, true) ~= nil, "A: the air fact says water plus power")
-- The capsule is a game gift, never presented as a real NASA flight.
check(string.find(Localization.STRINGS.en["ui.daily.note"], "not a real", 1, true) ~= nil, "A: the card says it is not a real flight")

----------------------------------------------------------------------------------------------------
-- B. Days and the calendar
check(Daily.dayNumber(T0) == Daily.dayNumber(T0 + 8 * 3600), "B: 15:00 and 23:00 are the same UTC day")
check(Daily.dayNumber(T0 + 9 * 3600) == Daily.dayNumber(T0) + 1, "B: midnight UTC starts a new day")
check(Daily.secondsToNextDay(T0) == 9 * 3600, "B: 9 hours to the next UTC day")

local record = Daily.emptyRecord()
check(Daily.isReady(record, T0), "B: a new explorer has a capsule waiting")
local calendar = Daily.calendar(MissionData, record, T0)
check(calendar.ready and calendar.week == 1 and #calendar.days == LENGTH, "B: week 1, 7 days, ready")
check(calendar.days[1].state == "today" and calendar.days[2].state == "later", "B: day 1 is today")
check(calendar.factKey == Daily.CARGO_FACTS[1], "B: the first capsule carries the first cargo fact")
-- Fixed rewards: the calendar shows exactly what each claim pays.
local shown: { any } = {}
for i, day in calendar.days do
	shown[i] = { kind = day.kind, amount = day.amount, stripe = day.stripe }
end

local reward, why = Daily.claim(MissionData, record, T0)
check(reward ~= nil and why == nil, "B: the first capsule opens")
check(reward ~= nil and reward.kind == shown[1].kind and reward.amount == shown[1].amount, "B: it pays what the calendar showed")
check(record.opened == 1 and record.lastDay == Daily.dayNumber(T0), "B: the record counts it")
check(not Daily.isReady(record, T0 + 60), "B: not twice on the same day")
local again, whyAgain = Daily.claim(MissionData, record, T0 + 3600)
check(again == nil and whyAgain == "not_ready", "B: a second claim that day is refused")
check(record.opened == 1, "B: a refused claim changes nothing")
local after = Daily.calendar(MissionData, record, T0 + 3600)
check(not after.ready and after.days[1].state == "done" and after.days[2].state == "later", "B: after opening: day 1 done, no today")
check(after.factKey == Daily.CARGO_FACTS[1], "B: the card keeps the fact of the capsule just opened")
-- A clock that went back (or a save from a later day) never opens an extra capsule.
check(not Daily.isReady(record, T0 - DAY), "B: an earlier day never opens a capsule")

-- Forgiving: missing three days only pauses the calendar (day 2 is next, not day 1).
local later = T0 + 4 * DAY
check(Daily.isReady(record, later), "B: a capsule waits after a pause")
local paused = Daily.calendar(MissionData, record, later)
check(paused.days[1].state == "done" and paused.days[2].state == "today", "B: after missed days, day 2 is next (nothing reset)")
local second = Daily.claim(MissionData, record, later)
check(second ~= nil and second.day == 2 and second.kind == shown[2].kind and second.amount == shown[2].amount, "B: day 2 pays what was shown")

-- Week 1 to the end: day 7 gives week 1's stripes, worn at once.
local t = later
for day = 3, LENGTH do
	t += DAY
	local r = Daily.claim(MissionData, record, t)
	check(r ~= nil and r.day == day and r.week == 1, `B: week 1 day {day}`)
	if day == LENGTH then
		check(r ~= nil and r.kind == "stripe" and r.stripe == DAILY.WEEK_STRIPES[1], "B: day 7 gives the week 1 stripes")
	end
end
check(record.stripes[DAILY.WEEK_STRIPES[1]] == true, "B: the stripes are owned")
check(record.wear == DAILY.WEEK_STRIPES[1], "B: the first stripes are worn at once")
local finished = Daily.calendar(MissionData, record, t + 60)
check(not finished.ready and finished.week == 1 and finished.days[LENGTH].state == "done", "B: a finished week stays on screen until the next day")
local nextWeek = Daily.calendar(MissionData, record, t + DAY)
check(nextWeek.ready and nextWeek.week == 2 and nextWeek.days[1].state == "today", "B: the next day starts week 2")
check(nextWeek.days[LENGTH].stripe == DAILY.WEEK_STRIPES[2], "B: week 2 shows its own stripes")

-- After the last weekly stripe, day 7 pays credits instead (still fixed and shown).
local beyond = Daily.rewardFor(MissionData, LENGTH * (#DAILY.WEEK_STRIPES + 1))
check(beyond.kind == "credits" and beyond.amount == DAILY.STRIPE_DONE_CREDITS and beyond.stripe == nil, "B: later day 7s pay credits")
-- Deterministic: the same capsule number always gives the same reward.
for capsule = 1, 30 do
	local a = Daily.rewardFor(MissionData, capsule)
	local b = Daily.rewardFor(MissionData, capsule)
	check(a.kind == b.kind and a.amount == b.amount and a.stripe == b.stripe, `B: capsule {capsule} is fixed`)
end
-- Cargo facts cycle.
check(Daily.factKey(#Daily.CARGO_FACTS + 1) == Daily.CARGO_FACTS[1], "B: cargo facts start again")

----------------------------------------------------------------------------------------------------
-- C. Wearing stripes
local wearing = Daily.emptyRecord()
check(not Daily.wear(wearing, "sunrise"), "C: stripes not owned cannot be worn")
check(wearing.wear == "none", "C: nothing worn")
wearing.stripes.sunrise = true
check(Daily.wear(wearing, "sunrise") and wearing.wear == "sunrise", "C: owned stripes can be worn")
check(Daily.wear(wearing, "none") and wearing.wear == "none", "C: stripes can be taken off")
check(not Daily.wear(wearing, "rainbow") and not Daily.wear(wearing, 5), "C: unknown values are refused")

----------------------------------------------------------------------------------------------------
-- D. Moon Logbook
local function facts(overrides: { [string]: number }?): Daily.LogbookFacts
	local result: any = {
		secrets = 0,
		secretTotal = 4,
		sites = 0,
		siteTotal = 5,
		meteors = 0,
		achievements = 0,
		achievementTotal = 13,
	}
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end
local entries, total = Daily.logbookEntries(MissionData, facts())
check(entries == 0 and total == 4 + 5 + LOGBOOK.METEOR_PAGE + 13, "D: an empty book and its size")
local full, fullTotal = Daily.logbookEntries(MissionData, facts({ secrets = 4, sites = 5, meteors = 99, achievements = 13 }))
check(full == fullTotal, "D: everything found fills the book (extra craters do not overflow)")
local some = Daily.logbookEntries(MissionData, facts({ secrets = 9, sites = -2, meteors = 2 }))
check(some == 4 + 0 + 2, "D: counts are clamped to each page")

local previous = 0
for _, milestone in Daily.MILESTONES do
	local target = Daily.milestoneTarget(MissionData, milestone.id)
	check(target > previous, `D: milestone {milestone.id} needs more entries than the one before`)
	check(target <= fullTotal, `D: milestone {milestone.id} can be reached ({target} of {fullTotal})`)
	check(Daily.stripe(milestone.stripe) ~= nil and (Daily.stripe(milestone.stripe) :: Daily.Stripe).source == "logbook", `D: {milestone.id} gives a logbook stripe`)
	previous = target
end
for id in LOGBOOK.MILESTONE_ENTRIES do
	check(Daily.isMilestone(id), `D: MissionData milestone {id} exists in Daily`)
end

local book = Daily.emptyRecord()
local first = Daily.MILESTONES[1]
local firstTarget = Daily.milestoneTarget(MissionData, first.id)
local stripe, reason = Daily.claimMilestone(MissionData, book, first.id, firstTarget - 1)
check(stripe == nil and reason == "not_yet", "D: a milestone waits for its entries (server count)")
check(#Daily.readyMilestones(MissionData, book, firstTarget - 1) == 0, "D: nothing ready below the first target")
check(Daily.readyMilestones(MissionData, book, firstTarget)[1] == first.id, "D: the first milestone is ready at its target")
stripe, reason = Daily.claimMilestone(MissionData, book, first.id, firstTarget)
check(stripe == first.stripe and reason == nil, "D: the milestone gives its stripes")
check(book.stripes[first.stripe] == true and book.wear == first.stripe, "D: owned and worn at once")
stripe, reason = Daily.claimMilestone(MissionData, book, first.id, 999)
check(stripe == nil and reason == "claimed", "D: a milestone pays once")
stripe, reason = Daily.claimMilestone(MissionData, book, "everything", 999)
check(stripe == nil and reason == "unknown", "D: unknown milestones are refused")
local secondMilestone = Daily.MILESTONES[2]
Daily.claimMilestone(MissionData, book, secondMilestone.id, 999)
check(book.wear == first.stripe and book.stripes[secondMilestone.stripe] == true, "D: a later reward never changes the stripes worn")

-- Fresh craters and fun facts.
check(Daily.addMeteor(book) and book.meteors == 1, "D: a fresh crater counts")
check(Daily.addFact(book, 7, 50) and book.facts["funfact.07"] == true, "D: a fun fact is remembered")
check(not Daily.addFact(book, 7, 50), "D: the same fact only once")
check(not Daily.addFact(book, 0, 50) and not Daily.addFact(book, 51, 50) and not Daily.addFact(book, 2.5, 50) and not Daily.addFact(book, "3", 50), "D: bad fact numbers are refused")
check(Daily.factList(book)[1] == "funfact.07", "D: the facts list")

----------------------------------------------------------------------------------------------------
-- E. Saves: old saves, damaged saves, merges, DataStore shape
local fromNil = Daily.sanitizeRecord(nil)
check(fromNil.opened == 0 and fromNil.lastDay == 0 and fromNil.wear == "none" and next(fromNil.stripes) == nil, "E: an old save without the field starts empty")
local damaged = Daily.sanitizeRecord({
	opened = -5,
	lastDay = 0 / 0,
	stripes = { sunrise = true, rainbow = true, ice = "yes" },
	wear = "rainbow",
	milestones = { first_page = true, cheat = true },
	meteors = 3.7,
	facts = { ["funfact.03"] = true, hack = true, ["funfact.4"] = true },
})
check(damaged.opened == 0 and damaged.lastDay == 0, "E: bad numbers become 0")
check(damaged.stripes.sunrise == true and damaged.stripes.rainbow == nil and damaged.stripes.ice == nil, "E: only known stripes set to true")
check(damaged.wear == "none", "E: wearing something not owned is dropped")
check(damaged.milestones.first_page == true and damaged.milestones.cheat == nil, "E: only known milestones")
check(damaged.meteors == 3, "E: counts are whole")
check(damaged.facts["funfact.03"] == true and damaged.facts.hack == nil and damaged.facts["funfact.4"] == nil, "E: only fun fact keys")
local wearsOwned = Daily.sanitizeRecord({ stripes = { ice = true }, wear = "ice" })
check(wearsOwned.wear == "ice", "E: owned stripes stay worn")

local stored = { opened = 9, lastDay = 20000, stripes = { sunrise = true }, wear = "sunrise", milestones = { first_page = true }, meteors = 4, facts = { ["funfact.01"] = true } }
local current = { opened = 8, lastDay = 19999, stripes = { ice = true }, wear = "ice", milestones = {}, meteors = 6, facts = { ["funfact.02"] = true } }
local merged = Daily.mergeRecord(stored, current)
check(merged.opened == 9 and merged.lastDay == 20000, "E: a merge keeps the most capsules and the latest day (no extra capsule)")
check(merged.stripes.sunrise and merged.stripes.ice, "E: a merge keeps every stripe")
check(merged.milestones.first_page == true, "E: a merge keeps claimed milestones")
check(merged.meteors == 6, "E: a merge keeps the highest crater count")
check(merged.facts["funfact.01"] and merged.facts["funfact.02"], "E: a merge keeps every fact")
check(merged.wear == "ice", "E: what is worn now is this server's choice")
check(Daily.mergeRecord(stored, nil).wear == "sunrise", "E: no record here keeps the stored choice")
local clone = Daily.cloneRecord(merged)
clone.stripes.garden = true
check(merged.stripes.garden == nil, "E: clones do not share tables")

-- DataStore shape: only string keys, booleans, numbers and strings, at most two levels deep.
local function storable(value: any, depth: number): boolean
	if type(value) ~= "table" then
		return type(value) == "number" or type(value) == "string" or type(value) == "boolean"
	end
	if depth > 2 then
		return false
	end
	for key, item in value do
		if type(key) ~= "string" or not storable(item, depth + 1) then
			return false
		end
	end
	return true
end
check(storable(merged, 1), "E: the record has string keys only (a DataStore can hold it)")
check(storable(Daily.emptyRecord(), 1), "E: an empty record is storable")

----------------------------------------------------------------------------------------------------
-- F. No randomness and no Roblox: the module never calls math.random, Random or os.time itself.
do
	local source = string.gsub(fs.readFile("src/shared/Daily.luau"), "%-%-[^\n]*", "")
	check(string.find(source, "math.random", 1, true) == nil and string.find(source, "Random.new", 1, true) == nil, "F: no randomness in the rules")
	check(string.find(source, "os.time", 1, true) == nil, "F: the time always comes from the caller (the server)")
	check(string.find(source, "Instance", 1, true) == nil and string.find(source, "require", 1, true) == nil, "F: pure module")
	check(string.find(fs.readFile("src/shared/Daily.luau"), "^%-%-!strict") ~= nil, "F: --!strict")
	for _, file in { "src/shared/Daily.luau", "src/server/DailyService.luau", "src/client/DailyCapsule.luau", "src/client/Collection.luau" } do
		local text = fs.readFile(file)
		check(string.sub(text, 1, 9) == "--!strict", `F: {file} starts with --!strict`)
		check(string.find(text, "SI disclosure", 1, true) ~= nil, `F: {file} has the SI disclosure line`)
	end
	-- The server decides the day: DailyService passes its own os.time() to the rules.
	local service = fs.readFile("src/server/DailyService.luau")
	check(string.find(service, "Daily.claim(MissionData, data.record, os.time())", 1, true) ~= nil, "F: the server's clock opens capsules")
end

print(`daily: {passes} passed, {failures} failed`)
if failures > 0 then
	error("daily tests failed")
end
