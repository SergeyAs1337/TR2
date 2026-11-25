-- StarterPlayerScripts/AdminPanel  (LocalScript, v1)
-- Админ-панель, которая целиком строится кодом: собирать интерфейс в Studio не нужно.
-- Вкладки: События, Игроки, Сервер, Журнал. Открывается кнопкой «🛠 Админ» или клавишей F2.
--
-- Безопасность: панель только просит сервер. Админа и все аргументы проверяет AdminService.lua
-- при каждом запросе, поэтому подмена этого скрипта на клиенте ничего не даёт.
-- Не админ: сервер отвечает isAdmin=false, и панель вообще не создаётся.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("AdminRequest", 30)
if not request then
	return
end

-- Безопасный вызов сервера: (результат, сообщение) или nil при сбое
local function ask(...)
	local ok, first, second = pcall(request.InvokeServer, request, ...)
	if ok then
		return first, second
	end
	return nil
end

local state = ask("state")
if typeof(state) ~= "table" or not state.isAdmin then
	return -- не админ: панели нет
end

-- ===== Оформление =====
local COLORS = {
	background = Color3.fromRGB(24, 26, 33),
	panel = Color3.fromRGB(33, 36, 46),
	row = Color3.fromRGB(46, 50, 64),
	rowSelected = Color3.fromRGB(72, 94, 170),
	text = Color3.fromRGB(235, 238, 245),
	muted = Color3.fromRGB(160, 166, 185),
	accent = Color3.fromRGB(70, 120, 235),
	good = Color3.fromRGB(52, 150, 96),
	bad = Color3.fromRGB(180, 66, 66),
	warn = Color3.fromRGB(196, 132, 40),
}

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(instance, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, instance)
end

local function addPadding(instance, amount)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
	}, instance)
end

local function addList(instance, gap)
	return make("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, instance)
end

local function newLabel(parent, text, size, color)
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, size or 20),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or COLORS.text,
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end

local function newButton(parent, text, color, onClick, height)
	local button = make("TextButton", {
		Size = UDim2.new(1, 0, 0, height or 34),
		BackgroundColor3 = color or COLORS.accent,
		TextColor3 = COLORS.text,
		TextSize = 15,
		Font = Enum.Font.GothamMedium,
		Text = text,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	addCorner(button, 8)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

local function newInput(parent, placeholder, defaultText)
	local box = make("TextBox", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = COLORS.row,
		TextColor3 = COLORS.text,
		PlaceholderText = placeholder,
		PlaceholderColor3 = COLORS.muted,
		Text = defaultText or "",
		ClearTextOnFocus = false,
		TextSize = 15,
		Font = Enum.Font.Gotham,
		BorderSizePixel = 0,
	}, parent)
	addCorner(box, 8)
	return box
end

local function newScroll(parent, size, position)
	local scroll = make("ScrollingFrame", {
		Size = size or UDim2.new(1, 0, 1, 0),
		Position = position or UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)
	addList(scroll, 6)
	return scroll
end

-- Две нажатия подряд для опасных действий: первое «взводит» кнопку на 3 секунды
local function newConfirmButton(parent, text, color, onConfirm)
	local armed = false
	local button
	button = newButton(parent, text, color, function()
		if not armed then
			armed = true
			button.Text = "Точно? Нажми ещё раз"
			task.delay(3, function()
				if armed then
					armed = false
					button.Text = text
				end
			end)
			return
		end
		armed = false
		button.Text = text
		onConfirm()
	end)
	return button
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ===== Окно =====
local gui = make("ScreenGui", {
	Name = "AdminPanelV2",
	ResetOnSpawn = false,
	DisplayOrder = 50,
}, player:WaitForChild("PlayerGui"))

local toggleButton = newButton(gui, "🛠 Админ", COLORS.accent, nil, 34)
toggleButton.Size = UDim2.new(0, 96, 0, 34)
toggleButton.Position = UDim2.new(0, 12, 0, 56)

local panel = make("Frame", {
	Name = "Panel",
	Size = UDim2.new(0.92, 0, 0.8, 0),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
addCorner(panel, 12)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 640) }, panel)

make("TextLabel", {
	Size = UDim2.new(1, -60, 0, 36),
	Position = UDim2.new(0, 12, 0, 4),
	BackgroundTransparency = 1,
	Text = "Админ-панель",
	TextColor3 = COLORS.text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local closeButton = newButton(panel, "✕", COLORS.bad, nil, 30)
closeButton.Size = UDim2.new(0, 40, 0, 30)
closeButton.Position = UDim2.new(1, -48, 0, 7)

local tabBar = make("Frame", {
	Size = UDim2.new(1, -16, 0, 34),
	Position = UDim2.new(0, 8, 0, 44),
	BackgroundTransparency = 1,
}, panel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local content = make("Frame", {
	Size = UDim2.new(1, -16, 1, -130),
	Position = UDim2.new(0, 8, 0, 84),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
}, panel)
addCorner(content, 10)

local toastLabel = make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 34),
	Position = UDim2.new(0, 8, 1, -42),
	BackgroundColor3 = COLORS.good,
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
	Text = "",
	TextWrapped = true,
	BorderSizePixel = 0,
	Visible = false,
}, panel)
addCorner(toastLabel, 8)

local toastToken = 0
local function toast(text, good)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	toastLabel.BackgroundColor3 = good and COLORS.good or COLORS.bad
	toastLabel.Visible = true
	task.delay(3, function()
		if toastToken == myToken then
			toastLabel.Visible = false
		end
	end)
end

-- ===== Вкладки =====
local pages = {}
local tabButtons = {}
local tabNames = { "События", "Игроки", "Сервер", "Журнал" }

local function showPage(name)
	for pageName, page in pages do
		page.Visible = pageName == name
	end
	for tabName, button in tabButtons do
		button.BackgroundColor3 = tabName == name and COLORS.accent or COLORS.row
	end
end

for index, name in tabNames do
	local button = newButton(tabBar, name, COLORS.row, function()
		showPage(name)
	end, 34)
	button.Size = UDim2.new(0.25, -3, 1, 0)
	button.LayoutOrder = index
	tabButtons[name] = button

	local page = make("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, content)
	addPadding(page, 8)
	pages[name] = page
end

-- Обновление состояния с сервера (объявлено заранее, используется действиями)
local refresh
local applyState

-- Действие на сервере: показывает ответ и сразу обновляет состояние
local function run(actionName, args)
	task.spawn(function()
		local success, message = ask("action", actionName, args or {})
		if success == nil then
			toast("Нет ответа от сервера", false)
			return
		end
		if message == nil or message == "" then
			message = success and "Готово" or "Отказано"
		end
		toast(message, success == true)
		refresh()
	end)
end

-- ===== Вкладка «События» =====
local eventsPage = newScroll(pages["События"])
local eventsStatus = newLabel(eventsPage, "", 48, COLORS.text)
eventsStatus.LayoutOrder = 1
local durationBox = newInput(eventsPage, "Длительность, секунд (пусто = до остановки)", "120")
durationBox.LayoutOrder = 2
local stopButton = newButton(eventsPage, "⏹ Остановить текущее событие", COLORS.bad, function()
	run("stopEvent")
end)
stopButton.LayoutOrder = 3
local randomButton
randomButton = newButton(eventsPage, "🎲 Случайные события", COLORS.warn, function()
	run("setRandomEvents", { enabled = not (state.randomEnabled == true) })
end)
randomButton.LayoutOrder = 4
local eventsHeader = newLabel(eventsPage, "Запустить событие:", 20, COLORS.muted)
eventsHeader.LayoutOrder = 5

local eventButtons = {}
for index, eventName in state.events or {} do
	local button = newButton(eventsPage, "▶ " .. eventName, COLORS.row, function()
		local duration = tonumber(durationBox.Text)
		if duration ~= nil and duration <= 0 then
			duration = nil
		end
		run("startEvent", { name = eventName, duration = duration })
	end)
	button.LayoutOrder = 10 + index
	eventButtons[eventName] = button
end

-- ===== Вкладка «Игроки» =====
local playersPage = pages["Игроки"]
local playersList = newScroll(playersPage, UDim2.new(1, 0, 0, 170), UDim2.new(0, 0, 0, 0))
local actionsScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -178),
	Position = UDim2.new(0, 0, 0, 178),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, playersPage)
addList(actionsScroll, 6)

local selectedLabel = newLabel(actionsScroll, "Выбери игрока в списке", 22, COLORS.muted)
selectedLabel.LayoutOrder = 1
local amountBox = newInput(actionsScroll, "Сумма монет", "")
amountBox.LayoutOrder = 2
local reasonBox = newInput(actionsScroll, "Причина кика (необязательно)", "")
reasonBox.LayoutOrder = 3
local actionsGrid = make("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 4,
}, actionsScroll)
make("UIGridLayout", {
	CellSize = UDim2.new(0.5, -4, 0, 34),
	CellPadding = UDim2.new(0, 8, 0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionsGrid)

local selectedUserId = nil
local rows = {} -- [userId] = кнопка строки

local function selectedPlayerInfo()
	for _, info in state.players or {} do
		if info.userId == selectedUserId then
			return info
		end
	end
	return nil
end

-- Возвращает цель или сообщает, что игрок не выбран
local function needTarget()
	local info = selectedPlayerInfo()
	if not info then
		toast("Сначала выбери игрока в списке", false)
		return nil
	end
	return info
end

local function parseAmount(allowZero)
	local amount = tonumber(amountBox.Text)
	local minimum = allowZero and 0 or 1
	if not amount or amount % 1 ~= 0 or amount < minimum then
		toast("Введи целое число" .. (allowZero and " (0 или больше)" or " больше нуля"), false)
		return nil
	end
	return amount
end

local gridOrder = 0
local function gridButton(text, color, handler, confirm)
	gridOrder += 1
	local button
	if confirm then
		button = newConfirmButton(actionsGrid, text, color, handler)
	else
		button = newButton(actionsGrid, text, color, handler)
	end
	button.LayoutOrder = gridOrder
	return button
end

gridButton("💰 Выдать", COLORS.good, function()
	local info = needTarget()
	local amount = info and parseAmount(false)
	if info and amount then
		run("giveCoins", { target = info.userId, amount = amount })
	end
end)
gridButton("✏️ Установить", COLORS.accent, function()
	local info = needTarget()
	local amount = info and parseAmount(true)
	if info and amount then
		run("setCoins", { target = info.userId, amount = amount })
	end
end)
gridButton("🔄 Сброс статистики", COLORS.warn, function()
	local info = needTarget()
	if not info then
		return
	end
	-- Сброс идёт через LeaderboardManager: он чистит и таблицу лидеров
	local remote = ReplicatedStorage:FindFirstChild("ResetPlayerStatsAdminEvent")
	if not remote then
		toast("Нет ResetPlayerStatsAdminEvent", false)
		return
	end
	remote:FireServer(info.name)
	toast("Запрос на сброс отправлен: " .. info.name, true)
	task.delay(1.5, function()
		refresh()
	end)
end, true)
gridButton("💀 Убить", COLORS.bad, function()
	local info = needTarget()
	if info then
		run("kill", { target = info.userId })
	end
end)
gridButton("❤️ Вылечить", COLORS.good, function()
	local info = needTarget()
	if info then
		run("heal", { target = info.userId })
	end
end)
gridButton("🧊 Заморозить / разморозить", COLORS.accent, function()
	local info = needTarget()
	if info then
		run("freeze", { target = info.userId, frozen = not info.frozen })
	end
end)
gridButton("➡️ Телепорт к игроку", COLORS.accent, function()
	local info = needTarget()
	if info then
		run("teleportTo", { target = info.userId })
	end
end)
gridButton("⬅️ Игрок ко мне", COLORS.accent, function()
	local info = needTarget()
	if info then
		run("bring", { target = info.userId })
	end
end)
gridButton("👢 Кик", COLORS.bad, function()
	local info = needTarget()
	if info then
		run("kick", { target = info.userId, reason = reasonBox.Text })
	end
end, true)

local function playerRowText(info)
	local parts = { info.name }
	if info.isAdmin then
		table.insert(parts, "👑")
	end
	if info.frozen then
		table.insert(parts, "🧊")
	end
	if info.health ~= nil and info.health <= 0 then
		table.insert(parts, "💀")
	end
	table.insert(parts, "  💰" .. tostring(info.coins or "?"))
	table.insert(parts, "☠" .. tostring(info.deaths or "?"))
	return table.concat(parts, " ")
end

local function updateSelectionVisuals()
	for userId, row in rows do
		row.BackgroundColor3 = userId == selectedUserId and COLORS.rowSelected or COLORS.row
	end
	local info = selectedPlayerInfo()
	if info then
		selectedLabel.Text = ("Выбран: %s (@%s)"):format(info.displayName or info.name, info.name)
		selectedLabel.TextColor3 = COLORS.text
	else
		selectedLabel.Text = "Выбери игрока в списке"
		selectedLabel.TextColor3 = COLORS.muted
	end
end

-- Строки обновляются на месте (а не пересоздаются каждую секунду), чтобы нажатие не терялось
local function updatePlayers()
	local present = {}
	for index, info in state.players or {} do
		present[info.userId] = true
		local row = rows[info.userId]
		if not row then
			local userId = info.userId
			row = newButton(playersList, "", COLORS.row, function()
				selectedUserId = userId
				updateSelectionVisuals()
			end, 30)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextSize = 14
			rows[info.userId] = row
		end
		row.LayoutOrder = index
		row.Text = " " .. playerRowText(info)
	end
	for userId, row in rows do
		if not present[userId] then
			row:Destroy()
			rows[userId] = nil
			if selectedUserId == userId then
				selectedUserId = nil
			end
		end
	end
	updateSelectionVisuals()
end

-- ===== Вкладка «Сервер» =====
local serverPage = newScroll(pages["Сервер"])
local serverInfo = newLabel(serverPage, "", 80, COLORS.text)
serverInfo.LayoutOrder = 1
local announceBox = newInput(serverPage, "Объявление всем игрокам (до 150 символов)", "")
announceBox.LayoutOrder = 2
local announceButton = newButton(serverPage, "📢 Отправить всем", COLORS.accent, function()
	if announceBox.Text == "" then
		toast("Введи текст объявления", false)
		return
	end
	run("announce", { message = announceBox.Text })
	announceBox.Text = ""
end)
announceButton.LayoutOrder = 3
local healAllButton = newButton(serverPage, "❤️ Вылечить всех", COLORS.good, function()
	run("heal", { all = true })
end)
healAllButton.LayoutOrder = 4

-- ===== Вкладка «Журнал» =====
local logPage = newScroll(pages["Журнал"])
local logLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLORS.text,
	TextSize = 13,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
}, logPage)

-- ===== Обновление интерфейса =====
local function updateClock()
	local now = Workspace:GetServerTimeNow()
	local lines = {}
	if state.currentEvent then
		if state.eventEndsAt then
			table.insert(lines, ("Идёт: %s (осталось %s)"):format(state.currentEvent, formatTime(state.eventEndsAt - now)))
		else
			table.insert(lines, ("Идёт: %s (до ручной остановки)"):format(state.currentEvent))
		end
	else
		table.insert(lines, "Сейчас событий нет")
	end
	if state.randomEnabled then
		if state.nextRandomAt then
			table.insert(lines, ("Следующее случайное через %s"):format(formatTime(state.nextRandomAt - now)))
		else
			table.insert(lines, "Случайные события включены")
		end
	else
		table.insert(lines, "Случайные события ВЫКЛЮЧЕНЫ")
	end
	eventsStatus.Text = table.concat(lines, "\n")
end

applyState = function(newState)
	state = newState

	randomButton.Text = state.randomEnabled and "🎲 Случайные: ВКЛ (нажми, чтобы выключить)" or "🎲 Случайные: ВЫКЛ (нажми, чтобы включить)"
	randomButton.BackgroundColor3 = state.randomEnabled and COLORS.good or COLORS.warn
	for eventName, button in eventButtons do
		button.BackgroundColor3 = eventName == state.currentEvent and COLORS.accent or COLORS.row
	end
	updateClock()
	updatePlayers()

	local server = state.server or {}
	serverInfo.Text = ("Игроков: %s / %s\nРаботает: %s\nВерсия места: %s   Сервер: %s"):format(
		tostring(server.players or "?"),
		tostring(server.maxPlayers or "?"),
		formatTime(server.uptime or 0),
		tostring(server.placeVersion or "?"),
		tostring(server.jobId or "?")
	)

	local lines = {}
	for _, entry in state.log or {} do
		table.insert(lines, ("%s  %s: %s"):format(os.date("%H:%M:%S", entry.t), entry.admin, entry.text))
	end
	logLabel.Text = #lines > 0 and table.concat(lines, "\n") or "Пока пусто"
end

refresh = function()
	local fresh = ask("state")
	if typeof(fresh) == "table" and fresh.isAdmin then
		applyState(fresh)
	end
end

-- ===== Открытие и закрытие =====
local function setOpen(open)
	panel.Visible = open
	if open then
		refresh()
	end
end

toggleButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F2 then
		setOpen(not panel.Visible)
	end
end)

-- Состояние запрашиваем раз в секунду, но только пока панель открыта; часы тикают чаще
task.spawn(function()
	while true do
		if panel.Visible then
			refresh()
		end
		task.wait(1)
	end
end)
task.spawn(function()
	while true do
		if panel.Visible then
			updateClock()
		end
		task.wait(0.25)
	end
end)

showPage("События")
applyState(state)
