--!strict
-- Space Base Odyssey - detailed models for the player's tools (Stage 7): wrench, ice core drill,
-- electrostatic panel brush, repair kit, tablet and a fresh greenhouse salad. Each one is a Roblox Tool
-- with a Handle and 13-21 welded parts in Theme colours (no assets besides the team's Tabler icons).
-- Model space: the Handle sits at the origin where the hand holds it. With Tool.Grip = identity the
-- hand's grip attachment lines up with the Handle, so in the holding pose +Y is up and -Z points
-- forward, away from the player (Grip only moves the hold point).
-- One part per tool may be animated (`anim`): it hangs on a Weld (named "SBO_AnimWeld") so
-- ToolService can spin it (drill bit, wrench worm screw, patch roll) or scrub it (brush head) by
-- changing C0. Parts with `attach` are welded to that named part and move with it. The tablet glows
-- instead (screen brightness, antenna tip light).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local Theme = require(Shared:WaitForChild("Theme"))

export type AnimKind = "spin" | "scrub" | "glow"

-- What ToolService needs to animate a tool.
export type Rig = {
	kind: AnimKind?,
	weld: Weld?, -- the animated part's weld (spin / scrub)
	base: CFrame, -- that weld's resting C0
	glowParts: { BasePart }, -- Neon parts that brighten while the tool works
	lights: { Light },
	guis: { SurfaceGui },
	levelPart: BasePart?, -- tinted by the tool level (drill upgrades)
}

type PartSpec = {
	name: string,
	size: Vector3,
	cf: CFrame, -- relative to the Handle
	color: string, -- key in Theme.ROLE
	shade: number?, -- 0..1 mixed toward Theme.ROLE.background (darker leaves, shadows)
	material: Enum.Material?,
	shape: "Block" | "Cylinder" | "Ball" | "Wedge" | nil,
	transparency: number?,
	anim: boolean?,
	attach: string?,
	glow: boolean?,
}

type ToolSpec = {
	name: string, -- short English name: Tool.Name is plain text (the hotbar shows the icon)
	icon: string, -- key in Icons
	grip: CFrame,
	anim: AnimKind?,
	parts: { PartSpec },
	decorate: ((parts: { [string]: BasePart }, rig: Rig) -> ())?,
}

local rad = math.rad
local MATERIAL_METAL = Enum.Material.Metal
local MATERIAL_SMOOTH = Enum.Material.SmoothPlastic
local MATERIAL_NEON = Enum.Material.Neon

-- Cylinders in Roblox run along their local X axis. These turn them along Y or Z.
local ALONG_Y = CFrame.Angles(0, 0, rad(90))
local ALONG_Z = CFrame.Angles(0, rad(90), 0)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function part(name: string, size: Vector3, cf: CFrame, color: string, extra: { [string]: any }?): PartSpec
	local spec: any = { name = name, size = size, cf = cf, color = color }
	if extra then
		for key, value in extra do
			spec[key] = value
		end
	end
	return spec :: PartSpec
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

----------------------------------------------------------------------------------------------------
-- Screens and labels (SurfaceGui with a team icon, tinted with Theme colours)

local function iconGui(target: BasePart, face: Enum.NormalId, icon: string, color: Color3, bars: boolean): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SBO_Screen"
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.Parent = target

	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(if bars then 0.42 else 0.5, 0.5)
	image.Size = UDim2.fromScale(0.62, 0.62)
	image.SizeConstraint = Enum.SizeConstraint.RelativeYY
	image.Image = icon
	image.ImageColor3 = color
	image.Parent = gui

	if bars then
		-- Signal bars beside the antenna icon: the link to Earth.
		for index = 1, 3 do
			local bar = Instance.new("Frame")
			bar.Name = `Bar{index}`
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = Theme.ROLE.good
			bar.AnchorPoint = Vector2.new(0, 1)
			bar.Size = UDim2.fromScale(0.05, 0.16 + index * 0.14)
			bar.Position = UDim2.fromScale(0.72 + (index - 1) * 0.08, 0.8)
			bar.Parent = gui
		end
	end
	return gui
end

----------------------------------------------------------------------------------------------------
-- Tool designs

-- Tablet frame: from the grip at the bottom edge, the tablet leans its top away from the player so
-- the screen (its +Z face) looks back at them.
local TABLET = CFrame.new(0, 0.14, 0) * CFrame.Angles(rad(-25), 0, 0)
-- Brush frame: the pole runs along -Z, tilted down toward the panels in front.
local BRUSH = CFrame.Angles(rad(-30), 0, 0)

local SPECS: { [string]: ToolSpec } = {
	-- Adjustable wrench: assembles every build step at the pads.
	wrench = {
		name = "Wrench",
		icon = "failure",
		grip = CFrame.new(0, 0, 0),
		anim = "spin",
		parts = {
			part("Handle", v(0.3, 1.0, 0.22), at(0, 0, 0), "panelRaised", { material = MATERIAL_SMOOTH }),
			part("GripRing1", v(0.34, 0.08, 0.26), at(0, -0.3, 0), "warning"),
			part("GripRing2", v(0.34, 0.08, 0.26), at(0, 0, 0), "warning"),
			part("GripRing3", v(0.34, 0.08, 0.26), at(0, 0.3, 0), "warning"),
			part("EndCap", v(0.12, 0.34, 0.34), at(0, -0.54, 0) * ALONG_Y, "warning", { shape = "Cylinder" }),
			part("LanyardRing", v(0.05, 0.22, 0.22), at(0, -0.68, 0) * ALONG_Z, "textDim", { shape = "Cylinder", material = MATERIAL_METAL }),
			part("Collar", v(0.3, 0.1, 0.18), at(0, 0.53, 0), "warning"),
			part("Shaft", v(0.22, 1.1, 0.12), at(0, 1.1, 0), "textDim", { material = MATERIAL_METAL }),
			part("ShaftStripe", v(0.06, 0.9, 0.13), at(0, 1.1, 0), "accent", { material = MATERIAL_NEON, glow = true }),
			part("HeadBase", v(0.78, 0.32, 0.16), at(0, 1.8, 0), "textDim", { material = MATERIAL_METAL }),
			part("FixedJaw", v(0.2, 0.52, 0.16), at(-0.29, 2.16, 0), "textDim", { material = MATERIAL_METAL }),
			part("MovingJaw", v(0.2, 0.38, 0.16), at(0.27, 2.09, 0), "text", { material = MATERIAL_METAL }),
			part("JawTeeth", v(0.05, 0.34, 0.17), at(-0.17, 2.14, 0), "stroke"),
			part("WormScrew", v(0.42, 0.17, 0.17), at(0.05, 1.6, 0), "star", { shape = "Cylinder", material = MATERIAL_METAL, anim = true }),
		},
	},

	-- Ice core drill: a pistol-grip motor with a hollow core bit (diamond teeth at the tip) and a work
	-- lamp, because the crater floor never sees the Sun.
	drill = {
		name = "Ice Drill",
		icon = "drill",
		grip = CFrame.new(0, 0, 0),
		anim = "spin",
		parts = {
			part("Handle", v(0.32, 0.8, 0.42), at(0, 0, 0), "panelRaised", { material = MATERIAL_SMOOTH }),
			part("Housing", v(0.5, 0.55, 1.3), at(0, 0.62, -0.35), "warning", { material = MATERIAL_SMOOTH }),
			part("HousingStripe", v(0.52, 0.1, 1.0), at(0, 0.92, -0.35), "panel"),
			part("VentA", v(0.54, 0.3, 0.05), at(0, 0.62, 0.02), "stroke"),
			part("VentB", v(0.54, 0.3, 0.05), at(0, 0.62, 0.14), "stroke"),
			part("VentC", v(0.54, 0.3, 0.05), at(0, 0.62, 0.26), "stroke"),
			part("RearCap", v(0.1, 0.5, 0.5), at(0, 0.62, 0.33) * ALONG_Z, "panel", { shape = "Cylinder" }),
			part("Trigger", v(0.12, 0.22, 0.12), at(0, 0.25, -0.27), "danger"),
			part("TriggerGuard", v(0.1, 0.06, 0.32), at(0, 0.08, -0.3), "panel"),
			part("Battery", v(0.48, 0.32, 0.62), at(0, -0.55, -0.05), "panel"),
			part("BatteryStripe", v(0.5, 0.08, 0.64), at(0, -0.48, -0.05), "good", { material = MATERIAL_NEON }),
			part("BatteryLed", v(0.1, 0.1, 0.1), at(0.25, -0.58, 0.16), "good", { shape = "Ball", material = MATERIAL_NEON, glow = true }),
			part("Chuck", v(0.35, 0.36, 0.36), at(0, 0.62, -1.15) * ALONG_Z, "textDim", { shape = "Cylinder", material = MATERIAL_METAL }),
			part("ChuckRing", v(0.08, 0.42, 0.42), at(0, 0.62, -1.0) * ALONG_Z, "panel", { shape = "Cylinder" }),
			part("Lamp", v(0.2, 0.14, 0.1), at(0, 0.95, -0.98), "text", { material = MATERIAL_NEON }),
			part("Bit", v(1.7, 0.26, 0.26), at(0, 0.62, -2.15) * ALONG_Z, "textDim", { shape = "Cylinder", material = MATERIAL_METAL, anim = true }),
			part("FluteA", v(0.06, 0.3, 0.3), at(0, 0.62, -1.75) * ALONG_Z, "accent", { shape = "Cylinder", material = MATERIAL_NEON, attach = "Bit", glow = true }),
			part("FluteB", v(0.06, 0.3, 0.3), at(0, 0.62, -2.45) * ALONG_Z, "accent", { shape = "Cylinder", material = MATERIAL_NEON, attach = "Bit", glow = true }),
			part("ToothA", v(0.08, 0.08, 0.14), at(0, 0.75, -3.02), "star", { material = MATERIAL_METAL, attach = "Bit" }),
			part("ToothB", v(0.08, 0.08, 0.14), at(0.11, 0.55, -3.02), "star", { material = MATERIAL_METAL, attach = "Bit" }),
			part("ToothC", v(0.08, 0.08, 0.14), at(-0.11, 0.55, -3.02), "star", { material = MATERIAL_METAL, attach = "Bit" }),
		},
		decorate = function(parts: { [string]: BasePart }, rig: Rig)
			local lamp = parts.Lamp
			if lamp then
				local light = Instance.new("SpotLight")
				light.Name = "WorkLight"
				light.Face = Enum.NormalId.Front -- -Z: forward, where the bit points
				light.Angle = 55
				light.Range = 18
				light.Brightness = 2
				light.Color = Theme.PALETTE.cream
				light.Shadows = false
				light.Parent = lamp
			end
			rig.levelPart = parts.BatteryStripe
		end,
	},

	-- Electrostatic panel brush: a charged strip lifts the clingy Moon dust off the panels.
	brush = {
		name = "Panel Brush",
		icon = "brush",
		grip = CFrame.new(0, 0, 0),
		anim = "scrub",
		parts = {
			part("Handle", v(0.26, 0.26, 0.26), at(0, 0, 0), "panelRaised"),
			part("GripSleeve", v(0.9, 0.3, 0.3), BRUSH * at(0, 0, 0.1) * ALONG_Z, "panel", { shape = "Cylinder" }),
			part("EndCap", v(0.1, 0.34, 0.34), BRUSH * at(0, 0, 0.6) * ALONG_Z, "warning", { shape = "Cylinder" }),
			part("Collar", v(0.12, 0.24, 0.24), BRUSH * at(0, 0, -0.32) * ALONG_Z, "warning", { shape = "Cylinder" }),
			part("Pole", v(2.6, 0.16, 0.16), BRUSH * at(0, 0, -1.6) * ALONG_Z, "textDim", { shape = "Cylinder", material = MATERIAL_METAL }),
			part("PowerBox", v(0.3, 0.28, 0.45), BRUSH * at(0, 0.2, -0.62), "warning", { material = MATERIAL_SMOOTH }),
			part("PowerLed", v(0.09, 0.09, 0.09), BRUSH * at(0, 0.36, -0.5), "good", { shape = "Ball", material = MATERIAL_NEON, glow = true }),
			part("Wire", v(2.0, 0.05, 0.05), BRUSH * at(0.1, 0.09, -1.8) * ALONG_Z, "accent", { shape = "Cylinder", material = MATERIAL_NEON }),
			part("HeadMount", v(0.3, 0.3, 0.25), BRUSH * at(0, 0, -2.95), "panel"),
			part("Head", v(1.8, 0.22, 0.35), BRUSH * at(0, -0.06, -3.15), "text", { anim = true }),
			part("Electrode", v(1.7, 0.05, 0.1), BRUSH * at(0, -0.19, -3.05), "accent", { material = MATERIAL_NEON, attach = "Head", glow = true }),
			part("BristlesA", v(1.7, 0.22, 0.06), BRUSH * at(0, -0.28, -3.03), "textDim", { material = Enum.Material.Fabric, attach = "Head" }),
			part("BristlesB", v(1.7, 0.22, 0.06), BRUSH * at(0, -0.28, -3.15), "text", { material = Enum.Material.Fabric, attach = "Head" }),
			part("BristlesC", v(1.7, 0.22, 0.06), BRUSH * at(0, -0.28, -3.27), "textDim", { material = Enum.Material.Fabric, attach = "Head" }),
			part("HeadCapL", v(0.1, 0.3, 0.4), BRUSH * at(-0.93, -0.06, -3.15), "warning", { attach = "Head" }),
			part("HeadCapR", v(0.1, 0.3, 0.4), BRUSH * at(0.93, -0.06, -3.15), "warning", { attach = "Head" }),
		},
	},

	-- Repair kit: a carry case with a roll of patch tape strapped underneath (fixes air leaks).
	repair_kit = {
		name = "Repair Kit",
		icon = "repairKit", -- its own case icon: the wrench keeps the tool icon (team feedback)
		grip = CFrame.new(0, 0, 0),
		anim = "spin",
		parts = {
			part("Handle", v(0.8, 0.14, 0.16), at(0, 0, 0), "panel"),
			part("PostL", v(0.12, 0.3, 0.14), at(-0.36, -0.2, 0), "textDim", { material = MATERIAL_METAL }),
			part("PostR", v(0.12, 0.3, 0.14), at(0.36, -0.2, 0), "textDim", { material = MATERIAL_METAL }),
			part("Lid", v(1.44, 0.12, 0.54), at(0, -0.39, 0), "warning"),
			part("Case", v(1.4, 0.82, 0.5), at(0, -0.85, 0), "text", { material = MATERIAL_SMOOTH }),
			part("Seam", v(1.42, 0.05, 0.52), at(0, -0.49, 0), "stroke"),
			part("LatchL", v(0.18, 0.2, 0.06), at(-0.42, -0.5, 0.27), "star", { material = MATERIAL_METAL }),
			part("LatchR", v(0.18, 0.2, 0.06), at(0.42, -0.5, 0.27), "star", { material = MATERIAL_METAL }),
			part("LabelBack", v(0.5, 0.36, 0.03), at(0, -0.88, 0.26), "accent"),
			part("LabelFront", v(0.5, 0.36, 0.03), at(0, -0.88, -0.26), "accent"),
			part("BumperL", v(0.06, 0.8, 0.52), at(-0.72, -0.85, 0), "warning"),
			part("BumperR", v(0.06, 0.8, 0.52), at(0.72, -0.85, 0), "warning"),
			part("Roll", v(0.7, 0.34, 0.34), at(0, -1.45, 0), "warning", { shape = "Cylinder", material = MATERIAL_SMOOTH, anim = true }),
			part("RollCore", v(0.72, 0.14, 0.14), at(0, -1.45, 0), "textDim", { shape = "Cylinder", attach = "Roll" }),
			part("StrapL", v(0.08, 0.42, 0.42), at(-0.26, -1.4, 0), "panel"),
			part("StrapR", v(0.08, 0.42, 0.42), at(0.26, -1.4, 0), "panel"),
		},
		decorate = function(parts: { [string]: BasePart }, rig: Rig)
			-- The repair kit's own case icon on both sides of the case.
			if parts.LabelBack then
				table.insert(rig.guis, iconGui(parts.LabelBack, Enum.NormalId.Back, Icons.repairKit, Theme.ROLE.background, false))
			end
			if parts.LabelFront then
				table.insert(rig.guis, iconGui(parts.LabelFront, Enum.NormalId.Front, Icons.repairKit, Theme.ROLE.background, false))
			end
		end,
	},

	-- Rugged tablet: aims the antenna at Earth and scans exploration sites and meteorite craters.
	tablet = {
		name = "Tablet",
		icon = "tablet",
		grip = CFrame.new(0, 0, 0),
		anim = "glow",
		parts = {
			part("Handle", v(0.9, 0.22, 0.3), at(0, 0, 0), "panelRaised"),
			part("Body", v(1.7, 1.2, 0.12), TABLET * at(0, 0.6, 0), "panel"),
			part("Screen", v(1.45, 0.95, 0.04), TABLET * at(0, 0.62, 0.07), "panelRaised", { material = MATERIAL_SMOOTH }),
			part("Strap", v(0.9, 0.6, 0.06), TABLET * at(0, 0.5, -0.09), "stroke"),
			part("BumperBL", v(0.25, 0.25, 0.18), TABLET * at(-0.8, 0.05, 0), "warning"),
			part("BumperBR", v(0.25, 0.25, 0.18), TABLET * at(0.8, 0.05, 0), "warning"),
			part("BumperTL", v(0.25, 0.25, 0.18), TABLET * at(-0.8, 1.15, 0), "warning"),
			part("BumperTR", v(0.25, 0.25, 0.18), TABLET * at(0.8, 1.15, 0), "warning"),
			part("AntennaBase", v(0.12, 0.14, 0.14), TABLET * at(0.6, 1.26, 0) * ALONG_Y, "textDim", { shape = "Cylinder", material = MATERIAL_METAL }),
			part("AntennaRod", v(0.6, 0.05, 0.05), TABLET * at(0.6, 1.6, 0) * ALONG_Y, "textDim", { shape = "Cylinder", material = MATERIAL_METAL }),
			part("AntennaTip", v(0.13, 0.13, 0.13), TABLET * at(0.6, 1.92, 0), "accent", { shape = "Ball", material = MATERIAL_NEON, glow = true }),
			part("Camera", v(0.07, 0.07, 0.07), TABLET * at(0, 1.13, 0.07), "stroke", { shape = "Ball" }),
			part("ButtonA", v(0.18, 0.05, 0.04), TABLET * at(-0.3, 0.1, 0.07), "good", { material = MATERIAL_NEON }),
			part("ButtonB", v(0.18, 0.05, 0.04), TABLET * at(0, 0.1, 0.07), "accent", { material = MATERIAL_NEON }),
			part("ButtonC", v(0.18, 0.05, 0.04), TABLET * at(0.3, 0.1, 0.07), "warning", { material = MATERIAL_NEON }),
		},
		decorate = function(parts: { [string]: BasePart }, rig: Rig)
			local screen = parts.Screen
			if screen then
				-- The screen faces the player (+Z, the Back face): the antenna icon and signal bars.
				table.insert(rig.guis, iconGui(screen, Enum.NormalId.Back, Icons.antenna, Theme.ROLE.accent, true))
				local light = Instance.new("PointLight")
				light.Name = "ScreenGlow"
				light.Range = 6
				light.Brightness = 0.6
				light.Color = Theme.ROLE.accent
				light.Shadows = false
				light.Parent = screen
				table.insert(rig.lights, light)
			end
		end,
	},

	-- A fresh tray from the greenhouse: lettuce and radishes, the first crops astronauts ate in space.
	food = {
		name = "Fresh Salad",
		icon = "food",
		grip = CFrame.new(0, 0, 0.42), -- held at the near edge of the tray
		anim = nil,
		parts = {
			part("Handle", v(1.3, 0.1, 0.9), at(0, 0, 0), "text", { material = MATERIAL_SMOOTH }),
			part("RimFront", v(1.3, 0.14, 0.06), at(0, 0.1, -0.45), "accent"),
			part("RimBack", v(1.3, 0.14, 0.06), at(0, 0.1, 0.45), "accent"),
			part("RimLeft", v(0.06, 0.14, 0.9), at(-0.65, 0.1, 0), "accent"),
			part("RimRight", v(0.06, 0.14, 0.9), at(0.65, 0.1, 0), "accent"),
			part("GrowMat", v(1.18, 0.06, 0.78), at(0, 0.08, 0), "panelRaised", { material = Enum.Material.Fabric }),
			part("LettuceA", v(0.44, 0.44, 0.44), at(-0.33, 0.27, -0.18), "good", { shape = "Ball", material = Enum.Material.Grass }),
			part("LettuceB", v(0.46, 0.46, 0.46), at(0.1, 0.28, 0.14), "good", { shape = "Ball", shade = 0.2, material = Enum.Material.Grass }),
			part("LettuceC", v(0.36, 0.36, 0.36), at(0.36, 0.23, -0.16), "good", { shape = "Ball", shade = 0.1, material = Enum.Material.Grass }),
			part("LeafA", v(0.3, 0.08, 0.22), at(-0.12, 0.3, -0.25) * CFrame.Angles(rad(-20), rad(30), 0), "good", { shade = 0.3 }),
			part("LeafB", v(0.28, 0.08, 0.2), at(0.3, 0.32, 0.22) * CFrame.Angles(rad(15), rad(-40), 0), "good"),
			part("RadishA", v(0.2, 0.2, 0.2), at(-0.42, 0.21, 0.25), "reward", { shape = "Ball" }),
			part("RadishB", v(0.18, 0.18, 0.18), at(-0.18, 0.2, 0.3), "reward", { shape = "Ball", shade = 0.15 }),
			part("RadishC", v(0.2, 0.2, 0.2), at(0.45, 0.21, 0.28), "reward", { shape = "Ball" }),
			part("SproutA", v(0.05, 0.16, 0.05), at(-0.42, 0.37, 0.25), "good"),
			part("SproutC", v(0.05, 0.16, 0.05), at(0.45, 0.37, 0.28), "good"),
		},
	},
}

local ORDER: { string } = { "wrench", "drill", "brush", "repair_kit", "tablet", "food" }

----------------------------------------------------------------------------------------------------
-- Builder

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
	Ball = Enum.PartType.Ball,
	Wedge = Enum.PartType.Wedge,
}

local function colorOf(spec: PartSpec): Color3
	local role: any = Theme.ROLE
	local color: Color3 = role[spec.color] or Theme.ROLE.text
	if spec.shade and spec.shade > 0 then
		color = color:Lerp(Theme.ROLE.background, math.clamp(spec.shade, 0, 1))
	end
	return color
end

local function makePart(spec: PartSpec): BasePart
	local instance = Instance.new("Part")
	instance.Name = spec.name
	instance.Shape = SHAPES[spec.shape or "Block"] or Enum.PartType.Block
	instance.Size = spec.size
	instance.CFrame = spec.cf
	instance.Color = colorOf(spec)
	instance.Material = spec.material or Enum.Material.Plastic
	instance.Transparency = spec.transparency or 0
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Anchored = false
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance.Massless = true
	instance.CastShadow = spec.size.Magnitude > 0.6
	return instance
end

local ToolModels = {}

ToolModels.ORDER = table.freeze(ORDER)

-- The plain-text Tool.Name of a tool id (nil for an unknown id).
function ToolModels.nameOf(id: string): string?
	local spec = SPECS[id]
	return if spec then spec.name else nil
end

-- Number of parts in a tool model (for checks and docs).
function ToolModels.partCount(id: string): number
	local spec = SPECS[id]
	return if spec then #spec.parts else 0
end

-- Builds a fresh Tool for `id` (not parented) and the rig ToolService animates; nil for an unknown id.
function ToolModels.create(id: string): (Tool?, Rig?)
	local spec = SPECS[id]
	if spec == nil then
		return nil, nil
	end
	local tool = Instance.new("Tool")
	tool.Name = spec.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = false
	tool.ToolTip = ""
	tool.Grip = spec.grip
	-- The hotbar shows the white team icon instead of the English name.
	local icon = (Icons :: any)[spec.icon]
	if type(icon) == "string" then
		tool.TextureId = icon
	end

	local rig: Rig = {
		kind = spec.anim,
		weld = nil,
		base = CFrame.identity,
		glowParts = {},
		lights = {},
		guis = {},
		levelPart = nil,
	}

	local byName: { [string]: BasePart } = {}
	local handle: BasePart? = nil
	for index, partSpec in spec.parts do
		local instance = makePart(partSpec)
		if index == 1 then
			instance.Name = "Handle"
			instance.CFrame = CFrame.identity
			handle = instance
		end
		byName[instance.Name] = instance
		if partSpec.glow then
			table.insert(rig.glowParts, instance)
		end
	end
	local root = handle :: BasePart

	-- Joints: the animated part on a Weld (C0 = its place on the Handle), followers welded to the part
	-- they name, everything else welded straight to the Handle.
	for index, partSpec in spec.parts do
		if index == 1 then
			continue
		end
		local instance = byName[partSpec.name]
		if partSpec.anim then
			local weld = Instance.new("Weld")
			weld.Name = "SBO_AnimWeld"
			weld.Part0 = root
			weld.Part1 = instance
			weld.C0 = partSpec.cf
			weld.C1 = CFrame.identity
			weld.Parent = instance
			rig.weld = weld
			rig.base = partSpec.cf
		else
			local anchor = if partSpec.attach then byName[partSpec.attach] or root else root
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = instance
			weld.Parent = instance
		end
	end

	if spec.decorate then
		spec.decorate(byName, rig)
	end

	root.Parent = tool
	for index, partSpec in spec.parts do
		if index > 1 then
			byName[partSpec.name].Parent = tool
		end
	end
	return tool, rig
end

return table.freeze(ToolModels)
