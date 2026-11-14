--!strict
-- Space Base Odyssey - shared UI building blocks: theme, icons, scaled root, labels, buttons and bars.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Ui = {}

-- Layout is designed for a 720-unit tall screen; a UIScale maps it to the real viewport height.
local REFERENCE_HEIGHT = 720
local MIN_SCALE = 0.4
local MAX_SCALE = 2.5

Ui.FONT = Enum.Font.FredokaOne

Ui.COLORS = table.freeze({
	backdrop = Color3.fromRGB(6, 8, 22),
	panel = Color3.fromRGB(22, 28, 56),
	panelLight = Color3.fromRGB(42, 52, 96),
	text = Color3.fromRGB(255, 255, 255),
	textDark = Color3.fromRGB(16, 18, 30),
	textSoft = Color3.fromRGB(196, 206, 240),
	accent = Color3.fromRGB(255, 200, 40),
	go = Color3.fromRGB(38, 186, 96),
	minus = Color3.fromRGB(222, 72, 60),
	plus = Color3.fromRGB(46, 140, 230),
	disabled = Color3.fromRGB(86, 90, 108),
	barBack = Color3.fromRGB(12, 14, 28),
	cell = Color3.fromRGB(255, 214, 10),
	cellEmpty = Color3.fromRGB(52, 58, 84),
	warning = Color3.fromRGB(255, 150, 0),
	storm = Color3.fromRGB(205, 36, 46),
	bubble = Color3.fromRGB(238, 246, 255),
	ice = Color3.fromRGB(150, 220, 255),
	outline = Color3.fromRGB(0, 0, 0),
	zoneGreen = Color3.fromRGB(46, 204, 113),
	zoneYellow = Color3.fromRGB(245, 196, 30),
	zoneRed = Color3.fromRGB(232, 60, 60),
})

-- Emoji glyphs used as icons next to text (never colour alone).
Ui.ICONS = table.freeze({
	air = "💨",
	food = "🍎",
	dose = "☢️",
	suit = "💨",
	LifeSupport = "💨",
	Greenhouse = "🌱",
	Science = "🔬",
	cell = "⚡",
	ice = "🧊",
	timer = "⏱️",
	warning = "⚠️",
	storm = "☢️",
	shelter = "🛡️",
	star = "⭐",
	rocket = "🚀",
	restart = "🔄",
	language = "🌐",
	run = "🏃",
	walk = "🚶",
	robot = "🤖",
	moon = "🌙",
})

Ui.EVENT_ICONS = table.freeze({
	None = "🌙",
	Dust = "🌫️",
	SolarStorm = "☀️",
	EquipmentFailure = "🔧",
})

-- Shape icons for meter zones, so the state is readable without colour.
Ui.ZONE_ICONS = table.freeze({
	green = "👍",
	yellow = "⚠️",
	red = "🚨",
})

function Ui.zoneColor(zone: string): Color3
	if zone == "red" then
		return Ui.COLORS.zoneRed
	elseif zone == "yellow" then
		return Ui.COLORS.zoneYellow
	end
	return Ui.COLORS.zoneGreen
end

export type Props = {
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	zindex: number?,
	order: number?,
	visible: boolean?,
	corner: number?, -- UICorner radius as a fraction of the shorter side
	stroke: number?, -- UIStroke thickness (unscaled pixels)
	strokeColor: Color3?,
	aspect: number?, -- width / height
	text: string?,
	textColor: Color3?,
	maxText: number?,
	minText: number?,
	alignX: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	font: Enum.Font?,
	outline: boolean?, -- dark text outline for text drawn over the 3D world
}

function Ui.corner(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = object
end

function Ui.stroke(object: GuiObject, thickness: number, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness
	stroke.Color = color or Ui.COLORS.outline
	stroke.Parent = object
end

function Ui.aspect(object: GuiObject, ratio: number)
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio
	constraint.Parent = object
end

function Ui.padding(object: GuiObject, fraction: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(fraction, 0)
	padding.PaddingRight = UDim.new(fraction, 0)
	padding.PaddingTop = UDim.new(fraction, 0)
	padding.PaddingBottom = UDim.new(fraction, 0)
	padding.Parent = object
end

local function applyBase(object: GuiObject, props: Props)
	if props.name then
		object.Name = props.name
	end
	object.Size = props.size or UDim2.fromScale(1, 1)
	object.Position = props.position or UDim2.fromScale(0, 0)
	object.AnchorPoint = props.anchor or Vector2.zero
	object.BackgroundColor3 = props.color or Ui.COLORS.panel
	object.BackgroundTransparency = props.transparency or (if props.color then 0 else 1)
	object.BorderSizePixel = 0
	object.ZIndex = props.zindex or 1
	object.LayoutOrder = props.order or 0
	object.Visible = if props.visible == nil then true else props.visible
	if props.corner then
		Ui.corner(object, props.corner)
	end
	if props.stroke then
		Ui.stroke(object, props.stroke, props.strokeColor)
	end
	if props.aspect then
		Ui.aspect(object, props.aspect)
	end
end

local function applyText(object: TextLabel | TextButton, props: Props)
	local target: any = object
	target.Font = props.font or Ui.FONT
	target.Text = props.text or ""
	target.TextColor3 = props.textColor or Ui.COLORS.text
	target.TextScaled = true
	target.TextWrapped = true
	target.RichText = false
	target.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	target.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	target.TextStrokeColor3 = Ui.COLORS.outline
	target.TextStrokeTransparency = if props.outline then 0.35 else 1
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = props.maxText or 40
	constraint.MinTextSize = props.minText or 10
	constraint.Parent = object
end

function Ui.frame(parent: Instance, props: Props): Frame
	local frame = Instance.new("Frame")
	applyBase(frame, props)
	frame.Parent = parent
	return frame
end

function Ui.label(parent: Instance, props: Props): TextLabel
	local label = Instance.new("TextLabel")
	applyBase(label, props)
	applyText(label, props)
	label.Parent = parent
	return label
end

-- A big friendly button. `onClick` runs on mouse click and on touch tap.
function Ui.button(parent: Instance, props: Props, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	local withDefaults: Props = table.clone(props)
	withDefaults.color = props.color or Ui.COLORS.go
	withDefaults.corner = props.corner or 0.25
	withDefaults.stroke = props.stroke or 3
	withDefaults.maxText = props.maxText or 44
	withDefaults.outline = if props.outline == nil then true else props.outline
	applyBase(button, withDefaults)
	applyText(button, withDefaults)
	button.AutoButtonColor = true
	button.Activated:Connect(onClick)
	button.Parent = parent
	return button
end

-- Visual enabled/disabled look; the click handler decides what a "disabled" click does.
function Ui.setButtonLook(button: TextButton, enabled: boolean, color: Color3)
	button.BackgroundColor3 = if enabled then color else Ui.COLORS.disabled
	button.TextTransparency = if enabled then 0 else 0.35
	button.AutoButtonColor = enabled
end

-- Square emoji icon.
function Ui.icon(parent: Instance, glyph: string, props: Props): TextLabel
	local withDefaults: Props = table.clone(props)
	withDefaults.text = glyph
	withDefaults.maxText = props.maxText or 64
	return Ui.label(parent, withDefaults)
end

export type IconText = {
	frame: Frame,
	icon: TextLabel,
	label: TextLabel,
	set: (glyph: string, text: string) -> (),
}

-- A pill with an emoji icon on the left and text on the right (e.g. today's event banner).
function Ui.iconText(parent: Instance, props: Props): IconText
	local withDefaults: Props = table.clone(props)
	withDefaults.corner = props.corner or 0.3
	local frame = Ui.frame(parent, withDefaults)
	local icon = Ui.icon(frame, "", {
		name = "Icon",
		size = UDim2.fromScale(0.2, 0.86),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		zindex = (props.zindex or 1) + 1,
	})
	local label = Ui.label(frame, {
		name = "Text",
		size = UDim2.fromScale(0.74, 0.86),
		position = UDim2.fromScale(0.24, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = props.textColor,
		maxText = props.maxText or 32,
		outline = props.outline,
		zindex = (props.zindex or 1) + 1,
	})
	local function set(glyph: string, text: string)
		icon.Text = glyph
		label.Text = text
	end
	return { frame = frame, icon = icon, label = label, set = set }
end

export type Bar = {
	frame: Frame,
	fill: Frame,
	label: TextLabel,
	set: (fraction: number, color: Color3, text: string) -> (),
}

-- A rounded progress bar with centred text on top of the fill.
function Ui.bar(parent: Instance, props: Props): Bar
	local withDefaults: Props = table.clone(props)
	withDefaults.color = props.color or Ui.COLORS.barBack
	withDefaults.corner = props.corner or 0.4
	withDefaults.stroke = props.stroke or 2
	local frame = Ui.frame(parent, withDefaults)
	local fill = Ui.frame(frame, { name = "Fill", size = UDim2.fromScale(1, 1), color = Ui.COLORS.zoneGreen, corner = 0.4 })
	local label = Ui.label(frame, {
		name = "Value",
		size = UDim2.fromScale(0.94, 0.86),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		maxText = props.maxText or 30,
		outline = true,
		zindex = 2,
	})
	local function set(fraction: number, color: Color3, text: string)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.BackgroundColor3 = color
		label.Text = text
	end
	return { frame = frame, fill = fill, label = label, set = set }
end

-- A ScreenGui plus a root Frame whose UIScale follows the viewport height. Everything inside the root
-- uses scale sizes; the UIScale keeps strokes and text limits proportional on phones and big screens.
function Ui.createRoot(playerGui: Instance): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpaceBaseOdysseyUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local cameraConnection: RBXScriptConnection? = nil
	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, REFERENCE_HEIGHT)
		if viewport.Y <= 0 then
			return
		end
		local scale = math.clamp(viewport.Y / REFERENCE_HEIGHT, MIN_SCALE, MAX_SCALE)
		uiScale.Scale = scale
		root.Size = UDim2.fromOffset(viewport.X / scale, viewport.Y / scale)
	end
	local function watchCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		end
		resize()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	root.Parent = gui
	gui.Parent = playerGui
	return gui, root
end

return table.freeze(Ui)
