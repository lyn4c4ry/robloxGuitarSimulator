-- @ScriptType: LocalScript
-- StationUI (LocalScript)
-- Shows the Shop or Craft panel when the player enters the matching zone,
-- and hides it when they leave. Talks to the server through RemoteEvents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local zoneEntered = remoteEvents:WaitForChild("ZoneEntered")
local zoneLeft = remoteEvents:WaitForChild("ZoneLeft")
local craftGuitar = remoteEvents:WaitForChild("CraftGuitar")
local craftResult = remoteEvents:WaitForChild("CraftResult")
local sellItems = remoteEvents:WaitForChild("SellItems")
local sellResult = remoteEvents:WaitForChild("SellResult")

-- ===== Recipe data (must match CraftHandler) =====

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

-- ===== Theme =====

local COLORS = {
	background = Color3.fromRGB(28, 24, 20),
	panel = Color3.fromRGB(40, 34, 28),
	accent = Color3.fromRGB(196, 142, 72), -- warm wood tone
	accentDark = Color3.fromRGB(150, 105, 50),
	text = Color3.fromRGB(245, 240, 232),
	subtext = Color3.fromRGB(180, 170, 160),
	success = Color3.fromRGB(120, 200, 140),
	fail = Color3.fromRGB(210, 100, 90),
	moneyGreen = Color3.fromRGB(140, 210, 120),
}

-- ===== Root GUI =====

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StationUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = true
screenGui.Parent = playerGui

-- ===== Helper UI builders =====

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.accentDark
	stroke.Thickness = thickness or 2
	stroke.Parent = parent
	return stroke
end

local function addPadding(parent, amount)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = parent
	return padding
end

local function makeButton(parentFrame, text, layoutOrder)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = COLORS.accent
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(30, 24, 18)
	button.Text = text
	button.LayoutOrder = layoutOrder or 0
	button.Parent = parentFrame
	addCorner(button, 8)
	return button
end

-- ===== Toast (small feedback popup) =====

local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Toast"
toastLabel.AnchorPoint = Vector2.new(0.5, 0)
toastLabel.Position = UDim2.new(0.5, 0, 0, 24)
toastLabel.Size = UDim2.new(0, 320, 0, 44)
toastLabel.BackgroundColor3 = COLORS.panel
toastLabel.BackgroundTransparency = 1
toastLabel.TextTransparency = 1
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextSize = 16
toastLabel.TextColor3 = COLORS.text
toastLabel.Text = ""
toastLabel.Parent = screenGui
addCorner(toastLabel, 10)
local toastStroke = addStroke(toastLabel, COLORS.accentDark, 1)
toastStroke.Transparency = 1

local toastTweenIn, toastTweenOut

local function showToast(message, isSuccess)
	toastLabel.Text = message
	toastLabel.TextColor3 = isSuccess and COLORS.success or COLORS.fail

	if toastTweenIn then toastTweenIn:Cancel() end
	if toastTweenOut then toastTweenOut:Cancel() end

	toastLabel.BackgroundTransparency = 1
	toastLabel.TextTransparency = 1
	toastStroke.Transparency = 1

	toastTweenIn = TweenService:Create(
		toastLabel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.1, TextTransparency = 0 }
	)
	local strokeTweenIn = TweenService:Create(
		toastStroke,
		TweenInfo.new(0.2),
		{ Transparency = 0.3 }
	)
	toastTweenIn:Play()
	strokeTweenIn:Play()

	task.delay(1.6, function()
		toastTweenOut = TweenService:Create(
			toastLabel,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1, TextTransparency = 1 }
		)
		local strokeTweenOut = TweenService:Create(
			toastStroke,
			TweenInfo.new(0.3),
			{ Transparency = 1 }
		)
		toastTweenOut:Play()
		strokeTweenOut:Play()
	end)
end

-- ===== Panel base (shared by Shop and Craft) =====

local function createPanel(titleText)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, 40) -- starts off-screen below
	panel.Size = UDim2.new(0, 360, 0, 320)
	panel.BackgroundColor3 = COLORS.background
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 16)
	addStroke(panel, COLORS.accentDark, 2)
	addPadding(panel, 18)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = panel

	local body = Instance.new("Frame")
	body.Position = UDim2.new(0, 0, 0, 38)
	body.Size = UDim2.new(1, 0, 1, -38)
	body.BackgroundTransparency = 1
	body.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	return panel, body
end

local function animatePanel(panel, show)
	local targetPosition = show
		and UDim2.new(0.5, 0, 1, -24)
		or UDim2.new(0.5, 0, 1, 40)

	panel.Visible = true
	local tween = TweenService:Create(
		panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, show and Enum.EasingDirection.Out or Enum.EasingDirection.In),
		{ Position = targetPosition }
	)
	tween:Play()

	if not show then
		tween.Completed:Wait()
		panel.Visible = false
	end
end

-- ===== Shop panel =====

local shopPanel, shopBody = createPanel("Shop")

local shopInfo = Instance.new("TextLabel")
shopInfo.Size = UDim2.new(1, 0, 0, 20)
shopInfo.BackgroundTransparency = 1
shopInfo.Font = Enum.Font.Gotham
shopInfo.TextSize = 14
shopInfo.TextColor3 = COLORS.subtext
shopInfo.TextXAlignment = Enum.TextXAlignment.Left
shopInfo.Text = "Sell your wood and guitars for money."
shopInfo.LayoutOrder = 1
shopInfo.Parent = shopBody

local sellWoodButton = makeButton(shopBody, "Sell All Wood  (2 Money each)", 2)
local sellGuitarButton = makeButton(shopBody, "Sell All Guitars  (25 Money each)", 3)

sellWoodButton.MouseButton1Click:Connect(function()
	local woodValue = player:WaitForChild("leaderstats"):FindFirstChild("Wood")
	local amount = woodValue and woodValue.Value or 0
	if amount <= 0 then
		showToast("No wood to sell.", false)
		return
	end
	sellItems:FireServer("Wood", amount)
end)

sellGuitarButton.MouseButton1Click:Connect(function()
	-- Guitar count isn't in leaderstats, ask the server to sell everything it has.
	sellItems:FireServer("Guitar", math.huge)
end)

-- ===== Craft panel =====

local craftPanel, craftBody = createPanel("Craft")

local craftInfo = Instance.new("TextLabel")
craftInfo.Size = UDim2.new(1, 0, 0, 16)
craftInfo.BackgroundTransparency = 1
craftInfo.Font = Enum.Font.GothamBold
craftInfo.TextSize = 15
craftInfo.TextColor3 = COLORS.text
craftInfo.TextXAlignment = Enum.TextXAlignment.Left
craftInfo.Text = CLASSIC_ACOUSTIC_RECIPE.name
craftInfo.LayoutOrder = 1
craftInfo.Parent = craftBody

local partsListFrame = Instance.new("Frame")
partsListFrame.Size = UDim2.new(1, 0, 0, 100)
partsListFrame.BackgroundTransparency = 1
partsListFrame.LayoutOrder = 2
partsListFrame.Parent = craftBody

local partsLayout = Instance.new("UIListLayout")
partsLayout.FillDirection = Enum.FillDirection.Vertical
partsLayout.Padding = UDim.new(0, 2)
partsLayout.SortOrder = Enum.SortOrder.LayoutOrder
partsLayout.Parent = partsListFrame

for i, part in ipairs(CLASSIC_ACOUSTIC_RECIPE.parts) do
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 18)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.Gotham
	row.TextSize = 14
	row.TextColor3 = COLORS.subtext
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.LayoutOrder = i
	row.Text = string.format("%s  —  %d Wood", part.name, part.wood)
	row.Parent = partsListFrame
end

local totalCostLabel = Instance.new("TextLabel")
totalCostLabel.Size = UDim2.new(1, 0, 0, 20)
totalCostLabel.BackgroundTransparency = 1
totalCostLabel.Font = Enum.Font.GothamBold
totalCostLabel.TextSize = 15
totalCostLabel.TextColor3 = COLORS.accent
totalCostLabel.TextXAlignment = Enum.TextXAlignment.Left
totalCostLabel.LayoutOrder = 3
totalCostLabel.Text = "Total cost: " .. getTotalWoodCost(CLASSIC_ACOUSTIC_RECIPE) .. " Wood"
totalCostLabel.Parent = craftBody

local craftButton = makeButton(craftBody, "Craft Guitar", 4)

craftButton.MouseButton1Click:Connect(function()
	craftGuitar:FireServer(CLASSIC_ACOUSTIC_RECIPE.id)
end)

-- ===== Zone events =====

local activePanel = nil

local function openPanel(panel)
	if activePanel == panel then return end
	if activePanel then
		animatePanel(activePanel, false)
	end
	activePanel = panel
	animatePanel(panel, true)
end

local function closePanel(panel)
	if activePanel ~= panel then return end
	activePanel = nil
	animatePanel(panel, false)
end

zoneEntered.OnClientEvent:Connect(function(zoneName)
	if zoneName == "ShopZone" then
		openPanel(shopPanel)
	elseif zoneName == "CraftZone" then
		openPanel(craftPanel)
	end
end)

zoneLeft.OnClientEvent:Connect(function(zoneName)
	if zoneName == "ShopZone" then
		closePanel(shopPanel)
	elseif zoneName == "CraftZone" then
		closePanel(craftPanel)
	end
end)

-- ===== Server feedback =====

craftResult.OnClientEvent:Connect(function(success, message)
	showToast(message, success)
end)

sellResult.OnClientEvent:Connect(function(success, message)
	showToast(message, success)
end)