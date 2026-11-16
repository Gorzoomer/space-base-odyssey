--!strict
-- Space Base Odyssey - the map edge on this client (Stage 11 world). The server builds invisible walls
-- just inside the ground's edge (Workspace.Base.MapEdge, see WorldBuilder S11World.mapEdge), so
-- nobody walks or drives into the void. Each wall has an orange warning band ("EdgeGlow", attribute
-- Side) that the server leaves invisible; here it fades in only while this player is near it, and
-- C.A.R.L. says "turn back" once in a while. The rules are pure, in src/shared/WorldSafety.luau.
-- Client-only: the glow's Transparency set here never replicates.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldSafety = require(Shared:WaitForChild("WorldSafety"))

local Store = require(script.Parent.Store)

export type Deps = {
	showMessage: ((ref: any) -> ())?,
}

local CHECK_SECONDS = 0.15
local WARN_KEY = "carl.map_edge"

local MapEdge = {}

local started = false

function MapEdge.start(deps: Deps?)
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local lastWarnAt = -math.huge
	local glows: { BasePart } = {}

	-- The place streams: the MapEdge folder arrives at join, but its walls and glows (about 600
	-- studs out) stream in and out later. So the glow list is rebuilt from the folder's children
	-- on every check (only a handful of parts), never kept from the first look.
	local function findGlows(): Instance?
		local base = workspace:FindFirstChild("Base")
		local edgeFolder = if base then base:FindFirstChild("MapEdge") else nil
		table.clear(glows)
		if edgeFolder then
			for _, child in edgeFolder:GetChildren() do
				if child:IsA("BasePart") and child.Name == "EdgeGlow" then
					table.insert(glows, child)
				end
			end
		end
		return edgeFolder
	end

	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < CHECK_SECONDS then
			return
		end
		since = 0
		local edgeFolder = findGlows()
		if edgeFolder == nil then
			return
		end
		local half = edgeFolder:GetAttribute("GroundHalf")
		if type(half) ~= "number" then
			return
		end
		local character = player.Character
		local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local position: Vector3? = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else nil
		for _, glow in glows do
			local alpha = 0
			if position then
				local side = glow:GetAttribute("Side")
				alpha = WorldSafety.glowAlpha(WorldSafety.sideDistance(if type(side) == "string" then side else "", position.X, position.Z, half))
			end
			local wanted = WorldSafety.glowTransparency(alpha)
			if math.abs(glow.Transparency - wanted) > 0.01 then
				glow.Transparency = wanted
			end
		end
		if position == nil or not Store.isSlotChosen() then
			return
		end
		local distance = WorldSafety.edgeDistance(position.X, position.Z, half)
		local now = os.clock()
		if distance < WorldSafety.EDGE.WARN_DISTANCE and now - lastWarnAt >= WorldSafety.EDGE.WARN_REPEAT_SECONDS then
			lastWarnAt = now
			local show = deps and deps.showMessage
			if show then
				pcall(show, { key = WARN_KEY })
			end
		end
	end)
end

return MapEdge
