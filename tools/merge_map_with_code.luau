-- Merges the latest DemonBlade2 update N.rbxl (map source) with code_build.rbxl
-- (produced by rojo build). The result is deploy.rbxl which contains the full
-- map Workspace plus the latest code across all Rojo-managed services.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local function getEntryName(entry): string?
	if type(entry) == "string" then
		return entry
	end
	return (entry :: any).name
end

local function getUpdateNumber(path: string): number?
	local lower = string.lower(path)
	if lower == "demonblade2.rbxl" then
		return -1
	end
	local n = string.match(lower, "^demonblade2 update%s*(%d+)%.rbxl$")
	return n and tonumber(n) or nil
end

local function findLatestMapPath(): string
	local bestPath: string? = nil
	local bestN = -2
	for _, entry in fs.readDir(".") do
		local name = getEntryName(entry)
		if name then
			local n = getUpdateNumber(name)
			if n and n > bestN then
				bestPath = name
				bestN = n
			end
		end
	end
	if not bestPath then
		error("No map file found. Expected 'DemonBlade2 update N.rbxl' in the repo root.")
	end
	return bestPath
end

local mapPath = findLatestMapPath()
print("[merge] Map source : " .. mapPath)
print("[merge] Code source: code_build.rbxl")

local okMap, mapPlace = pcall(roblox.deserializePlace, fs.readFile(mapPath))
if not okMap then
	error("[merge] Failed to load map: " .. tostring(mapPlace))
end

local okCode, codePlace = pcall(roblox.deserializePlace, fs.readFile("code_build.rbxl"))
if not okCode then
	error("[merge] Failed to load code build: " .. tostring(codePlace))
end

local mapWorkspace  = (mapPlace  :: any):GetService("Workspace")
local codeWorkspace = (codePlace :: any):GetService("Workspace")

local count = 0
for _, child in mapWorkspace:GetChildren() do
	child.Parent = codeWorkspace
	count += 1
end

print(("[merge] Injected %d Workspace children into code build"):format(count))

fs.writeFile("deploy.rbxl", roblox.serializePlace(codePlace :: any))
print("[merge] Wrote deploy.rbxl")
