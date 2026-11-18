local button = script.Parent
local RunService = game:GetService("RunService")

local hue = 0

RunService.RenderStepped:Connect(function(dt)
	hue = (hue + dt * 0.2) % 1  -- скорость радуги
	local color = Color3.fromHSV(hue, 1, 1)
	button.BackgroundColor3 = color
end)
