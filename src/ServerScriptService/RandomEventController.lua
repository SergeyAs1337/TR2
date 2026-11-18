local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventRemote = ReplicatedStorage:WaitForChild("EventAnnouncement") -- просто ждём уже существующий RemoteEvent

local Events = require(ReplicatedStorage:WaitForChild("EventManager"))

while true do
	wait(math.random(240, 360)) -- 10 секунд (поменял для примера)

	local event = Events.List[math.random(1, #Events.List)]

	print("Событие началось:", event.Name)
	event.Start()

	-- Сообщить клиентам
	EventRemote:FireAllClients(event.Name)

	wait(120) -- 15 секунд

	print("Событие закончилось:", event.Name)
	event.Stop()
end