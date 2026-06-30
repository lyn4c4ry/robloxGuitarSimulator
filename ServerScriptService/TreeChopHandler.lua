-- @ScriptType: Script
-- TreeChopHandler (ServerScript)
-- The whole tree model (Trunk + Leaves + Branches) falls together using REAL physics.
-- Flow: chop -> trunk unanchors and falls naturally (welded to leaves/branches) ->
--       settles on the ground -> tree disappears -> countdown billboard shows ->
--       tree respawns, fully anchored and reset.
-- Per-tree settings can be overridden using Attributes on the tree Model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PlayerData = require(ReplicatedStorage.Modules.PlayerData)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local xpGained = remoteEvents:WaitForChild("XPGained")
-- NEW: fired whenever a player gains wood from chopping, so the client can
-- show a "+X Wood" popup (mirrors how XPGained works).
local woodGained = remoteEvents:FindFirstChild("WoodGained")
if not woodGained then
	woodGained = Instance.new("RemoteEvent")
	woodGained.Name = "WoodGained"
	woodGained.Parent = remoteEvents
end

local DEFAULTS = {
	-- NEW: wood reward is now a random range instead of a fixed amount.
	MinWood = 1,
	MaxWood = 3,
	FallTime = 0.7,        -- initial wait before checking if the tree has settled
	GroundWait = 2,         -- seconds the fallen tree stays visible on the ground
	RespawnTime = 3,        -- seconds the tree stays gone before respawning (countdown shown)
	FadeTime = 0.35,        -- fade out duration when the tree disappears
	ChopCooldown = 1,       -- extra cooldown after respawn before it can be chopped again
	MinXP = 3,
	MaxXP = 5,
}

local playerCooldowns = {}     -- [player] = last chop time, used as a simple spam guard
local originalPivots = {}      -- [treeModel] = CFrame, the tree's spawn pivot
local partOriginalState = {}   -- [treeModel] = { [part] = {Transparency=, CanCollide=} }
local busyTrees = {}           -- [treeModel] = true while a chop sequence is running

-- ===== Config =====

local function getTreeConfig(treeModel)
	return {
		MinWood = treeModel:GetAttribute("MinWood") or DEFAULTS.MinWood,
		MaxWood = treeModel:GetAttribute("MaxWood") or DEFAULTS.MaxWood,
		FallTime = treeModel:GetAttribute("FallTime") or DEFAULTS.FallTime,
		GroundWait = treeModel:GetAttribute("GroundWait") or DEFAULTS.GroundWait,
		RespawnTime = treeModel:GetAttribute("RespawnTime") or DEFAULTS.RespawnTime,
		FadeTime = treeModel:GetAttribute("FadeTime") or DEFAULTS.FadeTime,
		ChopCooldown = treeModel:GetAttribute("ChopCooldown") or DEFAULTS.ChopCooldown,
		MinXP = treeModel:GetAttribute("MinXP") or DEFAULTS.MinXP,
		MaxXP = treeModel:GetAttribute("MaxXP") or DEFAULTS.MaxXP,
	}
end

-- ===== Player data =====

local function updateLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local woodValue = leaderstats:FindFirstChild("Wood")
	if woodValue then
		woodValue.Value = PlayerData.GetWood(player)
	end

	local moneyValue = leaderstats:FindFirstChild("Money")
	if moneyValue then
		moneyValue.Value = PlayerData.GetMoney(player)
	end

	-- NEW: Level is now also tracked on the leaderboard.
	local levelValue = leaderstats:FindFirstChild("Level")
	if levelValue then
		levelValue.Value = PlayerData.GetLevel(player)
	end
end

-- ===== Setup =====

local function setupTreeModel(treeModel)
	local trunk = treeModel:FindFirstChild("Trunk")
	if not trunk then
		warn("Missing Trunk in:", treeModel:GetFullName())
		return
	end

	treeModel.PrimaryPart = trunk

	if not originalPivots[treeModel] then
		originalPivots[treeModel] = treeModel:GetPivot()

		local states = {}
		for _, part in ipairs(treeModel:GetDescendants()) do
			if part:IsA("BasePart") then
				states[part] = {
					Transparency = part.Transparency,
					CanCollide = part.CanCollide,
				}
			end
		end
		partOriginalState[treeModel] = states
	end
end

-- ===== Fall animation (real physics) =====

local function getFallDirection(treeModel, player)
	local originalPivot = originalPivots[treeModel]
	if not originalPivot then
		return Vector3.new(0, 0, 1)
	end

	local character = player.Character
	if not character then
		return Vector3.new(0, 0, 1)
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return Vector3.new(0, 0, 1)
	end

	local flat = Vector3.new(
		originalPivot.Position.X - root.Position.X,
		0,
		originalPivot.Position.Z - root.Position.Z
	)

	if flat.Magnitude < 0.1 then
		return Vector3.new(0, 0, 1)
	end

	return flat.Unit
end

local function weldTreeToTrunk(treeModel, trunk)
	for _, part in ipairs(treeModel:GetDescendants()) do
		if part:IsA("BasePart") and part ~= trunk then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "TreeWeld"
			weld.Part0 = trunk
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function removeTreeWelds(treeModel)
	for _, part in ipairs(treeModel:GetDescendants()) do
		if part:IsA("WeldConstraint") and part.Name == "TreeWeld" then
			part:Destroy()
		end
	end
end

local function dropTreeWithPhysics(treeModel, player, fallTime)
	local trunk = treeModel:FindFirstChild("Trunk")
	if not trunk then return end

	-- weld every other part to the trunk so the whole tree falls together
	weldTreeToTrunk(treeModel, trunk)

	-- unanchor trunk and branches so real physics applies; leaves stay non-colliding and massless
	for _, part in ipairs(treeModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			if part.Name == "Leaves" then
				part.CanCollide = false
				part.Massless = true
			else
				part.CanCollide = true
				part.Massless = false
			end
		end
	end

	local away = getFallDirection(treeModel, player)

	-- small push so it falls away from the player instead of randomly
	trunk.AssemblyLinearVelocity = away * 4 + Vector3.new(0, 1, 0)
	trunk.AssemblyAngularVelocity = Vector3.new(away.Z, 0, -away.X) * 6

	-- let real physics settle the tree on the ground
	task.wait(fallTime)

	-- wait until the trunk basically stops moving (settled on the ground)
	local stableTime = 0
	local maxWait = 2.5
	local waited = 0
	while waited < maxWait do
		local speed = trunk.AssemblyLinearVelocity.Magnitude
		if speed < 0.5 then
			stableTime += 0.1
		else
			stableTime = 0
		end
		if stableTime >= 0.3 then
			break
		end
		task.wait(0.1)
		waited += 0.1
	end
end

-- ===== Effects =====

local function emitLeafBurst(treeModel, amount)
	local leaves = treeModel:FindFirstChild("Leaves")
	if not leaves then return end
	local emitter = leaves:FindFirstChild("LeafBurst")
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(amount or 20)
	end
end

local function spawnWoodEffect(treeModel)
	local trunk = treeModel:FindFirstChild("Trunk")
	if not trunk then return end

	local wood = Instance.new("Part")
	wood.Name = "WoodEffect"
	wood.Size = Vector3.new(0.6, 0.6, 0.6)
	wood.Color = Color3.fromRGB(120, 72, 40)
	wood.Material = Enum.Material.Wood
	wood.Anchored = true
	wood.CanCollide = false
	wood.CFrame = trunk.CFrame * CFrame.new(0, 2, 0)
	wood.Parent = workspace

	local tween = TweenService:Create(
		wood,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			CFrame = wood.CFrame * CFrame.new(0, 3, 0),
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1),
		}
	)
	tween:Play()
	Debris:AddItem(wood, 1)
end

-- ===== Despawn / respawn =====

local function fadeOutTree(treeModel, fadeTime)
	local tweens = {}

	for part, _ in pairs(partOriginalState[treeModel] or {}) do
		if part and part.Parent then
			part.CanCollide = false
			local tween = TweenService:Create(
				part,
				TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			)
			tween:Play()
			table.insert(tweens, tween)
		end
	end

	if #tweens > 0 then
		tweens[1].Completed:Wait()
	else
		task.wait(fadeTime)
	end

	treeModel.Parent = nil
end

local function restoreTree(treeModel, treesFolder)
	local originalPivot = originalPivots[treeModel]
	local states = partOriginalState[treeModel]
	if not originalPivot or not states then return end

	removeTreeWelds(treeModel)

	for part, state in pairs(states) do
		if part then
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end

	treeModel:PivotTo(originalPivot)

	for part, state in pairs(states) do
		if part then
			part.Transparency = state.Transparency
			part.CanCollide = state.CanCollide
		end
	end

	treeModel.Parent = treesFolder
end

-- ===== Respawn countdown (BillboardGui) =====

local function createCountdownGui(originalPivot)
	local anchor = Instance.new("Part")
	anchor.Name = "RespawnCountdownAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = originalPivot * CFrame.new(0, 4, 0)
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RespawnCountdown"
	billboard.Size = UDim2.new(0, 60, 0, 60)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.Size = UDim2.new(1, 0, 1, 0)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.new(0.5, 0, 0.5, 0)
	circle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	circle.BackgroundTransparency = 0.2
	circle.BorderSizePixel = 0
	circle.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(120, 220, 140)
	stroke.Parent = circle

	local label = Instance.new("TextLabel")
	label.Name = "CountLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Text = ""
	label.Parent = circle

	return anchor, label
end

local function runRespawnCountdown(originalPivot, respawnTime)
	local anchor, label = createCountdownGui(originalPivot)

	local secondsLeft = math.ceil(respawnTime)
	while secondsLeft > 0 do
		label.Text = tostring(secondsLeft)

		label.Parent.Size = UDim2.new(1, 0, 1, 0)
		local pulseTween = TweenService:Create(
			label.Parent,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0.85, 0, 0.85, 0) }
		)
		pulseTween:Play()

		task.wait(1)
		secondsLeft -= 1
	end

	anchor:Destroy()
end

-- ===== Main chop sequence =====

local function onChop(player, treeModel, treesFolder)
	if busyTrees[treeModel] then
		return
	end

	local config = getTreeConfig(treeModel)
	local trunk = treeModel:FindFirstChild("Trunk")
	if not trunk then return end

	local prompt = trunk:FindFirstChild("ChopPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then return end

	local lastChop = playerCooldowns[player]
	if lastChop and (tick() - lastChop) < config.ChopCooldown then
		return
	end

	busyTrees[treeModel] = true
	playerCooldowns[player] = tick()
	prompt.Enabled = false

	-- CHANGED: rewards (Wood + XP) are now given INSTANTLY, the moment the
	-- chop is triggered — no waiting on the fall animation, sound delays,
	-- or "has it settled" physics checks. This is what made the popups and
	-- the XP bar feel laggy before: they used to fire only after the tree
	-- had already fallen and settled (which could take 1-3+ seconds).
	local woodAmount = math.random(config.MinWood, config.MaxWood)
	PlayerData.AddWood(player, woodAmount)
	updateLeaderstats(player)
	woodGained:FireClient(player, woodAmount)

	local xpAmount = math.random(config.MinXP, config.MaxXP)
	local xpResult = PlayerData.AddXP(player, xpAmount)
	xpGained:FireClient(player, xpAmount, xpResult)

	-- Level may have changed as part of AddXP, keep leaderstats in sync
	updateLeaderstats(player)

	emitLeafBurst(treeModel, 18)
	spawnWoodEffect(treeModel)

	task.wait(0.12) -- tiny delay so the fall sound lands just after the tree starts tipping

	local fallSound = treeModel:FindFirstChild("FallSound", true)
	if fallSound and fallSound:IsA("Sound") then
		fallSound:Play()
	end

	-- whole tree falls together using real physics
	dropTreeWithPhysics(treeModel, player, config.FallTime)

	emitLeafBurst(treeModel, 12)

	-- stay fallen on the ground for a bit
	task.wait(config.GroundWait)

	-- fade out and remove from workspace
	local originalPivot = originalPivots[treeModel]
	fadeOutTree(treeModel, config.FadeTime)

	-- show countdown at the original spot while the tree is gone
	runRespawnCountdown(originalPivot, config.RespawnTime)

	-- bring the tree back
	restoreTree(treeModel, treesFolder)

	task.wait(config.ChopCooldown)
	local newPrompt = treeModel:FindFirstChild("Trunk") and treeModel.Trunk:FindFirstChild("ChopPrompt")
	if newPrompt then
		newPrompt.Enabled = true
	end
	busyTrees[treeModel] = nil
end

-- ===== Connect all trees =====

local function connectTreePrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	if prompt.Name ~= "ChopPrompt" then return end

	local treeModel = prompt:FindFirstAncestorWhichIsA("Model")
	if not treeModel then return end

	local treesFolder = treeModel.Parent

	setupTreeModel(treeModel)

	local holdingChopLoop = false

	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdingChopLoop = true
		task.spawn(function()
			local chopSound = treeModel:FindFirstChild("ChopSound", true)
			while holdingChopLoop do
				if chopSound and chopSound:IsA("Sound") then
					chopSound:Play()
				end
				task.wait(0.40) -- time between each "tak" sound, adjust to taste
			end
		end)
	end)

	prompt.PromptButtonHoldEnded:Connect(function(player)
		holdingChopLoop = false
	end)

	prompt.Triggered:Connect(function(player)
		holdingChopLoop = false
		onChop(player, treeModel, treesFolder)
	end)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") and descendant.Name == "ChopPrompt" then
		connectTreePrompt(descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") and descendant.Name == "ChopPrompt" then
		connectTreePrompt(descendant)
	end
end)