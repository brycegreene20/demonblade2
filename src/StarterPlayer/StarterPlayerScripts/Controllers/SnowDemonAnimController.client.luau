local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local IDLE_ID = "rbxassetid://97520328547508"
local WALK_ID = "rbxassetid://77060023937248"
local ATTACK_ID = "rbxassetid://128721527688471"
local MOVE_THRESHOLD = 0.05
local WALK_TIMEOUT = 0.75
local VFX_RENDER_DISTANCE = 180
local FROST_PRIMARY = Color3.fromRGB(90, 205, 255)
local FROST_SECONDARY = Color3.fromRGB(225, 250, 255)

-- Track tables keyed by demon model so the remote handler can reach any demon's tracks.
local idleTracks = {}
local walkTracks = {}
local attackTracks = {}

local attackAnimRemote = ReplicatedStorage:WaitForChild("SnowDemonAttackAnim")
local vfxAssets = ReplicatedStorage:WaitForChild("VFXAssets")
local soundAssets = ReplicatedStorage:WaitForChild("Assets")
local localPlayer = Players.LocalPlayer
local missingVFXWarnings = {}

local function findVFXTemplate(templateName)
	local container = vfxAssets:FindFirstChild("AnimeParticles")
	local template = container and container:FindFirstChild(templateName, true)
	if not template and not missingVFXWarnings[templateName] then
		missingVFXWarnings[templateName] = true
		warn(("[SnowDemonAnim] Missing owned VFX template AnimeParticles/%s"):format(templateName))
	end
	return template
end

local function spawnFrostBurst(templateName, cframe, particleCount, lifetime)
	local template = findVFXTemplate(templateName)
	if not template then return end

	local clone = template:Clone()
	if clone:IsA("BasePart") then
		clone.CFrame = cframe
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
	elseif clone:IsA("Model") then
		clone:PivotTo(cframe)
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant.Color = ColorSequence.new(FROST_PRIMARY, FROST_SECONDARY)
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Color = ColorSequence.new(FROST_PRIMARY, FROST_SECONDARY)
		end
	end

	clone.Parent = workspace
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local authoredCount = tonumber(descendant:GetAttribute("EmitCount")) or 0
			descendant:Emit(math.max(particleCount, authoredCount))
		end
	end
	Debris:AddItem(clone, lifetime)
end

local function playOwnedSlashSound(root)
	local container = soundAssets:FindFirstChild("Slashes anime")
	if not container then return end

	local source = if container:IsA("Sound") and container.SoundId ~= ""
		then container
		else container:FindFirstChildWhichIsA("Sound", true)
	if not source then return end

	local sound = source:Clone()
	sound.Volume = 0.24
	sound.RollOffMaxDistance = 75
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function playFrostAttackVFX(demon, targetPosition)
	local root = demon:FindFirstChild("HumanoidRootPart") or demon.PrimaryPart
	if not root or typeof(targetPosition) ~= "Vector3" then return end

	local localCharacter = localPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	if localRoot and (localRoot.Position - root.Position).Magnitude > VFX_RENDER_DISTANCE then
		return
	end

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local flatTarget = Vector3.new(targetPosition.X, origin.Y, targetPosition.Z)
	local direction = flatTarget - origin
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end

	local attackCFrame = CFrame.lookAt(origin, origin + direction.Unit)
	spawnFrostBurst("Wind-02", attackCFrame, 12, 0.65)
	spawnFrostBurst("Slashes-01", attackCFrame * CFrame.new(0, 0, -3), 24, 0.75)
	playOwnedSlashSound(root)

	task.delay(0.28, function()
		if not demon.Parent or not root.Parent then return end
		local impactPosition = root.Position + direction.Unit * 4 + Vector3.new(0, 1.2, 0)
		spawnFrostBurst("Slash-Impact-01", CFrame.lookAt(impactPosition, impactPosition + direction.Unit), 20, 0.65)
	end)
end

attackAnimRemote.OnClientEvent:Connect(function(demon, targetPosition)
	if not demon or not demon:IsA("Model") then return end
	local idleTrack = idleTracks[demon]
	local walkTrack = walkTracks[demon]
	local attackTrack = attackTracks[demon]
	if not attackTrack then
		warn("[SnowDemonAnim] No attack track registered for", demon.Name)
		return
	end
	if idleTrack then
		idleTrack:Stop(0.05)
	end
	if walkTrack then
		walkTrack:Stop(0.05)
	end
	attackTrack:Play(0)
	playFrostAttackVFX(demon, targetPosition)
end)

local function setupDemon(demon)
	local humanoid = demon:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local function loadTrack(id, looped)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track.Looped = looped
		return track
	end

	local idleTrack = loadTrack(IDLE_ID, true)
	local walkTrack = loadTrack(WALK_ID, true)

	local attackTrack
	local ok, err = pcall(function()
		attackTrack = loadTrack(ATTACK_ID, false)
		attackTrack.Priority = Enum.AnimationPriority.Action
	end)
	if ok then
		print("[SnowDemonAnim] Attack track loaded for", demon.Name)
	else
		warn("[SnowDemonAnim] Attack track failed:", err)
	end

	idleTracks[demon] = idleTrack
	walkTracks[demon] = walkTrack
	attackTracks[demon] = attackTrack

	idleTrack:Play()

	if attackTrack then
		attackTrack.Ended:Connect(function()
			if humanoid.Health > 0 then
				idleTrack:Play(0.15)
			end
		end)
	end

	local hrp = demon:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local lastPos = hrp.Position
	local lastMoveTime = 0
	local isWalking = false

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not demon.Parent or not hrp.Parent then
			conn:Disconnect()
			return
		end

		if attackTrack and attackTrack.IsPlaying then return end

		local now = tick()
		local moved = (hrp.Position - lastPos).Magnitude
		lastPos = hrp.Position

		if moved > MOVE_THRESHOLD then
			lastMoveTime = now
		end

		local moving = (now - lastMoveTime) < WALK_TIMEOUT

		if moving and not isWalking then
			isWalking = true
			idleTrack:Stop(0.2)
			walkTrack:Play(0.2)
		elseif not moving and isWalking then
			isWalking = false
			walkTrack:Stop(0.2)
			idleTrack:Play(0.2)
		end
	end)

	humanoid.Died:Connect(function()
		conn:Disconnect()
		idleTrack:Stop()
		walkTrack:Stop()
		if attackTrack then
			attackTrack:Stop()
		end
		idleTracks[demon] = nil
		walkTracks[demon] = nil
		attackTracks[demon] = nil
	end)
end

local snowDemons = workspace:WaitForChild("SnowDemons")

for _, demon in snowDemons:GetChildren() do
	if demon:IsA("Model") then
		task.defer(setupDemon, demon)
	end
end

snowDemons.ChildAdded:Connect(function(demon)
	if demon:IsA("Model") then
		task.defer(setupDemon, demon)
	end
end)
