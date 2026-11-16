--!strict
-- Space Base Odyssey - picture glossary card (Stage 11 "quests that teach", client side). The hard words
-- of src/shared/Glossary.luau ("habitat", "parts box", "solar panel", "oxygen", "radiation"...) are
-- painted gold and underlined in the quest tracker (Objectives.luau) and the achievement facts
-- (AchievementsPanel.luau). Tapping one opens this small card: the word's picture (a Tabler icon from
-- Icons.luau in a gold circle), the word and a one-line kid definition ("glossary.<id>.word" /
-- ".def", English and Spanish).
-- Matching (src/shared/Reading.luau findTerms): the word itself, a plural "s"/"es", and the extra
-- forms in "glossary.<id>.forms" when that key exists (Spanish "paneles solares", "cajas de piezas").
-- The card is a small modal ("GlossaryCard", z 60: above the Achievements panel, under the start menu
-- and Settings); a tap anywhere or the close button closes it. Read only: nothing is sent to the server.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Glossary = require(Shared:WaitForChild("Glossary"))
local Reading = require(Shared:WaitForChild("Reading"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local ROLE = Ui.ROLE

local Z = 60
local POP_SECONDS = 0.25

local GlossaryCard = {}

-- Every form of every glossary word in the current language (rebuilt on each call: 9 words).
function GlossaryCard.terms(): { Reading.Term }
	local list: { Reading.Term } = {}
	for _, term in Glossary.LIST do
		local word = Store.t(Glossary.wordKey(term.id))
		local formsKey = "glossary." .. term.id .. ".forms"
		local forms = Store.t(formsKey)
		for _, form in Reading.forms(word, if forms ~= formsKey then forms else nil) do
			table.insert(list, { id = term.id, word = form })
		end
	end
	return list
end

-- RichText for `text` with the glossary words painted gold, and the first word's id (nil = none).
function GlossaryCard.markup(text: string): (string, string?)
	local matches = Reading.findTerms(text, GlossaryCard.terms())
	local first = matches[1]
	return Reading.markup(text, matches, ROLE.star:ToHex()), if first then first.id else nil
end

type CardView = { open: (id: string) -> (), render: () -> () }
local card: CardView? = nil

-- Builds the card once under `root` (Objectives and AchievementsPanel call it; later calls do nothing).
function GlossaryCard.mount(root: Frame)
	if card ~= nil then
		return
	end
	local modal = Ui.modal(root, "GlossaryCard", Z)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z
	backdrop.AutoButtonColor = false
	backdrop.Parent = modal
	local function close()
		modal.Visible = false
	end
	backdrop.Activated:Connect(close)

	local panel = Ui.panel(modal, {
		name = "Panel",
		size = UDim2.fromScale(0.5, 0.36),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = ROLE.panel,
		corner = 0.1,
		stroke = 4,
		strokeColor = ROLE.star,
		aspect = 2.2,
		zindex = Z + 1,
	})
	panel.Active = true
	Ui.sheen(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	-- The picture: the word's icon in a big gold circle.
	local badge = Ui.frame(panel, {
		name = "Badge",
		size = UDim2.fromScale(0.3, 0.7),
		position = UDim2.fromScale(0.06, 0.5),
		anchor = Vector2.new(0, 0.5),
		color = ROLE.star,
		corner = 0.5,
		aspect = 1,
		zindex = Z + 2,
	})
	local icon = Ui.icon(badge, Ui.ICONS.book, {
		name = "Icon",
		size = UDim2.fromScale(0.64, 0.64),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = ROLE.primaryButtonText,
		zindex = Z + 3,
	})
	local header = Ui.label(panel, {
		name = "Header",
		size = UDim2.fromScale(0.5, 0.14),
		position = UDim2.fromScale(0.36, 0.1),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.textDim,
		font = Ui.BODY_FONT,
		maxText = 18,
		minText = 12,
		zindex = Z + 2,
	})
	Ui.oneLine(header)
	local word = Ui.label(panel, {
		name = "Word",
		size = UDim2.fromScale(0.58, 0.24),
		position = UDim2.fromScale(0.36, 0.25),
		alignX = Enum.TextXAlignment.Left,
		textColor = ROLE.star,
		maxText = 40,
		zindex = Z + 2,
	})
	Ui.oneLine(word)
	local definition = Ui.body(panel, {
		name = "Definition",
		size = UDim2.fromScale(0.58, 0.4),
		position = UDim2.fromScale(0.36, 0.52),
		textColor = ROLE.text,
		alignY = Enum.TextYAlignment.Top,
		maxText = 28,
		minText = 16,
		zindex = Z + 2,
	})
	Ui.button(panel, {
		name = "Close",
		size = UDim2.fromScale(0.1, 0.2),
		position = UDim2.fromScale(0.975, 0.06),
		anchor = Vector2.new(1, 0),
		color = Ui.COLORS.secondary,
		icon = Ui.ICONS.close,
		tint = ROLE.text,
		aspect = 1,
		zindex = Z + 3,
	}, close)

	local shownId: string? = nil
	local function render()
		local id = shownId
		local term = if id then Glossary.get(id) else nil
		if term == nil then
			return
		end
		header.Text = Store.t("ui.glossary.title")
		icon.Image = Ui.iconImage(term.icon)
		word.Text = Store.t(Glossary.wordKey(term.id))
		definition.Text = Store.t(Glossary.defKey(term.id))
	end

	local function open(id: string)
		if Glossary.get(id) == nil then
			return
		end
		shownId = id
		render()
		modal.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	Store.onChanged(function(kind: Store.ChangeKind)
		if kind == "language" and modal.Visible then
			render()
		end
	end)
	card = { open = open, render = render }
end

-- Opens the card for glossary word `id` (nothing happens before mount or for an unknown id).
function GlossaryCard.open(id: string)
	local view = card
	if view then
		view.open(id)
	end
end

return GlossaryCard
