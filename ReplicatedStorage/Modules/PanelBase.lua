-- @ScriptType: ModuleScript
--[[
    PanelBase.lua
    ReplicatedStorage/Modules/PanelBase

    A base panel structure featuring rounded corners, animations, and a top-right 
    close (X) button, designed to be shared across all panels (Shop, Craft, etc.). 
    Each specific panel requires this module and parent its own UI elements to the 
    Content frame.

    Usage:
        local PanelBase = require(ReplicatedStorage.Modules.PanelBase)
        local panel = PanelBase.new({
            Name = "ShopPanel",
            Title = "Workshop Shop",
            Size = UDim2.fromOffset(880, 560), -- Proportional size for 1280x720 reference resolution
        })

        panel.Content -- Add your content here (Frame)
        panel:Open()
        panel:Close()
        panel.Closed:Connect(function() ... end)
]]

local TweenService = game:GetService("TweenService")

local COLORS = {
	background = Color3.fromRGB(28, 22, 18), -- Dark wood-charcoal tone (reference panel color)
	backgroundLight = Color3.fromRGB(40, 32, 26),
	border = Color3.fromRGB(196, 142, 72), -- Wood/amber theme color
	accent = Color3.fromRGB(90, 150, 220), -- Blue accent (consistent with XPBar)
	accentDark = Color3.fromRGB(60, 110, 170),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(190, 180, 170),
	danger = Color3.fromRGB(200, 70, 70),
	overlay = Color3.fromRGB(0, 0, 0),
}

local PanelBase = {}
PanelBase.COLORS = COLORS
PanelBase.__index = PanelBase

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 16)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.border
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Simple custom Signal for Open/Closed events
local function newSignal()
	local bindable = Instance.new("BindableEvent")
	return {
		Connect = function(_, fn) return bindable.Event:Connect(fn) end,
		Fire = function(_, ...) bindable:Fire(...) end,
		_bindable = bindable,
	}
end

function PanelBase.new(opts)
	opts = opts or {}
	local self = setmetatable({}, PanelBase)

	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

	-- Dimmed background overlay behind all panels. Fades background when open,
	-- and closes the panel if clicked.
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = opts.Name or "Panel"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = opts.DisplayOrder or 10
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = COLORS.overlay
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 1
	overlay.Parent = screenGui

	-- Main panel: Proportional based on 1280x720 reference resolution, fixed size
	local size = opts.Size or UDim2.fromOffset(860, 540)
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.65) -- Opening animation will start from this offset position
	main.Size = UDim2.fromOffset(size.X.Offset, 0) -- Height is 0 when closed, expands with Open()
	main.BackgroundColor3 = COLORS.background
	main.ClipsDescendants = true
	main.ZIndex = 2
	main.Parent = screenGui
	corner(main, 22)
	stroke(main, COLORS.border, 2)

	local shadow = Instance.new("UIStroke")
	shadow.Color = Color3.fromRGB(0, 0, 0)
	shadow.Thickness = 0
	shadow.Parent = main -- Placeholder; an ImageLabel can be added for actual shadow later

	-- Top bar (Title + Tabs can be added here + Close button is always visible here)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 64)
	topBar.BackgroundColor3 = COLORS.backgroundLight
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 3
	topBar.Parent = main
	corner(topBar, 22)

	-- TopBar patch to keep bottom corners sharp
	local topBarFix = Instance.new("Frame")
	topBarFix.Size = UDim2.new(1, 0, 0, 22)
	topBarFix.Position = UDim2.new(0, 0, 1, -22)
	topBarFix.BackgroundColor3 = COLORS.backgroundLight
	topBarFix.BorderSizePixel = 0
	topBarFix.ZIndex = 3
	topBarFix.Parent = topBar

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 0)
	title.Size = UDim2.new(0, 300, 1, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = COLORS.textPrimary
	title.Text = opts.Title or "Panel"
	title.ZIndex = 4
	title.Parent = topBar

	-- Separate container for tabs or other top bar items
	local tabHolder = Instance.new("Frame")
	tabHolder.Name = "TabHolder"
	tabHolder.BackgroundTransparency = 1
	tabHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	tabHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
	tabHolder.Size = UDim2.new(0, 320, 0, 44)
	tabHolder.ZIndex = 4
	tabHolder.Parent = topBar

	-- Rounded close (X) button at the top-right — Identical position and look on ALL panels
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -16, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = COLORS.danger
	closeBtn.AutoButtonColor = true
	closeBtn.Text = "✕"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = COLORS.textPrimary
	closeBtn.ZIndex = 5
	closeBtn.Parent = topBar
	corner(closeBtn, 18)

	-- Content area: Each specific panel populates its UI here
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 64)
	content.Size = UDim2.new(1, 0, 1, -64)
	content.ZIndex = 2
	content.Parent = main

	self.ScreenGui = screenGui
	self.Overlay = overlay
	self.Main = main
	self.TopBar = topBar
	self.Title = title
	self.TabHolder = tabHolder
	self.CloseButton = closeBtn
	self.Content = content
	self._targetSize = size
	self.Opened = newSignal()
	self.Closed = newSignal()
	self._isOpen = false

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)
	overlay.MouseButton1Click:Connect(function()
		self:Close()
	end)

	return self
end

function PanelBase:Open()
	if self._isOpen then return end
	self._isOpen = true
	self.ScreenGui.Enabled = true

	self.Main.Size = UDim2.fromOffset(self._targetSize.X.Offset, 0)
	self.Main.Position = UDim2.fromScale(0.5, 0.6)
	self.Overlay.BackgroundTransparency = 1

	TweenService:Create(self.Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(
		self.Main,
		TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = self._targetSize,
			Position = UDim2.fromScale(0.5, 0.5),
		}
	):Play()

	self.Opened:Fire()
end

function PanelBase:Close()
	if not self._isOpen then return end
	self._isOpen = false

	local tween = TweenService:Create(
		self.Main,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Size = UDim2.fromOffset(self._targetSize.X.Offset, 0),
			Position = UDim2.fromScale(0.5, 0.62),
		}
	)
	TweenService:Create(self.Overlay, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
	tween:Play()
	tween.Completed:Connect(function()
		if not self._isOpen then
			self.ScreenGui.Enabled = false
		end
	end)

	self.Closed:Fire()
end

function PanelBase:Toggle()
	if self._isOpen then
		self:Close()
	else
		self:Open()
	end
end

function PanelBase:Destroy()
	self.ScreenGui:Destroy()
end

return PanelBase
