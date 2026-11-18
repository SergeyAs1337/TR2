local tool = script.Parent
local eatEvent = tool:WaitForChild("EatEvent")

-- Создаём количество использований
local useCount = 0
local maxUses = 1

eatEvent.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = humanoid.MaxHealth + 100
	end

	useCount += 1
	if useCount >= maxUses then
		task.wait(4)
		tool:Destroy()
	end
end)
