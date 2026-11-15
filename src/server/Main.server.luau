--!strict
-- Space Base Odyssey - server entry point: builds the Moon base, starts services, spawns players
-- (their own avatar with the astronaut helmet and backpack).
-- Start order: world, remotes, CrewService, ProgressService, BaseService (build and grow, building in
-- steps), MissionService, ToolService (Stage 7 tools in hand), VehicleService (Stage 7 garage
-- vehicles), ExploreService (Stage 7 exploration sites and meteorites), SuitService, PetService,
-- QuestService (Stage 9 main and side quests), AchievementService (Stage 10 learning achievements).
-- Each later service is started inside pcall so a missing or broken piece is reported with warn and
-- never stops the server. Players arrive (spawn) in the lander (world.spawn).
-- Stage 9 save slots: a player has no character until they pick a save slot on the start menu and it
-- is loaded (ProgressService.onLoaded); then they spawn. Remotes.SLOTS carries the slot list.
-- Stage 10 fix (private worlds): the public server is only a lobby. No slot ever loads there, so
-- nobody spawns in it: the start menu teleports each player to their own world server (or a
-- friend's). The cinematic menu keeps working there (streaming focus below, showcase base).
-- Roblox's place setting caps every server; ProgressService enforces MissionData.MISSION.PLAYERS_MAX
-- (4) per world in code, because Players.MaxPlayers cannot be set from a script.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Version = require(Shared:WaitForChild("Version"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local CrewService = require(script.Parent:WaitForChild("CrewService"))
local MissionService = require(script.Parent:WaitForChild("MissionService"))
local ProgressService = require(script.Parent:WaitForChild("ProgressService"))
local SpaceWeatherService = require(script.Parent:WaitForChild("SpaceWeatherService"))
local SuitService = require(script.Parent:WaitForChild("SuitService"))

local RESPAWN_DELAY_SECONDS = 3

print(`[SpaceBaseOdyssey] server started, build {Version.BUILD}`)

-- Live NASA space weather is fetched in the background while the base is built; nothing waits for it.
SpaceWeatherService.start()

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

-- Runs one start step; a failure is reported and the server keeps going.
local function startStep(label: string, step: () -> ())
	local ok, err = pcall(step)
	if not ok then
		warn(`[SpaceBaseOdyssey] {label} failed to start: {err}`)
	end
end

-- Stage 6 / 7 remotes (Remotes.BASE_STATE, Remotes.EXPLORE) live in the same folder
-- MissionService.createRemotes made.
local function extraRemote(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end
local baseStateEvent = extraRemote(Types.Remotes.BASE_STATE)
local exploreEvent = extraRemote(Types.Remotes.EXPLORE)
local slotsEvent = extraRemote(Types.Remotes.SLOTS) -- Stage 9: the start menu's save slots
local worldsEvent = extraRemote(Types.Remotes.WORLDS) -- Stage 10 fix: the "Join a friend" list
local achievementsEvent = extraRemote(Types.Remotes.ACHIEVEMENTS) -- Stage 10: learning achievements

-- An optional server module (Stage 7 services may be missing while the game is being built).
local function optionalModule(name: string): any?
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		warn(`[SpaceBaseOdyssey] {name} not found; it is off`)
		return nil
	end
	return (require :: any)(module)
end

CrewService.start(world, { playerStats = remotes.playerStats, message = remotes.message })
-- Saved progress (three save slots per player, chosen on the start menu) and the hidden collectibles
-- (prompts, rewards) start before the mission loop so missions know what is unlocked.
ProgressService.start(world, {
	progress = remotes.progress,
	collected = remotes.collected,
	message = remotes.message,
	action = remotes.action, -- ChooseSlot, RequestSlots, SaveNow, ListFriendWorlds, JoinWorld
	slots = slotsEvent,
	worlds = worldsEvent,
})
-- Build and grow the base: credits, XP, builds, skills, pets, wardrobe (saved by ProgressService).
startStep("BaseService", function()
	BaseService.start(world, { baseState = baseStateEvent, message = remotes.message }, ProgressService, CrewService)
end)
startStep("MissionService", function()
	MissionService.start(world, CrewService, ProgressService, BaseService)
end)
-- Stage 7: tools in hand (wrench, ice drill, brush, repair kit, tablet, greenhouse food).
local ToolService: any = nil
startStep("ToolService", function()
	local module = optionalModule("ToolService")
	if module then
		module.start(world, BaseService, CrewService, { message = remotes.message })
		ToolService = module
	end
end)
-- Stage 7: drivable garage vehicles (buggy, ice hauler).
startStep("VehicleService", function()
	local module = optionalModule("VehicleService")
	if module then
		module.start(world, BaseService, MissionService, CrewService)
	end
end)
-- Stage 7: exploration sites and meteorite impacts (scanned with the tablet).
startStep("ExploreService", function()
	local module = optionalModule("ExploreService")
	if module then
		module.start(world, BaseService, ToolService, { message = remotes.message, explore = exploreEvent })
	end
end)
-- Every character keeps its own avatar and gets the astronaut helmet and backpack; rewards, event
-- codes and the wardrobe choose their look.
startStep("SuitService", function()
	SuitService.start(ProgressService, BaseService)
end)
-- Pets follow their owners (PetService is optional: the server runs without it).
startStep("PetService", function()
	local module = optionalModule("PetService")
	if module then
		module.start(BaseService)
	end
end)
-- Stage 9: main and side quests (optional; started after every service it listens to).
startStep("QuestService", function()
	local module = optionalModule("QuestService")
	if module then
		module.start(world, BaseService, MissionService, CrewService, {
			message = remotes.message,
			baseState = baseStateEvent,
			action = remotes.action,
			snapshot = remotes.snapshot,
			progress = remotes.progress,
			explore = exploreEvent,
			slots = slotsEvent,
		}, ProgressService)
	end
end)

-- Stage 10: learning achievements (optional; started after every service it listens to).
startStep("AchievementService", function()
	local module = optionalModule("AchievementService")
	if module then
		module.start(BaseService, MissionService, ProgressService, {
			achievements = achievementsEvent,
			action = remotes.action,
		})
	end
end)

-- When the Earth hides the Sun (an eclipse seen from the Moon), C.A.R.L. explains it.
local onEclipse = (world :: any).onEclipse
if type(onEclipse) == "function" then
	onEclipse(function(active: boolean)
		MissionService.announce(if active then "carl.eclipse_start" else "carl.eclipse_end")
	end)
else
	warn("[SpaceBaseOdyssey] world has no onEclipse; eclipse lines are off")
end

local function loadCharacter(player: Player)
	if player.Parent == nil then
		return
	end
	local ok, err = pcall(function()
		SuitService.loadCharacter(player)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] could not load character for {player.Name}: {err}`)
	end
end

-- The first spawn waits for the player's save slot (start menu, then loading). Only once: later
-- spawns are respawns after a death.
local spawning: { [Player]: boolean } = {}
local function spawnWhenLoaded(player: Player)
	if player.Parent == nil or player.Character ~= nil or spawning[player] then
		return
	end
	if not ProgressService.isLoaded(player) then
		return -- still on the start menu: ProgressService.onLoaded spawns them
	end
	spawning[player] = true
	loadCharacter(player)
	spawning[player] = nil
end

ProgressService.onLoaded(spawnWhenLoaded)
Players.PlayerRemoving:Connect(function(player: Player)
	spawning[player] = nil
end)

-- Stage 10 cinematic start menu: the place streams (Workspace.StreamingEnabled), and a player on the
-- menu has no character yet, so nothing around the base would stream in for the menu's camera shots.
-- Until the character spawns, the player's streaming focus is this invisible anchored part in the
-- middle of the base (the streaming radius covers the base, the crater and the landing pad).
local MENU_FOCUS_POSITION = Vector3.new(-20, 4, 10)
local menuFocus: BasePart? = nil
local function getMenuFocus(): BasePart
	if menuFocus == nil or menuFocus.Parent == nil then
		local part = Instance.new("Part")
		part.Name = "SBO_MenuStreamFocus"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = CFrame.new(MENU_FOCUS_POSITION)
		part.Parent = workspace
		menuFocus = part
	end
	return menuFocus :: BasePart
end

local function onPlayerAdded(player: Player)
	if world.spawn then
		player.RespawnLocation = world.spawn
	end
	if player.Character == nil then
		player.ReplicationFocus = getMenuFocus()
	end
	player.CharacterAdded:Connect(function(character: Model)
		player.ReplicationFocus = nil -- the character is the streaming focus from now on
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
	task.spawn(spawnWhenLoaded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
