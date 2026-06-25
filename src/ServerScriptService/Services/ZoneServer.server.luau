local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ZoneChangedRemote = Remotes:WaitForChild("ZoneChanged")

local ZONE_CHECK_INTERVAL = 0.5

local zonesFolder = workspace:FindFirstChild("Zones")
local zoneParts = {}
local playerZones = {}

local function loadZones()
	if not zonesFolder then
		print("[ZoneServer] No Zones folder found, all players will be in Wilderness")
		return
	end
	for _, child in zonesFolder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("ZoneName") then
			table.insert(zoneParts, {
				part = child,
				name = child:GetAttribute("ZoneName"),
				minLevel = child:GetAttribute("MinLevel") or 1,
				maxLevel = child:GetAttribute("MaxLevel") or 100,
			})
			print("[ZoneServer] Registered zone: " .. child:GetAttribute("ZoneName"))
		end
	end
end

local function isPointInPart(point, part)
	local relative = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2
	return math.abs(relative.X) <= halfSize.X
		and math.abs(relative.Y) <= halfSize.Y
		and math.abs(relative.Z) <= halfSize.Z
end

local function getZoneForPosition(position)
	for _, zone in zoneParts do
		if isPointInPart(position, zone.part) then
			return zone.name
		end
	end
	return "Wilderness"
end

local function checkPlayerZones()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local newZone = getZoneForPosition(hrp.Position)
		local oldZone = playerZones[player]

		if newZone ~= oldZone then
			playerZones[player] = newZone
			ZoneChangedRemote:FireClient(player, newZone, oldZone or "")
			print("[ZoneServer] " .. player.Name .. " entered zone: " .. newZone)
		end
	end
end

-- selene: allow(global_usage)
shared.ZoneServer = {
	getPlayerZone = function(player)
		return playerZones[player] or "Wilderness"
	end,
	getZoneForPosition = getZoneForPosition,
}

Players.PlayerRemoving:Connect(function(player)
	playerZones[player] = nil
end)

loadZones()

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= ZONE_CHECK_INTERVAL then
		elapsed = 0
		checkPlayerZones()
	end
end)

print("[ZoneServer] Loaded - " .. #zoneParts .. " zones registered")