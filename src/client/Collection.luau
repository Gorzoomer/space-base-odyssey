--!strict
-- Space Base Odyssey - hidden collectibles on the client:
--   * Collection screen (from Mission Select): four slots (silhouette + lock until found; when found:
--     icon, name, myth line, science line, reward line) and a fifth Observatory slot.
--   * Find card: on the Collected remote, a celebratory card with a magenta glow showing the myth vs
--     the science and the reward; if that find completes the set, a second card announces the
--     observatory. Magenta = secrets and rewards (Theme "Lunar Sunrise").
-- The server's C.A.R.L. line for a find ("carl.secret_found" / "carl.all_secrets") arrives through
-- the message remote; the observatory card repeats "carl.all_secrets" as its body text.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef

local ROLE = Ui.ROLE
local GLOW_SPEED = 3
local POP_SECONDS = 0.4

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

local function iconFor(id: string): string
	return Ui.iconImage(Store.COLLECTIBLE_ICONS[id])
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
	-- Collection screen (above every screen and the C.A.R.L. bubble; the language button stays on top).
	-- Layout: title y 0.03-0.11, progress y 0.115-0.165, 2x2 slots x 0.03-0.71 y 0.19-0.825,
	-- observatory slot x 0.73-0.97 y 0.19-0.825, Close y 0.85-0.97.
	---------------------------------------------------------------------------------------------
	local screen = Ui.modal(root, "Collection", 56)
	screen.BackgroundTransparency = 0.04

	local title = Ui.iconText(screen, {
		name = "Title",
		size = UDim2.fromScale(0.5, 0.08),
		position = UDim2.fromScale(0.5, 0.03),
		anchor = Vector2.new(0.5, 0),
		icon = Ui.ICONS.gift,
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
		size = UDim2.fromScale(0.5, 0.05),
		position = UDim2.fromScale(0.5, 0.115),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.textDim,
		maxText = 26,
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
		local button = Ui.button(screen, {
			name = `Slot_{id}`,
			size = UDim2.fromScale(0.335, 0.31),
			position = UDim2.fromScale(0.03 + column * 0.345, 0.19 + rowIndex * 0.325),
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
		local lock = Ui.icon(badge, Ui.ICONS.lock, {
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
		local myth = makeLine(button, "Myth", Ui.ICONS.close, ROLE.warning, 58)
		myth.frame.Size = UDim2.fromScale(0.7, 0.22)
		myth.frame.Position = UDim2.fromScale(0.28, 0.26)
		local science = makeLine(button, "Science", Ui.ICONS.check, ROLE.good, 58)
		science.frame.Size = UDim2.fromScale(0.94, 0.3)
		science.frame.Position = UDim2.fromScale(0.03, 0.5)
		science.icon.Size = UDim2.fromScale(0.06, 0.4)
		science.text.Size = UDim2.fromScale(0.92, 1)
		science.text.Position = UDim2.fromScale(0.075, 0)
		local reward = makeLine(button, "Reward", Ui.ICONS.gift, ROLE.reward, 58)
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
	local observatory = Ui.panel(screen, {
		name = "ObservatorySlot",
		size = UDim2.fromScale(0.24, 0.635),
		position = UDim2.fromScale(0.73, 0.19),
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
		icon = Ui.ICONS.telescope,
		zindex = 58,
	})
	local obsLock = Ui.icon(obsBadge, Ui.ICONS.lock, {
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
		local pip = Ui.icon(observatory, Ui.ICONS.star, {
			name = `Pip{index}`,
			size = UDim2.fromScale(0.16, 0.07),
			position = UDim2.fromScale(0.14 + (index - 1) * 0.18, 0.88),
			tint = ROLE.textDim,
			zindex = 58,
		})
		table.insert(pips, pip)
	end

	local closeButton = Ui.button(screen, {
		name = "Close",
		size = UDim2.fromScale(0.28, 0.12),
		position = UDim2.fromScale(0.5, 0.85),
		anchor = Vector2.new(0.5, 0),
		icon = Ui.ICONS.close,
		maxText = 40,
		zindex = 57,
	}, function()
		screen.Visible = false
	end)

	local function render()
		title.label.Text = Store.t("ui.collection_title")
		local found = Store.collectibleCount()
		local total = #Store.COLLECTIBLES
		progressLabel.Text = Store.t("ui.secrets_found", { n = found, total = total })
		Ui.setButton(closeButton, Store.t("ui.close"))
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
		local all = found >= total
		observatoryStroke.Color = if all then ROLE.reward else ROLE.stroke
		obsBadgeStroke.Color = if all then ROLE.reward else ROLE.stroke
		obsIcon.ImageColor3 = if all then ROLE.reward else ROLE.stroke
		obsLock.Visible = not all
		obsTitle.Text = Store.t("ui.observatory_slot")
		obsText.Text = Store.t(if all then "ui.observatory_open" else "ui.observatory_locked")
		obsText.TextColor3 = if all then ROLE.reward else ROLE.textDim
		for index, pip in pips do
			local lit = index <= found
			Ui.setIcon(pip, if lit then Ui.ICONS.star else Ui.ICONS.starEmpty, if lit then ROLE.reward else ROLE.textDim)
		end
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
		icon = Ui.ICONS.gift,
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
	local cardMyth = makeLine(card, "Myth", Ui.ICONS.close, ROLE.warning, 60)
	cardMyth.frame.Size = UDim2.fromScale(0.88, 0.12)
	cardMyth.frame.Position = UDim2.fromScale(0.06, 0.42)
	cardMyth.icon.Size = UDim2.fromScale(0.06, 0.5)
	cardMyth.text.Size = UDim2.fromScale(0.92, 1)
	cardMyth.text.Position = UDim2.fromScale(0.08, 0)
	local cardScience = makeLine(card, "Science", Ui.ICONS.check, ROLE.good, 60)
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
	Ui.icon(rewardStrip, Ui.ICONS.gift, {
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
			Ui.setIcon(cardIcon, Ui.ICONS.telescope, ROLE.reward)
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
		icon = Ui.ICONS.check,
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
