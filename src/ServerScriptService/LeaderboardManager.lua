-- ServerScriptService/LeaderboardManager.lua  (v4.1)
-- Загрузка и сохранение Coins/Deaths. Формат данных и имена хранилищ прежние,
-- поэтому существующие сохранения подхватятся.
--
-- Что изменилось по сравнению с v3:
--  * если загрузка не удалась, данные игрока НИКОГДА не перезаписываются нулями
--    (повторы с паузой, затем кик либо игра без сохранения);
--  * leaderstats появляется только ПОСЛЕ загрузки: другие скрипты (магазины,
--    множитель монет, ачивки) видят уже загруженные значения, а не нули;
--  * автосохранение каждые 90 с (только если что-то изменилось), UpdateAsync с повторами;
--  * BindToClose сохраняет всех параллельно, повторного сохранения нет;
--  * убран список AllPlayers (его читала старая таблица лидеров);
--    таблица лидеров теперь работает на OrderedDataStore.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ===== Настройки =====
local ADMIN_USER_IDS = {
	940118285,
	3322927329,
}

local STATS_DATASTORE_NAME = "PlayerStatsDataStoreV1"
local DEATHS_BOARD_NAME = "DeathsLeaderboardV1" -- тот же, что в LeaderBoard.lua

local AUTOSAVE_INTERVAL = 90 -- секунд
local IS_STUDIO = RunService:IsStudio()
-- В Studio без включённого "Studio Access to API Services" DataStore всегда падает:
-- там одна попытка и игра без сохранения, без кика.
local LOAD_ATTEMPTS = IS_STUDIO and 1 or 5
local SAVE_ATTEMPTS = 3
local SHUTDOWN_TIMEOUT = 25 -- секунд на сохранение всех при закрытии сервера
local KICK_ON_LOAD_FAILURE = not IS_STUDIO -- false: игрок играет, но его прогресс не сохраняется
local MAX_ADMIN_COINS = 1_000_000_000

local KICK_MESSAGE = "Не удалось загрузить твои данные. Зайди ещё раз через минуту, прогресс не потерян."

-- ===== Хранилища и события =====
local statsStore = DataStoreService:GetDataStore(STATS_DATASTORE_NAME)
local deathsBoard = DataStoreService:GetOrderedDataStore(DEATHS_BOARD_NAME)

local resetStatsEvent = ReplicatedStorage:WaitForChild("ResetPlayerStatsAdminEvent")
local giveCoinsEvent = ReplicatedStorage:WaitForChild("GiveCoinsAdminEvent")

-- sessions[player] = { canSave, saving, finalizing, leaving, savedDeaths, savedCoins, boardDeaths }
local sessions = {}

-- ===== Вспомогательное =====
local function statsKey(userId)
	return "Player_" .. userId
end

local function isAdmin(player)
	return player ~= nil and table.find(ADMIN_USER_IDS, player.UserId) ~= nil
end

local function sanitize(n)
	if typeof(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(n)
end

-- Повтор с экспоненциальной паузой. Возвращает (успех, результат).
local function withRetry(attempts, label, fn)
	local pause = 1
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[Stats] %s: попытка %d/%d не удалась: %s"):format(label, attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(pause)
			pause = math.min(pause * 2, 16)
		end
	end
	return false, nil
end

local function getStatObjects(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local deaths = leaderstats and leaderstats:FindFirstChild("Deaths")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	return deaths, coins
end

local function createLeaderstats(player, deaths, coins)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local deathsStat = Instance.new("IntValue")
	deathsStat.Name = "Deaths"
	deathsStat.Value = deaths
	deathsStat.Parent = leaderstats

	local coinsStat = Instance.new("IntValue")
	coinsStat.Name = "Coins"
	coinsStat.Value = coins
	coinsStat.Parent = leaderstats

	leaderstats.Parent = player -- родитель ставим последним: к этому моменту значения уже загружены
	return deathsStat, coinsStat
end

-- ===== Сохранение =====
-- Значения читаются ДО любых ожиданий, поэтому при выходе игрока ничего не теряется.
local function saveProfile(player, force)
	local session = sessions[player]
	if not session or not session.canSave then
		return false
	end

	local deathsStat, coinsStat = getStatObjects(player)
	if not deathsStat or not coinsStat then
		return false
	end
	local deaths, coins = deathsStat.Value, coinsStat.Value

	local statsDirty = force or deaths ~= session.savedDeaths or coins ~= session.savedCoins
	local boardDirty = deaths > 0 and deaths ~= session.boardDeaths
	if not statsDirty and not boardDirty then
		return true
	end

	while session.saving do
		task.wait(0.1)
	end
	session.saving = true

	local ok = true
	if statsDirty then
		ok = withRetry(SAVE_ATTEMPTS, "сохранение " .. player.Name, function()
			statsStore:UpdateAsync(statsKey(player.UserId), function(old)
				local data = typeof(old) == "table" and old or {}
				data.Deaths = deaths
				data.Coins = coins
				return data
			end)
		end)
		if ok then
			session.savedDeaths = deaths
			session.savedCoins = coins
		end
	end

	-- Таблица лидеров: сбой здесь не страшен, следующее сохранение повторит запись.
	if boardDirty then
		local okBoard = pcall(function()
			deathsBoard:SetAsync(tostring(player.UserId), deaths)
		end)
		if okBoard then
			session.boardDeaths = deaths
		end
	end

	session.saving = false
	return ok
end

local function finalSave(player)
	local session = sessions[player]
	if not session then
		return
	end

	if session.finalizing then
		-- PlayerRemoving и BindToClose могут вызвать это одновременно: ждём первого
		while sessions[player] do
			task.wait(0.1)
		end
		return
	end

	session.finalizing = true
	session.leaving = true
	saveProfile(player, false)
	sessions[player] = nil
end

local function startAutosave(player)
	task.spawn(function()
		task.wait(player.UserId % AUTOSAVE_INTERVAL) -- разносим игроков по времени
		while true do
			local session = sessions[player]
			if not session or session.leaving then
				return
			end
			saveProfile(player, false)
			task.wait(AUTOSAVE_INTERVAL)
		end
	end)
end

-- ===== Логика смерти =====
local function connectDeathLogic(player, deathsStat, coinsStat)
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			deathsStat.Value += 1
			-- Множитель монет (апгрейд) действует только на награду за смерть.
			-- Атрибут выставляет UpgradeHandler.lua.
			local multiplier = player:GetAttribute("CoinMultiplier")
			if typeof(multiplier) ~= "number" or multiplier ~= multiplier then
				multiplier = 1
			end
			multiplier = math.clamp(math.floor(multiplier), 1, 10)
			coinsStat.Value += math.random(1, 5) * multiplier
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- ===== Вход игрока =====
local function onPlayerAdded(player)
	if sessions[player] then
		return
	end

	local session = {
		canSave = false,
		saving = false,
		finalizing = false,
		leaving = false,
		savedDeaths = 0,
		savedCoins = 0,
		boardDeaths = -1, -- -1: запись в таблицу лидеров ещё не делали
	}
	sessions[player] = session

	local ok, data = withRetry(LOAD_ATTEMPTS, "загрузка " .. player.Name, function()
		return statsStore:GetAsync(statsKey(player.UserId))
	end)

	-- nil означает нового игрока; всё, кроме таблицы, считаем повреждением
	if ok and data ~= nil and typeof(data) ~= "table" then
		warn("[Stats] Повреждённые данные у " .. player.Name .. ": " .. typeof(data))
		ok = false
	end

	if not player:IsDescendantOf(Players) then
		sessions[player] = nil -- игрок вышел во время загрузки, сохранять нечего
		return
	end

	if not ok then
		if KICK_ON_LOAD_FAILURE then
			sessions[player] = nil
			player:Kick(KICK_MESSAGE)
			return
		end
		-- Играет без сохранения: canSave остаётся false, настоящие данные не тронем
		local deathsStat, coinsStat = createLeaderstats(player, 0, 0)
		connectDeathLogic(player, deathsStat, coinsStat)
		return
	end

	local deaths = sanitize(data and data.Deaths)
	local coins = sanitize(data and data.Coins)
	session.savedDeaths = deaths
	session.savedCoins = coins
	session.canSave = true

	local deathsStat, coinsStat = createLeaderstats(player, deaths, coins)
	connectDeathLogic(player, deathsStat, coinsStat)
	startAutosave(player)
end

-- ===== Админ-события =====
local function findTarget(name)
	if typeof(name) ~= "string" then
		return nil
	end
	local target = Players:FindFirstChild(name)
	if target and target:IsA("Player") and sessions[target] and sessions[target].canSave then
		return target
	end
	return nil
end

resetStatsEvent.OnServerEvent:Connect(function(adminPlayer, targetPlayerName)
	if not isAdmin(adminPlayer) then
		return
	end
	local target = findTarget(targetPlayerName)
	if not target then
		return
	end
	local deathsStat, coinsStat = getStatObjects(target)
	if not deathsStat or not coinsStat then
		return
	end

	deathsStat.Value = 0
	coinsStat.Value = 0

	local session = sessions[target]
	pcall(function()
		deathsBoard:RemoveAsync(tostring(target.UserId))
	end)
	session.boardDeaths = -1

	local saved = saveProfile(target, true)
	print(("Admin %s сбросил данные для %s (сохранено: %s)"):format(adminPlayer.Name, target.Name, tostring(saved)))
end)

giveCoinsEvent.OnServerEvent:Connect(function(adminPlayer, targetPlayerName, amount)
	if not isAdmin(adminPlayer) then
		return
	end
	if typeof(amount) ~= "number" or amount ~= amount then
		return
	end
	if amount < 1 or amount > MAX_ADMIN_COINS or amount % 1 ~= 0 then
		return
	end
	local target = findTarget(targetPlayerName)
	if not target then
		return
	end
	local _, coinsStat = getStatObjects(target)
	if not coinsStat then
		return
	end

	coinsStat.Value += amount
	local saved = saveProfile(target, false)
	print(("Admin %s выдал %d монет игроку %s (сохранено: %s)"):format(adminPlayer.Name, amount, target.Name, tostring(saved)))
end)

-- ===== Подключение =====
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(finalSave)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	if IS_STUDIO then
		return
	end

	local list = {}
	for player in sessions do
		table.insert(list, player)
	end

	local pending = #list
	for _, player in list do
		task.spawn(function()
			finalSave(player)
			pending -= 1
		end)
	end

	local deadline = os.clock() + SHUTDOWN_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

print("LeaderboardManager (v4.1) загружен.")
