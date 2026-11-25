-- StarterPlayer/StarterPlayerScripts/CoinsHud  (LocalScript)  v2 — редизайн
-- HUD слева посередине экрана: плашки монет и смертей, под ними кнопки меню.
-- Заменяет StarterGui/CoinsDeaths. Строится кодом и подстраивается под размер экрана.
--   * число монет «докручивается» до нового значения и подпрыгивает при изменении;
--   * до миллиона число полностью («12 345»), дальше коротко («1.25M»);
--   * кнопка «Апгрейды» открывает окно апгрейдов (UpgradeShop) через UILib.open.
-- Добавить свою кнопку в меню: допиши строку в MENU_BUTTONS (окно должно быть создано
-- через UILib.window с таким же name).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local FORMAT_NUMBERS = true -- false: «1234567» без разделителей и сокращений
local COUNT_TIME = 0.4 -- секунд «докрутки» числа
local MENU_BUTTONS = {
	{ name = "Upgrades", text = "⬆ Апгрейды", color = "orange" },
}

local player = Players.LocalPlayer

local gui = UILib.screenGui("CoinsDeaths", 5, player)

local holder = UILib.make("Frame", {
	Name = "Frame",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.new(0, 210, 0, 260),
	BackgroundTransparency = 1,
}, gui)
UILib.fitScale(holder)
UILib.list(holder, 10)

local function format(value)
	if not FORMAT_NUMBERS then
		return tostring(value)
	end
	return UILib.formatShort(value)
end

-- Плашка «иконка + число»
local function makePill(name, icon, iconColor, order)
	local pill = UILib.make("Frame", {
		Name = name,
		Size = UDim2.new(0, 200, 0, 50),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, holder)
	UILib.corner(pill, 25)
	UILib.stroke(pill, THEME.stroke)
	UILib.gradient(pill, THEME.white, THEME.creamDark)
	local scale = UILib.make("UIScale", { Scale = 1 }, pill)

	local colors = UILib.palette(iconColor)
	local badge = UILib.make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		Size = UDim2.new(0, 58, 0, 58),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, pill)
	UILib.corner(badge, 29)
	UILib.stroke(badge, THEME.stroke)
	UILib.gradient(badge, colors.top, colors.face)
	UILib.text(badge, icon, { Size = UDim2.new(1, 0, 1, 0), TextSize = 30, ZIndex = 3, strokeThickness = 0 })

	local value = UILib.text(pill, "…", { -- «…» пока данные загружаются
		Name = "Value",
		Position = UDim2.new(0, 58, 0, 0),
		Size = UDim2.new(1, -70, 1, 0),
		TextColor3 = THEME.ink,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		strokeThickness = 0,
	})
	return { frame = pill, value = value, scale = scale }
end

local coinsPill = makePill("Coins", "🪙", "yellow", 1)
local deathsPill = makePill("Deaths", "💀", "grey", 2)

for index, entry in MENU_BUTTONS do
	UILib.toonButton(holder, {
		name = entry.name .. "Button",
		text = entry.text,
		color = entry.color,
		size = UDim2.new(0, 200, 0, 56),
		textSize = 22,
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
			UILib.bump(pill.scale, 1.12)
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

-- leaderstats создаётся после загрузки данных игрока, поэтому ждём подольше
task.spawn(watch, "Coins", coinsPill)
task.spawn(watch, "Deaths", deathsPill)
