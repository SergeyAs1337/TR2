local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game.Players.LocalPlayer
local UpgradeEvent = ReplicatedStorage:WaitForChild("UpgradeRequest")
local HttpService = game:GetService("HttpService")

local gui = script.Parent
local frame = gui.Frame
local template = frame.Template
local close = gui.CloseButton
local hint = gui:FindFirstChild("Hint") -- подсказка

frame.Visible = false
hint.Visible = false

local UPGRADES = {
	Health = {max = 10, title = "Макс. ХП"},
	Speed = {max = 10, title = "Скорость"},
	Regen = {max = 10, title = "Реген"},
	CoinMultiplier = {max = 10, title = "Множитель монет"}
}

-- Получаем апгрейды игрока
local upgrades = Player:GetAttribute("Upgrades")
if typeof(upgrades) == "string" then upgrades = HttpService:JSONDecode(upgrades) end
upgrades = upgrades or {}

close.MouseButton1Click:Connect(function()
	frame.Visible = false
	close.Visible = false
end)

local function showHint(text)
	hint.Text = text
	hint.Visible = true
	task.delay(1.5, function()
		hint.Visible = false
	end)
end

-- Копирование стиля кнопки
local function styleButton(button)
	for _,child in pairs(template.BuyButton:GetChildren()) do
		child:Clone().Parent = button
	end
end

-- Создание апгрейда
local function createUpgrade(name, data)
	local new = template:Clone()
	new.Name = name
	new.Title.Text = data.title
	new.Visible = true

	local level = upgrades[name] or 1
	local fill = new.Bar.Fill
	fill.Size = UDim2.new(level / data.max, 0, 1, 0)
	if new:FindFirstChild("LevelText") then
		new.LevelText.Text = string.format("Уровень %d / %d", level, data.max)
	end

	styleButton(new.BuyButton)

	new.BuyButton.MouseButton1Click:Connect(function()
		UpgradeEvent:FireServer(name)
	end)

	-- Обновление после ответа сервера
	UpgradeEvent.OnClientEvent:Connect(function(upgradeName, success, message)
		if upgradeName ~= name then return end
		if not success then
			showHint(message)
			return
		end

		-- Обновляем локально
		upgrades = Player:GetAttribute("Upgrades")
		if typeof(upgrades) == "string" then upgrades = HttpService:JSONDecode(upgrades) end
		level = upgrades[name] or level

		fill.Size = UDim2.new(level / data.max, 0, 1, 0)
		if new:FindFirstChild("LevelText") then
			new.LevelText.Text = string.format("Уровень %d / %d", level, data.max)
		end
	end)

	new.Parent = frame
end

-- Создаём все апгрейды
for name,data in pairs(UPGRADES) do
	createUpgrade(name, data)
end
