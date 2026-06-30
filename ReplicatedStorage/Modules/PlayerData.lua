-- @ScriptType: ModuleScript
-- Stores player data on the server, now backed by DataStoreService so
-- progress (Wood, Money, Guitar, XP, Level) survives the player leaving,
-- crashing, Alt+F4ing, or the server shutting down.
--
-- USAGE NOTE for other scripts:
-- Call PlayerData.Load(player) once, as early as possible, when a player
-- joins (e.g. in the same script that sets up leaderstats), BEFORE any
-- other PlayerData function is used for that player. Everything else
-- (Add*/Get*/Remove*) works exactly like before — no other script needs
-- to change.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

local PlayerData = {}
local data = {}

-- Tracks whether a player's data has finished loading, so other scripts
-- (or PlayerData itself) don't accidentally save a blank/default profile
-- over real saved data if something races ahead of Load().
local loaded = {}

-- ===== XP / Level config (adjustable) =====
local BASE_XP_REQUIRED = 20 -- XP needed to go from Level 1 to Level 2
local XP_REQUIRED_INCREASE = 10 -- extra XP required per additional level
local function getXPRequiredForLevel(level)
	return BASE_XP_REQUIRED + (level - 1) * XP_REQUIRED_INCREASE
end

-- ===== Defaults =====

local function defaultData()
	return {
		Wood = 0,
		Money = 0,
		Guitar = 0,
		XP = 0,
		Level = 1,
		Items = {},
	}
end

-- ===== Save debouncing =====
-- Saving on every single Add*/Remove* call would hammer the DataStore
-- (Roblox enforces request budgets/limits per key per minute). Instead,
-- each change marks the player as "dirty" and schedules a single save a
-- few seconds later; if more changes come in before that fires, they all
-- ride along on the same save instead of queuing up more requests.
local SAVE_DEBOUNCE_SECONDS = 5
local pendingSave = {} -- [player] = true while a debounced save is scheduled
local saving = {} -- [player] = true while an actual DataStore write is in flight

local function doSave(player)
	if not loaded[player] then
		return -- never got real data in, don't overwrite a saved profile with defaults
	end
	local playerData = data[player]
	if not playerData then
		return
	end

	saving[player] = true
	local success, err = pcall(function()
		playerStore:SetAsync("Player_" .. player.UserId, playerData)
	end)
	saving[player] = false

	if not success then
		warn("[PlayerData] Failed to save data for", player.Name, ":", err)
	end
end

local function scheduleSave(player)
	if pendingSave[player] then
		return -- a save is already scheduled, the upcoming write will include this change
	end
	pendingSave[player] = true
	task.delay(SAVE_DEBOUNCE_SECONDS, function()
		pendingSave[player] = nil
		-- player may have left while we were waiting; only save if they're
		-- still around (PlayerRemoving/BindToClose handle the leave-save)
		if player.Parent then
			doSave(player)
		end
	end)
end

-- ===== Load / Save (public) =====

-- Loads a player's saved data from the DataStore, or starts them off with
-- defaults if this is their first time playing (or the DataStore has
-- nothing for them). Safe to call multiple times; only loads once.
function PlayerData.Load(player)
	if loaded[player] then
		return data[player]
	end

	local loadedData
	local success, err = pcall(function()
		loadedData = playerStore:GetAsync("Player_" .. player.UserId)
	end)

	if not success then
		warn("[PlayerData] Failed to load data for", player.Name, ":", err)
	end

	local playerData = defaultData()
	if success and loadedData then
		-- Merge saved fields over the defaults so that adding a brand new
		-- stat later (like Level was, or Guitar before it) doesn't break
		-- existing save files that predate that field.
		for key, value in pairs(loadedData) do
			playerData[key] = value
		end
	end
	
	if type(playerData.Items) ~= "table" then
		playerData.Items = {}
	end
	
	data[player] = playerData
	loaded[player] = true
	return playerData
end

-- Immediately (synchronously, via pcall) saves a player's current data.
-- Used on PlayerRemoving and inside BindToClose, where we need the save
-- to actually happen before the script/server shuts down.
function PlayerData.Save(player)
	doSave(player)
end

function PlayerData.Get(player)
	if not data[player] then
		-- Fallback: something used PlayerData before Load() ran (e.g. a
		-- script that doesn't know about the new Load step yet). Better to
		-- hand back working defaults than to error, but this player's
		-- progress won't be tied to their saved file until Load() runs.
		data[player] = defaultData()
	end
	return data[player]
end

function PlayerData.AddWood(player, amount)
	local playerData = PlayerData.Get(player)
	playerData.Wood += amount
	scheduleSave(player)
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
	scheduleSave(player)
	return true
end

function PlayerData.AddMoney(player, amount)
	local playerData = PlayerData.Get(player)
	playerData.Money += amount
	scheduleSave(player)
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
	scheduleSave(player)
	return true
end

function PlayerData.AddGuitar(player, amount)
	local playerData = PlayerData.Get(player)
	playerData.Guitar += amount
	scheduleSave(player)
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
	scheduleSave(player)
	return true
end

-- ===== Generic Items inventory (used by Shop Buy/Sell) =====

function PlayerData.AddItem(player, itemId, amount)
	amount = amount or 1
	local playerData = PlayerData.Get(player)
	playerData.Items[itemId] = (playerData.Items[itemId] or 0) + amount
	scheduleSave(player)
	return playerData.Items[itemId]
end

function PlayerData.GetItemCount(player, itemId)
	local playerData = PlayerData.Get(player)
	return playerData.Items[itemId] or 0
end

function PlayerData.GetItems(player)
	-- Returns the full inventory table: { [itemId] = count, ... }
	return PlayerData.Get(player).Items
end

function PlayerData.RemoveItem(player, itemId, amount)
	amount = amount or 1
	local playerData = PlayerData.Get(player)
	local current = playerData.Items[itemId] or 0
	if current < amount then
		return false
	end
	local newCount = current - amount
	if newCount <= 0 then
		playerData.Items[itemId] = nil
	else
		playerData.Items[itemId] = newCount
	end
	scheduleSave(player)
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
	scheduleSave(player)
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
	loaded[player] = nil
	pendingSave[player] = nil
	saving[player] = nil
end

-- ===== Automatic save-on-leave and save-on-shutdown =====
-- These two hooks are the actual fix for "Alt+F4 resets my progress":
-- 1) PlayerRemoving fires for a normal leave (closing the tab, walking out
--    via Alt+F4, getting kicked, etc.) — we force an immediate save here
--    before RemovePlayer wipes the in-memory copy.
-- 2) BindToClose fires when the whole server is shutting down (e.g. the
--    last player leaves, or Roblox is restarting the server for an
--    update) — we save EVERY currently-connected player's data and make
--    Roblox wait for it before actually closing the server.

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Save(player)
	PlayerData.RemovePlayer(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.Save(player)
	end
end)

return PlayerData