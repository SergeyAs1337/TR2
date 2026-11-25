-- ServerScriptService/AdminService.lua  (v1)
-- Серверная часть админ-панели. ЗАМЕНЯЕТ admin.lua (старый admin.lua нужно удалить).
--
-- Один RemoteFunction "AdminRequest":
--   InvokeServer("state")                      -> снимок состояния (события, игроки, сервер, журнал)
--   InvokeServer("action", имя, {аргументы})   -> (успех, сообщение)
-- Админ проверяется на сервере при КАЖДОМ запросе, все аргументы проверяются, запросов не больше
-- RATE_PER_SECOND в секунду. Клиенту ничего не доверяется: даже если подделать панель,
-- без своего UserId в ADMIN_USER_IDS сервер вернёт отказ.
--
-- Старые RemoteEvent-ы EventAnnouncement и StopEventRemote по-прежнему принимают запросы
-- от старого AdminResetGui, пока он не удалён.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")

local Events = require(ReplicatedStorage:WaitForChild("EventManager"))

-- ===== Настройки =====
local ADMIN_USER_IDS = { 940118285, 3322927329 }
local MIN_DURATION = 5
local MAX_DURATION = 3600
local MAX_COINS_GIVE = 1_000_000_000
local MAX_COINS_TOTAL = 1_000_000_000_000
local MAX_ANNOUNCE_LENGTH = 150
local MAX_REASON_LENGTH = 100
local RATE_PER_SECOND = 8
local LOG_SIZE = 60
local LOG_SENT_TO_CLIENT = 40
local TELEPORT_OFFSET = 4

-- ===== Remote =====
local request = ReplicatedStorage:FindFirstChild("AdminRequest")
if not request then
	request = Instance.new("RemoteFunction")
	request.Name = "AdminRequest"
	request.Parent = ReplicatedStorage
end
local eventAnnouncement = ReplicatedStorage:WaitForChild("EventAnnouncement")
local eventStopRemote = ReplicatedStorage:WaitForChild("StopEventRemote")
local resetStatsEvent = ReplicatedStorage:FindFirstChild("ResetPlayerStatsAdminEvent")

-- ===== Вспомогательное =====
local function isAdmin(player)
	return player ~= nil and table.find(ADMIN_USER_IDS, player.UserId) ~= nil
end

local actionLog = {}
local function addLog(admin, text)
	table.insert(actionLog, { t = os.time(), admin = admin.Name, text = text })
	if #actionLog > LOG_SIZE then
		table.remove(actionLog, 1)
	end
	print(("[Admin] %s: %s"):format(admin.Name, text))
end

-- Не больше RATE_PER_SECOND запросов в секунду от одного админа
local buckets = {}
local function allow(player)
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = RATE_PER_SECOND, last = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(RATE_PER_SECOND, bucket.tokens + (now - bucket.last) * RATE_PER_SECOND)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Цель: UserId (число) или имя (точное или однозначное начало), без учёта регистра
local function resolveTarget(value)
	if typeof(value) == "number" and value == value then
		return Players:GetPlayerByUserId(value)
	end
	if typeof(value) == "string" and #value > 0 and #value <= 50 then
		local lower = string.lower(value)
		local partial, count = nil, 0
		for _, player in Players:GetPlayers() do
			local name, display = string.lower(player.Name), string.lower(player.DisplayName)
			if name == lower or display == lower then
				return player
			end
			if string.sub(name, 1, #lower) == lower or string.sub(display, 1, #lower) == lower then
				partial, count = player, count + 1
			end
		end
		if count == 1 then
			return partial
		end
	end
	return nil
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getStat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name)
end

local function isInteger(value, min, max)
	return typeof(value) == "number" and value == value and value >= min and value <= max and value % 1 == 0
end

-- ===== Действия: каждая возвращает (успех, сообщение) =====
local actions = {}

function actions.startEvent(admin, args)
	if typeof(args.name) ~= "string" then
		return false, "Не выбрано событие"
	end
	local seconds = nil
	if typeof(args.duration) == "number" and args.duration == args.duration and args.duration > 0 then
		seconds = math.clamp(args.duration, MIN_DURATION, MAX_DURATION)
	end
	local ok, err = Events.Start(args.name, seconds)
	if not ok then
		return false, "Не удалось запустить: " .. tostring(err)
	end
	addLog(admin, ("запустил «%s»%s"):format(args.name, seconds and (" на " .. math.floor(seconds) .. " с") or " (до ручной остановки)"))
	return true, "Запущено: " .. args.name
end

function actions.stopEvent(admin)
	local name = Events.GetCurrent()
	if not name then
		return false, "Сейчас нет события"
	end
	Events.Stop()
	addLog(admin, ("остановил «%s»"):format(name))
	return true, "Остановлено: " .. name
end

function actions.setRandomEvents(admin, args)
	if typeof(args.enabled) ~= "boolean" then
		return false, "Неверное значение"
	end
	Events.SetRandomEnabled(args.enabled)
	addLog(admin, args.enabled and "включил случайные события" or "выключил случайные события")
	return true, args.enabled and "Случайные события включены" or "Случайные события выключены"
end

function actions.giveCoins(admin, args)
	local target = resolveTarget(args.target)
	if not target then
		return false, "Игрок не найден"
	end
	if not isInteger(args.amount, 1, MAX_COINS_GIVE) then
		return false, ("Сумма: целое число от 1 до %d"):format(MAX_COINS_GIVE)
	end
	local coins = getStat(target, "Coins")
	if not coins then
		return false, "Данные игрока ещё загружаются"
	end
	coins.Value = math.min(coins.Value + args.amount, MAX_COINS_TOTAL)
	addLog(admin, ("выдал %d монет игроку %s"):format(args.amount, target.Name))
	return true, ("Выдано %d монет: %s"):format(args.amount, target.Name)
end

function actions.setCoins(admin, args)
	local target = resolveTarget(args.target)
	if not target then
		return false, "Игрок не найден"
	end
	if not isInteger(args.amount, 0, MAX_COINS_TOTAL) then
		return false, "Сумма: целое число от 0 до " .. MAX_COINS_TOTAL
	end
	local coins = getStat(target, "Coins")
	if not coins then
		return false, "Данные игрока ещё загружаются"
	end
	coins.Value = args.amount
	addLog(admin, ("установил %d монет игроку %s"):format(args.amount, target.Name))
	return true, ("У %s теперь %d монет"):format(target.Name, args.amount)
end

function actions.kill(admin, args)
	local target = resolveTarget(args.target)
	local humanoid = target and getHumanoid(target)
	if not humanoid then
		return false, "Игрок не найден или без персонажа"
	end
	humanoid.Health = 0
	addLog(admin, ("убил игрока %s"):format(target.Name))
	return true, "Убит: " .. target.Name
end

function actions.heal(admin, args)
	if args.all == true then
		local count = 0
		for _, player in Players:GetPlayers() do
			local humanoid = getHumanoid(player)
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = humanoid.MaxHealth
				count += 1
			end
		end
		addLog(admin, ("вылечил всех (%d)"):format(count))
		return true, ("Вылечено игроков: %d"):format(count)
	end
	local target = resolveTarget(args.target)
	local humanoid = target and getHumanoid(target)
	if not humanoid or humanoid.Health <= 0 then
		return false, "Игрок не найден или мёртв"
	end
	humanoid.Health = humanoid.MaxHealth
	addLog(admin, ("вылечил игрока %s"):format(target.Name))
	return true, "Вылечен: " .. target.Name
end

function actions.freeze(admin, args)
	local target = resolveTarget(args.target)
	local root = target and getRoot(target)
	if not root then
		return false, "Игрок не найден или без персонажа"
	end
	local frozen = args.frozen == true
	root.Anchored = frozen
	target:SetAttribute("AdminFrozen", frozen)
	addLog(admin, ("%s игрока %s"):format(frozen and "заморозил" or "разморозил", target.Name))
	return true, (frozen and "Заморожен: " or "Разморожен: ") .. target.Name
end

function actions.teleportTo(admin, args)
	local target = resolveTarget(args.target)
	local targetRoot = target and getRoot(target)
	local adminRoot = getRoot(admin)
	if not targetRoot or not adminRoot then
		return false, "Нет персонажа у игрока или у тебя"
	end
	admin.Character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, TELEPORT_OFFSET))
	adminRoot.AssemblyLinearVelocity = Vector3.zero
	addLog(admin, ("телепортировался к %s"):format(target.Name))
	return true, "Ты рядом с " .. target.Name
end

function actions.bring(admin, args)
	local target = resolveTarget(args.target)
	local targetRoot = target and getRoot(target)
	local adminRoot = getRoot(admin)
	if not targetRoot or not adminRoot then
		return false, "Нет персонажа у игрока или у тебя"
	end
	target.Character:PivotTo(adminRoot.CFrame * CFrame.new(0, 0, -TELEPORT_OFFSET))
	targetRoot.AssemblyLinearVelocity = Vector3.zero
	addLog(admin, ("телепортировал к себе %s"):format(target.Name))
	return true, target.Name .. " рядом с тобой"
end

function actions.kick(admin, args)
	local target = resolveTarget(args.target)
	if not target then
		return false, "Игрок не найден"
	end
	if target == admin then
		return false, "Себя кикать нельзя"
	end
	if isAdmin(target) then
		return false, "Админов кикать нельзя"
	end
	local reason = typeof(args.reason) == "string" and args.reason or ""
	reason = string.sub(reason, 1, MAX_REASON_LENGTH)
	if reason == "" then
		reason = "Вы были исключены администратором."
	end
	local name = target.Name
	target:Kick(reason)
	addLog(admin, ("кикнул %s (%s)"):format(name, reason))
	return true, "Кикнут: " .. name
end

function actions.announce(admin, args)
	if typeof(args.message) ~= "string" then
		return false, "Нет текста"
	end
	local message = (string.gsub(args.message, "^%s*(.-)%s*$", "%1"))
	local length = utf8.len(message) or #message
	if length == 0 then
		return false, "Пустое сообщение"
	end
	if length > MAX_ANNOUNCE_LENGTH then
		return false, ("Слишком длинно (максимум %d символов)"):format(MAX_ANNOUNCE_LENGTH)
	end

	-- Текст, который увидят все игроки, обязан пройти фильтр Roblox
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(message, admin.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(filtered) ~= "string" or filtered == "" then
		return false, "Не удалось отфильтровать текст"
	end

	-- Баннер событий показывает любой текст
	eventAnnouncement:FireAllClients("📢 " .. filtered)
	addLog(admin, "объявление: " .. filtered)
	return true, "Отправлено всем"
end

-- ===== Снимок состояния для панели =====
local function buildState()
	local list = {}
	for _, player in Players:GetPlayers() do
		local coins = getStat(player, "Coins")
		local deaths = getStat(player, "Deaths")
		local humanoid = getHumanoid(player)
		table.insert(list, {
			userId = player.UserId,
			name = player.Name,
			displayName = player.DisplayName,
			coins = coins and coins.Value or nil,
			deaths = deaths and deaths.Value or nil,
			health = humanoid and math.floor(humanoid.Health) or nil,
			maxHealth = humanoid and math.floor(humanoid.MaxHealth) or nil,
			isAdmin = isAdmin(player),
			frozen = player:GetAttribute("AdminFrozen") == true,
		})
	end
	table.sort(list, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)

	local eventNames = {}
	for _, event in Events.List do
		table.insert(eventNames, event.Name)
	end
	local info = Events.GetInfo()

	local recent = {}
	for i = #actionLog, math.max(1, #actionLog - LOG_SENT_TO_CLIENT + 1), -1 do
		table.insert(recent, actionLog[i]) -- новые сверху
	end

	return {
		isAdmin = true,
		serverTime = Workspace:GetServerTimeNow(),
		events = eventNames,
		currentEvent = info.name,
		eventEndsAt = info.endsAt,
		randomEnabled = Events.IsRandomEnabled(),
		nextRandomAt = Events.GetNextRandomAt(),
		players = list,
		server = {
			players = #list,
			maxPlayers = Players.MaxPlayers,
			uptime = math.floor(Workspace.DistributedGameTime),
			placeVersion = game.PlaceVersion,
			jobId = string.sub(game.JobId, 1, 8),
		},
		log = recent,
	}
end

-- ===== Обработчик запросов =====
request.OnServerInvoke = function(player, kind, actionName, args)
	if not isAdmin(player) then
		if kind == "state" then
			return { isAdmin = false }
		end
		return false, "Нет доступа"
	end
	if not allow(player) then
		if kind == "state" then
			return nil
		end
		return false, "Слишком часто, подожди секунду"
	end

	if kind == "state" then
		local ok, result = pcall(buildState)
		if ok then
			return result
		end
		warn("[Admin] Ошибка построения состояния: " .. tostring(result))
		return nil
	elseif kind == "action" then
		if typeof(actionName) ~= "string" then
			return false, "Неизвестное действие"
		end
		local handler = rawget(actions, actionName)
		if not handler then
			return false, "Неизвестное действие"
		end
		if typeof(args) ~= "table" then
			args = {}
		end
		local ok, success, message = pcall(handler, player, args)
		if not ok then
			warn(("[Admin] Ошибка в действии '%s': %s"):format(actionName, tostring(success)))
			return false, "Ошибка на сервере"
		end
		return success == true, tostring(message or "")
	end
	return nil
end

-- ===== Совместимость со старым AdminResetGui =====
eventAnnouncement.OnServerEvent:Connect(function(player, eventName, duration)
	if not isAdmin(player) or typeof(eventName) ~= "string" then
		return
	end
	actions.startEvent(player, { name = eventName, duration = duration })
end)

eventStopRemote.OnServerEvent:Connect(function(player, eventName)
	if not isAdmin(player) or typeof(eventName) ~= "string" then
		return
	end
	if Events.GetCurrent() == eventName then
		actions.stopEvent(player)
	end
end)

-- Сброс статистики идёт через LeaderboardManager (он чистит и таблицу лидеров); здесь только журнал
if resetStatsEvent then
	resetStatsEvent.OnServerEvent:Connect(function(player, targetName)
		if isAdmin(player) and typeof(targetName) == "string" then
			addLog(player, ("сбросил статистику игроку %s"):format(string.sub(targetName, 1, 50)))
		end
	end)
end

-- Заморозка снимается при возрождении (у нового персонажа Anchored и так выключен)
local function watchPlayer(player)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("AdminFrozen", false)
	end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

print("AdminService загружен.")
