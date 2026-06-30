-- @ScriptType: Script
--[[
    MerchantSetup.lua
    ServerScriptService/MerchantSetup  (ServerScript)

    Assumes there is an NPC Model named "Merchant" in the Workspace
    (PrimaryPart = HumanoidRootPart or Torso/UpperTorso).
    Adds a ProximityPrompt onto the NPC that opens the Shop panel
    when holding E (HoldDuration).

    SETUP:
    1. Place an NPC Model named "Merchant" in the Workspace (R15/R6 dummy, containing a Humanoid).
    2. Paste this script into ServerScriptService.
    3. ShopUI.lua (LocalScript) already listens to ProximityPromptService.PromptTriggered;
       since the prompt's Name is "OpenShopPrompt", it will automatically open the panel.
]]

local Workspace = game:GetService("Workspace")

local merchant = Workspace:WaitForChild("Merchant", 10)
if not merchant then
	warn("MerchantSetup: NPC named 'Merchant' could not be found in Workspace.")
	return
end

local rootPart = merchant.PrimaryPart or merchant:FindFirstChild("HumanoidRootPart") or merchant:FindFirstChild("Torso")
if not rootPart then
	warn("MerchantSetup: A suitable root part (PrimaryPart) could not be found in the Merchant NPC.")
	return
end

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "OpenShopPrompt"
prompt.ActionText = "Open"
prompt.ObjectText = "Shop"
prompt.HoldDuration = 0.6 -- Duration to hold E
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = rootPart