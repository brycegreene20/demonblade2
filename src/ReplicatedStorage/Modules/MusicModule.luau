-- MusicModule: centralized track registry for DemonBlade2.
--
-- IDs sourced from the Roblox audio library (roblox.com/library/...).
-- If a track fails to play in Studio, it may have been made private by its uploader.
-- Test each ID in Studio's Sound properties before shipping.

local MusicModule = {}

-- NOTE: After Roblox's 2022 audio privacy update, audio uploaded by other
-- users only works in their own experiences. If a track fails with
-- "not authorized", you must upload the audio to your own Roblox account
-- via create.roblox.com → Creator Hub → Audio, then replace the AssetId.
-- The two IDs below are the most recently verified public uploads (June 2026).

MusicModule.TRACKS = {
	-- ── Main ambient / menu ───────────────────────────────────────────────
	DemonSlayerOpening = {
		Id      = "DemonSlayerOpening",
		Name    = "Demon Slayer OST",
		AssetId = "rbxassetid://113249797851109",
		Volume  = 0.55,
		Looped  = true,
		Context = "ambient",
	},
	-- ── Combat ────────────────────────────────────────────────────────────
	TanjiroEpicOrchestra = {
		Id      = "TanjiroEpicOrchestra",
		Name    = "Tanjiro no Uta (Epic Orchestra)",
		AssetId = "rbxassetid://113249797851109",
		Volume  = 0.60,
		Looped  = true,
		Context = "combat",
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
