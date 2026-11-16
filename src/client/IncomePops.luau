--!strict
-- Space Base Odyssey - Stage 11 tycoon, client: what the ice line's money looks like.
--   * "+N" pops: every LineEvent "delivery" (the cargo robot at the hub's supply port) and "claim"
--     (ice sent by hand at the silo) shows a small sign in the world at the event's position that
--     rises and fades. Credits (a gold coin and "+N") only when this player got them (`mine`), with
--     a coin sound there; other players' deliveries show the product (water or air) without a number.
--   * "While you were away": the LineEvent "away" (the drills filled the silo while the owner was
--     gone) opens a C.A.R.L. card: the ice dug, what it is worth, and who brings it home. The server
--     never pays it at load (it waits in the silo): with a cargo robot the card just closes (the robot
--     carries it), else the button sends the existing ClaimSilo action when the player stands at the
--     silo, or closes and leaves the way to C.A.R.L.'s beam.
--   * Silo full ("full", once per fill): a short sound, and when a bigger habitat would make a bigger
--     silo, C.A.R.L.'s tip "Silo full! Upgrade the habitat for more room." after the server's own
--     "send the ice" line.
--   * The tycoon fields of BaseState (siloOwner, lineStatus, airStatus, product, plantLevel,
--     machineCreditsPerMinute) are kept here from the BaseState remote for the HUD, the world signs
--     (ProductionLine.luau) and C.A.R.L. (Store.setBase drops fields it does not know).
-- Rules for what to show: src/shared/IceLineView.luau (pure, tested in tests/base section R).
-- Motion respects Store.reduceMotion when it exists: pops then fade in place and the card does not
-- bounce in.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local IceLineView = require(Shared:WaitForChild("IceLineView"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local IncomePops = {}

local ROLE = Ui.ROLE

-- Visual tuning (not gameplay numbers).
local POP_SECONDS = 1.8
local POP_RISE_STUDS = 5
local POP_STILL_SECONDS = 1.2 -- reduced motion: the pop stays still this long, then fades
local POP_SIZE = UDim2.fromScale(7, 2.2) -- studs: smaller far away, like a real sign
local POP_MAX_DISTANCE = 220
local POP_NEAR_STUDS = 18 -- the coin sound is full volume this close ...
local POP_FAR_STUDS = 110 -- ... and silent past this
local COIN_HEARD_STUDS = 40 -- a pop this close counts as heard (the wallet then skips its coin)
local COIN_HEARD_SECONDS = 1.5
local BIG_POP = 50 -- this many credits or more: the coin burst
local MAX_POPS = 8 -- older pops are removed when many arrive at once
local CARD_ZINDEX = 60
local CARD_WAIT_SECONDS = 60 -- the away card waits this long at most for the game screen
local SILO_COLLECT_EXTRA = 2 -- studs beyond the silo prompt's range that still count as "at the silo"

type LineState = {
	siloOwner: boolean?,
	lineStatus: string?,
	airStatus: string?,
	product: string?,
	plantLevel: number?,
	machineCreditsPerMinute: number?,
	icePerMinute: number?,
	siloIce: number?,
	siloMax: number?,
	builds: { [string]: number },
}

local player = Players.LocalPlayer
local started = false
local listening = false
local state: LineState = { builds = {} }
local stateListeners: { () -> () } = {}
local lastCoinAt = -math.huge
local pops: { Instance } = {}

export type Deps = {
	-- Messages.showTip: C.A.R.L.'s low-priority tips (the silo-full upgrade hint). Optional.
	showTip: ((ref: Types.TextRef, phase: string?) -> ())?,
}

-- Store.reduceMotion (a function or a boolean), when the Settings work adds it.
local function reduceMotion(): boolean
	local ok, value = pcall(function(): any
		local store: any = Store
		local field = store.reduceMotion
		if type(field) == "function" then
			return field()
		end
		return field
	end)
	return ok and value == true
end
IncomePops.reduceMotion = reduceMotion

local function numberOrNil(value: any): number?
	return if type(value) == "number" and value == value then value else nil
end

local function stringOrNil(value: any): string?
	return if type(value) == "string" then value else nil
end

-- A new BaseState from the server: keep its tycoon fields.
local function onBaseState(raw: any)
	if type(raw) ~= "table" then
		return
	end
	local builds: { [string]: number } = {}
	if type(raw.builds) == "table" then
		for id, level in raw.builds do
			if type(id) == "string" and type(level) == "number" then
				builds[id] = level
			end
		end
	end
	state = {
		siloOwner = if type(raw.siloOwner) == "boolean" then raw.siloOwner else nil,
		lineStatus = stringOrNil(raw.lineStatus),
		airStatus = stringOrNil(raw.airStatus),
		product = stringOrNil(raw.product),
		plantLevel = numberOrNil(raw.plantLevel),
		machineCreditsPerMinute = numberOrNil(raw.machineCreditsPerMinute),
		icePerMinute = numberOrNil(raw.icePerMinute),
		siloIce = numberOrNil(raw.siloIce),
		siloMax = numberOrNil(raw.siloMax),
		builds = builds,
	}
	for _, listener in stateListeners do
		task.spawn(listener)
	end
end

local function remoteFolder(): Instance
	return ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
end

-- Listens to the BaseState remote (once; also when another module asks before start()).
local function ensureListening()
	if listening then
		return
	end
	listening = true
	task.spawn(function()
		local remote = remoteFolder():WaitForChild(Types.Remotes.BASE_STATE)
		if remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(function(raw: any)
				local ok, err = pcall(onBaseState, raw)
				if not ok then
					warn(`[SpaceBaseOdyssey] IncomePops base state failed: {err}`)
				end
			end)
		end
	end)
end

-- The latest tycoon fields of BaseState (empty until the server sends one).
function IncomePops.lineState(): LineState
	ensureListening()
	return state
end

-- Runs `listener` after every new BaseState (the tycoon fields are fresh then).
function IncomePops.onState(listener: () -> ())
	ensureListening()
	table.insert(stateListeners, listener)
end

-- True when the silo is this player's (the world owner's). An older server sends no siloOwner: then
-- a world owner attribute that names someone else means a guest.
function IncomePops.isSiloOwner(): boolean
	ensureListening()
	local sent = state.siloOwner
	if sent ~= nil then
		return sent
	end
	local owner = Workspace:GetAttribute("SBO_WorldOwner")
	if type(owner) == "number" and owner > 0 then
		return owner == player.UserId
	end
	return true
end

-- Credits a minute the machines make now (0 without drills).
function IncomePops.machineRate(): number
	ensureListening()
	local base = Store.getBase()
	local perMinute = state.icePerMinute or (if base then base.icePerMinute else 0)
	return IceLineView.creditsPerMinute(MissionData, state.machineCreditsPerMinute, perMinute, state.product)
end

-- True right after a pop played its coin close to the player (the wallet then stays quiet, so one
-- delivery is one coin sound).
function IncomePops.coinHeardRecently(): boolean
	return os.clock() - lastCoinAt <= COIN_HEARD_SECONDS
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- "+N" pops ------------------------------------------------------------------------------------

local function popFolder(): Instance
	local existing = Workspace:FindFirstChild("SBO_IncomePopsLocal")
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "SBO_IncomePopsLocal"
	folder.Parent = Workspace
	return folder
end

local function forget(item: Instance)
	local index = table.find(pops, item)
	if index then
		table.remove(pops, index)
	end
end

-- One rising, fading sign at `position`: an icon and a short text.
local function popAt(position: Vector3, image: string, tint: Color3, text: string)
	while #pops >= MAX_POPS do
		local oldest = table.remove(pops, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local anchor = Instance.new("Part")
	anchor.Name = "IncomePop"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = popFolder()
	table.insert(pops, anchor)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Pop"
	gui.Adornee = anchor
	gui.Size = POP_SIZE
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = POP_MAX_DISTANCE
	gui.ResetOnSpawn = false
	gui.Parent = anchor

	local icon = Ui.icon(gui, image, {
		name = "Icon",
		size = UDim2.fromScale(0.3, 0.9),
		position = UDim2.fromScale(0.05, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = tint,
	})
	local label = Ui.label(gui, {
		name = "Amount",
		text = text,
		size = UDim2.fromScale(0.62, 0.9),
		position = UDim2.fromScale(0.36, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = tint,
		outline = true,
		maxText = 48,
		minText = 8,
	})

	local still = reduceMotion()
	local fade = TweenInfo.new(if still then 0.5 else POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, if still then POP_STILL_SECONDS else 0)
	if not still then
		TweenService:Create(gui, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffsetWorldSpace = Vector3.new(0, POP_RISE_STUDS, 0),
		}):Play()
	end
	TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()
	local textFade = TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 })
	textFade.Completed:Connect(function()
		forget(anchor)
		anchor:Destroy()
	end)
	textFade:Play()
end

local function onDelivery(event: any)
	local position = event.position
	if typeof(position) ~= "Vector3" then
		return
	end
	local credits = IceLineView.popCredits(event)
	if credits then
		popAt(position, Ui.Icons.coin, ROLE.star, Store.t("ui.line.delivery", { n = credits }))
		Audio.play(if credits >= BIG_POP then "coin_burst" else "coin_single", {
			at = position,
			near = POP_NEAR_STUDS,
			far = POP_FAR_STUDS,
		})
		local here = rootPosition()
		if here and (here - position).Magnitude <= COIN_HEARD_STUDS then
			lastCoinAt = os.clock()
		end
	elseif event.kind == "delivery" then
		-- Someone else's robot load: what it brought, no number (the credits are not this player's).
		local oxygen = event.product == "oxygen"
		popAt(position, if oxygen then Ui.Icons.air else Ui.Icons.drop, ROLE.accent, Store.t(if oxygen then "ui.line.air" else "ui.line.water"))
	end
end

-- "While you were away" ----------------------------------------------------------------------

local cardRoot: Frame? = nil

-- The silo prompt and whether the player stands at it.
local function nearSilo(): boolean
	local base = Workspace:FindFirstChild("Base")
	local prompt = if base then base:FindFirstChild("SiloPrompt", true) else nil
	if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then
		return false
	end
	local holder = prompt.Parent
	local at: Vector3? = nil
	if holder and holder:IsA("Attachment") then
		at = holder.WorldPosition
	elseif holder and holder:IsA("BasePart") then
		at = holder.Position
	end
	local here = rootPosition()
	return at ~= nil and here ~= nil and (here - at).Magnitude <= prompt.MaxActivationDistance + SILO_COLLECT_EXTRA
end

local function showAwayCard(card: IceLineView.AwayCard)
	local root = cardRoot
	if root == nil then
		return
	end
	local old = root:FindFirstChild("AwayCard")
	if old then
		old:Destroy()
	end
	local backdrop = Ui.modal(root, "AwayCard", CARD_ZINDEX)
	local z = CARD_ZINDEX + 1
	local panel = Ui.panel(backdrop, {
		name = "Card",
		size = UDim2.fromScale(0.46, 0.46),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panelRaised,
		stroke = 3,
		strokeColor = ROLE.accent, -- C.A.R.L. speaks in cyan
		aspect = 1.45,
		zindex = z,
	})
	Ui.sheen(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	-- C.A.R.L.'s badge and the title.
	Ui.icon(panel, Ui.ICONS.robot, {
		name = "Carl",
		size = UDim2.fromScale(0.16, 0.2),
		position = UDim2.fromScale(0.05, 0.05),
		color = ROLE.background,
		transparency = 0,
		corner = 0.5,
		aspect = 1,
		tint = ROLE.accent,
		zindex = z + 1,
	})
	Ui.label(panel, {
		name = "Title",
		text = Store.t("ui.line.away_title"),
		size = UDim2.fromScale(0.72, 0.16),
		position = UDim2.fromScale(0.24, 0.07),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 34,
		zindex = z + 1,
	})

	-- The ice the drills dug.
	Ui.icon(panel, Ui.ICONS.ice, {
		name = "IceIcon",
		size = UDim2.fromScale(0.1, 0.13),
		position = UDim2.fromScale(0.08, 0.36),
		anchor = Vector2.new(0, 0.5),
		tint = Ui.COLORS.ice,
		zindex = z + 1,
	})
	Ui.label(panel, {
		name = "Ice",
		text = Store.t("ui.line.away", { n = card.ice }),
		size = UDim2.fromScale(0.76, 0.13),
		position = UDim2.fromScale(0.2, 0.36),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.text,
		maxText = 30,
		zindex = z + 1,
	})

	-- What it is worth once it reaches the base.
	Ui.icon(panel, Ui.Icons.coin, {
		name = "CoinIcon",
		size = UDim2.fromScale(0.1, 0.12),
		position = UDim2.fromScale(0.08, 0.52),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.star,
		zindex = z + 1,
	})
	Ui.label(panel, {
		name = "Worth",
		text = Store.t("ui.line.away_worth", { n = card.credits }),
		size = UDim2.fromScale(0.76, 0.12),
		position = UDim2.fromScale(0.2, 0.52),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 28,
		zindex = z + 1,
	})

	-- Who brings it home.
	Ui.body(panel, {
		name = "Hint",
		text = Store.t(if card.robot then "ui.line.away_robot" else "ui.line.away_silo"),
		size = UDim2.fromScale(0.86, 0.1),
		position = UDim2.fromScale(0.08, 0.66),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.textDim,
		maxText = 22,
		zindex = z + 1,
	})

	local collect = not card.robot and IncomePops.isSiloOwner() and nearSilo()
	local function close()
		if backdrop.Parent then
			backdrop.Visible = false
			task.delay(0.3, function()
				backdrop:Destroy()
			end)
		end
	end
	local button = Ui.button(panel, {
		name = "Ok",
		text = Store.t(if collect then "ui.line.collect" else "ui.line.ok"),
		icon = if collect then Ui.Icons.silo else Ui.ICONS.check,
		size = UDim2.fromScale(0.5, 0.15),
		position = UDim2.fromScale(0.5, 0.86),
		anchor = Vector2.new(0.5, 0.5),
		zindex = z + 2,
		maxText = 28,
	}, function()
		if collect then
			-- The existing silo action; the server checks the owner, the distance and the ice.
			local action: any = { type = "ClaimSilo" }
			Store.send(action)
		end
		close()
	end)
	button.Selectable = true

	backdrop.Visible = true
	if not reduceMotion() then
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

-- The card waits for the game screen (a slot loaded, not the end-of-mission report).
local function queueAwayCard(event: any)
	if IceLineView.awayCard(MissionData, BaseBuild, event, nil) == nil then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + CARD_WAIT_SECONDS
		while os.clock() < deadline do
			local phase = Store.phase()
			if Store.isSlotChosen() and phase ~= "Report" then
				-- Worked out now, with the builds of this world (the robot may stand or not).
				local base = Store.getBase()
				local card = IceLineView.awayCard(MissionData, BaseBuild, event, if base then base.builds else state.builds)
				if card then
					showAwayCard(card)
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

-- Silo full ----------------------------------------------------------------------------------

local showTip: ((ref: Types.TextRef, phase: string?) -> ())? = nil

local function onFull()
	Audio.play("toast_pop")
	local tip = showTip
	local base = Store.getBase()
	local builds = if base then base.builds else state.builds
	if tip and IceLineView.biggerSiloNext(MissionData, BaseBuild, builds) then
		tip({ key = "carl.line.silo_upgrade" }, Store.phase())
	end
end

local function onLineEvent(event: any)
	if type(event) ~= "table" then
		return
	end
	local kind = event.kind
	if kind == "delivery" or kind == "claim" then
		onDelivery(event)
	elseif kind == "away" then
		queueAwayCard(event)
	elseif kind == "full" then
		onFull()
	end
end

-- Starts the pops, the away card and the silo-full cue (once). root: the scaled UI root (Ui).
function IncomePops.start(root: Frame, deps: Deps?)
	if started then
		return
	end
	started = true
	cardRoot = root
	showTip = if deps then deps.showTip else nil
	ensureListening()
	task.spawn(function()
		local remote = remoteFolder():WaitForChild(Types.Remotes.LINE)
		if remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(function(event: any)
				local ok, err = pcall(onLineEvent, event)
				if not ok then
					warn(`[SpaceBaseOdyssey] IncomePops line event failed: {err}`)
				end
			end)
		end
	end)
end

return IncomePops
