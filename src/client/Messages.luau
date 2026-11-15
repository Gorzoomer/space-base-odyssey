--!strict
-- Space Base Odyssey - C.A.R.L. assistant speech bubble: shows server and local TextRefs for a few seconds.
-- Two queues: messages (server events, errors) come first; onboarding tips wait until no message is
-- pending, always get the full time on screen, and are dropped if their phase has passed.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef

local SHOW_SECONDS = 5
local SHOW_SECONDS_BUSY = 2.5 -- shorter when more messages are waiting
local MAX_QUEUE = 4
local MAX_TIPS = 6

local Messages = {}

export type MessagesView = {
	show: (ref: TextRef) -> (),
	-- Low-priority tip; `phase` (optional) drops it if that phase is over before it can be shown.
	showTip: (ref: TextRef, phase: string?) -> (),
	render: () -> (),
	setPhase: (phase: string) -> (), -- moves the bubble where it hides the least for that screen
}

-- Bubble placement per phase, chosen so it never covers a button or a meter:
-- * Briefing and Report: bottom-left, beside the centred Start / Restart button.
-- * Planning: bottom row of the power board, in the gap between the power-left box (x 0.05-0.30)
--   and the Start button (x 0.60-0.95); its top (with the name tag) stays below the last system
--   row, which ends at y 0.77. See the layout table in PowerBoard.luau.
-- * Shift: middle-left, below the storm countdown and its flare-source line (which end at y 0.49).
local MENU_POSITION = UDim2.fromScale(0.02, 0.8)
local MENU_SIZE = UDim2.fromScale(0.26, 0.18)
local PLANNING_POSITION = UDim2.fromScale(0.315, 0.795)
local PLANNING_SIZE = UDim2.fromScale(0.27, 0.18)
local PLAY_POSITION = UDim2.fromScale(0.02, 0.5)
local PLAY_SIZE = UDim2.fromScale(0.36, 0.19)

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

function Messages.new(root: Frame): MessagesView
	-- C.A.R.L. speaks in cyan (systems and guidance): raised night panel, cyan border and name tag.
	local bubble = Ui.panel(root, {
		name = "CarlBubble",
		size = MENU_SIZE,
		position = MENU_POSITION,
		color = Ui.ROLE.panelRaised,
		corner = 0.2,
		stroke = 4,
		strokeColor = Ui.ROLE.accent,
		zindex = 50,
		visible = false,
	})
	local iconBadge = Ui.frame(bubble, {
		name = "IconBadge",
		size = UDim2.fromScale(0.2, 0.56),
		position = UDim2.fromScale(0.04, 0.55),
		anchor = Vector2.new(0, 0.5),
		color = Ui.ROLE.background,
		corner = 0.5,
		aspect = 1,
		zindex = 51,
	})
	Ui.icon(iconBadge, Ui.ICONS.robot, {
		name = "Icon",
		size = UDim2.fromScale(0.72, 0.72),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = Ui.ROLE.accent,
		zindex = 52,
	})
	local nameTag = Ui.label(bubble, {
		name = "Name",
		size = UDim2.fromScale(0.4, 0.3),
		position = UDim2.fromScale(0.25, -0.12),
		color = Ui.ROLE.accent,
		textColor = Ui.COLORS.textDark,
		corner = 0.5,
		maxText = 26,
		zindex = 52,
	})
	local text = Ui.body(bubble, {
		name = "Text",
		size = UDim2.fromScale(0.68, 0.72),
		position = UDim2.fromScale(0.28, 0.2),
		textColor = Ui.ROLE.text,
		maxText = 26,
		zindex = 51,
	})

	local queue: { TextRef } = {}
	local tips: { { ref: TextRef, phase: string? } } = {}
	local current: TextRef? = nil
	local currentIsTip = false
	local currentTipPhase: string? = nil
	local currentSince = 0
	local token = 0

	local function render()
		nameTag.Text = Store.t("ui.assistant_name")
		if current then
			text.Text = Store.t(current.key, friendlyParams(current.params))
		end
	end

	local function showNext()
		token += 1
		local myToken = token
		current = table.remove(queue, 1)
		currentIsTip = false
		currentTipPhase = nil
		while current == nil and #tips > 0 do
			local tip = table.remove(tips, 1)
			if tip and (tip.phase == nil or tip.phase == Store.phase()) then
				current = tip.ref
				currentIsTip = true
				currentTipPhase = tip.phase
			end
		end
		if not current then
			bubble.Visible = false
			return
		end
		currentSince = os.clock()
		render()
		bubble.Visible = true
		local seconds = if #queue > 0 then SHOW_SECONDS_BUSY else SHOW_SECONDS
		task.delay(seconds, function()
			if token == myToken then
				showNext()
			end
		end)
	end

	local function show(ref: TextRef)
		if type(ref) ~= "table" or type(ref.key) ~= "string" then
			return
		end
		-- Skip an exact repeat of the message on screen (e.g. a button pressed twice).
		if current and current.key == ref.key and #queue == 0 then
			current = ref
			render()
			return
		end
		table.insert(queue, ref)
		while #queue > MAX_QUEUE do
			table.remove(queue, 1)
		end
		if not current then
			showNext()
		elseif currentIsTip and current then
			-- A real event beats a tip. A tip cut short comes back later; one mostly read does not.
			if os.clock() - currentSince < SHOW_SECONDS_BUSY then
				table.insert(tips, 1, { ref = current, phase = currentTipPhase })
			end
			showNext()
		end
	end

	local function showTip(ref: TextRef, phase: string?)
		if type(ref) ~= "table" or type(ref.key) ~= "string" then
			return
		end
		table.insert(tips, { ref = ref, phase = phase })
		while #tips > MAX_TIPS do
			table.remove(tips, 1)
		end
		if not current then
			showNext()
		end
	end

	local function setPhase(phase: string)
		if phase == "Planning" then
			bubble.Position = PLANNING_POSITION
			bubble.Size = PLANNING_SIZE
		elseif phase == "Shift" then
			bubble.Position = PLAY_POSITION
			bubble.Size = PLAY_SIZE
		else
			bubble.Position = MENU_POSITION
			bubble.Size = MENU_SIZE
		end
	end

	render()
	return { show = show, showTip = showTip, render = render, setPhase = setPhase }
end

return Messages
