-- StarterPlayer/StarterPlayerScripts/CoinsHud  (LocalScript)  v3 — стиль админ-панели
-- HUD слева посередине экрана: плашки монет и смертей, под ними кнопки меню.
-- Заменяет StarterGui/CoinsDeaths. Строится кодом и подстраивается под размер экрана.
--   * число монет «докручивается» до нового значения и подпрыгивает при изменении;
--   * до миллиона число полностью («12 345»), дальше коротко («1.25M»);
--   * кнопки «Апгрейды» и «Эмоции» открывают окна UpgradeShop и EmotionMenu через UILib;
--   * слушает сообщения сервера: Notify (уведомление) и OpenScreen (открыть окно по имени).
-- Добавить свою кнопку в меню: допиши строку в MENU_BUTTONS (окно должно быть создано
-- через UILib.window с таким же name).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local FORMAT_NUMBERS = true -- false: «1234567» без разделителей и сокращений
local COUNT_TIME = 0.4 -- секунд «докрутки» числа
local MENU_BUTTONS = {
	{ name = "Upgrades", text = "⬆  Апгрейды", color = "accent" },
	{ name = "Emotes", text = "💃  Эмоции", color = "neutral" },
}

local player = Players.LocalPlayer

local gui = UILib.screenGui("CoinsDeaths", 5, player)

local holder = UILib.make("Frame", {
	Name = "Frame",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.new(0, 210, 0, 300),
	BackgroundTransparency = 1,
}, gui)
UILib.fitScale(holder)
UILib.list(holder, 8)

local function format(value)
	if not FORMAT_NUMBERS then
		return tostring(value)
	end
	return UILib.formatShort(value)
end

-- Плашка «иконка + число»
local function makePill(name, icon, iconColor, order)
	local pill = UILib.panel(holder, {
		Name = name,
		Size = UDim2.new(0, 190, 0, 44),
		BackgroundTransparency = 0.08,
		LayoutOrder = order,
	})
	local scale = UILib.make("UIScale", { Scale = 1 }, pill)

	UILib.make("Frame", { -- цветная полоска слева
		Name = "Strip",
		Position = UDim2.new(0, 0, 0, 8),
		Size = UDim2.new(0, 3, 1, -16),
		BackgroundColor3 = iconColor,
		BorderSizePixel = 0,
	}, pill)
	UILib.text(pill, icon, {
		Name = "Icon",
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0, 28, 1, 0),
		TextSize = 20,
	})

	local value = UILib.text(pill, "…", { -- «…» пока данные загружаются
		Name = "Value",
		Position = UDim2.new(0, 44, 0, 0),
		Size = UDim2.new(1, -54, 1, 0),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	return { frame = pill, value = value, scale = scale }
end

local coinsPill = makePill("Coins", "🪙", THEME.coin, 1)
local deathsPill = makePill("Deaths", "💀", THEME.muted, 2)

for index, entry in MENU_BUTTONS do
	UILib.actionButton(holder, {
		name = entry.name .. "Button",
		text = entry.text,
		color = entry.color,
		size = UDim2.new(0, 190, 0, 42),
		layoutOrder = 10 + index,
		onClick = function()
			if not UILib.toggle(entry.name) then
				warn("[CoinsHud] Окно «" .. entry.name .. "» ещё не создано")
			end
		end,
	})
end

-- Число плавно докручивается от старого значения к новому
local function counter(pill)
	local shown = nil
	local generation = 0
	return function(target)
		generation += 1
		local myGeneration = generation
		if shown == nil or not FORMAT_NUMBERS then
			shown = target
			pill.value.Text = format(target)
			return
		end
		local from = shown
		if target > from then
			UILib.bump(pill.scale, 1.06)
		end
		task.spawn(function()
			local elapsed = 0
			while myGeneration == generation do
				local t = math.min(elapsed / COUNT_TIME, 1)
				shown = from + (target - from) * t
				pill.value.Text = format(t >= 1 and target or math.floor(shown))
				if t >= 1 then
					shown = target
					break
				end
				elapsed += task.wait(1 / 30) -- task.wait возвращает реально прошедшее время
			end
		end)
	end
end

local function watch(statName, pill)
	local leaderstats = player:WaitForChild("leaderstats", 120)
	local stat = leaderstats and leaderstats:WaitForChild(statName, 30)
	if not stat then
		warn("[CoinsHud] Не нашёл leaderstats." .. statName)
		return
	end
	local set = counter(pill)
	set(stat.Value)
	stat:GetPropertyChangedSignal("Value"):Connect(function()
		set(stat.Value)
	end)
end

-- Сообщения с сервера (модуль ServerScriptService/Notify): уведомление и «открыть окно»
task.spawn(function()
	local notify = ReplicatedStorage:WaitForChild("Notify", 60)
	if notify then
		notify.OnClientEvent:Connect(function(text, color)
			if typeof(text) == "string" and text ~= "" then
				UILib.toast(string.sub(text, 1, 200), typeof(color) == "string" and color or "accent")
			end
		end)
	end
end)
task.spawn(function()
	local openScreen = ReplicatedStorage:WaitForChild("OpenScreen", 60)
	if openScreen then
		openScreen.OnClientEvent:Connect(function(screenName)
			if typeof(screenName) == "string" then
				UILib.open(screenName)
			end
		end)
	end
end)

-- leaderstats создаётся после загрузки данных игрока, поэтому ждём подольше
task.spawn(watch, "Coins", coinsPill)
task.spawn(watch, "Deaths", deathsPill)
