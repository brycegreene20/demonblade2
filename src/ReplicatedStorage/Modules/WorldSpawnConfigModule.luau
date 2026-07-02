local WorldSpawnConfigModule = {}

WorldSpawnConfigModule.DUMMY_GRID = {
	originX = 291.286,
	originZ = -25.608,
	columns = 4,
	rows = 3,
	spacing = 9,
	useMarkerOverride = false,
}

WorldSpawnConfigModule.TRAINING_DUMMY_AREAS = {
	{
		name = "NorthTrainingGround",
		centerX = 291.286,
		centerZ = -25.608,
		columns = 3,
		rows = 2,
		spacing = 9,
	},
	{
		name = "EastTrainingGround",
		centerX = 368.224,
		centerZ = -139.176,
		columns = 3,
		rows = 2,
		spacing = 9,
	},
}

WorldSpawnConfigModule.SAFE_ZONE = {
	center = Vector3.new(264.982, 46.078, -140.58),
	size = Vector3.new(128, 18, 128),
	spawnOffset = Vector3.new(0, 5, 0),
	bubbleCenterGroundOffset = 0,
}

WorldSpawnConfigModule.DEMON_EXCLUSION_ZONES = {
	{
		name = "StarterTrainingYard",
		centerX = 278.982,
		centerZ = -126.58,
		radius = 85,
	},
	{
		name = "NorthTrainingDummy",
		centerX = 291.286,
		centerZ = -25.608,
		radius = 45,
	},
	{
		name = "EastTrainingDummy",
		centerX = 368.224,
		centerZ = -139.176,
		radius = 45,
	},
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
	{ zone = "ForestHollowWest", level = 4, centerX = -82.509, centerZ = 121.252, count = 3 },
	{ zone = "ForestHollowEast", level = 5, centerX = 84.97, centerZ = 257.62, count = 3 },
	{ zone = "ForestHollowNorth", level = 6, centerX = -142.973, centerZ = 188.376, count = 3 },
}

WorldSpawnConfigModule.BOSS_SPAWN = {
	zone = "DemonBossArena",
	x = -393.923,
	z = -337.774,
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
	{ zone = "DeepSnowfield", level = 8, centerX = -343.46, centerZ = 575.479, count = 4 },
}

WorldSpawnConfigModule.FROST_BOSS_SPAWN = {
	zone = "FrostDemonBossArena",
	x = -848.917,
	z = 51.089,
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
	local spawns = {}
	for _, area in ipairs(WorldSpawnConfigModule.TRAINING_DUMMY_AREAS) do
		local startX = area.centerX - ((area.columns - 1) * area.spacing) * 0.5
		local startZ = area.centerZ - ((area.rows - 1) * area.spacing) * 0.5
		for row = 0, area.rows - 1 do
			for column = 0, area.columns - 1 do
				table.insert(spawns, {
					x = startX + column * area.spacing,
					z = startZ + row * area.spacing,
					area = area.name,
				})
			end
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

function WorldSpawnConfigModule.getDemonExclusionZone(x, z)
	for _, zone in ipairs(WorldSpawnConfigModule.DEMON_EXCLUSION_ZONES) do
		local dx = x - zone.centerX
		local dz = z - zone.centerZ
		if dx * dx + dz * dz <= zone.radius * zone.radius then
			return zone
		end
	end
	return nil
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
