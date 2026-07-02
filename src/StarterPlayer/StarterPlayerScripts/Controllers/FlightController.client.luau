--!strict
-- FlightController: handles flight physics for all flight-slot (T) skills.
-- Exposes _G.FlightController = { isFlying, stop() } for CombatController to call.

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local Remotes              = ReplicatedStorage:WaitForChild("Remotes")
local SkillActivatedRemote = Remotes:WaitForChild("SkillActivated")

local FLIGHT_SKILL_IDS: { [string]: true } = {
	WaterFlight       = true,
	FlameFlight       = true,
	DemonFlight       = true,
	TemariFlightSkill = true,
}

local FLIGHT_SPEED         = 45    -- studs/s horizontal
local FLIGHT_VERTICAL_SPEED = 22   -- studs/s up/down
local FLIGHT_MAX_DURATION  = 20    -- seconds before auto-land
local FLIGHT_ACCEL         = 12    -- lerp speed (higher = snappier)

local isFlying       = false
local flightStart    = 0
local flightLoop: RBXScriptConnection?
local flightBV: BodyVelocity?

local function getHRP(): BasePart?
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(): Humanoid?
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

local function stopFlight()
	if not isFlying then return end
	isFlying = false

	if flightLoop then
		flightLoop:Disconnect()
		flightLoop = nil
	end

	if flightBV then
		flightBV:Destroy()
		flightBV = nil
	end

	local hum = getHumanoid()
	if hum then
		hum.PlatformStand = false
	end
end

local function startFlight()
	local hrp = getHRP()
	local hum = getHumanoid()
	if not hrp or not hum or hum.Health <= 0 then return end

	isFlying     = true
	flightStart  = os.clock()

	hum.PlatformStand = true

	local bv           = Instance.new("BodyVelocity")
	bv.MaxForce        = Vector3.new(1e6, 1e6, 1e6)
	bv.Velocity        = Vector3.zero
	bv.P               = 1500
	bv.Parent          = hrp
	flightBV           = bv

	flightLoop = RunService.RenderStepped:Connect(function(dt: number)
		local currentHRP = getHRP()
		local currentHum = getHumanoid()
		if not currentHRP or not currentHum or currentHum.Health <= 0 then
			stopFlight()
			return
		end

		if os.clock() - flightStart >= FLIGHT_MAX_DURATION then
			stopFlight()
			return
		end

		local lookVec  = camera.CFrame.LookVector
		local rightVec = camera.CFrame.RightVector

		local moveDir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDir += lookVec
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDir -= lookVec
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDir -= rightVec
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDir += rightVec
		end

		local vertInput = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			vertInput = 1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.C) then
			vertInput = -1
		end

		local horizontal: Vector3
		if moveDir.Magnitude > 0.001 then
			horizontal = moveDir.Unit * FLIGHT_SPEED
		else
			horizontal = Vector3.zero
		end

		local targetVelocity = Vector3.new(
			horizontal.X,
			vertInput * FLIGHT_VERTICAL_SPEED,
			horizontal.Z
		)

		bv.Velocity = bv.Velocity:Lerp(targetVelocity, math.min(1, dt * FLIGHT_ACCEL))

		-- Face movement direction when moving horizontally
		if horizontal.Magnitude > 1 then
			local flat = Vector3.new(horizontal.X, 0, horizontal.Z)
			local targetCF = CFrame.lookAt(currentHRP.Position, currentHRP.Position + flat)
			currentHRP.CFrame = currentHRP.CFrame:Lerp(targetCF, math.min(1, dt * 8))
		end
	end)
end

-- React to server confirming our own flight skill activation
SkillActivatedRemote.OnClientEvent:Connect(function(firstArg: any, _second: any)
	if typeof(firstArg) ~= "string" then return end
	if FLIGHT_SKILL_IDS[firstArg] then
		startFlight()
	end
end)

-- Land on death or respawn
local function hookCharacter(character: Model)
	stopFlight()
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(stopFlight)
end

if LocalPlayer.Character then
	hookCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookCharacter)

-- selene: allow(global_usage)
_G.FlightController = {
	isFlying = false,
	stop     = stopFlight,
}

-- Keep _G.FlightController.isFlying in sync
RunService.Heartbeat:Connect(function()
	_G.FlightController.isFlying = isFlying
end)

print("[FlightController] Loaded — T to fly, T again to land (max " .. FLIGHT_MAX_DURATION .. "s)")
