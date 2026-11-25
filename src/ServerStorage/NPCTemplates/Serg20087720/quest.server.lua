-- ServerStorage/NPCTemplates/Serg20087720/quest  (Script)  v2
-- Запускает диалог «hello_world» при нажатии на TalkPrompt.
-- Работает и как обычный серверный Script (тогда диалог стартует через
-- ServerStorage.DialogueServer.StartDialogue), и с RunContext = Client (тогда через FireServer).
-- Раньше скрипт на сервере сравнивал игрока с LocalPlayer (на сервере это nil), и диалог не начинался.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DIALOG_ID = "hello_world"

local npc = script.Parent
local prompt = npc:WaitForChild("TalkPrompt")

prompt.Triggered:Connect(function(player)
	if RunService:IsServer() then
		local folder = game:GetService("ServerStorage"):WaitForChild("DialogueServer", 10)
		local start = folder and folder:FindFirstChild("StartDialogue")
		if start then
			start:Fire(player, DIALOG_ID, npc)
		end
	elseif player == Players.LocalPlayer then
		ReplicatedStorage:WaitForChild("DialogueSystem"):WaitForChild("StartDialogue"):FireServer(DIALOG_ID)
	end
end)
