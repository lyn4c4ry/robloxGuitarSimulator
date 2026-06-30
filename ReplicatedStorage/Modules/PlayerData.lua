-- @ScriptType: ModuleScript
-- Stores player data on the server.
local PlayerData = {}
local data = {}

function PlayerData.Get(player)
	if not data[player] then
		data[player] = {
			Wood = 0,
			Money = 0,
			Guitar = 0,
		}
	end
	return data[player]
end

function PlayerData.AddWood(player, amount)
	local playerData = PlayerData.Get(player)
	playerData.Wood += amount
	return playerData.Wood
end

function PlayerData.GetWood(player)
	return PlayerData.Get(player).Wood
end

function PlayerData.RemoveWood(player, amount)
	local playerData = PlayerData.Get(player)
	if playerData.Wood < amount then
		return false
	end
	playerData.Wood -= amount
	return true
end

function PlayerData.AddMoney(player, amount)
	local playerData = PlayerData.Get(player)
	playerData.Money += amount
	return playerData.Money
end

function PlayerData.GetMoney(player)
	return PlayerData.Get(player).Money
end

function PlayerData.RemoveMoney(player, amount)
	local playerData = PlayerData.Get(player)
	if playerData.Money < amount then
		return false
	end
	playerData.Money -= amount
	return true
end

function PlayerData.AddGuitar(player, amount)
	local playerData = PlayerData.Get(player)
	playerData.Guitar += amount
	return playerData.Guitar
end

function PlayerData.GetGuitar(player)
	return PlayerData.Get(player).Guitar
end

function PlayerData.RemoveGuitar(player, amount)
	local playerData = PlayerData.Get(player)
	if playerData.Guitar < amount then
		return false
	end
	playerData.Guitar -= amount
	return true
end

function PlayerData.RemovePlayer(player)
	data[player] = nil
end

return PlayerData