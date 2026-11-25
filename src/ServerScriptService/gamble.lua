-- ServerScriptService/gamble.lua  (v2: сервер отвечает клиенту результатом ставки, см. reply)
-- Единый серверный скрипт ставок. ЗАМЕНЯЕТ И gamble.lua, И losssaved.lua
-- (losssaved.lua нужно удалить, иначе каждая ставка снова обработается дважды).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== Настройки =====
local MIN_BET = 1
local MAX_BET = 1_000_000_000 -- защита от переполнения (выигрыш = ставка * 10)
local COOLDOWN = 1 -- секунд между ставками одного игрока
local SAVE_INTERVAL = 60 -- как часто сохранять общий проигрыш
local SAVE_ATTEMPTS = 3

local STORE_NAME = "GlobalLostCoins" -- те же имена, что в losssaved.lua,
local STORE_KEY = "GlobalLost" -- поэтому накопленная статистика сохранится

-- Исходы проверяются по порядку, шансы суммируются (1% + 24% = выигрыш в 25%).
-- ВНИМАНИЕ: в старом gamble.lua в комментарии было "44% x2", но код давал 24%.
-- В losssaved.lua было 0.01% на x10 и 30% на x2. Здесь взяты значения из кода gamble.lua.
local OUTCOMES = {
	{ chance = 0.01, multiplier = 10 },
	{ chance = 0.24, multiplier = 2 },
}

-- ===== Общая статистика (читается клиентом: ReplicatedStorage.GlobalStats.TotalLost) =====
local remote = ReplicatedStorage:WaitForChild("GambleEvent")

local globalStats = ReplicatedStorage:FindFirstChild("GlobalStats")
if not globalStats then
	globalStats = Instance.new("Folder")
	globalStats.Name = "GlobalStats"
	globalStats.Parent = ReplicatedStorage
end

local totalLost = globalStats:FindFirstChild("TotalLost")
if not totalLost then
	totalLost = Instance.new("IntValue")
	totalLost.Name = "TotalLost"
	totalLost.Value = 0
	totalLost.Parent = globalStats
end

local lostStore = DataStoreService:GetDataStore(STORE_NAME)
local pendingLoss = 0 -- проигрыш этого сервера, ещё не записанный в DataStore
local flushing = false

-- ===== Сохранение =====
-- UpdateAsync прибавляет дельту к значению в хранилище, поэтому несколько серверов
-- не перезаписывают друг друга (SetAsync терял проигрыши с других серверов).
local function flush()
	if flushing or pendingLoss <= 0 then
		return
	end
	flushing = true

	local delta = pendingLoss
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, result = pcall(function()
			return lostStore:UpdateAsync(STORE_KEY, function(old)
				return (typeof(old) == "number" and old or 0) + delta
			end)
		end)

		if ok and typeof(result) == "number" then
			-- Вычитаем именно delta: пока шло сохранение, pendingLoss мог вырасти.
			pendingLoss -= delta
			totalLost.Value = result + pendingLoss
			break
		end

		warn(("Ошибка сохранения общего проигрыша (%d/%d): %s"):format(attempt, SAVE_ATTEMPTS, tostring(result)))
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end

	flushing = false
end

-- Загрузка при старте. Если не вышло — счётчик начинается с 0, но запись всё равно
-- безопасна: UpdateAsync прибавит дельту к реальному значению, а не затрёт его.
do
	local ok, value = pcall(function()
		return lostStore:GetAsync(STORE_KEY)
	end)
	if ok and typeof(value) == "number" then
		totalLost.Value = value
	elseif not ok then
		warn("Не удалось загрузить общий проигрыш: " .. tostring(value))
	end
end

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)
		flush()
	end
end)

game:BindToClose(function()
	while flushing do
		task.wait()
	end
	flush()
end)

-- ===== Ставки =====
local rng = Random.new()
local lastBetAt: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(player)
	lastBetAt[player] = nil
end)

-- Ответ клиенту, чтобы окно автомата остановило барабаны на результате:
--   { ok = true, bet = ставка, multiplier = 0 / 2 / 10, win = выигрыш }
--   { ok = false, reason = "текст для игрока" }
local function reply(player, result)
	remote:FireClient(player, result)
end

remote.OnServerEvent:Connect(function(player, bet)
	-- 1. Тип и диапазон: NaN, inf, дробные, отрицательные и огромные ставки отбрасываем
	if typeof(bet) ~= "number" or bet ~= bet or bet < MIN_BET or bet > MAX_BET or bet % 1 ~= 0 then
		reply(player, { ok = false, reason = "Неверная ставка" })
		return
	end

	-- 2. Кулдаун
	local now = os.clock()
	local last = lastBetAt[player]
	if last and now - last < COOLDOWN then
		reply(player, { ok = false, reason = "Не так быстро!" })
		return
	end

	-- 3. Баланс (проверка и списание идут без yield, поэтому гонок нет)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins or not coins:IsA("IntValue") or coins.Value < bet then
		reply(player, { ok = false, reason = "Не хватает монет!" })
		return
	end

	lastBetAt[player] = now
	coins.Value -= bet

	-- 4. Розыгрыш
	local roll = rng:NextNumber() -- [0, 1)
	local threshold = 0
	local multiplier = 0
	for _, outcome in OUTCOMES do
		threshold += outcome.chance
		if roll < threshold then
			multiplier = outcome.multiplier
			break
		end
	end

	local win = bet * multiplier
	if win > 0 then
		coins.Value += win
	else
		pendingLoss += bet
		totalLost.Value += bet -- клиенты видят проигрыш сразу, а в DataStore он уйдёт при ближайшем сохранении
	end

	reply(player, { ok = true, bet = bet, multiplier = multiplier, win = win })
end)
