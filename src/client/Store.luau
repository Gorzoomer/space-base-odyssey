--!strict
-- Space Base Odyssey - client state: latest Snapshot and PlayerStats, chosen language and the Action sender.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local Types = require(Shared:WaitForChild("Types"))

export type Snapshot = Types.Snapshot
export type PlayerStats = Types.PlayerStats
export type TextRef = Types.TextRef
export type Action = Types.Action
export type Language = "en" | "es"
export type ChangeKind = "snapshot" | "stats" | "language"

local Store = {}

local snapshot: Snapshot? = nil
local stats: PlayerStats? = nil
local language: Language = "en"
local actionRemote: RemoteEvent? = nil
local listeners: { (kind: ChangeKind) -> () } = {}

local function emit(kind: ChangeKind)
	for _, listener in listeners do
		task.spawn(listener, kind)
	end
end

function Store.onChanged(listener: (kind: ChangeKind) -> ())
	table.insert(listeners, listener)
end

function Store.getSnapshot(): Snapshot?
	return snapshot
end

function Store.setSnapshot(value: Snapshot)
	snapshot = value
	emit("snapshot")
end

function Store.getStats(): PlayerStats?
	return stats
end

function Store.setStats(value: PlayerStats)
	stats = value
	emit("stats")
end

function Store.getLanguage(): Language
	return language
end

function Store.setLanguage(value: Language)
	language = value
	Localization.setLanguage(value)
	emit("language")
end

-- Translate a key in the current language.
function Store.t(key: string, params: { [string]: string | number }?): string
	return Localization.t(key, params, language)
end

function Store.setActionRemote(remote: RemoteEvent)
	actionRemote = remote
end

-- Send an Action to the server (ignored until the remote exists). The server validates everything.
function Store.send(action: Action)
	if actionRemote then
		actionRemote:FireServer(action)
	end
end

function Store.phase(): string
	return if snapshot then snapshot.phase else "Briefing"
end

return Store
