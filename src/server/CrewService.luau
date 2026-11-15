--!strict
-- Space Base Odyssey - per-player suit oxygen, pressurized zones and carried ice (server side).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

type PlayerStats = {
	suitO2: number,
	inside: boolean,
	sheltered: boolean,
	carryingIce: boolean,
}

type Crew = {
	suitO2: number,
	inside: boolean,
	sheltered: boolean,
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
local spawnLocation: SpawnLocation? = nil
local remotes: Remotes? = nil
local shiftActive = false
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
	then
		return
	end
	crew.lastSent = stats
	remotes.playerStats:FireClient(player, stats)
end

local function fillSuit(crew: Crew)
	crew.suitO2 = SUIT.MAX
	crew.countRefill = false
	crew.rescueTopUp = false
	crew.lowWarned = false
end

local function rescue(player: Player, crew: Crew)
	local character = player.Character
	if character and spawnLocation then
		character:PivotTo(spawnLocation.CFrame + RESCUE_OFFSET)
		crew.measured = false -- a teleport, not a walk back inside
	end
	crew.suitO2 = SUIT.RESCUE_REFILL
	crew.carryingIce = false
	crew.countRefill = false
	crew.rescueTopUp = true
	crew.lowWarned = false
	refillCount += 1
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

local function updateCrew(player: Player, crew: Crew, dt: number)
	local root = getRoot(player)
	if root == nil then
		-- No living character: no reading. The next spawn starts a fresh measurement, so dying or
		-- respawning is never reported as walking in or out.
		crew.inside = false
		crew.sheltered = false
		crew.measured = false
		return
	end

	local position = root.Position
	local wasInside, wasSheltered = crew.inside, crew.sheltered
	crew.sheltered = insideBox(shelterZone, position)
	crew.inside = crew.sheltered or insideBox(habitatZone, position)
	if not crew.measured then
		crew.measured = true
	elseif wasInside ~= crew.inside or wasSheltered ~= crew.sheltered then
		notifyZone(player, crew.inside, crew.sheltered, wasInside, wasSheltered)
	end

	if crew.inside then
		if crew.suitO2 < SUIT.MAX then
			if crew.suitO2 < SUIT.MAX * REFILL_COUNT_FRACTION then
				crew.countRefill = true
			end
			crew.suitO2 = math.min(SUIT.MAX, crew.suitO2 + SUIT.REFILL_PER_SECOND * dt)
			if crew.suitO2 >= SUIT.MAX and crew.countRefill then
				crew.countRefill = false
				if crew.rescueTopUp then
					-- The rescue already counted this refill.
					crew.rescueTopUp = false
				elseif shiftActive then
					refillCount += 1
				end
			end
		end
		if crew.suitO2 >= SUIT.MAX * LOW_WARNING_FRACTION then
			crew.lowWarned = false
		end
		return
	end

	if not shiftActive then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local drain = if speed > SUIT.RUN_SPEED_THRESHOLD
		then SUIT.DRAIN_RUN_PER_SECOND
		elseif speed > MOVING_SPEED then SUIT.DRAIN_WALK_PER_SECOND
		else SUIT.DRAIN_IDLE_PER_SECOND
	crew.suitO2 = math.max(0, crew.suitO2 - drain * dt)
	crew.rescueTopUp = false -- going back out uses more air: the next refill counts again

	if crew.suitO2 < SUIT.MAX * REFILL_COUNT_FRACTION then
		crew.countRefill = true
	end
	if crew.suitO2 < SUIT.MAX * LOW_WARNING_FRACTION and not crew.lowWarned and crew.suitO2 > 0 then
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
	local crew: Crew = {
		suitO2 = SUIT.MAX,
		inside = false,
		sheltered = false,
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

-- world: WorldBuilder.World (uses habitatZone, shelterZone, spawn).
function CrewService.start(world: any, remoteEvents: Remotes)
	assert(not started, "CrewService already started")
	started = true
	habitatZone = world.habitatZone
	shelterZone = world.shelterZone
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
			for player, crew in crews do
				if player.Parent == nil then
					continue
				end
				updateCrew(player, crew, dt)
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

-- True when the player has a living character (used to count storm exposure).
function CrewService.isPresent(player: Player): boolean
	return getRoot(player) ~= nil
end

function CrewService.isInside(player: Player): boolean
	local crew = crews[player]
	return crew ~= nil and crew.inside
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

function CrewService.getStats(player: Player): PlayerStats?
	local crew = crews[player]
	if crew == nil then
		return nil
	end
	return statsOf(crew)
end

return CrewService
