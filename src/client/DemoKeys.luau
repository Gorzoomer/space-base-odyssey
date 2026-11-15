--!strict
-- Space Base Odyssey - demo keys for testing and recording. Only in Studio or for the place owner:
--   F2: a meteorite lands near this player now, to scan with the tablet (DebugMeteor).
--   F3: finish the build in progress, or build the next structure in C.A.R.L.'s order, free
--       (DebugBuildNext).
--   F4: start an eclipse now (DebugEclipse).
--   F6: unlock every mission (DebugUnlockAll) and get just enough credits and XP to unlock everything
--       else (DebugMaxResources).
--   F7: grant the next hidden collectible this player does not own yet (DebugGrantCollectible).
--   F8: force today's event to a solar storm (the server accepts it in the lobby or while planning).
--   F9: end the current shift now.
-- Team playtest: Studio or Windows keep F1 (help), F5 (Play), F10, F11 (full screen) and F12 (screen
-- recording) before the game sees them, so those keys are not used. DebugResetBase has no key now.
-- No UI. The server validates every debug action again (Studio or place owner only).
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Store = require(script.Parent.Store)

local DemoKeys = {}

local started = false

local function allowed(): boolean
	return RunService:IsStudio() or Players.LocalPlayer.UserId == game.CreatorId
end

function DemoKeys.start()
	if started or not allowed() then
		return
	end
	started = true
	UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
		-- Ignore keys typed into a text box (chat). Other "processed" input still counts, because
		-- function keys may be marked as processed by the core scripts.
		if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.F8 then
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
