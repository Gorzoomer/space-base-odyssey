--!strict
-- Space Base Odyssey - "C.A.R.L. asks" (Stage 11): one short picture question about what the player
-- just learned, asked after some quests are done (retrieval practice with hints, never a penalty).
-- Pure data and rules: no Roblox instances and no require, so it runs in Lune (tests/achievements)
-- as well as on the server (QuestService picks the question and checks the answer) and the client
-- (the question card).
--
-- Texts are localization keys built from the ids (at most 8 words each, en and es):
--   "quiz.<id>.q"      the question
--   "quiz.<id>.a<i>"   answer i (i = 1 .. #answers), shown with the icon answers[i]
--   "quiz.<id>.hint"   said after a wrong answer (a clue, not the answer); the question comes back later
--   "quiz.<id>.why"    said after the right answer: names the science, not "you are smart"
-- No numbers in quiz texts (tests/achievements checks it), so nothing can drift from DATA_SOURCES.md.
-- Science stays as CLAUDE.md says: the shelter protects by mass, radiation never goes down, plants
-- take time, oxygen comes from water plus electricity, a big flare does not always bring a storm.
--
-- The saved record lives inside the quest record (QuestService, base field quest.quiz):
--   { done = { [id] = true }, queue = { id, ... } }  queue = asked next, in order.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

export type Question = {
	id: string,
	after: string, -- the quest id (src/shared/Quests.luau) whose completion queues this question
	icon: string, -- key in src/shared/Icons.luau (the card header)
	answers: { string }, -- one icon (key in Icons) per answer; the texts are "quiz.<id>.a<i>"
	correct: number, -- index into answers of the one right answer
}

export type Record = {
	done: { [string]: boolean },
	queue: { string },
}

export type Result = "right" | "wrong" | "later" | "invalid"

local MAX_QUEUE = 32

local function q(id: string, after: string, icon: string, answers: { string }, correct: number): Question
	return { id = id, after = after, icon = icon, answers = answers, correct = correct }
end

-- One question per quest at most. The right answer is not always in the same place.
local LIST: { Question } = {
	q("power", "m01_home", "power", { "air", "panel", "planet" }, 2),
	q("plants", "m02_food", "greenhouse", { "clock", "close", "greenhouse" }, 3),
	q("dust", "m03_earth", "dust", { "dust", "build", "star" }, 1),
	q("shelter", "m04_storm", "shield", { "power", "calm", "shield" }, 3),
	q("ice", "m05_ice", "ice", { "drop", "cheese", "planet" }, 1),
	q("air", "m06_panels", "air", { "planet", "power", "air" }, 2),
	q("radiation", "m10_storm", "dose", { "calm", "dose", "food" }, 2),
	q("crater", "m11_explore", "meteor", { "meteor", "alert", "build" }, 1),
	q("flare", "m15_repair", "storm", { "storm", "calm", "close" }, 2),
	q("radio", "m18_laser", "antenna", { "clock", "antenna", "hourglass" }, 2),
	q("mars", "m21_mars", "rocket", { "calm", "antenna", "planet" }, 3),
}

local byId: { [string]: Question } = {}
for _, question in LIST do
	table.freeze(question.answers)
	table.freeze(question)
	byId[question.id] = question
end

local Quiz = {}

Quiz.LIST = table.freeze(LIST)

function Quiz.get(id: any): Question?
	return if type(id) == "string" then byId[id] else nil
end

function Quiz.isId(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function Quiz.questionKey(id: string): string
	return "quiz." .. id .. ".q"
end

function Quiz.answerKey(id: string, index: number): string
	return "quiz." .. id .. ".a" .. tostring(index)
end

function Quiz.hintKey(id: string): string
	return "quiz." .. id .. ".hint"
end

function Quiz.whyKey(id: string): string
	return "quiz." .. id .. ".why"
end

-- Questions queued when quest `questId` is done (in LIST order).
function Quiz.forQuest(questId: string): { Question }
	local list: { Question } = {}
	for _, question in LIST do
		if question.after == questId then
			table.insert(list, question)
		end
	end
	return list
end

-- "right" / "wrong" for answer `choice` (1 .. #answers), "later" for choice 0 (the "Not now"
-- button), "invalid" for anything else (unknown id, not a whole number, out of range).
function Quiz.check(id: any, choice: any): Result
	local question = Quiz.get(id)
	if question == nil or type(choice) ~= "number" or choice ~= choice or choice ~= math.floor(choice) then
		return "invalid"
	end
	if choice == 0 then
		return "later"
	end
	if choice < 1 or choice > #question.answers then
		return "invalid"
	end
	return if choice == question.correct then "right" else "wrong"
end

-- Record helpers ------------------------------------------------------------------------------------

function Quiz.emptyRecord(): Record
	return { done = {}, queue = {} }
end

-- Any stored value -> a clean Record (unknown ids dropped, no duplicates, nothing done in the queue).
function Quiz.sanitizeRecord(value: any): Record
	local record = Quiz.emptyRecord()
	if type(value) ~= "table" then
		return record
	end
	if type(value.done) == "table" then
		for id, flag in value.done do
			if flag == true and Quiz.isId(id) then
				record.done[id] = true
			end
		end
	end
	if type(value.queue) == "table" then
		for _, id in value.queue do
			if #record.queue >= MAX_QUEUE then
				break
			end
			if Quiz.isId(id) and not record.done[id] and table.find(record.queue, id) == nil then
				table.insert(record.queue, id)
			end
		end
	end
	return record
end

function Quiz.cloneRecord(record: Record): Record
	return { done = table.clone(record.done), queue = table.clone(record.queue) }
end

-- Stored + this server's record: answered questions stay answered, waiting ones stay waiting
-- (this server's order first).
function Quiz.mergeRecord(stored: any, current: any): Record
	local old = Quiz.sanitizeRecord(stored)
	local now = Quiz.sanitizeRecord(current)
	local merged = Quiz.emptyRecord()
	for _, source in { old.done, now.done } do
		for id in source do
			merged.done[id] = true
		end
	end
	for _, source in { now.queue, old.queue } do
		for _, id in source do
			if not merged.done[id] and table.find(merged.queue, id) == nil and #merged.queue < MAX_QUEUE then
				table.insert(merged.queue, id)
			end
		end
	end
	return merged
end

-- Queues the questions of quest `questId` that are neither answered nor waiting. Returns how many.
function Quiz.queueAfterQuest(record: Record, questId: string): number
	local added = 0
	for _, question in Quiz.forQuest(questId) do
		if not record.done[question.id] and table.find(record.queue, question.id) == nil and #record.queue < MAX_QUEUE then
			table.insert(record.queue, question.id)
			added += 1
		end
	end
	return added
end

-- Applies an answer to a WAITING question: right = answered (leaves the queue); wrong or later = it
-- goes to the back of the queue (asked again later). A question that is not waiting is "invalid".
function Quiz.answer(record: Record, id: any, choice: any): Result
	local position = if type(id) == "string" then table.find(record.queue, id) else nil
	if position == nil then
		return "invalid"
	end
	local result = Quiz.check(id, choice)
	if result == "invalid" then
		return result
	end
	table.remove(record.queue, position)
	if result == "right" then
		record.done[id :: string] = true
	else
		table.insert(record.queue, id :: string)
	end
	return result
end

return table.freeze(Quiz)
