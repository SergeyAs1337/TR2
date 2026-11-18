local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local remote = tool:WaitForChild("FireRequest")

print("LocalScript запущен")

tool.Activated:Connect(function()
	print("Tool activated")
	if mouse and mouse.Hit and remote then
		print("Отправляю FireRequest с позицией:", mouse.Hit.Position)
		remote:FireServer(mouse.Hit.Position)
	else
		warn("Не могу отправить FireRequest - mouse или mouse.Hit или remote отсутствует")
	end
end)
