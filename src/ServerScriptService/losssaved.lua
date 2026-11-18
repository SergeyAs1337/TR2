local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("GambleEvent")

-- Создаём папку и значение для передачи клиентам
local globalStats = Instance.new("Folder", ReplicatedStorage)
globalStats.Name = "GlobalStats"

local totalLost = Instance.new("IntValue", globalStats)
totalLost.Name = "TotalLost"
totalLost.Value = 0

-- DataStore для сохранения
local lostStore = DataStoreService:GetDataStore("GlobalLostCoins")

-- Локальный накопитель проигрышей
local pendingLoss = 0

-- Функция загрузки из DataStore
local function loadTotalLost()
	local success, value = pcall(function()
		return lostStore:GetAsync("GlobalLost")
	end)
	if success and typeof(value) == "number" then
		totalLost.Value = value
		print("✅ Загрузка общего проигрыша: " .. value)
	else
		print("⚠️ Не удалось загрузить общий проигрыш, начинаем с 0")
		totalLost.Value = 0
	end
end

-- Функция сохранения в DataStore
local function saveTotalLost()
	local success, err = pcall(function()
		lostStore:SetAsync("GlobalLost", totalLost.Value)
	end)
	if not success then
		warn("❌ Ошибка сохранения общего проигрыша: " .. tostring(err))
	end
	return success
end

-- Загружаем при старте
loadTotalLost()

-- Обработка ставок
remote.OnServerEvent:Connect(function(player, bet)
	if typeof(bet) ~= "number" or bet <= 0 then return end

	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local coins = stats:FindFirstChild("Coins")
	if not coins or coins.Value < bet then return end

	coins.Value -= bet

	local result = math.random() * 100
	local win = 0

	if result < 0.01 then
		win = bet * 10
	elseif result < 30 then
		win = bet * 2
	else
		-- проигрыш — накапливаем
		pendingLoss += bet
	end

	if win > 0 then
		coins.Value += win
	end
end)

-- Каждую минуту добавляем pendingLoss к totalLost и сохраняем
task.spawn(function()
	while true do
		if pendingLoss > 0 then
			totalLost.Value += pendingLoss

			local saved = saveTotalLost()
			if saved then
				pendingLoss = 0
			end
			-- Если сохранение не удалось, pendingLoss не сбрасываем,
			-- попробуем сохранить снова в следующем цикле
		end
		task.wait(60)
	end
end)
