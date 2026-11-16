--!strict
-- Space Base Odyssey - Stage 11: the daily supply capsule on the client.
-- The server owns everything that matters (src/server/DailyService.luau: the day, the reward, the
-- save); this module only shows it:
--   * Remotes.DAILY brings Types.DailyState. DailyCapsule.getState / onState share it with the Moon
--     Logbook (Collection.luau).
--   * When a capsule waits (state.ready) and the player stands in the open base (a slot loaded, a
--     character, phase Briefing, no start menu), a small capsule drops from the sky beside the arrival
--     lander's parts depot (state.landing), with a dust ring and a sound, and C.A.R.L. says so. The
--     capsule is local to this player (plain Parts, no assets) and carries a prompt to open the card.
--     "Reduce motion" (Settings) puts it down without the fall.
--   * The card: a 7-day calendar with every reward shown in advance (credits, XP, suit stripes on day
--     7), today's day highlighted, the cargo fact, the forgiving rule ("Missed a day? Your calendar
--     just waits."), and Open capsule (Action ClaimDaily) / the time to the next capsule, Logbook and
--     Close. What the capsule paid comes back as state.claimed / state.paid.
--   * DailyCapsule.noteFunFact(ref) sends HeardFact for a fun fact C.A.R.L. just shared (Main.client
--     wraps the fun fact tip), so the logbook facts page can list it.
-- Colours are Theme roles (Ui.ROLE / Theme.PALETTE), fonts Theme fonts, icons from Icons.luau.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent:WaitForChild("Audio"))

type DailyState = Types.DailyState
type DailyReward = Types.DailyReward
type TextRef = Types.TextRef

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE
local ICONS = Ui.Icons

-- Presentation tuning (not gameplay numbers).
local REMOTE_NAME: string = (Types.Remotes :: any).DAILY or "Daily"
local REMOTE_WAIT_SECONDS = 60
local LAND_DELAY_SECONDS = 4 -- the open base must be calm this long before the capsule drops
local FALL_HEIGHT = 90
local FALL_SECONDS = 3.2
local CARD_AFTER_LANDING_SECONDS = 1.6
local CLAIM_WAIT_SECONDS = 3 -- the Open button waits this long for the server's answer
local REMOVE_AFTER_OPEN_SECONDS = 25
local CHECK_SECONDS = 0.5
local CAPSULE_NAME = "SBO_SupplyCapsule"
local Z = 57 -- above the Moon Logbook (56), below the find card (58) and the language button (60)

local DailyCapsule = {}

export type Deps = {
	showMessage: (ref: TextRef) -> (),
	openLogbook: (() -> ())?,
	panelOpen: (() -> boolean)?, -- true while another full-screen panel is open (no auto card then)
}

local state: DailyState? = nil
local stateAt = 0 -- os.clock() when `state` arrived (nextIn counts from here)
local listeners: { (state: DailyState) -> () } = {}
local openCardFn: (() -> ())? = nil
local started = false

function DailyCapsule.getState(): DailyState?
	return state
end

function DailyCapsule.onState(listener: (state: DailyState) -> ())
	table.insert(listeners, listener)
end

-- Opens the capsule card (the logbook's calendar button). Does nothing before start.
function DailyCapsule.openCard()
	local fn = openCardFn
	if fn then
		fn()
	end
end

-- Main.client calls this for every tip FunFacts shows: fun facts are remembered for the logbook.
function DailyCapsule.noteFunFact(ref: any)
	if type(ref) ~= "table" or type(ref.key) ~= "string" then
		return
	end
	local digits = string.match(ref.key, "^funfact%.(%d+)$")
	local index = if digits then tonumber(digits) else nil
	if index then
		local action: any = { type = "HeardFact", index = index }
		Store.send(action)
	end
end

-- Seconds until the next capsule (counted from when the state arrived).
local function secondsLeft(): number
	local current = state
	if current == nil or type(current.nextIn) ~= "number" then
		return 0
	end
	return math.max(0, current.nextIn - (os.clock() - stateAt))
end

local function reduceMotion(): boolean
	local fn = (Store :: any).reduceMotion
	if type(fn) == "function" then
		local ok, value = pcall(fn)
		return ok and value == true
	end
	return false
end

local function menuOpen(): boolean
	local fn = (Store :: any).isMenuOpen
	if type(fn) == "function" then
		local ok, value = pcall(fn)
		if ok and value == true then
			return true
		end
	end
	return false
end

local function rewardIcon(reward: DailyReward): string
	if reward.kind == "credits" then
		return ICONS.coin
	elseif reward.kind == "xp" then
		return ICONS.xp
	end
	return ICONS.wardrobe
end

local function rewardTint(reward: DailyReward): Color3
	if reward.kind == "credits" then
		return ROLE.star
	elseif reward.kind == "xp" then
		return ROLE.accent
	end
	return ROLE.reward
end

local function rewardText(reward: DailyReward): string
	if reward.kind == "credits" then
		return Store.t("ui.daily.credits", { n = reward.amount })
	elseif reward.kind == "xp" then
		return Store.t("ui.daily.xp", { n = reward.amount })
	end
	return Store.t("ui.daily.stripes")
end

----------------------------------------------------------------------------------------------------
-- The capsule in the world (local to this player)

type Capsule = {
	model: Model,
	body: BasePart,
	lid: BasePart,
	flame: BasePart,
	prompt: ProximityPrompt,
	ground: Vector3,
	opened: boolean, -- the lid is open (today's capsule was claimed)
}

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Parent = model
	return p
end

-- Ground under `at` (ignores characters and the capsule itself).
local function groundAt(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position else at
end

-- Offsets of each piece from the capsule's foot point (the model is moved by these).
type Piece = { part: BasePart, offset: CFrame }

local function buildCapsule(ground: Vector3): (Capsule, { Piece })
	local model = Instance.new("Model")
	model.Name = CAPSULE_NAME
	local pieces: { Piece } = {}
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's round side is its X axis
	local function add(p: BasePart, offset: CFrame)
		table.insert(pieces, { part = p, offset = offset })
	end
	local body = part(model, "Body", Vector3.new(3.6, 3, 3), PALETTE.cream, Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Cylinder
	add(body, CFrame.new(0, 2.3, 0) * upright)
	local band = part(model, "Band", Vector3.new(0.5, 3.12, 3.12), PALETTE.orange)
	band.Shape = Enum.PartType.Cylinder
	add(band, CFrame.new(0, 2.6, 0) * upright)
	local lid = part(model, "Lid", Vector3.new(0.45, 3.2, 3.2), PALETTE.orange)
	lid.Shape = Enum.PartType.Cylinder
	add(lid, CFrame.new(0, 4.3, 0) * upright)
	local beacon = part(model, "Beacon", Vector3.new(0.6, 0.6, 0.6), PALETTE.cyan, Enum.Material.Neon)
	beacon.Shape = Enum.PartType.Ball
	add(beacon, CFrame.new(0, 4.8, 0))
	local light = Instance.new("PointLight")
	light.Color = PALETTE.cyan
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = beacon
	for i = 0, 2 do
		local angle = i * 2 * math.pi / 3
		local leg = part(model, "Leg", Vector3.new(0.3, 1.4, 0.3), PALETTE.nightLine, Enum.Material.Metal)
		add(leg, CFrame.new(math.cos(angle) * 1.5, 0.6, math.sin(angle) * 1.5) * CFrame.Angles(math.sin(angle) * 0.35, 0, -math.cos(angle) * 0.35))
	end
	local flame = part(model, "Flame", Vector3.new(1.4, 2.2, 1.4), PALETTE.orange, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	flame.Transparency = 0.25
	flame.CastShadow = false
	add(flame, CFrame.new(0, -0.4, 0))
	model.PrimaryPart = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DailyCapsulePrompt"
	prompt:SetAttribute("TextKey", "prompt.daily_capsule") -- Prompts.luau localizes it
	prompt.ActionText = Store.t("prompt.daily_capsule")
	prompt.ObjectText = Store.t("ui.daily.title")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body

	for _, piece in pieces do
		piece.part.CFrame = CFrame.new(ground) * piece.offset
	end
	model.Parent = workspace
	return { model = model, body = body, lid = lid, flame = flame, prompt = prompt, ground = ground, opened = false }, pieces
end

local function moveTo(pieces: { Piece }, foot: Vector3)
	local base = CFrame.new(foot)
	for _, piece in pieces do
		piece.part.CFrame = base * piece.offset
	end
end

-- A flat dust ring that grows and fades where the capsule touches down (no particles, no assets).
local function dustRing(ground: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "SBO_CapsuleDust"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = PALETTE.creamDim
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = workspace
	local tween = TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 16, 16),
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
	tween:Play()
end

----------------------------------------------------------------------------------------------------
-- Start

function DailyCapsule.start(root: Frame, deps: Deps)
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local capsule: Capsule? = nil
	local landing = false
	local landedDay = -1 -- the `opened` count of the capsule already landed (one landing per capsule)
	local claimPendingUntil = 0

	------------------------------------------------------------------------------------------------
	-- The card
	local screen = Ui.modal(root, "DailyCard", Z)
	local card = Ui.panel(screen, {
		name = "Card",
		size = UDim2.fromScale(0.74, 0.86),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.05,
		stroke = 4,
		strokeColor = ROLE.warning,
		zindex = Z + 1,
	})
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local title = Ui.iconText(card, {
		name = "Title",
		size = UDim2.fromScale(0.6, 0.085),
		position = UDim2.fromScale(0.5, 0.03),
		anchor = Vector2.new(0.5, 0),
		icon = ICONS.crate,
		tint = ROLE.warning,
		textColor = ROLE.warning,
		maxText = 40,
		zindex = Z + 2,
	})
	title.icon.Size = UDim2.fromScale(0.1, 0.86)
	title.label.Size = UDim2.fromScale(0.86, 0.9)
	title.label.Position = UDim2.fromScale(0.13, 0.5)
	local note = Ui.body(card, {
		name = "Note",
		size = UDim2.fromScale(0.9, 0.045),
		position = UDim2.fromScale(0.5, 0.12),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.textDim,
		maxText = 18,
		minText = 9,
		zindex = Z + 2,
	})
	local weekLabel = Ui.label(card, {
		name = "Week",
		size = UDim2.fromScale(0.4, 0.05),
		position = UDim2.fromScale(0.5, 0.175),
		anchor = Vector2.new(0.5, 0),
		textColor = ROLE.text,
		maxText = 24,
		zindex = Z + 2,
	})

	type Tile = { frame: Frame, stroke: UIStroke, day: TextLabel, icon: ImageLabel, amount: TextLabel, done: ImageLabel }
	local tiles: { Tile } = {}
	local TILE_COUNT = 7 -- the calendar's length (MissionData.DAILY.CALENDAR); extra tiles stay hidden
	for i = 1, TILE_COUNT do
		local frame = Ui.panel(card, {
			name = `Day{i}`,
			size = UDim2.fromScale(0.122, 0.27),
			position = UDim2.fromScale(0.035 + (i - 1) * 0.1335, 0.24),
			color = ROLE.panelRaised,
			corner = 0.14,
			stroke = 2,
			zindex = Z + 2,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		local dayLabel = Ui.label(frame, {
			name = "Day",
			size = UDim2.fromScale(0.9, 0.2),
			position = UDim2.fromScale(0.5, 0.05),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.textDim,
			maxText = 18,
			zindex = Z + 3,
		})
		local icon = Ui.icon(frame, ICONS.coin, {
			name = "Icon",
			size = UDim2.fromScale(0.62, 0.38),
			position = UDim2.fromScale(0.5, 0.28),
			anchor = Vector2.new(0.5, 0),
			zindex = Z + 3,
		})
		local amount = Ui.label(frame, {
			name = "Amount",
			size = UDim2.fromScale(0.94, 0.26),
			position = UDim2.fromScale(0.5, 0.7),
			anchor = Vector2.new(0.5, 0),
			maxText = 18,
			minText = 8,
			zindex = Z + 3,
		})
		local done = Ui.icon(frame, ICONS.check, {
			name = "Done",
			size = UDim2.fromScale(0.36, 0.22),
			position = UDim2.fromScale(0.98, 0.02),
			anchor = Vector2.new(1, 0),
			tint = ROLE.good,
			zindex = Z + 4,
			visible = false,
		})
		table.insert(tiles, { frame = frame, stroke = stroke, day = dayLabel, icon = icon, amount = amount, done = done })
	end

	local factBox = Ui.panel(card, {
		name = "Fact",
		size = UDim2.fromScale(0.92, 0.17),
		position = UDim2.fromScale(0.5, 0.54),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.panelRaised,
		corner = 0.12,
		stroke = 2,
		strokeColor = ROLE.accent,
		zindex = Z + 2,
	})
	Ui.icon(factBox, ICONS.book, {
		name = "Icon",
		size = UDim2.fromScale(0.08, 0.5),
		position = UDim2.fromScale(0.02, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = Z + 3,
	})
	local factTitle = Ui.label(factBox, {
		name = "Title",
		size = UDim2.fromScale(0.86, 0.34),
		position = UDim2.fromScale(0.12, 0.06),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 20,
		zindex = Z + 3,
	})
	local factText = Ui.body(factBox, {
		name = "Text",
		size = UDim2.fromScale(0.86, 0.52),
		position = UDim2.fromScale(0.12, 0.42),
		maxText = 20,
		minText = 9,
		zindex = Z + 3,
	})
	local forgiving = Ui.body(card, {
		name = "Forgiving",
		size = UDim2.fromScale(0.9, 0.05),
		position = UDim2.fromScale(0.5, 0.725),
		anchor = Vector2.new(0.5, 0),
		alignX = Enum.TextXAlignment.Center,
		textColor = ROLE.good,
		maxText = 18,
		minText = 9,
		zindex = Z + 2,
	})
	local result = Ui.iconText(card, {
		name = "Result",
		size = UDim2.fromScale(0.62, 0.065),
		position = UDim2.fromScale(0.5, 0.785),
		anchor = Vector2.new(0.5, 0),
		color = ROLE.background,
		stroke = 2,
		strokeColor = ROLE.reward,
		icon = ICONS.gift,
		tint = ROLE.reward,
		textColor = ROLE.reward,
		maxText = 26,
		zindex = Z + 2,
	})
	result.frame.Visible = false
	local resultScale = Instance.new("UIScale")
	resultScale.Parent = result.frame

	local openButton: TextButton
	local function claim()
		local current = state
		if current == nil or not current.ready or os.clock() < claimPendingUntil then
			return
		end
		claimPendingUntil = os.clock() + CLAIM_WAIT_SECONDS
		local action: any = { type = "ClaimDaily" }
		Store.send(action)
	end
	openButton = Ui.button(card, {
		name = "Open",
		size = UDim2.fromScale(0.44, 0.1),
		position = UDim2.fromScale(0.04, 0.87),
		icon = ICONS.gift,
		maxText = 30,
		zindex = Z + 2,
	}, claim)
	local logbookButton = Ui.button(card, {
		name = "Logbook",
		size = UDim2.fromScale(0.23, 0.1),
		position = UDim2.fromScale(0.5, 0.87),
		color = ROLE.secondaryButton,
		icon = ICONS.book,
		maxText = 26,
		zindex = Z + 2,
	}, function()
		screen.Visible = false
		local open = deps.openLogbook
		if open then
			open()
		end
	end)
	local closeButton = Ui.button(card, {
		name = "Close",
		size = UDim2.fromScale(0.21, 0.1),
		position = UDim2.fromScale(0.75, 0.87),
		color = ROLE.secondaryButton,
		icon = ICONS.close,
		maxText = 26,
		zindex = Z + 2,
	}, function()
		screen.Visible = false
	end)

	local function render()
		title.label.Text = Store.t("ui.daily.title")
		note.Text = Store.t("ui.daily.note")
		factTitle.Text = Store.t("ui.daily.fact_title")
		forgiving.Text = Store.t("ui.daily.forgiving")
		Ui.setButton(logbookButton, Store.t("ui.daily.logbook"))
		Ui.setButton(closeButton, Store.t("ui.close"))
		local current = state
		if current == nil then
			weekLabel.Text = ""
			factText.Text = ""
			for _, tile in tiles do
				tile.frame.Visible = false
			end
			Ui.setButton(openButton, Store.t("ui.daily.open"))
			Ui.setButtonLook(openButton, false, ROLE.primaryButton)
			return
		end
		weekLabel.Text = Store.t("ui.daily.week", { n = current.week })
		factText.Text = Store.t(current.factKey)
		for i, tile in tiles do
			local day = current.calendar[i]
			tile.frame.Visible = day ~= nil
			if day then
				tile.day.Text = Store.t("ui.daily.day", { n = day.day })
				Ui.setIcon(tile.icon, rewardIcon(day), rewardTint(day))
				tile.amount.Text = rewardText(day)
				local isDone = day.state == "done"
				local isToday = day.state == "today"
				tile.done.Visible = isDone
				tile.frame.BackgroundColor3 = if isToday then ROLE.background else ROLE.panelRaised
				tile.stroke.Color = if isToday then ROLE.warning elseif day.kind == "stripe" then ROLE.reward else ROLE.stroke
				tile.stroke.Thickness = if isToday then 4 else 2
				tile.icon.ImageTransparency = if isDone then 0.5 else 0
				tile.amount.TextColor3 = if isDone then ROLE.textDim else ROLE.text
				tile.day.TextColor3 = if isToday then ROLE.warning else ROLE.textDim
			end
		end
		if current.ready then
			Ui.setButton(openButton, Store.t("ui.daily.open"), ICONS.gift)
			Ui.setButtonLook(openButton, os.clock() >= claimPendingUntil, ROLE.primaryButton)
		else
			local left = secondsLeft()
			local text = if left >= 3600
				then Store.t("ui.daily.next_hours", { n = math.ceil(left / 3600) })
				else Store.t("ui.daily.next_minutes", { n = math.max(1, math.ceil(left / 60)) })
			Ui.setButton(openButton, text, ICONS.clock)
			Ui.setButtonLook(openButton, false, ROLE.primaryButton)
		end
	end

	local function showResult(current: DailyState)
		local reward = current.claimed
		if reward == nil then
			return
		end
		local paid = current.paid
		local text: string
		if reward.kind == "credits" then
			local n = if paid and paid.credits > 0 then paid.credits else reward.amount
			text = Store.t("ui.daily.got_credits", { n = n })
			Audio.play("coin_burst")
		elseif reward.kind == "xp" then
			local n = if paid and paid.xp > 0 then paid.xp else reward.amount
			text = Store.t("ui.daily.got_xp", { n = n })
			Audio.play("xp_gain")
		else
			local name = Store.t("stripe." .. tostring(reward.stripe) .. ".name")
			text = Store.t("ui.daily.got_stripes", { name = name })
			Audio.play("achievement_unlock")
		end
		Audio.sting("sting_level_up")
		result.set(rewardIcon(reward), text, rewardTint(reward))
		result.label.TextColor3 = rewardTint(reward)
		result.frame.Visible = true
		resultScale.Scale = 0.6
		TweenService:Create(resultScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	local function openCard()
		render()
		result.frame.Visible = false
		if not screen.Visible then
			screen.Visible = true
			cardScale.Scale = 0.7
			TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	openCardFn = openCard

	------------------------------------------------------------------------------------------------
	-- The capsule's life: land, wait, open, leave

	local function removeCapsule()
		local current = capsule
		capsule = nil
		if current then
			current.model:Destroy()
		end
	end

	local function openLid()
		local current = capsule
		if current == nil then
			return
		end
		current.prompt.Enabled = false
		current.opened = true
		local lid = current.lid
		-- The lid swings up and to one side (it stays a cylinder standing on its round edge).
		local goal = CFrame.new(lid.Position + Vector3.new(1.4, 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2 + math.rad(65))
		if reduceMotion() then
			lid.CFrame = goal
		else
			TweenService:Create(lid, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = goal }):Play()
		end
		Audio.play("crate_pickup", { at = current.body })
		task.delay(REMOVE_AFTER_OPEN_SECONDS, function()
			if capsule == current then
				removeCapsule()
			end
		end)
	end

	local function land(current: DailyState)
		local at = current.landing
		if at == nil or landing then
			return
		end
		landing = true
		landedDay = current.opened
		removeCapsule()
		local ground = groundAt(at)
		local built, pieces = buildCapsule(ground)
		capsule = built
		built.prompt.Triggered:Connect(function()
			openCard()
		end)
		local function touchdown()
			built.flame:Destroy()
			moveTo(pieces, ground)
			dustRing(ground)
			Audio.play("crate_drop", { at = built.body })
			built.prompt.Enabled = true
			landing = false
			deps.showMessage({ key = "carl.daily.landed" })
			task.delay(CARD_AFTER_LANDING_SECONDS, function()
				local panelOpen = deps.panelOpen
				-- Still calm: no other panel, no start menu, no mission started during the fall.
				local busy = (panelOpen ~= nil and panelOpen()) or menuOpen() or Store.phase() ~= "Briefing"
				local still = state
				if not busy and still and still.ready and capsule == built then
					openCard()
				end
			end)
		end
		if reduceMotion() then
			touchdown()
			return
		end
		Audio.play("carl_beep")
		local startClock = os.clock()
		moveTo(pieces, ground + Vector3.new(0, FALL_HEIGHT, 0))
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			if built.model.Parent == nil then
				if connection then
					connection:Disconnect()
				end
				landing = false
				return
			end
			local t = math.clamp((os.clock() - startClock) / FALL_SECONDS, 0, 1)
			local eased = 1 - (1 - t) * (1 - t) -- quad out: fast from the sky, gentle at the end
			moveTo(pieces, ground + Vector3.new(0, FALL_HEIGHT * (1 - eased), 0))
			if t >= 1 then
				if connection then
					connection:Disconnect()
				end
				touchdown()
			end
		end)
	end

	local function canLand(current: DailyState): boolean
		if not current.ready or current.landing == nil or capsule ~= nil or landing then
			return false
		end
		if landedDay == current.opened then
			return false -- already landed for this capsule (the player may have closed the card)
		end
		if not Store.isSlotChosen() or menuOpen() or Store.phase() ~= "Briefing" then
			return false
		end
		local character = player.Character
		return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
	end

	local calmFor = 0
	local sinceCheck = 0
	local sinceRender = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		sinceRender += deltaTime
		if sinceCheck < CHECK_SECONDS then
			return
		end
		local step = sinceCheck
		sinceCheck = 0
		local current = state
		if current and canLand(current) then
			calmFor += step
			if calmFor >= LAND_DELAY_SECONDS then
				calmFor = 0
				land(current)
			end
		else
			calmFor = 0
		end
		-- The countdown on the card and the Open button after a claim wait.
		if screen.Visible and sinceRender >= 1 then
			sinceRender = 0
			render()
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Server state

	local function onState(payload: any)
		if type(payload) ~= "table" or type(payload.calendar) ~= "table" or type(payload.logbook) ~= "table" then
			return
		end
		state = payload :: DailyState
		stateAt = os.clock()
		local current = state :: DailyState
		if current.claimed then
			claimPendingUntil = 0
			openLid()
			if screen.Visible then
				render()
			else
				openCard()
			end
			showResult(current)
		elseif screen.Visible then
			claimPendingUntil = 0
			render()
		end
		-- A closed capsule that is no longer waiting (opened in another server) leaves the world.
		local shown = capsule
		if not current.ready and current.claimed == nil and shown and not shown.opened and not landing then
			removeCapsule()
		end
		for _, listener in listeners do
			task.spawn(listener, current)
		end
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "language" and screen.Visible then
			render()
		end
	end)

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
		local remote = folder:WaitForChild(REMOTE_NAME, REMOTE_WAIT_SECONDS)
		if remote == nil or not remote:IsA("RemoteEvent") then
			return -- an older server: no daily capsules
		end
		local event = remote :: RemoteEvent
		event.OnClientEvent:Connect(function(payload: any)
			local ok, err = pcall(onState, payload)
			if not ok then
				warn(`[SpaceBaseOdyssey] daily state failed: {err}`)
			end
		end)
		-- Ask once, in case the state was sent before this listener existed (the server rate-limits it).
		local request: any = { type = "RequestDaily" }
		Store.send(request)
	end)
	-- A slot that loads later (start menu): ask again once it is chosen.
	player:GetAttributeChangedSignal(Store.SLOT_CHOSEN_ATTRIBUTE):Connect(function()
		if Store.isSlotChosen() then
			task.delay(2, function()
				local request: any = { type = "RequestDaily" }
				Store.send(request)
			end)
		end
	end)

	render()
end

return DailyCapsule
