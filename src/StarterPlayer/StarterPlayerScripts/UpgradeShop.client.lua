-- StarterPlayer/StarterPlayerScripts/UpgradeShop  (LocalScript)  v2 — стиль админ-панели
-- Заменяет StarterGui/UpgradeGUI (его нужно удалить вместе с его LocalScript).
-- Четыре карточки: иконка, уровень, полоска уровня, «было → станет», кнопка с ценой.
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
		color = "bad",
		max = 10,
		effect = function(level)
			return UILib.formatNumber(100 * level) .. " ХП"
		end,
	},
	{
		name = "Speed",
		title = "Скорость",
		icon = "👟",
		color = "accent",
		max = 10,
		effect = function(level)
			return trim(16 + (level - 1) * 16 / 9)
		end,
	},
	{
		name = "Regen",
		title = "Регенерация",
		icon = "💚",
		color = "good",
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
		color = "warn",
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
	title = "⬆  Апгрейды",
	size = Vector2.new(560, 440),
	player = player,
})

local balanceLabel = UILib.text(win.body, "Баланс: 🪙 …", {
	Name = "Balance",
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(1, 0, 0, 22),
	TextColor3 = THEME.muted,
	TextSize = 15,
	Font = THEME.fontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local grid = UILib.make("Frame", {
	Name = "Cards",
	Position = UDim2.new(0, 0, 0, 30),
	Size = UDim2.new(1, 0, 1, -30),
	BackgroundTransparency = 1,
}, win.body)
UILib.make("UIGridLayout", {
	CellSize = UDim2.new(0.5, -5, 0.5, -5),
	CellPadding = UDim2.new(0, 10, 0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

local cards = {} -- cards[name] = { ... }
-- Уведомление «уровень N!» только после своей покупки, а не при загрузке данных после входа
local pendingPurchase = {}

local function makeCard(data, order)
	local card = UILib.panel(grid, {
		Name = data.name,
		LayoutOrder = order,
	})

	UILib.text(card, data.icon, {
		Name = "Icon",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(0, 28, 0, 26),
		TextSize = 20,
	})
	UILib.text(card, data.title, {
		Name = "Title",
		Position = UDim2.new(0, 42, 0, 10),
		Size = UDim2.new(1, -110, 0, 26),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	})
	local levelText = UILib.text(card, "", {
		Name = "LevelText",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.new(0, 64, 0, 26),
		TextColor3 = THEME.muted,
		TextSize = 14,
		Font = THEME.fontBody,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- Полоска уровня
	local bar = UILib.panel(card, {
		Name = "Bar",
		Position = UDim2.new(0, 12, 0, 46),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = THEME.row,
	})
	local fill = UILib.panel(bar, {
		Name = "Fill",
		Size = UDim2.new(0.1, 0, 1, 0),
		BackgroundColor3 = UILib.palette(data.color).face,
	})

	local effectText = UILib.text(card, "", {
		Name = "Effect",
		Position = UDim2.new(0, 12, 0, 60),
		Size = UDim2.new(1, -24, 0, 20),
		TextColor3 = THEME.muted,
		TextSize = 14,
		Font = THEME.fontBody,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local buy = UILib.actionButton(card, {
		name = "BuyButton",
		text = "",
		color = "good",
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -12),
		size = UDim2.new(1, -24, 0, 38),
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
		fill = fill,
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

		card.levelText.Text = string.format("%d / %d", level, data.max)
		UILib.tween(card.fill, 0.25, { Size = UDim2.new(level / data.max, 0, 1, 0) })

		if level >= data.max then
			card.effectText.Text = data.effect(level) .. " · максимум"
			card.buy.setText("Максимум")
			card.buy.setEnabled(false)
		else
			local price = LEVEL_PRICES[level] or 0
			card.effectText.Text = data.effect(level) .. "  →  " .. data.effect(level + 1)
			card.buy.setText("Купить · 🪙 " .. UILib.formatNumber(price))
			card.buy.setEnabled(true)
			-- Не хватает монет: кнопка серая, но нажимается (сервер ответит «Недостаточно монет!»)
			card.buy.setColor((coins and coins < price) and "neutral" or "good")
		end

		if leveledUp then
			UILib.shake(card.frame)
			UILib.toast(data.icon .. " " .. data.title .. ": уровень " .. level, "good", 1.5)
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
		UILib.toast(message, "bad")
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
