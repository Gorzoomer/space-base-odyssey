--!strict
-- Space Base Odyssey - C.A.R.L.'s fun facts: every 60 to 90 seconds of Planning or Shift, when the
-- bubble is silent and no storm warning or storm is on, C.A.R.L. shares one short true fact
-- (Localization keys funfact.01 to funfact.N, N = Localization.FUNFACT_COUNT; the facts come
-- from DATA_SOURCES.md). Facts come from a shuffle bag: none repeats until all were shown, and a new
-- bag never starts with the fact just shown. The Settings panel can turn them off.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))

local Store = require(script.Parent.Store)

-- Timing (presentation tuning, not gameplay numbers).
local MIN_GAP_SECONDS = 60
local MAX_GAP_SECONDS = 90
local CHECK_SECONDS = 1
local FALLBACK_COUNT = 45 -- used only if Localization.FUNFACT_COUNT is missing

type TextRef = Store.TextRef

export type Deps = {
	showTip: (ref: TextRef, phase: string?, style: any) -> (),
	isIdle: () -> boolean,
}

local FunFacts = {}

local started = false
local rng = Random.new()

local function factKey(index: number): string
	return string.format("funfact.%02d", index)
end

local function factCount(): number
	local count = (Localization :: any).FUNFACT_COUNT
	if type(count) == "number" and count >= 1 then
		return math.floor(count)
	end
	return FALLBACK_COUNT
end

-- Indices of the facts that really exist in English (a missing key would show as the key itself).
local function availableFacts(): { number }
	local list: { number } = {}
	for index = 1, factCount() do
		local key = factKey(index)
		if Localization.t(key, nil, "en") ~= key then
			table.insert(list, index)
		end
	end
	return list
end

function FunFacts.start(deps: Deps)
	if started then
		return
	end
	started = true

	local facts = availableFacts()
	local bag: { number } = {}
	local lastShown: number? = nil

	-- Fisher-Yates shuffle; the fact just shown never opens the next bag (if there is a choice).
	local function refill()
		bag = table.clone(facts)
		for i = #bag, 2, -1 do
			local j = rng:NextInteger(1, i)
			bag[i], bag[j] = bag[j], bag[i]
		end
		-- The bag is used from the end: keep lastShown away from the last slot.
		if lastShown ~= nil and #bag > 1 and bag[#bag] == lastShown then
			local swap = rng:NextInteger(1, #bag - 1)
			bag[#bag], bag[swap] = bag[swap], bag[#bag]
		end
	end

	local function nextFact(): number?
		if #facts == 0 then
			return nil
		end
		if #bag == 0 then
			refill()
		end
		local index = table.remove(bag)
		lastShown = index
		return index
	end

	local function nextGap(): number
		return rng:NextNumber(MIN_GAP_SECONDS, MAX_GAP_SECONDS)
	end

	local waited = 0
	local gap = nextGap()
	local sinceCheck = 0

	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		if sinceCheck < CHECK_SECONDS then
			return
		end
		local step = sinceCheck
		sinceCheck = 0
		local phase = Store.phase()
		if not Store.settingOn("funFacts") or (phase ~= "Planning" and phase ~= "Shift") then
			return -- the clock pauses in menus and while facts are off
		end
		waited += step
		if waited < gap then
			return
		end
		-- Due: wait for silence (no message, tip, warning or storm), then speak.
		if not deps.isIdle() or Store.stormStage() ~= "none" then
			return
		end
		local index = nextFact()
		waited = 0
		gap = nextGap()
		if index then
			deps.showTip({ key = factKey(index) }, phase, "fact")
		end
	end)
end

return FunFacts
