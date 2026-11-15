--!strict
-- Space Base Odyssey - exploration card (Stage 7). When the player scans an exploration site or a
-- fresh meteorite crater with the tablet, the server sends an ExploreEvent (Remotes.EXPLORE) and this
-- card shows what was found: the site's name ("poi.<id>.name" / "meteor.name"), a true short fact
-- ("poi.<id>.fact" / "meteor.fact", checked in DATA_SOURCES.md), the reward line the first time
-- (MissionData.BASE.REWARDS.poi_scanned / meteor_scanned) and how many sites this player has scanned.
-- A Continue button closes it; several scans in a row queue up. Like the secret card (FindCard), it is
-- listed in Main.client's MODAL_PANELS so the mouse is free in first person.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type ExploreEvent = Types.ExploreEvent

local ROLE = Ui.ROLE

-- Below the secret card (FindCard, 58-61), above the Lab panel (53) and Sources (55).
local Z = 57
local POP_SECONDS = 0.35
local GLOW_SPEED = 3
local POI_ATTRIBUTE = "PoiId" -- the scan part of each exploration site (WorldSites)

local ExploreCard = {}

export type ExploreCardView = {
	show: (event: ExploreEvent) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	render: () -> (),
}

-- Every exploration site id in the world (parts with the PoiId attribute under Workspace.Base).
local function siteIds(): { string }
	local ids: { string } = {}
	local base = workspace:FindFirstChild("Base")
	if base == nil then
		return ids
	end
	for _, descendant in base:GetDescendants() do
		local id = descendant:GetAttribute(POI_ATTRIBUTE)
		if type(id) == "string" and id ~= "" and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	return ids
end

function ExploreCard.new(root: Frame): ExploreCardView
	local screen = Ui.modal(root, "ExploreCard", Z)
	-- Soft cyan glow behind the card.
	local glow = Ui.frame(screen, {
		name = "Glow",
		size = UDim2.fromScale(0.8, 0.95),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.accent,
		corner = 0.5,
		zindex = Z,
	})
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Parent = glow

	local card = Ui.panel(screen, {
		name = "Card",
		size = UDim2.fromScale(0.58, 0.76),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panelRaised,
		corner = 0.07,
		stroke = 5,
		strokeColor = ROLE.accent,
		aspect = 1.25,
		zindex = Z + 1,
	})
	card.Active = true
	Ui.sheen(card)
	local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local newPill = Ui.label(card, {
		name = "New",
		size = UDim2.fromScale(0.4, 0.07),
		position = UDim2.fromScale(0.5, -0.035),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.accent,
		textColor = ROLE.primaryButtonText,
		corner = 0.5,
		stroke = 3,
		strokeColor = ROLE.background,
		maxText = 26,
		zindex = Z + 4,
	})
	local badge = Ui.frame(card, {
		name = "Badge",
		size = UDim2.fromScale(0.22, 0.22),
		position = UDim2.fromScale(0.5, 0.06),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.background,
		corner = 0.5,
		stroke = 4,
		strokeColor = ROLE.accent,
		aspect = 1,
		zindex = Z + 2,
	})
	local badgeScale = Instance.new("UIScale")
	badgeScale.Parent = badge
	local badgeIcon = Ui.icon(badge, Ui.Icons.explore, {
		name = "Icon",
		size = UDim2.fromScale(0.62, 0.62),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.accent,
		zindex = Z + 3,
	})
	local kindLabel = Ui.body(card, {
		name = "Kind",
		size = UDim2.fromScale(0.8, 0.05),
		position = UDim2.fromScale(0.5, 0.29),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.textDim,
		maxText = 18,
		minText = 8,
		zindex = Z + 2,
	})
	local title = Ui.label(card, {
		name = "Title",
		size = UDim2.fromScale(0.9, 0.09),
		position = UDim2.fromScale(0.5, 0.345),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.accent,
		maxText = 40,
		zindex = Z + 2,
	})
	-- The fact, in a darker box with the telescope icon.
	local factBox = Ui.frame(card, {
		name = "Fact",
		size = UDim2.fromScale(0.88, 0.23),
		position = UDim2.fromScale(0.06, 0.455),
		color = ROLE.background,
		corner = 0.12,
		stroke = 2,
		strokeColor = ROLE.stroke,
		zindex = Z + 2,
	})
	Ui.icon(factBox, Ui.ICONS.telescope, {
		name = "Icon",
		size = UDim2.fromScale(0.08, 0.4),
		position = UDim2.fromScale(0.025, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.good,
		zindex = Z + 3,
	})
	local factText = Ui.body(factBox, {
		name = "Text",
		size = UDim2.fromScale(0.85, 0.86),
		position = UDim2.fromScale(0.12, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 22,
		minText = 9,
		zindex = Z + 3,
	})
	-- Reward strip (first scan only) or "scanned before".
	local rewardStrip = Ui.frame(card, {
		name = "Reward",
		size = UDim2.fromScale(0.88, 0.085),
		position = UDim2.fromScale(0.06, 0.7),
		color = ROLE.background,
		corner = 0.5,
		stroke = 2,
		strokeColor = ROLE.star,
		zindex = Z + 2,
	})
	local rewardIcon = Ui.icon(rewardStrip, Ui.Icons.coin, {
		name = "Icon",
		size = UDim2.fromScale(0.07, 0.7),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.star,
		zindex = Z + 3,
	})
	local rewardText = Ui.label(rewardStrip, {
		name = "Text",
		size = UDim2.fromScale(0.86, 0.8),
		position = UDim2.fromScale(0.11, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 22,
		minText = 9,
		zindex = Z + 3,
	})
	local countText = Ui.body(card, {
		name = "Count",
		size = UDim2.fromScale(0.88, 0.05),
		position = UDim2.fromScale(0.5, 0.8),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.textDim,
		maxText = 16,
		minText = 8,
		zindex = Z + 2,
	})

	local queue: { ExploreEvent } = {}
	local current: ExploreEvent? = nil
	local glowConnection: RBXScriptConnection? = nil
	local okButton: TextButton? = nil

	local function stopGlow()
		if glowConnection then
			glowConnection:Disconnect()
			glowConnection = nil
		end
	end

	local function renderCard()
		local event = current
		if event == nil then
			return
		end
		if okButton then
			Ui.setButton(okButton, Store.t("ui.continue"))
		end
		local isMeteor = event.kind == "meteor"
		local color = if isMeteor then ROLE.warning else ROLE.accent
		cardStroke.Color = color
		glow.BackgroundColor3 = color
		newPill.BackgroundColor3 = color
		local badgeStroke = badge:FindFirstChildOfClass("UIStroke")
		if badgeStroke then
			badgeStroke.Color = color
		end
		Ui.setIcon(badgeIcon, if isMeteor then Ui.Icons.meteor else Ui.Icons.explore, color)
		title.TextColor3 = color
		newPill.Visible = event.isNew
		newPill.Text = Store.t(if isMeteor then "explore.new_meteor" else "explore.new_site")
		kindLabel.Text = Store.t(if isMeteor then "explore.kind_meteor" else "explore.kind_site")
		if isMeteor then
			title.Text = Store.t("meteor.name")
			factText.Text = Store.t("meteor.fact")
		else
			title.Text = Store.t(`poi.{event.id}.name`)
			factText.Text = Store.t(`poi.{event.id}.fact`)
		end
		if event.isNew then
			local reward = if isMeteor then MissionData.BASE.REWARDS.meteor_scanned else MissionData.BASE.REWARDS.poi_scanned
			rewardText.Text = Store.t("explore.reward", { credits = reward.credits, xp = reward.xp })
			rewardText.TextColor3 = ROLE.star
			Ui.setIcon(rewardIcon, Ui.Icons.coin, ROLE.star)
			local stripStroke = rewardStrip:FindFirstChildOfClass("UIStroke")
			if stripStroke then
				stripStroke.Color = ROLE.star
			end
		else
			rewardText.Text = Store.t("explore.seen")
			rewardText.TextColor3 = ROLE.textDim
			Ui.setIcon(rewardIcon, Ui.ICONS.check, ROLE.good)
			local stripStroke = rewardStrip:FindFirstChildOfClass("UIStroke")
			if stripStroke then
				stripStroke.Color = ROLE.stroke
			end
		end
		-- Sites scanned so far (the meteorite craters come and go, so they are not counted).
		local ids = siteIds()
		local found = 0
		for _, id in ids do
			if Store.isScanned(id) or (not isMeteor and event.isNew and id == event.id) then
				found += 1
			end
		end
		countText.Visible = #ids > 0
		countText.Text = Store.t("explore.count", { n = found, max = #ids })
	end

	local function showNext()
		current = table.remove(queue, 1)
		if current == nil then
			screen.Visible = false
			stopGlow()
			return
		end
		renderCard()
		screen.Visible = true
		cardScale.Scale = 0.6
		TweenService:Create(cardScale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		if glowConnection == nil then
			glowConnection = RunService.Heartbeat:Connect(function()
				local wave = (math.sin(os.clock() * GLOW_SPEED) + 1) / 2
				glow.BackgroundTransparency = 0.2 + 0.35 * wave
				cardStroke.Thickness = 4 + 3 * wave
				badgeScale.Scale = 1 + 0.06 * wave
			end)
		end
	end

	okButton = Ui.button(card, {
		name = "Ok",
		size = UDim2.fromScale(0.4, 0.1),
		position = UDim2.fromScale(0.5, 0.87),
		anchor = Vector2.new(0.5, 0),
		icon = Ui.ICONS.check,
		maxText = 36,
		zindex = Z + 2,
	}, function()
		showNext()
	end)

	local function show(event: ExploreEvent)
		local raw: any = event
		if type(raw) ~= "table" or (raw.kind ~= "poi" and raw.kind ~= "meteor") then
			return
		end
		table.insert(queue, {
			kind = raw.kind,
			id = if type(raw.id) == "string" then raw.id else "",
			isNew = raw.isNew == true,
		})
		if current == nil then
			showNext()
		end
	end

	local function close()
		table.clear(queue)
		current = nil
		screen.Visible = false
		stopGlow()
	end

	local function isOpen(): boolean
		return screen.Visible
	end

	local function render()
		if current then
			renderCard()
		end
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if screen.Visible and (kind == "language" or kind == "base") then
			renderCard()
		end
	end)

	return { show = show, close = close, isOpen = isOpen, render = render }
end

return ExploreCard
