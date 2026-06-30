-- @ScriptType: LocalScript
-- XPBar (LocalScript)
-- Persistent rounded, blue-themed XP bar shown top-center of the screen.
-- Listens to the "XPGained" RemoteEvent: spawns a "+X XP" popup at a random
-- spot in a center-screen zone (pops in small->big with a bouncy overshoot,
-- then floats up and fades out, Roblox-reward-style) AND starts filling the
-- bar immediately (no waiting), animating step by step (filling, flashing
-- on level-up, then resetting for the next level).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local xpGained = remoteEvents:WaitForChild("XPGained")
-- NEW: used once on startup to fetch the player's ACTUAL saved Level/XP
-- from the server, instead of always showing Level 1 / 0 XP on rejoin.
local getPlayerProgress = remoteEvents:WaitForChild("GetPlayerProgress")

-- Must match PlayerData's XP curve (client has no direct access to the
-- server module, so the formula is mirrored here for the initial display
-- before any XP has been gained yet).
local BASE_XP_REQUIRED = 20
local XP_REQUIRED_INCREASE = 10

local function getXPRequiredForLevel(level)
	return BASE_XP_REQUIRED + (level - 1) * XP_REQUIRED_INCREASE
end

-- ===== Layout (adjustable) =====
-- NOTE: container height was increased and everything is now centered
-- using AnchorPoint/UDim2 fractions instead of fixed pixel offsets, so the
-- badge no longer looks "stuck" to the top edge.

local CONTAINER_WIDTH = 340
local CONTAINER_HEIGHT = 78 -- was 64; extra room so nothing feels cramped
local PADDING_X = 14
local PADDING_Y = 12
local BADGE_SIZE = 42
local CONTENT_X = PADDING_X + BADGE_SIZE + 14 -- where the bar / caption start, leaves a clear gap after the badge
local CONTENT_WIDTH = CONTAINER_WIDTH - CONTENT_X - PADDING_X
local BAR_HEIGHT = 16
local CAPTION_HEIGHT = 16
local ROW_GAP = 6 -- gap between bar and caption

-- vertical center of the "row" (badge + bar), leaving PADDING_Y above and
-- room below for the caption
local ROW_Y = PADDING_Y + (BADGE_SIZE / 2)

-- ===== Theme (blue XP theme) =====

local COLORS = {
	background = Color3.fromRGB(18, 22, 32),
	panel = Color3.fromRGB(26, 32, 46),
	accent = Color3.fromRGB(86, 156, 255), -- bright blue
	accentDark = Color3.fromRGB(48, 96, 180),
	text = Color3.fromRGB(240, 245, 255),
	subtext = Color3.fromRGB(165, 180, 205),
	success = Color3.fromRGB(110, 180, 255),
	levelUpGlow = Color3.fromRGB(160, 210, 255),
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
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

-- ===== Root GUI =====

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XPBar"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Top-center container
local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 20)
container.Size = UDim2.new(0, CONTAINER_WIDTH, 0, CONTAINER_HEIGHT)
container.BackgroundColor3 = COLORS.background
container.BackgroundTransparency = 0.05
container.Parent = screenGui
addCorner(container, 18)
addStroke(container, COLORS.accentDark, 2)

-- Level badge (circle, left side, vertically centered with the bar)
local levelBadge = Instance.new("Frame")
levelBadge.Name = "LevelBadge"
levelBadge.AnchorPoint = Vector2.new(0, 0.5)
levelBadge.Position = UDim2.new(0, PADDING_X, 0, ROW_Y)
levelBadge.Size = UDim2.new(0, BADGE_SIZE, 0, BADGE_SIZE)
levelBadge.BackgroundColor3 = COLORS.accent
levelBadge.Parent = container
addCorner(levelBadge, BADGE_SIZE / 2) -- perfect circle
local levelBadgeStroke = addStroke(levelBadge, COLORS.accentDark, 2)

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(1, 0, 1, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBlack
levelLabel.TextSize = 18
levelLabel.TextColor3 = Color3.fromRGB(14, 18, 28)
levelLabel.Text = "1"
levelLabel.Parent = levelBadge

-- Bar track + fill (same vertical center as the badge)
local barTrack = Instance.new("Frame")
barTrack.Name = "BarTrack"
barTrack.AnchorPoint = Vector2.new(0, 0.5)
barTrack.Position = UDim2.new(0, CONTENT_X, 0, ROW_Y)
barTrack.Size = UDim2.new(0, CONTENT_WIDTH, 0, BAR_HEIGHT)
barTrack.BackgroundColor3 = COLORS.panel
barTrack.Parent = container
addCorner(barTrack, 8)
addStroke(barTrack, COLORS.accentDark, 1)

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = COLORS.accent
barFill.BorderSizePixel = 0
barFill.Parent = barTrack
addCorner(barFill, 8)

-- Caption below the bar
local captionLabel = Instance.new("TextLabel")
captionLabel.Name = "Caption"
captionLabel.AnchorPoint = Vector2.new(0, 0)
captionLabel.Position = UDim2.new(0, CONTENT_X, 0, ROW_Y + (BAR_HEIGHT / 2) + ROW_GAP)
captionLabel.Size = UDim2.new(0, CONTENT_WIDTH, 0, CAPTION_HEIGHT)
captionLabel.BackgroundTransparency = 1
captionLabel.Font = Enum.Font.Gotham
captionLabel.TextSize = 13
captionLabel.TextColor3 = COLORS.subtext
captionLabel.TextXAlignment = Enum.TextXAlignment.Left
captionLabel.Text = "20 XP to Level 2"
captionLabel.Parent = container

-- "LEVEL UP!" flash text (hidden until triggered)
local levelUpLabel = Instance.new("TextLabel")
levelUpLabel.Name = "LevelUpFlash"
levelUpLabel.AnchorPoint = Vector2.new(0, 0.5)
levelUpLabel.Position = UDim2.new(0, CONTENT_X, 0, -14)
levelUpLabel.Size = UDim2.new(0, CONTENT_WIDTH, 0, 20)
levelUpLabel.BackgroundTransparency = 1
levelUpLabel.Font = Enum.Font.GothamBlack
levelUpLabel.TextSize = 16
levelUpLabel.TextColor3 = COLORS.levelUpGlow
levelUpLabel.TextTransparency = 1
levelUpLabel.Text = "LEVEL UP!"
levelUpLabel.Parent = container

-- ===== Floating popup layer (separate from the bar container) =====
-- "+X XP" popups no longer appear pinned above the bar — they spawn at a
-- random spot inside a center-screen zone, pop in from small to big with a
-- bouncy overshoot (like a lot of mobile/roblox reward popups), then float
-- up and fade out. Each popup is a fresh TextLabel so multiple can stack
-- without canceling each other.

local popupLayer = Instance.new("Frame")
popupLayer.Name = "PopupLayer"
popupLayer.AnchorPoint = Vector2.new(0.5, 0.5)
popupLayer.Position = UDim2.new(0.5, 0, 0.5, 0)
popupLayer.Size = UDim2.new(0, 1, 0, 1) -- zero-ish, popups use absolute offsets relative to it
popupLayer.BackgroundTransparency = 1
popupLayer.ZIndex = 5
popupLayer.Parent = screenGui

-- Rough "center zone" the popups can spawn within, in pixels relative to
-- the screen center. Keeps them readable without drifting to the edges.
local POPUP_ZONE_X = 220
local POPUP_ZONE_Y_TOP = -90
local POPUP_ZONE_Y_BOTTOM = 60

local function randomPopupOffset()
	local x = math.random(-POPUP_ZONE_X, POPUP_ZONE_X)
	local y = math.random(POPUP_ZONE_Y_TOP, POPUP_ZONE_Y_BOTTOM)
	return UDim2.new(0.5, x, 0.5, y)
end

-- Spawns a single floating "+X <label>" popup at a random center-screen
-- spot: pops in (small -> big, bouncy), holds briefly, floats up while
-- fading, then destroys itself.
local function spawnFloatingPopup(text, color)
	local startPos = randomPopupOffset()

	local label = Instance.new("TextLabel")
	label.Name = "FloatingPopup"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = startPos
	label.Size = UDim2.new(0, 180, 0, 36)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextTransparency = 1
	label.Text = text
	label.ZIndex = 5
	label.Parent = popupLayer

	-- start tiny so the "pop" growth reads clearly
	label.Size = UDim2.new(0, 0, 0, 0)

	local popIn = TweenService:Create(
		label,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 180, 0, 36), TextTransparency = 0 }
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

-- ===== Helpers =====

local function setCaption(nextLevel, remainingXP)
	captionLabel.Text = string.format("%d XP to Level %d", math.max(remainingXP, 0), nextLevel)
end

local function setBarFill(scale, instant)
	scale = math.clamp(scale, 0, 1)
	if instant then
		barFill.Size = UDim2.new(scale, 0, 1, 0)
		return nil
	end

	local tween = TweenService:Create(
		barFill,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(scale, 0, 1, 0) }
	)
	tween:Play()
	return tween
end

local function playLevelUpFlash(newLevel)
	levelLabel.Text = tostring(newLevel)

	local popUp = TweenService:Create(
		levelBadge,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, BADGE_SIZE + 8, 0, BADGE_SIZE + 8) }
	)
	local popDown = TweenService:Create(
		levelBadge,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.new(0, BADGE_SIZE, 0, BADGE_SIZE) }
	)
	popUp:Play()
	popUp.Completed:Connect(function()
		popDown:Play()
	end)

	local glowIn = TweenService:Create(levelBadgeStroke, TweenInfo.new(0.1), { Color = COLORS.levelUpGlow, Thickness = 3 })
	local glowOut = TweenService:Create(levelBadgeStroke, TweenInfo.new(0.4), { Color = COLORS.accentDark, Thickness = 2 })
	glowIn:Play()
	glowIn.Completed:Connect(function()
		glowOut:Play()
	end)

	levelUpLabel.Position = UDim2.new(0, CONTENT_X, 0, -14)
	levelUpLabel.TextTransparency = 0
	local floatUp = TweenService:Create(
		levelUpLabel,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, CONTENT_X, 0, -26), TextTransparency = 1 }
	)
	floatUp:Play()
end

-- Shows a "+X XP" popup at a random spot in the center-screen zone.
local function showXPPopup(amount)
	spawnFloatingPopup("+" .. tostring(amount) .. " XP", COLORS.accent)
end

-- Plays through a list of fill "steps" coming from PlayerData.AddXP,
-- one after another: fill -> (if leveled up) flash + reset -> next step.
local function playSteps(steps)
	for _, step in ipairs(steps) do
		local startScale = step.startXP / step.requiredXP
		local endScale = step.endXP / step.requiredXP

		setBarFill(startScale, true)
		setCaption(step.level + 1, step.requiredXP - step.endXP)

		local tween = setBarFill(endScale, false)
		if tween then
			tween.Completed:Wait()
		end

		if step.leveledUp then
			playLevelUpFlash(step.level + 1)
			task.wait(0.15)
			setBarFill(0, true)
		end
	end
end

-- ===== Initial state =====
-- CHANGED: instead of always starting the bar at Level 1 / 0 XP, ask the
-- server (via GetPlayerProgress) for the player's actual saved Level/XP
-- and initialize the bar with that. This is the fix for XP/Level visually
-- "resetting" on rejoin — Wood/Money were already persisting correctly,
-- but this bar never asked the server for the real numbers on load, so it
-- always rendered as if the player were brand new.

local function applyInitialProgress(level, xp, requiredXP)
	levelLabel.Text = tostring(level)
	setBarFill(requiredXP > 0 and (xp / requiredXP) or 0, true)
	setCaption(level + 1, requiredXP - xp)
end

-- Render a safe placeholder immediately so the bar isn't blank while we
-- wait on the server round-trip below.
applyInitialProgress(1, 0, getXPRequiredForLevel(1))

task.spawn(function()
	local success, progress = pcall(function()
		return getPlayerProgress:InvokeServer()
	end)

	if success and progress then
		applyInitialProgress(progress.Level, progress.XP, progress.XPRequiredForLevel)
	else
		warn("[XPBar] Failed to fetch initial progress from server:", progress)
	end
end)

-- ===== Server events =====

-- Server fires: xpGained:FireClient(player, amount, result)
-- where `amount` is the raw XP just gained and `result` is the table
-- returned by PlayerData.AddXP (steps / finalLevel / finalXP / finalRequiredXP).
--
-- CHANGED: the popup and the bar-fill animation now start at the same time
-- (no more POPUP_TO_BAR_DELAY wait) so the bar updates instantly on chop.
xpGained.OnClientEvent:Connect(function(amount, result)
	showXPPopup(amount)
	task.spawn(function()
		playSteps(result.steps)
		setBarFill(result.finalXP / result.finalRequiredXP, true)
		setCaption(result.finalLevel + 1, result.finalRequiredXP - result.finalXP)
	end)
end)