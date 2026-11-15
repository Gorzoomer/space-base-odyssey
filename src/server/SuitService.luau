--!strict
-- Space Base Odyssey - astronaut gear worn over the player's own Roblox avatar.
-- The avatar stays exactly as the player made it (body, colours, clothes, face): kids spent time and
-- money on it. Only two pieces are added, built from Parts and welded on (R15 or R6):
--   * an EVA helmet: white hard shell with a front window, a dark reflective visor (gold with the
--     "explorer26" event code), a visor frame, a metal neck ring, two helmet lamps (one soft SpotLight
--     for the whole helmet) and a small side camera;
--   * a life-support backpack: rounded pack with a service panel, a lime status light and two gas
--     vents, joined to the helmet by two hoses ("laika" adds a magenta stripe and a patch).
-- The shell, visor and frame are made once with CSG (solid modelling) at server start, cached in
-- ServerStorage and cloned per character, scaled to the head. If CSG fails, plain balls are used.
-- Hats and hair are hidden (Handle Transparency 1) so they do not poke through the helmet.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

-- The parts of ProgressService this module uses (only when no BaseService is given).
export type ProgressApi = {
	get: (player: Player) -> Types.Progress?,
	onChanged: (listener: () -> ()) -> (),
}

-- The parts of BaseService this module uses.
export type BaseApi = {
	equipped: (player: Player) -> Types.Equipped?,
	onEquippedChanged: (listener: (player: Player) -> ()) -> (),
}

type Look = { helmet: string, backpack: string }

type Rig = {
	head: BasePart,
	torso: BasePart, -- UpperTorso (R15) or Torso (R6)
	lowerTorso: BasePart?,
	r6: boolean,
}

-- One CSG piece of the helmet template: its part (built TEMPLATE_D studs wide) and where it sits
-- relative to the helmet centre.
type TemplatePiece = { name: string, part: BasePart, rel: CFrame }

type PieceOptions = {
	material: Enum.Material?,
	reflectance: number?,
	shadow: boolean?,
	shape: ("Ball" | "Cylinder" | "Ellipsoid")?,
}

local GEAR_NAME = "AstronautGear"
local PART_WAIT_SECONDS = 10
local TEMPLATE_WAIT_SECONDS = 8
local HIDDEN_ATTRIBUTE = "SBO_HiddenByHelmet" -- original Handle transparency of a hidden hat or hair

-- Helmet shape, in helmet diameters (D) from the helmet centre; the helmet faces -Z.
local HELMET_PER_HEAD = 1.5 -- helmet diameter / head size (playtest: 1.72 looked like a bubble)
local HELMET_LIFT = 0.06 -- helmet centre above the head centre, in head sizes
local TEMPLATE_D = 4 -- CSG is done at this size, then scaled
local WINDOW_CENTRE = Vector3.new(0, 0.02, -0.4)
local WINDOW_D = 0.78 -- the ball cut out of the shell (the opening is about 0.76 D wide)
local FRAME_D = 0.9 -- the visor frame is the band between FRAME_INNER_D and FRAME_D
local FRAME_INNER_D = 0.8 -- a little wider than the window, so frame and shell never share a surface
local VISOR_D = 0.97 -- the visor sits a little inside the shell surface
local FRAME_SHELL_D = 1.04 -- the frame stands a little proud of the shell
local BOTTOM_CUT = -0.36 -- the shell is flat below this height, where the neck ring sits
local NECK_RING_D = 0.76
local NECK_RING_H = 0.08

local P = Theme.PALETTE
-- Gear colours, all from the Lunar Sunrise palette.
local SHELL_WHITE = P.cream:Lerp(Color3.new(1, 1, 1), 0.75)
local PANEL_GREY = P.creamDim:Lerp(Color3.new(1, 1, 1), 0.35)
local METAL = P.creamDim:Lerp(Color3.new(1, 1, 1), 0.15)
local VISOR_DARK = P.night:Lerp(P.cyan, 0.08)
local DARK = P.nightLight
local HOSE = P.nightLine

local HELMETS: { [string]: boolean } = { standard = true, explorer26 = true }
local BACKPACKS: { [string]: boolean } = { standard = true, laika = true }

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X; this stands it up
local ALONG_LOOK = CFrame.Angles(0, math.rad(90), 0) -- turns a Cylinder's axis to point along -Z

local SuitService = {}

local started = false
local progressApi: ProgressApi? = nil
local baseApi: BaseApi? = nil
local appliedLook: { [Model]: string } = {}

local template: { TemplatePiece }? = nil
local templateState = "none" -- "none" | "building" | "ready" | "failed"

----------------------------------------------------------------------------------------------------
-- What the player wears

local function lookOf(player: Player): Look
	local look: Look = { helmet = "standard", backpack = "standard" }
	local base = baseApi
	if base then
		local equipped = base.equipped(player)
		if equipped then
			if HELMETS[equipped.helmet] then
				look.helmet = equipped.helmet
			end
			if BACKPACKS[equipped.backpack] then
				look.backpack = equipped.backpack
			end
		end
		return look
	end
	-- No BaseService: the rewards are simply worn.
	local api = progressApi
	local progress = if api then api.get(player) else nil
	if progress then
		if progress.cosmetics ~= nil and progress.cosmetics.explorer26 == true then
			look.helmet = "explorer26"
		end
		if progress.collectibles.laika == true then
			look.backpack = "laika"
		end
	end
	return look
end

local function lookKey(look: Look): string
	return look.helmet .. "|" .. look.backpack
end

----------------------------------------------------------------------------------------------------
-- Hats and hair go under the helmet

local function isHatOrHair(item: Instance): boolean
	if item:IsA("Accessory") then
		local accessoryType = (item :: Accessory).AccessoryType
		if accessoryType == Enum.AccessoryType.Hat or accessoryType == Enum.AccessoryType.Hair then
			return true
		end
	elseif not item:IsA("Accoutrement") then
		return false -- not a hat at all
	end
	-- Old hats and untyped accessories: look at the attachment the Handle uses.
	local handle = item:FindFirstChild("Handle")
	if handle then
		for _, child in handle:GetChildren() do
			if child:IsA("Attachment") and (child.Name == "HatAttachment" or child.Name == "HairAttachment") then
				return true
			end
		end
	end
	return item.ClassName == "Hat"
end

local function hideUnderHelmet(item: Instance)
	if not item:IsA("Accoutrement") then
		return
	end
	task.spawn(function()
		local handle = item:FindFirstChild("Handle") or item:WaitForChild("Handle", PART_WAIT_SECONDS)
		if handle == nil or not handle:IsA("BasePart") or item.Parent == nil then
			return
		end
		local part = handle :: BasePart
		if not isHatOrHair(item) or part:GetAttribute(HIDDEN_ATTRIBUTE) ~= nil then
			return
		end
		part:SetAttribute(HIDDEN_ATTRIBUTE, part.Transparency)
		part.Transparency = 1
	end)
end

local function hideHatsAndHair(character: Model)
	for _, child in character:GetChildren() do
		hideUnderHelmet(child)
	end
	-- The avatar's accessories arrive a moment after the character.
	character.ChildAdded:Connect(hideUnderHelmet)
end

----------------------------------------------------------------------------------------------------
-- Helmet template (CSG, built once)

local function rawPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function buildTemplate(): { TemplatePiece }
	local D = TEMPLATE_D
	local origin = CFrame.new(0, 4000, 0) -- far away from the base while CSG runs
	local scratch = Instance.new("Folder")
	scratch.Name = "SBO_HelmetCSG"
	scratch.Parent = workspace

	local function ball(diameter: number, centre: Vector3): Part
		return rawPart(Enum.PartType.Ball, Vector3.one * diameter * D, origin + centre * D, scratch)
	end
	local function belowNeck(): Part
		return rawPart(Enum.PartType.Block, Vector3.new(2 * D, D, 2 * D), origin + Vector3.new(0, (BOTTOM_CUT - 0.5) * D, 0), scratch)
	end
	local fidelity = Enum.CollisionFidelity.Box

	local ok, result = pcall(function(): { TemplatePiece }
		-- Shell: a ball with the front window and the bottom cut away.
		local shell = ball(1, Vector3.zero):SubtractAsync({ ball(WINDOW_D, WINDOW_CENTRE), belowNeck() }, fidelity)
		-- Visor: the part of a slightly smaller ball that fills the window.
		local visor = ball(VISOR_D, Vector3.zero):IntersectAsync({ ball(WINDOW_D, WINDOW_CENTRE) }, fidelity)
		-- Frame: a band around the window, a little proud of the shell.
		local frameDisc = ball(FRAME_SHELL_D, Vector3.zero):IntersectAsync({ ball(FRAME_D, WINDOW_CENTRE) }, fidelity)
		frameDisc.Parent = scratch
		local frame = frameDisc:SubtractAsync({ ball(FRAME_INNER_D, WINDOW_CENTRE), belowNeck() }, fidelity)

		local folder = Instance.new("Folder")
		folder.Name = "SBO_HelmetTemplate"
		local pieces: { TemplatePiece } = {}
		local unions: { { name: string, union: UnionOperation } } = {
			{ name = "HelmetShell", union = shell },
			{ name = "Visor", union = visor },
			{ name = "VisorFrame", union = frame },
		}
		for _, entry in unions do
			local name = entry.name
			local union = entry.union
			union.Name = name
			union.UsePartColor = true
			union.Anchored = true
			union.CanCollide = false
			union.CanQuery = false
			union.CanTouch = false
			union.Parent = folder
			table.insert(pieces, { name = name, part = union, rel = origin:ToObjectSpace(union.CFrame) })
		end
		folder.Parent = ServerStorage
		return pieces
	end)
	scratch:Destroy()
	if not ok then
		error(result)
	end
	return result
end

local function startTemplate()
	if templateState ~= "none" then
		return
	end
	templateState = "building"
	task.spawn(function()
		local ok, result = pcall(buildTemplate)
		if ok then
			template = result
			templateState = "ready"
		else
			templateState = "failed"
			warn(`[SpaceBaseOdyssey] helmet CSG failed, using simple parts: {result}`)
		end
	end)
end

-- The helmet template, or nil when CSG failed (or took too long).
local function awaitTemplate(): { TemplatePiece }?
	local waited = 0
	while templateState == "building" and waited < TEMPLATE_WAIT_SECONDS do
		waited += task.wait(0.1)
	end
	return if templateState == "ready" then template else nil
end

----------------------------------------------------------------------------------------------------
-- Gear pieces

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
	local torso = waitPart(character, if r6 then "Torso" else "UpperTorso")
	if head == nil or torso == nil then
		return nil
	end
	local lowerTorso = if r6 then nil else waitPart(character, "LowerTorso")
	return { head = head, torso = torso, lowerTorso = lowerTorso, r6 = r6 }
end

local function setLook(part: BasePart, name: string, color: Color3, options: PieceOptions?)
	local opts: PieceOptions = options or {}
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = opts.shadow == true
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = 0
	part.Reflectance = opts.reflectance or 0
	if part:IsA("PartOperation") then
		-- CSG results keep their source parts' colours unless told otherwise.
		part.UsePartColor = true
	end
end

-- Puts `part` at `world` and welds it to `body` there.
local function weldAt(model: Model, body: BasePart, part: BasePart, world: CFrame)
	part.CFrame = world
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
end

-- A new massless, non-colliding Part welded to `body` at the world CFrame `world`.
local function piece(model: Model, name: string, body: BasePart, size: Vector3, world: CFrame, color: Color3, options: PieceOptions?): Part
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local shape = options and options.shape
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Size = size
	if shape == "Ellipsoid" then
		-- A built-in sphere mesh stretched to the part's size (no asset).
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	setLook(part, name, color, options)
	weldAt(model, body, part, world)
	return part
end

-- Builds the helmet on the head. Returns the helmet centre and diameter (for the hoses).
local function buildHelmet(model: Model, rig: Rig, look: Look, pieces: { TemplatePiece }?): (CFrame, number)
	local head = rig.head
	-- The R6 head part is 2 x 1 x 1 shown through a 1.25 mesh; R15 heads are close to their size.
	local headSize = if rig.r6 then head.Size.Y * 1.25 else math.max(head.Size.X, head.Size.Y, head.Size.Z)
	local D = headSize * HELMET_PER_HEAD
	local centre = head.CFrame * CFrame.new(0, headSize * HELMET_LIFT, 0)
	local explorer = look.helmet == "explorer26"
	local visorColor = if explorer then P.gold else VISOR_DARK
	local trimColor = if explorer then P.gold else METAL
	local visorOptions: PieceOptions = {
		-- SmoothPlastic, not Glass: Glass renders a dark colour as pale grey (playtest).
		material = Enum.Material.SmoothPlastic,
		reflectance = if explorer then 0.5 else 0.35,
	}

	if pieces then
		local k = D / TEMPLATE_D
		for _, templatePiece in pieces do
			local part = templatePiece.part:Clone() :: BasePart
			part.Size = templatePiece.part.Size * k
			local world = centre * CFrame.new(templatePiece.rel.Position * k) * templatePiece.rel.Rotation
			if templatePiece.name == "HelmetShell" then
				setLook(part, "HelmetShell", SHELL_WHITE, { shadow = true })
			elseif templatePiece.name == "Visor" then
				setLook(part, "Visor", visorColor, visorOptions)
			else
				setLook(part, templatePiece.name, trimColor, { material = Enum.Material.Metal, reflectance = if explorer then 0.3 else 0.1 })
			end
			weldAt(model, head, part, world)
		end
	else
		-- Fallback without CSG: a white ball and a visor bulging out of its front.
		piece(model, "HelmetShell", head, Vector3.one * D, centre, SHELL_WHITE, { shape = "Ball", shadow = true })
		local fallbackVisor = table.clone(visorOptions)
		fallbackVisor.shape = "Ellipsoid"
		piece(model, "Visor", head, Vector3.new(0.78 * D, 0.62 * D, 0.5 * D), centre * CFrame.new(0, 0.02 * D, -0.28 * D), visorColor, fallbackVisor)
	end

	-- Metal neck ring where the helmet meets the shoulders.
	piece(
		model,
		"NeckRing",
		head,
		Vector3.new(NECK_RING_H * D, NECK_RING_D * D, NECK_RING_D * D),
		centre * CFrame.new(0, BOTTOM_CUT * D, 0) * UPRIGHT,
		trimColor,
		{ shape = "Cylinder", material = Enum.Material.Metal, reflectance = if explorer then 0.3 else 0.1 }
	)

	-- Two lamps on the temples, shining forward and a little down. One soft light for both.
	local elevation, azimuth = math.rad(45), math.rad(62) -- clear of the visor frame
	local forward = centre:VectorToWorldSpace(Vector3.new(0, -0.12, -1).Unit)
	for _, side in { -1, 1 } do
		local direction = Vector3.new(side * math.sin(azimuth) * math.cos(elevation), math.sin(elevation), -math.cos(azimuth) * math.cos(elevation))
		local spot = centre:PointToWorldSpace(direction * D * 0.5)
		local housingFrame = CFrame.lookAt(spot, spot + forward, centre.UpVector)
		piece(model, "LampHousing", head, Vector3.new(0.12 * D, 0.1 * D, 0.17 * D), housingFrame, METAL, { material = Enum.Material.Metal })
		local lens = piece(
			model,
			"LampLens",
			head,
			Vector3.new(0.025 * D, 0.08 * D, 0.08 * D),
			housingFrame * CFrame.new(0, 0, -0.085 * D) * ALONG_LOOK,
			P.cream,
			{ shape = "Cylinder", material = Enum.Material.Neon }
		)
		if side == 1 then
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Right -- the lens axis (X) points forward
			light.Range = 18
			light.Angle = 70
			light.Brightness = 1.4
			light.Color = P.cream
			light.Shadows = false
			light.Parent = lens
		end
	end

	-- Small camera on the left side of the helmet.
	local cameraDirection = Vector3.new(-math.cos(math.rad(10)) * math.sin(math.rad(80)), math.sin(math.rad(10)), -math.cos(math.rad(80)))
	local cameraSpot = centre:PointToWorldSpace(cameraDirection * D * 0.52)
	piece(
		model,
		"HelmetCamera",
		head,
		Vector3.new(0.1 * D, 0.11 * D, 0.24 * D),
		CFrame.lookAt(cameraSpot, cameraSpot + centre.LookVector, centre.UpVector),
		DARK
	)
	return centre, D
end

-- Builds the life-support backpack and the two hoses to the helmet.
local function buildBackpack(model: Model, rig: Rig, look: Look, helmetCentre: CFrame, helmetD: number)
	local torso = rig.torso
	local size = torso.Size
	-- R15 splits the trunk; the pack covers the upper torso and most of the lower one.
	local lower = rig.lowerTorso
	local trunk = size.Y + (if lower then lower.Size.Y else 0)
	local shift = if lower then -lower.Size.Y * 0.4 else 0
	local width = size.X * 0.78
	local depth = size.Z * 0.62
	local height = trunk * 0.8
	local bodyHeight = height - depth / 2
	-- Pack centre, on the back (+Z) of the torso.
	local base = torso.CFrame * CFrame.new(0, shift + trunk * 0.02, size.Z / 2 + depth / 2)
	local backFace = depth / 2

	-- Rounded pack: a box with a lying cylinder on top.
	local body = piece(model, "Backpack", torso, Vector3.new(width, bodyHeight, depth), base * CFrame.new(0, -depth / 4, 0), SHELL_WHITE, { shadow = true })
	piece(model, "BackpackTop", torso, Vector3.new(width, depth, depth), base * CFrame.new(0, height / 2 - depth / 2, 0), SHELL_WHITE, { shape = "Cylinder", shadow = true })
	-- Service panel (its edges read as panel lines) with a lime status light.
	piece(model, "ServicePanel", torso, Vector3.new(width * 0.62, bodyHeight * 0.5, 0.05), base * CFrame.new(0, bodyHeight * 0.05, backFace + 0.02), PANEL_GREY)
	local lightSize = math.max(0.08, width * 0.1)
	piece(model, "StatusLight", torso, Vector3.new(lightSize, lightSize, 0.05), base * CFrame.new(width * 0.2, bodyHeight * 0.2, backFace + 0.05), P.lime, {
		material = Enum.Material.Neon,
	})
	-- Two gas vents under the pack (the double jump puffs from here).
	local ventLength = math.max(0.1, height * 0.08)
	for _, side in { -1, 1 } do
		piece(
			model,
			"Vent",
			torso,
			Vector3.new(ventLength, width * 0.18, width * 0.18),
			base * CFrame.new(side * width * 0.27, -height / 2 - ventLength / 2 + 0.02, 0) * UPRIGHT,
			DARK,
			{ shape = "Cylinder", material = Enum.Material.Metal }
		)
	end
	local puff = Instance.new("Attachment")
	puff.Name = "JetPuff"
	puff.Position = Vector3.new(0, -bodyHeight / 2 - ventLength, 0)
	puff.Parent = body

	if look.backpack == "laika" then
		piece(model, "LaikaStripe", torso, Vector3.new(width * 0.12, bodyHeight * 0.85, 0.05), base * CFrame.new(-width * 0.4, -depth / 4, backFace + 0.02), P.magenta)
		piece(
			model,
			"LaikaPatch",
			torso,
			Vector3.new(0.04, width * 0.22, width * 0.22),
			base * CFrame.new(-width * 0.4, bodyHeight * 0.2, backFace + 0.06) * ALONG_LOOK,
			P.cream,
			{ shape = "Cylinder" }
		)
	end

	-- Two hoses from the top of the pack over the shoulders to the sides of the neck ring.
	local hoseWidth = math.max(0.1, size.X * 0.07)
	for _, side in { -1, 1 } do
		local from = base:PointToWorldSpace(Vector3.new(side * width * 0.36, height / 2 - depth * 0.45, -depth * 0.15))
		local to = helmetCentre:PointToWorldSpace(Vector3.new(side * NECK_RING_D * 0.47 * helmetD, (BOTTOM_CUT + 0.02) * helmetD, 0.12 * helmetD))
		local span = to - from
		if span.Magnitude > 0.05 then
			local middle = from + span / 2
			piece(
				model,
				"Hose",
				torso,
				Vector3.new(span.Magnitude, hoseWidth, hoseWidth),
				CFrame.lookAt(middle, to) * ALONG_LOOK,
				HOSE,
				{ shape = "Cylinder" }
			)
		end
	end
end

-- Builds (or rebuilds) the gear on `character` for what `player` wears now.
local function dress(player: Player, character: Model)
	local look = lookOf(player)
	local key = lookKey(look)
	if character:FindFirstChild(GEAR_NAME) and appliedLook[character] == key then
		return
	end
	local rig = findRig(character)
	local pieces = awaitTemplate()
	if rig == nil or character.Parent == nil or player.Character ~= character then
		return
	end
	-- Check again after waiting: the look may have changed, or been applied meanwhile.
	look = lookOf(player)
	key = lookKey(look)
	local existing = character:FindFirstChild(GEAR_NAME)
	if existing and appliedLook[character] == key then
		return
	end
	if existing then
		existing:Destroy()
	end
	appliedLook[character] = key
	local model = Instance.new("Model")
	model.Name = GEAR_NAME
	model:SetAttribute("Helmet", look.helmet)
	model:SetAttribute("Backpack", look.backpack)
	model.Parent = character
	local centre, diameter = buildHelmet(model, rig, look, pieces)
	buildBackpack(model, rig, look, centre, diameter)
end

local function safeDress(player: Player, character: Model)
	local ok, err = pcall(dress, player, character)
	if not ok then
		warn(`[SpaceBaseOdyssey] could not dress {player.Name}: {err}`)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	hideHatsAndHair(character)
	task.spawn(function()
		if not character:IsDescendantOf(workspace) then
			character.AncestryChanged:Wait()
		end
		task.wait() -- let the rig assemble before measuring it
		safeDress(player, character)
	end)
	character.Destroying:Once(function()
		appliedLook[character] = nil
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

local function redress(player: Player)
	local character = player.Character
	if character and character.Parent then
		task.spawn(safeDress, player, character)
	end
end

----------------------------------------------------------------------------------------------------
-- Public API

-- progressService: ProgressService (already started), used only when there is no baseService.
-- baseService: BaseService (already started): what each player has equipped.
function SuitService.start(progressService: ProgressApi?, baseService: BaseApi?)
	assert(not started, "SuitService already started")
	started = true
	progressApi = progressService
	baseApi = baseService
	startTemplate()
	if baseService then
		baseService.onEquippedChanged(redress)
	elseif progressService then
		progressService.onChanged(function()
			for _, player in Players:GetPlayers() do
				redress(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(addPlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

-- Spawns `player` with their own avatar; the helmet and backpack are added on spawn.
function SuitService.loadCharacter(player: Player)
	player:LoadCharacter()
end

return SuitService
