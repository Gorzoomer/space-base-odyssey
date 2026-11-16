--!strict
-- Space Base Odyssey - Stage 11 "juice": the pure rules behind the game's big moments.
--   * Which moments a BaseState update brings (a quest done, a player level up, a base level up,
--     a build finished): Feel.snap + Feel.detect. src/client/Celebrate.luau shows them.
--   * How each moment looks (confetti count, where it bursts, flash strength, title, sting):
--     Feel.STYLES. Colours are Theme.PALETTE names; the client tints with them.
--   * The report: when each earned star appears (Feel.starTime) and the "cause -> effect" chips of
--     each day (Feel.dayEffects: which meters went up or down that day).
--   * The camera: how hard a meteorite impact shakes it by distance (Feel.meteorTrauma) and the
--     shake curve (Feel.shakeAmount). src/client/CameraFx.luau uses them.
-- Science: a solar storm never shakes the camera (radiation is silent and pushes nothing); the
-- client only pulses a warning colour at the screen edge. The radiation dose chip only ever points
-- up: dose never goes down.
-- Pure (no Roblox instances), so tests/feel.luau runs it in Lune. These are feel and timing
-- numbers, not gameplay numbers (the gameplay numbers live in MissionData).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Feel = {}

export type Kind = "quest" | "level" | "base" | "mission" | "achievement" | "build"
export type Moment = { kind: Kind, n: number?, id: string? }

-- What the detector keeps from one BaseState.
export type BaseSnap = {
	level: number, -- player level
	habitat: number, -- base level (habitat build level)
	mainCount: number?, -- main quests done (nil from an older server)
	sides: { [string]: boolean }, -- open side quests
	builds: { [string]: number }, -- build levels standing in this server
}

export type Style = {
	count: number, -- confetti pieces on screen (0 = none)
	origin: { number }, -- burst point, screen fractions { x, y }
	rain: boolean, -- true: pieces fall from the top instead of bursting from `origin`
	speed: { number }, -- burst speed range, screen heights per second
	colors: { string }, -- Theme.PALETTE names
	flash: number?, -- start transparency of the screen flash (nil = no flash; higher = softer)
	flashColor: string, -- Theme.PALETTE name
	title: string?, -- localization key of a big centred title ({n} = the level)
	sting: string?, -- AudioIds name played with Audio.sting (nil: another module already plays one)
	world: boolean, -- also a burst of star sparkles in the world (at the build)
	seconds: number, -- how long the moment lasts on screen
}

-- Feel tuning.
Feel.MAX_PARTICLES = 90 -- confetti pieces alive at once (older ones are dropped first)
Feel.GRAVITY = 1.25 -- confetti fall, screen heights per second squared
Feel.GAP_SECONDS = 0.9 -- moments that arrive together play one after another
Feel.MAX_QUEUE = 4 -- moments waiting; more are merged away
Feel.SETTLE_SECONDS = 4 -- after a save slot loads, updates only refresh the memory
Feel.MAX_BUILD_MOMENTS = 3 -- more builds rising in one update = a world reload, not a celebration
Feel.REDUCED_FLASH = 0.9 -- with "reduce motion" the flash is never stronger than this
Feel.FLASH_SECONDS = 0.35

-- Quests and achievements burst near the toast cards (right side); levels in the middle; a
-- finished mission rains from the top. Quest, level, achievement and mission sounds already play in
-- QuestToasts, Hud and Audio (no second copy here); the base level up gets the level-up sting.
Feel.STYLES = table.freeze({
	quest = table.freeze({
		count = 20,
		origin = { 0.82, 0.32 },
		rain = false,
		speed = { 0.45, 0.85 },
		colors = { "lime", "gold", "cyan" },
		flash = 0.84,
		flashColor = "lime",
		title = nil,
		sting = nil,
		world = false,
		seconds = 1.4,
	} :: Style),
	achievement = table.freeze({
		count = 20,
		origin = { 0.82, 0.32 },
		rain = false,
		speed = { 0.45, 0.85 },
		colors = { "gold", "magenta", "cream" },
		flash = 0.84,
		flashColor = "gold",
		title = nil,
		sting = nil,
		world = false,
		seconds = 1.4,
	} :: Style),
	level = table.freeze({
		count = 28,
		origin = { 0.5, 0.4 },
		rain = false,
		speed = { 0.55, 1.0 },
		colors = { "gold", "lime", "cyan", "magenta" },
		flash = 0.78,
		flashColor = "gold",
		title = "ui.level",
		sting = nil,
		world = false,
		seconds = 1.6,
	} :: Style),
	base = table.freeze({
		count = 32,
		origin = { 0.5, 0.4 },
		rain = false,
		speed = { 0.55, 1.05 },
		colors = { "cyan", "gold", "lime", "orange" },
		flash = 0.76,
		flashColor = "cyan",
		title = "ui.base_level",
		sting = "sting_level_up",
		world = true,
		seconds = 1.8,
	} :: Style),
	mission = table.freeze({
		count = 36,
		origin = { 0.5, 0 },
		rain = true,
		speed = { 0.12, 0.35 },
		colors = { "gold", "lime", "cyan", "magenta", "orange" },
		flash = 0.82,
		flashColor = "gold",
		title = nil,
		sting = nil,
		world = false,
		seconds = 1.9,
	} :: Style),
	build = table.freeze({
		count = 0,
		origin = { 0.5, 0.5 },
		rain = false,
		speed = { 0, 0 },
		colors = { "cyan", "lime" },
		flash = nil,
		flashColor = "cyan",
		title = nil,
		sting = nil,
		world = true,
		seconds = 1.2,
	} :: Style),
} :: { [string]: Style })

-- Most important first (when several arrive together).
local PRIORITY: { [string]: number } = { base = 1, level = 2, mission = 3, quest = 4, achievement = 5, build = 6 }
Feel.PRIORITY = table.freeze(PRIORITY)

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

-- One BaseState (as the server sends it) reduced to what the detector compares. nil = not a state.
function Feel.snap(raw: any): BaseSnap?
	if type(raw) ~= "table" or type(raw.credits) ~= "number" then
		return nil
	end
	local builds: { [string]: number } = {}
	if type(raw.builds) == "table" then
		for id, level in raw.builds do
			if type(id) == "string" and type(level) == "number" and level == level then
				builds[id] = level
			end
		end
	end
	local mainCount: number? = nil
	local sides: { [string]: boolean } = {}
	local quest = raw.quest
	if type(quest) == "table" then
		if type(quest.mainCount) == "number" and quest.mainCount == quest.mainCount then
			mainCount = math.floor(quest.mainCount)
		end
		if type(quest.sides) == "table" then
			for index = 1, #quest.sides do
				local side = quest.sides[index]
				if type(side) == "table" and type(side.id) == "string" and side.id ~= "" then
					sides[side.id] = true
				end
			end
		end
	end
	return {
		level = math.max(1, math.floor(numberOr(raw.level, 1))),
		habitat = math.max(0, builds.habitat or 0),
		mainCount = mainCount,
		sides = sides,
		builds = builds,
	}
end

-- The moments between two snapshots, most important first. Nothing before a first snapshot.
function Feel.detect(before: BaseSnap?, after: BaseSnap): { Moment }
	local moments: { Moment } = {}
	if before == nil then
		return moments
	end
	-- One base level at a time is a real upgrade; a bigger jump is a world (re)load or the showcase.
	if after.habitat == before.habitat + 1 then
		table.insert(moments, { kind = "base", n = after.habitat })
	end
	if after.level > before.level then
		table.insert(moments, { kind = "level", n = after.level })
	end
	local questsDone = 0
	local beforeMain, afterMain = before.mainCount, after.mainCount
	if beforeMain ~= nil and afterMain ~= nil and afterMain > beforeMain then
		questsDone += afterMain - beforeMain
	end
	for id in before.sides do
		if not after.sides[id] then
			questsDone += 1 -- side quests leave the list only when they are done
		end
	end
	if questsDone > 0 then
		table.insert(moments, { kind = "quest", n = questsDone })
	end
	local risen: { string } = {}
	for id, level in after.builds do
		if id ~= "habitat" and level > (before.builds[id] or 0) then
			table.insert(risen, id)
		end
	end
	if #risen <= Feel.MAX_BUILD_MOMENTS then
		table.sort(risen)
		for _, id in risen do
			table.insert(moments, { kind = "build", id = id, n = after.builds[id] })
		end
	end
	table.sort(moments, function(a: Moment, b: Moment): boolean
		return PRIORITY[a.kind] < PRIORITY[b.kind]
	end)
	return moments
end

-- Adds a moment to a waiting queue: the same kind merges into the one already waiting (a quest
-- burst plays once for two quests); a full queue drops the least important moment.
function Feel.enqueue(queue: { Moment }, moment: Moment)
	for _, waiting in queue do
		if waiting.kind == moment.kind and moment.kind ~= "build" then
			if type(moment.n) == "number" then
				waiting.n = moment.n
			end
			return
		end
	end
	table.insert(queue, moment)
	table.sort(queue, function(a: Moment, b: Moment): boolean
		return PRIORITY[a.kind] < PRIORITY[b.kind]
	end)
	while #queue > Feel.MAX_QUEUE do
		table.remove(queue)
	end
end

-- Flash start transparency for a style; "reduce motion" keeps it soft. nil = no flash.
function Feel.flashFor(style: Style, reduced: boolean): number?
	local flash = style.flash
	if flash == nil then
		return nil
	end
	return if reduced then math.max(flash, Feel.REDUCED_FLASH) else flash
end

-- Report star reveal --------------------------------------------------------------------------------

Feel.STAR_FIRST_SECONDS = 0.55 -- after the report opens
Feel.STAR_GAP_SECONDS = 0.42
Feel.STAR_POP_SECONDS = 0.32

-- Seconds after the report opens when earned star `index` appears.
function Feel.starTime(index: number): number
	return Feel.STAR_FIRST_SECONDS + (math.max(1, index) - 1) * Feel.STAR_GAP_SECONDS
end

-- How many of `stars` earned stars show `elapsed` seconds after the report opened.
function Feel.starsShown(stars: number, elapsed: number): number
	local shown = 0
	for index = 1, stars do
		if elapsed >= Feel.starTime(index) then
			shown = index
		end
	end
	return shown
end

-- Each star's note is a little higher, so three stars climb.
function Feel.starPitch(index: number): number
	return 1 + 0.12 * (math.max(1, index) - 1)
end

-- Seconds until the whole reveal is done (the mission confetti follows it).
function Feel.revealSeconds(stars: number): number
	if stars <= 0 then
		return Feel.STAR_FIRST_SECONDS
	end
	return Feel.starTime(stars) + Feel.STAR_POP_SECONDS
end

-- Report "cause -> effect" chips ------------------------------------------------------------------

export type Effect = {
	meter: string, -- "air" | "food" | "dose" | "science"
	dir: number, -- 1 = went up, -1 = went down
	good: boolean, -- colour: good (lime) or warning (orange)
}

Feel.EFFECT_MIN_CHANGE = 0.5 -- smaller changes are "about the same" (no chip)
Feel.MAX_EFFECTS = 3

-- The chips of every day of a mission, from its history. `start` holds the meters before day 1
-- (MissionData.METERS.START_AIR / START_FOOD / START_DOSE). Dose only ever shows going up.
function Feel.dayEffects(history: { any }, start: { air: number, food: number, dose: number }): { { Effect } }
	local result: { { Effect } } = {}
	local previous = { air = start.air, food = start.food, dose = start.dose }
	for _, record in history do
		local effects: { Effect } = {}
		local air = numberOr(record.air, previous.air)
		local food = numberOr(record.food, previous.food)
		local dose = numberOr(record.dose, previous.dose)
		local airChange = air - previous.air
		if math.abs(airChange) >= Feel.EFFECT_MIN_CHANGE then
			table.insert(effects, { meter = "air", dir = if airChange > 0 then 1 else -1, good = airChange > 0 })
		end
		local foodChange = food - previous.food
		if math.abs(foodChange) >= Feel.EFFECT_MIN_CHANGE then
			table.insert(effects, { meter = "food", dir = if foodChange > 0 then 1 else -1, good = foodChange > 0 })
		end
		if dose - previous.dose >= Feel.EFFECT_MIN_CHANGE then
			table.insert(effects, { meter = "dose", dir = 1, good = false })
		end
		if numberOr(record.scienceSent, 0) > 0 and #effects < Feel.MAX_EFFECTS then
			table.insert(effects, { meter = "science", dir = 1, good = true })
		end
		while #effects > Feel.MAX_EFFECTS do
			table.remove(effects)
		end
		table.insert(result, effects)
		previous = { air = air, food = food, dose = math.max(dose, previous.dose) }
	end
	return result
end

-- Camera shake -------------------------------------------------------------------------------------

Feel.SHAKE = table.freeze({
	MAX_OFFSET = 0.15, -- studs at full trauma
	MAX_ANGLE_DEG = 1.2, -- degrees at full trauma
	DECAY_PER_SECOND = 1.6, -- trauma lost per second
	FREQUENCY = 16, -- noise speed
	METEOR_NEAR = 25, -- studs: a full jolt this close
	METEOR_FAR = 170, -- studs: nothing felt past this
	METEOR_MAX = 0.75, -- trauma of the closest impact
})

-- Trauma (0..1) from a meteorite impact `distance` studs away. On the Moon there is no air to carry a
-- blast: the ground shakes, so it fades fast with distance.
function Feel.meteorTrauma(distance: number): number
	local near, far = Feel.SHAKE.METEOR_NEAR, Feel.SHAKE.METEOR_FAR
	if distance ~= distance or distance >= far then
		return 0
	end
	if distance <= near then
		return Feel.SHAKE.METEOR_MAX
	end
	local t = 1 - (distance - near) / (far - near)
	return Feel.SHAKE.METEOR_MAX * t * t
end

-- Shake strength from trauma: squared, so small bumps stay tiny.
function Feel.shakeAmount(trauma: number): number
	local t = math.clamp(trauma, 0, 1)
	return t * t
end

-- Trauma after `dt` seconds.
function Feel.decay(trauma: number, dt: number): number
	return math.max(0, trauma - Feel.SHAKE.DECAY_PER_SECOND * math.max(0, dt))
end

return Feel
