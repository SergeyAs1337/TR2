local ReplicatedStorage = game:GetService("ReplicatedStorage")
local dialogueFolder = ReplicatedStorage:WaitForChild("Dialogues")
local dialogueSystem = ReplicatedStorage:WaitForChild("DialogueSystem")

local StartDialogue = dialogueSystem:WaitForChild("StartDialogue")
local SelectDialogueOption = dialogueSystem:WaitForChild("SelectDialogueOption")

local playerStates = {}

StartDialogue.OnServerEvent:Connect(function(player, dialogID)
	local module = dialogueFolder:FindFirstChild(dialogID)
	if not module then
		warn("Dialogue module not found:", dialogID)
		return
	end

	local data = require(module)

	if data.OneTime and player:GetAttribute("Completed_" .. dialogID) then
		local final = {
			Text = "Привет! что-то ещё?",
			Options = {}
		}
		-- Передаём имя NPC как отдельный параметр
		StartDialogue:FireClient(player, dialogID, final, data.Name or "NPC")
		return
	end

	local step = data.Steps["start"]
	if not step then return end

	playerStates[player] = { DialogID = dialogID, Step = "start" }
	StartDialogue:FireClient(player, dialogID, step, data.Name or "NPC")
end)

SelectDialogueOption.OnServerEvent:Connect(function(player, optionIndex)
	local state = playerStates[player]
	if not state then return end

	local module = dialogueFolder:FindFirstChild(state.DialogID)
	if not module then return end

	local data = require(module)
	local currentStep = data.Steps[state.Step]
	if not currentStep or not currentStep.Options then return end

	local selectedOption = currentStep.Options[optionIndex]
	if not selectedOption then return end

	if selectedOption.Reward then
		selectedOption.Reward(player)
	end

	if selectedOption.Next then
		local nextStep = data.Steps[selectedOption.Next]
		if nextStep then
			state.Step = selectedOption.Next
			StartDialogue:FireClient(player, state.DialogID, nextStep, data.Name or "NPC")
		else
			playerStates[player] = nil
		end
	else
		playerStates[player] = nil

		if data.OneTime then
			player:SetAttribute("Completed_" .. state.DialogID, true)
		end
	end
end)

game.Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)
