-- ReplicatedStorage/UILib  (ModuleScript, только для клиента)  v2 — мультяшный стиль
-- Общие кирпичики для интерфейсов, которые строятся кодом. Подключение:
--   local UILib = require(game:GetService("ReplicatedStorage"):WaitForChild("UILib"))
--
-- Что внутри:
--   THEME             — цвета, шрифты, толщина обводки. Поменяй здесь, и поменяется вся игра.
--   toonButton(...)   — объёмная кнопка с тенью: нажимается вниз, увеличивается при наведении.
--   window(...)       — окно с шапкой, крестиком, затемнением и pop-анимацией. Само подстраивается
--                       под размер экрана (телефон / ПК). Открытые окна закрывают друг друга.
--   open/close/toggle — открыть окно по имени из любого LocalScript (например, кнопкой в HUD).
--   toast(...)        — короткое уведомление сверху экрана.
--   text, stroke, gradient, tween, bump, shake, fitScale, formatNumber, formatShort, formatTime.
-- Старые функции v1 (make, corner, padding, list, label, button, input, scroll, confirmButton,
-- COLORS) оставлены без изменений, ими пользуется админ-панель.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UILib = {}

-- ===================================================================================
-- Тема
-- ===================================================================================
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Каждый цвет кнопки задан тремя оттенками: top (блик сверху), face (основной), shade (тень снизу).
-- Оттенки заданы явно, без вычислений: так проще подбирать цвета под себя.
local THEME = {
	font = Enum.Font.GothamBlack, -- заголовки, числа, кнопки (кириллица поддерживается)
	fontBody = Enum.Font.GothamBold, -- обычный текст

	ink = rgb(30, 22, 44), -- обводки и тёмный текст
	white = rgb(255, 255, 255),
	cream = rgb(255, 248, 232), -- фон окон
	creamDark = rgb(244, 228, 196), -- карточки внутри окон
	muted = rgb(128, 110, 132), -- второстепенный текст на светлом фоне
	empty = rgb(214, 200, 180), -- пустые деления полосок
	dim = rgb(10, 6, 20), -- затемнение под окном

	stroke = 3, -- толщина обводки, пиксели
	radius = 14, -- скругление углов
	depth = 5, -- высота «тени» под кнопками

	palette = {
		yellow = { top = rgb(255, 236, 110), face = rgb(255, 200, 40), shade = rgb(204, 140, 10) },
		orange = { top = rgb(255, 180, 90), face = rgb(255, 128, 30), shade = rgb(196, 80, 10) },
		green = { top = rgb(140, 240, 110), face = rgb(70, 200, 80), shade = rgb(30, 140, 50) },
		red = { top = rgb(255, 130, 120), face = rgb(240, 66, 66), shade = rgb(170, 30, 40) },
		blue = { top = rgb(120, 200, 255), face = rgb(50, 145, 255), shade = rgb(20, 90, 200) },
		purple = { top = rgb(200, 150, 255), face = rgb(150, 80, 240), shade = rgb(96, 40, 180) },
		pink = { top = rgb(255, 160, 210), face = rgb(255, 90, 170), shade = rgb(190, 40, 120) },
		grey = { top = rgb(205, 200, 210), face = rgb(160, 152, 168), shade = rgb(110, 102, 120) },
	},

	-- Адаптация под экран: окна рассчитаны на экран refSize и масштабируются в пределах min..max
	refSize = Vector2.new(1100, 640),
	minScale = 0.6,
	maxScale = 1.25,
}
UILib.THEME = THEME

-- ===================================================================================
-- Базовые помощники (v1, без изменений)
-- ===================================================================================
UILib.COLORS = {
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
local COLORS = UILib.COLORS

-- Создаёт объект, выставляет свойства и ПОСЛЕДНИМ ставит Parent (так быстрее и без мерцания)
function UILib.make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end
local make = UILib.make

function UILib.corner(instance, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, instance)
end

function UILib.padding(instance, amount)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
	}, instance)
end

function UILib.list(instance, gap)
	return make("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, instance)
end

function UILib.label(parent, text, height, color)
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, height or 20),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or COLORS.text,
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end

-- Кнопка. onClick вызывается через Activated: работает и мышью, и пальцем, и геймпадом
function UILib.button(parent, text, color, onClick, height)
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
	UILib.corner(button, 8)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function UILib.input(parent, placeholder, defaultText)
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
	UILib.corner(box, 8)
	return box
end

function UILib.scroll(parent, size, position)
	local scroll = make("ScrollingFrame", {
		Size = size or UDim2.new(1, 0, 1, 0),
		Position = position or UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)
	UILib.list(scroll, 6)
	return scroll
end

-- Опасное действие: первое нажатие «взводит» кнопку на 3 секунды, второе выполняет
function UILib.confirmButton(parent, text, color, onConfirm)
	local armed = false
	local button
	button = UILib.button(parent, text, color, function()
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

-- ===================================================================================
-- Числа и время
-- ===================================================================================

-- 1234567 -> "1 234 567" (дробная часть отбрасывается, отрицательные поддерживаются)
function UILib.formatNumber(value)
	local n = tonumber(value)
	if not n or n ~= n then
		return "0"
	end
	n = n >= 0 and math.floor(n) or math.ceil(n)
	local sign = n < 0 and "-" or ""
	local digits = string.format("%d", math.abs(n))
	local out = {}
	local length = #digits
	for i = 1, length do
		table.insert(out, string.sub(digits, i, i))
		local remaining = length - i
		if remaining > 0 and remaining % 3 == 0 then
			table.insert(out, " ")
		end
	end
	return sign .. table.concat(out)
end

-- Короткая запись для HUD: до миллиона как formatNumber, дальше 1.25M, 12.5B, 3T
local SHORT_SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" } }
function UILib.formatShort(value)
	local n = tonumber(value)
	if not n or n ~= n then
		return "0"
	end
	local absolute = math.abs(n)
	for _, entry in SHORT_SUFFIXES do
		if absolute >= entry[1] then
			local scaled = absolute / entry[1]
			-- 3 значащие цифры, отбрасывая (не округляя вверх), чтобы 999 999 999 не стало «1000M»
			local decimals = scaled >= 100 and 0 or (scaled >= 10 and 1 or 2)
			local factor = 10 ^ decimals
			local text = string.format("%." .. decimals .. "f", math.floor(scaled * factor) / factor)
			if decimals > 0 then
				text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
			end
			return (n < 0 and "-" or "") .. text .. entry[2]
		end
	end
	return UILib.formatNumber(n)
end

-- 83 -> "1:23"
function UILib.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ===================================================================================
-- Мультяшные кирпичики
-- ===================================================================================

function UILib.palette(key)
	return THEME.palette[key] or THEME.palette.blue
end

-- Обводка. mode = "border" (по краю рамки) или "text" (контур букв)
function UILib.stroke(instance, thickness, color, mode)
	return make("UIStroke", {
		Thickness = thickness or THEME.stroke,
		Color = color or THEME.ink,
		ApplyStrokeMode = mode == "text" and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, instance)
end

-- Вертикальный градиент: светлее сверху, темнее снизу
function UILib.gradient(instance, top, bottom)
	return make("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	}, instance)
end

function UILib.tween(instance, time, goals, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goals
	)
	tween:Play()
	return tween
end

-- Надпись в мультяшном стиле: жирный шрифт, белые буквы с тёмным контуром.
-- props перекрывают значения по умолчанию (Size, Position, TextColor3, TextSize, ...).
-- props.strokeThickness = 0 убирает контур.
function UILib.text(parent, text, props)
	props = props or {}
	local thickness = props.strokeThickness
	local defaults = {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = THEME.white,
		TextSize = 20,
		Font = THEME.font,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	}
	for key, value in props do
		if key ~= "strokeThickness" then
			defaults[key] = value
		end
	end
	local label = make("TextLabel", defaults, parent)
	if thickness ~= 0 then
		UILib.stroke(label, thickness or 2, THEME.ink, "text")
	end
	return label
end

-- Быстрое «подпрыгивание» через UIScale (например, при изменении числа)
function UILib.bump(uiScale, amount)
	if not uiScale then
		return
	end
	uiScale.Scale = amount or 1.15
	UILib.tween(uiScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Покачивание: «нельзя», «ошибка»
function UILib.shake(guiObject)
	if not guiObject then
		return
	end
	task.spawn(function()
		for _, angle in { -6, 6, -4, 4, -2, 0 } do
			guiObject.Rotation = angle
			task.wait(0.04)
		end
		guiObject.Rotation = 0
	end)
end

-- UIScale, который подстраивает размер под экран. Возвращает сам UIScale.
function UILib.fitScale(guiObject)
	local scale = make("UIScale", { Name = "FitScale", Scale = 1 }, guiObject)
	local camera = Workspace.CurrentCamera
	local function update()
		local viewport = camera and camera.ViewportSize
		if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		local value = math.min(viewport.X / THEME.refSize.X, viewport.Y / THEME.refSize.Y)
		scale.Scale = math.clamp(value, THEME.minScale, THEME.maxScale)
	end
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		update()
	end
	return scale
end

function UILib.screenGui(name, displayOrder, player)
	player = player or Players.LocalPlayer
	return make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
end

-- ===================================================================================
-- Объёмная кнопка
-- ===================================================================================
-- opts: text, color (ключ палитры), size (UDim2), position, anchor, textSize, onClick,
--       name, layoutOrder, zIndex
-- Возвращает объект: root (рамка), face (TextButton, на неё вешается Activated), label,
--                    setText(text), setColor(key), setEnabled(bool), isEnabled()
function UILib.toonButton(parent, opts)
	opts = opts or {}
	local depth = THEME.depth
	local colors = UILib.palette(opts.color or "blue")

	local root = make("Frame", {
		Name = opts.name or "ToonButton",
		Size = opts.size or UDim2.new(0, 160, 0, 50),
		Position = opts.position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = opts.anchor or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = opts.layoutOrder or 0,
		ZIndex = opts.zIndex or 1,
	}, parent)
	local hoverScale = make("UIScale", { Name = "HoverScale", Scale = 1 }, root)

	local shadow = make("Frame", {
		Name = "Shadow",
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.new(0, 0, 0, depth),
		BackgroundColor3 = colors.shade,
		BorderSizePixel = 0,
		ZIndex = opts.zIndex or 1,
	}, root)
	UILib.corner(shadow, THEME.radius - 2)
	UILib.stroke(shadow, THEME.stroke)

	local face = make("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = opts.zIndex or 1,
	}, root)
	UILib.corner(face, THEME.radius - 2)
	UILib.stroke(face, THEME.stroke)
	local gradient = UILib.gradient(face, colors.top, colors.face)

	local label = UILib.text(face, opts.text or "", {
		Name = "Label",
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		TextSize = opts.textSize or 22,
		TextWrapped = false,
		TextScaled = false,
		ZIndex = (opts.zIndex or 1) + 1,
	})

	local button = { root = root, face = face, label = label, shadow = shadow }
	local enabled = true
	local colorKey = opts.color or "blue"

	local function paint(key)
		local c = UILib.palette(key)
		gradient.Color = ColorSequence.new(c.top, c.face)
		shadow.BackgroundColor3 = c.shade
	end

	function button.setText(text)
		label.Text = text
	end

	function button.setColor(key)
		colorKey = key
		if enabled then
			paint(key)
		end
	end

	function button.setEnabled(value)
		enabled = value and true or false
		paint(enabled and colorKey or "grey")
		label.TextTransparency = enabled and 0 or 0.25
	end

	function button.isEnabled()
		return enabled
	end

	-- Нажатие: «лицо» опускается на тень
	local function press()
		if enabled then
			UILib.tween(face, 0.06, { Position = UDim2.new(0, 0, 0, depth - 1) })
		end
	end
	local function release()
		UILib.tween(face, 0.12, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
	end
	face.MouseButton1Down:Connect(press)
	face.MouseButton1Up:Connect(release)
	face.MouseEnter:Connect(function()
		if enabled then
			UILib.tween(hoverScale, 0.12, { Scale = 1.05 })
		end
	end)
	face.MouseLeave:Connect(function()
		release()
		UILib.tween(hoverScale, 0.12, { Scale = 1 })
	end)

	face.Activated:Connect(function()
		if not enabled then
			UILib.shake(root)
			return
		end
		if opts.onClick then
			opts.onClick()
		end
	end)

	return button
end

-- ===================================================================================
-- Окна
-- ===================================================================================
local screens = {} -- screens[name] = окно; открыто одновременно не больше одного

-- opts: name, title, accent (ключ палитры), size (Vector2, пиксели при масштабе 1),
--       displayOrder, player, onOpen(), onClose()
-- Возвращает окно: gui, holder, panel, header, title, body, closeButton,
--                  open(), close(), toggle(), isOpen()
function UILib.window(opts)
	local size = opts.size or Vector2.new(460, 380)
	local accent = UILib.palette(opts.accent or "blue")
	local gui = UILib.screenGui(opts.guiName or opts.name, opts.displayOrder or 10, opts.player)

	-- Затемнение: клик мимо окна закрывает его
	local dim = make("TextButton", {
		Name = "Dim",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = THEME.dim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, gui)

	-- holder отвечает за размер экрана, panel — за анимацию появления
	local holder = make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, size.X, 0, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	UILib.fitScale(holder)

	local panel = make("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = THEME.cream,
		BorderSizePixel = 0,
		Active = true, -- клик по окну не должен «проваливаться» в затемнение и закрывать его
	}, holder)
	UILib.corner(panel, THEME.radius + 4)
	UILib.stroke(panel, THEME.stroke + 1)
	local popScale = make("UIScale", { Name = "PopScale", Scale = 1 }, panel)

	-- Шапка выступает над окном, как ленточка
	local header = make("Frame", {
		Name = "Header",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.72, 0, 0, 54),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, panel)
	UILib.corner(header, THEME.radius)
	UILib.stroke(header, THEME.stroke + 1)
	UILib.gradient(header, accent.top, accent.face)

	local title = UILib.text(header, opts.title or "", {
		Name = "Title",
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextSize = 28,
		TextWrapped = false,
		ZIndex = 4,
		strokeThickness = 3,
	})

	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 18, 0, 44),
		Size = UDim2.new(1, -36, 1, -62),
		BackgroundTransparency = 1,
	}, panel)

	local win = { gui = gui, holder = holder, panel = panel, header = header, title = title, body = body, dim = dim }
	local opened = false
	local generation = 0

	local closeButton = UILib.toonButton(panel, {
		name = "CloseButton",
		text = "✕",
		color = "red",
		size = UDim2.new(0, 50, 0, 50),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.new(1, -6, 0, 6),
		textSize = 26,
		zIndex = 5,
		onClick = function()
			win.close()
		end,
	})
	win.closeButton = closeButton

	function win.isOpen()
		return opened
	end

	function win.open()
		if opened then
			return
		end
		-- одно окно за раз
		for _, other in screens do
			if other ~= win and other.isOpen() then
				other.close()
			end
		end
		opened = true
		generation += 1
		holder.Visible = true
		dim.Visible = true
		popScale.Scale = 0.6
		UILib.tween(popScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		UILib.tween(dim, 0.2, { BackgroundTransparency = 0.55 })
		if opts.onOpen then
			opts.onOpen()
		end
	end

	function win.close()
		if not opened then
			return
		end
		opened = false
		generation += 1
		local myGeneration = generation
		UILib.tween(popScale, 0.14, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UILib.tween(dim, 0.14, { BackgroundTransparency = 1 })
		task.delay(0.15, function()
			if myGeneration == generation then
				holder.Visible = false
				dim.Visible = false
			end
		end)
		if opts.onClose then
			opts.onClose()
		end
	end

	function win.toggle()
		if opened then
			win.close()
		else
			win.open()
		end
	end

	dim.Activated:Connect(win.close)

	if opts.name then
		screens[opts.name] = win
	end
	return win
end

function UILib.get(name)
	local win = screens[name]
	if win and win.gui.Parent then
		return win
	end
	return nil
end

function UILib.open(name)
	local win = UILib.get(name)
	if win then
		win.open()
	end
	return win ~= nil
end

function UILib.close(name)
	local win = UILib.get(name)
	if win then
		win.close()
	end
end

function UILib.toggle(name)
	local win = UILib.get(name)
	if win then
		win.toggle()
	end
	return win ~= nil
end

-- ===================================================================================
-- Уведомления сверху экрана
-- ===================================================================================
local MAX_TOASTS = 4
local toastHolder = nil

local function getToastHolder()
	if toastHolder and toastHolder.Parent and toastHolder.Parent.Parent then
		return toastHolder
	end
	local gui = UILib.screenGui("Toasts", 50)
	toastHolder = make("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0, 420, 0, 300),
		BackgroundTransparency = 1,
	}, gui)
	UILib.fitScale(toastHolder)
	local layout = UILib.list(toastHolder, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return toastHolder
end

-- color: ключ палитры (red — ошибка, green — успех, ...)
function UILib.toast(text, color, duration)
	local holder = getToastHolder()
	local existing = {}
	for _, child in holder:GetChildren() do
		if child.Name == "Toast" then
			table.insert(existing, child)
		end
	end
	if #existing >= MAX_TOASTS then
		existing[1]:Destroy()
	end

	local colors = UILib.palette(color or "blue")
	local toast = make("Frame", {
		Name = "Toast",
		Size = UDim2.new(0, 380, 0, 46),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, holder)
	UILib.corner(toast, 23)
	local toastStroke = UILib.stroke(toast, THEME.stroke)
	UILib.gradient(toast, colors.top, colors.face)
	local scale = make("UIScale", { Scale = 0.5 }, toast)
	local label = UILib.text(toast, text, {
		Name = "Label",
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextSize = 20,
	})

	UILib.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 2, function()
		if not toast.Parent then
			return
		end
		UILib.tween(toast, 0.3, { BackgroundTransparency = 1 })
		UILib.tween(label, 0.3, { TextTransparency = 1 })
		UILib.tween(toastStroke, 0.3, { Transparency = 1 })
		task.delay(0.31, function()
			toast:Destroy()
		end)
	end)
	return toast
end

return UILib
