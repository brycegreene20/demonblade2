local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local path = "src/ReplicatedStorage/Assets/ForestDemon.rbxm"

local instances = roblox.deserializeModel(fs.readFile(path))

local function printTree(instance: Instance, indent: string)
	print(("%s%s (%s)"):format(indent, instance.Name, instance.ClassName))
	for _, child in instance:GetChildren() do
		printTree(child, indent .. "  ")
	end
end

for _, instance in instances do
	printTree(instance, "")
end
