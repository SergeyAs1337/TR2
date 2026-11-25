-- ReplicatedStorage/GambleScreen  (ModuleScript, только для клиента)  v2 — редизайн
-- Окно однорукого бандита в мультяшном стиле: три барабана, быстрые ставки, баланс,
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

local REEL_FACE = Color3.fromRGB(255, 255, 255)
local REEL_PANEL = Color3.fromRGB(56, 34, 86)

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
		title = "🎰 ОДНОРУКИЙ БАНДИТ",
		accent = "purple",
		size = Vector2.new(480, 430),
		player = player,
		onOpen = function()
			screen.refresh()
		end,
	})
	local body = win.body

	-- ===== Барабаны =====
	local reelPanel = UILib.make("Frame", {
		Name = "Reels",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = REEL_PANEL,
		BorderSizePixel = 0,
	}, body)
	UILib.corner(reelPanel, THEME.radius)
	UILib.stroke(reelPanel, THEME.stroke)

	-- Стрелки линии выигрыша
	UILib.text(reelPanel, "▶", { Name = "ArrowLeft", Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(0, 2, 0, 0), TextColor3 = UILib.palette("yellow").face, TextSize = 22 })
	UILib.text(reelPanel, "◀", { Name = "ArrowRight", Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0), TextColor3 = UILib.palette("yellow").face, TextSize = 22 })

	local reels = {}
	for i = 1, 3 do
		local slot = UILib.make("Frame", {
			Name = "Reel" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.2 + (i - 1) * 0.3, 0, 0.5, 0),
			Size = UDim2.new(0.26, 0, 1, -24),
			BackgroundColor3 = REEL_FACE,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, reelPanel)
		UILib.corner(slot, THEME.radius - 4)
		UILib.stroke(slot, THEME.stroke)
		UILib.gradient(slot, Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 214, 240))
		local slotScale = UILib.make("UIScale", { Scale = 1 }, slot)

		local image = UILib.make("ImageLabel", {
			Name = "Seven",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.8, 0, 0.8, 0),
			BackgroundTransparency = 1,
			Image = SEVEN_IMAGE,
			ScaleType = Enum.ScaleType.Fit,
		}, slot)
		local emoji = UILib.text(slot, "", {
			Name = "Symbol",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 56,
			strokeThickness = 0,
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
	local resultLabel = UILib.text(body, "Ставь и крути!", {
		Name = "Result",
		Position = UDim2.new(0, 0, 0, 136),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 26,
		strokeThickness = 3,
	})
	local resultScale = UILib.make("UIScale", { Scale = 1 }, resultLabel)

	-- ===== Ставка =====
	local betRow = UILib.make("Frame", {
		Name = "BetRow",
		Position = UDim2.new(0, 0, 0, 178),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
	}, body)

	local betFrame = UILib.make("Frame", {
		Name = "BetFrame",
		Size = UDim2.new(0.42, 0, 1, 0),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, betRow)
	UILib.corner(betFrame, THEME.radius - 2)
	local betStroke = UILib.stroke(betFrame, THEME.stroke)
	UILib.text(betFrame, "🪙", { Name = "Icon", Size = UDim2.new(0, 36, 1, 0), TextSize = 22, strokeThickness = 0 })

	local betBox = UILib.make("TextBox", {
		Name = "BetBox",
		Position = UDim2.new(0, 36, 0, 0),
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = tostring(DEFAULT_BET),
		PlaceholderText = "Ставка",
		PlaceholderColor3 = THEME.muted,
		ClearTextOnFocus = false,
		TextColor3 = THEME.ink,
		TextSize = 22,
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
		{ "ВСЁ", function() return math.max(1, coinsValue() or DEFAULT_BET) end },
	}
	for index, chip in chips do
		UILib.toonButton(betRow, {
			name = "Chip" .. index,
			text = chip[1],
			color = index == 4 and "red" or "yellow",
			size = UDim2.new(0.13, 0, 1, 0),
			position = UDim2.new(0.45 + (index - 1) * 0.1375, 0, 0, 0),
			textSize = 18,
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
		Position = UDim2.new(0, 0, 0, 228),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = THEME.muted,
		TextSize = 16,
		Font = THEME.fontBody,
		strokeThickness = 0,
	})

	-- ===== Кнопка «Крутить» =====
	local spinButton = UILib.toonButton(body, {
		name = "SpinButton",
		text = "КРУТИТЬ!",
		color = "green",
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 256),
		size = UDim2.new(0.7, 0, 0, 66),
		textSize = 32,
	})

	local lostLabel = UILib.text(body, "", {
		Name = "TotalLostLabel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = THEME.muted,
		TextSize = 15,
		Font = THEME.fontBody,
		strokeThickness = 0,
	})

	screen = { gui = win.gui, frame = win.holder, window = win, reels = reels }
	screen.spinButton = spinButton
	screen.betBox = betBox
	screen.resultLabel = resultLabel

	local function setResult(text, color, big)
		resultLabel.Text = text
		resultLabel.TextColor3 = color or THEME.white
		UILib.bump(resultScale, big and 1.4 or 1.15)
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
		betStroke.Color = UILib.palette("red").face
		UILib.shake(betFrame)
		setResult(message, UILib.palette("red").top)
		task.delay(0.6, function()
			betStroke.Color = THEME.ink
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
				UILib.bump(reel.scale, 1.12)
			end)
		end

		task.delay((#reels - 1) * REEL_STOP_GAP + 0.1, function()
			if myId ~= spinId then
				return
			end
			spinning = false
			spinButton.setEnabled(true)
			spinButton.setText("КРУТИТЬ!")
			if not result.ok then
				setResult(result.reason or "Ставка не прошла", UILib.palette("red").top)
			elseif (result.multiplier or 0) >= 10 then
				setResult("💥 ДЖЕКПОТ! +" .. UILib.formatNumber(result.win) .. " 🪙", UILib.palette("yellow").top, true)
				UILib.shake(win.panel)
			elseif (result.multiplier or 0) > 0 then
				setResult("x" .. result.multiplier .. "! +" .. UILib.formatNumber(result.win) .. " 🪙", UILib.palette("green").top, true)
			else
				setResult("Мимо… −" .. UILib.formatNumber(result.bet) .. " 🪙", THEME.white)
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
		spinButton.setText("КРУТИТСЯ…")
		setResult("Крутим…", THEME.white)

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
