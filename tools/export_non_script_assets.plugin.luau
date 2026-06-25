-- Roblox Studio local plugin helper.
--
-- Purpose:
-- Export non-script Roblox Studio containers as .rbxmx files so they can be
-- brought into the Rojo/VS Code project without overwriting fixed .luau files.
--
-- Install temporarily by copying this file to:
--   %LOCALAPPDATA%/Roblox/Plugins/export_non_script_assets.plugin.luau
--
-- Then restart Studio or reload plugins, open DemonBlade2.rbxl, and use the
-- "Export Assets" toolbar.

local Selection = game:GetService("Selection")

local toolbar = plugin:CreateToolbar("DemonBlade2 Export")

local function getPath(path: { string }): Instance?
	local current: Instance = game

	for _, name in path do
		local nextInstance = current:FindFirstChild(name)
		if not nextInstance then
			warn(("[DemonBlade2 Export] Missing %s"):format(table.concat(path, ".")))
			return nil
		end

		current = nextInstance
	end

	return current
end

local function promptSaveSelection(label: string, fileName: string, targets: { Instance })
	if #targets == 0 then
		warn(("[DemonBlade2 Export] Nothing found for %s"):format(label))
		return
	end

	Selection:Set(targets)
	print(("[DemonBlade2 Export] Saving %s. Choose this repo when prompted."):format(label))
	plugin:PromptSaveSelection(fileName)
end

local exportReplicatedStorage = toolbar:CreateButton(
	"Export ReplicatedStorage assets",
	"Export Assets, NPCModels, and VFXAssets as one .rbxmx selection",
	""
)

exportReplicatedStorage.Click:Connect(function()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local targets = {}

	for _, name in { "Assets", "NPCModels", "VFXAssets" } do
		local child = replicatedStorage:FindFirstChild(name)
		if child then
			table.insert(targets, child)
		else
			warn(("[DemonBlade2 Export] ReplicatedStorage.%s was not found"):format(name))
		end
	end

	promptSaveSelection("ReplicatedStorage asset containers", "ReplicatedStorage_NonScripts.rbxmx", targets)
end)

local exportServerStorage = toolbar:CreateButton(
	"Export ServerStorage",
	"Export ServerStorage non-script folders as one .rbxmx selection",
	""
)

exportServerStorage.Click:Connect(function()
	local serverStorage = game:GetService("ServerStorage")
	promptSaveSelection("ServerStorage children", "ServerStorage_NonScripts.rbxmx", serverStorage:GetChildren())
end)

local exportStarterGui = toolbar:CreateButton(
	"Export StarterGui",
	"Export StarterGui contents as one .rbxmx selection",
	""
)

exportStarterGui.Click:Connect(function()
	local starterGui = game:GetService("StarterGui")
	promptSaveSelection("StarterGui children", "StarterGui_NonScripts.rbxmx", starterGui:GetChildren())
end)

local exportWorkspaceNonScripts = toolbar:CreateButton(
	"Export Workspace non-scripts",
	"Export Workspace children except Script instances as one .rbxmx selection",
	""
)

exportWorkspaceNonScripts.Click:Connect(function()
	local targets = {}

	for _, child in workspace:GetChildren() do
		if not child:IsA("LuaSourceContainer") then
			table.insert(targets, child)
		end
	end

	promptSaveSelection("Workspace non-script children", "Workspace_NonScripts.rbxmx", targets)
end)

local inspectForestDemon = toolbar:CreateButton(
	"Inspect ForestDemon",
	"Print child counts for ReplicatedStorage.Assets.ForestDemon",
	""
)

inspectForestDemon.Click:Connect(function()
	local forestDemon = getPath({ "ReplicatedStorage", "Assets", "ForestDemon" })
	if not forestDemon then
		return
	end

	print("[DemonBlade2 Export] ForestDemon descendant count:", #forestDemon:GetDescendants())

	local head = forestDemon:FindFirstChild("Head")
	if head then
		print("[DemonBlade2 Export] ForestDemon.Head descendant count:", #head:GetDescendants())
		for _, child in head:GetChildren() do
			print(("[DemonBlade2 Export]   Head child: %s (%s)"):format(child.Name, child.ClassName))
		end
	end
end)
