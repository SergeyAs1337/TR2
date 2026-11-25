-- ОДНОРАЗОВЫЙ перенос старых данных в новую таблицу лидеров (OrderedDataStore).
-- НЕ кладите этот файл в игру. Запустите один раз в Roblox Studio:
--   1. Опубликованное место, включено Game Settings -> Security -> "Enable Studio Access to API Services".
--   2. Вставьте скрипт в Command Bar (View -> Command Bar) и нажмите Enter.
--   3. Ждите строку "ГОТОВО". Скрипт идёт в пределах лимитов DataStore, это МЕДЛЕННО:
--      около 60-70 игроков в минуту. Можно прерывать и запускать заново: повторы безопасны.
-- Реальные игроки не пострадают: скрипт только читает сохранения и пишет в таблицу лидеров.

local DataStoreService = game:GetService("DataStoreService")

local seenStore = DataStoreService:GetDataStore("SeenPlayersV1")
local statsStore = DataStoreService:GetDataStore("PlayerStatsDataStoreV1")
local board = DataStoreService:GetOrderedDataStore("DeathsLeaderboardV1")

local function waitForBudget(requestType)
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 do
		task.wait(1)
	end
end

local ok, ids = pcall(function()
	return seenStore:GetAsync("AllPlayers")
end)
if not ok or typeof(ids) ~= "table" then
	error("Не удалось прочитать список AllPlayers: " .. tostring(ids))
end

print("Игроков в списке:", #ids)
local written, skipped, failed = 0, 0, 0

for i, userId in ids do
	if typeof(userId) ~= "number" or userId <= 0 then
		skipped += 1
	else
		waitForBudget(Enum.DataStoreRequestType.GetAsync)
		local okGet, data = pcall(function()
			return statsStore:GetAsync("Player_" .. userId)
		end)

		if not okGet then
			failed += 1
		elseif typeof(data) == "table" and typeof(data.Deaths) == "number" and data.Deaths >= 1 then
			waitForBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)
			local okSet = pcall(function()
				board:SetAsync(tostring(userId), math.floor(data.Deaths))
			end)
			if okSet then
				written += 1
			else
				failed += 1
			end
		else
			skipped += 1
		end
	end

	if i % 100 == 0 then
		print(("Обработано %d / %d (записано %d, пропущено %d, ошибок %d)"):format(i, #ids, written, skipped, failed))
	end
end

print(("ГОТОВО. Записано %d, пропущено %d, ошибок %d. Если ошибок > 0, запустите скрипт ещё раз."):format(written, skipped, failed))
