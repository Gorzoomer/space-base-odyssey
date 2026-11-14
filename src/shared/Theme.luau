--!strict
-- Space Base Odyssey - visual identity "Lunar Sunrise": one palette for UI, icons, lights and base details.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Theme = {}

-- Core palette (team decision: "Amanecer lunar").
Theme.PALETTE = table.freeze({
	night = hex("#12162B"), -- backgrounds, panels
	nightLight = hex("#1F2547"), -- raised panels, rows
	nightLine = hex("#343C70"), -- strokes and dividers
	cyan = hex("#2EE6FF"), -- primary accent: links, Earth link, C.A.R.L., info
	orange = hex("#FF8A3D"), -- warnings, sunrise, storms
	lime = hex("#9BE15D"), -- good state, go buttons, growth
	magenta = hex("#FF4FA3"), -- greenhouse grow lights, rewards, secrets
	cream = hex("#FFF4D6"), -- main text on dark
	creamDim = hex("#C9C3B0"), -- secondary text
	red = hex("#FF5A5F"), -- danger only (derived to match the palette)
	gold = hex("#FFD166"), -- stars and trophies (derived to match the palette)
})

-- Semantic roles: use these in code, not raw palette names, so the identity stays consistent.
local P = Theme.PALETTE
Theme.ROLE = table.freeze({
	background = P.night,
	panel = P.night,
	panelRaised = P.nightLight,
	stroke = P.nightLine,
	text = P.cream,
	textDim = P.creamDim,
	accent = P.cyan,
	primaryButton = P.lime,
	primaryButtonText = P.night,
	secondaryButton = P.nightLight,
	dangerButton = P.red,
	warning = P.orange,
	danger = P.red,
	good = P.lime,
	reward = P.magenta,
	star = P.gold,
	-- Meter zones
	zoneGreen = P.lime,
	zoneYellow = P.orange,
	zoneRed = P.red,
	-- Systems
	LifeSupport = P.cyan,
	Greenhouse = P.lime,
	Science = P.magenta,
	-- Meters
	air = P.cyan,
	food = P.lime,
	dose = P.orange,
	suit = P.cyan,
})

-- Fonts: one rounded display font for titles and buttons, one readable font for body text.
Theme.FONT = table.freeze({
	display = Enum.Font.FredokaOne,
	body = Enum.Font.GothamBold,
})

Theme.CORNER = UDim.new(0.18, 0)
Theme.STROKE_THICKNESS = 3

return table.freeze(Theme)
