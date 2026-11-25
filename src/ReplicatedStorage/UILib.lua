-- ReplicatedStorage/UILib  (ModuleScript, только для клиента)  v3 — стиль админ-панели
-- Общие кирпичики для интерфейсов, которые строятся кодом. Подключение:
--   local UILib = require(game:GetService("ReplicatedStorage"):WaitForChild("UILib"))
--
-- Весь внешний вид задаётся здесь, в THEME и в функциях ниже. Окна (автомат, HUD, апгрейды,
-- баннер) пользуются только THEME и компонентами, поэтому новый стиль = правка этого файла.
--
-- Что внутри:
--   THEME             — цвета, шрифты, скругления, размеры текста.
--   actionButton(...) — кнопка: цвет из палитры, подсветка при наведении, затемнение при нажатии.
--   window(...)       — окно с заголовком, крестиком, затемнением и анимацией появления. Само
--                       подстраивается под экран (телефон / ПК). Открытые окна закрывают друг друга.
--   open/close/toggle — открыть окно по имени из любого LocalScript (например, кнопкой в HUD).
--   toast(...)        — короткое уведомление сверху экрана.
--   panel, text, stroke, tween, bump, shake, fitScale, formatNumber, formatShort, formatTime.
-- Старые функции v1 (make, corner, padding, list, label, button, input, scroll, confirmButton,
-- COLORS) оставлены без изменений, ими пользуется админ-панель.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UILib = {}

-- ===================================================================================
-- Тема (цвета как у админ-панели)
-- ===================================================================================
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local THEME = {
	font = Enum.Font.GothamBold, -- заголовки, числа, кнопки
	fontBody = Enum.Font.Gotham, -- обычный текст

	background = rgb(24, 26, 33), -- фон окон
	panel = rgb(33, 36, 46), -- карточки и блоки внутри окна, плашки HUD
	row = rgb(46, 50, 64), -- поля ввода, дорожки полосок, барабаны
	border = rgb(52, 57, 72), -- тонкая рамка окон
	text = rgb(235, 238, 245),
	muted = rgb(160, 166, 185),
	dim = rgb(0, 0, 0), -- затемнение под окном
	coin = rgb(214, 160, 52), -- цвет монет

	radius = 8,
	textSize = 16,
	titleSize = 20,
	buttonHeight = 40,

	-- Цвета кнопок и акцентов: face (обычный), hover (под курсором), press (нажата)
	palette = {
		accent = { face = rgb(70, 120, 235), hover = rgb(92, 140, 245), press = rgb(54, 98, 200) },
		good = { face = rgb(52, 150, 96), hover = rgb(64, 172, 112), press = rgb(42, 124, 80) },
		bad = { face = rgb(180, 66, 66), hover = rgb(200, 82, 82), press = rgb(150, 52, 52) },
		warn = { face = rgb(196, 132, 40), hover = rgb(214, 150, 56), press = rgb(166, 110, 30) },
		neutral = { face = rgb(46, 50, 64), hover = rgb(58, 63, 80), press = rgb(38, 41, 53) },
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
-- Оформление
-- ===================================================================================


function UILib.palette(key)
	return THEME.palette[key] or THEME.palette.accent
end

-- Тонкая рамка. mode = "border" (по краю рамки) или "text" (контур букв)
function UILib.stroke(instance, thickness, color, mode)
	return make("UIStroke", {
		Thickness = thickness or 1,
		Color = color or THEME.border,
		ApplyStrokeMode = mode == "text" and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
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

-- Блок-подложка: скруглённый прямоугольник цвета color (по умолчанию THEME.panel)
function UILib.panel(parent, props)
	props = props or {}
	local defaults = {
		BackgroundColor3 = THEME.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 40),
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = make("Frame", defaults, parent)
	UILib.corner(frame, THEME.radius)
	return frame
end

-- Надпись. props перекрывают значения по умолчанию (Size, Position, TextColor3, TextSize, ...).
-- props.strokeThickness > 0 добавляет тёмный контур (для текста поверх 3D-мира).
function UILib.text(parent, text, props)
	props = props or {}
	local thickness = props.strokeThickness
	local defaults = {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = THEME.text,
		TextSize = THEME.textSize,
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
	if thickness and thickness > 0 then
		local stroke = UILib.stroke(label, thickness, Color3.fromRGB(0, 0, 0), "text")
		stroke.Transparency = 0.35
	end
	return label
end

-- Короткое «подпрыгивание» через UIScale (например, при изменении числа)
function UILib.bump(uiScale, amount)
	if not uiScale then
		return
	end
	uiScale.Scale = amount or 1.06
	UILib.tween(uiScale, 0.2, { Scale = 1 })
end

-- Покачивание: «нельзя», «ошибка»
function UILib.shake(guiObject)
	if not guiObject then
		return
	end
	task.spawn(function()
		for _, angle in { -3, 3, -2, 2, 0 } do
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
-- Кнопка
-- ===================================================================================
-- opts: text, color (ключ палитры: accent, good, bad, warn, neutral), size (UDim2), position,
--       anchor, textSize, onClick, name, layoutOrder, zIndex
-- Возвращает объект: root (рамка), face (TextButton, на неё вешается Activated), label,
--   setText(text), setColor(key), getColor(), setEnabled(bool), isEnabled()
-- Выключенная кнопка серая, не вызывает onClick и покачивается при нажатии.
function UILib.actionButton(parent, opts)
	opts = opts or {}

	local root = make("Frame", {
		Name = opts.name or "Button",
		Size = opts.size or UDim2.new(0, 160, 0, THEME.buttonHeight),
		Position = opts.position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = opts.anchor or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = opts.layoutOrder or 0,
		ZIndex = opts.zIndex or 1,
	}, parent)

	local face = make("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = THEME.palette.accent.face,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = opts.zIndex or 1,
	}, root)
	UILib.corner(face, THEME.radius)

	local label = UILib.text(face, opts.text or "", {
		Name = "Label",
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		TextSize = opts.textSize or THEME.textSize,
		TextWrapped = false,
		ZIndex = (opts.zIndex or 1) + 1,
	})

	local button = { root = root, face = face, label = label }
	local enabled = true
	local colorKey = opts.color or "accent"
	local hovered = false

	local function painted()
		return enabled and colorKey or "neutral"
	end
	local function paint(state)
		local colors = UILib.palette(painted())
		face.BackgroundColor3 = colors[state or (hovered and "hover" or "face")]
	end

	function button.setText(text)
		label.Text = text
	end

	function button.setColor(key)
		colorKey = key
		paint()
	end

	function button.getColor()
		return painted()
	end

	function button.setEnabled(value)
		enabled = value and true or false
		label.TextColor3 = enabled and THEME.text or THEME.muted
		paint()
	end

	function button.isEnabled()
		return enabled
	end

	face.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	face.MouseLeave:Connect(function()
		hovered = false
		paint()
	end)
	face.MouseButton1Down:Connect(function()
		paint("press")
	end)
	face.MouseButton1Up:Connect(function()
		paint()
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

	paint()
	return button
end
UILib.toonButton = UILib.actionButton -- старое имя из v2

-- ===================================================================================
-- Окна
-- ===================================================================================
local screens = {} -- screens[name] = окно; открыто одновременно не больше одного

-- opts: name, guiName, title, size (Vector2, пиксели при масштабе 1), displayOrder, player,
--       onOpen(), onClose()
-- Возвращает окно: gui, holder, panel, header, title, body, closeButton,
--                  open(), close(), toggle(), isOpen()
function UILib.window(opts)
	local size = opts.size or Vector2.new(440, 380)
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
		BackgroundColor3 = THEME.background,
		BorderSizePixel = 0,
		Active = true, -- клик по окну не должен «проваливаться» в затемнение и закрывать его
	}, holder)
	UILib.corner(panel, THEME.radius + 2)
	UILib.stroke(panel, 1, THEME.border)
	local popScale = make("UIScale", { Name = "PopScale", Scale = 1 }, panel)

	local header = make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
	}, panel)
	local title = UILib.text(header, opts.title or "", {
		Name = "Title",
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -70, 1, 0),
		TextSize = THEME.titleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
	make("Frame", { -- разделитель под заголовком
		Name = "Divider",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = THEME.border,
		BorderSizePixel = 0,
	}, header)

	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 16, 0, 64),
		Size = UDim2.new(1, -32, 1, -80),
		BackgroundTransparency = 1,
	}, panel)

	local win = { gui = gui, holder = holder, panel = panel, header = header, title = title, body = body, dim = dim }
	local opened = false
	local generation = 0

	local closeButton = UILib.actionButton(header, {
		name = "CloseButton",
		text = "✕",
		color = "neutral",
		size = UDim2.new(0, 34, 0, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0),
		onClick = function()
			win.close()
		end,
	})
	-- крестик краснеет под курсором
	closeButton.face.MouseEnter:Connect(function()
		closeButton.face.BackgroundColor3 = THEME.palette.bad.face
	end)
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
		popScale.Scale = 0.94
		UILib.tween(popScale, 0.18, { Scale = 1 })
		UILib.tween(dim, 0.18, { BackgroundTransparency = 0.5 })
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
		UILib.tween(popScale, 0.12, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UILib.tween(dim, 0.12, { BackgroundTransparency = 1 })
		task.delay(0.13, function()
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
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.new(0, 380, 0, 260),
		BackgroundTransparency = 1,
	}, gui)
	UILib.fitScale(toastHolder)
	local layout = UILib.list(toastHolder, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return toastHolder
end

-- color: ключ палитры полоски слева (bad — ошибка, good — успех, ...)
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

	local toast = UILib.panel(holder, {
		Name = "Toast",
		Size = UDim2.new(0, 360, 0, 42),
		BackgroundColor3 = THEME.background,
	})
	local toastStroke = UILib.stroke(toast, 1, THEME.border)
	local strip = make("Frame", {
		Name = "Strip",
		Size = UDim2.new(0, 4, 1, -12),
		Position = UDim2.new(0, 8, 0, 6),
		BackgroundColor3 = UILib.palette(color or "accent").face,
		BorderSizePixel = 0,
	}, toast)
	UILib.corner(strip, 2)
	local label = UILib.text(toast, text, {
		Name = "Label",
		Size = UDim2.new(1, -32, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = THEME.fontBody,
	})

	toast.BackgroundTransparency = 1
	UILib.tween(toast, 0.15, { BackgroundTransparency = 0 })
	task.delay(duration or 2, function()
		if not toast.Parent then
			return
		end
		UILib.tween(toast, 0.25, { BackgroundTransparency = 1 })
		UILib.tween(label, 0.25, { TextTransparency = 1 })
		UILib.tween(strip, 0.25, { BackgroundTransparency = 1 })
		UILib.tween(toastStroke, 0.25, { Transparency = 1 })
		task.delay(0.26, function()
			toast:Destroy()
		end)
	end)
	return toast
end

return UILib
