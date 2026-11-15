--!strict
-- Space Base Odyssey - exploring the Moon (Stage 7), server side.
-- 1) Exploration sites (world.pois, built by WorldSites): holding the tablet tool, a player scans a
--    site with its prompt. The first scan of each site gives that player REWARDS.poi_scanned and is
--    saved (BaseService.markScanned "poi:<id>"); every scan sends that player a Types.ExploreEvent
--    (Remotes.EXPLORE) so the client shows the site card (name, real fact, reward line when new).
-- 2) Meteorite impacts (random event): while at least one player is in the server, every
--    METEOR.MIN_SECONDS..MAX_SECONDS a small space rock lands in a clear spot of the ring
--    METEOR.RING_MIN..RING_MAX around the habitat (raycast on flat ground, away from structures, the
--    crater and the exploration sites). There is no fiery streak: the Moon has no air to burn the
--    rock, so the world only shows a flash and dust where it hits (world.spawnImpact). C.A.R.L. tells
--    everyone. Scanning the fresh crater with the tablet gives REWARDS.meteor_scanned once per player
--    per impact. Only one impact at a time; it is cleared after METEOR.LIFETIME_SECONDS.
--    The impact model carries attribute SBO_ImpactId (a serial number) and SBO_ExpiresAt (server
--    time); a player who scanned it gets the player attribute SBO_ScannedImpact = that serial, so
--    C.A.R.L.'s guidance (client) knows who still has to look at it.
-- 3) DebugMeteor (DemoKeys F2, Studio or the place owner only): an impact lands near that player now.
--    BaseService routes the action here through BaseService.setDebugMeteorHook.
-- Server authoritative: prompt distance, the tablet in hand and the cooldown are checked here.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

type ExploreEvent = Types.ExploreEvent
type Params = { [string]: string | number }

export type Remotes = {
	message: RemoteEvent,
	explore: RemoteEvent?,
}

local BASE = MissionData.BASE
local METEOR = BASE.METEOR

-- Technical settings (not gameplay numbers).
local TICK_SECONDS = 1
local SCAN_COOLDOWN_SECONDS = 1 -- one scan per player this often (double triggers are dropped)
local PROMPT_EXTRA_RANGE = 8 -- studs beyond the prompt's own range (lag), checked on the server
local RETRY_SECONDS = 20 -- no clear spot found: try again this much later
local SPOT_TRIES = 48
local CLEAR_RADIUS = 18 -- studs around the impact that must be free of structures
local CLEAR_HEIGHT = 14 -- the free box starts just above the ground top
local FLAT_NORMAL_Y = 0.9 -- ground flatter than this only
local GROUND_TOP_Y = 0 -- WorldBuilder: ground top is at Y = 0 ...
local GROUND_TOLERANCE = 3 -- ... hits higher or lower are hills, the ridge or the crater
local MAP_HALF = 600 - 40 -- stay well inside the map edge (WorldBuilder GROUND_HALF = 600)
local PLAYER_CLEAR = 15 -- never land right on top of an astronaut
local NO_AIR_LINE_DELAY = 6 -- seconds after the hit line, C.A.R.L. explains why there was no streak
local DEBUG_RING_MIN = 25 -- DebugMeteor: studs from the player
local DEBUG_RING_MAX = 40
local DEBUG_CLEAR_RADIUS = 8

-- Layout (studs, WorldBuilder / WorldSites anchors): places a meteorite must not land on, as
-- centre (X, Z) and radius. The structures are listed even before they are built so a later
-- build never stands inside a crater.
local KEEP_CLEAR: { { x: number, z: number, r: number } } = {
	{ x = 0, z = 0, r = 60 }, -- habitat hub and its modules
	{ x = 70, z = -40, r = 40 }, -- regolith shelter
	{ x = 0, z = 230, r = 115 }, -- ice crater and its rim (drills inside)
	{ x = -190, z = -60, r = 100 }, -- solar ridge
	{ x = -60, z = 70, r = 35 }, -- antenna
	{ x = -75, z = 95, r = 25 }, -- lookout rock behind the antenna
	{ x = 230, z = 60, r = 65 }, -- observatory hill
	{ x = -295, z = -60, r = 60 }, -- lava tube hill
	{ x = 40, z = -130, r = 45 }, -- arrival lander and its crate depot
	{ x = -55, z = -35, r = 35 }, -- lab
	{ x = 95, z = 75, r = 45 }, -- garage
	{ x = -110, z = -180, r = 50 }, -- landing pad and ship
	{ x = 330, z = 260, r = 50 }, -- exploration sites (also read from world.pois)
	{ x = -380, z = 280, r = 50 },
	{ x = 400, z = -230, r = 50 },
	{ x = -220, z = -360, r = 50 },
	{ x = 160, z = 430, r = 50 },
}
local POI_CLEAR = 50

local ExploreService = {}

type Impact = {
	serial: number,
	model: Model,
	prompt: ProximityPrompt?,
	connection: RBXScriptConnection?,
	scannedBy: { [Player]: boolean },
}

local started = false
local world: any = nil
local base: any = nil
local tools: any = nil
local remotes: Remotes? = nil
local exploreRemote: RemoteEvent? = nil

local active: Impact? = nil
local impactSerial = 0
local countdown = 0
local warnedNoImpact = false
local lastScanAt: { [Player]: number } = {}
local sessionScanned: { [Player]: { [string]: boolean } } = {} -- fallback when BaseService has no markScanned
local poiIds: { string } = {}

----------------------------------------------------------------------------------------------------
-- Helpers

local function say(key: string, params: Params?)
	local events = remotes
	if events then
		local text: Types.TextRef = { key = key, params = params }
		events.message:FireAllClients(text)
	end
end

local function sayTo(player: Player, key: string, params: Params?)
	local events = remotes
	if events and player.Parent then
		local text: Types.TextRef = { key = key, params = params }
		events.message:FireClient(player, text)
	end
end

local function sendExplore(player: Player, event: ExploreEvent)
	local remote = exploreRemote
	if remote and player.Parent then
		remote:FireClient(player, event)
	end
end

-- Remotes.EXPLORE: the one Main.server passed, else found (or made) in ReplicatedStorage.Remotes.
local function findExploreRemote(given: RemoteEvent?): RemoteEvent?
	if given then
		return given
	end
	local folder = ReplicatedStorage:FindFirstChild(Types.Remotes.FOLDER)
	if folder == nil then
		return nil
	end
	local existing = folder:FindFirstChild(Types.Remotes.EXPLORE)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = Types.Remotes.EXPLORE
	event.Parent = folder
	return event
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

local function closeEnough(player: Player, prompt: ProximityPrompt): boolean
	local root = rootOf(player)
	local at = promptPosition(prompt)
	if root == nil or at == nil then
		return false
	end
	return (root.Position - at).Magnitude <= prompt.MaxActivationDistance + PROMPT_EXTRA_RANGE
end

local function cooledDown(player: Player): boolean
	local t = os.clock()
	local last = lastScanAt[player]
	if last and t - last < SCAN_COOLDOWN_SECONDS then
		return false
	end
	lastScanAt[player] = t
	return true
end

-- The tablet must be in hand (ToolService). Without ToolService every scan works (graceful).
local function holdsTablet(player: Player): boolean
	local api = tools
	if api == nil or type(api.isHolding) ~= "function" then
		return true
	end
	local ok, holding = pcall(api.isHolding, player, "tablet")
	return ok and holding == true
end

local function reward(player: Player, kind: string)
	local api = base
	if api and type(api.reward) == "function" then
		local ok, err = pcall(api.reward, player, kind)
		if not ok then
			warn(`[SpaceBaseOdyssey] explore reward failed: {err}`)
		end
	end
end

-- True the first time this player scans `key` (saved by BaseService; session-only fallback).
local function markScanned(player: Player, key: string): boolean
	local api = base
	if api and type(api.markScanned) == "function" then
		local ok, isNew = pcall(api.markScanned, player, key)
		if ok then
			return isNew == true
		end
		warn(`[SpaceBaseOdyssey] markScanned failed: {isNew}`)
		return false
	end
	local set: { [string]: boolean } = sessionScanned[player] or {}
	sessionScanned[player] = set
	local seen = set[key] == true
	set[key] = true
	return not seen
end

-- How many of the world's exploration sites this player has scanned.
local function scannedSiteCount(player: Player): number
	local scanned: any = nil
	local api = base
	if api and type(api.getState) == "function" then
		local ok, state = pcall(api.getState, player)
		if ok and type(state) == "table" and type(state.scanned) == "table" then
			scanned = state.scanned
		end
	end
	if scanned == nil then
		scanned = sessionScanned[player] or {}
	end
	local count = 0
	for _, id in poiIds do
		if scanned["poi:" .. id] == true or scanned[id] == true then
			count += 1
		end
	end
	return count
end

----------------------------------------------------------------------------------------------------
-- Exploration sites

local function onPoiScanned(player: Player, id: string, prompt: ProximityPrompt)
	if not closeEnough(player, prompt) or not cooledDown(player) then
		return
	end
	if not holdsTablet(player) then
		sayTo(player, "carl.tool.need_tablet_scan")
		return
	end
	local isNew = markScanned(player, "poi:" .. id)
	if isNew then
		reward(player, "poi_scanned")
	end
	sendExplore(player, { kind = "poi", id = id, isNew = isNew })
	if isNew and #poiIds > 0 and scannedSiteCount(player) >= #poiIds then
		task.delay(2, function()
			sayTo(player, "carl.explore.all_sites")
		end)
	end
end

local function connectPois()
	local list = world and world.pois
	if type(list) ~= "table" then
		warn("[SpaceBaseOdyssey] world has no pois; exploration sites are off")
		return
	end
	for _, entry in list do
		local id = if type(entry) == "table" then entry.id else nil
		local prompt = if type(entry) == "table" then entry.prompt else nil
		if type(id) ~= "string" or typeof(prompt) ~= "Instance" or not (prompt :: Instance):IsA("ProximityPrompt") then
			continue
		end
		local poiPrompt = prompt :: ProximityPrompt
		table.insert(poiIds, id)
		local position = entry.position
		if typeof(position) == "Vector3" then
			table.insert(KEEP_CLEAR, { x = position.X, z = position.Z, r = POI_CLEAR })
		end
		poiPrompt.Triggered:Connect(function(player: Player)
			local ok, err = pcall(onPoiScanned, player, id, poiPrompt)
			if not ok then
				warn(`[SpaceBaseOdyssey] site scan failed: {err}`)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Meteorite impacts

local function habitatCentre(): Vector3
	local zone = world and world.habitatZone
	if typeof(zone) == "Instance" and (zone :: Instance):IsA("BasePart") then
		local position = (zone :: BasePart).Position
		return Vector3.new(position.X, GROUND_TOP_Y, position.Z)
	end
	return Vector3.new(0, GROUND_TOP_Y, 0)
end

local function characters(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function inKeepClear(x: number, z: number): boolean
	for _, zone in KEEP_CLEAR do
		local dx = x - zone.x
		local dz = z - zone.z
		if dx * dx + dz * dz < zone.r * zone.r then
			return true
		end
	end
	return false
end

local function nearAPlayer(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local offset = root.Position - position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < PLAYER_CLEAR then
				return true
			end
		end
	end
	return false
end

-- The ground point under (x, z) when it is flat open ground (not a hill, the ridge or the crater).
local function groundAt(x: number, z: number, aroundY: number?, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local top = (aroundY or GROUND_TOP_Y) + 150
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -300, 0), params)
	if hit == nil or hit.Normal.Y < FLAT_NORMAL_Y then
		return nil
	end
	local wantY = aroundY or GROUND_TOP_Y
	if math.abs(hit.Position.Y - wantY) > GROUND_TOLERANCE then
		return nil
	end
	return hit.Position
end

-- Nothing (a structure, a rock, a vehicle, a sign) stands in the box just above the ground.
local function isOpen(position: Vector3, radius: number, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local centre = CFrame.new(position + Vector3.new(0, 1 + CLEAR_HEIGHT / 2, 0))
	local parts = workspace:GetPartBoundsInBox(centre, Vector3.new(radius * 2, CLEAR_HEIGHT, radius * 2), params)
	return #parts == 0
end

local function randomRingPoint(centre: Vector3, minRadius: number, maxRadius: number): (number, number)
	local angle = math.random() * math.pi * 2
	-- Uniform over the ring's area (not crowded at the inner edge).
	local r2 = minRadius * minRadius + math.random() * (maxRadius * maxRadius - minRadius * minRadius)
	local radius = math.sqrt(r2)
	return centre.X + math.cos(angle) * radius, centre.Z + math.sin(angle) * radius
end

-- A clear landing spot in the ring around the habitat, or nil.
local function findRingSpot(): Vector3?
	local centre = habitatCentre()
	local ignore = characters()
	for _ = 1, SPOT_TRIES do
		local x, z = randomRingPoint(centre, METEOR.RING_MIN, METEOR.RING_MAX)
		if math.abs(x) > MAP_HALF or math.abs(z) > MAP_HALF or inKeepClear(x, z) then
			continue
		end
		local ground = groundAt(x, z, nil, ignore)
		if ground and not nearAPlayer(ground) and isOpen(ground, CLEAR_RADIUS, ignore) then
			return ground
		end
	end
	return nil
end

-- DebugMeteor: a spot a short walk from the player (structures still avoided when possible).
local function findSpotNear(player: Player): Vector3?
	local root = rootOf(player)
	if root == nil then
		return nil
	end
	local ignore = characters()
	local footY = root.Position.Y - 3
	for _ = 1, SPOT_TRIES do
		local x, z = randomRingPoint(root.Position, DEBUG_RING_MIN, DEBUG_RING_MAX)
		if math.abs(x) > MAP_HALF or math.abs(z) > MAP_HALF then
			continue
		end
		local ground = groundAt(x, z, footY, ignore)
		if ground and isOpen(ground, DEBUG_CLEAR_RADIUS, ignore) then
			return ground
		end
	end
	-- Fallback: straight ahead of the player, on whatever ground is there.
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local ahead = root.Position + look.Unit * DEBUG_RING_MIN
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ahead + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position else nil
end

local function clearActive()
	local impact = active
	if impact == nil then
		return
	end
	active = nil
	if impact.connection then
		impact.connection:Disconnect()
	end
	local clear = world and world.clearImpact
	if type(clear) == "function" then
		local ok, err = pcall(clear, impact.model)
		if not ok then
			warn(`[SpaceBaseOdyssey] clearImpact failed: {err}`)
			impact.model:Destroy()
		end
	else
		impact.model:Destroy()
	end
end

local function onImpactScanned(player: Player, impact: Impact)
	if active ~= impact then
		return
	end
	local prompt = impact.prompt
	if prompt and not closeEnough(player, prompt) then
		return
	end
	if not cooledDown(player) then
		return
	end
	if not holdsTablet(player) then
		sayTo(player, "carl.tool.need_tablet_scan")
		return
	end
	local isNew = not impact.scannedBy[player]
	if isNew then
		impact.scannedBy[player] = true
		reward(player, "meteor_scanned")
		player:SetAttribute("SBO_ScannedImpact", impact.serial)
	end
	sendExplore(player, { kind = "meteor", id = "", isNew = isNew })
end

-- Lands a meteorite at `position` (ground point). Returns true when the world made the crater.
local function spawnAt(position: Vector3): boolean
	local spawnImpact = world and world.spawnImpact
	if type(spawnImpact) ~= "function" then
		if not warnedNoImpact then
			warnedNoImpact = true
			warn("[SpaceBaseOdyssey] world has no spawnImpact; meteorites are off")
		end
		return false
	end
	clearActive()
	local ok, model, prompt = pcall(spawnImpact, position)
	if not ok then
		warn(`[SpaceBaseOdyssey] spawnImpact failed: {model}`)
		return false
	end
	if typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
		return false
	end
	impactSerial += 1
	local impactModel = model :: Model
	local impact: Impact = {
		serial = impactSerial,
		model = impactModel,
		prompt = nil,
		connection = nil,
		scannedBy = {},
	}
	impactModel:SetAttribute("SBO_ImpactId", impact.serial)
	impactModel:SetAttribute("SBO_ExpiresAt", workspace:GetServerTimeNow() + METEOR.LIFETIME_SECONDS)
	if typeof(prompt) == "Instance" and (prompt :: Instance):IsA("ProximityPrompt") then
		local impactPrompt = prompt :: ProximityPrompt
		impact.prompt = impactPrompt
		impactPrompt.Enabled = true
		impact.connection = impactPrompt.Triggered:Connect(function(player: Player)
			local scanOk, err = pcall(onImpactScanned, player, impact)
			if not scanOk then
				warn(`[SpaceBaseOdyssey] meteor scan failed: {err}`)
			end
		end)
	end
	active = impact

	say("carl.meteor.hit")
	task.delay(NO_AIR_LINE_DELAY, function()
		if active == impact then
			say("carl.meteor.no_air")
		end
	end)
	task.delay(METEOR.LIFETIME_SECONDS, function()
		if active == impact then
			clearActive()
		end
	end)
	return true
end

local function nextWait(): number
	return math.random(METEOR.MIN_SECONDS, METEOR.MAX_SECONDS)
end

local function meteorTick()
	if active ~= nil then
		return -- one impact at a time; the next countdown starts when it is gone
	end
	if #Players:GetPlayers() == 0 then
		return -- nobody to see it: the clock waits
	end
	countdown -= TICK_SECONDS
	if countdown > 0 then
		return
	end
	local spot = findRingSpot()
	if spot and spawnAt(spot) then
		countdown = nextWait()
	else
		countdown = RETRY_SECONDS
	end
end

local function isDebugAllowed(player: Player, trusted: boolean?): boolean
	if trusted == true or RunService:IsStudio() then
		return true
	end
	return player.UserId == game.CreatorId
end

----------------------------------------------------------------------------------------------------
-- Public API

-- worldRefs: WorldBuilder.World (pois, spawnImpact, clearImpact, habitatZone); baseService: the
-- BaseService module (reward, markScanned, getState, setDebugMeteorHook); toolService: the
-- ToolService module (isHolding) or nil; remoteEvents.message = Remotes.MESSAGE,
-- remoteEvents.explore = Remotes.EXPLORE (found or made in ReplicatedStorage.Remotes when nil).
function ExploreService.start(worldRefs: any, baseService: any, toolService: any, remoteEvents: Remotes)
	assert(not started, "ExploreService already started")
	started = true
	world = worldRefs
	base = baseService
	tools = toolService
	remotes = remoteEvents
	exploreRemote = findExploreRemote(remoteEvents.explore)

	connectPois()

	if base and type(base.setDebugMeteorHook) == "function" then
		base.setDebugMeteorHook(function(player: Player, trusted: boolean?)
			ExploreService.debugMeteor(player, trusted)
		end)
	else
		warn("[SpaceBaseOdyssey] BaseService has no setDebugMeteorHook; DebugMeteor is off")
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastScanAt[player] = nil
		sessionScanned[player] = nil
		local impact = active
		if impact then
			impact.scannedBy[player] = nil
		end
	end)

	countdown = nextWait()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local ok, err = pcall(meteorTick)
			if not ok then
				warn(`[SpaceBaseOdyssey] meteor tick failed: {err}`)
			end
		end
	end)
end

-- DebugMeteor: an impact lands near the player right now (Studio or the place owner only).
function ExploreService.debugMeteor(player: Player, trusted: boolean?)
	if not started or not isDebugAllowed(player, trusted) then
		return
	end
	local spot = findSpotNear(player)
	if spot and spawnAt(spot) then
		countdown = nextWait()
	end
end

-- The meteorite crater on the Moon right now, or nil.
function ExploreService.activeImpact(): Model?
	local impact = active
	return if impact then impact.model else nil
end

return ExploreService
