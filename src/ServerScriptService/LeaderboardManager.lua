local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Configuration for Admins
local ADMIN_USER_IDS = {
	940118285,
	3322927329
}

-- DataStores
local STATS_DATASTORE_NAME = "PlayerStatsDataStoreV1"
local statsDataStore = DataStoreService:GetDataStore(STATS_DATASTORE_NAME)
local seenPlayersStore = DataStoreService:GetDataStore("SeenPlayersV1")

-- RemoteEvents
local resetStatsEvent = ReplicatedStorage:WaitForChild("ResetPlayerStatsAdminEvent")
local giveCoinsEvent = ReplicatedStorage:WaitForChild("GiveCoinsAdminEvent") -- 👈 новое событие

-- Проверка на админа
local function isAdmin(player)
	if not player then return false end
	for _, adminId in ADMIN_USER_IDS do
		if player.UserId == adminId then
			return true
		end
	end
	return false
end

-- Создание leaderstats
local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local deathsStat = leaderstats:FindFirstChild("Deaths")
	if not deathsStat then
		deathsStat = Instance.new("IntValue")
		deathsStat.Name = "Deaths"
		deathsStat.Value = 0
		deathsStat.Parent = leaderstats
	end

	local coinsStat = leaderstats:FindFirstChild("Coins")
	if not coinsStat then
		coinsStat = Instance.new("IntValue")
		coinsStat.Name = "Coins"
		coinsStat.Value = 0
		coinsStat.Parent = leaderstats
	end

	return leaderstats
end

-- Логика смерти
local function setupCharacterDeathLogic(player)
	local leaderstats = ensureLeaderstats(player)
	if not leaderstats then return end

	local deathsStat = leaderstats:FindFirstChild("Deaths")
	local coinsStat = leaderstats:FindFirstChild("Coins")
	if not deathsStat or not coinsStat then return end

	local function connectDeathHandler(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if deathsStat then
				deathsStat.Value += 1
			end
			if coinsStat then
				local coinsEarned = math.random(1, 5)
				coinsStat.Value += coinsEarned
				print(player.Name .. " died. Deaths: " .. deathsStat.Value .. ", Coins + " .. coinsEarned)
			end
		end)
	end

	player.CharacterAdded:Connect(connectDeathHandler)

	-- Подключаем обработчик сразу, если персонаж уже есть
	if player.Character then
		connectDeathHandler(player.Character)
	end
end

-- Сохранить UserId в список
local function trackSeenPlayer(userId)
	task.spawn(function()
		local success, err = pcall(function()
			seenPlayersStore:UpdateAsync("AllPlayers", function(old)
				old = old or {}
				if not table.find(old, userId) then
					table.insert(old, userId)
				end
				return old
			end)
		end)
		if not success then
			warn("Не удалось сохранить UserId " .. userId .. ": " .. tostring(err))
		end
	end)
end

-- При входе игрока
local function onPlayerAdded(player)
	trackSeenPlayer(player.UserId)

	local leaderstats = ensureLeaderstats(player)
	local deathsStat = leaderstats:FindFirstChild("Deaths")
	local coinsStat = leaderstats:FindFirstChild("Coins")

	local key = "Player_" .. player.UserId
	local success, data = pcall(function()
		return statsDataStore:GetAsync(key)
	end)

	if success and type(data) == "table" then
		deathsStat.Value = data.Deaths or 0
		coinsStat.Value = data.Coins or 0
	else
		print("Нет данных для " .. player.Name .. " или ошибка загрузки.")
	end

	setupCharacterDeathLogic(player)
end

-- При выходе игрока
local function onPlayerRemoving(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local deathsStat = leaderstats:FindFirstChild("Deaths")
	local coinsStat = leaderstats:FindFirstChild("Coins")
	if not deathsStat or not coinsStat then return end

	local dataToSave = {
		Deaths = deathsStat.Value,
		Coins = coinsStat.Value
	}

	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		statsDataStore:SetAsync(key, dataToSave)
	end)

	if not success then
		warn("Ошибка при сохранении данных игрока " .. player.Name .. ": " .. tostring(err))
	end
end

-- Сброс статистики админом
resetStatsEvent.OnServerEvent:Connect(function(adminPlayer, targetPlayerName)
	if not isAdmin(adminPlayer) then return end

	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then return end

	local leaderstats = targetPlayer:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local deathsStat = leaderstats:FindFirstChild("Deaths")
	local coinsStat = leaderstats:FindFirstChild("Coins")

	if deathsStat then deathsStat.Value = 0 end
	if coinsStat then coinsStat.Value = 0 end

	local key = "Player_" .. targetPlayer.UserId
	local success, err = pcall(function()
		statsDataStore:SetAsync(key, {Deaths = 0, Coins = 0})
	end)

	if success then
		print("Admin " .. adminPlayer.Name .. " сбросил данные для " .. targetPlayer.Name)
	else
		warn("Ошибка сброса данных: " .. tostring(err))
	end
end)

-- Выдача монет админом
giveCoinsEvent.OnServerEvent:Connect(function(adminPlayer, targetPlayerName, amount)
	if not isAdmin(adminPlayer) then return end
	if typeof(amount) ~= "number" or amount <= 0 then return end

	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then return end

	local leaderstats = targetPlayer:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local coinsStat = leaderstats:FindFirstChild("Coins")
	if not coinsStat then return end

	coinsStat.Value += amount

	local key = "Player_" .. targetPlayer.UserId
	local success, err = pcall(function()
		statsDataStore:SetAsync(key, {
			Deaths = leaderstats:FindFirstChild("Deaths") and leaderstats.Deaths.Value or 0,
			Coins = coinsStat.Value
		})
	end)

	if success then
		print("Admin " .. adminPlayer.Name .. " выдал " .. amount .. " монет игроку " .. targetPlayer.Name)
	else
		warn("Ошибка при выдаче монет: " .. tostring(err))
	end
end)

-- Инициализация
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

game:BindToClose(function()
	if RunService:IsStudio() and not RunService:IsRunMode() then return end
	for _, player in Players:GetPlayers() do
		onPlayerRemoving(player)
	end
end)

print("LeaderboardManager (v3.0) загружен.")
