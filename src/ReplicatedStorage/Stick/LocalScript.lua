-- ReplicatedStorage/Stick/LocalScript  v2: без отладочного вывода в консоль на каждый клик
local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local remote = tool:WaitForChild("FireRequest")

tool.Activated:Connect(function()
	if mouse and mouse.Hit then
		remote:FireServer(mouse.Hit.Position)
	end
end)
