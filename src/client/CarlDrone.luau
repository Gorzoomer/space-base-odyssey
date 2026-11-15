--!strict
-- Space Base Odyssey - C.A.R.L., the helper robot: a client-only model of a small tracked rover
-- that drives on the ground beside the local astronaut (right side, a little behind). The Moon has
-- no air, so there are no propellers: two treads roll it along, and when the player jumps (or the
-- ground ahead is a step too high or too low) it HOPS on a short arc with a puff from two small gas
-- thrusters at its back.
-- Its eyes, core band and mast light glow cyan when all is well, orange when the suit air is low,
-- a task is urgent or a storm warning is on, red while storm particles are here (Theme "Lunar
-- Sunrise" roles). In a storm an orange beam (the shelter colour) points from the mast light to the
-- shelter door until the player is safe inside.
-- Guidance (Settings: on by default): a cyan beam points exactly where C.A.R.L.'s words send the
-- player. First, in every phase:
--   a) a parts crate in hand: the build PAD waiting for it (Workspace.Base.BuildPads.<id>, never the
--      structure on it);
--   b) parts waiting at a pad this player works at (base mode: any pad): that pad, to assemble;
--   c) the latest C.A.R.L. line with a place (AssistantMessage remote), for up to 45 s or until it
--      is done: "need a crate" / "build started" / "step done" -> the crate prompt at the lander;
--      "hold your wrench" / "parts here" -> the pad; "hold the <tool>" -> the task the player just
--      tried; meteorite and exploring lines -> that site; "build the <id> first" -> that pad.
-- Then the next unfinished objective (its enabled task prompt, else its Workspace.Base.Markers
-- part; "clean a panel" is always the cleaning prompt of a DUSTY array, never a clean row); with no
-- such objective during a shift, the most useful task (ice to deliver, leak, dusty arrays, antenna,
-- ice). In base mode (Briefing, no mission running), in this order:
--   0) right after carried ice (rule 1), Stage 9: the CURRENT QUEST STEP (BaseState.quest, read
--      through Objectives.currentQuest; the step's type comes from src/shared/Quests.luau):
--        build    the habitat first when the base level is too low, then a missing required build,
--                 then the build's own step logic (pad or crate depot, as in 2); a build the player
--                 cannot pay for yet: earn credits (the silo when it has ice, else the crater ice);
--        mission  the mission console in the habitat ("MissionConsolePrompt"; else the Console
--                 marker);
--        ice      the crater ice (the water machine while carrying ice); silo: the silo with ice;
--        clean    a DUSTY array; meteor: a fresh crater; scan: the nearest unscanned site (any range);
--        skill / gear / tool_upgrade  the Lab prompt ("LabPrompt", else the lab pad);
--        eat      the greenhouse food prompt; vehicle: a vehicle prompt (else the garage pad);
--        visit    that place (lab, greenhouse, crater ice site, garage);
--        collectible  nothing (secrets are found by exploring).
--      A step with nowhere to go now falls through to the rules below.
--   1) carried ice: the water machine;
--   2) a build being built in steps (Stage 7: the pad attribute SBO_Phase "crate" | "assemble",
--      else BaseState.inProgress): the nearest step needing assembly (its pad); a step needing a
--      parts crate: that pad when the player carries one (BaseState.carryingCrate or player
--      attribute SBO_CarryingCrate), else the crate depot at the lander (the point of its prompt
--      "CratePrompt", TextKey "prompt.take_crate"; else the marker "CrateDepot");
--   3) a fresh meteorite crater (Workspace.Base.Impacts) this player has not scanned yet (impact
--      attribute SBO_ImpactId vs player attribute SBO_ScannedImpact), when the tablet is unlocked;
--   4) the cheapest build pad the player can pay for now (Workspace.Base.BuildPads, attributes
--      BuildId, SBO_Cost, SBO_Locked; pads already under way are skipped);
--   5) the nearest exploration site (a part with attribute PoiId) within 250 studs that this player
--      has not scanned (BaseState.scanned "poi:<id>"), when the tablet is unlocked;
--   6) the ice: the silo when it has ice, the ice site otherwise.
-- It hides within 8 studs. A "build_<id>" mission objective uses the same step logic as 2).
-- Vehicles (Stage 7): while the player drives, C.A.R.L. keeps up beside the vehicle (wider gap,
-- faster follow) and its raycasts skip the vehicle.
-- Earth skin (chosen in the Wardrobe: Equipped.carl == "earth"; older data: the hidden mini Earth):
-- the dome shows the real Earth (NASA Blue Marble map, Icons.earthMap) slowly turning; it is local
-- to that player.
-- Anchored Parts moved every frame with BulkMoveTo (no physics); it never collides, blocks clicks
-- or casts shadows. Ground and walls are found with a few raycasts per frame that skip characters,
-- C.A.R.L. itself, pets and parts that do not collide.
-- Stage 10: CarlDrone.setCinematic(true) keeps both beams off while a cinematic camera plays.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Objectives = require(script.Parent.Objectives)
local Theme = require(Shared:WaitForChild("Theme"))
local Icons = require(Shared:WaitForChild("Icons"))

-- Suit air below the meters' yellow zone counts as low (same 0-100 scale as the HUD bar).
local SUIT_LOW = MissionData.METERS.YELLOW_ZONE * MissionData.SUIT.MAX / 100

-- Visual tuning (not gameplay numbers).
local SIDE_OFFSET = 3.2 -- studs to the player's right
local BACK_OFFSET = 1.6 -- studs behind the player
local WALL_MARGIN = 1.3 -- keep this far from a wall between the player and the spot
local RAY_UP = 1.5 -- ground rays start this far above the player's root part ...
local RAY_DOWN = 30 -- ... and look this far down
local BODY_RAY_HEIGHT = 0.9 -- height of the "is the way blocked" ray above C.A.R.L.'s ground
local WALL_NORMAL_Y = 0.6 -- a hit surface steeper than this counts as a wall, not a slope
local FOLLOW_RATE = 5 -- higher = snappier driving
local GROUND_RATE = 14 -- how fast it settles on small bumps
local TURN_RATE = 6
local HEAD_TURN_RATE = 5
local HEAD_TURN_MAX = math.rad(70)
local FACE_TRAVEL_DISTANCE = 1.2 -- farther than this from the spot: face where it drives
local SNAP_DISTANCE = 40 -- teleports (rescue, respawn) snap instead of driving across the map
local STEP_HEIGHT = 2.5 -- a bigger step up or down makes C.A.R.L. hop
local HOP_MIN_SECONDS = 0.45
local HOP_MAX_SECONDS = 1.0
local HOP_SECONDS_PER_STUD = 0.03
local HOP_APEX = 1.6 -- arc height above the straight line between take-off and landing
local HOP_COOLDOWN = 0.15
local HOP_CHAIN_PROGRESS = 0.55 -- a new player jump can start a new hop after this much of the last one
local WHEEL_RADIUS = 0.23
local TRACK_HALF_WIDTH = 0.95 -- for the skid-steer roll difference when turning
local PUFF_COUNT = 8 -- pool of puff balls for the thrusters
local PUFF_SECONDS = 0.45
local PUFF_SIZE_START = 0.22
local PUFF_SIZE_END = 0.75
local NOZZLE_GLOW_SECONDS = 0.35
local COLOR_RATE = 4
local GUIDE_REFRESH_SECONDS = 0.25 -- where the guidance beam points is worked out 4 times a second
local FILTER_REFRESH_SECONDS = 1
local SILO_SEARCH_SECONDS = 2
local POI_SEARCH_SECONDS = 10 -- exploration sites are found again this often
local POI_GUIDE_RANGE = 250 -- studs: unscanned sites closer than this are worth a detour
local SEATED_SIDE_OFFSET = 7 -- while driving: beside the vehicle, not inside it
local SEATED_FOLLOW_RATE = 12

local PALETTE = Theme.PALETTE
local ROLE = Theme.ROLE
local COLOR_BODY = PALETTE.cream
local COLOR_TREAD = PALETTE.nightLight
local COLOR_WHEEL = PALETTE.night
local COLOR_HUB = PALETTE.creamDim
local COLOR_VISOR = PALETTE.night
local COLOR_METAL = PALETTE.creamDim
local CORE_NORMAL = ROLE.accent -- cyan: systems and guidance
local CORE_ALERT = ROLE.warning -- orange: warnings
local CORE_STORM = ROLE.danger -- red: particles are here
local BEAM_COLOR = ROLE.warning -- orange: the way to the shelter
local GUIDE_COLOR = ROLE.accent -- cyan: C.A.R.L.'s guidance
local PUFF_COLORS = { PALETTE.cream, ROLE.accent }
local GUIDE_HIDE_DISTANCE = 8 -- studs: close enough, the task marker and prompt take over

-- Earth skin: the Blue Marble map in a turning disc over the dome.
local EARTH_OCEAN = PALETTE.cyan:Lerp(PALETTE.night, 0.55) -- shows while the map image loads
local EARTH_COLLECTIBLE = "mini_earth" -- fallback when the server sends no Equipped yet
local EARTH_DISC_STUDS = 1.06
local EARTH_TURN_SECONDS = 40 -- one turn of the little Earth (decoration only)

local SHELTER_MARKER = "ShelterDoor"

-- Where each objective happens (marker names in Workspace.Base.Markers). Objectives that are not
-- in one place (finish_day, complete_days, survive_storm, stars_at_least) are skipped.
local OBJECTIVE_MARKERS: { [string]: string } = {
	go_outside = "LanderDoor", -- Stage 7: the game starts in the arrival lander
	return_inside = "HabitatDoor",
	align_antenna = "Antenna",
	clean_panel = "Arrays",
	drill_ice = "IceSite",
	repair_leak = "Leak",
	reach_shelter = "ShelterDoor",
	set_power = "Console",
	start_shift = "Console",
}
-- Build objectives ("build_<id>", Stages 6-7) happen at the build pad of that structure (and, while
-- it is built in steps, at the crate depot). They can all be done while planning.
local BUILD_OBJECTIVE_PREFIX = "build_"
-- Objectives that can be done while planning (the rest need the shift: the console starts it).
local PLANNING_OBJECTIVES: { [string]: boolean } = {
	go_outside = true,
	return_inside = true,
	set_power = true,
	start_shift = true,
}
local CRATE_DEPOT_MARKER = "CrateDepot"
local CRATE_PROMPT_KEY = "prompt.take_crate"
local CRATE_PROMPT_NAME = "CratePrompt"

-- Task prompts (TextKey) per objective: C.A.R.L. points at the nearest ENABLED one (a disabled
-- prompt is a task that cannot be done now), else at the objective's marker.
local CLEAN_PROMPT_KEYS: { [string]: boolean } = { ["prompt.clean"] = true }
local OBJECTIVE_PROMPTS: { [string]: { [string]: boolean } } = {
	align_antenna = { ["prompt.antenna"] = true },
	clean_panel = CLEAN_PROMPT_KEYS,
	drill_ice = { ["prompt.drill"] = true },
	repair_leak = { ["prompt.repair"] = true },
}

-- C.A.R.L.'s spoken instructions (AssistantMessage keys) and where each one sends the player.
local INSTRUCTION_SECONDS = 45 -- the beam follows the latest instruction this long at most
local BUILDER_SECONDS = 120 -- a player who worked at a pad this recently is "building" it
local BUILDER_PAD_RANGE = 30 -- studs: the pad the player stood at when C.A.R.L. answered
local TOOL_PROMPT_RANGE = 25 -- studs: "hold the <tool>" is about a task right beside the player
local DEPOT_KEYS: { [string]: boolean } = { -- go and get a parts crate
	["carl.base.need_crate"] = true,
	["carl.base.build_started"] = true,
	["carl.base.step_done"] = true,
}
local PAD_KEYS: { [string]: boolean } = { -- the parts are at the pad: assemble them there
	["carl.base.need_wrench"] = true,
	["carl.base.crate_delivered"] = true,
}
local BUILDER_KEYS: { [string]: boolean } = {
	["carl.base.need_crate"] = true,
	["carl.base.build_started"] = true,
	["carl.base.step_done"] = true,
	["carl.base.need_wrench"] = true,
	["carl.base.crate_delivered"] = true,
	["carl.base.crate_taken"] = true,
}
-- "carl.tool.need_<tool>": the task that tool is for (TextKey of its prompt).
local TOOL_KEY_PREFIX = "carl.tool.need_"
local TOOL_PROMPT_KEYS: { [string]: { [string]: boolean } } = {
	drill = { ["prompt.drill"] = true },
	brush = CLEAN_PROMPT_KEYS,
	tablet = { ["prompt.antenna"] = true },
	tablet_scan = { ["prompt.scan"] = true },
	repair_kit = { ["prompt.repair"] = true },
}
local METEOR_KEY_PREFIX = "carl.meteor."
local EXPLORE_KEY_PREFIX = "carl.explore."
local EXPLORE_ALL_KEY = "carl.explore.all_sites" -- every site scanned: nowhere to go
local BUILD_FIRST_PREFIX = "carl.build_first." -- "build the <id> at the glowing pad first"
local DUST_KEY = "carl.dust"
local MARKER_KEYS: { [string]: string } = {
	["carl.leak"] = "Leak",
	["carl.return_inside"] = "HabitatDoor",
	["carl.vehicle.need_ice"] = "IceSite",
}
-- Lines that say the instruction is done.
local DONE_KEYS: { [string]: boolean } = {
	["carl.base.crate_taken"] = true,
	["carl.base.upgraded"] = true,
	["carl.panel_clean"] = true,
	["carl.leak_fixed"] = true,
	["carl.antenna_linked"] = true,
	["carl.ice_picked"] = true,
	["carl.ice_delivered"] = true,
}
local BUILT_KEY_PREFIX = "carl.base.built_"
local UPGRADED_KEY = "carl.base.upgraded"

local CarlDrone = {}

-- How a piece moves with the rover: "body" (rigid), "head" (turns with the head), "wheelL" /
-- "wheelR" (rolls with that tread). `after` is applied after the wheel roll (hub stripes).
type PieceKind = "body" | "head" | "wheelL" | "wheelR"
type Piece = { part: BasePart, offset: CFrame, kind: PieceKind, after: CFrame }
type Hop = { from: Vector3, to: Vector3, started: number, duration: number, apex: number }
type Puff = { part: BasePart, born: number, velocity: Vector3, alive: boolean }

local player = Players.LocalPlayer
local started = false
local cinematic = false -- Stage 10: a cinematic camera is playing (setCinematic): no beams
-- Where the guidance beam points now (a Part or an Attachment), read by Markers.luau.
local currentGuide: Instance? = nil

local function newPart(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- The seat the local astronaut sits in (a vehicle), or nil.
local function seatedIn(): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if humanoid then humanoid.SeatPart else nil
end

-- Stage 6 Store helpers (added by the UI): read through `any` so this file also works without them.
local function baseState(): any
	local store: any = Store
	if type(store.getBase) == "function" then
		local ok, state = pcall(store.getBase)
		if ok and type(state) == "table" then
			return state
		end
	end
	return nil
end

local function wantsEarthSkin(): boolean
	local store: any = Store
	if type(store.equipped) == "function" and baseState() ~= nil then
		local ok, equipped = pcall(store.equipped)
		if ok and type(equipped) == "table" then
			return equipped.carl == "earth"
		end
	end
	return Store.hasCollectible(EARTH_COLLECTIBLE)
end

local function coreTarget(stage: Store.StormStage): Color3
	if stage == "storm" then
		return CORE_STORM
	elseif stage == "warning" then
		return CORE_ALERT
	end
	local stats = Store.getStats()
	if stats and stats.suitO2 < SUIT_LOW then
		return CORE_ALERT
	end
	local snap = Store.getSnapshot()
	local shift = if snap and snap.phase == "Shift" then snap.shift else nil
	if shift and (shift.leakActive or shift.dustyArrays > 0) then
		return CORE_ALERT
	end
	return CORE_NORMAL
end

local function carryingIce(): boolean
	local stats = Store.getStats()
	return stats ~= nil and stats.carryingIce
end

local function baseFolder(name: string): Instance?
	local base = workspace:FindFirstChild("Base")
	return if base then base:FindFirstChild(name) else nil
end

-- World position of a guidance target: a Part (marker, pad) or an Attachment (a prompt point).
local function targetPosition(target: Instance?): Vector3?
	if target == nil or target.Parent == nil then
		return nil
	end
	if target:IsA("BasePart") then
		return (target :: BasePart).Position
	elseif target:IsA("Attachment") then
		return (target :: Attachment).WorldPosition
	end
	return nil
end

-- Distance from the player to a target (0 without a character, huge when it has no position).
local function distanceTo(target: Instance): number
	local position = targetPosition(target)
	if position == nil then
		return math.huge
	end
	local root = rootPart()
	return if root then (position - root.Position).Magnitude else 0
end

-- Where a prompt is in the world: its Attachment or Part (a Model's main part), or nil.
local function promptPoint(prompt: ProximityPrompt): Instance?
	local holder = prompt.Parent
	if holder and holder:IsA("Model") then
		holder = holder.PrimaryPart or holder:FindFirstChildWhichIsA("BasePart", true)
	end
	if holder and (holder:IsA("Attachment") or holder:IsA("BasePart")) then
		return holder
	end
	return nil
end

-- Every ProximityPrompt in Workspace (filled in CarlDrone.start and kept up to date).
local knownPrompts: { [ProximityPrompt]: boolean } = {}

local function promptTextKey(prompt: ProximityPrompt): string?
	local key = prompt:GetAttribute("TextKey")
	return if type(key) == "string" and key ~= "" then key else nil
end

-- The nearest ENABLED prompt whose TextKey is in `keys` (within `range` studs of the player when
-- given), or nil. A disabled prompt is a task that cannot be done now (a clean panel, a fixed leak).
local function nearestPrompt(keys: { [string]: boolean }, range: number?): ProximityPrompt?
	local root = rootPart()
	local best: ProximityPrompt? = nil
	local bestDistance = range or math.huge
	for prompt in knownPrompts do
		if prompt.Parent == nil then
			knownPrompts[prompt] = nil
			continue
		end
		local key = promptTextKey(prompt)
		if not prompt.Enabled or key == nil or not keys[key] then
			continue
		end
		local position = targetPosition(promptPoint(prompt))
		if position == nil then
			continue
		end
		local distance = if root then (position - root.Position).Magnitude else 0
		if distance <= bestDistance then
			best = prompt
			bestDistance = distance
		end
	end
	return best
end

local function nearestPromptPoint(keys: { [string]: boolean }, range: number?): Instance?
	local prompt = nearestPrompt(keys, range)
	return if prompt then promptPoint(prompt) else nil
end

-- A DUSTY solar array: its cleaning prompt is enabled only while that array is dusty (the server
-- turns it off on clean arrays), so C.A.R.L. never points at a clean row.
local function dustyArrayTarget(): Instance?
	return nearestPromptPoint(CLEAN_PROMPT_KEYS)
end

-- The build pad Part for one structure (Workspace.Base.BuildPads.<id>), or nil. Always the pad,
-- never the structure standing on it.
local function buildPad(id: string): BasePart?
	local pads = baseFolder("BuildPads")
	local pad = if pads then pads:FindFirstChild(id) else nil
	if pad and pad:IsA("BasePart") then
		return pad
	end
	return nil
end

-- The cheapest build pad the player can pay for now (not locked, not at its top level), or nil.
local function affordablePad(): BasePart?
	local state = baseState()
	local credits = if state and type(state.credits) == "number" then state.credits else nil
	local pads = baseFolder("BuildPads")
	if credits == nil or not pads then
		return nil
	end
	local best: BasePart? = nil
	local bestCost = math.huge
	for _, pad in pads:GetChildren() do
		if not pad:IsA("BasePart") then
			continue
		end
		local cost = pad:GetAttribute("SBO_Cost")
		if type(cost) ~= "number" or pad:GetAttribute("SBO_Locked") == true then
			continue
		end
		-- Stage 9: the base level (habitat) is too low for this structure's next level.
		local habNeed = pad:GetAttribute("SBO_HabNeed")
		if type(habNeed) ~= "number" then
			local level = pad:GetAttribute("SBO_Level")
			local buildId = pad:GetAttribute("BuildId")
			habNeed = BaseBuild.habitatNeeded(
				MissionData,
				if type(buildId) == "string" then buildId else pad.Name,
				(if type(level) == "number" then level else 0) + 1
			)
		end
		if type(habNeed) == "number" and Store.buildLevel("habitat") < habNeed then
			continue
		end
		-- A build already under way is not "next" (the step guidance handles it).
		local phase = pad:GetAttribute("SBO_Phase")
		if phase == "crate" or phase == "assemble" then
			continue
		end
		if cost <= credits and cost < bestCost then
			best = pad
			bestCost = cost
		end
	end
	return best
end

-- The ice silo: Markers.Silo when the world has it, else a Part named "Silo" (or the part holding
-- a "SiloPrompt") somewhere in Workspace.Base, searched at most every SILO_SEARCH_SECONDS.
local siloCache: BasePart? = nil
local siloSearchedAt = -math.huge
local function siloPart(): BasePart?
	local marker = Store.findMarker("Silo")
	if marker then
		return marker
	end
	if siloCache and siloCache.Parent ~= nil then
		return siloCache
	end
	local now = os.clock()
	if now - siloSearchedAt < SILO_SEARCH_SECONDS then
		return nil
	end
	siloSearchedAt = now
	siloCache = nil
	local base = workspace:FindFirstChild("Base")
	if not base then
		return nil
	end
	local prompt = base:FindFirstChild("SiloPrompt", true)
	local holder = if prompt then prompt.Parent else nil
	if holder and holder:IsA("Attachment") then
		holder = holder.Parent
	end
	if not (holder and holder:IsA("BasePart")) then
		local silo = base:FindFirstChild("Silo", true)
		if silo and silo:IsA("Model") then
			holder = silo.PrimaryPart or silo:FindFirstChildWhichIsA("BasePart", true)
		else
			holder = silo
		end
	end
	if holder and holder:IsA("BasePart") then
		siloCache = holder
	end
	return siloCache
end

-- Stage 7: the parts crate depot at the lander's cargo bay: the point of its "take crate" prompt
-- ("CratePrompt", TextKey "prompt.take_crate"), else the guidance marker CrateDepot.
local depotPrompt: ProximityPrompt? = nil
local function crateDepotTarget(): Instance?
	local cached = depotPrompt
	if cached == nil or cached.Parent == nil then
		depotPrompt = nil
		for prompt in knownPrompts do
			if prompt.Parent ~= nil and (prompt.Name == CRATE_PROMPT_NAME or promptTextKey(prompt) == CRATE_PROMPT_KEY) then
				depotPrompt = prompt
				break
			end
		end
		cached = depotPrompt
	end
	local point = if cached then promptPoint(cached) else nil
	return point or Store.findMarker(CRATE_DEPOT_MARKER)
end

-- Is the player carrying a parts crate from the lander?
local function carryingCrate(): boolean
	if player:GetAttribute("SBO_CarryingCrate") == true then
		return true
	end
	local state = baseState()
	return state ~= nil and state.carryingCrate == true
end

-- A tool the player can carry (BaseState.tools). Without that field (older data) every tool counts.
local function hasTool(id: string): boolean
	local state = baseState()
	local list = if state then state.tools else nil
	if type(list) ~= "table" then
		return true
	end
	local level = list[id]
	return type(level) == "number" and level > 0
end

-- What the build at this pad needs next while it is built in steps: "crate" (bring parts),
-- "assemble" (the parts are there: use the wrench) or nil (not being built). The pad attribute
-- SBO_Phase set by the server comes first (it replicates at once; "idle" = nothing under way), else
-- BaseState.inProgress.
local function stepNeed(id: string, pad: BasePart?): string?
	local phase = if pad then pad:GetAttribute("SBO_Phase") else nil
	if phase == "crate" or phase == "assemble" then
		return phase
	elseif type(phase) == "string" then
		return nil
	end
	local state = baseState()
	local list = if state then state.inProgress else nil
	if type(list) == "table" then
		local progress = list[id]
		if type(progress) ~= "table" then
			return nil
		end
		return if progress.crate == true then "assemble" else "crate"
	end
	return nil
end

local function padIdOf(pad: BasePart): string
	local id = pad:GetAttribute("BuildId")
	return if type(id) == "string" then id else pad.Name
end

-- A pad whose build needs `need` ("crate" | "assemble") now: `preferred` when it does, else the
-- nearest such pad, or nil.
local function padNeeding(need: string, preferred: BasePart?): BasePart?
	if preferred and preferred.Parent ~= nil and stepNeed(padIdOf(preferred), preferred) == need then
		return preferred
	end
	local pads = baseFolder("BuildPads")
	if not pads then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") and stepNeed(padIdOf(pad), pad) == need then
			local distance = distanceTo(pad)
			if distance < bestDistance then
				best = pad
				bestDistance = distance
			end
		end
	end
	return best
end

-- The nearest build pad within `range` studs of the player (any phase), or nil.
local function padNearPlayer(range: number): BasePart?
	local pads = baseFolder("BuildPads")
	if not pads then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = range
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") then
			local distance = distanceTo(pad)
			if distance <= bestDistance then
				best = pad
				bestDistance = distance
			end
		end
	end
	return best
end

-- Where to go for the next step of one build (the crate depot first when parts are needed and the
-- player has none, else its pad).
local function buildStepTarget(id: string): Instance?
	local pad = buildPad(id)
	if stepNeed(id, pad) == "crate" and not carryingCrate() then
		return crateDepotTarget() or pad
	end
	return pad
end

-- Builds in progress (base mode): the nearest pad waiting for the crate the player carries, else
-- the nearest step to assemble, else the crate depot (a step needs parts), or nil.
local function stepTarget(): Instance?
	local deliver = padNeeding("crate", nil)
	if deliver and carryingCrate() then
		return deliver
	end
	local assemble = padNeeding("assemble", nil)
	if assemble then
		return assemble
	end
	if deliver then
		return crateDepotTarget() or deliver
	end
	return nil
end

-- A fresh meteorite crater this player has not scanned yet (Workspace.Base.Impacts), or nil.
-- needTablet = only when the tablet is unlocked (base-mode suggestions).
local function impactTarget(needTablet: boolean): Instance?
	local impacts = baseFolder("Impacts")
	if not impacts or (needTablet and not hasTool("tablet")) then
		return nil
	end
	local scanned = player:GetAttribute("SBO_ScannedImpact")
	for _, impact in impacts:GetChildren() do
		local id = impact:GetAttribute("SBO_ImpactId")
		if id ~= nil and id == scanned then
			continue
		end
		local prompt = impact:FindFirstChildWhichIsA("ProximityPrompt", true)
		local point: Instance? = if prompt then promptPoint(prompt) else nil
		if point == nil and impact:IsA("Model") then
			point = impact.PrimaryPart or impact:FindFirstChildWhichIsA("BasePart", true)
		elseif point == nil and impact:IsA("BasePart") then
			point = impact
		end
		if point then
			return point
		end
	end
	return nil
end

-- Exploration sites: every part with the attribute PoiId (searched every POI_SEARCH_SECONDS).
local poiCache: { BasePart } = {}
local poiSearchedAt = -math.huge
local function poiParts(): { BasePart }
	local now = os.clock()
	if now - poiSearchedAt < POI_SEARCH_SECONDS then
		return poiCache
	end
	poiSearchedAt = now
	local found: { BasePart } = {}
	local base = workspace:FindFirstChild("Base")
	if base then
		for _, item in base:GetDescendants() do
			if item:IsA("BasePart") and type(item:GetAttribute("PoiId")) == "string" then
				table.insert(found, item)
			end
		end
	end
	poiCache = found
	return found
end

-- The nearest exploration site within `range` studs (default POI_GUIDE_RANGE) this player has not
-- scanned, or nil.
local function poiTarget(needTablet: boolean, range: number?): BasePart?
	local root = rootPart()
	if not root or (needTablet and not hasTool("tablet")) then
		return nil
	end
	local state = baseState()
	local scanned: { [string]: any } = if state and type(state.scanned) == "table" then state.scanned else {}
	local best: BasePart? = nil
	local bestDistance = range or POI_GUIDE_RANGE
	for _, part in poiParts() do
		local id = part:GetAttribute("PoiId")
		if part.Parent == nil or type(id) ~= "string" then
			continue
		end
		if scanned["poi:" .. id] == true or scanned[id] == true then
			continue
		end
		local distance = (part.Position - root.Position).Magnitude
		if distance < bestDistance then
			best = part
			bestDistance = distance
		end
	end
	return best
end

-- C.A.R.L.'s latest spoken instruction that names a place (AssistantMessage remote). The beam
-- follows it for INSTRUCTION_SECONDS, or until the job is done (see instructionTarget).
type InstructionKind = "depot" | "pad" | "prompt" | "impact" | "poi" | "build" | "marker" | "dusty"
type Instruction = { kind: InstructionKind, at: number, prompt: ProximityPrompt?, name: string? }
local instruction: Instruction? = nil
-- The pad this player last worked at (started, delivered, assembled, or was told what it needs).
local builderPad: BasePart? = nil
local builderAt = -math.huge

local function instructionTarget(): Instance?
	local current = instruction
	if current == nil then
		return nil
	end
	if os.clock() - current.at > INSTRUCTION_SECONDS then
		instruction = nil
		return nil
	end
	local kind = current.kind
	if kind == "depot" then
		-- "Bring a parts crate": the depot, while a build still waits for parts and the hands are free.
		if carryingCrate() or padNeeding("crate", nil) == nil then
			return nil
		end
		return crateDepotTarget()
	elseif kind == "pad" then
		-- "Hold your wrench and build": the pad whose parts are waiting.
		local recent = if os.clock() - builderAt <= BUILDER_SECONDS then builderPad else nil
		return padNeeding("assemble", recent)
	elseif kind == "prompt" then
		-- "Hold the <tool>": the task the player just tried, while it can still be done.
		local prompt = current.prompt
		if prompt == nil or prompt.Parent == nil or not prompt.Enabled then
			return nil
		end
		return promptPoint(prompt)
	elseif kind == "impact" then
		return impactTarget(false)
	elseif kind == "poi" then
		return poiTarget(false)
	elseif kind == "build" then
		return if current.name then buildStepTarget(current.name) else nil
	elseif kind == "dusty" then
		return dustyArrayTarget()
	elseif kind == "marker" then
		return if current.name then Store.findMarker(current.name) else nil
	end
	return nil
end

local function setInstruction(kind: InstructionKind, prompt: ProximityPrompt?, name: string?)
	instruction = { kind = kind, at = os.clock(), prompt = prompt, name = name }
end

-- A line from C.A.R.L. arrived (server TextRef key): remember where it sends the player.
local function onAssistantMessage(key: string)
	if BUILDER_KEYS[key] then
		builderAt = os.clock()
		if key ~= "carl.base.crate_taken" then
			-- Said at the pad (the server only answers a pad prompt near it).
			builderPad = padNearPlayer(BUILDER_PAD_RANGE) or builderPad
		end
	end
	if DEPOT_KEYS[key] then
		setInstruction("depot")
	elseif PAD_KEYS[key] then
		setInstruction("pad")
	elseif string.sub(key, 1, #TOOL_KEY_PREFIX) == TOOL_KEY_PREFIX then
		local keys = TOOL_PROMPT_KEYS[string.sub(key, #TOOL_KEY_PREFIX + 1)]
		local prompt = if keys then nearestPrompt(keys, TOOL_PROMPT_RANGE) else nil
		if prompt then
			setInstruction("prompt", prompt)
		end
	elseif string.sub(key, 1, #METEOR_KEY_PREFIX) == METEOR_KEY_PREFIX then
		setInstruction("impact")
	elseif string.sub(key, 1, #EXPLORE_KEY_PREFIX) == EXPLORE_KEY_PREFIX and key ~= EXPLORE_ALL_KEY then
		setInstruction("poi")
	elseif string.sub(key, 1, #BUILD_FIRST_PREFIX) == BUILD_FIRST_PREFIX then
		setInstruction("build", nil, string.sub(key, #BUILD_FIRST_PREFIX + 1))
	elseif key == DUST_KEY then
		setInstruction("dusty")
	elseif MARKER_KEYS[key] then
		setInstruction("marker", nil, MARKER_KEYS[key])
	elseif DONE_KEYS[key] or string.sub(key, 1, #BUILT_KEY_PREFIX) == BUILT_KEY_PREFIX then
		instruction = nil
	end
	if key == UPGRADED_KEY or string.sub(key, 1, #BUILT_KEY_PREFIX) == BUILT_KEY_PREFIX then
		builderAt = -math.huge -- the build is finished
		builderPad = nil
	end
end

-- What C.A.R.L.'s own words ask for, before mission objectives and suggestions:
--   1) a parts crate in hand: the build pad waiting for it;
--   2) parts waiting at a pad this player works at (or any, in base mode): that pad, to assemble;
--   3) the latest instruction with a place (instructionTarget).
local function priorityTarget(phase: string): Instance?
	local recentPad = if os.clock() - builderAt <= BUILDER_SECONDS then builderPad else nil
	if carryingCrate() then
		local pad = padNeeding("crate", recentPad)
		if pad then
			return pad
		end
	end
	if phase == "Briefing" or recentPad ~= nil then
		local pad = padNeeding("assemble", recentPad)
		if pad then
			return pad
		end
	end
	return instructionTarget()
end

local function isBuildObjective(id: string): boolean
	return string.sub(id, 1, #BUILD_OBJECTIVE_PREFIX) == BUILD_OBJECTIVE_PREFIX
end

local function doableWhilePlanning(id: string): boolean
	return PLANNING_OBJECTIVES[id] == true or isBuildObjective(id)
end

-- Where one objective happens, or nil when it is not done in one place (or not now).
local function objectiveTarget(id: string, phase: string): Instance?
	local isBuild = isBuildObjective(id)
	if phase == "Planning" and not doableWhilePlanning(id) then
		return nil
	end
	if id == "deliver_ice" or id == "deliver_ice_total" then
		return Store.findMarker(if carryingIce() then "Processor" else "IceSite")
	end
	if isBuild then
		return buildStepTarget(string.sub(id, #BUILD_OBJECTIVE_PREFIX + 1))
	end
	if id == "clean_panel" then
		return dustyArrayTarget() -- only a dusty array; with none there is nothing to clean
	end
	local keys = OBJECTIVE_PROMPTS[id]
	local point = if keys then nearestPromptPoint(keys) else nil
	if point then
		return point
	end
	local marker = OBJECTIVE_MARKERS[id]
	return if marker then Store.findMarker(marker) else nil
end

-- The most useful task right now during a shift (free play, or objectives with no place).
local function usefulTaskTarget(): Instance?
	local snap = Store.getSnapshot()
	local shift = if snap then snap.shift else nil
	if not shift then
		return nil
	end
	if carryingIce() then
		return Store.findMarker("Processor")
	elseif shift.leakActive then
		return nearestPromptPoint(OBJECTIVE_PROMPTS.repair_leak) or Store.findMarker("Leak")
	end
	if shift.dustyArrays > 0 then
		local dusty = dustyArrayTarget()
		if dusty then
			return dusty
		end
	end
	if not shift.antennaLinked then
		local antenna = nearestPromptPoint(OBJECTIVE_PROMPTS.align_antenna)
		if antenna then
			return antenna
		end
	end
	return Store.findMarker("IceSite")
end

-- Stage 9 quests ---------------------------------------------------------------------------------

local LAB_PROMPT_NAME = "LabPrompt"
local CONSOLE_PROMPT_NAME = "MissionConsolePrompt"
local FOOD_PROMPT_KEYS: { [string]: boolean } = { ["prompt.pick_food"] = true }
local VEHICLE_PROMPT_KEYS: { [string]: boolean } = { ["prompt.take_vehicle"] = true }
local DRILL_PROMPT_KEYS: { [string]: boolean } = { ["prompt.drill"] = true }
local QUEST_BUILD_DEPTH = 3 -- habitat -> required build -> build: never deeper

-- The point of the nearest enabled prompt with this Name, or nil.
local function namedPromptPoint(name: string): Instance?
	local root = rootPart()
	local best: Instance? = nil
	local bestDistance = math.huge
	for prompt in knownPrompts do
		if prompt.Parent == nil or prompt.Name ~= name or not prompt.Enabled then
			continue
		end
		local point = promptPoint(prompt)
		local position = targetPosition(point)
		if point and position then
			local distance = if root then (position - root.Position).Magnitude else 0
			if distance < bestDistance then
				best = point
				bestDistance = distance
			end
		end
	end
	return best
end

local function credits(): number
	local state = baseState()
	return if state and type(state.credits) == "number" then state.credits else 0
end

-- Builds standing in this server (BaseState.builds; empty before it arrives).
local function effectiveBuilds(): { [string]: number }
	local state = baseState()
	return if state and type(state.builds) == "table" then state.builds else {}
end

-- The crater ice (the water machine while carrying ice).
local function iceTarget(): Instance?
	if carryingIce() then
		return Store.findMarker("Processor")
	end
	return Store.findMarker("IceSite") or nearestPromptPoint(DRILL_PROMPT_KEYS)
end

-- Not enough credits: the silo when it has ice to claim, else the crater ice.
local function earnTarget(): Instance?
	local state = baseState()
	local siloIce = if state and type(state.siloIce) == "number" then state.siloIce else 0
	if siloIce >= 1 and not carryingIce() then
		local silo = siloPart()
		if silo then
			return silo
		end
	end
	return iceTarget()
end

local function labTarget(): Instance?
	return namedPromptPoint(LAB_PROMPT_NAME) or buildPad("lab")
end

-- Where to go to build `id` up to `level`: the habitat first when the base level is too low, then a
-- missing required build, then the build's own steps; short of credits: earn them.
local function questBuildTarget(id: string, level: number, depth: number): Instance?
	local current = Store.buildLevel(id)
	if current >= level or depth > QUEST_BUILD_DEPTH then
		return nil
	end
	local pad = buildPad(id)
	if stepNeed(id, pad) ~= nil then
		return buildStepTarget(id) -- already under way: the crate or the wrench
	end
	local nextLevel = current + 1
	if id ~= "habitat" then
		local habNeed = BaseBuild.habitatNeeded(MissionData, id, nextLevel)
		if habNeed ~= nil and BaseBuild.habitatLevel(effectiveBuilds()) < habNeed then
			return questBuildTarget("habitat", habNeed, depth + 1)
		end
	end
	local def = BaseBuild.buildDef(MissionData, id)
	if def then
		for needId, needLevel in def.requires do
			if Store.buildLevel(needId) < needLevel then
				return questBuildTarget(needId, needLevel, depth + 1)
			end
		end
	end
	local cost = BaseBuild.nextCost(MissionData, effectiveBuilds(), id)
	if cost ~= nil and credits() < cost then
		return earnTarget()
	end
	return buildStepTarget(id)
end

-- Where one quest step happens now, or nil (nowhere to go yet: the other rules lead on).
local function questStepTarget(step: Objectives.QuestStep): Instance?
	local def = step.def
	if def == nil or step.done then
		return nil
	end
	local kind = def.type
	if kind == "build" then
		return if def.id then questBuildTarget(def.id, def.level or 1, 0) else nil
	elseif kind == "mission" then
		if Store.isMissionSelectOpen() then
			return nil -- choosing a mission right now
		end
		return namedPromptPoint(CONSOLE_PROMPT_NAME) or Store.findMarker("Console") or Store.findMarker("HabitatDoor")
	elseif kind == "ice" then
		return iceTarget()
	elseif kind == "silo" then
		local state = baseState()
		local siloIce = if state and type(state.siloIce) == "number" then state.siloIce else 0
		return if siloIce >= 1 then siloPart() else nil
	elseif kind == "clean" then
		return dustyArrayTarget()
	elseif kind == "meteor" then
		return impactTarget(true)
	elseif kind == "scan" then
		return poiTarget(true, math.huge)
	elseif kind == "skill" then
		local state = baseState()
		local points = if state and type(state.skillPoints) == "number" then state.skillPoints else 0
		return if points >= 1 then labTarget() else nil
	elseif kind == "tool_upgrade" then
		local toolId = def.id or "drill"
		local cost = BaseBuild.toolUpgradeCost(MissionData, toolId, Store.toolLevel(toolId))
		if cost ~= nil and credits() < cost then
			return earnTarget()
		end
		return labTarget()
	elseif kind == "gear" then
		local gear = if def.id then BaseBuild.gearDef(MissionData, def.id) else nil
		local state = baseState()
		local playerLevel = if state and type(state.level) == "number" then state.level else 1
		if gear and playerLevel < gear.minLevel[1] then
			return nil -- not yet: the player level grows with everything else
		end
		if gear and credits() < gear.costs[1] then
			return earnTarget()
		end
		return labTarget()
	elseif kind == "eat" then
		return nearestPromptPoint(FOOD_PROMPT_KEYS)
	elseif kind == "vehicle" then
		if seatedIn() ~= nil then
			return nil
		end
		return nearestPromptPoint(VEHICLE_PROMPT_KEYS) or buildPad("garage")
	elseif kind == "visit" then
		local place = def.place
		if place == "lab" then
			return labTarget()
		elseif place == "greenhouse" then
			return buildPad("greenhouse") or nearestPromptPoint(FOOD_PROMPT_KEYS)
		elseif place == "crater" then
			return Store.findMarker("IceSite") or nearestPromptPoint(DRILL_PROMPT_KEYS)
		elseif place == "garage" then
			return buildPad("garage") or nearestPromptPoint(VEHICLE_PROMPT_KEYS)
		end
	end
	return nil -- collectible: secrets are found by exploring
end

-- The current quest step's place (base mode), or nil.
local function questTarget(): Instance?
	local quest = Objectives.currentQuest()
	local step = Objectives.currentStep(quest)
	if step then
		local target = questStepTarget(step)
		if target then
			return target
		end
	end
	-- The current step has nowhere to go now: try the quest's other open steps.
	if quest then
		for _, other in quest.steps do
			if other ~= step and not other.done then
				local target = questStepTarget(other)
				if target then
					return target
				end
			end
		end
	end
	return nil
end

-- Base mode (Briefing): carried ice, the current quest step, build steps, a fresh meteorite crater,
-- the next build the player can pay for, a nearby unscanned site, else ice.
local function baseModeTarget(): Instance?
	if carryingIce() then
		local processor = Store.findMarker("Processor")
		if processor then
			return processor
		end
	end
	local quest = questTarget()
	if quest then
		return quest
	end
	local step = stepTarget()
	if step then
		return step
	end
	local impact = impactTarget(true)
	if impact then
		return impact
	end
	local pad = affordablePad()
	if pad then
		return pad
	end
	local site = poiTarget(true)
	if site then
		return site
	end
	local state = baseState()
	local siloIce = if state and type(state.siloIce) == "number" then state.siloIce else 0
	if siloIce >= 1 then
		local silo = siloPart()
		if silo then
			return silo
		end
	end
	return Store.findMarker("IceSite")
end

-- Where C.A.R.L.'s guidance beam should point now, or nil.
local function guidanceTarget(): Instance?
	if not Store.settingOn("guidance") then
		return nil
	end
	local phase = Store.phase()
	if phase ~= "Briefing" and phase ~= "Planning" and phase ~= "Shift" then
		return nil
	end
	local first = priorityTarget(phase)
	if first then
		return first
	end
	if phase == "Briefing" then
		return baseModeTarget()
	end
	local mission = Store.mission()
	local objectives = if mission then mission.objectives else nil
	local hasShiftTask = false
	if type(objectives) == "table" then
		for _, objective in objectives do
			if objective.done then
				continue
			end
			local target = objectiveTarget(objective.id, phase)
			if target then
				return target
			end
			if phase == "Planning" and not doableWhilePlanning(objective.id) then
				hasShiftTask = true
			end
		end
	end
	if phase == "Planning" then
		-- Shift tasks wait: the shift starts at the console.
		return if hasShiftTask then Store.findMarker("Console") else nil
	end
	return usefulTaskTarget()
end

-- A small Earth for C.A.R.L.'s dome: a round CanvasGroup with two copies of the Blue Marble map
-- side by side, scrolled left to right (Earth turns west to east), a soft shade on one side and a
-- thin cyan atmosphere ring. Returns the gui and its scrolling strip.
local function makeEarthSkin(adornee: BasePart): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EarthSkin"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(EARTH_DISC_STUDS, EARTH_DISC_STUDS)
	gui.LightInfluence = 0.3
	gui.MaxDistance = 150
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local group = Instance.new("CanvasGroup")
	group.Name = "Globe"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = EARTH_OCEAN
	group.BorderSizePixel = 0
	group.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = group

	-- The disc shows half of the map's width (180 degrees of longitude): each copy is 2 discs wide.
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Size = UDim2.fromScale(4, 1)
	strip.Position = UDim2.fromScale(-2, 0)
	strip.Parent = group
	for copy = 0, 1 do
		local map = Instance.new("ImageLabel")
		map.Name = "Map" .. tostring(copy + 1)
		map.BackgroundTransparency = 1
		map.BorderSizePixel = 0
		map.Image = Icons.earthMap
		map.ScaleType = Enum.ScaleType.Stretch
		map.Size = UDim2.fromScale(0.5, 1)
		map.Position = UDim2.fromScale(copy * 0.5, 0)
		map.Parent = strip
	end

	-- Round look: darker towards the right edge (night side) and a little at the left limb.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = PALETTE.night
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 2
	shade.Parent = group
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	gradient.Rotation = 15
	gradient.Parent = shade

	local ring = Instance.new("UIStroke")
	ring.Color = PALETTE.cyan
	ring.Thickness = 1.5
	ring.Transparency = 0.35
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = group

	gui.Parent = adornee
	return gui, strip
end

-- Smallest signed angle from a to b (radians).
local function angleDelta(a: number, b: number): number
	return (b - a + math.pi) % (math.pi * 2) - math.pi
end

-- Yaw (rotation about +Y) that makes -Z point along a flat direction.
local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function CarlDrone.start()
	if started then
		return
	end
	started = true

	local model = Instance.new("Model")
	model.Name = "CarlDrone_Local"

	local pieces: { Piece } = {}
	local function add(part: BasePart, offset: CFrame, kind: PieceKind?, after: CFrame?)
		table.insert(pieces, { part = part, offset = offset, kind = kind or "body", after = after or CFrame.identity })
	end

	local plastic = Enum.Material.SmoothPlastic
	local neon = Enum.Material.Neon
	local metal = Enum.Material.Metal
	local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- turns a Cylinder's X axis upright
	local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a Cylinder's X axis front to back

	-- Offsets are from the ground point under the middle of the rover; its front is -Z.
	-- Treads: a dark housing per side with three road wheels on the outside, each with a hub stripe
	-- so the rolling shows.
	for _, side in { -1, 1 } do
		local kind: PieceKind = if side < 0 then "wheelL" else "wheelR"
		local sideName = if side < 0 then "Left" else "Right"
		add(
			newPart(model, "Tread" .. sideName, Enum.PartType.Block, Vector3.new(0.46, 0.5, 1.7), COLOR_TREAD, plastic),
			CFrame.new(side * 0.8, 0.3, 0)
		)
		for index, z in { -0.6, 0, 0.6 } do
			local center = CFrame.new(side * 1.07, 0.27, z)
			add(
				newPart(model, "Wheel" .. sideName .. index, Enum.PartType.Cylinder, Vector3.new(0.14, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2), COLOR_WHEEL, plastic),
				center,
				kind
			)
			add(
				newPart(model, "Hub" .. sideName .. index, Enum.PartType.Block, Vector3.new(0.04, WHEEL_RADIUS * 1.8, 0.09), COLOR_HUB, plastic),
				center,
				kind,
				CFrame.new(side * 0.075, 0, 0)
			)
		end
	end
	-- Body with a glowing core band, and two thruster nozzles at the back, low down.
	local body = newPart(model, "Body", Enum.PartType.Block, Vector3.new(1.2, 0.6, 1.3), COLOR_BODY, plastic)
	add(body, CFrame.new(0, 0.85, 0))
	local band = newPart(model, "CoreBand", Enum.PartType.Block, Vector3.new(1.24, 0.1, 1.34), CORE_NORMAL, neon)
	add(band, CFrame.new(0, 0.7, 0))
	local nozzleExits: { CFrame } = {}
	local nozzleGlows: { BasePart } = {}
	for _, side in { -1, 1 } do
		local sideName = if side < 0 then "Left" else "Right"
		add(
			newPart(model, "Nozzle" .. sideName, Enum.PartType.Cylinder, Vector3.new(0.26, 0.2, 0.2), COLOR_METAL, metal),
			CFrame.new(side * 0.35, 0.62, 0.74) * ALONG_Z
		)
		local glow = newPart(model, "NozzleGlow" .. sideName, Enum.PartType.Cylinder, Vector3.new(0.04, 0.14, 0.14), PALETTE.cream, neon)
		glow.Transparency = 1
		add(glow, CFrame.new(side * 0.35, 0.62, 0.88) * ALONG_Z)
		table.insert(nozzleGlows, glow)
		table.insert(nozzleExits, CFrame.new(side * 0.35, 0.62, 0.9))
	end
	-- Head: a neck, a round dome with a visor and two glowing eyes, and a short mast with a light
	-- where the beams start. The head turns toward what C.A.R.L. points at.
	add(
		newPart(model, "Neck", Enum.PartType.Cylinder, Vector3.new(0.3, 0.3, 0.3), COLOR_METAL, metal),
		CFrame.new(0, 1.28, 0) * VERTICAL,
		"head"
	)
	local head = newPart(model, "Head", Enum.PartType.Ball, Vector3.new(1, 1, 1), COLOR_BODY, plastic)
	add(head, CFrame.new(0, 1.75, 0), "head")
	add(
		newPart(model, "Visor", Enum.PartType.Block, Vector3.new(0.72, 0.34, 0.2), COLOR_VISOR, Enum.Material.Glass),
		CFrame.new(0, 1.8, -0.4),
		"head"
	)
	local eyeLeft = newPart(model, "EyeLeft", Enum.PartType.Ball, Vector3.new(0.17, 0.17, 0.17), CORE_NORMAL, neon)
	add(eyeLeft, CFrame.new(-0.16, 1.81, -0.5), "head")
	local eyeRight = newPart(model, "EyeRight", Enum.PartType.Ball, Vector3.new(0.17, 0.17, 0.17), CORE_NORMAL, neon)
	add(eyeRight, CFrame.new(0.16, 1.81, -0.5), "head")
	add(
		newPart(model, "Mast", Enum.PartType.Cylinder, Vector3.new(0.45, 0.07, 0.07), COLOR_METAL, metal),
		CFrame.new(0.18, 2.38, 0.12) * VERTICAL,
		"head"
	)
	local bulb = newPart(model, "MastLight", Enum.PartType.Ball, Vector3.new(0.18, 0.18, 0.18), CORE_NORMAL, neon)
	add(bulb, CFrame.new(0.18, 2.66, 0.12), "head")

	local light = Instance.new("PointLight")
	light.Color = CORE_NORMAL
	light.Range = 7
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = bulb

	-- Storm guide beam: from the mast light to an attachment inside the shelter door marker.
	local beamStart = Instance.new("Attachment")
	beamStart.Name = "BeamStart"
	beamStart.Parent = bulb
	local beam = Instance.new("Beam")
	beam.Name = "ShelterBeam"
	beam.Attachment0 = beamStart
	beam.Color = ColorSequence.new(BEAM_COLOR)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 4
	beam.FaceCamera = true
	beam.Width0 = 0.3
	beam.Width1 = 0.8
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = model
	-- Guidance beam (cyan): same start, ends inside the target part.
	local guide = Instance.new("Beam")
	guide.Name = "GuideBeam"
	guide.Attachment0 = beamStart
	guide.Color = ColorSequence.new(GUIDE_COLOR)
	guide.LightEmission = 1
	guide.LightInfluence = 0
	guide.Brightness = 3
	guide.FaceCamera = true
	guide.Width0 = 0.2
	guide.Width1 = 0.6
	guide.Segments = 1
	guide.Enabled = false
	guide.Parent = model

	-- Thruster puffs: a small pool of fading balls (no textures, no physics).
	local puffFolder = Instance.new("Folder")
	puffFolder.Name = "Puffs"
	puffFolder.Parent = model
	local puffs: { Puff } = {}
	for index = 1, PUFF_COUNT do
		local part = newPart(puffFolder, "Puff" .. index, Enum.PartType.Ball, Vector3.one * PUFF_SIZE_START, PUFF_COLORS[(index % #PUFF_COLORS) + 1], neon)
		part.Transparency = 1
		table.insert(puffs, { part = part, born = 0, velocity = Vector3.zero, alive = false })
	end

	model.PrimaryPart = body
	model.Parent = workspace

	-- Where a beam ends: an Attachment target (a prompt point) itself, else one local attachment per
	-- target part, created on first use (markers and pads can be rebuilt).
	local targetAttachments: { [BasePart]: Attachment } = {}
	local function attachmentFor(target: Instance): Attachment?
		if target:IsA("Attachment") then
			return target :: Attachment
		end
		if not target:IsA("BasePart") then
			return nil
		end
		local part = target :: BasePart
		local existing = targetAttachments[part]
		if existing and existing.Parent == part then
			return existing
		end
		for other, attachment in targetAttachments do
			if attachment.Parent == nil or other.Parent == nil then
				targetAttachments[other] = nil
			end
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "CarlBeamEnd_Local"
		attachment.Parent = part
		targetAttachments[part] = attachment
		return attachment
	end

	local earthGui, earthStrip = makeEarthSkin(head)
	local earthSkin: boolean? = nil
	local function applySkin()
		local wanted = wantsEarthSkin()
		if wanted == earthSkin then
			return
		end
		earthSkin = wanted
		-- The map disc replaces the plain dome; visor and eyes stay in front.
		head.Transparency = if wanted then 1 else 0
		earthGui.Enabled = wanted
	end
	applySkin()
	Store.onChanged(function(kind: Store.ChangeKind)
		local name: string = kind
		if name == "progress" or name == "base" then
			applySkin()
		elseif name == "explore" then
			-- A site or crater was scanned: a "hold the tablet to scan it" instruction is done.
			local current = instruction
			if current and (current.kind == "prompt" or current.kind == "impact" or current.kind == "poi") then
				instruction = nil
			end
		end
	end)

	-- Guidance target, worked out every GUIDE_REFRESH_SECONDS (guideAt = when it last was).
	local guideTarget: Instance? = nil
	local guideAt = -math.huge

	-- Every ProximityPrompt in Workspace (task prompts, the crate depot, build pads).
	local function watchPrompt(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			knownPrompts[instance :: ProximityPrompt] = true
		end
	end
	workspace.DescendantAdded:Connect(watchPrompt)
	workspace.DescendantRemoving:Connect(function(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			knownPrompts[instance :: ProximityPrompt] = nil
		end
	end)
	for _, descendant in workspace:GetDescendants() do
		watchPrompt(descendant)
	end

	-- C.A.R.L.'s lines from the server: the beam follows what they ask for.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
		local messageRemote = remotes:WaitForChild(Types.Remotes.MESSAGE)
		if messageRemote:IsA("RemoteEvent") then
			messageRemote.OnClientEvent:Connect(function(ref: any)
				if type(ref) == "table" and type(ref.key) == "string" then
					onAssistantMessage(ref.key)
					guideAt = -math.huge -- point the new way at once
				end
			end)
		end
	end)

	-- Raycasts: skip characters, C.A.R.L., pets and anything that does not collide.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true
	rayParams.IgnoreWater = true
	local filterAt = -math.huge
	local filterSeat: BasePart? = nil
	local function refreshFilter(now: number)
		local seat = seatedIn()
		if now - filterAt < FILTER_REFRESH_SECONDS and seat == filterSeat then
			return
		end
		filterAt = now
		filterSeat = seat
		local list: { Instance } = { model }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		for _, name in { "Pets", "SBO_Pets", "Vehicles" } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				table.insert(list, folder)
			end
		end
		local baseVehicles = baseFolder("Vehicles")
		if baseVehicles then
			table.insert(list, baseVehicles)
		end
		-- The vehicle the player drives (its whole model), wherever it lives.
		if seat then
			local top: Instance = seat
			while true do
				local parent = top.Parent
				if parent == nil or not parent:IsA("Model") then
					break
				end
				top = parent
			end
			table.insert(list, top)
		end
		rayParams.FilterDescendantsInstances = list
	end

	local function groundAt(position: Vector3, fromY: number): number?
		local origin = Vector3.new(position.X, fromY, position.Z)
		local hit = workspace:Raycast(origin, Vector3.new(0, -RAY_DOWN, 0), rayParams)
		return if hit then hit.Position.Y else nil
	end

	-- Hop on the player's jump (each time the Humanoid enters Jumping) and on the double jump
	-- (Gear.luau, the air boots, sets the character attribute SBO_DoubleJumpAt; it only changes velocity, so the
	-- Humanoid does not enter Jumping again).
	local jumpRequested = false
	local humanoidConnection: RBXScriptConnection? = nil
	local doubleJumpConnection: RBXScriptConnection? = nil
	local function watchCharacter(character: Model)
		if humanoidConnection then
			humanoidConnection:Disconnect()
			humanoidConnection = nil
		end
		if doubleJumpConnection then
			doubleJumpConnection:Disconnect()
		end
		doubleJumpConnection = character:GetAttributeChangedSignal("SBO_DoubleJumpAt"):Connect(function()
			jumpRequested = true
		end)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") and character.Parent ~= nil then
			humanoidConnection = humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
				if new == Enum.HumanoidStateType.Jumping then
					jumpRequested = true
				end
			end)
		end
	end
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	local parts: { BasePart } = {}
	for _, piece in pieces do
		table.insert(parts, piece.part)
	end
	local cframes: { CFrame } = table.create(#pieces, CFrame.identity)

	-- Rover state.
	local position: Vector3? = nil -- ground point under the middle of the rover
	local yaw = 0
	local headYaw = 0
	local rollLeft = 0
	local rollRight = 0
	local hop: Hop? = nil
	local landedAt = -math.huge
	local lastGood: Vector3? = nil -- last spot beside the player with ground under it
	local nozzleGlowUntil = 0
	local coreColor = CORE_NORMAL

	local function emitPuffs(cf: CFrame, now: number, perNozzle: number)
		local back = cf.LookVector * -1
		local emitted = 0
		for _, puff in puffs do
			if emitted >= perNozzle * #nozzleExits then
				break
			end
			if puff.alive then
				continue
			end
			local exit = nozzleExits[(emitted % #nozzleExits) + 1]
			local spread = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 1.5
			puff.alive = true
			puff.born = now
			puff.velocity = Vector3.new(0, -3.5, 0) + back * 1.5 + spread
			puff.part.Size = Vector3.one * PUFF_SIZE_START
			puff.part.Transparency = 0.15
			puff.part.CFrame = cf * exit
			emitted += 1
		end
		nozzleGlowUntil = now + NOZZLE_GLOW_SECONDS
	end

	local function updatePuffs(now: number, deltaTime: number)
		for _, puff in puffs do
			if not puff.alive then
				continue
			end
			local age = (now - puff.born) / PUFF_SECONDS
			if age >= 1 then
				puff.alive = false
				puff.part.Transparency = 1
				continue
			end
			puff.velocity *= math.exp(-deltaTime * 4)
			puff.part.CFrame = puff.part.CFrame + puff.velocity * deltaTime
			local size = PUFF_SIZE_START + (PUFF_SIZE_END - PUFF_SIZE_START) * age
			puff.part.Size = Vector3.one * size
			puff.part.Transparency = 0.15 + 0.85 * age
		end
	end

	local function startHop(from: Vector3, to: Vector3, now: number, cf: CFrame)
		local distance = (to - from).Magnitude
		local duration = math.clamp(HOP_MIN_SECONDS + distance * HOP_SECONDS_PER_STUD, HOP_MIN_SECONDS, HOP_MAX_SECONDS)
		local rise = math.abs(to.Y - from.Y)
		hop = { from = from, to = to, started = now, duration = duration, apex = HOP_APEX + rise * 0.5 }
		emitPuffs(cf, now, 2)
	end

	local function hide()
		position = nil
		hop = nil
		beam.Enabled = false
		guide.Enabled = false
		currentGuide = nil
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local root = rootPart()
		if not root then
			-- Between characters (respawn): no beam; the next character gets a fresh snap.
			hide()
			return
		end
		local now = os.clock()
		refreshFilter(now)
		local stage = Store.stormStage()
		local stats = Store.getStats()
		local sheltered = stats ~= nil and stats.sheltered

		-- 1) The spot beside the player: right side, a little behind, on the ground. If a wall stands
		--    between the player and that spot, pull the spot back to the player's side of it.
		local rootCf = root.CFrame
		local rootPos = rootCf.Position
		local playerLook = flat(rootCf.LookVector)
		if playerLook.Magnitude < 0.01 then
			playerLook = Vector3.new(0, 0, -1)
		end
		playerLook = playerLook.Unit
		local playerRight = Vector3.new(-playerLook.Z, 0, playerLook.X)
		local driving = seatedIn() ~= nil
		local sideOffset = if driving then SEATED_SIDE_OFFSET else SIDE_OFFSET
		local followRate = if driving then SEATED_FOLLOW_RATE else FOLLOW_RATE
		local spot = rootPos + playerRight * sideOffset - playerLook * BACK_OFFSET
		local toSpot = spot - rootPos
		local wall = workspace:Raycast(rootPos, toSpot, rayParams)
		if wall and math.abs(wall.Normal.Y) < WALL_NORMAL_Y then
			local reach = math.max(0, (wall.Position - rootPos).Magnitude - WALL_MARGIN)
			spot = rootPos + toSpot.Unit * reach
		end
		local spotGround = groundAt(spot, rootPos.Y + RAY_UP)
		local target: Vector3
		local good = lastGood
		if spotGround then
			target = Vector3.new(spot.X, spotGround, spot.Z)
			lastGood = target
		elseif good and (good - rootPos).Magnitude < SNAP_DISTANCE then
			target = good
		else
			local under = groundAt(rootPos, rootPos.Y + RAY_UP)
			target = Vector3.new(spot.X, under or (rootPos.Y - 3), spot.Z)
		end

		-- 2) What C.A.R.L. looks at: the shelter door in a storm, or the guidance target.
		local guiding = stage ~= "none" and not sheltered
		local door = if guiding then Store.findMarker(SHELTER_MARKER) else nil
		if now - guideAt >= GUIDE_REFRESH_SECONDS then
			guideAt = now
			guideTarget = if guiding then nil else guidanceTarget()
			currentGuide = guideTarget
		end
		local shownGuide: Instance? = nil
		local candidate = guideTarget
		local candidatePosition = targetPosition(candidate)
		if candidate and candidatePosition and (candidatePosition - rootPos).Magnitude > GUIDE_HIDE_DISTANCE then
			shownGuide = candidate
		end
		local lookAtPosition: Vector3? = if door then door.Position else targetPosition(shownGuide)

		-- 3) Move: snap, hop or drive.
		local current = position
		if current == nil or (current - target).Magnitude > SNAP_DISTANCE then
			current = target
			hop = nil
			yaw = yawOf(playerLook)
		end
		local pos = current :: Vector3
		local currentCf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		local moved = Vector3.zero
		local activeHop = hop
		if activeHop then
			-- The landing follows the spot while in the air, so the hop ends beside the player.
			activeHop.to = target
			local s = math.clamp((now - activeHop.started) / activeHop.duration, 0, 1)
			local line = activeHop.from:Lerp(activeHop.to, s)
			local newPos = line + Vector3.new(0, 4 * activeHop.apex * s * (1 - s), 0)
			moved = flat(newPos - pos)
			pos = newPos
			if s >= 1 then
				hop = nil
				landedAt = now
				emitPuffs(currentCf, now, 1)
			elseif jumpRequested and s >= HOP_CHAIN_PROGRESS then
				-- A double jump: start a fresh hop from here.
				jumpRequested = false
				startHop(pos, target, now, currentCf)
			end
		else
			local canHop = now - landedAt >= HOP_COOLDOWN
			local offset = target - pos
			local stepTooBig = math.abs(offset.Y) > STEP_HEIGHT
			local bodyUp = Vector3.new(0, BODY_RAY_HEIGHT, 0)
			local blocked = false
			if flat(offset).Magnitude > 0.5 then
				local hit = workspace:Raycast(pos + bodyUp, (target + bodyUp) - (pos + bodyUp), rayParams)
				-- Only something wall-like blocks the way (a gentle slope is driven up).
				blocked = hit ~= nil and math.abs(hit.Normal.Y) < WALL_NORMAL_Y
			end
			if canHop and (jumpRequested or stepTooBig or blocked) then
				jumpRequested = false
				startHop(pos, target, now, currentCf)
			else
				jumpRequested = false
				-- Drive on the ground toward the spot, settling on small bumps.
				local alpha = 1 - math.exp(-deltaTime * followRate)
				local nextXZ = flat(pos):Lerp(flat(target), alpha)
				local groundHere = groundAt(nextXZ, math.max(pos.Y, target.Y) + RAY_UP + BODY_RAY_HEIGHT)
				local y = pos.Y
				if groundHere and math.abs(groundHere - pos.Y) <= STEP_HEIGHT then
					y = pos.Y + (groundHere - pos.Y) * (1 - math.exp(-deltaTime * GROUND_RATE))
				elseif groundHere == nil then
					y = pos.Y + (target.Y - pos.Y) * alpha
				end
				local newPos = Vector3.new(nextXZ.X, y, nextXZ.Z)
				moved = flat(newPos - pos)
				pos = newPos
			end
		end
		position = pos

		-- 4) Turn: face where it drives when going somewhere, else what it points at (or the
		--    player's way). The head turns further toward what it points at.
		local remaining = flat(target - pos).Magnitude
		local wantYaw = yaw
		local travelling = moved.Magnitude > 0.002 and (remaining > FACE_TRAVEL_DISTANCE or hop ~= nil)
		if travelling then
			wantYaw = yawOf(moved)
		elseif lookAtPosition then
			local toLook = flat(lookAtPosition - pos)
			wantYaw = if toLook.Magnitude > 0.1 then yawOf(toLook) else yawOf(playerLook)
		else
			wantYaw = yawOf(playerLook)
		end
		local yawStep = angleDelta(yaw, wantYaw) * (1 - math.exp(-deltaTime * TURN_RATE))
		yaw += yawStep
		local headWant = 0
		if lookAtPosition then
			local toLook = flat(lookAtPosition - pos)
			if toLook.Magnitude > 0.1 then
				headWant = math.clamp(angleDelta(yaw, yawOf(toLook)), -HEAD_TURN_MAX, HEAD_TURN_MAX)
			end
		end
		headYaw += (headWant - headYaw) * (1 - math.exp(-deltaTime * HEAD_TURN_RATE))

		-- 5) Treads roll by the distance driven (skid steer: turning rolls them opposite ways).
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		if hop == nil then
			local forward = moved:Dot(cf.LookVector)
			rollLeft = (rollLeft + (forward - yawStep * TRACK_HALF_WIDTH) / WHEEL_RADIUS) % (math.pi * 2)
			rollRight = (rollRight + (forward + yawStep * TRACK_HALF_WIDTH) / WHEEL_RADIUS) % (math.pi * 2)
		end
		local headCf = cf * CFrame.Angles(0, headYaw, 0)
		local rollLeftCf = CFrame.Angles(-rollLeft, 0, 0)
		local rollRightCf = CFrame.Angles(-rollRight, 0, 0)
		for index, piece in pieces do
			local kind = piece.kind
			if kind == "head" then
				cframes[index] = headCf * piece.offset
			elseif kind == "wheelL" then
				cframes[index] = cf * piece.offset * rollLeftCf * piece.after
			elseif kind == "wheelR" then
				cframes[index] = cf * piece.offset * rollRightCf * piece.after
			else
				cframes[index] = cf * piece.offset
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

		-- Thruster glow and puffs.
		local glowing = now < nozzleGlowUntil
		for _, glow in nozzleGlows do
			glow.Transparency = if glowing then 0.1 + 0.9 * (1 - (nozzleGlowUntil - now) / NOZZLE_GLOW_SECONDS) else 1
		end
		updatePuffs(now, deltaTime)

		-- Core colour eases toward the state colour (eyes, band, mast light).
		coreColor = coreColor:Lerp(coreTarget(stage), 1 - math.exp(-deltaTime * COLOR_RATE))
		band.Color = coreColor
		eyeLeft.Color = coreColor
		eyeRight.Color = coreColor
		bulb.Color = coreColor
		light.Color = coreColor

		-- Shelter beam, pulsing so it catches the eye.
		local doorEnd = if door then attachmentFor(door) else nil
		local showBeam = doorEnd ~= nil
		if doorEnd then
			beam.Attachment1 = doorEnd
			local wave = (math.sin(now * 6) + 1) / 2
			beam.Transparency = NumberSequence.new(0.05 + 0.35 * wave)
		end
		beam.Enabled = showBeam and not cinematic

		-- Guidance beam: calmer pulse, fading toward the target.
		local guideEnd = if shownGuide and door == nil then attachmentFor(shownGuide) else nil
		local showGuide = guideEnd ~= nil
		if guideEnd then
			guide.Attachment1 = guideEnd
			local wave = (math.sin(now * 2.5) + 1) / 2
			local near = 0.15 + 0.3 * wave
			guide.Transparency = NumberSequence.new(near, math.min(0.9, near + 0.35))
		end
		guide.Enabled = showGuide and not cinematic

		-- Earth skin: turn the little Earth (one turn every EARTH_TURN_SECONDS).
		if earthSkin then
			local turn = (now / EARTH_TURN_SECONDS) % 1
			earthStrip.Position = UDim2.fromScale(-2 + turn * 2, 0)
		end
	end)
end

-- Stage 10: while a cinematic camera plays (Cinematic.luau) the shelter and guidance beams stay off.
function CarlDrone.setCinematic(on: boolean)
	cinematic = on == true
	local model = workspace:FindFirstChild("CarlDrone_Local")
	if cinematic and model then
		for _, name in { "ShelterBeam", "GuideBeam" } do
			local item = model:FindFirstChild(name)
			if item and item:IsA("Beam") then
				item.Enabled = false
			end
		end
	end
end

-- Where C.A.R.L.'s guidance beam points now (a Part or a prompt's Attachment), or nil: no guidance,
-- a storm (the shelter beam), or nothing to do. Markers.luau shows that task's marker from afar.
function CarlDrone.currentTarget(): Instance?
	local target = currentGuide
	if target and target.Parent ~= nil then
		return target
	end
	return nil
end

return CarlDrone
