--!strict
-- Space Base Odyssey - Mission Select (the Briefing phase): game title, a "Training" row (t1..t4), a
-- "Story" row (c1..c3), the "Free play" card, the "Explore the base" button, the Collection button
-- and the "Real NASA data" button.
-- Cards come from snapshot.missions (server decides what is unlocked). Tapping an unlocked card
-- opens its intro card (title + intro text + Start) which sends Action StartMission{missionId}.
-- Stage 6: the screen can be closed ("Explore the base", base mode) and reopened with the Missions
-- top button; Main.client decides when it is open. A card locked by a missing build
-- (MissionCard.missingBuild) says which build it needs.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef
type MissionCard = Store.MissionCard

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE
local PRESS_COOLDOWN = 1
local PULSE_SPEED = 4

-- Layout (fractions of the screen):
--   y 0.03-0.12 title, y 0.12-0.17 subtitle (x 0.2-0.8; language button at top right)
--   y 0.20-0.25 "Training" header, y 0.26-0.47 four training cards (x 0.06-0.94)
--   y 0.50-0.55 "Story" and "Free play" headers, y 0.56-0.77 three story cards + free play card
--   y 0.81-0.94 Explore the base 0.30-0.485 | Collection 0.50-0.685 | Real NASA data 0.70-0.96
--               (C.A.R.L. bubble: x 0.02-0.28)
local ROW_X = 0.06
local CARD_WIDTH = 0.205
local CARD_GAP = 0.02
local TRAINING_Y = 0.26
local STORY_Y = 0.56
local CARD_HEIGHT = 0.21

local MissionSelect = {}

export type MissionSelectView = {
	setVisible: (visible: boolean) -> (),
	render: () -> (),
}

export type Deps = {
	showMessage: (ref: TextRef) -> (),
	addSourcesButton: (parent: Instance, props: Ui.Props) -> TextButton,
	openCollection: () -> (),
	-- Stage 6: "Explore the base" pressed (Main.client closes the screen). nil = no close button.
	onClose: (() -> ())?,
}

type CardView = {
	id: string,
	button: TextButton,
	stroke: UIStroke,
	icon: ImageLabel,
	title: TextLabel,
	reason: TextLabel,
	number: TextLabel,
	status: Frame,
	statusIcon: ImageLabel,
	shake: UIScale,
}

local function kindColor(kind: string): Color3
	return (Ui.KIND_COLORS :: any)[kind] or ROLE.accent
end

-- The build a locked card waits for (Stage 6 MissionCard.missingBuild), or nil.
local function missingBuild(card: MissionCard): string?
	local value: any = (card :: any).missingBuild
	return if type(value) == "string" and value ~= "" then value else nil
end

local function lockRef(card: MissionCard): TextRef
	local build = missingBuild(card)
	if build then
		return { key = "ui.needs_build", params = { name = Store.t(`build.{build}.name`) } }
	end
	return { key = "ui.locked" }
end

local function kindLabelKey(kind: string): string
	if kind == "Tutorial" then
		return "ui.training"
	elseif kind == "Story" then
		return "ui.story"
	end
	return "ui.free_play"
end

function MissionSelect.new(root: Frame, deps: Deps): MissionSelectView
	local screen = Ui.frame(root, {
		name = "MissionSelect",
		color = ROLE.background,
		transparency = 0.06,
		zindex = 10,
		visible = false,
	})
	screen.ClipsDescendants = true

	-- Decoration: a lunar sunrise glow on the horizon, the grey Moon and a small Earth (all Theme colours).
	local glow = Ui.frame(screen, {
		name = "SunriseGlow",
		size = UDim2.fromScale(1, 0.5),
		position = UDim2.fromScale(0, 0.5),
		color = PALETTE.orange,
		zindex = 10,
	})
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Rotation = 90
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.7, 0.82),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	glowGradient.Parent = glow
	Ui.frame(screen, {
		name = "MoonHorizon",
		size = UDim2.fromScale(1.6, 0.6),
		position = UDim2.fromScale(0.5, 1.18),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.creamDim:Lerp(PALETTE.night, 0.6),
		corner = 0.5,
		zindex = 10,
	})
	local earth = Ui.frame(screen, {
		name = "Earth",
		size = UDim2.fromScale(0.07, 0.07),
		position = UDim2.fromScale(0.9, 0.2),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.cyan:Lerp(PALETTE.night, 0.35),
		corner = 0.5,
		aspect = 1,
		zindex = 10,
	})
	Ui.frame(earth, {
		name = "Land",
		size = UDim2.fromScale(0.45, 0.35),
		position = UDim2.fromScale(0.38, 0.4),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.lime,
		corner = 0.5,
		zindex = 11,
	})
	Ui.frame(earth, {
		name = "Cloud",
		size = UDim2.fromScale(0.42, 0.16),
		position = UDim2.fromScale(0.62, 0.7),
		anchor = Vector2.new(0.5, 0.5),
		color = PALETTE.cream,
		corner = 0.5,
		zindex = 11,
	})

	local title = Ui.label(screen, {
		name = "Title",
		size = UDim2.fromScale(0.6, 0.1),
		position = UDim2.fromScale(0.5, 0.025),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.warning,
		maxText = 72,
		outline = true,
		zindex = 12,
	})
	local subtitle = Ui.label(screen, {
		name = "Subtitle",
		size = UDim2.fromScale(0.6, 0.05),
		position = UDim2.fromScale(0.5, 0.125),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.accent,
		maxText = 30,
		zindex = 12,
	})

	local function rowHeader(name: string, x: number, y: number, width: number, image: string, color: Color3): Ui.IconText
		local header = Ui.iconText(screen, {
			name = name,
			size = UDim2.fromScale(width, 0.05),
			position = UDim2.fromScale(x, y),
			icon = image,
			tint = color,
			textColor = color,
			maxText = 28,
			zindex = 12,
		})
		header.icon.Size = UDim2.fromScale(0.07, 0.86)
		header.icon.Position = UDim2.fromScale(0, 0.5)
		header.label.Size = UDim2.fromScale(0.9, 0.9)
		header.label.Position = UDim2.fromScale(0.09, 0.5)
		return header
	end
	local trainingHeader = rowHeader("TrainingHeader", ROW_X, 0.2, 0.4, Ui.ICONS.book, Ui.KIND_COLORS.Tutorial)
	local storyHeader = rowHeader("StoryHeader", ROW_X, 0.5, 0.4, Ui.ICONS.rocket, Ui.KIND_COLORS.Story)
	local freeHeader = rowHeader(
		"FreeHeader",
		ROW_X + (CARD_WIDTH + CARD_GAP) * 3,
		0.5,
		CARD_WIDTH,
		Ui.ICONS.planet,
		Ui.KIND_COLORS.Free
	)
	freeHeader.icon.Size = UDim2.fromScale(0.13, 0.86)
	freeHeader.label.Size = UDim2.fromScale(0.84, 0.9)
	freeHeader.label.Position = UDim2.fromScale(0.16, 0.5)

	local lastPress = 0
	local function pressAllowed(): boolean
		if Store.phase() ~= "Briefing" or os.clock() - lastPress < PRESS_COOLDOWN then
			return false
		end
		lastPress = os.clock()
		return true
	end

	-- Fallback for a server without mission cards: one big Start button (the classic mission).
	local legacyStart = Ui.button(screen, {
		name = "LegacyStart",
		size = UDim2.fromScale(0.42, 0.17),
		position = UDim2.fromScale(0.5, 0.45),
		anchor = Vector2.new(0.5, 0),
		icon = Ui.ICONS.rocket,
		maxText = 52,
		zindex = 12,
		visible = false,
	}, function()
		if pressAllowed() then
			Store.startMission(nil)
		end
	end)

	-- Intro card (modal inside this screen).
	local intro = Ui.frame(screen, {
		name = "Intro",
		color = ROLE.background,
		transparency = 0.3,
		zindex = 20,
		visible = false,
	})
	intro.Active = true
	local introPanel = Ui.panel(intro, {
		name = "Panel",
		size = UDim2.fromScale(0.56, 0.62),
		position = UDim2.fromScale(0.5, 0.47),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panelRaised,
		corner = 0.08,
		stroke = 4,
		zindex = 21,
	})
	local introStroke = introPanel:FindFirstChildOfClass("UIStroke") :: UIStroke
	local introBadge = Ui.frame(introPanel, {
		name = "IconBadge",
		size = UDim2.fromScale(0.2, 0.24),
		position = UDim2.fromScale(0.5, 0.05),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.background,
		corner = 0.5,
		aspect = 1,
		zindex = 22,
	})
	local introIcon = Ui.icon(introBadge, Ui.ICONS.rocket, {
		name = "Icon",
		size = UDim2.fromScale(0.66, 0.66),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		zindex = 23,
	})
	local introKind = Ui.label(introPanel, {
		name = "Kind",
		size = UDim2.fromScale(0.3, 0.06),
		position = UDim2.fromScale(0.5, 0.31),
		anchor = Vector2.new(0.5, 0),
		corner = 0.5,
		color = ROLE.accent,
		textColor = ROLE.primaryButtonText,
		maxText = 20,
		zindex = 22,
	})
	local introTitle = Ui.label(introPanel, {
		name = "Title",
		size = UDim2.fromScale(0.9, 0.11),
		position = UDim2.fromScale(0.5, 0.38),
		anchor = Vector2.new(0.5, 0),
		maxText = 44,
		zindex = 22,
	})
	local introText = Ui.body(introPanel, {
		name = "IntroText",
		size = UDim2.fromScale(0.86, 0.24),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.text,
		maxText = 26,
		zindex = 22,
	})
	local selectedId: string? = nil
	local introStart = Ui.button(introPanel, {
		name = "Start",
		size = UDim2.fromScale(0.46, 0.15),
		position = UDim2.fromScale(0.04, 0.8),
		icon = Ui.ICONS.play,
		maxText = 40,
		zindex = 22,
	}, function()
		local id = selectedId
		if id and pressAllowed() then
			intro.Visible = false
			Store.startMission(id)
		end
	end)
	local introClose = Ui.button(introPanel, {
		name = "Close",
		size = UDim2.fromScale(0.42, 0.15),
		position = UDim2.fromScale(0.54, 0.8),
		color = ROLE.secondaryButton,
		icon = Ui.ICONS.close,
		maxText = 36,
		zindex = 22,
	}, function()
		intro.Visible = false
		selectedId = nil
	end)

	local cards: { CardView } = {}
	local cardsKey = ""

	local function findCard(id: string): MissionCard?
		for _, card in Store.missionCards() do
			if card.id == id then
				return card
			end
		end
		return nil
	end

	local function renderIntro()
		local id = selectedId
		local card = if id then findCard(id) else nil
		if not id or not card then
			intro.Visible = false
			return
		end
		local color = kindColor(card.kind)
		introStroke.Color = color
		Ui.setIcon(introIcon, Ui.iconImage(card.icon), color)
		introKind.Text = Store.t(kindLabelKey(card.kind))
		introKind.BackgroundColor3 = color
		introTitle.Text = Store.t(card.titleKey)
		introText.Text = Store.t(`mission.{id}.intro`)
		Ui.setButton(introStart, Store.t("ui.start"))
		Ui.setButton(introClose, Store.t("ui.close"))
	end

	local function openIntro(id: string)
		selectedId = id
		renderIntro()
		intro.Visible = true
	end

	local function shake(view: CardView)
		view.shake.Scale = 0.92
		TweenService:Create(view.shake, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end

	local function buildCard(card: MissionCard, x: number, y: number, number: number): CardView
		local id = card.id
		local view: CardView
		local button = Ui.button(screen, {
			name = `Mission_{id}`,
			size = UDim2.fromScale(CARD_WIDTH, CARD_HEIGHT),
			position = UDim2.fromScale(x, y),
			color = ROLE.panelRaised,
			corner = 0.14,
			zindex = 12,
		}, function()
			local current = findCard(id)
			if not current or Store.phase() ~= "Briefing" then
				return
			end
			if current.unlocked then
				openIntro(id)
			else
				shake(view)
				deps.showMessage(lockRef(current))
			end
		end)
		button.AutoButtonColor = true
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		local shakeScale = Instance.new("UIScale")
		shakeScale.Parent = button
		local icon = Ui.icon(button, Ui.iconImage(card.icon), {
			name = "MissionIcon",
			size = UDim2.fromScale(0.5, 0.42),
			position = UDim2.fromScale(0.5, 0.1),
			anchor = Vector2.new(0.5, 0),
			zindex = 13,
		})
		local titleLabel = Ui.label(button, {
			name = "MissionTitle",
			size = UDim2.fromScale(0.9, 0.34),
			position = UDim2.fromScale(0.5, 0.58),
			anchor = Vector2.new(0.5, 0),
			maxText = 22,
			zindex = 13,
		})
		-- Locked by a missing build: what to build, under the title.
		local reasonLabel = Ui.label(button, {
			name = "LockReason",
			size = UDim2.fromScale(0.9, 0.2),
			position = UDim2.fromScale(0.5, 0.76),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.warning,
			font = Ui.BODY_FONT,
			maxText = 16,
			minText = 7,
			zindex = 13,
			visible = false,
		})
		local numberLabel = Ui.label(button, {
			name = "Number",
			text = tostring(number),
			size = UDim2.fromScale(0.2, 0.22),
			position = UDim2.fromScale(0.05, 0.06),
			color = ROLE.accent,
			textColor = ROLE.primaryButtonText,
			corner = 0.5,
			aspect = 1,
			maxText = 22,
			zindex = 14,
		})
		local status = Ui.frame(button, {
			name = "Status",
			size = UDim2.fromScale(0.22, 0.24),
			position = UDim2.fromScale(0.95, 0.05),
			anchor = Vector2.new(1, 0),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			zindex = 14,
		})
		local statusIcon = Ui.icon(status, Ui.ICONS.lock, {
			name = "Icon",
			size = UDim2.fromScale(0.66, 0.66),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			zindex = 15,
		})
		view = {
			id = id,
			button = button,
			stroke = stroke,
			icon = icon,
			title = titleLabel,
			reason = reasonLabel,
			number = numberLabel,
			status = status,
			statusIcon = statusIcon,
			shake = shakeScale,
		}
		return view
	end

	local function rebuildCards(list: { MissionCard })
		for _, view in cards do
			view.button:Destroy()
		end
		table.clear(cards)
		local training = 0
		local story = 0
		for _, card in list do
			local view: CardView
			if card.kind == "Tutorial" then
				training += 1
				view = buildCard(card, ROW_X + (CARD_WIDTH + CARD_GAP) * (training - 1), TRAINING_Y, training)
			elseif card.kind == "Story" then
				story += 1
				view = buildCard(card, ROW_X + (CARD_WIDTH + CARD_GAP) * (story - 1), STORY_Y, story)
			else
				view = buildCard(card, ROW_X + (CARD_WIDTH + CARD_GAP) * 3, STORY_Y, 0)
				view.number.Visible = false
			end
			table.insert(cards, view)
		end
	end

	-- The first unlocked, not yet completed mission pulses: "play this next".
	local nextId: string? = nil

	local function renderCards()
		local list = Store.missionCards()
		local ids: { string } = {}
		for _, card in list do
			table.insert(ids, card.id)
		end
		local key = table.concat(ids, ",")
		if key ~= cardsKey then
			cardsKey = key
			rebuildCards(list)
		end
		nextId = nil
		for _, card in list do
			if card.unlocked and not card.completed then
				nextId = card.id
				break
			end
		end
		for index, view in cards do
			local card = list[index]
			if not card then
				continue
			end
			local color = kindColor(card.kind)
			local unlocked = card.unlocked == true
			view.stroke.Color = if unlocked then color else ROLE.stroke
			view.stroke.Thickness = Ui.STROKE
			view.button.BackgroundColor3 = if unlocked then ROLE.panelRaised else ROLE.panel
			view.button.AutoButtonColor = unlocked
			view.icon.ImageColor3 = if unlocked then color else ROLE.textDim
			view.icon.ImageTransparency = if unlocked then 0 else 0.55
			view.title.Text = Store.t(card.titleKey)
			view.title.TextColor3 = if unlocked then ROLE.text else ROLE.textDim
			local build = if unlocked then nil else missingBuild(card)
			view.reason.Visible = build ~= nil
			if build then
				local ref = lockRef(card)
				view.reason.Text = Store.t(ref.key, ref.params)
				view.title.Position = UDim2.fromScale(0.5, 0.54)
				view.title.Size = UDim2.fromScale(0.9, 0.22)
			else
				view.title.Position = UDim2.fromScale(0.5, 0.58)
				view.title.Size = UDim2.fromScale(0.9, 0.34)
			end
			view.number.BackgroundColor3 = if unlocked then color else ROLE.stroke
			view.number.TextColor3 = if unlocked then ROLE.primaryButtonText else ROLE.textDim
			if card.completed then
				view.status.Visible = true
				Ui.setIcon(view.statusIcon, Ui.ICONS.check, ROLE.good)
			elseif not unlocked then
				view.status.Visible = true
				Ui.setIcon(view.statusIcon, Ui.ICONS.lock, ROLE.textDim)
			else
				view.status.Visible = false
			end
		end
		local hasCards = #list > 0
		legacyStart.Visible = not hasCards
		trainingHeader.frame.Visible = hasCards
		storyHeader.frame.Visible = hasCards
		freeHeader.frame.Visible = hasCards
	end

	-- Bottom bar: Explore the base (lime = go), Collection (magenta = secrets and rewards) and the
	-- Real NASA data button.
	local explore = Ui.button(screen, {
		name = "ExploreBase",
		size = UDim2.fromScale(0.185, 0.12),
		position = UDim2.fromScale(0.3, 0.815),
		icon = Ui.ICONS.home,
		maxText = 30,
		zindex = 12,
		visible = deps.onClose ~= nil,
	}, function()
		local onClose = deps.onClose
		if onClose and not intro.Visible then
			onClose()
		end
	end)
	local collection = Ui.button(screen, {
		name = "Collection",
		size = UDim2.fromScale(0.185, 0.12),
		position = UDim2.fromScale(0.5, 0.815),
		color = ROLE.reward,
		icon = Ui.ICONS.gift,
		maxText = 32,
		zindex = 12,
	}, function()
		if Store.phase() == "Briefing" then
			deps.openCollection()
		end
	end)
	local collectionCount = Ui.label(collection, {
		name = "Count",
		size = UDim2.fromScale(0.26, 0.42),
		position = UDim2.fromScale(1.02, -0.18),
		anchor = Vector2.new(1, 0),
		color = ROLE.background,
		textColor = ROLE.reward,
		corner = 0.5,
		stroke = 2,
		strokeColor = ROLE.reward,
		maxText = 22,
		zindex = 14,
	})

	deps.addSourcesButton(screen, {
		size = UDim2.fromScale(0.26, 0.12),
		position = UDim2.fromScale(0.7, 0.815),
		zindex = 12,
	})

	local pulseConnection: RBXScriptConnection? = nil
	local function pulse()
		local wave = (math.sin(os.clock() * PULSE_SPEED) + 1) / 2
		for _, view in cards do
			if view.id == nextId then
				view.stroke.Thickness = Ui.STROKE + 3 * wave
			end
		end
	end

	local function render()
		title.Text = Store.t("ui.title")
		subtitle.Text = Store.t("ui.missions_title")
		trainingHeader.label.Text = Store.t("ui.training")
		storyHeader.label.Text = Store.t("ui.story")
		freeHeader.label.Text = Store.t("ui.free_play")
		Ui.setButton(legacyStart, Store.t("ui.start_mission"))
		Ui.setButton(collection, Store.t("ui.collection_button"))
		Ui.setButton(explore, Store.t("ui.explore_base"))
		collectionCount.Text = `{Store.collectibleCount()}/{#Store.COLLECTIBLES}`
		renderCards()
		if intro.Visible then
			renderIntro()
		end
	end

	local function setVisible(visible: boolean)
		screen.Visible = visible
		if not visible then
			intro.Visible = false
			selectedId = nil
		end
		if visible and not pulseConnection then
			pulseConnection = RunService.Heartbeat:Connect(pulse)
		elseif not visible and pulseConnection then
			pulseConnection:Disconnect()
			pulseConnection = nil
		end
		if visible then
			render()
		end
	end

	render()
	return { setVisible = setVisible, render = render }
end

return MissionSelect
