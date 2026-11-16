--!strict
-- Space Base Odyssey - client entry point: builds the UI, listens to the server and shows the right screen.
-- Stage 6 "base mode": in Briefing the mission select can be closed to roam the base, build and
-- gather ice. The Missions top button opens it (Stage 9: it never opens by itself). The Wardrobe opens
-- from the top bar.
-- Stage 7: there is no Base menu any more (builds happen only at the pads in the world). The Lab panel
-- (BasePanel.luau: skills, tool upgrades, pets) opens only when the player uses the Lab's prompt
-- ("LabPrompt") and closes when they walk away. Exploration scans show an ExploreCard. The vehicle
-- HUD (VehicleClient.luau) starts here too.
-- Fix 8 (playtest): Roblox's tool bar (backpack hotbar, bottom centre) covered our boxes. It is hidden
-- while a full-screen panel is open (mission select, power board, report, Lab, Wardrobe and the other
-- modal screens), and the C.A.R.L. bubble moves with the screen mode (Messages.setMode) so it never
-- sits at the bottom centre while the player walks around with tools.
-- Stage 8: gear (Gear.luau: air boots and jetpack, keys B / J, the client-side gas tank) is loaded
-- with pcall and feeds the HUD gas bar; auto-run (Sprint.luau, key X) stops while a panel is open.
-- Stage 9 (open world): the start menu (StartMenu.luau: Continue, New game, Load game with 3 save
-- slots, Settings, Credits) is the first screen; the player has no character until the server loads
-- a slot (player attribute SBO_SlotChosen). The mission select never opens by itself at the start any
-- more: missions start from the habitat's mission console (prompt "MissionConsolePrompt") or the
-- Missions top button, and main quests guide the player. After a report the player is back in the base.
-- Stage 10: the Achievements panel (AchievementsPanel.luau, learning achievements) opens from the top
-- bar in base mode.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Version = require(Shared:WaitForChild("Version"))
local Localization = require(Shared:WaitForChild("Localization"))
local Types = require(Shared:WaitForChild("Types"))

local Client = script.Parent
local Store = require(Client:WaitForChild("Store"))
local Ui = require(Client:WaitForChild("Ui"))
local Messages = require(Client:WaitForChild("Messages"))
local MissionSelect = require(Client:WaitForChild("MissionSelect"))
local PowerBoard = require(Client:WaitForChild("PowerBoard"))
local Hud = require(Client:WaitForChild("Hud"))
local Report = require(Client:WaitForChild("Report"))
local Sprint = require(Client:WaitForChild("Sprint"))
local Prompts = require(Client:WaitForChild("Prompts"))
local Sources = require(Client:WaitForChild("Sources"))
local Markers = require(Client:WaitForChild("Markers"))
local CarlDrone = require(Client:WaitForChild("CarlDrone"))
local Onboarding = require(Client:WaitForChild("Onboarding"))
local DemoKeys = require(Client:WaitForChild("DemoKeys"))
local Objectives = require(Client:WaitForChild("Objectives"))
local Collection = require(Client:WaitForChild("Collection"))
local Rewards = require(Client:WaitForChild("Rewards"))
local Settings = require(Client:WaitForChild("Settings"))
local FunFacts = require(Client:WaitForChild("FunFacts"))
local Movement = require(Client:WaitForChild("Movement"))

print(`[SpaceBaseOdyssey] client started, build {Version.BUILD}`)

local HUD_TICK_SECONDS = 0.1
-- Stage 4 remotes (names from Types.Remotes; literal fallbacks match the contract).
local PROGRESS_REMOTE: string = (Types.Remotes :: any).PROGRESS or "Progress"
local COLLECTED_REMOTE: string = (Types.Remotes :: any).COLLECTED or "Collected"
local BASE_STATE_REMOTE: string = (Types.Remotes :: any).BASE_STATE or "BaseState"
local EXPLORE_REMOTE: string = (Types.Remotes :: any).EXPLORE or "Explore"
local REMOTE_WAIT_SECONDS = 60 -- an older server never creates the Stage 6 remote
-- Stage 9 save slots: the server sends the slot list on this remote (nil = an older server).
local SLOTS_REMOTE: string = (Types.Remotes :: any).SLOTS or "Slots"
local SLOTS_WAIT_SECONDS = 20
-- Stage 7 Lab panel: opened by the prompt with this name, closed this far (studs) from it.
local LAB_PROMPT_NAME = "LabPrompt"
local LAB_CLOSE_DISTANCE = 30
-- Stage 9: the habitat's mission console opens the mission select.
local MISSION_CONSOLE_PROMPT_NAME = "MissionConsolePrompt"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

Store.setLanguage(Localization.detect(player.LocaleId))

local _gui, root = Ui.createRoot(playerGui)

-- Panels (src/client/BasePanel.luau = the Lab panel, src/client/Wardrobe.luau). Loaded with pcall: a
-- broken or missing panel hides its buttons but never breaks the rest of the client.
type PanelView = { open: () -> (), close: () -> (), isOpen: () -> boolean }

local function loadPanel(name: string, deps: any): PanelView?
	local ok, result = pcall(function(): any
		local moduleScript = Client:WaitForChild(name, 5)
		if moduleScript == nil then
			error(`{name} not found`)
		end
		local module: any = require(moduleScript :: any)
		return module.new(root, deps)
	end)
	if not ok or type(result) ~= "table" or type(result.open) ~= "function" or type(result.close) ~= "function" then
		warn(`[SpaceBaseOdyssey] {name} panel unavailable: {result}`)
		return nil
	end
	if type(result.isOpen) ~= "function" then
		result.isOpen = function(): boolean
			return false
		end
	end
	return result
end

-- Full-screen panels (by their frame names under the root). While one is open the mouse is freed,
-- the tool bar is hidden and auto-run stops.
local MODAL_PANELS = {
	"StartMenu", "MissionSelect", "Report", "PowerBoard", "Settings", "Sources", "Collection", "FindCard",
	"BasePanel", "Wardrobe", "ExploreCard", "Achievements",
}
local function anyPanelOpen(): boolean
	for _, name in MODAL_PANELS do
		local panel = root:FindFirstChild(name)
		if panel and panel:IsA("GuiObject") and panel.Visible then
			return true
		end
	end
	return false
end

-- Stage 8 gear (pcall: a broken Gear module never breaks the client; the HUD then shows no gas bar).
local gearModule: any = nil
do
	local ok, result = pcall(function(): any
		local moduleScript = Client:WaitForChild("Gear", 5)
		if moduleScript == nil then
			error("Gear not found")
		end
		return require(moduleScript :: any)
	end)
	if ok and type(result) == "table" and type(result.start) == "function" and type(result.gas) == "function" then
		gearModule = result
	else
		warn(`[SpaceBaseOdyssey] Gear unavailable: {result}`)
	end
end
local gearDeps: Hud.GearDeps? = if gearModule
	then {
		gas = function(): (number, number)
			return gearModule.gas()
		end,
		level = function(id: string): number
			return gearModule.level(id)
		end,
		isOn = function(id: string): boolean
			return gearModule.isOn(id)
		end,
	}
	else nil

local messages = Messages.new(root)
local sources = Sources.new(root)
local collection = Collection.new(root, { showMessage = messages.show })

-- Mission select open or closed (base mode) in Briefing; applyView (below) shows the result.
local applyView: () -> () = function() end
local function setSelectOpen(open: boolean)
	Store.setMissionSelectOpen(open)
	applyView()
end

local missionSelect = MissionSelect.new(root, {
	showMessage = messages.show,
	addSourcesButton = sources.addButton,
	openCollection = collection.open,
	onClose = function()
		setSelectOpen(false)
	end,
})
local powerBoard = PowerBoard.new(root, messages.show, sources.addButton)
local objectives = Objectives.new(root)
local sprint = Sprint.new(root, { panelOpen = anyPanelOpen })
-- The HUD meters sit in the left column, right under the objectives panel.
local hud = Hud.new(root, {
	columnTop = objectives.getBottom,
	gear = gearDeps,
	autoRunning = sprint.isAutoRunning,
})
local report = Report.new(root, sources.addButton)
-- Settings button (top right) and panel: language, volumes, C.A.R.L. options, redeem code.
local settings = Settings.new(root)

local basePanel = loadPanel("BasePanel", { showMessage = messages.show }) -- the Lab panel

-- Stage 9 start menu (pcall: if it ever breaks, the player still gets into the game, see below).
type StartMenuView = { render: () -> (), isOpen: () -> boolean, hide: () -> () }
local startMenu: StartMenuView? = nil
do
	local ok, result = pcall(function(): any
		local moduleScript = Client:WaitForChild("StartMenu", 5)
		if moduleScript == nil then
			error("StartMenu not found")
		end
		local module: any = require(moduleScript :: any)
		return module.new(root, {
			openSettings = settings.open,
			closeSettings = settings.close,
		})
	end)
	if ok and type(result) == "table" and type(result.render) == "function" then
		startMenu = result
	else
		warn(`[SpaceBaseOdyssey] StartMenu unavailable: {result}`)
	end
end
-- Stage 11 audio: music state machine and game sounds (src/client/Audio.luau; pcall: never breaks the client).
do
	local ok, result = pcall(function()
		local module: any = require(Client:WaitForChild("Audio", 5) :: any)
		module.start({
			menuOpen = function(): boolean
				return startMenu ~= nil and startMenu.isOpen()
			end,
		})
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] Audio unavailable: {result}`)
	end
end
local wardrobe = loadPanel("Wardrobe", { showMessage = messages.show })
local achievementsPanel = loadPanel("AchievementsPanel", {}) -- Stage 10 learning achievements

-- Stage 7 exploration card (pcall: a broken card never breaks the client).
type ExploreCardView = { show: (event: any) -> (), close: () -> (), isOpen: () -> boolean, render: () -> () }
local exploreCard: ExploreCardView? = nil
do
	local ok, result = pcall(function(): any
		local moduleScript = Client:WaitForChild("ExploreCard", 5)
		if moduleScript == nil then
			error("ExploreCard not found")
		end
		local module: any = require(moduleScript :: any)
		return module.new(root)
	end)
	if ok and type(result) == "table" and type(result.show) == "function" then
		exploreCard = result
	else
		warn(`[SpaceBaseOdyssey] ExploreCard unavailable: {result}`)
	end
end

local function closePanels()
	if basePanel then
		basePanel.close()
	end
	if wardrobe then
		wardrobe.close()
	end
	if achievementsPanel then
		achievementsPanel.close()
	end
end

-- Open one panel (closing the other); pressing its button again closes it.
local function togglePanel(panel: PanelView?, other: PanelView?)
	if panel == nil then
		return
	end
	if panel.isOpen() then
		panel.close()
		return
	end
	if other then
		other.close()
	end
	settings.close()
	sources.close()
	panel.open()
end

-- Top bar beside the Settings button: Missions (base mode) and Wardrobe.
-- Team feedback (Stage 6 playtest): no Base button. Building from a menu let players upgrade
-- everything while standing still; builds happen at the pads in the world, and the Lab panel opens
-- only at the Lab.
local topBar = Hud.newTopBar(root, {
	openWardrobe = if wardrobe
		then function()
			togglePanel(wardrobe, basePanel)
		end
		else nil,
	openMissions = function()
		if Store.phase() == "Briefing" then
			closePanels()
			setSelectOpen(true)
		end
	end,
	openAchievements = if achievementsPanel
		then function()
			local panel = achievementsPanel :: PanelView
			if panel.isOpen() then
				panel.close()
				return
			end
			closePanels()
			settings.close()
			sources.close()
			panel.open()
		end
		else nil,
})

-- First person locks the mouse to the screen centre, so a player could not reach a panel's buttons
-- (playtest: the "new secret" card). A visible GuiButton with Modal = true frees the mouse, so one
-- invisible Modal button is shown whenever any full-screen panel is open.
do
	local unlock = Instance.new("TextButton")
	unlock.Name = "MouseUnlock"
	unlock.Text = ""
	unlock.BackgroundTransparency = 1
	unlock.Size = UDim2.fromOffset(1, 1) -- a real (tiny) button: Modal needs a visible GuiButton
	unlock.Modal = true
	unlock.Visible = false
	unlock.Selectable = false
	unlock.Parent = root
	-- Roblox's tool bar draws over our panels' bottom buttons: hide it while one is open (the tools
	-- stay in the backpack; the number keys work again once the panel closes).
	local hotbarOn: boolean? = nil
	local function setHotbar(on: boolean)
		if on == hotbarOn then
			return
		end
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on)
		end)
		if ok then
			hotbarOn = on
		end
	end
	-- Small cards that pop up while playing keep the hotbar: hiding it would put away the tool in
	-- hand (the tablet right after a scan).
	local KEEP_HOTBAR: { [string]: boolean } = { ExploreCard = true, FindCard = true }
	local function bigPanelOpen(): boolean
		for _, name in MODAL_PANELS do
			local panel = root:FindFirstChild(name)
			if not KEEP_HOTBAR[name] and panel and panel:IsA("GuiObject") and panel.Visible then
				return true
			end
		end
		return false
	end
	RunService.Heartbeat:Connect(function()
		local open = anyPanelOpen()
		if unlock.Visible ~= open then
			unlock.Visible = open
		end
		setHotbar(not bigPanelOpen())
	end)
end

local shownPhase: string? = nil
local boardShown: boolean? = nil

-- Objectives done by walking around the base (training "First steps"). A mission that has only
-- these keeps the power board closed while planning, so the player can see where to walk.
local WALK_OBJECTIVES: { [string]: boolean } = {
	go_outside = true,
	return_inside = true,
	build_habitat = true,
	build_solar = true,
	build_greenhouse = true,
	build_antenna = true,
	build_shelter = true,
}

-- Stage 6: a mission that starts with building something keeps the power board closed until it
-- stands (the player walks to the build pad first).
local function buildPending(): boolean
	local mission = Store.mission()
	if mission == nil then
		return false
	end
	for _, objective in mission.objectives do
		if string.sub(objective.id, 1, 6) == "build_" and not objective.done then
			return true
		end
	end
	return false
end

local function walkOnlyMission(): boolean
	local mission = Store.mission()
	if mission == nil or #mission.objectives == 0 then
		return false
	end
	for _, objective in mission.objectives do
		if not WALK_OBJECTIVES[objective.id] then
			return false
		end
	end
	return true
end

local shownMode: Hud.Mode? = nil
local selectShown: boolean? = nil

-- HUD and top bar mode from the phase, the power board and the mission select.
local function viewMode(phase: string): Hud.Mode
	if phase == "Shift" then
		return "shift"
	elseif phase == "Planning" then
		return if boardShown then "board" else "roam"
	elseif phase == "Briefing" then
		return if Store.isMissionSelectOpen() then "select" else "base"
	end
	return "none"
end

applyView = function()
	local phase = Store.phase()
	local selectWanted = phase == "Briefing" and Store.isMissionSelectOpen()
	if selectWanted ~= selectShown then
		selectShown = selectWanted
		missionSelect.setVisible(selectWanted)
	end
	local mode = viewMode(phase)
	if mode ~= shownMode then
		shownMode = mode
		hud.setMode(mode)
		topBar.setMode(mode)
		messages.setMode(mode)
		sprint.setVisible(mode == "shift" or mode == "roam" or mode == "base")
	end
end

local function updateBoard(phase: string)
	local wanted = phase == "Planning" and not walkOnlyMission() and not buildPending()
	if wanted ~= boardShown then
		boardShown = wanted
		powerBoard.setVisible(wanted)
	end
	applyView()
end

local function showPhase(phase: string)
	shownPhase = phase
	if phase == "Briefing" then
		-- Stage 9 open world: the mission select never opens by itself (not on join, not after a
		-- report). Back from a report the player is in the base with the quest tracker; missions
		-- start from the habitat's mission console or the top Missions button.
		Store.setMissionSelectOpen(false)
	else
		Store.setMissionSelectOpen(false)
	end
	updateBoard(phase)
	report.setVisible(phase == "Report")
	objectives.setPhase(phase)
	messages.setPhase(phase)
	-- A new phase needs the player's attention (e.g. the shift clock starts): close the panels.
	sources.close()
	settings.close()
	if phase ~= "Briefing" then
		collection.close()
	end
	if phase == "Shift" or phase == "Report" then
		closePanels()
	end
	applyView()
end

local function renderAll()
	missionSelect.render()
	powerBoard.render()
	hud.render()
	report.render()
	sprint.render()
	messages.render()
	sources.render()
	objectives.render()
	collection.render()
	settings.render()
	topBar.render()
	if exploreCard then
		exploreCard.render()
	end
	if startMenu then
		startMenu.render()
	end
	for _, panel in { basePanel, wardrobe, achievementsPanel } do
		local render = (panel :: any).render
		if type(render) == "function" then
			render()
		end
	end
end

Store.onChanged(function(kind: Store.ChangeKind)
	if kind == "settings" then
		return -- Settings, C.A.R.L. and the fun facts read their settings themselves
	end
	if kind == "view" then
		return -- applyView already ran (setSelectOpen / showPhase)
	end
	if kind == "base" then
		hud.renderBase()
		topBar.render()
		if Store.isMissionSelectOpen() then
			missionSelect.render() -- the quest badge follows the active quest
		end
		return
	end
	if kind == "explore" then
		return -- the ExploreCard shows it (CarlDrone and Onboarding read the Store themselves)
	end
	if kind == "slots" then
		if startMenu then
			startMenu.render()
		end
		return
	end
	if kind == "stats" then
		hud.render()
		return
	end
	if kind == "progress" then
		missionSelect.render()
		collection.render()
		report.render()
		hud.render()
		return
	end
	local phase = Store.phase()
	if phase ~= shownPhase then
		showPhase(phase)
	else
		updateBoard(phase) -- the mission can change without a phase change ("Try again")
	end
	if kind == "language" then
		renderAll()
		Prompts.refresh()
	else
		missionSelect.render()
		powerBoard.render()
		hud.render()
		report.render()
		objectives.render()
		sources.render() -- the live space-weather summary can arrive after the first snapshot
	end
	hud.tick()
end)

showPhase("Briefing")
renderAll()
Prompts.start()

-- Preload every icon once so HUD icons never appear blank on first use.
task.spawn(function()
	local ContentProvider = game:GetService("ContentProvider")
	local Icons = require(Shared:WaitForChild("Icons"))
	local images: { Instance } = {}
	for _, id in Icons do
		local image = Instance.new("ImageLabel")
		image.Image = id
		table.insert(images, image)
	end
	pcall(function()
		ContentProvider:PreloadAsync(images)
	end)
	for _, image in images do
		image:Destroy()
	end
end)
-- Guidance: task markers, the C.A.R.L. drone and the tutorial tips follow the Store by themselves.
Markers.start()
CarlDrone.start()
Rewards.start()
-- Stage 10: quest toasts on the right side (new quest, step done, quest complete). pcall: a broken
-- toast module never breaks the client.
do
	local ok, result = pcall(function()
		local moduleScript = Client:WaitForChild("QuestToasts", 5)
		if moduleScript == nil then
			error("QuestToasts not found")
		end
		local module: any = require(moduleScript :: any)
		module.start(root)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] QuestToasts unavailable: {result}`)
	end
end
FunFacts.start({ showTip = messages.showTip, isIdle = messages.isIdle })
Onboarding.start({
	show = messages.show,
	showTip = messages.showTip,
	setGuide = powerBoard.setGuide,
	gearLevel = if gearModule then gearModule.level else nil,
})
DemoKeys.start()
Movement.start()
-- Stage 8 gear: keys B / J, touch buttons, the double jump, the jetpack and the gas tank.
if gearModule then
	local ok, result = pcall(gearModule.start, root, { showTip = messages.showTip })
	if not ok then
		warn(`[SpaceBaseOdyssey] Gear failed to start: {result}`)
	end
end
-- Stage 11 tycoon: the ice line's cubes, drill bits, cargo robot and air maker move here (pcall: never breaks the client).
pcall(function()
	(require(Client:WaitForChild("ProductionLine", 5) :: any) :: any).start()
end)
-- Stage 10: "Game saved" pill after each save (src/client/SaveIndicator.luau; pcall: never breaks the client).
do
	local ok, result = pcall(function()
		local moduleScript = Client:WaitForChild("SaveIndicator", 5)
		if moduleScript == nil then
			error("SaveIndicator not found")
		end
		local module: any = require(moduleScript :: any)
		module.start(root)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] SaveIndicator unavailable: {result}`)
	end
end
-- Stage 7 drivable vehicles: chase camera, speed readout and exit hint (src/client/VehicleClient.luau).
task.spawn(function()
	local ok, result = pcall(function()
		local moduleScript = Client:WaitForChild("VehicleClient", 10)
		if moduleScript == nil then
			error("VehicleClient not found")
		end
		local module: any = require(moduleScript :: any)
		module.start(root)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] VehicleClient unavailable: {result}`)
	end
end)

-- Stage 7 Lab panel: opens only when this player uses the Lab's prompt, closes when they walk away
-- (the server also checks the distance for every Lab action).
do
	local labPart: BasePart? = nil

	local function promptPart(prompt: ProximityPrompt): BasePart?
		local parent = prompt.Parent
		if parent and parent:IsA("Attachment") then
			parent = parent.Parent
		end
		if parent and parent:IsA("BasePart") then
			return parent
		end
		if parent and parent:IsA("Model") then
			return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
		end
		return nil
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		local panel = basePanel
		if who ~= player or prompt.Name ~= LAB_PROMPT_NAME or panel == nil then
			return
		end
		if Store.phase() == "Report" then
			return
		end
		labPart = promptPart(prompt)
		if wardrobe then
			wardrobe.close()
		end
		if achievementsPanel then
			achievementsPanel.close()
		end
		settings.close()
		sources.close()
		panel.open()
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		if sinceCheck < 0.25 then
			return
		end
		sinceCheck = 0
		local panel = basePanel
		if panel == nil or not panel.isOpen() then
			return
		end
		local part = labPart
		local character = player.Character
		local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if part == nil or part.Parent == nil then
			panel.close() -- the Lab is gone (base reset)
			return
		end
		if rootPart and rootPart:IsA("BasePart") and (rootPart.Position - part.Position).Magnitude > LAB_CLOSE_DISTANCE then
			panel.close()
		end
	end)
end
-- Stage 9: the habitat's mission console opens the mission select (in Briefing only: a mission
-- that is running keeps its own screens).
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or prompt.Name ~= MISSION_CONSOLE_PROMPT_NAME then
		return
	end
	if Store.phase() ~= "Briefing" or (startMenu ~= nil and startMenu.isOpen()) then
		return
	end
	closePanels()
	settings.close()
	sources.close()
	setSelectOpen(true)
end)

-- Countdowns use server time, refreshed a few times per second.
local sinceTick = 0
RunService.Heartbeat:Connect(function(deltaTime: number)
	sinceTick += deltaTime
	if sinceTick >= HUD_TICK_SECONDS then
		sinceTick = 0
		hud.tick()
	end
end)

-- Network: the server owns the mission and sends Snapshots, per-player stats, progress and
-- C.A.R.L. messages.
local remotes = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
local snapshotRemote = remotes:WaitForChild(Types.Remotes.SNAPSHOT) :: RemoteEvent
local statsRemote = remotes:WaitForChild(Types.Remotes.PLAYER_STATS) :: RemoteEvent
local messageRemote = remotes:WaitForChild(Types.Remotes.MESSAGE) :: RemoteEvent
local actionRemote = remotes:WaitForChild(Types.Remotes.ACTION) :: RemoteEvent

Store.setActionRemote(actionRemote)

snapshotRemote.OnClientEvent:Connect(function(snapshot: any)
	if type(snapshot) == "table" and type(snapshot.phase) == "string" then
		Store.setSnapshot(snapshot)
	end
end)

statsRemote.OnClientEvent:Connect(function(stats: any)
	if type(stats) == "table" and type(stats.suitO2) == "number" then
		Store.setStats(stats)
	end
end)

messageRemote.OnClientEvent:Connect(function(ref: any)
	if type(ref) == "table" and type(ref.key) == "string" then
		messages.show(ref)
		-- Answers to a redeem code also show inside the Settings panel (it covers the bubble).
		if string.match(ref.key, "^carl%.code_") then
			settings.showRedeemResult(ref)
		end
	end
end)

-- Progress and collectibles: wait in the background so an older server never blocks the client.
task.spawn(function()
	local progressRemote = remotes:WaitForChild(PROGRESS_REMOTE) :: RemoteEvent
	progressRemote.OnClientEvent:Connect(function(progress: any)
		if type(progress) == "table" then
			Store.setProgress(progress)
		end
	end)
end)
task.spawn(function()
	local baseRemote = remotes:WaitForChild(BASE_STATE_REMOTE, REMOTE_WAIT_SECONDS)
	if baseRemote == nil or not baseRemote:IsA("RemoteEvent") then
		return -- older server: no build-and-grow state
	end
	baseRemote.OnClientEvent:Connect(function(state: any)
		if type(state) == "table" and type(state.credits) == "number" then
			Store.setBase(state)
		end
	end)
end)
task.spawn(function()
	local exploreRemote = remotes:WaitForChild(EXPLORE_REMOTE, REMOTE_WAIT_SECONDS)
	if exploreRemote == nil or not exploreRemote:IsA("RemoteEvent") then
		return -- older server: no exploration scans
	end
	exploreRemote.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or (payload.kind ~= "poi" and payload.kind ~= "meteor") then
			return
		end
		local event: Types.ExploreEvent = {
			kind = payload.kind,
			id = if type(payload.id) == "string" then payload.id else "",
			isNew = payload.isNew == true,
		}
		Store.setExplore(event)
		if exploreCard then
			exploreCard.show(event)
		end
	end)
end)
task.spawn(function()
	local collectedRemote = remotes:WaitForChild(COLLECTED_REMOTE) :: RemoteEvent
	collectedRemote.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.id) == "string" then
			collection.showCollected({
				id = payload.id,
				isNew = payload.isNew == true,
				allFound = payload.allFound == true,
			})
		end
	end)
end)

Store.send({ type = "SetLanguage", language = Store.getLanguage() })

-- Stage 9 save slots: the start menu lists them. With an older server (no "Slots" remote) the menu
-- closes so the player is never stuck on it. If the start menu module failed to load, the player
-- still gets in: the last used world (or world 1) loads in this server.
task.spawn(function()
	local slotsRemote = remotes:WaitForChild(SLOTS_REMOTE, SLOTS_WAIT_SECONDS)
	if slotsRemote == nil or not slotsRemote:IsA("RemoteEvent") then
		if startMenu then
			startMenu.hide()
		end
		return
	end
	local fallbackSent = false
	slotsRemote.OnClientEvent:Connect(function(meta: any)
		if type(meta) ~= "table" then
			return
		end
		Store.setSlots(meta)
		if startMenu == nil and not fallbackSent and not Store.isSlotChosen() then
			fallbackSent = true
			local slot = Store.continueSlot()
			Store.chooseSlot(slot or 1, "friends", false)
		end
	end)
	-- Ask once for the slot list, in case it was sent before this listener existed.
	if not Store.isSlotChosen() then
		local request: any = { type = "RequestSlots" }
		Store.send(request)
	end
end)
