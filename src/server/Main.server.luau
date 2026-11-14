--!strict
-- Space Base Odyssey - server entry point: builds the Moon base, starts services, spawns players.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Version = require(Shared:WaitForChild("Version"))
local MissionData = require(Shared:WaitForChild("MissionData"))

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CrewService = require(script.Parent:WaitForChild("CrewService"))
local MissionService = require(script.Parent:WaitForChild("MissionService"))

local RESPAWN_DELAY_SECONDS = 3

print(`[SpaceBaseOdyssey] server started, build {Version.BUILD}`)

-- Turn off auto-loading first: applyEnvironment and build yield, and a player who joins meanwhile
-- must not spawn before Moon gravity and the base exist.
Players.CharacterAutoLoads = false
WorldBuilder.applyEnvironment(MissionData)

local world = WorldBuilder.build(MissionData)

-- Remove the template baseplate and any spawn that is not part of the Moon base.
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
local baseFolder = workspace:FindFirstChild("Base")
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("SpawnLocation") and not (baseFolder and descendant:IsDescendantOf(baseFolder)) then
		descendant:Destroy()
	end
end

local remotes = MissionService.createRemotes()
CrewService.start(world, { playerStats = remotes.playerStats, message = remotes.message })
MissionService.start(world, CrewService)

local function loadCharacter(player: Player)
	if player.Parent == nil then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] could not load character for {player.Name}: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	if world.spawn then
		player.RespawnLocation = world.spawn
	end
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Once(function()
				task.delay(RESPAWN_DELAY_SECONDS, function()
					-- Only respawn if this is still the player's current character.
					if player.Character == character then
						loadCharacter(player)
					end
				end)
			end)
		end
	end)
	task.spawn(loadCharacter, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
