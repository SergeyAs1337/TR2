-- StarterPlayer/StarterPlayerScripts/UpgradeShop  (LocalScript)  v1 — окно апгрейдов кодом
-- Заменяет StarterGui/UpgradeGUI (его нужно удалить вместе с его LocalScript).
-- Четыре карточки: иконка, уровень, полоска из 10 делений, «было → станет», цена.
-- Открывается кнопкой «⬆ Апгрейды» в HUD (CoinsHud) или из любого LocalScript:
--   require(ReplicatedStorage.UILib).open("Upgrades")
--
-- Сервер не меняется: покупка идёт в UpgradeRequest, уровни приходят в атрибуте игрока
-- "Upgrades" (JSON), отказ приходит через UpgradeRequest.OnClientEvent.
-- ВАЖНО: цены и формулы ниже — копия из UpgradeHandler.lua (LEVEL_PRICES, applyHealth,
-- applySpeed, regenDelay, regenPercent). Меняешь там — поменяй и здесь, иначе карточки
-- покажут неверные цены (списывает всё равно сервер, по своим ценам).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local player = Players.LocalPlayer
local upgradeEvent = ReplicatedStorage:WaitForChild("UpgradeRequest")

-- ===== Данные (копия с сервера) =====
local LEVEL_PRICES = { 100, 200, 400, 800, 1600, 3200, 5000, 7500, 10000 }

local function trim(number)
	local text = string.format("%.1f", number)
	return (string.gsub(text, "%.0$", ""))
end

local UPGRADES = {
	{
		name = "Health",
		title = "Здоровье",
		icon = "❤️",
		color = "red",
		max = 10,
		effect = function(level)
			return UILib.formatNumber(100 * level) .. " ХП"
		end,
	},
	{
		name = "Speed",
		title = "Скорость",
		icon = "👟",
		color = "blue",
		max = 10,
		effect = function(level)
			return trim(16 + (level - 1) * 16 / 9)
		end,
	},
	{
		name = "Regen",
		title = "Регенерация",
		icon = "💚",
		color = "green",
		max = 10,
		effect = function(level)
			local percent = 5 + (level - 1) * 5 / 9
			local delay = 5 - (level - 1) * 2 / 9
			return trim(percent) .. "% / " .. trim(delay) .. "с"
		end,
	},
	{
		name = "CoinMultiplier",
		title = "Монеты за смерть",
		icon = "🪙",
		color = "yellow",
		max = 10,
		effect = function(level)
			return "x" .. level
		end,
	},
}

-- ===== Окно =====
local win = UILib.window({
	name = "Upgrades",
	guiName = "UpgradeGUI",
	title = "⬆ АПГРЕЙДЫ",
	accent = "orange",
	size = Vector2.new(600, 470),
	player = player,
})

local balanceLabel = UILib.text(win.body, "Баланс: 🪙 …", {
	Name = "Balance",
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(1, 0, 0, 26),
	TextColor3 = THEME.ink,
	TextSize = 20,
	strokeThickness = 0,
})

local grid = UILib.make("Frame", {
	Name = "Cards",
	Position = UDim2.new(0, 0, 0, 32),
	Size = UDim2.new(1, 0, 1, -32),
	BackgroundTransparency = 1,
}, win.body)
UILib.make("UIGridLayout", {
	CellSize = UDim2.new(0.5, -6, 0.5, -6),
	CellPadding = UDim2.new(0, 12, 0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

local cards = {} -- cards[name] = { ... }
-- Уведомление «уровень N!» только после своей покупки, а не при загрузке данных после входа
local pendingPurchase = {}

local function makeCard(data, order)
	local colors = UILib.palette(data.color)
	local card = UILib.make("Frame", {
		Name = data.name,
		BackgroundColor3 = THEME.creamDark,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, grid)
	UILib.corner(card, THEME.radius)
	UILib.stroke(card, THEME.stroke)

	-- Иконка в кружке
	local badge = UILib.make("Frame", {
		Name = "Icon",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(0, 48, 0, 48),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, card)
	UILib.corner(badge, 24)
	UILib.stroke(badge, THEME.stroke)
	UILib.gradient(badge, colors.top, colors.face)
	UILib.text(badge, data.icon, { Size = UDim2.new(1, 0, 1, 0), TextSize = 26, strokeThickness = 0 })

	UILib.text(card, data.title, {
		Name = "Title",
		Position = UDim2.new(0, 66, 0, 8),
		Size = UDim2.new(1, -74, 0, 26),
		TextColor3 = THEME.ink,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		strokeThickness = 0,
	})
	local levelText = UILib.text(card, "", {
		Name = "LevelText",
		Position = UDim2.new(0, 66, 0, 34),
		Size = UDim2.new(1, -74, 0, 20),
		TextColor3 = THEME.muted,
		TextSize = 16,
		Font = THEME.fontBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		strokeThickness = 0,
	})

	-- Полоска из делений
	local bar = UILib.make("Frame", {
		Name = "Bar",
		Position = UDim2.new(0, 10, 0, 66),
		Size = UDim2.new(1, -20, 0, 14),
		BackgroundTransparency = 1,
	}, card)
	local segments = {}
	for i = 1, data.max do
		local segment = UILib.make("Frame", {
			Name = "Segment" .. i,
			Position = UDim2.new((i - 1) / data.max, 1, 0, 0),
			Size = UDim2.new(1 / data.max, -3, 1, 0),
			BackgroundColor3 = THEME.empty,
			BorderSizePixel = 0,
		}, bar)
		UILib.corner(segment, 4)
		UILib.stroke(segment, 2)
		segments[i] = segment
	end

	local effectText = UILib.text(card, "", {
		Name = "Effect",
		Position = UDim2.new(0, 10, 0, 86),
		Size = UDim2.new(1, -20, 0, 22),
		TextColor3 = THEME.ink,
		TextSize = 17,
		Font = THEME.fontBody,
		strokeThickness = 0,
	})

	local buy = UILib.toonButton(card, {
		name = "BuyButton",
		text = "",
		color = "green",
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		size = UDim2.new(1, -20, 0, 46),
		textSize = 20,
		onClick = function()
			pendingPurchase[data.name] = true
			upgradeEvent:FireServer(data.name)
		end,
	})

	cards[data.name] = {
		data = data,
		frame = card,
		levelText = levelText,
		effectText = effectText,
		segments = segments,
		buy = buy,
		level = nil,
	}
end

for order, data in UPGRADES do
	makeCard(data, order)
end

-- ===== Обновление =====
local function readUpgrades()
	local raw = player:GetAttribute("Upgrades")
	if typeof(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(decoded) == "table" then
			return decoded
		end
	end
	return {}
end

local function getCoins()
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return coins and coins.Value or nil
end

local function refresh()
	local levels = readUpgrades()
	local coins = getCoins()
	balanceLabel.Text = "Баланс: 🪙 " .. (coins and UILib.formatNumber(coins) or "…")

	for _, card in cards do
		local data = card.data
		local level = tonumber(levels[data.name]) or 1
		level = math.clamp(math.floor(level), 1, data.max)
		local leveledUp = card.level ~= nil and level > card.level and pendingPurchase[data.name]
		if card.level ~= nil and level ~= card.level then
			pendingPurchase[data.name] = nil
		end
		card.level = level

		card.levelText.Text = string.format("Уровень %d / %d", level, data.max)
		local fill = UILib.palette(data.color).face
		for i, segment in card.segments do
			segment.BackgroundColor3 = i <= level and fill or THEME.empty
		end

		if level >= data.max then
			card.effectText.Text = data.effect(level) .. "  (максимум)"
			card.buy.setText("⭐ МАКС")
			card.buy.setEnabled(true)
			card.buy.setColor("yellow")
		else
			local price = LEVEL_PRICES[level] or 0
			card.effectText.Text = data.effect(level) .. "  →  " .. data.effect(level + 1)
			card.buy.setText("🪙 " .. UILib.formatNumber(price))
			card.buy.setColor("green")
			-- Не хватает монет: кнопка серая, но нажимается (покажет «Недостаточно монет!» от сервера)
			card.buy.setEnabled(true)
			if coins and coins < price then
				card.buy.setColor("grey")
			end
		end

		if leveledUp then
			UILib.shake(card.frame)
			UILib.toast(data.icon .. " " .. data.title .. ": уровень " .. level .. "!", "green", 1.5)
		end
	end
end

-- Отказ от сервера: «Недостаточно монет!», «Макс уровень!»
upgradeEvent.OnClientEvent:Connect(function(upgradeName, success, message)
	if success then
		return
	end
	pendingPurchase[upgradeName] = nil
	local card = cards[upgradeName]
	if card then
		UILib.shake(card.frame)
	end
	if typeof(message) == "string" then
		UILib.toast(message, "red")
	end
end)

player:GetAttributeChangedSignal("Upgrades"):Connect(refresh)
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 120)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 30)
	if coins then
		coins:GetPropertyChangedSignal("Value"):Connect(refresh)
		refresh()
	end
end)
refresh()
