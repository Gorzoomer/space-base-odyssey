--!strict
-- Space Base Odyssey - C.A.R.L. assistant speech bubble: shows server and local TextRefs for a few seconds.
-- Two queues: messages (server events, errors) come first; onboarding tips wait until no message is
-- pending, always get the full time on screen, and are dropped if their phase has passed.
-- A tip may carry a style: C.A.R.L.'s fun facts show a book badge and stay a little longer.
-- Fix 8 (playtest): a message that asks for a tool (or a parts crate) shows that tool's icon in a
-- gold round badge between C.A.R.L.'s avatar and the text, so young players see what to hold.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type TextRef = Store.TextRef

local SHOW_SECONDS = 5
local SHOW_SECONDS_BUSY = 2.5 -- shorter when more messages are waiting
local MAX_QUEUE = 4
local MAX_TIPS = 6
local FACT_SECONDS = 7 -- fun facts are longer (up to 16 words)

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
--   countdown (y 0.27); the left column (objectives, meters, wallet) ends at x 0.21, the Earth link
--   starts at x 0.815. The bottom centre belongs to the tool bar and the suit air bar.
-- * Base mode ("base"): top centre too, under the "Build your base" hint pill (y 0.115-0.175).
local MENU_POSITION = UDim2.fromScale(0.02, 0.8)
local MENU_SIZE = UDim2.fromScale(0.26, 0.18)
local PLANNING_POSITION = UDim2.fromScale(0.315, 0.795)
local PLANNING_SIZE = UDim2.fromScale(0.27, 0.18)
local PLAY_POSITION = UDim2.fromScale(0.29, 0.115)
local PLAY_SIZE = UDim2.fromScale(0.42, 0.145)
local BASE_POSITION = UDim2.fromScale(0.29, 0.19)

-- Badge layout inside the bubble, in bubble heights (the bubble's width changes with the screen).
local EDGE = 0.16 -- left edge to the avatar
local AVATAR = 0.56 -- avatar badge diameter
local TOOL = 0.5 -- tool badge diameter (same size family as the avatar)
local BADGE_GAP = 0.07 -- avatar to tool badge
local TEXT_GAP = 0.13 -- last badge to the text
local RIGHT_PAD = 0.12 -- text to the right edge
local BADGE_Y = 0.55 -- badge centres (the name tag sits above the avatar)
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

	local queue: { TextRef } = {}
	type Tip = { ref: TextRef, phase: string?, style: TipStyle? }
	local tips: { Tip } = {}
	local current: TextRef? = nil
	local currentIsTip = false
	local currentTipPhase: string? = nil
	local currentStyle: TipStyle? = nil
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
		if not current then
			bubble.Visible = false
			return
		end
		currentSince = os.clock()
		local isFact = currentStyle == "fact"
		badgeIcon.Image = if isFact then Ui.ICONS.book else Ui.ICONS.robot
		badgeIcon.ImageColor3 = if isFact then Ui.ROLE.star else Ui.ROLE.accent
		setTool(if isFact then nil else toolImageFor(current.key))
		render()
		bubble.Visible = true
		local seconds = if #queue > 0 then SHOW_SECONDS_BUSY elseif isFact then FACT_SECONDS else SHOW_SECONDS
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
		local onScreen = current
		if
			onScreen
			and not currentIsTip
			and #queue == 0
			and toolImageFor(ref.key) ~= nil
			and (toolImageFor(onScreen.key) ~= nil or os.clock() - currentSince >= SHOW_SECONDS_BUSY)
		then
			-- A new tool instruction replaces an older tool instruction (or a message already read)
			-- right away: the player just tried something and needs the new hint now.
			table.insert(queue, ref)
			showNext()
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
			if os.clock() - currentSince < SHOW_SECONDS_BUSY and currentStyle ~= "fact" then
				table.insert(tips, 1, { ref = current, phase = currentTipPhase, style = currentStyle })
			end
			showNext()
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
		if not current then
			showNext()
		end
	end

	local modeSet = false

	local function place(position: UDim2, size: UDim2)
		if bubble.Position ~= position then
			bubble.Position = position
		end
		if bubble.Size ~= size then
			bubble.Size = size
		end
		layoutBubble()
	end

	local function setMode(mode: string)
		modeSet = true
		if mode == "shift" or mode == "roam" then
			place(PLAY_POSITION, PLAY_SIZE)
		elseif mode == "base" then
			place(BASE_POSITION, PLAY_SIZE)
		elseif mode == "board" then
			place(PLANNING_POSITION, PLANNING_SIZE)
		else
			place(MENU_POSITION, MENU_SIZE)
		end
	end

	-- Older callers: a phase alone (Main.client calls setMode once the screen is known).
	local function setPhase(phase: string)
		if modeSet then
			return
		end
		if phase == "Planning" then
			place(PLANNING_POSITION, PLANNING_SIZE)
		elseif phase == "Shift" then
			place(PLAY_POSITION, PLAY_SIZE)
		else
			place(MENU_POSITION, MENU_SIZE)
		end
	end

	local function isIdle(): boolean
		return current == nil and #queue == 0 and #tips == 0
	end

	render()
	layoutBubble()
	return {
		show = show,
		showTip = showTip,
		isIdle = isIdle,
		render = render,
		setPhase = setPhase,
		setMode = setMode,
	}
end

return Messages
