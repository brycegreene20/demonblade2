local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TeamInviteRemote = Remotes:WaitForChild("TeamInvite")
local TeamInviteResponseRemote = Remotes:WaitForChild("TeamInviteResponse")
local TeamLeaveRemote = Remotes:WaitForChild("TeamLeave")
local TeamUpdateRemote = Remotes:WaitForChild("TeamUpdate")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TeamModule = require(Modules:WaitForChild("TeamModule"))

local teamsByLeader = {}
local leaderByPlayer = {}
local pendingInvites = {}

local function getLeader(player)
	return leaderByPlayer[player] or player
end

local function getTeam(player)
	return teamsByLeader[getLeader(player)]
end

local function ensureTeam(player)
	local leader = getLeader(player)
	local team = teamsByLeader[leader]
	if not team then
		team = {
			Leader = leader,
			Members = { leader },
		}
		teamsByLeader[leader] = team
		leaderByPlayer[leader] = leader
	end
	return team
end

local function makeMemberPayload(team)
	local members = {}
	for _, member in team.Members do
		if member.Parent then
			table.insert(members, {
				UserId = member.UserId,
				Name = member.Name,
				DisplayName = member.DisplayName,
				IsLeader = member == team.Leader,
			})
		end
	end
	return members
end

local function sendUpdate(player, message, extraPayload)
	if not player or not player.Parent then return end
	local team = getTeam(player)
	local payload = {
		Members = team and makeMemberPayload(team) or {},
		MaxMembers = TeamModule.MAX_MEMBERS,
		Message = message,
	}
	for key, value in extraPayload or {} do
		payload[key] = value
	end
	TeamUpdateRemote:FireClient(player, payload)
end

local function broadcastTeam(team, message)
	for _, member in team.Members do
		if member.Parent then
			sendUpdate(member, message)
		end
	end
end

local function removeFromTeam(player, message)
	local leader = leaderByPlayer[player]
	if not leader then
		sendUpdate(player, message)
		return
	end

	local team = teamsByLeader[leader]
	if not team then
		leaderByPlayer[player] = nil
		sendUpdate(player, message)
		return
	end

	for index, member in team.Members do
		if member == player then
			table.remove(team.Members, index)
			break
		end
	end
	leaderByPlayer[player] = nil

	if #team.Members <= 1 then
		for _, member in team.Members do
			leaderByPlayer[member] = nil
			sendUpdate(member, "Team disbanded")
		end
		teamsByLeader[leader] = nil
		sendUpdate(player, message)
		return
	end

	if player == team.Leader then
		local newLeader = team.Members[1]
		teamsByLeader[leader] = nil
		team.Leader = newLeader
		teamsByLeader[newLeader] = team
		for _, member in team.Members do
			leaderByPlayer[member] = newLeader
		end
	end

	broadcastTeam(team, message or (player.DisplayName .. " left the team"))
	sendUpdate(player, message)
end

local function cleanupExpiredInvites(targetPlayer)
	local invites = pendingInvites[targetPlayer]
	if not invites then return end
	local now = os.clock()
	for inviter, invite in invites do
		if now - invite.CreatedAt > TeamModule.INVITE_TTL_SECONDS then
			invites[inviter] = nil
		end
	end
end

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function areWithinShareRange(anchorPlayer, otherPlayer, radius)
	local anchorRoot = getPlayerRoot(anchorPlayer)
	local otherRoot = getPlayerRoot(otherPlayer)
	if not anchorRoot or not otherRoot then return false end
	return TeamModule.isInShareRange((anchorRoot.Position - otherRoot.Position).Magnitude, radius)
end

local function getNearbyTeamMembers(player, radius)
	local team = getTeam(player)
	if not team then
		return {}
	end

	local result = {}
	for _, member in team.Members do
		if member ~= player and member.Parent and areWithinShareRange(player, member, radius) then
			table.insert(result, member)
		end
	end
	return result
end

TeamInviteRemote.OnServerEvent:Connect(function(player, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target or target == player then
		sendUpdate(player, "Invite failed: player not found")
		return
	end

	local team = ensureTeam(player)
	if not TeamModule.canAddMember(#team.Members) then
		sendUpdate(player, "Team is full")
		return
	end
	if leaderByPlayer[target] then
		sendUpdate(player, target.DisplayName .. " is already in a team")
		return
	end

	pendingInvites[target] = pendingInvites[target] or {}
	local createdAt = os.clock()
	pendingInvites[target][player] = { CreatedAt = createdAt }

	TeamUpdateRemote:FireClient(target, {
		Members = getTeam(target) and makeMemberPayload(getTeam(target)) or {},
		MaxMembers = TeamModule.MAX_MEMBERS,
		Invite = {
			UserId = player.UserId,
			Name = player.Name,
			DisplayName = player.DisplayName,
			ExpiresIn = TeamModule.INVITE_TTL_SECONDS,
		},
		Message = player.DisplayName .. " invited you to a team",
	})
	sendUpdate(player, "Invite sent to " .. target.DisplayName, {
		InviteSent = {
			UserId = target.UserId,
			DisplayName = target.DisplayName,
			ExpiresIn = TeamModule.INVITE_TTL_SECONDS,
		},
	})
	task.delay(TeamModule.INVITE_TTL_SECONDS, function()
		local invites = pendingInvites[target]
		local invite = invites and invites[player]
		if not invite or invite.CreatedAt ~= createdAt then return end
		invites[player] = nil
		sendUpdate(target, "Team invite from " .. player.DisplayName .. " expired", {
			InviteExpired = { UserId = player.UserId },
		})
		sendUpdate(player, "Invite to " .. target.DisplayName .. " expired", {
			InviteResolved = { UserId = target.UserId },
		})
	end)
	print("[TeamService] " .. player.Name .. " invited " .. target.Name .. " to a team")
end)

TeamInviteResponseRemote.OnServerEvent:Connect(function(player, inviterUserId, accepted)
	cleanupExpiredInvites(player)
	local inviter = Players:GetPlayerByUserId(tonumber(inviterUserId) or 0)
	local invites = pendingInvites[player]
	if not inviter or not invites or not invites[inviter] then
		sendUpdate(player, "Invite expired")
		return
	end
	invites[inviter] = nil

	if not accepted then
		sendUpdate(player, "Invite declined")
		sendUpdate(inviter, player.DisplayName .. " declined the team invite", {
			InviteResolved = { UserId = player.UserId },
		})
		return
	end

	local team = ensureTeam(inviter)
	if not TeamModule.canAddMember(#team.Members) then
		sendUpdate(player, "Team is full")
		sendUpdate(inviter, "Team is full")
		return
	end
	if leaderByPlayer[player] then
		sendUpdate(player, "You are already in a team")
		return
	end

	table.insert(team.Members, player)
	leaderByPlayer[player] = team.Leader
	broadcastTeam(team, player.DisplayName .. " joined the team")
	sendUpdate(inviter, player.DisplayName .. " joined the team", {
		InviteResolved = { UserId = player.UserId },
	})
	print("[TeamService] " .. player.Name .. " joined " .. team.Leader.Name .. "'s team")
end)

TeamLeaveRemote.OnServerEvent:Connect(function(player)
	removeFromTeam(player, "You left the team")
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		sendUpdate(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local receivedInvites = pendingInvites[player]
	if receivedInvites then
		for inviter in receivedInvites do
			sendUpdate(inviter, player.DisplayName .. " left the server", {
				InviteResolved = { UserId = player.UserId },
			})
		end
	end
	pendingInvites[player] = nil
	for target, invites in pendingInvites do
		if invites[player] then
			invites[player] = nil
			sendUpdate(target, "Team invite expired", {
				InviteExpired = { UserId = player.UserId },
			})
		end
	end
	removeFromTeam(player)
end)

local TeamService = {}

function TeamService.getNearbyTeamMembers(player, radius)
	return getNearbyTeamMembers(player, radius)
end

function TeamService.areTeammates(a, b)
	return a ~= nil and b ~= nil and a ~= b and leaderByPlayer[a] ~= nil and leaderByPlayer[a] == leaderByPlayer[b]
end

-- selene: allow(global_usage)
shared.TeamService = TeamService

print("[TeamService] Loaded")
