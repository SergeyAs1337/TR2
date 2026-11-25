local clearZone = script.Parent
local prompt = clearZone:FindFirstChild("ProximityPrompt")

if not prompt then
	warn("CleanScript on '" .. clearZone:GetFullName() .. "': ProximityPrompt named 'ProximityPrompt' not found. Please add a ProximityPrompt instance with this name as a child of the ClearZone Part for this script to work.")
	return
end

if not prompt:IsA("ProximityPrompt") then
	warn("CleanScript on '" .. clearZone:GetFullName() .. "': An instance named 'ProximityPrompt' was found, but it is a '" .. prompt.ClassName .. "', not a 'ProximityPrompt'. Please ensure it is the correct type.")
	return
end

prompt.Triggered:Connect(function(player)
	print("CleanScript: ProximityPrompt triggered by player: " .. player.Name)

	local character = player.Character
	if not character then
		warn("CleanScript: Character not found for player: " .. player.Name)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("CleanScript: Humanoid not found in character for player: " .. player.Name)
		return
	end

	if humanoid.Health <= 0 then
		warn("CleanScript: Player " .. player.Name .. "'s character is dead. No action taken.")
		return
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local toolName = tool.Name -- Store the tool's name before destroying it
		print("CleanScript: Tool '" .. toolName .. "' found in character of player: " .. player.Name .. ". Destroying tool.")
		tool:Destroy()
		print("CleanScript: Tool '" .. toolName .. "' destroyed successfully.")
	else
		warn("CleanScript: No tool found in character of player: " .. player.Name .. ". Please ensure a tool is equipped and visible to the server.")
	end
end)