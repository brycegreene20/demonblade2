local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

if not RunService:IsStudio() then
	return
end

local LocalPlayer = Players.LocalPlayer
local DIAGNOSTIC_INTERVAL = 60

local function countDescendants(instance)
	local ok, result = pcall(function()
		return #instance:GetDescendants()
	end)
	return ok and result or -1
end

local function getCharacterCount()
	local character = LocalPlayer.Character
	if not character then
		return 0
	end
	return countDescendants(character)
end

local function getPlayerGuiCount()
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return 0
	end
	return countDescendants(playerGui)
end

print("[ClientDiagnostics] Studio client diagnostics enabled")

task.spawn(function()
	task.wait(DIAGNOSTIC_INTERVAL)

	while true do
		print(
			"[ClientDiagnostics] uptime="
				.. tostring(math.floor(os.clock()))
				.. "s, workspaceDescendants="
				.. tostring(countDescendants(workspace))
				.. ", replicatedStorageDescendants="
				.. tostring(countDescendants(ReplicatedStorage))
				.. ", playerGuiDescendants="
				.. tostring(getPlayerGuiCount())
				.. ", characterDescendants="
				.. tostring(getCharacterCount())
				.. ", soundServiceDescendants="
				.. tostring(countDescendants(SoundService))
		)

		task.wait(DIAGNOSTIC_INTERVAL)
	end
end)
