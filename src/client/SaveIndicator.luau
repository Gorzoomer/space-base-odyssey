--!strict
-- Space Base Odyssey - Stage 10 save indicator (playtest: "I did not know how to save the world").
-- The server sends Remotes.SAVED (Types.SaveNotice) after each save of this player's slot. A small
-- pill fades in at the bottom-right corner for about 2 seconds: "Game saved" (a real save),
-- "Saved for this test only" (memory: Studio without DataStores) or "Could not save" (a "Save now"
-- that failed). It stays clear of the bottom-centre tool bar and of Roblox's chat and top bar; on
-- touch screens it sits under the Run button and the touch gear row (Sprint.luau / Gear.luau,
-- y 0.43-0.70) and above Roblox's jump button (top edge y 0.77 or lower), a little bigger so it can
-- be read on a phone. It never goes up to y 0.28-0.45, where QuestToasts.luau stacks its cards.
-- Autosaves happen every few seconds while playing, so they show at most once every
-- AUTO_SHOW_SECONDS (memory-only ones even less often); a "Save now" always shows.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

type SaveNotice = Types.SaveNotice

local ROLE = Ui.ROLE

-- Technical UI settings (not gameplay numbers).
local SIZE = UDim2.fromScale(0.19, 0.05)
local DESKTOP_POSITION = UDim2.fromScale(0.985, 0.975) -- bottom-right corner (anchor 1, 1)
local TOUCH_SIZE = UDim2.fromScale(0.2, 0.055) -- phones: 0.045 of the height is too small to read
local TOUCH_POSITION = UDim2.fromScale(0.97, 0.765) -- anchor 1, 1: y 0.71-0.765, under the gear row (0.70)
local SHOW_SECONDS = 2
local FADE_SECONDS = 0.25
local AUTO_SHOW_SECONDS = 30 -- autosaves show at most this often
local MEMORY_SHOW_SECONDS = 120 -- memory-only autosaves show even less often
local REMOTE_WAIT_SECONDS = 60 -- an older server never creates the remote
local Z = 70 -- above the Settings panel (62), so a "Save now" answer is seen

local SaveIndicator = {}

local started = false

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function SaveIndicator.start(root: Frame)
	if started then
		return
	end
	started = true

	-- A CanvasGroup fades the whole pill (fill, stroke, icon, text) with one value.
	local pill = Instance.new("CanvasGroup")
	pill.Name = "SaveIndicator"
	pill.Size = SIZE
	pill.AnchorPoint = Vector2.new(1, 1)
	pill.Position = DESKTOP_POSITION
	pill.BackgroundTransparency = 1
	pill.BorderSizePixel = 0
	pill.GroupTransparency = 1
	pill.Visible = false
	pill.Active = false
	pill.ZIndex = Z
	pill.Parent = root

	local fill = Ui.panel(pill, {
		name = "Fill",
		size = UDim2.new(1, -4, 1, -4),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.5,
		stroke = 2,
		strokeColor = ROLE.good,
		zindex = Z,
	})
	local fillStroke = fill:FindFirstChildOfClass("UIStroke")
	local icon = Ui.icon(fill, Ui.ICONS.check, {
		name = "Icon",
		size = UDim2.fromScale(0.16, 0.7),
		position = UDim2.fromScale(0.05, 0.5),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.good,
		zindex = Z + 1,
	})
	local label = Ui.body(fill, {
		name = "Text",
		size = UDim2.fromScale(0.74, 0.7),
		position = UDim2.fromScale(0.23, 0.5),
		anchor = Vector2.new(0, 0.5),
		maxText = 22,
		minText = 8,
		zindex = Z + 1,
	})

	local textKey = "ui.save_done"
	local hideToken = 0
	local lastAutoShown = -math.huge
	local lastMemoryShown = -math.huge
	local tweenInfo = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function render()
		label.Text = Store.t(textKey)
	end

	local function show(notice: SaveNotice)
		local tint: Color3
		local image: string
		if not notice.ok then
			textKey, tint, image = "ui.save_failed", ROLE.danger, Ui.ICONS.warning
		elseif notice.real then
			textKey, tint, image = "ui.save_done", ROLE.good, Ui.ICONS.check
		else
			textKey, tint, image = "ui.save_test_only", ROLE.star, Ui.ICONS.data
		end
		Ui.setIcon(icon, image, tint)
		if fillStroke then
			fillStroke.Color = tint
		end
		render()
		local touch = isTouchOnly()
		pill.Size = if touch then TOUCH_SIZE else SIZE
		pill.Position = if touch then TOUCH_POSITION else DESKTOP_POSITION

		hideToken += 1
		local token = hideToken
		pill.Visible = true
		TweenService:Create(pill, tweenInfo, { GroupTransparency = 0 }):Play()
		task.delay(FADE_SECONDS + SHOW_SECONDS, function()
			if token ~= hideToken then
				return -- a newer notice is showing
			end
			local fade = TweenService:Create(pill, tweenInfo, { GroupTransparency = 1 })
			fade.Completed:Connect(function()
				if token == hideToken then
					pill.Visible = false
				end
			end)
			fade:Play()
		end)
	end

	local function onNotice(data: any)
		if type(data) ~= "table" or type(data.ok) ~= "boolean" or type(data.real) ~= "boolean" then
			return
		end
		local notice: SaveNotice = { ok = data.ok, real = data.real, manual = data.manual == true }
		local t = os.clock()
		if notice.manual then
			lastAutoShown = t -- the next autosave does not repeat it right away
			if not notice.real then
				lastMemoryShown = t
			end
		elseif notice.real then
			if t - lastAutoShown < AUTO_SHOW_SECONDS then
				return
			end
			lastAutoShown = t
		else
			if t - lastMemoryShown < MEMORY_SHOW_SECONDS then
				return
			end
			lastMemoryShown = t
		end
		show(notice)
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "language" and pill.Visible then
			render()
		end
	end)

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(Types.Remotes.FOLDER, REMOTE_WAIT_SECONDS)
		local remote = if folder then folder:WaitForChild(Types.Remotes.SAVED, REMOTE_WAIT_SECONDS) else nil
		if remote == nil or not remote:IsA("RemoteEvent") then
			warn("[SpaceBaseOdyssey] Saved remote not found; the save indicator is off")
			return
		end
		(remote :: RemoteEvent).OnClientEvent:Connect(onNotice)
	end)
end

return SaveIndicator
