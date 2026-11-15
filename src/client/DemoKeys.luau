--!strict
-- Space Base Odyssey - demo keys for recording the video. Only in Studio or for the place owner:
--   F8: force today's event to a solar storm (the server accepts it in the lobby or while planning).
--   F9: end the current shift now.
--   F6: unlock every mission (DebugUnlockAll).
--   F7: grant the next hidden collectible this player does not own yet (DebugGrantCollectible).
--   F10: start an eclipse now (DebugEclipse).
--   F4: grant 100 credits (and the same XP) for testing the base (DebugGrantCredits).
--   F3: reset this player's base: builds, skills, credits and XP back to the start (DebugResetBase).
--   F2: a meteorite lands near this player now, to scan with the tablet (DebugMeteor, Stage 7).
--   F12 (or F11): finish the build in progress, or build the next structure in C.A.R.L.'s order, free
--     (DebugBuildNext). Not F1/F5: Studio keeps those keys (help page, Play) before the game sees them.
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
		elseif input.KeyCode == Enum.KeyCode.F10 then
			local action: any = { type = "DebugEclipse" }
			Store.send(action)
		elseif input.KeyCode == Enum.KeyCode.F6 then
			local action: any = { type = "DebugUnlockAll" }
			Store.send(action)
		elseif input.KeyCode == Enum.KeyCode.F4 then
			Store.send({ type = "DebugGrantCredits", amount = 100 })
		elseif input.KeyCode == Enum.KeyCode.F3 then
			Store.send({ type = "DebugResetBase" })
		elseif input.KeyCode == Enum.KeyCode.F2 then
			Store.send({ type = "DebugMeteor" })
		elseif input.KeyCode == Enum.KeyCode.F12 or input.KeyCode == Enum.KeyCode.F11 then
			local action: any = { type = "DebugBuildNext" }
			Store.send(action)
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
