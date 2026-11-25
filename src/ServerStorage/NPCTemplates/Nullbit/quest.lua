-- ServerStorage/NPCTemplates/Nullbit/quest  (Script)  v2
-- Открывает окно апгрейдов при нажатии на TalkPrompt.
-- Новое окно апгрейдов (UpgradeShop) строится на клиенте, сервер его не видит, поэтому
-- старый способ (включить PlayerGui.UpgradeGUI.Frame с сервера) больше не работает.
-- Теперь сервер просит клиента открыть окно через модуль Notify.
-- С RunContext = Client тоже работает: открывает окно напрямую через UILib.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SCREEN = "Upgrades"

local npc = script.Parent
local prompt = npc:WaitForChild("TalkPrompt")

prompt.Triggered:Connect(function(player)
	if RunService:IsServer() then
		local Notify = require(game:GetService("ServerScriptService"):WaitForChild("Notify"))
		Notify.openScreen(player, SCREEN)
	elseif player == Players.LocalPlayer then
		require(ReplicatedStorage:WaitForChild("UILib")).open(SCREEN)
	end
end)
