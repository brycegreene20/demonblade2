local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local function getEntryName(entry): string?
	if type(entry) == "string" then
		return entry
	end
	return entry.name
end

local function getPlaceUpdateNumber(path: string): number?
	local lowerPath = string.lower(path)
	if lowerPath == "demonblade2.rbxl" then
		return -1
	end

	local update = string.match(lowerPath, "^demonblade2 update%s*(%d+)%.rbxl$")
	return update and tonumber(update) or nil
end

local function findLatestOriginalPlacePath(): string
	local bestPath = nil
	local bestUpdate = -2
	for _, entry in fs.readDir(".") do
		local name = getEntryName(entry)
		local update = name and getPlaceUpdateNumber(name) or nil
		if update and update > bestUpdate then
			bestPath = name
			bestUpdate = update
		end
	end

	if not bestPath then
		error("No original place file found. Expected DemonBlade2.rbxl or DemonBlade2 updateN.rbxl.")
	end
	return bestPath
end

local function readFirstAvailable(paths: { string }): (string, string)
	for _, path in paths do
		local ok, contents = pcall(fs.readFile, path)
		if ok then
			return contents, path
		end
	end
	error("None of these files could be read: " .. table.concat(paths, ", "))
end

local originalPath = findLatestOriginalPlacePath()
local originalBytes = fs.readFile(originalPath)
local builtBytes, builtPath = readFirstAvailable({
	"build_check.rbxl",
})

local original = roblox.deserializePlace(originalBytes)
local built = roblox.deserializePlace(builtBytes)
print("Original place: " .. originalPath)
print("Built place: " .. builtPath)

local checks: { [string]: { string } } = {
	Lighting = {
		"Ambient",
		"Brightness",
		"ClockTime",
		"ColorShift_Bottom",
		"ColorShift_Top",
		"EnvironmentDiffuseScale",
		"EnvironmentSpecularScale",
		"ExposureCompensation",
		"FogColor",
		"FogEnd",
		"FogStart",
		"GeographicLatitude",
		"GlobalShadows",
		"OutdoorAmbient",
		"ShadowSoftness",
	},
	SoundService = {
		"AmbientReverb",
		"DistanceFactor",
		"DopplerScale",
		"RespectFilteringEnabled",
		"RolloffScale",
	},
	StarterGui = {
		"ResetPlayerGuiOnSpawn",
	},
	Players = {
		"CharacterAutoLoads",
		"RespawnTime",
	},
	StarterPlayer = {
		"AllowCustomAnimations",
		"AutoJumpEnabled",
		"CameraMaxZoomDistance",
		"CameraMinZoomDistance",
		"CameraMode",
		"CharacterJumpHeight",
		"CharacterJumpPower",
		"CharacterMaxSlopeAngle",
		"CharacterUseJumpPower",
		"CharacterWalkSpeed",
		"DevCameraOcclusionMode",
		"DevComputerCameraMovementMode",
		"DevComputerMovementMode",
		"DevTouchCameraMovementMode",
		"DevTouchMovementMode",
		"EnableMouseLockOption",
		"LoadCharacterAppearance",
		"UserEmotesEnabled",
	},
	TextChatService = {
		"ChatTranslationEnabled",
		"CreateDefaultCommands",
		"CreateDefaultTextChannels",
	},
	Workspace = {
		"AirDensity",
		"FallenPartsDestroyHeight",
		"Gravity",
	},
}

local function valueToString(value: any): string
	return tostring(value)
end

local mismatches = {}

for serviceName, properties in checks do
	local before = original:GetService(serviceName)
	local after = built:GetService(serviceName)

	for _, propertyName in properties do
		local okBefore, beforeValue = pcall(function()
			return (before :: any)[propertyName]
		end)
		local okAfter, afterValue = pcall(function()
			return (after :: any)[propertyName]
		end)

		if okBefore and okAfter and valueToString(beforeValue) ~= valueToString(afterValue) then
			table.insert(mismatches, ("%s.%s: %s -> %s"):format(
				serviceName,
				propertyName,
				valueToString(beforeValue),
				valueToString(afterValue)
			))
		end
	end
end

table.sort(mismatches)
print(("Key service property mismatches: %d"):format(#mismatches))
for _, mismatch in mismatches do
	print("  " .. mismatch)
end
