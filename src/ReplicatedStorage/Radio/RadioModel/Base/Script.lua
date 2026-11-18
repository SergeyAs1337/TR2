local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playTrack = ReplicatedStorage:WaitForChild("PlayTrack")

playTrack.OnServerEvent:Connect(function(player, soundId)
	for _, radio in pairs(workspace:GetChildren()) do
		if radio:GetAttribute("Owner") == player.UserId and radio:FindFirstChild("PrimaryPart") then
			-- Удалим старый звук, если он есть
			local existingSound = radio.PrimaryPart:FindFirstChild("RadioSound")
			if existingSound then
				existingSound:Destroy()
			end

			-- Создаём новый звук
			local sound = Instance.new("Sound")
			sound.Name = "RadioSound"
			sound.SoundId = soundId
			sound.Looped = true
			sound.Volume = 0.7
			sound.EmitterSize = 7
			sound.MaxDistance = 70
			sound.RollOffMode = Enum.RollOffMode.Inverse
			sound.Parent = radio.PrimaryPart
			sound:Play()
		end
	end
end)
