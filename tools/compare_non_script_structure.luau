local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local function getEntryName(entry): string?
	if type(entry) == "string" then
		return entry
	end
	return entry.name
end

local function getPlaceUpdateNumber(path: string): number?
	local lowerPath = string.lower(path)
	if lowerPath == "demonblade2.rbxl" then
		return -1
	end

	local update = string.match(lowerPath, "^demonblade2 update%s*(%d+)%.rbxl$")
	return update and tonumber(update) or nil
end

local function findLatestOriginalPlacePath(): string
	local bestPath = nil
	local bestUpdate = -2
	for _, entry in fs.readDir(".") do
		local name = getEntryName(entry)
		local update = name and getPlaceUpdateNumber(name) or nil
		if update and update > bestUpdate then
			bestPath = name
			bestUpdate = update
		end
	end

	if not bestPath then
		error("No original place file found. Expected DemonBlade2.rbxl or DemonBlade2 updateN.rbxl.")
	end
	return bestPath
end

local function readFirstAvailable(paths: { string }): (string, string)
	for _, path in paths do
		local ok, contents = pcall(fs.readFile, path)
		if ok then
			return contents, path
		end
	end
	error("None of these files could be read: " .. table.concat(paths, ", "))
end

local originalPath = findLatestOriginalPlacePath()
local originalBytes = fs.readFile(originalPath)
local builtBytes, builtPath = readFirstAvailable({
	"build_check.rbxl",
})

local okOrig, original = pcall(roblox.deserializePlace, originalBytes)
if not okOrig then
	print("WARN: Could not deserialize original place (" .. originalPath .. "): " .. tostring(original))
	print("Skipping structure comparison — place file contains properties unsupported by this Lune version.")
	return
end

local okBuilt, built = pcall(roblox.deserializePlace, builtBytes)
if not okBuilt then
	print("WARN: Could not deserialize built place (" .. builtPath .. "): " .. tostring(built))
	print("Skipping structure comparison.")
	return
end

print("Original place: " .. originalPath)
print("Built place: " .. builtPath)

local serviceNames = {
	"ReplicatedFirst",
	"ReplicatedStorage",
	"Players",
	"MaterialService",
	"NetworkClient",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"Lighting",
	"SoundService",
	"TextChatService",
}

local function addTree(instance: Instance, path: string, output: { [string]: string })
	if instance:IsA("LuaSourceContainer") then
		return
	end

	output[path] = instance.ClassName

	local seen: { [string]: number } = {}
	for _, child in instance:GetChildren() do
		local key = child.Name
		seen[key] = (seen[key] or 0) + 1
		local suffix = seen[key] > 1 and ("#" .. tostring(seen[key])) or ""
		addTree(child, path .. "/" .. child.Name .. suffix, output)
	end
end

local function collect(root: Instance): { [string]: string }
	local output = {}

	for _, serviceName in serviceNames do
		local ok, service = pcall(function()
			return root:GetService(serviceName)
		end)

		if ok and service then
			addTree(service, serviceName, output)
		end
	end

	return output
end

local before = collect(original)
local after = collect(built)

local missing = {}
local changed = {}

for path, className in before do
	if after[path] == nil then
		table.insert(missing, ("%s (%s)"):format(path, className))
	elseif after[path] ~= className then
		table.insert(changed, ("%s: %s -> %s"):format(path, className, after[path]))
	end
end

table.sort(missing)
table.sort(changed)

print(("Original non-script instances: %d"):format(#(function()
	local list = {}
	for _ in before do
		table.insert(list, true)
	end
	return list
end)()))
print(("Built non-script instances: %d"):format(#(function()
	local list = {}
	for _ in after do
		table.insert(list, true)
	end
	return list
end)()))
print(("Missing from build: %d"):format(#missing))
for _, item in missing do
	print("  missing " .. item)
end
print(("Class changes: %d"):format(#changed))
for _, item in changed do
	print("  changed " .. item)
end
