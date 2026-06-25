local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetLeaderboard = Remotes:WaitForChild("GetLeaderboard")
local BountyChanged = Remotes:WaitForChild("BountyChanged")

local slayerStore = DataStoreService:GetOrderedDataStore("BountyLeaderboard_Slayer")
local demonStore = DataStoreService:GetOrderedDataStore("BountyLeaderboard_Demon")

local SLAYER_TITLES = {
	{ threshold = 40000, title = "Hashira" },
	{ threshold = 25000, title = "Kinoe" },
	{ threshold = 15000, title = "Kinoto" },
	{ threshold = 8000,  title = "Tsuchinoe" },
	{ threshold = 3000,  title = "Hinoe" },
	{ threshold = 1000,  title = "Tsuchinoto" },
	{ threshold = 0,     title = "Mizunoto" },
}

local DEMON_TITLES = {
	{ threshold = 40000, title = "Upper Moon" },
	{ threshold = 25000, title = "Lower Moon" },
	{ threshold = 15000, title = "Kin-oni" },
	{ threshold = 8000,  title = "Blood Demon" },
	{ threshold = 3000,  title = "Oni" },
	{ threshold = 1000,  title = "Lesser Demon" },
	{ threshold = 0,     title = "Demon" },
}

local function getTitle(bounty: number, faction: string): string
	local tiers = if faction == "Slayer" then SLAYER_TITLES else DEMON_TITLES
	for _, tier in tiers do
		if bounty >= tier.threshold then
			return tier.title
		end
	end
	return tiers[#tiers].title
end

local cachedSlayerBoard = {}
local cachedDemonBoard = {}
local BOARD_SIZE = 10

local function fetchBoard(store: OrderedDataStore, faction: string): { any }
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, BOARD_SIZE)
	end)
	if not success or not pages then
		return {}
	end

	local entries = {}
	local page = pages:GetCurrentPage()
	for rank, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		local bounty = entry.value
		local name = "Unknown"
		if userId then
			local ok, displayName = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if ok and displayName then
				name = displayName
			end
		end
		table.insert(entries, {
			rank = rank,
			userId = userId,
			name = name,
			bounty = bounty,
			title = getTitle(bounty, faction),
		})
	end
	return entries
end

local function refreshBoards()
	cachedSlayerBoard = fetchBoard(slayerStore, "Slayer")
	cachedDemonBoard = fetchBoard(demonStore, "Demon")
end

local function pushPlayerBounty(player: Player)
	local data = PlayerDataModule.getData(player)
	if not data then return end

	local bounty = data.Bounty or 0
	local faction = data.Faction or ""
	local key = tostring(player.UserId)

	if faction == "Slayer" then
		pcall(function()
			slayerStore:SetAsync(key, bounty)
		end)
	elseif faction == "Demon" then
		pcall(function()
			demonStore:SetAsync(key, bounty)
		end)
	end
end

local function getPlayerEntry(player: Player, faction: string): any?
	local data = PlayerDataModule.getData(player)
	if not data then return nil end

	local playerFaction = data.Faction or ""
	if playerFaction ~= faction then return nil end

	local bounty = data.Bounty or 0
	local board = if faction == "Slayer" then cachedSlayerBoard else cachedDemonBoard

	for _, entry in board do
		if entry.userId == player.UserId then
			return nil
		end
	end

	local rank = 1
	for _, entry in board do
		if bounty < entry.bounty then
			rank = rank + 1
		end
	end

	return {
		rank = rank,
		userId = player.UserId,
		name = player.DisplayName,
		bounty = bounty,
		title = getTitle(bounty, faction),
	}
end

GetLeaderboard.OnServerInvoke = function(player, requestedFaction)
	local faction = requestedFaction or "Slayer"
	if faction ~= "Slayer" and faction ~= "Demon" then
		faction = "Slayer"
	end

	local board = if faction == "Slayer" then cachedSlayerBoard else cachedDemonBoard
	local playerEntry = getPlayerEntry(player, faction)

	return {
		entries = board,
		playerEntry = playerEntry,
	}
end

task.spawn(function()
	for _, player in Players:GetPlayers() do
		task.spawn(pushPlayerBounty, player)
	end
	refreshBoards()
	print("[LeaderboardServer] Initial board loaded — Slayers:", #cachedSlayerBoard, "Demons:", #cachedDemonBoard)
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			task.spawn(pushPlayerBounty, player)
		end
		task.wait(2)
		refreshBoards()
	end
end)

BountyChanged.OnServerEvent:Connect(function() end)

Players.PlayerRemoving:Connect(function(player)
	task.spawn(pushPlayerBounty, player)
end)

print("[LeaderboardServer] Loaded")
