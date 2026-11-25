-- StarterPlayer/StarterPlayerScripts/DialogueUI  (LocalScript)  v1 — окно диалогов с NPC
-- Заменяет StarterGui/DialogueGui (удалить). Стиль админ-панели, строится кодом.
--   * плашка снизу экрана: имя NPC, текст печатается по буквам (кириллица больше не
--     «ломается» посередине буквы), клик / E / Enter — дальше или пропустить печать;
--   * варианты ответа — кнопками, на ПК можно цифрами 1–9;
--   * протокол с сервером прежний (dialogsquests v2): StartDialogue и SelectDialogueOption.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local CHARS_PER_SECOND = 45
local REPLY_TIMEOUT = 4 -- если сервер не ответил на выбор, окно закрывается

local player = Players.LocalPlayer
local system = ReplicatedStorage:WaitForChild("DialogueSystem")
local StartDialogue = system:WaitForChild("StartDialogue")
local SelectOption = system:WaitForChild("SelectDialogueOption")

local gui = UILib.screenGui("DialogueGui", 12, player)

local panel = UILib.panel(gui, {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.new(0, 640, 0, 170),
	BackgroundColor3 = THEME.background,
	BackgroundTransparency = 0.04,
	Visible = false,
})
UILib.stroke(panel, 1, THEME.border)
UILib.fitScale(panel)

-- Клик по плашке = «дальше»
local advanceArea = UILib.make("TextButton", {
	Name = "Advance",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
}, panel)

local nameTag = UILib.panel(panel, {
	Name = "NameTag",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0, 0),
	Size = UDim2.new(0, 180, 0, 30),
	BackgroundColor3 = UILib.palette("accent").face,
	ZIndex = 3,
})
local nameLabel = UILib.text(nameTag, "", {
	Name = "Label",
	Size = UDim2.new(1, -16, 1, 0),
	Position = UDim2.new(0, 8, 0, 0),
	TextSize = 15,
	ZIndex = 4,
})

local closeButton = UILib.actionButton(panel, {
	name = "CloseButton",
	text = "✕",
	color = "neutral",
	size = UDim2.new(0, 30, 0, 30),
	anchor = Vector2.new(1, 0),
	position = UDim2.new(1, -10, 0, 10),
	zIndex = 3,
})

local textLabel = UILib.text(panel, "", {
	Name = "DialogText",
	Position = UDim2.new(0, 20, 0, 26),
	Size = UDim2.new(1, -70, 1, -56),
	Font = THEME.fontBody,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 2,
})

local hint = UILib.text(panel, "Нажми E или коснись, чтобы продолжить  ▸", {
	Name = "Hint",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -8),
	Size = UDim2.new(0, 360, 0, 18),
	TextSize = 12,
	Font = THEME.fontBody,
	TextColor3 = THEME.muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 2,
})

local optionsFrame = UILib.make("Frame", {
	Name = "OptionsFrame",
	Position = UDim2.new(0, 16, 0, 26),
	Size = UDim2.new(1, -32, 1, -38),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 3,
}, panel)
local optionsLayout = UILib.list(optionsFrame, 6)
optionsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

-- ===== Состояние =====
local lines = {}
local lineIndex = 0
local options = {}
local typing = false
local typeId = 0
local choosing = false
local waitingReply = 0 -- номер ожидания ответа сервера (0 = не ждём)

local function hide()
	panel.Visible = false
	choosing = false
	typing = false
	typeId += 1
	waitingReply = 0
end

local function clearOptions()
	for _, child in optionsFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function typeLine(text)
	typeId += 1
	local myId = typeId
	typing = true
	textLabel.Text = text
	local total = utf8.len(text) or #text
	textLabel.MaxVisibleGraphemes = 0
	task.spawn(function()
		local shown = 0
		while myId == typeId and shown < total do
			shown = math.min(total, shown + math.max(1, math.floor(CHARS_PER_SECOND * task.wait(1 / 30))))
			textLabel.MaxVisibleGraphemes = shown
		end
		if myId == typeId then
			textLabel.MaxVisibleGraphemes = -1
			typing = false
		end
	end)
end

local choose -- объявлена ниже

local function showOptions()
	choosing = true
	textLabel.Visible = false
	hint.Visible = false
	clearOptions()
	optionsFrame.Visible = true
	for index, option in options do
		UILib.actionButton(optionsFrame, {
			name = "Option" .. index,
			text = (#options > 1 and (index .. ".  ") or "") .. option.Text,
			color = "neutral",
			size = UDim2.new(1, 0, 0, 34),
			layoutOrder = index,
			zIndex = 3,
			onClick = function()
				choose(index)
			end,
		})
	end
end

local function showNext()
	if choosing or waitingReply ~= 0 then
		return
	end
	if typing then
		-- пропустить печать: сразу вся строка
		typeId += 1
		typing = false
		textLabel.MaxVisibleGraphemes = -1
		return
	end
	lineIndex += 1
	local line = lines[lineIndex]
	if line then
		textLabel.Visible = true
		optionsFrame.Visible = false
		hint.Visible = true
		typeLine(line)
	elseif #options > 0 then
		showOptions()
	else
		hide()
	end
end

function choose(index)
	if not choosing or not options[index] then
		return
	end
	choosing = false
	clearOptions()
	optionsFrame.Visible = false
	textLabel.Visible = true
	textLabel.Text = "…"
	textLabel.MaxVisibleGraphemes = -1
	hint.Visible = false
	waitingReply += 1
	local myWait = waitingReply
	SelectOption:FireServer(index)
	task.delay(REPLY_TIMEOUT, function()
		if waitingReply == myWait then
			hide()
		end
	end)
end

StartDialogue.OnClientEvent:Connect(function(_dialogID, step, npcName)
	if typeof(step) ~= "table" then
		hide() -- сервер закончил диалог
		return
	end
	waitingReply = 0
	choosing = false

	lines = {}
	if typeof(step.Lines) == "table" then
		for _, line in step.Lines do
			if typeof(line) == "string" and line ~= "" then
				table.insert(lines, line)
			end
		end
	elseif typeof(step.Text) == "string" and step.Text ~= "" then
		table.insert(lines, step.Text)
	end
	options = {}
	if typeof(step.Options) == "table" then
		for _, option in step.Options do
			if typeof(option) == "table" and typeof(option.Text) == "string" then
				table.insert(options, { Text = option.Text })
			end
		end
	end

	nameLabel.Text = typeof(npcName) == "string" and npcName or "NPC"
	panel.Visible = true
	clearOptions()
	optionsFrame.Visible = false
	lineIndex = 0
	typing = false
	showNext()
end)

advanceArea.Activated:Connect(showNext)
closeButton.face.Activated:Connect(hide)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not panel.Visible then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.E or key == Enum.KeyCode.Return then
		showNext()
	elseif choosing then
		local number = key.Value - Enum.KeyCode.One.Value + 1
		if number >= 1 and number <= 9 then
			choose(number)
		end
	end
end)
