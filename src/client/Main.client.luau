--!strict
-- Space Base Odyssey - client entry point: builds the UI, listens to the server and shows the right screen.
-- Stage 6 "base mode": in Briefing the mission select can be closed to roam the base, build and
-- gather ice. It opens by itself for a new player (no mission completed yet) and after a report;
-- the Missions top button opens it again. The Base and Wardrobe panels open from the top bar.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local REMOTE_WAIT_SECONDS = 60 -- an older server never creates the Stage 6 remote
local PROGRESS_WAIT_SECONDS = 5 -- first join: wait this long for saved progress, then decide

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

Store.setLanguage(Localization.detect(player.LocaleId))

local _gui, root = Ui.createRoot(playerGui)

-- Stage 6 panels (src/client/BasePanel.luau, src/client/Wardrobe.luau). Loaded with pcall: a broken
-- or missing panel hides its buttons but never breaks the rest of the client.
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
-- The HUD meters sit in the left column, right under the objectives panel.
local hud = Hud.new(root, { columnTop = objectives.getBottom })
local report = Report.new(root, sources.addButton)
local sprint = Sprint.new(root)
-- Settings button (top right) and panel: language, volumes, C.A.R.L. options, redeem code.
local settings = Settings.new(root)

local basePanel = loadPanel("BasePanel", { showMessage = messages.show })
local wardrobe = loadPanel("Wardrobe", { showMessage = messages.show })

local function closePanels()
	if basePanel then
		basePanel.close()
	end
	if wardrobe then
		wardrobe.close()
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

-- Top bar beside the Settings button: Missions (base mode), Wardrobe, Base.
local topBar = Hud.newTopBar(root, {
	openBase = if basePanel
		then function()
			togglePanel(basePanel, wardrobe)
		end
		else nil,
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
})

local shownPhase: string? = nil
local boardShown: boolean? = nil

-- Objectives done by walking around the base (training "First steps"). A mission that has only
-- these keeps the power board closed while planning, so the player can see where to walk.
local WALK_OBJECTIVES: { [string]: boolean } = {
	go_outside = true,
	return_inside = true,
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

-- First join: the mission select opens by itself only for a new player (decided once the saved
-- progress arrives, or after PROGRESS_WAIT_SECONDS).
local joinDecided = false
local progressWaitOver = false
local function decideOnJoin()
	if joinDecided or Store.getSnapshot() == nil or not (Store.hasProgress() or progressWaitOver) then
		return
	end
	joinDecided = true
	if Store.phase() == "Briefing" and Store.completedCount() == 0 then
		setSelectOpen(true)
	end
end

local function showPhase(phase: string)
	local previous = shownPhase
	shownPhase = phase
	if phase == "Briefing" then
		-- Back from a report ("Continue" / "Try again" goes to mission select): open it.
		if previous ~= nil and previous ~= "Briefing" then
			joinDecided = true
			Store.setMissionSelectOpen(true)
		end
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
	for _, panel in { basePanel, wardrobe } do
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
		hud.renderWallet()
		topBar.render()
		return
	end
	if kind == "stats" then
		hud.render()
		return
	end
	if kind == "progress" then
		decideOnJoin()
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
	if kind == "snapshot" then
		decideOnJoin()
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
FunFacts.start({ showTip = messages.showTip, isIdle = messages.isIdle })
Onboarding.start({
	show = messages.show,
	showTip = messages.showTip,
	setGuide = powerBoard.setGuide,
})
DemoKeys.start()
Movement.start()
task.delay(PROGRESS_WAIT_SECONDS, function()
	progressWaitOver = true
	decideOnJoin()
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
