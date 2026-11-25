-- ServerScriptService/everydaycount  (Script)  v2 — ежедневное задание «умри 15 раз»
-- Заменяет прежний everydaycount и мёртвый DailyQuestModule (его и sbrocs нужно удалить).
--
-- Что исправлено:
--  * сбой загрузки больше не считается «новым днём»: раньше награды можно было получить
--    повторно, а сохранение затирало настоящий прогресс. Теперь загрузка повторяется,
--    а пока данных нет, задание не считается и не сохраняется;
--  * сохранение не на каждой смерти (это выедало лимит DataStore), а раз в минуту, при выходе
--    и при остановке сервера (BindToClose). Запись через UpdateAsync со слиянием;
--  * награда не теряется, если leaderstats ещё не загрузились: она выдаётся, как только появятся;
--  * хранилище и ключ прежние (DailyDeaths / UserId), формат совместим: прогресс сохраняется.
--
-- Клиент (DailyQuestHud) читает атрибуты игрока: DailyDeaths, DailyQuestTarget,
-- DailyQuestCompleted, DailyRewardsGiven ("1,5"), DailyQuestAvailable.
-- Событие DailyQuestUpdate: FireClient(player, deaths, наградаМонет или nil).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ===== Настройки =====
local STORE_NAME = "DailyDeaths"
local TARGET = 15
local REWARDS = { -- по возрастанию
	{ deaths = 1, coins = 30 },
	{ deaths = 5, coins = 50 },
	{ deaths = 15, coins = 150 },
}
local AUTOSAVE_INTERVAL = 60
local RETRY_LOAD_INTERVAL = 30 -- если загрузка не удалась, пробуем снова
local IS_STUDIO = RunService:IsStudio()
local LOAD_ATTEMPTS = IS_STUDIO and 1 or 4
local SAVE_ATTEMPTS = 3
local SHUTDOWN_TIMEOUT = 20

local store = DataStoreService:GetDataStore(STORE_NAME)

local updateEvent = ReplicatedStorage:FindFirstChild("DailyQuestUpdate")
if not updateEvent then
	updateEvent = Instance.new("RemoteEvent")
	updateEvent.Name = "DailyQuestUpdate"
	updateEvent.Parent = ReplicatedStorage
end

-- sessions[player] = { ready, date, deaths, given = { [порог] = true }, dirty, saving }
local sessions = {}

-- ===== Вспомогательное =====
local function today()
	local d = os.date("!*t")
	return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function withRetry(attempts, label, fn)
	local pause = 1
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[Daily] %s: попытка %d/%d не удалась: %s"):format(label, attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(pause)
			pause = math.min(pause * 2, 8)
		end
	end
	return false, nil
end

local function parseGiven(raw)
	local given = {}
	if typeof(raw) == "string" then
		for piece in string.gmatch(raw, "[^,]+") do
			local n = tonumber(piece)
			if n then
				given[n] = true
			end
		end
	end
	return given
end

local function serializeGiven(given)
	local list = {}
	for threshold in given do
		table.insert(list, threshold)
	end
	table.sort(list)
	for i, n in list do
		list[i] = tostring(n)
	end
	return table.concat(list, ",")
end

local function publish(player, session)
	player:SetAttribute("DailyQuestTarget", TARGET)
	player:SetAttribute("DailyQuestAvailable", session.ready)
	player:SetAttribute("DailyDeaths", session.deaths)
	player:SetAttribute("DailyQuestCompleted", session.deaths >= TARGET)
	player:SetAttribute("DailyRewardsGiven", serializeGiven(session.given))
	-- старое имя атрибута, на случай если его читает что-то ещё
	player:SetAttribute("DailyQuestRewardsGiven", serializeGiven(session.given))
end

local function resetForDay(session, date)
	session.date = date
	session.deaths = 0
	session.given = {}
	session.dirty = true
end

-- ===== Сохранение =====
local function save(player)
	local session = sessions[player]
	if not session or not session.ready or not session.dirty or session.saving then
		return
	end
	session.saving = true
	session.dirty = false
	local snapshot = {
		date = session.date,
		deaths = session.deaths,
		given = table.clone(session.given),
	}

	local ok = withRetry(SAVE_ATTEMPTS, "сохранение " .. player.Name, function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if typeof(old) == "table" and typeof(old.date) == "string" then
				if old.date > snapshot.date then
					return nil -- другой сервер уже записал следующий день: не трогаем
				end
				if old.date == snapshot.date then
					-- тот же день: берём максимум и объединяем выданные награды
					local merged = parseGiven(old.rewardsGiven)
					for threshold in snapshot.given do
						merged[threshold] = true
					end
					local deaths = math.max(tonumber(old.deaths) or 0, snapshot.deaths)
					return { date = snapshot.date, deaths = deaths, completed = deaths >= TARGET, rewardsGiven = serializeGiven(merged) }
				end
			end
			return {
				date = snapshot.date,
				deaths = snapshot.deaths,
				completed = snapshot.deaths >= TARGET,
				rewardsGiven = serializeGiven(snapshot.given),
			}
		end)
	end)

	session.saving = false
	if not ok then
		session.dirty = true -- попробуем при следующем автосохранении
	end
end

-- ===== Награды =====
-- Выдаёт все положенные, но ещё не выданные награды. Если монет ещё нет, ждёт следующего вызова.
local function grantPending(player)
	local session = sessions[player]
	if not session or not session.ready then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then
		return
	end
	local changed = false
	for _, reward in REWARDS do
		if session.deaths >= reward.deaths and not session.given[reward.deaths] then
			session.given[reward.deaths] = true
			coins.Value += reward.coins
			changed = true
			updateEvent:FireClient(player, session.deaths, reward.coins)
		end
	end
	if changed then
		session.dirty = true
		publish(player, session)
	end
end

-- ===== Загрузка =====
local function load(player, attempts)
	local session = sessions[player]
	if not session then
		return
	end
	local ok, data = withRetry(attempts, "загрузка " .. player.Name, function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if sessions[player] ~= session then
		return -- игрок вышел, пока грузились данные
	end
	if not ok then
		return false
	end

	local date = today()
	if typeof(data) == "table" and data.date == date then
		session.date = date
		session.deaths = math.max(0, math.floor(tonumber(data.deaths) or 0))
		session.given = parseGiven(data.rewardsGiven)
		session.dirty = false
	else
		resetForDay(session, date)
		session.dirty = false -- пустой новый день записывать незачем
	end
	session.ready = true
	publish(player, session)
	grantPending(player)
	return true
end

-- ===== Смерти =====
local function onDied(player)
	local session = sessions[player]
	if not session or not session.ready then
		return -- данные ещё не загружены: смерть в задание не идёт, зато ничего не теряется
	end
	local date = today()
	if session.date ~= date then
		resetForDay(session, date)
	end
	if session.deaths < TARGET then
		session.deaths += 1
		session.dirty = true
	end
	publish(player, session)
	updateEvent:FireClient(player, session.deaths, nil)
	grantPending(player)
end

local function watchCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			onDied(player)
		end)
	end
end

local function onPlayerAdded(player)
	if sessions[player] then
		return
	end
	local session = { ready = false, date = today(), deaths = 0, given = {}, dirty = false }
	sessions[player] = session
	publish(player, session)

	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	-- leaderstats появились позже: выдать отложенные награды
	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			task.defer(grantPending, player)
		end
	end)

	if not load(player, LOAD_ATTEMPTS) then
		-- не вышло: пробуем ещё, пока игрок в игре
		task.spawn(function()
			while sessions[player] == session and not session.ready do
				task.wait(RETRY_LOAD_INTERVAL)
				if sessions[player] == session and not session.ready then
					load(player, 1)
				end
			end
		end)
	end
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	local waited = 0
	while session and session.saving and waited < 15 do -- идёт автосохранение: дождёмся и допишем
		waited += task.wait(0.1)
	end
	save(player)
	sessions[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Автосохранение и смена дня у тех, кто в игре
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		local date = today()
		for player, session in sessions do
			if session.ready and session.date ~= date then
				resetForDay(session, date)
				publish(player, session)
				updateEvent:FireClient(player, 0, nil)
			end
			task.spawn(save, player)
		end
	end
end)

game:BindToClose(function()
	if IS_STUDIO then
		return
	end
	local pending = 0
	for player in sessions do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < SHUTDOWN_TIMEOUT do
		waited += task.wait(0.1)
	end
end)
