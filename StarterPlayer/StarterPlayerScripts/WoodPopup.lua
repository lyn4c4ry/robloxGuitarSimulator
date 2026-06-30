-- @ScriptType: LocalScript
-- WoodPopup (LocalScript)
-- Floating "+X Wood" popup, no bar/box — just dynamic reward text.
-- Spawns at a random spot inside a center-screen zone, pops in from small
-- to big with a bouncy overshoot (Roblox-reward-style), then floats up
-- and fades out. Mirrors the popup behavior used by XPBar, but keeps the
-- warm wood color theme instead of XPBar's blue.
--
-- Listens to the "WoodGained" RemoteEvent fired by TreeChopHandler:
--   woodGained:FireClient(player, amount)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local woodGained = remoteEvents:WaitForChild("WoodGained")

local COLORS = {
	wood = Color3.fromRGB(196, 142, 72), -- warm wood tone, distinct from XPBar's blue
}

-- ===== Root GUI =====

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WoodPopup"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local popupLayer = Instance.new("Frame")
popupLayer.Name = "PopupLayer"
popupLayer.AnchorPoint = Vector2.new(0.5, 0.5)
popupLayer.Position = UDim2.new(0.5, 0, 0.5, 0)
popupLayer.Size = UDim2.new(0, 1, 0, 1)
popupLayer.BackgroundTransparency = 1
popupLayer.ZIndex = 5
popupLayer.Parent = screenGui

-- Same center-screen spawn zone shape as XPBar, offset slightly so XP and
-- Wood popups don't constantly overlap when both fire at once.
local POPUP_ZONE_X = 220
local POPUP_ZONE_Y_TOP = -40
local POPUP_ZONE_Y_BOTTOM = 130

local function randomPopupOffset()
	local x = math.random(-POPUP_ZONE_X, POPUP_ZONE_X)
	local y = math.random(POPUP_ZONE_Y_TOP, POPUP_ZONE_Y_BOTTOM)
	return UDim2.new(0.5, x, 0.5, y)
end

-- Spawns a single floating "+X Wood" popup at a random center-screen spot:
-- pops in (small -> big, bouncy), holds briefly, floats up while fading,
-- then destroys itself.
local function showWoodPopup(amount)
	local startPos = randomPopupOffset()

	local label = Instance.new("TextLabel")
	label.Name = "FloatingPopup"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = startPos
	label.Size = UDim2.new(0, 0, 0, 0) -- start tiny so the pop growth reads clearly
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextColor3 = COLORS.wood
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextTransparency = 1
	label.Text = "+" .. tostring(amount) .. " Wood"
	label.ZIndex = 5
	label.Parent = popupLayer

	local popIn = TweenService:Create(
		label,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 170, 0, 32), TextTransparency = 0 }
	)
	popIn:Play()

	task.delay(0.4, function()
		local floatOut = TweenService:Create(
			label,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = startPos + UDim2.new(0, 0, 0, -50), TextTransparency = 1 }
		)
		floatOut:Play()
		floatOut.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

woodGained.OnClientEvent:Connect(function(amount)
	showWoodPopup(amount)
end)