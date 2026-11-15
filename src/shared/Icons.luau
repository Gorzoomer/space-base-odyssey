--!strict
-- Space Base Odyssey - game icons. White Tabler Icons (MIT, https://tabler.io/icons) rendered to PNG and
-- uploaded to Roblox. They are tinted with Theme colours through ImageColor3, so every icon shares one style.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Icons = {
	air = "rbxassetid://127204977574497", -- tabler: wind
	food = "rbxassetid://100704362172702", -- salad
	dose = "rbxassetid://85247966655063", -- radioactive
	suit = "rbxassetid://112698185020317", -- lungs
	power = "rbxassetid://120326374445627", -- bolt (filled)
	greenhouse = "rbxassetid://117555385952843", -- plant-2
	science = "rbxassetid://109556187389390", -- microscope
	clock = "rbxassetid://118131844034642", -- clock-hour-4
	calm = "rbxassetid://79578753490818", -- moon
	dust = "rbxassetid://137477984447333", -- cloud-fog
	storm = "rbxassetid://88022283226797", -- sun-high
	failure = "rbxassetid://113720275308833", -- tool
	alert = "rbxassetid://134499273501318", -- alert-triangle (filled)
	shield = "rbxassetid://117027031894492", -- shield (filled)
	antenna = "rbxassetid://127938847567368", -- antenna
	satellite = "rbxassetid://117437382799092", -- satellite
	ice = "rbxassetid://128338365007721", -- snowflake
	drop = "rbxassetid://110290377689399", -- droplet (filled)
	panel = "rbxassetid://98630507905205", -- solar-panel
	run = "rbxassetid://119038010931265", -- run
	star = "rbxassetid://105478135517454", -- star (filled)
	starEmpty = "rbxassetid://86389367581431", -- star
	rocket = "rbxassetid://85356586802868", -- rocket
	language = "rbxassetid://81703720002350", -- world
	close = "rbxassetid://71879508387655", -- x
	restart = "rbxassetid://136632889471571", -- refresh
	data = "rbxassetid://86707802424006", -- database
	robot = "rbxassetid://140005459792879", -- robot
	pointer = "rbxassetid://76212921961655", -- hand-finger-right
	hourglass = "rbxassetid://129559590758885", -- hourglass
	lock = "rbxassetid://112505447028828", -- lock (filled)
	trophy = "rbxassetid://74068302307423", -- trophy (filled)
	gift = "rbxassetid://104225802085968", -- gift
	telescope = "rbxassetid://132116817547332", -- telescope
	paw = "rbxassetid://88291528279353", -- paw (filled)
	cheese = "rbxassetid://123119252293619", -- cheese
	potato = "rbxassetid://87080431149083", -- seedling
	check = "rbxassetid://89349158153835", -- circle-check
	map = "rbxassetid://97584615788906", -- map-pin
	book = "rbxassetid://130635844434903", -- book
	planet = "rbxassetid://116447932914581", -- planet
	flag = "rbxassetid://116670258362045", -- flag (filled)
	target = "rbxassetid://115948676619886", -- target-arrow
	home = "rbxassetid://112913752621612", -- home
	play = "rbxassetid://98866873797236", -- player-play (filled)
	-- Stage 6: build and grow the base.
	coin = "rbxassetid://134004009168001", -- coin (filled): credits
	xp = "rbxassetid://94002559377957", -- sparkles: experience
	drill = "rbxassetid://125137741032326", -- pick
	build = "rbxassetid://80278935277688", -- hammer
	upgrade = "rbxassetid://84032123245462", -- arrow-big-up-lines
	wardrobe = "rbxassetid://82541976645370", -- hanger
	helmet = "rbxassetid://83651822396222", -- helmet
	backpack = "rbxassetid://74585032502388", -- backpack
	silo = "rbxassetid://111195560556445", -- building-warehouse
	skills = "rbxassetid://124370977697332", -- trending-up
	-- Stage 7: tools, vehicles, exploring.
	car = "rbxassetid://129248089646643", -- car
	flask = "rbxassetid://84574378206316", -- flask: the Lab
	tablet = "rbxassetid://83474594791656", -- device-tablet
	brush = "rbxassetid://92142765274700", -- brush
	crate = "rbxassetid://118825664624545", -- package: parts crate
	meteor = "rbxassetid://86135352621535", -- meteor
	truck = "rbxassetid://116616146253941", -- truck: ice hauler
	explore = "rbxassetid://140628088698623", -- map-search: exploration sites
	repairKit = "rbxassetid://115851349850340", -- briefcase-2: the repair kit tool (not the wrench icon)
}

-- Earth map: NASA Visible Earth "Blue Marble" (public domain, NASA Goddard), 1024x512 equirectangular.
Icons.earthMap = "rbxassetid://108242726596736"

-- Near-black 64x64 skybox face made by the team (no external source).
Icons.skyBlack = "rbxassetid://116532295206191"

-- Aliases share an image.
Icons.lifesupport = Icons.air
Icons.repair = Icons.failure
Icons.earth = Icons.language
Icons.solar = Icons.panel
Icons.plant = Icons.greenhouse
Icons.lungs = Icons.suit

export type IconName = string

return table.freeze(Icons)
