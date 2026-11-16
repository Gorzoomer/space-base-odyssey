--!strict
-- Space Base Odyssey - demo keys for testing and recording. Studio only (Stage 11: never in the live game):
--   F2: a meteorite lands near this player now, to scan with the tablet (DebugMeteor).
--   F3: finish the build in progress, or build the next structure free (DebugBuildNext). Stage 9: it
--       follows the habitat tree: everything the current base level allows, then the next base level.
--   F4: start an eclipse now (DebugEclipse).
--   F6: unlock every mission (DebugUnlockAll) and get just enough credits (every build level with the
--       habitat tiers, tool upgrade, gear level and pet) and XP for everything else (DebugMaxResources).
--   F7: grant the next hidden collectible this player does not own yet (DebugGrantCollectible).
--   F8: force today's event to a solar storm (the server accepts it in the lobby or while planning).
--   F9: end the current shift now.
--   Ctrl+Shift+C (Stage 10): play the start menu's cinematic shots full screen (every other screen
--       hidden) for recording; again to stop. On the start menu (its shots already play) it hides or
--       shows the menu instead. Ctrl+Shift+G: the cinematic grade on or off (Cinematic).
--   The same from a Studio command: set the player attribute SBO_Cinematic to "play", "grade" or
--   "off" on the server (attributes only replicate from the server, so players cannot set it).
-- Team playtest: Studio or Windows keep F1 (help), F5 (Play), F10, F11 (full screen) and F12 (screen
-- recording) before the game sees them, so those keys are not used. DebugResetBase has no key now.
-- No UI. The server validates every debug action again (Studio or place owner only). The cinematic
-- keys are client-only camera and look changes.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Store = require(script.Parent.Store)
local Cinematic = require(script.Parent.Cinematic)

local DemoKeys = {}

local started = false

local function allowed(): boolean
	-- Stage 11 (team, live game): the debug keys only exist in Roblox Studio.
	return RunService:IsStudio()
end

-- Stage 10: recording helpers (client only). The start menu's own shots (owner "menu") are never
-- stopped from here: its screen is only hidden or shown.
local DEBUG_OWNER = "debug"

local function startRecording()
	if not Cinematic.isPlaying() then
		Cinematic.playMenu({ cleanScreen = true, owner = DEBUG_OWNER })
	else
		Cinematic.setCleanScreen(true)
	end
end

local function stopRecording()
	if Cinematic.owner() == DEBUG_OWNER then
		Cinematic.stop()
	else
		Cinematic.setCleanScreen(false)
	end
end

local function toggleRecording()
	if Cinematic.isPlaying() and (Cinematic.owner() == DEBUG_OWNER or Cinematic.isCleanScreen()) then
		stopRecording()
	else
		startRecording()
	end
end

local function applyCinematicAttribute(value: any)
	if value == "play" then
		startRecording()
	elseif value == "grade" then
		Cinematic.setGrade(true)
	elseif value == "off" or value == nil then
		Cinematic.setGrade(false)
		stopRecording()
	end
end

function DemoKeys.start()
	if started or not allowed() then
		return
	end
	started = true
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("SBO_Cinematic"):Connect(function()
		applyCinematicAttribute(player:GetAttribute("SBO_Cinematic"))
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
		-- Ignore keys typed into a text box (chat). Other "processed" input still counts, because
		-- function keys may be marked as processed by the core scripts.
		if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() then
			return
		end
		local recordingCombo = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		if recordingCombo and input.KeyCode == Enum.KeyCode.C then
			toggleRecording()
		elseif recordingCombo and input.KeyCode == Enum.KeyCode.G then
			Cinematic.setGrade(not Cinematic.isGradeOn())
		elseif input.KeyCode == Enum.KeyCode.F8 then
			Store.send({ type = "DebugForceEvent", event = "SolarStorm" })
		elseif input.KeyCode == Enum.KeyCode.F9 then
			Store.send({ type = "DebugEndShift" })
		elseif input.KeyCode == Enum.KeyCode.F4 then
			local action: any = { type = "DebugEclipse" }
			Store.send(action)
		elseif input.KeyCode == Enum.KeyCode.F6 then
			local unlock: any = { type = "DebugUnlockAll" }
			Store.send(unlock)
			local resources: any = { type = "DebugMaxResources" }
			Store.send(resources)
		elseif input.KeyCode == Enum.KeyCode.F3 then
			local action: any = { type = "DebugBuildNext" }
			Store.send(action)
		elseif input.KeyCode == Enum.KeyCode.F2 then
			Store.send({ type = "DebugMeteor" })
		elseif input.KeyCode == Enum.KeyCode.F7 then
			for _, id in Store.COLLECTIBLES do
				if not Store.hasCollectible(id) then
					local action: any = { type = "DebugGrantCollectible", id = id }
					Store.send(action)
					break
				end
			end
		end
	end)
end

return DemoKeys
