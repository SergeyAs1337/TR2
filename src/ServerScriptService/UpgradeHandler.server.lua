-- ServerScriptService/UpgradeHandler.lua  (v2)
-- ЕДИНАЯ система апгрейдов. Заменяет и UpgradeHandler.lua, и hyperscript.lua.
-- hyperscript.lua нужно УДАЛИТЬ: он создаёт то же событие UpgradeRequest, и каждая покупка
-- снова обработается дважды.
--
-- Что изменилось:
--  * один владелец данных и одно событие; цены берутся из LEVEL_PRICES (как в старом UpgradeHandler);
--  * при загрузке читаются ОБА старых хранилища (PlayerUpgrades и PlayerUpgradesV1),
--    берётся максимальный уровень каждого апгрейда: прогресс игроков не теряется;
--  * сбой загрузки не затирает данные (повторы, затем кик либо игра без сохранения);
--  * запись через UpdateAsync со слиянием по максимуму: уровни никогда не понижаются,
--    даже если два сервера записывают одновременно;
--  * множитель монет больше НЕ следит за Coins.Value. Раньше он умножал любой прирост монет,
--    включая выигрыши в казино: при x3+ казино становилось прибыльным. Теперь скрипт только
--    выставляет атрибут игрока CoinMultiplier, а награду за смерть умножает LeaderboardManager.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- ===== Настройки =====
local STORE_NAME = "PlayerUpgrades"
local LEGACY_STORE_NAME = "PlayerUpgradesV1" -- хранилище hyperscript.lua
local READ_LEGACY = true -- когда убедишься, что всё перенесено, можно выключить

local IS_STUDIO = RunService:IsStudio()
-- В Studio без включённого "Studio Access to API Services" DataStore всегда падает:
-- там одна попытка и игра без сохранения, без кика.
local LOAD_ATTEMPTS = IS_STUDIO and 1 or 5
local SAVE_ATTEMPTS = 3
local KICK_ON_LOAD_FAILURE = not IS_STUDIO
local PURCHASE_COOLDOWN = 0.25 -- секунд между покупками одного игрока
local SHUTDOWN_TIMEOUT = 25

local MAX_LEVELS = { Health = 10, Speed = 10, Regen = 10, CoinMultiplier = 10 }
local LEVEL_PRICES = { 100, 200, 400, 800, 1600, 3200, 5000, 7500, 10000 } -- цена повышения с уровня N на N+1

local KICK_MESSAGE = "Не удалось загрузить твои апгрейды. Зайди ещё раз через минуту, прогресс не потерян."

-- ===== Хранилища и событие =====
local store = DataStoreService:GetDataStore(STORE_NAME)
local legacyStore = DataStoreService:GetDataStore(LEGACY_STORE_NAME)

local upgradeEvent = ReplicatedStorage:FindFirstChild("UpgradeRequest")
if not upgradeEvent then
	upgradeEvent = Instance.new("RemoteEvent")
	upgradeEvent.Name = "UpgradeRequest"
	upgradeEvent.Parent = ReplicatedStorage
end

if ServerScriptService:FindFirstChild("hyperscript") then
	warn("[Upgrades] hyperscript.lua всё ещё в игре! Удали его, иначе каждая покупка обрабатывается дважды.")
end

-- sessions[player] = { levels, ready, canSave, dirty, saving, finalizing, lastBuy }
local sessions = {}

-- ===== Вспомогательное =====
local function withRetry(attempts, label, fn)
	local pause = 1
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[Upgrades] %s: попытка %d/%d не удалась: %s"):format(label, attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(pause)
			pause = math.min(pause * 2, 16)
		end
	end
	return false, nil
end

-- Приводит что угодно к корректной таблице уровней 1..max
local function sanitizeLevels(raw)
	local levels = {}
	for name, maxLevel in MAX_LEVELS do
		local value = typeof(raw) == "table" and raw[name] or nil
		if typeof(value) ~= "number" or value ~= value then
			value = 1
		end
		levels[name] = math.clamp(math.floor(value), 1, maxLevel)
	end
	return levels
end

local function regenDelay(level)
	return 5 - (level - 1) * 2 / 9 -- 5 с -> 3 с
end

local function regenPercent(level)
	return 5 + (level - 1) * 5 / 9 -- 5% -> 10%
end

-- ===== Эффекты =====
local function applyHealth(humanoid, level, healToFull)
	local oldMax = humanoid.MaxHealth
	local newMax = 100 * level
	humanoid.MaxHealth = newMax
	if healToFull then
		humanoid.Health = newMax
	elseif newMax > oldMax then
		humanoid.Health += newMax - oldMax -- при покупке лечим только на прибавку
	end
end

local function applySpeed(humanoid, level)
	local speed = 16 + (level - 1) * 16 / 9 -- 16 -> 32
	-- Базовая скорость для других систем: BoxJob вычитает из неё замедление от коробок
	humanoid.WalkSpeed = speed
	humanoid:SetAttribute("BaseWalkSpeed", speed) -- после WalkSpeed: BoxJob пересчитает замедление
end

local function startRegen(player, humanoid)
	task.spawn(function()
		while humanoid.Parent and humanoid.Health > 0 do
			local session = sessions[player]
			if not session then
				return
			end
			task.wait(regenDelay(session.levels.Regen)) -- уровень читается заново на каждом шаге
			if humanoid.Parent and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				local percent = regenPercent(session.levels.Regen)
				humanoid.Health = math.min(humanoid.Health + humanoid.MaxHealth * percent / 100, humanoid.MaxHealth)
			end
		end
	end)
end

local function onCharacterAdded(player, character)
	task.wait(0.3) -- как в прежних скриптах: даём персонажу собраться
	local session = sessions[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not session or not humanoid then
		return
	end
	applyHealth(humanoid, session.levels.Health, true)
	applySpeed(humanoid, session.levels.Speed)
	startRegen(player, humanoid)
end

-- Зеркало для клиента (JSON-строка, как ждёт интерфейс) и для LeaderboardManager
local function publish(player, session)
	player:SetAttribute("Upgrades", HttpService:JSONEncode(session.levels))
	player:SetAttribute("CoinMultiplier", session.levels.CoinMultiplier)
end

-- ===== Загрузка =====
-- Возвращает уровни или nil при сбое. Сбой чтения ЛЮБОГО из хранилищ считается сбоем загрузки:
-- иначе игрок увидел бы заниженные уровни и мог бы докупить уже купленное.
local function loadLevels(player)
	local key = tostring(player.UserId)

	local ok, main = withRetry(LOAD_ATTEMPTS, "загрузка " .. player.Name, function()
		return store:GetAsync(key)
	end)
	if not ok or (main ~= nil and typeof(main) ~= "table") then
		return nil
	end

	local legacy = nil
	if READ_LEGACY then
		local okLegacy, legacyData = withRetry(LOAD_ATTEMPTS, "загрузка (V1) " .. player.Name, function()
			return legacyStore:GetAsync(key)
		end)
		if not okLegacy or (legacyData ~= nil and typeof(legacyData) ~= "table") then
			return nil
		end
		legacy = legacyData
	end

	local levels = sanitizeLevels(main)
	local legacyLevels = sanitizeLevels(legacy)
	for name in MAX_LEVELS do
		levels[name] = math.max(levels[name], legacyLevels[name])
	end
	return levels
end

-- ===== Сохранение =====
local function writeLevels(player, session)
	local levels = table.clone(session.levels) -- снимок: покупки во время записи не потеряются
	return withRetry(SAVE_ATTEMPTS, "сохранение " .. player.Name, function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			local data = typeof(old) == "table" and old or {}
			for name in MAX_LEVELS do
				local oldLevel = typeof(data[name]) == "number" and data[name] or 1
				data[name] = math.max(oldLevel, levels[name]) -- уровни не понижаются
			end
			return data
		end)
	end)
end

-- Пишет, пока есть несохранённые изменения. Быстрые покупки подряд склеиваются в одну запись.
local function flush(player)
	local session = sessions[player]
	if not session or not session.canSave or session.saving then
		return
	end
	session.saving = true
	while session.dirty do
		session.dirty = false
		if not writeLevels(player, session) then
			session.dirty = true -- не вышло: повторим при следующей покупке или при выходе
			break
		end
	end
	session.saving = false
end

local function requestSave(player)
	local session = sessions[player]
	if session then
		session.dirty = true
		task.spawn(flush, player)
	end
end

local function finalSave(player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.finalizing then
		while sessions[player] do
			task.wait(0.1)
		end
		return
	end
	session.finalizing = true
	while session.saving do
		task.wait(0.1)
	end
	if session.dirty then
		flush(player)
	end
	sessions[player] = nil
end

-- ===== Вход игрока =====
local function onPlayerAdded(player)
	if sessions[player] then
		return
	end
	local session = {
		levels = sanitizeLevels(nil),
		ready = false,
		canSave = false,
		dirty = false,
		saving = false,
		finalizing = false,
		lastBuy = nil,
	}
	sessions[player] = session

	local levels = loadLevels(player)

	if not player:IsDescendantOf(Players) then
		sessions[player] = nil -- вышел во время загрузки
		return
	end

	if levels then
		session.levels = levels
		session.canSave = true
		-- Если из старых хранилищ получилось больше, чем в основном, фиксируем слияние
		session.dirty = READ_LEGACY
	elseif KICK_ON_LOAD_FAILURE then
		sessions[player] = nil
		player:Kick(KICK_MESSAGE)
		return
	end
	-- (если levels == nil и кика нет: играет с базовыми уровнями, canSave остаётся false)

	session.ready = true
	publish(player, session)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	if session.dirty then
		task.spawn(flush, player)
	end
end

-- ===== Покупка =====
upgradeEvent.OnServerEvent:Connect(function(player, upgradeName)
	if typeof(upgradeName) ~= "string" then
		return
	end
	local maxLevel = MAX_LEVELS[upgradeName]
	if not maxLevel then
		return
	end

	local session = sessions[player]
	if not session or not session.ready then
		return
	end

	local now = os.clock()
	if session.lastBuy and now - session.lastBuy < PURCHASE_COOLDOWN then
		return
	end
	session.lastBuy = now

	local level = session.levels[upgradeName]
	if level >= maxLevel then
		upgradeEvent:FireClient(player, upgradeName, false, "Макс уровень!")
		return
	end

	local price = LEVEL_PRICES[level]
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not price or not coins then
		return
	end
	if coins.Value < price then
		upgradeEvent:FireClient(player, upgradeName, false, "Недостаточно монет!")
		return
	end

	-- Проверка и списание идут без yield, поэтому двойная трата невозможна
	coins.Value -= price
	session.levels[upgradeName] = level + 1
	publish(player, session)

	-- Эффект применяем только к тому, что купили (чтобы не сбрасывать чужие временные изменения)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		if upgradeName == "Health" then
			applyHealth(humanoid, level + 1, false)
		elseif upgradeName == "Speed" then
			applySpeed(humanoid, level + 1)
		end
	end

	requestSave(player)
	upgradeEvent:FireClient(player, upgradeName, true)
end)

-- ===== Подключение =====
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(finalSave)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	if IS_STUDIO then
		return
	end

	local list = {}
	for player in sessions do
		table.insert(list, player)
	end

	local pending = #list
	for _, player in list do
		task.spawn(function()
			finalSave(player)
			pending -= 1
		end)
	end

	local deadline = os.clock() + SHUTDOWN_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)
