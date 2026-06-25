local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MusicModule = require(Modules:WaitForChild("MusicModule"))

local FADE_IN_TIME   = 2.5
local FADE_OUT_TIME  = 1.5

print("[MusicController] Booting")

local bgmSound = Instance.new("Sound")
bgmSound.Name = "DemonBladeBGM"
bgmSound.Volume = 0
bgmSound.Parent = SoundService

local currentTrackId = nil
local currentContext = nil
local fadeTween      = nil

local function cancelFade()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
end

local function fadeVolume(targetVol, duration, callback)
	cancelFade()
	fadeTween = TweenService:Create(bgmSound, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Volume = targetVol,
	})
	if callback then
		fadeTween.Completed:Once(callback)
	end
	fadeTween:Play()
end

local function playTrack(track)
	if not track then return end

	if currentTrackId == track.Id and bgmSound.IsPlaying then return end

	print("[MusicController] Now playing: " .. track.Name .. "  (" .. track.AssetId .. ")")
	currentTrackId = track.Id

	local function startTrack()
		bgmSound.SoundId = track.AssetId
		bgmSound.Looped  = track.Looped
		bgmSound:Play()
		fadeVolume(track.Volume, FADE_IN_TIME)
	end

	if bgmSound.IsPlaying then
		fadeVolume(0, FADE_OUT_TIME, function()
			bgmSound:Stop()
			startTrack()
		end)
	else
		startTrack()
	end
end

local function stopMusic(instant)
	if instant then
		cancelFade()
		bgmSound:Stop()
		bgmSound.Volume = 0
		currentTrackId = nil
		currentContext = nil
	else
		fadeVolume(0, FADE_OUT_TIME, function()
			bgmSound:Stop()
			currentTrackId = nil
			currentContext = nil
		end)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────

local MusicController = {}

function MusicController.playAmbient()
	if currentContext == "ambient" and bgmSound.IsPlaying then return end
	print("[MusicController] Switching to ambient playlist")
	local track = MusicModule.getDefaultAmbient()
	currentContext = "ambient"
	playTrack(track)
end

function MusicController.playCombat()
	if currentContext == "combat" and bgmSound.IsPlaying then return end
	print("[MusicController] Switching to combat playlist")
	local track = MusicModule.getDefaultCombat()
	currentContext = "combat"
	playTrack(track)
end

function MusicController.stop(instant)
	stopMusic(instant)
end

function MusicController.setVolume(vol)
	cancelFade()
	bgmSound.Volume = math.clamp(vol, 0, 1)
end

function MusicController.playSpecific(trackId)
	local track = MusicModule.getTrack(trackId)
	if track then
		currentContext = track.Context
		playTrack(track)
	else
		warn("[MusicController] Unknown track: " .. tostring(trackId))
	end
end

-- ── Auto-start ────────────────────────────────────────────────────────────

local LocalPlayer = Players.LocalPlayer

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(2)
	MusicController.playAmbient()
end)

if LocalPlayer.Character then
	task.delay(2, MusicController.playAmbient)
end

print("[MusicController] Loaded — " .. #MusicModule.getAllTracks() .. " tracks registered")

return MusicController
