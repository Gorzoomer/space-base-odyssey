--!strict
-- Space Base Odyssey - pet models (Parts only). Based on the original pet designs by team member
-- Santiago Alvarado Delgadillo (his Stage 6 prototype pack: Laika the cosmonaut dog, the moon cheese
-- with a helmet, the moon rabbit and the space chimp). Stage 7 adds detail while keeping each pet's
-- character: paws and boots, tails, ears with an inner colour, eyes with a shine, little space suits,
-- helmets with rims and small backpacks with a light.
-- Pure data: no Roblox instances. The small helpers below only do math so the shapes stay readable.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.
--
-- Data shape (read by PetService and by the BasePanel / Wardrobe previews):
--   PetModels[petId] = { PetPart }, an array. Each part's CFrame is relative to the model's root
--   (centre of the bottom of the model, facing -Z, +Y up, the pet's left is -X), in model units
--   (PetService scales every pet to its own height).
--   Optional animation fields (previews can ignore them; the parts are already in their rest pose):
--   * anim: the joint the part moves with, as a dotted chain from the body: "head", "head.earL",
--     "tail", "legFL". Parts without anim move with the body. PetService picks the motion from the
--     last name of the chain:
--       head            slow look-around tilt and nod
--       tail            wag side to side (faster when walking)
--       earL / earR     small wiggles with a quick wiggle now and then; flop back when walking
--       legFL legFR legBL legBR legL legR armL armR   swing while walking
--       antenna         springy sway
--     The name "light" at the end ("light" or "head.light") is not a joint: that part blinks like a
--     status light and moves with the joint before it (or the body).
--   * pivot: { x, y, z } the point the joint turns around, in model units. One part of each joint
--     must give it (by convention the first part listed for that joint).

export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"

export type PetPart = {
	name: string,
	shape: Shape, -- a Ball with unequal sizes is an egg shape (use a sphere mesh to show it)
	size: { number }, -- x, y, z
	cframe: { number }, -- 12 numbers: x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
	color: { number }, -- r, g, b (0-255)
	material: string, -- Enum.Material name
	transparency: number,
	reflectance: number,
	anim: string?, -- joint chain, see above
	pivot: { number }?, -- joint turning point, see above
}

type Opts = {
	rot: { number }?, -- degrees, applied like CFrame.Angles(rx, ry, rz)
	mat: string?,
	tr: number?,
	rf: number?,
	anim: string?,
	pivot: { number }?,
}

----------------------------------------------------------------------------------------------------
-- Colours (r, g, b). Accents copy the "Lunar Sunrise" palette in Theme.luau (cyan, orange, lime,
-- magenta, gold, night tones) so the pets match the base; fur and cheese keep Santiago's colours.

local SUIT = { 238, 242, 250 } -- white suit fabric
local METAL = { 200, 205, 215 } -- rims, tanks
local BOOT = { 110, 118, 138 } -- boots and gloves
local DARK = { 22, 24, 32 } -- eyes, nose
local WHITE = { 255, 255, 255 } -- eye shine
local GLASS = { 175, 225, 255 } -- helmet glass
local PINK = { 255, 140, 170 } -- noses, tongues
local CYAN = { 46, 230, 255 } -- Theme cyan
local ORANGE = { 255, 138, 61 } -- Theme orange
local LIME = { 155, 225, 93 } -- Theme lime
local MAGENTA = { 255, 79, 163 } -- Theme magenta
local GOLD = { 255, 209, 102 } -- Theme gold
local NIGHT_LIGHT = { 31, 37, 71 } -- Theme nightLight (control boxes)
local NIGHT_LINE = { 52, 60, 112 } -- Theme nightLine (pack lids)

----------------------------------------------------------------------------------------------------
-- Math helpers (pure: they only build the 12 CFrame numbers)

local function round(n: number): number
	return math.floor(n * 10000 + 0.5) / 10000
end

-- Rotation matrix of CFrame.Angles(rx, ry, rz) in degrees (= Rx * Ry * Rz), row by row.
local function angles(rx: number, ry: number, rz: number): { number }
	local ax, ay, az = math.rad(rx), math.rad(ry), math.rad(rz)
	local cx, sx = math.cos(ax), math.sin(ax)
	local cy, sy = math.cos(ay), math.sin(ay)
	local cz, sz = math.cos(az), math.sin(az)
	return {
		cy * cz,
		-cy * sz,
		sy,
		cx * sz + sx * sy * cz,
		cx * cz - sx * sy * sz,
		-sx * cy,
		sx * sz - cx * sy * cz,
		sx * cz + cx * sy * sz,
		cx * cy,
	}
end

-- Rotation whose X axis (a cylinder's length) points along `d`.
local function alongX(d: { number }): { number }
	local length = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	local x = { d[1] / length, d[2] / length, d[3] / length }
	local h = if math.abs(x[2]) < 0.9 then { 0, 1, 0 } else { 1, 0, 0 }
	-- z = normalize(x cross h), y = z cross x
	local z = { x[2] * h[3] - x[3] * h[2], x[3] * h[1] - x[1] * h[3], x[1] * h[2] - x[2] * h[1] }
	local zl = math.sqrt(z[1] * z[1] + z[2] * z[2] + z[3] * z[3])
	z = { z[1] / zl, z[2] / zl, z[3] / zl }
	local y = { z[2] * x[3] - z[3] * x[2], z[3] * x[1] - z[1] * x[3], z[1] * x[2] - z[2] * x[1] }
	return { x[1], y[1], z[1], x[2], y[2], z[2], x[3], y[3], z[3] }
end

local function make(name: string, shape: Shape, size: { number }, pos: { number }, r: { number }, color: { number }, opts: Opts?): PetPart
	local o: Opts = opts or {}
	local cframe = { round(pos[1]), round(pos[2]), round(pos[3]) }
	for _, v in r do
		table.insert(cframe, round(v))
	end
	return {
		name = name,
		shape = shape,
		size = { round(size[1]), round(size[2]), round(size[3]) },
		cframe = cframe,
		color = color,
		material = o.mat or "SmoothPlastic",
		transparency = o.tr or 0,
		reflectance = o.rf or 0,
		anim = o.anim,
		pivot = o.pivot,
	}
end

-- A part at `pos` turned by opts.rot (degrees).
local function P(name: string, shape: Shape, size: { number }, pos: { number }, color: { number }, opts: Opts?): PetPart
	local rot = if opts and opts.rot then opts.rot else { 0, 0, 0 }
	return make(name, shape, size, pos, angles(rot[1], rot[2], rot[3]), color, opts)
end

-- A cylinder of diameter `d` from point `a` to point `b`.
local function Seg(name: string, a: { number }, b: { number }, d: number, color: { number }, opts: Opts?): PetPart
	local dir = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
	local length = math.sqrt(dir[1] * dir[1] + dir[2] * dir[2] + dir[3] * dir[3])
	local mid = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }
	return make(name, "Cylinder", { length, d, d }, mid, alongX(dir), color, opts)
end

-- Left side is -X (sign -1), right side is +X (sign 1).
local SIDES: { { s: number, n: string } } = { { s = -1, n = "L" }, { s = 1, n = "R" } }

----------------------------------------------------------------------------------------------------
-- Laika the cosmonaut dog (33 parts): white suit with an orange band, brown and white face, pointy
-- ears, four booted paws, a wagging tail, a bubble helmet on a tilted collar and a backpack light.

local function laika(): { PetPart }
	local FUR = { 178, 122, 72 }
	local FUR_DARK = { 140, 88, 45 }
	local FUR_LIGHT = { 245, 242, 235 }
	local EAR_IN = { 235, 170, 160 }
	local list: { PetPart } = {}
	local function add(p: PetPart)
		table.insert(list, p)
	end

	-- Suit
	add(P("SuitTorso", "Ball", { 1.9, 1.6, 2.8 }, { 0, 1.55, 0.25 }, SUIT))
	add(P("SuitBand", "Ball", { 1.96, 1.66, 0.28 }, { 0, 1.55, 0.45 }, ORANGE))
	add(P("ChestBox", "Block", { 0.8, 0.45, 0.2 }, { 0, 1.25, -1.05 }, NIGHT_LIGHT))
	add(P("ChestLightA", "Ball", { 0.13, 0.13, 0.13 }, { -0.2, 1.3, -1.16 }, CYAN, { mat = "Neon" }))
	add(P("ChestLightB", "Ball", { 0.13, 0.13, 0.13 }, { 0.2, 1.3, -1.16 }, LIME, { mat = "Neon" }))
	add(P("Backpack", "Block", { 1.0, 0.5, 1.1 }, { 0, 2.4, 0.55 }, METAL, { mat = "Metal" }))
	add(P("BackpackLid", "Block", { 1.05, 0.12, 1.15 }, { 0, 2.68, 0.55 }, NIGHT_LINE))
	add(P("BackpackLight", "Ball", { 0.24, 0.24, 0.24 }, { 0.3, 2.82, 0.85 }, ORANGE, { mat = "Neon", anim = "light" }))
	add(P("HelmetRim", "Cylinder", { 0.22, 2.2, 2.2 }, { 0, 2.0, -0.95 }, METAL, { rot = { -25, 0, 90 }, mat = "Metal" }))

	-- Head (turns around the neck)
	local head = { 0, 2.1, -0.8 }
	add(P("DogHead", "Ball", { 1.7, 1.55, 1.6 }, { 0, 2.65, -1.05 }, FUR, { anim = "head", pivot = head }))
	add(P("Blaze", "Ball", { 0.5, 0.9, 0.4 }, { 0, 2.95, -1.72 }, FUR_LIGHT, { anim = "head" }))
	add(P("Muzzle", "Ball", { 0.95, 0.7, 0.9 }, { 0, 2.35, -1.85 }, FUR_LIGHT, { anim = "head" }))
	add(P("Nose", "Ball", { 0.32, 0.24, 0.24 }, { 0, 2.55, -2.27 }, DARK, { anim = "head" }))
	add(P("Tongue", "Ball", { 0.24, 0.1, 0.3 }, { 0.06, 2.03, -2.12 }, PINK, { anim = "head" }))
	for _, side in SIDES do
		add(P("Eye" .. side.n, "Ball", { 0.3, 0.3, 0.3 }, { 0.42 * side.s, 2.85, -1.75 }, DARK, { anim = "head" }))
	end
	-- Both shines sit up and to the left, as if one sun lights the face.
	add(P("ShineL", "Ball", { 0.11, 0.11, 0.11 }, { -0.47, 2.92, -1.87 }, WHITE, { mat = "Neon", anim = "head" }))
	add(P("ShineR", "Ball", { 0.11, 0.11, 0.11 }, { 0.37, 2.92, -1.87 }, WHITE, { mat = "Neon", anim = "head" }))
	for _, side in SIDES do
		local joint = "head.ear" .. side.n
		-- A wedge turned so its triangle faces forward: straight inner edge, slope going outward.
		local turn = { 0, -90 * side.s, 0 }
		add(P("Ear" .. side.n, "Wedge", { 0.18, 0.8, 0.55 }, { 0.62 * side.s, 3.5, -0.95 }, FUR_DARK, {
			rot = turn,
			anim = joint,
			pivot = { 0.6 * side.s, 3.15, -0.95 },
		}))
		add(P("EarInner" .. side.n, "Wedge", { 0.06, 0.55, 0.35 }, { 0.58 * side.s, 3.4, -1.05 }, EAR_IN, {
			rot = turn,
			anim = joint,
		}))
	end
	add(P("HelmetGlass", "Ball", { 2.6, 2.6, 2.6 }, { 0, 2.75, -1.2 }, GLASS, { mat = "Glass", tr = 0.55, rf = 0.2, anim = "head" }))

	-- Legs with booted paws (front left and back right step together)
	for _, leg in { { n = "FL", x = -0.5, z = -0.5 }, { n = "FR", x = 0.5, z = -0.5 }, { n = "BL", x = -0.5, z = 0.95 }, { n = "BR", x = 0.5, z = 0.95 } } do
		local joint = "leg" .. leg.n
		add(Seg("Leg" .. leg.n, { leg.x, 1.2, leg.z }, { leg.x, 0.2, leg.z }, 0.5, SUIT, {
			anim = joint,
			pivot = { leg.x, 1.15, leg.z },
		}))
		add(P("Paw" .. leg.n, "Ball", { 0.55, 0.32, 0.7 }, { leg.x, 0.16, leg.z - 0.12 }, BOOT, { anim = joint }))
	end

	-- Tail
	add(Seg("Tail", { 0, 1.75, 1.5 }, { 0, 2.45, 2.35 }, 0.35, FUR, { anim = "tail", pivot = { 0, 1.75, 1.5 } }))
	add(P("TailTip", "Ball", { 0.42, 0.42, 0.42 }, { 0, 2.47, 2.37 }, FUR_LIGHT, { anim = "tail" }))
	return list
end

----------------------------------------------------------------------------------------------------
-- Cheese, the moon cheese wedge (30 parts): tall flat face in front with big eyes and a smile, holes
-- all over, a glass helmet over the top with a metal rim lying on the slope, a springy antenna,
-- little arms and boots, and an air pack with a light on its back.

local function cheese(): { PetPart }
	local CHEESE = { 255, 215, 35 }
	local HOLE = { 230, 175, 20 }
	local MOUTH = { 150, 70, 25 }
	local BLUSH = { 255, 150, 140 }
	local EYE_WHITE = { 250, 250, 250 }
	local SLOPE = 42.5 -- the wedge's top slope, in degrees (2.2 up over 2.4 back)
	local list: { PetPart } = {}
	local function add(p: PetPart)
		table.insert(list, p)
	end

	-- Body: a wedge turned around so its tall face looks forward (front face at z = -1.2)
	add(P("CheeseWedge", "Wedge", { 2.4, 2.2, 2.4 }, { 0, 1.5, 0 }, CHEESE, { rot = { 0, 180, 0 } }))
	add(P("HoleFront1", "Ball", { 0.5, 0.5, 0.5 }, { -0.8, 0.8, -1.03 }, HOLE))
	add(P("HoleFront2", "Ball", { 0.36, 0.36, 0.36 }, { 0.85, 0.65, -1.07 }, HOLE))
	add(P("HoleSideL", "Ball", { 0.5, 0.5, 0.5 }, { -1.03, 0.95, 0.05 }, HOLE))
	add(P("HoleSideR", "Ball", { 0.4, 0.4, 0.4 }, { 1.07, 0.75, -0.55 }, HOLE))
	add(P("HoleBack", "Ball", { 0.36, 0.36, 0.36 }, { 0.85, 0.55, 1.05 }, HOLE))

	-- Face: round balls sunk into the flat front so each shows as a round dot (eyes, mouth, cheeks)
	for _, side in SIDES do
		add(P("EyeWhite" .. side.n, "Ball", { 0.6, 0.6, 0.6 }, { 0.42 * side.s, 1.9, -1.06 }, EYE_WHITE))
		add(P("Pupil" .. side.n, "Ball", { 0.34, 0.34, 0.34 }, { 0.38 * side.s, 1.86, -1.23 }, DARK))
	end
	add(P("ShineL", "Ball", { 0.12, 0.12, 0.12 }, { -0.45, 1.97, -1.38 }, WHITE, { mat = "Neon" }))
	add(P("ShineR", "Ball", { 0.12, 0.12, 0.12 }, { 0.31, 1.97, -1.38 }, WHITE, { mat = "Neon" }))
	add(P("Mouth", "Ball", { 0.3, 0.3, 0.3 }, { 0, 1.4, -1.1 }, MOUTH))
	add(P("Tongue", "Ball", { 0.12, 0.12, 0.12 }, { 0, 1.34, -1.23 }, PINK))
	for _, side in SIDES do
		add(P("Cheek" .. side.n, "Ball", { 0.3, 0.3, 0.3 }, { 0.8 * side.s, 1.55, -1.1 }, BLUSH))
	end

	-- Helmet: a rim lying on the slope near the top and a glass bubble over the face and top
	add(P("HelmetRim", "Cylinder", { 0.2, 2.5, 2.5 }, { 0, 2.03, -0.5 }, METAL, { rot = { SLOPE, 0, 90 }, mat = "Metal" }))
	add(P("HelmetGlass", "Ball", { 2.4, 2.4, 2.4 }, { 0, 2.05, -0.5 }, GLASS, { mat = "Glass", tr = 0.55, rf = 0.2 }))
	add(Seg("Antenna", { 0.45, 3.05, -0.35 }, { 0.6, 3.75, -0.2 }, 0.08, METAL, {
		mat = "Metal",
		anim = "antenna",
		pivot = { 0.45, 3.05, -0.35 },
	}))
	add(P("AntennaBall", "Ball", { 0.26, 0.26, 0.26 }, { 0.6, 3.8, -0.2 }, MAGENTA, { mat = "Neon", anim = "antenna" }))

	-- Little legs and boots, little arms and gloves
	for _, side in SIDES do
		local leg = "leg" .. side.n
		add(Seg("Leg" .. side.n, { 0.5 * side.s, 0.55, -0.3 }, { 0.5 * side.s, 0.2, -0.3 }, 0.3, SUIT, {
			anim = leg,
			pivot = { 0.5 * side.s, 0.5, -0.3 },
		}))
		add(P("Boot" .. side.n, "Ball", { 0.55, 0.32, 0.75 }, { 0.5 * side.s, 0.16, -0.42 }, BOOT, { anim = leg }))
		local arm = "arm" .. side.n
		add(Seg("Arm" .. side.n, { 1.15 * side.s, 1.25, -0.5 }, { 1.6 * side.s, 0.8, -0.6 }, 0.22, SUIT, {
			anim = arm,
			pivot = { 1.15 * side.s, 1.25, -0.5 },
		}))
		add(P("Glove" .. side.n, "Ball", { 0.34, 0.34, 0.34 }, { 1.65 * side.s, 0.75, -0.62 }, BOOT, { anim = arm }))
	end

	-- Air pack lying on the back slope
	add(P("AirPack", "Block", { 1.1, 0.6, 0.4 }, { 0, 1.06, 0.78 }, METAL, { rot = { SLOPE, 0, 0 }, mat = "Metal" }))
	add(P("PackLight", "Ball", { 0.22, 0.22, 0.22 }, { 0.35, 1.3, 1.0 }, ORANGE, { mat = "Neon", anim = "light" }))
	return list
end

----------------------------------------------------------------------------------------------------
-- The moon rabbit (28 parts): white suit with a cyan band, soft head with cheeks and teeth, tall
-- ears with pink insides, big booted feet, a fluffy tail, a tall bubble helmet and an orange pack.

local function rabbit(): { PetPart }
	local FUR = { 248, 248, 252 }
	local EAR_IN = { 255, 155, 185 }
	local EYE = { 200, 40, 95 } -- Santiago's ruby eyes
	local list: { PetPart } = {}
	local function add(p: PetPart)
		table.insert(list, p)
	end

	-- Suit
	add(P("SuitBody", "Ball", { 2.0, 2.0, 2.2 }, { 0, 1.2, 0.2 }, SUIT))
	add(P("SuitBand", "Ball", { 2.06, 0.25, 2.26 }, { 0, 1.2, 0.2 }, CYAN))
	add(P("ChestBox", "Block", { 0.7, 0.4, 0.15 }, { 0, 1.45, -0.86 }, NIGHT_LIGHT))
	add(P("ChestLight", "Ball", { 0.12, 0.12, 0.12 }, { 0.18, 1.45, -0.94 }, LIME, { mat = "Neon" }))
	add(P("HelmetRim", "Cylinder", { 0.25, 2.1, 2.1 }, { 0, 2.0, -0.2 }, METAL, { rot = { 0, 0, 90 }, mat = "Metal" }))
	add(P("Backpack", "Block", { 1.2, 1.0, 0.45 }, { 0, 1.6, 1.3 }, ORANGE))
	add(P("BackpackLight", "Ball", { 0.22, 0.22, 0.22 }, { 0, 2.0, 1.55 }, LIME, { mat = "Neon", anim = "light" }))

	-- Head
	add(P("BunnyHead", "Ball", { 1.75, 1.6, 1.65 }, { 0, 2.75, -0.25 }, FUR, { anim = "head", pivot = { 0, 2.05, -0.1 } }))
	for _, side in SIDES do
		add(P("Cheek" .. side.n, "Ball", { 0.55, 0.45, 0.45 }, { 0.2 * side.s, 2.5, -0.95 }, FUR, { anim = "head" }))
	end
	add(P("Nose", "Ball", { 0.22, 0.16, 0.14 }, { 0, 2.68, -1.1 }, PINK, { anim = "head" }))
	add(P("Teeth", "Block", { 0.2, 0.15, 0.05 }, { 0, 2.35, -1.12 }, WHITE, { anim = "head" }))
	for _, side in SIDES do
		add(P("Eye" .. side.n, "Ball", { 0.36, 0.42, 0.3 }, { 0.42 * side.s, 2.95, -0.9 }, EYE, { anim = "head" }))
	end
	add(P("ShineL", "Ball", { 0.12, 0.12, 0.12 }, { -0.48, 3.03, -1.04 }, WHITE, { mat = "Neon", anim = "head" }))
	add(P("ShineR", "Ball", { 0.12, 0.12, 0.12 }, { 0.36, 3.03, -1.04 }, WHITE, { mat = "Neon", anim = "head" }))
	for _, side in SIDES do
		local joint = "head.ear" .. side.n
		local lean = -12 * side.s -- each ear leans a little outward
		local dir = { math.sin(math.rad(12)) * side.s, math.cos(math.rad(12)) } -- outward and up
		local base = { 0.4 * side.s, 3.4 }
		add(P("Ear" .. side.n, "Ball", { 0.5, 1.7, 0.3 }, { base[1] + dir[1] * 0.85, base[2] + dir[2] * 0.85, -0.2 }, FUR, {
			rot = { 0, 0, lean },
			anim = joint,
			pivot = { base[1], base[2], -0.2 },
		}))
		add(P("EarInner" .. side.n, "Ball", { 0.3, 1.3, 0.12 }, { base[1] + dir[1] * 0.85, base[2] + dir[2] * 0.85, -0.33 }, EAR_IN, {
			rot = { 0, 0, lean },
			anim = joint,
		}))
	end
	add(P("HelmetGlass", "Ball", { 3.2, 3.6, 3.1 }, { 0, 3.6, -0.2 }, GLASS, { mat = "Glass", tr = 0.55, rf = 0.2, anim = "head" }))

	-- Arms with gloves, big booted feet (a rabbit hops with both feet together)
	for _, side in SIDES do
		local arm = "arm" .. side.n
		add(Seg("Arm" .. side.n, { 0.85 * side.s, 1.65, -0.2 }, { 1.05 * side.s, 0.95, -0.55 }, 0.32, SUIT, {
			anim = arm,
			pivot = { 0.85 * side.s, 1.65, -0.2 },
		}))
		add(P("Glove" .. side.n, "Ball", { 0.38, 0.38, 0.38 }, { 1.07 * side.s, 0.9, -0.57 }, BOOT, { anim = arm }))
		add(P("Foot" .. side.n, "Ball", { 0.6, 0.38, 1.15 }, { 0.6 * side.s, 0.19, -0.35 }, BOOT, {
			anim = "leg" .. side.n,
			pivot = { 0.6 * side.s, 0.5, 0 },
		}))
	end

	-- Fluffy tail
	add(P("Tail", "Ball", { 0.65, 0.65, 0.65 }, { 0, 0.6, 1.15 }, FUR, { anim = "tail", pivot = { 0, 0.6, 0.9 } }))
	return list
end

----------------------------------------------------------------------------------------------------
-- The space chimp (32 parts): gold foil vest (Santiago's), long arms with white sleeves, a brown
-- head with a light face, round ears, a bubble helmet with a cap light and a cyan backpack.
-- Chimpanzees are apes, so no tail.

local function monkey(): { PetPart }
	local FOIL = { 215, 175, 55 }
	local FUR = { 115, 72, 42 }
	local SKIN = { 225, 180, 135 }
	local EAR_IN = { 200, 130, 110 }
	local MOUTH = { 90, 40, 30 }
	local list: { PetPart } = {}
	local function add(p: PetPart)
		table.insert(list, p)
	end

	-- Suit
	add(P("SuitVest", "Ball", { 1.8, 2.0, 1.5 }, { 0, 1.6, 0 }, FOIL, { mat = "Foil", rf = 0.25 }))
	add(P("SuitBand", "Ball", { 1.86, 0.22, 1.56 }, { 0, 1.15, 0 }, CYAN))
	add(P("ChestBox", "Block", { 0.8, 0.45, 0.15 }, { 0, 1.95, -0.72 }, NIGHT_LIGHT))
	add(P("ChestLightA", "Ball", { 0.12, 0.12, 0.12 }, { -0.2, 1.97, -0.8 }, CYAN, { mat = "Neon" }))
	add(P("ChestLightB", "Ball", { 0.12, 0.12, 0.12 }, { 0.2, 1.97, -0.8 }, MAGENTA, { mat = "Neon" }))
	add(P("HelmetRim", "Cylinder", { 0.25, 2.2, 2.2 }, { 0, 2.45, -0.05 }, METAL, { rot = { 0, 0, 90 }, mat = "Metal" }))
	add(P("Backpack", "Block", { 1.2, 1.2, 0.5 }, { 0, 1.8, 0.85 }, CYAN))
	add(P("BackpackLight", "Ball", { 0.2, 0.2, 0.2 }, { 0.3, 2.42, 0.95 }, GOLD, { mat = "Neon", anim = "light" }))

	-- Legs and boots, long arms and hands
	for _, side in SIDES do
		local leg = "leg" .. side.n
		add(Seg("Leg" .. side.n, { 0.45 * side.s, 0.9, 0 }, { 0.5 * side.s, 0.3, -0.05 }, 0.45, SUIT, {
			anim = leg,
			pivot = { 0.45 * side.s, 0.9, 0 },
		}))
		add(P("Boot" .. side.n, "Ball", { 0.6, 0.32, 0.85 }, { 0.5 * side.s, 0.16, -0.2 }, BOOT, { anim = leg }))
		local arm = "arm" .. side.n
		add(Seg("Arm" .. side.n, { 0.85 * side.s, 2.2, 0 }, { 1.15 * side.s, 0.95, -0.2 }, 0.4, SUIT, {
			anim = arm,
			pivot = { 0.85 * side.s, 2.2, 0 },
		}))
		add(P("Hand" .. side.n, "Ball", { 0.45, 0.45, 0.45 }, { 1.17 * side.s, 0.85, -0.22 }, SKIN, { anim = arm }))
	end

	-- Head
	add(P("MonkeyHead", "Ball", { 1.8, 1.7, 1.7 }, { 0, 3.25, 0 }, FUR, { anim = "head", pivot = { 0, 2.5, 0 } }))
	add(P("FaceMask", "Ball", { 1.4, 1.15, 0.9 }, { 0, 3.15, -0.55 }, SKIN, { anim = "head" }))
	add(P("Muzzle", "Ball", { 0.95, 0.6, 0.6 }, { 0, 2.85, -0.85 }, SKIN, { anim = "head" }))
	add(P("Brow", "Ball", { 1.3, 0.3, 0.4 }, { 0, 3.62, -0.75 }, FUR, { anim = "head" }))
	for _, side in SIDES do
		add(P("Nostril" .. side.n, "Ball", { 0.1, 0.1, 0.1 }, { 0.1 * side.s, 2.95, -1.13 }, MOUTH, { anim = "head" }))
	end
	add(P("Mouth", "Ball", { 0.45, 0.1, 0.08 }, { 0, 2.72, -1.12 }, MOUTH, { anim = "head" }))
	for _, side in SIDES do
		add(P("Eye" .. side.n, "Ball", { 0.28, 0.32, 0.2 }, { 0.3 * side.s, 3.38, -0.95 }, DARK, { anim = "head" }))
	end
	add(P("ShineL", "Ball", { 0.1, 0.1, 0.1 }, { -0.35, 3.44, -1.05 }, WHITE, { mat = "Neon", anim = "head" }))
	add(P("ShineR", "Ball", { 0.1, 0.1, 0.1 }, { 0.25, 3.44, -1.05 }, WHITE, { mat = "Neon", anim = "head" }))
	for _, side in SIDES do
		local joint = "head.ear" .. side.n
		add(P("Ear" .. side.n, "Cylinder", { 0.25, 0.75, 0.75 }, { 0.98 * side.s, 3.3, 0.05 }, SKIN, {
			anim = joint,
			pivot = { 0.85 * side.s, 3.3, 0.05 },
		}))
		add(P("EarInner" .. side.n, "Cylinder", { 0.06, 0.48, 0.48 }, { 1.12 * side.s, 3.3, 0.05 }, EAR_IN, { anim = joint }))
	end
	add(P("HelmetGlass", "Ball", { 2.9, 2.6, 2.9 }, { 0, 3.35, -0.1 }, GLASS, { mat = "Glass", tr = 0.55, rf = 0.2, anim = "head" }))
	add(P("HelmetCap", "Cylinder", { 0.14, 0.7, 0.7 }, { 0, 4.62, -0.1 }, METAL, { rot = { 0, 0, 90 }, mat = "Metal", anim = "head" }))
	add(P("CapLight", "Ball", { 0.22, 0.22, 0.22 }, { 0, 4.75, -0.1 }, LIME, { mat = "Neon", anim = "head.light" }))
	return list
end

----------------------------------------------------------------------------------------------------

local PetModels: { [string]: { PetPart } } = {
	laika = laika(),
	cheese = cheese(),
	rabbit = rabbit(),
	monkey = monkey(),
}

-- Colour tables are shared between parts, so freeze each table only once.
local function freeze(t: any)
	if not table.isfrozen(t) then
		table.freeze(t)
	end
end

for _, parts in PetModels do
	for _, p in parts do
		freeze(p.size)
		freeze(p.cframe)
		freeze(p.color)
		if p.pivot then
			freeze(p.pivot)
		end
		freeze(p)
	end
	freeze(parts)
end

return table.freeze(PetModels)
