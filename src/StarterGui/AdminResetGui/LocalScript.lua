-- 📦 Сервисы
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🧍 Игрок и GUI
local player = Players.LocalPlayer
local adminGui = script.Parent
local toggleButton = adminGui:WaitForChild("ToggleButton")
local mainFrame = adminGui:WaitForChild("MainFrame")

-- 🔘 Кнопки и поля
local playerNameInput = mainFrame:WaitForChild("PlayerNameInput")
local resetButton = mainFrame:WaitForChild("ResetButton")
local giveCoinsButton = mainFrame:WaitForChild("GiveCoinsButton")
local coinsAmountInput = mainFrame:WaitForChild("CoinsAmountInput")
local eventsButton = mainFrame:WaitForChild("EventsButton")
local eventsListFrame = mainFrame:WaitForChild("EventsListFrame")
local durationInput = mainFrame.EventsListFrame:WaitForChild("DurationInput")
local uiListLayout = eventsListFrame:WaitForChild("UIListLayout")

-- 🌐 RemoteEvents
local resetStatsEvent = ReplicatedStorage:WaitForChild("ResetPlayerStatsAdminEvent")
local giveCoinsEvent = ReplicatedStorage:WaitForChild("GiveCoinsAdminEvent")
local eventStartRemote = ReplicatedStorage:WaitForChild("EventAnnouncement")
local eventStopRemote = ReplicatedStorage:WaitForChild("StopEventRemote")

-- 📋 Модуль с ивентами
local Events = require(ReplicatedStorage:WaitForChild("EventManager"))

-- 🛡️ Проверка на админа
local ADMIN_USER_IDS = {
	940118285,
	3322927329
}

local function isAdmin()
	for _, adminId in ipairs(ADMIN_USER_IDS) do
		if player.UserId == adminId then
			return true
		end
	end
	return false
end

-- Показываем GUI только админам
if isAdmin() then
	adminGui.Enabled = true
	mainFrame.Visible = false
	toggleButton.Visible = true
	toggleButton.Text = "Развернуть"
else
	adminGui.Enabled = false
end

-- Переключение главной панели
local mainVisible = false
toggleButton.MouseButton1Click:Connect(function()
	mainVisible = not mainVisible
	mainFrame.Visible = mainVisible
	toggleButton.Text = mainVisible and "Свернуть" or "Развернуть"
end)

-- 💰 Выдача монет
giveCoinsButton.MouseButton1Click:Connect(function()
	local name = playerNameInput.Text
	local amount = tonumber(coinsAmountInput.Text)
	if name == "" or not amount or amount <= 0 then return end
	giveCoinsEvent:FireServer(name, amount)
	playerNameInput.Text = ""
	coinsAmountInput.Text = ""
end)

-- 🔄 Сброс статистики
resetButton.MouseButton1Click:Connect(function()
	local name = playerNameInput.Text
	if name == "" then return end
	resetStatsEvent:FireServer(name)
	playerNameInput.Text = ""
end)

-- 🗨️ Чат-команда
player.Chatted:Connect(function(msg)
	if msg:lower() == "/resetgui" and isAdmin() then
		adminGui.Enabled = not adminGui.Enabled
	end
end)

-- 📜 Отображение/скрытие списка ивентов
local eventsVisible = false

local function updateCanvas()
	eventsListFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 10)
end

local function populateEventList()
	-- Очистка
	for _, child in ipairs(eventsListFrame:GetChildren()) do
		if child:IsA("TextButton") and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	for _, event in ipairs(Events.List) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 30)
		btn.Text = event.Name
		btn.BackgroundColor3 = Color3.fromRGB(200, 200, 255)
		btn.Font = Enum.Font.SourceSans
		btn.TextScaled = true
		btn.Parent = eventsListFrame

		btn.MouseButton1Click:Connect(function()
			local duration = tonumber(durationInput.Text)
			if not duration or duration <= 0 then duration = nil end
			eventStartRemote:FireServer(event.Name, duration)
		end)

		-- Кнопка остановки
		local stopBtn = Instance.new("TextButton")
		stopBtn.Size = UDim2.new(0.3, 0, 1, 0)
		stopBtn.Position = UDim2.new(0.7, 0, 0, 0)
		stopBtn.Text = "Стоп"
		stopBtn.TextScaled = true
		stopBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 150)
		stopBtn.Font = Enum.Font.SourceSans
		stopBtn.Parent = btn

		stopBtn.MouseButton1Click:Connect(function()
			eventStopRemote:FireServer(event.Name)
		end)
	end

	updateCanvas()
end

uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

eventsButton.MouseButton1Click:Connect(function()
	eventsVisible = not eventsVisible
	eventsListFrame.Visible = eventsVisible
	if eventsVisible then
		populateEventList()
	end
end)
