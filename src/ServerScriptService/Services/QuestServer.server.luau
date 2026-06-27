local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AcceptQuestRemote = Remotes:WaitForChild("AcceptQuest")
local QuestUpdatedRemote = Remotes:WaitForChild("QuestUpdated")
local QuestCompletedRemote = Remotes:WaitForChild("QuestCompleted")
local GetAvailableQuestsRemote = Remotes:WaitForChild("GetAvailableQuests")
local QuestCompletedToastRemote = Remotes:WaitForChild("QuestCompletedToast")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local QuestDataModule = require(Modules:WaitForChild("QuestDataModule"))
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))

local playerQuests = {}

local function getPlayerQuestState(player)
	if not playerQuests[player] then
		playerQuests[player] = {
			activeQuest = nil,
			completedQuests = {},
		}
	end
	return playerQuests[player]
end

local function isQuestCompleted(state, questId)
	return state.completedQuests[questId] ~= nil
end

local function isRepeatAvailable(state, quest)
	if not quest.repeatable then return false end
	local completion = state.completedQuests[quest.id]
	return completion ~= nil
end

local function getCompletionData(state, questId)
	return state.completedQuests[questId]
end

local function hasCompletedQuest(state, questId)
	return state.completedQuests[questId] ~= nil
end

local function canAcceptQuest(player, questId)
	local state = getPlayerQuestState(player)
	local quest = QuestDataModule.getQuest(questId)
	if not quest then return false, "Quest not found" end

	if state.activeQuest and state.activeQuest.questId == questId then
		return false, "Quest already active"
	end

	local completed = isQuestCompleted(state, questId)

	if completed then
		if not quest.repeatable then
			return false, "Quest already completed"
		end
	end

	local data = PlayerDataModule.getData(player)
	if not data then return false, "No player data" end

	if quest.requiredLevel and data.Level < quest.requiredLevel then
		return false, "Level too low"
	end

	if quest.prerequisite then
		if not hasCompletedQuest(state, quest.prerequisite) then
			return false, "Prerequisite not met"
		end
	end

	return true
end

local function acceptQuest(player, questId)
	local ok, err = canAcceptQuest(player, questId)
	if not ok then
		warn("[QuestServer] " .. player.Name .. " cannot accept " .. questId .. ": " .. err)
		return false
	end

	local state = getPlayerQuestState(player)
	state.activeQuest = QuestDataModule.createActiveQuestState(questId)

	local quest = QuestDataModule.getQuest(questId)
	local completion = getCompletionData(state, questId)
	local isRepeat = completion ~= nil

	QuestUpdatedRemote:FireClient(player, {
		questId = questId,
		title = (isRepeat and "↺ " or "") .. quest.title,
		objectives = quest.objectives,
		progress = state.activeQuest.progress,
		completed = false,
	})

	print("[QuestServer] " .. player.Name .. " accepted quest: " .. quest.title .. (isRepeat and " (repeat)" or ""))
	return true
end

local function completeQuest(player)
	local state = getPlayerQuestState(player)
	if not state.activeQuest then return end

	local questId = state.activeQuest.questId
	local quest = QuestDataModule.getQuest(questId)
	if not quest then return end

	if not QuestDataModule.areAllObjectivesComplete(quest, state.activeQuest.progress) then
		return
	end

	local prev = state.completedQuests[questId]
	local timesCompleted = (prev and prev.timesCompleted or 0) + 1

	state.completedQuests[questId] = {
		completedAt = os.time(),
		timesCompleted = timesCompleted,
	}

	state.activeQuest = nil

	local rewards = QuestDataModule.getProgressionRewards(quest)
	PlayerDataModule.addXP(player, rewards.XP)
	local data = PlayerDataModule.getData(player)
	if data and data.EquippedStyle and data.EquippedStyle ~= "" and rewards.MasteryXP > 0 then
		PlayerDataModule.addMasteryXP(player, data.EquippedStyle, rewards.MasteryXP)
	end
	if data and data.EquippedTitle and data.EquippedTitle ~= "" and rewards.TitleXP > 0 then
		PlayerDataModule.addTitleXP(player, data.EquippedTitle, rewards.TitleXP)
	end

	QuestCompletedRemote:FireClient(player, {
		questId = questId,
		title = quest.title,
		xpReward = rewards.XP,
		masteryXPReward = rewards.MasteryXP,
		titleXPReward = rewards.TitleXP,
		timesCompleted = timesCompleted,
		repeatable = quest.repeatable or false,
	})

	if quest.repeatable then
		QuestCompletedToastRemote:FireClient(player, {
			questId = questId,
			title = quest.title,
			xpReward = rewards.XP,
			masteryXPReward = rewards.MasteryXP,
			titleXPReward = rewards.TitleXP,
			isRepeatable = true,
		})
	end

	print(
		"[QuestServer] "
			.. player.Name
			.. " completed quest: "
			.. quest.title
			.. " (+"
			.. rewards.XP
			.. " XP, +"
			.. rewards.MasteryXP
			.. " mastery, +"
			.. rewards.TitleXP
			.. " title XP, x"
			.. timesCompleted
			.. ")"
	)
end

local function advanceKillObjective(player, enemyType)
	local state = playerQuests[player]
	if not state or not state.activeQuest then return end

	local quest = QuestDataModule.getQuest(state.activeQuest.questId)
	if not quest then return end

	local changed = false
	for i, obj in quest.objectives do
		if obj.type == "KillCount" and obj.enemyType == enemyType then
			local current = state.activeQuest.progress[i] or 0
			if current < obj.required then
				state.activeQuest.progress[i] = current + 1
				changed = true
			end
		end
	end

	if changed then
		QuestUpdatedRemote:FireClient(player, {
			questId = state.activeQuest.questId,
			title = quest.title,
			objectives = quest.objectives,
			progress = state.activeQuest.progress,
			completed = false,
		})

		if QuestDataModule.areAllObjectivesComplete(quest, state.activeQuest.progress) then
			completeQuest(player)
		end
	end
end

local function advanceReachObjective(player, partName)
	local state = playerQuests[player]
	if not state or not state.activeQuest then return end

	local quest = QuestDataModule.getQuest(state.activeQuest.questId)
	if not quest then return end

	local changed = false
	for i, obj in quest.objectives do
		if obj.type == "ReachLocation" and obj.partName == partName then
			local current = state.activeQuest.progress[i] or 0
			if current < obj.required then
				state.activeQuest.progress[i] = 1
				changed = true
			end
		end
	end

	if changed then
		QuestUpdatedRemote:FireClient(player, {
			questId = state.activeQuest.questId,
			title = quest.title,
			objectives = quest.objectives,
			progress = state.activeQuest.progress,
			completed = false,
		})

		if QuestDataModule.areAllObjectivesComplete(quest, state.activeQuest.progress) then
			completeQuest(player)
		end
	end
end

AcceptQuestRemote.OnServerEvent:Connect(function(player, questId)
	if typeof(questId) ~= "string" then return end
	acceptQuest(player, questId)
end)

GetAvailableQuestsRemote.OnServerInvoke = function(player, npcId)
	if typeof(npcId) ~= "string" then return {} end

	local state = getPlayerQuestState(player)
	local npcQuests = QuestDataModule.getQuestsForNPC(npcId)
	local available = {}

	for _, quest in npcQuests do
		local completed = isQuestCompleted(state, quest.id)
		local isActive = state.activeQuest and state.activeQuest.questId == quest.id
		local repeatReady = completed and isRepeatAvailable(state, quest)
		local canAccept, reason = canAcceptQuest(player, quest.id)

		local status
		local cooldownText = nil
		if isActive then
			status = "active"
		elseif repeatReady or canAccept then
			status = "available"
		elseif completed then
			status = "completed"
		else
			status = "locked"
		end

		local completion = getCompletionData(state, quest.id)
		local displayTitle = quest.title
		if repeatReady then
			displayTitle = "↺ " .. quest.title
		end

		table.insert(available, {
			id = quest.id,
			title = displayTitle,
			description = quest.description,
			xpReward = quest.xpReward,
			masteryXPReward = quest.masteryXPReward or 0,
			titleXPReward = quest.titleXPReward or 0,
			requiredLevel = quest.requiredLevel,
			objectives = quest.objectives,
			status = status,
			lockReason = (status == "locked") and reason or nil,
			repeatable = quest.repeatable or false,
			timesCompleted = completion and completion.timesCompleted or 0,
			cooldownText = cooldownText,
		})
	end

	return available
end

local function setupLocationTriggers()
	local locationParts = {}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name:match("^QuestLocation_") then
			table.insert(locationParts, descendant)
		end
	end

	for _, part in locationParts do
		part.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end
			advanceReachObjective(player, part.Name)
		end)
	end

	print("[QuestServer] Setup " .. #locationParts .. " location triggers")
end

local function onEnemyKilled(attackerPlayer, enemyType)
	if not attackerPlayer then return end
	advanceKillObjective(attackerPlayer, enemyType)
end

local _G_QuestServer = {}
_G_QuestServer.onEnemyKilled = onEnemyKilled
-- selene: allow(global_usage)
shared.QuestServer = _G_QuestServer

Players.PlayerRemoving:Connect(function(player)
	playerQuests[player] = nil
end)

setupLocationTriggers()

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") and descendant.Name:match("^QuestLocation_") then
		task.defer(function()
			descendant.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				if not character then return end
				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end
				advanceReachObjective(player, descendant.Name)
			end)
			print("[QuestServer] Registered late location trigger: " .. descendant.Name)
		end)
	end
end)

print("[QuestServer] Loaded")
