local QuestDataModule = {}

QuestDataModule.ObjectiveType = {
	KillCount = "KillCount",
	ReachLocation = "ReachLocation",
}

QuestDataModule.Quests = {
	{
		id = "train_01",
		title = "First Strike",
		description = "Destroy one training dummy for Urokodaki.",
		npcId = "QuestNPC_Elder",
		zone = "StarterVillage",
		requiredLevel = 1,
		xpReward = 50,
		masteryXPReward = 10,
		titleXPReward = 8,
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
		id = "train_02",
		title = "Dummy Demolisher",
		description = "Destroy three training dummies for Urokodaki.",
		npcId = "QuestNPC_Elder",
		zone = "StarterVillage",
		requiredLevel = 1,
		prerequisite = "train_01",
		xpReward = 120,
		masteryXPReward = 25,
		titleXPReward = 18,
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
		id = "train_03",
		title = "Endurance Training",
		description = "Destroy five training dummies in one assignment.",
		npcId = "QuestNPC_Elder",
		zone = "StarterVillage",
		requiredLevel = 3,
		prerequisite = "train_02",
		xpReward = 200,
		masteryXPReward = 45,
		titleXPReward = 30,
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
	{
		id = "demon_01",
		title = "First Demon Hunt",
		description = "Defeat one forest demon for the Corps Officer.",
		npcId = "QuestNPC_Officer",
		zone = "StarterVillage",
		requiredLevel = 1,
		xpReward = 90,
		masteryXPReward = 20,
		titleXPReward = 15,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "KillCount",
				enemyType = "ForestDemon",
				label = "Defeat a Forest Demon",
				required = 1,
			},
		},
	},
	{
		id = "demon_02",
		title = "Night Patrol",
		description = "Defeat three forest demons for the Corps Officer.",
		npcId = "QuestNPC_Officer",
		zone = "StarterVillage",
		requiredLevel = 2,
		prerequisite = "demon_01",
		xpReward = 180,
		masteryXPReward = 45,
		titleXPReward = 30,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "KillCount",
				enemyType = "ForestDemon",
				label = "Defeat Forest Demons",
				required = 3,
			},
		},
	},
	{
		id = "demon_boss_01",
		title = "The Great Demon",
		description = "Defeat the Demon Boss for the Corps Officer.",
		npcId = "QuestNPC_Officer",
		zone = "StarterVillage",
		requiredLevel = 5,
		prerequisite = "demon_02",
		xpReward = 600,
		masteryXPReward = 150,
		titleXPReward = 100,
		repeatable = true,
		repeatCooldown = 0,
		objectives = {
			{
				type = "KillCount",
				enemyType = "DemonBoss",
				label = "Defeat the Demon Boss",
				required = 1,
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

function QuestDataModule.getProgressionRewards(quest)
	if not quest then
		return { XP = 0, MasteryXP = 0, TitleXP = 0 }
	end
	return {
		XP = math.max(0, tonumber(quest.xpReward) or 0),
		MasteryXP = math.max(0, tonumber(quest.masteryXPReward) or 0),
		TitleXP = math.max(0, tonumber(quest.titleXPReward) or 0),
	}
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
