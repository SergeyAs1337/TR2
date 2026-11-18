local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("GambleEvent")

-- Глобальная статистика
local globalStats = Instance.new("Folder")
globalStats.Name = "GlobalStats"
globalStats.Parent = ReplicatedStorage

local totalLost = Instance.new("IntValue")
totalLost.Name = "TotalLost"
totalLost.Value = 0
totalLost.Parent = globalStats

remote.OnServerEvent:Connect(function(player, bet)
	if typeof(bet) ~= "number" or bet <= 0 then return end

	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local coins = stats:FindFirstChild("Coins")
	if not coins or coins.Value < bet then return end

	-- Снимаем ставку
	coins.Value = coins.Value - bet

	-- Генерируем случайный результат (0–100)
	local result = math.random() * 100
	local win = 0

	-- Вероятности:
	-- 1% шанс x10
	-- 44% шанс x2
	-- 55% проигрыш
	if result <= 1 then
		win = bet * 10
	elseif result <= 25 then
		win = bet * 2
	else
		totalLost.Value += bet
	end

	if win > 0 then
		coins.Value += win
	end
end)