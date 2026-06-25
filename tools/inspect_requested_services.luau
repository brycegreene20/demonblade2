local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))

local serviceNames = {
	"Players",
	"MaterialService",
	"NetworkClient",
	"StarterPack",
	"Teams",
	"SoundService",
	"TextChatService",
}

for _, serviceName in serviceNames do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)

	if ok and service then
		local children = service:GetChildren()
		print(("[%s] class=%s children=%d descendants=%d"):format(
			serviceName,
			service.ClassName,
			#children,
			#service:GetDescendants()
		))

		for _, child in children do
			print(("  %s (%s) descendants=%d"):format(child.Name, child.ClassName, #child:GetDescendants()))
		end
	else
		print(("[%s] unavailable"):format(serviceName))
	end
end
