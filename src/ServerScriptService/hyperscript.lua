-- 🔥 ГИПЕР СИСТЕМА ПРОКАЧКИ 🔥
-- Всё работает из одного скрипта!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- 🔹 Создаём RemoteEvent для покупок из GUI
local UpgradeEvent = Instance.new("RemoteEvent")
UpgradeEvent.Name = "UpgradeRequest"
UpgradeEvent.Parent = ReplicatedStorage

-- 🔹 Настройки
local UpgradesStore = DataStoreService:GetDataStore("PlayerUpgradesV1")

local MAX_LEVELS = {
	Health = 10,
	Speed = 10,
	Regen = 10,
	CoinMultiplier = 10
}

local BASE_STATS = {
	Health = 100,
	Speed = 16,
	RegenPercent = 0.05, -- 5%
	RegenDelay = 5
}

-- 💾 Загрузка и сохранение
local function LoadUpgrades(player)
	local saved = nil
	pcall(function()
		saved = UpgradesStore:GetAsync(player.UserId)
	end)

	if not saved then
		saved = {Health = 1, Speed = 1, Regen = 1, CoinMultiplier = 1}
	end

	player:SetAttribute("Upgrades", HttpService:JSONEncode(saved))
	return saved
end

local function SaveUpgrades(player)
	local upgrades = HttpService:JSONDecode(player:GetAttribute("Upgrades") or "{}")
	pcall(function()
		UpgradesStore:SetAsync(player.UserId, upgrades)
	end)
end

-- 💪 Применение эффектов при спавне
local function ApplyUpgrades(player, character)
	local upgrades = HttpService:JSONDecode(player:GetAttribute("Upgrades") or "{}")
	local humanoid = character:WaitForChild("Humanoid")

	-- ❤️ ХП
	local hpLevel = upgrades.Health or 1
	local maxHp = 100 * hpLevel
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp

	-- ⚡ Скорость
	local speedLevel = upgrades.Speed or 1
	local walkspeed = 16 + ((speedLevel - 1) * ((32 - 16) / 9))
	humanoid.WalkSpeed = walkspeed

	-- 💊 Реген
	local regenLevel = upgrades.Regen or 1
	local regenPercent = 0.05 + ((regenLevel - 1) * ((0.10 - 0.05) / 9))
	local regenDelay = 5 - ((regenLevel - 1) * ((5 - 3) / 9))

	task.spawn(function()
		while humanoid.Parent and humanoid.Health > 0 do
			task.wait(regenDelay)
			if humanoid.Health < humanoid.MaxHealth then
				local heal = humanoid.MaxHealth * regenPercent
				humanoid.Health = math.clamp(humanoid.Health + heal, 0, humanoid.MaxHealth)
			end
		end
	end)
end

-- 💰 Получение множителя монет
local function GetCoinMultiplier(player)
	local upgrades = HttpService:JSONDecode(player:GetAttribute("Upgrades") or "{}")
	return upgrades.CoinMultiplier or 1
end

-- 💵 Универсальная функция изменения монет
-- baseAmount > 0 → множитель применяется
-- baseAmount < 0 → множитель не применяется
function ChangeCoins(player, baseAmount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then return end

	local multiplier = GetCoinMultiplier(player)
	local finalAmount = baseAmount

	if baseAmount > 0 then
		finalAmount = math.floor(baseAmount * multiplier)
	end

	coins.Value += finalAmount

	if finalAmount > 0 then
		print(string.format("%s получил +%d монет (x%d множитель)", player.Name, finalAmount, multiplier))
	elseif finalAmount < 0 then
		print(string.format("%s потерял %d монет", player.Name, math.abs(finalAmount)))
	end
end

-- 💾 Подключение игрока
Players.PlayerAdded:Connect(function(player)
	local upgrades = LoadUpgrades(player)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		ApplyUpgrades(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	SaveUpgrades(player)
end)

-- 🛠️ Покупка апгрейдов
UpgradeEvent.OnServerEvent:Connect(function(player, upgradeName)
	local upgrades = HttpService:JSONDecode(player:GetAttribute("Upgrades") or "{}")
	local currentLevel = upgrades[upgradeName] or 1
	local maxLevel = MAX_LEVELS[upgradeName] or 10
	if currentLevel >= maxLevel then return end

	-- 💵 Цена (100, 200, 300 и т.д.)
	local price = currentLevel * 100
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or coins.Value < price then
		warn(player.Name .. " не хватает монет на " .. upgradeName)
		return
	end

	coins.Value -= price
	upgrades[upgradeName] = currentLevel + 1
	player:SetAttribute("Upgrades", HttpService:JSONEncode(upgrades))
	SaveUpgrades(player)

	print(player.Name .. " улучшил " .. upgradeName .. " до уровня " .. upgrades[upgradeName])

	-- Если игрок жив — сразу обновить эффекты
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		ApplyUpgrades(player, player.Character)
	end
end)