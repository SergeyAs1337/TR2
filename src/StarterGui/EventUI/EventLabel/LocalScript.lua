local eventLabel = script.Parent
local remote = game.ReplicatedStorage:WaitForChild("EventAnnouncement")
local tweenService = game:GetService("TweenService")

-- Настройка для адаптивности
eventLabel.AnchorPoint = Vector2.new(0.5, 0)
eventLabel.Position = UDim2.new(0.5, 0, -0.1, 0)
eventLabel.Size = UDim2.new(0.6, 0, 0.05, 0)
eventLabel.TextScaled = true
eventLabel.BackgroundTransparency = 1
eventLabel.TextColor3 = Color3.new(1, 1, 1)
eventLabel.TextStrokeTransparency = 0.5
eventLabel.Font = Enum.Font.GothamBold
eventLabel.Visible = false

local isShowing = false
local currentTween = nil

remote.OnClientEvent:Connect(function(eventName)

	if isShowing then 
		return 
	end
	isShowing = true

	eventLabel.Text = eventName
	eventLabel.Visible = true
	eventLabel.Position = UDim2.new(0.5, 0, -0.1, 0)

	if currentTween then
		currentTween:Cancel()
	end

	currentTween = tweenService:Create(eventLabel, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.05, 0)
	})
	currentTween:Play()
	currentTween.Completed:Wait()

	wait(5)

	if currentTween then
		currentTween:Cancel()
	end

	currentTween = tweenService:Create(eventLabel, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, -0.1, 0)
	})
	currentTween:Play()
	currentTween.Completed:Wait()

	eventLabel.Visible = false
	isShowing = false
end)
