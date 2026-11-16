--!strict
-- Space Base Odyssey - private world tests (Stage 10 fix). Run with: lune run tests/worlds
-- Checks src/shared/Worlds.luau: which servers are lobbies, worlds or local; TeleportData is checked
-- (an owner's trip names the player, a guest's trip names someone else, damaged data is refused);
-- only Roblox friends join a friends world and never past the player limit; solo worlds stay
-- private; the base is always the owner's builds (never the highest of everyone present); stale
-- registry entries count as closed; and the "Join a friend" list is ordered and capped.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local MissionData = require("../src/shared/MissionData")
local Worlds = require("../src/shared/Worlds")

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

local MAX = MissionData.MISSION.PLAYERS_MAX
local OWNER = 1001
local FRIEND = 2002
local STRANGER = 3003

-- A. Server roles.
do
	check(MAX == 4, "A: the world limit is 4 players (owner + 3 friends)")
	check(Worlds.serverRole(true, 123, "", 0) == "local", "A: Studio is local")
	check(Worlds.serverRole(true, 123, "abc", 0) == "local", "A: Studio is local even in a reserved test")
	check(Worlds.serverRole(false, 0, "", 0) == "local", "A: an unpublished place is local")
	check(Worlds.serverRole(false, 123, "", 0) == "lobby", "A: a public server is the lobby")
	check(Worlds.serverRole(false, 123, "abc", 0) == "world", "A: a reserved server is a world")
	check(Worlds.serverRole(false, 123, "abc", 55) == "local", "A: a VIP server is local")
end

-- B. TeleportData.
do
	local owner = Worlds.sanitizeArrival({ owner = OWNER, slot = 2, mode = "friends", fresh = true, code = "XYZ" }, OWNER)
	check(owner ~= nil, "B: an owner's trip is accepted")
	if owner then
		check(not owner.guest and owner.slot == 2 and owner.mode == "friends" and owner.fresh, "B: owner fields kept")
		check(owner.code == "XYZ", "B: the owner's trip keeps the access code")
	end
	local solo = Worlds.sanitizeArrival({ owner = OWNER, slot = 1, mode = "solo" }, OWNER)
	check(solo ~= nil and solo.mode == "solo" and solo.fresh == false, "B: a solo trip, not fresh by default")

	local guest = Worlds.sanitizeArrival({ owner = OWNER, guest = true, slot = 3, mode = "solo", code = "XYZ" }, FRIEND)
	check(guest ~= nil, "B: a guest's trip is accepted")
	if guest then
		check(guest.guest and guest.owner == OWNER and guest.slot == 3, "B: guest fields kept")
		check(guest.mode == "friends", "B: a guest always joins a friends world")
		check(guest.code == nil, "B: a guest's trip never carries the access code")
	end

	check(Worlds.sanitizeArrival({ owner = OWNER, slot = 1, mode = "solo" }, FRIEND) == nil, "B: an owner trip naming someone else is refused")
	check(Worlds.sanitizeArrival({ owner = OWNER, guest = true, slot = 1 }, OWNER) == nil, "B: a guest of their own world is refused")
	check(Worlds.sanitizeArrival({ owner = OWNER, slot = 1 }, OWNER) == nil, "B: an owner trip needs a mode")
	check(Worlds.sanitizeArrival({ owner = OWNER, slot = 4, mode = "solo" }, OWNER) == nil, "B: slot 4 is refused")
	check(Worlds.sanitizeArrival({ owner = OWNER, slot = 1.5, mode = "solo" }, OWNER) == nil, "B: a broken slot is refused")
	check(Worlds.sanitizeArrival({ owner = -1, slot = 1, mode = "solo" }, -1) == nil, "B: a broken UserId is refused")
	check(Worlds.sanitizeArrival({ owner = "1001", slot = 1, mode = "solo" }, OWNER) == nil, "B: a text UserId is refused")
	check(Worlds.sanitizeArrival(nil, OWNER) == nil, "B: no data is refused")
	check(Worlds.sanitizeArrival({ slot = 1, mode = "solo" }, OWNER) == nil, "B: a trip with no owner is refused")
	local long = string.rep("a", Worlds.MAX_CODE_LENGTH + 1)
	local longCode = Worlds.sanitizeArrival({ owner = OWNER, slot = 1, mode = "friends", code = long }, OWNER)
	check(longCode ~= nil and longCode.code == nil, "B: an oversized access code is dropped")

	check(Worlds.sanitizeNotice({ notice = "host_left" }) == "host_left", "B: the host-left notice is read")
	check(Worlds.sanitizeNotice({ notice = "hello" }) == nil, "B: unknown notices are dropped")
	check(Worlds.sanitizeNotice(nil) == nil, "B: no notice")
end

-- C. Who may join.
do
	local friends = { owner = OWNER, mode = "friends" :: Worlds.Mode, players = 1 }
	local ok, reason = Worlds.canJoin(friends, FRIEND, true, MAX)
	check(ok and reason == nil, "C: a friend joins a friends world")
	ok, reason = Worlds.canJoin(friends, STRANGER, false, MAX)
	check(not ok and reason == "not_friend", "C: a random player cannot join")
	ok, reason = Worlds.canJoin({ owner = OWNER, mode = "solo", players = 1 }, FRIEND, true, MAX)
	check(not ok and reason == "private", "C: nobody joins a solo world, not even a friend")
	ok, reason = Worlds.canJoin(nil, FRIEND, true, MAX)
	check(not ok and reason == "closed", "C: a world that is not open")
	ok, reason = Worlds.canJoin(friends, OWNER, true, MAX)
	check(not ok and reason == "self", "C: the owner does not join their own world as a guest")
	for players = 1, MAX do
		local allowed = Worlds.canJoin({ owner = OWNER, mode = "friends", players = players }, FRIEND, true, MAX)
		check(allowed == (players < MAX), `C: {players} already there -> join is {players < MAX}`)
	end
	-- The world can never hold more than MAX: add friends one by one until it refuses.
	local inWorld = 1
	for _ = 1, 10 do
		if Worlds.canJoin({ owner = OWNER, mode = "friends", players = inWorld }, FRIEND, true, MAX) then
			inWorld += 1
		end
	end
	check(inWorld == MAX, "C: a friends world fills up to exactly 4 players")
end

-- D. Registry entries.
do
	local now = 1_800_000_000
	local entry = Worlds.sanitizeEntry({
		owner = OWNER,
		code = "CODE",
		mode = "friends",
		slot = 2,
		players = 2,
		max = 10,
		baseLevel = 3,
		name = "Santi",
		updatedAt = now - 30,
	}, now, MAX)
	check(entry ~= nil, "D: a fresh entry is read")
	if entry then
		check(entry.max == MAX, "D: a stored max above the limit is cut to it")
		check(entry.players == 2 and entry.baseLevel == 3 and entry.name == "Santi", "D: entry fields kept")
	end
	check(
		Worlds.sanitizeEntry({ owner = OWNER, code = "CODE", mode = "friends", updatedAt = now - Worlds.ENTRY_MAX_AGE_SECONDS - 1 }, now, MAX) == nil,
		"D: a stale entry counts as closed"
	)
	check(Worlds.sanitizeEntry({ owner = OWNER, mode = "friends", updatedAt = now }, now, MAX) == nil, "D: an entry without a code is closed")
	check(Worlds.sanitizeEntry({ owner = OWNER, code = "C", mode = "party", updatedAt = now }, now, MAX) == nil, "D: an unknown mode is closed")
	check(Worlds.sanitizeEntry("junk", now, MAX) == nil, "D: junk is closed")
end

-- E. The "Join a friend" list.
do
	local now = 1_800_000_000
	local function entry(owner: number, name: string, players: number, mode: Worlds.Mode?): Worlds.Entry
		return {
			owner = owner,
			code = "c" .. owner,
			mode = mode or "friends",
			slot = 1,
			players = players,
			max = MAX,
			baseLevel = 2,
			name = name,
			updatedAt = now,
		}
	end
	local entries: { [number]: Worlds.Entry } = {
		[1] = entry(1, "Ana", 1),
		[2] = entry(2, "Beto", 3),
		[3] = entry(3, "Caro", MAX),
		[4] = entry(4, "Dani", 1, "solo"),
		[99] = entry(99, "Stranger", 1),
	}
	local rows = Worlds.friendWorlds({ 1, 2, 3, 4, 5, 2 }, entries)
	check(#rows == 3, "E: only friends with open friends worlds are listed, once each")
	check(rows[1] and rows[1].owner == 2, "E: the world with the most friends playing comes first")
	check(rows[2] and rows[2].owner == 1, "E: then the others with room")
	check(rows[3] and rows[3].owner == 3 and rows[3].full, "E: full worlds go last and say so")
	for _, row in rows do
		check(row.owner ~= 99, "E: a stranger's world is never listed")
		check(row.owner ~= 4, "E: a solo world is never listed")
	end
	local many: { number } = {}
	local manyEntries: { [number]: Worlds.Entry } = {}
	for id = 1, 20 do
		table.insert(many, id)
		manyEntries[id] = entry(id, "P" .. id, 1)
	end
	check(#Worlds.friendWorlds(many, manyEntries) == Worlds.LIST_LIMIT, "E: the list is capped")

	local views = Worlds.sanitizeViews({ { owner = 7, name = "Pau", baseLevel = 2, players = 4, max = 9 }, { owner = "x" }, "junk" }, MAX)
	check(#views == 1 and views[1].max == MAX and views[1].full, "E: the client keeps only valid rows")
	check(#Worlds.sanitizeViews(nil, MAX) == 0, "E: no list is an empty list")
end

-- F. The base is the owner's save.
do
	local owner = { habitat = 3, solar = 2 }
	local guestBig = { habitat = 5, solar = 3, lab = 2 }
	local lists = Worlds.worldBuildLists(owner, {}, true)
	check(#lists == 1 and lists[1] == owner, "F: the world stands on the owner's builds only")
	for _, list in lists do
		check(list ~= guestBig, "F: a guest's bigger base never shows in a friend's world")
	end
	local current = { habitat = 3 }
	local frozen = Worlds.worldBuildLists(nil, current, true)
	check(#frozen == 1 and frozen[1] == current, "F: with the owner gone, the base stays as it was")
	check(#Worlds.worldBuildLists(nil, current, false) == 0, "F: nobody loaded: the start menu showcase")
	check(Worlds.buildSaveTarget(OWNER, FRIEND) == OWNER, "F: a guest's build goes into the owner's save")
	check(Worlds.buildSaveTarget(nil, FRIEND) == FRIEND, "F: without an owner the payer keeps the build")
end

-- G. Owners of local worlds (Studio).
do
	check(Worlds.pickOwner(nil, {}) == nil, "G: nobody loaded, no owner")
	check(Worlds.pickOwner(nil, { OWNER, FRIEND }) == OWNER, "G: the first player whose slot loaded owns the world")
	check(Worlds.pickOwner(OWNER, { FRIEND, OWNER }) == OWNER, "G: the owner stays the owner")
	check(Worlds.pickOwner(OWNER, { FRIEND }) == FRIEND, "G: when the owner leaves, the next player in line owns it")
end

-- H. Stage 11: the session lock of a save slot (src/shared/ServerGuard.luau).
do
	local ServerGuard = require("../src/shared/ServerGuard")
	local TIMEOUT = 180
	local now = 1_800_000_000
	local mine = { job = "server-A", token = "visit-1", at = now - 10 }
	check(ServerGuard.lockDecision(nil, "server-A", "visit-1", now, TIMEOUT) == "take", "H: a slot with no lock is taken")
	check(ServerGuard.lockDecision("junk", "server-A", "visit-1", now, TIMEOUT) == "take", "H: a damaged lock counts as none")
	check(ServerGuard.lockDecision(mine, "server-A", "visit-1", now, TIMEOUT) == "own", "H: this visit's own lock")
	check(
		ServerGuard.lockDecision(mine, "server-B", "visit-2", now, TIMEOUT) == "wait",
		"H: a fresh lock of another server makes the load wait (its last save may still come)"
	)
	check(
		ServerGuard.lockDecision(mine, "server-A", "visit-2", now, TIMEOUT) == "wait",
		"H: the same server, a newer visit (left and joined again) also waits for the release"
	)
	local old = { job = "server-A", token = "visit-1", at = now - TIMEOUT - 1 }
	check(ServerGuard.lockDecision(old, "server-B", "visit-2", now, TIMEOUT) == "take", "H: a stale lock (crashed server) is taken")
	local future = { job = "server-A", token = "visit-1", at = now + TIMEOUT + 5 }
	check(ServerGuard.lockDecision(future, "server-B", "visit-2", now, TIMEOUT) == "take", "H: a lock stamped far in the future is stale")
	check(ServerGuard.lockDecision({ job = "", token = "t", at = now }, "server-B", "v", now, TIMEOUT) == "take", "H: an empty job id is no lock")

	check(ServerGuard.canWrite(mine, "server-A", "visit-1"), "H: the lock holder may write")
	check(not ServerGuard.canWrite(mine, "server-B", "visit-2"), "H: another server may not write")
	check(not ServerGuard.canWrite(mine, "server-A", "visit-0"), "H: an older visit on the same server may not write")
	check(not ServerGuard.canWrite(nil, "server-A", "visit-1"), "H: a released (or stolen and released) lock refuses the old visit")
	-- Stage 11 review: a regular save while the player is still here may take a missing lock back
	-- (an older server version wrote the slot without one), never a lock another visit holds.
	check(ServerGuard.canWrite(nil, "server-A", "visit-1", true), "H: a missing lock is taken back by a player still here")
	check(ServerGuard.canWrite("junk", "server-A", "visit-1", true), "H: a damaged lock counts as missing")
	check(not ServerGuard.canWrite(mine, "server-B", "visit-2", true), "H: allowFree never overwrites another visit's lock")
	check(not ServerGuard.canWrite(nil, "server-A", "visit-1", false), "H: a final save never takes a missing lock back")

	-- Server hop: world A loads, the player hops to world B before A's last save lands.
	local record: { [string]: any } = { base = { credits = 100 }, lock = { job = "A", token = "a1", at = now } }
	check(ServerGuard.lockDecision(record.lock, "B", "b1", now + 2, TIMEOUT) == "wait", "H: hop: B waits while A still holds the slot")
	record.lock = nil -- A's last save on leave releases the lock
	check(ServerGuard.lockDecision(record.lock, "B", "b1", now + 4, TIMEOUT) == "take", "H: hop: B loads once A released it")
	record.lock = { job = "B", token = "b1", at = now + 4 }
	check(not ServerGuard.canWrite(record.lock, "A", "a1"), "H: hop: a late write from A is refused (no duplicated credits)")
	-- B waited too long and stole A's lock: A's later writes are refused too.
	local stolen = { job = "B", token = "b2", at = now + 30 }
	check(not ServerGuard.canWrite(stolen, "A", "a1"), "H: a stolen lock refuses its old holder")

	check(ServerGuard.isEmptySlotRecord(nil), "H: nothing stored is an empty slot")
	check(ServerGuard.isEmptySlotRecord({ v = 5, lock = mine }), "H: a lock alone is not game data")
	check(not ServerGuard.isEmptySlotRecord({ v = 5, lock = mine, base = {} }), "H: a record with a base is data (never wiped by Continue)")
	check(not ServerGuard.isEmptySlotRecord({ completed = {} }), "H: an old record without a version is data")
end

-- I. Stage 11: settings kept in the meta record (SaveSettings).
do
	local ServerGuard = require("../src/shared/ServerGuard")
	local defaults = ServerGuard.defaultSettings()
	check(defaults.language == nil and defaults.funFacts and defaults.guidance, "I: defaults follow the device language, C.A.R.L. on")
	check(defaults.musicVolume >= 0 and defaults.musicVolume <= 1 and defaults.effectsVolume >= 0 and defaults.effectsVolume <= 1, "I: default volumes 0..1")
	local s, changed = ServerGuard.applySettings(defaults, { language = "es", musicVolume = 0.25, guidance = false })
	check(changed and s.language == "es" and math.abs(s.musicVolume - 0.25) < 1e-9 and s.guidance == false, "I: a patch changes only its fields")
	check(s.effectsVolume == defaults.effectsVolume and s.funFacts == defaults.funFacts, "I: other fields stay")
	check(defaults.language == nil, "I: the patch never changes the settings it started from")
	local loud = ServerGuard.applySettings(defaults, { musicVolume = 7, effectsVolume = -3 })
	check(loud.musicVolume == 1 and loud.effectsVolume == 0, "I: volumes are clamped to 0..1")
	local odd = ServerGuard.applySettings(defaults, { musicVolume = 0 / 0, language = "fr", funFacts = "yes", hack = true })
	check(odd.musicVolume == defaults.musicVolume and odd.language == nil and odd.funFacts == true and (odd :: any).hack == nil, "I: bad values and unknown fields are ignored")
	local _, same = ServerGuard.applySettings(s, { language = "es" })
	check(not same, "I: the same value is no change")
	local _, junk = ServerGuard.applySettings(s, "junk")
	check(not junk, "I: a patch that is not a table is ignored")
	local stepped = ServerGuard.applySettings(defaults, { effectsVolume = 0.333333 })
	check(math.abs(stepped.effectsVolume - 0.33) < 1e-9, "I: volumes are kept in steps of 0.01")
	local stored = ServerGuard.sanitizeSettings({ language = "en", musicVolume = 0.5, funFacts = false })
	check(stored.language == "en" and stored.musicVolume == 0.5 and stored.funFacts == false and stored.guidance == true, "I: a stored record is read, missing fields default")
	check(ServerGuard.sanitizeSettings(nil).language == nil, "I: an old meta without settings reads as defaults")
	local count = 0
	for _ in ServerGuard.SETTING_NAMES do
		count += 1
	end
	-- Stage 11 menu: plus big text, reduce motion, colour helper and message speed.
	check(count == 9, "I: nine settings (language, two volumes, fun facts, guidance, four accessibility)")
	check(defaults.bigText == false and defaults.reduceMotion == false and defaults.colourHelper == false and defaults.messageSpeed == 1, "I: accessibility defaults are off, normal speed")
	local access, accessChanged = ServerGuard.applySettings(defaults, { bigText = true, reduceMotion = true, colourHelper = true, messageSpeed = 2 })
	check(accessChanged and access.bigText and access.reduceMotion and access.colourHelper and access.messageSpeed == 2, "I: accessibility settings are saved")
	local badSpeed = ServerGuard.applySettings(defaults, { messageSpeed = 7, bigText = "yes" })
	check(badSpeed.messageSpeed == 1 and badSpeed.bigText == false, "I: an unknown message speed or a non-boolean flag is ignored")
	local nearSpeed = ServerGuard.applySettings(defaults, { messageSpeed = 1.5000000001 })
	check(nearSpeed.messageSpeed == 1.5, "I: message speed snaps to a listed value")
	check(ServerGuard.applySettings(defaults, { messageSpeed = 0 / 0 }).messageSpeed == 1, "I: NaN message speed is ignored")
	for _, speed in ServerGuard.MESSAGE_SPEEDS do
		check(speed >= 1 and speed <= 3, "I: message speeds only make bubbles stay longer: " .. tostring(speed))
	end
	local oldStored = ServerGuard.sanitizeSettings({ language = "es", musicVolume = 0.4 })
	check(oldStored.bigText == false and oldStored.messageSpeed == 1, "I: a meta from before Stage 11 menu reads accessibility defaults")

	-- SaveSettings rate limit (5 a second): the sixth request in the same second is dropped.
	local times: { number } = {}
	local accepted = 0
	for i = 1, 6 do
		if ServerGuard.allowInWindow(times, 100 + i * 0.1, 1, 5) then
			accepted += 1
		end
	end
	check(accepted == 5, "I: at most 5 settings requests a second")
	check(ServerGuard.allowInWindow(times, 102, 1, 5), "I: a second later requests are accepted again")
end

print(`worlds: {passes} passed, {failures} failed`)
if failures > 0 then
	error("worlds tests failed")
end
