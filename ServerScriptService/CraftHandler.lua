-- @ScriptType: Script
-- CraftHandler (ServerScript)
-- Handles guitar crafting requests from the client.
-- Currently supports one recipe: the Classic Acoustic Guitar.
-- All 5 parts use plain Wood for now; future guitars can require
-- different wood types once more tree types are added.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local craftGuitar = remoteEvents:WaitForChild("CraftGuitar")
local craftResult = remoteEvents:WaitForChild("CraftResult")

-- Recipe: total wood cost for one Classic Acoustic Guitar,
-- broken down by part for display purposes in the UI.
local CLASSIC_ACOUSTIC_RECIPE = {
	id = "ClassicAcoustic",
	name = "Classic Acoustic Guitar",
	parts = {
		{ name = "Body", wood = 5 },
		{ name = "Neck", wood = 3 },
		{ name = "Fretboard", wood = 2 },
		{ name = "Bridge", wood = 1 },
		{ name = "Tuning Pegs", wood = 1 },
	},
}

local function getTotalWoodCost(recipe)
	local total = 0
	for _, part in ipairs(recipe.parts) do
		total += part.wood
	end
	return total
end

local function updateLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local woodValue = leaderstats:FindFirstChild("Wood")
	if woodValue then
		woodValue.Value = PlayerData.GetWood(player)
	end
end

craftGuitar.OnServerEvent:Connect(function(player, recipeId)
	if recipeId ~= CLASSIC_ACOUSTIC_RECIPE.id then
		craftResult:FireClient(player, false, "Unknown recipe.")
		return
	end

	local totalCost = getTotalWoodCost(CLASSIC_ACOUSTIC_RECIPE)
	local currentWood = PlayerData.GetWood(player)

	if currentWood < totalCost then
		craftResult:FireClient(player, false, "Not enough wood.")
		return
	end

	local removed = PlayerData.RemoveWood(player, totalCost)
	if not removed then
		craftResult:FireClient(player, false, "Not enough wood.")
		return
	end

	local newGuitarCount = PlayerData.AddGuitar(player, 1)
	updateLeaderstats(player)

	craftResult:FireClient(player, true, "Guitar crafted!", newGuitarCount)
end)