--!strict
-- Space Base Odyssey - client entry point: builds the UI, listens to the server and shows the right screen.
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
local Briefing = require(Client:WaitForChild("Briefing"))
local PowerBoard = require(Client:WaitForChild("PowerBoard"))
local Hud = require(Client:WaitForChild("Hud"))
local Report = require(Client:WaitForChild("Report"))
local Sprint = require(Client:WaitForChild("Sprint"))
local Prompts = require(Client:WaitForChild("Prompts"))

print(`[SpaceBaseOdyssey] client started, build {Version.BUILD}`)

local HUD_TICK_SECONDS = 0.1

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

Store.setLanguage(Localization.detect(player.LocaleId))

local _gui, root = Ui.createRoot(playerGui)

local messages = Messages.new(root)
local briefing = Briefing.new(root)
local powerBoard = PowerBoard.new(root, messages.show)
local hud = Hud.new(root)
local report = Report.new(root)
local sprint = Sprint.new(root)

-- Language toggle (top right): shows the current language; a tap switches EN <-> ES.
local languageButton = Ui.button(root, {
	name = "Language",
	size = UDim2.fromScale(0.17, 0.08),
	position = UDim2.fromScale(0.985, 0.02),
	anchor = Vector2.new(1, 0),
	color = Ui.COLORS.panelLight,
	stroke = 3,
	maxText = 26,
	zindex = 60,
}, function()
	local nextLanguage: Store.Language = if Store.getLanguage() == "en" then "es" else "en"
	Store.setLanguage(nextLanguage)
	Store.send({ type = "SetLanguage", language = nextLanguage })
end)

local function renderLanguageButton()
	languageButton.Text = `{Ui.ICONS.language} {Store.t("ui.language")}`
end

local shownPhase: string? = nil

local function showPhase(phase: string)
	briefing.setVisible(phase == "Briefing")
	powerBoard.setVisible(phase == "Planning")
	hud.setVisible(phase == "Shift")
	report.setVisible(phase == "Report")
	sprint.setVisible(phase == "Shift")
	messages.setPhase(phase)
	shownPhase = phase
end

local function renderAll()
	briefing.render()
	powerBoard.render()
	hud.render()
	report.render()
	sprint.render()
	messages.render()
	renderLanguageButton()
end

Store.onChanged(function(kind: Store.ChangeKind)
	if kind == "stats" then
		hud.render()
		return
	end
	local phase = Store.phase()
	if phase ~= shownPhase then
		showPhase(phase)
	end
	if kind == "language" then
		renderAll()
		Prompts.refresh()
	else
		briefing.render()
		powerBoard.render()
		hud.render()
		report.render()
	end
	hud.tick()
end)

showPhase("Briefing")
renderAll()
Prompts.start()

-- Countdowns use server time, refreshed a few times per second.
local sinceTick = 0
RunService.Heartbeat:Connect(function(deltaTime: number)
	sinceTick += deltaTime
	if sinceTick >= HUD_TICK_SECONDS then
		sinceTick = 0
		hud.tick()
	end
end)

-- Network: the server owns the mission and sends Snapshots, per-player stats and C.A.R.L. messages.
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
	end
end)

Store.send({ type = "SetLanguage", language = Store.getLanguage() })
