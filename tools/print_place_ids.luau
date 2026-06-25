local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))

local okPlaceId, placeId = pcall(function()
	return game.PlaceId
end)
local okUniverseId, universeId = pcall(function()
	return game.GameId
end)

if okPlaceId then
	print("PlaceId:", placeId)
else
	print("PlaceId: unavailable from local .rbxl metadata")
end

if okUniverseId then
	print("UniverseId:", universeId)
else
	print("UniverseId: unavailable from local .rbxl metadata")
end
