local BountyModule = {}

BountyModule.PVP_KILL_BASE_GAIN = 25
BountyModule.PVP_STEAL_RATE = 0.10
BountyModule.PVP_MIN_LOSS = 10
BountyModule.PVP_DAMAGE_BONUS_PER_BOUNTY = 0.00005
BountyModule.PVP_DAMAGE_BONUS_CAP = 0.25

function BountyModule.getPvPDamageMultiplier(bounty)
	local numericBounty = math.max(0, tonumber(bounty) or 0)
	local bonus = math.min(numericBounty * BountyModule.PVP_DAMAGE_BONUS_PER_BOUNTY, BountyModule.PVP_DAMAGE_BONUS_CAP)
	return 1 + bonus
end

function BountyModule.calculatePvpTransfer(killerBounty, victimBounty)
	local killer = math.max(0, tonumber(killerBounty) or 0)
	local victim = math.max(0, tonumber(victimBounty) or 0)
	local victimStake = math.floor(victim * BountyModule.PVP_STEAL_RATE)
	local victimLoss = math.min(victim, math.max(BountyModule.PVP_MIN_LOSS, victimStake))
	local killerGain = BountyModule.PVP_KILL_BASE_GAIN + victimLoss

	return {
		KillerBounty = killer + killerGain,
		VictimBounty = math.max(0, victim - victimLoss),
		KillerGain = killerGain,
		VictimLoss = victimLoss,
	}
end

return BountyModule
