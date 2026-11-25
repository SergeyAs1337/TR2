-- ServerScriptService/RandomEventController.lua  (v2)
-- Запускает случайное событие раз в несколько минут.
--
-- Что изменилось:
--  * ошибка в событии больше не убивает контроллер (раньше любое исключение в Start()
--    навсегда останавливало все случайные события, пока сервер не перезапустят);
--  * событие объявляется игрокам, только если оно реально началось;
--  * не запускаем события на пустом сервере и поверх события, запущенного админом;
--  * одно и то же событие не выпадает дважды подряд.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage:WaitForChild("EventManager"))

local PAUSE_MIN = 240 -- пауза между событиями, секунд
local PAUSE_MAX = 360
local EVENT_DURATION = 120 -- сколько длится событие
local RETRY_DELAY = 30 -- если событие не смогло начаться, пробуем другое через столько секунд

local lastName = nil

local function pickEvent()
	local list = Events.List
	if #list <= 1 then
		return list[1]
	end
	local event
	repeat
		event = list[math.random(1, #list)]
	until event.Name ~= lastName
	return event
end

local nextDelay = math.random(PAUSE_MIN, PAUSE_MAX)

while true do
	-- время следующего события видно в админ-панели
	Events.SetNextRandomAt(Workspace:GetServerTimeNow() + nextDelay)
	task.wait(nextDelay)

	if not Events.IsRandomEnabled() then
		-- выключены админом: ждём включения, после него новая пауза (а не мгновенный запуск)
		Events.SetNextRandomAt(nil)
		while not Events.IsRandomEnabled() do
			task.wait(2)
		end
		nextDelay = math.random(PAUSE_MIN, PAUSE_MAX)
	elseif #Players:GetPlayers() == 0 or Events.GetCurrent() then
		-- пустой сервер или идёт событие админа: проверим снова чуть позже
		Events.SetNextRandomAt(nil)
		task.wait(5)
		nextDelay = 0
	else
		local event = pickEvent()
		local ok, err = Events.Start(event.Name, EVENT_DURATION)
		if ok then
			lastName = event.Name
			Events.SetNextRandomAt(nil)
			task.wait(EVENT_DURATION) -- остановит событие таймер внутри Events.Start
			nextDelay = math.random(PAUSE_MIN, PAUSE_MAX)
		else
			warn(("[Events] '%s' не запустилось: %s"):format(event.Name, tostring(err)))
			nextDelay = RETRY_DELAY -- не ждём полную паузу: пробуем другое событие скоро
		end
	end
end
