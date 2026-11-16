--!strict
-- Space Base Odyssey - "C.A.R.L. asks" question card (Stage 11 "quests that teach", client side of
-- src/shared/Quiz.luau and QuestService). After some quests the server offers one short picture
-- question in BaseState.quest.quiz = { id, questionKey, icon, answers = { { key, icon } }, xp } (the
-- right answer is never sent). This card shows it in base mode only (between missions, mission select
-- closed, no full-screen panel open, start menu closed):
--   * the question with its picture, then 2-3 big answer buttons (an icon plus a few words; tall
--     enough for a finger), a "Not now" button and a close button;
--   * an answer sends Types.Action { type = "AnswerQuiz", id, choice = 1..#answers }; "Not now" and
--     the close button send choice 0 (the server asks again later, nothing is lost);
--   * the server's BaseState.quest.quizResult = { id, right, xp, lineKey } then turns the card into:
--     right -> lime border, a pop, stars, a "+XP" that floats up, "Right! +{xp} XP" and the "why" line;
--     wrong -> the hint line and "Good try! I will ask again later." (never a penalty).
-- It never blocks play: it is not a modal (the world keeps working behind it), it hides while a panel
-- or a mission is up and comes back after, and the kid can always close it.
-- Placement: centre of the screen, under the C.A.R.L. bubble (y 0.19-0.285 in base mode) and above
-- the bottom pills; taller on small (touch) screens so each answer is a big target. Z index 46: over
-- the HUD and the quest toasts' layer, under the C.A.R.L. bubble (50) and every panel (53+).
-- Main.client starts it with QuizCard.start(root) (pcall: a broken card never breaks the client).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Reading = require(Shared:WaitForChild("Reading"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local ROLE = Ui.ROLE

-- Technical UI settings (not gameplay numbers). Sizes are fractions of the screen.
local Z = 46
local CARD_ASPECT = 1.45 -- width / height
local CARD_HEIGHT = 0.44
local CARD_Y = 0.52 -- centre
local CARD_HEIGHT_SMALL = 0.6 -- small screens (root UIScale under SMALL_SCALE): bigger buttons
local CARD_Y_SMALL = 0.59
local SMALL_SCALE = 0.75
local MAX_ANSWERS = 3
local ANSWER_TOP = 0.34 -- fractions of the card
local ANSWER_HEIGHT = 0.155
local ANSWER_GAP = 0.012
local CHECK_SECONDS = 0.25
local RESULT_WAIT_SECONDS = 6 -- no result from the server by then: close (it asks again later)
local RESULT_MIN_SECONDS = 6
local POP_SECONDS = 0.35
local XP_FLOAT_SECONDS = 1.4
local STAR_COUNT = 6
local STAR_SECONDS = 0.9
local BASE_STATE_WAIT_SECONDS = 60
-- Full-screen panels (root children) that hide the card while open (same list as QuestToasts).
local HIDE_PANELS = {
	"StartMenu", "MissionSelect", "Report", "PowerBoard", "Settings", "Sources", "Collection", "FindCard",
	"BasePanel", "Wardrobe", "ExploreCard", "Achievements", "CarlHistory", "GlossaryCard",
	"AwayCard", "DailyCard", -- Stage 11 tycoon and daily cards (IncomePops.luau, DailyCapsule.luau)
}

local QuizCard = {}

type Answer = { key: string, icon: string }
type Prompt = { id: string, questionKey: string, icon: string, answers: { Answer }, xp: number }
type Result = { id: string, right: boolean, xp: number, lineKey: string }

local function parsePrompt(raw: any): Prompt?
	if type(raw) ~= "table" or type(raw.id) ~= "string" or raw.id == "" or type(raw.questionKey) ~= "string" then
		return nil
	end
	local answers: { Answer } = {}
	if type(raw.answers) == "table" then
		for index = 1, math.min(#raw.answers, MAX_ANSWERS) do
			local answer = raw.answers[index]
			if type(answer) == "table" and type(answer.key) == "string" then
				table.insert(answers, { key = answer.key, icon = if type(answer.icon) == "string" then answer.icon else "star" })
			end
		end
	end
	if #answers < 2 then
		return nil
	end
	return {
		id = raw.id,
		questionKey = raw.questionKey,
		icon = if type(raw.icon) == "string" then raw.icon else "star",
		answers = answers,
		xp = if type(raw.xp) == "number" then raw.xp else 0,
	}
end

local function parseResult(raw: any): Result?
	if type(raw) ~= "table" or type(raw.id) ~= "string" or type(raw.lineKey) ~= "string" then
		return nil
	end
	return {
		id = raw.id,
		right = raw.right == true,
		xp = if type(raw.xp) == "number" then math.max(0, math.floor(raw.xp)) else 0,
		lineKey = raw.lineKey,
	}
end

local started = false

function QuizCard.start(root: Frame)
	if started then
		return
	end
	started = true

	local card = Ui.panel(root, {
		name = "QuizCard",
		size = UDim2.fromScale(0.5, CARD_HEIGHT),
		position = UDim2.fromScale(0.5, CARD_Y),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		transparency = 0.04,
		corner = 0.07,
		stroke = 4,
		strokeColor = ROLE.accent,
		aspect = CARD_ASPECT,
		zindex = Z,
		visible = false,
	})
	card.Active = true -- taps on the card do not reach the world behind it
	Ui.sheen(card)
	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	-- Header: C.A.R.L. and "C.A.R.L. asks", close button.
	Ui.icon(card, Ui.ICONS.robot, {
		name = "Robot",
		size = UDim2.fromScale(0.08, 0.1),
		position = UDim2.fromScale(0.035, 0.075),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.accent,
		zindex = Z + 1,
	})
	local header = Ui.label(card, {
		name = "Header",
		size = UDim2.fromScale(0.6, 0.1),
		position = UDim2.fromScale(0.12, 0.075),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		maxText = 30,
		zindex = Z + 1,
	})
	Ui.oneLine(header)

	-- Question: its picture in a gold circle, then the words.
	local questionBadge = Ui.frame(card, {
		name = "QuestionBadge",
		size = UDim2.fromScale(0.14, 0.17),
		position = UDim2.fromScale(0.04, 0.23),
		anchor = Vector2.new(0, 0.5),
		color = ROLE.star,
		corner = 0.5,
		aspect = 1,
		zindex = Z + 1,
	})
	local questionIcon = Ui.icon(questionBadge, Ui.ICONS.star, {
		name = "Icon",
		size = UDim2.fromScale(0.66, 0.66),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.primaryButtonText,
		zindex = Z + 2,
	})
	local question = Ui.body(card, {
		name = "Question",
		size = UDim2.fromScale(0.74, 0.18),
		position = UDim2.fromScale(0.2, 0.23),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.text,
		font = Ui.FONT,
		maxText = 30,
		minText = 15,
		zindex = Z + 1,
	})

	-- Answer buttons (filled per question).
	local chooseAnswer: (choice: number) -> () = function() end
	local answerButtons: { TextButton } = {}
	for index = 1, MAX_ANSWERS do
		local button = Ui.button(card, {
			name = `Answer{index}`,
			size = UDim2.fromScale(0.9, ANSWER_HEIGHT),
			position = UDim2.fromScale(0.5, ANSWER_TOP + (ANSWER_HEIGHT + ANSWER_GAP) * (index - 1)),
			anchor = Vector2.new(0.5, 0),
			color = ROLE.panelRaised,
			stroke = 2,
			strokeColor = ROLE.accent,
			tint = ROLE.star,
			corner = 0.3,
			maxText = 26,
			minText = 14,
			zindex = Z + 1,
			visible = false,
		}, function()
			chooseAnswer(index)
		end)
		table.insert(answerButtons, button)
	end

	local laterButton = Ui.button(card, {
		name = "NotNow",
		size = UDim2.fromScale(0.36, 0.11),
		position = UDim2.fromScale(0.5, 0.965),
		anchor = Vector2.new(0.5, 1),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.hourglass,
		maxText = 22,
		minText = 13,
		zindex = Z + 1,
	}, function()
		chooseAnswer(0)
	end)

	-- Result view (replaces the answers).
	local result = Ui.frame(card, {
		name = "Result",
		size = UDim2.fromScale(1, 0.62),
		position = UDim2.fromScale(0, 0.34),
		zindex = Z + 1,
		visible = false,
	})
	local resultIcon = Ui.icon(result, Ui.ICONS.check, {
		name = "Icon",
		size = UDim2.fromScale(0.2, 0.42),
		position = UDim2.fromScale(0.05, 0.05),
		aspect = 1,
		tint = ROLE.good,
		zindex = Z + 2,
	})
	local resultTitle = Ui.label(result, {
		name = "Title",
		size = UDim2.fromScale(0.68, 0.24),
		position = UDim2.fromScale(0.28, 0.06),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.good,
		maxText = 32,
		minText = 15,
		zindex = Z + 2,
	})
	local resultLine = Ui.body(result, {
		name = "Line",
		size = UDim2.fromScale(0.68, 0.44),
		position = UDim2.fromScale(0.28, 0.32),
		textColor = ROLE.text,
		alignY = Enum.TextYAlignment.Top,
		maxText = 26,
		minText = 15,
		zindex = Z + 2,
	})
	-- "+XP" that floats up from the result icon.
	local xpPop = Ui.frame(card, {
		name = "XpPop",
		size = UDim2.fromScale(0.3, 0.12),
		position = UDim2.fromScale(0.16, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		zindex = Z + 4,
		visible = false,
	})
	local xpIcon = Ui.icon(xpPop, Ui.Icons.xp, {
		name = "Icon",
		size = UDim2.fromScale(0.3, 1),
		position = UDim2.fromScale(0, 0),
		aspect = 1,
		tint = ROLE.accent,
		zindex = Z + 4,
	})
	local xpText = Ui.label(xpPop, {
		name = "Text",
		size = UDim2.fromScale(0.68, 1),
		position = UDim2.fromScale(0.32, 0),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.accent,
		outline = true,
		maxText = 34,
		zindex = Z + 4,
	})
	local stars: { ImageLabel } = {}
	for index = 1, STAR_COUNT do
		table.insert(stars, Ui.icon(card, Ui.ICONS.star, {
			name = `Star{index}`,
			size = UDim2.fromScale(0.07, 0.1),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			aspect = 1,
			tint = ROLE.star,
			zindex = Z + 4,
			visible = false,
		}))
	end

	Ui.button(card, {
		name = "Close",
		size = UDim2.fromScale(0.09, 0.12),
		position = UDim2.fromScale(0.975, 0.025),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 2,
	}, function()
		chooseAnswer(0)
	end)

	-- State --------------------------------------------------------------------------------------------
	local prompt: Prompt? = nil -- the question the server offers now
	local latestResult: Result? = nil
	local shownId: string? = nil -- the question laid out on the card
	local closedId: string? = nil -- answered or put away here: do not show it again until it changes
	local waiting: { id: string, choice: number, at: number }? = nil
	local showingResult: { id: string, untilAt: number }? = nil

	local function allowed(): boolean
		if not Store.isSlotChosen() or Store.phase() ~= "Briefing" or not Store.isBaseMode() then
			return false
		end
		for _, name in HIDE_PANELS do
			local panel = root:FindFirstChild(name)
			if panel and panel:IsA("GuiObject") and panel.Visible then
				return false
			end
		end
		return true
	end

	local function small(): boolean
		return Ui.scale() < SMALL_SCALE
	end

	local function placeCard()
		if small() then
			card.Size = UDim2.fromScale(0.7, CARD_HEIGHT_SMALL)
			card.Position = UDim2.fromScale(0.5, CARD_Y_SMALL)
		else
			card.Size = UDim2.fromScale(0.5, CARD_HEIGHT)
			card.Position = UDim2.fromScale(0.5, CARD_Y)
		end
	end

	local function setAnswersEnabled(enabled: boolean, chosen: number?)
		for index, button in answerButtons do
			Ui.setButtonLook(button, enabled or index == chosen, ROLE.panelRaised)
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if index == chosen then ROLE.star else ROLE.accent
				stroke.Thickness = if index == chosen then Ui.STROKE * 2 else 2
			end
		end
		Ui.setButtonLook(laterButton, enabled, Ui.COLORS.secondary)
	end

	-- Fills the question view (texts follow the current language).
	local function renderQuestion()
		local current = prompt
		header.Text = Store.t("ui.quiz.title")
		if current == nil then
			return
		end
		questionIcon.Image = Ui.iconImage(current.icon)
		question.Text = Store.t(current.questionKey)
		for index, button in answerButtons do
			local answer = current.answers[index]
			button.Visible = answer ~= nil
			if answer then
				Ui.setButton(button, Store.t(answer.key), Ui.iconImage(answer.icon))
			end
		end
		Ui.setButton(laterButton, Store.t("ui.quiz.later"))
	end

	local function showQuestionView()
		result.Visible = false
		xpPop.Visible = false
		laterButton.Visible = true
		if cardStroke then
			cardStroke.Color = ROLE.accent
		end
		setAnswersEnabled(true, nil)
		renderQuestion()
	end

	local function popIn()
		cardScale.Scale = 0.85
		TweenService:Create(cardScale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	local function celebrate(xp: number)
		popIn()
		for index, star in stars do
			local angle = (index - 1) / #stars * math.pi * 2 + 0.4
			star.Visible = true
			star.ImageTransparency = 0
			star.Rotation = 0
			star.Position = UDim2.fromScale(0.16, 0.5)
			TweenService:Create(star, TweenInfo.new(STAR_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.16 + math.cos(angle) * 0.2, 0.5 + math.sin(angle) * 0.3),
				ImageTransparency = 1,
				Rotation = 120,
			}):Play()
		end
		if xp > 0 then
			xpText.Text = `+{xp}`
			xpPop.Visible = true
			xpPop.Position = UDim2.fromScale(0.16, 0.5)
			xpText.TextTransparency = 0
			xpIcon.ImageTransparency = 0
			local info = TweenInfo.new(XP_FLOAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(xpPop, info, { Position = UDim2.fromScale(0.16, 0.3) }):Play()
			TweenService:Create(xpText, info, { TextTransparency = 1 }):Play()
			TweenService:Create(xpIcon, info, { ImageTransparency = 1 }):Play()
		end
	end

	-- The server's answer: right or wrong (a hint, the question comes back later).
	local function showResult(res: Result)
		for _, button in answerButtons do
			button.Visible = false
		end
		laterButton.Visible = false
		result.Visible = true
		local line = Store.t(res.lineKey)
		if res.right then
			resultIcon.Image = Ui.ICONS.check
			resultIcon.ImageColor3 = ROLE.good
			resultTitle.Text = Store.t("ui.quiz.right", { xp = res.xp })
			resultTitle.TextColor3 = ROLE.good
			if cardStroke then
				cardStroke.Color = ROLE.good
			end
			Audio.play("achievement_unlock")
			celebrate(res.xp)
		else
			resultIcon.Image = Ui.ICONS.book
			resultIcon.ImageColor3 = ROLE.star
			resultTitle.Text = Store.t("ui.quiz.try_again")
			resultTitle.TextColor3 = ROLE.star
			if cardStroke then
				cardStroke.Color = ROLE.star
			end
			Audio.play("toast_pop")
		end
		resultLine.Text = line
		local seconds = Reading.seconds(`{resultTitle.Text} {line}`, { minimum = RESULT_MIN_SECONDS })
		showingResult = { id = res.id, untilAt = os.clock() + seconds }
	end

	chooseAnswer = function(choice: number)
		local current = prompt
		if showingResult then
			-- The result is up: the close button just closes it.
			showingResult = nil
			shownId = nil
			card.Visible = false
			return
		end
		if current == nil or waiting ~= nil then
			return
		end
		Store.send({ type = "AnswerQuiz", id = current.id, choice = choice } :: any)
		if choice == 0 then
			closedId = current.id
			shownId = nil
			card.Visible = false
			return
		end
		waiting = { id = current.id, choice = choice, at = os.clock() }
		setAnswersEnabled(false, choice)
	end

	local function onQuest(raw: any)
		if type(raw) ~= "table" then
			return
		end
		local nextPrompt = parsePrompt(raw.quiz)
		-- A different question, none, or a question offered again after a pause (nil -> id: the server
		-- withdrew it after "Not now" or a wrong answer and now asks again): show it again.
		if nextPrompt == nil or prompt == nil or nextPrompt.id ~= prompt.id then
			closedId = nil -- a different question (or none): a later return is shown again
			if showingResult == nil and waiting == nil then
				shownId = nil
			end
		end
		prompt = nextPrompt
		latestResult = parseResult(raw.quizResult)
		local pending = waiting
		local res = latestResult
		if pending and res and res.id == pending.id then
			waiting = nil
			closedId = pending.id
			showResult(res)
		end
	end

	-- Every CHECK_SECONDS: show, hide or time out the card.
	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		if sinceCheck < CHECK_SECONDS then
			return
		end
		sinceCheck = 0
		local ok = allowed()
		local resultView = showingResult
		if resultView then
			if os.clock() >= resultView.untilAt or not ok then
				showingResult = nil
				shownId = nil
				card.Visible = false
			end
			return
		end
		local pending = waiting
		if pending then
			if os.clock() - pending.at > RESULT_WAIT_SECONDS then
				-- No answer from the server (an older server, or the answer was refused): lay the
				-- question out again if it is still offered.
				waiting = nil
				shownId = nil
				card.Visible = false
			elseif card.Visible ~= ok then
				card.Visible = ok -- a panel or a mission opened meanwhile: hide, the answer still counts
			end
			return
		end
		local current = prompt
		local wanted = ok and current ~= nil and current.id ~= closedId
		if wanted and current then
			if shownId ~= current.id then
				shownId = current.id
				placeCard()
				showQuestionView()
				popIn()
				Audio.play("quest_new")
			end
			if not card.Visible then
				placeCard()
				card.Visible = true
			end
		elseif card.Visible and waiting == nil then
			card.Visible = false
		end
	end)

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "language" and card.Visible then
			if showingResult == nil then
				renderQuestion()
			end
		end
	end)

	-- The quest (with the quiz) arrives in the BaseState; Store.setBase does not keep it, so listen to
	-- the remote too (like Objectives.luau). It only reads.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER)
		local name: string = (Types.Remotes :: any).BASE_STATE or "BaseState"
		local remote = remotes:WaitForChild(name, BASE_STATE_WAIT_SECONDS)
		if remote == nil or not remote:IsA("RemoteEvent") then
			return -- older server: no questions
		end
		(remote :: RemoteEvent).OnClientEvent:Connect(function(state: any)
			if type(state) == "table" and type(state.credits) == "number" then
				onQuest(state.quest)
			end
		end)
	end)
end

return QuizCard
