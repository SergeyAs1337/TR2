local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Создаём RemoteEvent, если его нет
local popupEvent = ReplicatedStorage:FindFirstChild("CoinPopup")
if not popupEvent then
	popupEvent = Instance.new("RemoteEvent")
	popupEvent.Name = "CoinPopup"
	popupEvent.Parent = ReplicatedStorage
end

-- 🔁 Функция для выдачи монет с отображением всплывашки
local function giveCoins(player, amount)
	if not player or not player:IsDescendantOf(game) then return end

	local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	if not coins then
		warn("У игрока нет leaderstats.Coins")
		return
	end

	coins.Value += amount

	-- Отправляем клиенту всплывашку
	pcall(function()
		popupEvent:FireClient(player, amount)
	end)
end


