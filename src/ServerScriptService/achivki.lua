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

-- Выдача бейджа (только если нет)
local function awardBadgeOnce(player, badgeId)
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)

	if success and not hasBadge then
		local ok = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)

		if ok then
			print("🎖️ Выдан бейдж " .. badgeId .. " игроку " .. player.Name)
			return true
		end
	end
	return false
end

-- Проверка достижения по смертям
local function tryAwardDeathAchievement(player, amount)
	local data = DeathAchievements[amount]
	if not data then return end

	if awardBadgeOnce(player, data.badgeId) then
		local stats = player:FindFirstChild("leaderstats")
		if stats and stats:FindFirstChild("Coins") then
			stats.Coins.Value += data.reward
			print("💰 +" .. data.reward .. " монет за " .. amount .. " смертей")
		end
	end
end

-- Проверка всех достижений
local function checkAchievements(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local deaths = stats:FindFirstChild("Deaths")
	if deaths then
		for amount in pairs(DeathAchievements) do
			if deaths.Value >= amount then
				tryAwardDeathAchievement(player, amount)
			end
		end
	end
end

-- Игрок зашёл
Players.PlayerAdded:Connect(function(player)
	player:WaitForChild("leaderstats")
	local deaths = player.leaderstats:FindFirstChild("Deaths")

	if deaths then
		deaths:GetPropertyChangedSignal("Value"):Connect(function()
			checkAchievements(player)
		end)
	end

	checkAchievements(player)
end)
