-- StarterPlayer/StarterPlayerScripts/EmotionMenu  (LocalScript)  v1 — меню эмоций
-- Заменяет StarterGui/EmotionGui и StarterPlayerScripts/ewq (оба удалить). Стиль админ-панели.
--   * открывается клавишей G или кнопкой «Эмоции» в HUD (на телефоне тоже);
--   * все танцы из ReplicatedStorage.Dances сеткой, текущий подсвечен;
--   * остановить: кнопка в меню, пробел, прыжок или B на геймпаде. Событие на сервер уходит,
--     только если игрок действительно танцует (раньше — на каждый прыжок).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local player = Players.LocalPlayer
local dancesFolder = ReplicatedStorage:WaitForChild("Dances")
local DanceRequest = ReplicatedStorage:WaitForChild("DanceRequest")
local StopDance = ReplicatedStorage:WaitForChild("DanceEnded")

local win
win = UILib.window({
	name = "Emotes",
	guiName = "EmotionGui",
	title = "💃  Эмоции",
	size = Vector2.new(480, 420),
	player = player,
	onOpen = function()
		win.refresh()
	end,
})
local body = win.body

UILib.text(body, "Клавиша G — открыть меню · пробел или прыжок — остановить", {
	Name = "Hint",
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 12,
	TextColor3 = THEME.muted,
	Font = THEME.fontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local grid = UILib.make("ScrollingFrame", {
	Name = "DanceList",
	Position = UDim2.new(0, 0, 0, 26),
	Size = UDim2.new(1, 0, 1, -76),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = THEME.row,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, body)
UILib.make("UIGridLayout", {
	CellSize = UDim2.new(1 / 3, -6, 0, 40),
	CellPadding = UDim2.new(0, 6, 0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

local stopButton = UILib.actionButton(body, {
	name = "StopButton",
	text = "Остановить",
	color = "bad",
	anchor = Vector2.new(0, 1),
	position = UDim2.new(0, 0, 1, 0),
	size = UDim2.new(1, 0, 0, 40),
	onClick = function()
		if player:GetAttribute("Dancing") then
			StopDance:FireServer()
		end
	end,
})

local buttons = {} -- buttons[имя] = кнопка

local function highlight()
	local current = player:GetAttribute("Dancing")
	for name, button in buttons do
		button.setColor(name == current and "accent" or "neutral")
	end
	stopButton.setEnabled(current ~= nil)
end

local function build()
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	buttons = {}
	local dances = {}
	for _, item in dancesFolder:GetChildren() do
		if item:IsA("Animation") then
			table.insert(dances, item.Name)
		end
	end
	table.sort(dances)
	for index, name in dances do
		buttons[name] = UILib.actionButton(grid, {
			name = "Dance" .. index,
			text = name,
			color = "neutral",
			layoutOrder = index,
			textSize = 14,
			onClick = function()
				DanceRequest:FireServer(name)
				win.close()
			end,
		})
	end
	highlight()
end

function win.refresh()
	build()
end

player:GetAttributeChangedSignal("Dancing"):Connect(highlight)

-- G — открыть/закрыть
ContextActionService:BindAction("ToggleEmotionMenu", function(_, state)
	if state == Enum.UserInputState.Begin then
		win.toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G)

-- Остановка: пробел / B на геймпаде / прыжок. Прыжку не мешаем (Pass).
local function stopIfDancing()
	if player:GetAttribute("Dancing") then
		StopDance:FireServer()
	end
end

ContextActionService:BindAction("StopDanceKey", function(_, state)
	if state == Enum.UserInputState.Begin then
		stopIfDancing()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Jumping:Connect(function(active)
			if active ~= false then
				stopIfDancing()
			end
		end)
	end
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
