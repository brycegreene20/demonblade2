local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LungeRemote = Remotes:WaitForChild("Lunge")
local StaminaChanged = Remotes:WaitForChild("StaminaChanged")
local HPChanged = Remotes:WaitForChild("HPChanged")

local LUNGE_COOLDOWN = 0.9
local AERIAL_COOLDOWN = 1.1
local LUNGE_POWER = 110
local AERIAL_POWER_MULT = 1.1
local _IFRAME_DURATION = 0.2
local LUNGE_VFX_DURATION = 0.35
local DOUBLE_JUMP_MULT = 0.95
local MAX_DOWNWARD_ANGLE = math.rad(60)

local _lastLungeTime = 0
local isLunging = false
local doubleJumpAvailable = false
local hasDoubleJumped = false
local isAirborne = false
local currentStamina = 100
local _maxStamina = 100
local _currentHP = 100
local _maxHP = 100
local lungeCooldownExpiry = 0

local _lungeModule = {}

function _lungeModule.getCooldownRemaining()
	return math.max(0, lungeCooldownExpiry - os.clock())
end

function _lungeModule.getCooldownTotal()
	if isAirborne then return AERIAL_COOLDOWN end
	return LUNGE_COOLDOWN
end

-- selene: allow(global_usage)
_G.MovementController = _lungeModule

StaminaChanged.OnClientEvent:Connect(function(stamina, maxStam)
	currentStamina = stamina
	_maxStamina = maxStam
end)

HPChanged.OnClientEvent:Connect(function(hp, maxHp)
	_currentHP = hp
	_maxHP = maxHp
end)

local function getCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
	local character = getCharacter()
	return character:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
	local character = getCharacter()
	return character:FindFirstChild("HumanoidRootPart")
end

local function getLungeDirection()
	local humanoid = getHumanoid()
	local camera = workspace.CurrentCamera

	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		local dir = humanoid.MoveDirection
		return Vector3.new(dir.X, 0, dir.Z).Unit
	end

	if camera then
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end

	local hrp = getHRP()
	if hrp then
		local look = hrp.CFrame.LookVector
		return Vector3.new(look.X, 0, look.Z).Unit
	end

	return Vector3.new(0, 0, -1)
end

local function getAerialDirection()
	local humanoid = getHumanoid()
	local camera = workspace.CurrentCamera

	local dir
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		dir = humanoid.MoveDirection
	elseif camera then
		dir = camera.CFrame.LookVector
	else
		local hrp = getHRP()
		if hrp then
			dir = hrp.CFrame.LookVector
		else
			dir = Vector3.new(0, 0, -1)
		end
	end

	local angle = math.asin(math.clamp(-dir.Y / math.max(dir.Magnitude, 0.01), -1, 1))
	if angle > MAX_DOWNWARD_ANGLE then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude > 0.01 then
			dir = flat.Unit
		else
			dir = Vector3.new(0, 0, -1)
		end
	end

	if dir.Magnitude > 0.01 then
		return dir.Unit
	end
	return Vector3.new(0, 0, -1)
end

local function spawnLungeVFX(character, _direction)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local trail = Instance.new("Part")
	trail.Name = "LungeTrail"
	trail.Size = Vector3.new(0.3, 2, 4)
	trail.Anchored = true
	trail.CanCollide = false
	trail.CanQuery = false
	trail.CanTouch = false
	trail.Material = Enum.Material.Neon
	trail.Color = Color3.fromRGB(180, 200, 255)
	trail.Transparency = 0.4
	trail.CastShadow = false
	trail.CFrame = hrp.CFrame * CFrame.new(0, 0, 2)
	trail.Parent = workspace

	TweenService:Create(trail, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.05, 3, 6),
	}):Play()
	Debris:AddItem(trail, 0.3)
end

local function spawnDoubleJumpVFX(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local burst = Instance.new("Part")
	burst.Name = "DoubleJumpVFX"
	burst.Shape = Enum.PartType.Cylinder
	burst.Size = Vector3.new(0.3, 3, 3)
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Material = Enum.Material.Neon
	burst.Color = Color3.fromRGB(100, 180, 255)
	burst.Transparency = 0.3
	burst.CastShadow = false
	burst.CFrame = hrp.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	burst.Parent = workspace

	TweenService:Create(burst, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 8, 8),
		Transparency = 1,
	}):Play()
	Debris:AddItem(burst, 0.35)

	local ring = Instance.new("Part")
	ring.Name = "JumpRing"
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.new(1, 1, 1)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(140, 200, 255)
	ring.Transparency = 0.4
	ring.CastShadow = false
	ring.CFrame = hrp.CFrame * CFrame.new(0, -3, 0)
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(5, 5, 5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.3)
end

local function spawnAerialDashVFX(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, 3 do
		task.delay((i - 1) * 0.04, function()
			if not hrp or not hrp.Parent then return end
			local ghost = Instance.new("Part")
			ghost.Name = "AerialGhost"
			ghost.Size = Vector3.new(2, 4, 1)
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CanTouch = false
			ghost.Material = Enum.Material.Neon
			ghost.Color = Color3.fromRGB(120, 160, 255)
			ghost.Transparency = 0.5
			ghost.CastShadow = false
			ghost.CFrame = hrp.CFrame
			ghost.Parent = workspace

			TweenService:Create(ghost, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Size = Vector3.new(1, 2, 0.5),
			}):Play()
			Debris:AddItem(ghost, 0.35)
		end)
	end
end

local function lungeFOVPunch()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local originalFOV = camera.FieldOfView
	local targetFOV = originalFOV + 12

	TweenService:Create(camera, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = targetFOV}):Play()
	task.delay(0.1, function()
		TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FieldOfView = originalFOV}):Play()
	end)
end

local cachedLungeTrack = nil

local function playLungeAnimation(_humanoid)
	if not cachedLungeTrack then return end

	cachedLungeTrack:AdjustSpeed(1.8)
	cachedLungeTrack:Play(0.05)

	task.delay(LUNGE_VFX_DURATION, function()
		if cachedLungeTrack then
			cachedLungeTrack:Stop(0.1)
		end
	end)
end

local function performGroundLunge()
	local now = os.clock()
	if now < lungeCooldownExpiry then return end
	if isLunging then return end
	if currentStamina < 15 then return end

	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then return end

	local character = getCharacter()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dir = getLungeDirection()

	isLunging = true
	_lastLungeTime = now
	lungeCooldownExpiry = now + LUNGE_COOLDOWN

	LungeRemote:FireServer(dir, false)

	spawnLungeVFX(character, dir)
	lungeFOVPunch()
	playLungeAnimation(humanoid)

	local attachment = hrp:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = hrp
	end

	local force = Instance.new("LinearVelocity")
	force.MaxForce = math.huge
	force.VectorVelocity = dir * LUNGE_POWER
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Parent = hrp

	task.delay(0.18, function()
		if force and force.Parent then
			force:Destroy()
		end
	end)

	task.delay(LUNGE_COOLDOWN, function()
		isLunging = false
	end)
end

local function performAerialDash()
	local now = os.clock()
	if now < lungeCooldownExpiry then return end
	if isLunging then return end
	if currentStamina < 15 then return end

	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then return end

	local character = getCharacter()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dir = getAerialDirection()
	local aerialPower = LUNGE_POWER * AERIAL_POWER_MULT

	isLunging = true
	_lastLungeTime = now
	lungeCooldownExpiry = now + AERIAL_COOLDOWN

	LungeRemote:FireServer(dir, true)

	spawnAerialDashVFX(character)
	lungeFOVPunch()

	local attachment = hrp:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = hrp
	end

	local force = Instance.new("LinearVelocity")
	force.MaxForce = math.huge
	force.VectorVelocity = dir * aerialPower
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Parent = hrp

	task.delay(0.18, function()
		if force and force.Parent then
			force:Destroy()
		end
	end)

	task.delay(AERIAL_COOLDOWN, function()
		isLunging = false
	end)
end

local function performDoubleJump()
	if not doubleJumpAvailable then return end
	if hasDoubleJumped then return end

	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then return end

	local character = getCharacter()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	hasDoubleJumped = true
	doubleJumpAvailable = false

	local jumpImpulse = humanoid.JumpPower * DOUBLE_JUMP_MULT
	hrp.AssemblyLinearVelocity = Vector3.new(
		hrp.AssemblyLinearVelocity.X,
		jumpImpulse,
		hrp.AssemblyLinearVelocity.Z
	)

	spawnDoubleJumpVFX(character)
end

local function onShiftTap()
	if isAirborne then
		performAerialDash()
	else
		performGroundLunge()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		onShiftTap()
	end
end)

UserInputService.JumpRequest:Connect(function()
	if isAirborne and not hasDoubleJumped then
		performDoubleJump()
	end
end)

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	isLunging = false
	_lastLungeTime = 0
	lungeCooldownExpiry = 0
	doubleJumpAvailable = false
	hasDoubleJumped = false
	isAirborne = false

	cachedLungeTrack = nil
	task.defer(function()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = humanoid:WaitForChild("Animator", 5)
		end
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://180435571"
			cachedLungeTrack = animator:LoadAnimation(anim)
			cachedLungeTrack.Priority = Enum.AnimationPriority.Action2
		end
	end)

	humanoid.StateChanged:Connect(function(_oldState, newState)
		if newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
			if not isAirborne then
				isAirborne = true
				task.delay(0.1, function()
					if isAirborne then
						doubleJumpAvailable = true
					end
				end)
			end
		elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			isAirborne = false
			doubleJumpAvailable = false
			hasDoubleJumped = false
		end
	end)

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
end

local function onCharacterAdded(character)
	setupCharacter(character)
end

if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

print("[MovementController] Loaded - Lunge Dash + Double Jump + Aerial Dash")