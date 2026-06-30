-- @ScriptType: Script
-- StationSetup (ServerScript)
-- Adds a floating label above each station zone and fires RemoteEvents
-- when a player enters or leaves a zone.
-- Uses a position check on a heartbeat loop instead of Touched/TouchEnded,
-- since Touched fires per-limb and causes flickering enter/leave events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local zoneEntered = remoteEvents:WaitForChild("ZoneEntered")
local zoneLeft = remoteEvents:WaitForChild("ZoneLeft")

local stations = workspace:WaitForChild("Stations")

local ZONE_LABELS = {
	ShopZone = "SHOP",
	CraftZone = "CRAFT",
}

local CHECK_INTERVAL = 0.15 -- how often (seconds) we check player positions

local zones = {} -- list of { part = Part, name = string }
local playerZoneState = {} -- [player] = currently-active zone name or nil

local function createLabel(zonePart, text)
	local existing = zonePart:FindFirstChild("ZoneLabel")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.new(0, 120, 0, 32)
	billboard.StudsOffset = Vector3.new(0, 14, 0) -- well above head height
	billboard.AlwaysOnTop = true
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function isInsideZone(rootPosition, zonePart)
	-- simple world-space check: horizontal distance from the zone's center
	-- must be within its largest horizontal radius, and the player must be
	-- close enough vertically (a few studs above or below the zone's surface)
	local zoneCenter = zonePart.Position
	local horizontalRadius = math.max(zonePart.Size.Y, zonePart.Size.Z) / 2

	local dx = rootPosition.X - zoneCenter.X
	local dz = rootPosition.Z - zoneCenter.Z
	local horizontalDistance = math.sqrt(dx * dx + dz * dz)

	local verticalDistance = math.abs(rootPosition.Y - zoneCenter.Y)

	return horizontalDistance <= horizontalRadius and verticalDistance <= 6
end

local function getZoneNameUnderPlayer(rootPosition)
	for _, zone in ipairs(zones) do
		if isInsideZone(rootPosition, zone.part) then
			return zone.name
		end
	end
	return nil
end

for zoneName, labelText in pairs(ZONE_LABELS) do
	local zonePart = stations:WaitForChild(zoneName)
	createLabel(zonePart, labelText)
	table.insert(zones, { part = zonePart, name = zoneName })
end

local accumulatedTime = 0
RunService.Heartbeat:Connect(function(deltaTime)
	accumulatedTime += deltaTime
	if accumulatedTime < CHECK_INTERVAL then
		return
	end
	accumulatedTime = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local currentZone = getZoneNameUnderPlayer(root.Position)
			local previousZone = playerZoneState[player]

			if currentZone ~= previousZone then
				if previousZone then
					zoneLeft:FireClient(player, previousZone)
				end
				if currentZone then
					zoneEntered:FireClient(player, currentZone)
				end
				playerZoneState[player] = currentZone
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerZoneState[player] = nil
end)