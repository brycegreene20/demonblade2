local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))
local workspace = game:GetService("Workspace")

local scriptIndex = 0
for _, child in workspace:GetChildren() do
	if child:IsA("LuaSourceContainer") then
		scriptIndex += 1
		if scriptIndex == 3 then
			fs.writeFile("src/Workspace/Script.rbxm", roblox.serializeModel({ child }))
			print("Exported Workspace Script #3 to src/Workspace/Script.rbxm")
			return
		end
	end
end

error("Could not find Workspace Script #3")
