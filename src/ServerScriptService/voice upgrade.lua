local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if ReplicatedStorage:FindFirstChild("SendLikelySpeakingUsers") then
	ReplicatedStorage.SendLikelySpeakingUsers.OnClientEvent:Connect(function(likelySpeakingUsers)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				local head = character:FindFirstChild("Head")
				local indicator = head and head:FindFirstChild("VoiceIndicator")

				-- Проверяем, есть ли игрок в списке говорящих
				local isSpeaking = table.find(likelySpeakingUsers, player)

				-- Показываем/скрываем индикатор
				if isSpeaking and not indicator then
					local gui = Instance.new("BillboardGui")
					gui.Name = "VoiceIndicator"
					gui.Size = UDim2.new(0, 50, 0, 50)
					gui.StudsOffset = Vector3.new(0, 2, 0)
					gui.AlwaysOnTop = true
					gui.Parent = head

					local image = Instance.new("ImageLabel")
					image.Size = UDim2.new(1, 0, 1, 0)
					image.BackgroundTransparency = 1
					image.Image = "rbxassetid://1234567890" -- сюда вставь иконку микрофона
					image.Parent = gui

				elseif not isSpeaking and indicator then
					indicator:Destroy()
				end
			end
		end
	end)
end
