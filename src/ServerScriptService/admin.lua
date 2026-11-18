local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage:WaitForChild("EventManager"))

local eventAnnouncement = ReplicatedStorage:WaitForChild("EventAnnouncement")
local eventStopRemote = ReplicatedStorage:WaitForChild("StopEventRemote")

local currentEventName = nil

local ADMIN_USER_IDS = {940118285, 3322927329}

local function isAdmin(player)
	for _, id in pairs(ADMIN_USER_IDS) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

-- Запуск ивента по запросу админа
eventAnnouncement.OnServerEvent:Connect(function(player, eventName)
	if not player or not isAdmin(player) then return end
	if typeof(eventName) ~= "string" then return end

	-- Останавливаем текущий ивент, если он есть
	if currentEventName then
		for _, ev in ipairs(Events.List) do
			if ev.Name == currentEventName then
				local ok, err = pcall(function() ev.Stop() end)
				if not ok then
					warn("Ошибка при остановке ивента '"..currentEventName.."': "..tostring(err))
				end
				break
			end
		end
	end

	-- Запускаем новый ивент
	for _, event in ipairs(Events.List) do
		if event.Name == eventName then
			local ok, err = pcall(function() event.Start() end)
			if ok then
				currentEventName = eventName
				eventAnnouncement:FireAllClients(eventName)
				print("Ивент запущен:", eventName)
			else
				warn("Ошибка при запуске ивента '"..eventName.."': "..tostring(err))
			end
			break
		end
	end
end)

-- Остановка ивента по запросу админа
eventStopRemote.OnServerEvent:Connect(function(player, eventName)
	if not player or not isAdmin(player) then return end
	if typeof(eventName) ~= "string" then return end

	for _, event in ipairs(Events.List) do
		if event.Name == eventName then
			local ok, err = pcall(function() event.Stop() end)
			if not ok then
				warn("Ошибка при остановке ивента '"..eventName.."': "..tostring(err))
			end

			if currentEventName == eventName then
				currentEventName = nil
				eventAnnouncement:FireAllClients(nil)
			end
			print("Ивент остановлен:", eventName)
			break
		end
	end
end)
