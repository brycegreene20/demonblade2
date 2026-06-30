local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local _TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local WorldSpawnConfigModule = require(Modules:WaitForChild("WorldSpawnConfigModule"))

local NPC_CONFIGS = {
	{
		id = "QuestNPC_Elder",
		displayName = "Trainer Urokodaki",
		roleText = "Training Quests",
		hasQuestPrompt = true,
		bodyColors = {
			Head = Color3.fromRGB(234, 184, 146),
			Torso = Color3.fromRGB(60, 40, 80),
			["Left Arm"] = Color3.fromRGB(234, 184, 146),
			["Right Arm"] = Color3.fromRGB(234, 184, 146),
			["Left Leg"] = Color3.fromRGB(40, 40, 50),
			["Right Leg"] = Color3.fromRGB(40, 40, 50),
		},
	},
	{
		id = "QuestNPC_Scout",
		displayName = "Merchant Aoi",
		roleText = "Merchant",
		hasQuestPrompt = false,
		bodyColors = {
			Head = Color3.fromRGB(234, 184, 146),
			Torso = Color3.fromRGB(50, 100, 60),
			["Left Arm"] = Color3.fromRGB(234, 184, 146),
			["Right Arm"] = Color3.fromRGB(234, 184, 146),
			["Left Leg"] = Color3.fromRGB(70, 60, 40),
			["Right Leg"] = Color3.fromRGB(70, 60, 40),
		},
	},
	{
		id = "QuestNPC_Officer",
		displayName = "Corps Officer",
		roleText = "Demon Quests",
		hasQuestPrompt = true,
		bodyColors = {
			Head = Color3.fromRGB(234, 184, 146),
			Torso = Color3.fromRGB(30, 30, 60),
			["Left Arm"] = Color3.fromRGB(234, 184, 146),
			["Right Arm"] = Color3.fromRGB(234, 184, 146),
			["Left Leg"] = Color3.fromRGB(25, 25, 45),
			["Right Leg"] = Color3.fromRGB(25, 25, 45),
		},
	},
}

local R6_PARTS = {
	{
		name = "HumanoidRootPart",
		size = Vector3.new(2, 2, 1),
		offset = CFrame.new(0, 0, 0),
		transparency = 1,
		canCollide = false,
	},
	{
		name = "Torso",
		size = Vector3.new(2, 2, 1),
		offset = CFrame.new(0, 0, 0),
	},
	{
		name = "Head",
		size = Vector3.new(2, 1, 1),
		offset = CFrame.new(0, 1.5, 0),
		mesh = { meshType = Enum.MeshType.Head, scale = Vector3.new(1.25, 1.25, 1.25) },
	},
	{
		name = "Left Arm",
		size = Vector3.new(1, 2, 1),
		offset = CFrame.new(-1.5, 0, 0),
	},
	{
		name = "Right Arm",
		size = Vector3.new(1, 2, 1),
		offset = CFrame.new(1.5, 0, 0),
	},
	{
		name = "Left Leg",
		size = Vector3.new(1, 2, 1),
		offset = CFrame.new(-0.5, -2, 0),
	},
	{
		name = "Right Leg",
		size = Vector3.new(1, 2, 1),
		offset = CFrame.new(0.5, -2, 0),
	},
}

local RING_COLOR = Color3.fromRGB(255, 210, 60)
local RING_SECONDARY = Color3.fromRGB(255, 255, 150)
local NPC_ROOT_HEIGHT = 3
local MARKERS_FOLDER_NAME = "DemonBlade2Markers"

local npcsFolder = Instance.new("Folder")
npcsFolder.Name = "NPCs"
npcsFolder.Parent = workspace

local function copyConfig(config)
	local nextConfig = {}
	for key, value in config do
		nextConfig[key] = value
	end
	return nextConfig
end

local function getMarkerPart(markerName)
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if not markersFolder then
		return nil
	end

	local marker = markersFolder:FindFirstChild(markerName)
	if marker and marker:IsA("BasePart") then
		return marker
	end
	return nil
end

local function resolveNPCSpawn(config)
	local spawn = WorldSpawnConfigModule.getNPCSpawn(config.id)
	local marker = getMarkerPart(config.id)
	local configuredPosition = marker and marker.Position
		or spawn and spawn.position
		or config.position
		or Vector3.new(0, 4, 0)
	local facingAngle = marker and (marker:GetAttribute("FacingAngle") or marker.Orientation.Y)
		or spawn and spawn.facingAngle
		or config.facingAngle
		or 0

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { npcsFolder }
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	raycastParams.FilterDescendantsInstances = excluded
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	local result = workspace:Raycast(
		configuredPosition + Vector3.new(0, 350, 0),
		Vector3.new(0, -800, 0),
		raycastParams
	)

	if result and result.Normal.Y >= 0.5 then
		return Vector3.new(configuredPosition.X, result.Position.Y + NPC_ROOT_HEIGHT, configuredPosition.Z), facingAngle
	end

	warn(("[NPCSpawner] No ground found for %s at %s; using configured fallback"):format(
		config.displayName,
		tostring(configuredPosition)
	))
	return configuredPosition, facingAngle
end

local function buildR6Rig(config)
	local model = Instance.new("Model")
	model.Name = config.id

	local rootCFrame = CFrame.new(config.position) * CFrame.Angles(0, math.rad(config.facingAngle), 0)

	local parts = {}
	for _, partDef in R6_PARTS do
		local part = Instance.new("Part")
		part.Name = partDef.name
		part.Size = partDef.size
		part.CFrame = rootCFrame * partDef.offset
		part.Anchored = true
		part.CanCollide = partDef.canCollide ~= nil and partDef.canCollide or (partDef.name ~= "HumanoidRootPart")
		part.Transparency = partDef.transparency or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth

		local color = config.bodyColors[partDef.name]
		if color then
			part.Color = color
		end

		if partDef.mesh then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = partDef.mesh.meshType
			mesh.Scale = partDef.mesh.scale
			mesh.Parent = part
		end

		part.Parent = model
		parts[partDef.name] = part
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	local streamAnchor = Instance.new("Part")
	streamAnchor.Name = "StreamAnchor"
	streamAnchor.Size = Vector3.new(1, 1, 1)
	streamAnchor.Transparency = 1
	streamAnchor.CanCollide = false
	streamAnchor.CanQuery = false
	streamAnchor.Anchored = true
	streamAnchor.CFrame = rootCFrame
	streamAnchor.Parent = model

	model.PrimaryPart = parts["HumanoidRootPart"]

	return model
end

local function createNameBillboard(model, displayName, roleText)
	local head = model:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameGui"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 50
	billboard.LightInfluence = 0
	billboard.Adornee = head
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = displayName
	nameLabel.Parent = billboard

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Size = UDim2.fromScale(1, 0.35)
	roleLabel.Position = UDim2.fromScale(0, 0.6)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Font = Enum.Font.Gotham
	roleLabel.TextScaled = true
	roleLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	roleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	roleLabel.TextStrokeTransparency = 0.5
	roleLabel.Text = roleText or "Villager"
	roleLabel.Parent = billboard
end

local function createGlowingRing(model, rootCFrame)
	local ring = Instance.new("Part")
	ring.Name = "InteractionRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 4, 4)
	ring.CFrame = CFrame.new(rootCFrame.Position) * CFrame.new(0, -1.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = RING_COLOR
	ring.Transparency = 0.3
	ring.Parent = model

	local innerRing = Instance.new("Part")
	innerRing.Name = "InnerRing"
	innerRing.Shape = Enum.PartType.Cylinder
	innerRing.Size = Vector3.new(0.1, 3.2, 3.2)
	innerRing.CFrame = ring.CFrame
	innerRing.Anchored = true
	innerRing.CanCollide = false
	innerRing.CanQuery = false
	innerRing.Material = Enum.Material.Neon
	innerRing.Color = RING_SECONDARY
	innerRing.Transparency = 0.6
	innerRing.Parent = model

	return ring, innerRing
end

local function createProximityPrompt(model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Hold to Talk"
	prompt.ObjectText = ""
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 1.0
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.RequiresLineOfSight = false
	prompt.Parent = hrp
end

local activeRings = {}

for _, config in NPC_CONFIGS do
	local placedConfig = copyConfig(config)
	placedConfig.position, placedConfig.facingAngle = resolveNPCSpawn(config)

	local model = buildR6Rig(placedConfig)
	local rootCFrame = CFrame.new(placedConfig.position) * CFrame.Angles(0, math.rad(placedConfig.facingAngle), 0)

	createNameBillboard(model, placedConfig.displayName, placedConfig.roleText)

	if placedConfig.hasQuestPrompt ~= false then
		local ring, innerRing = createGlowingRing(model, rootCFrame)
		createProximityPrompt(model)
		CollectionService:AddTag(model, "QuestGiver")
		table.insert(activeRings, { ring = ring, innerRing = innerRing, baseCFrame = ring.CFrame })
	end

	model.Parent = npcsFolder

	print("[NPCSpawner] Spawned " .. placedConfig.displayName .. " (" .. placedConfig.id .. ") at " .. tostring(placedConfig.position))
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	for _, ringData in activeRings do
		local pulse = 0.3 + 0.15 * math.sin(elapsed * 2.5)
		ringData.ring.Transparency = pulse

		local innerPulse = 0.55 + 0.15 * math.sin(elapsed * 2.5 + math.pi)
		ringData.innerRing.Transparency = innerPulse

		local basePos = ringData.baseCFrame.Position
		ringData.ring.CFrame = CFrame.new(basePos) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(elapsed * 0.8, 0, 0)
	end
end)

print("[NPCSpawner] Loaded - " .. #NPC_CONFIGS .. " NPC(s) spawned")
