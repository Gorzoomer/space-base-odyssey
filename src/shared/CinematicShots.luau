--!strict
-- Space Base Odyssey - cinematic camera shots (Stage 10): the start menu's background and the shots
-- for the 30-second video and promo material. Pure data and pure maths with plain number vectors
-- ({ x, y, z } arrays, no Roblox types), so it runs in Lune (tests/cinematic.luau) as well as on the
-- client (src/client/Cinematic.luau turns the vectors into a CFrame).
-- A shot is a list of camera keys (position + point looked at, world studs), a length in seconds and
-- a field of view that changes from `fov.from` to `fov.to`. sample(shot, u) follows a Catmull-Rom
-- curve through the keys (the ends are clamped: the first and last key are repeated), with the eased
-- time s = 0.5 * smoothstep(u) + 0.5 * u, so the camera slows near the ends but never stops mid-shot.
-- `needs` says what the world must show: "showcase" = the finished base (BaseService shows every
-- structure at its top level while nobody has loaded a save), "eclipse" = the Sun close to the Earth
-- (WorldSky.previewEclipse). `lookAtEarth` shots get their keys at run time from the Earth's position
-- (earthKeys). `blur` = a depth-of-field setting for close-ups (skipped on low-end devices).
-- World landmarks (studs, WorldParts S7 layout): hub centre (0, 0, 0), roof top y 33; greenhouse
-- dome A (-62, 0, 0), planter rows at x -70, -65.5 (z -9..6) and -61 (z -2..6), soil top y 1.8,
-- plants up to about y 3.3; dome B (-66, 0, 36); lab (-55, 0, -35); lander (40, 0, -130); crater
-- centre (0, 0, 230), floor y -24, rim band r 70..100 at y 8, drills on the floor at r 56 on the side
-- facing the base (z about 175); antenna tower (-60, 0, 70), dish hub y 37.5; landing pad and ship
-- (-110, 0, -180). These are camera framing values (GAME, not science numbers).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type Vec = { number } -- { x, y, z }

export type Key = { pos: Vec, look: Vec }

export type Need = "eclipse" | "showcase"

export type Blur = {
	focus: number, -- studs from the camera to the sharp plane
	radius: number, -- studs around it that stay sharp
	far: number, -- 0..1 blur beyond
	near: number, -- 0..1 blur in front
}

export type Shot = {
	id: string,
	keys: { Key },
	seconds: number,
	fov: { from: number, to: number },
	needs: Need?,
	lookAtEarth: boolean?,
	blur: Blur?,
}

local CinematicShots = {}

-- Earth shot framing: the camera stands on the line from the hub roof away from the Earth, so the
-- hub sits in front of the Earth disc (and of the Sun during an eclipse).
CinematicShots.HUB_ROOF = { 0, 33, 0 } :: Vec
CinematicShots.EARTH_SHOT_DISTANCE = 170 -- closer and wider than a long lens: the Sun (9 degrees wide) would fill a long-lens frame
CinematicShots.EARTH_SHOT_DRIFT = 8 -- studs sideways, from -8 to +8
CinematicShots.EARTH_SHOT_LOOK_FROM = -14 -- studs below the Earth centre at the start
CinematicShots.EARTH_SHOT_LOOK_TO = 8 -- studs above it at the end
CinematicShots.EARTH_SHOT_MIN_Y = 4 -- never below this height (the client also checks the ground)

local function key(px: number, py: number, pz: number, lx: number, ly: number, lz: number): Key
	return { pos = { px, py, pz }, look = { lx, ly, lz } }
end

-- The shots, in no particular order (MENU_ORDER is the start menu sequence).
CinematicShots.SHOTS = {
	{
		-- The Earth rises behind the hub; with the eclipse preview the Sun slides
		-- behind it. Keys come from earthKeys at run time.
		id = "earthrise_eclipse",
		keys = {},
		seconds = 9,
		fov = { from = 24, to = 20 },
		needs = "eclipse",
		lookAtEarth = true,
	},
	{
		-- Slow macro push along the middle planter row of dome A, in the aisle between rows
		-- x -65.5 and x -61 (aisle x -64.2..-62.3).
		id = "plant_closeup",
		keys = {
			key(-63, 3.4, -8, -66.5, 2.2, 4),
			key(-63.5, 3, -3, -66.5, 2, 6),
		},
		seconds = 5,
		fov = { from = 40, to = 34 },
		needs = "showcase",
		blur = { focus = 6, radius = 4, far = 0.35, near = 0 },
	},
	{
		-- Over the crater rim on the base side, looking down at the ice drills on the dark floor.
		-- The first key is 14 studs above the rim band so the view clears the inner lip (r 70, y 8);
		-- the second is already inside the rim (r 68).
		id = "crater_ice",
		keys = {
			key(36, 22, 156, -2, -20, 180),
			key(48, 17, 182, 4, -20, 184),
		},
		seconds = 6,
		fov = { from = 50, to = 50 },
		needs = "showcase",
	},
	{
		id = "aerial_base",
		keys = {
			key(110, 75, 120, 0, 4, 0),
			key(30, 58, 140, -20, 4, 0),
			key(-70, 46, 115, -35, 4, -10),
		},
		seconds = 5,
		fov = { from = 48, to = 48 },
		needs = "showcase",
	},
	{
		-- From inside the hub, through the west doorway and the walk-through tube into dome A.
		id = "greenhouse_tube",
		keys = {
			key(-24, 5.2, 0.5, -60, 4.2, 0),
			key(-40, 5, 0.3, -70, 3.5, 2),
			key(-52, 6, 3, -68, 2.5, 12),
		},
		seconds = 5,
		fov = { from = 58, to = 58 },
		needs = "showcase",
	},
	{
		-- Low hero angle on the antenna tower (-60, 0, 70) from the east, clear of dome B
		-- (x -80..-52, z 22..50): the tower and dish stand against the black sky.
		id = "antenna_dusk",
		keys = {
			key(-26, 5, 50, -60, 28, 70),
			key(-34, 4, 42, -60, 36, 70),
		},
		seconds = 5,
		fov = { from = 45, to = 40 },
		needs = "showcase",
	},
	{
		id = "ship_hero",
		keys = {
			key(-52, 3, -136, -110, 16, -180),
			key(-66, 2.5, -130, -110, 34, -180),
		},
		seconds = 5,
		fov = { from = 50, to = 50 },
		needs = "showcase",
	},
	{
		-- The closing move: up and back over the ship until the whole base is in view.
		id = "pullback",
		keys = {
			key(-25, 16, -75, -10, 10, 0),
			key(-60, 40, -125, -10, 6, 10),
			key(-110, 75, -175, -10, 0, 20),
		},
		seconds = 6,
		fov = { from = 50, to = 50 },
		needs = "showcase",
	},
} :: { Shot }

-- The start menu loops these. The first one shows the eclipse preview; the eclipse then dims the
-- sunlight for about 20 seconds, so the shots lit by the base's own lamps (greenhouse, tube, crater
-- floor, the antenna against the stars) come next and the sunlit wide shots come after it.
CinematicShots.MENU_ORDER = {
	"earthrise_eclipse",
	"plant_closeup",
	"greenhouse_tube",
	"crater_ice",
	"antenna_dusk",
	"aerial_base",
	"ship_hero",
	"pullback",
}

function CinematicShots.get(id: string): Shot?
	for _, shot in CinematicShots.SHOTS do
		if shot.id == id then
			return shot
		end
	end
	return nil
end

-- Seconds of camera motion for a list of shot ids (fades not included; unknown ids count 0).
function CinematicShots.totalSeconds(ids: { string }): number
	local total = 0
	for _, id in ids do
		local shot = CinematicShots.get(id)
		if shot then
			total += shot.seconds
		end
	end
	return total
end

----------------------------------------------------------------------------------------------------
-- Vector maths on { x, y, z }

local function add(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function scale(a: Vec, k: number): Vec
	return { a[1] * k, a[2] * k, a[3] * k }
end

local function length(a: Vec): number
	return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

local function unit(a: Vec, fallback: Vec): Vec
	local n = length(a)
	if n < 1e-6 then
		return fallback
	end
	return scale(a, 1 / n)
end

CinematicShots.length = length

-- Smooth start and end, but at least half speed everywhere (derivative 0.5 + 3u(1 - u) >= 0.5).
function CinematicShots.ease(u: number): number
	local t = math.clamp(u, 0, 1)
	local smooth = t * t * (3 - 2 * t)
	return 0.5 * smooth + 0.5 * t
end

-- Uniform Catmull-Rom through p1..p2 (p0 and p3 shape the tangents), f in 0..1.
local function catmullRom(p0: Vec, p1: Vec, p2: Vec, p3: Vec, f: number): Vec
	local f2 = f * f
	local f3 = f2 * f
	local result: Vec = {}
	for i = 1, 3 do
		local a, b, c, d = p0[i], p1[i], p2[i], p3[i]
		result[i] = 0.5 * (2 * b + (c - a) * f + (2 * a - 5 * b + 4 * c - d) * f2 + (3 * b - a - 3 * c + d) * f3)
	end
	return result
end

-- A point on the curve through `points` at s in 0..1 (ends clamped: the first and last points
-- are repeated, so the curve starts and ends exactly on them).
function CinematicShots.curve(points: { Vec }, s: number): Vec
	local count = #points
	if count == 0 then
		return { 0, 0, 0 }
	elseif count == 1 then
		return { points[1][1], points[1][2], points[1][3] }
	end
	local t = math.clamp(s, 0, 1) * (count - 1)
	local index = math.min(math.floor(t), count - 2) -- segment from points[index + 1] to points[index + 2]
	local f = t - index
	local p1 = points[index + 1]
	local p2 = points[index + 2]
	local p0 = points[index] or p1
	local p3 = points[index + 3] or p2
	return catmullRom(p0, p1, p2, p3, f)
end

-- Camera position, the point it looks at and the field of view at u (0..1 of the shot's time).
-- `keys` replaces shot.keys (lookAtEarth shots pass earthKeys(...)).
function CinematicShots.sample(shot: Shot, u: number, keys: { Key }?): (Vec, Vec, number)
	local list = keys or shot.keys
	local s = CinematicShots.ease(u)
	local positions: { Vec } = {}
	local looks: { Vec } = {}
	for _, item in list do
		table.insert(positions, item.pos)
		table.insert(looks, item.look)
	end
	local fov = shot.fov.from + (shot.fov.to - shot.fov.from) * s
	return CinematicShots.curve(positions, s), CinematicShots.curve(looks, s), fov
end

-- Keys for the Earth shot from the Earth's position: on the line from the hub roof away from the
-- Earth at EARTH_SHOT_DISTANCE, drifting sideways from -DRIFT to +DRIFT, looking from below the
-- Earth's centre to above it.
function CinematicShots.earthKeys(earth: Vec): { Key }
	local roof = CinematicShots.HUB_ROOF
	local toward = unit(sub(earth, roof), { 0, 0, 1 })
	local base = sub(roof, scale(toward, CinematicShots.EARTH_SHOT_DISTANCE))
	base[2] = math.max(base[2], CinematicShots.EARTH_SHOT_MIN_Y)
	-- Horizontal right-hand direction across the line of sight (toward x up = cross(toward, up)).
	local right = unit({ -toward[3], 0, toward[1] }, { 1, 0, 0 })
	local drift = CinematicShots.EARTH_SHOT_DRIFT
	return {
		{
			pos = sub(base, scale(right, drift)),
			look = add(earth, { 0, CinematicShots.EARTH_SHOT_LOOK_FROM, 0 }),
		},
		{
			pos = add(base, scale(right, drift)),
			look = add(earth, { 0, CinematicShots.EARTH_SHOT_LOOK_TO, 0 }),
		},
	}
end

return CinematicShots
