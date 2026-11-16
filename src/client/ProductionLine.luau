--!strict
-- Space Base Odyssey - Stage 11 tycoon: the ice line, animated on this client.
-- The server publishes the line as attributes of Workspace.Base.ProductionLine (WorldBuilder,
-- BaseService) and moves nothing itself; this module turns that state into motion, so a busy line
-- costs no network traffic:
--   * ice cubes ride the whole belt (BeltCount + Belt1..n: rim hopper -> rim -> over the slope ->
--     bucket lift -> silo top, then drop in) and each drill's lift belt (Lift<i>A/B). Their speed and
--     spacing follow SBO_IcePerMinute, so every drill upgrade is a busier, faster belt. The belt
--     stops while the silo is full (SBO_Status "full") and stays empty without drills ("off").
--   * drill bits spin around their rest pose (SBO_RestCFrame) at their drill's level speed
--     (SBO_Drill1..3; a bit with SBO_BitLevel above its drill's level stays still).
--   * the cargo robot drives its trip from SBO_CargoPhase / SBO_CargoAt / SBO_CargoSeconds along
--     Route1..n, with tanks on board (water = cyan, air = cream) while it carries a load.
--   * the air maker's fan turns and bubbles rise in its split tubes while it makes air.
-- Purely visual: credits come from the server (Remotes.LINE events; the "+N" pops and the "While you
-- were away" card are IncomePops.luau).
-- Stage 11 tycoon client: two world signs (local BillboardGuis) float over the silo and the water
-- plant while the camera is near: the silo's ice n/max, ice a minute and a status light; the plant's
-- product (water or air), credits a minute (BaseState.machineCreditsPerMinute; a guest sees "Your
-- friend's silo" instead) and its own status light. Each light has a short reason: running, silo
-- full (the belt stopped), the air maker needs power, or build a drill first (src/shared/
-- IceLineView.luau). A guest's copy of the silo prompt is switched off (the server refuses a guest's
-- claim anyway: "This is your friend's silo.").
-- Everything sleeps when the camera is far from the line.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local IceLineView = require(Shared:WaitForChild("IceLineView")) -- Stage 11 tycoon client
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local IncomePops = require(script.Parent.IncomePops)

local ProductionLine = {}

-- Visual tuning (not gameplay numbers: those are in MissionData.BASE).
local CUBE_SIZE = 0.9
local ICE_COLOUR = Color3.fromRGB(205, 236, 250)
local BELT_SPEED_BASE = 3 -- studs per second with one ice a minute ...
local BELT_SPEED_PER_ICE = 0.5 -- ... plus this much for every ice a minute
local CUBES_BASE = 3 -- cubes on the main belt: CUBES_BASE + CUBES_PER_ICE * ice a minute
local CUBES_PER_ICE = 2
local MAX_CUBES = 26
local LIFT_CUBES_PER_LEVEL = 2 -- cubes on a drill's lift belt per drill level
local DROP_STUDS = 5 -- after the silo top a cube falls this far into the silo while it fades
local DRILL_SPIN_RAD = { 3, 5, 8 } -- bit spin by drill level (radians per second)
local SETTLE_SECONDS = 1.6 -- after a drill's level changes its parts rise in; wait before spinning
local FAN_SPIN_RAD = 9
local BUBBLES_PER_TUBE = 3
local BUBBLE_SECONDS = 1.6
local AWAKE_RANGE = 320 -- the line animates while the camera is this close to it
local REFRESH_SECONDS = 1 -- models are looked up again this often (they come and go with builds)
local TURN_LERP = 0.25

type Path = { points: { Vector3 }, lengths: { number }, total: number }

local started = false
local folder: Folder? = nil
local cubeFolder: Folder? = nil
local mainCubes: { BasePart } = {}
local liftCubes: { { BasePart } } = { {}, {}, {} }
local bubbles: { BasePart } = {}
local beltPath: Path? = nil
local liftPaths: { Path? } = {}
local routePath: Path? = nil
local beltClock = 0
local liftClock = 0
local fanAngle = 0
local bubbleClock = 0
local drillAngle = { 0, 0, 0 }
local drillChangedAt = { 0, 0, 0 }
local drillLevelSeen = { -1, -1, -1 }
local refreshTimer = REFRESH_SECONDS
local awake = false
local warned = false -- one warning per visit if a step ever fails

-- Looked-up world parts (refreshed every REFRESH_SECONDS: unbuilt structures wait in ServerStorage).
local refs = {
	bits = {} :: { { root: BasePart, rest: CFrame, level: number, drill: number } },
	robot = nil :: BasePart?,
	robotRest = nil :: CFrame?,
	robotSeenAt = 0,
	loads = {} :: { BasePart },
	fan = nil :: BasePart?,
	fanRest = nil :: CFrame?,
	fanSeenAt = 0,
	tubes = {} :: { { foot: Vector3, height: number } },
}

local function makePath(points: { Vector3 }): Path?
	if #points < 2 then
		return nil
	end
	local lengths: { number } = {}
	local total = 0
	for i = 1, #points - 1 do
		local length = (points[i + 1] - points[i]).Magnitude
		lengths[i] = length
		total += length
	end
	if total <= 0 then
		return nil
	end
	return { points = points, lengths = lengths, total = total }
end

-- Position and unit direction at `distance` along the path.
local function along(path: Path, distance: number): (Vector3, Vector3)
	local d = math.clamp(distance, 0, path.total)
	for i, length in path.lengths do
		if d <= length or i == #path.lengths then
			local a, b = path.points[i], path.points[i + 1]
			local t = if length > 0 then math.clamp(d / length, 0, 1) else 0
			local dir = if length > 0 then (b - a) / length else Vector3.zAxis
			return a:Lerp(b, t), dir
		end
		d -= length
	end
	return path.points[1], Vector3.zAxis
end

local function readPoints(source: Instance, countName: string, prefix: string): { Vector3 }
	local points: { Vector3 } = {}
	local count = source:GetAttribute(countName)
	if type(count) ~= "number" then
		return points
	end
	for i = 1, count do
		local value = source:GetAttribute(prefix .. i)
		if typeof(value) == "Vector3" then
			table.insert(points, value)
		end
	end
	return points
end

local function attrNumber(name: string, fallback: number): number
	local f = folder
	local value = if f then f:GetAttribute(name) else nil
	return if type(value) == "number" and value == value then value else fallback
end

local function attrString(name: string, fallback: string): string
	local f = folder
	local value = if f then f:GetAttribute(name) else nil
	return if type(value) == "string" then value else fallback
end

local function newCube(parent: Instance, size: number): BasePart
	local cube = Instance.new("Part")
	cube.Name = "IceCube"
	cube.Size = Vector3.new(size, size, size)
	cube.Anchored = true
	cube.CanCollide = false
	cube.CanQuery = false
	cube.CanTouch = false
	cube.CastShadow = false
	cube.Material = Enum.Material.Ice
	cube.Color = ICE_COLOUR
	cube.Transparency = 1
	cube.Parent = parent
	return cube
end

local function newBubble(parent: Instance): BasePart
	local bubble = Instance.new("Part")
	bubble.Name = "AirBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(0.25, 0.25, 0.25)
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Material = Enum.Material.Neon
	bubble.Color = Theme.PALETTE.cream
	bubble.Transparency = 1
	bubble.Parent = parent
	return bubble
end

-- Keeps `list` at exactly `count` cubes (extra ones are hidden, never destroyed mid-frame).
local function poolTo(list: { BasePart }, count: number, size: number)
	local parent = cubeFolder
	if parent == nil then
		return
	end
	while #list < count do
		table.insert(list, newCube(parent, size))
	end
	for i, cube in list do
		if i > count then
			cube.Transparency = 1
		end
	end
end

-- Looks up the line folder, its paths and the moving parts again (cheap; once a second).
local function refresh()
	local base = Workspace:FindFirstChild("Base")
	local found = if base then base:FindFirstChild("ProductionLine") else nil
	if found == nil or not found:IsA("Folder") then
		folder = nil
		return
	end
	if folder ~= found then
		folder = found
		beltPath = makePath(readPoints(found, "BeltCount", "Belt"))
		routePath = makePath(readPoints(found, "RouteCount", "Route"))
		for i = 1, 3 do
			local a, b = found:GetAttribute("Lift" .. i .. "A"), found:GetAttribute("Lift" .. i .. "B")
			liftPaths[i] = if typeof(a) == "Vector3" and typeof(b) == "Vector3" then makePath({ a, b }) else nil
		end
	end
	local holder = base :: Instance
	-- Drill bits.
	local bits = {}
	local drills = holder:FindFirstChild("IceDrills")
	if drills then
		for i = 1, 3 do
			local drill = drills:FindFirstChild("IceDrill" .. i)
			if drill then
				for _, item in drill:GetChildren() do
					local rest = item:GetAttribute("SBO_RestCFrame")
					local level = item:GetAttribute("SBO_BitLevel")
					if item:IsA("BasePart") and typeof(rest) == "CFrame" then
						table.insert(bits, { root = item, rest = rest, level = if type(level) == "number" then level else 1, drill = i })
					end
				end
			end
		end
	end
	refs.bits = bits
	-- The cargo robot.
	local robot = holder:FindFirstChild("CargoRobot")
	local body = if robot then robot:FindFirstChild("Body") else nil
	local bodyRest = if body then body:GetAttribute("SBO_RestCFrame") else nil
	if body and body:IsA("BasePart") and typeof(bodyRest) == "CFrame" then
		if refs.robot ~= body then
			refs.robot = body
			refs.robotRest = bodyRest
			refs.robotSeenAt = os.clock() -- Stage 11 review: let its rise-in finish before driving it
			local loads = {}
			for _, item in (robot :: Instance):GetChildren() do
				if item:IsA("BasePart") and string.sub(item.Name, 1, 8) == "TankLoad" then
					table.insert(loads, item)
				end
			end
			refs.loads = loads
		end
	else
		refs.robot = nil
		refs.loads = {}
	end
	-- The air maker.
	local air = holder:FindFirstChild("AirMaker")
	local fan = if air then air:FindFirstChild("AirFan") else nil
	local fanRest = if fan then fan:GetAttribute("SBO_RestCFrame") else nil
	local fanPart = if fan and fan:IsA("BasePart") and typeof(fanRest) == "CFrame" then fan else nil
	if fanPart ~= refs.fan then
		refs.fanSeenAt = os.clock()
	end
	refs.fan = fanPart
	refs.fanRest = if typeof(fanRest) == "CFrame" then fanRest else nil
	local tubes = {}
	if air then
		for _, item in air:GetChildren() do
			local foot = item:GetAttribute("SBO_TubeFoot")
			local height = item:GetAttribute("SBO_TubeHeight")
			if typeof(foot) == "Vector3" and type(height) == "number" then
				table.insert(tubes, { foot = foot, height = height })
			end
		end
	end
	refs.tubes = tubes
end

local function hideAll()
	for _, cube in mainCubes do
		cube.Transparency = 1
	end
	for _, list in liftCubes do
		for _, cube in list do
			cube.Transparency = 1
		end
	end
	for _, bubble in bubbles do
		bubble.Transparency = 1
	end
end

-- The camera is near any part of the line.
local function isNear(): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	local eye = camera.CFrame.Position
	local path = beltPath
	if path then
		for _, point in { path.points[1], path.points[#path.points] } do
			if (eye - point).Magnitude <= AWAKE_RANGE then
				return true
			end
		end
	end
	local route = routePath
	if route and (eye - route.points[#route.points]).Magnitude <= AWAKE_RANGE then
		return true
	end
	return false
end

-- Main belt: cubes at even spacing, moving at the rate's speed; at the silo they drop in and fade.
local function animateBelt(dt: number, rate: number, running: boolean)
	local path = beltPath
	if path == nil or rate <= 0 then
		for _, cube in mainCubes do
			cube.Transparency = 1
		end
		return
	end
	local count = math.clamp(math.floor(CUBES_BASE + CUBES_PER_ICE * rate), 1, MAX_CUBES)
	poolTo(mainCubes, count, CUBE_SIZE)
	local speed = BELT_SPEED_BASE + BELT_SPEED_PER_ICE * rate
	if running then
		beltClock += dt * speed
	end
	local loop = path.total + DROP_STUDS
	local spacing = loop / count
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for k = 1, count do
		local cube = mainCubes[k]
		local d = (beltClock + (k - 1) * spacing) % loop
		local cf: CFrame
		if d <= path.total then
			local position, dir = along(path, d)
			cf = CFrame.lookAt(position, position + dir)
			cube.Transparency = 0
		else
			local fall = d - path.total
			local top = path.points[#path.points]
			cf = CFrame.new(top - Vector3.new(0, fall, 0)) * CFrame.Angles(fall, fall * 0.7, 0)
			cube.Transparency = math.clamp(fall / DROP_STUDS, 0, 1)
		end
		table.insert(parts, cube)
		table.insert(frames, cf)
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Each standing drill's lift belt (more cubes on a bigger drill).
local function animateLifts(dt: number, levels: { number }, running: boolean)
	if running then
		liftClock += dt
	end
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for i = 1, 3 do
		local list = liftCubes[i]
		local path = liftPaths[i]
		local level = levels[i] or 0
		if path == nil or level <= 0 then
			for _, cube in list do
				cube.Transparency = 1
			end
			continue
		end
		local count = math.clamp(LIFT_CUBES_PER_LEVEL * level, 1, 8)
		poolTo(list, count, CUBE_SIZE * 0.8)
		local speed = BELT_SPEED_BASE + DRILL_SPIN_RAD[math.clamp(level, 1, #DRILL_SPIN_RAD)] * 0.4
		local spacing = path.total / count
		for k = 1, count do
			local cube = list[k]
			local d = (liftClock * speed + (k - 1) * spacing) % path.total
			local position, dir = along(path, d)
			cube.Transparency = 0
			table.insert(parts, cube)
			table.insert(frames, CFrame.lookAt(position, position + dir))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function animateDrills(dt: number, levels: { number }, running: boolean)
	local now = os.clock()
	for i = 1, 3 do
		local level = levels[i] or 0
		if level ~= drillLevelSeen[i] then
			drillLevelSeen[i] = level
			drillChangedAt[i] = now
		end
		if running and level > 0 then
			drillAngle[i] = (drillAngle[i] + DRILL_SPIN_RAD[math.clamp(level, 1, #DRILL_SPIN_RAD)] * dt) % (2 * math.pi)
		end
	end
	for _, bit in refs.bits do
		local level = levels[bit.drill] or 0
		if level >= bit.level and now - drillChangedAt[bit.drill] >= SETTLE_SECONDS and bit.root.Parent then
			bit.root.CFrame = CFrame.new(bit.rest.Position) * CFrame.Angles(0, drillAngle[bit.drill], 0) * bit.rest.Rotation
		end
	end
end

-- The robot's pose from the server's trip phase.
local function animateRobot()
	local body = refs.robot
	local route = routePath
	if body == nil or route == nil or body.Parent == nil or os.clock() - refs.robotSeenAt < SETTLE_SECONDS then
		return
	end
	local phase = attrString("SBO_CargoPhase", "off")
	local at = attrNumber("SBO_CargoAt", 0)
	local seconds = math.max(0.1, attrNumber("SBO_CargoSeconds", 1))
	local now = Workspace:GetServerTimeNow()
	local t = math.clamp((now - at) / seconds, 0, 1)
	local distance = 0
	local forward = true
	local loaded = false
	if phase == "load" then
		loaded = t > 0.5
	elseif phase == "go" then
		distance = route.total * t
		loaded = true
	elseif phase == "drop" then
		distance = route.total
		loaded = t < 0.5
	elseif phase == "back" then
		distance = route.total * (1 - t)
		forward = false
	elseif phase == "loop" then
		-- Start menu showcase: there and back again, tanks on the way out.
		local drive = attrNumber("SBO_DriveSeconds", seconds)
		local cycle = 2 * drive + 2
		local s = (now - at) % cycle
		if s < drive then
			distance = route.total * (s / drive)
			loaded = true
		elseif s < drive + 1 then
			distance = route.total
		elseif s < 2 * drive + 1 then
			distance = route.total * (1 - (s - drive - 1) / drive)
			forward = false
		end
	end
	local position, dir = along(route, distance)
	local facing = if forward then dir else -dir
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.zAxis
	end
	local target = CFrame.lookAt(position, position + flat.Unit)
	body.CFrame = CFrame.new(position) * body.CFrame.Rotation:Lerp(target.Rotation, TURN_LERP)
	local product = attrString("SBO_CargoProduct", "water")
	local colour = if product == "oxygen" then Theme.PALETTE.cream else Theme.ROLE.accent
	for _, tank in refs.loads do
		tank.Transparency = if loaded then 0 else 1
		tank.Color = colour
	end
end

local function animateAir(dt: number, making: boolean)
	local fan = refs.fan
	local rest = refs.fanRest
	if fan and rest and fan.Parent and making and os.clock() - refs.fanSeenAt >= SETTLE_SECONDS then
		-- Stage 11 review: only while making air (a still fan is left to the server's rise-in).
		fanAngle = (fanAngle + FAN_SPIN_RAD * dt) % (2 * math.pi)
		fan.CFrame = rest * CFrame.Angles(0, fanAngle, 0)
	end
	local parent = cubeFolder
	local tubes = refs.tubes
	local want = if making and parent then #tubes * BUBBLES_PER_TUBE else 0
	while parent and #bubbles < want do
		table.insert(bubbles, newBubble(parent))
	end
	bubbleClock += dt
	for i, bubble in bubbles do
		if i > want then
			bubble.Transparency = 1
			continue
		end
		local tube = tubes[(i - 1) // BUBBLES_PER_TUBE + 1]
		local k = (i - 1) % BUBBLES_PER_TUBE
		local phase = ((bubbleClock / BUBBLE_SECONDS) + k / BUBBLES_PER_TUBE) % 1
		local wobble = math.sin((bubbleClock + i) * 6) * 0.12
		bubble.CFrame = CFrame.new(tube.foot + Vector3.new(wobble, 0.4 + phase * (tube.height - 0.8), 0))
		bubble.Transparency = 0.2 + 0.6 * phase
	end
end

local function step(dt: number)
	refreshTimer += dt
	if refreshTimer >= REFRESH_SECONDS then
		refreshTimer = 0
		refresh()
		awake = folder ~= nil and isNear()
		if not awake then
			hideAll()
		end
	end
	if not awake or folder == nil then
		return
	end
	local rate = attrNumber("SBO_IcePerMinute", 0)
	local status = attrString("SBO_Status", "off")
	local running = status == "run"
	local levels = { attrNumber("SBO_Drill1", 0), attrNumber("SBO_Drill2", 0), attrNumber("SBO_Drill3", 0) }
	animateBelt(dt, if status == "off" then 0 else rate, running)
	animateLifts(dt, levels, running)
	animateDrills(dt, levels, running)
	animateRobot()
	animateAir(dt, attrString("SBO_AirStatus", "off") == "run")
end

-- Stage 11 tycoon client: world signs over the silo and the water plant ---------------------------

local SIGN_SIZE = UDim2.fromScale(10, 4.4) -- studs (smaller far away, like a real sign)
local SIGN_MAX_DISTANCE = 140
local SIGN_REFRESH_SECONDS = 0.5
local SIGN_ABOVE_SILO = 5.5 -- studs above the silo glass top
local SIGN_ABOVE_PLANT = 4.5 -- studs above the melter roof
local SIGN_PULSE_SPEED = 5 -- the full / no power stroke pulses (unless motion is reduced)
local LIGHT_COLOURS: { [string]: Color3 } = {
	run = Theme.ROLE.good,
	full = Theme.ROLE.danger,
	nopower = Theme.ROLE.warning,
	off = Theme.ROLE.stroke,
}

type Sign = {
	anchor: Attachment,
	gui: BillboardGui,
	stroke: UIStroke?,
	topIcon: ImageLabel,
	topText: TextLabel,
	midIcon: ImageLabel,
	midText: TextLabel,
	light: Frame,
	reason: TextLabel,
	alert: boolean,
}

local signs: { silo: Sign?, plant: Sign? } = {}
local signTimer = SIGN_REFRESH_SECONDS
local hiddenPrompt: ProximityPrompt? = nil -- the silo prompt this client switched off (a guest)

local function makeSign(name: string): Sign
	local anchor = Instance.new("Attachment")
	anchor.Name = "SBO_" .. name .. "SignPoint"
	anchor.Parent = Workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Name = name .. "Sign"
	gui.Adornee = anchor
	gui.Size = SIGN_SIZE
	gui.LightInfluence = 0
	gui.MaxDistance = SIGN_MAX_DISTANCE
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = anchor
	local panel = Ui.panel(gui, {
		name = "Panel",
		size = UDim2.fromScale(1, 1),
		color = Theme.ROLE.panel,
		transparency = 0.12,
		corner = 0.14,
		stroke = 2,
		strokeColor = Theme.ROLE.accent,
	})
	local function row(y: number, iconName: string): (ImageLabel, TextLabel)
		local icon = Ui.icon(panel, iconName, {
			name = "Icon",
			size = UDim2.fromScale(0.16, 0.26),
			position = UDim2.fromScale(0.04, y),
			anchor = Vector2.new(0, 0.5),
			tint = Theme.ROLE.text,
			zindex = 2,
		})
		local text = Ui.label(panel, {
			name = "Text",
			size = UDim2.fromScale(0.76, 0.27),
			position = UDim2.fromScale(0.21, y),
			anchor = Vector2.new(0, 0.5),
			alignX = Enum.TextXAlignment.Left,
			textColor = Theme.ROLE.text,
			maxText = 40,
			minText = 6,
			zindex = 2,
		})
		return icon, text
	end
	local topIcon, topText = row(0.2, Ui.Icons.silo)
	local midIcon, midText = row(0.5, Ui.Icons.ice)
	-- The status light: a round lamp (colour) and its short reason (text, so colour is not the only cue).
	local light = Ui.frame(panel, {
		name = "Light",
		size = UDim2.fromScale(0.1, 0.18),
		position = UDim2.fromScale(0.07, 0.8),
		anchor = Vector2.new(0, 0.5),
		color = LIGHT_COLOURS.off,
		corner = 0.5,
		aspect = 1,
		stroke = 2,
		strokeColor = Theme.ROLE.background,
		zindex = 2,
	})
	local reason = Ui.body(panel, {
		name = "Reason",
		size = UDim2.fromScale(0.76, 0.24),
		position = UDim2.fromScale(0.21, 0.8),
		anchor = Vector2.new(0, 0.5),
		textColor = Theme.ROLE.textDim,
		maxText = 32,
		minText = 6,
		zindex = 2,
	})
	return {
		anchor = anchor,
		gui = gui,
		stroke = panel:FindFirstChildOfClass("UIStroke"),
		topIcon = topIcon,
		topText = topText,
		midIcon = midIcon,
		midText = midText,
		light = light,
		reason = reason,
		alert = false,
	}
end

local function showStatus(sign: Sign, status: IceLineView.SignStatus)
	sign.light.BackgroundColor3 = LIGHT_COLOURS[status.light] or LIGHT_COLOURS.off
	sign.reason.Text = Store.t(status.reasonKey)
	sign.alert = status.light == "full" or status.light == "nopower"
	local stroke = sign.stroke
	if stroke and not sign.alert then
		stroke.Color = Theme.ROLE.accent
		stroke.Transparency = 0
	end
end

-- Top of a model's part (the plant's melter roof), else the model's bounding box top.
local function topOf(model: Instance, partName: string): Vector3?
	local named = model:FindFirstChild(partName, true)
	if named and named:IsA("BasePart") then
		return named.Position + Vector3.new(0, named.Size.Y / 2, 0)
	end
	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return nil
end

-- The silo prompt: a guest's local copy is switched off; given back when this player owns the silo.
local function guardSiloPrompt(silo: Instance?, owner: boolean)
	local found = if silo then silo:FindFirstChild("SiloPrompt", true) else nil
	local prompt: ProximityPrompt? = if found and found:IsA("ProximityPrompt") then found :: ProximityPrompt else nil
	if prompt and not owner then
		if prompt.Enabled then
			prompt.Enabled = false
		end
		hiddenPrompt = prompt
	elseif hiddenPrompt ~= nil then
		local was = hiddenPrompt
		hiddenPrompt = nil
		if was.Parent ~= nil and not was.Enabled then
			was.Enabled = Store.buildLevel("drill_1") >= 1 -- the server's own rule (BaseService)
		end
	end
end

local function hideSigns()
	for _, sign in { signs.silo, signs.plant } do
		if sign then
			sign.gui.Enabled = false
		end
	end
end

local function updateSigns()
	local base = Workspace:FindFirstChild("Base")
	local silo = if base then base:FindFirstChild("IceSilo") else nil
	local plant = if base then base:FindFirstChild("WaterPlant") else nil
	local owner = IncomePops.isSiloOwner()
	guardSiloPrompt(silo, owner)
	local f = folder
	-- Only in the player's own game (not the start menu's showcase base) and near the line.
	if f == nil or not awake or Workspace:GetAttribute("SBO_Showcase") == true or not Store.isSlotChosen() then
		hideSigns()
		return
	end
	local line = IncomePops.lineState()
	local info: IceLineView.LineInfo = {
		lineStatus = attrString("SBO_Status", line.lineStatus or "off"),
		airStatus = attrString("SBO_AirStatus", line.airStatus or "off"),
		icePerMinute = attrNumber("SBO_IcePerMinute", line.icePerMinute or 0),
	}
	-- The silo: ice n/max, ice a minute, the belt's light.
	local centre = f:GetAttribute("SiloCentre")
	if silo and typeof(centre) == "Vector3" then
		local sign = signs.silo or makeSign("Silo")
		signs.silo = sign
		local top = attrNumber("SiloBottomY", centre.Y) + attrNumber("SiloHeight", 14)
		sign.anchor.WorldPosition = Vector3.new(centre.X, top + SIGN_ABOVE_SILO, centre.Z)
		local state = Store.getBase()
		local ice = math.floor(attrNumber("SBO_SiloIce", if state then state.siloIce else 0))
		local max = math.floor(attrNumber("SBO_SiloMax", if state then state.siloMax else 0))
		Ui.setIcon(sign.topIcon, Ui.Icons.silo, Ui.COLORS.ice)
		sign.topText.Text = Store.t("ui.line.ice", { n = ice, max = max })
		sign.topText.TextColor3 = if max > 0 and ice >= max then Theme.ROLE.star else Theme.ROLE.text
		Ui.setIcon(sign.midIcon, Ui.Icons.drill, Theme.ROLE.textDim)
		sign.midText.Text = Store.t("ui.line.rate", { n = IceLineView.formatRate(info.icePerMinute or 0) })
		showStatus(sign, IceLineView.siloStatus(info))
		sign.gui.Enabled = true
	elseif signs.silo then
		(signs.silo :: Sign).gui.Enabled = false
	end
	-- The water plant: what it makes, credits a minute (the owner's), the plant's light.
	local plantTop = if plant then topOf(plant, "MelterRoof") else nil
	if plant and plantTop then
		local sign = signs.plant or makeSign("Plant")
		signs.plant = sign
		sign.anchor.WorldPosition = plantTop + Vector3.new(0, SIGN_ABOVE_PLANT, 0)
		local oxygen = attrString("SBO_Product", line.product or "water") == "oxygen"
		Ui.setIcon(sign.topIcon, if oxygen then Ui.ICONS.air else Ui.ICONS.drop, Theme.ROLE.accent)
		sign.topText.Text = Store.t(if oxygen then "ui.line.air" else "ui.line.water")
		sign.topText.TextColor3 = Theme.ROLE.text
		if owner then
			Ui.setIcon(sign.midIcon, Ui.Icons.coin, Theme.ROLE.star)
			sign.midText.Text = Store.t("ui.line.credits", { n = IceLineView.formatRate(IncomePops.machineRate()) })
			sign.midText.TextColor3 = Theme.ROLE.star
		else
			Ui.setIcon(sign.midIcon, Ui.ICONS.home, Theme.ROLE.textDim)
			sign.midText.Text = Store.t("ui.line.friend_silo")
			sign.midText.TextColor3 = Theme.ROLE.textDim
		end
		showStatus(sign, IceLineView.plantStatus(info))
		sign.gui.Enabled = true
	elseif signs.plant then
		(signs.plant :: Sign).gui.Enabled = false
	end
end

-- A full silo or a plant without power: the sign's border pulses (still when motion is reduced).
local function pulseSigns()
	local still = IncomePops.reduceMotion()
	local wave = (math.sin(os.clock() * SIGN_PULSE_SPEED) + 1) / 2
	for _, sign in { signs.silo, signs.plant } do
		local stroke = if sign then sign.stroke else nil
		if sign and stroke and sign.alert and sign.gui.Enabled then
			stroke.Color = sign.light.BackgroundColor3
			stroke.Transparency = if still then 0 else 0.5 * wave
		end
	end
end

local function signStep(dt: number)
	signTimer += dt
	if signTimer >= SIGN_REFRESH_SECONDS then
		signTimer = 0
		updateSigns()
	end
	pulseSigns()
end

-- Starts the animation (once). Cubes and bubbles live in a client-only folder in Workspace.
function ProductionLine.start()
	if started then
		return
	end
	started = true
	local holder = Instance.new("Folder")
	holder.Name = "SBO_IceLineLocal"
	holder.Parent = Workspace
	cubeFolder = holder
	local signWarned = false
	RunService.RenderStepped:Connect(function(rawDt: number)
		local ok, err = pcall(step, math.min(rawDt, 0.1))
		if not ok then
			awake = false
			if not warned then
				warned = true
				warn(`[SpaceBaseOdyssey] ProductionLine step failed: {err}`)
			end
		end
		-- Stage 11 tycoon client: the world signs (their own pcall: a sign never stops the line).
		local signOk, signErr = pcall(signStep, math.min(rawDt, 0.1))
		if not signOk and not signWarned then
			signWarned = true
			warn(`[SpaceBaseOdyssey] ProductionLine signs failed: {signErr}`)
		end
	end)
end

return ProductionLine
