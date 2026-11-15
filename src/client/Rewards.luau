--!strict
-- Space Base Odyssey - client-side rewards of the hidden collectibles.
--   * All four found: the hidden Observatory door (Workspace.Base.Observatory.Door) opens for this
--     player only. Character movement is client-owned, so making the door non-colliding and
--     invisible locally lets this player walk in; other players still see a closed door.
--   * A collectible this player already owns is hidden for this player only.
--   * The C.A.R.L. "Earth skin" for the mini Earth lives in CarlDrone.luau.
--   * The observatory teaser sign is localized by Prompts.luau (TextKey attribute).
-- Server-side rewards (laika backpack, cheese rover paint, team flag) are not handled here.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)

local OBSERVATORY_NAME = "Observatory"
local DOOR_NAME = "Door"
local COLLECTIBLES_FOLDER = "Collectibles" -- Workspace.Base.Collectibles.<id> (WorldBuilder)
local COLLECTIBLE_ATTRIBUTE = "CollectibleId"

local Rewards = {}

type Saved = { canCollide: boolean, canQuery: boolean, canTouch: boolean, transparency: number }

local started = false
local saved: { [BasePart]: Saved } = {}
local opened = false

local function findDoor(): BasePart?
	local base = workspace:FindFirstChild("Base")
	local observatory = if base then base:FindFirstChild(OBSERVATORY_NAME) else nil
	local door = if observatory then observatory:FindFirstChild(DOOR_NAME) else nil
	if door and door:IsA("BasePart") then
		return door
	end
	return nil
end

-- Parts that make up the door: the Door part itself and any parts welded inside it.
local function doorParts(door: BasePart): { BasePart }
	local parts: { BasePart } = { door }
	for _, descendant in door:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function setDecalsVisible(door: BasePart, visible: boolean)
	for _, descendant in door:GetDescendants() do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = if visible then 0 else 1
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function apply()
	local door = findDoor()
	if not door then
		return
	end
	if opened then
		for _, part in doorParts(door) do
			if not saved[part] then
				saved[part] = {
					canCollide = part.CanCollide,
					canQuery = part.CanQuery,
					canTouch = part.CanTouch,
					transparency = part.Transparency,
				}
			end
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
		end
		setDecalsVisible(door, false)
	else
		for part, values in saved do
			if part.Parent then
				part.CanCollide = values.canCollide
				part.CanQuery = values.canQuery
				part.CanTouch = values.canTouch
				part.Transparency = values.transparency
			end
		end
		table.clear(saved)
		setDecalsVisible(door, true)
	end
end

-- A collectible this player already owns disappears for this player only (other players still see
-- theirs): the model goes invisible, its glow goes out and its prompt is turned off locally. The
-- server never changes these properties after the build, so the local values stay.
local function applyCollectibles()
	local base = workspace:FindFirstChild("Base")
	local folder = if base then base:FindFirstChild(COLLECTIBLES_FOLDER) else nil
	if folder == nil then
		return
	end
	for _, item in folder:GetChildren() do
		local id = item:GetAttribute(COLLECTIBLE_ATTRIBUTE)
		if type(id) ~= "string" then
			continue
		end
		local owned = Store.hasCollectible(id)
		for _, descendant in item:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = if owned then 1 else 0
			elseif descendant:IsA("Light") then
				descendant.Enabled = not owned
			elseif descendant:IsA("ProximityPrompt") then
				descendant.Enabled = not owned
			end
		end
	end
end

function Rewards.start()
	if started then
		return
	end
	started = true

	local function refresh()
		local wanted = Store.allCollectibles()
		if wanted ~= opened then
			opened = wanted
		end
		apply()
		applyCollectibles()
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "progress" then
			refresh()
		end
	end)

	-- The world may be built (or rebuilt, or streamed in) after the client starts.
	local collectiblesQueued = false
	workspace.DescendantAdded:Connect(function(instance: Instance)
		-- A collectible streamed in (or rebuilt): hide it again if this player owns it.
		if not collectiblesQueued then
			local folder = instance:FindFirstAncestor(COLLECTIBLES_FOLDER)
			if folder and folder.Parent and folder.Parent.Name == "Base" then
				collectiblesQueued = true
				task.defer(function()
					collectiblesQueued = false
					applyCollectibles()
				end)
			end
		end
		if opened and instance:IsA("BasePart") then
			local parent = instance.Parent
			if
				(instance.Name == DOOR_NAME and parent and parent.Name == OBSERVATORY_NAME)
				or (parent and parent.Name == DOOR_NAME)
			then
				task.defer(apply)
			end
		end
	end)

	refresh()
end

return Rewards
