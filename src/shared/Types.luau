--!strict
-- Space Base Odyssey - network contract between server and clients.
-- The server owns the mission. It sends a full Snapshot on every change (and to each player who
-- joins late). Clients only send Actions; the server validates every one.
-- All player-facing text travels as localization keys; clients translate (see Localization).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Simulation = require(script.Parent.Simulation)

export type SystemId = Simulation.SystemId
export type EventId = Simulation.EventId
export type MeterId = Simulation.MeterId
export type Outcome = Simulation.Outcome
export type Allocation = Simulation.Allocation
export type DayRecord = Simulation.DayRecord

-- Briefing: lobby and guided intro. Planning: power board, no clock. Shift: real-time work outside.
-- Report: timeline of the mission with causes and stars.
export type Phase = "Briefing" | "Planning" | "Shift" | "Report"

export type TextRef = {
	key: string,
	params: { [string]: string | number }?,
}

-- What Earth knows about today's solar event. Shown on the Command Center screen and the
-- Sources screen. `source` says honestly whether it came from a live query or the archive.
export type SpaceWeather = {
	source: "live" | "archive",
	flareId: string,
	flareClass: string,
	flareDate: string,
	particles: boolean, -- false = big flare, no particle storm reached Earth (false alarm)
	fetchedAt: string?, -- ISO time of the live query, when source == "live"
}

-- Live state of the current shift (nil outside the Shift phase).
export type ShiftState = {
	endsAt: number, -- workspace:GetServerTimeNow() value
	antennaLinked: boolean,
	stormWarningAt: number?, -- when the warning was given
	stormArrivesAt: number?, -- when particles arrive; players outside the shelter are exposed
	stormEndsAt: number?,
	dustyArrays: number,
	leakActive: boolean,
	iceCoresDelivered: number,
}

export type Snapshot = {
	phase: Phase,
	day: number,
	totalDays: number,
	todayEvent: EventId,
	allocation: Allocation,
	cellsAvailable: number,
	air: number,
	food: number,
	dose: number,
	sciencePoints: number,
	stars: number,
	outcome: Outcome,
	history: { DayRecord },
	shift: ShiftState?,
	spaceWeather: SpaceWeather?,
}

-- Per-player data, sent only to that player.
export type PlayerStats = {
	suitO2: number,
	inside: boolean, -- inside a pressurized module
	sheltered: boolean, -- inside the regolith shelter
	carryingIce: boolean,
}

-- Client -> server requests.
export type Action =
	{ type: "SetCells", system: SystemId, cells: number }
	| { type: "StartShift" }
	| { type: "Restart" }
	| { type: "SetLanguage", language: "en" | "es" }
	-- Owner-only, Studio or the place owner: deterministic testing and video recording.
	| { type: "DebugForceEvent", event: EventId }
	| { type: "DebugSkipToDay", day: number }
	| { type: "DebugSeed", seed: number }

-- Names of the RemoteEvents the server creates in ReplicatedStorage.Remotes.
local Remotes = table.freeze({
	FOLDER = "Remotes",
	SNAPSHOT = "Snapshot", -- server -> client: Snapshot
	PLAYER_STATS = "PlayerStats", -- server -> one client: PlayerStats
	MESSAGE = "AssistantMessage", -- server -> client: TextRef from the C.A.R.L. assistant
	ACTION = "Action", -- client -> server: Action
})

return table.freeze({
	Remotes = Remotes,
})
