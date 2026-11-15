--!strict
-- Space Base Odyssey - guided tips. Short C.A.R.L. tips and power-board highlights that never block
-- play: every control stays usable. Each tip shows at most once per mission and waits in the
-- Messages tip queue so tips never overwrite each other or a real event message.
-- Tips run only where they teach something new (story chapters show the objectives panel instead):
--   Tutorial t2_power, Planning: highlight Life support and Science; Greenhouse "food comes tomorrow".
--   Tutorial t2_power, Shift: follow the markers.
--   Tutorial t3_tasks, Shift: tasks have markers, the antenna gives early warnings, ice is in the crater.
--   Free play day 1 and day 2: the original guided days (power board, tasks, then the Greenhouse).
--   Safety, any mission (once each): follow C.A.R.L.'s light to the shelter; low suit air, go inside.
-- Stage 6-7, the new start: the player lands in the arrival lander and the base is still empty.
--   Base mode (Briefing, mission select closed), each tip once per visit, in this order: "you
--   landed, let's build a base"; build the Moon home (habitat) first and follow C.A.R.L.; then for
--   a build being built in steps: take a parts box from the lander, carry it to the build spot,
--   hold the wrench to put it together; once the habitat stands: build the solar panels next; then
--   bring ice to earn credits, until the four main builds stand.
--   Any mission with an open build objective (build_habitat, build_solar, build_greenhouse,
--   build_antenna, build_shelter): one tip that says what to build, in Planning and in the shift.
--   A new tool unlocked (brush, repair kit, tablet, food) or the lab / garage just built: one tip
--   that says what it is for. The first meteorite crater seen with the tablet: how to scan it.
--   The "jump" skill learned: how to double jump.
-- Build steps come from BaseState.inProgress (or the pad attribute SBO_Phase when the Store does
-- not carry it yet); a carried crate from BaseState.carryingCrate or the player attribute
-- SBO_CarryingCrate.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local PowerBoard = require(script.Parent.PowerBoard)
local Store = require(script.Parent.Store)

type TextRef = Store.TextRef
type Allocation = { LifeSupport: number, Greenhouse: number, Science: number }
-- Which guide applies to the current mission and day (nil = no onboarding tips).
type GuideMode = "power" | "tasks" | "storm" | "free"

local GUIDED_SYSTEMS: { string } = { "LifeSupport", "Greenhouse", "Science" }

local SUIT_LOW = MissionData.METERS.YELLOW_ZONE * MissionData.SUIT.MAX / 100
local GUIDED_DAYS: number = MissionData.MISSION.GUIDED_DAYS
local CHECK_SECONDS = 0.5 -- storm stage follows server time

-- Tip for each open build objective (keys quoted in full so the localization test checks them).
local BUILD_TIPS: { [string]: string } = {
	build_habitat = "tip.build_habitat",
	build_solar = "tip.build_solar",
	build_greenhouse = "tip.build_greenhouse",
	build_antenna = "tip.build_antenna",
	build_shelter = "tip.build_shelter",
}

-- Stage 7: a tool just unlocked (the wrench and drill come from the start) and builds just finished.
local TOOL_TIPS: { [string]: string } = {
	brush = "tip.tool_brush",
	repair_kit = "tip.tool_repair_kit",
	tablet = "tip.tool_tablet",
	food = "tip.tool_food",
}
local BUILT_TIPS: { [string]: string } = {
	lab = "tip.lab_built",
	garage = "tip.garage_built",
}
local CORE_BUILDS: { string } = { "solar", "greenhouse", "antenna", "shelter" }

export type Deps = {
	show: (ref: TextRef) -> (), -- urgent: shown before queued tips
	showTip: (ref: TextRef, phase: string?) -> (),
	setGuide: (guide: PowerBoard.Guide?) -> (),
}

local Onboarding = {}

local function guideMode(day: number): GuideMode?
	local mission = Store.mission()
	if mission == nil then
		-- Older server without missions: the classic guided first days.
		return if day <= GUIDED_DAYS then "free" else nil
	end
	if mission.kind == "Free" then
		return if day <= GUIDED_DAYS then "free" else nil
	elseif mission.kind == "Tutorial" then
		if mission.id == "t2_power" then
			return "power"
		elseif mission.id == "t3_tasks" then
			return "tasks"
		elseif mission.id == "t4_storm" then
			return "storm"
		end
	end
	return nil
end

-- Build steps under way in this server: does any step wait for a parts crate, or for assembly?
-- BaseState.inProgress when the Store carries it, else the pads' SBO_Phase attributes.
local function stepNeeds(state: any): (boolean, boolean)
	local needsCrate = false
	local needsAssembly = false
	local list = if type(state) == "table" then state.inProgress else nil
	if type(list) == "table" then
		for _, progress in list do
			if type(progress) == "table" then
				if progress.crate == true then
					needsAssembly = true
				else
					needsCrate = true
				end
			end
		end
		return needsCrate, needsAssembly
	end
	local base = workspace:FindFirstChild("Base")
	local pads = if base then base:FindFirstChild("BuildPads") else nil
	if pads then
		for _, pad in pads:GetChildren() do
			local phase = pad:GetAttribute("SBO_Phase")
			if phase == "crate" then
				needsCrate = true
			elseif phase == "assemble" then
				needsAssembly = true
			end
		end
	end
	return needsCrate, needsAssembly
end

-- Is the habitat (or any build) being built in steps right now?
local function inProgress(state: any, id: string): boolean
	local list = if type(state) == "table" then state.inProgress else nil
	if type(list) == "table" then
		return type(list[id]) == "table"
	end
	local base = workspace:FindFirstChild("Base")
	local pads = if base then base:FindFirstChild("BuildPads") else nil
	local pad = if pads then pads:FindFirstChild(id) else nil
	local phase = if pad then pad:GetAttribute("SBO_Phase") else nil
	return phase == "crate" or phase == "assemble"
end

local function carryingCrate(state: any): boolean
	local player = Players.LocalPlayer
	if player:GetAttribute("SBO_CarryingCrate") == true then
		return true
	end
	return type(state) == "table" and state.carryingCrate == true
end

local function level(state: any, id: string): number
	local builds = if type(state) == "table" then state.builds else nil
	local value = if type(builds) == "table" then builds[id] else nil
	return if type(value) == "number" then value else 0
end

-- The base-mode tips that apply now, in the order they should be read.
local function baseTips(state: any): { string }
	local keys: { string } = {}
	local habitat = level(state, "habitat")
	if habitat < 1 then
		table.insert(keys, "tip.lander_start")
		if not inProgress(state, "habitat") then
			table.insert(keys, "tip.build_habitat")
		end
	end
	local needsCrate, needsAssembly = stepNeeds(state)
	if needsCrate and carryingCrate(state) then
		table.insert(keys, "tip.deliver_crate")
	elseif needsAssembly then
		table.insert(keys, "tip.use_wrench")
	elseif needsCrate then
		table.insert(keys, "tip.take_crate")
	end
	if habitat >= 1 and not needsCrate and not needsAssembly then
		if level(state, "solar") < 1 then
			table.insert(keys, "tip.base_start")
		else
			for _, id in CORE_BUILDS do
				if level(state, id) < 1 then
					table.insert(keys, "tip.base_ice")
					break
				end
			end
		end
	end
	return keys
end

local function hasTablet(state: any): boolean
	local tools = if type(state) == "table" then state.tools else nil
	if type(tools) ~= "table" then
		return true -- older data: no tool list, scanning needs nothing
	end
	local value = tools.tablet
	return type(value) == "number" and value > 0
end

local function impactVisible(): boolean
	local base = workspace:FindFirstChild("Base")
	local impacts = if base then base:FindFirstChild("Impacts") else nil
	return impacts ~= nil and #impacts:GetChildren() > 0
end

local started = false

function Onboarding.start(deps: Deps)
	if started then
		return
	end
	started = true

	local shown: { [string]: boolean } = {}
	-- Base mode tips: once per visit to base mode (cleared when a mission starts).
	local baseShown: { [string]: boolean } = {}
	local lastDay = 0
	local lastMissionId: string? = nil
	local lastGuideKey = ""
	-- Allocation when this planning phase began, and the systems the player has changed since.
	local baseline: Allocation? = nil
	local baselineDay = 0
	local touched: { [string]: boolean } = {}

	local function once(key: string): boolean
		if shown[key] then
			return false
		end
		shown[key] = true
		return true
	end

	local function tip(key: string, phase: string?)
		if once(key) then
			deps.showTip({ key = key }, phase)
		end
	end

	local function urgent(key: string)
		if once(key) then
			deps.show({ key = key })
		end
	end

	local function setGuide(highlight: { PowerBoard.SystemId }, later: { PowerBoard.SystemId })
		-- Only touch the board when the guide really changes.
		local guideKey = table.concat(highlight, ",") .. "|" .. table.concat(later, ",")
		if guideKey == lastGuideKey then
			return
		end
		lastGuideKey = guideKey
		if #highlight == 0 and #later == 0 then
			deps.setGuide(nil)
		else
			deps.setGuide({ highlight = highlight, later = later })
		end
	end

	local function evaluate()
		local snap = Store.getSnapshot()
		if not snap then
			return
		end
		-- A new mission (back to the lobby, another mission, or the day counter went back): tips may
		-- show again.
		local mission = Store.mission()
		local missionId = if mission then mission.id else nil
		if snap.phase == "Briefing" or snap.day < lastDay or missionId ~= lastMissionId then
			table.clear(shown)
		end
		lastDay = snap.day
		lastMissionId = missionId

		local phase = snap.phase
		local day = snap.day
		local mode = guideMode(day)
		local allocation = snap.allocation

		-- Base mode: the new start. C.A.R.L. points at the next step (CarlDrone); these tips say why.
		if phase ~= "Briefing" then
			table.clear(baseShown)
		elseif Store.isBaseMode() then
			local state = Store.getBase()
			if state ~= nil then
				for _, key in baseTips(state) do
					if not baseShown[key] then
						baseShown[key] = true
						deps.showTip({ key = key }, "Briefing")
					end
				end
			end
		end

		-- A mission that starts with building something: say what to build (once per mission).
		if mission and (phase == "Planning" or phase == "Shift") then
			for _, objective in mission.objectives do
				local key = BUILD_TIPS[objective.id]
				if key and not objective.done then
					tip(key, phase)
					break -- one build at a time
				end
			end
		end

		-- The plan carries over between days and a new mission already starts with cells in every
		-- system, so "has no cell" says nothing. A guided row pulses until the player changes it
		-- in this planning phase.
		if phase == "Planning" then
			if baselineDay ~= day or baseline == nil then
				baselineDay = day
				baseline = {
					LifeSupport = allocation.LifeSupport,
					Greenhouse = allocation.Greenhouse,
					Science = allocation.Science,
				}
				table.clear(touched)
			end
			local start = baseline :: Allocation
			for _, system in GUIDED_SYSTEMS do
				if (allocation :: any)[system] ~= (start :: any)[system] then
					touched[system] = true
				end
			end
		else
			baselineDay = 0
			baseline = nil
		end

		-- Power board guide.
		local highlight: { PowerBoard.SystemId } = {}
		local later: { PowerBoard.SystemId } = {}
		local planPower = mode == "power" or (mode == "free" and day == 1)
		local planGreenhouse = mode == "free" and day == 2
		if phase == "Planning" and planPower then
			if not touched.LifeSupport then
				table.insert(highlight, "LifeSupport")
			end
			if not touched.Science then
				table.insert(highlight, "Science")
			end
			table.insert(later, "Greenhouse")
			tip("tip.day1_plan", "Planning")
			tip("tip.day1_science", "Planning")
			-- The row already says "food comes tomorrow"; repeat it only when the player adds plant power.
			if baseline and allocation.Greenhouse > baseline.Greenhouse then
				tip("tip.greenhouse_tomorrow", "Planning")
			end
		elseif phase == "Planning" and planGreenhouse then
			if not touched.Greenhouse then
				table.insert(highlight, "Greenhouse")
			end
			tip("tip.day2_greenhouse", "Planning")
		end
		setGuide(highlight, later)

		if phase ~= "Shift" then
			return
		end
		local shift = snap.shift
		local shiftTasks = mode == "tasks" or (mode == "free" and day == 1)
		if shiftTasks or mode == "power" then
			tip("tip.day1_shift", "Shift")
		end
		if shiftTasks then
			if shift and not shift.antennaLinked then
				tip("tip.antenna", "Shift")
			end
			if shift and shift.iceCoresDelivered == 0 then
				tip("tip.find_ice", "Shift")
			end
		end
		if Store.stormStage() == "warning" then
			urgent("tip.storm_follow")
		end
		local stats = Store.getStats()
		if stats and not stats.inside and stats.suitO2 < SUIT_LOW then
			urgent("tip.suit_home")
		end
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind ~= "language" then
			evaluate()
		end
	end)

	-- The "jump" skill: explain the double jump right after it is learned (not on every join: the
	-- first BaseState only records the level).
	local knownJump: number? = nil
	Store.onChanged(function(kind: Store.ChangeKind)
		if kind ~= "base" then
			return
		end
		local state = Store.getBase()
		if state == nil then
			return
		end
		local jumpLevel = state.skills.jump or 0
		if knownJump ~= nil and (knownJump :: number) < 1 and jumpLevel >= 1 then
			deps.showTip({ key = "tip.double_jump" })
		end
		knownJump = jumpLevel
	end)

	-- Stage 7: a tool just unlocked, or the lab / garage just built: say what it is for. The first
	-- BaseState only records what the player already has.
	local knownTools: { [string]: boolean }? = nil
	local knownBuilt: { [string]: boolean }? = nil
	Store.onChanged(function(kind: Store.ChangeKind)
		if kind ~= "base" then
			return
		end
		local state: any = Store.getBase()
		if state == nil then
			return
		end
		local tools: { [string]: boolean } = {}
		if type(state.tools) == "table" then
			for id, toolLevel in state.tools do
				if type(id) == "string" and type(toolLevel) == "number" and toolLevel > 0 then
					tools[id] = true
				end
			end
		end
		local built: { [string]: boolean } = {}
		for id in BUILT_TIPS do
			built[id] = level(state, id) >= 1
		end
		local oldTools = knownTools
		if oldTools ~= nil then
			for id, key in TOOL_TIPS do
				if tools[id] and not oldTools[id] then
					deps.showTip({ key = key })
				end
			end
		end
		local oldBuilt = knownBuilt
		if oldBuilt ~= nil then
			for id, key in BUILT_TIPS do
				if built[id] and not oldBuilt[id] then
					deps.showTip({ key = key })
				end
			end
		end
		knownTools = tools
		knownBuilt = built
	end)

	-- A parts crate picked up or delivered (a player attribute, not a Store change).
	Players.LocalPlayer:GetAttributeChangedSignal("SBO_CarryingCrate"):Connect(function()
		if Store.phase() == "Briefing" then
			evaluate()
		end
	end)

	local meteorTipShown = false
	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			local phase = Store.phase()
			if phase == "Shift" or phase == "Briefing" then
				-- Briefing: build steps change through pad attributes too.
				evaluate()
			end
			-- The first meteorite crater the player can scan (once per session).
			if not meteorTipShown and impactVisible() and hasTablet(Store.getBase()) then
				meteorTipShown = true
				deps.showTip({ key = "tip.meteor_scan" })
			end
		end
	end)

	evaluate()
end

return Onboarding
