local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local original = roblox.deserializePlace(fs.readFile("DemonBlade2.rbxl"))
local built = roblox.deserializePlace(fs.readFile("build_check.rbxl"))

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
