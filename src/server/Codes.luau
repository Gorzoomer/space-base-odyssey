--!strict
-- Space Base Odyssey - redeem codes for event cosmetics. Server only: this module lives in
-- ServerScriptService, which is never replicated, so players cannot read the codes.
-- The team changes the code before the event. A cosmetic is only a look, never a gameplay advantage.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Codes = {}

-- Every cosmetic a code can give (saved in Progress.cosmetics). Name key: "cosmetic.<id>.name".
Codes.COSMETICS = table.freeze({
	"explorer26", -- NASA Space Apps 2026 participants: gold visor and gold suit bands
})

-- Code (upper case, no spaces around it) -> cosmetic id.
local CODES: { [string]: string } = {
	QRO2026 = "explorer26",
}

function Codes.isCosmetic(id: any): boolean
	return type(id) == "string" and table.find(Codes.COSMETICS, id) ~= nil
end

-- Trims and upper-cases a code typed by a player. nil when it is not a usable string.
function Codes.normalize(code: any, maxLength: number): string?
	if type(code) ~= "string" or #code > maxLength * 4 then
		return nil
	end
	local trimmed = string.upper(string.match(code, "^%s*(.-)%s*$") or "")
	if trimmed == "" or #trimmed > maxLength then
		return nil
	end
	return trimmed
end

-- The cosmetic a normalized code gives, or nil.
function Codes.lookup(normalized: string): string?
	return CODES[normalized]
end

return table.freeze(Codes)
