-- @ScriptType: Script
-- Creates leaderstats when a player joins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

local function onPlayerAdded(player)
	PlayerData.Get(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local wood = Instance.new("IntValue")
	wood.Name = "Wood"
	wood.Value = PlayerData.GetWood(player)
	wood.Parent = leaderstats

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = PlayerData.GetMoney(player)
	money.Parent = leaderstats
end

local function onPlayerRemoving(player)
	PlayerData.RemovePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
