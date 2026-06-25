-- Extracts all scripts from a .rbxl file into the Rojo src/ folder structure
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local PLACE_FILE = "DemonBlade2.rbxl"
-- Map top-level service names to their src/ paths
local SERVICE_PATHS: { [string]: string } = {
	ServerScriptService = "src/ServerScriptService",
	ServerStorage = "src/ServerStorage",
	ReplicatedStorage = "src/ReplicatedStorage",
	StarterGui = "src/StarterGui",
	Workspace = "src/Workspace",
	ReplicatedFirst = "src/ReplicatedFirst",
}
local STARTER_PLAYER_PATHS: { [string]: string } = {
	StarterPlayerScripts = "src/StarterPlayer/StarterPlayerScripts",
	StarterCharacterScripts = "src/StarterPlayer/StarterCharacterScripts",
}

local written = 0
local skipped = 0
local errored = 0

local function sanitize(name: string): string
	return name:gsub('[\\/:*?"<>|]', "_")
end

local function ext(className: string): string
	if className == "Script" then
		return ".server.luau"
	elseif className == "LocalScript" then
		return ".client.luau"
	else
		return ".luau"
	end
end

local function safeWriteDir(path: string): boolean
	local ok, _err = pcall(fs.writeDir, path)
	if not ok then
		print("  [SKIP dir too long] " .. path)
		errored += 1
	end
	return ok
end

local function safeWriteFile(path: string, content: string): boolean
	local ok, _err = pcall(fs.writeFile, path, content)
	if not ok then
		print("  [SKIP path too long] " .. path)
		errored += 1
	else
		written += 1
		print("  [+] " .. path)
	end
	return ok
end

local function writeInstance(instance: Instance, basePath: string)
	local name = sanitize(instance.Name)
	local children = instance:GetChildren()
	local isScript = instance.ClassName == "Script"
		or instance.ClassName == "LocalScript"
		or instance.ClassName == "ModuleScript"

	if isScript then
		local source = (instance :: any).Source or ""
		if #children == 0 then
			safeWriteFile(basePath .. "/" .. name .. ext(instance.ClassName), source)
		else
			local folderPath = basePath .. "/" .. name
			if not fs.isDir(folderPath) then
				if not safeWriteDir(folderPath) then return end
			end
			safeWriteFile(folderPath .. "/init" .. ext(instance.ClassName), source)
			for _, child in children do
				writeInstance(child, folderPath)
			end
		end
	else
		if #children > 0 then
			local folderPath = basePath .. "/" .. name
			if not fs.isDir(folderPath) then
				if not safeWriteDir(folderPath) then return end
			end
			for _, child in children do
				writeInstance(child, folderPath)
			end
		else
			skipped += 1
		end
	end
end

-- Load the place
print("Reading " .. PLACE_FILE .. "...")
local placeData = fs.readFile(PLACE_FILE)
local game = roblox.deserializePlace(placeData)

-- Walk each mapped service
for serviceName, basePath in SERVICE_PATHS do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if not ok or service == nil then
		continue
	end
	print("\n-- " .. serviceName .. " --> " .. basePath)
	if not fs.isDir(basePath) then
		fs.writeDir(basePath)
	end
	for _, child in service:GetChildren() do
		writeInstance(child, basePath)
	end
end

-- StarterPlayer children mapped individually
local ok, starterPlayer = pcall(function()
	return game:GetService("StarterPlayer")
end)
if ok and starterPlayer then
	for childName, basePath in STARTER_PLAYER_PATHS do
		local container = starterPlayer:FindFirstChild(childName)
		if container then
			print("\n-- StarterPlayer." .. childName .. " --> " .. basePath)
			if not fs.isDir(basePath) then
				fs.writeDir(basePath)
			end
			for _, child in container:GetChildren() do
				writeInstance(child, basePath)
			end
		end
	end
end

print("\nDone! " .. written .. " files written, " .. skipped .. " non-script instances skipped, " .. errored .. " skipped (path too long).")
