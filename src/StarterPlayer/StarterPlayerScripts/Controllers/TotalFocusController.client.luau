--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TotalFocusToggle  = Remotes:WaitForChild("TotalFocusToggle")
local TotalFocusChanged = Remotes:WaitForChild("TotalFocusChanged")
local TotalFocusRebirth = Remotes:WaitForChild("TotalFocusRebirth")

local HALO_NAME = "TotalFocusHalo"
local currentState = { active = false, tierIndex = 0, haloColor = Color3.fromRGB(0, 220, 80) }

local function getHRP(): BasePart?
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function removeHalo()
	local char = LocalPlayer.Character
	if not char then return end
	local existing = char:FindFirstChild(HALO_NAME)
	if existing then
		existing:Destroy()
	end
end

local function spawnHalo(color: Color3)
	removeHalo()
	local hrp = getHRP()
	if not hrp then return end
	local char = LocalPlayer.Character
	if not char then return end

	local halo = Instance.new("Part")
	halo.Name = HALO_NAME
	halo.Shape = Enum.PartType.Cylinder
	halo.Size = Vector3.new(0.15, 5.5, 5.5)
	halo.Anchored = false
	halo.CanCollide = false
	halo.CanQuery = false
	halo.CanTouch = false
	halo.CastShadow = false
	halo.Massless = true
	halo.Material = Enum.Material.Neon
	halo.Color = color
	halo.Transparency = 0.35
	halo.Parent = char

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = halo
	weld.Parent = halo
	halo.CFrame = hrp.CFrame * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))

	-- Pulse transparency
	local function pulse()
		if not halo.Parent then return end
		TweenService:Create(halo, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.6,
		}):Play()
	end
	pulse()
end

local function applyVisuals()
	if currentState.active and currentState.tierIndex > 0 then
		spawnHalo(currentState.haloColor)
	else
		removeHalo()
	end
end

TotalFocusChanged.OnClientEvent:Connect(function(state: { active: boolean, tierIndex: number, haloColor: Color3, label: string, xp: number })
	currentState.active = state.active
	currentState.tierIndex = state.tierIndex
	currentState.haloColor = state.haloColor
	applyVisuals()
end)

-- J (keyboard) or DPad Up (controller) to toggle
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.J or input.KeyCode == Enum.KeyCode.DPadUp then
		TotalFocusToggle:FireServer()
	end
end)

-- Re-apply halo on respawn
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	applyVisuals()
end)

-- selene: allow(global_usage)
_G.TotalFocusController = {
	requestRebirth = function()
		TotalFocusRebirth:FireServer()
	end,
}

print("[TotalFocusController] Loaded — J to toggle Total Focus")
