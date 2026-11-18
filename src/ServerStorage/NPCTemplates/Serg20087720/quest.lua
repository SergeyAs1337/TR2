local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueSystem = ReplicatedStorage:WaitForChild("DialogueSystem")
local StartDialogue = DialogueSystem:WaitForChild("StartDialogue")

local npc = script.Parent
local prompt = npc:WaitForChild("TalkPrompt")

local dialogID = "hello_world"

prompt.Triggered:Connect(function(player)
	if player == game.Players.LocalPlayer then
		StartDialogue:FireServer(dialogID)
	end
end)
