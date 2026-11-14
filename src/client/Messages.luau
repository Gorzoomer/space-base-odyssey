--!strict
-- Space Base Odyssey - C.A.R.L. assistant speech bubble: shows server and local TextRefs for a few seconds.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef

local SHOW_SECONDS = 5
local SHOW_SECONDS_BUSY = 2.5 -- shorter when more messages are waiting
local MAX_QUEUE = 4

local Messages = {}

export type MessagesView = {
	show: (ref: TextRef) -> (),
	render: () -> (),
	setPhase: (phase: string) -> (), -- moves the bubble where it hides the least for that screen
}

-- Bubble placement per phase: bottom-left on full-screen menus, middle-left while playing.
local MENU_POSITION = UDim2.fromScale(0.02, 0.8)
local MENU_SIZE = UDim2.fromScale(0.26, 0.18)
local PLAY_POSITION = UDim2.fromScale(0.02, 0.44)
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
	local bubble = Ui.frame(root, {
		name = "CarlBubble",
		size = MENU_SIZE,
		position = MENU_POSITION,
		color = Ui.COLORS.bubble,
		corner = 0.2,
		stroke = 4,
		strokeColor = Ui.COLORS.plus,
		zindex = 50,
		visible = false,
	})
	local icon = Ui.icon(bubble, Ui.ICONS.robot, {
		size = UDim2.fromScale(0.22, 0.6),
		position = UDim2.fromScale(0.03, 0.5),
		anchor = Vector2.new(0, 0.5),
		aspect = 1,
		zindex = 51,
	})
	icon.Name = "Icon"
	local nameTag = Ui.label(bubble, {
		name = "Name",
		size = UDim2.fromScale(0.4, 0.3),
		position = UDim2.fromScale(0.25, -0.12),
		color = Ui.COLORS.plus,
		corner = 0.4,
		maxText = 26,
		zindex = 52,
	})
	local text = Ui.label(bubble, {
		name = "Text",
		size = UDim2.fromScale(0.7, 0.72),
		position = UDim2.fromScale(0.27, 0.2),
		textColor = Ui.COLORS.textDark,
		alignX = Enum.TextXAlignment.Left,
		maxText = 30,
		zindex = 51,
	})

	local queue: { TextRef } = {}
	local current: TextRef? = nil
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
		if not current then
			bubble.Visible = false
			return
		end
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
		end
	end

	local function setPhase(phase: string)
		local playing = phase == "Planning" or phase == "Shift"
		bubble.Position = if playing then PLAY_POSITION else MENU_POSITION
		bubble.Size = if playing then PLAY_SIZE else MENU_SIZE
	end

	render()
	return { show = show, render = render, setPhase = setPhase }
end

return Messages
