--!strict
-- Space Base Odyssey - client entry point.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Version = require(Shared:WaitForChild("Version"))

print(`[SpaceBaseOdyssey] client started, build {Version.BUILD}`)
