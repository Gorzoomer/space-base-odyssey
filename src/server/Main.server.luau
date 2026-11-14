--!strict
-- Space Base Odyssey - server entry point.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Version = require(Shared:WaitForChild("Version"))

print(`[SpaceBaseOdyssey] server started, build {Version.BUILD}`)
