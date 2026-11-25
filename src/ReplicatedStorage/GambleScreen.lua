-- ReplicatedStorage/GambleScreen  (ModuleScript, только для клиента)  v3 — стиль админ-панели
-- Окно однорукого бандита: три барабана, быстрые ставки, баланс,
-- результат с сервера и счётчик «Проиграно всеми».
--
-- Как работает ставка: клиент проверяет ввод и шлёт ставку в GambleEvent, барабаны начинают
-- крутиться. Сервер (gamble.lua v2) отвечает тем же событием: { ok, bet, multiplier, win } или
-- { ok = false, reason }. Барабаны останавливаются на результате. Выигрыш решает ТОЛЬКО сервер,
-- клиент лишь рисует то, что пришло.
--
--   local screen = require(ReplicatedStorage:WaitForChild("GambleScreen")).get(Players.LocalPlayer)
--   screen.show() / screen.hide() / screen.isOpen()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

-- ===== Настройки =====
local SEVEN_IMAGE = "rbxassetid://85504738002100" -- семёрка из прежнего окна
local SYMBOLS = { "🍒", "🍋", "🔔", "💎", "⭐", "🍀" } -- остальные символы барабанов
local MAX_BET = 1_000_000_000 -- как на сервере (gamble.lua)
local DEFAULT_BET = 100
local SPIN_MIN_TIME = 0.9 -- первый барабан крутится не меньше стольких секунд
local REEL_STOP_GAP = 0.35 -- пауза между остановками барабанов
local SPIN_FRAME = 0.06 -- как часто меняется символ на крутящемся барабане
local REPLY_TIMEOUT = 5 -- если сервер не ответил, барабаны останавливаются


local GambleScreen = {}
local controller = nil -- окно одно на игрока

local function getCoins(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins")
end

-- Символы для результата: x10 — три семёрки, x2 — три одинаковых, проигрыш — разные
local function pickSymbols(multiplier)
	if multiplier >= 10 then
		return { "7", "7", "7" }
	end
	if multiplier > 0 then
		local s = SYMBOLS[math.random(#SYMBOLS)]
		return { s, s, s }
	end
	local all = { "7" }
	for _, s in SYMBOLS do
		table.insert(all, s)
	end
	local a, b = all[math.random(#all)], all[math.random(#all)]
	local c = all[math.random(#all)]
	while a == b and b == c do -- три одинаковых при проигрыше нельзя
		c = all[math.random(#all)]
	end
	return { a, b, c }
end

local function randomSymbol()
	if math.random(7) == 1 then
		return "7"
	end
	return SYMBOLS[math.random(#SYMBOLS)]
end

local function build(player)
	local remote = ReplicatedStorage:WaitForChild("GambleEvent", 10)
	local stats = ReplicatedStorage:WaitForChild("GlobalStats", 10)
	local totalLost = stats and stats:WaitForChild("TotalLost", 10)

	local screen
	local win = UILib.window({
		name = "Gamble",
		guiName = "GambleUI",
		title = "🎰 Однорукий бандит",
		size = Vector2.new(440, 420),
		player = player,
		onOpen = function()
			screen.refresh()
		end,
	})
	local body = win.body

	-- ===== Барабаны =====
	local reelPanel = UILib.panel(body, {
		Name = "Reels",
		Size = UDim2.new(1, 0, 0, 110),
	})

	local reels = {}
	for i = 1, 3 do
		local slot = UILib.panel(reelPanel, {
			Name = "Reel" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + (i - 2) * 0.32, 0, 0.5, 0),
			Size = UDim2.new(0.29, 0, 1, -24),
			BackgroundColor3 = THEME.row,
			ClipsDescendants = true,
		})
		local slotScale = UILib.make("UIScale", { Scale = 1 }, slot)

		local image = UILib.make("ImageLabel", {
			Name = "Seven",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.75, 0, 0.75, 0),
			BackgroundTransparency = 1,
			Image = SEVEN_IMAGE,
			ScaleType = Enum.ScaleType.Fit,
		}, slot)
		local emoji = UILib.text(slot, "", {
			Name = "Symbol",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 44,
		})

		local reel = { slot = slot, image = image, emoji = emoji, scale = slotScale, symbol = "7" }
		function reel.set(symbol)
			reel.symbol = symbol
			image.Visible = symbol == "7"
			emoji.Text = symbol == "7" and "" or symbol
		end
		reel.set("7")
		reels[i] = reel
	end

	-- ===== Результат =====
	local resultLabel = UILib.text(body, "Сделай ставку", {
		Name = "Result",
		Position = UDim2.new(0, 0, 0, 116),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 20,
	})
	local resultScale = UILib.make("UIScale", { Scale = 1 }, resultLabel)

	-- ===== Ставка =====
	local betRow = UILib.make("Frame", {
		Name = "BetRow",
		Position = UDim2.new(0, 0, 0, 152),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, body)

	local betFrame = UILib.panel(betRow, {
		Name = "BetFrame",
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundColor3 = THEME.row,
	})
	local betStroke = UILib.stroke(betFrame, 1, THEME.row)
	UILib.text(betFrame, "🪙", { Name = "Icon", Size = UDim2.new(0, 32, 1, 0), TextSize = 18 })

	local betBox = UILib.make("TextBox", {
		Name = "BetBox",
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = tostring(DEFAULT_BET),
		PlaceholderText = "Ставка",
		PlaceholderColor3 = THEME.muted,
		ClearTextOnFocus = false,
		TextColor3 = THEME.text,
		TextSize = 18,
		Font = THEME.font,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, betFrame)

	-- Быстрые ставки
	local function currentBet()
		local text = string.gsub(betBox.Text, "%s", "")
		return tonumber(text)
	end
	local function setBet(value)
		value = math.clamp(math.floor(value), 1, MAX_BET)
		betBox.Text = tostring(value)
	end
	local function coinsValue()
		local coins = getCoins(player)
		return coins and coins.Value or nil
	end

	local chips = {
		{ "½", function(v) return math.max(1, (v or DEFAULT_BET) // 2) end },
		{ "x2", function(v) return (v or DEFAULT_BET) * 2 end },
		{ "+1К", function(v) return (v or 0) + 1000 end },
		{ "Всё", function() return math.max(1, coinsValue() or DEFAULT_BET) end },
	}
	for index, chip in chips do
		UILib.actionButton(betRow, {
			name = "Chip" .. index,
			text = chip[1],
			color = index == 4 and "bad" or "neutral",
			size = UDim2.new(0.135, 0, 1, 0),
			position = UDim2.new(0.43 + (index - 1) * 0.1425, 0, 0, 0),
			textSize = 15,
			onClick = function()
				local value = currentBet()
				if value and value ~= value then
					value = nil
				end
				setBet(chip[2](value))
			end,
		})
	end

	local balanceLabel = UILib.text(body, "", {
		Name = "Balance",
		Position = UDim2.new(0, 0, 0, 198),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = THEME.muted,
		TextSize = 14,
		Font = THEME.fontBody,
	})

	-- ===== Кнопка «Крутить» =====
	local spinButton = UILib.actionButton(body, {
		name = "SpinButton",
		text = "Крутить",
		color = "accent",
		position = UDim2.new(0, 0, 0, 226),
		size = UDim2.new(1, 0, 0, 48),
		textSize = 20,
	})

	local lostLabel = UILib.text(body, "", {
		Name = "TotalLostLabel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = THEME.muted,
		TextSize = 13,
		Font = THEME.fontBody,
	})

	screen = { gui = win.gui, frame = win.holder, window = win, reels = reels }
	screen.spinButton = spinButton
	screen.betBox = betBox
	screen.resultLabel = resultLabel

	local function setResult(text, color, big)
		resultLabel.Text = text
		resultLabel.TextColor3 = color or THEME.text
		UILib.bump(resultScale, big and 1.2 or 1.06)
	end

	function screen.refresh()
		lostLabel.Text = "Проиграно всеми: 🪙 " .. UILib.formatNumber(totalLost and totalLost.Value or 0)
		local coins = coinsValue()
		balanceLabel.Text = coins and ("Баланс: 🪙 " .. UILib.formatNumber(coins)) or "Баланс: …"
	end
	if totalLost then
		totalLost:GetPropertyChangedSignal("Value"):Connect(screen.refresh)
	end
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 120)
		local coins = leaderstats and leaderstats:WaitForChild("Coins", 30)
		if coins then
			coins:GetPropertyChangedSignal("Value"):Connect(screen.refresh)
			screen.refresh()
		end
	end)
	screen.refresh()

	function screen.show()
		win.open()
	end

	function screen.hide()
		win.close()
	end

	function screen.isOpen()
		return win.isOpen()
	end

	-- ===== Прокрутка =====
	local spinning = false
	local spinId = 0
	screen.isSpinning = function()
		return spinning
	end

	local function flashInvalid(message)
		betStroke.Color = UILib.palette("bad").face
		UILib.shake(betFrame)
		setResult(message, UILib.palette("bad").hover)
		task.delay(0.6, function()
			betStroke.Color = THEME.row
		end)
	end

	local function finishSpin(result)
		local myId = spinId
		local symbols
		if result.ok then
			symbols = pickSymbols(result.multiplier or 0)
		else
			symbols = pickSymbols(0)
		end

		for i, reel in reels do
			task.delay((i - 1) * REEL_STOP_GAP, function()
				if myId ~= spinId then
					return
				end
				reel.stopped = true
				reel.set(symbols[i])
				UILib.bump(reel.scale, 1.08)
			end)
		end

		task.delay((#reels - 1) * REEL_STOP_GAP + 0.1, function()
			if myId ~= spinId then
				return
			end
			spinning = false
			spinButton.setEnabled(true)
			spinButton.setText("Крутить")
			if not result.ok then
				setResult(result.reason or "Ставка не прошла", UILib.palette("bad").hover)
			elseif (result.multiplier or 0) >= 10 then
				setResult("Джекпот! +" .. UILib.formatNumber(result.win) .. " 🪙", UILib.palette("warn").hover, true)
				UILib.shake(win.panel)
			elseif (result.multiplier or 0) > 0 then
				setResult("x" .. result.multiplier .. "  +" .. UILib.formatNumber(result.win) .. " 🪙", UILib.palette("good").hover, true)
			else
				setResult("Мимо  −" .. UILib.formatNumber(result.bet) .. " 🪙", THEME.muted)
			end
		end)
	end

	local function startSpin(amount)
		spinning = true
		spinId += 1
		local myId = spinId
		local elapsed = 0 -- сколько уже крутимся (по task.wait, а не os.clock)
		local reply = nil

		spinButton.setEnabled(false)
		spinButton.setText("Крутится…")
		setResult("Крутим…", THEME.text)

		for _, reel in reels do
			reel.stopped = false
		end

		-- Анимация: символы меняются, пока барабан не остановлен
		task.spawn(function()
			while myId == spinId do
				local anyMoving = false
				for _, reel in reels do
					if not reel.stopped then
						anyMoving = true
						reel.set(randomSymbol())
					end
				end
				if not anyMoving then
					break
				end
				task.wait(SPIN_FRAME)
			end
		end)

		-- Ждём ответ сервера (или таймаут), но крутим не меньше SPIN_MIN_TIME
		screen._onReply = function(result)
			reply = result
		end
		task.spawn(function()
			while myId == spinId and not reply and elapsed < REPLY_TIMEOUT do
				elapsed += task.wait(0.05)
			end
			if myId ~= spinId then
				return
			end
			screen._onReply = nil
			local left = SPIN_MIN_TIME - elapsed
			if left > 0 then
				task.wait(left)
			end
			if myId ~= spinId then
				return
			end
			finishSpin(reply or { ok = false, reason = "Сервер не ответил" })
		end)

		remote:FireServer(amount)
	end

	if remote then
		remote.OnClientEvent:Connect(function(result)
			if typeof(result) ~= "table" then
				return
			end
			local handler = screen._onReply
			if handler then
				handler(result)
			end
		end)
	end

	spinButton.face.Activated:Connect(function()
		if spinning then
			return
		end
		local amount = currentBet()
		if not amount or amount ~= amount or amount < 1 or amount > MAX_BET or amount % 1 ~= 0 then
			flashInvalid("Неверная ставка")
			return
		end
		local coins = coinsValue()
		if coins and amount > coins then
			flashInvalid("Не хватает монет!")
			return
		end
		if not remote then
			warn("[GambleScreen] GambleEvent не найден")
			flashInvalid("Автомат сломан :(")
			return
		end
		startSpin(amount)
	end)

	return screen
end

-- Окно создаётся один раз; если его уничтожили, создаётся заново
function GambleScreen.get(player)
	if controller and controller.gui.Parent then
		return controller
	end
	controller = build(player)
	return controller
end

return GambleScreen
