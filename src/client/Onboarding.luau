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
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

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

local started = false

function Onboarding.start(deps: Deps)
	if started then
		return
	end
	started = true

	local shown: { [string]: boolean } = {}
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

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			if Store.phase() == "Shift" then
				evaluate()
			end
		end
	end)

	evaluate()
end

return Onboarding
