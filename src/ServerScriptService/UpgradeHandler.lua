local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

-- RemoteEvent
local UpgradeEvent = ReplicatedStorage:FindFirstChild("UpgradeRequest") or Instance.new("RemoteEvent")
UpgradeEvent.Name = "UpgradeRequest"
UpgradeEvent.Parent = ReplicatedStorage

local UpgradeStore = DataStoreService:GetDataStore("PlayerUpgrades")

local MAX_LEVELS = {Health = 10, Speed = 10, Regen = 10, CoinMultiplier = 10}
local LEVEL_PRICES = {100, 200, 400, 800, 1600, 3200, 5000, 7500, 10000}

----------------------------------------------------
-- 🔹 Получить таблицу апгрейдов безопасно
----------------------------------------------------
local function GetUpgradesTable(player)
	local attr = player:GetAttribute("Upgrades")

	if typeof(attr) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, attr)
		if ok and type(decoded) == "table" then
			return decoded
		end
	end

	if type(attr) == "table" then
		return attr
	end

	-- если ничего нет — создать базовую таблицу
	local default = {Health = 1, Speed = 1, Regen = 1, CoinMultiplier = 1}
	player:SetAttribute("Upgrades", HttpService:JSONEncode(default))
	return default
end

----------------------------------------------------
-- 🔹 Применить апгрейд к персонажу
----------------------------------------------------
local function ApplyUpgrades(player)
	local upgrades = GetUpgradesTable(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- здоровье
	hum.MaxHealth = 100 * (upgrades.Health or 1)
	hum.Health = hum.MaxHealth

	-- скорость
	hum.WalkSpeed = 16 + ((upgrades.Speed or 1) - 1) * (32 - 16) / 9

	-- реген (упрощённый пример)
	if not char:FindFirstChild("CustomRegen") then
		local regen = Instance.new("Folder")
		regen.Name = "CustomRegen"
		regen.Parent = char
		task.spawn(function()
			while char.Parent do
				local rLvl = upgrades.Regen or 1
				local percent = 5 + (rLvl - 1) * (10 - 5) / 9 -- 5% → 10%
				local delay = 5 - (rLvl - 1) * (2) / 9 -- 5s → 3s
				task.wait(delay)
				if hum and hum.Health > 0 then
					hum.Health = math.min(hum.Health + hum.MaxHealth * (percent / 100), hum.MaxHealth)
				end
			end
		end)
	end
end

----------------------------------------------------
-- 🔹 Загрузка и сохранение DataStore
----------------------------------------------------
local function LoadUpgrades(player)
	local data
	local success, result = pcall(function()
		return UpgradeStore:GetAsync(player.UserId)
	end)
	if success and type(result) == "table" then
		data = result
	else
		data = {Health = 1, Speed = 1, Regen = 1, CoinMultiplier = 1}
	end
	player:SetAttribute("Upgrades", HttpService:JSONEncode(data))
	return data
end

local function SaveUpgrades(player)
	local upgrades = GetUpgradesTable(player)
	pcall(function()
		UpgradeStore:SetAsync(player.UserId, upgrades)
	end)
end

----------------------------------------------------
-- 🔹 Реакция на изменение монет (множитель)
----------------------------------------------------
local function ApplyCoinMultiplier(player, newValue, lastValue)
	local delta = newValue - lastValue
	if delta <= 0 then return end

	local upgrades = GetUpgradesTable(player)
	local multiplier = upgrades.CoinMultiplier or 1

	local bonus = math.floor(delta * multiplier - delta)
	if bonus > 0 then
		player.leaderstats.Coins.Value += bonus
	end
end

----------------------------------------------------
-- 🔹 Игрок зашёл
----------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local upgrades = LoadUpgrades(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		ApplyUpgrades(player)
	end)

	player:WaitForChild("leaderstats")
	local coins = player.leaderstats:WaitForChild("Coins")

	local lastValue = coins.Value
	coins:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = coins.Value
		ApplyCoinMultiplier(player, newValue, lastValue)
		lastValue = coins.Value
	end)
end)

----------------------------------------------------
-- 🔹 Игрок вышел
----------------------------------------------------
Players.PlayerRemoving:Connect(SaveUpgrades)

----------------------------------------------------
-- 🔹 Покупка апгрейда
----------------------------------------------------
UpgradeEvent.OnServerEvent:Connect(function(player, upgradeName)
	local upgrades = GetUpgradesTable(player)
	local currentLevel = upgrades[upgradeName] or 1
	local maxLevel = MAX_LEVELS[upgradeName] or 10

	if currentLevel >= maxLevel then
		UpgradeEvent:FireClient(player, upgradeName, false, "Макс уровень!")
		return
	end

	local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	if not coins then return end

	local price = LEVEL_PRICES[currentLevel]
	if coins.Value < price then
		UpgradeEvent:FireClient(player, upgradeName, false, "Недостаточно монет!")
		return
	end

	-- списываем монеты
	coins.Value -= price

	-- повышаем уровень
	upgrades[upgradeName] = currentLevel + 1
	player:SetAttribute("Upgrades", HttpService:JSONEncode(upgrades))

	-- применяем эффект
	ApplyUpgrades(player)

	-- сохраняем
	SaveUpgrades(player)

	UpgradeEvent:FireClient(player, upgradeName, true)
end)