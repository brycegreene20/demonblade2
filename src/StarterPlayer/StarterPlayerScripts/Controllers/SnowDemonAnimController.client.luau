local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IDLE_ID = "rbxassetid://97520328547508"
local WALK_ID = "rbxassetid://77060023937248"
local ATTACK_ID = "rbxassetid://128721527688471"
local MOVE_THRESHOLD = 0.05
local WALK_TIMEOUT = 0.75

-- Track tables keyed by demon model so the remote handler can reach any demon's tracks.
local idleTracks = {}
local walkTracks = {}
local attackTracks = {}

local attackAnimRemote = ReplicatedStorage:WaitForChild("SnowDemonAttackAnim")

attackAnimRemote.OnClientEvent:Connect(function(demon)
	print("[SnowDemonAnim] Remote received for", demon.Name)
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
