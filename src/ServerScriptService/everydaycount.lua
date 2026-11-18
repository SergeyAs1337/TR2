-- ✅ Daily Quest Server Script (починенный и полный)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dailyDeathsStore = DataStoreService:GetDataStore("DailyDeaths")
local updateEvent = ReplicatedStorage:WaitForChild("DailyQuestUpdate")

local maxDeaths = 15
local rewards = {
	[1] = 30,
	[5] = 50,
	[15] = 150
}

-- 🗓️ Дата в формате YYYY-MM-DD
local function getTodayUTC()
	local date = os.date("!*t")
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- 📥 Загрузка данных игрока
local function loadPlayerData(player)
	local success, data = pcall(function()
		return dailyDeathsStore:GetAsync(player.UserId)
	end)

	local today = getTodayUTC()

	if success and type(data) == "table" and data.date then
		if data.date == today then
			player:SetAttribute("DailyDeaths", data.deaths or 0)
			player:SetAttribute("DailyQuestCompleted", data.completed or false)
			player:SetAttribute("DailyQuestRewardsGiven", data.rewardsGiven or "") -- сериализованная строка
		else
			player:SetAttribute("DailyDeaths", 0)
			player:SetAttribute("DailyQuestCompleted", false)
			player:SetAttribute("DailyQuestRewardsGiven", "")
		end
	else
		player:SetAttribute("DailyDeaths", 0)
		player:SetAttribute("DailyQuestCompleted", false)
		player:SetAttribute("DailyQuestRewardsGiven", "")
	end

	player:SetAttribute("DailyDeathsDate", today)
end

-- 💾 Сохранение данных игрока
local function savePlayerData(player)
	local deaths = player:GetAttribute("DailyDeaths") or 0
	local completed = player:GetAttribute("DailyQuestCompleted") or false
	local date = player:GetAttribute("DailyDeathsDate") or getTodayUTC()
	local rewardsGiven = player:GetAttribute("DailyQuestRewardsGiven") or ""

	pcall(function()
		dailyDeathsStore:SetAsync(player.UserId, {
			deaths = deaths,
			date = date,
			completed = completed,
			rewardsGiven = rewardsGiven
		})
	end)
end

-- 🟢 Выдача награды
local function giveRewardIfNeeded(player, deaths)
	-- Достаём список выданных наград
	local rewardsGivenStr = player:GetAttribute("DailyQuestRewardsGiven") or ""
	local rewardsGiven = {}

	-- Превращаем строку вида "1,5" в таблицу
	for reward in string.gmatch(rewardsGivenStr, "([^,]+)") do
		rewardsGiven[tonumber(reward)] = true
	end

	for threshold, coins in pairs(rewards) do
		if deaths >= threshold and not rewardsGiven[threshold] then
			-- Выдаём награду
			local stats = player:FindFirstChild("leaderstats")
			if stats and stats:FindFirstChild("Coins") then
				stats.Coins.Value += coins
				print(player.Name .. " получил " .. coins .. " монет за " .. threshold .. " смертей")
			end

			rewardsGiven[threshold] = true
		end
	end

	-- Сохраняем обновлённый список
	local newList = {}
	for k, _ in pairs(rewardsGiven) do
		table.insert(newList, tostring(k))
	end
	player:SetAttribute("DailyQuestRewardsGiven", table.concat(newList, ","))
end

-- ⚰️ Обработчик смерти
local function onDeath(player)
	return function()
		local deaths = player:GetAttribute("DailyDeaths") or 0
		local savedDate = player:GetAttribute("DailyDeathsDate") or getTodayUTC()
		local today = getTodayUTC()

		if savedDate ~= today then
			deaths = 0
			player:SetAttribute("DailyQuestCompleted", false)
			player:SetAttribute("DailyQuestRewardsGiven", "")
			savedDate = today
		end

		deaths += 1
		player:SetAttribute("DailyDeaths", deaths)
		player:SetAttribute("DailyDeathsDate", savedDate)

		if deaths >= maxDeaths then
			player:SetAttribute("DailyQuestCompleted", true)
		end

		giveRewardIfNeeded(player, deaths)

		updateEvent:FireClient(player, deaths)
		savePlayerData(player)
	end
end

-- 🔄 Цикл для сброса всех онлайн игроков при смене даты
task.spawn(function()
	local lastCheck = getTodayUTC()
	while true do
		task.wait(60)
		local current = getTodayUTC()
		if current ~= lastCheck then
			lastCheck = current
			for _, player in ipairs(Players:GetPlayers()) do
				player:SetAttribute("DailyDeaths", 0)
				player:SetAttribute("DailyDeathsDate", current)
				player:SetAttribute("DailyQuestCompleted", false)
				player:SetAttribute("DailyQuestRewardsGiven", "")

				updateEvent:FireClient(player, 0)
				savePlayerData(player)
			end
		end
	end
end)

-- 🎮 Игрок зашёл
Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)

	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(onDeath(player))
		end
	end

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(onDeath(player))
	end)

	-- GUI прогресс
	updateEvent:FireClient(player, player:GetAttribute("DailyDeaths") or 0)
end)

-- 💾 Игрок ушёл
Players.PlayerRemoving:Connect(savePlayerData)
