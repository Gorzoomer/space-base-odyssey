--!strict
-- Space Base Odyssey - every astronaut wears the same spacesuit, whatever their Roblox avatar.
-- Characters load from a plain HumanoidDescription (standard body, no accessories or clothes) in suit
-- white with a neutral head. Anything an avatar still brings (accessories, clothes, package meshes,
-- face decals) is removed, then a suit built only from Parts is welded on (R15 or R6): bubble helmet
-- with a gold visor band and a soft helmet lamp, chest control panel, life-support backpack, gloves,
-- boots with orange bands and a shoulder patch in Theme colours.
-- Rewards change only the look, never the game: laika -> magenta backpack; explorer26 (event code)
-- -> full gold visor and gold bands.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

-- The parts of ProgressService this module uses.
export type ProgressApi = {
	get: (player: Player) -> Types.Progress?,
	onChanged: (listener: () -> ()) -> (),
}

type Style = { laika: boolean, explorer: boolean }

type Rig = {
	head: BasePart,
	torso: BasePart, -- UpperTorso (R15) or Torso (R6)
	lowerTorso: BasePart?,
	leftHand: BasePart,
	rightHand: BasePart,
	leftFoot: BasePart,
	rightFoot: BasePart,
	leftArm: BasePart, -- LeftUpperArm (R15) or Left Arm (R6): the shoulder patch
	r6: boolean,
}

local SUIT_NAME = "AstronautSuit"
local PART_WAIT_SECONDS = 10

local P = Theme.PALETTE
-- Suit colours, all derived from the Lunar Sunrise palette.
local SUIT_WHITE = P.cream:Lerp(Color3.new(1, 1, 1), 0.65)
local SUIT_GREY = P.creamDim:Lerp(Color3.new(1, 1, 1), 0.35)
local SUIT_DARK = P.nightLight
local GLASS = P.cyan:Lerp(Color3.new(1, 1, 1), 0.75)
-- One neutral skin tone for every head inside the helmet (not a palette colour on purpose).
local NEUTRAL_SKIN = Color3.fromRGB(214, 165, 128)

local SuitService = {}

local started = false
local progressApi: ProgressApi? = nil
local appliedStyle: { [Model]: string } = {}

----------------------------------------------------------------------------------------------------
-- Style

local function styleOf(player: Player): Style
	local api = progressApi
	local progress = if api then api.get(player) else nil
	return {
		laika = progress ~= nil and progress.collectibles.laika == true,
		explorer = progress ~= nil and progress.cosmetics ~= nil and progress.cosmetics.explorer26 == true,
	}
end

local function styleKey(style: Style): string
	return (if style.laika then "laika" else "-") .. "|" .. (if style.explorer then "explorer26" else "-")
end

----------------------------------------------------------------------------------------------------
-- Removing the avatar's own look

local function isAvatarItem(item: Instance): boolean
	return item:IsA("Accessory")
		or item:IsA("Hat")
		or item:IsA("Clothing") -- Shirt and Pants
		or item:IsA("ShirtGraphic")
		or item:IsA("CharacterMesh") -- R6 body packages
end

local function paintBody(colors: BodyColors)
	colors.HeadColor3 = NEUTRAL_SKIN
	colors.TorsoColor3 = SUIT_WHITE
	colors.LeftArmColor3 = SUIT_WHITE
	colors.RightArmColor3 = SUIT_WHITE
	colors.LeftLegColor3 = SUIT_WHITE
	colors.RightLegColor3 = SUIT_WHITE
end

local function stripItem(item: Instance)
	if isAvatarItem(item) then
		task.defer(function()
			if item.Parent then
				item:Destroy()
			end
		end)
	elseif item:IsA("BodyColors") then
		paintBody(item)
	end
end

local function stripFace(head: BasePart)
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	head.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Decal") then
			task.defer(function()
				if child.Parent then
					child:Destroy()
				end
			end)
		end
	end)
end

-- Removes what the avatar brought now and whatever its appearance adds later.
local function stripAvatar(character: Model)
	local hasColors = false
	for _, child in character:GetChildren() do
		if child:IsA("BodyColors") then
			hasColors = true
		end
		stripItem(child)
	end
	if not hasColors then
		local colors = Instance.new("BodyColors")
		paintBody(colors)
		colors.Parent = character
	end
	character.ChildAdded:Connect(stripItem)
end

----------------------------------------------------------------------------------------------------
-- Suit pieces

local function waitPart(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name) or character:WaitForChild(name, PART_WAIT_SECONDS)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function findRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", PART_WAIT_SECONDS)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return nil
	end
	local r6 = humanoid.RigType == Enum.HumanoidRigType.R6
	local head = waitPart(character, "Head")
	if r6 then
		local torso = waitPart(character, "Torso")
		local leftArm = waitPart(character, "Left Arm")
		local rightArm = waitPart(character, "Right Arm")
		local leftLeg = waitPart(character, "Left Leg")
		local rightLeg = waitPart(character, "Right Leg")
		if head and torso and leftArm and rightArm and leftLeg and rightLeg then
			return {
				head = head,
				torso = torso,
				lowerTorso = nil,
				leftHand = leftArm,
				rightHand = rightArm,
				leftFoot = leftLeg,
				rightFoot = rightLeg,
				leftArm = leftArm,
				r6 = true,
			}
		end
		return nil
	end
	local torso = waitPart(character, "UpperTorso")
	local lowerTorso = waitPart(character, "LowerTorso")
	local leftHand = waitPart(character, "LeftHand")
	local rightHand = waitPart(character, "RightHand")
	local leftFoot = waitPart(character, "LeftFoot")
	local rightFoot = waitPart(character, "RightFoot")
	local leftArm = waitPart(character, "LeftUpperArm")
	if head and torso and leftHand and rightHand and leftFoot and rightFoot and leftArm then
		return {
			head = head,
			torso = torso,
			lowerTorso = lowerTorso,
			leftHand = leftHand,
			rightHand = rightHand,
			leftFoot = leftFoot,
			rightFoot = rightFoot,
			leftArm = leftArm,
			r6 = false,
		}
	end
	return nil
end

type PieceOptions = {
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	shadow: boolean?,
	shape: ("Ball" | "Cylinder" | "Ellipsoid")?,
}

-- A massless, non-colliding Part welded to `body` at body.CFrame * offset.
local function piece(
	model: Model,
	name: string,
	body: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	options: PieceOptions?
): Part
	local opts: PieceOptions = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = opts.shadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = opts.transparency or 0
	part.Reflectance = opts.reflectance or 0
	if opts.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif opts.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Size = size
	if opts.shape == "Ellipsoid" then
		-- A built-in sphere mesh stretched to the part's size (no asset).
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.CFrame = body.CFrame * offset
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	return part
end

local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X; this stands it up

local function buildHelmet(model: Model, rig: Rig, style: Style)
	local head = rig.head
	-- The R6 head part is 2 x 1 x 1 shown through a 1.25 mesh; R15 heads are close to their size.
	local headSize = if rig.r6 then head.Size.Y * 1.25 else math.max(head.Size.Y, head.Size.Z)
	local diameter = headSize * 1.75
	local centre = CFrame.new(0, headSize * 0.06, 0)

	piece(model, "HelmetGlass", head, Vector3.one * diameter, centre, GLASS, {
		shape = "Ball",
		transparency = 0.72,
		reflectance = 0.2,
	})
	-- Gold visor: a band across the eyes, or the full lowered visor with the event cosmetic.
	local visorSize = if style.explorer
		then Vector3.new(diameter * 0.84, diameter * 0.58, diameter * 0.52)
		else Vector3.new(diameter * 0.8, diameter * 0.3, diameter * 0.5)
	local visorY = if style.explorer then headSize * 0.1 else headSize * 0.14
	piece(model, "Visor", head, visorSize, CFrame.new(0, visorY, -diameter * 0.22), P.gold, {
		shape = "Ellipsoid",
		reflectance = if style.explorer then 0.45 else 0.3,
		transparency = if style.explorer then 0 else 0.08,
	})
	-- Neck ring where the helmet meets the suit.
	piece(
		model,
		"NeckRing",
		head,
		Vector3.new(headSize * 0.22, diameter * 0.66, diameter * 0.66),
		CFrame.new(0, -headSize * 0.58, 0) * UPRIGHT_CYLINDER,
		if style.explorer then P.gold else SUIT_DARK,
		{ shape = "Cylinder" }
	)
	-- Helmet lamp: top front of the bubble, shining forward (soft, helps in the dark crater).
	local angle = math.rad(38)
	local lampOffset = centre
		* CFrame.new(0, math.sin(angle) * diameter * 0.5, -math.cos(angle) * diameter * 0.5)
		* CFrame.Angles(math.rad(-8), 0, 0)
	local lamp = piece(model, "HelmetLamp", head, Vector3.new(0.34, 0.22, 0.2), lampOffset, P.cream, {
		material = Enum.Material.Neon,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = 30
	light.Angle = 70
	light.Brightness = 1.1
	light.Color = P.cream
	light.Shadows = false
	light.Parent = lamp
end

local function buildTorso(model: Model, rig: Rig, style: Style)
	local torso = rig.torso
	local size = torso.Size
	-- R15 splits the trunk; the pack covers the upper torso and most of the lower one.
	local lower = rig.lowerTorso
	local trunkHeight = size.Y + (if lower then lower.Size.Y else 0)
	local trunkShift = if lower then -lower.Size.Y * 0.4 else 0

	-- Chest control panel with a cyan status light.
	local panelOffset = CFrame.new(0, size.Y * 0.1, -size.Z / 2 - 0.08)
	piece(model, "ChestPanel", torso, Vector3.new(size.X * 0.46, size.Y * 0.32, 0.16), panelOffset, SUIT_DARK)
	piece(model, "ChestLight", torso, Vector3.new(size.X * 0.14, size.Y * 0.08, 0.06), panelOffset * CFrame.new(-size.X * 0.1, size.Y * 0.05, -0.1), P.cyan, {
		material = Enum.Material.Neon,
	})
	piece(model, "ChestButton", torso, Vector3.new(size.X * 0.06, size.X * 0.06, 0.06), panelOffset * CFrame.new(size.X * 0.12, size.Y * 0.05, -0.1), P.orange, {
		material = Enum.Material.Neon,
	})
	piece(model, "ChestButtonGo", torso, Vector3.new(size.X * 0.06, size.X * 0.06, 0.06), panelOffset * CFrame.new(size.X * 0.12, -size.Y * 0.07, -0.1), P.lime, {
		material = Enum.Material.Neon,
	})

	-- Life-support backpack (magenta with the laika reward).
	local packColor = if style.laika then P.magenta else SUIT_WHITE
	local packSize = Vector3.new(size.X * 0.82, trunkHeight * 0.86, size.Z * 0.75)
	local back = CFrame.new(0, trunkShift + trunkHeight * 0.04, size.Z / 2 + packSize.Z / 2)
	piece(model, "Backpack", torso, packSize, back, packColor, { shadow = true })
	for _, side in { -1, 1 } do
		piece(
			model,
			"Tank",
			torso,
			Vector3.new(packSize.Y * 0.8, packSize.Z * 0.55, packSize.Z * 0.55),
			back * CFrame.new(side * packSize.X * 0.26, -packSize.Y * 0.02, packSize.Z * 0.5) * UPRIGHT_CYLINDER,
			if style.laika then P.cream else SUIT_GREY,
			{ shape = "Cylinder" }
		)
	end
	piece(model, "PackCap", torso, Vector3.new(packSize.X * 1.04, packSize.Y * 0.12, packSize.Z * 1.12), back * CFrame.new(0, packSize.Y * 0.47, 0.02), SUIT_DARK)
	piece(model, "PackStatus", torso, Vector3.new(packSize.X * 0.6, packSize.Y * 0.06, 0.06), back * CFrame.new(0, packSize.Y * 0.3, packSize.Z * 0.5 + 0.03), P.cyan, {
		material = Enum.Material.Neon,
	})
end

local function buildLimbs(model: Model, rig: Rig, style: Style)
	local accent = if style.explorer then P.gold else P.orange
	local accentOptions: PieceOptions = { reflectance = if style.explorer then 0.3 else 0 }

	for _, hand in { rig.leftHand, rig.rightHand } do
		local s = hand.Size
		if rig.r6 then
			-- R6 arm (1 x 2 x 1): glove on the lowest quarter, band just above it.
			piece(model, "Glove", hand, Vector3.new(s.X + 0.08, s.Y * 0.26, s.Z + 0.08), CFrame.new(0, -s.Y * 0.38, 0), SUIT_GREY)
			piece(model, "GloveBand", hand, Vector3.new(s.X + 0.14, s.Y * 0.09, s.Z + 0.14), CFrame.new(0, -s.Y * 0.22, 0), accent, accentOptions)
		else
			piece(model, "Glove", hand, s + Vector3.new(0.08, 0.08, 0.08), CFrame.new(), SUIT_GREY)
			piece(model, "GloveBand", hand, Vector3.new(s.X + 0.16, math.min(0.2, s.Y * 0.6), s.Z + 0.16), CFrame.new(0, s.Y * 0.5 + 0.06, 0), accent, accentOptions)
		end
	end

	for _, foot in { rig.leftFoot, rig.rightFoot } do
		local s = foot.Size
		if rig.r6 then
			-- R6 leg (1 x 2 x 1): boot on the lowest third, band on top of it.
			piece(model, "Boot", foot, Vector3.new(s.X + 0.1, s.Y * 0.3, s.Z + 0.18), CFrame.new(0, -s.Y * 0.36, -0.05), SUIT_DARK, { shadow = true })
			piece(model, "BootBand", foot, Vector3.new(s.X + 0.16, s.Y * 0.08, s.Z + 0.2), CFrame.new(0, -s.Y * 0.19, -0.04), accent, accentOptions)
		else
			piece(model, "Boot", foot, Vector3.new(s.X + 0.1, s.Y + 0.12, s.Z + 0.18), CFrame.new(0, 0.02, -0.05), SUIT_DARK, { shadow = true })
			piece(model, "BootBand", foot, Vector3.new(s.X + 0.16, 0.16, s.Z + 0.2), CFrame.new(0, s.Y * 0.5 + 0.1, -0.04), accent, accentOptions)
		end
	end

	-- Shoulder patch on the outside of the left arm: orange rim, cyan centre, rocket icon.
	local arm = rig.leftArm
	local s = arm.Size
	local patchY = if rig.r6 then s.Y * 0.28 else s.Y * 0.15
	local patchSize = math.min(s.Y * 0.45, s.Z * 0.6)
	piece(model, "PatchRim", arm, Vector3.new(0.06, patchSize, patchSize), CFrame.new(-s.X / 2 - 0.03, patchY, 0), accent, accentOptions)
	local patch = piece(
		model,
		"Patch",
		arm,
		Vector3.new(0.06, patchSize * 0.78, patchSize * 0.78),
		CFrame.new(-s.X / 2 - 0.05, patchY, 0),
		P.cyan
	)
	local icon = Instance.new("Decal")
	icon.Face = Enum.NormalId.Left
	icon.Texture = Icons.rocket
	icon.Color3 = P.night
	icon.Parent = patch
end

-- Builds (or rebuilds) the suit on `character` for `player`'s current style.
local function dress(player: Player, character: Model)
	local style = styleOf(player)
	local key = styleKey(style)
	local existing = character:FindFirstChild(SUIT_NAME)
	if existing and appliedStyle[character] == key then
		return
	end
	local rig = findRig(character)
	if rig == nil or character.Parent == nil or player.Character ~= character then
		return
	end
	-- Check again: the style may have been applied while this call waited for the body parts.
	existing = character:FindFirstChild(SUIT_NAME)
	if existing and appliedStyle[character] == key then
		return
	end
	if existing then
		existing:Destroy()
	end
	appliedStyle[character] = key
	local model = Instance.new("Model")
	model.Name = SUIT_NAME
	model.Parent = character
	buildHelmet(model, rig, style)
	buildTorso(model, rig, style)
	buildLimbs(model, rig, style)
end

local function onCharacterAdded(player: Player, character: Model)
	stripAvatar(character)
	task.spawn(function()
		local head = waitPart(character, "Head")
		if head then
			stripFace(head)
		end
		if not character:IsDescendantOf(workspace) then
			character.AncestryChanged:Wait()
		end
		task.wait() -- let the rig assemble before measuring limbs
		local ok, err = pcall(dress, player, character)
		if not ok then
			warn(`[SpaceBaseOdyssey] could not dress {player.Name}: {err}`)
		end
	end)
	character.Destroying:Once(function()
		appliedStyle[character] = nil
	end)
end

local function addPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

-- A reward or code changed someone's look: rebuild the suits whose style changed.
local function refreshAll()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.Parent then
			task.spawn(function()
				local ok, err = pcall(dress, player, character)
				if not ok then
					warn(`[SpaceBaseOdyssey] could not restyle {player.Name}: {err}`)
				end
			end)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- progressService: ProgressService (already started) for rewards and cosmetics, or nil.
function SuitService.start(progressService: ProgressApi?)
	assert(not started, "SuitService already started")
	started = true
	progressApi = progressService
	if progressService then
		progressService.onChanged(refreshAll)
	end
	Players.PlayerAdded:Connect(addPlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

-- Spawns `player` with the plain suit body (standard shape, no accessories or clothes), so every
-- avatar fits the suit. Falls back to a normal spawn; the avatar's items are then removed on spawn.
function SuitService.loadCharacter(player: Player)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = NEUTRAL_SKIN
	description.TorsoColor = SUIT_WHITE
	description.LeftArmColor = SUIT_WHITE
	description.RightArmColor = SUIT_WHITE
	description.LeftLegColor = SUIT_WHITE
	description.RightLegColor = SUIT_WHITE
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(description)
	end)
	if not ok then
		warn(`[SpaceBaseOdyssey] suit spawn failed for {player.Name}, using a normal spawn: {err}`)
		player:LoadCharacter()
	end
end

return SuitService
