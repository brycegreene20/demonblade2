local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local original = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))
local built = roblox.deserializePlace(fs.readFile("build_check.rbxl"))

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
	"Workspace",
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
