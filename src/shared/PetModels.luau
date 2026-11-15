--!strict
-- Space Base Odyssey - pet models (Parts only), designed by team member Santiago Alvarado Delgadillo
-- in his Stage 6 prototype pack and converted to data by a script. Each part's CFrame is relative to
-- the model's root (centre of the bottom of the model, facing -Z). Pure data: no Roblox instances.
-- SI disclosure: converted with AI assistance (Claude, Anthropic) and reviewed by the team.

export type PetPart = {
	name: string,
	shape: "Block" | "Ball" | "Cylinder" | "Wedge",
	size: { number }, -- x, y, z
	cframe: { number }, -- 12 numbers: x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
	color: { number }, -- r, g, b (0-255)
	material: string, -- Enum.Material name
	transparency: number,
	reflectance: number,
}

local PetModels: { [string]: { PetPart } } = {
	-- Pet_Quesito_Lunar (9 parts, display stand removed)
	cheese = {
		{ name = "CheeseWedge", shape = "Wedge", size = { 2.6, 2.2, 3.2 }, cframe = { 0, 1.1, 0, 0.707, 0, 0.707, 0, 1, 0, -0.707, 0, 0.707 }, color = { 255, 215, 35 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Hole1", shape = "Ball", size = { 0.7, 0.7, 0.7 }, cframe = { 0.424, 1.3, -1.131, 0.707, 0, 0.707, 0, 1, 0, -0.707, 0, 0.707 }, color = { 230, 175, 20 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Hole2", shape = "Ball", size = { 0.5, 0.5, 0.5 }, cframe = { -0.495, 0.8, 1.061, 0.707, 0, 0.707, 0, 1, 0, -0.707, 0, 0.707 }, color = { 230, 175, 20 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EyeL", shape = "Ball", size = { 0.42, 0.42, 0.42 }, cframe = { -0.55, 1, -1.35, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 20, 22, 28 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EyeR", shape = "Ball", size = { 0.42, 0.42, 0.42 }, cframe = { 0.55, 1, -1.35, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 20, 22, 28 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "ShineL", shape = "Ball", size = { 0.16, 0.16, 0.16 }, cframe = { -0.48, 1.1, -1.52, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 255, 255, 255 }, material = "Neon", transparency = 0, reflectance = 0 },
		{ name = "ShineR", shape = "Ball", size = { 0.16, 0.16, 0.16 }, cframe = { 0.62, 1.1, -1.52, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 255, 255, 255 }, material = "Neon", transparency = 0, reflectance = 0 },
		{ name = "HelmetRing", shape = "Cylinder", size = { 0.35, 2.2, 2.2 }, cframe = { 0, 2.25, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, color = { 220, 225, 235 }, material = "Metal", transparency = 0, reflectance = 0 },
		{ name = "HelmetGlass", shape = "Ball", size = { 2.3, 2.3, 2.3 }, cframe = { 0, 2.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 165, 220, 255 }, material = "Glass", transparency = 0.4, reflectance = 0.2 },
	},
	-- Pet_Laika_Cosmonaut (17 parts, display stand removed)
	laika = {
		{ name = "SuitTorso", shape = "Block", size = { 1.9, 2.1, 2.4 }, cframe = { 0, 1.125, 0.237, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 238, 242, 250 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "ChestPlate", shape = "Block", size = { 1.3, 0.6, 0.2 }, cframe = { 0, 1.325, -0.983, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 210, 215, 225 }, material = "Metal", transparency = 0, reflectance = 0 },
		{ name = "Leg", shape = "Cylinder", size = { 1.1, 0.65, 0.65 }, cframe = { -0.65, 0.325, -0.563, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, color = { 235, 240, 248 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Leg", shape = "Cylinder", size = { 1.1, 0.65, 0.65 }, cframe = { -0.65, 0.325, 0.837, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, color = { 235, 240, 248 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Leg", shape = "Cylinder", size = { 1.1, 0.65, 0.65 }, cframe = { 0.65, 0.325, -0.563, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, color = { 235, 240, 248 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Leg", shape = "Cylinder", size = { 1.1, 0.65, 0.65 }, cframe = { 0.65, 0.325, 0.837, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, color = { 235, 240, 248 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "DogHead", shape = "Ball", size = { 2.1, 1.9, 2.1 }, cframe = { 0, 2.525, -0.163, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 178, 122, 72 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "WhiteStripe", shape = "Block", size = { 0.55, 1.6, 1.8 }, cframe = { 0, 2.605, -0.343, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 245, 242, 235 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Snout", shape = "Block", size = { 0.95, 0.75, 0.9 }, cframe = { 0, 2.275, -1.112, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 245, 242, 235 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Nose", shape = "Ball", size = { 0.4, 0.32, 0.4 }, cframe = { 0, 2.475, -1.543, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 25, 25, 30 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EyeL", shape = "Ball", size = { 0.32, 0.32, 0.32 }, cframe = { -0.48, 2.675, -1.083, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 20, 20, 25 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EyeR", shape = "Ball", size = { 0.32, 0.32, 0.32 }, cframe = { 0.48, 2.675, -1.083, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 20, 20, 25 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarL", shape = "Wedge", size = { 0.5, 0.8, 0.9 }, cframe = { -0.85, 3.275, -0.063, 0.878, -0.479, 0, 0.479, 0.878, 0, 0, 0, 1 }, color = { 140, 88, 45 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarR", shape = "Wedge", size = { 0.5, 0.8, 0.9 }, cframe = { 0.85, 3.275, -0.063, 0.878, 0.479, 0, -0.479, 0.878, 0, 0, 0, 1 }, color = { 140, 88, 45 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "Tail", shape = "Cylinder", size = { 1.3, 0.45, 0.45 }, cframe = { 0, 1.625, 1.587, 0, -1, 0, 0.765, 0, -0.644, 0.644, 0, 0.765 }, color = { 178, 122, 72 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "CollarRing", shape = "Cylinder", size = { 0.35, 2.4, 2.4 }, cframe = { 0, 1.825, -0.063, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, color = { 190, 198, 210 }, material = "Metal", transparency = 0, reflectance = 0 },
		{ name = "BubbleHelmet", shape = "Ball", size = { 3.3, 3.3, 3.3 }, cframe = { 0, 2.675, -0.163, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 185, 230, 255 }, material = "Glass", transparency = 0.55, reflectance = 0.2 },
	},
	-- Pet_Conejo_Lunar (10 parts, display stand removed)
	rabbit = {
		{ name = "BunnyBody", shape = "Ball", size = { 2.1, 2.3, 2.4 }, cframe = { 0, 1.15, 0.25, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 248, 250, 255 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "BunnyHead", shape = "Ball", size = { 1.9, 1.8, 1.9 }, cframe = { 0, 2.45, -0.15, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 248, 250, 255 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarL", shape = "Cylinder", size = { 2.2, 0.55, 0.55 }, cframe = { -0.5, 3.95, -0.05, 0.149, -0.989, 0, 0.989, 0.149, 0, 0, 0, 1 }, color = { 248, 250, 255 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarR", shape = "Cylinder", size = { 2.2, 0.55, 0.55 }, cframe = { 0.5, 3.95, -0.05, -0.149, -0.989, 0, 0.989, -0.149, 0, 0, 0, 1 }, color = { 248, 250, 255 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarPinkL", shape = "Cylinder", size = { 1.6, 0.3, 0.3 }, cframe = { -0.5, 3.95, -0.2, 0.149, -0.989, 0, 0.989, 0.149, 0, 0, 0, 1 }, color = { 255, 155, 185 }, material = "Neon", transparency = 0, reflectance = 0 },
		{ name = "EarPinkR", shape = "Cylinder", size = { 1.6, 0.3, 0.3 }, cframe = { 0.5, 3.95, -0.2, -0.149, -0.989, 0, 0.989, -0.149, 0, 0, 0, 1 }, color = { 255, 155, 185 }, material = "Neon", transparency = 0, reflectance = 0 },
		{ name = "EyeL", shape = "Ball", size = { 0.32, 0.32, 0.32 }, cframe = { -0.45, 2.6, -0.97, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 220, 40, 95 }, material = "Neon", transparency = 0, reflectance = 0 },
		{ name = "EyeR", shape = "Ball", size = { 0.32, 0.32, 0.32 }, cframe = { 0.45, 2.6, -0.97, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 220, 40, 95 }, material = "Neon", transparency = 0, reflectance = 0 },
		{ name = "Tail", shape = "Ball", size = { 0.8, 0.8, 0.8 }, cframe = { 0, 0.95, 1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 255, 255, 255 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "BubbleHelmet", shape = "Ball", size = { 3.8, 4.6, 3.6 }, cframe = { 0, 3.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 165, 230, 255 }, material = "Glass", transparency = 0.55, reflectance = 0.2 },
	},
	-- Pet_Mono_Espacial (8 parts, display stand removed)
	monkey = {
		{ name = "SuitVest", shape = "Block", size = { 1.8, 2, 1.5 }, cframe = { 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 215, 175, 55 }, material = "Foil", transparency = 0, reflectance = 0.25 },
		{ name = "MonkeyHead", shape = "Ball", size = { 1.9, 1.8, 1.8 }, cframe = { 0, 2.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 115, 72, 42 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "FaceMask", shape = "Ball", size = { 1.5, 1.3, 1.2 }, cframe = { 0, 2.3, -0.45, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 225, 180, 135 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarL", shape = "Cylinder", size = { 0.3, 0.8, 0.8 }, cframe = { -1, 2.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 225, 180, 135 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EarR", shape = "Cylinder", size = { 0.3, 0.8, 0.8 }, cframe = { 1, 2.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 225, 180, 135 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EyeL", shape = "Ball", size = { 0.28, 0.28, 0.28 }, cframe = { -0.38, 2.45, -0.98, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 20, 20, 25 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "EyeR", shape = "Ball", size = { 0.28, 0.28, 0.28 }, cframe = { 0.38, 2.45, -0.98, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 20, 20, 25 }, material = "SmoothPlastic", transparency = 0, reflectance = 0 },
		{ name = "BubbleHelmet", shape = "Ball", size = { 2.9, 2.9, 2.9 }, cframe = { 0, 2.45, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, color = { 175, 225, 255 }, material = "Glass", transparency = 0.5, reflectance = 0.2 },
	},
}

for _, parts in PetModels do
	for _, p in parts do
		table.freeze(p.size)
		table.freeze(p.cframe)
		table.freeze(p.color)
		table.freeze(p)
	end
	table.freeze(parts)
end

return table.freeze(PetModels)
