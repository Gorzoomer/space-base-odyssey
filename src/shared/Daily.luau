--!strict
-- Space Base Odyssey - Stage 11: the daily supply capsule and the Moon Logbook (pure rules).
-- No Roblox instances and no require: it runs in Lune (tests/daily.luau) as well as in Roblox.
-- Numbers come from MissionData (passed in as `data`): DAILY and LOGBOOK, all GAME values.
--
-- Daily supply capsule (server: DailyService.luau, client: DailyCapsule.luau):
--   * Once per real day, counted in UTC days from the SERVER's os.time() (the client clock is never
--     trusted), one capsule can be opened (Action ClaimDaily).
--   * A 7-day calendar shows every reward in advance (data.DAILY.CALENDAR): no randomness, no loot box.
--   * Forgiving streak: the calendar position is the number of capsules opened, not days in a row.
--     Missing a day only pauses it; nothing is ever taken away.
--   * Day 7 gives suit stripes (a look only) from data.DAILY.WEEK_STRIPES: week 1, week 2, ... Once
--     every weekly stripe is owned, day 7 pays data.DAILY.STRIPE_DONE_CREDITS instead.
--   * Every capsule card shows one "cargo fact" (Daily.CARGO_FACTS, in order). The facts quote no
--     numbers and only repeat science that DATA_SOURCES.md already backs (tests/daily checks this).
--   * The capsule is a game gift: the card says it is not a real NASA flight.
-- Moon Logbook (client: Collection.luau): pages of what the player found. Entries that count are the
-- four secrets, the exploration sites, the first data.LOGBOOK.METEOR_PAGE fresh craters scanned and
-- the learning achievements (all known to the server). Fun facts C.A.R.L. shared and the cargo facts
-- of opened capsules are kept on a facts page but never count (the server cannot see them heard).
-- Filling data.LOGBOOK.MILESTONE_ENTRIES[id] entries lets the player claim that milestone's stripes
-- (Action ClaimLogbook, checked on the server against its own count).
--
-- Saved record (base field `daily` of the save slot, ProgressService): see Record. Saves only grow:
-- mergeRecord keeps the most capsules, the latest day, every stripe, milestone and fact.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type RewardKind = "credits" | "xp" | "stripe"

-- One capsule of the calendar. capsule = its number since the first capsule (1, 2, ...).
export type Reward = {
	capsule: number,
	day: number, -- 1..#data.DAILY.CALENDAR
	week: number,
	kind: RewardKind,
	amount: number, -- credits or XP (0 for stripes)
	stripe: string?, -- stripe id for kind "stripe"
}

-- "done" = opened, "today" = waiting to be opened now, "later" = a day still to come.
export type CalendarDay = Reward & { state: "done" | "today" | "later" }

export type Calendar = {
	week: number,
	ready: boolean, -- a capsule is waiting today
	days: { CalendarDay },
	factKey: string, -- the cargo fact on the card (today's capsule, or the last one opened)
}

export type Record = {
	opened: number, -- capsules opened in total
	lastDay: number, -- UTC day number of the last capsule opened (0 = never)
	stripes: { [string]: boolean }, -- owned suit stripes
	wear: string, -- "none" or an owned stripe id
	milestones: { [string]: boolean }, -- claimed logbook milestones
	meteors: number, -- fresh craters scanned for the first time, lifetime
	facts: { [string]: boolean }, -- fun facts C.A.R.L. shared ("funfact.07" keys)
}

export type Stripe = {
	id: string,
	colors: { string }, -- two Theme.PALETTE names: upper band, lower band
	source: "daily" | "logbook",
}

export type Milestone = {
	id: string,
	stripe: string,
}

-- What the server knows for the logbook count (DailyService builds it).
export type LogbookFacts = {
	secrets: number,
	secretTotal: number,
	sites: number,
	siteTotal: number,
	meteors: number,
	achievements: number,
	achievementTotal: number,
}

local Daily = {}

-- Seconds in a day: a unit, not a gameplay number. Days are counted from the Unix epoch (UTC).
local DAY_SECONDS = 24 * 60 * 60
local MAX_COUNT = 100000 -- damaged saves cannot grow without limit
local MAX_FACTS = 200
local FACT_PATTERN = "^funfact%.%d%d%d?$"

Daily.DAY_SECONDS = DAY_SECONDS

-- Suit stripes: two coloured bands on each upper arm (DailyService welds them on). Colours are
-- Theme.PALETTE names so the look stays "Lunar Sunrise".
local STRIPES: { Stripe } = {
	{ id = "sunrise", colors = { "orange", "gold" }, source = "daily" },
	{ id = "ice", colors = { "cyan", "cream" }, source = "daily" },
	{ id = "garden", colors = { "lime", "cyan" }, source = "daily" },
	{ id = "star", colors = { "gold", "cream" }, source = "logbook" },
	{ id = "secret", colors = { "magenta", "gold" }, source = "logbook" },
	{ id = "lunar", colors = { "cyan", "magenta" }, source = "logbook" },
}

-- Logbook milestones in order; their entry targets are data.LOGBOOK.MILESTONE_ENTRIES[id].
local MILESTONES: { Milestone } = {
	{ id = "first_page", stripe = "star" },
	{ id = "half_book", stripe = "secret" },
	{ id = "moon_expert", stripe = "lunar" },
}

-- Cargo facts, one per capsule in this order (then again from the first). Localization keys.
local CARGO_FACTS: { string } = {
	"daily.fact.1",
	"daily.fact.2",
	"daily.fact.3",
	"daily.fact.4",
	"daily.fact.5",
	"daily.fact.6",
	"daily.fact.7",
}

local stripeById: { [string]: Stripe } = {}
for _, stripe in STRIPES do
	table.freeze(stripe.colors)
	table.freeze(stripe)
	stripeById[stripe.id] = stripe
end
local milestoneById: { [string]: Milestone } = {}
for _, milestone in MILESTONES do
	table.freeze(milestone)
	milestoneById[milestone.id] = milestone
end

Daily.STRIPES = table.freeze(STRIPES)
Daily.MILESTONES = table.freeze(MILESTONES)
Daily.CARGO_FACTS = table.freeze(CARGO_FACTS)

function Daily.isStripe(id: any): boolean
	return type(id) == "string" and stripeById[id] ~= nil
end

function Daily.stripe(id: any): Stripe?
	return if type(id) == "string" then stripeById[id] else nil
end

function Daily.isMilestone(id: any): boolean
	return type(id) == "string" and milestoneById[id] ~= nil
end

function Daily.stripeNameKey(id: string): string
	return "stripe." .. id .. ".name"
end

----------------------------------------------------------------------------------------------------
-- Days

-- The UTC day number of a Unix time (os.time()).
function Daily.dayNumber(time: number): number
	return math.floor(time / DAY_SECONDS)
end

-- Seconds until the next UTC day starts.
function Daily.secondsToNextDay(time: number): number
	return DAY_SECONDS - (math.floor(time) % DAY_SECONDS)
end

----------------------------------------------------------------------------------------------------
-- Record helpers

function Daily.emptyRecord(): Record
	return { opened = 0, lastDay = 0, stripes = {}, wear = "none", milestones = {}, meteors = 0, facts = {} }
end

local function wholeCount(value: any): number
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	return math.min(math.floor(value), MAX_COUNT)
end

-- Any stored value -> a clean Record (unknown ids dropped, counts whole and >= 0).
function Daily.sanitizeRecord(value: any): Record
	local record = Daily.emptyRecord()
	if type(value) ~= "table" then
		return record
	end
	record.opened = wholeCount(value.opened)
	local lastDay = value.lastDay
	if type(lastDay) == "number" and lastDay == lastDay and lastDay > 0 and lastDay < 1e7 then
		record.lastDay = math.floor(lastDay)
	end
	if type(value.stripes) == "table" then
		for id, flag in value.stripes do
			if flag == true and Daily.isStripe(id) then
				record.stripes[id] = true
			end
		end
	end
	if type(value.milestones) == "table" then
		for id, flag in value.milestones do
			if flag == true and Daily.isMilestone(id) then
				record.milestones[id] = true
			end
		end
	end
	record.meteors = wholeCount(value.meteors)
	if type(value.facts) == "table" then
		local count = 0
		for key, flag in value.facts do
			if count >= MAX_FACTS then
				break
			end
			if flag == true and type(key) == "string" and string.match(key, FACT_PATTERN) then
				record.facts[key] = true
				count += 1
			end
		end
	end
	if type(value.wear) == "string" and record.stripes[value.wear] then
		record.wear = value.wear
	end
	return record
end

function Daily.cloneRecord(record: Record): Record
	return {
		opened = record.opened,
		lastDay = record.lastDay,
		stripes = table.clone(record.stripes),
		wear = record.wear,
		milestones = table.clone(record.milestones),
		meteors = record.meteors,
		facts = table.clone(record.facts),
	}
end

-- Stored + this server's record (another server may have saved meanwhile): the most capsules, the
-- latest day, every stripe, milestone and fact; what is worn now is this server's choice.
function Daily.mergeRecord(stored: any, current: any): Record
	local old = Daily.sanitizeRecord(stored)
	local merged = Daily.sanitizeRecord(current)
	merged.opened = math.max(merged.opened, old.opened)
	merged.lastDay = math.max(merged.lastDay, old.lastDay)
	merged.meteors = math.max(merged.meteors, old.meteors)
	for id in old.stripes do
		merged.stripes[id] = true
	end
	for id in old.milestones do
		merged.milestones[id] = true
	end
	for key in old.facts do
		merged.facts[key] = true
	end
	if current == nil and old.wear ~= "none" then
		merged.wear = old.wear
	end
	return merged
end

----------------------------------------------------------------------------------------------------
-- Daily capsule

local function calendarLength(data: any): number
	return math.max(1, #data.DAILY.CALENDAR)
end

-- True when a capsule is waiting today (never twice on one UTC day; a clock that went back waits).
function Daily.isReady(record: Record, time: number): boolean
	return Daily.dayNumber(time) > record.lastDay
end

-- The reward of capsule number `capsule` (1-based): fixed by its day and week, never random.
function Daily.rewardFor(data: any, capsule: number): Reward
	local length = calendarLength(data)
	local index = math.max(1, math.floor(capsule))
	local day = (index - 1) % length + 1
	local week = (index - 1) // length + 1
	local entry = data.DAILY.CALENDAR[day]
	local kind: RewardKind = if entry and (entry.kind == "xp" or entry.kind == "stripe") then entry.kind else "credits"
	local amount = if entry and type(entry.amount) == "number" then entry.amount else 0
	local reward: Reward = { capsule = index, day = day, week = week, kind = kind, amount = amount, stripe = nil }
	if kind == "stripe" then
		local stripe = data.DAILY.WEEK_STRIPES[week]
		if Daily.isStripe(stripe) then
			reward.stripe = stripe
			reward.amount = 0
		else
			reward.kind = "credits"
			reward.amount = data.DAILY.STRIPE_DONE_CREDITS
		end
	end
	return reward
end

-- The cargo fact on capsule number `capsule` (1-based, cycling through Daily.CARGO_FACTS).
function Daily.factKey(capsule: number): string
	local index = (math.max(1, math.floor(capsule)) - 1) % #CARGO_FACTS + 1
	return CARGO_FACTS[index]
end

-- The week the calendar shows: the week of today's capsule while one waits, else the week of the
-- last capsule opened (a finished week stays on screen, all done, until the next day).
function Daily.calendar(data: any, record: Record, time: number): Calendar
	local length = calendarLength(data)
	local ready = Daily.isReady(record, time)
	local shown = if ready then record.opened + 1 else math.max(1, record.opened)
	local weekStart = ((shown - 1) // length) * length
	local days: { CalendarDay } = {}
	for i = 1, length do
		local capsule = weekStart + i
		local reward = Daily.rewardFor(data, capsule) :: any
		if capsule <= record.opened then
			reward.state = "done"
		elseif ready and capsule == record.opened + 1 then
			reward.state = "today"
		else
			reward.state = "later"
		end
		table.insert(days, reward :: CalendarDay)
	end
	return {
		week = weekStart // length + 1,
		ready = ready,
		days = days,
		factKey = Daily.factKey(shown),
	}
end

-- Opens today's capsule. Returns its reward, or nil and why ("not_ready"). Changes the record:
-- one more capsule, today's day, and the stripes (worn at once if nothing else is worn).
function Daily.claim(data: any, record: Record, time: number): (Reward?, string?)
	if not Daily.isReady(record, time) then
		return nil, "not_ready"
	end
	local reward = Daily.rewardFor(data, record.opened + 1)
	record.opened = math.min(record.opened + 1, MAX_COUNT)
	record.lastDay = Daily.dayNumber(time)
	if reward.kind == "stripe" and reward.stripe then
		local id = reward.stripe :: string
		record.stripes[id] = true
		if record.wear == "none" then
			record.wear = id
		end
	end
	return reward, nil
end

-- Wear owned stripes ("none" takes them off). Returns true when the choice is allowed.
function Daily.wear(record: Record, id: any): boolean
	if id == "none" then
		record.wear = "none"
		return true
	end
	if type(id) == "string" and record.stripes[id] == true then
		record.wear = id
		return true
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- Moon Logbook

-- One more fresh crater scanned (the first scan of each one). Returns true if it changed.
function Daily.addMeteor(record: Record): boolean
	if record.meteors >= MAX_COUNT then
		return false
	end
	record.meteors += 1
	return true
end

-- Remembers fun fact number `index` (1..count). Returns true if it is new.
function Daily.addFact(record: Record, index: any, count: number): boolean
	if type(index) ~= "number" or index ~= index or index ~= math.floor(index) or index < 1 or index > count then
		return false
	end
	local key = string.format("funfact.%02d", index)
	if record.facts[key] then
		return false
	end
	local total = 0
	for _ in record.facts do
		total += 1
	end
	if total >= MAX_FACTS then
		return false
	end
	record.facts[key] = true
	return true
end

-- Fun facts heard, sorted ("funfact.01", ...).
function Daily.factList(record: Record): { string }
	local list: { string } = {}
	for key in record.facts do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

-- Entries filled and entries in the whole book (the meteor page has data.LOGBOOK.METEOR_PAGE slots).
function Daily.logbookEntries(data: any, facts: LogbookFacts): (number, number)
	local page = data.LOGBOOK.METEOR_PAGE
	local function clampCount(n: number, total: number): number
		return math.clamp(math.floor(n), 0, math.max(0, total))
	end
	local filled = clampCount(facts.secrets, facts.secretTotal)
		+ clampCount(facts.sites, facts.siteTotal)
		+ clampCount(facts.meteors, page)
		+ clampCount(facts.achievements, facts.achievementTotal)
	local total = math.max(0, facts.secretTotal) + math.max(0, facts.siteTotal) + page + math.max(0, facts.achievementTotal)
	return filled, total
end

-- Entries a milestone needs (0 = unknown milestone, never ready).
function Daily.milestoneTarget(data: any, id: string): number
	local targets = data.LOGBOOK.MILESTONE_ENTRIES
	local value = if Daily.isMilestone(id) and targets then targets[id] else nil
	return if type(value) == "number" and value > 0 then value else 0
end

function Daily.milestoneReady(data: any, record: Record, id: string, entries: number): boolean
	local target = Daily.milestoneTarget(data, id)
	return target > 0 and entries >= target and not record.milestones[id]
end

-- Milestones that could be claimed now, in order.
function Daily.readyMilestones(data: any, record: Record, entries: number): { string }
	local list: { string } = {}
	for _, milestone in MILESTONES do
		if Daily.milestoneReady(data, record, milestone.id, entries) then
			table.insert(list, milestone.id)
		end
	end
	return list
end

-- Claims a milestone with `entries` counted by the server. Returns its stripe id, or nil and why
-- ("unknown", "claimed", "not_yet"). The stripes are worn at once if nothing else is worn.
function Daily.claimMilestone(data: any, record: Record, id: any, entries: number): (string?, string?)
	if not Daily.isMilestone(id) then
		return nil, "unknown"
	end
	if record.milestones[id] then
		return nil, "claimed"
	end
	if not Daily.milestoneReady(data, record, id, entries) then
		return nil, "not_yet"
	end
	local stripe = (milestoneById[id] :: Milestone).stripe
	record.milestones[id] = true
	record.stripes[stripe] = true
	if record.wear == "none" then
		record.wear = stripe
	end
	return stripe, nil
end

-- Owned stripes in Daily.STRIPES order.
function Daily.stripeList(record: Record): { string }
	local list: { string } = {}
	for _, stripe in STRIPES do
		if record.stripes[stripe.id] then
			table.insert(list, stripe.id)
		end
	end
	return list
end

return table.freeze(Daily)
