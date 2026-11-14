--!strict
-- Space Base Odyssey - localization tests. Run with: lune run tests/localization
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.
-- Fails if a key is missing in English or Spanish, a string has more than 8 words (after
-- removing {placeholders}), placeholders differ between languages, or the lookup API misbehaves.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Localization = require("../src/shared/Localization")

local MAX_WORDS = 8

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
	["carl.storm_warning"] = { "class", "date" },
	["carl.storm_now"] = {},
	["carl.storm_over"] = {},
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
}

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
			check(words >= 1 and words <= MAX_WORDS, string.format("%s %s has %d words: %s", lang, key, words, text))
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

-- 3. Keys the simulation uses all exist (scan the shared source for quoted keys).
local KEY_PREFIXES = { "cause", "error", "event", "carl", "ui", "prompt" }
for _, file in { "src/shared/Simulation.luau", "src/shared/MissionData.luau" } do
	if fs.isFile(file) then
		local source = fs.readFile(file)
		for quoted in string.gmatch(source, '"([%a_]+%.[%w_.]+)"') do
			local prefix = string.match(quoted, "^([%a_]+)%.")
			if prefix and table.find(KEY_PREFIXES, prefix) then
				check(inKeys[quoted] == true, file .. " uses a key that is not localized: " .. quoted)
			end
		end
	end
end

-- 4. API behaviour.
check(Localization.t("ui.day", { day = 2, total = 5 }, "en") == "Day 2 of 5", "t fills placeholders (en)")
check(Localization.t("ui.day", { day = 2, total = 5 }, "es") == "Día 2 de 5", "t fills placeholders (es)")
check(Localization.t("ui.day", nil, "en") == "Day {day} of {total}", "t leaves placeholders without params")
check(Localization.t("ui.day", { day = 3 }, "en") == "Day 3 of {total}", "t keeps unknown placeholders")
check(Localization.t("ui.power_left", { n = "50%" }, "en") == "50% power left", "t inserts values literally")
check(Localization.t("no.such.key", nil, "es") == "no.such.key", "t falls back to the key")
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
