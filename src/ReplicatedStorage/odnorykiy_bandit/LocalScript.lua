-- ReplicatedStorage/odnorykiy_bandit/LocalScript  (v2)
-- Инструмент только открывает окно. Само окно строит и обслуживает модуль GambleScreen:
-- он же отправляет ставку на сервер и показывает счётчик «Проиграно всеми».

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local tool = script.Parent
local GambleScreen = require(ReplicatedStorage:WaitForChild("GambleScreen"))
local screen = GambleScreen.get(Players.LocalPlayer)

tool.Activated:Connect(function()
	screen.show()
end)
