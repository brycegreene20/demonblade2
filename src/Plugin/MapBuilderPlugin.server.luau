local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

local toolbar     = plugin:CreateToolbar("DemonBlade2")
local placeButton = toolbar:CreateButton("Place Assets", "Place repo models in edit mode (no terrain)", "rbxassetid://7072706620")
local clearButton = toolbar:CreateButton("Clear Assets", "Remove the Environment folder",               "rbxassetid://7072706661")

local function pivotTo(model, cf)
	if model:IsA("Model") then
		model:PivotTo(cf)
	elseif model:IsA("BasePart") then
		model.CFrame = cf
	end
end

local function placeModel(template, x, groundY, z, rot)
	local clone = template:Clone()
	clone.Parent = workspace
	local rotCF = CFrame.Angles(0, rot or 0, 0)
	pivotTo(clone, CFrame.new(x, groundY, z) * rotCF)
	local boxCF, boxSize = clone:GetBoundingBox()
	local bottom     = boxCF.Position.Y - boxSize.Y / 2
	local correction = groundY - bottom
	pivotTo(clone, CFrame.new(x, groundY + correction, z) * rotCF)
	return clone
end

local function placeAssets()
	ChangeHistoryService:SetWaypoint("Before Place Assets")

	local old = workspace:FindFirstChild("Environment")
	if old then old:Destroy() end

	local envFolder = Instance.new("Folder")
	envFolder.Name  = "Environment"
	envFolder.Parent = workspace

	local Assets    = ReplicatedStorage:FindFirstChild("Assets")
	local NPCModels = ReplicatedStorage:FindFirstChild("NPCModels")

	-- Training dummies
	local dummyTemplate = (NPCModels and NPCModels:FindFirstChild("TrainingDummy"))
		or (Assets and Assets:FindFirstChild("TrainingDummy"))
	if dummyTemplate then
		local cols, rows, spacing = 4, 3, 8
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				local clone = placeModel(dummyTemplate, 258 + col * spacing, 0.5, 8 + row * spacing, 0)
				clone.Name   = "TrainingDummy"
				clone.Parent = envFolder
			end
		end
		print("[DemonBlade2] Placed " .. (cols * rows) .. " training dummies.")
	else
		warn("[DemonBlade2] TrainingDummy not found in ReplicatedStorage.")
	end

	-- Forest Demon
	local demonTemplate = Assets and Assets:FindFirstChild("ForestDemon")
	if demonTemplate then
		local clone = placeModel(demonTemplate, -280, 0.5, 0, 0)
		clone.Name   = "ForestDemon_Preview"
		clone.Parent = envFolder
		print("[DemonBlade2] Placed ForestDemon.")
	else
		warn("[DemonBlade2] ForestDemon not found in ReplicatedStorage/Assets.")
	end

	ChangeHistoryService:SetWaypoint("After Place Assets")
end

local function clearAssets()
	ChangeHistoryService:SetWaypoint("Before Clear Assets")
	local env = workspace:FindFirstChild("Environment")
	if env then
		env:Destroy()
		print("[DemonBlade2] Environment cleared.")
	end
	ChangeHistoryService:SetWaypoint("After Clear Assets")
end

placeButton.Click:Connect(function()
	placeButton:SetActive(false)
	placeAssets()
end)

clearButton.Click:Connect(function()
	clearButton:SetActive(false)
	clearAssets()
end)
