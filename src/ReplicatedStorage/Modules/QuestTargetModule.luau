local QuestTargetModule = {}

function QuestTargetModule.getIncompleteEnemyType(objectives, progress)
	if type(objectives) ~= "table" then return nil end
	progress = type(progress) == "table" and progress or {}

	for index, objective in ipairs(objectives) do
		local required = math.max(0, tonumber(objective.required) or 0)
		local current = math.max(0, tonumber(progress[index]) or 0)
		if objective.type == "KillCount" and current < required then
			return objective.enemyType
		end
	end
	return nil
end

return QuestTargetModule
