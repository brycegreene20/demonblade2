local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))

local index = 0
for _, child in game:GetService("Workspace"):GetChildren() do
	if child:IsA("LuaSourceContainer") then
		index += 1
		print(("SCRIPT %d: %s (%s) children=%d sourceLen=%d"):format(
			index,
			child.Name,
			child.ClassName,
			#child:GetChildren(),
			#child.Source
		))
		print(child.Source)
		print("----")
	end
end
