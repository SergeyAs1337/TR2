local tool = script.Parent
local player = game.Players.LocalPlayer
local remote = tool:WaitForChild("FireBazooka")

tool.Activated:Connect(function()
	local mouse = player:GetMouse()
	if mouse and mouse.Hit then
		remote:FireServer(mouse.Hit.Position)
	end
end)
