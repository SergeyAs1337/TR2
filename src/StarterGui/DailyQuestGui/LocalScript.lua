local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("DailyQuestGui")
local topBar = gui:WaitForChild("TopBar")
local title = topBar:WaitForChild("Title")
local progressBG = topBar:WaitForChild("ProgressBarBG")
local fill = progressBG:WaitForChild("ProgressBarFill")
local tweenService = game:GetService("TweenService")
local event = game.ReplicatedStorage:WaitForChild("DailyQuestUpdate")

local maxDeaths = 15
local questDone = false

-- Цвета
local redColor = Color3.new(1, 0, 0)
local greenColor = Color3.new(0, 1, 0)

-- === ГАРАНТИРОВАННЫЙ ЦЕНТР ===
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 0) -- старт: спрятан выше      -- 40% ширины, 10% высоты
topBar.Visible = true

-- Полоска изначально пустая
fill.Size = UDim2.new(0, 0, 1, 0)
fill.Position = UDim2.new(0, 0, 0, 0)
fill.BackgroundTransparency = 1

-- Куда выезжает
local posVisible = UDim2.new(0.5, 0, 0.05, 0) -- по центру сверху
local posHidden = UDim2.new(0.5, 0, -0.3, 0)  -- спрятано выше

local tweenIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function showProgress(deaths)
	local percent = math.clamp(deaths / maxDeaths, 0, 1)
	local displayPercent = math.max(0.05, percent)

	topBar.Visible = true
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = redColor:lerp(greenColor, percent)

	-- Едем вниз
	tweenService:Create(topBar, tweenIn, {Position = posVisible}):Play()
	-- Заполняем
	fill:TweenSize(UDim2.new(displayPercent, 0, 1, 0), "Out", "Quad", 0.3, true)
end

local function hideProgress()
	task.delay(3, function()
		tweenService:Create(topBar, tweenOut, {Position = posHidden}):Play()
		task.delay(0.5, function()
			fill.Size = UDim2.new(0, 0, 1, 0)
			fill.BackgroundTransparency = 1
		end)
	end)
end

event.OnClientEvent:Connect(function(deaths)
	if questDone then return end

	showProgress(deaths)

	if deaths < maxDeaths then
		title.Text = string.format("Умер(ла): %d / %d", deaths, maxDeaths)
	else
		title.Text = string.format("Умер(ла): %d / %d", deaths, maxDeaths)
		task.delay(1, function()
			title.Text = "Ежедневный квест выполнен!"
		end)
		questDone = true
	end

	hideProgress()
end)