local QuestDataModule = {}

QuestDataModule.ObjectiveType = {
	KillCount = "KillCount",
	ReachLocation = "ReachLocation",
}

QuestDataModule.Quests = {
	{
		id = "sv_01",
		title = "First Blood",
		description = "The training dummies won't fight back... probably. Destroy one to prove your worth.",
		npcId = "QuestNPC_Elder",
		zone = "StarterVillage",
		requiredLevel = 1,
		xpReward = 50,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "KillCount",
				enemyType = "TrainingDummy",
				label = "Destroy a Training Dummy",
				required = 1,
			},
		},
	},
	{
		id = "sv_02",
		title = "Dummy Demolisher",
		description = "One dummy down, but can you handle more? Show your combat skills by destroying three dummies.",
		npcId = "QuestNPC_Elder",
		zone = "StarterVillage",
		requiredLevel = 1,
		prerequisite = "sv_01",
		xpReward = 120,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "KillCount",
				enemyType = "TrainingDummy",
				label = "Destroy Training Dummies",
				required = 3,
			},
		},
	},
	{
		id = "sv_03",
		title = "Village Explorer",
		description = "The village has many landmarks. Find the bridge to the east to learn the lay of the land.",
		npcId = "QuestNPC_Scout",
		zone = "StarterVillage",
		requiredLevel = 1,
		xpReward = 75,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "ReachLocation",
				partName = "QuestLocation_Bridge",
				label = "Find the Bridge",
				required = 1,
			},
		},
	},
	{
		id = "sv_04",
		title = "Into the Woods",
		description = "Brave souls venture beyond the village. Find the forest entrance and report back what you see.",
		npcId = "QuestNPC_Scout",
		zone = "StarterVillage",
		requiredLevel = 2,
		prerequisite = "sv_03",
		xpReward = 100,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "ReachLocation",
				partName = "QuestLocation_ForestEntrance",
				label = "Reach the Forest Entrance",
				required = 1,
			},
		},
	},
	{
		id = "sv_05",
		title = "Endurance Training",
		description = "The Elder wants to see true dedication. Destroy five training dummies in a row to earn his respect.",
		npcId = "QuestNPC_Elder",
		zone = "StarterVillage",
		requiredLevel = 3,
		prerequisite = "sv_02",
		xpReward = 200,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "KillCount",
				enemyType = "TrainingDummy",
				label = "Destroy Training Dummies",
				required = 5,
			},
		},
	},
}

local questLookup = {}
for _, quest in QuestDataModule.Quests do
	questLookup[quest.id] = quest
end

function QuestDataModule.getQuest(questId)
	return questLookup[questId]
end

function QuestDataModule.getQuestsForNPC(npcId)
	local quests = {}
	for _, quest in QuestDataModule.Quests do
		if quest.npcId == npcId then
			table.insert(quests, quest)
		end
	end
	return quests
end

function QuestDataModule.getQuestsForZone(zoneName)
	local quests = {}
	for _, quest in QuestDataModule.Quests do
		if quest.zone == zoneName then
			table.insert(quests, quest)
		end
	end
	return quests
end

function QuestDataModule.createActiveQuestState(questId)
	local quest = questLookup[questId]
	if not quest then return nil end
	local progress = {}
	for i, _obj in quest.objectives do
		progress[i] = 0
	end
	return {
		questId = questId,
		progress = progress,
		completed = false,
	}
end

function QuestDataModule.isObjectiveComplete(quest, objectiveIndex, progress)
	local obj = quest.objectives[objectiveIndex]
	if not obj then return false end
	return (progress[objectiveIndex] or 0) >= obj.required
end

function QuestDataModule.areAllObjectivesComplete(quest, progress)
	for i, obj in quest.objectives do
		if (progress[i] or 0) < obj.required then
			return false
		end
	end
	return true
end

return QuestDataModule