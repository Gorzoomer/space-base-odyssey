--!strict
-- Space Base Odyssey - "Real NASA data" panel: live/archived space-weather status, the real facts
-- behind the game (values from MissionData.REAL) and the text attribution of every source.
-- Opened from a small button on the Briefing, Planning and Report screens.
-- Never labels archived data as live: the live line only appears when the server's query succeeded.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionData = require(Shared:WaitForChild("MissionData"))
local SpaceWeatherArchive = require(Shared:WaitForChild("SpaceWeatherArchive"))

local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local REAL = MissionData.REAL

-- Layout inside the scrolling list, in reference units (the root UIScale maps them to the screen).
local ROW_HEIGHT = 60
local SOURCE_ROW_HEIGHT = 42
local ROW_GAP = 8
local LIST_PADDING = 12
local SCROLL_BAR = 16

local SOURCES_ICON = "🛰️"
local CLOSE_ICON = "✖️"
local SOURCE_ICON = "📚"

local Sources = {}

export type SourcesView = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	render: () -> (),
	-- Adds a "Real NASA data" button to a screen; size/position/anchor/zindex come from `props`.
	addButton: (parent: Instance, props: Ui.Props) -> TextButton,
}

-- Rounds to `decimals` places and drops trailing zeros: 0.895 -> "0.9", 16.5 -> "16.5", 33 -> "33".
-- Whole numbers of 1000 or more get a thousands comma (used in English and Mexican Spanish).
local function formatNumber(value: number, decimals: number): string
	local text = string.format(`%.{decimals}f`, value)
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	if not string.find(text, "%.") and math.abs(value) >= 1000 then
		local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
		text = string.gsub(formatted, "^(-?),", "%1")
	end
	return text
end

-- "2026-11-14T18:05Z" -> "2026-11-14 18:05 UTC" (the time of the server's live query).
local function queryTime(value: string): string
	local date, clock = string.match(value, "^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d)")
	if date and clock then
		return `{date} {clock} UTC`
	end
	return value
end

-- "2026-11-10T12:34Z" -> "2026-11-10". Anything else is shown unchanged.
local function shortDate(value: string?): string
	if type(value) ~= "string" then
		return ""
	end
	if string.match(value, "^%d%d%d%d%-%d%d%-%d%d") then
		return string.sub(value, 1, 10)
	end
	return value
end

type Fact = {
	key: string,
	icon: string,
	params: { [string]: string | number },
}

-- Moon gravity as a percent of Earth's, one decimal: 1.62 / 9.81 -> 16.5.
local gravityPercent = math.floor(REAL.MOON_GRAVITY_MS2 / REAL.EARTH_GRAVITY_MS2 * 1000 + 0.5) / 10

local FACTS: { Fact } = {
	{ key = "fact.gravity", icon = "🌙", params = { percent = formatNumber(gravityPercent, 1) } },
	{ key = "fact.light_delay", icon = "📡", params = { moon = formatNumber(REAL.MOON_EARTH_LIGHT_TIME_S, 1) } },
	{
		key = "fact.mars_delay",
		icon = "🔴",
		params = {
			min = formatNumber(REAL.MARS_LIGHT_TIME_MIN_MIN, 0),
			max = formatNumber(REAL.MARS_LIGHT_TIME_MAX_MIN, 0),
		},
	},
	{ key = "fact.oxygen", icon = "💨", params = { kg = formatNumber(REAL.O2_PER_CREW_KG_DAY, 1) } },
	{ key = "fact.water", icon = "💧", params = { kg = formatNumber(REAL.WATER_PER_CREW_KG_DAY, 1) } },
	{ key = "fact.food", icon = "🍎", params = { kcal = formatNumber(REAL.FOOD_KCAL_PER_DAY, 0) } },
	{ key = "fact.lettuce", icon = "🥬", params = { days = formatNumber(REAL.LETTUCE_DAYS_TO_HARVEST_ISS, 0) } },
	{ key = "fact.dose_moon", icon = "☢️", params = { msv = formatNumber(REAL.LUNAR_SURFACE_DOSE_MSV_DAY, 2) } },
	{ key = "fact.dose_earth", icon = "🌍", params = { msv = formatNumber(REAL.EARTH_SURFACE_DOSE_MSV_YEAR, 1) } },
	{ key = "fact.shelter", icon = "🛡️", params = {} },
	{ key = "fact.sep", icon = "⏱️", params = { min = formatNumber(REAL.SEP_ARRIVAL_MINUTES, 0) } },
	{
		key = "fact.sunlight",
		icon = "🌞",
		params = { days = formatNumber(REAL.SHACKLETON_RIM_SUNLIT_DAYS_PER_YEAR, 0) },
	},
	{ key = "fact.cold", icon = "❄️", params = { k = formatNumber(REAL.COLDEST_LUNAR_TEMP_K, 0) } },
	{ key = "fact.ice", icon = "🧊", params = { percent = formatNumber(REAL.LCROSS_WATER_ICE_PERCENT, 1) } },
	{ key = "fact.flare_vs_storm", icon = "☀️", params = {} },
	{ key = "fact.career_limit", icon = "🚀", params = { msv = formatNumber(REAL.CAREER_DOSE_LIMIT_MSV, 0) } },
}

local SOURCE_KEYS: { string } = {
	"src.donki",
	"src.bvad",
	"src.lro",
	"src.lcross",
	"src.veggie",
	"src.change4",
	"src.nasa_std",
	"src.nasa_science",
	"src.epa",
	"src.list",
}

type TextRow = {
	frame: Frame,
	icon: TextLabel,
	label: TextLabel,
	height: number,
}

function Sources.new(root: Frame): SourcesView
	-- Above every screen and the C.A.R.L. bubble (50); the language button (60) stays usable on top.
	local screen = Ui.frame(root, {
		name = "Sources",
		color = Ui.COLORS.backdrop,
		transparency = 0.04,
		zindex = 55,
		visible = false,
	})
	screen.Active = true -- blocks taps from reaching the screen underneath

	local title = Ui.label(screen, {
		name = "Title",
		size = UDim2.fromScale(0.6, 0.09),
		position = UDim2.fromScale(0.5, 0.02),
		anchor = Vector2.new(0.5, 0),
		textColor = Ui.COLORS.accent,
		maxText = 48,
		outline = true,
	})

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.fromScale(0.9, 0.7)
	list.Position = UDim2.fromScale(0.5, 0.12)
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.BackgroundColor3 = Ui.COLORS.panel
	list.BackgroundTransparency = 0.1
	list.BorderSizePixel = 0
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = SCROLL_BAR
	list.ScrollBarImageColor3 = Ui.COLORS.accent
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ZIndex = 2
	Ui.stroke(list, 3)
	list.Parent = screen

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, LIST_PADDING)
	padding.PaddingBottom = UDim.new(0, LIST_PADDING)
	padding.PaddingLeft = UDim.new(0, LIST_PADDING)
	padding.PaddingRight = UDim.new(0, LIST_PADDING + SCROLL_BAR)
	padding.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = list

	local rowCount = 0
	local allRows: { TextRow } = {}

	local function addRow(icon: string, height: number, color: Color3, textColor: Color3, maxText: number): TextRow
		rowCount += 1
		local frame = Ui.frame(list, {
			name = `Row{rowCount}`,
			size = UDim2.new(1, 0, 0, height),
			color = color,
			corner = 0.25,
			order = rowCount,
			zindex = 3,
		})
		local iconLabel = Ui.icon(frame, icon, {
			name = "Icon",
			size = UDim2.new(0, height - 8, 1, -8),
			position = UDim2.new(0, 6, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			maxText = 40,
			zindex = 4,
		})
		local label = Ui.label(frame, {
			name = "Text",
			size = UDim2.new(1, -(height + 14), 1, -8),
			position = UDim2.new(0, height + 4, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			alignX = Enum.TextXAlignment.Left,
			textColor = textColor,
			maxText = maxText,
			zindex = 4,
		})
		local row: TextRow = { frame = frame, icon = iconLabel, label = label, height = height }
		table.insert(allRows, row)
		return row
	end

	-- Space weather first: what the server knows right now, then the saved archive.
	local weatherStatus = addRow(SOURCES_ICON, ROW_HEIGHT, Ui.COLORS.panelLight, Ui.COLORS.accent, 28)
	local weatherChecked = addRow("🕒", ROW_HEIGHT, Ui.COLORS.panelLight, Ui.COLORS.text, 28)
	local weatherLatest = addRow("☀️", ROW_HEIGHT, Ui.COLORS.panelLight, Ui.COLORS.text, 28)
	local weatherArchive = addRow("💾", ROW_HEIGHT, Ui.COLORS.panelLight, Ui.COLORS.text, 28)

	local factRows: { [string]: TextRow } = {}
	for _, fact in FACTS do
		factRows[fact.key] = addRow(fact.icon, ROW_HEIGHT, Ui.COLORS.panelLight, Ui.COLORS.text, 28)
	end

	local sourceRows: { [string]: TextRow } = {}
	for _, key in SOURCE_KEYS do
		sourceRows[key] = addRow(SOURCE_ICON, SOURCE_ROW_HEIGHT, Ui.COLORS.panel, Ui.COLORS.textSoft, 22)
	end

	-- The canvas height is computed from the fixed row heights (AutomaticCanvasSize is unreliable
	-- under a UIScale).
	local function updateCanvas()
		local total = LIST_PADDING * 2
		local shown = 0
		for _, row in allRows do
			if row.frame.Visible then
				total += row.height
				shown += 1
			end
		end
		total += math.max(0, shown - 1) * ROW_GAP
		list.CanvasSize = UDim2.new(0, 0, 0, total)
	end

	local closeButton = Ui.button(screen, {
		name = "Close",
		size = UDim2.fromScale(0.32, 0.13),
		position = UDim2.fromScale(0.5, 0.845),
		anchor = Vector2.new(0.5, 0),
		color = Ui.COLORS.go,
		stroke = 4,
		maxText = 48,
		zindex = 2,
	}, function()
		screen.Visible = false
	end)

	local buttons: { TextButton } = {}

	local function renderWeather()
		local snap = Store.getSnapshot()
		local live: Store.LiveWeather? = if snap then snap.liveWeather else nil
		if live and live.status == "live" then
			weatherStatus.icon.Text = SOURCES_ICON
			weatherStatus.label.Text = Store.t("ui.weather_live", { n = live.flaresLast30Days or 0 })
			-- Live data always says when it was fetched.
			if live.fetchedAt then
				weatherChecked.frame.Visible = true
				weatherChecked.label.Text = Store.t("ui.weather_checked", { time = queryTime(live.fetchedAt) })
			else
				weatherChecked.frame.Visible = false
			end
			if live.latestClass and live.latestDate then
				weatherLatest.frame.Visible = true
				weatherLatest.label.Text =
					Store.t("ui.weather_latest", { class = live.latestClass, date = shortDate(live.latestDate) })
			else
				weatherLatest.frame.Visible = false
			end
		else
			-- Still fetching, HttpService off, or the request failed: say so, never pretend it is live.
			weatherStatus.icon.Text = "📦"
			weatherStatus.label.Text = Store.t("ui.weather_offline")
			weatherChecked.frame.Visible = false
			weatherLatest.frame.Visible = false
		end
		weatherArchive.label.Text = Store.t("ui.weather_archive", { date = SpaceWeatherArchive.DOWNLOADED })
		updateCanvas()
	end

	local function render()
		title.Text = `{SOURCES_ICON} {Store.t("ui.sources_title")}`
		closeButton.Text = `{CLOSE_ICON} {Store.t("ui.close")}`
		for _, button in buttons do
			button.Text = `{SOURCES_ICON} {Store.t("ui.sources_button")}`
		end
		for _, fact in FACTS do
			factRows[fact.key].label.Text = Store.t(fact.key, fact.params)
		end
		for _, key in SOURCE_KEYS do
			sourceRows[key].label.Text = Store.t(key)
		end
		renderWeather()
	end

	local function open()
		render()
		list.CanvasPosition = Vector2.zero
		screen.Visible = true
	end

	local function close()
		screen.Visible = false
	end

	local function isOpen(): boolean
		return screen.Visible
	end

	local function addButton(parent: Instance, props: Ui.Props): TextButton
		local withDefaults: Ui.Props = table.clone(props)
		withDefaults.name = props.name or "SourcesButton"
		withDefaults.color = props.color or Ui.COLORS.panelLight
		withDefaults.stroke = props.stroke or 3
		withDefaults.maxText = props.maxText or 24
		local button = Ui.button(parent, withDefaults, open)
		button.Text = `{SOURCES_ICON} {Store.t("ui.sources_button")}`
		table.insert(buttons, button)
		return button
	end

	render()
	return { open = open, close = close, isOpen = isOpen, render = render, addButton = addButton }
end

return Sources
