-- @ScriptType: Script
--[[
    RemoteEventsSetup.lua
    ServerScriptService/RemoteEventsSetup   (ServerScript)

    Ensures every Remote object the shop/inventory system needs actually
    exists under ReplicatedStorage.RemoteEvents. This removes the
    "Infinite yield possible on WaitForChild(...)" failure that happens
    when a Remote was never created in Studio: every other server/client
    script can safely WaitForChild on these because this script creates
    them immediately on server start.

    IMPORTANT: In Roblox, Script execution order between separate Scripts
    is not guaranteed by Studio's Explorer position - it's effectively
    parallel. To make sure this one runs first, this script does NOT wait
    on anything itself, so it always finishes within the same frame the
    server starts. Other scripts using WaitForChild will simply wait the
    few milliseconds needed instead of yielding forever.

    Safe to run multiple times - uses FindFirstChild checks so it never
    duplicates an existing Remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not RemoteEvents then
	RemoteEvents = Instance.new("Folder")
	RemoteEvents.Name = "RemoteEvents"
	RemoteEvents.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local existing = RemoteEvents:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy() -- wrong type with same name, replace it
	end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = RemoteEvents
	return re
end

local function ensureRemoteFunction(name)
	local existing = RemoteEvents:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	if existing then
		existing:Destroy() -- wrong type with same name, replace it
	end
	local rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = RemoteEvents
	return rf
end

ensureRemoteEvent("BuyItem")
ensureRemoteEvent("BuyResult")
ensureRemoteEvent("SellItems")
ensureRemoteEvent("SellResult")
ensureRemoteEvent("WoodGained")
ensureRemoteFunction("GetInventory")

print("[RemoteEventsSetup] All shop/inventory Remotes verified under ReplicatedStorage.RemoteEvents")