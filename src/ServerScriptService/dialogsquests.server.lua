-- ServerScriptService/dialogsquests  (Script)  v2 — движок диалогов с NPC
-- Диалоги лежат в ReplicatedStorage/Dialogues (ModuleScript на каждый). Формат прежний:
--   { ID, Name = "Имя NPC", Npc = "имя модели NPC в Workspace" (необязательно), OneTime,
--     Steps = { start = { Text = "..." или Lines = {...}, Options = { { Text, Next, Reward } } } } }
-- Новое:
--  * Reward(player) может ВЕРНУТЬ имя следующего шага (например, "bought" или "not_enough").
--    Так покупка показывает правильный ответ без ручных FireClient;
--  * Reward выполняется в pcall: ошибка в диалоге не ломает систему;
--  * клиенту уходят только тексты (без функций); проверка типов, частоты и расстояния до NPC;
--  * NPC-скрипты на сервере могут запускать диалог через BindableEvent
--    ServerStorage.DialogueServer.StartDialogue:Fire(player, dialogID, npcModel).
--    Раньше NPC-скрипты (обычные Script) звали FireServer, который на сервере не работает,
--    поэтому диалоги с NPC не запускались.
-- Протокол с клиентом не менялся: StartDialogue:FireClient(player, dialogID, шаг, имяNPC),
-- SelectDialogueOption:FireServer(номерВарианта). Пустой шаг (nil) = диалог закончен.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local dialogueFolder = ReplicatedStorage:WaitForChild("Dialogues")
local dialogueSystem = ReplicatedStorage:WaitForChild("DialogueSystem")
local StartDialogue = dialogueSystem:WaitForChild("StartDialogue")
local SelectDialogueOption = dialogueSystem:WaitForChild("SelectDialogueOption")

-- ===== Настройки =====
local MIN_INTERVAL = 0.25 -- секунд между запросами одного игрока
local MAX_TALK_DISTANCE = 25 -- если у диалога указан Npc, игрок должен стоять рядом
local MAX_ID_LENGTH = 64

-- Сервер-сервер: запуск диалога из скриптов NPC
local serverFolder = ServerStorage:FindFirstChild("DialogueServer")
if not serverFolder then
	serverFolder = Instance.new("Folder")
	serverFolder.Name = "DialogueServer"
	serverFolder.Parent = ServerStorage
end
local serverStart = serverFolder:FindFirstChild("StartDialogue")
if not serverStart then
	serverStart = Instance.new("BindableEvent")
	serverStart.Name = "StartDialogue"
	serverStart.Parent = serverFolder
end

local playerStates = {} -- [player] = { DialogID, Step }
local lastRequest = {}

local function rateLimited(player)
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < MIN_INTERVAL then
		return true
	end
	lastRequest[player] = now
	return false
end

local function loadDialogue(dialogID)
	if typeof(dialogID) ~= "string" or #dialogID == 0 or #dialogID > MAX_ID_LENGTH then
		return nil
	end
	local module = dialogueFolder:FindFirstChild(dialogID)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, data = pcall(require, module)
	if not ok or typeof(data) ~= "table" or typeof(data.Steps) ~= "table" then
		warn("[Dialogue] Ошибка в диалоге " .. dialogID .. ": " .. tostring(data))
		return nil
	end
	return data
end

-- Клиенту — только строки
local function sanitize(step)
	local lines = {}
	if typeof(step.Lines) == "table" then
		for _, line in step.Lines do
			if typeof(line) == "string" and line ~= "" then
				table.insert(lines, line)
			end
		end
	elseif typeof(step.Text) == "string" and step.Text ~= "" then
		table.insert(lines, step.Text)
	end
	local options = {}
	if typeof(step.Options) == "table" then
		for _, option in step.Options do
			if typeof(option) == "table" and typeof(option.Text) == "string" then
				table.insert(options, { Text = option.Text })
			end
		end
	end
	return { Lines = lines, Options = options }
end

local function nearNpc(player, data, npcModel)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local model = npcModel
	if not model and typeof(data.Npc) == "string" then
		model = Workspace:FindFirstChild(data.Npc)
		if not model then
			-- NPC не нашёлся (переименовали модель или он сейчас респавнится): не мешаем игре
			return true
		end
	end
	if not model then
		return true -- у диалога не указан NPC: проверять не с чем
	end
	local ok, pivot = pcall(model.GetPivot, model)
	if not ok then
		return false
	end
	return (pivot.Position - root.Position).Magnitude <= MAX_TALK_DISTANCE
end

local function sendStep(player, dialogID, step, data)
	StartDialogue:FireClient(player, dialogID, sanitize(step), data.Name or "NPC")
end

local function finish(player, state, data)
	playerStates[player] = nil
	if data.OneTime then
		player:SetAttribute("Completed_" .. state.DialogID, true)
	end
	StartDialogue:FireClient(player, state.DialogID, nil, data.Name or "NPC") -- закрыть окно
end

local function begin(player, dialogID, npcModel)
	local data = loadDialogue(dialogID)
	if not data then
		return
	end
	if not nearNpc(player, data, npcModel) then
		return
	end

	if data.OneTime and player:GetAttribute("Completed_" .. dialogID) then
		playerStates[player] = nil
		sendStep(player, dialogID, { Text = "Привет! Что-то ещё?", Options = { { Text = "Нет, пока" } } }, data)
		playerStates[player] = { DialogID = dialogID, Step = "__done" }
		return
	end

	local step = data.Steps.start
	if typeof(step) ~= "table" then
		return
	end
	playerStates[player] = { DialogID = dialogID, Step = "start" }
	sendStep(player, dialogID, step, data)
end

StartDialogue.OnServerEvent:Connect(function(player, dialogID)
	if rateLimited(player) then
		return
	end
	begin(player, dialogID, nil)
end)

serverStart.Event:Connect(function(player, dialogID, npcModel)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if typeof(npcModel) ~= "Instance" then
		npcModel = nil
	end
	begin(player, dialogID, npcModel)
end)

SelectDialogueOption.OnServerEvent:Connect(function(player, optionIndex)
	if rateLimited(player) then
		return
	end
	if typeof(optionIndex) ~= "number" or optionIndex ~= optionIndex or optionIndex % 1 ~= 0 then
		return
	end
	local state = playerStates[player]
	if not state then
		return
	end
	local data = loadDialogue(state.DialogID)
	if not data then
		playerStates[player] = nil
		return
	end
	if state.Step == "__done" then
		playerStates[player] = nil
		StartDialogue:FireClient(player, state.DialogID, nil, data.Name or "NPC")
		return
	end

	local currentStep = data.Steps[state.Step]
	if typeof(currentStep) ~= "table" or typeof(currentStep.Options) ~= "table" then
		finish(player, state, data)
		return
	end
	-- номер считаем по тем вариантам, что ушли клиенту (sanitize пропускает битые)
	local valid = {}
	for _, option in currentStep.Options do
		if typeof(option) == "table" and typeof(option.Text) == "string" then
			table.insert(valid, option)
		end
	end
	local selected = valid[optionIndex]
	if not selected then
		return
	end

	local nextId = selected.Next
	if typeof(selected.Reward) == "function" then
		local ok, result = pcall(selected.Reward, player)
		if not ok then
			warn("[Dialogue] Ошибка в Reward (" .. state.DialogID .. "): " .. tostring(result))
		elseif typeof(result) == "string" then
			nextId = result
		end
	end
	if playerStates[player] ~= state then
		return -- игрок вышел или начал другой диалог, пока выполнялся Reward
	end

	local nextStep = typeof(nextId) == "string" and data.Steps[nextId]
	if typeof(nextStep) == "table" then
		state.Step = nextId
		sendStep(player, state.DialogID, nextStep, data)
	else
		finish(player, state, data)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
	lastRequest[player] = nil
end)
