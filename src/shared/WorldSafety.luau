--!strict
-- Space Base Odyssey - Stage 11 world safety: the pure layout rules that keep kids from getting stuck.
--   * Map edge: four invisible walls just inside the ground's edge (the ground ends at
--     +-GROUND_HALF and past it is the void), and a soft warning glow on them that the client fades
--     in only when a player comes close (src/client/MapEdge.luau). C.A.R.L. says "turn back" then.
--   * Ice crater exits: two more gentle ramps out of the crater floor besides the main one, placed
--     clear of the drills, the hidden cheese niche, the ice nodes and the floor lamps, the first one
--     as close to the base side as that allows. WorldBuilder builds them.
-- Pure (no Roblox instances), so tests/feel.luau runs it in Lune. Layout numbers (studs, radians),
-- not gameplay numbers.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local WorldSafety = {}

WorldSafety.EDGE = table.freeze({
	INSET = 12, -- the walls' inner face stands this far inside the ground's edge
	WALL_HEIGHT = 420, -- taller than a full jetpack climb
	WALL_THICKNESS = 4,
	GLOW_HEIGHT = 7, -- the warning band at the foot of each wall
	GLOW_START = 80, -- studs from the wall: the glow starts to show
	GLOW_FULL = 12, -- studs from the wall: the glow is as strong as it gets
	GLOW_TRANSPARENCY = 0.35, -- the glow at its strongest
	WARN_DISTANCE = 45, -- studs from the wall: C.A.R.L. says to turn back
	WARN_REPEAT_SECONDS = 25,
})

WorldSafety.EXIT = table.freeze({
	INNER = 18, -- each exit ramp starts this far from the crater centre ...
	WIDTH = 14, -- ... and is this wide (the main ramp is 12)
	CANDIDATE_STEP_DEG = 5,
	-- Clearances (radians around the crater centre).
	FROM_RAMP = 1.0, -- the main ramp
	FROM_NICHE = 0.5, -- the hidden cheese niche's tunnel in the rim wall
	FROM_DRILL = 0.75, -- the middle drill (the others are 0.3 to each side, their lift belts above)
	FROM_ICE = 0.5, -- the ice nodes on the floor
	FROM_LAMP = 0.35, -- the far floor lamp
	BETWEEN_EXITS = 1.2,
})

-- Ice nodes and the far floor lamp, as angles from the main ramp (WorldBuilder.buildCrater).
WorldSafety.ICE_FROM_RAMP_DEG = table.freeze({ 100, 180, 260 })
WorldSafety.LAMP_FROM_RAMP_DEG = 167

local TAU = 2 * math.pi

-- Smallest angle between two directions (radians, 0..pi).
function WorldSafety.angleGap(a: number, b: number): number
	local d = (a - b) % TAU
	return math.min(d, TAU - d)
end

local angleGap = WorldSafety.angleGap

type Blocker = { angle: number, gap: number }

local function blockers(rampAngle: number, nicheAngle: number, drillAngle: number): { Blocker }
	local exit = WorldSafety.EXIT
	local list: { Blocker } = {
		{ angle = rampAngle, gap = exit.FROM_RAMP },
		{ angle = nicheAngle, gap = exit.FROM_NICHE },
		{ angle = drillAngle, gap = exit.FROM_DRILL },
		{ angle = rampAngle + math.rad(WorldSafety.LAMP_FROM_RAMP_DEG), gap = exit.FROM_LAMP },
	}
	for _, deg in WorldSafety.ICE_FROM_RAMP_DEG do
		table.insert(list, { angle = rampAngle + math.rad(deg), gap = exit.FROM_ICE })
	end
	return list
end

-- True when a ramp at `angle` keeps clear of everything on the crater floor and rim wall.
function WorldSafety.exitClear(angle: number, rampAngle: number, nicheAngle: number, drillAngle: number): boolean
	for _, blocker in blockers(rampAngle, nicheAngle, drillAngle) do
		if angleGap(angle, blocker.angle) < blocker.gap then
			return false
		end
	end
	return true
end

-- Angles (radians, WorldParts.dirFromAngle convention) of the extra exit ramps: the first as close
-- to the base side (angle pi: toward the habitat) as the clearances allow, the second as far from
-- every other exit as possible. May return fewer than two when nothing fits.
function WorldSafety.exitAngles(rampAngle: number, nicheAngle: number, drillAngle: number): { number }
	local exit = WorldSafety.EXIT
	local candidates: { number } = {}
	local step = math.rad(exit.CANDIDATE_STEP_DEG)
	for k = 0, math.floor(360 / exit.CANDIDATE_STEP_DEG) - 1 do
		local angle = k * step
		if WorldSafety.exitClear(angle, rampAngle, nicheAngle, drillAngle) then
			table.insert(candidates, angle)
		end
	end
	local chosen: { number } = {}
	local first: number? = nil
	for _, angle in candidates do
		if first == nil or angleGap(angle, math.pi) < angleGap(first :: number, math.pi) then
			first = angle
		end
	end
	if first == nil then
		return chosen
	end
	table.insert(chosen, first :: number)
	local best: number? = nil
	local bestGap = -1
	for _, angle in candidates do
		local gap = math.min(angleGap(angle, rampAngle), angleGap(angle, first :: number))
		if gap >= exit.BETWEEN_EXITS and gap > bestGap then
			best = angle
			bestGap = gap
		end
	end
	if best ~= nil then
		table.insert(chosen, best :: number)
	end
	return chosen
end

-- Slope of a straight ramp (degrees) that climbs `height` between radius `inner` and `outer`.
function WorldSafety.slopeDegrees(inner: number, outer: number, height: number): number
	return math.deg(math.atan2(height, math.max(0.001, outer - inner)))
end

-- Angle (radians) from a point on the crater wall to the nearest way out.
function WorldSafety.nearestExitGap(angle: number, exits: { number }): number
	local best = math.pi
	for _, exitAngle in exits do
		best = math.min(best, angleGap(angle, exitAngle))
	end
	return best
end

-- Map edge -----------------------------------------------------------------------------------------

export type WallBox = { cx: number, cz: number, sx: number, sz: number, side: string }

-- The four walls (centre and size on the ground plane), for a square ground of half size `half`.
-- Each wall's inner face is EDGE.INSET inside the ground's edge; they overlap at the corners.
function WorldSafety.wallBoxes(half: number): { WallBox }
	local edge = WorldSafety.EDGE
	local face = half - edge.INSET
	local mid = face + edge.WALL_THICKNESS / 2
	local long = 2 * (face + edge.WALL_THICKNESS)
	return {
		{ cx = mid, cz = 0, sx = edge.WALL_THICKNESS, sz = long, side = "east" },
		{ cx = -mid, cz = 0, sx = edge.WALL_THICKNESS, sz = long, side = "west" },
		{ cx = 0, cz = mid, sx = long, sz = edge.WALL_THICKNESS, side = "north" },
		{ cx = 0, cz = -mid, sx = long, sz = edge.WALL_THICKNESS, side = "south" },
	}
end

-- Studs from a point to the inner face of one wall ("east" = +x, "west" = -x, "north" = +z,
-- "south" = -z). Negative = past it.
function WorldSafety.sideDistance(side: string, x: number, z: number, half: number): number
	local face = half - WorldSafety.EDGE.INSET
	if side == "east" then
		return face - x
	elseif side == "west" then
		return face + x
	elseif side == "north" then
		return face - z
	end
	return face + z
end

-- Studs from a point to the nearest wall.
function WorldSafety.edgeDistance(x: number, z: number, half: number): number
	local face = half - WorldSafety.EDGE.INSET
	return face - math.max(math.abs(x), math.abs(z))
end

-- How strongly a wall's glow shows for a player `distance` studs from it (0 = hidden, 1 = full).
function WorldSafety.glowAlpha(distance: number): number
	local edge = WorldSafety.EDGE
	if distance ~= distance or distance >= edge.GLOW_START then
		return 0
	end
	if distance <= edge.GLOW_FULL then
		return 1
	end
	local t = 1 - (distance - edge.GLOW_FULL) / (edge.GLOW_START - edge.GLOW_FULL)
	return t * t
end

-- The glow part's Transparency for an alpha (1 = invisible).
function WorldSafety.glowTransparency(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return 1 - a * (1 - WorldSafety.EDGE.GLOW_TRANSPARENCY)
end

return WorldSafety
