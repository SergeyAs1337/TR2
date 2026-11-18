local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local remote = ReplicatedStorage:WaitForChild("AwardBadge")
local BADGE_ID = 2698462963901961 -- Замени на реальный ID

remote.OnServerEvent:Connect(function(player)
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, BADGE_ID)
	end)

	if not success then
		warn("Не удалось проверить наличие бейджа для", player.Name)
		return
	end

	if not hasBadge then
		local awardSuccess, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, BADGE_ID)
		end)
		if awardSuccess then
			print("Выдан бейдж игроку:", player.Name)
		else
			warn("Ошибка при выдаче бейджа игроку", player.Name, ":", err)
		end
	else
		print("У игрока уже есть бейдж:", player.Name)
	end
end)
