-- DemonBlade2 Asset Brush
-- 1. Select models in the Explorer (or put them in ServerStorage/BrushAssets)
-- 2. Click "Asset Brush" in the Plugins toolbar to activate
-- 3. Hold left mouse button and drag to paint
-- [ / ] keys to shrink / grow the brush while active

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection            = game:GetService("Selection")
local ServerStorage        = game:GetService("ServerStorage")
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")

local toolbar     = plugin:CreateToolbar("DemonBlade2")
local brushButton = toolbar:CreateButton(
	"Asset Brush",
	"Select assets in Explorer then drag to paint  |  [ ] = resize  |  Ctrl+Z = undo",
	"rbxassetid://7072706620"
)

-- ── Config ────────────────────────────────────────────────────────────────────
local brushRadius    = 12    -- studs
local placeCooldown  = 0.2   -- seconds between placements while dragging
local scaleMin       = 0.85
local scaleMax       = 1.15
local rng = Random.new()

-- ── State ─────────────────────────────────────────────────────────────────────
local active        = false
local indicator     = nil
local heartbeatConn = nil
local keyConn       = nil
local lastPlace     = 0
local mouse         = plugin:GetMouse()

-- ── Asset pool ────────────────────────────────────────────────────────────────
local function getPool()
	-- Priority 1: whatever is selected in the Explorer right now
	local pool = {}
	for _, inst in Selection:Get() do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			pool[#pool + 1] = inst
		end
	end
	if #pool > 0 then
		print("[AssetBrush] Using " .. #pool .. " selected asset(s) as brush pool.")
		return pool
	end

	-- Priority 2: ServerStorage/BrushAssets folder
	local folder = ServerStorage:FindFirstChild("BrushAssets")
	if folder then
		for _, inst in folder:GetChildren() do
			if inst:IsA("Model") or inst:IsA("BasePart") then
				pool[#pool + 1] = inst
			end
		end
	end

	if #pool == 0 then
		warn("[AssetBrush] No assets found!\nSelect models in the Explorer first, or put them in ServerStorage/BrushAssets.")
	else
		print("[AssetBrush] Using ServerStorage/BrushAssets (" .. #pool .. " asset(s)).")
	end
	return pool
end

-- ── Brush indicator ───────────────────────────────────────────────────────────
local function makeIndicator()
	local p = Instance.new("Part")
	p.Name        = "__BrushIndicator__"
	p.Anchored    = true
	p.CanCollide  = false
	p.CanQuery    = false
	p.CanTouch    = false
	p.CastShadow  = false
	p.Locked      = true
	p.Shape       = Enum.PartType.Cylinder
	p.Size        = Vector3.new(0.3, brushRadius * 2, brushRadius * 2)
	p.Material    = Enum.Material.Neon
	p.Color       = Color3.fromRGB(0, 220, 100)
	p.Transparency = 0.5
	p.Parent      = workspace
	return p
end

local function updateIndicatorSize()
	if indicator then
		indicator.Size = Vector3.new(0.3, brushRadius * 2, brushRadius * 2)
	end
end

-- ── Model placement ───────────────────────────────────────────────────────────
local function pivotTo(inst, cf)
	if inst:IsA("Model") then inst:PivotTo(cf) else inst.CFrame = cf end
end

local function placeAt(hitPos, pool)
	if #pool == 0 then return end

	local template = pool[rng:NextInteger(1, #pool)]
	local clone    = template:Clone()

	-- Random offset within brush radius (uniform distribution)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist  = math.sqrt(rng:NextNumber(0, 1)) * brushRadius
	local ox, oz = math.cos(angle) * dist, math.sin(angle) * dist

	-- Raycast down at offset to find actual ground
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = indicator and { indicator } or {}
	local downHit = workspace:Raycast(
		Vector3.new(hitPos.X + ox, hitPos.Y + 80, hitPos.Z + oz),
		Vector3.new(0, -200, 0),
		params
	)
	local groundY  = downHit and downHit.Position.Y or hitPos.Y
	local finalPos = Vector3.new(hitPos.X + ox, groundY, hitPos.Z + oz)

	local rot   = rng:NextNumber(0, math.pi * 2)
	local scale = rng:NextNumber(scaleMin, scaleMax)

	clone.Parent = workspace

	-- Scale
	if clone:IsA("Model") then
		pcall(function() clone:ScaleTo(scale) end)
	elseif clone:IsA("BasePart") then
		clone.Size = clone.Size * scale
	end

	-- Initial placement then correct bottom to sit on ground
	local rotCF = CFrame.Angles(0, rot, 0)
	pivotTo(clone, CFrame.new(finalPos) * rotCF)

	if clone:IsA("Model") then
		local boxCF, boxSz = clone:GetBoundingBox()
		local bottom     = boxCF.Position.Y - boxSz.Y / 2
		local correction = finalPos.Y - bottom
		pivotTo(clone, CFrame.new(finalPos.X, finalPos.Y + correction, finalPos.Z) * rotCF)
	end
end

-- ── Activate / deactivate ─────────────────────────────────────────────────────
local function activate()
	active = true
	brushButton:SetActive(true)
	plugin:Activate(true)
	indicator = makeIndicator()

	local pool = getPool()

	heartbeatConn = RunService.Heartbeat:Connect(function()
		local hit = mouse.Hit
		if not hit then return end

		-- Snap indicator to ground
		if indicator then
			indicator.CFrame = CFrame.new(hit.Position) * CFrame.Angles(0, 0, math.rad(90))
		end

		-- Paint while left button held
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			local now = tick()
			if now - lastPlace >= placeCooldown then
				lastPlace = now
				ChangeHistoryService:SetWaypoint("Before Paint Asset")
				placeAt(hit.Position, pool)
				ChangeHistoryService:SetWaypoint("After Paint Asset")
			end
		end
	end)

	-- [ / ] to resize brush
	keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.RightBracket then
			brushRadius = math.min(brushRadius + 2, 80)
			updateIndicatorSize()
			print("[AssetBrush] Brush radius: " .. brushRadius)
		elseif input.KeyCode == Enum.KeyCode.LeftBracket then
			brushRadius = math.max(brushRadius - 2, 2)
			updateIndicatorSize()
			print("[AssetBrush] Brush radius: " .. brushRadius)
		end
	end)

	print("[AssetBrush] Active — hold left mouse to paint  |  [ ] = resize  |  click toolbar button to stop")
end

local function deactivate()
	active = false
	brushButton:SetActive(false)
	plugin:Deactivate()
	if indicator     then indicator:Destroy();        indicator     = nil end
	if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
	if keyConn       then keyConn:Disconnect();       keyConn       = nil end
	print("[AssetBrush] Deactivated.")
end

brushButton.Click:Connect(function()
	if active then deactivate() else activate() end
end)

plugin.Unloading:Connect(deactivate)
