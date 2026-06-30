-- @ScriptType: LocalScript
--[[
    ShopUI.lua
    StarterPlayer/StarterPlayerScripts/ShopUI   (LocalScript)

    Listens to ProximityPromptService.PromptTriggered for the "OpenShopPrompt"
    (created by MerchantSetup.lua on the Merchant NPC) and opens the Shop panel
    built on top of PanelBase.

    Buy tab  -> icon grid from ShopItems, price bottom-right on each icon,
                click -> detail popup -> Buy 1x / Buy Multiple -> confirm -> BuyItem remote.
    Sell tab -> icon grid built from the player's live inventory (Items table
                from PlayerData, fetched via GetInventory RemoteFunction),
                click -> detail popup -> Sell 1x / Sell Multiple -> confirm -> SellItems remote.

    REQUIRED RemoteEvents/Functions in ReplicatedStorage.RemoteEvents:
        BuyItem        (RemoteEvent)   already exists
        BuyResult      (RemoteEvent)   already exists
        SellItems      (RemoteEvent)   already exists
        SellResult     (RemoteEvent)   already exists
        GetInventory    (RemoteFunction) <-- NEW, must be added (see setup notes)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PanelBase = require(ReplicatedStorage.Modules.PanelBase)
local ShopItems = require(ReplicatedStorage.Modules.ShopItems)
local COLORS = PanelBase.COLORS

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BuyItemEvent = RemoteEvents:WaitForChild("BuyItem")
local BuyResultEvent = RemoteEvents:WaitForChild("BuyResult")
local SellItemsEvent = RemoteEvents:WaitForChild("SellItems")
local SellResultEvent = RemoteEvents:WaitForChild("SellResult")
local GetInventoryFunc = RemoteEvents:WaitForChild("GetInventory")

local ITEMS_BY_ID = {}
for _, item in ipairs(ShopItems) do
	ITEMS_BY_ID[item.Id] = item
end

-- ============================================================
-- Panel creation
-- ============================================================

local panel = PanelBase.new({
	Name = "ShopPanel",
	Title = "Workshop Shop",
	Size = UDim2.fromOffset(880, 560),
})

local TABS = { "Buy", "Sell" }
local activeTab = "Buy"

-- Tab buttons in the TopBar's TabHolder
local tabButtons = {}
local function styleTabButton(btn, active)
	if active then
		btn.BackgroundColor3 = COLORS.accent
		btn.TextColor3 = COLORS.textPrimary
	else
		btn.BackgroundColor3 = COLORS.backgroundLight
		btn.TextColor3 = COLORS.textSecondary
	end
end

for i, tabName in ipairs(TABS) do
	local btn = Instance.new("TextButton")
	btn.Name = tabName .. "Tab"
	btn.Size = UDim2.new(0, 150, 1, 0)
	btn.Position = UDim2.new(0, (i - 1) * 160, 0, 0)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.AutoButtonColor = true
	btn.Text = tabName
	btn.ZIndex = 5
	btn.Parent = panel.TabHolder
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = btn
	tabButtons[tabName] = btn
end

-- ============================================================
-- Grid (shared between Buy and Sell)
-- ============================================================

local gridFrame = Instance.new("ScrollingFrame")
gridFrame.Name = "Grid"
gridFrame.BackgroundTransparency = 1
gridFrame.Size = UDim2.new(1, -32, 1, -32)
gridFrame.Position = UDim2.fromOffset(16, 16)
gridFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
gridFrame.ScrollBarThickness = 6
gridFrame.ZIndex = 2
gridFrame.Parent = panel.Content

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(120, 120)
gridLayout.CellPadding = UDim2.fromOffset(14, 14)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "EmptyLabel"
emptyLabel.BackgroundTransparency = 1
emptyLabel.Size = UDim2.new(1, 0, 0, 40)
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 16
emptyLabel.TextColor3 = COLORS.textSecondary
emptyLabel.Text = "No items to show."
emptyLabel.Visible = false
emptyLabel.ZIndex = 2
emptyLabel.Parent = panel.Content

local function clearGrid()
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeIconCell(layoutOrder, name, iconId, priceText)
	local cell = Instance.new("TextButton")
	cell.Name = name
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.BackgroundColor3 = COLORS.backgroundLight
	cell.LayoutOrder = layoutOrder
	cell.ZIndex = 3
	cell.Parent = gridFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = cell
	local s = Instance.new("UIStroke")
	s.Color = COLORS.border
	s.Thickness = 1
	s.Transparency = 0.5
	s.Parent = cell

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Position = UDim2.new(0.5, 0, 0.5, -10)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Image = iconId or "rbxassetid://0"
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 4
	icon.Parent = cell

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "Price"
	priceLabel.BackgroundTransparency = 1
	priceLabel.AnchorPoint = Vector2.new(1, 1)
	priceLabel.Position = UDim2.new(1, -6, 1, -6)
	priceLabel.Size = UDim2.fromOffset(70, 18)
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextSize = 13
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.TextColor3 = Color3.fromRGB(255, 214, 120)
	priceLabel.Text = priceText or ""
	priceLabel.ZIndex = 4
	priceLabel.Parent = cell

	return cell
end

-- ============================================================
-- Detail popup (works for both Buy and Sell, content swapped per mode)
-- ============================================================

local detailOverlay = Instance.new("TextButton")
detailOverlay.Name = "DetailOverlay"
detailOverlay.AutoButtonColor = false
detailOverlay.Text = ""
detailOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
detailOverlay.BackgroundTransparency = 1
detailOverlay.Size = UDim2.fromScale(1, 1)
detailOverlay.Visible = false
detailOverlay.ZIndex = 10
detailOverlay.Parent = panel.Main

local detailBox = Instance.new("Frame")
detailBox.Name = "DetailBox"
detailBox.AnchorPoint = Vector2.new(0.5, 0.5)
detailBox.Position = UDim2.fromScale(0.5, 0.5)
detailBox.Size = UDim2.fromOffset(420, 320)
detailBox.BackgroundColor3 = COLORS.backgroundLight
detailBox.ZIndex = 11
detailBox.Parent = detailOverlay
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 18)
	c.Parent = detailBox
	local s = Instance.new("UIStroke")
	s.Color = COLORS.border
	s.Thickness = 2
	s.Parent = detailBox
end

local detailClose = Instance.new("TextButton")
detailClose.Name = "DetailClose"
detailClose.AnchorPoint = Vector2.new(1, 0)
detailClose.Position = UDim2.new(1, -10, 0, 10)
detailClose.Size = UDim2.fromOffset(30, 30)
detailClose.BackgroundColor3 = COLORS.danger
detailClose.Text = "✕"
detailClose.Font = Enum.Font.GothamBold
detailClose.TextSize = 15
detailClose.TextColor3 = COLORS.textPrimary
detailClose.ZIndex = 12
detailClose.Parent = detailBox
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 15)
	c.Parent = detailClose
end

local detailIcon = Instance.new("ImageLabel")
detailIcon.Name = "DetailIcon"
detailIcon.BackgroundTransparency = 1
detailIcon.Size = UDim2.fromOffset(80, 80)
detailIcon.Position = UDim2.new(0.5, 0, 0, 24)
detailIcon.AnchorPoint = Vector2.new(0.5, 0)
detailIcon.ScaleType = Enum.ScaleType.Fit
detailIcon.ZIndex = 12
detailIcon.Parent = detailBox

local detailName = Instance.new("TextLabel")
detailName.Name = "DetailName"
detailName.BackgroundTransparency = 1
detailName.Position = UDim2.new(0, 20, 0, 112)
detailName.Size = UDim2.new(1, -40, 0, 28)
detailName.Font = Enum.Font.GothamBlack
detailName.TextSize = 19
detailName.TextColor3 = COLORS.textPrimary
detailName.Text = ""
detailName.ZIndex = 12
detailName.Parent = detailBox

local detailDesc = Instance.new("TextLabel")
detailDesc.Name = "DetailDesc"
detailDesc.BackgroundTransparency = 1
detailDesc.Position = UDim2.new(0, 20, 0, 144)
detailDesc.Size = UDim2.new(1, -40, 0, 60)
detailDesc.Font = Enum.Font.Gotham
detailDesc.TextSize = 14
detailDesc.TextWrapped = true
detailDesc.TextYAlignment = Enum.TextYAlignment.Top
detailDesc.TextColor3 = COLORS.textSecondary
detailDesc.Text = ""
detailDesc.ZIndex = 12
detailDesc.Parent = detailBox

local detailPrice = Instance.new("TextLabel")
detailPrice.Name = "DetailPrice"
detailPrice.BackgroundTransparency = 1
detailPrice.Position = UDim2.new(0, 20, 0, 206)
detailPrice.Size = UDim2.new(1, -40, 0, 24)
detailPrice.Font = Enum.Font.GothamBold
detailPrice.TextSize = 15
detailPrice.TextColor3 = Color3.fromRGB(255, 214, 120)
detailPrice.Text = ""
detailPrice.ZIndex = 12
detailPrice.Parent = detailBox

local btn1x = Instance.new("TextButton")
btn1x.Name = "Buy1x"
btn1x.Position = UDim2.new(0, 20, 1, -56)
btn1x.Size = UDim2.fromOffset(170, 38)
btn1x.BackgroundColor3 = COLORS.accent
btn1x.Font = Enum.Font.GothamBold
btn1x.TextSize = 15
btn1x.TextColor3 = COLORS.textPrimary
btn1x.Text = "Buy 1x"
btn1x.ZIndex = 12
btn1x.Parent = detailBox
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = btn1x
end

local btnMulti = Instance.new("TextButton")
btnMulti.Name = "BuyMultiple"
btnMulti.Position = UDim2.new(1, -20, 1, -56)
btnMulti.AnchorPoint = Vector2.new(1, 0)
btnMulti.Size = UDim2.fromOffset(190, 38)
btnMulti.BackgroundColor3 = COLORS.backgroundLight
btnMulti.BackgroundTransparency = 0
btnMulti.Font = Enum.Font.GothamBold
btnMulti.TextSize = 14
btnMulti.TextColor3 = COLORS.textPrimary
btnMulti.Text = "Buy Multiple"
btnMulti.ZIndex = 12
btnMulti.Parent = detailBox
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = btnMulti
	local s = Instance.new("UIStroke")
	s.Color = COLORS.border
	s.Thickness = 1
	s.Parent = btnMulti
end

-- Quantity input row (hidden unless "Buy Multiple"/"Sell Multiple" pressed)
local qtyRow = Instance.new("Frame")
qtyRow.Name = "QtyRow"
qtyRow.BackgroundTransparency = 1
qtyRow.Position = UDim2.new(0, 20, 1, -56)
qtyRow.Size = UDim2.new(1, -40, 0, 38)
qtyRow.Visible = false
qtyRow.ZIndex = 12
qtyRow.Parent = detailBox

local qtyBox = Instance.new("TextBox")
qtyBox.Name = "QtyBox"
qtyBox.Size = UDim2.fromOffset(90, 38)
qtyBox.BackgroundColor3 = COLORS.background
qtyBox.Font = Enum.Font.GothamBold
qtyBox.TextSize = 16
qtyBox.TextColor3 = COLORS.textPrimary
qtyBox.Text = "1"
qtyBox.ClearTextOnFocus = false
qtyBox.ZIndex = 13
qtyBox.Parent = qtyRow
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = qtyBox
	local s = Instance.new("UIStroke")
	s.Color = COLORS.border
	s.Thickness = 1
	s.Parent = qtyBox
end

local qtyConfirm = Instance.new("TextButton")
qtyConfirm.Name = "QtyConfirm"
qtyConfirm.Position = UDim2.new(0, 100, 0, 0)
qtyConfirm.Size = UDim2.fromOffset(150, 38)
qtyConfirm.BackgroundColor3 = COLORS.accent
qtyConfirm.Font = Enum.Font.GothamBold
qtyConfirm.TextSize = 14
qtyConfirm.TextColor3 = COLORS.textPrimary
qtyConfirm.Text = "Confirm Amount"
qtyConfirm.ZIndex = 13
qtyConfirm.Parent = qtyRow
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = qtyConfirm
end

-- ============================================================
-- Confirmation popup (shared)
-- ============================================================

local confirmOverlay = Instance.new("TextButton")
confirmOverlay.Name = "ConfirmOverlay"
confirmOverlay.AutoButtonColor = false
confirmOverlay.Text = ""
confirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.3
confirmOverlay.Size = UDim2.fromScale(1, 1)
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 20
confirmOverlay.Parent = panel.Main

local confirmBox = Instance.new("Frame")
confirmBox.Name = "ConfirmBox"
confirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
confirmBox.Position = UDim2.fromScale(0.5, 0.5)
confirmBox.Size = UDim2.fromOffset(360, 180)
confirmBox.BackgroundColor3 = COLORS.backgroundLight
confirmBox.ZIndex = 21
confirmBox.Parent = confirmOverlay
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = confirmBox
	local s = Instance.new("UIStroke")
	s.Color = COLORS.border
	s.Thickness = 2
	s.Parent = confirmBox
end

local confirmText = Instance.new("TextLabel")
confirmText.Name = "ConfirmText"
confirmText.BackgroundTransparency = 1
confirmText.Position = UDim2.new(0, 16, 0, 20)
confirmText.Size = UDim2.new(1, -32, 0, 80)
confirmText.Font = Enum.Font.Gotham
confirmText.TextSize = 16
confirmText.TextWrapped = true
confirmText.TextColor3 = COLORS.textPrimary
confirmText.Text = ""
confirmText.ZIndex = 22
confirmText.Parent = confirmBox

local confirmYes = Instance.new("TextButton")
confirmYes.Name = "ConfirmYes"
confirmYes.Position = UDim2.new(0, 16, 1, -54)
confirmYes.Size = UDim2.fromOffset(150, 38)
confirmYes.BackgroundColor3 = COLORS.accent
confirmYes.Font = Enum.Font.GothamBold
confirmYes.TextSize = 15
confirmYes.TextColor3 = COLORS.textPrimary
confirmYes.Text = "Confirm"
confirmYes.ZIndex = 22
confirmYes.Parent = confirmBox
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = confirmYes
end

local confirmNo = Instance.new("TextButton")
confirmNo.Name = "ConfirmNo"
confirmNo.AnchorPoint = Vector2.new(1, 0)
confirmNo.Position = UDim2.new(1, -16, 1, -54)
confirmNo.Size = UDim2.fromOffset(150, 38)
confirmNo.BackgroundColor3 = COLORS.danger
confirmNo.Font = Enum.Font.GothamBold
confirmNo.TextSize = 15
confirmNo.TextColor3 = COLORS.textPrimary
confirmNo.Text = "Cancel"
confirmNo.ZIndex = 22
confirmNo.Parent = confirmBox
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = confirmNo
end

local function closeConfirm()
	confirmOverlay.Visible = false
end
confirmNo.MouseButton1Click:Connect(closeConfirm)
confirmOverlay.MouseButton1Click:Connect(function() end) -- swallow clicks landing on overlay edges

local function openConfirm(text, onYes)
	confirmText.Text = text
	confirmOverlay.Visible = true
	local conn
	conn = confirmYes.MouseButton1Click:Connect(function()
		conn:Disconnect()
		closeConfirm()
		onYes()
	end)
end

local function closeDetail()
	detailOverlay.Visible = false
	qtyRow.Visible = false
	btn1x.Visible = true
	btnMulti.Visible = true
end
detailClose.MouseButton1Click:Connect(closeDetail)

-- ============================================================
-- BUY TAB
-- ============================================================

local function openBuyDetail(item)
	detailIcon.Image = item.Icon or "rbxassetid://0"
	detailName.Text = item.Name
	detailDesc.Text = item.Description or ""
	detailPrice.Text = ("Price: %d %s"):format(item.Price, item.Currency or "Money")

	btnMulti.Visible = item.AllowMultiple == true
	btn1x.Visible = true
	qtyRow.Visible = false
	qtyBox.Text = "1"

	-- rebind buttons fresh each time to avoid stacking connections
	for _, conn in ipairs(getconnections and {} or {}) do end

	btn1x.MouseButton1Click:Once(function()
		openConfirm(("Buy 1x %s for %d %s?"):format(item.Name, item.Price, item.Currency or "Money"), function()
			BuyItemEvent:FireServer(item.Id, 1)
		end)
	end)

	btnMulti.MouseButton1Click:Once(function()
		qtyRow.Visible = true
	end)

	qtyConfirm.MouseButton1Click:Once(function()
		local qty = tonumber(qtyBox.Text)
		if not qty or qty < 1 or qty ~= math.floor(qty) then
			qtyBox.Text = "1"
			return
		end
		openConfirm(("Buy %dx %s for %d %s?"):format(qty, item.Name, item.Price * qty, item.Currency or "Money"), function()
			BuyItemEvent:FireServer(item.Id, qty)
		end)
	end)

	detailOverlay.Visible = true
end

local function renderBuyTab()
	clearGrid()
	emptyLabel.Visible = false
	for i, item in ipairs(ShopItems) do
		local cell = makeIconCell(i, item.Name, item.Icon, tostring(item.Price))
		cell.MouseButton1Click:Connect(function()
			openBuyDetail(item)
		end)
	end
end

-- ============================================================
-- SELL TAB
-- ============================================================

-- Friendly display names/icons for the "special" stats (Wood/Guitar) that
-- live outside the generic Items table in PlayerData.
local SPECIAL_SELLABLES = {
	Wood = { Name = "Wood", Icon = "rbxassetid://0", SellPrice = 2, Description = "Raw wood collected from trees." },
	Guitar = { Name = "Guitar", Icon = "rbxassetid://0", SellPrice = 50, Description = "A finished guitar ready for sale." },
}

local function getItemSellPrice(itemId)
	local cfg = ITEMS_BY_ID[itemId]
	if cfg then
		return math.max(1, math.floor(cfg.Price * 0.5)) -- sell back at 50% of buy price
	end
	return 1
end

local function openSellDetail(entry)
	-- entry = { id, name, icon, description, sellPrice, count, isSpecial }
	detailIcon.Image = entry.icon or "rbxassetid://0"
	detailName.Text = entry.name
	detailDesc.Text = (entry.description or "") .. ("\nYou own: %d"):format(entry.count)
	detailPrice.Text = ("Sell Price: %d Money each"):format(entry.sellPrice)

	btnMulti.Visible = entry.count > 1
	btn1x.Visible = true
	btn1x.Text = "Sell 1x"
	qtyRow.Visible = false
	qtyBox.Text = "1"

	btn1x.MouseButton1Click:Once(function()
		openConfirm(("Sell 1x %s for %d Money?"):format(entry.name, entry.sellPrice), function()
			SellItemsEvent:FireServer(entry.id, 1)
		end)
	end)

	btnMulti.MouseButton1Click:Once(function()
		qtyRow.Visible = true
	end)

	qtyConfirm.MouseButton1Click:Once(function()
		local qty = tonumber(qtyBox.Text)
		if not qty or qty < 1 or qty ~= math.floor(qty) then
			qtyBox.Text = "1"
			return
		end
		qty = math.min(qty, entry.count)
		openConfirm(("Sell %dx %s for %d Money?"):format(qty, entry.name, entry.sellPrice * qty), function()
			SellItemsEvent:FireServer(entry.id, qty)
		end)
	end)

	detailOverlay.Visible = true
	btn1x.Text = "Sell 1x"
end

local function renderSellTab()
	clearGrid()

	local ok, inventory = pcall(function()
		return GetInventoryFunc:InvokeServer()
	end)
	if not ok or type(inventory) ~= "table" then
		inventory = { Items = {}, Wood = 0, Guitar = 0 }
	end

	local entries = {}

	if (inventory.Wood or 0) > 0 then
		table.insert(entries, {
			id = "Wood",
			name = SPECIAL_SELLABLES.Wood.Name,
			icon = SPECIAL_SELLABLES.Wood.Icon,
			description = SPECIAL_SELLABLES.Wood.Description,
			sellPrice = SPECIAL_SELLABLES.Wood.SellPrice,
			count = inventory.Wood,
		})
	end
	if (inventory.Guitar or 0) > 0 then
		table.insert(entries, {
			id = "Guitar",
			name = SPECIAL_SELLABLES.Guitar.Name,
			icon = SPECIAL_SELLABLES.Guitar.Icon,
			description = SPECIAL_SELLABLES.Guitar.Description,
			sellPrice = SPECIAL_SELLABLES.Guitar.SellPrice,
			count = inventory.Guitar,
		})
	end

	if inventory.Items then
		for itemId, count in pairs(inventory.Items) do
			if count and count > 0 then
				local cfg = ITEMS_BY_ID[itemId]
				table.insert(entries, {
					id = itemId,
					name = cfg and cfg.Name or itemId,
					icon = cfg and cfg.Icon or "rbxassetid://0",
					description = cfg and cfg.Description or "",
					sellPrice = getItemSellPrice(itemId),
					count = count,
				})
			end
		end
	end

	emptyLabel.Visible = #entries == 0
	for i, entry in ipairs(entries) do
		local cell = makeIconCell(i, entry.name, entry.icon, tostring(entry.sellPrice))
		cell.MouseButton1Click:Connect(function()
			openSellDetail(entry)
		end)
	end
end

-- ============================================================
-- Tab switching
-- ============================================================

local function setActiveTab(tabName)
	activeTab = tabName
	for name, btn in pairs(tabButtons) do
		styleTabButton(btn, name == tabName)
	end
	if tabName == "Buy" then
		renderBuyTab()
	else
		renderSellTab()
	end
end

for tabName, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		setActiveTab(tabName)
	end)
end

-- ============================================================
-- Result feedback (simple on-screen flash text, top of panel)
-- ============================================================

local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "ResultLabel"
resultLabel.BackgroundTransparency = 1
resultLabel.AnchorPoint = Vector2.new(0.5, 0)
resultLabel.Position = UDim2.new(0.5, 0, 0, 4)
resultLabel.Size = UDim2.new(1, -200, 0, 20)
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 13
resultLabel.TextColor3 = COLORS.textPrimary
resultLabel.Text = ""
resultLabel.TextTransparency = 1
resultLabel.ZIndex = 4
resultLabel.Parent = panel.TopBar

local function flashResult(success, message)
	resultLabel.TextColor3 = success and Color3.fromRGB(120, 220, 130) or Color3.fromRGB(230, 90, 90)
	resultLabel.Text = message
	resultLabel.TextTransparency = 0
	TweenService:Create(resultLabel, TweenInfo.new(2.4), { TextTransparency = 1 }):Play()
end

BuyResultEvent.OnClientEvent:Connect(function(success, message)
	flashResult(success, message)
	closeDetail()
	if success and activeTab == "Sell" then
		renderSellTab()
	end
end)

SellResultEvent.OnClientEvent:Connect(function(success, message)
	flashResult(success, message)
	closeDetail()
	if success and activeTab == "Sell" then
		renderSellTab()
	end
end)

-- ============================================================
-- Open via Merchant ProximityPrompt
-- ============================================================

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	if prompt.Name ~= "OpenShopPrompt" then
		return
	end
	setActiveTab("Buy")
	panel:Open()
end)