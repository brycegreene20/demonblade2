local Lighting = game:GetService("Lighting")
local _TweenService = game:GetService("TweenService")

-- === COLD-BLUE DEMON SLAYER LIGHTING ===
Lighting.Ambient = Color3.fromRGB(40, 50, 75)
Lighting.OutdoorAmbient = Color3.fromRGB(60, 75, 110)
Lighting.ColorShift_Top = Color3.fromRGB(170, 190, 220)
Lighting.ColorShift_Bottom = Color3.fromRGB(30, 35, 55)
Lighting.Brightness = 2.5
Lighting.ClockTime = 6.5
Lighting.GeographicLatitude = 40
Lighting.EnvironmentDiffuseScale = 0.8
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = -0.3
Lighting.FogColor = Color3.fromRGB(140, 160, 190)
Lighting.FogEnd = 800
Lighting.FogStart = 100

-- === ATMOSPHERE (mountain fog) ===
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(170, 200, 215)
atmosphere.Decay = Color3.fromRGB(90, 110, 140)
atmosphere.Glare = 0.15
atmosphere.Haze = 2.5
atmosphere.Parent = Lighting

-- === BLOOM (soft overcast glow) ===
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 30
bloom.Threshold = 1.2
bloom.Parent = Lighting

-- === COLOR CORRECTION (cold blue tint) ===
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Brightness = -0.02
colorCorrection.Contrast = 0.08
colorCorrection.Saturation = -0.1
colorCorrection.TintColor = Color3.fromRGB(220, 230, 255)
colorCorrection.Parent = Lighting

-- === LANTERN POSITIONS (Starter Village area around 300, 14, 150) ===
local LANTERN_POSITIONS = {
	Vector3.new(290, 14, 140),
	Vector3.new(310, 14, 140),
	Vector3.new(300, 14, 160),
	Vector3.new(285, 14, 155),
	Vector3.new(315, 14, 155),
	Vector3.new(295, 14, 130),
	Vector3.new(305, 14, 170),
	Vector3.new(280, 14, 145),
}

local lanternFolder = Instance.new("Folder")
lanternFolder.Name = "Lanterns"
lanternFolder.Parent = workspace

for i, pos in ipairs(LANTERN_POSITIONS) do
	local pole = Instance.new("Part")
	pole.Name = "LanternPole_" .. i
	pole.Size = Vector3.new(0.4, 6, 0.4)
	pole.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	pole.Anchored = true
	pole.Material = Enum.Material.Wood
	pole.Color = Color3.fromRGB(90, 60, 30)
	pole.Parent = lanternFolder

	local lanternHead = Instance.new("Part")
	lanternHead.Name = "LanternHead_" .. i
	lanternHead.Shape = Enum.PartType.Block
	lanternHead.Size = Vector3.new(1.2, 1.5, 1.2)
	lanternHead.CFrame = CFrame.new(pos + Vector3.new(0, 6.5, 0))
	lanternHead.Anchored = true
	lanternHead.Material = Enum.Material.Neon
	lanternHead.Color = Color3.fromRGB(255, 180, 80)
	lanternHead.Transparency = 0.3
	lanternHead.Parent = lanternFolder

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2
	pointLight.Range = 16
	pointLight.Color = Color3.fromRGB(255, 200, 130)
	pointLight.Parent = lanternHead
end

-- === DAY/NIGHT CYCLE ===
local DAY_LENGTH_MINUTES = 20
local SECONDS_PER_HOUR = (DAY_LENGTH_MINUTES * 60) / 24

local NIGHT_AMBIENT = Color3.fromRGB(20, 25, 50)
local NIGHT_OUTDOOR = Color3.fromRGB(30, 40, 70)
local DAY_AMBIENT = Color3.fromRGB(40, 50, 75)
local DAY_OUTDOOR = Color3.fromRGB(60, 75, 110)
local DUSK_AMBIENT = Color3.fromRGB(50, 35, 55)
local DUSK_OUTDOOR = Color3.fromRGB(80, 55, 70)

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function getTimeOfDayColors(hour: number)
	if hour >= 6 and hour < 8 then
		local t = (hour - 6) / 2
		return lerpColor(NIGHT_AMBIENT, DAY_AMBIENT, t), lerpColor(NIGHT_OUTDOOR, DAY_OUTDOOR, t)
	elseif hour >= 8 and hour < 16 then
		return DAY_AMBIENT, DAY_OUTDOOR
	elseif hour >= 16 and hour < 18 then
		local t = (hour - 16) / 2
		return lerpColor(DAY_AMBIENT, DUSK_AMBIENT, t), lerpColor(DAY_OUTDOOR, DUSK_OUTDOOR, t)
	elseif hour >= 18 and hour < 20 then
		local t = (hour - 18) / 2
		return lerpColor(DUSK_AMBIENT, NIGHT_AMBIENT, t), lerpColor(DUSK_OUTDOOR, NIGHT_OUTDOOR, t)
	else
		return NIGHT_AMBIENT, NIGHT_OUTDOOR
	end
end

local function updateLanterns(hour: number)
	local isNight = hour < 6 or hour >= 18
	local isDusk = hour >= 16 and hour < 18
	local isDawn = hour >= 6 and hour < 8

	local brightness = 0
	if isNight then
		brightness = 2
	elseif isDusk then
		brightness = (hour - 16) / 2 * 2
	elseif isDawn then
		brightness = (1 - (hour - 6) / 2) * 2
	end

	for _, child in lanternFolder:GetChildren() do
		if child.Name:find("LanternHead") then
			local light = child:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = brightness
			end
			child.Transparency = if brightness > 0.1 then 0.3 else 0.8
		end
	end
end

local function updateAtmosphere(hour: number)
	local isNight = hour < 6 or hour >= 20
	if isNight then
		atmosphere.Density = 0.4
		atmosphere.Haze = 3.5
		Lighting.ExposureCompensation = -0.5
		Lighting.FogEnd = 500
	elseif hour >= 6 and hour < 8 then
		local t = (hour - 6) / 2
		atmosphere.Density = 0.4 - t * 0.1
		atmosphere.Haze = 3.5 - t * 1.0
		Lighting.ExposureCompensation = -0.5 + t * 0.2
		Lighting.FogEnd = 500 + t * 300
	elseif hour >= 18 and hour < 20 then
		local t = (hour - 18) / 2
		atmosphere.Density = 0.3 + t * 0.1
		atmosphere.Haze = 2.5 + t * 1.0
		Lighting.ExposureCompensation = -0.3 - t * 0.2
		Lighting.FogEnd = 800 - t * 300
	else
		atmosphere.Density = 0.3
		atmosphere.Haze = 2.5
		Lighting.ExposureCompensation = -0.3
		Lighting.FogEnd = 800
	end
end

print("[AtmosphereServer] Cold-blue Demon Slayer atmosphere initialized")
print("[AtmosphereServer] Day/night cycle: " .. DAY_LENGTH_MINUTES .. " minute full cycle")

while true do
	local dt = task.wait(0.5)
	local hoursElapsed = dt / SECONDS_PER_HOUR
	Lighting.ClockTime = (Lighting.ClockTime + hoursElapsed) % 24

	local hour = Lighting.ClockTime
	local ambient, outdoor = getTimeOfDayColors(hour)
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = outdoor

	updateLanterns(hour)
	updateAtmosphere(hour)
end