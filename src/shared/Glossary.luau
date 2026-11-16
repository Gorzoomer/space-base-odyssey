--!strict
-- Space Base Odyssey - picture glossary (Stage 11): ONE word per thing, a Tabler icon and a short
-- kid definition. Quests, pads, prompts and C.A.R.L. use these exact words (DEVELOPMENT.md, "Stage 11:
-- quests that teach", lists the choices), and a future "?" card can show a word with its picture.
-- Pure data: no Roblox instances and no require (tests/achievements checks it in Lune).
--
-- Texts: "glossary.<id>.word" (the word itself, at most 3 words) and "glossary.<id>.def" (at most 8
-- words, no numbers).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type Term = {
	id: string,
	icon: string, -- key in src/shared/Icons.luau
}

local LIST: { Term } = {
	{ id = "habitat", icon = "home" },
	{ id = "parts_box", icon = "crate" },
	{ id = "solar_panel", icon = "panel" },
	{ id = "ice_crater", icon = "ice" },
	{ id = "oxygen", icon = "air" },
	{ id = "radiation", icon = "dose" },
	{ id = "solar_flare", icon = "storm" },
	{ id = "silo", icon = "silo" },
	{ id = "base_level", icon = "upgrade" },
}

local byId: { [string]: Term } = {}
for _, term in LIST do
	table.freeze(term)
	byId[term.id] = term
end

local Glossary = {}

Glossary.LIST = table.freeze(LIST)

function Glossary.get(id: any): Term?
	return if type(id) == "string" then byId[id] else nil
end

function Glossary.wordKey(id: string): string
	return "glossary." .. id .. ".word"
end

function Glossary.defKey(id: string): string
	return "glossary." .. id .. ".def"
end

return table.freeze(Glossary)
