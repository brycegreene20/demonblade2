local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1]
if not path then
	error("Usage: lune run tools/inspect_model_tree.luau <model.rbxm>")
end

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
