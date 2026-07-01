local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClanAction = Remotes:WaitForChild("ClanAction")
local ClanUpdate = Remotes:WaitForChild("ClanUpdate")
local GetClanData = Remotes:WaitForChild("GetClanData")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ClanModule = require(Modules:WaitForChild("ClanModule"))
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))

local clanStore = DataStoreService:GetDataStore("ClanData_v1")
local membershipStore = DataStoreService:GetDataStore("ClanMembership_v1")
local REGISTRY_KEY = "Registry"
local ACTIVITY_FLUSH_INTERVAL = 30
local MAX_RETRIES = 3

local clanCache = {}
local clanIdByPlayer = {}
local pendingInvites = {}
local pendingActivity = {}
local dirtyClans = {}
local actionTimestamps = {}

local function retryDataStore(label, callback)
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(callback)
		if success then
			return true, result
		end
		if attempt == MAX_RETRIES then
			warn(("[ClanService] %s failed after %d attempts: %s"):format(label, attempt, tostring(result)))
		else
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, nil
end

local function getMemberKey(userId)
	return tostring(math.floor(tonumber(userId) or 0))
end

local function getClanKey(clanId)
	return "Clan_" .. clanId
end

local function trim(text)
	return (tostring(text or ""):match("^%s*(.-)%s*$") or "")
end

local function filterUserText(player, text)
	local success, filtered = pcall(function()
		local result = TextService:FilterStringAsync(tostring(text or ""), player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not success then
		warn("[ClanService] Text filtering failed for " .. player.Name .. ": " .. tostring(filtered))
		return nil
	end
	return filtered
end

local function memberCount(clan)
	local count = 0
	for _ in clan.Members or {} do
		count += 1
	end
	return count
end

local function isManager(clan, userId)
	local key = getMemberKey(userId)
	local member = clan and clan.Members and clan.Members[key]
	return member ~= nil and (member.Role == "Owner" or member.Role == "Officer")
end

local function publicMember(member, userId)
	return {
		UserId = tonumber(userId) or 0,
		Name = member.Name or "Unknown",
		DisplayName = member.DisplayName or member.Name or "Unknown",
		Role = member.Role or "Member",
		Reputation = math.max(0, math.floor(tonumber(member.Reputation) or 0)),
		Bounty = math.max(0, math.floor(tonumber(member.Bounty) or 0)),
		JoinedAt = member.JoinedAt or 0,
	}
end

local function publicSummary(clan)
	local clanBounty = 0
	for _, member in clan.Members or {} do
		clanBounty += math.max(0, math.floor(tonumber(member.Bounty) or 0))
	end
	return {
		Id = clan.Id,
		Name = clan.Name,
		Logo = clan.Logo,
		Description = clan.Description or "",
		Prestige = math.max(0, math.floor(tonumber(clan.Prestige) or 0)),
		ClanBounty = clanBounty,
		Level = ClanModule.getLevel(clan.Prestige),
		MemberCount = memberCount(clan),
		MaxMembers = ClanModule.MAX_MEMBERS,
	}
end

local function loadClan(clanId)
	if type(clanId) ~= "string" or clanId == "" then return nil end
	if clanCache[clanId] then return clanCache[clanId] end
	local success, clan = retryDataStore("load " .. clanId, function()
		return clanStore:GetAsync(getClanKey(clanId))
	end)
	if success and type(clan) == "table" then
		clanCache[clanId] = clan
		return clan
	end
	return nil
end

local function updateRegistrySummary(clan)
	local summary = publicSummary(clan)
	retryDataStore("update clan registry", function()
		clanStore:UpdateAsync(REGISTRY_KEY, function(registry)
			registry = type(registry) == "table" and registry or {}
			local replaced = false
			for index, entry in ipairs(registry) do
				if entry.Id == clan.Id then
					registry[index] = summary
					replaced = true
					break
				end
			end
			if not replaced then
				table.insert(registry, summary)
			end
			return registry
		end)
	end)
end

local function mutateClan(clanId, label, callback)
	local rejection
	local success, clan = retryDataStore(label, function()
		return clanStore:UpdateAsync(getClanKey(clanId), function(current)
			if type(current) ~= "table" then
				rejection = "Clan no longer exists."
				return current
			end
			local accepted, message = callback(current)
			if accepted == false then
				rejection = message or "Action denied."
				return current
			end
			current.UpdatedAt = os.time()
			return current
		end)
	end)
	if not success then return false, "Clan service is temporarily unavailable." end
	if rejection then return false, rejection end
	if type(clan) ~= "table" then return false, "Clan no longer exists." end
	clanCache[clanId] = clan
	task.spawn(updateRegistrySummary, clan)
	return true, clan
end

local function setMembershipIndex(userId, clanId)
	local key = getMemberKey(userId)
	return retryDataStore("update membership " .. key, function()
		if clanId and clanId ~= "" then
			membershipStore:SetAsync(key, clanId)
		else
			membershipStore:RemoveAsync(key)
		end
	end)
end

local function setPlayerClan(player, clan, member)
	local clanId = clan and clan.Id or ""
	local reputation = member and member.Reputation or 0
	clanIdByPlayer[player] = clanId ~= "" and clanId or nil
	PlayerDataModule.setClanMembership(player, clanId, reputation)
	player:SetAttribute("ClanId", clanId)
	player:SetAttribute("ClanName", clan and clan.Name or "")
	player:SetAttribute("ClanReputation", reputation)
end

local function notify(player, message)
	if player and player.Parent then
		ClanUpdate:FireClient(player, { Message = message })
	end
end

local function notifyClan(clanId, message)
	for player, playerClanId in clanIdByPlayer do
		if playerClanId == clanId and player.Parent then
			ClanUpdate:FireClient(player, { Message = message, Refresh = true })
		end
	end
end

local function removeRegistryEntry(clanId)
	retryDataStore("remove clan registry entry", function()
		clanStore:UpdateAsync(REGISTRY_KEY, function(registry)
			registry = type(registry) == "table" and registry or {}
			for index = #registry, 1, -1 do
				if registry[index].Id == clanId then
					table.remove(registry, index)
				end
			end
			return registry
		end)
	end)
end

local function getRegistry()
	local success, registry = retryDataStore("load clan registry", function()
		return clanStore:GetAsync(REGISTRY_KEY)
	end)
	if not success or type(registry) ~= "table" then return {} end
	table.sort(registry, function(left, right)
		if (left.Prestige or 0) == (right.Prestige or 0) then
			return (left.Name or "") < (right.Name or "")
		end
		return (left.Prestige or 0) > (right.Prestige or 0)
	end)
	return registry
end

local function makeClanDetail(player, clan)
	if not clan then return nil end
	local members = {}
	for userId, member in clan.Members or {} do
		table.insert(members, publicMember(member, userId))
	end
	table.sort(members, function(left, right)
		if left.Role ~= right.Role then
			local order = { Owner = 1, Officer = 2, Member = 3 }
			return (order[left.Role] or 4) < (order[right.Role] or 4)
		end
		return left.Reputation > right.Reputation
	end)

	local achievements = {}
	for _, definition in ipairs(ClanModule.ACHIEVEMENTS) do
		local progress, goal = ClanModule.getAchievementProgress(clan, definition)
		table.insert(achievements, {
			Id = definition.Id,
			Name = definition.Name,
			Description = definition.Description,
			Progress = progress,
			Goal = goal,
			PrestigeReward = definition.PrestigeReward,
			MemberReputationReward = definition.MemberReputationReward,
			Completed = clan.Achievements and clan.Achievements[definition.Id] == true,
		})
	end

	local requests = {}
	if isManager(clan, player.UserId) then
		for userId, request in clan.PendingRequests or {} do
			table.insert(requests, {
				UserId = tonumber(userId) or 0,
				Name = request.Name,
				DisplayName = request.DisplayName,
				RequestedAt = request.RequestedAt,
			})
		end
	end

	local detail = publicSummary(clan)
	detail.Members = members
	detail.Achievements = achievements
	detail.Requests = requests
	detail.CanManage = isManager(clan, player.UserId)
	detail.IsOwner = getMemberKey(clan.OwnerUserId) == getMemberKey(player.UserId)
	detail.NextLevelPrestige = ClanModule.getNextLevelPrestige(clan.Prestige)
	return detail
end

local function getPlayerDataPayload(player)
	local clanId = clanIdByPlayer[player]
	local clan = clanId and loadClan(clanId) or nil
	local nearbyCount = 0
	if clan then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			for otherPlayer, otherClanId in clanIdByPlayer do
				if otherPlayer ~= player and otherClanId == clanId then
					local otherCharacter = otherPlayer.Character
					local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
					if otherRoot and ClanModule.isInProximity((root.Position - otherRoot.Position).Magnitude) then
						nearbyCount += 1
					end
				end
			end
		end
	end
	return {
		Clan = makeClanDetail(player, clan),
		Browse = getRegistry(),
		PendingInvites = pendingInvites[player] or {},
		Bonuses = ClanModule.getProximityBonuses(nearbyCount),
		NearbyClanMembers = nearbyCount,
		Logos = ClanModule.LOGOS,
	}
end

local function syncPlayerMembership(player)
	local deadline = os.clock() + 20
	while player.Parent and player:GetAttribute("DataPersistenceAvailable") == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	if not player.Parent then return end

	local data = PlayerDataModule.getData(player)
	local savedClanId = data and data.ClanId or ""
	local success, indexedClanId = retryDataStore("load membership " .. player.UserId, function()
		return membershipStore:GetAsync(getMemberKey(player.UserId))
	end)
	local clanId = success and indexedClanId or savedClanId
	local clan = loadClan(clanId)
	local member = clan and clan.Members and clan.Members[getMemberKey(player.UserId)]
	if clan and member then
		member.Reputation = math.max(member.Reputation or 0, data and data.ClanReputation or 0)
		member.Bounty = math.max(0, data and data.Bounty or member.Bounty or 0)
		setPlayerClan(player, clan, member)
	else
		setPlayerClan(player, nil, nil)
		if success and indexedClanId then
			task.spawn(setMembershipIndex, player.UserId, "")
		end
	end
end

local function createClan(player, payload)
	if clanIdByPlayer[player] then return false, "Leave your current clan first." end
	local valid, nameOrError = ClanModule.isValidName(payload.Name)
	if not valid then return false, nameOrError end
	local name = filterUserText(player, nameOrError)
	if not name or name == "" then return false, "Clan name could not be filtered." end
	local logo = ClanModule.isValidLogo(payload.Logo) and payload.Logo or "Blossom"
	local rawDescription = trim(payload.Description):sub(1, ClanModule.MAX_DESCRIPTION_LENGTH)
	local description = rawDescription == "" and "" or filterUserText(player, rawDescription)
	if description == nil then return false, "Clan description could not be filtered." end
	local clanId = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 16)
	local duplicateName = false

	local registrySuccess = retryDataStore("reserve clan name", function()
		clanStore:UpdateAsync(REGISTRY_KEY, function(registry)
			registry = type(registry) == "table" and registry or {}
			for _, entry in ipairs(registry) do
				if string.lower(entry.Name or "") == string.lower(name) then
					duplicateName = true
					return registry
				end
			end
			table.insert(registry, {
				Id = clanId,
				Name = name,
				Logo = logo,
				Description = description,
				Prestige = 0,
				Level = 1,
				MemberCount = 1,
				MaxMembers = ClanModule.MAX_MEMBERS,
			})
			return registry
		end)
	end)
	if not registrySuccess then return false, "Clan service is temporarily unavailable." end
	if duplicateName then return false, "That clan name is already taken." end

	local memberKey = getMemberKey(player.UserId)
	local playerData = PlayerDataModule.getData(player)
	local clan = {
		Id = clanId,
		Name = name,
		Logo = logo,
		Description = description,
		OwnerUserId = player.UserId,
		Prestige = 0,
		Members = {
			[memberKey] = {
				Name = player.Name,
				DisplayName = player.DisplayName,
				Role = "Owner",
				Reputation = 0,
				Bounty = math.max(0, playerData and playerData.Bounty or 0),
				JoinedAt = os.time(),
			},
		},
		PendingRequests = {},
		Stats = { EnemyKills = 0, BossKills = 0, QuestsCompleted = 0 },
		Achievements = {},
		CreatedAt = os.time(),
		UpdatedAt = os.time(),
	}
	local saved = retryDataStore("create clan", function()
		clanStore:SetAsync(getClanKey(clanId), clan)
	end)
	if not saved then
		task.spawn(removeRegistryEntry, clanId)
		return false, "Clan could not be created."
	end

	clanCache[clanId] = clan
	setMembershipIndex(player.UserId, clanId)
	setPlayerClan(player, clan, clan.Members[memberKey])
	print(("[ClanService] %s created clan %s"):format(player.Name, name))
	return true, "Clan created."
end

local function requestJoin(player, payload)
	if clanIdByPlayer[player] then return false, "You are already in a clan." end
	local clanId = tostring(payload.ClanId or "")
	local success, result = mutateClan(clanId, "request clan membership", function(clan)
		local key = getMemberKey(player.UserId)
		if clan.Members[key] then return false, "You are already a member." end
		clan.PendingRequests = clan.PendingRequests or {}
		clan.PendingRequests[key] = {
			Name = player.Name,
			DisplayName = player.DisplayName,
			RequestedAt = os.time(),
		}
		return true
	end)
	if success then
		notifyClan(clanId, player.DisplayName .. " requested to join the clan.")
		return true, "Join request sent."
	end
	return false, result
end

local function invitePlayer(player, payload)
	local clanId = clanIdByPlayer[player]
	local clan = clanId and loadClan(clanId)
	if not clan or not isManager(clan, player.UserId) then
		return false, "Only clan leaders and officers can invite."
	end
	local target = Players:GetPlayerByUserId(tonumber(payload.UserId) or 0)
	if not target or target == player then return false, "Player is not available." end
	if clanIdByPlayer[target] then return false, "That player is already in a clan." end
	local invite = {
		ClanId = clanId,
		ClanName = clan.Name,
		InviterUserId = player.UserId,
		InviterName = player.DisplayName,
		ExpiresAt = os.time() + ClanModule.INVITE_TTL_SECONDS,
	}
	local invites = pendingInvites[target] or {}
	for index = #invites, 1, -1 do
		if invites[index].ClanId == clanId then
				table.remove(invites, index)
			end
	end
	table.insert(invites, invite)
	pendingInvites[target] = invites
	ClanUpdate:FireClient(target, { Message = player.DisplayName .. " invited you to " .. clan.Name, Refresh = true })
	task.delay(ClanModule.INVITE_TTL_SECONDS, function()
		local currentInvites = pendingInvites[target]
		if not currentInvites then return end
		for index = #currentInvites, 1, -1 do
			if currentInvites[index] == invite then
				table.remove(currentInvites, index)
			end
		end
		if #currentInvites == 0 then
			pendingInvites[target] = nil
		end
		if target.Parent then
			ClanUpdate:FireClient(target, { Message = "Clan invite expired.", Refresh = true })
		end
	end)
	return true, "Invite sent."
end

local function addMemberToClan(clanId, userId, name, displayName)
	return mutateClan(clanId, "add clan member", function(clan)
		if memberCount(clan) >= ClanModule.MAX_MEMBERS then return false, "Clan is full." end
		local key = getMemberKey(userId)
		if clan.Members[key] then return false, "Player is already a member." end
		clan.Members[key] = {
			Name = name,
			DisplayName = displayName,
			Role = "Member",
			Reputation = 0,
			Bounty = 0,
			JoinedAt = os.time(),
		}
		if clan.PendingRequests then
			clan.PendingRequests[key] = nil
		end
		return true
	end)
end

local function respondToInvite(player, payload)
	local invites = pendingInvites[player] or {}
	local selected
	local selectedIndex
	for index, invite in ipairs(invites) do
		if invite.ClanId == payload.ClanId and invite.ExpiresAt >= os.time() then
			selected = invite
			selectedIndex = index
			break
		end
	end
	if selectedIndex then
		table.remove(invites, selectedIndex)
	end
	pendingInvites[player] = #invites > 0 and invites or nil
	if not selected then return false, "Invite expired." end
	if payload.Accepted ~= true then return true, "Invite declined." end
	if clanIdByPlayer[player] then return false, "You are already in a clan." end
	local success, clanOrMessage = addMemberToClan(
		selected.ClanId,
		player.UserId,
		player.Name,
		player.DisplayName
	)
	if not success then return false, clanOrMessage end
	local clan = clanOrMessage
	setMembershipIndex(player.UserId, clan.Id)
	setPlayerClan(player, clan, clan.Members[getMemberKey(player.UserId)])
	notifyClan(clan.Id, player.DisplayName .. " joined the clan.")
	return true, "Joined " .. clan.Name .. "."
end

local function reviewRequest(player, payload)
	local clanId = clanIdByPlayer[player]
	local clan = clanId and loadClan(clanId)
	if not clan or not isManager(clan, player.UserId) then return false, "You cannot review requests." end
	local userId = tonumber(payload.UserId) or 0
	local key = getMemberKey(userId)
	local request = clan.PendingRequests and clan.PendingRequests[key]
	if not request then return false, "Request no longer exists." end
	if payload.Accepted ~= true then
		return mutateClan(clanId, "decline clan request", function(current)
			current.PendingRequests[key] = nil
			return true
		end)
	end
	local success, clanOrMessage = addMemberToClan(clanId, userId, request.Name, request.DisplayName)
	if not success then return false, clanOrMessage end
	setMembershipIndex(userId, clanId)
	local target = Players:GetPlayerByUserId(userId)
	if target then
		setPlayerClan(target, clanOrMessage, clanOrMessage.Members[key])
	end
	notifyClan(clanId, request.DisplayName .. " joined the clan.")
	return true, "Request accepted."
end

local function leaveClan(player)
	local clanId = clanIdByPlayer[player]
	local clan = clanId and loadClan(clanId)
	if not clan then return false, "You are not in a clan." end
	local key = getMemberKey(player.UserId)
	local isOwner = getMemberKey(clan.OwnerUserId) == key
	if isOwner and memberCount(clan) > 1 then
		return false, "Transfer leadership or remove other members before disbanding."
	end
	if isOwner then
		retryDataStore("disband clan", function()
			clanStore:RemoveAsync(getClanKey(clanId))
		end)
		removeRegistryEntry(clanId)
		clanCache[clanId] = nil
	else
		local success, message = mutateClan(clanId, "leave clan", function(current)
			current.Members[key] = nil
			return true
		end)
		if not success then return false, message end
	end
	setMembershipIndex(player.UserId, "")
	setPlayerClan(player, nil, nil)
	notifyClan(clanId, player.DisplayName .. " left the clan.")
	return true, isOwner and "Clan disbanded." or "You left the clan."
end

local function updateSettings(player, payload)
	local clanId = clanIdByPlayer[player]
	local clan = clanId and loadClan(clanId)
	if not clan or getMemberKey(clan.OwnerUserId) ~= getMemberKey(player.UserId) then
		return false, "Only the clan owner can change settings."
	end
	local rawDescription = trim(payload.Description):sub(1, ClanModule.MAX_DESCRIPTION_LENGTH)
	local description = rawDescription == "" and "" or filterUserText(player, rawDescription)
	if description == nil then return false, "Clan description could not be filtered." end
	local logo = ClanModule.isValidLogo(payload.Logo) and payload.Logo or clan.Logo
	return mutateClan(clanId, "update clan settings", function(current)
		current.Description = description
		current.Logo = logo
		return true
	end)
end

local actionHandlers = {
	Create = createClan,
	RequestJoin = requestJoin,
	Invite = invitePlayer,
	InviteResponse = respondToInvite,
	ReviewRequest = reviewRequest,
	Leave = leaveClan,
	UpdateSettings = updateSettings,
}

ClanAction.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then return end
	local now = os.clock()
	if now - (actionTimestamps[player] or 0) < 0.5 then return end
	actionTimestamps[player] = now
	local handler = actionHandlers[payload.Type]
	if not handler then
		notify(player, "Unknown clan action.")
		return
	end
	local callSucceeded, success, message = pcall(handler, player, payload)
	if not callSucceeded then
		warn(("[ClanService] Action %s failed for %s: %s"):format(
			tostring(payload.Type),
			player.Name,
			tostring(success)
		))
		notify(player, "Clan action failed safely. Please try again.")
		return
	end
	notify(player, type(message) == "string" and message or (success and "Clan updated." or "Clan action failed."))
	if success then
		ClanUpdate:FireClient(player, { Refresh = true })
	end
end)

GetClanData.OnServerInvoke = function(player)
	return getPlayerDataPayload(player)
end

local function getNearbyClanMemberCount(player)
	local clanId = clanIdByPlayer[player]
	if not clanId then return 0 end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return 0 end
	local count = 0
	for otherPlayer, otherClanId in clanIdByPlayer do
		if otherPlayer ~= player and otherClanId == clanId then
			local otherCharacter = otherPlayer.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if otherRoot and ClanModule.isInProximity((root.Position - otherRoot.Position).Magnitude) then
				count += 1
			end
		end
	end
	return count
end

local function flushActivity(clanId)
	local activity = pendingActivity[clanId]
	if not activity then return end
	pendingActivity[clanId] = nil
	dirtyClans[clanId] = nil
	local completedNow = {}
	local success, clan = mutateClan(clanId, "save clan activity", function(current)
		completedNow = {}
		current.Prestige = math.max(0, (current.Prestige or 0) + activity.Prestige)
		current.Stats = current.Stats or {}
		current.Achievements = current.Achievements or {}
		for stat, amount in activity.Stats do
			current.Stats[stat] = math.max(0, (current.Stats[stat] or 0) + amount)
		end
		for userId, reputation in activity.Reputation do
			local member = current.Members and current.Members[userId]
			if member then
				member.Reputation = math.max(0, (member.Reputation or 0) + reputation)
			end
		end
		for userId, bounty in activity.Bounties or {} do
			local member = current.Members and current.Members[userId]
			if member then
				member.Bounty = math.max(0, bounty)
			end
		end
		for _, achievement in ipairs(ClanModule.ACHIEVEMENTS) do
			if current.Achievements[achievement.Id] ~= true
				and (current.Stats[achievement.Stat] or 0) >= achievement.Goal
			then
				current.Achievements[achievement.Id] = true
				current.Prestige += achievement.PrestigeReward
				for _, member in current.Members or {} do
					member.Reputation = math.max(
						0,
						(member.Reputation or 0) + achievement.MemberReputationReward
					)
				end
				table.insert(completedNow, achievement.Name)
			end
		end
		return true
	end)
	if success then
		for player, playerClanId in clanIdByPlayer do
			if playerClanId == clanId then
				local member = clan.Members and clan.Members[getMemberKey(player.UserId)]
				if member then
					PlayerDataModule.setClanMembership(player, clanId, member.Reputation)
					player:SetAttribute("ClanReputation", member.Reputation)
				end
			end
		end
		local message = #completedNow > 0
			and ("Achievement completed: " .. table.concat(completedNow, ", "))
			or "Clan activity and reputation updated."
		notifyClan(clanId, message)
	else
		pendingActivity[clanId] = activity
		dirtyClans[clanId] = true
		warn("[ClanService] Re-queued unsaved activity for " .. clanId .. ": " .. tostring(clan))
	end
end

local ClanService = {}

function ClanService.areClanmates(left, right)
	return left ~= nil
		and right ~= nil
		and left ~= right
		and clanIdByPlayer[left] ~= nil
		and clanIdByPlayer[left] == clanIdByPlayer[right]
end

function ClanService.getXPBonusMultiplier(player)
	return ClanModule.getProximityBonuses(getNearbyClanMemberCount(player)).XPMultiplier
end

function ClanService.getDamageBonusMultiplier(player)
	return ClanModule.getProximityBonuses(getNearbyClanMemberCount(player)).DamageMultiplier
end

function ClanService.grantActivity(player, eventName, prestige, reputation)
	local clanId = clanIdByPlayer[player]
	if not clanId then return false end
	local statByEvent = {
		EnemyKill = "EnemyKills",
		BossKill = "BossKills",
		QuestCompleted = "QuestsCompleted",
	}
	local activity = pendingActivity[clanId] or {
		Prestige = 0,
		Reputation = {},
		Bounties = {},
		Stats = {},
	}
	pendingActivity[clanId] = activity
	activity.Prestige += math.max(0, math.floor(tonumber(prestige) or 0))
	local key = getMemberKey(player.UserId)
	local reputationGain = math.max(0, math.floor(tonumber(reputation) or 0))
	activity.Reputation[key] = (activity.Reputation[key] or 0) + reputationGain
	local playerData = PlayerDataModule.getData(player)
	activity.Bounties[key] = math.max(0, playerData and playerData.Bounty or 0)
	local stat = statByEvent[eventName]
	if stat then
		activity.Stats[stat] = (activity.Stats[stat] or 0) + 1
	end
	dirtyClans[clanId] = true
	local newReputation = PlayerDataModule.addClanReputation(player, reputationGain)
	player:SetAttribute("ClanReputation", newReputation)
	local cachedClan = clanCache[clanId]
	if cachedClan then
		cachedClan.Prestige = (cachedClan.Prestige or 0) + math.max(0, math.floor(tonumber(prestige) or 0))
		cachedClan.Stats = cachedClan.Stats or {}
		if stat then
			cachedClan.Stats[stat] = (cachedClan.Stats[stat] or 0) + 1
		end
		local member = cachedClan.Members and cachedClan.Members[key]
		if member then
			member.Reputation = newReputation
			member.Bounty = activity.Bounties[key]
		end
	end
	return true
end

-- selene: allow(global_usage)
shared.ClanService = ClanService

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("ClanId", "")
	player:SetAttribute("ClanName", "")
	player:SetAttribute("ClanReputation", 0)
	task.spawn(syncPlayerMembership, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(syncPlayerMembership, player)
end

Players.PlayerRemoving:Connect(function(player)
	local clanId = clanIdByPlayer[player]
	if clanId and dirtyClans[clanId] then
		task.spawn(flushActivity, clanId)
	end
	clanIdByPlayer[player] = nil
	pendingInvites[player] = nil
	actionTimestamps[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				player:SetAttribute("LobbyPosition", root.Position)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(ACTIVITY_FLUSH_INTERVAL)
		for clanId in dirtyClans do
			task.spawn(flushActivity, clanId)
		end
	end
end)

game:BindToClose(function()
	for clanId in dirtyClans do
		task.spawn(flushActivity, clanId)
	end
	task.wait(4)
end)

print("[ClanService] Loaded")
