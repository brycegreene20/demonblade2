local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatVFXConfigModule = require(Modules:WaitForChild("CombatVFXConfigModule"))
local VFXAssets = ReplicatedStorage:WaitForChild("VFXAssets")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local LocalPlayer = Players.LocalPlayer

local CombatPresentationModule = {}
local missingTemplateWarnings = {}

local function isWithinRenderDistance(position)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return not root
		or (root.Position - position).Magnitude <= CombatVFXConfigModule.RENDER_DISTANCE
end

local function findAnimeTemplate(name)
	local container = VFXAssets:FindFirstChild("AnimeParticles")
	local template = container and container:FindFirstChild(name, true)
	if not template and not missingTemplateWarnings[name] then
		missingTemplateWarnings[name] = true
		warn(("[CombatPresentation] Missing owned AnimeParticles template '%s'"):format(name))
	end
	return template
end

local function prepareWorldEffect(instance, cframe)
	if instance:IsA("BasePart") then
		instance.CFrame = cframe
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
		instance.CastShadow = false
	elseif instance:IsA("Model") then
		instance:PivotTo(cframe)
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
end

local function colorize(instance, primary, secondary)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Color = ColorSequence.new(primary, secondary)
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
			descendant.Color = secondary
		end
	end
end

local function spawnAuthoredBurst(templateName, cframe, count, lifetime, primary, secondary)
	local template = findAnimeTemplate(templateName)
	if not template then return nil end

	local clone = template:Clone()
	prepareWorldEffect(clone, cframe)
	colorize(clone, primary, secondary)
	clone.Parent = workspace

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			local authoredCount = tonumber(descendant:GetAttribute("EmitCount")) or 0
			descendant:Emit(math.max(count, authoredCount))
		end
	end

	Debris:AddItem(clone, lifetime)
	return clone
end

local function spawnSlashMesh(cframe, color, scale, finisher)
	local source = VFXAssets:FindFirstChild(finisher and "SlashSkill" or "SlashEffect")
	if not source or not source:IsA("BasePart") then return end

	local slash = source:Clone()
	prepareWorldEffect(slash, cframe)
	slash.Material = Enum.Material.Neon
	slash.Color = color
	slash.Transparency = 0.04
	slash.Size = Vector3.new(4.5, 0.45, 2.2) * scale
	slash.Parent = workspace

	TweenService:Create(slash, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		CFrame = cframe * CFrame.new(0, 0, -4.5),
		Size = Vector3.new(11, 1.1, 5.5) * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(slash, 0.38)
end

local function addWeaponTrail(character, primary, secondary, duration)
	local tool = character:FindFirstChildOfClass("Tool")
	local limb = tool and tool:FindFirstChild("Handle")
		or character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
	if not limb or not limb:IsA("BasePart") then return end

	local top = Instance.new("Attachment")
	top.Name = "CombatTrailTop"
	top.Position = Vector3.new(0, limb.Size.Y * 0.48, 0)
	top.Parent = limb

	local bottom = Instance.new("Attachment")
	bottom.Name = "CombatTrailBottom"
	bottom.Position = Vector3.new(0, -limb.Size.Y * 0.48, 0)
	bottom.Parent = limb

	local trail = Instance.new("Trail")
	trail.Name = "CombatWeaponTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(primary, secondary)
	trail.Lifetime = 0.18
	trail.LightEmission = 0.85
	trail.FaceCamera = true
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = limb

	Debris:AddItem(trail, duration)
	Debris:AddItem(top, duration + 0.2)
	Debris:AddItem(bottom, duration + 0.2)
end

local function playOwnedSlashSound(root, playbackSpeed, volume)
	local container = Assets:FindFirstChild("Slashes anime")
	if not container then return end
	local source = if container:IsA("Sound") and container.SoundId ~= ""
		then container
		else container:FindFirstChildWhichIsA("Sound", true)
	if not source then return end

	local sound = source:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.RollOffMaxDistance = 85
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function pulseLight(root, color, brightness, duration)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = 14
	light.Shadows = true
	light.Parent = root
	TweenService:Create(light, TweenInfo.new(duration), { Brightness = 0, Range = 4 }):Play()
	Debris:AddItem(light, duration + 0.05)
end

function CombatPresentationModule.playBasicSwing(character, comboIndex)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not isWithinRenderDistance(root.Position) then return end

	local style = CombatVFXConfigModule.getStyleProfile("Basic")
	local combo = CombatVFXConfigModule.getComboProfile(comboIndex)
	local color = style.Primary:Lerp(style.Secondary, combo.ColorMix)
	local slashCFrame = root.CFrame
		* CFrame.new(0, 0.7, -2.8)
		* CFrame.Angles(0, 0, math.rad(combo.Angle))

	spawnSlashMesh(slashCFrame, color, combo.Scale, combo.Finisher == true)
	spawnAuthoredBurst("Slashes-01", slashCFrame, combo.Finisher and 22 or 12, 0.55, color, style.Secondary)
	spawnAuthoredBurst("Wind-01", slashCFrame, combo.Finisher and 14 or 7, 0.5, style.Secondary, color)
	addWeaponTrail(character, color, style.Secondary, 0.32)
	pulseLight(root, color, combo.Finisher and 2.8 or 1.5, 0.22)
	playOwnedSlashSound(root, 0.92 + comboIndex * 0.08, combo.Finisher and 0.34 or 0.24)

	if combo.Finisher then
		spawnAuthoredBurst("Slash-Impact-01", root.CFrame * CFrame.new(0, 0.5, -5), 28, 0.75, color, style.Secondary)
	end
end

function CombatPresentationModule.playDamageImpact(targetModel, hitPosition, isCritical, styleName)
	local targetPart = targetModel
		and (targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Head"))
	if not targetPart then return end

	local position = typeof(hitPosition) == "Vector3" and hitPosition or targetPart.Position
	if not isWithinRenderDistance(position) then return end

	local style = CombatVFXConfigModule.getStyleProfile(styleName)
	local cframe = CFrame.new(position)
	for _, template in ipairs(style.ImpactTemplates) do
		spawnAuthoredBurst(
			template.Name,
			cframe,
			isCritical and math.floor(template.Count * 1.5) or template.Count,
			template.Lifetime,
			style.Primary,
			style.Secondary
		)
	end
	pulseLight(targetPart, style.Secondary, isCritical and 3.5 or 2, 0.28)
end

function CombatPresentationModule.playSkillCastAccent(character, styleName, isUltimate)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not isWithinRenderDistance(root.Position) then return end

	local style = CombatVFXConfigModule.getStyleProfile(styleName)
	local cframe = root.CFrame * CFrame.new(0, 0.5, -1.5)
	for _, template in ipairs(style.CastTemplates) do
		spawnAuthoredBurst(
			template.Name,
			cframe,
			isUltimate and math.floor(template.Count * 1.6) or template.Count,
			isUltimate and template.Lifetime * 1.25 or template.Lifetime,
			style.Primary,
			style.Secondary
		)
	end
	addWeaponTrail(character, style.Primary, style.Secondary, isUltimate and 0.8 or 0.5)
	pulseLight(root, style.Secondary, isUltimate and 4 or 2.2, isUltimate and 0.5 or 0.3)

	if isUltimate then
		spawnSlashMesh(root.CFrame * CFrame.new(0, 0.8, -3), style.Primary, 1.8, true)
	end
end

return CombatPresentationModule
