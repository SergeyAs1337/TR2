local DataStoreService = game:GetService("DataStoreService")
local dailyDeathsStore = DataStoreService:GetDataStore("DailyDeaths")

-- Заменить UserId на нужный
local userIdToReset = 940118285 

local success, err = pcall(function()
	dailyDeathsStore:RemoveAsync(userIdToReset)
end)

if success then
	print("Данные игрока сброшены")
else
	warn("Ошибка при сбросе данных: "..tostring(err))
end
