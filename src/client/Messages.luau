--!strict
-- Space Base Odyssey - C.A.R.L. assistant speech bubble: shows server and local TextRefs for a few seconds.
-- Two queues: messages (server events, errors) come first; onboarding tips wait until no message is
-- pending, always get the full time on screen, and are dropped if their phase has passed.
-- A tip may carry a style: C.A.R.L.'s fun facts show a book badge and stay a little longer.
-- Fix 8 (playtest): a message that asks for a tool (or a parts crate) shows that tool's icon in a
-- gold round badge between C.A.R.L.'s avatar and the text, so young players see what to hold.
-- Stage 10 (playtest): the bubble is about half its old area in every mode (team feedback: it covered
-- too much of the world). Badges and the name tag are sized in bubble heights, so they shrink with it.
-- Stage 11 readable UI (src/shared/Reading.luau):
--   * a line stays on screen by its word count (at least 4 s, about one word a second for young
--     readers), times the "Message time" setting (Store.messageSeconds). The clock pauses while the
--     start menu is open, so nothing is "shown" unseen behind it.
--   * notice storms: a repeated key merges into the waiting line, and when more than MAX_QUEUE lines
--     wait (a finished quest can bring praise, "quest done", "new quest", an achievement and a level-up
--     at once) the least useful one skips the screen and goes straight to the history.
--   * history: a small replay button beside the bubble opens "What C.A.R.L. said" (modal
--     "CarlHistory") with the last HISTORY_SIZE lines, newest first, in the current language.
--   * while the Lab (BasePanel) or the Wardrobe is open, the bubble moves to the bottom centre and
--     rises above those panels (z RAISED_Z), so the server's answer to a Lab or Wardrobe button
--     ("not enough credits", "bought!") is seen.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local Reading = require(Shared:WaitForChild("Reading")) -- Stage 11 readable UI

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio) -- Stage 11 audio

type TextRef = Store.TextRef

local MAX_QUEUE = 4
local MAX_TIPS = 6
local READ_ENOUGH_SECONDS = 2.5 -- a line shown this long counts as read (a tool hint may replace it)
-- Stage 11 readable UI (technical UI settings, not gameplay numbers).
local HISTORY_SIZE = 10
local Z = 50
local RAISED_Z = 59 -- above the Lab and Wardrobe (53) and the cards (56-58), under StartMenu (61) and Settings (62)
local HISTORY_Z = 60
local RAISE_PANELS = { "BasePanel", "Wardrobe" }
local PANEL_CHECK_SECONDS = 0.2

local Messages = {}

-- "fact": fun fact (book badge, longer on screen). nil: a normal tip.
export type TipStyle = "fact"

export type MessagesView = {
	show: (ref: TextRef) -> (),
	-- Low-priority tip; `phase` (optional) drops it if that phase is over before it can be shown.
	showTip: (ref: TextRef, phase: string?, style: TipStyle?) -> (),
	-- True when nothing is on screen or waiting (fun facts only speak into silence).
	isIdle: () -> boolean,
	render: () -> (),
	setPhase: (phase: string) -> (), -- kept for older callers: used only until setMode is called
	-- Moves the bubble where it hides the least for that screen (Hud.Mode: "shift", "roam", "base",
	-- "select", "board" or "none").
	setMode: (mode: string) -> (),
	-- Stage 11: opens the "What C.A.R.L. said" list (also the replay button beside the bubble).
	openHistory: () -> (),
}

-- Bubble placement per screen, chosen so it never covers a button, a meter or Roblox's tool bar
-- (the backpack hotbar at the bottom centre, shown while the player has tools):
-- * Mission select and Report ("select", "none"): bottom-left, beside the centred Start / Restart
--   button. Main.client hides the tool bar on these screens.
-- * Power board open ("board"): bottom row of the power board, in the gap between the power-left box
--   (x 0.05-0.30) and the Start button (x 0.60-0.95); its top (with the name tag) stays below the
--   last system row, which ends at y 0.77. See the layout table in PowerBoard.luau. The tool bar is
--   hidden while the board is open.
-- * Walking around ("shift", "roam"): top centre, under the shift timer and above the storm
--   countdown (y 0.27); the left column (objectives, meters, vitals, wallet) ends at x 0.21, the
--   right buttons (Earth link, Wardrobe) start at x 0.74 or later. The bottom centre belongs to the
--   tool bar and the field pills.
-- * Base mode ("base"): top centre too, under the "Build your base" hint pill (y 0.115-0.175).
-- * Stage 11, Lab or Wardrobe open: bottom centre over the panel's bottom edge (the tool bar is hidden
--   while they are open), above the panel.
-- Stage 10 table (fractions of the screen; the name tag rises about 0.012 above the bubble's top):
--   mode              x            y
--   select, none      0.02-0.26    0.835-0.945
--   board             0.32-0.58    0.835-0.95
--   shift, roam       0.33-0.67    0.115-0.21
--   base              0.33-0.67    0.19-0.285
--   Lab / Wardrobe    0.30-0.70    0.845-0.945
-- The Stage 11 replay button sits right of the bubble (about x +0.006 to +0.045), except on the power
-- board, where the Start button is too close (it is hidden there).
local MENU_POSITION = UDim2.fromScale(0.02, 0.835)
local MENU_SIZE = UDim2.fromScale(0.24, 0.11)
local PLANNING_POSITION = UDim2.fromScale(0.32, 0.835)
local PLANNING_SIZE = UDim2.fromScale(0.26, 0.115)
local PLAY_POSITION = UDim2.fromScale(0.33, 0.115)
local PLAY_SIZE = UDim2.fromScale(0.34, 0.095)
local BASE_POSITION = UDim2.fromScale(0.33, 0.19)
local PANEL_POSITION = UDim2.fromScale(0.3, 0.845)
local PANEL_SIZE = UDim2.fromScale(0.4, 0.1)
local TEXT_MAX = 20 -- biggest text size: two lines of 8 words still fit the small play bubble
local HISTORY_GAP = 0.006 -- bubble's right edge to the replay button
local HISTORY_BUTTON_HEIGHT = 0.6 -- replay button height, in bubble heights

-- Badge layout inside the bubble, in bubble heights (the bubble's width changes with the screen).
local EDGE = 0.16 -- left edge to the avatar
local AVATAR = 0.56 -- avatar badge diameter
local TOOL = 0.5 -- tool badge diameter (same size family as the avatar)
local BADGE_GAP = 0.07 -- avatar to tool badge
local TEXT_GAP = 0.13 -- last badge to the text
local RIGHT_PAD = 0.12 -- text to the right edge
local BADGE_Y = 0.55 -- badge centres (the name tag sits above the avatar)
local NAME_WIDTH = 1.15 -- name tag width, starting at the avatar's right edge
local NAME_HEIGHT = 0.3 -- name tag height (fraction of the bubble height), centred on the top edge
local NAME_Y = -0.12
local TOOL_POP_SECONDS = 0.35

-- Messages that ask for a tool, by localization key -> tool id (MissionData.BASE.TOOLS) or "crate"
-- (a parts crate from the lander). "carl.tool.need_<id>" and "tip.tool_<id>" are matched by pattern.
local TOOL_FOR_KEY: { [string]: string } = {
	["carl.tool.need_tablet_scan"] = "tablet",
	["carl.base.need_wrench"] = "wrench",
	["carl.base.crate_delivered"] = "wrench",
	["tip.use_wrench"] = "wrench",
	["carl.base.need_crate"] = "crate",
	["carl.base.build_started"] = "crate",
	["carl.base.step_done"] = "crate",
	["carl.base.crate_taken"] = "crate",
	["carl.base.has_crate"] = "crate",
	["carl.tool.hands_full"] = "crate",
	["tip.take_crate"] = "crate",
	["tip.deliver_crate"] = "crate",
	["carl.dust"] = "brush",
	["carl.leak"] = "repair_kit",
	["tip.antenna"] = "tablet",
	["carl.meteor.hit"] = "tablet",
	["tip.meteor_scan"] = "tablet",
	["tip.find_ice"] = "drill",
	["tip.base_ice"] = "drill",
	["carl.no_water"] = "drill",
	["carl.vehicle.need_ice"] = "drill",
	["carl.tool.eat_inside"] = "food",
	["carl.tool.food_picked"] = "food",
	["carl.tool.food_full"] = "food",
}

-- Tool id -> icon image (the same icon as the tool in the backpack and the Lab).
local TOOL_IMAGES: { [string]: string } = { crate = Ui.Icons.crate }
for _, tool in MissionData.BASE.TOOLS do
	TOOL_IMAGES[tool.id] = Ui.iconImage(tool.icon)
end

-- The icon of the tool a message asks for, or nil for any other message.
local function toolImageFor(key: string): string?
	local id = TOOL_FOR_KEY[key]
	if id == nil then
		id = string.match(key, "^carl%.tool%.need_(.+)$") or string.match(key, "^tip%.tool_(.+)$")
	end
	return if id then TOOL_IMAGES[id] else nil
end

-- ISO dates from the flare archive ("2024-05-10T06:54Z") read better as "2024-05-10".
local function friendlyParams(params: { [string]: string | number }?): { [string]: string | number }?
	if not params then
		return nil
	end
	local result: { [string]: string | number } = {}
	for name, value in params do
		if type(value) == "string" and string.match(value, "^%d%d%d%d%-%d%d%-%d%dT") then
			result[name] = string.sub(value, 1, 10)
		else
			result[name] = value
		end
	end
	return result
end

local function textOf(ref: TextRef): string
	return Store.t(ref.key, friendlyParams(ref.params))
end

-- Stage 11: the "Message time" setting makes lines stay longer (Store.messageSeconds(seconds) returns
-- the time at the chosen speed). Read through `any`: an older Store has none.
local function atPlayerSpeed(seconds: number): number
	local scale: any = (Store :: any).messageSeconds
	if type(scale) == "function" then
		local ok, result = pcall(scale, seconds)
		if ok and type(result) == "number" and result == result and result >= seconds then
			return result
		end
	end
	return seconds
end

local function keyOf(ref: TextRef): string
	return ref.key
end

function Messages.new(root: Frame): MessagesView
	-- C.A.R.L. speaks in cyan (systems and guidance): raised night panel, cyan border and name tag.
	local bubble = Ui.panel(root, {
		name = "CarlBubble",
		size = MENU_SIZE,
		position = MENU_POSITION,
		color = Ui.ROLE.panelRaised,
		corner = 0.2,
		stroke = 3,
		strokeColor = Ui.ROLE.accent,
		zindex = Z,
		visible = false,
	})
	local iconBadge = Ui.frame(bubble, {
		name = "IconBadge",
		size = UDim2.fromScale(0.2, AVATAR),
		position = UDim2.fromScale(0.04, BADGE_Y),
		anchor = Vector2.new(0, 0.5),
		color = Ui.ROLE.background,
		corner = 0.5,
		aspect = 1,
		zindex = 51,
	})
	local badgeIcon = Ui.icon(iconBadge, Ui.ICONS.robot, {
		name = "Icon",
		size = UDim2.fromScale(0.72, 0.72),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = Ui.ROLE.accent,
		zindex = 52,
	})
	-- The tool the message asks for (gold badge, dark icon), between the avatar and the text.
	local toolBadge = Ui.frame(bubble, {
		name = "ToolBadge",
		size = UDim2.fromScale(0.18, TOOL),
		position = UDim2.fromScale(0.2, BADGE_Y),
		anchor = Vector2.new(0.5, 0.5),
		color = Ui.ROLE.star,
		corner = 0.5,
		stroke = 3,
		strokeColor = Ui.ROLE.background,
		aspect = 1,
		zindex = 51,
		visible = false,
	})
	local toolIcon = Ui.icon(toolBadge, Ui.Icons.crate, {
		name = "Icon",
		size = UDim2.fromScale(0.66, 0.66),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = Ui.COLORS.textDark,
		zindex = 52,
	})
	local toolScale = Instance.new("UIScale")
	toolScale.Parent = toolBadge
	local nameTag = Ui.label(bubble, {
		name = "Name",
		size = UDim2.fromScale(0.32, NAME_HEIGHT),
		position = UDim2.fromScale(0.25, NAME_Y),
		color = Ui.ROLE.accent,
		textColor = Ui.COLORS.textDark,
		corner = 0.5,
		maxText = 16,
		minText = 8,
		zindex = 52,
	})
	local text = Ui.body(bubble, {
		name = "Text",
		size = UDim2.fromScale(0.68, 0.72),
		position = UDim2.fromScale(0.28, 0.2),
		textColor = Ui.ROLE.text,
		maxText = TEXT_MAX,
		minText = 9,
		zindex = 51,
	})

	-- Badges are sized in bubble heights; the text takes the rest of the width.
	local function layoutBubble()
		local size = bubble.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local h = size.Y / size.X -- one bubble height as a fraction of the bubble width
		iconBadge.Size = UDim2.fromScale(AVATAR * h, AVATAR)
		iconBadge.Position = UDim2.fromScale(EDGE * h, BADGE_Y)
		local right = EDGE + AVATAR
		nameTag.Size = UDim2.fromScale(math.min(0.6, NAME_WIDTH * h), NAME_HEIGHT)
		nameTag.Position = UDim2.fromScale(right * h, NAME_Y)
		if toolBadge.Visible then
			local toolLeft = right + BADGE_GAP
			toolBadge.Size = UDim2.fromScale(TOOL * h, TOOL)
			toolBadge.Position = UDim2.fromScale((toolLeft + TOOL / 2) * h, BADGE_Y)
			right = toolLeft + TOOL
		end
		local textLeft = (right + TEXT_GAP) * h
		text.Position = UDim2.fromScale(textLeft, 0.2)
		text.Size = UDim2.fromScale(math.max(0.2, 1 - textLeft - RIGHT_PAD * h), 0.72)
	end
	bubble:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBubble)

	local function setTool(image: string?)
		local shown = image ~= nil
		local changed = toolBadge.Visible ~= shown or (shown and toolIcon.Image ~= image)
		toolBadge.Visible = shown
		if image then
			toolIcon.Image = image
		end
		layoutBubble()
		if shown and changed then
			-- A little pop so the eye goes to the tool.
			toolScale.Scale = 1.35
			TweenService:Create(toolScale, TweenInfo.new(TOOL_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end

	-- Stage 11 history: the last lines C.A.R.L. said (shown ones and the ones a notice storm skipped).
	type Entry = { ref: TextRef, style: TipStyle? }
	local history: { Entry } = {}
	local renderHistory: () -> () = function() end
	local historyButton: TextButton? = nil
	local historyModal: Frame? = nil

	local function remember(ref: TextRef, style: TipStyle?)
		local last = history[#history]
		if last and last.ref.key == ref.key and textOf(last.ref) == textOf(ref) then
			history[#history] = { ref = ref, style = style }
		else
			table.insert(history, { ref = ref, style = style })
			while #history > HISTORY_SIZE do
				table.remove(history, 1)
			end
		end
		if historyModal and historyModal.Visible then
			renderHistory()
		end
	end

	local queue: { TextRef } = {}
	type Tip = { ref: TextRef, phase: string?, style: TipStyle? }
	local tips: { Tip } = {}
	local current: TextRef? = nil
	local currentIsTip = false
	local currentTipPhase: string? = nil
	local currentStyle: TipStyle? = nil
	local shownFor = 0 -- seconds the current line has been on screen (paused while held)
	local duration = 0 -- seconds it stays

	-- Stage 11: the start menu covers the game UI (StartMenu.luau moves it into a hidden holder), so
	-- nothing starts and no clock runs while it is open.
	local function held(): boolean
		local menu = root:FindFirstChild("StartMenu")
		return menu ~= nil and menu:IsA("GuiObject") and menu.Visible
	end

	local function durationFor(ref: TextRef, isFact: boolean, busy: boolean): number
		return atPlayerSpeed(Reading.seconds(textOf(ref), { fact = isFact, busy = busy }))
	end

	local function render()
		nameTag.Text = Store.t("ui.assistant_name")
		if current then
			text.Text = textOf(current)
		end
		if historyModal and historyModal.Visible then
			renderHistory()
		end
	end

	local function showNext()
		current = table.remove(queue, 1)
		currentIsTip = false
		currentTipPhase = nil
		currentStyle = nil
		while current == nil and #tips > 0 do
			local tip = table.remove(tips, 1)
			if tip and (tip.phase == nil or tip.phase == Store.phase()) then
				current = tip.ref
				currentIsTip = true
				currentTipPhase = tip.phase
				currentStyle = tip.style
			end
		end
		local shown = current
		if not shown then
			bubble.Visible = false
			duration = 0
			return
		end
		shownFor = 0
		local isFact = currentStyle == "fact"
		duration = durationFor(shown, isFact, #queue > 0)
		badgeIcon.Image = if isFact then Ui.ICONS.book else Ui.ICONS.robot
		badgeIcon.ImageColor3 = if isFact then Ui.ROLE.star else Ui.ROLE.accent
		setTool(if isFact then nil else toolImageFor(shown.key))
		render()
		bubble.Visible = true
		remember(shown, currentStyle)
		Audio.play(if string.sub(shown.key, 1, 9) == "base.why." then "ui_error" else "carl_beep") -- Stage 11 audio
	end

	local function show(ref: TextRef)
		if type(ref) ~= "table" or type(ref.key) ~= "string" then
			return
		end
		-- Stage 11 readable UI: the "C.A.R.L. asks" card (QuizCard.luau) already shows the hint or the
		-- "why" line of an answer; while it is up the same line only goes to the history (no double text).
		if string.sub(ref.key, 1, 5) == "quiz." then
			local quizCard = root:FindFirstChild("QuizCard")
			if quizCard and quizCard:IsA("GuiObject") and quizCard.Visible then
				remember(ref, nil)
				return
			end
		end
		-- Skip an exact repeat of the message on screen (e.g. a button pressed twice).
		if current and current.key == ref.key and #queue == 0 then
			current = ref
			render()
			remember(ref, currentStyle)
			return
		end
		local onScreen = current
		if
			onScreen
			and not currentIsTip
			and #queue == 0
			and not held()
			and toolImageFor(ref.key) ~= nil
			and (toolImageFor(onScreen.key) ~= nil or shownFor >= READ_ENOUGH_SECONDS)
		then
			-- A new tool instruction replaces an older tool instruction (or a message already read)
			-- right away: the player just tried something and needs the new hint now.
			table.insert(queue, ref)
			showNext()
			return
		end
		-- Stage 11: merge repeats; lines a storm pushes out go straight to the history.
		for _, skipped in Reading.enqueue(queue, ref, keyOf, MAX_QUEUE) do
			remember(skipped, nil)
		end
		if not current then
			if not held() then
				showNext()
			end
		elseif currentIsTip then
			-- A real event beats a tip. A tip cut short comes back later; one mostly read does not.
			if shownFor < READ_ENOUGH_SECONDS and currentStyle ~= "fact" then
				table.insert(tips, 1, { ref = current, phase = currentTipPhase, style = currentStyle })
			end
			showNext()
		else
			-- Another line waits: the one on screen gets its "busy" time (never under the minimum).
			duration = math.min(duration, durationFor(current, currentStyle == "fact", true))
		end
	end

	local function showTip(ref: TextRef, phase: string?, style: TipStyle?)
		if type(ref) ~= "table" or type(ref.key) ~= "string" then
			return
		end
		table.insert(tips, { ref = ref, phase = phase, style = style })
		while #tips > MAX_TIPS do
			table.remove(tips, 1)
		end
		if not current and not held() then
			showNext()
		end
	end

	-- Placement ------------------------------------------------------------------------------------
	local modeSet = false
	local mode = "none"
	local raised = false

	local function placeHistoryButton(position: UDim2, size: UDim2)
		local button = historyButton
		if button == nil then
			return
		end
		button.Position = UDim2.fromScale(position.X.Scale + size.X.Scale + HISTORY_GAP, position.Y.Scale + size.Y.Scale * 0.5)
		button.Size = UDim2.fromScale(0.06, size.Y.Scale * HISTORY_BUTTON_HEIGHT)
	end

	local function place(position: UDim2, size: UDim2)
		if bubble.Position ~= position then
			bubble.Position = position
		end
		if bubble.Size ~= size then
			bubble.Size = size
		end
		placeHistoryButton(position, size)
		layoutBubble()
	end

	local function refreshHistoryButton()
		local button = historyButton
		if button == nil then
			return
		end
		local wanted = #history > 0 and not raised and mode ~= "board" and not held()
		if button.Visible ~= wanted then
			button.Visible = wanted
		end
	end

	local function updatePlacement()
		bubble.ZIndex = if raised then RAISED_Z else Z
		if raised then
			place(PANEL_POSITION, PANEL_SIZE)
		elseif mode == "shift" or mode == "roam" then
			place(PLAY_POSITION, PLAY_SIZE)
		elseif mode == "base" then
			place(BASE_POSITION, PLAY_SIZE)
		elseif mode == "board" then
			place(PLANNING_POSITION, PLANNING_SIZE)
		else
			place(MENU_POSITION, MENU_SIZE)
		end
		refreshHistoryButton()
	end

	local function setMode(value: string)
		modeSet = true
		mode = value
		updatePlacement()
	end

	-- Older callers: a phase alone (Main.client calls setMode once the screen is known).
	local function setPhase(phase: string)
		if modeSet then
			return
		end
		mode = if phase == "Planning" then "board" elseif phase == "Shift" then "shift" else "none"
		updatePlacement()
	end

	local function isIdle(): boolean
		return current == nil and #queue == 0 and #tips == 0
	end

	-- Stage 11: the Lab or the Wardrobe is open (they may wait in the start menu's holder frame).
	local function raisePanelOpen(): boolean
		local layer = root:FindFirstChild("GameLayer")
		for _, name in RAISE_PANELS do
			local panel = root:FindFirstChild(name) or (if layer then layer:FindFirstChild(name) else nil)
			if panel and panel:IsA("GuiObject") and panel.Visible then
				return true
			end
		end
		return false
	end

	-- History list -----------------------------------------------------------------------------------
	do
		local modal = Ui.modal(root, "CarlHistory", HISTORY_Z)
		historyModal = modal
		local backdrop = Instance.new("TextButton")
		backdrop.Name = "Backdrop"
		backdrop.Text = ""
		backdrop.BackgroundTransparency = 1
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.ZIndex = HISTORY_Z
		backdrop.AutoButtonColor = false
		backdrop.Parent = modal
		local function close()
			modal.Visible = false
		end
		backdrop.Activated:Connect(close)

		local panel = Ui.panel(modal, {
			name = "Panel",
			size = UDim2.fromScale(0.7, 0.82),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			color = Ui.ROLE.panel,
			corner = 0.05,
			stroke = 4,
			strokeColor = Ui.ROLE.accent,
			aspect = 1.25,
			zindex = HISTORY_Z + 1,
		})
		panel.Active = true
		Ui.sheen(panel)
		Ui.icon(panel, Ui.ICONS.robot, {
			name = "Icon",
			size = UDim2.fromScale(0.08, 0.09),
			position = UDim2.fromScale(0.04, 0.08),
			anchor = Vector2.new(0, 0.5),
			tint = Ui.ROLE.accent,
			zindex = HISTORY_Z + 2,
		})
		local title = Ui.label(panel, {
			name = "Title",
			size = UDim2.fromScale(0.66, 0.09),
			position = UDim2.fromScale(0.13, 0.08),
			anchor = Vector2.new(0, 0.5),
			alignX = Enum.TextXAlignment.Left,
			textColor = Ui.ROLE.accent,
			maxText = 34,
			zindex = HISTORY_Z + 2,
		})
		Ui.oneLine(title)
		Ui.button(panel, {
			name = "Close",
			size = UDim2.fromScale(0.1, 0.11),
			position = UDim2.fromScale(0.97, 0.025),
			anchor = Vector2.new(1, 0),
			color = Ui.COLORS.secondary,
			icon = Ui.ICONS.close,
			tint = Ui.ROLE.text,
			aspect = 1,
			zindex = HISTORY_Z + 2,
		}, close)

		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Position = UDim2.fromScale(0.04, 0.16)
		list.Size = UDim2.fromScale(0.92, 0.8)
		list.CanvasSize = UDim2.fromScale(0, 0)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.ScrollingDirection = Enum.ScrollingDirection.Y
		list.ScrollBarThickness = 10
		list.ScrollBarImageColor3 = Ui.ROLE.accent
		list.ZIndex = HISTORY_Z + 2
		list.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = list

		local empty = Ui.body(panel, {
			name = "Empty",
			size = UDim2.fromScale(0.8, 0.12),
			position = UDim2.fromScale(0.1, 0.4),
			alignX = Enum.TextXAlignment.Center,
			textColor = Ui.ROLE.textDim,
			maxText = 24,
			minText = 14,
			zindex = HISTORY_Z + 2,
			visible = false,
		})

		-- Rows in reference units (the root's UIScale maps them to the screen): big enough to read.
		local ROW_HEIGHT = 64
		local rows: { Frame } = {}
		renderHistory = function()
			title.Text = Store.t("ui.history.title")
			empty.Text = Store.t("ui.history.empty")
			empty.Visible = #history == 0
			for _, row in rows do
				row:Destroy()
			end
			table.clear(rows)
			for order = 1, #history do
				local entry = history[#history - order + 1] -- newest first
				local isFact = entry.style == "fact"
				local row = Ui.frame(list, {
					name = `Line{order}`,
					size = UDim2.new(1, -14, 0, ROW_HEIGHT),
					color = if order == 1 then Ui.ROLE.panelRaised else Ui.ROLE.background,
					transparency = if order == 1 then 0 else 0.35,
					corner = 0.2,
					order = order,
					zindex = HISTORY_Z + 3,
				})
				Ui.icon(row, if isFact then Ui.ICONS.book else Ui.ICONS.robot, {
					name = "Icon",
					size = UDim2.new(0, 40, 0, 40),
					position = UDim2.new(0, 10, 0.5, 0),
					anchor = Vector2.new(0, 0.5),
					tint = if isFact then Ui.ROLE.star else Ui.ROLE.accent,
					zindex = HISTORY_Z + 4,
				})
				Ui.body(row, {
					name = "Text",
					size = UDim2.new(1, -72, 0.9, 0),
					position = UDim2.new(0, 60, 0.5, 0),
					anchor = Vector2.new(0, 0.5),
					text = textOf(entry.ref),
					textColor = if order == 1 then Ui.ROLE.text else Ui.ROLE.textDim,
					maxText = 22,
					minText = 15,
					zindex = HISTORY_Z + 4,
				})
				table.insert(rows, row)
			end
			list.CanvasPosition = Vector2.zero
		end

		historyButton = Ui.button(root, {
			name = "CarlHistoryButton",
			size = UDim2.fromScale(0.06, 0.057),
			position = UDim2.fromScale(0.68, 0.16),
			anchor = Vector2.new(0, 0.5),
			color = Ui.ROLE.panelRaised,
			corner = 0.5,
			stroke = 2,
			strokeColor = Ui.ROLE.accent,
			icon = Ui.ICONS.restart,
			tint = Ui.ROLE.accent,
			aspect = 1,
			zindex = Z,
			visible = false,
		}, function()
			renderHistory()
			modal.Visible = true
		end)
	end

	local function openHistory()
		local modal = historyModal
		if modal then
			renderHistory()
			modal.Visible = true
		end
	end

	-- Clock and panel watch: one Heartbeat (the clock pauses while held).
	local sinceCheck = PANEL_CHECK_SECONDS
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceCheck += deltaTime
		if sinceCheck >= PANEL_CHECK_SECONDS then
			sinceCheck = 0
			local wanted = raisePanelOpen()
			if wanted ~= raised then
				raised = wanted
				updatePlacement()
			else
				refreshHistoryButton()
			end
		end
		if held() then
			return
		end
		if current == nil then
			if #queue > 0 or #tips > 0 then
				showNext()
			end
			return
		end
		shownFor += deltaTime
		if shownFor >= duration then
			showNext()
		end
	end)

	render()
	layoutBubble()
	updatePlacement()
	return {
		show = show,
		showTip = showTip,
		isIdle = isIdle,
		render = render,
		setPhase = setPhase,
		setMode = setMode,
		openHistory = openHistory,
	}
end

return Messages
