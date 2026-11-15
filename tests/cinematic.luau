--!strict
-- Space Base Odyssey - cinematic shot tests (Stage 10). Run with: lune run tests/cinematic
-- Checks src/shared/CinematicShots.luau: the shot list is well formed, the menu order names real
-- shots, the curve starts and ends on the keys, the easing never stops mid-shot, the camera moves
-- smoothly (no jumps between samples) and the Earth shot keys sit behind the hub, away from the Earth.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local CinematicShots = require("../src/shared/CinematicShots")

type Vec = CinematicShots.Vec

local failures = 0
local passes = 0

local function check(condition: boolean, label: string)
	if condition then
		passes += 1
	else
		failures += 1
		print("FAIL  " .. label)
	end
end

local function distance(a: Vec, b: Vec): number
	return CinematicShots.length({ a[1] - b[1], a[2] - b[2], a[3] - b[3] })
end

local function isVec(value: any): boolean
	if type(value) ~= "table" or #value ~= 3 then
		return false
	end
	for i = 1, 3 do
		if type(value[i]) ~= "number" or value[i] ~= value[i] then
			return false
		end
	end
	return true
end

-- A. The shot list.
do
	local seen: { [string]: boolean } = {}
	for _, shot in CinematicShots.SHOTS do
		check(type(shot.id) == "string" and shot.id ~= "", "A: every shot has an id")
		check(not seen[shot.id], `A: {shot.id} is listed once`)
		seen[shot.id] = true
		check(shot.seconds >= 3 and shot.seconds <= 10, `A: {shot.id} lasts 3 to 10 seconds`)
		check(shot.fov.from >= 1 and shot.fov.from <= 120 and shot.fov.to >= 1 and shot.fov.to <= 120, `A: {shot.id} field of view in range`)
		check(shot.needs == nil or shot.needs == "eclipse" or shot.needs == "showcase", `A: {shot.id} needs is known`)
		if shot.lookAtEarth then
			check(#shot.keys == 0, `A: {shot.id} gets its keys from the Earth`)
		else
			check(#shot.keys >= 2, `A: {shot.id} has at least two keys`)
		end
		for index, item in shot.keys do
			check(isVec(item.pos) and isVec(item.look), `A: {shot.id} key {index} is two vectors`)
			check(distance(item.pos, item.look) > 5, `A: {shot.id} key {index} looks at something away from the lens`)
		end
		local blur = shot.blur
		if blur then
			check(blur.focus > 0 and blur.radius > 0, `A: {shot.id} blur has a focus`)
			check(blur.far >= 0 and blur.far <= 1 and blur.near >= 0 and blur.near <= 1, `A: {shot.id} blur 0..1`)
		end
	end
	check(#CinematicShots.MENU_ORDER >= 6, "A: the menu sequence has several shots")
	check(CinematicShots.MENU_ORDER[1] == "earthrise_eclipse", "A: the menu starts with the Earth and the eclipse")
	local inMenu: { [string]: boolean } = {}
	for _, id in CinematicShots.MENU_ORDER do
		check(CinematicShots.get(id) ~= nil, `A: menu shot {id} exists`)
		check(not inMenu[id], `A: menu shot {id} is used once`)
		inMenu[id] = true
	end
	for _, shot in CinematicShots.SHOTS do
		check(inMenu[shot.id] == true, `A: {shot.id} is in the menu sequence`)
	end
	local total = CinematicShots.totalSeconds(CinematicShots.MENU_ORDER)
	check(total >= 30 and total <= 60, "A: the menu loop lasts 30 to 60 seconds")
	check(CinematicShots.get("nothing") == nil, "A: unknown shots are nil")
end

-- B. Easing: 0 -> 0, 1 -> 1, rising, never flat.
do
	check(CinematicShots.ease(0) == 0 and CinematicShots.ease(1) == 1, "B: ease starts at 0 and ends at 1")
	check(CinematicShots.ease(-1) == 0 and CinematicShots.ease(2) == 1, "B: ease clamps u")
	local steps = 200
	local minSpeed = math.huge
	for i = 1, steps do
		local a = CinematicShots.ease((i - 1) / steps)
		local b = CinematicShots.ease(i / steps)
		minSpeed = math.min(minSpeed, (b - a) * steps)
	end
	check(minSpeed >= 0.49, "B: the camera never stops mid-shot (speed >= half)")
end

-- C. Curves: exact ends, continuous, no jumps.
do
	for _, shot in CinematicShots.SHOTS do
		if #shot.keys < 2 then
			continue
		end
		local startPos, startLook, startFov = CinematicShots.sample(shot, 0)
		local endPos, endLook, endFov = CinematicShots.sample(shot, 1)
		local first = shot.keys[1]
		local last = shot.keys[#shot.keys]
		check(distance(startPos, first.pos) < 1e-6 and distance(startLook, first.look) < 1e-6, `C: {shot.id} starts on its first key`)
		check(distance(endPos, last.pos) < 1e-6 and distance(endLook, last.look) < 1e-6, `C: {shot.id} ends on its last key`)
		check(math.abs(startFov - shot.fov.from) < 1e-6 and math.abs(endFov - shot.fov.to) < 1e-6, `C: {shot.id} field of view from and to`)
		-- Path length vs the largest step: 400 samples, no step bigger than 3% of the path.
		local samples = 400
		local previous = startPos
		local total = 0
		local biggest = 0
		for i = 1, samples do
			local pos = CinematicShots.sample(shot, i / samples)
			local step = distance(pos, previous)
			total += step
			biggest = math.max(biggest, step)
			previous = pos
		end
		check(total > 1, `C: {shot.id} camera moves`)
		check(biggest <= total * 0.03, `C: {shot.id} camera moves smoothly`)
		-- Each key is passed through (the curve hits the middle keys too).
		local count = #shot.keys
		for index = 2, count - 1 do
			local u = (index - 1) / (count - 1)
			-- Invert the easing by bisection to find the time when s reaches the key.
			local lo, hi = 0, 1
			for _ = 1, 60 do
				local mid = (lo + hi) / 2
				if CinematicShots.ease(mid) < u then
					lo = mid
				else
					hi = mid
				end
			end
			local pos = CinematicShots.sample(shot, (lo + hi) / 2)
			check(distance(pos, shot.keys[index].pos) < 1e-3, `C: {shot.id} passes through key {index}`)
		end
	end
	local single = CinematicShots.curve({ { 1, 2, 3 } }, 0.7)
	check(single[1] == 1 and single[2] == 2 and single[3] == 3, "C: one point is a still camera")
	local none = CinematicShots.curve({}, 0.5)
	check(none[1] == 0 and none[2] == 0 and none[3] == 0, "C: no points gives the origin")
end

-- D. The Earth shot.
do
	local shot = CinematicShots.get("earthrise_eclipse")
	check(shot ~= nil, "D: the Earth shot exists")
	local roof = CinematicShots.HUB_ROOF
	for _, earth in { { 303, 125, 829 } :: Vec, { -500, 60, 700 }, { 0, 900, 1 }, { 850, -40, 0 } } do
		local keys = CinematicShots.earthKeys(earth)
		check(#keys == 2, "D: two keys")
		for _, item in keys do
			check(item.pos[2] >= CinematicShots.EARTH_SHOT_MIN_Y, "D: the camera stays above the ground")
			-- Behind the hub: farther from the Earth than the roof is.
			check(distance(item.pos, earth) > distance(roof, earth), "D: the camera is behind the hub")
		end
		check(math.abs(distance(keys[1].pos, keys[2].pos) - 2 * CinematicShots.EARTH_SHOT_DRIFT) < 0.5 or earth[2] > 800, "D: the camera drifts sideways")
		check(keys[1].look[2] < earth[2] and keys[2].look[2] > earth[2], "D: the view tilts up across the Earth")
		if shot then
			local pos, look, fov = CinematicShots.sample(shot, 0.5, keys)
			check(isVec(pos) and isVec(look) and fov <= shot.fov.from and fov >= shot.fov.to, "D: the Earth shot samples")
		end
	end
	-- The usual sky: the Earth 900 studs out, about 8 degrees up. The hub roof is right in front of it.
	local earth: Vec = { 303, 125, 829 }
	local keys = CinematicShots.earthKeys(earth)
	local mid = { (keys[1].pos[1] + keys[2].pos[1]) / 2, (keys[1].pos[2] + keys[2].pos[2]) / 2, (keys[1].pos[3] + keys[2].pos[3]) / 2 }
	local toEarth = { earth[1] - mid[1], earth[2] - mid[2], earth[3] - mid[3] }
	local toRoof = { roof[1] - mid[1], roof[2] - mid[2], roof[3] - mid[3] }
	local dot = (toEarth[1] * toRoof[1] + toEarth[2] * toRoof[2] + toEarth[3] * toRoof[3])
		/ (CinematicShots.length(toEarth) * CinematicShots.length(toRoof))
	check(dot > math.cos(math.rad(2)), "D: the hub roof is in line with the Earth")
end

print(`cinematic: {passes} passed, {failures} failed`)
if failures > 0 then
	error("cinematic tests failed")
end
