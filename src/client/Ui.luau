--!strict
-- Space Base Odyssey - shared UI building blocks in the "Lunar Sunrise" identity: Theme colours and fonts,
-- game icons (Icons.luau images tinted with Theme), scaled root, panels, labels, buttons and bars.
-- No emoji anywhere: every pictogram is an ImageLabel from src/shared/Icons.luau.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Icons = require(Shared:WaitForChild("Icons"))
local Audio = require(script.Parent:WaitForChild("Audio")) -- Stage 11 audio
local Store = require(script.Parent:WaitForChild("Store")) -- Stage 11 menu: Store.textScale (Store never requires Ui)

local Ui = {}

-- Layout is designed for a 720-unit tall screen; a UIScale maps it to the real viewport height.
local REFERENCE_HEIGHT = 720
local MIN_SCALE = 0.4
local MAX_SCALE = 2.5

local ROLE = Theme.ROLE
local PALETTE = Theme.PALETTE

Ui.Theme = Theme
Ui.Icons = Icons
Ui.ROLE = ROLE
Ui.FONT = Theme.FONT.display -- titles and buttons
Ui.BODY_FONT = Theme.FONT.body -- body text
Ui.CORNER = Theme.CORNER.Scale
Ui.STROKE = Theme.STROKE_THICKNESS

-- Named colours used by the screens, all taken from the Theme (never raw RGB in screen code).
Ui.COLORS = table.freeze({
	backdrop = ROLE.background,
	panel = ROLE.panel,
	panelLight = ROLE.panelRaised,
	stroke = ROLE.stroke,
	text = ROLE.text,
	textDark = ROLE.primaryButtonText,
	textSoft = ROLE.textDim,
	accent = ROLE.accent,
	go = ROLE.primaryButton,
	secondary = ROLE.secondaryButton,
	disabled = ROLE.stroke,
	barBack = ROLE.background,
	cell = PALETTE.gold,
	cellEmpty = ROLE.stroke,
	warning = ROLE.warning,
	storm = ROLE.danger,
	reward = ROLE.reward,
	star = ROLE.star,
	ice = PALETTE.cyan,
	outline = ROLE.background,
	zoneGreen = ROLE.zoneGreen,
	zoneYellow = ROLE.zoneYellow,
	zoneRed = ROLE.zoneRed,
})

-- Icons by game meaning (values are rbxassetid images from Icons.luau).
Ui.ICONS = table.freeze({
	air = Icons.air,
	food = Icons.food,
	dose = Icons.dose,
	suit = Icons.suit,
	LifeSupport = Icons.lifesupport,
	Greenhouse = Icons.greenhouse,
	Science = Icons.science,
	cell = Icons.power,
	ice = Icons.ice,
	drop = Icons.drop,
	timer = Icons.clock,
	warning = Icons.alert,
	storm = Icons.storm,
	shelter = Icons.shield,
	star = Icons.star,
	starEmpty = Icons.starEmpty,
	rocket = Icons.rocket,
	restart = Icons.restart,
	language = Icons.language,
	run = Icons.run,
	robot = Icons.robot,
	moon = Icons.calm,
	antenna = Icons.antenna,
	satellite = Icons.satellite,
	close = Icons.close,
	data = Icons.data,
	pointer = Icons.pointer,
	hourglass = Icons.hourglass,
	lock = Icons.lock,
	check = Icons.check,
	trophy = Icons.trophy,
	gift = Icons.gift,
	telescope = Icons.telescope,
	book = Icons.book,
	planet = Icons.planet,
	target = Icons.target,
	home = Icons.home,
	play = Icons.play,
	map = Icons.map,
	flag = Icons.flag,
	panel = Icons.panel,
	repair = Icons.repair,
})

Ui.EVENT_ICONS = table.freeze({
	None = Icons.calm,
	Dust = Icons.dust,
	SolarStorm = Icons.storm,
	EquipmentFailure = Icons.failure,
})

Ui.EVENT_COLORS = table.freeze({
	None = ROLE.accent,
	Dust = ROLE.warning,
	SolarStorm = ROLE.warning,
	EquipmentFailure = ROLE.warning,
})

-- Shape icons for meter zones, so the state is readable without colour.
Ui.ZONE_ICONS = table.freeze({
	green = Icons.check,
	yellow = Icons.alert,
	red = Icons.close,
})

-- Colour per system (and its icon tint).
Ui.SYSTEM_COLORS = table.freeze({
	LifeSupport = ROLE.LifeSupport,
	Greenhouse = ROLE.Greenhouse,
	Science = ROLE.Science,
})

-- Accent colour per mission kind: training = cyan (guidance), story = orange (sunrise), free = lime (go).
Ui.KIND_COLORS = table.freeze({
	Tutorial = PALETTE.cyan,
	Story = PALETTE.orange,
	Free = PALETTE.lime,
})

-- Image for an Icons.luau key (e.g. from a Snapshot); unknown names fall back to the star.
function Ui.iconImage(name: string?): string
	if type(name) == "string" then
		local image = (Icons :: any)[name]
		if type(image) == "string" then
			return image
		end
	end
	return Icons.star
end

function Ui.zoneColor(zone: string): Color3
	if zone == "red" then
		return Ui.COLORS.zoneRed
	elseif zone == "yellow" then
		return Ui.COLORS.zoneYellow
	end
	return Ui.COLORS.zoneGreen
end

-- Readable text colour on a filled background: night on bright colours, cream on dark ones.
function Ui.contrastText(background: Color3): Color3
	local luminance = 0.2126 * background.R + 0.7152 * background.G + 0.0722 * background.B
	return if luminance > 0.45 then ROLE.primaryButtonText else ROLE.text
end

-- Current UIScale of the root (offsets inside the root are in reference units).
local currentScale = 1
function Ui.scale(): number
	return currentScale
end

-- Stage 11 phones: text is never smaller than READABLE_TEXT_PIXELS real pixels (the old floor of
-- 7-10 units became 4-5 pixels on a landscape phone). Touch-only devices also lay out for a smaller
-- reference height, so the whole UI (text limits, strokes, touch targets) is about 1.3x bigger there.
-- Every text minimum made here goes through readableMin; createRoot re-applies them on resize.
local READABLE_TEXT_PIXELS = 11
local TOUCH_REFERENCE_HEIGHT = 560
local function readableFloor(): number
	return math.ceil(READABLE_TEXT_PIXELS / math.max(currentScale, 0.01))
end
-- A text minimum raised to the readable floor (never above the label's own maximum).
local function readableMin(minText: number, maxText: number): number
	return math.min(maxText, math.max(minText, readableFloor()))
end
-- The floor is in root units, so it only applies inside the scaled root (createRoot sets it):
-- world signs (BillboardGuis) and other ScreenGuis keep their own minimums.
local floorRoot: Instance? = nil
local function floorApplies(object: Instance): boolean
	local scaledRoot = floorRoot
	return scaledRoot ~= nil and object:IsDescendantOf(scaledRoot)
end
local function touchOnly(): boolean
	local ok, result = pcall(function(): boolean
		local input = game:GetService("UserInputService")
		return input.TouchEnabled and not input.KeyboardEnabled and not input.GamepadEnabled
	end)
	return ok and result == true
end
local refreshTextFloor: () -> () = function() end -- set at the end of this module

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
	icon: string?, -- image (rbxassetid) for Ui.icon / Ui.button
	tint: Color3?, -- ImageColor3 for icons
}

function Ui.corner(object: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius or Ui.CORNER, 0)
	corner.Parent = object
end

function Ui.stroke(object: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness or Ui.STROKE
	stroke.Color = color or ROLE.stroke
	stroke.Parent = object
	return stroke
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

-- Soft vertical gradient on a panel (subtle depth; transparency only, colours stay Theme colours).
function Ui.sheen(object: GuiObject)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.18),
	})
	gradient.Parent = object
end

local function applyBase(object: GuiObject, props: Props)
	if props.name then
		object.Name = props.name
	end
	object.Size = props.size or UDim2.fromScale(1, 1)
	object.Position = props.position or UDim2.fromScale(0, 0)
	object.AnchorPoint = props.anchor or Vector2.zero
	object.BackgroundColor3 = props.color or ROLE.panel
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

-- Stage 11 menu: "Big text" (Settings, accessibility page). Store.textScale() multiplies the text
-- size limits of every label made here and of every Ui.button (1 = normal); a change re-applies them.
local textScale = 1
-- `setMax` / `setMin` are the sizes this hook last wrote: a module that later sets its own sizes (Hud
-- signs, the Achievements tiles) makes those its new base instead of being reset to Ui's.
type TextBase = { max: number, min: number, setMax: number, setMin: number }
local textBases: { [UITextSizeConstraint]: TextBase } = setmetatable({}, { __mode = "k" }) :: any
local oneLineFits: { [TextLabel]: () -> () } = setmetatable({}, { __mode = "k" }) :: any -- Ui.oneLine labels
local function scaledSizes(maxText: number, minText: number, floored: boolean): (number, number)
	local maxSize = math.floor(maxText * textScale + 0.5)
	local minSize = math.floor(minText * textScale + 0.5)
	return maxSize, if floored then readableMin(minSize, maxSize) else math.min(minSize, maxSize) -- Stage 11 phones: readable floor
end
local function scaleConstraint(constraint: UITextSizeConstraint, base: TextBase)
	if constraint.MaxTextSize ~= base.setMax then
		base.max = constraint.MaxTextSize
	end
	if constraint.MinTextSize ~= base.setMin then
		base.min = constraint.MinTextSize
	end
	local maxText, minText = scaledSizes(base.max, base.min, floorApplies(constraint))
	constraint.MaxTextSize = maxText
	constraint.MinTextSize = minText
	base.setMax, base.setMin = constraint.MaxTextSize, constraint.MinTextSize
end
local function trackTextSize(constraint: UITextSizeConstraint)
	local base: TextBase = {
		max = constraint.MaxTextSize,
		min = constraint.MinTextSize,
		setMax = constraint.MaxTextSize,
		setMin = constraint.MinTextSize,
	}
	textBases[constraint] = base
	if textScale ~= 1 then
		scaleConstraint(constraint, base)
	end
	-- Stage 11 phones: the label is parented right after this; then raise it to the readable floor.
	task.defer(function()
		if textBases[constraint] == base and readableFloor() > base.min and floorApplies(constraint) then
			scaleConstraint(constraint, base)
		end
	end)
end
-- The current factor (Ui.oneLine and screens with their own text sizes can read it).
function Ui.textScale(): number
	return textScale
end

local function applyText(object: TextLabel | TextButton, props: Props)
	local target: any = object
	target.Font = props.font or Ui.FONT
	target.Text = props.text or ""
	target.TextColor3 = props.textColor or ROLE.text
	target.TextScaled = true
	target.TextWrapped = true
	target.RichText = false
	target.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	target.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	target.TextStrokeColor3 = ROLE.background
	target.TextStrokeTransparency = if props.outline then 0.35 else 1
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = props.maxText or 40
	constraint.MinTextSize = props.minText or 10
	trackTextSize(constraint) -- Stage 11 menu: "Big text" scales it
	constraint.Parent = object
end

function Ui.frame(parent: Instance, props: Props): Frame
	local frame = Instance.new("Frame")
	applyBase(frame, props)
	frame.Parent = parent
	return frame
end

-- A rounded Theme panel: night (or raised) fill, Theme stroke and corner.
function Ui.panel(parent: Instance, props: Props): Frame
	local withDefaults: Props = table.clone(props)
	withDefaults.color = props.color or ROLE.panel
	withDefaults.corner = props.corner or Ui.CORNER
	withDefaults.stroke = props.stroke or Ui.STROKE
	withDefaults.strokeColor = props.strokeColor or ROLE.stroke
	return Ui.frame(parent, withDefaults)
end

-- Text label; titles use the display font, `font = Ui.BODY_FONT` for body text.
function Ui.label(parent: Instance, props: Props): TextLabel
	local label = Instance.new("TextLabel")
	applyBase(label, props)
	applyText(label, props)
	label.Parent = parent
	return label
end

-- Body-text label (readable font, left aligned by default).
function Ui.body(parent: Instance, props: Props): TextLabel
	local withDefaults: Props = table.clone(props)
	withDefaults.font = props.font or Ui.BODY_FONT
	withDefaults.alignX = props.alignX or Enum.TextXAlignment.Left
	withDefaults.textColor = props.textColor or ROLE.text
	return Ui.label(parent, withDefaults)
end

-- Game icon: an image from Icons.luau, fitted inside its box and tinted with a Theme colour.
function Ui.icon(parent: Instance, image: string, props: Props): ImageLabel
	local icon = Instance.new("ImageLabel")
	applyBase(icon, props)
	icon.Image = image
	icon.ImageColor3 = props.tint or ROLE.text
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

function Ui.setIcon(icon: ImageLabel, image: string, tint: Color3?)
	icon.Image = image
	if tint then
		icon.ImageColor3 = tint
	end
end

-- Buttons: a TextButton with no text of its own; an "Icon" ImageLabel and a "Label" TextLabel inside
-- are laid out as one centred group (icon then text), sized from the button's real size.
type ButtonParts = {
	label: TextLabel,
	icon: ImageLabel,
	maxText: number,
	minText: number,
}
local buttonParts: { [TextButton]: ButtonParts } = setmetatable({}, { __mode = "k" }) :: any

local ICON_HEIGHT = 0.56
local ICON_GAP = 0.16
local BUTTON_MARGIN = 0.22
local TEXT_HEIGHT = 0.46

local function layoutButton(button: TextButton)
	local parts = buttonParts[button]
	if not parts then
		return
	end
	local scale = math.max(currentScale, 0.01)
	local width = button.AbsoluteSize.X / scale
	local height = button.AbsoluteSize.Y / scale
	if width <= 2 or height <= 2 then
		return
	end
	local label = parts.label
	local icon = parts.icon
	local hasIcon = icon.Image ~= ""
	local hasText = label.Text ~= ""
	icon.Visible = hasIcon
	local iconSize = if hasIcon then height * ICON_HEIGHT else 0
	if hasIcon and not hasText then
		iconSize = height * 0.66
	end
	local gap = if hasIcon and hasText then height * ICON_GAP else 0
	local margin = math.min(height * BUTTON_MARGIN, width * 0.08)
	local available = math.max(4, width - margin * 2 - iconSize - gap)
	local maxText, minText = scaledSizes(parts.maxText, parts.minText, floorApplies(button)) -- Stage 11 menu: big text
	local textSize = math.clamp(math.floor(height * TEXT_HEIGHT * textScale), minText, maxText)
	local textWidth = 0
	if hasText then
		local ok, bounds = pcall(function(): Vector2
			return TextService:GetTextSize(label.Text, textSize, label.Font, Vector2.new(10000, 10000))
		end)
		textWidth = if ok then bounds.X else available
		if textWidth > available then
			textSize = math.max(parts.minText, math.floor(textSize * available / textWidth))
			local ok2, bounds2 = pcall(function(): Vector2
				return TextService:GetTextSize(label.Text, textSize, label.Font, Vector2.new(10000, 10000))
			end)
			textWidth = if ok2 then bounds2.X else available
		end
	end
	local shownWidth = math.min(textWidth + 2, available)
	local groupWidth = iconSize + gap + shownWidth
	local startX = (width - groupWidth) / 2
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	icon.Position = UDim2.fromOffset(startX, height / 2)
	label.TextScaled = false
	label.TextSize = textSize
	label.Size = UDim2.fromOffset(shownWidth, height * 0.92)
	label.Position = UDim2.fromOffset(startX + iconSize + gap, height / 2)
end

-- A big friendly button. `onClick` runs on mouse click and on touch tap.
-- Default look: primary (lime with night text). Pass `color` for other roles.
function Ui.button(parent: Instance, props: Props, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	local withDefaults: Props = table.clone(props)
	withDefaults.color = props.color or ROLE.primaryButton
	withDefaults.corner = props.corner or Ui.CORNER
	withDefaults.stroke = props.stroke or Ui.STROKE
	withDefaults.strokeColor = props.strokeColor or ROLE.stroke
	applyBase(button, withDefaults)
	button.Text = ""
	button.AutoButtonColor = true
	button.Selectable = true

	local textColor = props.textColor or Ui.contrastText(withDefaults.color :: Color3)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Font = props.font or Ui.FONT
	label.Text = props.text or ""
	label.TextColor3 = textColor
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = ROLE.background
	label.TextStrokeTransparency = if props.outline then 0.4 else 1
	label.ZIndex = withDefaults.zindex or 1
	label.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = props.icon or ""
	icon.ImageColor3 = props.tint or textColor
	icon.ZIndex = withDefaults.zindex or 1
	icon.Parent = button

	buttonParts[button] = {
		label = label,
		icon = icon,
		maxText = props.maxText or 40,
		minText = props.minText or 10,
	}
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layoutButton(button)
	end)
	-- Stage 11 audio: a click (a "no" sound on a greyed-out button); close buttons leave it to the
	-- panel's close sound (Ui.modal).
	button.Activated:Connect(function()
		if props.icon ~= Icons.close then
			Audio.play(if button.AutoButtonColor then "ui_click" else "ui_error")
		end
		onClick()
	end)
	button.Parent = parent
	layoutButton(button)
	return button
end

-- Change a button's text and (optionally) its icon image.
function Ui.setButton(button: TextButton, text: string, image: string?)
	local parts = buttonParts[button]
	if not parts then
		return
	end
	parts.label.Text = text
	if image ~= nil then
		parts.icon.Image = image
	end
	layoutButton(button)
end

-- Visual enabled/disabled look; the click handler decides what a "disabled" click does.
function Ui.setButtonLook(button: TextButton, enabled: boolean, color: Color3)
	button.BackgroundColor3 = if enabled then color else Ui.COLORS.disabled
	button.AutoButtonColor = enabled
	local parts = buttonParts[button]
	if parts then
		local textColor = if enabled then Ui.contrastText(color) else ROLE.textDim
		parts.label.TextColor3 = textColor
		parts.label.TextTransparency = if enabled then 0 else 0.3
		parts.icon.ImageColor3 = textColor
		parts.icon.ImageTransparency = if enabled then 0 else 0.3
	end
end

-- Recolour a button for a new role (fill, text and icon follow).
function Ui.setButtonColor(button: TextButton, color: Color3)
	Ui.setButtonLook(button, true, color)
end

export type IconText = {
	frame: Frame,
	icon: ImageLabel,
	label: TextLabel,
	set: (image: string, text: string, tint: Color3?) -> (),
}

-- A pill with an icon on the left and text on the right (e.g. today's event banner).
function Ui.iconText(parent: Instance, props: Props): IconText
	local withDefaults: Props = table.clone(props)
	withDefaults.corner = props.corner or 0.3
	withDefaults.strokeColor = props.strokeColor or ROLE.stroke
	local frame = Ui.frame(parent, withDefaults)
	local textColor = props.textColor or ROLE.text
	local icon = Ui.icon(frame, props.icon or "", {
		name = "Icon",
		size = UDim2.fromScale(0.16, 0.7),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = props.tint or textColor,
		zindex = (props.zindex or 1) + 1,
	})
	local label = Ui.label(frame, {
		name = "Text",
		size = UDim2.fromScale(0.77, 0.8),
		position = UDim2.fromScale(0.21, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = textColor,
		maxText = props.maxText or 32,
		outline = props.outline,
		font = props.font,
		zindex = (props.zindex or 1) + 1,
	})
	local function set(image: string, text: string, tint: Color3?)
		icon.Image = image
		if tint then
			icon.ImageColor3 = tint
		end
		label.Text = text
	end
	return { frame = frame, icon = icon, label = label, set = set }
end

export type Bar = {
	frame: Frame,
	fill: Frame,
	label: TextLabel,
	zone: ImageLabel,
	set: (fraction: number, color: Color3, text: string, zoneImage: string?) -> (),
}

-- A rounded progress bar with the value text and a zone shape icon on top of the fill.
function Ui.bar(parent: Instance, props: Props): Bar
	local withDefaults: Props = table.clone(props)
	withDefaults.color = props.color or Ui.COLORS.barBack
	withDefaults.corner = props.corner or 0.5
	withDefaults.stroke = props.stroke or 2
	local frame = Ui.frame(parent, withDefaults)
	local fill = Ui.frame(frame, { name = "Fill", size = UDim2.fromScale(1, 1), color = Ui.COLORS.zoneGreen, corner = 0.5 })
	local label = Ui.label(frame, {
		name = "Value",
		size = UDim2.fromScale(0.62, 0.86),
		position = UDim2.fromScale(0.06, 0.5),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		maxText = props.maxText or 30,
		outline = true,
		zindex = 2,
	})
	-- Zone shape in a small night badge at the right end, readable over any fill colour.
	local zone = Ui.icon(frame, "", {
		name = "Zone",
		size = UDim2.fromScale(0.9, 0.9),
		position = UDim2.fromScale(0.985, 0.5),
		anchor = Vector2.new(1, 0.5),
		color = ROLE.background,
		corner = 0.5,
		aspect = 1,
		tint = ROLE.text,
		zindex = 2,
	})
	local function set(fraction: number, color: Color3, text: string, zoneImage: string?)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.BackgroundColor3 = color
		fill.Visible = fraction > 0.005
		label.Text = text
		zone.Image = zoneImage or ""
		zone.Visible = zoneImage ~= nil
		zone.ImageColor3 = color
	end
	return { frame = frame, fill = fill, label = label, zone = zone, set = set }
end

-- A dark full-screen backdrop that blocks taps to the screen underneath (for modal cards).
function Ui.modal(parent: Instance, name: string, zindex: number): Frame
	local frame = Ui.frame(parent, {
		name = name,
		color = ROLE.background,
		transparency = 0.25,
		zindex = zindex,
		visible = false,
	})
	frame.Active = true
	frame:GetPropertyChangedSignal("Visible"):Connect(function() -- Stage 11 audio: open / close
		Audio.play(if frame.Visible then "ui_open" else "ui_close")
	end)
	return frame
end

-- A ScreenGui plus a root Frame whose UIScale follows the viewport height. Everything inside the root
-- uses scale sizes; the UIScale keeps strokes and text limits proportional on phones and big screens.
function Ui.createRoot(playerGui: Instance): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpaceBaseOdysseyUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Stage 11 phones: keep the game UI out of the notch and rounded corners (DeviceSafeInsets). The
	-- area under Roblox's top bar stays ours: the HUD already starts below GuiService.TopbarInset, so
	-- CoreUISafeInsets would push it down twice. Full-screen layers (the cinematic fade, celebrations,
	-- the storm edge pulse) are their own ScreenGuis with ScreenInsets None.
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
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
	floorRoot = root -- Stage 11 phones: the readable text floor applies inside this root

	local cameraConnection: RBXScriptConnection? = nil
	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, REFERENCE_HEIGHT)
		-- Stage 11 phones: the safe area (the ScreenGui's own size) once it is known.
		local area = gui.AbsoluteSize
		if area.X > 0 and area.Y > 0 then
			viewport = area
		end
		if viewport.Y <= 0 then
			return
		end
		local reference = if touchOnly() then TOUCH_REFERENCE_HEIGHT else REFERENCE_HEIGHT -- Stage 11 phones
		local scale = math.clamp(viewport.Y / reference, MIN_SCALE, MAX_SCALE)
		local changed = scale ~= currentScale
		currentScale = scale
		uiScale.Scale = scale
		root.Size = UDim2.fromOffset(viewport.X / scale, viewport.Y / scale)
		if changed then
			refreshTextFloor() -- Stage 11 phones: the readable floor follows the scale
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize) -- Stage 11 phones
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

-- A label that stays on ONE line at the biggest size that fits its box. Roblox's TextScaled with
-- TextWrapped off picked the minimum size for short names (team playtest: tiny "Laboratorio" and skill
-- names), so the size is measured here with TextService instead.
function Ui.oneLine(label: TextLabel)
	label.TextWrapped = false
	label.TextScaled = false
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	-- Stage 11 menu: this label fits itself, so "Big text" only raises its top size (read per fit).
	local base = if constraint then textBases[constraint] else nil
	if constraint then
		textBases[constraint] = nil
	end
	local baseMax = if base then base.max elseif constraint then constraint.MaxTextSize else 40
	local minSize = 8
	if constraint then
		constraint.MinTextSize = math.min(constraint.MinTextSize, minSize)
	end
	local function fit()
		-- Stage 11 phones: AbsoluteSize is in real pixels, TextSize in reference units (the root's
		-- UIScale multiplies it), so measure the box in reference units, like layoutButton does.
		local box = label.AbsoluteSize / math.max(currentScale, 0.01)
		if box.X <= 0 or box.Y <= 0 then
			return
		end
		local maxSize = math.floor(baseMax * textScale + 0.5)
		if constraint and constraint.MaxTextSize ~= maxSize then
			constraint.MaxTextSize = maxSize
		end
		local size = math.max(minSize, math.min(maxSize, math.floor(box.Y * 0.9)))
		while size > minSize and TextService:GetTextSize(label.Text, size, label.Font, Vector2.new(100000, 100000)).X > box.X do
			size -= 1
		end
		label.TextSize = size
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	oneLineFits[label] = fit -- Stage 11 menu
	fit()
end

-- Stage 11 menu: follow the "Big text" setting (Store.textScale) for everything made with Ui.
local function applyTextScale()
	local wanted = Store.textScale()
	if wanted == textScale then
		return
	end
	textScale = wanted
	for constraint, base in textBases do
		scaleConstraint(constraint, base)
	end
	for button in buttonParts do
		layoutButton(button)
	end
	for _, fit in oneLineFits do
		fit()
	end
end
Store.onChanged(function(kind: string)
	if kind == "settings" then
		applyTextScale()
	end
end)
applyTextScale()

-- Stage 11 phones: a new UI scale moves the readable floor; re-apply every text size made here.
refreshTextFloor = function()
	for constraint, base in textBases do
		scaleConstraint(constraint, base)
	end
	for button in buttonParts do
		layoutButton(button)
	end
	for _, fit in oneLineFits do
		fit()
	end
end

return table.freeze(Ui)
