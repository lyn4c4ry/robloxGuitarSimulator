-- @ScriptType: Script
-- Creates leaderstats when a player joins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

-- NEW: RemoteFunction so the client (XPBar) can ask "what's my actual
-- saved progress?" the moment it loads in, instead of always starting
-- from a hardcoded Level 1 / 0 XP display. This is what fixes XP/Level
-- appearing to reset on rejoin even though Wood/Money correctly persist —
-- Wood/Money were never wrong in the DataStore, the XP bar UI just never
-- asked the server for the real numbers on startup.
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local getPlayerProgress = remoteEvents:FindFirstChild("GetPlayerProgress")
if not getPlayerProgress then
	getPlayerProgress = Instance.new("RemoteFunction")
	getPlayerProgress.Name = "GetPlayerProgress"
	getPlayerProgress.Parent = remoteEvents
end

getPlayerProgress.OnServerInvoke = function(player)
	-- Safe to call even if PlayerAdded's Load already ran — PlayerData.Load
	-- only actually hits the DataStore once per player (it's a no-op after
	-- the first real load), so this just returns the already-loaded data.
	PlayerData.Load(player)
	return {
		Wood = PlayerData.GetWood(player),
		Money = PlayerData.GetMoney(player),
		Guitar = PlayerData.GetGuitar(player),
		XP = PlayerData.GetXP(player),
		Level = PlayerData.GetLevel(player),
		XPRequiredForLevel = PlayerData.GetXPRequiredForLevel(PlayerData.GetLevel(player)),
	}
end

local function onPlayerAdded(player)
	-- CHANGED: PlayerData.Load (not .Get) — this is what actually pulls the
	-- player's saved Wood/Money/Guitar/XP/Level from the DataStore (or
	-- starts them on defaults if they're new). Must happen before the
	-- leaderstats values below are filled in, otherwise the board would
	-- show 0s for a returning player for a moment.
	PlayerData.Load(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	-- Creation order alone does NOT guarantee leaderboard column order —
	-- Roblox's built-in leaderboard actually sorts alphabetically unless
	-- told otherwise. To force Level to always appear first (leftmost),
	-- we add a child BoolValue named "IsPrimary" set to true, which is
	-- the official way to pin a stat to the front regardless of name.
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = PlayerData.GetLevel(player)
	level.Parent = leaderstats

	local levelIsPrimary = Instance.new("BoolValue")
	levelIsPrimary.Name = "IsPrimary"
	levelIsPrimary.Value = true
	levelIsPrimary.Parent = level

	local wood = Instance.new("IntValue")
	wood.Name = "Wood"
	wood.Value = PlayerData.GetWood(player)
	wood.Parent = leaderstats
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = PlayerData.GetMoney(player)
	money.Parent = leaderstats
end
-- NOTE: PlayerRemoving (save + cleanup) and BindToClose (shutdown save)
-- are now handled INSIDE PlayerData.lua itself, so every script that
-- touches PlayerData gets the same save guarantee automatically. This
-- script no longer needs its own onPlayerRemoving — calling
-- PlayerData.RemovePlayer here too would just be a redundant no-op call
-- racing right after PlayerData's own handler already ran it.
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end