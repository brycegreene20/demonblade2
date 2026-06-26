-- MusicModule: centralized track registry for DemonBlade2.
--
-- IDs sourced from the Roblox audio library (roblox.com/library/...).
-- If a track fails to play in Studio, it may have been made private by its uploader.
-- Test each ID in Studio's Sound properties before shipping.

local MusicModule = {}
local AMBIENT_VOLUME = 0.55
local COMBAT_VOLUME = 0.60

-- NOTE: After Roblox's 2022 audio privacy update, audio uploaded by other
-- users only works in their own experiences. If a track fails with
-- "not authorized", upload the audio to your own Roblox account in Creator Hub,
-- then replace the AssetId.

MusicModule.TRACKS = {
	-- Main ambient / menu
	DemonSlayerOpening = {
		Id = "DemonSlayerOpening",
		Name = "Demon Slayer OST",
		AssetId = "rbxassetid://113249797851109",
		Volume = AMBIENT_VOLUME,
		Looped = true,
		Context = "ambient",
		SortOrder = 10,
	},
	MountainCalm = {
		Id = "MountainCalm",
		Name = "Mountain Calm",
		AssetId = "rbxassetid://110015946983764",
		Volume = AMBIENT_VOLUME,
		Looped = true,
		Context = "ambient",
		SortOrder = 20,
	},
	NightPatrol = {
		Id = "NightPatrol",
		Name = "Night Patrol",
		AssetId = "rbxassetid://92987384618845",
		Volume = AMBIENT_VOLUME,
		Looped = true,
		Context = "ambient",
		SortOrder = 30,
	},
	QuietResolve = {
		Id = "QuietResolve",
		Name = "Quiet Resolve",
		AssetId = "rbxassetid://88564010620423",
		Volume = AMBIENT_VOLUME,
		Looped = true,
		Context = "ambient",
		SortOrder = 40,
	},
	ShadowMarch = {
		Id = "ShadowMarch",
		Name = "Shadow March",
		AssetId = "rbxassetid://96055187526468",
		Volume = AMBIENT_VOLUME,
		Looped = true,
		Context = "ambient",
		SortOrder = 50,
	},

	-- Combat
	TanjiroEpicOrchestra = {
		Id = "TanjiroEpicOrchestra",
		Name = "Tanjiro no Uta (Epic Orchestra)",
		AssetId = "rbxassetid://88564010620423",
		Volume = COMBAT_VOLUME,
		Looped = true,
		Context = "combat",
		SortOrder = 10,
	},
	DemonEncounter = {
		Id = "DemonEncounter",
		Name = "Demon Encounter",
		AssetId = "rbxassetid://96055187526468",
		Volume = COMBAT_VOLUME,
		Looped = true,
		Context = "combat",
		SortOrder = 20,
	},
}

function MusicModule.getTrack(trackId)
	return MusicModule.TRACKS[trackId]
end

function MusicModule.getDefaultAmbient()
	return MusicModule.TRACKS.DemonSlayerOpening
end

function MusicModule.getDefaultCombat()
	return MusicModule.TRACKS.TanjiroEpicOrchestra
end

function MusicModule.getAllTracks()
	local result = {}
	for _, track in MusicModule.TRACKS do
		table.insert(result, track)
	end
	table.sort(result, function(a, b)
		return (a.SortOrder or 100) < (b.SortOrder or 100)
	end)
	return result
end

function MusicModule.getTracksForContext(context)
	local result = {}
	for _, track in MusicModule.TRACKS do
		if track.Context == context then
			table.insert(result, track)
		end
	end
	table.sort(result, function(a, b)
		return (a.SortOrder or 100) < (b.SortOrder or 100)
	end)
	return result
end

function MusicModule.isValidTrack(track)
	return typeof(track) == "table"
		and typeof(track.Id) == "string"
		and typeof(track.AssetId) == "string"
		and typeof(track.Volume) == "number"
		and typeof(track.Looped) == "boolean"
end

return MusicModule
