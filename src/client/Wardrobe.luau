--!strict
-- Space Base Odyssey - Wardrobe (Stage 6): choose what you wear and show. The player keeps their own
-- Roblox avatar; the suit only adds a helmet and a life-support backpack. Four slots:
--   helmet   standard | explorer26 (event code "explorer26" cosmetic)
--   backpack standard | laika (Laika secret)
--   carl     classic  | earth (Mini Earth secret)
--   pet      none | laika | cheese (secrets) | rabbit | monkey (adopted at the Lab, Stage 7)
-- Each option is a tile: the worn one is highlighted, locked ones are greyed with how to unlock them.
-- Tapping an owned tile sends Action Equip { slot, value }; the server checks ownership again.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local BasePanel = require(script.Parent.BasePanel)

type BaseState = Types.BaseState
type Slot = "helmet" | "backpack" | "carl" | "pet"

local ROLE = Ui.ROLE
local PALETTE = Ui.Theme.PALETTE

local Z = 53 -- same layer as the Lab panel (above the C.A.R.L. bubble, below Sources and Settings)
local PANEL_ASPECT = 1.5
local PRESS_COOLDOWN = 0.4
local PENDING_SECONDS = 2 -- an optimistic choice shows this long if the server never answers
local SPIN_SPEED = 0.6

-- Defaults when the server has not sent a BaseState yet (Types.Equipped contract).
local DEFAULTS: { [Slot]: string } = {
	helmet = "standard",
	backpack = "standard",
	carl = "classic",
	pet = "none",
}

-- How a locked option is unlocked: "secret" (find a hidden collectible), "code" (event code) or
-- "buy" (adopted at the Lab: Lab panel, Pets tab; text "wardrobe.how_buy").
type Unlock = "free" | "secret" | "code" | "buy"

type Option = {
	value: string,
	icon: string?, -- Icons.luau image (nil = 3D pet preview)
	tint: Color3,
	unlock: Unlock,
	collectible: string?, -- for "secret"
	cosmetic: string?, -- for "code"
}

type SlotDef = { id: Slot, icon: string, options: { Option } }

local SLOTS: { SlotDef } = {
	{
		id = "helmet",
		icon = Ui.Icons.helmet,
		options = {
			{ value = "standard", icon = Ui.Icons.helmet, tint = ROLE.text, unlock = "free" },
			{ value = "explorer26", icon = Ui.Icons.helmet, tint = ROLE.star, unlock = "code", cosmetic = "explorer26" },
		},
	},
	{
		id = "backpack",
		icon = Ui.Icons.backpack,
		options = {
			{ value = "standard", icon = Ui.Icons.backpack, tint = ROLE.text, unlock = "free" },
			{ value = "laika", icon = Ui.Icons.paw, tint = ROLE.reward, unlock = "secret", collectible = "laika" },
		},
	},
	{
		id = "carl",
		icon = Ui.Icons.robot,
		options = {
			{ value = "classic", icon = Ui.Icons.robot, tint = ROLE.accent, unlock = "free" },
			{ value = "earth", icon = Ui.Icons.planet, tint = PALETTE.lime, unlock = "secret", collectible = "mini_earth" },
		},
	},
	{
		id = "pet",
		icon = Ui.Icons.paw,
		options = {
			{ value = "none", icon = Ui.Icons.close, tint = ROLE.textDim, unlock = "free" },
			{ value = "laika", tint = ROLE.reward, unlock = "secret", collectible = "laika" },
			{ value = "cheese", tint = ROLE.reward, unlock = "secret", collectible = "cheese" },
			{ value = "rabbit", tint = ROLE.reward, unlock = "buy" },
			{ value = "monkey", tint = ROLE.reward, unlock = "buy" },
		},
	},
}

local UNLOCK_KEYS: { [Unlock]: string } = {
	free = "",
	secret = "wardrobe.how_secret",
	code = "wardrobe.how_code",
	buy = "wardrobe.how_buy",
}

local Wardrobe = {}

export type Deps = {
	showMessage: any, -- reserved for local hints
}

export type WardrobeView = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	render: () -> (),
}

local function getBase(): BaseState?
	return Store.getBase()
end

-- What the server says this player wears (defaults for missing fields).
local function equippedValue(base: BaseState?, slot: Slot): string
	local equipped: any = if base then base.equipped else nil
	if type(equipped) == "table" and type(equipped[slot]) == "string" then
		return equipped[slot]
	end
	return DEFAULTS[slot]
end

-- Does this player own an option? (Same rules as the server's Equip check.)
local function owns(base: BaseState?, slot: Slot, option: Option): boolean
	if option.unlock == "free" then
		return true
	end
	if slot == "pet" then
		return BasePanel.ownedPets(base)[option.value] == true
	end
	if option.cosmetic then
		return Store.hasCosmetic(option.cosmetic)
	end
	if option.collectible then
		return Store.hasCollectible(option.collectible)
	end
	return false
end

-- Display name key of an option: pets reuse "pet.<id>.name".
local function nameKey(slot: Slot, value: string): string
	if slot == "pet" and value ~= "none" then
		return "pet." .. value .. ".name"
	end
	return "wardrobe.item." .. slot .. "." .. value
end

function Wardrobe.new(root: Frame, _deps: Deps): WardrobeView
	local modal = Ui.modal(root, "Wardrobe", Z)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z
	backdrop.AutoButtonColor = false
	backdrop.Parent = modal

	local panel = Ui.panel(modal, {
		name = "Panel",
		size = UDim2.fromScale(0.94, 0.92),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.04,
		stroke = 4,
		strokeColor = ROLE.reward,
		aspect = PANEL_ASPECT,
		zindex = Z + 1,
	})
	panel.Active = true
	Ui.sheen(panel)

	Ui.icon(panel, Ui.Icons.wardrobe, {
		size = UDim2.fromScale(0.05, 0.08),
		position = UDim2.fromScale(0.025, 0.075),
		anchor = Vector2.new(0, 0.5),
		tint = ROLE.reward,
		zindex = Z + 2,
	})
	local title = Ui.label(panel, {
		name = "Title",
		size = UDim2.fromScale(0.3, 0.08),
		position = UDim2.fromScale(0.08, 0.075),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.reward,
		maxText = 36,
		zindex = Z + 2,
	})
	local hint = Ui.body(panel, {
		name = "Hint",
		size = UDim2.fromScale(0.5, 0.06),
		position = UDim2.fromScale(0.39, 0.075),
		anchor = Vector2.new(0, 0.5),
		textColor = ROLE.textDim,
		maxText = 18,
		minText = 8,
		zindex = Z + 2,
	})

	local function close()
		modal.Visible = false
	end
	backdrop.Activated:Connect(close)
	Ui.button(panel, {
		name = "Close",
		size = UDim2.fromScale(0.07, 0.09),
		position = UDim2.fromScale(0.975, 0.03),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 2,
	}, close)

	-- Slot rows ----------------------------------------------------------------------------------
	local ROWS_TOP = 0.15
	local ROW_H = 0.2
	local ROW_GAP = 0.012
	local TILE_X = 0.205
	local TILE_W = 0.152
	local TILE_GAP = 0.007

	type Tile = {
		slot: Slot,
		option: Option,
		button: TextButton,
		stroke: UIStroke,
		icon: ImageLabel?,
		preview: BasePanel.PetPreview?,
		lock: ImageLabel,
		check: ImageLabel,
		name: TextLabel,
		status: TextLabel,
	}
	local tiles: { Tile } = {}
	local slotLabels: { [Slot]: TextLabel } = {}
	-- Optimistic choice per slot until the server's next BaseState confirms it (or it times out).
	local pending: { [Slot]: { value: string, at: number } } = {}
	local lastPress = -math.huge
	local render: () -> () -- defined below the tiles

	local function shownValue(base: BaseState?, slot: Slot): string
		local choice = pending[slot]
		if choice and os.clock() - choice.at < PENDING_SECONDS then
			return choice.value
		end
		return equippedValue(base, slot)
	end

	for rowIndex, slotDef in SLOTS do
		local y = ROWS_TOP + (rowIndex - 1) * (ROW_H + ROW_GAP)
		local rowFrame = Ui.frame(panel, {
			name = `Slot_{slotDef.id}`,
			size = UDim2.fromScale(0.95, ROW_H),
			position = UDim2.fromScale(0.025, y),
			color = ROLE.background,
			transparency = 0.3,
			corner = 0.12,
			zindex = Z + 2,
		})
		-- Slot name with its icon on the left.
		Ui.icon(rowFrame, slotDef.icon, {
			name = "SlotIcon",
			size = UDim2.fromScale(0.07, 0.45),
			position = UDim2.fromScale(0.1, 0.06),
			anchor = Vector2.new(0.5, 0),
			tint = ROLE.reward,
			zindex = Z + 3,
		})
		slotLabels[slotDef.id] = Ui.label(rowFrame, {
			name = "SlotName",
			size = UDim2.fromScale(0.19, 0.36),
			position = UDim2.fromScale(0.1, 0.56),
			anchor = Vector2.new(0.5, 0),
			textColor = ROLE.reward,
			maxText = 22,
			minText = 8,
			zindex = Z + 3,
		})

		for index, option in slotDef.options do
			local tile: Tile
			local button = Ui.button(rowFrame, {
				name = `Option_{option.value}`,
				size = UDim2.fromScale(TILE_W, 0.88),
				position = UDim2.fromScale(TILE_X + (index - 1) * (TILE_W + TILE_GAP), 0.5),
				anchor = Vector2.new(0, 0.5),
				color = ROLE.panelRaised,
				corner = 0.14,
				stroke = 2,
				zindex = Z + 3,
			}, function()
				local base = getBase()
				if not owns(base, tile.slot, tile.option) or os.clock() - lastPress < PRESS_COOLDOWN then
					return
				end
				if shownValue(base, tile.slot) == tile.option.value then
					return
				end
				lastPress = os.clock()
				pending[tile.slot] = { value = tile.option.value, at = lastPress }
				local action: any = { type = "Equip", slot = tile.slot, value = tile.option.value }
				Store.send(action)
				render()
				task.delay(PENDING_SECONDS + 0.1, function()
					if modal.Visible then
						render()
					end
				end)
			end)
			local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
			local icon: ImageLabel? = nil
			local preview: BasePanel.PetPreview? = nil
			if option.icon then
				icon = Ui.icon(button, option.icon, {
					name = "Picture",
					size = UDim2.fromScale(0.7, 0.44),
					position = UDim2.fromScale(0.5, 0.06),
					anchor = Vector2.new(0.5, 0),
					tint = option.tint,
					zindex = Z + 4,
				})
			else
				preview = BasePanel.petPreview(button, option.value, {
					name = "Picture",
					size = UDim2.fromScale(0.9, 0.52),
					position = UDim2.fromScale(0.5, 0.03),
					anchor = Vector2.new(0.5, 0),
					zindex = Z + 4,
				})
			end
			local lock = Ui.icon(button, Ui.ICONS.lock, {
				name = "Lock",
				size = UDim2.fromScale(0.24, 0.24),
				position = UDim2.fromScale(0.95, 0.05),
				anchor = Vector2.new(1, 0),
				color = ROLE.background,
				corner = 0.5,
				aspect = 1,
				tint = ROLE.textDim,
				zindex = Z + 5,
			})
			local check = Ui.icon(button, Ui.ICONS.check, {
				name = "Check",
				size = UDim2.fromScale(0.24, 0.24),
				position = UDim2.fromScale(0.95, 0.05),
				anchor = Vector2.new(1, 0),
				color = ROLE.background,
				corner = 0.5,
				aspect = 1,
				tint = ROLE.good,
				zindex = Z + 5,
			})
			local name = Ui.label(button, {
				name = "Name",
				size = UDim2.fromScale(0.92, 0.22),
				position = UDim2.fromScale(0.5, 0.55),
				anchor = Vector2.new(0.5, 0),
				maxText = 18,
				minText = 7,
				zindex = Z + 4,
			})
			local status = Ui.body(button, {
				name = "Status",
				size = UDim2.fromScale(0.92, 0.18),
				position = UDim2.fromScale(0.5, 0.78),
				anchor = Vector2.new(0.5, 0),
				alignX = Enum.TextXAlignment.Center,
				textColor = ROLE.textDim,
				maxText = 14,
				minText = 7,
				zindex = Z + 4,
			})
			tile = {
				slot = slotDef.id,
				option = option,
				button = button,
				stroke = stroke,
				icon = icon,
				preview = preview,
				lock = lock,
				check = check,
				name = name,
				status = status,
			}
			table.insert(tiles, tile)
		end
	end

	render = function()
		local base = getBase()
		title.Text = Store.t("wardrobe.title")
		hint.Text = Store.t("wardrobe.hint")
		for slot, label in slotLabels do
			label.Text = Store.t("wardrobe.slot." .. slot)
		end
		for _, tile in tiles do
			local option = tile.option
			local owned = owns(base, tile.slot, option)
			local wearing = shownValue(base, tile.slot) == option.value
			tile.name.Text = Store.t(nameKey(tile.slot, option.value))
			tile.name.TextColor3 = if owned then ROLE.text else ROLE.textDim
			tile.lock.Visible = not owned
			tile.check.Visible = owned and wearing
			tile.button.AutoButtonColor = owned and not wearing
			tile.button.BackgroundColor3 = if wearing then PALETTE.nightLine else ROLE.panelRaised
			tile.stroke.Color = if wearing then ROLE.good elseif owned then ROLE.stroke else ROLE.background
			tile.stroke.Thickness = if wearing then 4 else 2
			local icon = tile.icon
			if icon then
				icon.ImageColor3 = if owned then option.tint else ROLE.stroke
			end
			local preview = tile.preview
			if preview then
				preview.setLocked(not owned)
			end
			if not owned then
				tile.status.Text = Store.t(UNLOCK_KEYS[option.unlock])
				tile.status.TextColor3 = ROLE.warning
			elseif wearing then
				tile.status.Text = Store.t("wardrobe.wearing")
				tile.status.TextColor3 = ROLE.good
			else
				tile.status.Text = Store.t("wardrobe.tap")
				tile.status.TextColor3 = ROLE.textDim
			end
		end
	end

	-- Spin the pet previews while the wardrobe is open.
	local spinConnection: RBXScriptConnection? = nil
	modal:GetPropertyChangedSignal("Visible"):Connect(function()
		if modal.Visible and spinConnection == nil then
			spinConnection = RunService.RenderStepped:Connect(function()
				local angle = 0.5 + math.sin(os.clock() * SPIN_SPEED) * 0.9
				for _, tile in tiles do
					if tile.preview then
						tile.preview.setAngle(angle)
					end
				end
			end)
		elseif not modal.Visible and spinConnection ~= nil then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end)

	Store.onChanged(function(kind: Store.ChangeKind)
		local name: string = kind
		if name == "base" then
			table.clear(pending) -- the server's answer wins (it may have refused the choice)
		end
		if modal.Visible and (name == "base" or name == "progress" or name == "language") then
			render()
		end
	end)

	local function open()
		modal.Visible = true
		render()
	end

	local function isOpen(): boolean
		return modal.Visible
	end

	render()
	return { open = open, close = close, isOpen = isOpen, render = render }
end

return Wardrobe
