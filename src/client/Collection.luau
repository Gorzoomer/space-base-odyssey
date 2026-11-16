--!strict
-- Space Base Odyssey - hidden collectibles on the client, and (Stage 11) the Moon Logbook:
--   * Moon Logbook (opened from Mission Select's "Logbook" button and from the supply capsule card):
--     a book with six pages chosen by tabs.
--       Secrets       the four hidden collectibles (silhouette + lock until found; when found: icon,
--                     name, myth line, science line, reward line) and the Observatory slot.
--       Places        the exploration sites (name and real fact once scanned, a hint before).
--       Space rocks   the first fresh craters scanned (MissionData.LOGBOOK.METEOR_PAGE slots).
--       Achievements  the learning achievements (fact once unlocked, the hint before).
--       Facts         cargo facts from opened supply capsules and the fun facts C.A.R.L. shared.
--       Stripes       suit stripes (Wear / Wearing / how to get them), the logbook milestones with a
--                     Claim button (Action ClaimLogbook; the server counts the entries itself) and the
--                     capsule calendar button.
--     The logbook data comes from the server (Types.DailyState.logbook through DailyCapsule.luau); the
--     Secrets page reads the Store as before. Entries count only what the server saw (secrets, sites,
--     craters, achievements); facts are kept but never count.
--   * Find card: on the Collected remote, a celebratory card with a magenta glow showing the myth vs
--     the science and the reward; if that find completes the set, a second card announces the
--     observatory. Magenta = secrets and rewards (Theme "Lunar Sunrise").
-- The server's C.A.R.L. line for a find ("carl.secret_found" / "carl.all_secrets") arrives through
-- the message remote; the observatory card repeats "carl.all_secrets" as its body text.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local Daily = require(Shared:WaitForChild("Daily"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent:WaitForChild("Audio")) -- Stage 11 daily: logbook reward sound

type TextRef = Store.TextRef
type DailyState = Types.DailyState

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE
local ICONS = Ui.Icons
local GLOW_SPEED = 3
local POP_SECONDS = 0.4
local ENTRY_HEIGHT = 96 -- logbook entry card height (reference units; the root's UIScale scales it)

-- Stage 11 daily: the capsule state lives in DailyCapsule (pcall: the logbook still opens without it).
local dailyModule: any = nil
do
	local ok, result = pcall(function(): any
		return (require :: any)(script.Parent:WaitForChild("DailyCapsule", 5))
	end)
	if ok and type(result) == "table" then
		dailyModule = result
	else
		warn(`[SpaceBaseOdyssey] DailyCapsule unavailable for the logbook: {result}`)
	end
end

local function dailyState(): DailyState?
	local module = dailyModule
	if module and type(module.getState) == "function" then
		return module.getState()
	end
	return nil
end

local Collection = {}

export type Collected = { id: string, isNew: boolean, allFound: boolean }

export type CollectionView = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	render: () -> (),
	showCollected: (payload: Collected) -> (),
}

export type Deps = {
	showMessage: (ref: TextRef) -> (), -- reserved for local hints
}

type TabId = "secrets" | "sites" | "rocks" | "achievements" | "facts" | "stripes"
type TabDef = { id: TabId, key: string, icon: string }
local TABS: { TabDef } = {
	{ id = "secrets", key = "ui.logbook.tab_secrets", icon = ICONS.gift },
	{ id = "sites", key = "ui.logbook.tab_sites", icon = ICONS.explore },
	{ id = "rocks", key = "ui.logbook.tab_rocks", icon = ICONS.meteor },
	{ id = "achievements", key = "ui.logbook.tab_achievements", icon = ICONS.trophy },
	{ id = "facts", key = "ui.logbook.tab_facts", icon = ICONS.book },
	{ id = "stripes", key = "ui.logbook.tab_stripes", icon = ICONS.wardrobe },
}

local function iconFor(id: string): string
	return Ui.iconImage(Store.COLLECTIBLE_ICONS[id])
end

local function paletteColour(name: string): Color3
	return (PALETTE :: any)[name] or ROLE.accent
end

-- One line with a small icon on the left and wrapped body text (myth, science or reward).
type Line = { frame: Frame, icon: ImageLabel, text: TextLabel }
local function makeLine(parent: Instance, name: string, image: string, tint: Color3, zindex: number): Line
	local frame = Ui.frame(parent, { name = name, zindex = zindex })
	local icon = Ui.icon(frame, image, {
		name = "Icon",
		size = UDim2.fromScale(0.08, 0.5),
		position = UDim2.fromScale(0, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = tint,
		zindex = zindex,
	})
	local text = Ui.body(frame, {
		name = "Text",
		size = UDim2.fromScale(0.9, 1),
		position = UDim2.fromScale(0.1, 0),
		maxText = 20,
		minText = 9,
		zindex = zindex,
	})
	return { frame = frame, icon = icon, text = text }
end

-- Round icon badge (night disc, magenta ring) with an icon inside.
local function makeBadge(parent: Instance, props: Ui.Props): (Frame, ImageLabel, UIStroke)
	local badgeProps: Ui.Props = table.clone(props)
	badgeProps.color = ROLE.background
	badgeProps.corner = 0.5
	badgeProps.aspect = 1
	badgeProps.stroke = 3
	badgeProps.strokeColor = ROLE.reward
	local badge = Ui.frame(parent, badgeProps)
	local icon = Ui.icon(badge, props.icon or "", {
		name = "Icon",
		size = UDim2.fromScale(0.64, 0.64),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.reward,
		zindex = (props.zindex or 1) + 1,
	})
	return badge, icon, badge:FindFirstChildOfClass("UIStroke") :: UIStroke
end

function Collection.new(root: Frame, _deps: Deps): CollectionView
	---------------------------------------------------------------------------------------------
	-- Moon Logbook screen (above every screen and the C.A.R.L. bubble; the language button stays on
	-- top). Layout: title y 0.02-0.1, progress y 0.1-0.145, tabs y 0.155-0.225, page y 0.235-0.83,
	-- Close y 0.85-0.97.
	---------------------------------------------------------------------------------------------
	local screen = Ui.modal(root, "Collection", 56)
	screen.BackgroundTransparency = 0.04

	local title = Ui.iconText(screen, {
		name = "Title",
		size = UDim2.fromScale(0.5, 0.08),
		position = UDim2.fromScale(0.5, 0.02),
		anchor = Vector2.new(0.5, 0),
		icon = ICONS.book,
		tint = ROLE.reward,
		textColor = ROLE.reward,
		maxText = 44,
		zindex = 57,
	})
	title.icon.Size = UDim2.fromScale(0.1, 0.86)
	title.label.Size = UDim2.fromScale(0.86, 0.9)
	title.label.Position = UDim2.fromScale(0.13, 0.5)
	local progressLabel = Ui.label(screen, {
		name = "Progress",
		size = UDim2.fromScale(0.6, 0.045),
		position = UDim2.fromScale(0.5, 0.1),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.textDim,
		maxText = 26,
		zindex = 57,
	})

	local PAGE_TOP = 0.235
	local PAGE_HEIGHT = 0.595
	local currentTab: TabId = "secrets"
	local renderLogbook: () -> () -- set below

	type Tab = { def: TabDef, button: TextButton, pip: ImageLabel }
	local tabs: { Tab } = {}
	for index, def in TABS do
		local button = Ui.button(screen, {
			name = `Tab_{def.id}`,
			size = UDim2.fromScale(0.152, 0.07),
			position = UDim2.fromScale(0.03 + (index - 1) * 0.158, 0.155),
			color = ROLE.secondaryButton,
			icon = def.icon,
			maxText = 22,
			minText = 8,
			zindex = 57,
		}, function()
			currentTab = def.id
			renderLogbook()
		end)
		local pip = Ui.icon(button, ICONS.star, {
			name = "Ready",
			size = UDim2.fromScale(0.22, 0.5),
			position = UDim2.fromScale(1.02, -0.2),
			anchor = Vector2.new(1, 0),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			tint = ROLE.reward,
			zindex = 59,
			visible = false,
		})
		table.insert(tabs, { def = def, button = button, pip = pip })
	end

	---------------------------------------------------------------------------------------------
	-- Page: Secrets (the four collectibles and the observatory, as before Stage 11)
	---------------------------------------------------------------------------------------------
	local secretsPage = Ui.frame(screen, {
		name = "SecretsPage",
		size = UDim2.fromScale(1, PAGE_HEIGHT),
		position = UDim2.fromScale(0, PAGE_TOP),
		zindex = 57,
	})

	type Slot = {
		id: string,
		button: TextButton,
		stroke: UIStroke,
		badge: Frame,
		badgeStroke: UIStroke,
		icon: ImageLabel,
		lock: ImageLabel,
		name: TextLabel,
		myth: Line,
		science: Line,
		reward: Line,
	}
	local slots: { Slot } = {}
	local openDetail: (id: string) -> () -- set below, with the find card

	for index, id in Store.COLLECTIBLES do
		local column = (index - 1) % 2
		local rowIndex = math.floor((index - 1) / 2)
		local button = Ui.button(secretsPage, {
			name = `Slot_{id}`,
			size = UDim2.fromScale(0.335, 0.48),
			position = UDim2.fromScale(0.03 + column * 0.345, rowIndex * 0.52),
			color = ROLE.panelRaised,
			corner = 0.08,
			zindex = 57,
		}, function()
			if Store.hasCollectible(id) then
				openDetail(id)
			end
		end)
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		local badge, icon, badgeStroke = makeBadge(button, {
			name = "Badge",
			size = UDim2.fromScale(0.22, 0.4),
			position = UDim2.fromScale(0.03, 0.08),
			icon = iconFor(id),
			zindex = 58,
		})
		local lock = Ui.icon(badge, ICONS.lock, {
			name = "Lock",
			size = UDim2.fromScale(0.42, 0.42),
			position = UDim2.fromScale(0.95, 0.95),
			anchor = Vector2.new(1, 1),
			color = ROLE.background,
			corner = 0.5,
			tint = ROLE.textDim,
			zindex = 60,
		})
		local name = Ui.label(button, {
			name = "Name",
			size = UDim2.fromScale(0.7, 0.18),
			position = UDim2.fromScale(0.28, 0.06),
			alignX = Enum.TextXAlignment.Left,
			textColor = ROLE.reward,
			maxText = 28,
			zindex = 58,
		})
		local myth = makeLine(button, "Myth", ICONS.close, ROLE.warning, 58)
		myth.frame.Size = UDim2.fromScale(0.7, 0.22)
		myth.frame.Position = UDim2.fromScale(0.28, 0.26)
		local science = makeLine(button, "Science", ICONS.check, ROLE.good, 58)
		science.frame.Size = UDim2.fromScale(0.94, 0.3)
		science.frame.Position = UDim2.fromScale(0.03, 0.5)
		science.icon.Size = UDim2.fromScale(0.06, 0.4)
		science.text.Size = UDim2.fromScale(0.92, 1)
		science.text.Position = UDim2.fromScale(0.075, 0)
		local reward = makeLine(button, "Reward", ICONS.gift, ROLE.reward, 58)
		reward.frame.Size = UDim2.fromScale(0.94, 0.15)
		reward.frame.Position = UDim2.fromScale(0.03, 0.82)
		reward.icon.Size = UDim2.fromScale(0.06, 0.8)
		reward.text.Size = UDim2.fromScale(0.92, 1)
		reward.text.Position = UDim2.fromScale(0.075, 0)
		reward.text.TextColor3 = ROLE.reward
		table.insert(slots, {
			id = id,
			button = button,
			stroke = stroke,
			badge = badge,
			badgeStroke = badgeStroke,
			icon = icon,
			lock = lock,
			name = name,
			myth = myth,
			science = science,
			reward = reward,
		})
	end

	-- Fifth slot: the observatory (opens when all four are found).
	local observatory = Ui.panel(secretsPage, {
		name = "ObservatorySlot",
		size = UDim2.fromScale(0.24, 1),
		position = UDim2.fromScale(0.73, 0),
		color = ROLE.panelRaised,
		corner = 0.08,
		zindex = 57,
	})
	local observatoryStroke = observatory:FindFirstChildOfClass("UIStroke") :: UIStroke
	local obsBadge, obsIcon, obsBadgeStroke = makeBadge(observatory, {
		name = "Badge",
		size = UDim2.fromScale(0.5, 0.3),
		position = UDim2.fromScale(0.5, 0.06),
		anchor = Vector2.new(0.5, 0),
		icon = ICONS.telescope,
		zindex = 58,
	})
	local obsLock = Ui.icon(obsBadge, ICONS.lock, {
		name = "Lock",
		size = UDim2.fromScale(0.4, 0.4),
		position = UDim2.fromScale(0.95, 0.95),
		anchor = Vector2.new(1, 1),
		color = ROLE.background,
		corner = 0.5,
		tint = ROLE.textDim,
		zindex = 60,
	})
	local obsTitle = Ui.label(observatory, {
		name = "Title",
		size = UDim2.fromScale(0.9, 0.12),
		position = UDim2.fromScale(0.5, 0.4),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.reward,
		maxText = 28,
		zindex = 58,
	})
	local obsText = Ui.body(observatory, {
		name = "Text",
		size = UDim2.fromScale(0.86, 0.3),
		position = UDim2.fromScale(0.5, 0.54),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		maxText = 22,
		zindex = 58,
	})
	-- Four little pips: one per secret found.
	local pips: { ImageLabel } = {}
	for index = 1, #Store.COLLECTIBLES do
		local pip = Ui.icon(observatory, ICONS.star, {
			name = `Pip{index}`,
			size = UDim2.fromScale(0.16, 0.07),
			position = UDim2.fromScale(0.14 + (index - 1) * 0.18, 0.88),
			tint = ROLE.textDim,
			zindex = 58,
		})
		table.insert(pips, pip)
	end

	local function renderSecrets()
		for _, slot in slots do
			local owned = Store.hasCollectible(slot.id)
			slot.button.AutoButtonColor = owned
			slot.stroke.Color = if owned then ROLE.reward else ROLE.stroke
			slot.badgeStroke.Color = if owned then ROLE.reward else ROLE.stroke
			-- Locked: a dark silhouette of the item with a lock.
			slot.icon.ImageColor3 = if owned then ROLE.reward else ROLE.stroke
			slot.lock.Visible = not owned
			slot.name.Text = if owned then Store.t(`collect.{slot.id}.name`) else Store.t("ui.locked")
			slot.name.TextColor3 = if owned then ROLE.reward else ROLE.textDim
			slot.myth.frame.Visible = owned
			slot.science.frame.Visible = owned
			slot.reward.frame.Visible = owned
			if owned then
				slot.myth.text.Text = Store.t(`card.{slot.id}.myth`)
				slot.myth.text.TextColor3 = ROLE.textDim
				slot.science.text.Text = Store.t(`card.{slot.id}.science`)
				slot.reward.text.Text = Store.t(`card.{slot.id}.reward`)
			end
		end
		local found = Store.collectibleCount()
		local all = found >= #Store.COLLECTIBLES
		observatoryStroke.Color = if all then ROLE.reward else ROLE.stroke
		obsBadgeStroke.Color = if all then ROLE.reward else ROLE.stroke
		obsIcon.ImageColor3 = if all then ROLE.reward else ROLE.stroke
		obsLock.Visible = not all
		obsTitle.Text = Store.t("ui.observatory_slot")
		obsText.Text = Store.t(if all then "ui.observatory_open" else "ui.observatory_locked")
		obsText.TextColor3 = if all then ROLE.reward else ROLE.textDim
		for index, pip in pips do
			local lit = index <= found
			Ui.setIcon(pip, if lit then ICONS.star else ICONS.starEmpty, if lit then ROLE.reward else ROLE.textDim)
		end
	end

	---------------------------------------------------------------------------------------------
	-- Pages: Places, Space rocks, Achievements, Facts (one scrolling grid of entry cards)
	---------------------------------------------------------------------------------------------
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "EntryPage"
	grid.Size = UDim2.fromScale(0.94, PAGE_HEIGHT)
	grid.Position = UDim2.fromScale(0.03, PAGE_TOP)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = ROLE.accent
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.ZIndex = 57
	grid.Visible = false
	grid.Parent = screen
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.485, 0, 0, ENTRY_HEIGHT)
	layout.CellPadding = UDim2.new(0.02, 0, 0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingRight = UDim.new(0, 12)
	gridPadding.Parent = grid
	local emptyLabel = Ui.body(screen, {
		name = "Empty",
		size = UDim2.fromScale(0.8, 0.1),
		position = UDim2.fromScale(0.5, PAGE_TOP + 0.2),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.textDim,
		maxText = 24,
		zindex = 58,
		visible = false,
	})

	type Entry = {
		frame: Frame,
		stroke: UIStroke,
		badgeStroke: UIStroke,
		icon: ImageLabel,
		lock: ImageLabel,
		name: TextLabel,
		text: TextLabel,
	}
	local entries: { Entry } = {}

	local function entryAt(index: number): Entry
		local existing = entries[index]
		if existing then
			return existing
		end
		local frame = Ui.panel(grid, {
			name = `Entry{index}`,
			color = ROLE.panelRaised,
			corner = 0.12,
			stroke = 2,
			zindex = 57,
			order = index,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		local badge, icon, badgeStroke = makeBadge(frame, {
			name = "Badge",
			size = UDim2.fromScale(0.3, 0.74),
			position = UDim2.fromScale(0.025, 0.5),
			anchor = Vector2.new(0, 0.5),
			icon = ICONS.star,
			zindex = 58,
		})
		local lock = Ui.icon(badge, ICONS.lock, {
			name = "Lock",
			size = UDim2.fromScale(0.42, 0.42),
			position = UDim2.fromScale(0.98, 0.98),
			anchor = Vector2.new(1, 1),
			color = ROLE.background,
			corner = 0.5,
			tint = ROLE.textDim,
			zindex = 60,
		})
		local name = Ui.label(frame, {
			name = "Name",
			size = UDim2.fromScale(0.74, 0.32),
			position = UDim2.fromScale(0.24, 0.06),
			alignX = Enum.TextXAlignment.Left,
			textColor = ROLE.reward,
			maxText = 22,
			minText = 9,
			zindex = 58,
		})
		local text = Ui.body(frame, {
			name = "Text",
			size = UDim2.fromScale(0.74, 0.56),
			position = UDim2.fromScale(0.24, 0.4),
			alignY = Enum.TextYAlignment.Top,
			maxText = 16,
			minText = 8,
			zindex = 58,
		})
		local entry: Entry = { frame = frame, stroke = stroke, badgeStroke = badgeStroke, icon = icon, lock = lock, name = name, text = text }
		entries[index] = entry
		return entry
	end

	-- Fills entry `index`: found entries in the reward colour, locked ones dim with a lock and a hint.
	local function setEntry(index: number, image: string, found: boolean, nameText: string, bodyText: string, tint: Color3?)
		local entry = entryAt(index)
		local colour = tint or ROLE.reward
		entry.frame.Visible = true
		entry.stroke.Color = if found then colour else ROLE.stroke
		entry.badgeStroke.Color = if found then colour else ROLE.stroke
		Ui.setIcon(entry.icon, image, if found then colour else ROLE.stroke)
		entry.lock.Visible = not found
		entry.name.Text = nameText
		entry.name.TextColor3 = if found then colour else ROLE.textDim
		entry.text.Text = bodyText
		entry.text.TextColor3 = if found then ROLE.text else ROLE.textDim
	end

	local function hideEntriesFrom(index: number)
		for i = index, #entries do
			entries[i].frame.Visible = false
		end
	end

	local function renderSites(logbook: Types.LogbookState?): number
		local count = 0
		for _, site in (if logbook then logbook.sites else {}) do
			count += 1
			local nameText = Store.t(`poi.{site.id}.name`)
			if site.found then
				setEntry(count, ICONS.explore, true, nameText, Store.t(`poi.{site.id}.fact`), ROLE.accent)
			else
				setEntry(count, ICONS.explore, false, nameText, Store.t("ui.logbook.site_hint"))
			end
		end
		return count
	end

	local function renderRocks(logbook: Types.LogbookState?): number
		local page = if logbook then logbook.meteorPage else MissionData.LOGBOOK.METEOR_PAGE
		local scanned = if logbook then logbook.meteors else 0
		for i = 1, page do
			if i <= scanned then
				setEntry(i, ICONS.meteor, true, Store.t("ui.logbook.rock", { n = i }), Store.t("meteor.fact"), ROLE.warning)
			else
				setEntry(i, ICONS.meteor, false, Store.t("ui.logbook.locked"), Store.t("ui.logbook.rock_hint"))
			end
		end
		return page
	end

	local function renderAchievements(logbook: Types.LogbookState?): number
		local unlocked: { [string]: boolean } = {}
		for _, id in (if logbook then logbook.achievements else {}) do
			unlocked[id] = true
		end
		for index, def in Achievements.LIST do
			local title = Store.t(Achievements.titleKey(def.id))
			if unlocked[def.id] then
				setEntry(index, Ui.iconImage(def.icon), true, title, Store.t(Achievements.factKey(def.id), Achievements.factParams(MissionData, def) :: any), ROLE.star)
			else
				setEntry(index, Ui.iconImage(def.icon), false, title, Store.t(Achievements.hintKey(def.id), Achievements.hintParams(MissionData, def) :: any))
			end
		end
		return #Achievements.LIST
	end

	local function renderFacts(current: DailyState?): number
		local count = 0
		local opened = if current then current.opened else 0
		for i = 1, math.min(opened, #Daily.CARGO_FACTS) do
			count += 1
			setEntry(count, ICONS.crate, true, Store.t("ui.logbook.cargo", { n = i }), Store.t(Daily.CARGO_FACTS[i]), ROLE.warning)
		end
		for _, key in (if current then current.logbook.facts else {}) do
			count += 1
			setEntry(count, ICONS.robot, true, Store.t("ui.funfacts_toggle"), Store.t(key), ROLE.accent)
		end
		return count
	end

	---------------------------------------------------------------------------------------------
	-- Page: Stripes (suit stripes, milestones, the capsule calendar)
	---------------------------------------------------------------------------------------------
	local stripesPage = Ui.frame(screen, {
		name = "StripesPage",
		size = UDim2.fromScale(0.94, PAGE_HEIGHT),
		position = UDim2.fromScale(0.03, PAGE_TOP),
		zindex = 57,
		visible = false,
	})

	type StripeTile = { id: string, button: TextButton, stroke: UIStroke, name: TextLabel, status: TextLabel, bars: { Frame } }
	local stripeTiles: { StripeTile } = {}
	for index, def in Daily.STRIPES do
		local column = (index - 1) % 3
		local rowIndex = math.floor((index - 1) / 3)
		local id = def.id
		local button = Ui.button(stripesPage, {
			name = `Stripe_{id}`,
			size = UDim2.fromScale(0.19, 0.47),
			position = UDim2.fromScale(column * 0.2, rowIndex * 0.51),
			color = ROLE.panelRaised,
			corner = 0.1,
			zindex = 57,
		}, function()
			local current = dailyState()
			if current and table.find(current.stripes, id) and current.wear ~= id then
				local action: any = { type = "WearStripes", id = id }
				Store.send(action)
			end
		end)
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		local bars: { Frame } = {}
		for band, colourName in def.colors do
			local bar = Ui.frame(button, {
				name = `Band{band}`,
				size = UDim2.fromScale(0.7, 0.1),
				position = UDim2.fromScale(0.5, 0.1 + (band - 1) * 0.15),
				anchor = Vector2.new(0.5, 0),
				color = paletteColour(colourName),
				corner = 0.5,
				zindex = 58,
			})
			table.insert(bars, bar)
		end
		local name = Ui.label(button, {
			name = "Name",
			size = UDim2.fromScale(0.92, 0.26),
			position = UDim2.fromScale(0.5, 0.42),
			anchor = Vector2.new(0.5, 0),
			maxText = 18,
			minText = 8,
			zindex = 58,
		})
		local status = Ui.body(button, {
			name = "Status",
			size = UDim2.fromScale(0.92, 0.26),
			position = UDim2.fromScale(0.5, 0.7),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			maxText = 15,
			minText = 8,
			zindex = 58,
		})
		table.insert(stripeTiles, { id = id, button = button, stroke = stroke, name = name, status = status, bars = bars })
	end

	type MilestoneRow = { id: string, frame: Frame, label: TextLabel, count: TextLabel, button: TextButton }
	local milestoneRows: { MilestoneRow } = {}
	for index, milestone in Daily.MILESTONES do
		local id = milestone.id
		local frame = Ui.panel(stripesPage, {
			name = `Milestone_{id}`,
			size = UDim2.fromScale(0.38, 0.18),
			position = UDim2.fromScale(0.62, (index - 1) * 0.2),
			color = ROLE.panelRaised,
			corner = 0.2,
			stroke = 2,
			zindex = 57,
		})
		local stripe = Daily.stripe(milestone.stripe)
		for band, colourName in (if stripe then stripe.colors else {}) do
			Ui.frame(frame, {
				name = `Band{band}`,
				size = UDim2.fromScale(0.05, 0.6),
				position = UDim2.fromScale(0.03 + (band - 1) * 0.065, 0.2),
				color = paletteColour(colourName),
				corner = 0.5,
				zindex = 58,
			})
		end
		local label = Ui.label(frame, {
			name = "Label",
			size = UDim2.fromScale(0.5, 0.5),
			position = UDim2.fromScale(0.17, 0.05),
			alignX = Enum.TextXAlignment.Left,
			maxText = 18,
			minText = 8,
			zindex = 58,
		})
		local count = Ui.body(frame, {
			name = "Count",
			size = UDim2.fromScale(0.5, 0.4),
			position = UDim2.fromScale(0.17, 0.55),
			textColor = ROLE.textDim,
			maxText = 14,
			minText = 8,
			zindex = 58,
		})
		local button = Ui.button(frame, {
			name = "Claim",
			size = UDim2.fromScale(0.3, 0.72),
			position = UDim2.fromScale(0.97, 0.5),
			anchor = Vector2.new(1, 0.5),
			icon = ICONS.gift,
			maxText = 18,
			minText = 8,
			zindex = 58,
		}, function()
			local current = dailyState()
			if current == nil then
				return
			end
			for _, entry in current.logbook.milestones do
				if entry.id == id and entry.ready then
					local action: any = { type = "ClaimLogbook", id = id }
					Store.send(action)
				end
			end
		end)
		table.insert(milestoneRows, { id = id, frame = frame, label = label, count = count, button = button })
	end
	local calendarButton = Ui.button(stripesPage, {
		name = "Calendar",
		size = UDim2.fromScale(0.38, 0.17),
		position = UDim2.fromScale(0.62, 0.62),
		color = ROLE.warning,
		icon = ICONS.crate,
		maxText = 22,
		zindex = 57,
	}, function()
		local module = dailyModule
		if module and type(module.openCard) == "function" then
			module.openCard()
		end
	end)
	local noStripesButton = Ui.button(stripesPage, {
		name = "NoStripes",
		size = UDim2.fromScale(0.38, 0.17),
		position = UDim2.fromScale(0.62, 0.82),
		color = ROLE.secondaryButton,
		icon = ICONS.close,
		maxText = 22,
		zindex = 57,
	}, function()
		local current = dailyState()
		if current and current.wear ~= "none" then
			local action: any = { type = "WearStripes", id = "none" }
			Store.send(action)
		end
	end)

	local function renderStripes(current: DailyState?)
		local owned: { [string]: boolean } = {}
		for _, id in (if current then current.stripes else {}) do
			owned[id] = true
		end
		local wear = if current then current.wear else "none"
		for _, tile in stripeTiles do
			local def = Daily.stripe(tile.id) :: Daily.Stripe
			local has = owned[tile.id] == true
			local worn = wear == tile.id
			tile.name.Text = Store.t(Daily.stripeNameKey(tile.id))
			tile.name.TextColor3 = if has then ROLE.text else ROLE.textDim
			tile.button.AutoButtonColor = has and not worn
			tile.stroke.Color = if worn then ROLE.good elseif has then ROLE.reward else ROLE.stroke
			tile.stroke.Thickness = if worn then 4 else 3
			for band, bar in tile.bars do
				bar.BackgroundColor3 = if has then paletteColour(def.colors[band]) else ROLE.stroke
			end
			if worn then
				tile.status.Text = Store.t("ui.logbook.wearing")
				tile.status.TextColor3 = ROLE.good
			elseif has then
				tile.status.Text = Store.t("ui.logbook.wear")
				tile.status.TextColor3 = ROLE.accent
			else
				tile.status.Text = Store.t(if def.source == "daily" then "ui.logbook.how_daily" else "ui.logbook.how_logbook")
				tile.status.TextColor3 = ROLE.textDim
			end
		end
		local entriesFilled = if current then current.logbook.entries else 0
		for _, row in milestoneRows do
			local info: Types.LogbookMilestone? = nil
			for _, entry in (if current then current.logbook.milestones else {}) do
				if entry.id == row.id then
					info = entry
				end
			end
			local target = if info then info.entries else Daily.milestoneTarget(MissionData, row.id)
			row.label.Text = Store.t("ui.logbook.milestone", { n = target })
			row.count.Text = `{math.min(entriesFilled, target)}/{target}`
			if info and info.claimed then
				Ui.setButton(row.button, Store.t("ui.logbook.claimed"), ICONS.check)
				Ui.setButtonLook(row.button, false, ROLE.primaryButton)
			else
				Ui.setButton(row.button, Store.t("ui.logbook.claim"), ICONS.gift)
				Ui.setButtonLook(row.button, info ~= nil and info.ready, ROLE.reward)
			end
		end
		Ui.setButton(calendarButton, Store.t("ui.logbook.calendar"))
		Ui.setButton(noStripesButton, Store.t("ui.logbook.no_stripes"))
		Ui.setButtonLook(noStripesButton, wear ~= "none", ROLE.secondaryButton)
	end

	local closeButton = Ui.button(screen, {
		name = "Close",
		size = UDim2.fromScale(0.28, 0.12),
		position = UDim2.fromScale(0.5, 0.85),
		anchor = Vector2.new(0.5, 0),
		icon = ICONS.close,
		maxText = 40,
		zindex = 57,
	}, function()
		screen.Visible = false
	end)

	renderLogbook = function()
		local current = dailyState()
		local logbook = if current then current.logbook else nil
		title.label.Text = Store.t("ui.logbook.title")
		Ui.setButton(closeButton, Store.t("ui.close"))
		local anyReady = false
		for _, entry in (if logbook then logbook.milestones else {}) do
			if entry.ready then
				anyReady = true
			end
		end
		for _, tab in tabs do
			local active = tab.def.id == currentTab
			Ui.setButton(tab.button, Store.t(tab.def.key))
			Ui.setButtonColor(tab.button, if active then ROLE.accent else ROLE.secondaryButton)
			tab.pip.Visible = tab.def.id == "stripes" and anyReady
		end
		secretsPage.Visible = currentTab == "secrets"
		stripesPage.Visible = currentTab == "stripes"
		local gridTab = currentTab == "sites" or currentTab == "rocks" or currentTab == "achievements" or currentTab == "facts"
		grid.Visible = gridTab
		emptyLabel.Visible = false

		-- Progress line: what this page counts.
		if currentTab == "secrets" or logbook == nil then
			progressLabel.Text = Store.t("ui.secrets_found", { n = Store.collectibleCount(), total = #Store.COLLECTIBLES })
		elseif currentTab == "facts" then
			progressLabel.Text = Store.t("ui.logbook.facts_count", { n = #logbook.facts })
		elseif currentTab == "stripes" then
			progressLabel.Text = Store.t("ui.logbook.capsules", { n = if current then current.opened else 0 })
		else
			progressLabel.Text = Store.t("ui.logbook.entries", { n = logbook.entries, total = logbook.total })
		end

		if currentTab == "secrets" then
			renderSecrets()
		elseif currentTab == "stripes" then
			renderStripes(current)
		elseif gridTab then
			local shown = 0
			if currentTab == "sites" then
				shown = renderSites(logbook)
			elseif currentTab == "rocks" then
				shown = renderRocks(logbook)
			elseif currentTab == "achievements" then
				shown = renderAchievements(logbook)
			else
				shown = renderFacts(current)
				if shown == 0 then
					emptyLabel.Text = Store.t("ui.logbook.facts_none")
					emptyLabel.Visible = true
				end
			end
			hideEntriesFrom(shown + 1)
		end
	end

	local function render()
		renderLogbook()
	end

	-- New logbook data from the server: redraw while open; a claimed milestone gets its sound.
	if dailyModule and type(dailyModule.onState) == "function" then
		dailyModule.onState(function(current: DailyState)
			if current.logbook and current.logbook.milestone then
				Audio.play("achievement_unlock")
			end
			if screen.Visible then
				renderLogbook()
			end
		end)
	end

	---------------------------------------------------------------------------------------------
	-- Find card (above the Collection screen; the language button at 60 stays reachable).
	---------------------------------------------------------------------------------------------
	local cardScreen = Ui.modal(root, "FindCard", 58)
	-- Soft magenta glow behind the card.
	local glow = Ui.frame(cardScreen, {
		name = "Glow",
		size = UDim2.fromScale(0.8, 0.95),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.reward,
		corner = 0.5,
		zindex = 58,
	})
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Parent = glow

	local card = Ui.panel(cardScreen, {
		name = "Card",
		size = UDim2.fromScale(0.58, 0.76),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panelRaised,
		corner = 0.07,
		stroke = 5,
		strokeColor = ROLE.reward,
		zindex = 59,
	})
	local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local newPill = Ui.label(card, {
		name = "NewFind",
		size = UDim2.fromScale(0.36, 0.07),
		position = UDim2.fromScale(0.5, -0.035),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.reward,
		textColor = ROLE.primaryButtonText,
		corner = 0.5,
		stroke = 3,
		strokeColor = ROLE.background,
		maxText = 26,
		zindex = 61,
	})
	local cardBadge, cardIcon = makeBadge(card, {
		name = "Badge",
		size = UDim2.fromScale(0.24, 0.24),
		position = UDim2.fromScale(0.5, 0.06),
		anchor = Vector2.new(0.5, 0),
		icon = ICONS.gift,
		zindex = 60,
	})
	local badgeScale = Instance.new("UIScale")
	badgeScale.Parent = cardBadge
	local cardTitle = Ui.label(card, {
		name = "Title",
		size = UDim2.fromScale(0.9, 0.09),
		position = UDim2.fromScale(0.5, 0.31),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.reward,
		maxText = 40,
		zindex = 60,
	})
	local cardMyth = makeLine(card, "Myth", ICONS.close, ROLE.warning, 60)
	cardMyth.frame.Size = UDim2.fromScale(0.88, 0.12)
	cardMyth.frame.Position = UDim2.fromScale(0.06, 0.42)
	cardMyth.icon.Size = UDim2.fromScale(0.06, 0.5)
	cardMyth.text.Size = UDim2.fromScale(0.92, 1)
	cardMyth.text.Position = UDim2.fromScale(0.08, 0)
	local cardScience = makeLine(card, "Science", ICONS.check, ROLE.good, 60)
	cardScience.frame.Size = UDim2.fromScale(0.88, 0.2)
	cardScience.frame.Position = UDim2.fromScale(0.06, 0.55)
	cardScience.icon.Size = UDim2.fromScale(0.06, 0.34)
	cardScience.text.Size = UDim2.fromScale(0.92, 1)
	cardScience.text.Position = UDim2.fromScale(0.08, 0)
	-- Reward strip: label pill + gift icon + reward text.
	local rewardStrip = Ui.frame(card, {
		name = "Reward",
		size = UDim2.fromScale(0.88, 0.09),
		position = UDim2.fromScale(0.06, 0.765),
		color = ROLE.background,
		corner = 0.5,
		stroke = 2,
		strokeColor = ROLE.reward,
		zindex = 60,
	})
	local rewardLabel = Ui.label(rewardStrip, {
		name = "Label",
		size = UDim2.fromScale(0.24, 0.76),
		position = UDim2.fromScale(0.015, 0.5),
		anchor = Vector2.new(0, 0.5),
		color = ROLE.reward,
		textColor = ROLE.primaryButtonText,
		corner = 0.5,
		maxText = 20,
		zindex = 61,
	})
	Ui.icon(rewardStrip, ICONS.gift, {
		name = "Icon",
		size = UDim2.fromScale(0.06, 0.7),
		position = UDim2.fromScale(0.27, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.reward,
		zindex = 61,
	})
	local rewardText = Ui.body(rewardStrip, {
		name = "Text",
		size = UDim2.fromScale(0.64, 0.84),
		position = UDim2.fromScale(0.345, 0.5),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.reward,
		maxText = 20,
		minText = 9,
		zindex = 61,
	})
	-- Observatory card body (replaces myth / science / reward).
	local cardBody = Ui.body(card, {
		name = "Body",
		size = UDim2.fromScale(0.84, 0.36),
		position = UDim2.fromScale(0.5, 0.43),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		maxText = 26,
		zindex = 60,
		visible = false,
	})

	type CardItem = { kind: "item", id: string, isNew: boolean } | { kind: "observatory" }
	local okButton: TextButton? = nil
	local queue: { CardItem } = {}
	local current: CardItem? = nil
	local glowConnection: RBXScriptConnection? = nil

	local function stopGlow()
		if glowConnection then
			glowConnection:Disconnect()
			glowConnection = nil
		end
	end

	local function renderCard()
		local item = current
		if not item then
			return
		end
		if okButton then
			Ui.setButton(okButton, Store.t("ui.continue"))
		end
		if item.kind == "item" then
			local id = item.id
			newPill.Visible = item.isNew
			newPill.Text = Store.t("ui.new_find")
			Ui.setIcon(cardIcon, iconFor(id), ROLE.reward)
			cardTitle.Text = Store.t(`collect.{id}.name`)
			cardMyth.text.Text = Store.t(`card.{id}.myth`)
			cardMyth.text.TextColor3 = ROLE.textDim
			cardScience.text.Text = Store.t(`card.{id}.science`)
			rewardLabel.Text = Store.t("ui.reward_label")
			rewardText.Text = Store.t(`card.{id}.reward`)
			cardMyth.frame.Visible = true
			cardScience.frame.Visible = true
			rewardStrip.Visible = true
			cardBody.Visible = false
		else
			newPill.Visible = true
			newPill.Text = Store.t("ui.new_find")
			Ui.setIcon(cardIcon, ICONS.telescope, ROLE.reward)
			cardTitle.Text = Store.t("ui.observatory_open")
			cardBody.Text = Store.t("carl.all_secrets")
			cardMyth.frame.Visible = false
			cardScience.frame.Visible = false
			rewardStrip.Visible = false
			cardBody.Visible = true
		end
	end

	local function showNextCard()
		current = table.remove(queue, 1)
		if not current then
			cardScreen.Visible = false
			stopGlow()
			return
		end
		renderCard()
		cardScreen.Visible = true
		cardScale.Scale = 0.6
		TweenService:Create(cardScale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		if not glowConnection then
			glowConnection = RunService.Heartbeat:Connect(function()
				local wave = (math.sin(os.clock() * GLOW_SPEED) + 1) / 2
				glow.BackgroundTransparency = 0.15 + 0.35 * wave
				cardStroke.Thickness = 4 + 3 * wave
				badgeScale.Scale = 1 + 0.06 * wave
			end)
		end
	end

	okButton = Ui.button(card, {
		name = "Ok",
		size = UDim2.fromScale(0.4, 0.1),
		position = UDim2.fromScale(0.5, 0.875),
		anchor = Vector2.new(0.5, 0),
		icon = ICONS.check,
		maxText = 36,
		zindex = 60,
	}, function()
		showNextCard()
	end)

	local function enqueue(item: CardItem)
		table.insert(queue, item)
		if not current then
			showNextCard()
		end
	end

	openDetail = function(id: string)
		enqueue({ kind = "item", id = id, isNew = false })
	end

	local function showCollected(payload: Collected)
		if type(payload) ~= "table" or type(payload.id) ~= "string" then
			return
		end
		if not table.find(Store.COLLECTIBLES, payload.id) then
			return
		end
		enqueue({ kind = "item", id = payload.id, isNew = payload.isNew == true })
		if payload.allFound == true and payload.isNew == true then
			enqueue({ kind = "observatory" })
		end
		render()
	end

	local function open()
		render()
		screen.Visible = true
	end

	local function close()
		screen.Visible = false
	end

	local function isOpen(): boolean
		return screen.Visible
	end

	local function renderAll()
		render()
		if current then
			renderCard()
		end
	end

	renderAll()
	return { open = open, close = close, isOpen = isOpen, render = renderAll, showCollected = showCollected }
end

return Collection
