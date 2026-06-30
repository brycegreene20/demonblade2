local WorldSpawnConfigModule = {}

WorldSpawnConfigModule.DUMMY_GRID = {
	originX = 275.555,
	originZ = -27.898,
	columns = 4,
	rows = 3,
	spacing = 9,
}

WorldSpawnConfigModule.SAFE_ZONE = {
	center = Vector3.new(264.982, 46.078, -140.58),
	size = Vector3.new(96, 18, 96),
	spawnOffset = Vector3.new(0, 5, 0),
}

WorldSpawnConfigModule.NPC_SPAWNS = {
	QuestNPC_Elder = {
		position = Vector3.new(291.339, 45.817, -120.274),
		facingAngle = 0,
	},
	QuestNPC_Officer = {
		position = Vector3.new(275.072, 45.817, -122.065),
		facingAngle = 0,
	},
	QuestNPC_Scout = {
		position = Vector3.new(280.745, 45.817, -111.636),
		facingAngle = 0,
	},
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

WorldSpawnConfigModule.FROST_DEMON_GROUPS = {
	{ zone = "FrostOutskirts", level = 3, centerX = -210, centerZ = 95, count = 3 },
	{ zone = "FrostRidge", level = 4, centerX = -265, centerZ = 55, count = 3 },
	{ zone = "FrozenLakeWest", level = 5, centerX = -315, centerZ = 5, count = 3 },
	{ zone = "FrostPines", level = 6, centerX = -360, centerZ = -55, count = 3 },
	{ zone = "BlizzardPass", level = 7, centerX = -410, centerZ = -120, count = 3 },
	{ zone = "FrostCavernApproach", level = 8, centerX = -455, centerZ = -190, count = 2 },
}

WorldSpawnConfigModule.FROST_BOSS_SPAWN = {
	zone = "FrostDemonBossArena",
	x = -620,
	z = -360,
	level = 14,
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

function WorldSpawnConfigModule.getSafeZoneCenter()
	return WorldSpawnConfigModule.SAFE_ZONE.center
end

function WorldSpawnConfigModule.getSafeZoneSize()
	return WorldSpawnConfigModule.SAFE_ZONE.size
end

function WorldSpawnConfigModule.getSafeSpawnCFrame()
	local safeZone = WorldSpawnConfigModule.SAFE_ZONE
	return CFrame.new(safeZone.center + safeZone.spawnOffset)
end

function WorldSpawnConfigModule.getNPCSpawn(npcId)
	return WorldSpawnConfigModule.NPC_SPAWNS[npcId]
end

local function appendGroupedSpawns(spawns, groups)
	for _, group in ipairs(groups) do
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
end

function WorldSpawnConfigModule.getDemonSpawns()
	local spawns = {}
	appendGroupedSpawns(spawns, WorldSpawnConfigModule.DEMON_GROUPS)

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

function WorldSpawnConfigModule.getFrostDemonSpawns()
	local spawns = {}
	appendGroupedSpawns(spawns, WorldSpawnConfigModule.FROST_DEMON_GROUPS)

	local boss = WorldSpawnConfigModule.FROST_BOSS_SPAWN
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
