-- Export non-script Roblox Studio assets from DemonBlade2.rbxl into Rojo-friendly
-- .rbxm files. This intentionally does not write or overwrite .luau files.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PLACE_FILE = "DemonBlade2.rbxl"

local exports: { { path: { string }, outDir: string, childrenOnly: boolean? } } = {
	{ path = { "ReplicatedStorage", "Assets" }, outDir = "src/ReplicatedStorage/Assets", childrenOnly = true },
	{ path = { "ReplicatedStorage", "Config" }, outDir = "src/ReplicatedStorage", childrenOnly = false },
	{ path = { "ReplicatedStorage", "NPCModels" }, outDir = "src/ReplicatedStorage/NPCModels", childrenOnly = true },
	{ path = { "ReplicatedStorage", "VFXAssets" }, outDir = "src/ReplicatedStorage/VFXAssets", childrenOnly = true },
	{ path = { "ServerStorage" }, outDir = "src/ServerStorage", childrenOnly = true },
	{ path = { "StarterGui" }, outDir = "src/StarterGui", childrenOnly = true },
	{ path = { "ReplicatedFirst" }, outDir = "src/ReplicatedFirst", childrenOnly = true },
	{ path = { "Lighting" }, outDir = "src/Lighting", childrenOnly = true },
	{ path = { "TextChatService" }, outDir = "src/TextChatService", childrenOnly = true },
	{ path = { "Workspace" }, outDir = "src/Workspace", childrenOnly = true },
}

local function sanitize(name: string): string
	return name:gsub('[\\/:*?"<>|]', "_")
end

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

-- Tracks how many times each base name has been used per output directory
-- so duplicate-named siblings get unique filenames: Foo.rbxm, Foo_2.rbxm, Foo_3.rbxm …
local usedNames: { [string]: { [string]: number } } = {}

local function getPath(root: Instance, path: { string }): Instance?
	local current: Instance = root

	for index, name in path do
		if index == 1 then
			local ok, service = pcall(function()
				return (current :: any):GetService(name)
			end)
			if ok and service then
				current = service
				continue
			end
		end

		local child = current:FindFirstChild(name)
		if not child then
			return nil
		end

		current = child
	end

	return current
end

local function isScript(instance: Instance): boolean
	return instance:IsA("LuaSourceContainer")
end

local function exportInstance(instance: Instance, outDir: string): boolean
	if isScript(instance) then
		return false
	end

	local baseName = sanitize(instance.Name)

	if not usedNames[outDir] then
		usedNames[outDir] = {}
	end

	local seen = usedNames[outDir][baseName] or 0
	usedNames[outDir][baseName] = seen + 1

	local fileName = if seen == 0 then baseName else baseName .. "_" .. (seen + 1)
	local outPath = outDir .. "/" .. fileName .. ".rbxm"
	local bytes = roblox.serializeModel({ instance })
	fs.writeFile(outPath, bytes)
	print(("[+] %s (%s) -> %s"):format(instance:GetFullName(), instance.ClassName, outPath))
	return true
end

print("Reading " .. PLACE_FILE .. "...")
local placeData = fs.readFile(PLACE_FILE)
local game = roblox.deserializePlace(placeData)

local count = 0

for _, item in exports do
	local instance = getPath(game, item.path)
	if not instance then
		warn("[SKIP missing] " .. table.concat(item.path, "."))
		continue
	end

	ensureDir(item.outDir)

	if item.childrenOnly then
		for _, child in instance:GetChildren() do
			if exportInstance(child, item.outDir) then
				count += 1
			end
		end
	else
		if exportInstance(instance, item.outDir) then
			count += 1
		end
	end
end

print(("Done. Exported %d non-script model files."):format(count))
