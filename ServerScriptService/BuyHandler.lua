-- @ScriptType: Script
--[[
    BuyHandler.lua
    ServerScriptService/BuyHandler  (ServerScript)

    Listens to the "BuyItem" RemoteEvent, performs server-side validation for price 
    and AllowMultiple based on the ShopItems config (never trust the client), 
    deducts currency from PlayerData, and informs the player of the result via BuyResult.

    NOTE — PlayerData Integration:
    Your current PlayerData module currently holds Wood / Money / Guitar / XP / Level.
    Since the products in the Buy tab (TuningPegs, RareWoodPack, GuitarStrings...) are new
    inventory items, you need to add a general "Items" table to PlayerData. Below is a 
    minimal code example to be added to PlayerData.lua; if you share the PlayerData module 
    with me, I can directly implement the full integration there.

    -- Example to be added to PlayerData.lua (add to the default table inside Load() and the module):
    --
    -- default.Items = default.Items or {} -- { [itemId] = count }
    --
    -- function PlayerData.AddItem(player, itemId, amount)
    --     local data = PlayerData.Get(player)
    --     data.Items[itemId] = (data.Items[itemId] or 0) + amount
    --     scheduleSave(player)
    -- end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ShopItems = require(ReplicatedStorage.Modules.ShopItems)
local PlayerData = require(ReplicatedStorage.Modules.PlayerData) -- Your existing module

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BuyItemEvent = RemoteEvents:WaitForChild("BuyItem")
local BuyResultEvent = RemoteEvents:WaitForChild("BuyResult")

-- Id -> item config table for fast lookup
local ITEMS_BY_ID = {}
for _, item in ipairs(ShopItems) do
	ITEMS_BY_ID[item.Id] = item
end

BuyItemEvent.OnServerEvent:Connect(function(player, itemId, qty)
	local item = ITEMS_BY_ID[itemId]
	if not item then
		BuyResultEvent:FireClient(player, false, "Invalid item.")
		return
	end

	-- Quantity validation (never trust data coming from the client)
	if type(qty) ~= "number" or qty ~= math.floor(qty) or qty < 1 then
		BuyResultEvent:FireClient(player, false, "Invalid quantity.")
		return
	end

	if not item.AllowMultiple and qty > 1 then
		BuyResultEvent:FireClient(player, false, "Only 1 " .. (item.Name) .. " can be purchased at a time.")
		return
	end

	local totalCost = item.Price * qty

	-- Check if there is enough balance in PlayerData (if RemoveMoney returns false, it means insufficient funds)
	local success = PlayerData.RemoveMoney(player, totalCost)
	if not success then
		BuyResultEvent:FireClient(player, false, "Insufficient Money. Required: " .. totalCost)
		return
	end

	-- Add to inventory (requires adding the AddItem function to PlayerData, see the note above)
	if PlayerData.AddItem then
		PlayerData.AddItem(player, item.Id, qty)
	else
		warn("BuyHandler: PlayerData.AddItem function not found. Currency deducted but item could not be added to inventory! AddItem must be added to PlayerData.lua.")
	end

	BuyResultEvent:FireClient(player, true, ("Purchased %s x%d! (-%d Money)"):format(item.Name, qty, totalCost))
end)