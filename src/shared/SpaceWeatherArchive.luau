--!strict
-- Space Base Odyssey - real X-class solar flares from NASA's DONKI database (CCMC).
-- Downloaded 14 November 2026 from https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR and /SEP.
-- "particles" is true when DONKI links the flare to a solar energetic particle (SEP) event seen by
-- the GOES satellites. These events were observed near Earth; the game asks "what if a storm like
-- this reached your base?" and never claims the event hit the Moon.
-- Flares with particles = false are real examples of a huge flare WITHOUT a particle storm at
-- Earth: a forecaster's "false alarm" that teaches flare size alone does not decide the danger.
-- SI disclosure: compiled with AI assistance (Claude, Anthropic) and reviewed by the team.

export type ArchivedFlare = {
	id: string, -- DONKI flare ID
	date: string, -- peak time, UTC (ISO 8601)
	class: string, -- GOES X-ray class
	particles: boolean,
	above100MeV: boolean, -- DONKI linked a >100 MeV GOES particle event
}

local FLARES: { ArchivedFlare } = {
	{ id = "2024-05-10T06:27:00-FLR-001", date = "2024-05-10T06:54Z", class = "X3.9", particles = true, above100MeV = false },
	{ id = "2024-05-11T01:10:00-FLR-001", date = "2024-05-11T01:23Z", class = "X5.8", particles = true, above100MeV = true },
	{ id = "2024-05-14T16:46:00-FLR-001", date = "2024-05-14T16:51Z", class = "X8.7", particles = false, above100MeV = false },
	{ id = "2024-10-01T21:58:00-FLR-001", date = "2024-10-01T22:20Z", class = "X7.1", particles = false, above100MeV = false },
	{ id = "2024-10-03T12:08:00-FLR-001", date = "2024-10-03T12:18Z", class = "X9.0", particles = false, above100MeV = false },
	{ id = "2024-10-09T01:25:00-FLR-001", date = "2024-10-09T01:56Z", class = "X1.8", particles = true, above100MeV = true },
	{ id = "2024-10-26T06:32:00-FLR-001", date = "2024-10-26T07:19Z", class = "X1.8", particles = true, above100MeV = false },
	{ id = "2025-11-11T09:49:00-FLR-001", date = "2025-11-11T10:04Z", class = "X5.1", particles = true, above100MeV = true },
	{ id = "2025-11-14T07:44:00-FLR-001", date = "2025-11-14T08:30Z", class = "X4.0", particles = true, above100MeV = false },
	{ id = "2026-01-18T17:27:00-FLR-001", date = "2026-01-18T18:09Z", class = "X1.9", particles = true, above100MeV = false },
	{ id = "2026-02-01T23:44:00-FLR-001", date = "2026-02-01T23:57Z", class = "X8.1", particles = false, above100MeV = false },
}

for _, flare in FLARES do
	table.freeze(flare)
end

return table.freeze({
	SOURCE = "NASA / CCMC DONKI",
	DOWNLOADED = "2026-11-14",
	FLARES = table.freeze(FLARES),
})
