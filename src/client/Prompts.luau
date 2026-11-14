--!strict
-- Space Base Odyssey - localizes every ProximityPrompt in Workspace that carries a "TextKey" attribute.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)

local TEXT_KEY_ATTRIBUTE = "TextKey"

local Prompts = {}

local tracked: { [ProximityPrompt]: RBXScriptConnection } = {}
local started = false

local function localize(prompt: ProximityPrompt)
	local key = prompt:GetAttribute(TEXT_KEY_ATTRIBUTE)
	if type(key) == "string" and key ~= "" then
		prompt.ActionText = Store.t(key)
	end
end

local function track(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local prompt = instance :: ProximityPrompt
	if tracked[prompt] then
		return
	end
	tracked[prompt] = prompt:GetAttributeChangedSignal(TEXT_KEY_ATTRIBUTE):Connect(function()
		localize(prompt)
	end)
	localize(prompt)
end

local function untrack(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		local prompt = instance :: ProximityPrompt
		local connection = tracked[prompt]
		if connection then
			connection:Disconnect()
			tracked[prompt] = nil
		end
	end
end

-- Start watching Workspace (prompts added later are localized when they appear).
function Prompts.start()
	if started then
		return
	end
	started = true
	workspace.DescendantAdded:Connect(track)
	workspace.DescendantRemoving:Connect(untrack)
	for _, descendant in workspace:GetDescendants() do
		track(descendant)
	end
end

-- Re-apply the current language to every known prompt.
function Prompts.refresh()
	for prompt in tracked do
		localize(prompt)
	end
end

return Prompts
