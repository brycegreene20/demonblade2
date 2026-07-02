--!strict
-- SkillVFXController: AAA-quality skill VFX + SFX using imported Studio assets.
-- Exposes _G.SkillVFX.play(character, skillId) for CombatController to call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local Debris        = game:GetService("Debris")
local RunService    = game:GetService("RunService")

local VFXAssets   = ReplicatedStorage:WaitForChild("VFXAssets")
local SFXAssets   = ReplicatedStorage:WaitForChild("Assets")
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))
local CombatPresentationModule = require(Modules:WaitForChild("CombatPresentationModule"))

-- ── Asset cache ────────────────────────────────────────────────────────────────

local vfxCache: { [string]: Instance } = {}

local function cacheVFX(name: string)
	local asset = VFXAssets:FindFirstChild(name)
	if asset then
		vfxCache[name] = asset
	else
		warn("[SkillVFX] Missing VFX asset:", name)
	end
end

for _, name in ipairs({
	"TanjiroWaterSlash", "DemonSlayerKit", "Tanjiro VFX",
	"Wave", "Whirl", "Spiral", "Swirl", "WindSphere",
	"SlashEffect", "SlashSkill", "Shockwave", "Tornado",
	"AnimeParticles", "AuraTemplates", "WaterVFX",
}) do
	cacheVFX(name)
end

-- ── SFX helpers ────────────────────────────────────────────────────────────────

-- "Slashes anime" exported from Studio — may be a Sound or a Folder of Sounds.
local slashSFXContainer = SFXAssets:FindFirstChild("Slashes anime")

local SFX_FALLBACK: { [string]: { id: string, speed: number } } = {
	WaterBreathing  = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.5 },
	FlameBreathing  = { id = "rbxasset://sounds/impact_explosion_03.mp3", speed = 1.2 },
	DemonArts       = { id = "rbxasset://sounds/impact_explosion_03.mp3", speed = 0.85 },
	TemariDemonArts = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.95 },
}

local function getSlashSoundId(style: string): (string, number)
	if slashSFXContainer then
		if slashSFXContainer:IsA("Sound") then
			return slashSFXContainer.SoundId, 1
		end
		-- Folder of Sounds: try to find one named after the style or grab first
		local byStyle = slashSFXContainer:FindFirstChild(style)
		local sound = (byStyle and byStyle:IsA("Sound") and byStyle)
			or (slashSFXContainer:FindFirstChildOfClass("Sound"))
		if sound then
			return (sound :: Sound).SoundId, 1
		end
	end
	local fallback = SFX_FALLBACK[style] or { id = "rbxasset://sounds/action_get_up.mp3", speed = 1 }
	return fallback.id, fallback.speed
end

local function playSound(parent: Instance, style: string, volume: number, speedMult: number?)
	if not parent then return end
	local soundId, baseSpeed = getSlashSoundId(style)
	local snd = Instance.new("Sound")
	snd.SoundId = soundId
	snd.Volume = volume
	snd.PlaybackSpeed = baseSpeed * (speedMult or 1)
	snd.RollOffMaxDistance = 90
	snd.Parent = parent
	snd:Play()
	Debris:AddItem(snd, 2.5)
end


-- ── Style colours ──────────────────────────────────────────────────────────────

local WATER_C1  = Color3.fromRGB(70,  210, 255)
local WATER_C2  = Color3.fromRGB(200, 240, 255)
local FLAME_C1  = Color3.fromRGB(255, 100, 25)
local FLAME_C2  = Color3.fromRGB(255, 220, 80)
local DEMON_C1  = Color3.fromRGB(205, 20,  45)
local DEMON_C2  = Color3.fromRGB(120, 0,   185)
local TEMARI_C1 = Color3.fromRGB(200, 60,  220)
local TEMARI_C2 = Color3.fromRGB(255, 100, 255)

-- ── VFX primitives ─────────────────────────────────────────────────────────────

local missingTemplateWarnings: { [string]: boolean } = {}

local function findVFXTemplate(containerName: string, templateName: string): Instance?
	local container = vfxCache[containerName]
	local template = container and container:FindFirstChild(templateName, true)
	if not template then
		local warningKey = containerName .. "/" .. templateName
		if not missingTemplateWarnings[warningKey] then
			missingTemplateWarnings[warningKey] = true
			warn("[SkillVFX] Missing authored template:", warningKey)
		end
	end
	return template
end

local function colorizeWater(instance: Instance, primary: Color3, secondary: Color3?)
	local bright = secondary or WATER_C2
	for _, desc in instance:GetDescendants() do
		if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
			desc.Color = ColorSequence.new(primary, bright)
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Color3 = primary:Lerp(bright, 0.35)
		elseif desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
			desc.Color = bright
		end
	end
end

local function prepareWorldVFX(instance: Instance, cframe: CFrame)
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
	for _, desc in instance:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.CastShadow = false
		end
	end
end

local function spawnAuthoredBurst(
	containerName: string,
	templateName: string,
	cframe: CFrame,
	particleCount: number,
	lifetime: number,
	primary: Color3?,
	secondary: Color3?
): Instance?
	local template = findVFXTemplate(containerName, templateName)
	if not template then return nil end
	local clone = template:Clone()
	prepareWorldVFX(clone, cframe)
	if primary then
		colorizeWater(clone, primary, secondary)
	end
	clone.Parent = workspace
	for _, desc in clone:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = false
			local authoredCount = desc:GetAttribute("EmitCount")
			desc:Emit(math.max(particleCount, tonumber(authoredCount) or 0))
		end
	end
	task.delay(math.max(0.1, lifetime * 0.45), function()
		if not clone.Parent then return end
		local fadeDuration = math.max(0.12, lifetime * 0.45)
		for _, desc in clone:GetDescendants() do
			if desc:IsA("Decal") or desc:IsA("Texture") then
				TweenService:Create(desc, TweenInfo.new(fadeDuration), { Transparency = 1 }):Play()
			elseif desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
				TweenService:Create(desc, TweenInfo.new(fadeDuration), { Brightness = 0 }):Play()
			end
		end
	end)
	Debris:AddItem(clone, lifetime)
	return clone
end

local function spawnTanjiroArc(cframe: CFrame, scale: number, lifetime: number): Model?
	local container = vfxCache["TanjiroWaterSlash"]
	local source = container and container:FindFirstChild("Slash", true)
	if not source or not source:IsA("Model") then
		if not missingTemplateWarnings.TanjiroArc then
			missingTemplateWarnings.TanjiroArc = true
			warn("[SkillVFX] TanjiroWaterSlash/Slash model is unavailable")
		end
		return nil
	end

	local arc = source:Clone()
	for _, child in arc:GetChildren() do
		local isArcMesh = child:IsA("BasePart")
			and (child.Name == "Top part" or child.Name == "bottom part")
		if not isArcMesh then
			child:Destroy()
		end
	end
	prepareWorldVFX(arc, cframe)
	pcall(function()
		arc:ScaleTo(scale)
	end)
	colorizeWater(arc, Color3.fromRGB(70, 210, 255), Color3.fromRGB(200, 240, 255))
	arc.Parent = workspace
	Debris:AddItem(arc, lifetime)
	return arc
end

local function animateModel(model: Model, duration: number, getCFrame: (number) -> CFrame)
	task.spawn(function()
		local started = os.clock()
		while model.Parent do
			local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
			model:PivotTo(getCFrame(alpha))
			if alpha >= 1 then break end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function tweenFade(part: BasePart, targetSize: Vector3, duration: number)
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = targetSize,
		Transparency = 1,
	}):Play()
end

local function launchMesh(name: string, origin: Vector3, dir: Vector3, color: Color3, speed: number, duration: number)
	local asset = vfxCache[name]
	if not asset or not asset:IsA("BasePart") then return end
	local clone = asset:Clone() :: BasePart
	local startCF = CFrame.lookAt(origin, origin + dir)
	clone.CFrame = startCF
	clone.Color = color
	clone.Transparency = 0.05
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = false
	clone.Parent = workspace

	TweenService:Create(clone, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = startCF + dir * speed * duration,
		Transparency = 0.85,
	}):Play()
	Debris:AddItem(clone, duration + 0.05)
end

local function spawnGroundRing(origin: Vector3, color: Color3, radius: number, duration: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, radius * 2, radius * 2)
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.15
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	tweenFade(ring, Vector3.new(0.02, radius * 4.5, radius * 4.5), duration)
	Debris:AddItem(ring, duration + 0.05)
end

local function spawnShockwave(origin: Vector3, color: Color3, scale: number, delay_: number?)
	task.delay(delay_ or 0, function()
		-- Use the actual Shockwave mesh if available
		local shockAsset = vfxCache["Shockwave"]
		if shockAsset and shockAsset:IsA("BasePart") then
			local clone = shockAsset:Clone() :: BasePart
			clone.Size = Vector3.new(0.25 * scale, 3 * scale, 3 * scale)
			clone.CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			clone.Color = color
			clone.Transparency = 0.1
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.Parent = workspace
			tweenFade(clone, Vector3.new(0.03 * scale, 18 * scale, 18 * scale), 0.4)
			Debris:AddItem(clone, 0.45)
		else
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.2 * scale, 3 * scale, 3 * scale)
			ring.Material = Enum.Material.Neon
			ring.Color = color
			ring.Transparency = 0.15
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
			ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = workspace
			tweenFade(ring, Vector3.new(0.03 * scale, 16 * scale, 16 * scale), 0.42)
			Debris:AddItem(ring, 0.48)
		end
	end)
end

local function spawnAura(hrp: BasePart, color: Color3, duration: number, _radius: number?)
	local burstCF = CFrame.new(hrp.Position + Vector3.new(0, 1, 0))
	spawnAuthoredBurst("AnimeParticles", "ForceField-01", burstCF, 22, duration, color, color:Lerp(Color3.new(1, 1, 1), 0.4))
	spawnAuthoredBurst("AnimeParticles", "Charge-01",     burstCF, 16, duration * 0.75, color, color)
end

-- ── Water Breathing ────────────────────────────────────────────────────────────

-- Form 1: Water Surface Slash — the iconic diagonal slash arc with a water burst
local function vfxWaterSurfaceSlash(hrp: BasePart, skill)
	local castCF = hrp.CFrame * CFrame.new(0, 1.1, -4)

	-- The blue crescent arc — Tanjiro's signature
	local arc = spawnTanjiroArc(castCF * CFrame.Angles(0, 0, math.rad(-22)), 0.9, 0.6)
	if arc then
		animateModel(arc, 0.35, function(alpha)
			return castCF * CFrame.Angles(0, math.rad(-22 + alpha * 44), math.rad(-22 + alpha * 40))
		end)
	end

	-- Water mist that trails the blade path
	spawnAuthoredBurst("DemonSlayerKit", "Mist/water 2", castCF * CFrame.Angles(0, math.rad(90), 0), 22, 0.7, WATER_C1, WATER_C2)

	-- The anime slash mark appearing at the strike
	spawnAuthoredBurst("AnimeParticles", "Slashes-01", castCF, 20, 0.75, WATER_C1, WATER_C2)

	task.delay(0.1, function()
		if not hrp.Parent then return end
		local impactCF = hrp.CFrame * CFrame.new(0, 1, -skill.HitboxOffset)
		spawnAuthoredBurst("AnimeParticles", "Water-01",      impactCF, 28, 0.9,  WATER_C1, WATER_C2)
		spawnAuthoredBurst("AnimeParticles", "Slash-Impact-01", impactCF, 14, 0.7, WATER_C2, WATER_C1)
		spawnAuthoredBurst("AnimeParticles", "Slash-01",      impactCF, 12, 0.6,  WATER_C1, WATER_C2)
		launchMesh("Wave", impactCF.Position, hrp.CFrame.LookVector, WATER_C1, 26, 0.25)
	end)
	playSound(hrp, "WaterBreathing", 0.48, 1.35)
end

-- Form 2: Water Wheel — spinning wheel of water arcs
local function vfxWaterWheel(hrp: BasePart, _skill)
	local baseCF = hrp.CFrame * CFrame.new(0, 1.4, 0)

	-- Primary arc sweeps clockwise
	local arc = spawnTanjiroArc(baseCF, 1.1, 0.8)
	if arc then
		animateModel(arc, 0.62, function(alpha)
			return baseCF
				* CFrame.Angles(alpha * math.pi * 2, 0, math.rad(90))
				* CFrame.new(0, 0, -3.0)
		end)
	end

	-- Counter arc sweeps the other direction — creates the "wheel" illusion
	local arc2 = spawnTanjiroArc(baseCF, 0.78, 0.7)
	if arc2 then
		animateModel(arc2, 0.55, function(alpha)
			return baseCF
				* CFrame.Angles(-alpha * math.pi * 2, 0, math.rad(-90))
				* CFrame.new(0, 0, -2.5)
		end)
	end

	-- Spin particles + water splash
	spawnAuthoredBurst("DemonSlayerKit", "good twirl",  baseCF, 30, 0.85, WATER_C1, WATER_C2)
	spawnAuthoredBurst("AnimeParticles", "Water-02",    baseCF, 32, 1.0,  WATER_C1, WATER_C2)
	spawnAuthoredBurst("AnimeParticles", "Slashes-01",  baseCF, 24, 0.9,  WATER_C1, WATER_C2)

	-- Water energy builds during spin
	spawnAuthoredBurst("AnimeParticles", "Charge-01", baseCF, 22, 1.2, WATER_C1, WATER_C2)

	task.delay(0.28, function()
		if not hrp.Parent then return end
		spawnAuthoredBurst("AnimeParticles", "Water-01", baseCF, 22, 0.8, WATER_C1, WATER_C2)
		spawnShockwave(hrp.Position, WATER_C1, 0.75)
	end)
	playSound(hrp, "WaterBreathing", 0.52, 1.15)
end

-- Form 3: Flowing Dance — multiple flowing strikes like water around the user
local function vfxFlowingDance(hrp: BasePart, skill)
	local castCF = hrp.CFrame
	local hitCount = math.max(3, skill.MultiHit)

	-- Opening water ripple
	spawnAuthoredBurst("AnimeParticles", "Water-01", CFrame.new(hrp.Position + Vector3.new(0, 1, 0)), 14, 0.5, WATER_C1, WATER_C2)

	for i = 1, hitCount do
		task.delay((i - 1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			local progress = i / hitCount
			local lateral = math.sin(progress * math.pi * 3) * 3.2
			local stepCF = castCF
				* CFrame.new(lateral, 0.8 + math.sin(progress * math.pi) * 1.2, -progress * 13)
				* CFrame.Angles(0, math.rad(-30 + progress * 60), math.rad(i % 2 == 0 and 24 or -24))

			spawnAuthoredBurst(
				"DemonSlayerKit",
				i % 2 == 0 and "Side slash" or "Mist/water",
				stepCF,
				16,
				0.65,
				i % 2 == 0 and WATER_C2 or WATER_C1,
				WATER_C2
			)
			spawnAuthoredBurst("AnimeParticles", "Water-01",   stepCF, 12, 0.75, WATER_C1, WATER_C2)
			spawnAuthoredBurst("AnimeParticles", "Slashes-01", stepCF, 10, 0.6,  WATER_C1, WATER_C2)

			-- Animated arc on the first and last hit
			if i == 1 or i == hitCount then
				local arc = spawnTanjiroArc(stepCF, 0.6, 0.5)
				if arc then
					local dir = i == 1 and 1 or -1
					animateModel(arc, 0.28, function(alpha)
						return stepCF * CFrame.Angles(0, alpha * math.rad(36), alpha * math.rad(dir * 45))
					end)
				end
			end

			-- Final strike: big cascade
			if i == hitCount then
				spawnAuthoredBurst("AnimeParticles", "Water-02", stepCF, 38, 1.0, WATER_C1, WATER_C2)
				spawnShockwave(stepCF.Position, WATER_C1, 0.8)
			end
		end)
	end
	playSound(hrp, "WaterBreathing", 0.46, 1.45)
end

-- Form 4: Waterfall Basin — three cascading slashes crashing like a waterfall
local function vfxWaterfallBasin(hrp: BasePart, _skill)
	local castCF = hrp.CFrame

	-- Waterfall streams pour down before the strikes
	spawnAuthoredBurst("WaterVFX", "Waterfall-01", castCF * CFrame.new(0, 5, -2), 18, 1.1, WATER_C1, WATER_C2)

	for i = 1, 3 do
		task.delay((i - 1) * 0.13, function()
			if not hrp.Parent then return end
			local side = i == 2 and 2.2 or (i == 3 and -1.6 or 0)
			local strikeCF = castCF
				* CFrame.new(side, 1 + i * 0.35, -3.2 * i)
				* CFrame.Angles(
					math.rad(i == 3 and -35 or 0),
					math.rad(i == 2 and -18 or 12),
					math.rad(i % 2 == 0 and 32 or -28)
				)
			local template = if i == 1 then "Side slash" elseif i == 2 then "Mist/water 2" else "Downwards slash"
			spawnAuthoredBurst("DemonSlayerKit", template, strikeCF, 20 + i * 4, 0.78, WATER_C1, WATER_C2)
			spawnAuthoredBurst("AnimeParticles", "Water-01",   strikeCF, 16, 0.82, WATER_C1, WATER_C2)
			spawnAuthoredBurst("AnimeParticles", "Slashes-01", strikeCF, 14, 0.7,  WATER_C1, WATER_C2)

			local arc = spawnTanjiroArc(strikeCF, 0.7 + i * 0.12, 0.55)
			if arc then
				animateModel(arc, 0.32, function(alpha)
					return strikeCF
						* CFrame.Angles(0, alpha * math.rad(35), alpha * math.rad(i % 2 == 0 and -60 or 60))
				end)
			end

			-- Third strike: the basin crashes into the ground
			if i == 3 then
				task.delay(0.05, function()
					if not hrp.Parent then return end
					spawnAuthoredBurst("AnimeParticles", "Water-02",      strikeCF, 44, 1.1,  WATER_C1, WATER_C2)
					spawnAuthoredBurst("AnimeParticles", "Splash-01",     strikeCF, 30, 1.05, WATER_C2, WATER_C1)
					spawnAuthoredBurst("AnimeParticles", "Slash-Impact-01", strikeCF, 18, 0.9, WATER_C1, WATER_C2)
					spawnShockwave(strikeCF.Position, WATER_C1, 1.05)
				end)
			end
		end)
	end
	playSound(hrp, "WaterBreathing", 0.56, 1.08)
end

-- Form 5: Constant Flux / Dead Calm — invisible precision cuts erupt 360° around the user
local function vfxConstantFlux(hrp: BasePart, skill)
	local centerCF = CFrame.new(hrp.Position + Vector3.new(0, 1, 0))

	-- "Dead calm" energy — water seems to stop moving before the explosion of cuts
	spawnAuthoredBurst("AnimeParticles", "Charge-01", centerCF, 26, 1.6, WATER_C1, WATER_C2)
	spawnAuthoredBurst("AnimeParticles",    "Water-01",       centerCF, 24, 1.2, WATER_C1, WATER_C2)
	spawnAuthoredBurst("DemonSlayerKit",    "Mist/water",     centerCF, 20, 1.1, WATER_C1, WATER_C2)

	local precisionCuts = math.max(8, skill.MultiHit)
	for i = 1, precisionCuts do
		task.delay((i - 1) * 0.055, function()
			if not hrp.Parent then return end
			local angle = (i / precisionCuts) * math.pi * 2
			local radius = 3.5 + (i % 3) * 1.1
			local cutCF = CFrame.new(
				hrp.Position + Vector3.new(math.cos(angle) * radius, 1 + (i % 2) * 1.3, math.sin(angle) * radius)
			) * CFrame.Angles(0, -angle + math.pi / 2, math.rad(i % 2 == 0 and 18 or -18))

			-- The "invisible slash" bursts into existence at each cut point
			spawnAuthoredBurst(
				"DemonSlayerKit",
				i % 3 == 0 and "Slash" or "Side slash",
				cutCF,
				9,
				0.52,
				i % 2 == 0 and WATER_C2 or WATER_C1,
				WATER_C2
			)
			spawnAuthoredBurst("AnimeParticles", "Slashes-01", cutCF, 8, 0.55, WATER_C1, WATER_C2)
			spawnAuthoredBurst("AnimeParticles", "Slash-01",   cutCF, 6, 0.45, WATER_C2, WATER_C1)
		end)
	end

	-- Everything resolves in a final burst
	task.delay(precisionCuts * 0.055 + 0.05, function()
		if not hrp.Parent then return end
		spawnAuthoredBurst("AnimeParticles", "Water-02",       centerCF, 26, 0.95, WATER_C1, WATER_C2)
		spawnAuthoredBurst("AnimeParticles", "Slash-Impact-01", centerCF, 18, 0.85, WATER_C1, WATER_C2)
		spawnShockwave(hrp.Position, WATER_C1, 1.1)
	end)
	playSound(hrp, "WaterBreathing", 0.4, 1.65)
end

-- Form 6 / Dragon: Whirlpool — massive water dragon surges toward the target
local function vfxWaterDragon(hrp: BasePart, skill)
	local origin = hrp.Position + Vector3.new(0, 2.2, 0)
	local forward = hrp.CFrame.LookVector
	local right = hrp.CFrame.RightVector
	local distance = math.max(28, skill.HitboxOffset * 2)

	-- Dragon model surges through the air
	local dragonSource = findVFXTemplate("DemonSlayerKit", "Constant flux's dragon")
	if dragonSource and dragonSource:IsA("Model") then
		local dragon = dragonSource:Clone()
		prepareWorldVFX(dragon, CFrame.lookAt(origin, origin + forward))
		for _, desc in dragon:GetDescendants() do
			if desc:IsA("BasePart") then
				if desc.Name == "Eye" then
					desc.Color = WATER_C2
					desc.Material = Enum.Material.Neon
				elseif desc.Name == "Outline" then
					desc.Color = Color3.fromRGB(10, 70, 150)
				else
					desc.Color = WATER_C1
				end
			end
		end
		pcall(function()
			dragon:ScaleTo(1.55)
		end)
		dragon.Parent = workspace
		Debris:AddItem(dragon, 1.35)
		animateModel(dragon, 0.88, function(alpha)
			local lateral = math.sin(alpha * math.pi * 3) * 2.0
			local lift = math.sin(alpha * math.pi) * 3.5
			local pos = origin + forward * (distance * alpha) + right * lateral + Vector3.new(0, lift, 0)
			local nextPos = pos + forward + right * math.cos(alpha * math.pi * 3) * 0.25
			return CFrame.lookAt(pos, nextPos)
		end)
	else
		launchMesh("Spiral", origin, forward, WATER_C1, distance / 0.7, 0.7)
	end

	-- Water energy erupts at the origin as the dragon launches
	spawnAuthoredBurst("AnimeParticles", "Charge-01", CFrame.new(origin), 30, 1.3, WATER_C1, WATER_C2)
	spawnAuthoredBurst("DemonSlayerKit",    "Water effect",   CFrame.new(origin), 28, 1.0, WATER_C1, WATER_C2)

	-- Water + slash trails along the dragon's serpentine path
	for i = 1, 6 do
		task.delay(i * 0.12, function()
			if not hrp.Parent then return end
			local a = i / 6
			local lateral = math.sin(a * math.pi * 3) * 2.0
			local lift = math.sin(a * math.pi) * 3.5
			local trailPos = origin + forward * distance * a + right * lateral + Vector3.new(0, lift, 0)
			spawnAuthoredBurst("AnimeParticles", "Water-01",   CFrame.new(trailPos), 14, 0.75, WATER_C1, WATER_C2)
			spawnAuthoredBurst("AnimeParticles", "Slashes-01", CFrame.lookAt(trailPos, trailPos + forward), 8, 0.6, WATER_C1, WATER_C2)
		end)
	end

	-- Dragon crashes into the target with a massive explosion of water
	task.delay(0.82, function()
		if not hrp.Parent then return end
		local impactPos = origin + forward * distance
		local impactCF = CFrame.lookAt(impactPos, impactPos + forward)
		spawnAuthoredBurst("AnimeParticles", "Water-02",       impactCF, 65, 1.35, WATER_C1, WATER_C2)
		spawnAuthoredBurst("AnimeParticles", "Splash-01",      impactCF, 52, 1.2,  WATER_C2, WATER_C1)
		spawnAuthoredBurst("AnimeParticles", "Slash-Impact-01", impactCF, 30, 1.05, WATER_C1, WATER_C2)
		spawnAuthoredBurst("DemonSlayerKit", "Mist/water 2",   impactCF, 32, 1.0,  WATER_C1, WATER_C2)
		spawnShockwave(impactPos, WATER_C1, 1.65)
		spawnShockwave(impactPos, WATER_C2, 1.1, 0.08)
	end)
	playSound(hrp, "WaterBreathing", 0.62, 1.02)
end

-- ── Flame Breathing ─────────────────────────────────────────────────────────────

-- Form 1 & 4: Unknowing Fire — precise upward diagonal flame slash
local function vfxFlameSlash(hrp: BasePart, skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)
	local fwd    = hrp.CFrame.LookVector

	for i = 1, math.min(skill.MultiHit, 3) do
		task.delay((i-1) * 0.08, function()
			if not hrp.Parent then return end
			launchMesh("SlashEffect", origin + Vector3.new(0, (i-1) * 0.35, 0), fwd, FLAME_C1, 32, 0.26)
		end)
	end

	local strikeCF = hrp.CFrame * CFrame.new(0, 1, -skill.HitboxOffset)
	spawnAuthoredBurst("DemonSlayerKit", "Flame strike",  strikeCF, 20, 0.65, FLAME_C1, FLAME_C2)
	spawnAuthoredBurst("DemonSlayerKit", "Flame",         strikeCF, 14, 0.6,  FLAME_C1, FLAME_C2)
	spawnAuthoredBurst("AnimeParticles", "Fire-Slash-01", strikeCF, 16, 0.7,  FLAME_C1, FLAME_C2)
	spawnAuthoredBurst("AnimeParticles", "Fire-01",       strikeCF, 14, 0.65, FLAME_C1, FLAME_C2)

	spawnGroundRing(hrp.Position, FLAME_C1, 5.5, 0.42)
	playSound(hrp, "FlameBreathing", 0.55, 1.1)
end

-- Form 2: Rising Scorching Sun — upward arc with blinding sun flare at the apex
local function vfxFlameRisingSun(hrp: BasePart, _skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)

	launchMesh("SlashSkill",  origin,                        Vector3.new(0, 1, 0.25), FLAME_C2, 20, 0.48)
	launchMesh("SlashEffect", origin + Vector3.new(0, 0.5, 0), hrp.CFrame.LookVector, FLAME_C1, 24, 0.34)

	local apexCF = hrp.CFrame * CFrame.new(0, 5, -4)
	spawnAuthoredBurst("DemonSlayerKit", "Flame/sun",    apexCF, 24, 0.85, FLAME_C2, FLAME_C1)
	spawnAuthoredBurst("DemonSlayerKit", "Flame swirly", apexCF, 18, 0.8,  FLAME_C2, FLAME_C1)
	spawnAuthoredBurst("AnimeParticles", "Fire-02",      apexCF, 20, 0.75, FLAME_C2, FLAME_C1)

	task.delay(0.22, function()
		if not hrp.Parent then return end
		local slamCF = hrp.CFrame * CFrame.new(0, 1, -3)
		spawnAuthoredBurst("AnimeParticles", "Fire-01", slamCF, 22, 0.7, FLAME_C1, FLAME_C2)
		spawnShockwave(hrp.Position, FLAME_C2, 0.65)
	end)
	playSound(hrp, "FlameBreathing", 0.6, 1.3)
end

-- Form 3: Blazing Universe — eruption of fire in all directions simultaneously
local function vfxFlameUniverse(hrp: BasePart, skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)

	spawnAuthoredBurst("DemonSlayerKit", "Flame burst", CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0)), 22, 0.85, FLAME_C1, FLAME_C2)
	spawnAuthoredBurst("AnimeParticles", "Fire-01",     CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0)), 18, 0.8,  FLAME_C1, FLAME_C2)

	for i = 1, skill.MultiHit do
		task.delay((i-1) * 0.09, function()
			if not hrp.Parent then return end
			local angle = math.rad(i * (360 / skill.MultiHit))
			local dir   = Vector3.new(math.cos(angle), 0, math.sin(angle))
			launchMesh("SlashEffect", origin, dir, FLAME_C1, 16, 0.34)
			spawnAuthoredBurst("DemonSlayerKit", "Flame arrow", CFrame.lookAt(origin, origin + dir), 12, 0.55, FLAME_C1, FLAME_C2)
		end)
	end

	spawnGroundRing(hrp.Position, FLAME_C1, 7, 0.52)
	task.delay(0.18, function()
		if hrp.Parent then
			spawnShockwave(hrp.Position, FLAME_C2, 0.8)
		end
	end)
	playSound(hrp, "FlameBreathing", 0.6, 1.0)
end

-- Esoteric: Purgatory — Rengoku's Sun Dragon charges through + all-direction purgatory flame
local function vfxFlameEsoteric(hrp: BasePart, skill)
	local origin   = hrp.Position
	local forward  = hrp.CFrame.LookVector
	local right    = hrp.CFrame.RightVector
	local distance = math.max(22, skill.HitboxOffset * 2)

	-- Sun Dragon charges forward
	local dragonSource = findVFXTemplate("DemonSlayerKit", "Sun dragon")
	if dragonSource and dragonSource:IsA("Model") then
		local dragon = dragonSource:Clone()
		prepareWorldVFX(dragon, CFrame.lookAt(origin + Vector3.new(0, 2, 0), origin + Vector3.new(0, 2, 0) + forward))
		for _, desc in dragon:GetDescendants() do
			if desc:IsA("BasePart") then
				if desc.Name == "Eye" then
					desc.Color    = FLAME_C2
					desc.Material = Enum.Material.Neon
				elseif desc.Name == "Outline" then
					desc.Color = Color3.fromRGB(180, 60, 10)
				else
					desc.Color = FLAME_C1
				end
			end
		end
		pcall(function()
			dragon:ScaleTo(1.45)
		end)
		dragon.Parent = workspace
		Debris:AddItem(dragon, 1.2)
		animateModel(dragon, 0.75, function(alpha)
			local lift    = math.sin(alpha * math.pi) * 2.5
			local lateral = math.sin(alpha * math.pi * 2) * 1.5
			local pos     = (origin + Vector3.new(0, 2, 0)) + forward * (distance * alpha) + right * lateral + Vector3.new(0, lift, 0)
			local nextPos = pos + forward + right * math.cos(alpha * math.pi * 2) * 0.1
			return CFrame.lookAt(pos, nextPos)
		end)
	end

	spawnAuthoredBurst("DemonSlayerKit", "Flame burst",  CFrame.new(origin + Vector3.new(0, 1.5, 0)), 28, 1.0, FLAME_C1, FLAME_C2)
	spawnAuthoredBurst("DemonSlayerKit", "Flame swirly", CFrame.new(origin + Vector3.new(0, 1, 0)),   22, 1.1, FLAME_C2, FLAME_C1)
	spawnAuthoredBurst("AnimeParticles", "Fire-01",       CFrame.new(origin + Vector3.new(0, 1, 0)),   26, 1.0, FLAME_C1, FLAME_C2)

	for i = 1, skill.MultiHit do
		task.delay((i-1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			local angle = math.rad(i * 60)
			local dir   = hrp.CFrame.LookVector * math.cos(angle) + hrp.CFrame.RightVector * math.sin(angle)
			launchMesh("SlashEffect", origin + Vector3.new(0, 1, 0),   dir, FLAME_C1, 30, 0.28)
			launchMesh("SlashSkill",  origin + Vector3.new(0, 1.6, 0), dir, FLAME_C2, 26, 0.30)
			spawnAuthoredBurst("DemonSlayerKit", "Uknowing fire", hrp.CFrame * CFrame.new(0, 1, -3), 10, 0.55, FLAME_C1, FLAME_C2)
		end)
	end

	for i = 1, 4 do
		spawnShockwave(origin, i%2==0 and FLAME_C2 or FLAME_C1, 0.8 + i*0.3, (i-1)*0.1)
	end
	task.delay(0.6, function()
		if hrp.Parent then
			spawnAuthoredBurst("AnimeParticles", "Fire-03", CFrame.new(origin + Vector3.new(0, 1, 0)), 35, 0.9, FLAME_C1, FLAME_C2)
		end
	end)
	spawnAura(hrp, FLAME_C1, 0.8, 5)
	spawnGroundRing(origin, FLAME_C2, 13, 0.9)
	playSound(hrp, "FlameBreathing", 0.8, 0.88)
end

-- Form 5: Flame Tiger — a flaming beast rushes forward leaving a scorching trail
local function vfxFlameTiger(hrp: BasePart, skill)
	local fwd      = hrp.CFrame.LookVector
	local origin   = hrp.Position + Vector3.new(0, 1, 0)
	local distance = (skill.HitboxOffset or 14)

	launchMesh("Tornado",     origin,                          fwd, FLAME_C1, 52, 0.5)
	launchMesh("SlashEffect", origin + Vector3.new(0, 1.2, 0), fwd, FLAME_C2, 50, 0.5)

	for i = 1, 4 do
		task.delay(i * 0.08, function()
			if not hrp.Parent then return end
			local trailPos = origin + fwd * distance * (i / 5)
			spawnAuthoredBurst("DemonSlayerKit", "Flame",  CFrame.new(trailPos), 14, 0.6,  FLAME_C1, FLAME_C2)
			spawnAuthoredBurst("AnimeParticles", "Fire-02", CFrame.new(trailPos), 12, 0.55, FLAME_C1, FLAME_C2)
		end)
	end

	task.delay(0.42, function()
		if not hrp.Parent then return end
		local impactPos = hrp.Position + fwd * distance
		spawnAuthoredBurst("DemonSlayerKit", "Flame burst",  CFrame.new(impactPos), 30, 0.85, FLAME_C1, FLAME_C2)
		spawnAuthoredBurst("DemonSlayerKit", "Flame swirly", CFrame.new(impactPos), 22, 0.8,  FLAME_C2, FLAME_C1)
		spawnAuthoredBurst("AnimeParticles", "Fire-01",       CFrame.new(impactPos), 28, 0.8,  FLAME_C1, FLAME_C2)
		spawnShockwave(impactPos, FLAME_C1, 1.5)
		spawnGroundRing(impactPos, FLAME_C2, 9, 0.6)
	end)
	playSound(hrp, "FlameBreathing", 0.7, 1.05)
end

-- ── Demon Arts ─────────────────────────────────────────────────────────────────

-- Demon Slash — dark evil slashes with blood impact and crushing evil twirl
local function vfxDemonSlash(hrp: BasePart, skill)
	local fwd    = hrp.CFrame.LookVector
	local origin = hrp.Position + Vector3.new(0, 1, 0)

	for i = 1, skill.MultiHit do
		task.delay((i-1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			launchMesh("SlashEffect", origin, fwd, DEMON_C1, 24, 0.28)
			spawnAuthoredBurst("DemonSlayerKit", "Evil twirl", CFrame.lookAt(origin, origin + fwd), 12, 0.5, DEMON_C1, DEMON_C2)
		end)
	end

	task.delay(0.08, function()
		if not hrp.Parent then return end
		local impactCF = hrp.CFrame * CFrame.new(0, 1, -skill.HitboxOffset)
		spawnAuthoredBurst("AnimeParticles", "Blood-01",   impactCF, 16, 0.6, DEMON_C1, DEMON_C2)
		spawnAuthoredBurst("AnimeParticles", "Slashes-01", impactCF, 12, 0.5, DEMON_C1, DEMON_C2)
	end)

	spawnGroundRing(hrp.Position, DEMON_C2, 4.5, 0.42)
	playSound(hrp, "DemonArts", 0.55, 0.85)
end

-- Blood Burst — massive crimson explosion shatters the ground
local function vfxBloodBurst(hrp: BasePart, _skill)
	local centerCF = CFrame.new(hrp.Position + Vector3.new(0, 1, 0))

	spawnAuthoredBurst("AnimeParticles", "Blood-02",  centerCF, 35, 0.85, DEMON_C1, DEMON_C2)
	spawnAuthoredBurst("AnimeParticles", "Blood-01",  centerCF, 22, 0.75, DEMON_C1, DEMON_C2)
	spawnAuthoredBurst("DemonSlayerKit", "Explosion", centerCF, 24, 0.8,  DEMON_C1, DEMON_C2)
	spawnAuthoredBurst("AnimeParticles", "Crack-01",  CFrame.new(hrp.Position + Vector3.new(0, 0.1, 0)), 18, 0.9, DEMON_C1, DEMON_C2)

	for i = 1, 3 do
		spawnShockwave(hrp.Position, i%2==0 and DEMON_C2 or DEMON_C1, 0.5 + i*0.35, (i-1)*0.08)
	end
	spawnAura(hrp, DEMON_C1, 0.6, 4)
	playSound(hrp, "DemonArts", 0.65, 0.8)
end

-- Shadow Step — demon blinks between strike points leaving lightning trails
local function vfxShadowStep(hrp: BasePart, skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)

	spawnAuthoredBurst("AnimeParticles", "Lighting-02", CFrame.new(origin), 16, 0.45, DEMON_C2, DEMON_C1)
	spawnAuthoredBurst("AnimeParticles", "Wind-02",     CFrame.new(origin), 14, 0.4,  DEMON_C2, DEMON_C1)
	spawnShockwave(hrp.Position, DEMON_C2, 0.7)

	for i = 1, skill.MultiHit do
		task.delay((i-1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			local angle = math.rad(i * 90)
			local dir   = hrp.CFrame.LookVector * math.cos(angle) + hrp.CFrame.RightVector * math.sin(angle)
			launchMesh("SlashSkill", origin, dir, DEMON_C1, 20, 0.26)
			spawnAuthoredBurst("DemonSlayerKit", "Thunder2",  CFrame.lookAt(origin, origin + dir), 10, 0.45, DEMON_C1, DEMON_C2)
			spawnAuthoredBurst("AnimeParticles", "Blood-01",  CFrame.new(origin + dir * 3),        10, 0.5,  DEMON_C1, DEMON_C2)
		end)
	end
	playSound(hrp, "DemonArts", 0.5, 1.15)
end

-- Demon Awakening — the demon's true power erupts with dark energy and lightning
local function vfxDemonAwakening(hrp: BasePart, skill)
	local origin   = hrp.Position
	local centerCF = CFrame.new(origin + Vector3.new(0, 1, 0))

	spawnAuthoredBurst("DemonSlayerKit", "Evil twirl",  centerCF, 28, 1.2, DEMON_C1, DEMON_C2)
	spawnAuthoredBurst("AnimeParticles", "Lighting-03", centerCF, 24, 1.1, DEMON_C2, DEMON_C1)
	spawnAuthoredBurst("AnimeParticles", "Blood-02",    centerCF, 22, 1.0, DEMON_C1, DEMON_C2)

	for i = 1, skill.MultiHit do
		task.delay((i-1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			local angle = math.rad(i * (360 / skill.MultiHit))
			local dir   = Vector3.new(math.cos(angle), 0, math.sin(angle))
			launchMesh("SlashEffect", origin + Vector3.new(0, 1, 0), dir, DEMON_C1, 22, 0.32)
			spawnAuthoredBurst("DemonSlayerKit", "Thunder",
				CFrame.new(origin + Vector3.new(dir.X * 3, 1, dir.Z * 3)), 8, 0.45, DEMON_C1, DEMON_C2)
		end)
	end

	for i = 1, 5 do
		spawnShockwave(origin, i%2==0 and DEMON_C1 or DEMON_C2, 1 + i*0.4, (i-1)*0.12)
	end
	spawnAura(hrp, DEMON_C2, 1.0, 6)
	spawnGroundRing(origin, DEMON_C1, 13, 0.85)
	playSound(hrp, "DemonArts", 0.85, 0.78)
end

-- Blood Moon — crimson moon rises, raining blood across a vast radius
local function vfxBloodMoon(hrp: BasePart, skill)
	local origin   = hrp.Position
	local centerCF = CFrame.new(origin + Vector3.new(0, 1, 0))

	spawnAuthoredBurst("DemonSlayerKit", "Rain or sum", CFrame.new(origin + Vector3.new(0, 6, 0)), 22, 1.1, DEMON_C1, DEMON_C2)
	spawnAuthoredBurst("AnimeParticles", "Blood-02",    centerCF, 28, 1.0, DEMON_C1, DEMON_C2)
	spawnAuthoredBurst("DemonSlayerKit", "Evil twirl",  centerCF, 18, 0.9, DEMON_C2, DEMON_C1)

	for ring = 1, 4 do
		task.delay((ring-1) * 0.12, function()
			if not hrp.Parent then return end
			spawnShockwave(origin, ring%2==0 and DEMON_C2 or DEMON_C1, 1.2 + ring*0.3)
		end)
	end

	for i = 1, skill.MultiHit do
		task.delay((i-1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			local angle = math.rad(i * (360 / skill.MultiHit))
			local dir   = Vector3.new(math.cos(angle), 0, math.sin(angle))
			launchMesh("SlashSkill", origin + Vector3.new(0, 1, 0), dir, DEMON_C2, 20, 0.35)
			spawnAuthoredBurst("AnimeParticles", "Blood-01",
				CFrame.new(origin + Vector3.new(dir.X * 4, 1, dir.Z * 4)), 10, 0.5, DEMON_C1, DEMON_C2)
		end)
	end

	spawnGroundRing(origin, DEMON_C1, 11, 0.7)
	spawnAura(hrp, DEMON_C1, 0.9, 7)
	playSound(hrp, "DemonArts", 0.8, 0.75)
end

-- ── Temari Demon Arts ───────────────────────────────────────────────────────────

-- Temari Throw — a spinning ball of dark energy hurled forward with sparkle trail
local function vfxTemariThrow(hrp: BasePart, _skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)
	local fwd    = hrp.CFrame.LookVector

	launchMesh("WindSphere", origin, fwd, TEMARI_C1, 36, 0.4)
	launchMesh("Swirl",      origin, fwd, TEMARI_C2, 34, 0.38)
	spawnAuthoredBurst("AnimeParticles", "Shiny-01", CFrame.new(origin), 14, 0.4, TEMARI_C1, TEMARI_C2)

	task.delay(0.22, function()
		if not hrp.Parent then return end
		local impactCF = hrp.CFrame * CFrame.new(0, 1, -8)
		spawnAuthoredBurst("AnimeParticles", "Punch-01",  impactCF, 16, 0.5,  TEMARI_C1, TEMARI_C2)
		spawnAuthoredBurst("DemonSlayerKit", "Splatter",  impactCF, 18, 0.55, TEMARI_C1, TEMARI_C2)
		spawnShockwave(impactCF.Position, TEMARI_C1, 0.6)
	end)
	playSound(hrp, "TemariDemonArts", 0.5, 0.95)
end

-- Double Temari — two balls diverge on separate arcing paths then detonate
local function vfxDoubleTemari(hrp: BasePart, _skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)
	local fwd    = hrp.CFrame.LookVector
	local right  = hrp.CFrame.RightVector

	launchMesh("WindSphere", origin, fwd + right * 0.35, TEMARI_C1, 33, 0.42)
	launchMesh("WindSphere", origin, fwd - right * 0.35, TEMARI_C2, 33, 0.42)
	launchMesh("Swirl",      origin, fwd + right * 0.2,  TEMARI_C2, 31, 0.40)
	launchMesh("Swirl",      origin, fwd - right * 0.2,  TEMARI_C1, 31, 0.40)

	spawnAuthoredBurst("AnimeParticles", "Stars-01", CFrame.new(origin), 18, 0.45, TEMARI_C1, TEMARI_C2)
	spawnAuthoredBurst("AnimeParticles", "Shiny-01", CFrame.new(origin), 14, 0.42, TEMARI_C2, TEMARI_C1)

	task.delay(0.25, function()
		if not hrp.Parent then return end
		local impactCF = hrp.CFrame * CFrame.new(0, 1, -9)
		spawnAuthoredBurst("AnimeParticles", "Punch-02", impactCF, 18, 0.5, TEMARI_C1, TEMARI_C2)
		spawnShockwave(impactCF.Position, TEMARI_C1, 0.65)
	end)
	playSound(hrp, "TemariDemonArts", 0.5, 1.0)
end

-- Temari Barrage — rapid fire of spinning balls in a spread fan pattern
local function vfxTemariBarrage(hrp: BasePart, skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)
	local fwd    = hrp.CFrame.LookVector

	for i = 1, skill.MultiHit do
		task.delay((i-1) * 0.09, function()
			if not hrp.Parent then return end
			local spread = math.rad((i-1) * 12 - 30)
			local dir    = fwd * math.cos(spread) + hrp.CFrame.RightVector * math.sin(spread)
			local col    = i%2==0 and TEMARI_C2 or TEMARI_C1
			launchMesh("WindSphere", origin, dir, col, 31, 0.36)
			spawnAuthoredBurst("AnimeParticles", "Punch-02", CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -4), 8, 0.38, col, TEMARI_C2)
		end)
	end

	task.delay(skill.MultiHit * 0.09 + 0.1, function()
		if not hrp.Parent then return end
		local finalCF = hrp.CFrame * CFrame.new(0, 1, -skill.HitboxOffset)
		spawnAuthoredBurst("AnimeParticles", "Punch-03", finalCF, 22, 0.6, TEMARI_C1, TEMARI_C2)
		spawnShockwave(hrp.Position, TEMARI_C1, 0.9)
	end)
	playSound(hrp, "TemariDemonArts", 0.55, 1.0)
end

-- Moon Claw — crescent slash arcs with alternating razor claw strikes
local function vfxMoonClaw(hrp: BasePart, skill)
	local origin = hrp.Position + Vector3.new(0, 1, 0)
	local fwd    = hrp.CFrame.LookVector

	spawnAuthoredBurst("AnimeParticles", "Slashes-01",  CFrame.new(origin), 18, 0.65, TEMARI_C1, TEMARI_C2)
	spawnAuthoredBurst("DemonSlayerKit", "Multi slash", CFrame.new(origin), 16, 0.6,  TEMARI_C1, TEMARI_C2)

	for i = 1, skill.MultiHit do
		task.delay((i-1) * skill.MultiHitDelay, function()
			if not hrp.Parent then return end
			local side = i%2==0 and 1 or -1
			local dir  = fwd + hrp.CFrame.RightVector * side * 0.4
			launchMesh("SlashSkill", origin, dir, TEMARI_C1, 20, 0.28)
			spawnAuthoredBurst("AnimeParticles", "Punch-01",
				CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -3), 10, 0.4, TEMARI_C1, TEMARI_C2)
		end)
	end

	spawnGroundRing(hrp.Position, TEMARI_C2, 6, 0.45)
	playSound(hrp, "TemariDemonArts", 0.55, 1.05)
end

-- Blood Temari — a blood-infused temari erupts with dark twisted energy
local function vfxBloodTemari(hrp: BasePart, _skill)
	local centerCF = CFrame.new(hrp.Position + Vector3.new(0, 1, 0))

	spawnAuthoredBurst("DemonSlayerKit", "Evil twirl", centerCF, 22, 0.85, TEMARI_C1, TEMARI_C2)
	spawnAuthoredBurst("AnimeParticles", "Blood-01",   centerCF, 20, 0.8,  TEMARI_C1, TEMARI_C2)
	spawnAuthoredBurst("AnimeParticles", "Wind-01",    centerCF, 18, 0.75, TEMARI_C2, TEMARI_C1)
	spawnAuthoredBurst("AnimeParticles", "Slashes-01", centerCF, 14, 0.7,  TEMARI_C1, TEMARI_C2)

	for i = 1, 3 do
		spawnShockwave(hrp.Position, i%2==0 and TEMARI_C2 or TEMARI_C1, 0.75 + i*0.4, (i-1)*0.08)
	end
	spawnGroundRing(hrp.Position, TEMARI_C1, 10, 0.62)
	playSound(hrp, "TemariDemonArts", 0.7, 0.88)
end

-- Full Moon — the ultimate technique: moon energy erupts in 6 directions
local function vfxTemariFullMoon(hrp: BasePart, _skill)
	local origin   = hrp.Position
	local centerCF = CFrame.new(origin + Vector3.new(0, 1, 0))

	spawnAuthoredBurst("AnimeParticles", "Stars-01",   centerCF, 30, 1.0, TEMARI_C1, TEMARI_C2)
	spawnAuthoredBurst("AnimeParticles", "Shiny-01",   centerCF, 24, 0.9, TEMARI_C2, TEMARI_C1)
	spawnAuthoredBurst("DemonSlayerKit", "Evil twirl", centerCF, 20, 1.0, TEMARI_C1, TEMARI_C2)

	for arm = 1, 6 do
		task.delay((arm-1) * 0.09, function()
			if not hrp.Parent then return end
			local angle    = math.rad((arm-1) * 60)
			local dir      = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local spawnPos = origin + dir * 4 + Vector3.new(0, 1, 0)
			launchMesh("WindSphere", spawnPos, dir, arm%2==0 and TEMARI_C2 or TEMARI_C1, 30, 0.44)
			launchMesh("Swirl",      spawnPos, dir, arm%2==0 and TEMARI_C1 or TEMARI_C2, 28, 0.42)
			spawnAuthoredBurst("AnimeParticles", "Punch-03", CFrame.new(spawnPos), 8, 0.4, TEMARI_C1, TEMARI_C2)
		end)
	end

	for i = 1, 3 do
		spawnShockwave(origin, TEMARI_C1, 1 + i*0.5, (i-1)*0.14)
	end
	spawnGroundRing(origin, TEMARI_C2, 14, 0.75)
	spawnAura(hrp, TEMARI_C2, 1.0, 7)
	playSound(hrp, "TemariDemonArts", 0.8, 0.85)
end

-- ── Flight VFX (takeoff burst per style) ──────────────────────────────────────

local function vfxWaterFlight(hrp: BasePart, _skill)
	spawnAura(hrp, WATER_C1, 1.2, 5)
	spawnGroundRing(hrp.Position, WATER_C1, 7, 0.5)
	spawnAuthoredBurst("AnimeParticles", "Water-01", CFrame.new(hrp.Position + Vector3.new(0, 1, 0)), 20, 0.8, WATER_C1, WATER_C2)
	spawnShockwave(hrp.Position, WATER_C2, 0.9, 0)
	playSound(hrp, "WaterBreathing", 0.55, 1.1)
end

local function vfxFlameFlight(hrp: BasePart, _skill)
	spawnAura(hrp, FLAME_C1, 1.2, 5)
	spawnGroundRing(hrp.Position, FLAME_C1, 7, 0.5)
	spawnAuthoredBurst("AnimeParticles", "Punch-03", CFrame.new(hrp.Position + Vector3.new(0, 1, 0)), 20, 0.8, FLAME_C1, FLAME_C2)
	spawnShockwave(hrp.Position, FLAME_C2, 0.9, 0)
	playSound(hrp, "FlameBreathing", 0.6, 1.0)
end

local function vfxDemonFlight(hrp: BasePart, _skill)
	spawnAura(hrp, DEMON_C2, 1.2, 5)
	spawnGroundRing(hrp.Position, DEMON_C1, 7, 0.5)
	spawnAuthoredBurst("DemonSlayerKit", "Evil twirl", CFrame.new(hrp.Position + Vector3.new(0, 1, 0)), 18, 0.8, DEMON_C1, DEMON_C2)
	spawnShockwave(hrp.Position, DEMON_C2, 0.9, 0)
	playSound(hrp, "DemonArts", 0.55, 0.9)
end

local function vfxTemariFlightSkill(hrp: BasePart, _skill)
	spawnAura(hrp, TEMARI_C1, 1.2, 5)
	spawnGroundRing(hrp.Position, TEMARI_C2, 7, 0.5)
	spawnAuthoredBurst("AnimeParticles", "Stars-01", CFrame.new(hrp.Position + Vector3.new(0, 1, 0)), 18, 0.8, TEMARI_C1, TEMARI_C2)
	spawnShockwave(hrp.Position, TEMARI_C1, 0.9, 0)
	playSound(hrp, "TemariDemonArts", 0.55, 1.05)
end

-- ── Dispatch table ─────────────────────────────────────────────────────────────

type VFXHandler = (hrp: BasePart, skill: any) -> ()

local SKILL_HANDLERS: { [string]: VFXHandler } = {
	-- Water Breathing
	WaterSurfaceSlash = vfxWaterSurfaceSlash,
	WaterWheel        = vfxWaterWheel,
	FlowingDance      = vfxFlowingDance,
	WaterfallBasin    = vfxWaterfallBasin,
	ConstantFlux      = vfxConstantFlux,
	WaterDragon       = vfxWaterDragon,
	-- Flame Breathing
	FlameFirst        = vfxFlameSlash,
	FlameSecond       = vfxFlameRisingSun,
	FlameThird        = vfxFlameUniverse,
	FlameFourth       = vfxFlameSlash,
	FlameEsoteric     = vfxFlameEsoteric,
	FlameFifth        = vfxFlameTiger,
	-- Demon Arts
	DemonSlash        = vfxDemonSlash,
	BloodBurst        = vfxBloodBurst,
	ShadowStep        = vfxShadowStep,
	CrimsonClaw       = vfxDemonSlash,
	DemonAwakening    = vfxDemonAwakening,
	BloodMoon         = vfxBloodMoon,
	-- Temari Demon Arts
	TemariThrow       = vfxTemariThrow,
	DoubleTemari      = vfxDoubleTemari,
	TemariBarrage     = vfxTemariBarrage,
	MoonClaw          = vfxMoonClaw,
	BloodTemari       = vfxBloodTemari,
	TemariFullMoon    = vfxTemariFullMoon,
	-- Flight
	WaterFlight       = vfxWaterFlight,
	FlameFlight       = vfxFlameFlight,
	DemonFlight       = vfxDemonFlight,
	TemariFlightSkill = vfxTemariFlightSkill,
}

local STYLE_FALLBACK_COLOR: { [string]: Color3 } = {
	WaterBreathing  = WATER_C1,
	FlameBreathing  = FLAME_C1,
	DemonArts       = DEMON_C1,
	TemariDemonArts = TEMARI_C1,
}

-- ── Public API ─────────────────────────────────────────────────────────────────

local SkillVFX = {}

function SkillVFX.play(character: Model, skillId: string)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local skill = SkillSystemModule.getSkill(skillId)
	if not skill then return end

	CombatPresentationModule.playSkillCastAccent(character, skill.Style, skill.Slot == "V")
	local handler = SKILL_HANDLERS[skillId]
	if handler then
		handler(hrp, skill)
	else
		local color = STYLE_FALLBACK_COLOR[skill.Style] or Color3.fromRGB(200, 200, 255)
		launchMesh("SlashEffect", hrp.Position + Vector3.new(0,1,0), hrp.CFrame.LookVector, color, 26, 0.3)
		spawnGroundRing(hrp.Position, color, 5, 0.42)
		playSound(hrp, skill.Style or "", 0.45, 1.0)
	end
end

-- selene: allow(global_usage)
_G.SkillVFX = SkillVFX

print("[SkillVFXController] Loaded — AAA skill VFX + imported SFX active")
