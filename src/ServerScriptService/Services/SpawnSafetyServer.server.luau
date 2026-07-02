--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local WorldSpawnConfigModule = require(Modules:WaitForChild("WorldSpawnConfigModule"))

local SPAWN_CLEARANCE = 5
local MARKERS_FOLDER_NAME = "DemonBlade2Markers"
local PRIMARY_SAFE_ZONE_MARKER_NAME = "SafeZoneCenter"
local SAFE_ZONE_MARKER_PREFIX = "SafeZone_"
local SAFE_SPAWN_SAMPLE_OFFSETS = {
	Vector2.new(0, 0),
	Vector2.new(8, 0),
	Vector2.new(-8, 0),
	Vector2.new(0, 8),
	Vector2.new(0, -8),
	Vector2.new(14, 14),
	Vector2.new(-14, 14),
	Vector2.new(14, -14),
	Vector2.new(-14, -14),
}

local function getMarkerPart(markerName): BasePart?
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

local function isSafeZoneMarker(marker: Instance): boolean
	return marker:IsA("BasePart")
		and (
			marker:GetAttribute("MarkerRole") == "SafeZone"
			or marker.Name == PRIMARY_SAFE_ZONE_MARKER_NAME
			or string.sub(marker.Name, 1, #SAFE_ZONE_MARKER_PREFIX) == SAFE_ZONE_MARKER_PREFIX
		)
end

local function getPrimarySafeZoneMarker(): BasePart?
	local primary = getMarkerPart(PRIMARY_SAFE_ZONE_MARKER_NAME)
	if primary then
		return primary
	end

	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if not markersFolder then
		return nil
	end

	local fallback = nil
	for _, child in markersFolder:GetChildren() do
		if isSafeZoneMarker(child) then
			local marker = child :: BasePart
			if marker:GetAttribute("SpawnSafeZone") == true then
				return marker
			end
			if not fallback or marker.Name < fallback.Name then
				fallback = marker
			end
		end
	end
	return fallback
end

local function getConfiguredSafeSpawnCFrame(): CFrame
	-- selene: allow(global_usage)
	local zoneServer = shared and shared.ZoneServer
	if zoneServer and zoneServer.getSafeSpawnCFrame then
		local ok, cframe = pcall(zoneServer.getSafeSpawnCFrame)
		if ok and typeof(cframe) == "CFrame" then
			return cframe
		end
	end
	local marker = getPrimarySafeZoneMarker()
	if marker then
		return CFrame.new(marker.Position + WorldSpawnConfigModule.SAFE_ZONE.spawnOffset)
	end
	return WorldSpawnConfigModule.getSafeSpawnCFrame()
end

local function getGroundedSafeSpawnCFrame(character: Model): CFrame
	local configured = getConfiguredSafeSpawnCFrame()
	local configuredPosition = configured.Position

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = { character }
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	rayParams.FilterDescendantsInstances = excluded
	rayParams.IgnoreWater = true
	rayParams.RespectCanCollide = true

	local bestGround = nil
	for _, offset in SAFE_SPAWN_SAMPLE_OFFSETS do
		local origin = configuredPosition + Vector3.new(offset.X, 250, offset.Y)
		local result = workspace:Raycast(origin, Vector3.new(0, -500, 0), rayParams)
		if result and result.Normal.Y >= 0.65 then
			if not bestGround or result.Position.Y < bestGround.Y then
				bestGround = result.Position
			end
		end
	end

	if bestGround then
		return CFrame.new(bestGround + Vector3.new(0, SPAWN_CLEARANCE, 0))
	end

	return configured
end

local function safeSpawn(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not hrp then return end
	task.wait(0.2)

	local spawnCFrame = getGroundedSafeSpawnCFrame(character)
	character:PivotTo(spawnCFrame)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(safeSpawn)
	if player.Character then
		safeSpawn(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[SpawnSafetyServer] Loaded")
