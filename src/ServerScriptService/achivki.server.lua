-- ServerScriptService/achivki  (Script)  v2 — бейджи и монеты за количество смертей
-- Что исправлено:
--  * раньше на КАЖДУЮ смерть проверялись все бейджи (до 6 запросов к Roblox): лимиты BadgeService
--    кончались. Теперь каждый бейдж проверяется один раз за сессию;
--  * две смерти подряд могли выдать монеты за один бейдж дважды (проверки шли параллельно).
--    Теперь одна проверка на игрока за раз;
--  * не зависает, если leaderstats так и не появились.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

-- Бейджи и награды за количество смертей
local DeathAchievements = {
	[0] = {badgeId = 4411658371875021, reward = 50},
	[1] = {badgeId = 1061211277070394, reward = 20},
	[10] = {badgeId = 3815151093631676, reward = 50},
	[100] = {badgeId = 2687414340719451, reward = 100},
	[1000] = {badgeId = 2787688261301921, reward = 500}, -- укажи реальные ID
	[1000000] = {badgeId = 2019746548973271, reward = 100000},
}

local checked = {} -- checked[player][порог] = true: уже есть / уже выдан / выдавать не нужно
local busy = {}

-- Выдать бейдж, если его ещё нет. Возвращает true, если выдали сейчас.
local function awardBadgeOnce(player, badgeId)
	local ok, hasBadge = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
	if not ok then
		return false, false -- не узнали: попробуем при следующей смерти
	end
	if hasBadge then
		return false, true
	end
	local awardOk, result = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
	local awarded = awardOk and result ~= false
	return awarded, awarded
end

local function checkAchievements(player)
	if busy[player] then
		busy[player] = "again" -- проверим ещё раз, когда закончится текущая
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local deaths = stats and stats:FindFirstChild("Deaths")
	if not deaths then
		return
	end
	busy[player] = true
	local done = checked[player]
	if not done then
		done = {}
		checked[player] = done
	end

	for amount, data in DeathAchievements do
		if not player.Parent then
			break
		end
		if deaths.Value >= amount and not done[amount] then
			local awardedNow, settled = awardBadgeOnce(player, data.badgeId)
			if settled then
				done[amount] = true
			end
			if awardedNow then
				local coins = stats:FindFirstChild("Coins")
				if coins then
					coins.Value += data.reward
				end
			end
		end
	end

	local again = busy[player] == "again"
	busy[player] = nil
	if again and player.Parent then
		checkAchievements(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats", 120)
	local deaths = leaderstats and leaderstats:WaitForChild("Deaths", 30)
	if not deaths then
		return
	end
	deaths:GetPropertyChangedSignal("Value"):Connect(function()
		checkAchievements(player)
	end)
	checkAchievements(player)
end)

Players.PlayerRemoving:Connect(function(player)
	checked[player] = nil
	busy[player] = nil
end)
