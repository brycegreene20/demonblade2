--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SelflessStateToggle  = Remotes:WaitForChild("SelflessStateToggle")
local SelflessStateChanged = Remotes:WaitForChild("SelflessStateChanged")

-- PC key: C  |  Controller: DPad Down  |  Mobile: [Realm] button (wired separately in mobile UI)
local TOGGLE_KEY = Enum.KeyCode.C
local COOLDOWN   = 0.5

local lastToggleTime = 0
local AURA_NAME = "SelflessAura"

local currentState = { active = false, tier = 1, bonus = 0.10 }

local function getHRP(): BasePart?
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function removeAura()
	local char = LocalPlayer.Character
	if not char then return end
	local existing = char:FindFirstChild(AURA_NAME)
	if existing then
		existing:Destroy()
	end
end

local function spawnAura(tier: number)
	removeAura()
	local hrp = getHRP()
	if not hrp then return end
	local char = LocalPlayer.Character
	if not char then return end

	-- Aura color scales from silver (V1) toward white-gold (V10)
	local t = (tier - 1) / 9
	local color = Color3.fromRGB(
		math.floor(180 + t * 75),
		math.floor(180 + t * 70),
		math.floor(255 - t * 50)
	)

	local aura = Instance.new("Part")
	aura.Name = AURA_NAME
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.new(6, 6, 6)
	aura.Anchored = false
	aura.CanCollide = false
	aura.CanQuery = false
	aura.CanTouch = false
	aura.CastShadow = false
	aura.Massless = true
	aura.Material = Enum.Material.Neon
	aura.Color = color
	aura.Transparency = 0.7
	aura.CFrame = hrp.CFrame
	aura.Parent = char

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = aura
	weld.Parent = aura

	TweenService:Create(aura, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.85,
		Size = Vector3.new(6.5, 6.5, 6.5),
	}):Play()
end

local function applyVisuals()
	if currentState.active then
		spawnAura(currentState.tier)
	else
		removeAura()
	end
end

SelflessStateChanged.OnClientEvent:Connect(function(state: { active: boolean, tier: number, bonus: number })
	currentState.active = state.active
	currentState.tier = state.tier
	currentState.bonus = state.bonus
	applyVisuals()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.KeyCode ~= TOGGLE_KEY and input.KeyCode ~= Enum.KeyCode.DPadDown then return end
	local now = os.clock()
	if now - lastToggleTime < COOLDOWN then return end
	lastToggleTime = now
	SelflessStateToggle:FireServer()
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	applyVisuals()
end)

print("[SelflessStateController] Loaded — C to toggle Selfless State")
