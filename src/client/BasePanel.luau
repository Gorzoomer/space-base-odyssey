--!strict
-- Space Base Odyssey - Base panel (Stage 6): build and grow the Moon base like a tycoon.
--   * Header: credits, player level with an XP bar, ice per minute from the drills, silo ice x/max
--     and a Collect button (Action ClaimSilo).
--   * Base tab: every build of MissionData.BASE.BUILDS in order: icon, name, what it does, level pips,
--     next cost and a Build / Upgrade button (Action Build). Building works from here too (no need to
--     walk to the pad). A blocked build shows the same reason the server would ("base.why.<reason>").
--   * Skills tab: speed, tank, jump, drill cards with level pips and a Learn button (Action LearnSkill).
--   * Pets tab: the four pets with a small 3D preview (Santiago's PetModels), how to get each one and a
--     Buy button (Action BuyPet); owned pets get a Use button (Action Equip, slot "pet").
-- The client only shows what is possible; the server (BaseService) validates every Action again.
-- Also exports BasePanel.petPreview, used by the Wardrobe for its pet tiles.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local PetModels = require(Shared:WaitForChild("PetModels"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type BaseState = Types.BaseState
type Params = { [string]: string | number }

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE
local BASE = MissionData.BASE
-- Typed views of the MissionData.BASE lists (their rows differ in optional fields).
local BUILDS: { BaseBuild.BuildDef } = BASE.BUILDS :: any
local SKILLS: { BaseBuild.SkillDef } = BASE.SKILLS :: any
local PETS: { BaseBuild.PetDef } = BASE.PETS :: any

-- Above the C.A.R.L. bubble (50-52), below Sources (55), Collection (56-61) and Settings (60-62).
local Z = 53
local PANEL_ASPECT = 1.5 -- width / height; fits phones in landscape and tablets
local ROW_HEIGHT = 92 -- reference units (the root is 720 units tall)
local ROW_GAP = 8
local LIST_PADDING = 8
local SCROLL_BAR = 8
local PRESS_COOLDOWN = 0.5 -- seconds between two presses of the same button (the server checks too)
local SPIN_SPEED = 0.6 -- radians per second for the pet previews
local PREVIEW_FOV = 30

local BasePanel = {}

export type Deps = {
	showMessage: any, -- reserved for local hints (the C.A.R.L. bubble sits under this panel)
}

export type Tab = "base" | "skills" | "pets"

export type BasePanelView = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	openTab: (tab: Tab) -> (),
	render: () -> (),
}

---------------------------------------------------------------------------------------------------
-- Small shared helpers
---------------------------------------------------------------------------------------------------

-- 1.5 -> "1.5", 25 -> "25".
local function formatNumber(value: number): string
	if math.abs(value - math.floor(value + 0.5)) < 0.001 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.1f", value)
end
BasePanel.formatNumber = formatNumber

local function levelOf(levels: { [string]: number }?, id: string): number
	return BaseBuild.levelOf(levels, id)
end

-- The base state from the server (nil until the first BaseState arrives).
local function getBase(): BaseState?
	return Store.getBase()
end

-- Owned pets: the server's list, plus collectible pets the saved Progress already shows.
local function ownedPets(base: BaseState?): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	if base and type(base.pets) == "table" then
		for id, value in base.pets do
			if value == true then
				owned[id] = true
			end
		end
	end
	for _, def in PETS do
		if def.collectible and Store.hasCollectible(def.collectible) then
			owned[def.id] = true
		end
	end
	return owned
end
BasePanel.ownedPets = ownedPets

-- Why something is blocked. The reason is the same one the server gives (BaseBuild); the panel can
-- say it more exactly ("Needs level 3", "Build Antenna first") because it knows the numbers.
-- Other reasons use the server's own "base.why.<reason>" text.
local DETAILED_REASONS: { [string]: string } = {
	level = "panel.needs_level", -- {n} = player level needed
	credits = "panel.needs_credits", -- {n} = credits needed
	requires = "panel.needs_build", -- {name} = the build to make first
}
local function reasonText(reason: string?, params: Params?): string
	if reason == nil then
		return ""
	end
	local detailed = DETAILED_REASONS[reason]
	if detailed and params and (params.n ~= nil or params.name ~= nil) then
		return Store.t(detailed, params)
	end
	return Store.t("base.why." .. reason, params)
end

-- Params for a blocked build: n = player level needed ("level"), credits needed ("credits") or the
-- level of the missing build ("requires"); name = the missing build's name.
local function buildReasonParams(base: BaseState, id: string, reason: string?): Params
	local def = BaseBuild.buildDef(MissionData, id)
	local params: Params = {}
	if def == nil then
		return params
	end
	local nextLevel = math.min(levelOf(base.builds, id) + 1, def.maxLevel)
	if reason == "level" then
		params.n = def.minLevel[nextLevel]
		params.level = def.minLevel[nextLevel]
	elseif reason == "credits" then
		params.n = def.costs[nextLevel]
		params.cost = def.costs[nextLevel]
	elseif reason == "requires" then
		-- The first missing requirement in BUILDS order (stable text).
		for _, other in BUILDS do
			local needed = def.requires[other.id]
			if needed and levelOf(base.builds, other.id) < needed then
				params.name = Store.t("build." .. other.id .. ".name")
				params.n = needed
				break
			end
		end
	end
	return params
end

-- A pill: rounded raised frame with an icon on the left and a text label.
type Pill = { frame: Frame, icon: ImageLabel, label: TextLabel }
local function makePill(parent: Instance, props: Ui.Props, image: string, tint: Color3, zindex: number): Pill
	local withDefaults: Ui.Props = table.clone(props)
	withDefaults.color = props.color or ROLE.panelRaised
	withDefaults.corner = props.corner or 0.4
	withDefaults.zindex = zindex
	local frame = Ui.frame(parent, withDefaults)
	local icon = Ui.icon(frame, image, {
		name = "Icon",
		size = UDim2.fromScale(0.7, 0.7),
		position = UDim2.fromScale(0.04, 0.5),
		anchor = Vector2.new(0, 0.5),
		aspect = 1,
		tint = tint,
		zindex = zindex + 1,
	})
	local label = Ui.label(frame, {
		name = "Text",
		size = UDim2.fromScale(0.7, 0.8),
		position = UDim2.fromScale(0.27, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = props.textColor or ROLE.text,
		maxText = props.maxText or 24,
		minText = 8,
		zindex = zindex + 1,
	})
	return { frame = frame, icon = icon, label = label }
end

-- A row of small level pips (filled = level reached).
type Pips = { frame: Frame, set: (level: number, maxLevel: number, color: Color3) -> () }
local function makePips(parent: Instance, props: Ui.Props, count: number, zindex: number): Pips
	local frame = Ui.frame(parent, props)
	frame.ZIndex = zindex
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = frame
	local dots: { Frame } = {}
	for index = 1, count do
		local dot = Ui.frame(frame, {
			name = `Pip{index}`,
			size = UDim2.fromScale(0.2, 0.8),
			color = ROLE.background,
			corner = 0.5,
			stroke = 2,
			strokeColor = ROLE.stroke,
			aspect = 1,
			order = index,
			zindex = zindex + 1,
		})
		table.insert(dots, dot)
	end
	local function set(level: number, maxLevel: number, color: Color3)
		for index, dot in dots do
			dot.Visible = index <= maxLevel
			local lit = index <= level
			dot.BackgroundColor3 = if lit then color else ROLE.background
			local stroke = dot:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if lit then color else ROLE.stroke
			end
		end
	end
	return { frame = frame, set = set }
end

---------------------------------------------------------------------------------------------------
-- Pet preview: Santiago's pet models (PetModels.luau) in a ViewportFrame with a spinning camera.
---------------------------------------------------------------------------------------------------

export type PetPreview = {
	viewport: ViewportFrame,
	setAngle: (angle: number) -> (),
	setLocked: (locked: boolean) -> (),
}

local PART_SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local function materialFor(name: string): Enum.Material
	local ok, value = pcall(function(): any
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(value) == "EnumItem" then
		return value :: any
	end
	return Enum.Material.SmoothPlastic
end

function BasePanel.petPreview(parent: Instance, petId: string, props: Ui.Props): PetPreview?
	local parts = PetModels[petId]
	if parts == nil then
		return nil
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = props.name or "Preview"
	viewport.Size = props.size or UDim2.fromScale(1, 1)
	viewport.Position = props.position or UDim2.fromScale(0, 0)
	viewport.AnchorPoint = props.anchor or Vector2.zero
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.ZIndex = props.zindex or 1
	viewport.Ambient = PALETTE.creamDim
	viewport.LightColor = PALETTE.cream
	viewport.LightDirection = Vector3.new(-0.4, -1, 0.6)
	if props.aspect then
		Ui.aspect(viewport, props.aspect)
	end

	local model = Instance.new("Model")
	model.Name = petId
	local top = 0.5
	local reach = 0.5
	for _, data in parts do
		local part: BasePart
		if data.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local plain = Instance.new("Part")
			plain.Shape = PART_SHAPES[data.shape] or Enum.PartType.Block
			part = plain
		end
		local c = data.cframe
		part.Name = data.name
		part.Size = Vector3.new(data.size[1], data.size[2], data.size[3])
		part.CFrame = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		part.Color = Color3.fromRGB(data.color[1], data.color[2], data.color[3])
		part.Material = materialFor(data.material)
		part.Transparency = data.transparency
		part.Reflectance = data.reflectance
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Parent = model
		local half = math.max(data.size[1], data.size[2], data.size[3]) / 2
		top = math.max(top, c[2] + half)
		reach = math.max(reach, math.abs(c[1]) + half, math.abs(c[3]) + half)
	end
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = PREVIEW_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local target = Vector3.new(0, top * 0.5, 0)
	local radius = math.max(top * 0.5, reach)
	local distance = radius / math.tan(math.rad(PREVIEW_FOV / 2)) * 1.15

	local function setAngle(angle: number)
		-- The model faces -Z: angle 0 looks at its face, a little from above.
		local direction = Vector3.new(math.sin(angle), 0.28, -math.cos(angle)).Unit
		camera.CFrame = CFrame.lookAt(target + direction * distance, target)
	end
	local function setLocked(locked: boolean)
		-- Locked: a dark silhouette (like the hidden collectibles).
		viewport.ImageColor3 = if locked then PALETTE.nightLine else Color3.new(1, 1, 1) -- white = no tint
		viewport.ImageTransparency = if locked then 0.15 else 0
	end
	setAngle(0.5)
	setLocked(false)
	viewport.Parent = parent
	return { viewport = viewport, setAngle = setAngle, setLocked = setLocked }
end

---------------------------------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------------------------------

function BasePanel.new(root: Frame, _deps: Deps): BasePanelView
	local modal = Ui.modal(root, "BasePanel", Z)
	-- Tapping the dark area around the panel closes it.
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
		strokeColor = ROLE.good,
		aspect = PANEL_ASPECT,
		zindex = Z + 1,
	})
	panel.Active = true
	Ui.sheen(panel)

	-- Header: icon, title, tabs, close ------------------------------------------------------------
	Ui.icon(panel, Ui.Icons.build, {
		size = UDim2.fromScale(0.05, 0.08),
		position = UDim2.fromScale(0.025, 0.075),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.good,
		zindex = Z + 2,
	})
	local title = Ui.label(panel, {
		name = "Title",
		size = UDim2.fromScale(0.26, 0.08),
		position = UDim2.fromScale(0.08, 0.075),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.good,
		maxText = 36,
		zindex = Z + 2,
	})

	local currentTab: Tab = "base"
	local render: () -> () -- defined below

	local TABS: { { id: Tab, key: string, icon: string, color: Color3 } } = {
		{ id = "base", key = "panel.tab_base", icon = Ui.Icons.build, color = ROLE.good },
		{ id = "skills", key = "panel.tab_skills", icon = Ui.Icons.skills, color = ROLE.accent },
		{ id = "pets", key = "panel.tab_pets", icon = Ui.Icons.paw, color = ROLE.reward },
	}
	local tabButtons: { [Tab]: TextButton } = {}
	for index, tab in TABS do
		tabButtons[tab.id] = Ui.button(panel, {
			name = `Tab_{tab.id}`,
			size = UDim2.fromScale(0.165, 0.085),
			position = UDim2.fromScale(0.35 + (index - 1) * 0.177, 0.035),
			color = Ui.COLORS.secondary,
			icon = tab.icon,
			corner = 0.35,
			stroke = 2,
			maxText = 26,
			zindex = Z + 2,
		}, function()
			currentTab = tab.id
			render()
		end)
		-- One line only: wrapping split "Mascotas" mid-word in playtest; scaling shrinks it instead.
		local tabLabel = tabButtons[tab.id]:FindFirstChild("Label", true)
		if tabLabel and tabLabel:IsA("TextLabel") then
			tabLabel.TextWrapped = false
			tabLabel.TextScaled = true
		end
	end

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

	-- Stats row: credits, level + XP, ice per minute, silo + Collect ------------------------------
	local STATS_Y = 0.145
	local STATS_H = 0.085
	local credits = makePill(panel, {
		name = "Credits",
		size = UDim2.fromScale(0.15, STATS_H),
		position = UDim2.fromScale(0.025, STATS_Y),
		textColor = ROLE.star,
		maxText = 28,
	}, Ui.Icons.coin, ROLE.star, Z + 2)

	local levelPill = makePill(panel, {
		name = "Level",
		size = UDim2.fromScale(0.27, STATS_H),
		position = UDim2.fromScale(0.185, STATS_Y),
		textColor = ROLE.accent,
	}, Ui.Icons.xp, ROLE.accent, Z + 2)
	levelPill.icon.Size = UDim2.fromScale(0.7, 0.7)
	levelPill.label.Size = UDim2.fromScale(0.36, 0.62)
	levelPill.label.Position = UDim2.fromScale(0.15, 0.4)
	local xpLabel = Ui.label(levelPill.frame, {
		name = "Xp",
		size = UDim2.fromScale(0.46, 0.5),
		position = UDim2.fromScale(0.95, 0.4),
		anchor = Vector2.new(1, 0.5),
		alignX = Enum.TextXAlignment.Right,
		textColor = ROLE.textDim,
		font = Ui.BODY_FONT,
		maxText = 18,
		minText = 7,
		zindex = Z + 3,
	})
	local xpBack = Ui.frame(levelPill.frame, {
		name = "XpBar",
		size = UDim2.fromScale(0.8, 0.16),
		position = UDim2.fromScale(0.15, 0.78),
		anchor = Vector2.new(0, 0.5),
		color = ROLE.background,
		corner = 0.5,
		zindex = Z + 3,
	})
	local xpFill = Ui.frame(xpBack, {
		name = "Fill",
		size = UDim2.fromScale(0, 1),
		color = ROLE.accent,
		corner = 0.5,
		zindex = Z + 4,
	})

	local icePill = makePill(panel, {
		name = "IceRate",
		size = UDim2.fromScale(0.22, STATS_H),
		position = UDim2.fromScale(0.465, STATS_Y),
		maxText = 20,
	}, Ui.Icons.drill, PALETTE.cyan, Z + 2)
	icePill.label.Size = UDim2.fromScale(0.78, 0.8)
	icePill.label.Position = UDim2.fromScale(0.19, 0.5)

	local siloPill = makePill(panel, {
		name = "Silo",
		size = UDim2.fromScale(0.15, STATS_H),
		position = UDim2.fromScale(0.695, STATS_Y),
		maxText = 20,
	}, Ui.Icons.silo, PALETTE.cyan, Z + 2)

	local lastClaim = -math.huge
	local collectButton = Ui.button(panel, {
		name = "Collect",
		size = UDim2.fromScale(0.125, STATS_H),
		position = UDim2.fromScale(0.975, STATS_Y),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.go,
		icon = Ui.Icons.ice,
		corner = 0.35,
		stroke = 2,
		maxText = 22,
		zindex = Z + 2,
	}, function()
		local base = getBase()
		if base == nil or base.siloIce < 1 or os.clock() - lastClaim < PRESS_COOLDOWN then
			return
		end
		lastClaim = os.clock()
		local action: any = { type = "ClaimSilo" }
		Store.send(action)
	end)

	-- Content area: one page per tab, plus a "loading" line until the first BaseState ------------
	local content = Ui.frame(panel, {
		name = "Content",
		size = UDim2.fromScale(0.95, 0.715),
		position = UDim2.fromScale(0.025, 0.255),
		zindex = Z + 1,
	})
	local waiting = Ui.label(content, {
		name = "Waiting",
		size = UDim2.fromScale(1, 0.2),
		position = UDim2.fromScale(0.5, 0.4),
		anchor = Vector2.new(0.5, 0.5),
		textColor = ROLE.textDim,
		maxText = 30,
		zindex = Z + 2,
	})
	local pages: { [Tab]: Frame } = {}
	for _, tab in TABS do
		pages[tab.id] = Ui.frame(content, { name = `Page_{tab.id}`, zindex = Z + 1, visible = false })
	end

	-----------------------------------------------------------------------------------------------
	-- Base tab: a scrolling list of builds
	-----------------------------------------------------------------------------------------------
	local list = Instance.new("ScrollingFrame")
	list.Name = "Builds"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundColor3 = ROLE.background
	list.BackgroundTransparency = 0.3
	list.BorderSizePixel = 0
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = SCROLL_BAR
	list.ScrollBarImageColor3 = ROLE.good
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ZIndex = Z + 2
	Ui.corner(list, 0.04)
	list.Parent = pages["base"]
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, LIST_PADDING)
	listPadding.PaddingBottom = UDim.new(0, LIST_PADDING)
	listPadding.PaddingLeft = UDim.new(0, LIST_PADDING)
	listPadding.PaddingRight = UDim.new(0, LIST_PADDING + SCROLL_BAR)
	listPadding.Parent = list
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.Parent = list
	-- Canvas from the fixed row heights (AutomaticCanvasSize is unreliable under a UIScale).
	list.CanvasSize = UDim2.new(0, 0, 0, LIST_PADDING * 2 + #BUILDS * ROW_HEIGHT + (#BUILDS - 1) * ROW_GAP)

	type BuildRow = {
		id: string,
		frame: Frame,
		stroke: UIStroke,
		badgeScale: UIScale,
		name: TextLabel,
		desc: TextLabel,
		pips: Pips,
		cost: Pill,
		button: TextButton,
		reason: TextLabel,
		allowed: boolean,
		lastPress: number,
	}
	local buildRows: { BuildRow } = {}
	local shownLevels: { [string]: number } = {}

	for index, def in BUILDS do
		local frame = Ui.frame(list, {
			name = `Build_{def.id}`,
			size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			color = ROLE.panelRaised,
			corner = 0.2,
			stroke = 2,
			strokeColor = ROLE.stroke,
			order = index,
			zindex = Z + 3,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		local badge = Ui.frame(frame, {
			name = "Badge",
			size = UDim2.fromScale(0.8, 0.8),
			position = UDim2.fromScale(0.012, 0.5),
			anchor = Vector2.new(0, 0.5),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			zindex = Z + 4,
		})
		local badgeScale = Instance.new("UIScale")
		badgeScale.Parent = badge
		Ui.icon(badge, Ui.iconImage(def.icon), {
			name = "Icon",
			size = UDim2.fromScale(0.62, 0.62),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			tint = ROLE.good,
			zindex = Z + 5,
		})
		local name = Ui.label(frame, {
			name = "Name",
			size = UDim2.fromScale(0.36, 0.42),
			position = UDim2.fromScale(0.1, 0.07),
			alignX = Enum.TextXAlignment.Left,
			maxText = 26,
			zindex = Z + 4,
		})
		local desc = Ui.body(frame, {
			name = "Desc",
			size = UDim2.fromScale(0.46, 0.42),
			position = UDim2.fromScale(0.1, 0.52),
			textColor = ROLE.textDim,
			maxText = 18,
			minText = 7,
			zindex = Z + 4,
		})
		local pips = makePips(frame, {
			name = "Pips",
			size = UDim2.fromScale(0.15, 0.3),
			position = UDim2.fromScale(0.585, 0.12),
		}, def.maxLevel, Z + 4)
		local cost = makePill(frame, {
			name = "Cost",
			size = UDim2.fromScale(0.15, 0.38),
			position = UDim2.fromScale(0.585, 0.5),
			color = ROLE.background,
			textColor = ROLE.star,
			maxText = 24,
		}, Ui.Icons.coin, ROLE.star, Z + 4)
		local row: BuildRow
		local button = Ui.button(frame, {
			name = "Action",
			size = UDim2.fromScale(0.24, 0.5),
			position = UDim2.fromScale(0.99, 0.08),
			anchor = Vector2.new(1, 0),
			color = Ui.COLORS.go,
			icon = Ui.Icons.build,
			corner = 0.35,
			stroke = 2,
			maxText = 24,
			zindex = Z + 4,
		}, function()
			local base = getBase()
			if base == nil or not row.allowed or os.clock() - row.lastPress < PRESS_COOLDOWN then
				return
			end
			-- Same check as the server, with the newest state.
			local ok = BaseBuild.canBuild(MissionData, base.builds, base.level, base.credits, def.id)
			if not ok then
				return
			end
			row.lastPress = os.clock()
			local action: any = { type = "Build", id = def.id }
			Store.send(action)
		end)
		local reason = Ui.body(frame, {
			name = "Reason",
			size = UDim2.fromScale(0.24, 0.32),
			position = UDim2.fromScale(0.99, 0.62),
			anchor = Vector2.new(1, 0),
			alignX = Enum.TextXAlignment.Center,
			textColor = ROLE.warning,
			maxText = 16,
			minText = 7,
			zindex = Z + 4,
		})
		row = {
			id = def.id,
			frame = frame,
			stroke = stroke,
			badgeScale = badgeScale,
			name = name,
			desc = desc,
			pips = pips,
			cost = cost,
			button = button,
			reason = reason,
			allowed = false,
			lastPress = -math.huge,
		}
		table.insert(buildRows, row)
	end

	local function pop(scale: UIScale)
		scale.Scale = 1.35
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	local function renderBuilds(base: BaseState)
		for _, row in buildRows do
			local def = BaseBuild.buildDef(MissionData, row.id)
			if def == nil then
				continue
			end
			local level = levelOf(base.builds, row.id)
			local maxed = level >= def.maxLevel
			local allowed, reason = BaseBuild.canBuild(MissionData, base.builds, base.level, base.credits, row.id)
			row.allowed = allowed
			row.name.Text = Store.t("build." .. row.id .. ".name")
			row.desc.Text = Store.t("build." .. row.id .. ".desc")
			row.pips.set(level, def.maxLevel, ROLE.good)
			if shownLevels[row.id] ~= nil and level > (shownLevels[row.id] :: number) then
				pop(row.badgeScale)
			end
			shownLevels[row.id] = level

			local nextCost = BaseBuild.nextCost(MissionData, base.builds, row.id)
			row.cost.frame.Visible = nextCost ~= nil
			if nextCost ~= nil then
				row.cost.label.Text = if nextCost == 0 then Store.t("panel.free") else formatNumber(nextCost)
				row.cost.label.TextColor3 = if base.credits >= nextCost then ROLE.star else ROLE.textDim
			end

			if maxed then
				Ui.setButton(row.button, Store.t("panel.max"), Ui.ICONS.check)
				Ui.setButtonLook(row.button, true, Ui.COLORS.secondary)
				row.button.AutoButtonColor = false
				row.reason.Text = ""
			else
				local verb = if level == 0 then "panel.build" else "panel.upgrade"
				local image = if allowed then (if level == 0 then Ui.Icons.build else Ui.Icons.upgrade) else Ui.ICONS.lock
				Ui.setButton(row.button, Store.t(verb), image)
				Ui.setButtonLook(row.button, allowed, Ui.COLORS.go)
				row.reason.Text = if allowed then "" else reasonText(reason, buildReasonParams(base, row.id, reason))
			end
			-- Something the player can do right now glows lime.
			row.stroke.Color = if allowed then ROLE.good else ROLE.stroke
			row.stroke.Thickness = if allowed then 3 else 2
		end
	end

	-----------------------------------------------------------------------------------------------
	-- Cards (skills and pets): icon/preview on top, name, text, pips, reason, button
	-----------------------------------------------------------------------------------------------
	local CARD_W = 0.235
	local CARD_GAP = (1 - CARD_W * 4) / 3

	local function topLine(page: Frame, color: Color3): (TextLabel, TextLabel)
		local left = Ui.label(page, {
			name = "Points",
			size = UDim2.fromScale(0.45, 0.09),
			position = UDim2.fromScale(0, 0.005),
			alignX = Enum.TextXAlignment.Left,
			textColor = color,
			maxText = 26,
			zindex = Z + 2,
		})
		local right = Ui.body(page, {
			name = "Hint",
			size = UDim2.fromScale(0.54, 0.09),
			position = UDim2.fromScale(1, 0.005),
			anchor = Vector2.new(1, 0),
			alignX = Enum.TextXAlignment.Right,
			textColor = ROLE.textDim,
			maxText = 18,
			minText = 8,
			zindex = Z + 2,
		})
		return left, right
	end

	local function card(page: Frame, index: number, name: string, strokeColor: Color3): (Frame, UIStroke)
		local frame = Ui.frame(page, {
			name = name,
			size = UDim2.fromScale(CARD_W, 0.87),
			position = UDim2.fromScale((index - 1) * (CARD_W + CARD_GAP), 0.13),
			color = ROLE.panelRaised,
			corner = 0.08,
			stroke = 2,
			strokeColor = strokeColor,
			zindex = Z + 2,
		})
		return frame, frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	end

	-- Skills tab ----------------------------------------------------------------------------------
	local pointsLabel, skillHint = topLine(pages["skills"], ROLE.accent)
	type SkillCard = {
		id: string,
		stroke: UIStroke,
		badgeScale: UIScale,
		name: TextLabel,
		desc: TextLabel,
		pips: Pips,
		reason: TextLabel,
		button: TextButton,
		allowed: boolean,
		lastPress: number,
	}
	local skillCards: { SkillCard } = {}
	local shownSkills: { [string]: number } = {}
	for index, def in SKILLS do
		local frame, stroke = card(pages["skills"], index, `Skill_{def.id}`, ROLE.stroke)
		local badge = Ui.frame(frame, {
			name = "Badge",
			size = UDim2.fromScale(0.5, 0.25),
			position = UDim2.fromScale(0.5, 0.04),
			anchor = Vector2.new(0.5, 0),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			stroke = 3,
			strokeColor = ROLE.accent,
			zindex = Z + 3,
		})
		local badgeScale = Instance.new("UIScale")
		badgeScale.Parent = badge
		Ui.icon(badge, Ui.iconImage(def.icon), {
			name = "Icon",
			size = UDim2.fromScale(0.62, 0.62),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			tint = ROLE.accent,
			zindex = Z + 4,
		})
		local name = Ui.label(frame, {
			name = "Name",
			size = UDim2.fromScale(0.92, 0.1),
			position = UDim2.fromScale(0.5, 0.31),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.accent,
			maxText = 26,
			zindex = Z + 3,
		})
		local desc = Ui.body(frame, {
			name = "Desc",
			size = UDim2.fromScale(0.88, 0.2),
			position = UDim2.fromScale(0.5, 0.42),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			maxText = 18,
			minText = 7,
			zindex = Z + 3,
		})
		local pips = makePips(frame, {
			name = "Pips",
			size = UDim2.fromScale(0.56, 0.06),
			position = UDim2.fromScale(0.5, 0.64),
			anchor = Vector2.new(0.5, 0),
		}, def.maxLevel, Z + 3)
		local layout = pips.frame:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		end
		local reason = Ui.body(frame, {
			name = "Reason",
			size = UDim2.fromScale(0.9, 0.08),
			position = UDim2.fromScale(0.5, 0.72),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			textColor = ROLE.warning,
			maxText = 16,
			minText = 7,
			zindex = Z + 3,
		})
		local entry: SkillCard
		local button = Ui.button(frame, {
			name = "Learn",
			size = UDim2.fromScale(0.84, 0.13),
			position = UDim2.fromScale(0.5, 0.83),
			anchor = Vector2.new(0.5, 0),
			color = Ui.COLORS.go,
			icon = Ui.Icons.upgrade,
			corner = 0.35,
			stroke = 2,
			maxText = 24,
			zindex = Z + 3,
		}, function()
			local base = getBase()
			if base == nil or not entry.allowed or os.clock() - entry.lastPress < PRESS_COOLDOWN then
				return
			end
			if not BaseBuild.canLearn(MissionData, base.skills, base.level, def.id) then
				return
			end
			entry.lastPress = os.clock()
			local action: any = { type = "LearnSkill", id = def.id }
			Store.send(action)
		end)
		entry = {
			id = def.id,
			stroke = stroke,
			badgeScale = badgeScale,
			name = name,
			desc = desc,
			pips = pips,
			reason = reason,
			button = button,
			allowed = false,
			lastPress = -math.huge,
		}
		table.insert(skillCards, entry)
	end

	-- The effect shown in a skill's text: what the next level gives (the top level when maxed).
	local function skillEffect(id: string, level: number, maxLevel: number): Params
		local target = math.clamp(level + 1, 1, maxLevel)
		if id == "speed" then
			return { n = formatNumber(target * BASE.SPEED_BONUS_PER_LEVEL) }
		elseif id == "tank" then
			return { n = formatNumber(target * BASE.TANK_BONUS_PER_LEVEL) }
		elseif id == "jump" then
			return { n = formatNumber(BASE.JUMP_POWER_BONUS[target]) }
		elseif id == "drill" then
			return { n = formatNumber(math.floor((1 - BASE.DRILL_HOLD_FACTOR[target]) * 100 + 0.5)) }
		end
		return {}
	end

	local function renderSkills(base: BaseState)
		pointsLabel.Text = Store.t("panel.skill_points", { n = base.skillPoints })
		skillHint.Text = Store.t("panel.skill_hint")
		for _, entry in skillCards do
			local def = BaseBuild.skillDef(MissionData, entry.id)
			if def == nil then
				continue
			end
			local level = levelOf(base.skills, entry.id)
			local maxed = level >= def.maxLevel
			local allowed, reason = BaseBuild.canLearn(MissionData, base.skills, base.level, entry.id)
			entry.allowed = allowed
			entry.name.Text = Store.t("skill." .. entry.id .. ".name")
			entry.desc.Text = Store.t("skill." .. entry.id .. ".desc", skillEffect(entry.id, level, def.maxLevel))
			entry.pips.set(level, def.maxLevel, ROLE.accent)
			if shownSkills[entry.id] ~= nil and level > (shownSkills[entry.id] :: number) then
				pop(entry.badgeScale)
			end
			shownSkills[entry.id] = level
			if maxed then
				Ui.setButton(entry.button, Store.t("panel.max"), Ui.ICONS.check)
				Ui.setButtonLook(entry.button, true, Ui.COLORS.secondary)
				entry.button.AutoButtonColor = false
				entry.reason.Text = ""
			else
				Ui.setButton(entry.button, Store.t("panel.learn"), if allowed then Ui.Icons.upgrade else Ui.ICONS.lock)
				Ui.setButtonLook(entry.button, allowed, Ui.COLORS.go)
				local params: Params = {}
				if reason == "level" then
					params.n = def.minLevel[level + 1]
					params.level = def.minLevel[level + 1]
				end
				entry.reason.Text = if allowed then "" else reasonText(reason, params)
			end
			entry.stroke.Color = if allowed then ROLE.good else ROLE.stroke
			entry.stroke.Thickness = if allowed then 3 else 2
		end
	end

	-- Pets tab ------------------------------------------------------------------------------------
	local petTitle, petHint = topLine(pages["pets"], ROLE.reward)
	type PetCard = {
		id: string,
		stroke: UIStroke,
		preview: PetPreview?,
		lock: ImageLabel,
		name: TextLabel,
		how: TextLabel,
		reason: TextLabel,
		button: TextButton,
		mode: "buy" | "use" | "none",
		lastPress: number,
	}
	local petCards: { PetCard } = {}
	for index, def in PETS do
		local frame, stroke = card(pages["pets"], index, `Pet_{def.id}`, ROLE.stroke)
		local stage = Ui.frame(frame, {
			name = "Stage",
			size = UDim2.fromScale(0.9, 0.42),
			position = UDim2.fromScale(0.5, 0.04),
			anchor = Vector2.new(0.5, 0),
			color = ROLE.background,
			corner = 0.12,
			zindex = Z + 3,
		})
		local preview = BasePanel.petPreview(stage, def.id, {
			name = "Preview",
			size = UDim2.fromScale(1, 1),
			zindex = Z + 4,
		})
		local lock = Ui.icon(stage, Ui.ICONS.lock, {
			name = "Lock",
			size = UDim2.fromScale(0.26, 0.26),
			position = UDim2.fromScale(0.96, 0.95),
			anchor = Vector2.new(1, 1),
			color = ROLE.background,
			corner = 0.5,
			aspect = 1,
			tint = ROLE.textDim,
			zindex = Z + 5,
		})
		local name = Ui.label(frame, {
			name = "Name",
			size = UDim2.fromScale(0.92, 0.1),
			position = UDim2.fromScale(0.5, 0.48),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.reward,
			maxText = 26,
			zindex = Z + 3,
		})
		local how = Ui.body(frame, {
			name = "How",
			size = UDim2.fromScale(0.88, 0.13),
			position = UDim2.fromScale(0.5, 0.59),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			textColor = ROLE.textDim,
			maxText = 17,
			minText = 7,
			zindex = Z + 3,
		})
		local reason = Ui.body(frame, {
			name = "Reason",
			size = UDim2.fromScale(0.9, 0.08),
			position = UDim2.fromScale(0.5, 0.73),
			anchor = Vector2.new(0.5, 0),
			alignX = Enum.TextXAlignment.Center,
			textColor = ROLE.warning,
			maxText = 16,
			minText = 7,
			zindex = Z + 3,
		})
		local entry: PetCard
		local button = Ui.button(frame, {
			name = "Action",
			size = UDim2.fromScale(0.84, 0.13),
			position = UDim2.fromScale(0.5, 0.83),
			anchor = Vector2.new(0.5, 0),
			color = ROLE.reward,
			icon = Ui.Icons.coin,
			corner = 0.35,
			stroke = 2,
			maxText = 24,
			zindex = Z + 3,
		}, function()
			local base = getBase()
			if base == nil or os.clock() - entry.lastPress < PRESS_COOLDOWN then
				return
			end
			if entry.mode == "buy" then
				local owned = ownedPets(base)
				if not BaseBuild.canBuyPet(MissionData, owned, base.level, base.credits, def.id) then
					return
				end
				entry.lastPress = os.clock()
				local action: any = { type = "BuyPet", id = def.id }
				Store.send(action)
			elseif entry.mode == "use" then
				entry.lastPress = os.clock()
				local action: any = { type = "Equip", slot = "pet", value = def.id }
				Store.send(action)
			end
		end)
		entry = {
			id = def.id,
			stroke = stroke,
			preview = preview,
			lock = lock,
			name = name,
			how = how,
			reason = reason,
			button = button,
			mode = "none",
			lastPress = -math.huge,
		}
		table.insert(petCards, entry)
	end

	local function renderPets(base: BaseState)
		petTitle.Text = Store.t("panel.tab_pets")
		petHint.Text = Store.t("panel.pets_hint")
		local owned = ownedPets(base)
		local equipped: any = base.equipped
		local wearing = if type(equipped) == "table" and type(equipped.pet) == "string" then equipped.pet else "none"
		for _, entry in petCards do
			local def = BaseBuild.petDef(MissionData, entry.id)
			if def == nil then
				continue
			end
			local has = owned[entry.id] == true
			entry.name.Text = Store.t("pet." .. entry.id .. ".name")
			if entry.preview then
				entry.preview.setLocked(not has)
			end
			entry.lock.Visible = not has
			if has then
				entry.how.Text = Store.t("petfact." .. entry.id) -- a true fact about the pet it is based on
			elseif def.collectible then
				entry.how.Text = Store.t("panel.pet_secret")
			else
				entry.how.Text = Store.t("panel.pet_price", { n = def.cost or 0, level = def.minLevel or 1 })
			end
			if has then
				local inUse = wearing == entry.id
				if inUse then
					entry.mode = "none"
				else
					entry.mode = "use"
				end
				Ui.setButton(entry.button, Store.t(if inUse then "panel.in_use" else "panel.use"), Ui.ICONS.check)
				Ui.setButtonLook(entry.button, true, if inUse then Ui.COLORS.secondary else ROLE.good)
				entry.button.AutoButtonColor = not inUse
				entry.button.Visible = true
				entry.reason.Text = Store.t("panel.owned")
				entry.reason.TextColor3 = ROLE.good
				entry.stroke.Color = if inUse then ROLE.reward else ROLE.good
			elseif def.collectible then
				-- Found, never bought: no button, the text says where to look.
				entry.mode = "none"
				entry.button.Visible = false
				entry.reason.Text = ""
				entry.stroke.Color = ROLE.stroke
			else
				local allowed, reason = BaseBuild.canBuyPet(MissionData, owned, base.level, base.credits, entry.id)
				if allowed then
					entry.mode = "buy"
				else
					entry.mode = "none"
				end
				entry.button.Visible = true
				Ui.setButton(entry.button, Store.t("panel.buy"), if allowed then Ui.Icons.coin else Ui.ICONS.lock)
				Ui.setButtonLook(entry.button, allowed, ROLE.reward)
				local params: Params = {}
				if reason == "level" then
					params.n = def.minLevel or 1
					params.level = def.minLevel or 1
				elseif reason == "credits" then
					params.n = def.cost or 0
					params.cost = def.cost or 0
				end
				entry.reason.Text = if allowed then "" else reasonText(reason, params)
				entry.reason.TextColor3 = ROLE.warning
				entry.stroke.Color = if allowed then ROLE.good else ROLE.stroke
			end
		end
	end

	-- Spin the pet previews while the Pets tab is showing.
	local spinConnection: RBXScriptConnection? = nil
	local function updateSpin()
		local wanted = modal.Visible and currentTab == "pets"
		if wanted and spinConnection == nil then
			spinConnection = RunService.RenderStepped:Connect(function()
				local angle = 0.5 + math.sin(os.clock() * SPIN_SPEED) * 0.9
				for _, entry in petCards do
					if entry.preview then
						entry.preview.setAngle(angle)
					end
				end
			end)
		elseif not wanted and spinConnection ~= nil then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end
	modal:GetPropertyChangedSignal("Visible"):Connect(updateSpin)

	-----------------------------------------------------------------------------------------------
	-- Render
	-----------------------------------------------------------------------------------------------
	local function renderHeader(base: BaseState?)
		title.Text = Store.t("panel.base_title")
		for _, tab in TABS do
			local button = tabButtons[tab.id]
			Ui.setButton(button, Store.t(tab.key))
			Ui.setButtonColor(button, if currentTab == tab.id then tab.color else Ui.COLORS.secondary)
		end
		Ui.setButton(collectButton, Store.t("panel.collect"))
		if base == nil then
			credits.label.Text = "-"
			levelPill.label.Text = Store.t("panel.level", { n = 1 })
			xpLabel.Text = ""
			xpFill.Size = UDim2.fromScale(0, 1)
			icePill.label.Text = Store.t("panel.ice_rate", { n = 0 })
			siloPill.label.Text = Store.t("panel.silo", { n = 0, max = BASE.SILO_MAX })
			Ui.setButtonLook(collectButton, false, Ui.COLORS.go)
			return
		end
		credits.label.Text = formatNumber(math.floor(base.credits))
		levelPill.label.Text = Store.t("panel.level", { n = base.level })
		local nextXp = base.nextLevelXp
		if nextXp ~= nil and nextXp > base.levelXp then
			xpLabel.Text = Store.t("panel.xp", { n = math.floor(base.xp), max = nextXp })
			xpFill.Size = UDim2.fromScale(math.clamp((base.xp - base.levelXp) / (nextXp - base.levelXp), 0, 1), 1)
		else
			xpLabel.Text = Store.t("panel.level_top")
			xpFill.Size = UDim2.fromScale(1, 1)
		end
		xpFill.Visible = xpFill.Size.X.Scale > 0.005
		icePill.label.Text = Store.t("panel.ice_rate", { n = formatNumber(base.icePerMinute) })
		local siloMax = if base.siloMax > 0 then base.siloMax else BASE.SILO_MAX
		siloPill.label.Text = Store.t("panel.silo", { n = math.floor(base.siloIce), max = siloMax })
		local canClaim = base.siloIce >= 1
		Ui.setButtonLook(collectButton, canClaim, Ui.COLORS.go)
		siloPill.label.TextColor3 = if base.siloIce >= siloMax then ROLE.warning else ROLE.text
	end

	render = function()
		local base = getBase()
		renderHeader(base)
		waiting.Text = Store.t("panel.waiting")
		waiting.Visible = base == nil
		for _, tab in TABS do
			pages[tab.id].Visible = base ~= nil and currentTab == tab.id
		end
		if base ~= nil then
			if currentTab == "base" then
				renderBuilds(base)
			elseif currentTab == "skills" then
				renderSkills(base)
			else
				renderPets(base)
			end
		end
		updateSpin()
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		local name: string = kind
		if not modal.Visible then
			-- Remember levels while closed too, so opening never "pops" an old upgrade.
			if name == "base" then
				local base = getBase()
				if base then
					for id, value in base.builds do
						shownLevels[id] = value
					end
					for id, value in base.skills do
						shownSkills[id] = value
					end
				end
			end
			return
		end
		if name == "base" or name == "progress" or name == "language" then
			render()
		end
	end)

	local function open()
		modal.Visible = true
		render()
	end

	local function openTab(tab: Tab)
		currentTab = tab
		open()
	end

	local function isOpen(): boolean
		return modal.Visible
	end

	render()
	return { open = open, close = close, isOpen = isOpen, openTab = openTab, render = render }
end

return BasePanel
