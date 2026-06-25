local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))

local serviceNames = {
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"Lighting",
	"SoundService",
	"Workspace",
}

for _, serviceName in serviceNames do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)

	if ok and service then
		local children = service:GetChildren()
		if #children > 0 then
			print(("[%s] %d children"):format(serviceName, #children))
			for _, child in children do
				print(("  %s (%s) descendants=%d"):format(child.Name, child.ClassName, #child:GetDescendants()))
			end
		end
	end
end
