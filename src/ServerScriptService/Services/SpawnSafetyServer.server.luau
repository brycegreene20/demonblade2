--!strict
local Players = game:GetService("Players")

local MIN_SAFE_Y = 2

local function safeSpawn(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not hrp then return end
	task.wait(0.15)
	if hrp.Position.Y < MIN_SAFE_Y then
		hrp.CFrame = CFrame.new(hrp.Position.X, MIN_SAFE_Y + 6, hrp.Position.Z)
	end
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
