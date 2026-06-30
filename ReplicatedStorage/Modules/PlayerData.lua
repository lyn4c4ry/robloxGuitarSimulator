-- @ScriptType: ModuleScript
-- Stores player data on the server.
local PlayerData = {}
local data = {}

-- ===== XP / Level config (adjustable) =====
local BASE_XP_REQUIRED = 20 -- XP needed to go from Level 1 to Level 2
local XP_REQUIRED_INCREASE = 10 -- extra XP required per additional level

local function getXPRequiredForLevel(level)
	return BASE_XP_REQUIRED + (level - 1) * XP_REQUIRED_INCREASE
end

function PlayerData.Get(player)
	if not data[player] then
		data[player] = {
			Wood = 0,
			Money = 0,
			Guitar = 0,
			XP = 0,
			Level = 1,
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

-- Adds XP and handles leveling up (including multiple level-ups in one call).
-- Returns a table describing each fill "step" so the client can animate the
-- bar filling up, flashing on level-up, and resetting for the next level.
--
-- Return shape:
-- {
--     steps = {
--         { level = 1, startXP = 10, endXP = 20, requiredXP = 20, leveledUp = true },
--         { level = 2, startXP = 0, endXP = 5, requiredXP = 30, leveledUp = false },
--     },
--     finalLevel = 2,
--     finalXP = 5,
--     finalRequiredXP = 30,
-- }
function PlayerData.AddXP(player, amount)
	local playerData = PlayerData.Get(player)
	local steps = {}

	local remainingXP = amount
	while remainingXP > 0 do
		local requiredForLevel = getXPRequiredForLevel(playerData.Level)
		local xpNeededToLevel = requiredForLevel - playerData.XP

		if remainingXP >= xpNeededToLevel then
			local startXP = playerData.XP
			table.insert(steps, {
				level = playerData.Level,
				startXP = startXP,
				endXP = requiredForLevel,
				requiredXP = requiredForLevel,
				leveledUp = true,
			})
			remainingXP -= xpNeededToLevel
			playerData.Level += 1
			playerData.XP = 0
		else
			local startXP = playerData.XP
			playerData.XP += remainingXP
			table.insert(steps, {
				level = playerData.Level,
				startXP = startXP,
				endXP = playerData.XP,
				requiredXP = requiredForLevel,
				leveledUp = false,
			})
			remainingXP = 0
		end
	end

	return {
		steps = steps,
		finalLevel = playerData.Level,
		finalXP = playerData.XP,
		finalRequiredXP = getXPRequiredForLevel(playerData.Level),
	}
end

function PlayerData.GetXP(player)
	return PlayerData.Get(player).XP
end

function PlayerData.GetLevel(player)
	return PlayerData.Get(player).Level
end

function PlayerData.GetXPRequiredForLevel(level)
	return getXPRequiredForLevel(level)
end

function PlayerData.RemovePlayer(player)
	data[player] = nil
end

return PlayerData