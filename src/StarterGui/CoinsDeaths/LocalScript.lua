local player = game:GetService("Players").LocalPlayer
local coinLabel = script.Parent.Frame.Coins

-- Ждём leaderstats и coins
local leaderstats = player:WaitForChild("leaderstats", 10) -- максимум 10 сек ожидания
if not leaderstats then
	warn("Не удалось найти leaderstats")
	return
end

local coins = leaderstats:WaitForChild("Coins", 10)
if not coins then
	warn("Не удалось найти coins")
	return
end

-- Функция обновления
local function updateCoins()
	coinLabel.Text = tostring(coins.Value)
end

-- Первое обновление
updateCoins()

-- Автообновление при изменении
coins:GetPropertyChangedSignal("Value"):Connect(updateCoins)
local player = game:GetService("Players").LocalPlayer
local coinLabel = script.Parent.Frame.Coins

-- Ждём leaderstats и coins
local leaderstats = player:WaitForChild("leaderstats", 10) -- максимум 10 сек ожидания
if not leaderstats then
	warn("Не удалось найти leaderstats")
	return
end

local coins = leaderstats:WaitForChild("Coins", 10)
if not coins then
	warn("Не удалось найти coins")
	return
end

-- Функция обновления
local function updateCoins()
	coinLabel.Text = tostring(coins.Value)
end

-- Первое обновление
updateCoins()

-- Автообновление при изменении
coins:GetPropertyChangedSignal("Value"):Connect(updateCoins)
