local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local gui = script.Parent
local main = gui:WaitForChild("MainFrame")
local textLabel = main:WaitForChild("DialogText")
local optionsFrame = main:WaitForChild("OptionsFrame")
local interactButton = main:WaitForChild("InteractButton")
local npcNameLabel = main:WaitForChild("NpcNameLabel")

local StartDialogue = ReplicatedStorage:WaitForChild("DialogueSystem"):WaitForChild("StartDialogue")
local SelectOption = ReplicatedStorage:WaitForChild("DialogueSystem"):WaitForChild("SelectDialogueOption")

-- Поднять интерфейс и изменить кнопки на телефонах
if UIS.TouchEnabled then
	-- Поднимаем интерфейс на 50 пикселей вверх
	local pos = main.Position
	main.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset - 60)
end

local currentLines = {}
local currentLineIndex = 0
local currentOptions = {}
local waitingForChoice = false
local isTyping = false

local function clearOptions()
	for _, btn in pairs(optionsFrame:GetChildren()) do
		if btn:IsA("TextButton") then
			btn:Destroy()
		end
	end
end

local function showOptions()
	waitingForChoice = true
	textLabel.Visible = false
	optionsFrame.Visible = true
	interactButton.Visible = false
	npcNameLabel.Visible = false
	clearOptions()

	local buttonHeight = 40
	if UIS.TouchEnabled then
		buttonHeight = 20 -- Меньше кнопки на телефонах
	end

	for i, option in ipairs(currentOptions) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -10, 0, buttonHeight)
		button.Position = UDim2.new(0, 5, 0, (i - 1) * (buttonHeight + 5))
		button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		button.TextColor3 = Color3.new(1,1,1)
		button.TextScaled = true
		button.Text = option.Text
		button.Parent = optionsFrame

		button.MouseButton1Click:Connect(function()
			gui.Enabled = false
			clearOptions()
			waitingForChoice = false
			optionsFrame.Visible = false
			textLabel.Visible = true
			npcNameLabel.Visible = false
			interactButton.Visible = false
			SelectOption:FireServer(i)
		end)
	end
end

local function typeText(text)
	isTyping = true
	textLabel.Text = ""
	for i = 1, #text do
		textLabel.Text = string.sub(text, 1, i)
		wait(0.03)
	end
	isTyping = false
end

local function showNextLine()
	if isTyping then return end

	currentLineIndex += 1

	if currentLines[currentLineIndex] then
		textLabel.Visible = true
		optionsFrame.Visible = false
		interactButton.Visible = true
		npcNameLabel.Visible = true
		coroutine.wrap(function()
			typeText(currentLines[currentLineIndex])
		end)()
	else
		if #currentOptions > 0 then
			showOptions()
		else
			gui.Enabled = false
			interactButton.Visible = false
			npcNameLabel.Visible = false
		end
	end
end

StartDialogue.OnClientEvent:Connect(function(dialogID, stepData, npcName)
	gui.Enabled = true
	main.Visible = true
	textLabel.Visible = true
	optionsFrame.Visible = false
	interactButton.Visible = true
	npcNameLabel.Visible = true

	npcNameLabel.Text = npcName or "NPC"

	if stepData.Lines then
		currentLines = stepData.Lines
	elseif stepData.Text then
		currentLines = {stepData.Text}
	else
		currentLines = {}
	end

	currentLineIndex = 0
	currentOptions = stepData.Options or {}
	waitingForChoice = false

	showNextLine()
end)

UIS.InputBegan:Connect(function(input, gp)
	if not gui.Enabled or waitingForChoice then return end
	if input.KeyCode == Enum.KeyCode.E then
		showNextLine()
	end
end)

interactButton.MouseButton1Click:Connect(function()
	if gui.Enabled and not waitingForChoice then
		showNextLine()
	end
end)

gui.Enabled = false
