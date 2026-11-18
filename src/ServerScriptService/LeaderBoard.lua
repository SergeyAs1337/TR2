--[[
	LeaderBoard.server.lua
	Показывает топ-1000 игроков по количеству смертей.
	Добавлена фильтрация некорректных UserId.
	Оптимизация: кеш имён, частичная загрузка с паузами.
]]--

local DEBUG = false          -- true = вывод отладки; false = тишина
local UPDATE_PERIOD = 30     -- сек между обновлениями
local MAX_ROWS = 1000        -- максимальное число строк в таблице
local BATCH_SIZE = 20        -- сколько игроков обрабатываем за раз
local BATCH_WAIT = 0.5       -- пауза между партиями, чтобы не блокировать

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local seenStore  = DataStoreService:GetDataStore("SeenPlayersV1")
local statsStore = DataStoreService:GetDataStore("PlayerStatsDataStoreV1")

local board     = workspace.topdeath.Top_Deaths.DeathsLeaderboard
local gui       = board:WaitForChild("SurfaceGui")
local frame     = gui:WaitForChild("ScrollingFrame")
local template  = frame:WaitForChild("Template")
local layout    = frame:WaitForChild("UIListLayout")

local usernameCache = {}

local function dprint(...)
	if DEBUG then
		print("[DeathsBoard]", ...)
	end
end

local function rememberPlayer(userId)
	if typeof(userId) ~= "number" or userId <= 0 then
		warn("Попытка сохранить некорректный userId в AllPlayers:", userId)
		return
	end
	local ok, err = pcall(function()
		seenStore:UpdateAsync("AllPlayers", function(list)
			list = list or {}
			for _, id in ipairs(list) do
				if id == userId then
					return list
				end
			end
			table.insert(list, userId)
			return list
		end)
	end)
	if not ok then
		warn("UpdateAsync FAILED:", err)
	end
end

local function getUsername(userId)
	if usernameCache[userId] then
		return usernameCache[userId]
	end

	local success, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success then
		usernameCache[userId] = username
		return username
	else
		warn("Failed to get username for", userId)
		return "User_" .. userId
	end
end

local function getDeaths(userId)
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		local ls = plr:FindFirstChild("leaderstats")
		local d  = ls and ls:FindFirstChild("Deaths")
		if d then
			return d.Value
		end
	end

	local suc, data = pcall(function()
		return statsStore:GetAsync("Player_" .. userId)
	end)
	if not suc then
		warn("GetAsync FAILED for", userId, data)
		return 0
	end

	return (type(data) == "table" and data.Deaths) or 0
end

local function redraw(rows)
	for _, ch in ipairs(frame:GetChildren()) do
		if ch:IsA("TextLabel") and ch ~= template then
			ch:Destroy()
		end
	end

	if #rows == 0 then
		local lbl = template:Clone()
		lbl.Name = "Empty"
		lbl.Text = "No data."
		lbl.Visible = true
		lbl.Parent = frame
	else
		for i = 1, math.min(#rows, MAX_ROWS) do
			local r = rows[i]
			local lbl = template:Clone()
			lbl.Name = "Row" .. i
			lbl.Text = string.format("%d. %s  –  %d", i, r.Username, r.Deaths)
			lbl.Visible = true
			lbl.Parent = frame
		end
	end

	frame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
end

local function refresh()
	dprint("=== обновление таблицы ===")

	local ok, userIds = pcall(function()
		return seenStore:GetAsync("AllPlayers")
	end)

	if not ok or not userIds then
		warn("Не удалось получить AllPlayers:", userIds)
		return
	end

	dprint("Всего userId в AllPlayers:", #userIds)

	local filteredUserIds = {}
	for _, id in ipairs(userIds) do
		if typeof(id) == "number" and id > 0 then
			table.insert(filteredUserIds, id)
		end
	end

	local rows = {}

	for i = 1, #filteredUserIds, BATCH_SIZE do
		for j = i, math.min(i + BATCH_SIZE - 1, #filteredUserIds) do
			local userId = filteredUserIds[j]
			local username = getUsername(userId)
			local deaths = getDeaths(userId)

			table.insert(rows, {
				UserId = userId,
				Username = username,
				Deaths = deaths,
			})

			dprint(string.format(" [%d] %s (%d) – %d", j, username, userId, deaths))
		end

		task.wait(BATCH_WAIT)
	end

	table.sort(rows, function(a, b)
		return a.Deaths > b.Deaths
	end)

	redraw(rows)

	dprint("Таблица перерисована (" .. #rows .. " записей)\n")
end

Players.PlayerAdded:Connect(function(plr)
	rememberPlayer(plr.UserId)
end)

task.spawn(function()
	while true do
		refresh()
		task.wait(UPDATE_PERIOD)
	end
end)

refresh()
