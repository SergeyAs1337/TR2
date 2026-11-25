-- Workspace/Shop/odnoryk/Script.lua  (Script)  v2 — покупка «odnorykiy_bandit» через ProximityPrompt
-- Что исправлено: раньше скрипт падал с ошибкой, если монеты ещё не загрузились
-- (player.leaderstats), и молча печатал «not enough money» в консоль сервера.
-- Теперь проверяет всё безопасно, а игроку показывает уведомление. Цена — как и раньше,
-- из значения price рядом со скриптом.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ITEM_NAME = "odnorykiy_bandit" -- инструмент в ReplicatedStorage

local shop = script.Parent
local price = shop:WaitForChild("price")
local prompt = shop:WaitForChild("price_aktive")
local sound = shop:FindFirstChild("ui_buy")
local item = ReplicatedStorage:WaitForChild(ITEM_NAME)

local okNotify, Notify = pcall(function()
	return require(ServerScriptService:WaitForChild("Notify", 10))
end)
local function notify(player, text, color)
	if okNotify and Notify then
		Notify.send(player, text, color)
	end
end

local busy = {}

prompt.Triggered:Connect(function(player)
	if busy[player] then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local backpack = player:FindFirstChildOfClass("Backpack")
	local cost = price.Value
	if not coins or not backpack or typeof(cost) ~= "number" or cost < 0 then
		return
	end
	if coins.Value < cost then
		notify(player, "Не хватает монет: нужно " .. cost, "bad")
		return
	end

	busy[player] = true
	coins.Value -= cost -- проверка и списание без yield: дважды купить на одни монеты нельзя
	if sound then
		sound:Play()
	end
	item:Clone().Parent = backpack
	notify(player, "Куплено!", "good")
	task.delay(0.5, function()
		busy[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
