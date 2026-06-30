local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local original = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))
local built = roblox.deserializePlace(fs.readFile("build_check.rbxl"))

local serviceNames = {
	"Players",
	"Lighting",
	"MaterialService",
	"NetworkClient",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"SoundService",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"TextChatService",
}

local function addTree(instance: Instance, path: string, output: { [string]: string })
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

local function count(map: { [string]: string }): number
	local total = 0
	for _ in map do
		total += 1
	end
	return total
end

local before = collect(original)
local after = collect(built)

local missing = {}
local extra = {}
local changed = {}

for path, className in before do
	if after[path] == nil then
		table.insert(missing, ("%s (%s)"):format(path, className))
	elseif after[path] ~= className then
		table.insert(changed, ("%s: %s -> %s"):format(path, className, after[path]))
	end
end

for path, className in after do
	if before[path] == nil then
		table.insert(extra, ("%s (%s)"):format(path, className))
	end
end

table.sort(missing)
table.sort(extra)
table.sort(changed)

print(("Original instances: %d"):format(count(before)))
print(("Built instances: %d"):format(count(after)))
print(("Missing from build: %d"):format(#missing))
for _, item in missing do
	print("  missing " .. item)
end
print(("Extra in build: %d"):format(#extra))
for _, item in extra do
	print("  extra " .. item)
end
print(("Class changes: %d"):format(#changed))
for _, item in changed do
	print("  changed " .. item)
end
