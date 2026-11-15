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

print(`worlds: {passes} passed, {failures} failed`)
if failures > 0 then
	error("worlds tests failed")
end
