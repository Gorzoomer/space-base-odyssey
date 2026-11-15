--!strict
-- Space Base Odyssey - private worlds (Stage 10 fix, live playtest: "Pau pressed New game and landed
-- in Santi's world"). Pure rules shared by ProgressService, BaseService, the start menu and
-- tests/worlds.luau (no Roblox instances, so it runs in Lune).
--
-- Every world is its OWNER's save slot and runs in its own reserved server:
--   lobby  a public server: only the start menu, nobody spawns. Choosing a world teleports the
--          player to a new reserved server (TeleportData = Arrival below).
--   world  a reserved server made for one owner. "solo": only the owner. "friends": the owner and
--          Roblox friends of the owner, at most MissionData.MISSION.PLAYERS_MAX players in all (the
--          callers pass it in: pure modules take their data as an argument).
--   local  Studio, an unpublished place or a VIP server: slots load in this server. The first player
--          whose slot loads owns the world; later players are guests.
-- The base (builds standing, builds in progress, silo) is the owner's save: guests keep their own
-- credits, XP, skills, gear, tools, pets, wardrobe, quests and collectibles from their own slot, and
-- what they build in a friend's world goes into the owner's save.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Worlds = {}

export type Role = "lobby" | "world" | "local"
export type Mode = "solo" | "friends"
export type Levels = { [string]: number }

-- What a player brings to a world server (TeleportData, set by the lobby server). The owner's own
-- trip carries the reserved server's access code (the world server keeps it in the registry so
-- friends can follow); a guest's trip never does.
export type Arrival = {
	owner: number, -- the world owner's UserId
	guest: boolean, -- true = a friend joining the owner's world
	slot: number, -- the slot this player plays (a guest's own slot: their explorer save)
	mode: Mode, -- the world's mode ("friends" for every guest)
	fresh: boolean, -- New game in that slot (the slot is wiped)
	code: string?, -- owner only: the reserved server access code
}

-- One open world in the registry (MemoryStore "SBO_Worlds", key = owner UserId).
export type Entry = {
	owner: number,
	code: string,
	mode: Mode,
	slot: number,
	players: number, -- players in the world now (owner included)
	max: number,
	baseLevel: number, -- the owner's habitat level
	name: string, -- the owner's display name
	updatedAt: number, -- os.time() of the last refresh
}

-- One row of the "Join a friend" list (Types.FriendWorld).
export type View = {
	owner: number,
	name: string,
	baseLevel: number,
	players: number,
	max: number,
	full: boolean,
}

-- Why a join (or an arrival) was refused. The client shows "ui.menu_notice_<reason>".
export type Reason = "closed" | "self" | "private" | "not_friend" | "full" | "host_left"

Worlds.SLOT_COUNT = 3 -- contract with ProgressService and the start menu
Worlds.ENTRY_MAX_AGE_SECONDS = 150 -- an entry not refreshed for this long is treated as closed
Worlds.LIST_LIMIT = 6 -- rows on the "Join a friend" screen
Worlds.MAX_NAME_LENGTH = 32
Worlds.MAX_CODE_LENGTH = 1024 -- Roblox does not document the access code length: generous, still bounded
-- Notices a world server sends back to the lobby (TeleportData { notice = ... }).
Worlds.NOTICES = table.freeze({
	host_left = true,
	private = true,
	full = true,
	closed = true,
	not_friend = true,
} :: { [string]: boolean })

local function isWhole(value: any): boolean
	return type(value) == "number" and value == value and value == math.floor(value) and value ~= math.huge
end

-- A Roblox UserId (positive whole number).
function Worlds.isUserId(value: any): boolean
	return isWhole(value) and value > 0
end

function Worlds.isSlot(value: any, slotCount: number?): boolean
	return isWhole(value) and value >= 1 and value <= (slotCount or Worlds.SLOT_COUNT)
end

-- The role of a server, from facts the server reads (game.PlaceId, game.PrivateServerId,
-- game.PrivateServerOwnerId, RunService:IsStudio()).
function Worlds.serverRole(studio: boolean, placeId: number, privateServerId: string, privateServerOwnerId: number): Role
	if studio or placeId == 0 then
		return "local"
	end
	if privateServerId == "" then
		return "lobby"
	end
	if privateServerOwnerId == 0 then
		return "world" -- a reserved server (TeleportService)
	end
	return "local" -- a VIP server: everyone plays here; the first to load owns the world
end

-- TeleportData -> Arrival, or nil when it is not a valid trip for `userId`. Data may be old or damaged.
function Worlds.sanitizeArrival(data: any, userId: number, slotCount: number?): Arrival?
	if type(data) ~= "table" or not Worlds.isUserId(userId) then
		return nil
	end
	local owner = data.owner
	if not Worlds.isUserId(owner) or not Worlds.isSlot(data.slot, slotCount) then
		return nil
	end
	local guest = data.guest == true
	if guest == (owner == userId) then
		return nil -- an owner's trip names the player; a guest's trip names someone else
	end
	local mode: Mode? = if data.mode == "solo" then "solo" elseif data.mode == "friends" then "friends" else nil
	if guest then
		mode = "friends" -- guests only ever join friends worlds
	elseif mode == nil then
		return nil
	end
	local code: string? = nil
	if not guest and type(data.code) == "string" and #data.code > 0 and #data.code <= Worlds.MAX_CODE_LENGTH then
		code = data.code
	end
	return {
		owner = owner,
		guest = guest,
		slot = data.slot,
		mode = mode :: Mode,
		fresh = data.fresh == true,
		code = code,
	}
end

-- The notice a world server sent back to the lobby (TeleportData { notice }), if any.
function Worlds.sanitizeNotice(data: any): string?
	if type(data) ~= "table" or type(data.notice) ~= "string" then
		return nil
	end
	return if Worlds.NOTICES[data.notice] then data.notice else nil
end

-- May `requesterId` join (or stay in) this world? world = the registry entry (nil = no such world
-- open). players = players already in the world NOT counting the requester. Checks, in order: the
-- world is open, it is not the requester's own, it is a friends world, they are Roblox friends of
-- the owner, there is room.
function Worlds.canJoin(world: { owner: number, mode: Mode, players: number }?, requesterId: number, isFriend: boolean, maxPlayers: number): (boolean, Reason?)
	if world == nil then
		return false, "closed"
	end
	if world.owner == requesterId then
		return false, "self"
	end
	if world.mode ~= "friends" then
		return false, "private"
	end
	if not isFriend then
		return false, "not_friend"
	end
	if world.players >= maxPlayers then
		return false, "full"
	end
	return true, nil
end

-- A registry value -> Entry, or nil when damaged or stale (older than ENTRY_MAX_AGE_SECONDS at `now`).
-- maxPlayers = MissionData.MISSION.PLAYERS_MAX (a bigger stored max is cut to it).
function Worlds.sanitizeEntry(value: any, now: number, maxPlayers: number): Entry?
	if type(value) ~= "table" then
		return nil
	end
	if not Worlds.isUserId(value.owner) or type(value.code) ~= "string" or #value.code == 0 or #value.code > Worlds.MAX_CODE_LENGTH then
		return nil
	end
	if value.mode ~= "solo" and value.mode ~= "friends" then
		return nil
	end
	if not isWhole(value.updatedAt) or now - value.updatedAt > Worlds.ENTRY_MAX_AGE_SECONDS then
		return nil
	end
	local max = if isWhole(value.max) and value.max >= 1 then math.min(value.max, maxPlayers) else maxPlayers
	local players = if isWhole(value.players) then math.clamp(value.players, 0, 99) else 0
	local name = if type(value.name) == "string" then string.sub(value.name, 1, Worlds.MAX_NAME_LENGTH) else ""
	return {
		owner = value.owner,
		code = value.code,
		mode = value.mode,
		slot = if Worlds.isSlot(value.slot) then value.slot else 1,
		players = players,
		max = max,
		baseLevel = if isWhole(value.baseLevel) then math.clamp(value.baseLevel, 0, 99) else 0,
		name = name,
		updatedAt = value.updatedAt,
	}
end

-- The "Join a friend" rows: open friends worlds of `friendIds` found in `entries` (owner -> Entry),
-- the ones with room first, then fuller worlds, then by name. At most `limit` rows.
function Worlds.friendWorlds(friendIds: { number }, entries: { [number]: Entry }, limit: number?): { View }
	local rows: { View } = {}
	local seen: { [number]: boolean } = {}
	for _, id in friendIds do
		local entry = entries[id]
		if entry and not seen[id] and entry.mode == "friends" then
			seen[id] = true
			table.insert(rows, {
				owner = id,
				name = entry.name,
				baseLevel = entry.baseLevel,
				players = entry.players,
				max = entry.max,
				full = entry.players >= entry.max,
			})
		end
	end
	table.sort(rows, function(a: View, b: View): boolean
		if a.full ~= b.full then
			return not a.full
		end
		if a.players ~= b.players then
			return a.players > b.players
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.owner < b.owner
	end)
	local cap = limit or Worlds.LIST_LIMIT
	while #rows > cap do
		table.remove(rows)
	end
	return rows
end

-- The client's copy of the list (Remotes.WORLDS): every field checked, at most `limit` rows.
function Worlds.sanitizeViews(value: any, maxPlayers: number, limit: number?): { View }
	local rows: { View } = {}
	if type(value) ~= "table" then
		return rows
	end
	local cap = limit or Worlds.LIST_LIMIT
	for index = 1, math.min(#value, cap) do
		local row = value[index]
		if type(row) == "table" and Worlds.isUserId(row.owner) then
			local max = if isWhole(row.max) and row.max >= 1 then math.min(row.max, maxPlayers) else maxPlayers
			local players = if isWhole(row.players) then math.max(0, row.players) else 0
			table.insert(rows, {
				owner = row.owner,
				name = if type(row.name) == "string" then string.sub(row.name, 1, Worlds.MAX_NAME_LENGTH) else "",
				baseLevel = if isWhole(row.baseLevel) then math.max(0, row.baseLevel) else 0,
				players = players,
				max = max,
				full = players >= max,
			})
		end
	end
	return rows
end

-- The owner of a local world: the current owner while they still play, else the player whose slot
-- loaded first (`loaded` = UserIds in load order). nil when nobody is loaded.
function Worlds.pickOwner(current: number?, loaded: { number }): number?
	if current ~= nil and table.find(loaded, current) then
		return current
	end
	return loaded[1]
end

-- The build lists the world stands on (the argument for BaseBuild.shownLevels / effective):
--   the owner is loaded       -> the owner's builds only (never the highest of everyone present);
--   no owner, someone loaded  -> `current` (the base does not vanish while guests leave);
--   nobody loaded             -> nothing (the start menu's showcase base).
function Worlds.worldBuildLists(ownerBuilds: Levels?, current: Levels, anyoneLoaded: boolean): { Levels }
	if ownerBuilds ~= nil then
		return { ownerBuilds }
	end
	if anyoneLoaded then
		return { current }
	end
	return {}
end

-- Whose save gets a finished build level: always the world owner (a guest's own slot never changes
-- in a friend's world). Without a known owner (an old server) the payer keeps it, as before.
function Worlds.buildSaveTarget(ownerId: number?, payerId: number): number
	return ownerId or payerId
end

return table.freeze(Worlds)
