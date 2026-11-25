local ReplicatedStorage = game:GetService("ReplicatedStorage")
local event = ReplicatedStorage:WaitForChild("ShowNexbotMessage")
local label = script.Parent:WaitForChild("MessageLabel")

event.OnClientEvent:Connect(function(text)
	label.Text = text
	label.Visible = true
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1

	-- Плавное появление
	for i = 1, 20 do
		label.TextTransparency = 1 - i * 0.05
		label.TextStrokeTransparency = 1 - i * 0.05
		task.wait(0.02)
	end

	task.wait(2.5)

	-- Плавное исчезновение
	for i = 1, 20 do
		label.TextTransparency = i * 0.05
		label.TextStrokeTransparency = i * 0.05
		task.wait(0.02)
	end

	label.Visible = false
end)
