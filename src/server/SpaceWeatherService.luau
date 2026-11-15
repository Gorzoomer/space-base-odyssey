--!strict
-- Space Base Odyssey - live space weather from NASA / CCMC DONKI, with the saved archive as backup.
-- At server start it asks DONKI for the solar flares (FLR) and solar energetic particle events (SEP)
-- of the last 30 days. A flare "has particles" when DONKI links it to an SEP event measured by the
-- GOES satellites. These events were observed near Earth: the game replays them as "what if a storm
-- like this reached your base", never as something that hit the Moon.
-- Honesty rule: only flares returned by this server's own live query are labelled "live". Everything
-- else comes from SpaceWeatherArchive and is labelled "archive".
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpaceWeatherArchive = require(Shared:WaitForChild("SpaceWeatherArchive"))
local Types = require(Shared:WaitForChild("Types"))

type LiveWeather = Types.LiveWeather
type ArchivedFlare = SpaceWeatherArchive.ArchivedFlare

-- Technical settings of the live query (not gameplay numbers).
local DONKI_BASE_URL = "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/"
local QUERY_DAYS = 30 -- DONKI allows up to 60 days per request
local FETCH_BUDGET_SECONDS = 15 -- overall budget for both requests
local POLL_SECONDS = 0.1
local SECONDS_PER_DAY = 86400
-- Live flares strong enough to replay as a storm: M5 or stronger (5e-5 W/m^2 peak X-ray flux).
local MIN_REPLAY_FLUX = 5e-5
local CLASS_BASE_FLUX: { [string]: number } = { A = 1e-8, B = 1e-7, C = 1e-6, M = 1e-5, X = 1e-4 }
-- A live flare with no linked particle event is only replayed as a false alarm once it is this old:
-- particles take hours to arrive and DONKI links them later, so a fresh flare's "no particles" is not
-- settled yet and C.A.R.L. must not claim it.
local FALSE_ALARM_MIN_AGE_SECONDS = 2 * SECONDS_PER_DAY

export type FlareSource = "live" | "archive"
-- What the mission needs from the replayed flare: "particles" = a flare DONKI links to a particle
-- storm, "none" = a big flare without one (a real false alarm), "any" = either.
export type FlareWant = "particles" | "none" | "any"

local SpaceWeatherService = {}

local started = false
local live: LiveWeather? = nil -- nil while the first query is still running
local liveFlares: { ArchivedFlare } = {} -- every flare from the live query, already parsed
local listeners: { (LiveWeather) -> () } = {}

----------------------------------------------------------------------------------------------------
-- Pure helpers (no Roblox instances; tested in Lune with a mocked HttpService)

local function isoDate(unixSeconds: number): string
	local t = os.date("!*t", unixSeconds) :: any
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function isoTime(unixSeconds: number): string
	local t = os.date("!*t", unixSeconds) :: any
	return string.format("%04d-%02d-%02dT%02d:%02dZ", t.year, t.month, t.day, t.hour, t.min)
end

-- Peak X-ray flux of a GOES class such as "M1.3" or "X10.0"; nil when the text is not a class.
local function classFlux(classType: any): number?
	if type(classType) ~= "string" then
		return nil
	end
	local letter, magnitude = string.match(classType, "^%s*([ABCMX])(%d+%.?%d*)")
	if letter == nil or magnitude == nil then
		return nil
	end
	local base = CLASS_BASE_FLUX[letter]
	local value = tonumber(magnitude)
	if base == nil or value == nil then
		return nil
	end
	return base * value
end

local function hasGoesInstrument(instruments: any): (boolean, boolean)
	local goes, above100 = false, false
	if type(instruments) ~= "table" then
		return false, false
	end
	for _, instrument in instruments do
		local name = type(instrument) == "table" and instrument.displayName
		if type(name) == "string" and string.find(name, "GOES", 1, true) then
			goes = true
			if string.find(name, ">100", 1, true) then
				above100 = true
			end
		end
	end
	return goes, above100
end

local function linkedIds(linkedEvents: any): { string }
	local ids = {}
	if type(linkedEvents) == "table" then
		for _, event in linkedEvents do
			local id = type(event) == "table" and event.activityID
			if type(id) == "string" then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

-- Turns decoded DONKI FLR and SEP lists into flares (same shape as the archive) plus a summary.
-- DONKI links flares and SEPs in both directions, but not always on both records, so both are read.
function SpaceWeatherService._parse(flrList: any, sepList: any, fetchedAt: string): ({ ArchivedFlare }, LiveWeather)
	-- sepID -> { goes, above100 }, and flrID -> particle info from SEP records that name the flare.
	local seps: { [string]: { goes: boolean, above100: boolean } } = {}
	local fromSep: { [string]: { above100: boolean } } = {}
	if type(sepList) == "table" then
		for _, sep in sepList do
			if type(sep) == "table" and type(sep.sepID) == "string" then
				local goes, above100 = hasGoesInstrument(sep.instruments)
				seps[sep.sepID] = { goes = goes, above100 = above100 }
				if goes then
					for _, id in linkedIds(sep.linkedEvents) do
						local known = fromSep[id]
						fromSep[id] = { above100 = above100 or (known ~= nil and known.above100) }
					end
				end
			end
		end
	end

	local flares: { ArchivedFlare } = {}
	local strongest: ArchivedFlare? = nil
	local strongestFlux = -1
	local latest: ArchivedFlare? = nil
	if type(flrList) == "table" then
		for _, record in flrList do
			if type(record) ~= "table" or type(record.flrID) ~= "string" then
				continue
			end
			local flux = classFlux(record.classType)
			local peak = record.peakTime
			if flux == nil or type(peak) ~= "string" then
				continue
			end
			local particles, above100 = false, false
			local viaSep = fromSep[record.flrID]
			if viaSep then
				particles = true
				above100 = viaSep.above100
			end
			for _, id in linkedIds(record.linkedEvents) do
				local sep = seps[id]
				if sep and sep.goes then
					particles = true
					above100 = above100 or sep.above100
				end
			end
			local flare: ArchivedFlare = table.freeze({
				id = record.flrID,
				date = peak,
				class = record.classType,
				particles = particles,
				above100MeV = above100,
			})
			table.insert(flares, flare)
			if flux > strongestFlux then
				strongestFlux = flux
				strongest = flare
			end
			if latest == nil or peak > (latest :: ArchivedFlare).date then
				latest = flare
			end
		end
	end

	local summary: LiveWeather = {
		status = "live",
		fetchedAt = fetchedAt,
		flaresLast30Days = #flares,
		strongestClass = if strongest then strongest.class else nil,
		strongestDate = if strongest then string.sub(strongest.date, 1, 10) else nil,
		latestClass = if latest then latest.class else nil,
		latestDate = if latest then string.sub(latest.date, 1, 10) else nil,
	}
	return flares, summary
end

-- Chooses from `liveList` first, then the archive. `avoid` holds flare IDs already used this mission.
-- The flare always keeps its real `particles` value: if no flare matches `want`, the closest honest
-- choice is returned and the caller reads `particles` from it.
function SpaceWeatherService._choose(
	liveList: { ArchivedFlare },
	want: FlareWant,
	rng: Random,
	avoid: { [string]: boolean }?
): (ArchivedFlare, FlareSource)
	local function filter(list: { ArchivedFlare }, minFlux: number?, skipUsed: boolean): { ArchivedFlare }
		local pool = {}
		for _, flare in list do
			if want == "particles" and not flare.particles then
				continue
			elseif want == "none" and flare.particles then
				continue
			end
			if minFlux and (classFlux(flare.class) or 0) < minFlux then
				continue
			end
			if skipUsed and avoid and avoid[flare.id] then
				continue
			end
			table.insert(pool, flare)
		end
		return pool
	end

	for _, skipUsed in { true, false } do
		local livePool = filter(liveList, MIN_REPLAY_FLUX, skipUsed)
		if #livePool > 0 then
			return livePool[rng:NextInteger(1, #livePool)], "live"
		end
		local archivePool = filter(SpaceWeatherArchive.FLARES, nil, skipUsed)
		if #archivePool > 0 then
			return archivePool[rng:NextInteger(1, #archivePool)], "archive"
		end
	end
	-- Only reachable if the archive had no matching flare; replay any archived flare.
	local all = SpaceWeatherArchive.FLARES
	return all[rng:NextInteger(1, #all)], "archive"
end

----------------------------------------------------------------------------------------------------
-- Live query

local function setLive(value: LiveWeather)
	live = value
	for _, listener in listeners do
		task.spawn(function()
			local ok, err = pcall(listener, table.clone(value))
			if not ok then
				warn(`[SpaceBaseOdyssey] space weather listener failed: {err}`)
			end
		end)
	end
end

local function getJson(url: string): (boolean, any)
	local ok, body = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	if not ok or type(body) ~= "string" then
		return false, body
	end
	-- DONKI answers with an empty body or "[]" when there are no events.
	if string.match(body, "^%s*$") then
		return true, {}
	end
	local decoded, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not decoded or type(data) ~= "table" then
		return false, data
	end
	return true, data
end

local function fetch()
	local nowSeconds = os.time()
	local range = `startDate={isoDate(nowSeconds - QUERY_DAYS * SECONDS_PER_DAY)}&endDate={isoDate(nowSeconds)}`
	local results: { [string]: any } = {}
	local failures = 0
	local pending = 2

	for _, kind in { "FLR", "SEP" } do
		task.spawn(function()
			local ok, data = getJson(`{DONKI_BASE_URL}{kind}?{range}`)
			if ok then
				results[kind] = data
			else
				failures += 1
				warn(`[SpaceBaseOdyssey] DONKI {kind} query failed: {data}`)
			end
			pending -= 1
		end)
	end

	-- Wait for both answers, the first failure or the end of the budget. Late answers are ignored.
	local deadline = os.clock() + FETCH_BUDGET_SECONDS
	while pending > 0 and failures == 0 and os.clock() < deadline do
		task.wait(POLL_SECONDS)
	end
	if pending > 0 and failures == 0 then
		warn(`[SpaceBaseOdyssey] DONKI query took longer than {FETCH_BUDGET_SECONDS} s`)
	end
	local flrList, sepList = results.FLR, results.SEP

	-- Both lists are needed: without SEP data a flare cannot be called a particle storm or a false alarm.
	if failures > 0 or flrList == nil or sepList == nil then
		setLive({ status = "unavailable" })
		return
	end
	local flares, summary = SpaceWeatherService._parse(flrList, sepList, isoTime(nowSeconds))
	-- The summary counts every flare; the replay pool leaves out flares whose particle status is not
	-- settled yet. Peak times and the cutoff share the "YYYY-MM-DDTHH:MMZ" format, so text order works.
	local settledBefore = isoTime(nowSeconds - FALSE_ALARM_MIN_AGE_SECONDS)
	local replayable: { ArchivedFlare } = {}
	for _, flare in flares do
		if flare.particles or flare.date <= settledBefore then
			table.insert(replayable, flare)
		end
	end
	liveFlares = replayable
	setLive(summary)
	print(`[SpaceBaseOdyssey] live DONKI data: {#flares} flares in the last {QUERY_DAYS} days`)
end

----------------------------------------------------------------------------------------------------
-- Public API

-- Starts the live query in the background. Returns at once; listeners hear the result.
function SpaceWeatherService.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local httpEnabled = true
		pcall(function()
			httpEnabled = HttpService.HttpEnabled
		end)
		if not httpEnabled then
			setLive({ status = "unavailable" })
			return
		end
		local ok, err = pcall(fetch)
		if not ok then
			warn(`[SpaceBaseOdyssey] DONKI query error: {err}`)
			setLive({ status = "unavailable" })
		end
	end)
end

-- nil while the first query is still running, then "live" or "unavailable".
function SpaceWeatherService.getLive(): LiveWeather?
	if live then
		return table.clone(live)
	end
	return nil
end

-- Called with the new LiveWeather each time the query finishes.
function SpaceWeatherService.onChanged(listener: (LiveWeather) -> ())
	table.insert(listeners, listener)
end

-- Pool: live flares of class M5 or stronger, plus every archived flare. Live flares are preferred when
-- one matches `want`. `avoid` (optional) lists flare IDs already replayed this mission; they are
-- skipped while another choice exists. The returned source is "live" only for a flare from this
-- server's own live query.
function SpaceWeatherService.pickFlare(
	want: FlareWant,
	rng: Random,
	avoid: { [string]: boolean }?
): (ArchivedFlare, FlareSource)
	local liveList = if live and live.status == "live" then liveFlares else {}
	return SpaceWeatherService._choose(liveList, want, rng, avoid)
end

-- ISO time of the live query, or nil when there is no live data.
function SpaceWeatherService.getFetchedAt(): string?
	if live and live.status == "live" then
		return live.fetchedAt
	end
	return nil
end

return SpaceWeatherService
