-- ServerScriptService/LeaderBoard.lua  (v2.1, топ-1000)
-- Топ игроков по смертям из OrderedDataStore. Данные пишет LeaderboardManager.lua.
--
-- Как это укладывается в лимиты DataStore:
--  * GetSortedAsync отдаёт максимум 100 записей, поэтому 1000 строк = 10 запросов
--    (страницы читаются по очереди, с ожиданием бюджета запросов);
--  * имена игроков запрашиваются пачками через UserService и кэшируются,
--    а не по одному GetNameFromUserIdAsync на каждого;
--  * обновление раз в 3 минуты; если чтение сломалось на полпути, старая таблица остаётся как есть.

local UPDATE_PERIOD = 180 -- секунд между обновлениями
local MAX_ROWS = 1000
local PAGE_SIZE = 100 -- максимум для GetSortedAsync
local NAME_BATCH = 50 -- сколько имён просим за один вызов UserService
local BOARD_NAME = "DeathsLeaderboardV1" -- тот же, что в LeaderboardManager.lua

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UserService = game:GetService("UserService")

local deathsBoard = DataStoreService:GetOrderedDataStore(BOARD_NAME)

local board = workspace:WaitForChild("topdeath"):WaitForChild("Top_Deaths"):WaitForChild("DeathsLeaderboard")
local gui = board:WaitForChild("SurfaceGui")
local frame = gui:WaitForChild("ScrollingFrame")
local template = frame:WaitForChild("Template")

-- Высоту прокрутки считает клиент сам (на сервере AbsoluteContentSize не считается)
frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
frame.CanvasSize = UDim2.new()

local usernameCache = {}
local rowLabels = {} -- надписи переиспользуются, поэтому клиентам уходят только изменения текста
local emptyLabel = nil

local function waitForBudget(requestType)
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 do
		task.wait(2)
	end
end

-- Имена пачками. Кого не нашли или не получили, того подставляем как User_<id>.
local function resolveNames(userIds)
	local missing = {}
	for _, userId in ipairs(userIds) do
		if not usernameCache[userId] and not Players:GetPlayerByUserId(userId) then
			table.insert(missing, userId)
		end
	end

	for i = 1, #missing, NAME_BATCH do
		local batch = table.move(missing, i, math.min(i + NAME_BATCH - 1, #missing), 1, {})
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(batch)
		end)

		if ok and typeof(infos) == "table" then
			for _, info in ipairs(infos) do
				if typeof(info.Id) == "number" and typeof(info.Username) == "string" then
					usernameCache[info.Id] = info.Username
				end
			end
			-- удалённые/недоступные аккаунты кэшируем заглушкой, чтобы не спрашивать вечно
			for _, userId in ipairs(batch) do
				usernameCache[userId] = usernameCache[userId] or ("User_" .. userId)
			end
		else
			warn("[DeathsBoard] Не удалось получить имена: " .. tostring(infos))
			-- не кэшируем: попробуем снова при следующем обновлении
		end
		task.wait(0.2)
	end
end

local function getUsername(userId)
	local online = Players:GetPlayerByUserId(userId)
	if online then
		return online.Name
	end
	return usernameCache[userId] or ("User_" .. userId)
end

local function render(entries)
	if #entries == 0 then
		if not emptyLabel then
			emptyLabel = template:Clone()
			emptyLabel.Name = "Empty"
			emptyLabel.Text = "No data."
			emptyLabel.Visible = true
			emptyLabel.Parent = frame
		end
	elseif emptyLabel then
		emptyLabel:Destroy()
		emptyLabel = nil
	end

	for i, entry in ipairs(entries) do
		local label = rowLabels[i]
		if not label then
			label = template:Clone()
			label.Name = string.format("Row%04d", i) -- сортировка по имени даёт верный порядок
			label.LayoutOrder = i
			label.Visible = true
			label.Parent = frame
			rowLabels[i] = label
			if i % 100 == 0 then
				task.wait() -- не создаём 1000 объектов за один кадр
			end
		end
		label.Text = string.format("%d. %s  –  %d", i, entry.Username, entry.Deaths)
	end

	for i = #rowLabels, #entries + 1, -1 do
		rowLabels[i]:Destroy()
		rowLabels[i] = nil
	end
end

-- Читает все страницы. Возвращает nil, если хоть одна страница не прочиталась
-- (лучше оставить прежнюю таблицу, чем показать обрезанную).
local function fetchTop()
	local ok, pages = pcall(function()
		return deathsBoard:GetSortedAsync(false, PAGE_SIZE)
	end)
	if not ok then
		warn("[DeathsBoard] GetSortedAsync не удался: " .. tostring(pages))
		return nil
	end

	local items = {}
	while true do
		local okPage, page = pcall(function()
			return pages:GetCurrentPage()
		end)
		if not okPage then
			warn("[DeathsBoard] GetCurrentPage не удался: " .. tostring(page))
			return nil
		end

		for _, item in ipairs(page) do
			table.insert(items, item)
		end

		if pages.IsFinished or #items >= MAX_ROWS then
			break
		end

		waitForBudget(Enum.DataStoreRequestType.GetSortedAsync)
		local okNext, err = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not okNext then
			warn("[DeathsBoard] AdvanceToNextPageAsync не удался: " .. tostring(err))
			return nil
		end
	end

	return items
end

local function refresh()
	local items = fetchTop()
	if not items then
		return
	end

	local userIds = {}
	for _, item in ipairs(items) do
		local userId = tonumber(item.key)
		if userId and userId > 0 and typeof(item.value) == "number" and #userIds < MAX_ROWS then
			table.insert(userIds, userId)
		end
	end

	resolveNames(userIds)

	local entries = {}
	for _, item in ipairs(items) do
		local userId = tonumber(item.key)
		if userId and userId > 0 and typeof(item.value) == "number" and #entries < MAX_ROWS then
			table.insert(entries, {
				Username = getUsername(userId),
				Deaths = item.value,
			})
		end
	end

	render(entries)
end

task.spawn(function()
	while true do
		local ok, err = pcall(refresh)
		if not ok then
			warn("[DeathsBoard] Ошибка обновления: " .. tostring(err))
		end
		task.wait(UPDATE_PERIOD)
	end
end)
