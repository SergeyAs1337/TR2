-- ReplicatedStorage/Radio/LocalScript  (LocalScript в инструменте)  v2
-- Клик инструментом ставит радио туда, куда смотрит курсор (на телефоне — куда коснулся).
-- Проверки (расстояние, одно радио на игрока) делает сервер (RadioHandler v2).
-- Убран отладочный вывод в консоль на каждый клик.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent
local placeRadio = ReplicatedStorage:WaitForChild("PlaceRadio")

local busy = false

tool.Activated:Connect(function()
	if busy then
		return
	end
	local mouse = player:GetMouse()
	if not mouse or not mouse.Hit then
		return
	end
	busy = true
	placeRadio:FireServer(mouse.Hit.Position)
	task.delay(0.5, function()
		busy = false
	end)
end)
