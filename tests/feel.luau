--!strict
-- Space Base Odyssey - Stage 11 feel and world-safety tests. Run with: lune run tests/feel
-- Checks src/shared/Feel.luau (which moments a BaseState update celebrates, the celebration styles,
-- the report's star reveal and cause -> effect chips, the camera shake curve) and
-- src/shared/WorldSafety.luau (the map-edge walls and glow, the extra ice crater exits).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Feel = require("../src/shared/Feel")
local WorldSafety = require("../src/shared/WorldSafety")
local MissionData = require("../src/shared/MissionData")

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

local function kinds(moments: { Feel.Moment }): string
	local names: { string } = {}
	for _, moment in moments do
		table.insert(names, moment.kind)
	end
	return table.concat(names, ",")
end

local function state(level: number, builds: { [string]: number }, mainCount: number?, sides: { string }?): any
	local sideList = {}
	for _, id in sides or {} do
		table.insert(sideList, { id = id, steps = {} })
	end
	return {
		credits = 10,
		level = level,
		builds = builds,
		quest = { id = "m01_home", mainCount = mainCount, sides = sideList, steps = {} },
	}
end

-- A. Snapshots and moment detection.
do
	check(Feel.snap(nil) == nil, "A: nil is not a state")
	check(Feel.snap({ level = 3 }) == nil, "A: a table without credits is not a state")
	local s = Feel.snap(state(2, { habitat = 1, solar = 1 }, 3, { "s_ice" })) :: Feel.BaseSnap
	check(s ~= nil and s.level == 2 and s.habitat == 1 and s.mainCount == 3 and s.sides.s_ice == true, "A: snap reads level, habitat, quests")
	local empty = Feel.snap({ credits = 0 }) :: Feel.BaseSnap
	check(empty.level == 1 and empty.habitat == 0 and empty.mainCount == nil, "A: an older server's state has safe defaults")

	local before = Feel.snap(state(2, { habitat = 1, solar = 1 }, 3, { "s_ice" })) :: Feel.BaseSnap
	check(#Feel.detect(nil, before) == 0, "A: the first state celebrates nothing")
	check(#Feel.detect(before, before) == 0, "A: no change, no moment")

	local up = Feel.snap(state(3, { habitat = 2, solar = 2 }, 4, {})) :: Feel.BaseSnap
	local moments = Feel.detect(before, up)
	check(kinds(moments) == "base,level,quest,build", "A: base, level, quest and build in priority order (" .. kinds(moments) .. ")")
	check(moments[1].n == 2 and moments[2].n == 3, "A: base and level moments carry the new level")
	check(moments[3].n == 2, "A: one main quest and one side quest = 2 quests done")
	check(moments[4].id == "solar", "A: the build moment names the build")

	local down = Feel.snap(state(1, { habitat = 0 }, 0, {})) :: Feel.BaseSnap
	check(#Feel.detect(before, down) == 0 or kinds(Feel.detect(before, down)) == "quest",
		"A: levels going down (another save) are never celebrated")
	check(not string.find(kinds(Feel.detect(before, down)), "level") and not string.find(kinds(Feel.detect(before, down)), "base"),
		"A: no level or base moment when they drop")

	local many = Feel.snap(state(2, { habitat = 1, solar = 3, antenna = 2, shelter = 1, greenhouse = 1, lab = 1 }, 3, { "s_ice" })) :: Feel.BaseSnap
	local reload = Feel.detect(before, many)
	check(#reload == 0, "A: many builds rising at once (a world reload) are not celebrated")

	local jump = Feel.snap(state(2, { habitat = 4, solar = 1 }, 3, { "s_ice" })) :: Feel.BaseSnap
	check(#Feel.detect(before, jump) == 0, "A: a base jumping several levels at once (a world load) is not celebrated")

	local noQuestCount = Feel.snap(state(2, { habitat = 1, solar = 1 }, nil, { "s_ice" })) :: Feel.BaseSnap
	check(#Feel.detect(noQuestCount, before) == 0, "A: an unknown main count never counts as quests done")
end

-- B. The waiting queue.
do
	local queue: { Feel.Moment } = {}
	Feel.enqueue(queue, { kind = "quest", n = 1 })
	Feel.enqueue(queue, { kind = "quest", n = 2 })
	check(#queue == 1 and queue[1].n == 2, "B: the same kind merges")
	Feel.enqueue(queue, { kind = "level", n = 4 })
	check(queue[1].kind == "level", "B: more important moments go first")
	for i = 1, 6 do
		Feel.enqueue(queue, { kind = "build", id = "b" .. i })
	end
	check(#queue <= Feel.MAX_QUEUE, "B: the queue never grows past MAX_QUEUE")
	check(queue[1].kind == "level", "B: a full queue drops the least important moments")
end

-- C. Celebration styles.
do
	local paletteNames = { cyan = true, orange = true, lime = true, magenta = true, cream = true, gold = true, red = true }
	for _, kind in { "quest", "level", "base", "mission", "achievement", "build" } do
		local style = Feel.STYLES[kind]
		check(style ~= nil, `C: {kind} has a style`)
		if style then
			check(style.count >= 0 and style.count <= Feel.MAX_PARTICLES, `C: {kind} confetti fits the cap`)
			check(style.seconds > 0 and style.seconds <= 2, `C: {kind} lasts at most 2 s (play never stops)`)
			check(#style.colors >= 1, `C: {kind} has colours`)
			for _, name in style.colors do
				check(paletteNames[name] == true, `C: {kind} colour {name} is a Theme palette name`)
			end
			check(paletteNames[style.flashColor] == true, `C: {kind} flash colour is a Theme palette name`)
			local flash = style.flash
			if flash then
				check(flash >= 0.7 and flash < 1, `C: {kind} flash is soft (start transparency 0.7 or more)`)
				check((Feel.flashFor(style, true) :: number) >= Feel.REDUCED_FLASH, `C: {kind} reduce motion keeps the flash very soft`)
			else
				check(Feel.flashFor(style, false) == nil, `C: {kind} without a flash stays without one`)
			end
			check(Feel.PRIORITY[kind] ~= nil, `C: {kind} has a priority`)
		end
	end
	check(Feel.STYLES.base.sting == "sting_level_up", "C: the base level up plays the level-up sting")
	check(Feel.STYLES.level.sting == nil and Feel.STYLES.quest.sting == nil and Feel.STYLES.achievement.sting == nil,
		"C: no second copy of sounds that Hud and QuestToasts already play")
	check(Feel.STYLES.level.title == "ui.level" and Feel.STYLES.base.title == "ui.base_level", "C: level titles use existing keys")
end

-- D. Report star reveal.
do
	check(Feel.starsShown(3, 0) == 0, "D: no star at the very start")
	check(Feel.starsShown(3, Feel.starTime(1)) == 1, "D: the first star at its time")
	check(Feel.starsShown(3, Feel.starTime(3) + 5) == 3, "D: all stars in the end")
	check(Feel.starsShown(0, 10) == 0, "D: no star earned, none shown")
	check(Feel.starTime(2) > Feel.starTime(1) and Feel.starTime(3) > Feel.starTime(2), "D: stars come one by one")
	check(Feel.revealSeconds(3) <= 2.2, "D: the reveal is quick")
	check(Feel.starPitch(3) > Feel.starPitch(1), "D: each star's note is higher")
end

-- E. Cause -> effect chips.
do
	local start = { air = MissionData.METERS.START_AIR, food = MissionData.METERS.START_FOOD, dose = MissionData.METERS.START_DOSE }
	local history = {
		{ day = 1, air = start.air - 10, food = start.food + 5, dose = start.dose, scienceSent = 2 },
		{ day = 2, air = start.air - 10, food = start.food + 5, dose = start.dose + 8, scienceSent = 0 },
		{ day = 3, air = start.air - 2, food = start.food + 5.2, dose = start.dose + 4, scienceSent = 1 },
	}
	local effects = Feel.dayEffects(history, start)
	check(#effects == 3, "E: one list per day")
	local function has(list: { Feel.Effect }, meter: string, dir: number): boolean
		for _, effect in list do
			if effect.meter == meter and effect.dir == dir then
				return true
			end
		end
		return false
	end
	check(has(effects[1], "air", -1) and has(effects[1], "food", 1) and has(effects[1], "science", 1), "E: day 1 compares with the start")
	check(not has(effects[1], "dose", 1), "E: no dose change, no dose chip")
	check(#effects[2] == 1 and has(effects[2], "dose", 1), "E: only the dose went up on day 2")
	check(has(effects[3], "air", 1) and not has(effects[3], "food", 1), "E: tiny changes are 'about the same'")
	check(not has(effects[3], "dose", 1) and not has(effects[3], "dose", -1), "E: dose never shows going down (a lower number is ignored)")
	for _, list in effects do
		check(#list <= Feel.MAX_EFFECTS, "E: at most MAX_EFFECTS chips a day")
		for _, effect in list do
			if effect.meter == "dose" then
				check(effect.dir == 1 and effect.good == false, "E: more dose is never shown as good")
			elseif effect.meter == "air" or effect.meter == "food" then
				check(effect.good == (effect.dir == 1), "E: more air or food is good, less is a warning")
			end
		end
	end
	check(#Feel.dayEffects({}, start) == 0, "E: an empty history has no chips")
end

-- F. Camera shake.
do
	check(Feel.meteorTrauma(0) == Feel.SHAKE.METEOR_MAX, "F: a very close impact gives the strongest jolt")
	check(Feel.meteorTrauma(Feel.SHAKE.METEOR_FAR) == 0 and Feel.meteorTrauma(1000) == 0, "F: far impacts are not felt")
	check(Feel.meteorTrauma(60) > Feel.meteorTrauma(120), "F: the jolt fades with distance")
	check(Feel.SHAKE.METEOR_MAX < 1, "F: even the closest impact is a gentle shake")
	check(Feel.shakeAmount(0.5) < 0.5 and Feel.shakeAmount(2) == 1 and Feel.shakeAmount(-1) == 0, "F: shake is trauma squared, clamped")
	check(Feel.decay(0.5, 10) == 0 and Feel.decay(0.5, 0.1) < 0.5, "F: trauma decays to zero")
	check(Feel.SHAKE.MAX_OFFSET <= 0.2 and Feel.SHAKE.MAX_ANGLE_DEG <= 1.5, "F: the shake stays small")
end

-- G. Map edge.
do
	local half = 600 -- WorldParts.GROUND_HALF
	local edge = WorldSafety.EDGE
	local walls = WorldSafety.wallBoxes(half)
	check(#walls == 4, "G: four walls")
	for _, wall in walls do
		local outer = math.max(math.abs(wall.cx) + wall.sx / 2, math.abs(wall.cz) + wall.sz / 2)
		check(outer <= half + 0.01, `G: the {wall.side} wall stands on the ground (not over the void)`)
		local long = math.max(wall.sx, wall.sz)
		check(long >= 2 * (half - edge.INSET), `G: the {wall.side} wall spans the whole side`)
	end
	check(edge.INSET < 40, "G: the walls stand outside the meteorite zone (kept 40 studs inside the edge)")
	check(half - edge.INSET > 460 + 20, "G: the farthest exploration site (about 460 studs out) stays well inside")
	check(edge.WALL_HEIGHT >= 300, "G: the walls are taller than a jetpack climb")
	check(WorldSafety.edgeDistance(0, 0, half) == half - edge.INSET, "G: the centre is far from the edge")
	check(WorldSafety.edgeDistance(580, 10, half) == half - edge.INSET - 580, "G: distance to the nearest wall")
	check(WorldSafety.sideDistance("east", 580, 0, half) == 8 and WorldSafety.sideDistance("west", 580, 0, half) == 2 * half - edge.INSET * 2 - 8,
		"G: each wall measures its own distance")
	check(WorldSafety.glowAlpha(500) == 0, "G: no glow far from the wall")
	check(WorldSafety.glowAlpha(edge.GLOW_FULL) == 1 and WorldSafety.glowAlpha(0) == 1, "G: full glow at the wall")
	check(WorldSafety.glowAlpha(40) > WorldSafety.glowAlpha(70), "G: the glow grows as you come closer")
	check(WorldSafety.glowTransparency(0) == 1, "G: a hidden glow is fully transparent")
	check(math.abs(WorldSafety.glowTransparency(1) - edge.GLOW_TRANSPARENCY) < 1e-9, "G: the strongest glow is still see-through")
	check(edge.WARN_DISTANCE < edge.GLOW_START, "G: the glow shows before C.A.R.L. speaks")
end

-- H. Ice crater exits (WorldBuilder.buildCrater + buildCraterExits). The drill and niche angles are
-- worked out here with the same rules as WorldStructures (Six.chooseDrillAngle, Six.nicheAngle).
do
	local function angleGap(a: number, b: number): number
		return WorldSafety.angleGap(a, b)
	end
	local CHEESE_NICHE_OFFSET = math.rad(220)
	local function nicheAngle(rampAngle: number): number
		local step = math.rad(10)
		return (math.floor((rampAngle + CHEESE_NICHE_OFFSET) / step + 0.5) % 36) * step
	end
	local function roverSideAngle(rampAngle: number): number
		local sideA, sideB = math.pi - 0.6, math.pi + 0.6
		return if angleGap(sideA, rampAngle) >= angleGap(sideB, rampAngle) then sideA else sideB
	end
	local function chooseDrillAngle(rampAngle: number): number
		local rover = roverSideAngle(rampAngle)
		local niche = nicheAngle(rampAngle)
		local sign = if rover > math.pi then -1 else 1
		for _, offset in { 0, 0.55, -0.55, 0.9, -0.9, 1.25, -1.25 } do
			local angle = math.pi + offset * sign
			if angleGap(angle, rampAngle) >= 0.6 and angleGap(angle, niche) >= 0.6 and angleGap(angle, rover) >= 0.75 then
				return angle
			end
		end
		return math.pi + 1.25 * sign
	end

	local exit = WorldSafety.EXIT
	local worstCover = 0
	local fewest = math.huge
	for k = 0, 35 do
		local rampAngle = k * math.rad(10)
		local niche = nicheAngle(rampAngle)
		local drill = chooseDrillAngle(rampAngle)
		local exits = WorldSafety.exitAngles(rampAngle, niche, drill)
		fewest = math.min(fewest, #exits)
		for _, angle in exits do
			check(WorldSafety.exitClear(angle, rampAngle, niche, drill), `H: ramp {k * 10}: exit clear of drills, niche, ice and lamps`)
			check(angleGap(angle, rampAngle) >= exit.FROM_RAMP, `H: ramp {k * 10}: exit away from the main ramp`)
		end
		if #exits == 2 then
			check(angleGap(exits[1], exits[2]) >= exit.BETWEEN_EXITS, `H: ramp {k * 10}: the two exits are apart`)
		end
		local all = table.clone(exits)
		table.insert(all, rampAngle)
		for d = 0, 355, 5 do
			-- Straight walk across the floor from the foot of the wall (r 70) to the nearest ramp's
			-- foot (the main ramp starts at r 10, the exits at EXIT.INNER).
			local gap = WorldSafety.nearestExitGap(math.rad(d), all)
			local walk = math.sqrt(70 * 70 + exit.INNER * exit.INNER - 2 * 70 * exit.INNER * math.cos(gap))
			worstCover = math.max(worstCover, walk)
		end
	end
	check(fewest >= 2, "H: every crater layout gets two extra exits")
	-- About 16 studs a second on foot: 90 studs is under 6 s, even carrying ice.
	check(worstCover <= 90, `H: from anywhere on the crater floor a ramp foot is at most 90 studs away ({math.floor(worstCover)})`)
	local rise = 8 - -24 -- WorldParts.CRATER_RIM_Y - CRATER_FLOOR_Y
	local slope = WorldSafety.slopeDegrees(exit.INNER, 70, rise)
	check(slope <= 35, `H: the exit ramps are gentle ({math.floor(slope)} degrees)`)
	check(exit.WIDTH >= 12, "H: the exit ramps are at least as wide as the main ramp")
end

print(`feel: {passes} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} feel test(s) failed`)
end
