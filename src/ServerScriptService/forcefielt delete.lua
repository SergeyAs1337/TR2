local function onCharacterAdded(character)
	local ff = character:FindFirstChildOfClass("ForceField")
	if ff then
		ff:Destroy()
	end
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end)
