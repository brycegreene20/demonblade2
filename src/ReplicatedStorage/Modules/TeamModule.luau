local TeamModule = {}

TeamModule.MAX_MEMBERS = 5
TeamModule.SHARE_RADIUS = 160
TeamModule.INVITE_TTL_SECONDS = 30

function TeamModule.canAddMember(currentMemberCount)
	return (tonumber(currentMemberCount) or 0) < TeamModule.MAX_MEMBERS
end

function TeamModule.isInShareRange(distance, radius)
	return (tonumber(distance) or math.huge) <= (radius or TeamModule.SHARE_RADIUS)
end

function TeamModule.canDamagePlayer(areTeammates)
	return areTeammates ~= true
end

function TeamModule.canRemoveMember(requesterIsLeader, targetIsLeader, sameTeam)
	return requesterIsLeader == true and targetIsLeader ~= true and sameTeam == true
end

return TeamModule
