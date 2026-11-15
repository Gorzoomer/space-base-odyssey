--!strict
-- Space Base Odyssey - the player's tools (Stage 7, team feedback: "no drill, no ice").
-- Every tool the player has unlocked (BaseService.toolLevel > 0, MissionData.BASE.TOOLS) is a Roblox
-- Tool in their backpack bar, built by ToolModels: wrench (assembles build steps), ice drill (crater
-- ice), panel brush (dusty panels), repair kit (air leaks), tablet (antenna, exploration scans). Tools
-- come back after a respawn and appear the moment their unlock build stands. A task only works with
-- its tool IN HAND (isHolding: the Tool is a child of the character); MissionService and BaseService
-- (setToolChecker) ask here.
-- Food: the greenhouse prompt gives one fresh salad tray (BaseService.takeFood keeps the cooldown:
-- plants take time to grow). Eating it (tool Activate) needs a pressurized room (lander or habitat:
-- helmets stay on outside), pays REWARDS.food_eaten and sets the player attribute SBO_FoodBoostUntil
-- (server time) for FOOD.BOOST_SECONDS; the client Sprint adds FOOD.BOOST_SPEED meanwhile.
-- The drill tool level goes to the player attribute SBO_DrillLevel: the client shortens the ice
-- prompts' hold time with BaseBuild.drillHoldFactor (a prompt's hold time cannot differ per player on
-- the server).
-- Tools move while used: the drill bit spins, the brush scrubs, the wrench screw and the patch roll
-- turn, the tablet screen glows. That happens while the player holds any prompt with the tool in hand,
-- for a moment after clicking with it, and when another service calls ToolService.pulse.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local ToolModels = require(script.Parent:WaitForChild("ToolModels"))

type Rig = ToolModels.Rig

-- The parts of BaseService this module uses.
export type BaseApi = {
	toolLevel: (player: Player, id: string) -> number,
	onToolsChanged: (listener: (player: Player) -> ()) -> (),
	setToolChecker: (checker: (player: Player, toolId: string) -> boolean) -> (),
	takeFood: (player: Player) -> boolean,
	reward: (player: Player, kind: string, count: number?) -> (),
}

-- The parts of CrewService this module uses.
export type CrewApi = {
	isInside: (player: Player) -> boolean,
}

export type Remotes = {
	message: RemoteEvent,
}

type Owned = {
	id: string,
	tool: Tool,
	rig: Rig?,
	activeUntil: number, -- os.clock() until which the tool keeps moving
	holding: boolean, -- the player is holding a prompt with this tool in hand
	moving: boolean, -- the animation is showing (so it can be put back at rest)
	angle: number,
	level: number,
}

type Record = {
	tools: { [string]: Owned },
	food: boolean, -- carries a salad tray (kept through a respawn until eaten)
	connections: { RBXScriptConnection },
}

local TOOL_ID_ATTRIBUTE = "SBO_ToolId"
local TEXT_KEY_ATTRIBUTE = "TextKey"
local LEVEL_ATTRIBUTE = "SBO_Level"
local DRILL_LEVEL_ATTRIBUTE = "SBO_DrillLevel"
local FOOD_BOOST_ATTRIBUTE = "SBO_FoodBoostUntil"

-- Feel tuning (not gameplay numbers).
local RESPAWN_GIVE_DELAY = 0.5 -- Roblox empties the backpack around a respawn; give after it
local SAFETY_SYNC_SECONDS = 4 -- a quiet check that nobody lost a tool
local ACTIVATE_SECONDS = 1.2 -- a click with a tool makes it move this long
local TRIGGER_SECONDS = 0.6 -- and finishing a prompt
local ANIM_STEP_SECONDS = 1 / 20 -- weld updates per second while a tool moves
local SPIN_SPEED = 16 -- radians per second
local SCRUB_SPEED = 18
local SCRUB_DISTANCE = 0.14
local GLOW_BRIGHTNESS = 3
local REST_BRIGHTNESS = 1.2
local GLOW_LIGHT = 2
local REST_LIGHT = 0.6

-- Level tint of the drill's battery stripe: basic, upgraded, best.
local LEVEL_COLORS: { Color3 } = { Theme.ROLE.good, Theme.ROLE.accent, Theme.ROLE.star }

local ToolService = {}

local started = false
local baseApi: BaseApi? = nil
local crewApi: CrewApi? = nil
local remotes: Remotes? = nil
local records: { [Player]: Record } = {}

----------------------------------------------------------------------------------------------------
-- Helpers

local function sayTo(player: Player, key: string)
	if remotes and player.Parent then
		local text: Types.TextRef = { key = key }
		remotes.message:FireClient(player, text)
	end
end

local function toolLevel(player: Player, id: string): number
	local api = baseApi
	if api == nil then
		return 0
	end
	local ok, level = pcall(api.toolLevel, player, id)
	if ok and type(level) == "number" and level == level then
		return math.max(0, math.floor(level))
	end
	return 0
end

local function toolDef(id: string): any
	for _, def in MissionData.BASE.TOOLS do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- The Tool with this id the player holds right now (a child of the character), if any.
local function heldTool(player: Player): Tool?
	local character = player.Character
	if character == nil then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and type(child:GetAttribute(TOOL_ID_ATTRIBUTE)) == "string" then
			return child
		end
	end
	return nil
end

-- The player still has this tool: in the backpack or in hand.
local function stillOwned(player: Player, owned: Owned?): boolean
	if owned == nil then
		return false
	end
	local parent = owned.tool.Parent
	if parent == nil then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	return (backpack ~= nil and parent == backpack) or (player.Character ~= nil and parent == player.Character)
end

local function setLevelTint(owned: Owned)
	local rig = owned.rig
	if rig and rig.levelPart then
		rig.levelPart.Color = LEVEL_COLORS[math.clamp(owned.level, 1, #LEVEL_COLORS)]
	end
end

----------------------------------------------------------------------------------------------------
-- Animation

local function setGlow(rig: Rig, on: boolean)
	for _, gui in rig.guis do
		gui.Brightness = if on then GLOW_BRIGHTNESS else REST_BRIGHTNESS
	end
	for _, light in rig.lights do
		light.Brightness = if on then GLOW_LIGHT else REST_LIGHT
	end
	for _, glowPart in rig.glowParts do
		glowPart.Transparency = 0
	end
end

local function animate(owned: Owned, dt: number, t: number)
	local rig = owned.rig
	if rig == nil or rig.kind == nil then
		return
	end
	local weld = rig.weld
	local active = owned.holding or owned.activeUntil > t
	if not active then
		if owned.moving then
			owned.moving = false
			if weld then
				weld.C0 = rig.base
			end
			setGlow(rig, false)
		end
		return
	end
	owned.moving = true
	if rig.kind == "spin" and weld then
		owned.angle = (owned.angle + SPIN_SPEED * dt) % (2 * math.pi)
		weld.C0 = rig.base * CFrame.Angles(owned.angle, 0, 0)
	elseif rig.kind == "scrub" and weld then
		owned.angle += SCRUB_SPEED * dt
		weld.C0 = rig.base * CFrame.new(math.sin(owned.angle) * SCRUB_DISTANCE, 0, 0)
	end
	-- Every moving tool lights up a little; the tablet's screen and its glow parts blink.
	setGlow(rig, true)
	if rig.kind == "glow" then
		local blink = (math.floor(t * 4) % 2 == 0)
		for _, glowPart in rig.glowParts do
			glowPart.Transparency = if blink then 0 else 0.5
		end
	end
end

local function animationLoop()
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		if accumulated < ANIM_STEP_SECONDS then
			return
		end
		local step = accumulated
		accumulated = 0
		local t = os.clock()
		for player, record in records do
			if player.Parent == nil then
				continue
			end
			for _, owned in record.tools do
				if owned.moving or owned.holding or owned.activeUntil > t then
					local ok, err = pcall(animate, owned, step, t)
					if not ok then
						warn(`[SpaceBaseOdyssey] tool animation failed: {err}`)
						owned.holding = false
						owned.activeUntil = 0
					end
				end
			end
		end
	end)
end

-- The tool the player has in hand (Owned), if it is one of ours.
local function ownedInHand(player: Player): Owned?
	local record = records[player]
	local tool = heldTool(player)
	if record == nil or tool == nil then
		return nil
	end
	local id = tool:GetAttribute(TOOL_ID_ATTRIBUTE)
	local owned = if type(id) == "string" then record.tools[id] else nil
	return if owned and owned.tool == tool then owned else nil
end

----------------------------------------------------------------------------------------------------
-- Food

local function removeTool(record: Record, id: string)
	local owned = record.tools[id]
	if owned then
		record.tools[id] = nil
		owned.tool:Destroy()
	end
end

local function eat(player: Player)
	local record = records[player]
	if record == nil or not record.food then
		return
	end
	local crew = crewApi
	if crew and not crew.isInside(player) then
		-- Real: an astronaut outside cannot open the helmet. Eat in the lander or the habitat.
		sayTo(player, "carl.tool.eat_inside")
		return
	end
	record.food = false
	removeTool(record, "food")
	player:SetAttribute(FOOD_BOOST_ATTRIBUTE, workspace:GetServerTimeNow() + MissionData.BASE.FOOD.BOOST_SECONDS)
	local api = baseApi
	if api then
		local ok, err = pcall(api.reward, player, "food_eaten", nil)
		if not ok then
			warn(`[SpaceBaseOdyssey] food reward failed: {err}`)
		end
	end
	sayTo(player, "carl.tool.food_eaten")
end

----------------------------------------------------------------------------------------------------
-- Giving tools

local function onActivated(player: Player, id: string)
	if id == "food" then
		eat(player)
		return
	end
	local record = records[player]
	local owned = record and record.tools[id]
	if owned and owned.tool.Parent == player.Character then
		owned.activeUntil = os.clock() + ACTIVATE_SECONDS
	end
end

local function give(player: Player, record: Record, id: string, level: number, backpack: Backpack)
	local tool, rig = ToolModels.create(id)
	if tool == nil then
		warn(`[SpaceBaseOdyssey] no tool model for {id}`)
		return
	end
	local newTool = tool :: Tool
	newTool:SetAttribute(TOOL_ID_ATTRIBUTE, id)
	newTool:SetAttribute(TEXT_KEY_ATTRIBUTE, `tool.{id}.name`)
	newTool:SetAttribute(LEVEL_ATTRIBUTE, level)
	local owned: Owned = {
		id = id,
		tool = newTool,
		rig = rig,
		activeUntil = 0,
		holding = false,
		moving = false,
		angle = 0,
		level = level,
	}
	setLevelTint(owned)
	newTool.Activated:Connect(function()
		local ok, err = pcall(onActivated, player, id)
		if not ok then
			warn(`[SpaceBaseOdyssey] tool {id} failed: {err}`)
		end
	end)
	record.tools[id] = owned
	newTool.Parent = backpack
end

-- Makes the player's tools match what they have unlocked: missing ones are given, ones no longer
-- unlocked (for example after a debug reset) are taken away, levels are updated.
local function sync(player: Player)
	local record = records[player]
	if record == nil or player.Parent == nil then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, id in ToolModels.ORDER do
		local def = toolDef(id)
		if def == nil then
			continue
		end
		local level = toolLevel(player, id)
		local owned = record.tools[id]
		local wanted = level > 0 and (not def.consumable or record.food)
		if def.consumable and level <= 0 then
			record.food = false
		end
		if wanted then
			if not stillOwned(player, owned) then
				if owned then
					record.tools[id] = nil
					owned.tool:Destroy()
				end
				if backpack then
					give(player, record, id, level, backpack)
				end
			elseif owned and owned.level ~= level then
				owned.level = level
				owned.tool:SetAttribute(LEVEL_ATTRIBUTE, level)
				setLevelTint(owned)
			end
		elseif owned then
			removeTool(record, id)
		end
	end
	player:SetAttribute(DRILL_LEVEL_ATTRIBUTE, toolLevel(player, "drill"))
end

local function safeSync(player: Player)
	local ok, err = pcall(sync, player)
	if not ok then
		warn(`[SpaceBaseOdyssey] tool sync failed for {player.Name}: {err}`)
	end
end

local function addPlayer(player: Player)
	if records[player] then
		return
	end
	local record: Record = { tools = {}, food = false, connections = {} }
	records[player] = record
	table.insert(
		record.connections,
		player.CharacterAdded:Connect(function()
			-- The old tools went with the old character and backpack: give fresh ones.
			for _, owned in record.tools do
				owned.holding = false
			end
			task.delay(RESPAWN_GIVE_DELAY, safeSync, player)
		end)
	)
	safeSync(player)
end

local function removePlayer(player: Player)
	local record = records[player]
	if record == nil then
		return
	end
	records[player] = nil
	for _, connection in record.connections do
		connection:Disconnect()
	end
	for _, owned in record.tools do
		owned.tool:Destroy()
	end
end

local function onFoodPrompt(player: Player)
	local record = records[player]
	local api = baseApi
	if record == nil or api == nil or toolLevel(player, "food") <= 0 then
		return
	end
	if record.food then
		sayTo(player, "carl.tool.food_full") -- one tray at a time
		return
	end
	local ok, taken = pcall(api.takeFood, player)
	if not ok then
		warn(`[SpaceBaseOdyssey] takeFood failed: {taken}`)
		return
	end
	if taken == true then
		record.food = true
		safeSync(player)
		sayTo(player, "carl.tool.food_picked")
	else
		sayTo(player, "carl.tool.food_growing") -- plants take time to grow
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- world: WorldBuilder.World (greenhouseFoodPrompt); baseService: BaseService (already started);
-- crewService: CrewService (already started); remoteEvents.message: C.A.R.L. lines.
function ToolService.start(world: any, baseService: BaseApi, crewService: CrewApi, remoteEvents: Remotes)
	assert(not started, "ToolService already started")
	assert(type(baseService) == "table" and type(baseService.toolLevel) == "function", "ToolService needs BaseService.toolLevel")
	baseApi = baseService
	crewApi = crewService
	remotes = remoteEvents
	started = true

	-- BaseService asks here whether the wrench is in hand before a build step is assembled.
	if type(baseService.setToolChecker) == "function" then
		baseService.setToolChecker(function(player: Player, toolId: string): boolean
			return ToolService.isHolding(player, toolId)
		end)
	else
		warn("[SpaceBaseOdyssey] BaseService has no setToolChecker; the wrench is not checked")
	end
	if type(baseService.onToolsChanged) == "function" then
		baseService.onToolsChanged(function(player: Player)
			safeSync(player)
		end)
	else
		warn("[SpaceBaseOdyssey] BaseService has no onToolsChanged; tools update every few seconds")
	end

	local foodPrompt = world and world.greenhouseFoodPrompt
	if typeof(foodPrompt) == "Instance" and foodPrompt:IsA("ProximityPrompt") then
		foodPrompt.Triggered:Connect(function(player: Player)
			local ok, err = pcall(onFoodPrompt, player)
			if not ok then
				warn(`[SpaceBaseOdyssey] food prompt failed: {err}`)
			end
		end)
	else
		warn("[SpaceBaseOdyssey] world has no greenhouseFoodPrompt; no fresh food")
	end

	-- A tool in hand moves while its player holds any prompt (drilling, scrubbing, assembling...).
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(_prompt: ProximityPrompt, player: Player)
		local owned = ownedInHand(player)
		if owned then
			owned.holding = true
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(_prompt: ProximityPrompt, player: Player)
		local record = records[player]
		if record then
			for _, owned in record.tools do
				owned.holding = false
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(_prompt: ProximityPrompt, player: Player)
		local owned = ownedInHand(player)
		if owned then
			owned.holding = false
			owned.activeUntil = math.max(owned.activeUntil, os.clock() + TRIGGER_SECONDS)
		end
	end)

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end

	animationLoop()
	task.spawn(function()
		while true do
			task.wait(SAFETY_SYNC_SECONDS)
			for player in records do
				if player.Parent ~= nil and player.Character ~= nil then
					safeSync(player)
				end
			end
		end
	end)
end

-- True once start ran: tasks then need their tool in hand. Before that (or without ToolService) the
-- game works the Stage 6 way, without tools.
function ToolService.isActive(): boolean
	return started
end

-- True when the player holds the tool `id` in hand right now (a child of the character).
function ToolService.isHolding(player: Player, id: string): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(TOOL_ID_ATTRIBUTE) == id then
			return true
		end
	end
	return false
end

-- The id of the tool the player holds right now, or nil.
function ToolService.heldId(player: Player): string?
	local tool = heldTool(player)
	if tool == nil then
		return nil
	end
	local id = tool:GetAttribute(TOOL_ID_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

-- True when the player has the tool (in the backpack or in hand).
function ToolService.hasTool(player: Player, id: string): boolean
	local record = records[player]
	return record ~= nil and stillOwned(player, record.tools[id])
end

-- Makes the tool in the player's hand move for a moment (for example the tablet while scanning).
function ToolService.pulse(player: Player, id: string, seconds: number?)
	local record = records[player]
	local owned = record and record.tools[id]
	if owned and owned.tool.Parent == player.Character then
		local duration = if type(seconds) == "number" and seconds == seconds then math.clamp(seconds, 0, 10) else ACTIVATE_SECONDS
		owned.activeUntil = math.max(owned.activeUntil, os.clock() + duration)
	end
end

-- Re-checks one player's tools now (for example right after an unlock, if onToolsChanged is missing).
function ToolService.refresh(player: Player)
	safeSync(player)
end

return ToolService
