local tool = script.Parent
local handle = tool:WaitForChild("Handle")
local click = handle:WaitForChild("click")

local debounce = false

click.MouseClick:Connect(function(player)
	if debounce then return end
	debounce = true

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local clone = tool:Clone()
		clone.Parent = backpack
		tool:Destroy()
		print("Инструмент передан игроку в рюкзак")
	end

	task.wait(1)
	debounce = false
end)
