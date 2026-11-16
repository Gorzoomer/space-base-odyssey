--!strict
-- Space Base Odyssey - reading rules for young players (Stage 11 "readable UI"). Pure rules shared by
-- the client screens that show text:
--   * how long a line stays on screen (Messages, QuestToasts): it grows with the number of words, so a
--     7-year-old (about one word a second) can finish it, and never drops under a minimum;
--   * which C.A.R.L. lines to keep when many arrive at once (a finished quest can bring the praise,
--     "quest done", "new quest", an achievement and a level-up in the same second): a repeated key is
--     merged, and when the queue is full the least useful line goes to the history instead of the
--     screen;
--   * which quest toast to drop when its queue is full: step lines first, achievement cards never;
--   * where the picture-glossary words (src/shared/Glossary.luau) sit inside a text, and the RichText
--     markup that paints them gold so they can be tapped;
--   * whether a quest step shows "progress/target" (counted steps only, never "level 2  1/2");
--   * page maths for the Achievements panel.
-- Pure: no Roblox instances and no require, so tests/reading runs it in Lune.
-- The timings here are technical UI settings (like the old SHOW_SECONDS constants), not gameplay
-- numbers, so they are not in MissionData.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Reading = {}

-- Reading time ------------------------------------------------------------------------------------

Reading.MIN_SECONDS = 4 -- no line is shorter on screen (team request for young readers)
Reading.LEAD_SECONDS = 2 -- time to notice a new line before reading starts
Reading.WORD_SECONDS = 0.75 -- per word (an 8-word line stays 8 s)
Reading.MAX_SECONDS = 12 -- a normal line never waits longer
Reading.FACT_MAX_SECONDS = 16 -- fun facts and achievement facts may have 16 words
Reading.BUSY_FACTOR = 0.75 -- shorter (never under the minimum) while more lines wait

-- Words a reader has to read: tokens with at least one letter or digit ("{n}" placeholders are already
-- filled when this runs; a lone "-" or "!" does not count). Bytes 128-255 are UTF-8 letters such as
-- "á" or "ñ".
function Reading.wordCount(text: string): number
	local count = 0
	for token in string.gmatch(text, "%S+") do
		if string.find(token, "[%w\128-\255]") then
			count += 1
		end
	end
	return count
end

export type SecondsOptions = {
	minimum: number?, -- a player setting (Store.messageSeconds) may raise the minimum
	fact: boolean?, -- longer cap for 16-word facts
	busy: boolean?, -- more lines wait: a little shorter, never under the minimum
}

-- Seconds a line stays on screen.
function Reading.seconds(text: string, options: SecondsOptions?): number
	local opts: SecondsOptions = options or {}
	local minimum = Reading.MIN_SECONDS
	if type(opts.minimum) == "number" and opts.minimum == opts.minimum and opts.minimum > minimum then
		minimum = math.min(opts.minimum, Reading.FACT_MAX_SECONDS)
	end
	local cap = if opts.fact then Reading.FACT_MAX_SECONDS else Reading.MAX_SECONDS
	local seconds = Reading.LEAD_SECONDS + Reading.WORD_SECONDS * Reading.wordCount(text)
	if opts.busy then
		seconds *= Reading.BUSY_FACTOR
	end
	return math.clamp(seconds, minimum, math.max(minimum, cap))
end

-- C.A.R.L. line queue ------------------------------------------------------------------------------

-- How useful a line is when many wait (higher = kept). The quest toast already shows "quest done"
-- and "new quest", so those lines are the first to give way; a refusal ("base.why.*") answers what
-- the player just tried, and praise, quiz lines and treasure hints teach something.
function Reading.priority(key: string): number
	if string.sub(key, 1, 9) == "base.why." then
		return 4
	end
	if key == "carl.quest.done" or key == "carl.quest.new" or key == "carl.quest.side" or key == "quest.main_done" then
		return 1
	end
	if string.match(key, "^quest%.[%w_]+%.praise$") or string.sub(key, 1, 5) == "quiz." or string.sub(key, 1, 14) == "carl.treasure." then
		return 3
	end
	return 2
end

-- Adds `item` to the waiting `queue` (oldest first) and returns the items that will not be shown (the
-- caller keeps them in the history). A line whose key is already waiting replaces it in place (newer
-- numbers win, no repeat). While the queue holds more than `cap` items, the oldest of the lowest
-- priority goes.
function Reading.enqueue<T>(queue: { T }, item: T, keyOf: (T) -> string, cap: number): { T }
	local dropped: { T } = {}
	local key = keyOf(item)
	for index, waiting in queue do
		if keyOf(waiting) == key then
			queue[index] = item
			return dropped
		end
	end
	table.insert(queue, item)
	while #queue > math.max(1, cap) do
		local dropAt = 1
		local lowest = math.huge
		for index, waiting in queue do
			local rank = Reading.priority(keyOf(waiting))
			if rank < lowest then
				lowest = rank
				dropAt = index
			end
		end
		table.insert(dropped, table.remove(queue, dropAt) :: T)
	end
	return dropped
end

-- Quest toasts -------------------------------------------------------------------------------------

-- Toast tags (QuestToasts.luau) by how much they matter. Achievements are the learning moment: they
-- are never dropped (math.huge), even if the queue grows past its cap.
Reading.TOAST_RANK = table.freeze({
	step = 1,
	current = 2,
	new = 3,
	side_done = 4,
	main_done = 5,
	achievement = math.huge,
} :: { [string]: number })

-- Index of the toast to drop from a full queue (the oldest one of the lowest rank), or nil when only
-- achievement cards wait. Unknown tags rank like a step line.
function Reading.toastDropIndex(tags: { string }): number?
	local dropAt: number? = nil
	local lowest = math.huge
	for index, tag in tags do
		local rank = Reading.TOAST_RANK[tag] or 1
		if rank < lowest then
			lowest = rank
			dropAt = index
		end
	end
	return dropAt
end

-- Quest step fraction -------------------------------------------------------------------------------

-- True when the tracker should add "  progress/target" and a progress bar. `counted` comes from the
-- server (Types.QuestStepState.counted, Stage 11), `defShows` from Quests.showsFraction(step def);
-- with neither (an older server and an unknown quest) any target above 1 counts. Build and tool
-- levels say "level 2" in the text instead, and a done step shows its tick only.
function Reading.stepShowsFraction(counted: boolean?, defShows: boolean?, target: number, done: boolean): boolean
	if done or target <= 1 then
		return false
	end
	if counted ~= nil then
		return counted
	end
	if defShows ~= nil then
		return defShows
	end
	return true
end

-- Glossary words in a text ----------------------------------------------------------------------------

export type Term = { id: string, word: string } -- word: one form of the glossary word (any case)
export type Match = { id: string, first: number, last: number } -- byte range in the text

-- Is the character that ends just before byte `position` a letter (then `position` is not a word start)?
local function letterBefore(text: string, position: number): boolean
	if position <= 1 then
		return false
	end
	local byte = string.byte(text, position - 1)
	if byte < 128 then
		return string.match(string.char(byte), "%w") ~= nil
	end
	-- A UTF-8 character: walk back to its first byte.
	local start = position - 1
	while start > 1 and string.byte(text, start) >= 128 and string.byte(text, start) < 192 do
		start -= 1
	end
	local char = string.sub(text, start, position - 1)
	return char ~= "¡" and char ~= "¿" and char ~= "«" and char ~= "»" and char ~= "—" and char ~= "–"
end

-- Is the byte at `position` the start of a letter (then the word goes on)?
local function letterAt(text: string, position: number): boolean
	local byte = string.byte(text, position)
	if byte == nil then
		return false
	end
	if byte < 128 then
		return string.match(string.char(byte), "%w") ~= nil
	end
	return byte >= 195 -- lead byte of a Latin letter (á, é, ñ...); "¡" and "¿" start with 194
end

-- Glossary words found in `text`, in reading order, never overlapping (a longer form wins at the same
-- place). Case does not matter for ASCII letters. A word must start at a word start; it may end with a
-- plural "s" or "es" ("solar panels", "silos").
function Reading.findTerms(text: string, terms: { Term }): { Match }
	local lower = string.lower(text)
	local found: { Match } = {}
	for _, term in terms do
		local word = string.lower(term.word)
		if #word == 0 then
			continue
		end
		local from = 1
		while true do
			local first, last = string.find(lower, word, from, true)
			if first == nil or last == nil then
				break
			end
			from = first + 1
			if letterBefore(lower, first) then
				continue
			end
			local finish = last
			if letterAt(lower, finish + 1) then
				if string.sub(lower, finish + 1, finish + 2) == "es" and not letterAt(lower, finish + 3) then
					finish += 2
				elseif string.sub(lower, finish + 1, finish + 1) == "s" and not letterAt(lower, finish + 2) then
					finish += 1
				else
					continue -- the word goes on ("silos" is fine, "silom" is not)
				end
			end
			table.insert(found, { id = term.id, first = first, last = finish })
		end
	end
	-- Reading order; at the same start the longer match first, then drop overlaps.
	table.sort(found, function(a: Match, b: Match): boolean
		if a.first ~= b.first then
			return a.first < b.first
		end
		return a.last > b.last
	end)
	local result: { Match } = {}
	local reached = 0
	for _, match in found do
		if match.first > reached then
			table.insert(result, match)
			reached = match.last
		end
	end
	return result
end

-- Text safe for a RichText label: &, < and > written as entities.
function Reading.escape(text: string): string
	local escaped = string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" })
	return escaped
end

-- RichText for `text` with every match painted `hex` (for example "F5C542") and underlined, so a
-- young reader sees which words can be tapped. Everything else is escaped.
function Reading.markup(text: string, matches: { Match }, hex: string): string
	local parts: { string } = {}
	local at = 1
	for _, match in matches do
		if match.first < at then
			continue
		end
		table.insert(parts, Reading.escape(string.sub(text, at, match.first - 1)))
		table.insert(parts, `<font color="#{hex}"><u>{Reading.escape(string.sub(text, match.first, match.last))}</u></font>`)
		at = match.last + 1
	end
	table.insert(parts, Reading.escape(string.sub(text, at)))
	return table.concat(parts)
end

-- The forms of a glossary word: the word itself plus a comma-separated list of other forms
-- ("paneles solares, paneles"). Empty entries are skipped.
function Reading.forms(word: string, extra: string?): { string }
	local list: { string } = {}
	local function add(form: string)
		local trimmed = string.match(form, "^%s*(.-)%s*$") or ""
		if trimmed ~= "" and table.find(list, trimmed) == nil then
			table.insert(list, trimmed)
		end
	end
	add(word)
	if type(extra) == "string" then
		for form in string.gmatch(extra, "[^,]+") do
			add(form)
		end
	end
	return list
end

-- Pages ---------------------------------------------------------------------------------------------

function Reading.pageCount(total: number, perPage: number): number
	return math.max(1, math.ceil(math.max(0, total) / math.max(1, perPage)))
end

-- The first and last item on page `page` (clamped to the pages that exist); last < first when empty.
function Reading.pageRange(total: number, perPage: number, page: number): (number, number, number)
	local size = math.max(1, math.floor(perPage))
	local pages = Reading.pageCount(total, size)
	local current = math.clamp(math.floor(page), 1, pages)
	local first = (current - 1) * size + 1
	return first, math.min(total, first + size - 1), current
end

return table.freeze(Reading)
