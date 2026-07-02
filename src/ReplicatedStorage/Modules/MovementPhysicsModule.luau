local MovementPhysicsModule = {}

MovementPhysicsModule.REPEAT_JUMP_BOOST_PER_JUMP = 0.12
MovementPhysicsModule.MAX_REPEAT_JUMP_BOOST = 0.48

function MovementPhysicsModule.getDashStopDistance(hitDistance, wallOffset)
	return math.max(0, (tonumber(hitDistance) or 0) - math.max(0, tonumber(wallOffset) or 0))
end

function MovementPhysicsModule.getConfiguredJumpVelocity(useJumpPower, jumpPower, jumpHeight, gravity)
	if useJumpPower and (tonumber(jumpPower) or 0) > 0 then
		return jumpPower
	end

	local safeGravity = math.max(0, tonumber(gravity) or 0)
	local safeHeight = math.max(0, tonumber(jumpHeight) or 0)
	return math.sqrt(2 * safeGravity * safeHeight)
end

function MovementPhysicsModule.getRepeatJumpMultiplier(jumpIndex)
	local safeJumpIndex = math.max(0, math.floor(tonumber(jumpIndex) or 0))
	local boost = math.min(
		MovementPhysicsModule.MAX_REPEAT_JUMP_BOOST,
		safeJumpIndex * MovementPhysicsModule.REPEAT_JUMP_BOOST_PER_JUMP
	)
	return 1 + boost
end

function MovementPhysicsModule.getRepeatJumpVelocity(
	useJumpPower,
	jumpPower,
	jumpHeight,
	gravity,
	observedGroundVelocity,
	jumpIndex
)
	local configured = MovementPhysicsModule.getConfiguredJumpVelocity(
		useJumpPower,
		jumpPower,
		jumpHeight,
		gravity
	)
	local baseVelocity = math.max(configured, tonumber(observedGroundVelocity) or 0)
	return baseVelocity * MovementPhysicsModule.getRepeatJumpMultiplier(jumpIndex)
end

return MovementPhysicsModule
