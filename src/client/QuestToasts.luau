--!strict
-- Space Base Odyssey - quest toasts (Stage 10, team playtest): a small card on the right side that
-- says when a quest opens, when a step of it gets done and when a quest is complete.
-- Team feedback: quests sometimes finished before the player had even read them ("you go to do it
-- and it turns out you already did it"), and C.A.R.L.'s generic "quest done" line was easy to miss.
-- The server (QuestService.evaluate) moves the tracker silently, so this module compares successive
-- BaseState.quest values on the client and turns the differences into toasts:
--   * a main quest finished (BaseState.quest.mainCount went up): "Quest complete!" + its title and
--     reward (coin and XP icons, with the skill bonus the server adds). Main quests that opened and
--     finished in the same update (every step was already done) say "Already done!" instead.
--   * a side quest left quest.sides (sides only leave when done): "Quest complete!" too. A side quest
--     that opened and finished in the same update (its main quest just finished) is found through
--     Quests.SIDE (`after`) and says "Already done!".
--   * a new main quest or a new side quest: "New quest!" / "New side quest!" + its icon and title; the
--     steps that are already done are listed in the card with a tick ("Already done: ...").
--   * a step of a quest that stays active got done: a smaller line "Done: <step>".
-- One update queues: step lines, then completed quests, then new quests. One card shows at a time
-- (SHOW_SECONDS, sliding in from the right); the queue keeps QUEUE_CAP toasts and drops step lines
-- first. The queue waits while any full-screen panel is open (HOLD_PANELS: start menu, mission
-- select, Lab, settings, wardrobe...). Right after a save slot loads nothing toasts (the quest in progress is not new): after a
-- short settle time one card shows "Your quest right now". The memory resets when the slot changes
-- (player attributes SBO_Slot, SBO_SlotChosen, SBO_SlotLoading). No sound: the project has no UI
-- sound helper.
-- Placement: right side, x 0.78-0.985, from y 0.28 down (at most y 0.47): under the top-right buttons
-- and the wardrobe square (y <= 0.27 in every mode), right of the storm countdown (x <= 0.78) and the
-- C.A.R.L. bubble (x 0.29-0.71), far from the left column (x < 0.21) and the bottom tool bar. Z index
-- 45: over the HUD, under the C.A.R.L. bubble (50) and the full-screen panels (55+).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseBuild = require(Shared:WaitForChild("BaseBuild"))
local MissionData = require(Shared:WaitForChild("MissionData"))
local Quests = require(Shared:WaitForChild("Quests"))
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE

-- Technical UI settings (not gameplay numbers). Sizes are fractions of the screen.
local CARD_RIGHT = 0.985 -- right edge (anchor 1, 0)
local CARD_TOP = 0.28
local CARD_WIDTH = 0.205
local PAD = 0.008
local HEADER_HEIGHT = 0.03
local TITLE_HEIGHT = 0.042
local REWARD_HEIGHT = 0.04
local TICK_HEIGHT = 0.03
local STEP_HEIGHT = 0.042 -- the one line of a step toast
local MAX_TICKS = 2 -- steps already done listed in a new-quest card
local ICON_COLUMN = 0.2 -- share of the card width for the big icon
local TEXT_X = 0.22
local ZINDEX = 45
local SHOW_SECONDS = 3.5
local STEP_SECONDS = 2.5
local HURRY_FACTOR = 0.7 -- shorter cards while two or more wait
local SLIDE_SECONDS = 0.3
local GAP_SECONDS = 0.15
local QUEUE_CAP = 5
local SETTLE_SECONDS = 2.5 -- after a slot loads, updates only refresh the memory for this long
local POLL_SECONDS = 0.1
local BASE_STATE_WAIT_SECONDS = 60
-- Full-screen panels (frame names under the root) that hold the queue while they are open. Same list
-- as Main.client.luau's MODAL_PANELS: every one is a dimmed full-screen modal (Ui.modal, z 55+) that
-- would hide a toast (e.g. a skill step done inside the Lab panel), so the toast waits instead.
local HOLD_PANELS = {
	"StartMenu", "MissionSelect", "Report", "PowerBoard", "Settings", "Sources", "Collection", "FindCard",
	"BasePanel", "Wardrobe", "ExploreCard",
}
-- On touch-only screens the Run button starts at y 0.43 under the card: new-quest cards list no ticked
-- steps there, so the tallest card (header, title, reward) ends at about y 0.40.
local MAX_TICKS_TOUCH = 0
local SLOT_ATTRIBUTE = "SBO_Slot"
local SLOT_LOADING_ATTRIBUTE = "SBO_SlotLoading"

local QuestToasts = {}

type Reward = { credits: number, xp: number }
type StepSnap = { key: string, target: number, done: boolean }
type QuestSnap = {
	id: string,
	kind: string, -- "main" | "side"
	icon: string,
	steps: { StepSnap },
	reward: Reward,
}
-- One BaseState.quest, reduced to what the diff needs.
type StateSnap = {
	main: QuestSnap?, -- the active main quest (nil once the main line is done)
	mainCount: number, -- main quests done
	sides: { [string]: QuestSnap },
	sideOrder: { string },
}
type Tick = { key: string, n: number }
type Toast = {
	kind: "quest" | "step",
	header: string, -- localization key ("" = none)
	color: Color3,
	questId: string?,
	titleKey: string?,
	stepText: Tick?, -- step toasts
	icon: string,
	iconColor: Color3,
	reward: Reward?,
	ticks: { Tick },
	seconds: number,
}

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

-- Reading BaseState.quest -------------------------------------------------------------------------

local function parseView(raw: any): QuestSnap?
	if type(raw) ~= "table" or type(raw.id) ~= "string" or raw.id == "" then
		return nil
	end
	local def = Quests.byId(raw.id)
	local steps: { StepSnap } = {}
	if type(raw.steps) == "table" then
		for index = 1, #raw.steps do
			local step = raw.steps[index]
			if type(step) == "table" then
				table.insert(steps, {
					key = if type(step.key) == "string" then step.key else Quests.stepKey(raw.id, index),
					target = math.max(1, math.floor(numberOr(step.target, 1))),
					done = step.done == true,
				})
			end
		end
	end
	local rawReward: any = raw.reward
	local reward: Reward = if type(rawReward) == "table"
		then { credits = numberOr(rawReward.credits, 0), xp = numberOr(rawReward.xp, 0) }
		elseif def then { credits = def.reward.credits, xp = def.reward.xp }
		else { credits = 0, xp = 0 }
	return {
		id = raw.id,
		kind = if raw.kind == "side" or raw.kind == "main" then raw.kind elseif def then def.kind else "main",
		icon = if type(raw.icon) == "string" then raw.icon elseif def then def.icon else "target",
		steps = steps,
		reward = reward,
	}
end

local function parseState(raw: any): StateSnap?
	if type(raw) ~= "table" then
		return nil
	end
	local mainDone = raw.mainDone == true
	local view = parseView(raw)
	local main = if view and view.kind == "main" and not mainDone then view else nil
	local mainCount: number
	if type(raw.mainCount) == "number" then
		mainCount = math.floor(raw.mainCount)
	elseif main then
		mainCount = (Quests.mainIndex(main.id) or 1) - 1
	elseif mainDone then
		mainCount = #Quests.MAIN
	else
		mainCount = 0
	end
	local sides: { [string]: QuestSnap } = {}
	local sideOrder: { string } = {}
	if type(raw.sides) == "table" then
		for index = 1, #raw.sides do
			local side = parseView(raw.sides[index])
			if side and sides[side.id] == nil then
				side.kind = "side"
				sides[side.id] = side
				table.insert(sideOrder, side.id)
			end
		end
	end
	if main == nil and view == nil and mainCount == 0 and #sideOrder == 0 then
		return nil -- an empty or broken quest table
	end
	return { main = main, mainCount = mainCount, sides = sides, sideOrder = sideOrder }
end

-- The reward the server pays: the quest reward plus the "credits" / "xp" skill bonus (as
-- BaseService.grantCredits adds it).
local function paidReward(reward: Reward): Reward
	local base: any = Store.getBase()
	local skills: any = if type(base) == "table" then base.skills else nil
	local credits = math.max(0, math.floor(reward.credits))
	local xp = math.max(0, math.floor(reward.xp))
	return {
		credits = credits + BaseBuild.bonusAmount(MissionData, credits, BaseBuild.levelOf(skills, "credits")),
		xp = xp + BaseBuild.bonusAmount(MissionData, xp, BaseBuild.levelOf(skills, "xp")),
	}
end

-- The card ----------------------------------------------------------------------------------------

type Card = {
	frame: Frame,
	stroke: UIStroke?,
	icon: ImageLabel,
	header: TextLabel,
	title: TextLabel,
	reward: Frame,
	coinText: TextLabel,
	xpText: TextLabel,
	ticks: { { frame: Frame, text: TextLabel } },
}

local function buildCard(root: Frame): Card
	local frame = Ui.panel(root, {
		name = "QuestToast",
		size = UDim2.fromScale(CARD_WIDTH, 0.08),
		position = UDim2.fromScale(CARD_RIGHT, CARD_TOP),
		anchor = Vector2.new(1, 0),
		transparency = 0.06,
		corner = 0.14,
		zindex = ZINDEX,
		visible = false,
	})
	local icon = Ui.icon(frame, Ui.ICONS.star, {
		name = "Icon",
		size = UDim2.fromScale(ICON_COLUMN - 0.04, 0.6),
		position = UDim2.fromScale(0.03, 0.1),
		zindex = ZINDEX + 1,
	})
	local header = Ui.label(frame, {
		name = "Header",
		size = UDim2.fromScale(0.75, 0.3),
		position = UDim2.fromScale(TEXT_X, 0.1),
		alignX = Enum.TextXAlignment.Left,
		maxText = 22,
		zindex = ZINDEX + 1,
	})
	Ui.oneLine(header)
	local title = Ui.label(frame, {
		name = "Title",
		size = UDim2.fromScale(0.75, 0.4),
		position = UDim2.fromScale(TEXT_X, 0.4),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.text,
		font = Ui.BODY_FONT,
		maxText = 28,
		zindex = ZINDEX + 1,
	})
	Ui.oneLine(title)

	local reward = Ui.frame(frame, { name = "Reward", zindex = ZINDEX + 1, visible = false })
	Ui.icon(reward, Ui.Icons.coin, {
		name = "Coin",
		size = UDim2.fromScale(0.1, 0.9),
		position = UDim2.fromScale(TEXT_X, 0.05),
		tint = ROLE.star,
		zindex = ZINDEX + 1,
	})
	local coinText = Ui.label(reward, {
		name = "Credits",
		size = UDim2.fromScale(0.26, 0.9),
		position = UDim2.fromScale(TEXT_X + 0.11, 0.05),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 22,
		zindex = ZINDEX + 1,
	})
	Ui.oneLine(coinText)
	Ui.icon(reward, Ui.Icons.xp, {
		name = "Xp",
		size = UDim2.fromScale(0.1, 0.9),
		position = UDim2.fromScale(TEXT_X + 0.39, 0.05),
		tint = ROLE.accent,
		zindex = ZINDEX + 1,
	})
	local xpText = Ui.label(reward, {
		name = "XpText",
		size = UDim2.fromScale(0.26, 0.9),
		position = UDim2.fromScale(TEXT_X + 0.5, 0.05),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 22,
		zindex = ZINDEX + 1,
	})
	Ui.oneLine(xpText)

	local ticks: { { frame: Frame, text: TextLabel } } = {}
	for index = 1, MAX_TICKS do
		local row = Ui.frame(frame, { name = `Tick{index}`, zindex = ZINDEX + 1, visible = false })
		Ui.icon(row, Ui.ICONS.check, {
			name = "Check",
			size = UDim2.fromScale(0.09, 0.85),
			position = UDim2.fromScale(0.05, 0.075),
			tint = ROLE.good,
			zindex = ZINDEX + 1,
		})
		local text = Ui.label(row, {
			name = "Text",
			size = UDim2.fromScale(0.8, 0.85),
			position = UDim2.fromScale(0.16, 0.075),
			alignX = Enum.TextXAlignment.Left,
			textColor = ROLE.good,
			font = Ui.BODY_FONT,
			maxText = 20,
			zindex = ZINDEX + 1,
		})
		Ui.oneLine(text)
		table.insert(ticks, { frame = row, text = text })
	end

	return {
		frame = frame,
		stroke = frame:FindFirstChildOfClass("UIStroke"),
		icon = icon,
		header = header,
		title = title,
		reward = reward,
		coinText = coinText,
		xpText = xpText,
		ticks = ticks,
	}
end

-- Fills the card for one toast and sizes it (children are fractions of the card height).
local function layoutCard(card: Card, toast: Toast)
	local frame = card.frame
	if card.stroke then
		card.stroke.Color = toast.color
	end
	card.icon.Image = toast.icon
	card.icon.ImageColor3 = toast.iconColor

	if toast.kind == "step" then
		local height = PAD * 2 + STEP_HEIGHT
		frame.Size = UDim2.fromScale(CARD_WIDTH, height)
		card.header.Visible = false
		card.reward.Visible = false
		for _, tick in card.ticks do
			tick.frame.Visible = false
		end
		card.icon.Size = UDim2.fromScale(ICON_COLUMN - 0.06, STEP_HEIGHT / height)
		card.icon.Position = UDim2.fromScale(0.04, PAD / height)
		local step = toast.stepText
		local stepText = if step then Store.t(step.key, { n = step.n }) else ""
		card.title.Text = Store.t("ui.toast.step_done", { step = stepText })
		card.title.TextColor3 = ROLE.good
		card.title.Size = UDim2.fromScale(0.75, STEP_HEIGHT / height)
		card.title.Position = UDim2.fromScale(TEXT_X, PAD / height)
		return
	end

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local tickCount = math.min(#toast.ticks, if touchOnly then MAX_TICKS_TOUCH else MAX_TICKS)
	local rewardHeight = if toast.reward then REWARD_HEIGHT else 0
	local height = PAD * 2 + HEADER_HEIGHT + TITLE_HEIGHT + rewardHeight + TICK_HEIGHT * tickCount
	frame.Size = UDim2.fromScale(CARD_WIDTH, height)

	local iconHeight = HEADER_HEIGHT + TITLE_HEIGHT
	card.icon.Size = UDim2.fromScale(ICON_COLUMN - 0.04, iconHeight / height)
	card.icon.Position = UDim2.fromScale(0.03, PAD / height)

	card.header.Visible = toast.header ~= ""
	card.header.Text = if toast.header ~= "" then Store.t(toast.header) else ""
	card.header.TextColor3 = toast.color
	card.header.Size = UDim2.fromScale(0.75, HEADER_HEIGHT / height)
	card.header.Position = UDim2.fromScale(TEXT_X, PAD / height)

	card.title.Text = if toast.titleKey then Store.t(toast.titleKey) else ""
	card.title.TextColor3 = ROLE.text
	card.title.Size = UDim2.fromScale(0.75, TITLE_HEIGHT / height)
	card.title.Position = UDim2.fromScale(TEXT_X, (PAD + HEADER_HEIGHT) / height)

	local reward = toast.reward
	card.reward.Visible = reward ~= nil
	if reward then
		card.coinText.Text = `+{reward.credits}`
		card.xpText.Text = `+{reward.xp}`
		card.reward.Size = UDim2.fromScale(1, REWARD_HEIGHT / height)
		card.reward.Position = UDim2.fromScale(0, (PAD + iconHeight) / height)
	end

	local tickTop = PAD + iconHeight + rewardHeight
	for index, tick in card.ticks do
		local entry = toast.ticks[index]
		tick.frame.Visible = index <= tickCount and entry ~= nil
		if entry and index <= tickCount then
			local stepText = Store.t(entry.key, { n = entry.n })
			tick.text.Text = Store.t("ui.toast.step_already", { step = stepText })
			tick.frame.Size = UDim2.fromScale(1, TICK_HEIGHT / height)
			tick.frame.Position = UDim2.fromScale(0, (tickTop + TICK_HEIGHT * (index - 1)) / height)
		end
	end
end

-- The toast logic ---------------------------------------------------------------------------------

local started = false

function QuestToasts.start(root: Frame)
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local card = buildCard(root)
	local shownPosition = UDim2.fromScale(CARD_RIGHT, CARD_TOP)
	local hiddenPosition = UDim2.fromScale(CARD_RIGHT + CARD_WIDTH + 0.03, CARD_TOP)

	local queue: { Toast } = {}
	local running = false
	local generation = 0 -- goes up on every reset: older loops and timers stop
	local previous: StateSnap? = nil
	local latestRaw: any = nil -- the last BaseState.quest received (also before a slot is chosen)
	local settleUntil = 0
	local toastedNew: { [string]: boolean } = {}
	local toastedDone: { [string]: boolean } = {}
	local toastedStep: { [string]: boolean } = {}

	local function held(): boolean
		if not Store.isSlotChosen() then
			return true
		end
		for _, name in HOLD_PANELS do
			local panel = root:FindFirstChild(name)
			if panel and panel:IsA("GuiObject") and panel.Visible then
				return true
			end
		end
		return false
	end

	local function show(toast: Toast, token: number)
		layoutCard(card, toast)
		card.frame.Position = hiddenPosition
		card.frame.Visible = true
		TweenService:Create(card.frame, TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = shownPosition,
		}):Play()
		local seconds = toast.seconds * (if #queue >= 2 then HURRY_FACTOR else 1)
		local elapsed = 0
		while elapsed < seconds and token == generation do
			local dt = task.wait(POLL_SECONDS)
			-- A panel opened on top: hide the card and pause its timer.
			if held() then
				card.frame.Visible = false
			else
				card.frame.Visible = true
				elapsed += dt
			end
		end
		if token ~= generation then
			return
		end
		local out = TweenService:Create(card.frame, TweenInfo.new(SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = hiddenPosition,
		})
		out:Play()
		task.wait(SLIDE_SECONDS)
		if token == generation then
			card.frame.Visible = false
			task.wait(GAP_SECONDS)
		end
	end

	local function runQueue()
		if running then
			return
		end
		running = true
		task.spawn(function()
			while #queue > 0 do
				local token = generation
				while held() and token == generation do
					task.wait(POLL_SECONDS)
				end
				if token ~= generation then
					continue -- reset: the queue was cleared
				end
				local toast = table.remove(queue, 1)
				if toast then
					-- pcall: one broken toast never stops the queue.
					local ok, err = pcall(show, toast, token)
					if not ok then
						card.frame.Visible = false
						warn(`[SpaceBaseOdyssey] quest toast failed: {err}`)
					end
				end
			end
			running = false
		end)
	end

	local function push(toast: Toast)
		table.insert(queue, toast)
		while #queue > QUEUE_CAP do
			local dropAt = 1
			for index, queued in queue do
				if queued.kind == "step" then
					dropAt = index
					break
				end
			end
			table.remove(queue, dropAt)
		end
		runQueue()
	end

	local function doneTicks(quest: QuestSnap): { Tick }
		local ticks: { Tick } = {}
		for _, step in quest.steps do
			if step.done then
				toastedStep[step.key] = true
				table.insert(ticks, { key = step.key, n = step.target })
			end
		end
		return ticks
	end

	local function questToast(header: string, quest: QuestSnap, reward: Reward?, ticks: { Tick }): Toast
		local side = quest.kind == "side"
		local done = reward ~= nil
		local color = if done then ROLE.good elseif side then ROLE.reward else ROLE.star
		return {
			kind = "quest",
			header = header,
			color = color,
			questId = quest.id,
			titleKey = Quests.titleKey(quest.id),
			stepText = nil,
			icon = if done then Ui.ICONS.trophy else Ui.iconImage(quest.icon),
			iconColor = if done then ROLE.star elseif side then ROLE.reward else ROLE.star,
			reward = reward,
			ticks = ticks,
			seconds = SHOW_SECONDS,
		}
	end

	-- A quest from Quests.luau (opened and finished between two updates).
	local function snapOf(def: Quests.Quest): QuestSnap
		return {
			id = def.id,
			kind = def.kind,
			icon = def.icon,
			steps = {},
			reward = { credits = def.reward.credits, xp = def.reward.xp },
		}
	end

	local function completed(quest: QuestSnap, already: boolean)
		if toastedDone[quest.id] then
			return
		end
		toastedDone[quest.id] = true
		toastedNew[quest.id] = true
		-- Its pending "new quest" card is old news now.
		for index = #queue, 1, -1 do
			local queued = queue[index]
			if queued.questId == quest.id then
				table.remove(queue, index)
			end
		end
		local header = if already then "ui.toast.quest_already" else "ui.toast.quest_done"
		push(questToast(header, quest, paidReward(quest.reward), {}))
	end

	local function opened(quest: QuestSnap)
		if toastedNew[quest.id] or toastedDone[quest.id] then
			return
		end
		toastedNew[quest.id] = true
		local header = if quest.kind == "side" then "ui.toast.side_new" else "ui.toast.quest_new"
		push(questToast(header, quest, nil, doneTicks(quest)))
	end

	-- Steps that got done in a quest that is still active (same id before and after).
	local function stepsTicked(before: QuestSnap, after: QuestSnap)
		for index, step in after.steps do
			local old = before.steps[index]
			if step.done and old and not old.done and not toastedStep[step.key] then
				toastedStep[step.key] = true
				local tick: Tick = { key = step.key, n = step.target }
				-- Its "new quest" card still waits: tick the step there instead.
				local merged = false
				for _, queued in queue do
					if queued.kind == "quest" and queued.questId == after.id and queued.reward == nil then
						table.insert(queued.ticks, tick)
						merged = true
						break
					end
				end
				if not merged then
					push({
						kind = "step",
						header = "",
						color = ROLE.good,
						questId = after.id,
						titleKey = nil,
						stepText = tick,
						icon = Ui.ICONS.check,
						iconColor = ROLE.good,
						reward = nil,
						ticks = {},
						seconds = STEP_SECONDS,
					})
				end
			end
		end
	end

	-- Everything already on screen when a slot loads counts as seen.
	local function remember(state: StateSnap)
		local function seen(quest: QuestSnap)
			toastedNew[quest.id] = true
			for _, step in quest.steps do
				if step.done then
					toastedStep[step.key] = true
				end
			end
		end
		if state.main then
			seen(state.main)
		end
		for _, id in state.sideOrder do
			seen(state.sides[id])
		end
	end

	local function diff(before: StateSnap, after: StateSnap)
		-- 1. Steps of quests that stay active.
		local beforeMain, afterMain = before.main, after.main
		if beforeMain and afterMain and beforeMain.id == afterMain.id then
			stepsTicked(beforeMain, afterMain)
		end
		for _, id in after.sideOrder do
			local old = before.sides[id]
			if old then
				stepsTicked(old, after.sides[id])
			end
		end
		-- 2. Completed main quests, in line order (and the side quests they opened and finished).
		local finishedMain: { [string]: boolean } = {}
		for index = before.mainCount + 1, math.min(after.mainCount, #Quests.MAIN) do
			local def = Quests.MAIN[index]
			finishedMain[def.id] = true
			if beforeMain and beforeMain.id == def.id then
				completed(beforeMain, false)
			else
				completed(snapOf(def), true)
			end
		end
		-- 3. Completed side quests: they left the list.
		for _, id in before.sideOrder do
			if after.sides[id] == nil then
				completed(before.sides[id], false)
			end
		end
		for _, def in Quests.SIDE do
			if def.after and finishedMain[def.after] and before.sides[def.id] == nil and after.sides[def.id] == nil then
				completed(snapOf(def), true)
			end
		end
		-- 4. New quests.
		if afterMain and (beforeMain == nil or beforeMain.id ~= afterMain.id) then
			opened(afterMain)
		end
		for _, id in after.sideOrder do
			if before.sides[id] == nil then
				opened(after.sides[id])
			end
		end
	end

	local function reset()
		generation += 1
		table.clear(queue)
		previous = nil
		settleUntil = 0
		table.clear(toastedNew)
		table.clear(toastedDone)
		table.clear(toastedStep)
		card.frame.Visible = false
	end

	-- After a slot loads: one card with the quest in progress (once the memory has settled).
	local function showCurrentLater()
		local token = generation
		task.delay(SETTLE_SECONDS, function()
			local state = previous
			if token ~= generation or state == nil then
				return
			end
			local quest = state.main
			if quest == nil and state.sideOrder[1] then
				quest = state.sides[state.sideOrder[1]]
			end
			if quest then
				local toast = questToast("ui.toast.current", quest, nil, {})
				toast.color = ROLE.accent
				push(toast)
			end
		end)
	end

	local function baseline(state: StateSnap)
		previous = state
		settleUntil = os.clock() + SETTLE_SECONDS
		remember(state)
		showCurrentLater()
	end

	local function onQuest(raw: any)
		latestRaw = raw
		if not Store.isSlotChosen() then
			return
		end
		local state = parseState(raw)
		if state == nil then
			return
		end
		local before = previous
		if before == nil then
			baseline(state)
			return
		end
		-- Fewer main quests done than before: another save (or a debug reset). Start over quietly.
		if state.mainCount < before.mainCount then
			reset()
			baseline(state)
			return
		end
		if os.clock() < settleUntil then
			previous = state
			remember(state)
			return
		end
		diff(before, state)
		previous = state
	end

	-- Save slots: a new slot (or the start menu again) forgets everything.
	local function onSlotChanged()
		reset()
		if Store.isSlotChosen() and player:GetAttribute(SLOT_LOADING_ATTRIBUTE) ~= true then
			onQuest(latestRaw)
		end
	end
	player:GetAttributeChangedSignal(Store.SLOT_CHOSEN_ATTRIBUTE):Connect(onSlotChanged)
	player:GetAttributeChangedSignal(SLOT_ATTRIBUTE):Connect(onSlotChanged)
	player:GetAttributeChangedSignal(SLOT_LOADING_ATTRIBUTE):Connect(function()
		if player:GetAttribute(SLOT_LOADING_ATTRIBUTE) == true then
			reset()
			latestRaw = nil
		end
	end)

	-- The quest arrives in the BaseState (Store.setBase does not keep sides or rewards): listen to
	-- the remote too, like Objectives.luau does. It only reads.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
		local name: string = (Types.Remotes :: any).BASE_STATE or "BaseState"
		local remote = remotes:WaitForChild(name, BASE_STATE_WAIT_SECONDS)
		if remote == nil or not remote:IsA("RemoteEvent") then
			return -- older server: no quests
		end
		(remote :: RemoteEvent).OnClientEvent:Connect(function(state: any)
			if type(state) == "table" and type(state.credits) == "number" and state.quest ~= nil then
				onQuest(state.quest)
			end
		end)
	end)
end

return QuestToasts
