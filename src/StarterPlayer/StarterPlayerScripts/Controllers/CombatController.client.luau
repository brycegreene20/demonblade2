local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local _SoundService = game:GetService("SoundService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LightAttackRemote = Remotes:WaitForChild("LightAttack")
local DamageDealt = Remotes:WaitForChild("DamageDealt")
local UseSkillRemote = Remotes:WaitForChild("UseSkill")
local SkillActivatedRemote = Remotes:WaitForChild("SkillActivated")
local FactionChosenRemote = Remotes:WaitForChild("FactionChosen")
local StyleChangedRemote = Remotes:WaitForChild("StyleChanged")
local InventoryChangedRemote = Remotes:WaitForChild("InventoryChanged")
local BlockRemote = Remotes:WaitForChild("Block")
local ParryAttemptRemote = Remotes:WaitForChild("ParryAttempt")
local BlockParryVFXRemote = Remotes:WaitForChild("BlockParryVFX")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))

local COMBO_RESET_TIME = 1.2
local MAX_COMBO = 4
local ATTACK_COOLDOWN = 0.25
local CAMERA_SHAKE_INTENSITY = 0.3
local CAMERA_SHAKE_DURATION = 0.08
local comboIndex = 0
local lastAttackTime = 0
local isAttacking = false

local isBlocking = false
local blockPressTime = 0
local PARRY_TAP_THRESHOLD = 0.25
local blockShieldPart = nil
local blockShieldTween = nil
local MAX_BLOCK_DURATION = 5
local blockSafetyThread = nil

local COMBO_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 220, 255),
	Color3.fromRGB(170, 200, 255),
	Color3.fromRGB(255, 200, 100),
}

local COMBO_LUNGE = {3, 4, 5, 8}

local cachedComboTracks = {}

local function cacheAnimations()
	cachedComboTracks = {}
	local character = LocalPlayer.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local comboAnimIds = {
		"rbxassetid://180435571",
		"rbxassetid://180435571",
		"rbxassetid://180435571",
		"rbxassetid://180435571",
	}
	for i, animId in comboAnimIds do
		local anim = Instance.new("Animation")
		anim.AnimationId = animId
		cachedComboTracks[i] = animator:LoadAnimation(anim)
		cachedComboTracks[i].Priority = Enum.AnimationPriority.Action
	end

end

local function getCharacter()
	return LocalPlayer.Character
end

local function shakeCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end
	task.spawn(function()
		for _ = 1, 3 do
			local offset = Vector3.new(
				(math.random() - 0.5) * 2 * CAMERA_SHAKE_INTENSITY,
				(math.random() - 0.5) * 2 * CAMERA_SHAKE_INTENSITY,
				0
			)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait(CAMERA_SHAKE_DURATION / 3)
		end
	end)
end

local function spawnSwingVFX(character, hitIndex)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local slash = Instance.new("Part")
	slash.Name = "SlashVFX"
	slash.Size = Vector3.new(0.2, 3, 3)
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.CanTouch = false
	slash.Material = Enum.Material.Neon
	slash.Color = COMBO_COLORS[hitIndex] or COMBO_COLORS[1]
	slash.Transparency = 0.3
	slash.CastShadow = false

	local angles = {0, 45, -30, 90}
	local angle = math.rad(angles[hitIndex] or 0)
	slash.CFrame = hrp.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, 0, angle)
	slash.Parent = workspace

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(slash, tweenInfo, {
		Transparency = 1,
		Size = Vector3.new(0.05, 5, 5),
	})
	tween:Play()
	Debris:AddItem(slash, 0.25)
end

local function playSwingSound(character, hitIndex)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_get_up.mp3"
	sound.Volume = 0.4
	sound.PlaybackSpeed = 0.9 + (hitIndex * 0.1)
	sound.Parent = hrp
	sound:Play()
	Debris:AddItem(sound, 1)
end

local function applyLunge(character, hitIndex)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local lungeForce = COMBO_LUNGE[hitIndex] or 3
	hrp.AssemblyLinearVelocity = hrp.CFrame.LookVector * lungeForce * 5 + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
end

local function performLightAttack()
	local now = os.clock()
	if now - lastAttackTime < ATTACK_COOLDOWN then return end
	if isAttacking then return end
	if isBlocking then return end

	local character = getCharacter()
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if now - lastAttackTime > COMBO_RESET_TIME then
		comboIndex = 0
	end

	comboIndex = comboIndex + 1
	if comboIndex > MAX_COMBO then
		comboIndex = 1
	end

	lastAttackTime = now
	isAttacking = true

	LightAttackRemote:FireServer()

	spawnSwingVFX(character, comboIndex)
	playSwingSound(character, comboIndex)
	applyLunge(character, comboIndex)

	local _animTrack = playComboAnimation(humanoid, comboIndex)

	task.delay(ATTACK_COOLDOWN, function()
		isAttacking = false
	end)
	task.delay(1.0, function()
		isAttacking = false
	end)
end

-- selene: allow(unused_variable)
function playComboAnimation(_humanoid, hitIndex)
	local track = cachedComboTracks[hitIndex] or cachedComboTracks[1]
	if not track then return nil end

	track:AdjustSpeed(1.3 + (hitIndex - 1) * 0.1)
	track:Play(0.05)

	task.delay(0.4, function()
		track:Stop(0.1)
	end)

	return track
end

LightAttackRemote.OnClientEvent:Connect(function(serverComboIndex, didHit, sourcePlayer)
	if sourcePlayer then
		local otherChar = sourcePlayer.Character
		if otherChar then
			spawnSwingVFX(otherChar, serverComboIndex)
			playSwingSound(otherChar, serverComboIndex)
		end
		return
	end
	if didHit then
		shakeCamera()
	end
	comboIndex = serverComboIndex
end)

DamageDealt.OnClientEvent:Connect(function(targetModel, amount, _hitPos, isCritical)
	if not targetModel or not targetModel.Parent then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Size = UDim2.fromScale(2, 1)
	billboard.StudsOffset = Vector3.new(math.random(-1, 1), 2 + math.random(), 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 50

	local targetPart = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Head")
	if not targetPart then return end
	billboard.Adornee = targetPart
	billboard.Parent = targetPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(amount))
	label.TextColor3 = isCritical and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 100)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(billboard, tweenInfo, {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 3, 0),
	})
	tween:Play()

	task.delay(0.3, function()
		local fadeTween = TweenService:Create(label, TweenInfo.new(0.3), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fadeTween:Play()
	end)

	Debris:AddItem(billboard, 0.7)
end)

-- ==================== SKILL SYSTEM ====================
local _currentFaction = ""
local _currentStyle = ""
local _clientInventory = {}
local _clientMastery = {}
local skillSlots = {}
local skillCooldownExpiry = {}
local isUsingSkill = false
local updateSkillBarUI

local SLOT_KEYS = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.V] = "V",
	[Enum.KeyCode.Y] = "Y",
	[Enum.KeyCode.ButtonR1] = "Q",
	[Enum.KeyCode.ButtonR2] = "E",
	[Enum.KeyCode.ButtonL2] = "R",
	[Enum.KeyCode.ButtonY] = "F",
	[Enum.KeyCode.ButtonB] = "V",
	[Enum.KeyCode.DPadUp] = "Y",
}

local SKILL_VFX_COLORS = {
	WaterSurfaceSlash = Color3.fromRGB(40, 140, 255),
	WaterWheel = Color3.fromRGB(60, 180, 255),
	FlowingDance = Color3.fromRGB(80, 200, 255),
	WaterfallBasin = Color3.fromRGB(20, 100, 220),
	ConstantFlux = Color3.fromRGB(0, 200, 255),
	DemonSlash = Color3.fromRGB(180, 30, 60),
	BloodBurst = Color3.fromRGB(200, 20, 20),
	ShadowStep = Color3.fromRGB(80, 0, 120),
	CrimsonClaw = Color3.fromRGB(160, 10, 40),
	DemonAwakening = Color3.fromRGB(120, 0, 180),
	WaterDragon = Color3.fromRGB(0, 120, 255),
	BloodMoon = Color3.fromRGB(140, 0, 30),
	FlameFirst = Color3.fromRGB(255, 100, 20),
	FlameSecond = Color3.fromRGB(255, 140, 0),
	FlameThird = Color3.fromRGB(255, 60, 10),
	FlameFourth = Color3.fromRGB(255, 80, 0),
	FlameEsoteric = Color3.fromRGB(255, 200, 30),
	FlameFifth = Color3.fromRGB(255, 120, 10),
	TemariThrow = Color3.fromRGB(220, 90, 230),
	DoubleTemari = Color3.fromRGB(210, 80, 220),
	TemariBarrage = Color3.fromRGB(230, 120, 240),
	MoonClaw = Color3.fromRGB(190, 50, 210),
	BloodTemari = Color3.fromRGB(200, 40, 90),
	TemariFullMoon = Color3.fromRGB(230, 160, 255),
}

local function buildSkillSlots(faction)
	skillSlots = {}
	for _, slot in {"Q", "E", "R", "F", "V", "Y"} do
		local skill = SkillSystemModule.getSkillForSlot(faction, slot)
		if skill then
			local mastery = _clientMastery[skill.Style or ""]
			local masteryLevel = mastery and (mastery.Level or 1) or 1
			if masteryLevel >= (skill.MasteryLevelRequired or 1) then
				skillSlots[slot] = skill
			end
		end
	end
end

local function rebuildCurrentSkillSlots()
	local styleToUse = _currentStyle ~= "" and _currentStyle or _currentFaction
	if styleToUse ~= "" then
		buildSkillSlots(styleToUse)
		updateSkillBarUI()
	end
end

local function cacheMastery(mastery)
	_clientMastery = typeof(mastery) == "table" and mastery or {}
end

local function cacheMasteryEntry(styleId, level, xp, xpNeeded, totalXP)
	if typeof(styleId) ~= "string" or styleId == "" then return end
	_clientMastery[styleId] = {
		Level = level or 1,
		XP = xp or 0,
		XPNeeded = xpNeeded or 30,
		TotalXP = totalXP or 0,
	}
	rebuildCurrentSkillSlots()
end

local function setFaction(faction)
	_currentFaction = faction
	buildSkillSlots(_currentStyle ~= "" and _currentStyle or faction)
end

local function setStyle(style)
	_currentStyle = style
	buildSkillSlots(style ~= "" and style or _currentFaction)
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local skillBarGui = Instance.new("ScreenGui")
skillBarGui.Name = "SkillBarHUD"
skillBarGui.ResetOnSpawn = false
skillBarGui.IgnoreGuiInset = true
skillBarGui.DisplayOrder = 6
skillBarGui.Parent = PlayerGui

local SLOT_ORDER = { Q = 1, E = 2, R = 3, F = 4, V = 5, Y = 6 }
local ULTIMATE_SLOT = "V"

local skillBarContainer = Instance.new("Frame")
skillBarContainer.Name = "SkillBar"
skillBarContainer.Size = UDim2.fromOffset(440, 74)
skillBarContainer.Position = UDim2.new(0.5, 0, 1, -30)
skillBarContainer.AnchorPoint = Vector2.new(0.5, 1)
skillBarContainer.BackgroundTransparency = 1
skillBarContainer.Parent = skillBarGui

local skillBarLayout = Instance.new("UIListLayout")
skillBarLayout.FillDirection = Enum.FillDirection.Horizontal
skillBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillBarLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
skillBarLayout.Padding = UDim.new(0, 8)
skillBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
skillBarLayout.Parent = skillBarContainer

local skillSlotFrames = {}

local function createSkillSlotUI(slotKey)
	local isUlt = slotKey == ULTIMATE_SLOT
	local slotSize = if isUlt then 70 else 60

	local frame = Instance.new("Frame")
	frame.Name = slotKey .. "Slot"
	frame.Size = UDim2.fromOffset(slotSize, slotSize)
	frame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.LayoutOrder = SLOT_ORDER[slotKey] or 99
	frame.Parent = skillBarContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if isUlt then 2.5 else 1.5
	stroke.Transparency = if isUlt then 0.1 else 0.3
	stroke.Color = if isUlt then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(60, 65, 80)
	stroke.Parent = frame

	if isUlt then
		local glow = Instance.new("ImageLabel")
		glow.Name = "UltGlow"
		glow.Size = UDim2.new(1, 16, 1, 16)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxassetid://6031265976"
		glow.ImageColor3 = Color3.fromRGB(255, 200, 50)
		glow.ImageTransparency = 0.7
		glow.ZIndex = 0
		glow.Parent = frame
	end

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.Size = UDim2.fromOffset(20, 16)
	keyLabel.Position = UDim2.fromOffset(4, 2)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = if isUlt then 13 else 11
	keyLabel.TextColor3 = if isUlt then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(200, 200, 220)
	keyLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	keyLabel.TextStrokeTransparency = 0.5
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Text = slotKey
	keyLabel.ZIndex = 3
	keyLabel.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "SkillName"
	nameLabel.Size = UDim2.new(1, -4, 0, 14)
	nameLabel.Position = UDim2.new(0, 2, 1, -16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 8
	nameLabel.TextColor3 = if isUlt then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(180, 180, 200)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = ""
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 3
	nameLabel.Parent = frame

	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name = "CooldownOverlay"
	cdOverlay.Size = UDim2.fromScale(1, 0)
	cdOverlay.Position = UDim2.fromScale(0, 1)
	cdOverlay.AnchorPoint = Vector2.new(0, 1)
	cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 0.4
	cdOverlay.BorderSizePixel = 0
	cdOverlay.ZIndex = 2
	cdOverlay.Parent = frame

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0, 8)
	cdCorner.Parent = cdOverlay

	local cdText = Instance.new("TextLabel")
	cdText.Name = "CooldownText"
	cdText.Size = UDim2.fromScale(1, 1)
	cdText.BackgroundTransparency = 1
	cdText.Font = Enum.Font.GothamBold
	cdText.TextSize = 18
	cdText.TextColor3 = Color3.fromRGB(255, 255, 255)
	cdText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	cdText.TextStrokeTransparency = 0.3
	cdText.Text = ""
	cdText.ZIndex = 4
	cdText.Visible = false
	cdText.Parent = frame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 28)
	iconLabel.Position = UDim2.fromOffset(0, 12)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = if isUlt then 26 else 22
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.Text = ""
	iconLabel.ZIndex = 3
	iconLabel.Parent = frame

	return {
		Frame = frame,
		KeyLabel = keyLabel,
		NameLabel = nameLabel,
		CdOverlay = cdOverlay,
		CdText = cdText,
		IconLabel = iconLabel,
		Stroke = stroke,
	}
end

for _, slot in {"Q", "E", "R", "F", "V", "Y"} do
	skillSlotFrames[slot] = createSkillSlotUI(slot)
end

local SLOT_ICONS = {
	Q = "🌊",
	E = "💧",
	R = "🌀",
	F = "⚔️",
	V = "⭐",
	Y = "🐉",
}

updateSkillBarUI = function()
	for slot, ui in skillSlotFrames do
		local isUlt = slot == ULTIMATE_SLOT
		local skill = skillSlots[slot]
		if skill then
			ui.NameLabel.Text = skill.Name
			ui.IconLabel.Text = skill.Icon or SLOT_ICONS[slot] or "✦"
			ui.Frame.BackgroundTransparency = 0.2
			local color = SKILL_VFX_COLORS[skill.Id] or Color3.fromRGB(120, 120, 180)
			ui.Stroke.Color = if isUlt then Color3.fromRGB(255, 200, 50) else color
			ui.Stroke.Thickness = if isUlt then 2.5 else 1.5
		else
			ui.NameLabel.Text = "Locked"
			ui.IconLabel.Text = "🔒"
			ui.Frame.BackgroundTransparency = 0.5
			ui.Stroke.Color = if isUlt then Color3.fromRGB(130, 100, 25) else Color3.fromRGB(40, 40, 50)
			ui.Stroke.Thickness = if isUlt then 2.5 else 1.5
		end
	end
end

local VFXAssets = ReplicatedStorage:WaitForChild("VFXAssets")
local AnimeParticles = VFXAssets:WaitForChild("AnimeParticles"):WaitForChild("Anime")
local DSKit = VFXAssets:WaitForChild("DemonSlayerKit")
local BigEffects = VFXAssets:WaitForChild("BigEffects"):WaitForChild("Big")
local TanjiroSlash = VFXAssets:WaitForChild("TanjiroWaterSlash"):WaitForChild("Slash")

local function prepMesh(mesh, col, trans, size, cf)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = false
	mesh.Color = col
	mesh.Material = Enum.Material.Neon
	mesh.Transparency = trans or 0
	if size then
		mesh.Size = size
	end
	if cf then
		mesh.CFrame = cf
	end
	mesh.Parent = workspace
end

local function spawnDSKitPart(name, cf, size, color, transparency, duration)
	local source = DSKit:FindFirstChild(name)
	if not source then return nil end
	local clone = source:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = false
	if color then
		clone.Color = color
	end
	clone.Transparency = transparency or 0
	if size then
		clone.Size = size
	end
	clone.CFrame = cf
	clone.Parent = workspace
	if duration then
		Debris:AddItem(clone, duration)
	end
	return clone
end

local function spawnTanjiroSlash(cf, size, color, transparency, duration)
	local clone = TanjiroSlash:Clone()
	for _, mp in clone:GetChildren() do
		if mp:IsA("MeshPart") then
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
			mp.CastShadow = false
			if color then
				mp.Color = color
			end
			mp.Material = Enum.Material.Neon
			mp.Transparency = transparency or 0
		end
	end
	clone:PivotTo(cf)
	if size then
		local scale = size / clone:GetExtentsSize()
		clone:ScaleTo(math.max(scale.X, scale.Y, scale.Z))
	end
	clone.Parent = workspace
	if duration then
		Debris:AddItem(clone, duration)
	end
	return clone
end

local function _spawnBigEffect(name, cf, color, duration)
	local source = BigEffects:FindFirstChild(name)
	if not source then return nil end
	local clone = source:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = false
	if color then
		clone.Color = color
	end
	clone.CFrame = cf
	clone.Parent = workspace
	local att = clone:FindFirstChildWhichIsA("Attachment", true)
	if att then
		for _, pe in att:GetChildren() do
			if pe:IsA("ParticleEmitter") and color then
				pe.Color = ColorSequence.new(color, Color3.fromRGB(180, 230, 255))
			end
		end
	end
	if duration then
		task.delay(duration * 0.6, function()
			if att then
				for _, pe in att:GetChildren() do
					if pe:IsA("ParticleEmitter") then
						pe.Enabled = false
					end
				end
			end
		end)
		Debris:AddItem(clone, duration)
	end
	return clone
end

local function makeInvisPart(name, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(1, 1, 1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = cf
	p.Parent = workspace
	return p
end

local function cloneParticleSet(sourceName, parentPart, duration, colorOverride)
	local source = AnimeParticles:FindFirstChild(sourceName)
	if not source then return end
	local mainAtt = source:FindFirstChild("Main")
	if not mainAtt then return end
	local att = Instance.new("Attachment")
	att.Parent = parentPart
	local emitters = {}
	for _, child in mainAtt:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local pe = child:Clone()
			if colorOverride then
				pe.Color = ColorSequence.new(colorOverride, Color3.fromRGB(200, 230, 255))
			end
			pe.Parent = att
			table.insert(emitters, pe)
		end
	end
	if duration then
		task.delay(duration, function()
			for _, em in emitters do
				em.Enabled = false
			end
		end)
	end
	Debris:AddItem(att, (duration or 0.5) + 1.5)
	return att, emitters
end

local function cloneSubParticles(sourceName, childName, parentPart, duration, colorOverride)
	local source = AnimeParticles:FindFirstChild(sourceName)
	if not source then return end
	local sub = source:FindFirstChild(childName)
	if not sub then return end
	local att = Instance.new("Attachment")
	att.Parent = parentPart
	local emitters = {}
	for _, child in sub:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local pe = child:Clone()
			if colorOverride then
				pe.Color = ColorSequence.new(colorOverride, Color3.fromRGB(200, 230, 255))
			end
			pe.Parent = att
			table.insert(emitters, pe)
		end
	end
	if duration then
		task.delay(duration, function()
			for _, em in emitters do
				em.Enabled = false
			end
		end)
	end
	Debris:AddItem(att, (duration or 0.5) + 1.5)
	return att, emitters
end

local function addWaterParticles(parent, color, rate, lifetime, speed, spread)
	local att = Instance.new("Attachment")
	att.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color, Color3.fromRGB(180, 220, 255))
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	pe.Rate = rate
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(spread, spread)
	pe.LightEmission = 0.4
	pe.LightInfluence = 0.6
	pe.Drag = 2
	pe.Parent = att
	return att, pe
end

local function spawnGroundRing(hrp, color, duration)
	local ring = Instance.new("Part")
	ring.Name = "SkillRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 3, 3)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.CastShadow = false
	ring.CFrame = hrp.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 16, 16),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, (duration or 0.4) + 0.1)
end

local function spawnScreenFlash(duration, col)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local flash = Instance.new("Part")
	flash.Name = "ScreenFlash"
	flash.Size = Vector3.new(200, 200, 0.1)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = col or Color3.fromRGB(180, 220, 255)
	flash.Transparency = 0.6
	flash.CastShadow = false
	flash.CFrame = camera.CFrame * CFrame.new(0, 0, -3)
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, (duration or 0.2) + 0.05)
end

local function heavyCameraShake(intensity, count, interval)
	local camera = workspace.CurrentCamera
	if not camera then return end
	task.spawn(function()
		for i = 1, (count or 5) do
			local power = (intensity or 0.6) * (1 - (i - 1) / (count or 5))
			local offset = Vector3.new(
				(math.random() - 0.5) * 2 * power,
				(math.random() - 0.5) * 2 * power,
				0
			)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait(interval or 0.03)
		end
	end)
end

local function vfxWaterSurfaceSlash(hrp)
	local color = Color3.fromRGB(20, 120, 255)
	local colorLight = Color3.fromRGB(80, 190, 255)
	local colorWhite = Color3.fromRGB(180, 225, 255)
	local colorDeep = Color3.fromRGB(5, 60, 180)

	spawnScreenFlash(0.1, colorWhite)

	local mainSlash = VFXAssets:FindFirstChild("SlashSkill"):Clone()
	prepMesh(mainSlash, color, 0, Vector3.new(1.5, 0.8, 5), hrp.CFrame * CFrame.new(0, 0.3, -2))
	TweenService:Create(mainSlash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(10, 4, 34),
		CFrame = hrp.CFrame * CFrame.new(0, 0, -13),
		Transparency = 1,
	}):Play()
	Debris:AddItem(mainSlash, 0.55)
	cloneParticleSet("Water-01", mainSlash, 0.35, color)
	cloneParticleSet("Slash-01", mainSlash, 0.3, colorLight)

	local waterTrail = spawnDSKitPart("Water trail", hrp.CFrame * CFrame.new(0, 0, -3), Vector3.new(3, 1, 8), color, 0, 0.7)
	if waterTrail then
		TweenService:Create(waterTrail, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(6, 3, 30),
			CFrame = hrp.CFrame * CFrame.new(0, 0, -14),
			Transparency = 1,
		}):Play()
	end

	task.delay(0.02, function()
		if not hrp or not hrp.Parent then return end
		local hSlash = spawnDSKitPart("Horizontel Slash", hrp.CFrame * CFrame.new(0, 0.5, -4), Vector3.new(8, 3, 3), colorLight, 0.05, 0.5)
		if hSlash then
			TweenService:Create(hSlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(16, 5, 8),
				CFrame = hrp.CFrame * CFrame.new(0, 0, -10),
				Transparency = 1,
			}):Play()
		end
	end)

	task.delay(0.04, function()
		if not hrp or not hrp.Parent then return end
		for i = 1, 2 do
			local slashFx = VFXAssets:FindFirstChild("SlashEffect"):Clone()
			local ang = math.rad(15 * (i == 1 and 1 or -1))
			prepMesh(slashFx, colorLight, 0.05, Vector3.new(5, 0.4, 2), hrp.CFrame * CFrame.new(0, 0.3 + (i - 1) * 0.6, -4) * CFrame.Angles(0, 0, ang))
			TweenService:Create(slashFx, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(14, 1.2, 6),
				CFrame = hrp.CFrame * CFrame.new(0, 0.3 + (i - 1) * 0.6, -10) * CFrame.Angles(0, 0, ang),
				Transparency = 1,
			}):Play()
			Debris:AddItem(slashFx, 0.4)
		end
	end)

	task.delay(0.05, function()
		if not hrp or not hrp.Parent then return end
		local waterFx = spawnDSKitPart("Water effect", hrp.CFrame * CFrame.new(0, -1, -6), Vector3.new(4, 3, 4), colorLight, 0.1, 0.65)
		if waterFx then
			TweenService:Create(waterFx, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(9, 5, 9),
				CFrame = hrp.CFrame * CFrame.new(0, 0, -10) * CFrame.Angles(0, math.rad(90), 0),
				Transparency = 1,
			}):Play()
		end

		local wave = VFXAssets:FindFirstChild("Wave"):Clone()
		prepMesh(wave, color, 0.05, Vector3.new(2, 2, 2), hrp.CFrame * CFrame.new(0, -1, -5))
		TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(9, 5, 9),
			CFrame = hrp.CFrame * CFrame.new(0, 0, -10) * CFrame.Angles(0, math.rad(120), 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(wave, 0.6)
		local _, wpe = addWaterParticles(wave, color, 120, 0.5, 16, 30)
		task.delay(0.3, function()
			wpe.Enabled = false
		end)
	end)

	task.delay(0.06, function()
		if not hrp or not hrp.Parent then return end
		local mist = spawnDSKitPart("Mist", hrp.CFrame * CFrame.new(0, -1.5, -8), Vector3.new(6, 2, 12), colorWhite, 0.3, 0.8)
		if mist then
			TweenService:Create(mist, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(16, 4, 30),
				CFrame = hrp.CFrame * CFrame.new(0, -1, -18),
				Transparency = 1,
			}):Play()
		end
	end)

	task.delay(0.08, function()
		if not hrp or not hrp.Parent then return end
		local sw = VFXAssets:FindFirstChild("Shockwave"):Clone()
		prepMesh(sw, colorDeep, 0.15, Vector3.new(3, 1, 3), hrp.CFrame * CFrame.new(0, -2.5, -4))
		TweenService:Create(sw, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(22, 2.5, 22),
			Transparency = 1,
		}):Play()
		Debris:AddItem(sw, 0.6)
	end)

	task.delay(0.1, function()
		if not hrp or not hrp.Parent then return end
		local impactPart = makeInvisPart("SlashImpact", hrp.CFrame * CFrame.new(0, 0, -10))
		cloneParticleSet("Splash-01", impactPart, 0.25, color)
		cloneParticleSet("Water-02", impactPart, 0.3, colorLight)
		cloneParticleSet("Shiny-01", impactPart, 0.2, colorWhite)
		local _, spe = addWaterParticles(impactPart, color, 180, 0.5, 22, 45)
		task.delay(0.2, function()
			spe.Enabled = false
		end)
		Debris:AddItem(impactPart, 1.8)

		spawnTanjiroSlash(hrp.CFrame * CFrame.new(0, 0, -12), Vector3.new(10, 6, 10), color, 0.1, 0.5)
	end)

	heavyCameraShake(0.55, 5, 0.025)
	spawnGroundRing(hrp, color, 0.5)
	task.delay(0.06, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, colorDeep, 0.4)
		end
	end)
end

local function vfxWaterWheel(hrp)
	local color = Color3.fromRGB(30, 150, 255)
	local colorLight = Color3.fromRGB(90, 200, 255)
	local colorWhite = Color3.fromRGB(185, 230, 255)
	local colorDeep = Color3.fromRGB(5, 70, 200)

	spawnScreenFlash(0.12, colorWhite)

	local twirl = spawnDSKitPart("good twirl", hrp.CFrame, Vector3.new(4, 4, 4), color, 0, 0.9)
	if twirl then
		TweenService:Create(twirl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(14, 14, 14),
			CFrame = hrp.CFrame * CFrame.Angles(math.rad(720), 0, math.rad(360)),
			Transparency = 1,
		}):Play()
	end

	local whirl = VFXAssets:FindFirstChild("Whirl"):Clone()
	prepMesh(whirl, colorDeep, 0, Vector3.new(3, 3, 3), hrp.CFrame)
	TweenService:Create(whirl, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(13, 13, 13),
		CFrame = hrp.CFrame * CFrame.Angles(math.rad(540), 0, math.rad(270)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(whirl, 0.95)
	cloneParticleSet("Water-02", whirl, 0.6, color)
	cloneParticleSet("Water-01", whirl, 0.55, colorLight)

	task.delay(0.03, function()
		if not hrp or not hrp.Parent then return end
		local spiral = VFXAssets:FindFirstChild("Spiral"):Clone()
		prepMesh(spiral, colorLight, 0.05, Vector3.new(4, 4, 4), hrp.CFrame * CFrame.new(0, -2, 0))
		TweenService:Create(spiral, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(14, 11, 14),
			CFrame = hrp.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(720), 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(spiral, 0.9)
	end)

	for i = 1, 6 do
		task.delay((i - 1) * 0.08, function()
			if not hrp or not hrp.Parent then return end
			local angle = math.rad((i - 1) * 60)
			local radius = 5
			local y = math.sin(angle) * radius
			local z = math.cos(angle) * radius
			local arcCF = hrp.CFrame * CFrame.new(0, y, z)

			local wave = VFXAssets:FindFirstChild("Wave"):Clone()
			prepMesh(wave, color, 0.05, Vector3.new(2.5, 3, 2.5), arcCF)
			TweenService:Create(wave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(10, 8, 10),
				CFrame = arcCF * CFrame.Angles(math.rad(i * 45), math.rad(90), 0),
				Transparency = 1,
			}):Play()
			Debris:AddItem(wave, 0.55)

			local slashFx = VFXAssets:FindFirstChild("SlashEffect"):Clone()
			local slashAng = math.rad(i * 60)
			prepMesh(slashFx, colorLight, 0.05, Vector3.new(7, 0.4, 3), arcCF * CFrame.Angles(slashAng, 0, 0))
			TweenService:Create(slashFx, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(16, 1.2, 7),
				Transparency = 1,
			}):Play()
			Debris:AddItem(slashFx, 0.4)

			local segPart = makeInvisPart("WheelSeg" .. i, arcCF)
			cloneParticleSet("Water-01", segPart, 0.2, color)
			local _, spe = addWaterParticles(segPart, colorLight, 100, 0.4, 14, 35)
			task.delay(0.2, function()
				spe.Enabled = false
			end)
			Debris:AddItem(segPart, 1.5)

			heavyCameraShake(0.2, 2, 0.02)
		end)
	end

	task.delay(0.1, function()
		if not hrp or not hrp.Parent then return end
		local tornado = VFXAssets:FindFirstChild("Tornado"):Clone()
		prepMesh(tornado, color, 0.05, Vector3.new(4, 5, 4), hrp.CFrame * CFrame.new(0, -2, 0))
		TweenService:Create(tornado, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(14, 18, 14),
			CFrame = hrp.CFrame * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(720), 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(tornado, 0.8)
		cloneParticleSet("Splash-01", tornado, 0.4, color)
	end)

	task.delay(0.15, function()
		if not hrp or not hrp.Parent then return end
		local waterFx = spawnDSKitPart("Water effect", hrp.CFrame * CFrame.new(0, 0, 0), Vector3.new(5, 5, 5), colorLight, 0.1, 0.7)
		if waterFx then
			TweenService:Create(waterFx, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(16, 12, 16),
				CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(360), 0),
				Transparency = 1,
			}):Play()
		end
	end)

	task.delay(0.2, function()
		if not hrp or not hrp.Parent then return end
		local ws = VFXAssets:FindFirstChild("WindSphere"):Clone()
		prepMesh(ws, colorWhite, 0.2, Vector3.new(3, 3, 3), hrp.CFrame)
		TweenService:Create(ws, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(20, 20, 20),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ws, 0.7)
	end)

	task.delay(0.25, function()
		if not hrp or not hrp.Parent then return end
		local mistTwirl = spawnDSKitPart("Mist twirl", hrp.CFrame * CFrame.new(0, -1, 0), Vector3.new(6, 4, 6), colorWhite, 0.2, 0.8)
		if mistTwirl then
			TweenService:Create(mistTwirl, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(18, 10, 18),
				CFrame = hrp.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(540), 0),
				Transparency = 1,
			}):Play()
		end

		local sw = VFXAssets:FindFirstChild("Shockwave"):Clone()
		prepMesh(sw, colorDeep, 0.15, Vector3.new(5, 1.5, 5), hrp.CFrame * CFrame.new(0, -2.5, 0))
		TweenService:Create(sw, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(26, 3, 26),
			Transparency = 1,
		}):Play()
		Debris:AddItem(sw, 0.7)
	end)

	local vortexCenter = makeInvisPart("VortexCenter", hrp.CFrame)
	cloneParticleSet("Water-02", vortexCenter, 0.6, color)
	cloneParticleSet("Charge-01", vortexCenter, 0.5, colorLight)
	cloneParticleSet("Shiny-01", vortexCenter, 0.6, colorWhite)
	local _, mpe = addWaterParticles(vortexCenter, colorWhite, 120, 0.8, 8, 180)
	task.delay(0.6, function()
		mpe.Enabled = false
	end)
	Debris:AddItem(vortexCenter, 2.5)

	heavyCameraShake(0.7, 7, 0.03)
	spawnGroundRing(hrp, color, 0.7)
	task.delay(0.1, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, colorDeep, 0.5)
		end
	end)
end

local function vfxFlowingDance(hrp)
	local color = Color3.fromRGB(40, 170, 255)
	local colorLight = Color3.fromRGB(100, 210, 255)
	local colorWhite = Color3.fromRGB(190, 235, 255)
	local colorDeep = Color3.fromRGB(10, 80, 210)
	local multiHitDelay = 0.16
	local directions = {-1, 1, -1, 1, 0}
	local slashAngles = {25, -30, 45, -40, 0}
	local yOffsets = {0.5, -0.3, 0.8, -0.5, 0}

	for i = 1, 5 do
		task.delay((i - 1) * multiHitDelay, function()
			if not hrp or not hrp.Parent then return end
			local dir = directions[i] or 0
			local sideOffset = dir * 4
			local fwdOffset = -3.5 - (i * 2)
			local startCF = hrp.CFrame * CFrame.new(sideOffset, yOffsets[i] or 0, fwdOffset)

			local sideSlash = spawnDSKitPart("Side slash", startCF * CFrame.Angles(0, math.rad(dir * 30), math.rad(slashAngles[i] or 0)), Vector3.new(6, 4, 3), colorLight, 0, 0.45)
			if sideSlash then
				TweenService:Create(sideSlash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(18, 10, 8),
					CFrame = startCF * CFrame.new(dir * 3, 1, -3) * CFrame.Angles(0, math.rad(dir * 50), math.rad(slashAngles[i] or 0)),
					Transparency = 1,
				}):Play()
			end

			local wave = VFXAssets:FindFirstChild("Wave"):Clone()
			prepMesh(wave, color, 0.03, Vector3.new(2, 2.5, 2), startCF)
			TweenService:Create(wave, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(10, 7, 10),
				CFrame = startCF * CFrame.new(dir * 3, 1.5, -3) * CFrame.Angles(0, math.rad(dir * 60), 0),
				Transparency = 1,
			}):Play()
			Debris:AddItem(wave, 0.5)

			local swirl = VFXAssets:FindFirstChild("Swirl"):Clone()
			prepMesh(swirl, colorLight, 0.08, Vector3.new(3, 1.5, 3), startCF * CFrame.new(0, -1, 0))
			TweenService:Create(swirl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(11, 5, 11),
				CFrame = startCF * CFrame.new(0, 0.5, -2) * CFrame.Angles(0, math.rad(240), 0),
				Transparency = 1,
			}):Play()
			Debris:AddItem(swirl, 0.5)

			local waterTrail = spawnDSKitPart("Water trail", startCF * CFrame.new(-dir * 2, 0, 1), Vector3.new(2, 1, 5), color, 0.1, 0.5)
			if waterTrail then
				TweenService:Create(waterTrail, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(6, 3, 14),
					CFrame = startCF * CFrame.new(dir * 2, 0.5, -4),
					Transparency = 1,
				}):Play()
			end

			local hitPart = makeInvisPart("DanceHit" .. i, startCF)
			cloneParticleSet("Slash-01", hitPart, 0.18, colorLight)
			cloneParticleSet("Water-01", hitPart, 0.2, color)
			local _, hpe = addWaterParticles(hitPart, color, 100, 0.45, 18, 35)
			task.delay(0.15, function()
				hpe.Enabled = false
			end)
			Debris:AddItem(hitPart, 1.5)

			if i == 2 or i == 4 then
				local mistFx = spawnDSKitPart("Mist", startCF * CFrame.new(0, -1, 0), Vector3.new(5, 2, 8), colorWhite, 0.3, 0.6)
				if mistFx then
					TweenService:Create(mistFx, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = Vector3.new(12, 4, 16),
						Transparency = 1,
					}):Play()
				end
			end

			if i == 3 or i == 5 then
				local intensePart = makeInvisPart("IntenseHit" .. i, startCF)
				cloneSubParticles("Slashes-01", "Main", intensePart, 0.22, colorLight)
				cloneSubParticles("Slashes-01", "Bottom", intensePart, 0.22, color)
				cloneParticleSet("Shiny-01", intensePart, 0.18, colorWhite)
				Debris:AddItem(intensePart, 2)
			end

			heavyCameraShake(0.25 + (i * 0.06), 2, 0.02)

			if i == 5 then
				task.delay(0.05, function()
					if not hrp or not hrp.Parent then return end
					local finalCF = hrp.CFrame * CFrame.new(0, 0, -10)

					spawnTanjiroSlash(finalCF, Vector3.new(12, 8, 12), color, 0.05, 0.6)

					local multiSlash = spawnDSKitPart("Multi slash", finalCF, Vector3.new(8, 8, 8), colorLight, 0, 0.55)
					if multiSlash then
						TweenService:Create(multiSlash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(22, 16, 22),
							Transparency = 1,
						}):Play()
					end

					local ws = VFXAssets:FindFirstChild("WindSphere"):Clone()
					prepMesh(ws, colorWhite, 0.15, Vector3.new(4, 4, 4), finalCF)
					TweenService:Create(ws, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = Vector3.new(22, 22, 22),
						Transparency = 1,
					}):Play()
					Debris:AddItem(ws, 0.65)

					local sw = VFXAssets:FindFirstChild("Shockwave"):Clone()
					prepMesh(sw, colorDeep, 0.1, Vector3.new(5, 1.5, 5), finalCF * CFrame.new(0, -2, 0))
					TweenService:Create(sw, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = Vector3.new(28, 4, 28),
						Transparency = 1,
					}):Play()
					Debris:AddItem(sw, 0.7)

					local waterFx = spawnDSKitPart("Water effect", finalCF, Vector3.new(6, 5, 6), color, 0.1, 0.65)
					if waterFx then
						TweenService:Create(waterFx, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(18, 12, 18),
							CFrame = finalCF * CFrame.Angles(0, math.rad(180), 0),
							Transparency = 1,
						}):Play()
					end

					local finalPart = makeInvisPart("DanceFinal", finalCF)
					cloneParticleSet("Splash-01", finalPart, 0.3, color)
					cloneParticleSet("Water-02", finalPart, 0.35, colorLight)
					cloneParticleSet("Water-01", finalPart, 0.3, colorDeep)
					local _, bpe = addWaterParticles(finalPart, colorWhite, 250, 0.6, 26, 55)
					task.delay(0.25, function()
						bpe.Enabled = false
					end)
					Debris:AddItem(finalPart, 2.2)

					spawnScreenFlash(0.2, colorWhite)
					heavyCameraShake(0.9, 7, 0.03)
					spawnGroundRing(hrp, colorDeep, 0.5)
				end)
			end
		end)
	end

	spawnGroundRing(hrp, color, 0.7)
end

local function vfxWaterfallBasin(hrp)
	local color = Color3.fromRGB(10, 80, 220)
	local colorLight = Color3.fromRGB(50, 155, 255)
	local colorWhite = Color3.fromRGB(175, 220, 255)
	local colorDeep = Color3.fromRGB(0, 40, 160)
	local impactCF = hrp.CFrame * CFrame.new(0, 0, -5)

	spawnScreenFlash(0.15, Color3.fromRGB(100, 180, 255))

	local mistUp = spawnDSKitPart("Mist upwards", hrp.CFrame * CFrame.new(0, -2, -5), Vector3.new(8, 4, 8), colorWhite, 0.2, 0.9)
	if mistUp then
		TweenService:Create(mistUp, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(20, 30, 20),
			CFrame = hrp.CFrame * CFrame.new(0, 10, -5),
			Transparency = 1,
		}):Play()
	end

	local pillar = VFXAssets:FindFirstChild("Tornado"):Clone()
	prepMesh(pillar, color, 0, Vector3.new(6, 3, 6), hrp.CFrame * CFrame.new(0, 12, -5))
	TweenService:Create(pillar, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(16, 35, 16),
		CFrame = hrp.CFrame * CFrame.new(0, -3, -5) * CFrame.Angles(0, math.rad(540), 0),
		Transparency = 0.4,
	}):Play()
	task.delay(0.45, function()
		if pillar and pillar.Parent then
			TweenService:Create(pillar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
		end
	end)
	Debris:AddItem(pillar, 0.85)
	cloneParticleSet("Water-01", pillar, 0.5, color)
	cloneParticleSet("Water-02", pillar, 0.5, colorLight)
	cloneParticleSet("Charge-01", pillar, 0.4, colorWhite)

	task.delay(0.04, function()
		if not hrp or not hrp.Parent then return end
		local downSlash = spawnDSKitPart("Downwards slash", hrp.CFrame * CFrame.new(0, 8, -5), Vector3.new(14, 14, 14), colorLight, 0, 0.7)
		if downSlash then
			TweenService:Create(downSlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = hrp.CFrame * CFrame.new(0, -3, -5),
				Size = Vector3.new(24, 24, 24),
			}):Play()
			task.delay(0.35, function()
				if downSlash and downSlash.Parent then
					TweenService:Create(downSlash, TweenInfo.new(0.25), {Transparency = 1}):Play()
				end
			end)
		end
	end)

	task.delay(0.06, function()
		if not hrp or not hrp.Parent then return end
		local waterTrail = spawnDSKitPart("Water trail", hrp.CFrame * CFrame.new(0, 6, -5), Vector3.new(4, 2, 4), color, 0, 0.65)
		if waterTrail then
			TweenService:Create(waterTrail, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(12, 28, 12),
				CFrame = hrp.CFrame * CFrame.new(0, -2, -5),
			}):Play()
			task.delay(0.4, function()
				if waterTrail and waterTrail.Parent then
					TweenService:Create(waterTrail, TweenInfo.new(0.2), {Transparency = 1}):Play()
				end
			end)
		end
	end)

	task.delay(0.1, function()
		if not hrp or not hrp.Parent then return end
		local wave1 = VFXAssets:FindFirstChild("Wave"):Clone()
		prepMesh(wave1, colorLight, 0.03, Vector3.new(4, 7, 4), impactCF * CFrame.new(0, -2, 0))
		TweenService:Create(wave1, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(22, 14, 22),
			CFrame = impactCF * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(180), 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(wave1, 0.7)
		local _, wpe = addWaterParticles(wave1, color, 220, 0.6, 20, 50)
		task.delay(0.4, function()
			wpe.Enabled = false
		end)
	end)

	task.delay(0.12, function()
		if not hrp or not hrp.Parent then return end
		local waterFx = spawnDSKitPart("Water effect", impactCF * CFrame.new(0, -2, 0), Vector3.new(6, 4, 6), color, 0.05, 0.7)
		if waterFx then
			TweenService:Create(waterFx, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(20, 14, 20),
				CFrame = impactCF * CFrame.Angles(0, math.rad(120), 0),
				Transparency = 1,
			}):Play()
		end
	end)

	task.delay(0.15, function()
		if not hrp or not hrp.Parent then return end
		local sw = VFXAssets:FindFirstChild("Shockwave"):Clone()
		prepMesh(sw, colorDeep, 0.1, Vector3.new(5, 2, 5), impactCF * CFrame.new(0, -2.5, 0))
		TweenService:Create(sw, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(35, 5, 35),
			Transparency = 1,
		}):Play()
		Debris:AddItem(sw, 0.75)

		local sw2 = VFXAssets:FindFirstChild("Shockwave"):Clone()
		prepMesh(sw2, colorLight, 0.2, Vector3.new(3, 1, 3), impactCF * CFrame.new(0, -2.5, 0))
		TweenService:Create(sw2, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(25, 3, 25),
			Transparency = 1,
		}):Play()
		Debris:AddItem(sw2, 0.6)
	end)

	task.delay(0.18, function()
		if not hrp or not hrp.Parent then return end
		local impactPart = makeInvisPart("WaterfallImpact", impactCF * CFrame.new(0, -2, 0))
		cloneParticleSet("Splash-01", impactPart, 0.4, color)
		cloneParticleSet("Water-01", impactPart, 0.4, colorLight)
		cloneParticleSet("Water-02", impactPart, 0.35, colorDeep)
		cloneParticleSet("Shiny-01", impactPart, 0.3, colorWhite)
		local _, spe = addWaterParticles(impactPart, colorWhite, 300, 0.7, 24, 65)
		task.delay(0.3, function()
			spe.Enabled = false
		end)
		Debris:AddItem(impactPart, 2.2)
	end)

	for i = 1, 4 do
		task.delay(i * 0.07, function()
			if not hrp or not hrp.Parent then return end
			local ring = Instance.new("Part")
			ring.Name = "WaterfallRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.Material = Enum.Material.Neon
			ring.Color = i <= 2 and colorLight or color
			ring.Transparency = 0.15
			ring.CastShadow = false
			ring.Size = Vector3.new(0.3, 4, 4)
			ring.CFrame = hrp.CFrame * CFrame.new(0, 8 - i * 3, -5) * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = workspace
			TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.1, 22 + i * 5, 22 + i * 5),
				Transparency = 1,
			}):Play()
			Debris:AddItem(ring, 0.6)
		end)
	end

	task.delay(0.22, function()
		if not hrp or not hrp.Parent then return end
		local ws = VFXAssets:FindFirstChild("WindSphere"):Clone()
		prepMesh(ws, colorWhite, 0.2, Vector3.new(5, 5, 5), impactCF)
		TweenService:Create(ws, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(26, 26, 26),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ws, 0.65)

		spawnTanjiroSlash(impactCF * CFrame.new(0, -1, 0), Vector3.new(14, 10, 14), color, 0.05, 0.6)

		local mistCloud = spawnDSKitPart("Mist cloud", impactCF * CFrame.new(0, -2, 0), Vector3.new(8, 3, 8), colorWhite, 0.3, 1.0)
		if mistCloud then
			TweenService:Create(mistCloud, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(28, 6, 28),
				Transparency = 1,
			}):Play()
		end
	end)

	heavyCameraShake(0.9, 9, 0.03)
	spawnGroundRing(hrp, color, 0.7)
	task.delay(0.12, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, colorDeep, 0.5)
		end
	end)
end

local function vfxConstantFlux(hrp)
	local color = Color3.fromRGB(0, 160, 255)
	local colorDeep = Color3.fromRGB(0, 50, 180)
	local colorLight = Color3.fromRGB(100, 215, 255)
	local colorWhite = Color3.fromRGB(200, 240, 255)
	local colorIce = Color3.fromRGB(160, 230, 255)

	local calmSphere = VFXAssets:FindFirstChild("WindSphere"):Clone()
	prepMesh(calmSphere, colorDeep, 0.3, Vector3.new(8, 8, 8), hrp.CFrame)
	TweenService:Create(calmSphere, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		Size = Vector3.new(3, 3, 3),
		Transparency = 0,
	}):Play()
	Debris:AddItem(calmSphere, 0.5)

	local calmCenter = makeInvisPart("CalmCenter", hrp.CFrame)
	cloneParticleSet("Charge-01", calmCenter, 0.3, colorIce)
	cloneParticleSet("Shiny-01", calmCenter, 0.4, colorWhite)
	Debris:AddItem(calmCenter, 2)

	task.delay(0.25, function()
		if not hrp or not hrp.Parent then return end

		if calmSphere and calmSphere.Parent then
			TweenService:Create(calmSphere, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(40, 40, 40),
				Transparency = 1,
			}):Play()
		end

		spawnScreenFlash(0.25, colorWhite)
		spawnScreenFlash(0.15, colorIce)

		local multiSlash = spawnDSKitPart("Multi slash", hrp.CFrame, Vector3.new(6, 6, 6), colorLight, 0, 0.7)
		if multiSlash then
			TweenService:Create(multiSlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(30, 24, 30),
				CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0),
				Transparency = 1,
			}):Play()
		end

		local crazyCut = spawnDSKitPart("Crazy cutting", hrp.CFrame, Vector3.new(5, 5, 5), color, 0, 0.65)
		if crazyCut then
			TweenService:Create(crazyCut, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(26, 20, 26),
				CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(-90), 0),
				Transparency = 1,
			}):Play()
		end
	end)

	for i = 1, 8 do
		task.delay(0.25 + (i - 1) * 0.07, function()
			if not hrp or not hrp.Parent then return end
			local angle = math.rad((i - 1) * 45)
			local dist = 5
			local slashCF = hrp.CFrame * CFrame.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

			local slashFx = VFXAssets:FindFirstChild("SlashEffect"):Clone()
			local slashAng = math.rad((i - 1) * 45)
			prepMesh(slashFx, colorLight, 0, Vector3.new(10, 0.5, 4), slashCF * CFrame.Angles(0, angle, slashAng))
			TweenService:Create(slashFx, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(24, 2, 10),
				CFrame = slashCF * CFrame.new(math.cos(angle) * 4, 0, math.sin(angle) * 4) * CFrame.Angles(0, angle, slashAng),
				Transparency = 1,
			}):Play()
			Debris:AddItem(slashFx, 0.4)

			local sideSlash = spawnDSKitPart("Side slash", slashCF * CFrame.Angles(0, angle, slashAng), Vector3.new(5, 3, 2), color, 0.05, 0.4)
			if sideSlash then
				TweenService:Create(sideSlash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(16, 8, 6),
					Transparency = 1,
				}):Play()
			end

			local hitPart = makeInvisPart("CalmHit" .. i, slashCF)
			cloneParticleSet("Slash-01", hitPart, 0.15, colorLight)
			cloneParticleSet("Water-01", hitPart, 0.2, color)
			local _, hpe = addWaterParticles(hitPart, color, 80, 0.4, 16, 40)
			task.delay(0.15, function()
				hpe.Enabled = false
			end)
			Debris:AddItem(hitPart, 1.5)

			heavyCameraShake(0.3, 2, 0.02)
		end)
	end

	task.delay(0.35, function()
		if not hrp or not hrp.Parent then return end
		local tornado = VFXAssets:FindFirstChild("Tornado"):Clone()
		prepMesh(tornado, color, 0, Vector3.new(7, 10, 7), hrp.CFrame * CFrame.new(0, -3, 0))
		TweenService:Create(tornado, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(24, 30, 24),
			CFrame = hrp.CFrame * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(1080), 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(tornado, 0.95)
		cloneParticleSet("Water-02", tornado, 0.6, color)
	end)

	task.delay(0.4, function()
		if not hrp or not hrp.Parent then return end
		local mistExpand = spawnDSKitPart("Mist expand", hrp.CFrame * CFrame.new(0, -1, 0), Vector3.new(6, 3, 6), colorWhite, 0.15, 0.8)
		if mistExpand then
			TweenService:Create(mistExpand, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(30, 8, 30),
				Transparency = 1,
			}):Play()
		end

		local whirl = VFXAssets:FindFirstChild("Whirl"):Clone()
		prepMesh(whirl, colorLight, 0.05, Vector3.new(6, 6, 6), hrp.CFrame)
		TweenService:Create(whirl, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(32, 32, 32),
			CFrame = hrp.CFrame * CFrame.Angles(math.rad(270), math.rad(540), 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(whirl, 0.85)
	end)

	for i = 1, 4 do
		task.delay(0.15 + i * 0.1, function()
			if not hrp or not hrp.Parent then return end
			local sw = VFXAssets:FindFirstChild("Shockwave"):Clone()
			prepMesh(sw, i <= 2 and colorLight or colorDeep, 0.1, Vector3.new(4, 1.5, 4), hrp.CFrame * CFrame.new(0, -2.5 + i * 0.5, 0))
			TweenService:Create(sw, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(30 + i * 6, 3.5, 30 + i * 6),
				Transparency = 1,
			}):Play()
			Debris:AddItem(sw, 0.75)
		end)
	end

	task.delay(0.55, function()
		if not hrp or not hrp.Parent then return end

		spawnTanjiroSlash(hrp.CFrame, Vector3.new(16, 12, 16), color, 0, 0.7)

		local waterFx = spawnDSKitPart("Water effect", hrp.CFrame, Vector3.new(8, 6, 8), color, 0.05, 0.7)
		if waterFx then
			TweenService:Create(waterFx, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(28, 18, 28),
				CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(360), 0),
				Transparency = 1,
			}):Play()
		end

		local finalPart = makeInvisPart("DeadCalmFinal", hrp.CFrame)
		cloneParticleSet("Splash-01", finalPart, 0.35, colorDeep)
		cloneParticleSet("Water-02", finalPart, 0.4, color)
		cloneParticleSet("Water-01", finalPart, 0.35, colorLight)
		cloneSubParticles("Slashes-01", "Main", finalPart, 0.3, colorLight)
		cloneSubParticles("Slashes-01", "Bottom", finalPart, 0.3, color)
		cloneParticleSet("Shiny-01", finalPart, 0.4, colorWhite)
		local _, fpe = addWaterParticles(finalPart, colorWhite, 450, 0.9, 32, 100)
		task.delay(0.35, function()
			fpe.Enabled = false
		end)
		Debris:AddItem(finalPart, 2.8)

		spawnScreenFlash(0.25, colorWhite)
		heavyCameraShake(1.2, 12, 0.025)
	end)

	spawnGroundRing(hrp, colorDeep, 0.9)
	task.delay(0.3, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, color, 0.7)
		end
	end)
	task.delay(0.55, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, colorLight, 0.5)
		end
	end)
end

local function vfxWaterDragon(hrp)
	local color = Color3.fromRGB(0, 90, 255)
	local colorLight = Color3.fromRGB(50, 170, 255)
	local colorWhite = Color3.fromRGB(180, 230, 255)
	local colorDeep = Color3.fromRGB(0, 40, 160)
	local colorIce = Color3.fromRGB(150, 225, 255)

	spawnScreenFlash(0.2, colorIce)

	local chargePart = makeInvisPart("DragonCharge", hrp.CFrame * CFrame.new(0, 0, -3))
	cloneParticleSet("Charge-01", chargePart, 0.35, colorLight)
	cloneParticleSet("Water-01", chargePart, 0.35, color)
	cloneParticleSet("Shiny-01", chargePart, 0.35, colorWhite)
	Debris:AddItem(chargePart, 2.5)

	local dragonModel = DSKit:FindFirstChild("Constant flux's dragon")
	if dragonModel then
		local dragon = dragonModel:Clone()
		for _, part in dragon:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Color = color
				part.Material = Enum.Material.Neon
				part.Transparency = 0.1
			end
		end
		if dragon:IsA("BasePart") then
			dragon.Anchored = true
			dragon.CanCollide = false
			dragon.CanQuery = false
			dragon.CanTouch = false
			dragon.CastShadow = false
			dragon.Color = color
			dragon.Material = Enum.Material.Neon
			dragon.Transparency = 0.1
		end
		dragon:PivotTo(hrp.CFrame * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.rad(180), 0))
		dragon.Parent = workspace

		local startScale = dragon:GetScale()
		dragon:ScaleTo(startScale * 0.3)

		task.spawn(function()
			local totalTime = 0.7
			local steps = 14
			for s = 1, steps do
				if not dragon or not dragon.Parent then break end
				local t = s / steps
				local zOff = -6 - (t * 50)
				local yOff = math.sin(t * math.pi * 3) * 4
				local xOff = math.cos(t * math.pi * 2.5) * 3
				local scale = startScale * (0.3 + t * 0.9)
				dragon:PivotTo(hrp.CFrame * CFrame.new(xOff, yOff, zOff) * CFrame.Angles(math.rad(xOff * 5), math.rad(180), math.rad(yOff * 3)))
				dragon:ScaleTo(scale)
				for _, part in dragon:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = t * 0.7
					end
				end
				if dragon:IsA("BasePart") then
					dragon.Transparency = t * 0.7
				end
				task.wait(totalTime / steps)
			end
			for _, part in dragon:GetDescendants() do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.3), {Transparency = 1}):Play()
				end
			end
			if dragon:IsA("BasePart") then
				TweenService:Create(dragon, TweenInfo.new(0.3), {Transparency = 1}):Play()
			end
		end)
		Debris:AddItem(dragon, 1.5)
	end

	local dragonSegments = 10
	local segmentDelay = 0.05
	for i = 1, dragonSegments do
		task.delay((i - 1) * segmentDelay, function()
			if not hrp or not hrp.Parent then return end
			local _t = i / dragonSegments
			local zOff = -4 - (i * 5.5)
			local yOff = math.sin(i * 0.7) * 3.5
			local xOff = math.cos(i * 1.1) * 3
			local segCF = hrp.CFrame * CFrame.new(xOff, yOff, zOff)

			local spiral = VFXAssets:FindFirstChild("Spiral"):Clone()
			prepMesh(spiral, colorLight, 0.03, Vector3.new(5, 5, 5), segCF)
			TweenService:Create(spiral, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(14 + i * 0.6, 12 + i * 0.6, 14 + i * 0.6),
				CFrame = segCF * CFrame.Angles(0, math.rad(540), math.rad(i * 36)),
				Transparency = 1,
			}):Play()
			Debris:AddItem(spiral, 0.65)

			local wave = VFXAssets:FindFirstChild("Wave"):Clone()
			prepMesh(wave, color, 0.03, Vector3.new(3.5, 5, 3.5), segCF)
			TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(12, 10, 12),
				CFrame = segCF * CFrame.Angles(math.rad(i * 25), math.rad(120), 0),
				Transparency = 1,
			}):Play()
			Debris:AddItem(wave, 0.6)

			if i % 3 == 0 then
				local twirl = spawnDSKitPart("good twirl", segCF, Vector3.new(4, 4, 4), colorLight, 0.05, 0.55)
				if twirl then
					TweenService:Create(twirl, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = Vector3.new(12, 12, 12),
						CFrame = segCF * CFrame.Angles(0, math.rad(360), math.rad(i * 30)),
						Transparency = 1,
					}):Play()
				end
			end

			local segPart = makeInvisPart("DragonSeg" .. i, segCF)
			cloneParticleSet("Water-02", segPart, 0.35, color)
			if i % 2 == 0 then
				cloneParticleSet("Water-01", segPart, 0.3, colorLight)
			end
			local _, spe = addWaterParticles(segPart, colorLight, 180, 0.55, 20, 40)
			task.delay(0.3, function()
				spe.Enabled = false
			end)
			Debris:AddItem(segPart, 2)

			if i == dragonSegments then
				task.delay(0.06, function()
					if not hrp or not hrp.Parent then return end
					local headCF = hrp.CFrame * CFrame.new(0, 0, -4 - dragonSegments * 5.5 - 5)

					spawnTanjiroSlash(headCF, Vector3.new(22, 16, 22), color, 0, 0.8)

					local multiSlash = spawnDSKitPart("Multi slash", headCF, Vector3.new(10, 10, 10), colorLight, 0, 0.65)
					if multiSlash then
						TweenService:Create(multiSlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(30, 24, 30),
							Transparency = 1,
						}):Play()
					end

					local ws = VFXAssets:FindFirstChild("WindSphere"):Clone()
					prepMesh(ws, colorWhite, 0.05, Vector3.new(6, 6, 6), headCF)
					TweenService:Create(ws, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = Vector3.new(36, 36, 36),
						Transparency = 1,
					}):Play()
					Debris:AddItem(ws, 0.75)

					local waterFx = spawnDSKitPart("Water effect", headCF, Vector3.new(8, 6, 8), color, 0.05, 0.7)
					if waterFx then
						TweenService:Create(waterFx, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(24, 18, 24),
							CFrame = headCF * CFrame.Angles(0, math.rad(180), 0),
							Transparency = 1,
						}):Play()
					end

					local impactPart = makeInvisPart("DragonImpact", headCF)
					cloneParticleSet("Splash-01", impactPart, 0.45, color)
					cloneParticleSet("Water-01", impactPart, 0.45, colorLight)
					cloneParticleSet("Water-02", impactPart, 0.4, colorDeep)
					cloneSubParticles("Slashes-01", "Main", impactPart, 0.35, colorLight)
					cloneSubParticles("Slashes-01", "Bottom", impactPart, 0.35, color)
					cloneParticleSet("Shiny-01", impactPart, 0.35, colorWhite)
					local _, ipe = addWaterParticles(impactPart, colorWhite, 400, 0.8, 30, 75)
					task.delay(0.35, function()
						ipe.Enabled = false
					end)
					Debris:AddItem(impactPart, 2.8)

					for j = 1, 2 do
						local sw = VFXAssets:FindFirstChild("Shockwave"):Clone()
						prepMesh(sw, j == 1 and colorDeep or colorLight, 0.1, Vector3.new(6, 2, 6), headCF * CFrame.new(0, -2 + j, 0))
						TweenService:Create(sw, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(38 + j * 4, 5, 38 + j * 4),
							Transparency = 1,
						}):Play()
						Debris:AddItem(sw, 0.8)
					end

					local mistCloud = spawnDSKitPart("Mist cloud", headCF * CFrame.new(0, -2, 0), Vector3.new(10, 4, 10), colorWhite, 0.2, 1.0)
					if mistCloud then
						TweenService:Create(mistCloud, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(35, 8, 35),
							Transparency = 1,
						}):Play()
					end

					spawnScreenFlash(0.25, colorWhite)
					spawnScreenFlash(0.15, colorIce)
					heavyCameraShake(1.2, 12, 0.025)
				end)
			end
		end)
	end

	local whirl = VFXAssets:FindFirstChild("Whirl"):Clone()
	prepMesh(whirl, color, 0.05, Vector3.new(5, 5, 5), hrp.CFrame * CFrame.new(0, 0, -8))
	TweenService:Create(whirl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(18, 12, 18),
		CFrame = hrp.CFrame * CFrame.new(0, 0, -25) * CFrame.Angles(math.rad(90), math.rad(1080), 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(whirl, 0.9)

	local mistPart = makeInvisPart("DragonMist", hrp.CFrame * CFrame.new(0, -1.5, -12))
	cloneParticleSet("Wind-01", mistPart, 0.6, colorLight)
	cloneParticleSet("Water-01", mistPart, 0.5, color)
	local _, mpe = addWaterParticles(mistPart, colorWhite, 150, 0.9, 10, 130)
	task.delay(0.6, function()
		mpe.Enabled = false
	end)
	Debris:AddItem(mistPart, 2.8)

	local trailMist = spawnDSKitPart("Mist", hrp.CFrame * CFrame.new(0, -2, -15), Vector3.new(10, 3, 30), colorWhite, 0.3, 1.2)
	if trailMist then
		TweenService:Create(trailMist, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(16, 5, 55),
			CFrame = hrp.CFrame * CFrame.new(0, -1, -25),
			Transparency = 1,
		}):Play()
	end

	heavyCameraShake(0.8, 8, 0.03)
	spawnGroundRing(hrp, color, 0.8)
	task.delay(0.15, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, colorDeep, 0.6)
		end
	end)
	task.delay(0.3, function()
		if hrp and hrp.Parent then
			spawnGroundRing(hrp, colorLight, 0.4)
		end
	end)
end

local function vfxFlameSlash(hrp, color, skill)
	local colorGlow = Color3.fromRGB(255, 200, 50)
	spawnScreenFlash(0.12, color)

	local chargePart = makeInvisPart("FlameCharge", hrp.CFrame * CFrame.new(0, 0, -2))
	cloneParticleSet("Charge-01", chargePart, 0.3, color)
	cloneParticleSet("Shiny-01", chargePart, 0.3, colorGlow)
	Debris:AddItem(chargePart, 1.5)

	local hitCount = skill.MultiHit or 1
	local delay = skill.MultiHitDelay or 0.12
	for i = 1, hitCount do
		task.delay((i - 1) * delay, function()
			if not hrp or not hrp.Parent then return end
			local angle = math.rad((i - 1) * (360 / hitCount))
			local zOff = -3 - (i * 1.5)

			local slash = Instance.new("Part")
			slash.Name = "FlameSlash"
			slash.Size = Vector3.new(0.15, 5, 5)
			slash.Anchored = true
			slash.CanCollide = false
			slash.CanQuery = false
			slash.CanTouch = false
			slash.CastShadow = false
			slash.Material = Enum.Material.Neon
			slash.Color = color
			slash.Transparency = 0.1
			slash.CFrame = hrp.CFrame * CFrame.new(0, 0, zOff) * CFrame.Angles(0, 0, angle)
			slash.Parent = workspace

			local light = Instance.new("PointLight")
			light.Color = colorGlow
			light.Range = 14
			light.Brightness = 1.8
			light.Parent = slash

			local emberAtt = Instance.new("Attachment")
			emberAtt.Parent = slash
			local embers = Instance.new("ParticleEmitter")
			embers.Color = ColorSequence.new(colorGlow, color)
			embers.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 0),
			})
			embers.Transparency = NumberSequence.new(0.05, 1)
			embers.Lifetime = NumberRange.new(0.18, 0.38)
			embers.Rate = 130
			embers.Speed = NumberRange.new(3, 8)
			embers.SpreadAngle = Vector2.new(35, 35)
			embers.LightEmission = 0.85
			embers.Parent = emberAtt

			TweenService:Create(slash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Size = Vector3.new(0.05, 8, 8),
			}):Play()
			TweenService:Create(light, TweenInfo.new(0.25), {Brightness = 0, Range = 4}):Play()
			task.delay(0.16, function()
				embers.Enabled = false
			end)
			Debris:AddItem(slash, 0.35)

			local embr = VFXAssets:FindFirstChild("Shockwave") and VFXAssets:FindFirstChild("Shockwave"):Clone()
			if embr then
				prepMesh(embr, colorGlow, 0.1, Vector3.new(3, 1, 3), hrp.CFrame * CFrame.new(0, -1, zOff))
				TweenService:Create(embr, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(10 + i * 2, 2, 10 + i * 2),
					Transparency = 1,
				}):Play()
				Debris:AddItem(embr, 0.45)
			end

			local impactPart = makeInvisPart("FlameImpact" .. i, hrp.CFrame * CFrame.new(0, 0, zOff))
			cloneParticleSet("Charge-01", impactPart, 0.25, color)
			cloneParticleSet("Shiny-01", impactPart, 0.18, colorGlow)
			Debris:AddItem(impactPart, 1.2)
		end)
	end

	spawnGroundRing(hrp, color, 0.5)
	heavyCameraShake(0.4, 6, 0.02)
end

local function vfxFlameEsoteric(hrp)
	local colorCore = Color3.fromRGB(255, 200, 30)
	local colorFlame = Color3.fromRGB(255, 80, 10)
	local colorWhite = Color3.fromRGB(255, 240, 200)

	spawnScreenFlash(0.3, colorCore)
	heavyCameraShake(1.0, 14, 0.03)

	local chargePart = makeInvisPart("FlameEsotericCharge", hrp.CFrame * CFrame.new(0, 0, -3))
	cloneParticleSet("Charge-01", chargePart, 0.6, colorFlame)
	cloneParticleSet("Charge-01", chargePart, 0.6, colorCore)
	cloneParticleSet("Shiny-01", chargePart, 0.5, colorWhite)
	Debris:AddItem(chargePart, 2.5)

	local ws = VFXAssets:FindFirstChild("WindSphere") and VFXAssets:FindFirstChild("WindSphere"):Clone()
	if ws then
		prepMesh(ws, colorCore, 0.05, Vector3.new(4, 4, 4), hrp.CFrame * CFrame.new(0, 0, -4))
		TweenService:Create(ws, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(40, 40, 40),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ws, 0.9)
	end

	local segments = 6
	for i = 1, segments do
		task.delay((i - 1) * 0.07, function()
			if not hrp or not hrp.Parent then return end
			local zOff = -4 - (i * 6)
			local yOff = math.sin(i * 0.8) * 3
			local xOff = math.cos(i * 1.2) * 2.5
			local segCF = hrp.CFrame * CFrame.new(xOff, yOff, zOff)

			local spiral = VFXAssets:FindFirstChild("Spiral") and VFXAssets:FindFirstChild("Spiral"):Clone()
			if spiral then
				prepMesh(spiral, colorFlame, 0.05, Vector3.new(4, 4, 4), segCF)
				TweenService:Create(spiral, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(16 + i * 0.5, 14 + i * 0.5, 16 + i * 0.5),
					CFrame = segCF * CFrame.Angles(0, math.rad(540), math.rad(i * 40)),
					Transparency = 1,
				}):Play()
				Debris:AddItem(spiral, 0.6)
			end

			local segPart = makeInvisPart("FlameEsotericSeg" .. i, segCF)
			cloneParticleSet("Charge-01", segPart, 0.3, colorFlame)
			if i % 2 == 0 then
				cloneParticleSet("Shiny-01", segPart, 0.25, colorCore)
			end
			Debris:AddItem(segPart, 1.8)

			if i == segments then
				task.delay(0.06, function()
					if not hrp or not hrp.Parent then return end
					local headCF = hrp.CFrame * CFrame.new(0, 0, -4 - segments * 6 - 4)

					spawnTanjiroSlash(headCF, Vector3.new(26, 20, 26), colorFlame, 0, 0.9)

					local sw1 = VFXAssets:FindFirstChild("Shockwave") and VFXAssets:FindFirstChild("Shockwave"):Clone()
					if sw1 then
						prepMesh(sw1, colorCore, 0.08, Vector3.new(8, 2, 8), headCF * CFrame.new(0, -2, 0))
						TweenService:Create(sw1, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(44, 6, 44),
							Transparency = 1,
						}):Play()
						Debris:AddItem(sw1, 0.85)
					end

					local impactPart = makeInvisPart("FlameEsotericImpact", headCF)
					cloneParticleSet("Charge-01", impactPart, 0.5, colorFlame)
					cloneParticleSet("Shiny-01", impactPart, 0.45, colorCore)
					cloneSubParticles("Slashes-01", "Main", impactPart, 0.4, colorFlame)
					cloneSubParticles("Slashes-01", "Bottom", impactPart, 0.4, colorCore)
					Debris:AddItem(impactPart, 2.8)

					spawnScreenFlash(0.2, colorWhite)
					heavyCameraShake(1.2, 16, 0.03)
					spawnGroundRing(hrp, colorFlame, 1.0)
					task.delay(0.2, function()
						if hrp and hrp.Parent then
							spawnGroundRing(hrp, colorCore, 0.7)
						end
					end)
				end)
			end
		end)
	end

	spawnGroundRing(hrp, colorFlame, 0.8)
end

local FLAME_SKILL_VFX = {
	FlameEsoteric = vfxFlameEsoteric,
}

local function spawnFlameVFX(hrp, skillId, skill)
	local handler = FLAME_SKILL_VFX[skillId]
	if handler then
		handler(hrp)
	else
		local color = SKILL_VFX_COLORS[skillId] or Color3.fromRGB(255, 100, 20)
		vfxFlameSlash(hrp, color, skill)
	end
end

-- ==================== TEMARI DEMON ARTS VFX ====================
local TEMARI_COLOR1 = Color3.fromRGB(200, 60, 220)
local TEMARI_COLOR2 = Color3.fromRGB(255, 100, 255)
local TEMARI_GLOW   = Color3.fromRGB(220, 120, 255)

local function vfxTemariBall(hrp, count, spread)
	count = count or 1
	spread = spread or 0
	spawnScreenFlash(0.08, TEMARI_COLOR1)
	for i = 1, count do
		task.spawn(function()
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.new(1.4, 1.4, 1.4)
			ball.Material = Enum.Material.Neon
			ball.Color = TEMARI_COLOR2
			ball.CastShadow = false
			ball.CanCollide = false
			ball.Anchored = true

			local angle = math.rad((i - 1) * (spread / math.max(count - 1, 1)) - spread / 2)
			local fwd = hrp.CFrame.LookVector
			local right = hrp.CFrame.RightVector
			local dir = (fwd * math.cos(angle) + right * math.sin(angle)).Unit
			ball.CFrame = CFrame.new(hrp.Position + dir * 2 + Vector3.new(0, 0.5, 0))
			ball.Parent = workspace

			local frontAtt = Instance.new("Attachment")
			frontAtt.Position = Vector3.new(0, 0, -0.7)
			frontAtt.Parent = ball
			local backAtt = Instance.new("Attachment")
			backAtt.Position = Vector3.new(0, 0, 0.7)
			backAtt.Parent = ball
			local trailFx = Instance.new("Trail")
			trailFx.Attachment0 = frontAtt
			trailFx.Attachment1 = backAtt
			trailFx.Color = ColorSequence.new(TEMARI_COLOR2, TEMARI_COLOR1)
			trailFx.Lifetime = 0.22
			trailFx.LightEmission = 0.75
			trailFx.Transparency = NumberSequence.new(0.12, 1)
			trailFx.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.1),
				NumberSequenceKeypoint.new(1, 0),
			})
			trailFx.Parent = ball

			local spark = Instance.new("ParticleEmitter")
			spark.Color = ColorSequence.new(TEMARI_GLOW, TEMARI_COLOR1)
			spark.Size = NumberSequence.new(0.18, 0)
			spark.Lifetime = NumberRange.new(0.16, 0.3)
			spark.Rate = 80
			spark.Speed = NumberRange.new(0.5, 2)
			spark.SpreadAngle = Vector2.new(180, 180)
			spark.LightEmission = 0.8
			spark.Parent = frontAtt

			local trail = Instance.new("SelectionBox")
			trail.Color3 = TEMARI_COLOR1
			trail.LineThickness = 0.04
			trail.Adornee = ball
			trail.Parent = workspace

			local steps = 16
			for s = 1, steps do
				if not ball.Parent then break end
				ball.CFrame = ball.CFrame + dir * (s * 0.18)
				ball.Size = Vector3.new(1.4 - s * 0.04, 1.4 - s * 0.04, 1.4 - s * 0.04)
				task.wait(0.03)
			end
			spark.Enabled = false
			trailFx.Enabled = false
			trail:Destroy()
			TweenService:Create(ball, TweenInfo.new(0.12), {Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)}):Play()
			Debris:AddItem(ball, 0.18)
		end)
		task.wait(0.06)
	end
end

local function vfxTemariExplosion(hrp)
	spawnScreenFlash(0.18, TEMARI_GLOW)
	for ring = 1, 3 do
		task.spawn(function()
			task.wait((ring - 1) * 0.08)
			local shockwave = Instance.new("Part")
			shockwave.Name = "TemariShockwave"
			shockwave.Shape = Enum.PartType.Ball
			shockwave.Size = Vector3.new(ring * 2, ring * 2, ring * 2)
			shockwave.Material = Enum.Material.Neon
			shockwave.Color = TEMARI_COLOR1
			shockwave.Transparency = 0.3
			shockwave.CanCollide = false
			shockwave.Anchored = true
			shockwave.CFrame = CFrame.new(hrp.Position)
			shockwave.Parent = workspace

			TweenService:Create(shockwave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(ring * 9, ring * 9, ring * 9),
				Transparency = 1,
			}):Play()
			Debris:AddItem(shockwave, 0.5)
		end)
	end
end

local function vfxTemariFullMoon(hrp)
	spawnScreenFlash(0.22, TEMARI_GLOW)
	local orbitRadius = 5
	local armCount = 6
	for arm = 1, armCount do
		task.spawn(function()
			task.wait((arm - 1) * 0.1)
			local angle = math.rad((arm - 1) * (360 / armCount))
			local offset = Vector3.new(math.cos(angle) * orbitRadius, 0.5, math.sin(angle) * orbitRadius)

			local orb = Instance.new("Part")
			orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.new(2, 2, 2)
			orb.Material = Enum.Material.Neon
			orb.Color = TEMARI_COLOR2
			orb.CanCollide = false
			orb.Anchored = true
			orb.CFrame = CFrame.new(hrp.Position + offset)
			orb.Parent = workspace

			local inner = Instance.new("Part")
			inner.Shape = Enum.PartType.Ball
			inner.Size = Vector3.new(0.8, 0.8, 0.8)
			inner.Material = Enum.Material.Neon
			inner.Color = Color3.new(1, 1, 1)
			inner.CanCollide = false
			inner.Anchored = true
			inner.CFrame = orb.CFrame
			inner.Parent = workspace

			for t = 1, 14 do
				if not orb.Parent then break end
				local a = angle + math.rad(t * 18)
				local pos = hrp.Position + Vector3.new(math.cos(a) * orbitRadius * (1 - t * 0.06), 0.5, math.sin(a) * orbitRadius * (1 - t * 0.06))
				orb.CFrame = CFrame.new(pos)
				inner.CFrame = orb.CFrame
				task.wait(0.04)
			end

			TweenService:Create(orb, TweenInfo.new(0.2), {Size = Vector3.new(5, 5, 5), Transparency = 1}):Play()
			inner:Destroy()
			Debris:AddItem(orb, 0.25)
		end)
	end
end

local TEMARI_SKILL_VFX = {
	BloodTemari   = function(hrp, _skill) vfxTemariExplosion(hrp) end,
	TemariFullMoon = function(hrp, _skill) vfxTemariFullMoon(hrp) end,
	DoubleTemari  = function(hrp, _skill) vfxTemariBall(hrp, 2, 40) end,
	TemariBarrage = function(hrp, _skill) vfxTemariBall(hrp, 5, 60) end,
}

local function spawnTemariVFX(hrp, skillId, _skill)
	local handler = TEMARI_SKILL_VFX[skillId]
	if handler then
		handler(hrp, _skill)
	else
		vfxTemariBall(hrp, 1, 0)
	end
end

local function spawnDemonVFXGeneric(hrp, _skillId, color, skill)
	if skill.MultiHit > 1 and skill.HitboxOffset > 0 then
		for i = 1, skill.MultiHit do
			task.delay((i - 1) * skill.MultiHitDelay, function()
				if not hrp or not hrp.Parent then return end
				local slash = Instance.new("Part")
				slash.Name = "SkillVFX"
				slash.Size = Vector3.new(0.2, 4, 4)
				slash.Anchored = true
				slash.CanCollide = false
				slash.CanQuery = false
				slash.CanTouch = false
				slash.Material = Enum.Material.Neon
				slash.Color = color
				slash.Transparency = 0.2
				slash.CastShadow = false
				local angle = math.rad((i - 1) * (360 / skill.MultiHit))
				slash.CFrame = hrp.CFrame * CFrame.new(0, 0, -skill.HitboxOffset) * CFrame.Angles(0, 0, angle)
				slash.Parent = workspace
				TweenService:Create(slash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
					Size = Vector3.new(0.05, 6, 6),
				}):Play()
				Debris:AddItem(slash, 0.3)
			end)
		end
	else
		local burst = Instance.new("Part")
		burst.Name = "SkillVFX"
		burst.Shape = Enum.PartType.Ball
		burst.Size = Vector3.new(2, 2, 2)
		burst.Anchored = true
		burst.CanCollide = false
		burst.CanQuery = false
		burst.CanTouch = false
		burst.Material = Enum.Material.Neon
		burst.Color = color
		burst.Transparency = 0.2
		burst.CastShadow = false
		burst.CFrame = hrp.CFrame * CFrame.new(0, 0, -skill.HitboxOffset)
		burst.Parent = workspace
		TweenService:Create(burst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = skill.HitboxSize * 1.5,
			Transparency = 1,
		}):Play()
		Debris:AddItem(burst, 0.4)
	end
	spawnGroundRing(hrp, color, 0.4)
end

local WATER_SKILL_VFX = {
	WaterSurfaceSlash = vfxWaterSurfaceSlash,
	WaterWheel = vfxWaterWheel,
	FlowingDance = vfxFlowingDance,
	WaterfallBasin = vfxWaterfallBasin,
	ConstantFlux = vfxConstantFlux,
	WaterDragon = vfxWaterDragon,
}

local function spawnSkillVFX(character, skillId)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local waterHandler = WATER_SKILL_VFX[skillId]
	if waterHandler then
		waterHandler(hrp)
		return
	end

	local skill = SkillSystemModule.getSkill(skillId)
	if not skill then return end

	if skill.Style == "FlameBreathing" then
		spawnFlameVFX(hrp, skillId, skill)
		return
	end

	if skill.Style == "TemariDemonArts" then
		spawnTemariVFX(hrp, skillId, skill)
		return
	end

	local color = SKILL_VFX_COLORS[skillId] or Color3.fromRGB(200, 200, 255)
	spawnDemonVFXGeneric(hrp, skillId, color, skill)
end

local function playSkillSound(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_get_up.mp3"
	sound.Volume = 0.5
	sound.PlaybackSpeed = 0.6
	sound.Parent = hrp
	sound:Play()
	Debris:AddItem(sound, 1.5)
end

local function skillCameraShake()
	local camera = workspace.CurrentCamera
	if not camera then return end
	task.spawn(function()
		for _ = 1, 4 do
			local intensity = 0.5
			local offset = Vector3.new(
				(math.random() - 0.5) * 2 * intensity,
				(math.random() - 0.5) * 2 * intensity,
				0
			)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait(0.025)
		end
	end)
end

local function useSkill(slot)
	if isUsingSkill or isAttacking or isBlocking then return end

	local skill = skillSlots[slot]
	if not skill then return end

	local expiry = skillCooldownExpiry[skill.Id]
	if expiry and os.clock() < expiry then return end

	local character = getCharacter()
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	isUsingSkill = true
	UseSkillRemote:FireServer(skill.Id)

	task.delay(0.5, function()
		isUsingSkill = false
	end)
	task.delay(2.0, function()
		isUsingSkill = false
	end)
end

SkillActivatedRemote.OnClientEvent:Connect(function(playerOrSkillId, skillIdOrCooldown)
	if typeof(playerOrSkillId) == "string" then
		local skillId = playerOrSkillId
		local cooldown = skillIdOrCooldown
		skillCooldownExpiry[skillId] = os.clock() + cooldown

		local character = getCharacter()
		if character then
			spawnSkillVFX(character, skillId)
			playSkillSound(character)
			skillCameraShake()
		end

		local skill = SkillSystemModule.getSkill(skillId)
		if skill then
			local ui = skillSlotFrames[skill.Slot]
			if ui then
				local color = SKILL_VFX_COLORS[skillId] or Color3.fromRGB(120, 120, 180)
				ui.Stroke.Color = Color3.fromRGB(255, 255, 255)
				TweenService:Create(ui.Stroke, TweenInfo.new(0.3), {Color = color}):Play()
			end
		end
	elseif typeof(playerOrSkillId) == "Instance" and playerOrSkillId:IsA("Player") then
		local otherPlayer = playerOrSkillId
		local skillId = skillIdOrCooldown
		if otherPlayer ~= LocalPlayer and otherPlayer.Character then
			spawnSkillVFX(otherPlayer.Character, skillId)
		end
	end
end)

FactionChosenRemote.OnClientEvent:Connect(function(faction)
	setFaction(faction)
	updateSkillBarUI()
end)

StyleChangedRemote.OnClientEvent:Connect(function(style)
	setStyle(style or "")
	updateSkillBarUI()
end)

InventoryChangedRemote.OnClientEvent:Connect(function(inventory, equippedStyle)
	_clientInventory = typeof(inventory) == "table" and inventory or {}
	if typeof(equippedStyle) == "string" and equippedStyle ~= "" and equippedStyle ~= _currentStyle then
		setStyle(equippedStyle)
		updateSkillBarUI()
	end
end)

task.spawn(function()
	local GetPlayerData = Remotes:FindFirstChild("GetPlayerData")
	if GetPlayerData then
		local ok, result = pcall(function()
			return GetPlayerData:InvokeServer()
		end)
		if ok and result and typeof(result) == "table" then
			if result.Faction and result.Faction ~= "" then
				_currentFaction = result.Faction
			end
			if result.Inventory then
				_clientInventory = result.Inventory
			end
			if result.Mastery then
				cacheMastery(result.Mastery)
			end
			local styleToUse = (result.EquippedStyle and result.EquippedStyle ~= "") and result.EquippedStyle or _currentFaction
			if styleToUse ~= "" then
				_currentStyle = result.EquippedStyle or ""
				buildSkillSlots(styleToUse)
				updateSkillBarUI()
			end
		end
	end
end)

-- ==================== COOLDOWN TICK ====================
task.spawn(function()
	while true do
		task.wait(0.1)
		for slot, ui in skillSlotFrames do
			local skill = skillSlots[slot]
			if skill then
				local expiry = skillCooldownExpiry[skill.Id]
				if expiry then
					local remaining = expiry - os.clock()
					if remaining > 0 then
						local ratio = remaining / skill.Cooldown
						ui.CdOverlay.Size = UDim2.fromScale(1, math.clamp(ratio, 0, 1))
						ui.CdText.Visible = true
						ui.CdText.Text = tostring(math.ceil(remaining))
					else
						ui.CdOverlay.Size = UDim2.fromScale(1, 0)
						ui.CdText.Visible = false
						skillCooldownExpiry[skill.Id] = nil
					end
				else
					ui.CdOverlay.Size = UDim2.fromScale(1, 0)
					ui.CdText.Visible = false
				end
			end
		end
	end
end)

-- ==================== BLOCK & PARRY ====================
local function createBlockShield(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if blockShieldPart and blockShieldPart.Parent then
		blockShieldPart:Destroy()
	end

	local shield = Instance.new("Part")
	shield.Name = "BlockShield"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(7, 7, 7)
	shield.Anchored = true
	shield.CanCollide = false
	shield.CanQuery = false
	shield.CanTouch = false
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(80, 160, 255)
	shield.Transparency = 0.75
	shield.CastShadow = false
	shield.CFrame = hrp.CFrame
	shield.Parent = workspace

	blockShieldPart = shield

	local pulseUp = TweenService:Create(shield, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.6,
		Size = Vector3.new(7.5, 7.5, 7.5),
	})
	pulseUp:Play()
	blockShieldTween = pulseUp

	task.spawn(function()
		while blockShieldPart and blockShieldPart.Parent and isBlocking do
			if hrp and hrp.Parent then
				blockShieldPart.CFrame = hrp.CFrame
			end
			task.wait()
		end
	end)
end

local function destroyBlockShield()
	if blockShieldTween then
		blockShieldTween:Cancel()
		blockShieldTween = nil
	end
	if blockShieldPart and blockShieldPart.Parent then
		TweenService:Create(blockShieldPart, TweenInfo.new(0.15), {
			Transparency = 1,
			Size = Vector3.new(9, 9, 9),
		}):Play()
		Debris:AddItem(blockShieldPart, 0.2)
		blockShieldPart = nil
	end
end

local function stopBlock()
	if not isBlocking then return end
	local holdDuration = os.clock() - blockPressTime

	if blockSafetyThread then
		task.cancel(blockSafetyThread)
		blockSafetyThread = nil
	end

	isBlocking = false
	destroyBlockShield()

	if holdDuration <= PARRY_TAP_THRESHOLD then
		ParryAttemptRemote:FireServer()
		BlockRemote:FireServer(false)
	else
		BlockRemote:FireServer(false)
	end
end

local function startBlock()
	if isBlocking then return end
	if isAttacking or isUsingSkill then return end

	local character = getCharacter()
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	isBlocking = true
	blockPressTime = os.clock()
	BlockRemote:FireServer(true)
	createBlockShield(character)

	if blockSafetyThread then
		task.cancel(blockSafetyThread)
	end
	blockSafetyThread = task.delay(MAX_BLOCK_DURATION, function()
		blockSafetyThread = nil
		if isBlocking then
			stopBlock()
		end
	end)
end

local function spawnParrySuccessVFX(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local flash = Instance.new("Part")
	flash.Name = "ParryFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(3, 3, 3)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 230, 100)
	flash.Transparency = 0
	flash.CastShadow = false
	flash.CFrame = hrp.CFrame
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(12, 12, 12),
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.3)

	local ring = Instance.new("Part")
	ring.Name = "ParryRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 4, 4)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 255, 200)
	ring.Transparency = 0.2
	ring.CastShadow = false
	ring.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 14, 14),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.35)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
	sound.Volume = 0.6
	sound.PlaybackSpeed = 1.4
	sound.Parent = hrp
	sound:Play()
	Debris:AddItem(sound, 1)
end

local function spawnGuardBreakVFX(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local flash = Instance.new("Part")
	flash.Name = "GuardBreakFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(5, 5, 5)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 50, 30)
	flash.Transparency = 0.2
	flash.CastShadow = false
	flash.CFrame = hrp.CFrame
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(10, 10, 10),
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.45)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.5
	sound.PlaybackSpeed = 0.6
	sound.Parent = hrp
	sound:Play()
	Debris:AddItem(sound, 1)
end

local function playWhiffSound(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_get_up.mp3"
	sound.Volume = 0.3
	sound.PlaybackSpeed = 0.4
	sound.Parent = hrp
	sound:Play()
	Debris:AddItem(sound, 1)
end

BlockParryVFXRemote.OnClientEvent:Connect(function(eventType, sourcePlayer, character, _attackerModel)
	if eventType == "parrySuccess" then
		if character and character.Parent then
			spawnParrySuccessVFX(character)
		end
	elseif eventType == "parryWhiff" then
		if sourcePlayer == LocalPlayer then
			local myChar = getCharacter()
			if myChar then
				playWhiffSound(myChar)
			end
		end
	elseif eventType == "guardBreak" then
		if character and character.Parent then
			spawnGuardBreakVFX(character)
			if sourcePlayer == LocalPlayer then
				isBlocking = false
				destroyBlockShield()
			end
		end
	end
end)

-- ==================== INPUT ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonX then
		performLightAttack()
	elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonL1 then
		startBlock()
	elseif SLOT_KEYS[input.KeyCode] then
		useSkill(SLOT_KEYS[input.KeyCode])
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonL1 then
		if isBlocking then
			stopBlock()
		else
			isBlocking = false
			destroyBlockShield()
			if blockSafetyThread then
				task.cancel(blockSafetyThread)
				blockSafetyThread = nil
			end
		end
	end
end)

local function onCharacterAdded()
	comboIndex = 0
	lastAttackTime = 0
	isAttacking = false
	isUsingSkill = false
	isBlocking = false
	if blockSafetyThread then
		task.cancel(blockSafetyThread)
		blockSafetyThread = nil
	end
	destroyBlockShield()
	task.defer(cacheAnimations)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

updateSkillBarUI()

local InputModeValue = ReplicatedStorage:WaitForChild("InputMode")

local XBOX_SLOT_LABELS = {
	Q = "RB",
	E = "RT",
	R = "LT",
	F = "Y",
	V = "B",
	Y = "D↑",
}

local PS_SLOT_LABELS = {
	Q = "R1",
	E = "R2",
	R = "L2",
	F = "△",
	V = "○",
	Y = "D↑",
}

local KEYBOARD_SLOT_LABELS = {
	Q = "Q",
	E = "E",
	R = "R",
	F = "F",
	V = "V",
	Y = "Y",
}

local function updateSkillBarPrompts()
	local mode = InputModeValue.Value
	local labels
	if mode == "Xbox" then
		labels = XBOX_SLOT_LABELS
	elseif mode == "PlayStation" then
		labels = PS_SLOT_LABELS
	else
		labels = KEYBOARD_SLOT_LABELS
	end
	for slot, ui in skillSlotFrames do
		ui.KeyLabel.Text = labels[slot] or slot
	end
end

InputModeValue.Changed:Connect(function()
	updateSkillBarPrompts()
end)

updateSkillBarPrompts()

-- ==================== MASTERY STATE (bar moved to HUDController) ====================
local currentMasteryStyleId = ""

local function getActiveStyleId()
	local qSkill = skillSlots["Q"]
	if qSkill then
		return qSkill.Style or _currentStyle
	end
	return _currentStyle
end

local function getStyleDisplayName(styleId)
	if styleId == "WaterBreathing" then
		return "Water Breathing"
	elseif styleId == "FlameBreathing" then
		return "Flame Breathing"
	elseif styleId == "DemonArts" then
		return "Blood Demon Art"
	elseif styleId == "TemariDemonArts" then
		return "Temari Demon Art"
	end
	return styleId
end

-- ==================== MILESTONE TOAST ====================
local milestoneToast = Instance.new("Frame")
milestoneToast.Name = "MilestoneToast"
milestoneToast.Size = UDim2.fromOffset(340, 46)
milestoneToast.Position = UDim2.new(1, -20, 0, 60)
milestoneToast.AnchorPoint = Vector2.new(1, 0)
milestoneToast.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
milestoneToast.BackgroundTransparency = 0.1
milestoneToast.BorderSizePixel = 0
milestoneToast.Visible = false
milestoneToast.ZIndex = 18
milestoneToast.Parent = skillBarGui

local milestoneCorner = Instance.new("UICorner")
milestoneCorner.CornerRadius = UDim.new(0, 8)
milestoneCorner.Parent = milestoneToast

local milestoneStroke = Instance.new("UIStroke")
milestoneStroke.Color = Color3.fromRGB(255, 200, 60)
milestoneStroke.Thickness = 1.5
milestoneStroke.Transparency = 0.3
milestoneStroke.Parent = milestoneToast

local milestoneTitle = Instance.new("TextLabel")
milestoneTitle.Name = "Title"
milestoneTitle.Size = UDim2.new(1, -16, 0, 20)
milestoneTitle.Position = UDim2.fromOffset(8, 4)
milestoneTitle.BackgroundTransparency = 1
milestoneTitle.Font = Enum.Font.GothamBold
milestoneTitle.TextSize = 13
milestoneTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
milestoneTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
milestoneTitle.TextStrokeTransparency = 0.4
milestoneTitle.TextXAlignment = Enum.TextXAlignment.Left
milestoneTitle.Text = ""
milestoneTitle.ZIndex = 19
milestoneTitle.Parent = milestoneToast

local milestoneSub = Instance.new("TextLabel")
milestoneSub.Name = "Sub"
milestoneSub.Size = UDim2.new(1, -16, 0, 16)
milestoneSub.Position = UDim2.fromOffset(8, 24)
milestoneSub.BackgroundTransparency = 1
milestoneSub.Font = Enum.Font.GothamMedium
milestoneSub.TextSize = 11
milestoneSub.TextColor3 = Color3.fromRGB(180, 180, 200)
milestoneSub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
milestoneSub.TextStrokeTransparency = 0.5
milestoneSub.TextXAlignment = Enum.TextXAlignment.Left
milestoneSub.Text = ""
milestoneSub.ZIndex = 19
milestoneSub.Parent = milestoneToast

local milestoneQueue = {}
local milestoneShowing = false

local function showNextMilestone()
	if #milestoneQueue == 0 then
		milestoneShowing = false
		return
	end
	milestoneShowing = true
	local data = table.remove(milestoneQueue, 1)
	milestoneTitle.Text = data.title
	milestoneSub.Text = data.sub
	milestoneToast.Visible = true
	milestoneToast.Position = UDim2.new(1, 20, 0, 60)
	milestoneToast.BackgroundTransparency = 1
	TweenService:Create(milestoneToast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 0, 60),
		BackgroundTransparency = 0.1,
	}):Play()
	TweenService:Create(milestoneTitle, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
	TweenService:Create(milestoneSub, TweenInfo.new(0.2), {TextTransparency = 0}):Play()

	task.delay(3, function()
		TweenService:Create(milestoneToast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 20, 0, 60),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(milestoneTitle, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(milestoneSub, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		task.delay(0.35, function()
			milestoneToast.Visible = false
			showNextMilestone()
		end)
	end)
end

local function queueMilestone(title, sub)
	table.insert(milestoneQueue, {title = title, sub = sub})
	if not milestoneShowing then
		showNextMilestone()
	end
end

-- ==================== MASTERY EVENT ====================
local MasteryChangedRemote = Remotes:FindFirstChild("MasteryChanged")
if not MasteryChangedRemote then
	MasteryChangedRemote = Remotes:WaitForChild("MasteryChanged", 5)
end

if MasteryChangedRemote then
	MasteryChangedRemote.OnClientEvent:Connect(function(styleId, level, xp, xpNeeded, totalXP, levelsGained)
		cacheMasteryEntry(styleId, level, xp, xpNeeded, totalXP)
		currentMasteryStyleId = getActiveStyleId()
		if styleId == getActiveStyleId() or styleId == currentMasteryStyleId then
			if levelsGained > 0 then
				local displayName = getStyleDisplayName(styleId)
				queueMilestone(
					displayName .. " - Mastery " .. level .. " reached",
					"New forms may be available."
				)
			end
		end
	end)
end

print("[CombatController] Loaded")
