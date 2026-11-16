--!strict
-- Space Base Odyssey - Stage 11 "safer server": the pure rules behind the server's checks, so they
-- run in Lune (tests/worlds and tests/missions). No Roblox instances here.
--   * Session lock: a save slot record holds `lock = { job, token, at }` (the server and the visit
--     that may write it, and os.time() of its last write). A server loads a slot only after it takes
--     the lock (UpdateAsync); a lock another visit refreshed within the timeout makes it wait, an older
--     one is stale and may be stolen. A write from a visit that no longer holds the lock is refused,
--     so a quick server hop can never duplicate or overwrite credits.
--   * Player settings (language, music and effects volume, C.A.R.L. fun facts and guidance), kept in
--     the player's meta record so they survive teleports and rejoins. SaveSettings patches are checked
--     and clamped here.
--   * Ice travel: an ice core cannot reach the water machine faster than the fastest legal way to
--     carry it (MissionData.GUARD.ICE_TRAVEL_MAX_SPEED), and drilling is limited per minute.
--   * Ice hauler payments: each core pays the player who loaded it (or the unloader when that player
--     left).
--   * Open-world dust: a gentle timer that covers one solar panel with dust between missions.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ServerGuard = {}

----------------------------------------------------------------------------------------------------
-- Session lock

export type Lock = {
	job: string, -- the server (game.JobId, or a generated id in Studio)
	token: string, -- this visit's load (a new token every time a slot loads)
	at: number, -- os.time() when the lock was taken or last refreshed
}

-- "take" = the lock is free or stale (take it), "own" = this visit holds it, "wait" = another visit
-- holds a fresh lock.
export type LockDecision = "take" | "own" | "wait"

local MAX_ID_LENGTH = 64

local function isId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

-- A stored lock, checked (anything damaged counts as no lock).
function ServerGuard.sanitizeLock(value: any): Lock?
	if type(value) ~= "table" or not isId(value.job) or not isId(value.token) then
		return nil
	end
	local at = value.at
	if type(at) ~= "number" or at ~= at or at == math.huge or at == -math.huge then
		return nil
	end
	return { job = value.job, token = value.token, at = at }
end

-- What a visit (job, token) may do with the stored lock at time `now`. A lock not refreshed for more
-- than `timeout` seconds is stale (its server crashed or never released it).
function ServerGuard.lockDecision(stored: any, job: string, token: string, now: number, timeout: number): LockDecision
	local lock = ServerGuard.sanitizeLock(stored)
	if lock == nil then
		return "take"
	end
	if lock.job == job and lock.token == token then
		return "own"
	end
	if now - lock.at > timeout or lock.at - now > timeout then
		return "take" -- stale (or stamped far in the future by a broken clock)
	end
	return "wait"
end

-- True when this visit still holds the lock (a write is allowed). A missing lock means another visit
-- took it and released it: this visit lost it. Stage 11 review: `allowFree` = a missing lock may be
-- taken back (the caller passes it only for a regular save while the player still plays on this
-- server: then the lock was dropped by an older server version that knows no locks, during the first
-- hours after this update; a player cannot play on two servers at once). A lock held by another
-- visit is never overwritten.
function ServerGuard.canWrite(stored: any, job: string, token: string, allowFree: boolean?): boolean
	local lock = ServerGuard.sanitizeLock(stored)
	if lock == nil then
		return allowFree == true
	end
	return lock.job == job and lock.token == token
end

-- True for a slot record with no game data (nothing stored, or only the version and a lock): it loads
-- as a new game, and slot 1 then reads the save from before slots.
function ServerGuard.isEmptySlotRecord(value: any): boolean
	if type(value) ~= "table" then
		return true
	end
	for key in value do
		if key ~= "v" and key ~= "lock" then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Player settings

export type Language = "en" | "es"
export type Settings = {
	language: Language?, -- nil = follow the device language
	musicVolume: number, -- 0..1
	effectsVolume: number, -- 0..1
	funFacts: boolean,
	guidance: boolean,
}

-- UI defaults (not gameplay numbers), the same as the client Store's.
local DEFAULT_SETTINGS: Settings = table.freeze({
	language = nil,
	musicVolume = 0.6,
	effectsVolume = 0.8,
	funFacts = true,
	guidance = true,
})
local VOLUME_STEP = 0.01

ServerGuard.SETTING_NAMES = table.freeze({ "language", "musicVolume", "effectsVolume", "funFacts", "guidance" })

function ServerGuard.defaultSettings(): Settings
	return table.clone(DEFAULT_SETTINGS)
end

local function cleanVolume(value: any): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	local clamped = math.clamp(value, 0, 1)
	return math.floor(clamped / VOLUME_STEP + 0.5) * VOLUME_STEP
end

local function cleanLanguage(value: any): Language?
	if value == "en" or value == "es" then
		return value
	end
	return nil
end

-- Applies the valid fields of `patch` to a copy of `current`. Unknown fields and bad values are
-- ignored; volumes are clamped to 0..1 (steps of 0.01). Returns the new settings and whether
-- anything changed.
function ServerGuard.applySettings(current: Settings, patch: any): (Settings, boolean)
	local result = table.clone(current)
	if type(patch) ~= "table" then
		return result, false
	end
	local changed = false
	local language = cleanLanguage(patch.language)
	if language ~= nil and language ~= result.language then
		result.language = language
		changed = true
	end
	for _, name in { "musicVolume", "effectsVolume" } do
		local volume = cleanVolume(patch[name])
		if volume ~= nil and volume ~= (result :: any)[name] then
			(result :: any)[name] = volume
			changed = true
		end
	end
	for _, name in { "funFacts", "guidance" } do
		local flag = patch[name]
		if type(flag) == "boolean" and flag ~= (result :: any)[name] then
			(result :: any)[name] = flag
			changed = true
		end
	end
	return result, changed
end

-- Stored settings (or anything damaged) -> clean settings; missing fields keep their defaults.
function ServerGuard.sanitizeSettings(value: any): Settings
	local settings = ServerGuard.applySettings(ServerGuard.defaultSettings(), value)
	return settings
end

----------------------------------------------------------------------------------------------------
-- Ice travel and rate limits

-- The shortest time an ice core needs to travel `distance` studs at `maxSpeed` studs per second.
function ServerGuard.minTravelSeconds(distance: number, maxSpeed: number): number
	if maxSpeed <= 0 or distance <= 0 then
		return 0
	end
	return distance / maxSpeed
end

-- True when `elapsed` seconds are enough to bring a core `distance` studs at `maxSpeed`.
function ServerGuard.travelOk(distance: number, elapsed: number, maxSpeed: number): boolean
	return elapsed >= ServerGuard.minTravelSeconds(distance, maxSpeed)
end

-- A sliding window: `times` holds the moments of earlier accepted events. Drops the ones older than
-- `window` seconds, then accepts this one (adds `now`) when fewer than `max` remain, and when the last
-- accepted event is at least `minGap` seconds ago. Returns true when accepted.
function ServerGuard.allowInWindow(times: { number }, now: number, window: number, max: number, minGap: number?): boolean
	local index = 1
	while index <= #times do
		if now - times[index] >= window then
			table.remove(times, index)
		else
			index += 1
		end
	end
	local last = times[#times]
	if minGap and last ~= nil and now - last < minGap then
		return false
	end
	if #times >= max then
		return false
	end
	table.insert(times, now)
	return true
end

----------------------------------------------------------------------------------------------------
-- Ice hauler payments

-- Who gets paid for unloaded cores: `loaders` lists the UserId that loaded each core; a loader who is
-- not here any more (isPresent false) leaves their core to `unloader`. Returns UserId -> cores, and
-- the order the payees first appear in (so payments run in a stable order).
function ServerGuard.splitCores(loaders: { number }, isPresent: (userId: number) -> boolean, unloader: number): ({ [number]: number }, { number })
	local counts: { [number]: number } = {}
	local order: { number } = {}
	for _, userId in loaders do
		local payee = if isPresent(userId) then userId else unloader
		if counts[payee] == nil then
			counts[payee] = 0
			table.insert(order, payee)
		end
		counts[payee] += 1
	end
	return counts, order
end

----------------------------------------------------------------------------------------------------
-- Open-world dust

-- True when the open base should cover one more solar panel with dust: there are standing arrays
-- without dust, fewer dusty arrays than `maxDusty`, and `every` seconds passed since the last dust
-- (or `first` seconds since the base opened, when there was none yet).
function ServerGuard.roamDustDue(
	openSince: number,
	lastDustAt: number?,
	now: number,
	first: number,
	every: number,
	dustyCount: number,
	standingArrays: number,
	maxDusty: number
): boolean
	if standingArrays <= 0 or dustyCount >= math.min(maxDusty, standingArrays) then
		return false
	end
	if lastDustAt == nil then
		return now - openSince >= first
	end
	return now - math.max(lastDustAt, openSince) >= every
end

return table.freeze(ServerGuard)
