local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local remote = ReplicatedStorage:WaitForChild("AwardBadge")
local BADGE_ID = 2698462963901961 -- Замени на реальный ID

-- v2: не больше одной проверки на игрока за сессию (раньше событие можно было спамить,
-- и каждый вызов шёл запросом к BadgeService). Бейдж выдаётся по сигналу клиента
-- (чёрная фигура видна только ему), поэтому защититься от читера полностью нельзя —
-- но это только бейдж, без монет.
local handled = {}
game:GetService("Players").PlayerRemoving:Connect(function(player)
	handled[player] = nil
end)

remote.OnServerEvent:Connect(function(player)
	if handled[player] then
		return
	end
	handled[player] = true
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
