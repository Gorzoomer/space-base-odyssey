--!strict
-- Space Base Odyssey - Achievements panel (Stage 10, learning achievements). Opens from the top bar
-- (base mode, button "Achievements"). One tile per achievement in src/shared/Achievements.luau: an
-- unlocked one shows its icon in colour, its title and what the player learned ("ach.<id>.fact"); a
-- locked one is greyed with its title and how to unlock it ("ach.<id>.hint", plus "have/need" for the
-- counted ones). The state comes from the server (Remotes.ACHIEVEMENTS, Types.AchievementState); this
-- module also turns "new" into the QuestToasts "Achievement unlocked!" card. Read only: the server
-- decides every unlock.
-- Stage 11 readable UI: fewer, bigger tiles on pages (2 columns x 3 rows; 2 x 2 on small screens such
-- as phones, where the root's UIScale is under SMALL_SCALE), with big previous / next buttons and
-- "Page n of m". Fact and hint text never goes below a readable size: at least READABLE_PX real pixels
-- (minText = READABLE_PX / Ui.scale(), between 14 and 22 layout units), so long Spanish facts wrap
-- instead of shrinking away. Glossary words (src/shared/Glossary.luau) in a fact or hint are gold and
-- underlined; tapping the tile opens the picture card (GlossaryCard.luau).
-- Layout (fractions of the panel): title row y 0.03-0.12, tiles y 0.15-0.85, page row y 0.87-0.97.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))
local Reading = require(Shared:WaitForChild("Reading")) -- Stage 11 readable UI

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE

local Z = 53 -- same layer as the Lab and Wardrobe panels
local PANEL_ASPECT = 1.5
local COLUMNS = 2
local ROWS = 3
local ROWS_SMALL = 2 -- small screens: 4 big tiles per page
local SMALL_SCALE = 0.75 -- root UIScale under this = a small screen (a phone in landscape is about 0.54)
local READABLE_PX = 12 -- smallest fact text in real screen pixels
local TILES_TOP = 0.15
local TILES_BOTTOM = 0.85
local TILES_LEFT = 0.025
local TILES_WIDTH = 0.95
local TILE_GAP = 0.014
local PAGE_Y = 0.92 -- centre of the page row
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

-- Stage 11 glossary card (pcall: a broken card never breaks the panel).
local glossary: any = nil
do
	local ok, result = pcall(function(): any
		return require(script.Parent:WaitForChild("GlossaryCard", 5) :: any)
	end)
	if ok and type(result) == "table" then
		glossary = result
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

-- One tile slot on the page (filled with a different achievement on each page).
type Tile = {
	frame: Frame,
	stroke: UIStroke?,
	icon: ImageLabel,
	badge: ImageLabel,
	title: TextLabel,
	body: TextLabel,
	bodyLimit: UITextSizeConstraint?,
	book: ImageLabel,
	hit: TextButton,
	term: string?,
}

-- Smallest body text in layout units for READABLE_PX real pixels at the current UI scale.
local function readableMin(): number
	return math.clamp(math.ceil(READABLE_PX / math.max(Ui.scale(), 0.01)), 14, 22)
end

local function markup(text: string): (string, string?)
	if glossary and type(glossary.markup) == "function" then
		local ok, rich, termId = pcall(glossary.markup, text)
		if ok and type(rich) == "string" then
			return rich, if type(termId) == "string" then termId else nil
		end
	end
	return Reading.escape(text), nil
end

function AchievementsPanel.new(root: Frame, _deps: Deps?): PanelView
	local record: Achievements.Record = Achievements.emptyRecord()
	if glossary and type(glossary.mount) == "function" then
		pcall(glossary.mount, root)
	end

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
		size = UDim2.fromScale(0.3, 0.08),
		position = UDim2.fromScale(0.58, 0.075),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.textDim,
		maxText = 18,
		minText = 13,
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

	-- Tiles (COLUMNS x ROWS slots, refilled for each page) -------------------------------------------
	local tiles: { Tile } = {}
	for index = 1, COLUMNS * ROWS do
		local frame = Ui.frame(panel, {
			name = `Tile{index}`,
			color = ROLE.panelRaised,
			corner = 0.1,
			stroke = 2,
			strokeColor = ROLE.background,
			zindex = Z + 2,
			visible = false,
		})
		local icon = Ui.icon(frame, Ui.ICONS.star, {
			name = "Icon",
			size = UDim2.fromScale(0.13, 0.4),
			position = UDim2.fromScale(0.025, 0.06),
			aspect = 1,
			tint = ROLE.stroke,
			zindex = Z + 3,
		})
		local titleLabel = Ui.label(frame, {
			name = "Title",
			size = UDim2.fromScale(0.66, 0.26),
			position = UDim2.fromScale(0.17, 0.05),
			alignX = Enum.TextXAlignment.Left,
			maxText = 26,
			minText = 14,
			zindex = Z + 3,
		})
		local badge = Ui.icon(frame, Ui.ICONS.lock, {
			name = "Badge",
			size = UDim2.fromScale(0.1, 0.22),
			position = UDim2.fromScale(0.975, 0.06),
			anchor = Vector2.new(1, 0),
			aspect = 1,
			tint = ROLE.textDim,
			zindex = Z + 3,
		})
		local body = Ui.body(frame, {
			name = "Body",
			size = UDim2.fromScale(0.8, 0.62),
			position = UDim2.fromScale(0.17, 0.33),
			textColor = ROLE.textDim,
			alignY = Enum.TextYAlignment.Top,
			maxText = 22,
			minText = 14,
			zindex = Z + 3,
		})
		body.RichText = true -- glossary words in gold (markup escapes everything else)
		local book = Ui.icon(frame, Ui.ICONS.book, {
			name = "Glossary",
			size = UDim2.fromScale(0.09, 0.2),
			position = UDim2.fromScale(0.975, 0.95),
			anchor = Vector2.new(1, 1),
			aspect = 1,
			tint = ROLE.star,
			zindex = Z + 3,
			visible = false,
		})
		local hit = Instance.new("TextButton")
		hit.Name = "GlossaryTap"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.BorderSizePixel = 0
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = Z + 4
		hit.AutoButtonColor = false
		hit.Visible = false
		hit.Parent = frame
		local tile: Tile = {
			frame = frame,
			stroke = frame:FindFirstChildOfClass("UIStroke"),
			icon = icon,
			badge = badge,
			title = titleLabel,
			body = body,
			bodyLimit = body:FindFirstChildOfClass("UITextSizeConstraint"),
			book = book,
			hit = hit,
			term = nil,
		}
		hit.Activated:Connect(function()
			local termId = tile.term
			if termId and glossary and type(glossary.open) == "function" then
				pcall(glossary.open, termId)
			end
		end)
		table.insert(tiles, tile)
	end

	-- Page row ---------------------------------------------------------------------------------------
	local page = 1
	local render: () -> () = function() end
	local function turn(delta: number)
		page += delta
		render()
	end
	local prevButton = Ui.button(panel, {
		name = "Previous",
		size = UDim2.fromScale(0.09, 0.085),
		position = UDim2.fromScale(0.33, PAGE_Y),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.accent,
		icon = Ui.ICONS.play,
		aspect = 1.4,
		zindex = Z + 2,
	}, function()
		turn(-1)
	end)
	local prevIcon = prevButton:FindFirstChild("Icon")
	if prevIcon and prevIcon:IsA("ImageLabel") then
		prevIcon.Rotation = 180 -- the play triangle points left
	end
	local nextButton = Ui.button(panel, {
		name = "Next",
		size = UDim2.fromScale(0.09, 0.085),
		position = UDim2.fromScale(0.67, PAGE_Y),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.accent,
		icon = Ui.ICONS.play,
		aspect = 1.4,
		zindex = Z + 2,
	}, function()
		turn(1)
	end)
	local pageLabel = Ui.label(panel, {
		name = "Page",
		size = UDim2.fromScale(0.22, 0.06),
		position = UDim2.fromScale(0.5, PAGE_Y),
		anchor = Vector2.new(0.5, 0.5),
		textColor = ROLE.text,
		maxText = 24,
		minText = 13,
		zindex = Z + 2,
	})
	Ui.oneLine(pageLabel)
	local glossaryHint = Ui.body(panel, {
		name = "GlossaryHint",
		size = UDim2.fromScale(0.25, 0.07),
		position = UDim2.fromScale(0.025, PAGE_Y),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.star,
		maxText = 16,
		minText = 12,
		zindex = Z + 2,
	})

	local function perPage(): number
		return COLUMNS * (if Ui.scale() < SMALL_SCALE then ROWS_SMALL else ROWS)
	end

	-- Slot positions for `rows` rows on the page.
	local function layoutTiles(rows: number)
		local tileW = (TILES_WIDTH - TILE_GAP * (COLUMNS - 1)) / COLUMNS
		local tileH = (TILES_BOTTOM - TILES_TOP - TILE_GAP * (rows - 1)) / rows
		for index, tile in tiles do
			local column = (index - 1) % COLUMNS
			local row = math.floor((index - 1) / COLUMNS)
			tile.frame.Size = UDim2.fromScale(tileW, tileH)
			tile.frame.Position = UDim2.fromScale(TILES_LEFT + column * (tileW + TILE_GAP), TILES_TOP + row * (tileH + TILE_GAP))
		end
	end

	render = function()
		title.Text = Store.t("ui.ach_title")
		hint.Text = Store.t("ui.ach_hint")
		glossaryHint.Text = Store.t("ui.glossary.tap")
		local unlockedCount = #Achievements.unlockedList(record)
		count.Text = Store.t("ui.ach_count", { n = unlockedCount, total = #Achievements.LIST })
		-- A guest in a friend's world: that base is the owner's, so it never counts for this player.
		local guest = Players.LocalPlayer:GetAttribute("SBO_Guest") == true
		local baseLevel = if guest then 0 else Store.buildLevel("habitat")

		local size = perPage()
		layoutTiles(math.floor(size / COLUMNS))
		local first, last, current = Reading.pageRange(#Achievements.LIST, size, page)
		page = current
		local pages = Reading.pageCount(#Achievements.LIST, size)
		pageLabel.Text = Store.t("ui.ach_page", { n = current, total = pages })
		local morePages = pages > 1
		pageLabel.Visible = morePages
		Ui.setButtonLook(prevButton, current > 1, ROLE.accent)
		Ui.setButtonLook(nextButton, current < pages, ROLE.accent)
		prevButton.Visible = morePages
		nextButton.Visible = morePages
		local minText = readableMin()

		for slot, tile in tiles do
			local index = first + slot - 1
			local def = if slot <= size and index <= last then Achievements.LIST[index] else nil
			tile.frame.Visible = def ~= nil
			tile.term = nil
			tile.book.Visible = false
			tile.hit.Visible = false
			if def == nil then
				continue
			end
			local unlocked = record.unlocked[def.id] == true
			tile.icon.Image = Ui.iconImage(def.icon)
			tile.title.Text = Store.t(Achievements.titleKey(def.id))
			tile.title.TextColor3 = if unlocked then ROLE.star else ROLE.textDim
			tile.icon.ImageColor3 = if unlocked then ROLE.star else ROLE.stroke
			tile.frame.BackgroundColor3 = if unlocked then PALETTE.nightLine else ROLE.panelRaised
			if tile.stroke then
				tile.stroke.Color = if unlocked then ROLE.star else ROLE.background
			end
			Ui.setIcon(tile.badge, if unlocked then Ui.ICONS.check else Ui.ICONS.lock, if unlocked then ROLE.good else ROLE.textDim)
			local text: string
			if unlocked then
				text = Store.t(Achievements.factKey(def.id), Achievements.factParams(MissionData, def) :: any)
				tile.body.TextColor3 = ROLE.text
			else
				text = Store.t(Achievements.hintKey(def.id), Achievements.hintParams(MissionData, def) :: any)
				local have, need = Achievements.progress(MissionData, def, record, baseLevel)
				if need > 0 then
					text ..= ` ({have}/{need})`
				end
				tile.body.TextColor3 = ROLE.textDim
			end
			local rich, term = markup(text)
			tile.body.Text = rich
			if tile.bodyLimit then
				tile.bodyLimit.MinTextSize = minText
			end
			tile.term = term
			tile.book.Visible = term ~= nil
			tile.hit.Visible = term ~= nil
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
		page = 1
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
