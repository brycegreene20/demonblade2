local EnemyAIModule = {}

EnemyAIModule.DUMMY_MAX_HP = 500
EnemyAIModule.DUMMY_RESPAWN_TIME = 10

function EnemyAIModule.spawnDummy(_position)
	-- Create a training dummy at the given position with MaxHP
end

function EnemyAIModule.takeDamage(_dummy, _amount)
	-- Reduce dummy HP, trigger floating damage number, check death
end

function EnemyAIModule.onDummyDeath(_dummy)
	-- Play death animation, schedule respawn after DUMMY_RESPAWN_TIME
end

function EnemyAIModule.respawnDummy(_dummy)
	-- Reset dummy HP and position, re-enable collision
end

function EnemyAIModule.getDummyHP(_dummy)
	-- Return current HP of a dummy
end

return EnemyAIModule