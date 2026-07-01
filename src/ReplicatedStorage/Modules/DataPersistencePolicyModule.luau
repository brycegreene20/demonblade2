local DataPersistencePolicyModule = {}

DataPersistencePolicyModule.AUTO_SAVE_INTERVAL = 60
DataPersistencePolicyModule.MAX_RETRIES = 3
DataPersistencePolicyModule.BASE_RETRY_DELAY = 1
DataPersistencePolicyModule.MIN_WRITE_INTERVAL = 6

function DataPersistencePolicyModule.canWrite(loadSucceeded)
	return loadSucceeded == true
end

function DataPersistencePolicyModule.copySnapshot(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[DataPersistencePolicyModule.copySnapshot(key)] = DataPersistencePolicyModule.copySnapshot(child)
	end
	return copy
end

return DataPersistencePolicyModule
