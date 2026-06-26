local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MusicModule = require(Modules:WaitForChild("MusicModule"))

local FADE_IN_TIME = 2.5
local FADE_OUT_TIME = 1.5
local MUSIC_MASTER_SCALE = 0.7
local MAX_EFFECTIVE_VOLUME = 0.18
local TRACK_LOAD_TIMEOUT = 8
local TRACK_START_TIMEOUT = 2

print("[MusicController] Booting")

local bgmSound = Instance.new("Sound")
bgmSound.Name = "DemonBladeBGM"
bgmSound.Volume = 0
bgmSound.Parent = SoundService

local currentTrackId = nil
local currentContext = nil
local fadeTween = nil
local suppressEndedAdvance = false
local activeTrackToken = 0
local playlistCursor = {
	ambient = 0,
	combat = 0,
}

local advancePlaylist

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

local function getEffectiveVolume(track)
	return math.clamp((track.Volume or 0) * MUSIC_MASTER_SCALE, 0, MAX_EFFECTIVE_VOLUME)
end

local function getNextTrackForContext(context, fallback)
	local tracks = MusicModule.getTracksForContext(context)
	if #tracks == 0 then
		return fallback
	end

	playlistCursor[context] = (playlistCursor[context] or 0) + 1
	if playlistCursor[context] > #tracks then
		playlistCursor[context] = 1
	end

	return tracks[playlistCursor[context]]
end

local function getFallbackForContext(context)
	if context == "combat" then
		return MusicModule.getDefaultCombat()
	end
	return MusicModule.getDefaultAmbient()
end

local function skipTrack(track, reason, attempts)
	warn(
		"[MusicController] Skipping track "
			.. tostring(track and track.Id or "unknown")
			.. " ("
			.. tostring(reason)
			.. ")"
	)

	if not currentContext or not advancePlaylist then return end
	task.defer(function()
		advancePlaylist(reason, (attempts or 0) + 1)
	end)
end

local function playTrack(track, attempts)
	if not track then return end

	if currentTrackId == track.Id and bgmSound.IsPlaying then return end

	local effectiveVolume = getEffectiveVolume(track)
	print(
		"[MusicController] Now playing: "
			.. track.Name
			.. " ("
			.. track.AssetId
			.. "), volume="
			.. string.format("%.2f", effectiveVolume)
	)
	currentTrackId = track.Id

	local function startTrack()
		activeTrackToken += 1
		local trackToken = activeTrackToken
		local preloadComplete = false

		bgmSound.SoundId = track.AssetId
		bgmSound.Looped = false
		bgmSound.TimePosition = 0
		bgmSound.Volume = 0

		task.spawn(function()
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync({bgmSound})
			end)

			if trackToken ~= activeTrackToken or currentTrackId ~= track.Id then
				return
			end

			preloadComplete = true
			if not ok then
				skipTrack(track, "preload failed: " .. tostring(err), attempts)
				return
			end

			local playOk, playErr = pcall(function()
				bgmSound:Play()
			end)
			if not playOk then
				skipTrack(track, "play failed: " .. tostring(playErr), attempts)
				return
			end

			fadeVolume(effectiveVolume, FADE_IN_TIME)

			task.delay(TRACK_START_TIMEOUT, function()
				if trackToken ~= activeTrackToken or currentTrackId ~= track.Id then
					return
				end
				if not bgmSound.IsPlaying and bgmSound.TimePosition <= 0.05 then
					skipTrack(track, "sound did not start", attempts)
				end
			end)
		end)

		task.delay(TRACK_LOAD_TIMEOUT, function()
			if trackToken ~= activeTrackToken or currentTrackId ~= track.Id then
				return
			end
			if not preloadComplete then
				skipTrack(track, "load timed out", attempts)
			end
		end)
	end

	if bgmSound.IsPlaying then
		fadeVolume(0, FADE_OUT_TIME, function()
			suppressEndedAdvance = true
			bgmSound:Stop()
			suppressEndedAdvance = false
			startTrack()
		end)
	else
		startTrack()
	end
end

advancePlaylist = function(reason, attempts)
	if not currentContext then return end
	attempts = attempts or 0

	local tracks = MusicModule.getTracksForContext(currentContext)
	local maxAttempts = math.max(#tracks, 1)
	if attempts >= maxAttempts then
		warn(
			"[MusicController] No playable "
				.. currentContext
				.. " tracks after "
				.. tostring(attempts)
				.. " attempt(s); music paused"
		)
		currentTrackId = nil
		return
	end

	local nextTrack = getNextTrackForContext(currentContext, getFallbackForContext(currentContext))
	if nextTrack then
		print(
			"[MusicController] Advancing "
				.. currentContext
				.. " playlist"
				.. (reason and (" after " .. tostring(reason)) or "")
		)
		playTrack(nextTrack, attempts)
	end
end

local function stopMusic(instant)
	if instant then
		cancelFade()
		suppressEndedAdvance = true
		bgmSound:Stop()
		suppressEndedAdvance = false
		bgmSound.Volume = 0
		currentTrackId = nil
		currentContext = nil
	else
		fadeVolume(0, FADE_OUT_TIME, function()
			suppressEndedAdvance = true
			bgmSound:Stop()
			suppressEndedAdvance = false
			currentTrackId = nil
			currentContext = nil
		end)
	end
end

local MusicController = {}

function MusicController.playAmbient()
	if currentContext == "ambient" and bgmSound.IsPlaying then return end
	print("[MusicController] Switching to ambient playlist")
	local track = getNextTrackForContext("ambient", MusicModule.getDefaultAmbient())
	currentContext = "ambient"
	playTrack(track)
end

function MusicController.playCombat()
	if currentContext == "combat" and bgmSound.IsPlaying then return end
	print("[MusicController] Switching to combat playlist")
	local track = getNextTrackForContext("combat", MusicModule.getDefaultCombat())
	currentContext = "combat"
	playTrack(track)
end

function MusicController.stop(instant)
	stopMusic(instant)
end

function MusicController.setVolume(vol)
	cancelFade()
	bgmSound.Volume = math.clamp(vol, 0, MAX_EFFECTIVE_VOLUME)
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

bgmSound.Ended:Connect(function()
	if suppressEndedAdvance then return end
	print("[MusicController] Track ended: " .. tostring(currentTrackId))
	task.defer(function()
		advancePlaylist("ended", 0)
	end)
end)

local LocalPlayer = Players.LocalPlayer

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(2)
	MusicController.playAmbient()
end)

if LocalPlayer.Character then
	task.delay(2, MusicController.playAmbient)
end

print("[MusicController] Loaded - " .. #MusicModule.getAllTracks() .. " tracks registered")

return MusicController
