--!strict
-- Space Base Odyssey - per-player suit oxygen, pressurized zones and carried ice (server side).
-- Stage 6: each player's suit holds SUIT.MAX plus their "tank" skill (player attribute SBO_SuitMax,
-- set by BaseService) and the running threshold rises with the "speed" skill (SBO_SpeedBonus). Outside
-- a shift the suit also drains outside while the base is open to roam (Briefing and Planning: building
-- and manual ice), refills inside and C.A.R.L. still rescues; only shift refills cost base air.
-- The regolith shelter only counts once it is built (world.isBuilt("shelter")).
-- Stage 7: players arrive in the lander (world.landerZone, the spawn): it is always a pressurized
-- room, so suits refill there and C.A.R.L. brings a player with an empty suit back to it. The
-- habitat is built like everything else and counts as inside only once it stands. zoneOf tells the
-- rooms apart ("go back inside" in first steps means the habitat).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

type PlayerStats = Types.PlayerStats

type Crew = {
	suitO2: number,
	suitMax: number, -- SUIT.MAX plus the tank skill, read from the player attribute every tick
	inside: boolean,
	sheltered: boolean,
	inHabitat: boolean,
	inLander: boolean,
	carryingIce: boolean,
	countRefill: boolean, -- suit dropped below the refill threshold; count it when full again
	rescueTopUp: boolean, -- the next top-up after a rescue is already counted
	lowWarned: boolean,
	measured: boolean, -- inside / sheltered hold a real reading for the current character
	lastSent: PlayerStats?,
	connections: { RBXScriptConnection },
}

-- Called when a player's measured zone changes (never for the first reading after a spawn).
export type ZoneListener = (player: Player, inside: boolean, sheltered: boolean, wasInside: boolean, wasSheltered: boolean) -> ()

type Remotes = {
	playerStats: RemoteEvent,
	message: RemoteEvent,
}

local TICK_SECONDS = 0.25 -- zone checks and stats updates, about four per second
local MOVING_SPEED = 2 -- studs/s; slower than this counts as standing still
local REFILL_COUNT_FRACTION = 0.9 -- a refill counts when the suit started below 90% of MAX
local LOW_WARNING_FRACTION = 0.25 -- C.A.R.L. warns once below 25% of MAX
local RESCUE_OFFSET = Vector3.new(0, 4, 0)

local SUIT = MissionData.SUIT

local CrewService = {}

local crews: { [Player]: Crew } = {}
local habitatZone: BasePart? = nil
local shelterZone: BasePart? = nil
local landerZone: BasePart? = nil
local spawnLocation: SpawnLocation? = nil
local remotes: Remotes? = nil
local worldRef: any = nil
local shiftActive = false
local roamDrain = false -- suits drain outside between shifts too (Briefing / Planning)
local refillCount = 0
local started = false
local zoneListeners: { ZoneListener } = {}

local function insideBox(zone: BasePart?, position: Vector3): boolean
	if zone == nil then
		return false
	end
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Per-player suit size: SUIT.MAX plus the tank skill (attribute SBO_SuitMax from BaseService).
local function suitMaxOf(player: Player): number
	local value = player:GetAttribute("SBO_SuitMax")
	if type(value) == "number" and value == value and value >= 1 and value < math.huge then
		return value
	end
	return SUIT.MAX
end

-- Running threshold plus the speed skill (attribute SBO_SpeedBonus): a faster walker is not "running".
-- Stage 7: while a greenhouse food boost lasts (SBO_FoodBoostUntil, set by ToolService) the client
-- walks FOOD.BOOST_SPEED faster, so the threshold rises by the same amount.
local function runThresholdOf(player: Player): number
	local threshold = SUIT.RUN_SPEED_THRESHOLD
	local bonus = player:GetAttribute("SBO_SpeedBonus")
	if type(bonus) == "number" and bonus == bonus and bonus >= 0 and bonus < math.huge then
		threshold += bonus
	end
	local boostUntil = player:GetAttribute("SBO_FoodBoostUntil")
	if type(boostUntil) == "number" and boostUntil > workspace:GetServerTimeNow() then
		threshold += MissionData.BASE.FOOD.BOOST_SPEED
	end
	return threshold
end

-- A structure counts only once it stands (Stage 6: the shelter; Stage 7: the habitat too). Worlds
-- without isBuilt keep the old, fully built base.
local function structureBuilt(id: string): boolean
	local isBuilt = worldRef and worldRef.isBuilt
	if type(isBuilt) ~= "function" then
		return true
	end
	local ok, built = pcall(isBuilt, id)
	return not ok or built == true
end

type BuiltNow = { habitat: boolean, shelter: boolean }

local function sendMessage(player: Player, key: string)
	if remotes then
		local text: Types.TextRef = { key = key }
		remotes.message:FireClient(player, text)
	end
end

local function statsOf(crew: Crew): PlayerStats
	return {
		suitO2 = math.floor(crew.suitO2 + 0.5),
		inside = crew.inside,
		sheltered = crew.sheltered,
		carryingIce = crew.carryingIce,
		suitMax = crew.suitMax,
	}
end

local function sendStatsIfChanged(player: Player, crew: Crew)
	if remotes == nil then
		return
	end
	local stats = statsOf(crew)
	local last = crew.lastSent
	if last
		and last.suitO2 == stats.suitO2
		and last.inside == stats.inside
		and last.sheltered == stats.sheltered
		and last.carryingIce == stats.carryingIce
		and last.suitMax == stats.suitMax
	then
		return
	end
	crew.lastSent = stats
	remotes.playerStats:FireClient(player, stats)
end

local function fillSuit(crew: Crew)
	crew.suitO2 = crew.suitMax
	crew.countRefill = false
	crew.rescueTopUp = false
	crew.lowWarned = false
end

local function rescue(player: Player, crew: Crew)
	local character = player.Character
	if character and spawnLocation then
		-- A seated character is welded to its seat: unseat first so the teleport does not drag a
		-- garage vehicle into the lander.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local seat = if humanoid then humanoid.SeatPart else nil
		if humanoid and seat then
			local seatWeld = seat:FindFirstChild("SeatWeld")
			if seatWeld then
				seatWeld:Destroy()
			end
			humanoid.Sit = false
		end
		character:PivotTo(spawnLocation.CFrame + RESCUE_OFFSET)
		crew.measured = false -- a teleport, not a walk back inside
	end
	crew.suitO2 = math.min(SUIT.RESCUE_REFILL, crew.suitMax)
	crew.carryingIce = false
	crew.countRefill = false
	crew.rescueTopUp = true
	crew.lowWarned = false
	if shiftActive then
		refillCount += 1 -- only shift refills cost base air (a rescue while roaming is free)
	end
	sendMessage(player, "carl.rescued")
end

local function notifyZone(player: Player, inside: boolean, sheltered: boolean, wasInside: boolean, wasSheltered: boolean)
	for _, listener in zoneListeners do
		local ok, err = pcall(listener, player, inside, sheltered, wasInside, wasSheltered)
		if not ok then
			warn(`[SpaceBaseOdyssey] zone listener failed: {err}`)
		end
	end
end

local function updateCrew(player: Player, crew: Crew, dt: number, built: BuiltNow)
	local root = getRoot(player)
	if root == nil then
		-- No living character: no reading. The next spawn starts a fresh measurement, so dying or
		-- respawning is never reported as walking in or out.
		crew.inside = false
		crew.sheltered = false
		crew.inHabitat = false
		crew.inLander = false
		crew.measured = false
		return
	end

	-- The tank skill can grow (or a reset shrink) the suit at any time: keep the air inside it.
	local suitMax = suitMaxOf(player)
	if suitMax ~= crew.suitMax then
		crew.suitMax = suitMax
		crew.suitO2 = math.min(crew.suitO2, suitMax)
	end

	local position = root.Position
	local wasInside, wasSheltered = crew.inside, crew.sheltered
	crew.sheltered = built.shelter and insideBox(shelterZone, position)
	crew.inHabitat = built.habitat and insideBox(habitatZone, position)
	crew.inLander = insideBox(landerZone, position)
	crew.inside = crew.sheltered or crew.inHabitat or crew.inLander
	if not crew.measured then
		crew.measured = true
	elseif wasInside ~= crew.inside or wasSheltered ~= crew.sheltered then
		notifyZone(player, crew.inside, crew.sheltered, wasInside, wasSheltered)
	end

	if crew.inside then
		if crew.suitO2 < suitMax then
			if crew.suitO2 < suitMax * REFILL_COUNT_FRACTION then
				crew.countRefill = true
			end
			crew.suitO2 = math.min(suitMax, crew.suitO2 + SUIT.REFILL_PER_SECOND * dt)
			if crew.suitO2 >= suitMax and crew.countRefill then
				crew.countRefill = false
				if crew.rescueTopUp then
					-- The rescue already counted this refill.
					crew.rescueTopUp = false
				elseif shiftActive then
					refillCount += 1
				end
			end
		end
		if crew.suitO2 >= suitMax * LOW_WARNING_FRACTION then
			crew.lowWarned = false
		end
		return
	end

	if not shiftActive and not roamDrain then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local drain = if speed > runThresholdOf(player)
		then SUIT.DRAIN_RUN_PER_SECOND
		elseif speed > MOVING_SPEED then SUIT.DRAIN_WALK_PER_SECOND
		else SUIT.DRAIN_IDLE_PER_SECOND
	crew.suitO2 = math.max(0, crew.suitO2 - drain * dt)
	crew.rescueTopUp = false -- going back out uses more air: the next refill counts again

	if crew.suitO2 < suitMax * REFILL_COUNT_FRACTION then
		crew.countRefill = true
	end
	if crew.suitO2 < suitMax * LOW_WARNING_FRACTION and not crew.lowWarned and crew.suitO2 > 0 then
		crew.lowWarned = true
		sendMessage(player, "carl.suit_low")
	end
	if crew.suitO2 <= 0 then
		rescue(player, crew)
	end
end

local function addPlayer(player: Player)
	if crews[player] then
		return
	end
	local startMax = suitMaxOf(player)
	local crew: Crew = {
		suitO2 = startMax,
		suitMax = startMax,
		inside = false,
		sheltered = false,
		inHabitat = false,
		inLander = false,
		carryingIce = false,
		countRefill = false,
		rescueTopUp = false,
		lowWarned = false,
		measured = false,
		lastSent = nil,
		connections = {},
	}
	crews[player] = crew
	table.insert(
		crew.connections,
		player.CharacterAdded:Connect(function()
			-- A fresh character starts with a full suit and empty hands.
			crew.suitMax = suitMaxOf(player)
			fillSuit(crew)
			crew.carryingIce = false
			crew.measured = false
		end)
	)
end

local function removePlayer(player: Player)
	local crew = crews[player]
	if crew == nil then
		return
	end
	for _, connection in crew.connections do
		connection:Disconnect()
	end
	crews[player] = nil
end

-- world: WorldBuilder.World (uses habitatZone, shelterZone, landerZone, spawn, and isBuilt when present).
function CrewService.start(world: any, remoteEvents: Remotes)
	assert(not started, "CrewService already started")
	started = true
	worldRef = world
	habitatZone = world.habitatZone
	shelterZone = world.shelterZone
	local lander = world.landerZone
	if typeof(lander) == "Instance" and lander:IsA("BasePart") then
		landerZone = lander
	else
		warn("[SpaceBaseOdyssey] world has no landerZone; only the habitat and shelter are inside")
	end
	spawnLocation = world.spawn
	remotes = remoteEvents

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_SECONDS)
			local now = os.clock()
			local dt = math.min(now - last, 1)
			last = now
			-- Asked once per tick for everyone.
			local built: BuiltNow = { habitat = structureBuilt("habitat"), shelter = structureBuilt("shelter") }
			for player, crew in crews do
				if player.Parent == nil then
					continue
				end
				updateCrew(player, crew, dt, built)
				sendStatsIfChanged(player, crew)
			end
		end
	end)
end

-- Starting a shift refills every suit, empties hands and resets the refill count.
-- Ending a shift drops any carried ice and stops suit drain (call takeRefillCount first).
function CrewService.setShiftActive(active: boolean)
	shiftActive = active
	if active then
		refillCount = 0
	end
	for player, crew in crews do
		if active then
			fillSuit(crew)
		end
		crew.carryingIce = false
		sendStatsIfChanged(player, crew)
	end
end

function CrewService.isShiftActive(): boolean
	return shiftActive
end

-- Stage 6 base mode: while true, suits also drain outside between shifts (roaming, building, manual
-- ice). Refills taken then are free: only refills during a shift cost base air.
function CrewService.setRoamDrain(active: boolean)
	roamDrain = active
end

-- This player's suit size (SUIT.MAX plus the tank skill).
function CrewService.suitMax(player: Player): number
	local crew = crews[player]
	return if crew then crew.suitMax else suitMaxOf(player)
end

-- True when the player has a living character (used to count storm exposure).
function CrewService.isPresent(player: Player): boolean
	return getRoot(player) ~= nil
end

function CrewService.isInside(player: Player): boolean
	local crew = crews[player]
	return crew ~= nil and crew.inside
end

-- Stage 7: which room the player is in: "shelter", "habitat", "lander" or "outside".
function CrewService.zoneOf(player: Player): string
	local crew = crews[player]
	if crew == nil or not crew.inside then
		return "outside"
	elseif crew.sheltered then
		return "shelter"
	elseif crew.inHabitat then
		return "habitat"
	elseif crew.inLander then
		return "lander"
	end
	return "outside"
end

function CrewService.isInHabitat(player: Player): boolean
	local crew = crews[player]
	return crew ~= nil and crew.inHabitat
end

function CrewService.isInLander(player: Player): boolean
	local crew = crews[player]
	return crew ~= nil and crew.inLander
end

function CrewService.isSheltered(player: Player): boolean
	local crew = crews[player]
	return crew ~= nil and crew.sheltered
end

function CrewService.isCarrying(player: Player): boolean
	local crew = crews[player]
	return crew ~= nil and crew.carryingIce
end

function CrewService.setCarrying(player: Player, carrying: boolean)
	local crew = crews[player]
	if crew == nil then
		return
	end
	crew.carryingIce = carrying
	sendStatsIfChanged(player, crew)
end

-- Inside / outside and shelter transitions. go_outside, return_inside and reach_shelter objectives
-- are counted from these (MissionService).
function CrewService.onZoneChanged(listener: ZoneListener)
	table.insert(zoneListeners, listener)
end

-- Players whose living character is inside the regolith shelter right now.
function CrewService.shelteredPlayers(): { Player }
	local list = {}
	for player, crew in crews do
		if player.Parent ~= nil and crew.sheltered then
			table.insert(list, player)
		end
	end
	return list
end

-- Returns the suit refills counted since the last call (or since the shift started) and resets it.
function CrewService.takeRefillCount(): number
	local count = refillCount
	refillCount = 0
	return count
end

-- The suit refills counted so far this shift, without resetting (live meters).
function CrewService.peekRefillCount(): number
	return refillCount
end

function CrewService.getStats(player: Player): PlayerStats?
	local crew = crews[player]
	if crew == nil then
		return nil
	end
	return statsOf(crew)
end

return CrewService
