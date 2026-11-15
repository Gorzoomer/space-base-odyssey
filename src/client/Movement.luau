--!strict
-- Space Base Odyssey - shorter prompt holds from tool and skill levels, applied on this client.
-- Prompt hold times cannot be set per player on the server, so this local change is the only place
-- it happens. The original HoldDuration is kept in the prompt attribute SBO_BaseHold so a factor
-- never compounds; when the server itself changes HoldDuration, the new value becomes the original.
--   * Faster drilling (Stage 7): the player attribute SBO_DrillLevel is the level of the ice drill
--     TOOL (set by the server's ToolService; upgraded at the Lab). Ice drill prompts (TextKey
--     "prompt.drill") hold for original * BaseBuild.drillHoldFactor(data, level).
--   * Faster building (Stage 8): the "builder" skill. The player attribute SBO_BuilderLevel (set by
--     the server's BaseService) shortens the build pads' "AssemblePrompt" hold to
--     original * BaseBuild.builderHoldFactor(data, skills). It is applied as soon as the prompt
--     exists (also while it is switched off), so the player never sees the long hold first.
-- Roblox's prompt UI keeps the hold time a prompt had when it appeared (BaseService header), so a
-- level change never touches a prompt on screen: it waits until that prompt hides.
-- Stage 8: the double jump moved to the air boots (Gear.luau); there is no jump skill any more.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))

local DRILL_LEVEL_ATTRIBUTE = "SBO_DrillLevel"
local BUILDER_LEVEL_ATTRIBUTE = "SBO_BuilderLevel"
local BASE_HOLD_ATTRIBUTE = "SBO_BaseHold"
-- Prompts whose TextKey is one of these are ice drill prompts (WorldBuilder: makePrompt "prompt.drill").
local DRILL_KEYS: { [string]: boolean } = { ["prompt.drill"] = true }
local ASSEMBLE_PROMPT_NAME = "AssemblePrompt" -- BaseService: the wrench step at a build pad
local HOLD_TOLERANCE = 0.001 -- HoldDuration is stored as a float

local Movement = {}

local started = false

local function attributeLevel(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
end

type Kind = "drill" | "builder"

local function kindOf(prompt: ProximityPrompt): Kind?
	if prompt.Name == ASSEMBLE_PROMPT_NAME then
		return "builder"
	end
	local key = prompt:GetAttribute("TextKey")
	if type(key) == "string" and DRILL_KEYS[key] then
		return "drill"
	end
	return nil
end

local function startPromptHolds(player: Player)
	-- Prompt -> its kind and the HoldDuration this script last set (weak keys: removed prompts go away).
	local kinds: { [ProximityPrompt]: Kind } = setmetatable({}, { __mode = "k" }) :: any
	local applied: { [ProximityPrompt]: number } = setmetatable({}, { __mode = "k" }) :: any
	local shown: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local pending: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function factor(kind: Kind): number
		if kind == "drill" then
			-- Level 0 (no drill yet) and 1 (basic drill) both use the normal hold time.
			local level = math.max(1, attributeLevel(player, DRILL_LEVEL_ATTRIBUTE))
			return BaseBuild.drillHoldFactor(MissionData, level)
		end
		local level = attributeLevel(player, BUILDER_LEVEL_ATTRIBUTE)
		return BaseBuild.builderHoldFactor(MissionData, { builder = level })
	end

	local function apply(prompt: ProximityPrompt)
		local kind = kinds[prompt]
		if kind == nil then
			return
		end
		local original = prompt:GetAttribute(BASE_HOLD_ATTRIBUTE)
		local last = applied[prompt]
		-- First time, or the server set a new hold since: that value is the original now.
		if type(original) ~= "number" or (last ~= nil and math.abs(prompt.HoldDuration - last) > HOLD_TOLERANCE) then
			original = prompt.HoldDuration
			prompt:SetAttribute(BASE_HOLD_ATTRIBUTE, original)
		end
		local value = (original :: number) * factor(kind)
		applied[prompt] = value
		if math.abs(prompt.HoldDuration - value) > HOLD_TOLERANCE then
			prompt.HoldDuration = value
			applied[prompt] = prompt.HoldDuration -- the float the engine really stored
		end
	end

	local function consider(instance: Instance)
		if not instance:IsA("ProximityPrompt") then
			return
		end
		local prompt = instance :: ProximityPrompt
		if kinds[prompt] then
			return
		end
		local kind = kindOf(prompt)
		if kind == nil then
			return
		end
		kinds[prompt] = kind
		apply(prompt)
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			if prompt.Enabled then
				apply(prompt)
			end
		end)
		prompt:GetPropertyChangedSignal("HoldDuration"):Connect(function()
			local last = applied[prompt]
			if last == nil or math.abs(prompt.HoldDuration - last) > HOLD_TOLERANCE then
				apply(prompt) -- changed by the server: keep the shorter hold
			end
		end)
	end

	local function applyKind(kind: Kind)
		for prompt, promptKind in kinds do
			if promptKind == kind and prompt.Parent then
				if shown[prompt] then
					pending[prompt] = true -- on screen now: change it once it hides
				else
					apply(prompt)
				end
			end
		end
	end

	workspace.DescendantAdded:Connect(consider)
	for _, descendant in workspace:GetDescendants() do
		consider(descendant)
	end
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		consider(prompt) -- normally already known from DescendantAdded
		shown[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		shown[prompt] = nil
		if pending[prompt] then
			pending[prompt] = nil
			apply(prompt)
		end
	end)
	player:GetAttributeChangedSignal(DRILL_LEVEL_ATTRIBUTE):Connect(function()
		applyKind("drill")
	end)
	player:GetAttributeChangedSignal(BUILDER_LEVEL_ATTRIBUTE):Connect(function()
		applyKind("builder")
	end)
end

function Movement.start()
	if started then
		return
	end
	started = true
	startPromptHolds(Players.LocalPlayer)
end

return table.freeze(Movement)
