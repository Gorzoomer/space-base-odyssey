--!strict
-- Space Base Odyssey - localizes world text: every ProximityPrompt in Workspace with a "TextKey"
-- attribute (ActionText) or an "ObjectKey" attribute (ObjectText), and every TextLabel / TextButton
-- in Workspace with a "TextKey" (e.g. the observatory teaser sign, a SurfaceGui built by WorldBuilder).
-- Optional "TextParams" / "ObjectParams" attributes hold a JSON object of {placeholders} for the key
-- (Stage 6 build pads: TextKey "prompt.build", TextParams {"n": 30}, ObjectKey "build.solar.name").
-- Text follows attribute changes and the chosen language.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local HttpService = game:GetService("HttpService")

local Store = require(script.Parent.Store)

local TEXT_KEY = "TextKey"
local TEXT_PARAMS = "TextParams"
local OBJECT_KEY = "ObjectKey"
local OBJECT_PARAMS = "ObjectParams"
local WATCHED: { [string]: boolean } = {
	[TEXT_KEY] = true,
	[TEXT_PARAMS] = true,
	[OBJECT_KEY] = true,
	[OBJECT_PARAMS] = true,
}

local Prompts = {}

local tracked: { [Instance]: RBXScriptConnection } = {}
local started = false

-- A JSON object string of placeholder values, or nil when missing or broken.
local function readParams(instance: Instance, attribute: string): { [string]: string | number }?
	local raw = instance:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, decoded = pcall(function(): any
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil
	end
	local params: { [string]: string | number } = {}
	for name, value in decoded do
		if type(name) == "string" and (type(value) == "string" or type(value) == "number") then
			params[name] = value
		end
	end
	return params
end

local function localize(instance: Instance)
	local key = instance:GetAttribute(TEXT_KEY)
	local hasKey = type(key) == "string" and key ~= ""
	if instance:IsA("ProximityPrompt") then
		if hasKey then
			instance.ActionText = Store.t(key :: string, readParams(instance, TEXT_PARAMS))
		end
		local objectKey = instance:GetAttribute(OBJECT_KEY)
		if type(objectKey) == "string" then
			instance.ObjectText = if objectKey == "" then "" else Store.t(objectKey, readParams(instance, OBJECT_PARAMS))
		end
	elseif hasKey and (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
		(instance :: any).Text = Store.t(key :: string, readParams(instance, TEXT_PARAMS))
	end
end

local function isLocalizable(instance: Instance): boolean
	return instance:IsA("ProximityPrompt") or instance:IsA("TextLabel") or instance:IsA("TextButton")
end

local function track(instance: Instance)
	if not isLocalizable(instance) or tracked[instance] then
		return
	end
	tracked[instance] = instance.AttributeChanged:Connect(function(attribute: string)
		if WATCHED[attribute] then
			localize(instance)
		end
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
