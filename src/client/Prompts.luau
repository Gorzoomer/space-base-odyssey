--!strict
-- Space Base Odyssey - localizes world text: every ProximityPrompt in Workspace with a "TextKey"
-- attribute (ActionText), and every TextLabel / TextButton in Workspace with one (e.g. the
-- observatory teaser sign, a SurfaceGui built by WorldBuilder).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)

local TEXT_KEY_ATTRIBUTE = "TextKey"

local Prompts = {}

local tracked: { [Instance]: RBXScriptConnection } = {}
local started = false

local function localize(instance: Instance)
	local key = instance:GetAttribute(TEXT_KEY_ATTRIBUTE)
	if type(key) ~= "string" or key == "" then
		return
	end
	if instance:IsA("ProximityPrompt") then
		instance.ActionText = Store.t(key)
	elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
		(instance :: any).Text = Store.t(key)
	end
end

local function isLocalizable(instance: Instance): boolean
	return instance:IsA("ProximityPrompt") or instance:IsA("TextLabel") or instance:IsA("TextButton")
end

local function track(instance: Instance)
	if not isLocalizable(instance) or tracked[instance] then
		return
	end
	tracked[instance] = instance:GetAttributeChangedSignal(TEXT_KEY_ATTRIBUTE):Connect(function()
		localize(instance)
	end)
	localize(instance)
end

local function untrack(instance: Instance)
	local connection = tracked[instance]
	if connection then
		connection:Disconnect()
		tracked[instance] = nil
	end
end

-- Start watching Workspace (text added later is localized when it appears).
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

-- Re-apply the current language to every known prompt and sign.
function Prompts.refresh()
	for instance in tracked do
		localize(instance)
	end
end

return Prompts
