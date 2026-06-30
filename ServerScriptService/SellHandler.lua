-- @ScriptType: Script
-- SellHandler (ServerScript)
-- Handles selling Wood and Guitars from the shop UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local sellItems = remoteEvents:WaitForChild("SellItems")
local sellResult = remoteEvents:WaitForChild("SellResult")

local PRICES = {
	Wood = 2,    -- money per 1 Wood
	Guitar = 25, -- money per 1 Guitar
}

local function updateLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local woodValue = leaderstats:FindFirstChild("Wood")
	if woodValue then
		woodValue.Value = PlayerData.GetWood(player)
	end

	local moneyValue = leaderstats:FindFirstChild("Money")
	if moneyValue then
		moneyValue.Value = PlayerData.GetMoney(player)
	end
end

-- itemType: "Wood" or "Guitar"
-- amount: how many units to sell
sellItems.OnServerEvent:Connect(function(player, itemType, amount)
	if itemType ~= "Wood" and itemType ~= "Guitar" then
		sellResult:FireClient(player, false, "Unknown item.")
		return
	end

	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		sellResult:FireClient(player, false, "Invalid amount.")
		return
	end

	local removed
	if itemType == "Wood" then
		removed = PlayerData.RemoveWood(player, amount)
	else
		removed = PlayerData.RemoveGuitar(player, amount)
	end

	if not removed then
		sellResult:FireClient(player, false, "You don't have enough " .. itemType .. ".")
		return
	end

	local earned = amount * PRICES[itemType]
	local newMoney = PlayerData.AddMoney(player, earned)
	updateLeaderstats(player)

	sellResult:FireClient(player, true, "Sold!", newMoney)
end)