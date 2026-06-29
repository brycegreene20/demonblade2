local MovementPhysicsModule = {}

function MovementPhysicsModule.getConfiguredJumpVelocity(useJumpPower, jumpPower, jumpHeight, gravity)
	if useJumpPower and (tonumber(jumpPower) or 0) > 0 then
		return jumpPower
	end

	local safeGravity = math.max(0, tonumber(gravity) or 0)
	local safeHeight = math.max(0, tonumber(jumpHeight) or 0)
	return math.sqrt(2 * safeGravity * safeHeight)
end

function MovementPhysicsModule.getRepeatJumpVelocity(
	useJumpPower,
	jumpPower,
	jumpHeight,
	gravity,
	observedGroundVelocity
)
	local configured = MovementPhysicsModule.getConfiguredJumpVelocity(
		useJumpPower,
		jumpPower,
		jumpHeight,
		gravity
	)
	return math.max(configured, tonumber(observedGroundVelocity) or 0)
end

return MovementPhysicsModule
