local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local dancesFolder = ReplicatedStorage:WaitForChild("Dances")
local DanceRequest = ReplicatedStorage:WaitForChild("DanceRequest")
local StopDance = ReplicatedStorage:WaitForChild("DanceEnded")

local screenGui = script.Parent
local menu = screenGui:WaitForChild("EmotionMenu")
local toggleButton = screenGui:WaitForChild("ToggleButton")
local listFrame = menu:WaitForChild("DanceListFrame")
local prevButton = menu:WaitForChild("PrevButton")
local nextButton = menu:WaitForChild("NextButton")
local pageLabel = menu:WaitForChild("PageLabel")

local danceAnimations = dancesFolder:GetChildren()
local pageSize = 8
local currentPage = 1
local currentDanceName = nil
local canPlay = true

-- Показываем кнопку только на мобильных устройствах
toggleButton.Visible = UserInputService.TouchEnabled
menu.Visible = false

local function updateMenu()
	listFrame:ClearAllChildren()
	local startIndex = (currentPage - 1) * pageSize + 1
	local endIndex = math.min(startIndex + pageSize - 1, #danceAnimations)

	for i = startIndex, endIndex do
		local anim = danceAnimations[i]
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 110, 0, 40)
		button.Position = UDim2.new(0, ((i - startIndex) % 4) * 115 + 10, 0, math.floor((i - startIndex) / 4) * 50)
		button.Text = anim.Name
		button.Parent = listFrame

		button.MouseButton1Click:Connect(function()
			if not canPlay then return end
			canPlay = false
			currentDanceName = anim.Name
			DanceRequest:FireServer(anim.Name)
			task.delay(1, function() canPlay = true end)
		end)
	end

	pageLabel.Text = string.format("%d / %d", currentPage, math.ceil(#danceAnimations / pageSize))
end

prevButton.MouseButton1Click:Connect(function()
	if currentPage > 1 then
		currentPage -= 1
		updateMenu()
	end
end)

nextButton.MouseButton1Click:Connect(function()
	if currentPage < math.ceil(#danceAnimations / pageSize) then
		currentPage += 1
		updateMenu()
	end
end)

toggleButton.MouseButton1Click:Connect(function()
	menu.Visible = not menu.Visible
	if menu.Visible then updateMenu() end
end)

-- Кнопка G для ПК — открыть/закрыть меню
ContextActionService:BindAction("ToggleEmotionMenu", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		menu.Visible = not menu.Visible
		if menu.Visible then updateMenu() end
	end
end, false, Enum.KeyCode.G)

-- Прерывание эмоции пробелом (не мешает прыжку)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Space and currentDanceName then
		currentDanceName = nil
		StopDance:FireServer()
	end
end)
