--!strict
-- Space Base Odyssey - Stage 11 tycoon, client side: pure rules for what the ice line SHOWS (no Roblox
-- instances, so it runs in Lune: tests/base section R). Used by src/client/IncomePops.luau ("+N"
-- pops, the "While you were away" card, the silo-full cue), src/client/ProductionLine.luau (the
-- world signs over the silo and the water plant), src/client/Hud.luau (the "Machines" income line)
-- and src/client/CarlDrone.luau (when C.A.R.L. sends the player to the silo).
-- Every number comes from MissionData (BASE and TYCOON_CLIENT, all GAME). The server stays the
-- authority: these rules only decide what a client draws from what the server sent.
-- Like the other shared rule modules it requires nothing: callers pass MissionData (`data`) and
-- BaseBuild (`rules`), so the same file runs in Roblox and in Lune.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local IceLineView = {}

-- The status light of a sign: green "run", red "full" (the belt stopped), amber "nopower" (the air
-- maker has no electricity), dim "off" (no drill yet).
export type Light = "run" | "full" | "nopower" | "off"

export type SignStatus = {
	light: Light,
	reasonKey: string, -- localization key of the short reason under the light
}

-- What the line folder / BaseState says (any field may be missing with an older server).
export type LineInfo = {
	lineStatus: string?, -- "off" | "run" | "full"
	airStatus: string?, -- "off" | "run" | "nopower"
	icePerMinute: number?,
}

local function number(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

-- The silo's sign: the belt decides (off, full, running).
function IceLineView.siloStatus(info: LineInfo): SignStatus
	if info.lineStatus == "off" or number(info.icePerMinute, 0) <= 0 then
		return { light = "off", reasonKey = "ui.line.status_off" }
	elseif info.lineStatus == "full" then
		return { light = "full", reasonKey = "ui.line.status_full" }
	end
	return { light = "run", reasonKey = "ui.line.status_run" }
end

-- The water plant's sign: no power for the air maker comes first (it is the thing the kid can fix
-- with solar panels), then the silo's own state.
function IceLineView.plantStatus(info: LineInfo): SignStatus
	local silo = IceLineView.siloStatus(info)
	if silo.light ~= "off" and info.airStatus == "nopower" then
		return { light = "nopower", reasonKey = "ui.line.air_nopower" }
	end
	return silo
end

-- Credits a minute the machines make now: BaseState.machineCreditsPerMinute when the server sent it,
-- else worked out from the ice a minute and the product (same rule as BaseService.buildState).
function IceLineView.creditsPerMinute(data: any, sent: number?, icePerMinute: number?, product: string?): number
	if type(sent) == "number" and sent == sent and sent >= 0 then
		return sent
	end
	local rate = number(icePerMinute, 0)
	if rate <= 0 or product == "none" then
		return 0
	end
	local factor = if product == "oxygen" then (100 + (data.BASE.OXYGEN_BONUS_PERCENT or 0)) / 100 else 1
	return rate * data.BASE.CREDITS_PER_SILO_ICE * factor
end

-- A rate for a sign or the wallet: whole numbers as they are, others with one decimal ("2.5").
function IceLineView.formatRate(value: number): string
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return "0"
	end
	local tenths = math.floor(value * 10 + 0.5)
	if tenths % 10 == 0 then
		return tostring(tenths // 10)
	end
	return string.format("%d.%d", tenths // 10, tenths % 10)
end

-- The "+N" credits of a line event, or nil when this client gets no credits pop: only deliveries
-- and hand claims, only when the credits went to this player (mine), only whole credits above 0.
function IceLineView.popCredits(event: any): number?
	if type(event) ~= "table" or (event.kind ~= "delivery" and event.kind ~= "claim") then
		return nil
	end
	if event.mine ~= true then
		return nil
	end
	local credits = event.credits
	if type(credits) ~= "number" or credits ~= credits or credits < 1 then
		return nil
	end
	return math.floor(credits)
end

export type AwayCard = {
	ice: number, -- whole ice the drills dug while the player was away
	credits: number, -- what that ice is worth once it reaches the base
	robot: boolean, -- true: the cargo robot carries it home by itself (the card just closes)
	capped: boolean, -- the silo filled up (or the time limit ran out) while away
}

-- The "While you were away" card from a LineEvent of kind "away", or nil (nothing to show). The ice
-- waits in the silo (the server never pays it at load): with a cargo robot it is carried home and
-- pays the robot's product; without one the player sends it at the silo (water).
function IceLineView.awayCard(data: any, rules: any, event: any, builds: { [string]: number }?): AwayCard?
	if type(event) ~= "table" or event.kind ~= "away" then
		return nil
	end
	local ice = event.ice
	if type(ice) ~= "number" or ice ~= ice or ice < 1 then
		return nil
	end
	local whole = math.floor(ice)
	local levels = builds or {}
	local robot = rules.levelOf(levels, "cargo_bot") >= 1
	local product: string = if robot then rules.plantProduct(data, levels) else "water"
	if product == "none" then
		product = "water"
	end
	return {
		ice = whole,
		credits = rules.productCredits(data, whole, product),
		robot = robot,
		capped = event.capped == true,
	}
end

-- C.A.R.L. sends the player to the silo only when it is theirs (siloOwner is not false: older
-- servers do not send it) and it holds at least TYCOON_CLIENT.CARL_SILO_MIN_ICE whole ice; else the
-- crater ice is the better way to earn.
function IceLineView.siloWorthAVisit(data: any, siloOwner: boolean?, siloIce: number?): boolean
	if siloOwner == false then
		return false
	end
	local client = data.TYCOON_CLIENT
	local need = if client and type(client.CARL_SILO_MIN_ICE) == "number" then client.CARL_SILO_MIN_ICE else 1
	return math.floor(number(siloIce, 0)) >= math.max(1, need)
end

-- True when a bigger habitat would make the silo bigger (the "upgrade" half of the silo-full hint):
-- the next habitat level's silo holds more than this one's.
function IceLineView.biggerSiloNext(data: any, rules: any, builds: { [string]: number }?): boolean
	local levels = table.clone(builds or {})
	local habitat = rules.levelOf(levels, "habitat")
	local now = rules.siloMax(data, levels)
	local list = data.BASE.SILO_MAX_BY_HABITAT
	if type(list) ~= "table" or habitat >= #list then
		return false
	end
	levels.habitat = habitat + 1
	return rules.siloMax(data, levels) > now
end

return table.freeze(IceLineView)
