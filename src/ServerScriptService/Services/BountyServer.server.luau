local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BountyChanged = Remotes:WaitForChild("BountyChanged")

local BOUNTY_REWARDS = {
	TrainingDummy = 5,
	ForestDemon = 0,
}

local function getBountyForDemon(level)
	return 8 + (level - 1) * 4
end

local NAMEPLATE_STUDS_OFFSET = Vector3.new(0, 3, 0)
local NAMEPLATE_MAX_DISTANCE = 80
local NAMEPLATE_WIDTH = 6
local NAMEPLATE_HEIGHT = 1.2

local FACTION_COLORS = {
	Slayer = Color3.fromRGB(80, 180, 255),
	Demon = Color3.fromRGB(255, 80, 80),
}
local DEFAULT_FACTION_COLOR = Color3.fromRGB(180, 180, 180)

local BOUNTY_TIERS = {
	{ threshold = 500,  color = Color3.fromRGB(255, 50, 50),   label = "WANTED" },
	{ threshold = 200,  color = Color3.fromRGB(255, 160, 40),  label = "Notorious" },
	{ threshold = 50,   color = Color3.fromRGB(255, 230, 80),  label = "" },
	{ threshold = 0,    color = Color3.fromRGB(180, 180, 180), label = "" },
}

local function getBountyTier(bounty)
	for _, tier in BOUNTY_TIERS do
		if bounty >= tier.threshold then
			return tier
		end
	end
	return BOUNTY_TIERS[#BOUNTY_TIERS]
end

local playerNameplates = {}

local function createNameplate(character, player)
	local head = character:WaitForChild("Head", 5)
	if not head then return end

	local existing = head:FindFirstChild("PlayerNameplate")
	if existing then
		existing:Destroy()
	end

	local data = PlayerDataModule.getData(player)
	local level = data and data.Level or 1
	local faction = data and data.Faction or ""
	local bounty = data and data.Bounty or 0

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerNameplate"
	billboard.Size = UDim2.fromScale(NAMEPLATE_WIDTH, NAMEPLATE_HEIGHT)
	billboard.StudsOffset = NAMEPLATE_STUDS_OFFSET
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = NAMEPLATE_MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.Parent = head

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local factionColor = FACTION_COLORS[faction] or DEFAULT_FACTION_COLOR

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = player.DisplayName
	nameLabel.LayoutOrder = 1
	nameLabel.Parent = container

	local factionText = faction ~= "" and faction or "Unaffiliated"
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.fromScale(1, 0.3)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextScaled = true
	infoLabel.TextColor3 = factionColor
	infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	infoLabel.TextStrokeTransparency = 0.4
	infoLabel.Text = "Lv." .. level .. " " .. factionText
	infoLabel.LayoutOrder = 2
	infoLabel.Parent = container

	local tier = getBountyTier(bounty)
	local bountyText = bounty > 0 and ("⚔ " .. tostring(bounty)) or ""
	if tier.label ~= "" and bounty >= tier.threshold and bounty > 0 then
		bountyText = tier.label .. " ⚔ " .. tostring(bounty)
	end

	local bountyLabel = Instance.new("TextLabel")
	bountyLabel.Name = "BountyLabel"
	bountyLabel.Size = UDim2.fromScale(1, 0.3)
	bountyLabel.BackgroundTransparency = 1
	bountyLabel.Font = Enum.Font.GothamBold
	bountyLabel.TextScaled = true
	bountyLabel.TextColor3 = tier.color
	bountyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	bountyLabel.TextStrokeTransparency = 0.3
	bountyLabel.Text = bountyText
	bountyLabel.Visible = bounty > 0
	bountyLabel.LayoutOrder = 3
	bountyLabel.Parent = container

	playerNameplates[player] = {
		billboard = billboard,
		nameLabel = nameLabel,
		infoLabel = infoLabel,
		bountyLabel = bountyLabel,
	}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function updateNameplate(player)
	local plate = playerNameplates[player]
	if not plate then return end

	local data = PlayerDataModule.getData(player)
	if not data then return end

	local level = data.Level
	local faction = data.Faction or ""
	local bounty = data.Bounty or 0

	local factionColor = FACTION_COLORS[faction] or DEFAULT_FACTION_COLOR
	local factionText = faction ~= "" and faction or "Unaffiliated"

	plate.infoLabel.Text = "Lv." .. level .. " " .. factionText
	plate.infoLabel.TextColor3 = factionColor

	local tier = getBountyTier(bounty)
	local bountyText = bounty > 0 and ("⚔ " .. tostring(bounty)) or ""
	if tier.label ~= "" and bounty >= tier.threshold and bounty > 0 then
		bountyText = tier.label .. " ⚔ " .. tostring(bounty)
	end

	plate.bountyLabel.Text = bountyText
	plate.bountyLabel.TextColor3 = tier.color
	plate.bountyLabel.Visible = bounty > 0
end

local function onEnemyKilled(attackerPlayer, enemyType, enemyLevel)
	if not attackerPlayer then return end

	local reward = BOUNTY_REWARDS[enemyType]
	if reward == nil then
		reward = 10
	end

	if enemyType == "ForestDemon" and enemyLevel then
		reward = getBountyForDemon(enemyLevel)
	end

	if reward > 0 then
		PlayerDataModule.addBounty(attackerPlayer, reward)
		updateNameplate(attackerPlayer)
	end
end

BountyChanged.OnServerEvent:Connect(function()
end)

local _G_BountyServer = {}
_G_BountyServer.onEnemyKilled = onEnemyKilled
_G_BountyServer.updateNameplate = updateNameplate
-- selene: allow(global_usage)
shared.BountyServer = _G_BountyServer

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			createNameplate(character, player)
		end)
	end)

	if player.Character then
		task.defer(function()
			createNameplate(player.Character, player)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerNameplates[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(5)
		for _, player in Players:GetPlayers() do
			updateNameplate(player)
		end
	end
end)

print("[BountyServer] Loaded")