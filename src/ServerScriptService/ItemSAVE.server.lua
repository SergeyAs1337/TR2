-- ServerScriptService/ItemSAVE  (Script)  v2 — сохранение инструментов игрока
-- Хранилище и ключ прежние (PlayerTools / "tools_" .. UserId), список имён инструментов.
-- Что исправлено:
--  * если загрузка не удалась, при выходе сохранялся пустой рюкзак и ВСЕ предметы игрока
--    пропадали навсегда. Теперь без успешной загрузки ничего не сохраняется;
--  * сохраняется и инструмент в руках (раньше терялся, если выйти с ним в руках);
--  * повторы при сбоях, сохранение при остановке сервера (BindToClose);
--  * загружаются только инструменты из ReplicatedStorage и не больше MAX_TOOLS.
-- Известное ограничение: если игрок вышел сразу после смерти, предметы уже выпали
-- на землю (ItemDrops), и в сохранение они не попадут — так было и раньше.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local toolsDataStore = DataStoreService:GetDataStore("PlayerTools")

local IS_STUDIO = RunService:IsStudio()
local LOAD_ATTEMPTS = IS_STUDIO and 1 or 4
local SAVE_ATTEMPTS = 3
local MAX_TOOLS = 50
local SHUTDOWN_TIMEOUT = 20

local loaded = {} -- loaded[player] = true, если загрузка прошла успешно
local saving = {}

local function withRetry(attempts, label, fn)
	local pause = 1
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[ItemSAVE] %s: попытка %d/%d не удалась: %s"):format(label, attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(pause)
			pause = math.min(pause * 2, 8)
		end
	end
	return false, nil
end

local function collectTools(player)
	local names = {}
	local function add(container)
		if not container then
			return
		end
		for _, item in container:GetChildren() do
			if item:IsA("Tool") and #names < MAX_TOOLS then
				table.insert(names, item.Name)
			end
		end
	end
	add(player:FindFirstChildOfClass("Backpack"))
	add(player.Character) -- инструмент в руках
	return names
end

local function loadTools(player)
	local ok, savedTools = withRetry(LOAD_ATTEMPTS, "загрузка " .. player.Name, function()
		return toolsDataStore:GetAsync("tools_" .. player.UserId)
	end)
	if not ok then
		warn("[ItemSAVE] Не удалось загрузить предметы " .. player.Name .. ", сохранение для него выключено")
		return
	end
	if not player.Parent then
		return
	end
	loaded[player] = true

	if typeof(savedTools) ~= "table" then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	local count = 0
	for _, toolName in savedTools do
		if count >= MAX_TOOLS then
			break
		end
		if typeof(toolName) == "string" then
			local tool = ReplicatedStorage:FindFirstChild(toolName)
			if tool and tool:IsA("Tool") then
				tool:Clone().Parent = backpack
				count += 1
			end
		end
	end
end

local function saveTools(player)
	if not loaded[player] or saving[player] then
		return
	end
	saving[player] = true
	local toolNames = collectTools(player)
	withRetry(SAVE_ATTEMPTS, "сохранение " .. player.Name, function()
		toolsDataStore:SetAsync("tools_" .. player.UserId, toolNames)
	end)
	saving[player] = nil
end

Players.PlayerAdded:Connect(loadTools)
for _, player in Players:GetPlayers() do
	task.spawn(loadTools, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveTools(player)
	loaded[player] = nil
end)

game:BindToClose(function()
	if IS_STUDIO then
		return
	end
	local pending = 0
	for player in loaded do
		pending += 1
		task.spawn(function()
			saveTools(player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < SHUTDOWN_TIMEOUT do
		waited += task.wait(0.1)
	end
end)
