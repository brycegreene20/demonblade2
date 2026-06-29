local WorldSpawnConfigModule = {}

WorldSpawnConfigModule.DUMMY_GRID = {
	originX = 30,
	originZ = 28,
	columns = 4,
	rows = 3,
	spacing = 8,
}

WorldSpawnConfigModule.DEMON_GROUPS = {
	{ zone = "LowerSnowfield", level = 1, centerX = 78, centerZ = -55, count = 4 },
	{ zone = "WestSnowfield", level = 2, centerX = -72, centerZ = -72, count = 4 },
	{ zone = "EastSnowfield", level = 3, centerX = 108, centerZ = -110, count = 4 },
	{ zone = "FrozenPassWest", level = 4, centerX = -112, centerZ = -128, count = 3 },
	{ zone = "FrozenPassEast", level = 5, centerX = 148, centerZ = -158, count = 3 },
	{ zone = "UpperSnowfieldWest", level = 6, centerX = -152, centerZ = -180, count = 3 },
	{ zone = "UpperSnowfieldEast", level = 7, centerX = 180, centerZ = -210, count = 2 },
	{ zone = "MountainApproach", level = 8, centerX = -190, centerZ = -235, count = 2 },
}

WorldSpawnConfigModule.BOSS_SPAWN = {
	zone = "DemonBossArena",
	x = 300,
	z = -320,
	level = 12,
	boss = true,
}

local CLUSTER_OFFSETS = {
	{ x = -9, z = -8 },
	{ x = 9, z = -8 },
	{ x = -9, z = 8 },
	{ x = 9, z = 8 },
	{ x = 0, z = 0 },
}

function WorldSpawnConfigModule.getTrainingDummySpawns()
	local grid = WorldSpawnConfigModule.DUMMY_GRID
	local spawns = {}
	for row = 0, grid.rows - 1 do
		for column = 0, grid.columns - 1 do
			table.insert(spawns, {
				x = grid.originX + column * grid.spacing,
				z = grid.originZ + row * grid.spacing,
			})
		end
	end
	return spawns
end

function WorldSpawnConfigModule.getDemonSpawns()
	local spawns = {}
	for _, group in ipairs(WorldSpawnConfigModule.DEMON_GROUPS) do
		for index = 1, group.count do
			local offset = CLUSTER_OFFSETS[index]
			table.insert(spawns, {
				x = group.centerX + offset.x,
				z = group.centerZ + offset.z,
				level = group.level,
				zone = group.zone,
			})
		end
	end

	local boss = WorldSpawnConfigModule.BOSS_SPAWN
	table.insert(spawns, {
		x = boss.x,
		z = boss.z,
		level = boss.level,
		zone = boss.zone,
		boss = true,
	})
	return spawns
end

function WorldSpawnConfigModule.distanceBetween(left, right)
	local dx = left.x - right.x
	local dz = left.z - right.z
	return math.sqrt(dx * dx + dz * dz)
end

return WorldSpawnConfigModule
