local camera = workspace.CurrentCamera
local player = game.Players.LocalPlayer
local menuGui = script.Parent
menuGui.Enabled = true

local menuFrame = menuGui:WaitForChild("MenuFrame")
local playButton = menuFrame:WaitForChild("PlayButton")
local toggleButton = menuGui:WaitForChild("ToggleMenuButton")
local menuCameraPart = workspace:WaitForChild("MenuCameraPart")

-- Настройка UI для адаптивности
local function setupUI()
	-- Пример: Кнопка "Играть" внизу по центру меню
	playButton.AnchorPoint = Vector2.new(0.1, 0.3)
	playButton.Position = UDim2.new(-5.111, 0, -0.319, 0)  -- по центру по горизонтали, 80% вниз по вертикали{-5.111, 0},{-0.319, 0}

	-- Кнопка "Меню" (Toggle) — в верхнем левом углу экрана
	toggleButton.AnchorPoint = Vector2.new(0, 0)
	toggleButton.Position = UDim2.new(0.02, 0, 0.02, 0) -- 2% от левого и верхнего края экрана

	-- Само меню по центру экрана (если нужно)
	menuFrame.AnchorPoint = Vector2.new(0.5, 0,5.0)
	menuFrame.Position = UDim2.new(0.932, 0, 0.957, 0)
end

-- Установка камеры
local function setMenuCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = menuCameraPart.CFrame
end

local function setPlayerCamera()
	camera.CameraType = Enum.CameraType.Custom
end

-- Показать главное меню
local function showMenu()
	menuFrame.Visible = true
	toggleButton.Visible = false -- Скрыть кнопку меню
	setMenuCamera()
end

-- Скрыть главное меню
local function hideMenu()
	menuFrame.Visible = false
	toggleButton.Visible = true -- Показать кнопку меню
	setPlayerCamera()
end

-- Кнопка "Играть"
playButton.MouseButton1Click:Connect(function()
	hideMenu()
end)

-- Кнопка "Меню"
toggleButton.MouseButton1Click:Connect(function()
	showMenu()
end)

setupUI()

-- При запуске показать главное меню
showMenu()