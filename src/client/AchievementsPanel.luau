--!strict
-- Space Base Odyssey - Achievements panel (Stage 10, learning achievements). Opens from the top bar
-- (base mode, button "Achievements"). One small tile per achievement in src/shared/Achievements.luau,
-- three columns: an unlocked one shows its icon in colour, its title and what the player learned
-- ("ach.<id>.fact"); a locked one is greyed with its title and how to unlock it ("ach.<id>.hint",
-- plus "have/need" for the counted ones). The state comes from the server (Remotes.ACHIEVEMENTS,
-- Types.AchievementState); this module also turns "new" into the QuestToasts "Achievement
-- unlocked!" card. Read only: the server decides every unlock.
-- Layout (fractions of the panel): title row y 0.03-0.12, tiles y 0.15-0.97 (5 rows of 3).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE

local Z = 53 -- same layer as the Lab and Wardrobe panels
local PANEL_ASPECT = 1.5
local COLUMNS = 3
local TILES_TOP = 0.15
local TILES_BOTTOM = 0.97
local TILE_GAP = 0.012
local REMOTE_WAIT_SECONDS = 60

-- QuestToasts shows the unlock card (pcall: a broken toast module never breaks the panel).
local toasts: any = nil
do
	local ok, result = pcall(function(): any
		return require(script.Parent:WaitForChild("QuestToasts", 5) :: any)
	end)
	if ok and type(result) == "table" then
		toasts = result
	end
end

local AchievementsPanel = {}

export type Deps = {}

export type PanelView = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	render: () -> (),
}

type Tile = {
	def: Achievements.Achievement,
	frame: Frame,
	stroke: UIStroke?,
	icon: ImageLabel,
	badge: ImageLabel,
	title: TextLabel,
	body: TextLabel,
}

function AchievementsPanel.new(root: Frame, _deps: Deps?): PanelView
	local record: Achievements.Record = Achievements.emptyRecord()

	local modal = Ui.modal(root, "Achievements", Z)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z
	backdrop.AutoButtonColor = false
	backdrop.Parent = modal

	local panel = Ui.panel(modal, {
		name = "Panel",
		size = UDim2.fromScale(0.94, 0.92),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.04,
		stroke = 4,
		strokeColor = ROLE.star,
		aspect = PANEL_ASPECT,
		zindex = Z + 1,
	})
	panel.Active = true
	Ui.sheen(panel)

	Ui.icon(panel, Ui.Icons.trophy, {
		size = UDim2.fromScale(0.05, 0.08),
		position = UDim2.fromScale(0.025, 0.075),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.star,
		zindex = Z + 2,
	})
	local title = Ui.label(panel, {
		name = "Title",
		size = UDim2.fromScale(0.3, 0.08),
		position = UDim2.fromScale(0.08, 0.075),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 36,
		zindex = Z + 2,
	})
	Ui.oneLine(title)
	local count = Ui.label(panel, {
		name = "Count",
		size = UDim2.fromScale(0.18, 0.05),
		position = UDim2.fromScale(0.39, 0.075),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.good,
		maxText = 22,
		zindex = Z + 2,
	})
	Ui.oneLine(count)
	local hint = Ui.body(panel, {
		name = "Hint",
		size = UDim2.fromScale(0.3, 0.06),
		position = UDim2.fromScale(0.58, 0.075),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.textDim,
		maxText = 16,
		minText = 8,
		zindex = Z + 2,
	})

	local function close()
		modal.Visible = false
	end
	backdrop.Activated:Connect(close)
	Ui.button(panel, {
		name = "Close",
		size = UDim2.fromScale(0.07, 0.09),
		position = UDim2.fromScale(0.975, 0.03),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 2,
	}, close)

	-- Tiles ------------------------------------------------------------------------------------------
	local rows = math.ceil(#Achievements.LIST / COLUMNS)
	local tileW = (0.95 - TILE_GAP * (COLUMNS - 1)) / COLUMNS
	local tileH = (TILES_BOTTOM - TILES_TOP - TILE_GAP * (rows - 1)) / rows
	local tiles: { Tile } = {}
	for index, def in Achievements.LIST do
		local column = (index - 1) % COLUMNS
		local row = math.floor((index - 1) / COLUMNS)
		local frame = Ui.frame(panel, {
			name = `Ach_{def.id}`,
			size = UDim2.fromScale(tileW, tileH),
			position = UDim2.fromScale(0.025 + column * (tileW + TILE_GAP), TILES_TOP + row * (tileH + TILE_GAP)),
			color = ROLE.panelRaised,
			corner = 0.14,
			stroke = 2,
			strokeColor = ROLE.background,
			zindex = Z + 2,
		})
		local icon = Ui.icon(frame, Ui.iconImage(def.icon), {
			name = "Icon",
			size = UDim2.fromScale(0.15, 0.62),
			position = UDim2.fromScale(0.025, 0.5),
			anchor = Vector2.new(0, 0.5),
			tint = ROLE.stroke,
			zindex = Z + 3,
		})
		local titleLabel = Ui.label(frame, {
			name = "Title",
			size = UDim2.fromScale(0.66, 0.32),
			position = UDim2.fromScale(0.2, 0.06),
			alignX = Enum.TextXAlignment.Left,
			maxText = 20,
			zindex = Z + 3,
		})
		Ui.oneLine(titleLabel)
		local badge = Ui.icon(frame, Ui.ICONS.lock, {
			name = "Badge",
			size = UDim2.fromScale(0.1, 0.3),
			position = UDim2.fromScale(0.975, 0.07),
			anchor = Vector2.new(1, 0),
			aspect = 1,
			tint = ROLE.textDim,
			zindex = Z + 3,
		})
		local body = Ui.body(frame, {
			name = "Body",
			size = UDim2.fromScale(0.77, 0.54),
			position = UDim2.fromScale(0.2, 0.4),
			textColor = ROLE.textDim,
			alignY = Enum.TextYAlignment.Top,
			maxText = 15,
			minText = 7,
			zindex = Z + 3,
		})
		table.insert(tiles, {
			def = def,
			frame = frame,
			stroke = frame:FindFirstChildOfClass("UIStroke"),
			icon = icon,
			badge = badge,
			title = titleLabel,
			body = body,
		})
	end

	local function render()
		title.Text = Store.t("ui.ach_title")
		hint.Text = Store.t("ui.ach_hint")
		local unlockedCount = #Achievements.unlockedList(record)
		count.Text = Store.t("ui.ach_count", { n = unlockedCount, total = #Achievements.LIST })
		-- A guest in a friend's world: that base is the owner's, so it never counts for this player.
		local guest = Players.LocalPlayer:GetAttribute("SBO_Guest") == true
		local baseLevel = if guest then 0 else Store.buildLevel("habitat")
		for _, tile in tiles do
			local def = tile.def
			local unlocked = record.unlocked[def.id] == true
			tile.title.Text = Store.t(Achievements.titleKey(def.id))
			tile.title.TextColor3 = if unlocked then ROLE.star else ROLE.textDim
			tile.icon.ImageColor3 = if unlocked then ROLE.star else ROLE.stroke
			tile.frame.BackgroundColor3 = if unlocked then PALETTE.nightLine else ROLE.panelRaised
			if tile.stroke then
				tile.stroke.Color = if unlocked then ROLE.star else ROLE.background
			end
			Ui.setIcon(tile.badge, if unlocked then Ui.ICONS.check else Ui.ICONS.lock, if unlocked then ROLE.good else ROLE.textDim)
			if unlocked then
				tile.body.Text = Store.t(Achievements.factKey(def.id), Achievements.factParams(MissionData, def) :: any)
				tile.body.TextColor3 = ROLE.text
			else
				local text = Store.t(Achievements.hintKey(def.id), Achievements.hintParams(MissionData, def) :: any)
				local have, need = Achievements.progress(MissionData, def, record, baseLevel)
				if need > 0 then
					text ..= ` ({have}/{need})`
				end
				tile.body.Text = text
				tile.body.TextColor3 = ROLE.textDim
			end
		end
	end

	-- Server state ---------------------------------------------------------------------------------
	local function onState(payload: any)
		if type(payload) ~= "table" or type(payload.unlocked) ~= "table" then
			return
		end
		local unlocked: { [string]: boolean } = {}
		for _, id in payload.unlocked do
			unlocked[id] = true
		end
		record = Achievements.sanitizeRecord({ unlocked = unlocked, counts = payload.counts })
		local newId = payload.new
		if type(newId) == "string" and Achievements.isId(newId) and toasts and type(toasts.achievement) == "function" then
			local xp = if type(payload.xp) == "number" then payload.xp else 0
			local ok, err = pcall(toasts.achievement, newId, xp)
			if not ok then
				warn(`[SpaceBaseOdyssey] achievement toast failed: {err}`)
			end
		end
		if modal.Visible then
			render()
		end
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
		local name: string = (Types.Remotes :: any).ACHIEVEMENTS or "Achievements"
		local remote = remotes:WaitForChild(name, REMOTE_WAIT_SECONDS)
		if remote == nil or not remote:IsA("RemoteEvent") then
			return -- older server: no achievements
		end
		(remote :: RemoteEvent).OnClientEvent:Connect(onState)
	end)

	Store.onChanged(function(kind: Store.ChangeKind)
		local changed: string = kind
		if modal.Visible and (changed == "base" or changed == "language") then
			render()
		end
	end)

	local function open()
		render()
		modal.Visible = true
	end

	local function isOpen(): boolean
		return modal.Visible
	end

	render()
	return { open = open, close = close, isOpen = isOpen, render = render }
end

return AchievementsPanel
