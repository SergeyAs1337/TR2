-- StarterPlayer/StarterPlayerScripts/RadioMenu  (LocalScript)  v1 — меню радио
-- Заменяет StarterGui/RadioUI (удалить). Стиль админ-панели, строится кодом.
-- Открывается, когда игрок нажимает «Настроить радио» у своего радио (сервер шлёт OpenRadioMenu).
--   * «Сейчас играет» — из атрибута NowPlaying на радио (ставит RadioHandler v2);
--   * список треков из ReplicatedStorage.RadioTracks одной прокручиваемой колонкой;
--   * свой трек по ID: без геймпасса кнопка предлагает его купить (проверяет всё равно сервер);
--   * «Стоп» и «Подобрать радио».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local CUSTOM_PASS_ID = 1253905433 -- как в RadioHandler

local player = Players.LocalPlayer
local playTrackEvent = ReplicatedStorage:WaitForChild("PlayTrack")
local stopTrackEvent = ReplicatedStorage:WaitForChild("StopTrack")
local pickupEvent = ReplicatedStorage:WaitForChild("PickupRadio")
local openRadioMenu = ReplicatedStorage:WaitForChild("OpenRadioMenu")
local tracksFolder = ReplicatedStorage:WaitForChild("RadioTracks")

local win
win = UILib.window({
	name = "Radio",
	guiName = "RadioUI",
	title = "📻  Радио",
	size = Vector2.new(440, 520),
	player = player,
	onOpen = function()
		win.refresh()
	end,
})
local body = win.body

-- ===== Сейчас играет =====
local nowPanel = UILib.panel(body, { Name = "NowPlaying", Size = UDim2.new(1, 0, 0, 48) })
UILib.text(nowPanel, "СЕЙЧАС ИГРАЕТ", {
	Name = "Caption",
	Position = UDim2.new(0, 12, 0, 6),
	Size = UDim2.new(1, -24, 0, 14),
	TextSize = 11,
	TextColor3 = THEME.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local nowLabel = UILib.text(nowPanel, "Тишина", {
	Name = "Title",
	Position = UDim2.new(0, 12, 0, 20),
	Size = UDim2.new(1, -24, 0, 22),
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextWrapped = false,
})

-- ===== Список треков =====
local list = UILib.make("ScrollingFrame", {
	Name = "TrackList",
	Position = UDim2.new(0, 0, 0, 56),
	Size = UDim2.new(1, 0, 0, 220),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = THEME.row,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, body)
UILib.list(list, 4)

-- ===== Свой трек =====
UILib.text(body, "Свой трек по ID", {
	Name = "CustomCaption",
	Position = UDim2.new(0, 0, 0, 284),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 13,
	TextColor3 = THEME.muted,
	Font = THEME.fontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local customRow = UILib.make("Frame", {
	Name = "CustomRow",
	Position = UDim2.new(0, 0, 0, 306),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
}, body)
local idFrame = UILib.panel(customRow, { Name = "IdFrame", Size = UDim2.new(0.64, 0, 1, 0), BackgroundColor3 = THEME.row })
local customBox = UILib.make("TextBox", {
	Name = "CustomBox",
	Position = UDim2.new(0, 10, 0, 0),
	Size = UDim2.new(1, -20, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	PlaceholderText = "Например, 1837849285",
	PlaceholderColor3 = THEME.muted,
	ClearTextOnFocus = false,
	TextColor3 = THEME.text,
	TextSize = 15,
	Font = THEME.fontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
}, idFrame)
local passLabel = UILib.text(body, "", {
	Name = "PassLabel",
	Position = UDim2.new(0, 0, 0, 350),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 12,
	TextColor3 = THEME.muted,
	Font = THEME.fontBody,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local ownsPass = nil -- nil = ещё не знаем
local function checkPass()
	if ownsPass then
		return true
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, CUSTOM_PASS_ID)
	ownsPass = ok and owns == true
	passLabel.Text = ownsPass and "Геймпасс есть: можно включать любые треки" or "Свои треки доступны с геймпассом"
	return ownsPass
end

UILib.actionButton(customRow, {
	name = "PlayCustom",
	text = "Играть",
	color = "accent",
	anchor = Vector2.new(1, 0),
	position = UDim2.new(1, 0, 0, 0),
	size = UDim2.new(0.34, 0, 1, 0),
	onClick = function()
		local digits = string.match(string.gsub(customBox.Text, "%s", ""), "^%d+$")
		if not digits then
			UILib.toast("Введи ID трека цифрами", "bad")
			UILib.shake(idFrame)
			return
		end
		if not checkPass() then
			MarketplaceService:PromptGamePassPurchase(player, CUSTOM_PASS_ID)
			return
		end
		playTrackEvent:FireServer(digits)
	end,
})

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, passId, purchased)
	if who == player and passId == CUSTOM_PASS_ID and purchased then
		ownsPass = true
		passLabel.Text = "Геймпасс есть: можно включать любые треки"
	end
end)

-- ===== Стоп / подобрать =====
local bottom = UILib.make("Frame", {
	Name = "BottomRow",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
}, body)
UILib.actionButton(bottom, {
	name = "StopButton",
	text = "■  Стоп",
	color = "bad",
	size = UDim2.new(0.49, 0, 1, 0),
	onClick = function()
		stopTrackEvent:FireServer()
	end,
})
UILib.actionButton(bottom, {
	name = "PickupButton",
	text = "Подобрать радио",
	color = "neutral",
	anchor = Vector2.new(1, 0),
	position = UDim2.new(1, 0, 0, 0),
	size = UDim2.new(0.49, 0, 1, 0),
	onClick = function()
		pickupEvent:FireServer()
		win.close()
	end,
})

-- ===== Обновление =====
local rows = {} -- rows[имя трека] = кнопка
local function myRadio()
	return Workspace:FindFirstChild(player.Name .. "_Radio")
end

local function highlight()
	local radio = myRadio()
	local playing = radio and radio:GetAttribute("NowPlaying") or ""
	nowLabel.Text = (typeof(playing) == "string" and playing ~= "") and playing or "Тишина"
	for name, row in rows do
		row.setColor(name == playing and "accent" or "neutral")
	end
end

local function buildList()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rows = {}
	local tracks = {}
	for _, track in tracksFolder:GetChildren() do
		if track:IsA("Sound") then
			table.insert(tracks, track)
		end
	end
	table.sort(tracks, function(a, b)
		return a.Name < b.Name
	end)
	for index, track in tracks do
		rows[track.Name] = UILib.actionButton(list, {
			name = "Track" .. index,
			text = "▶  " .. track.Name,
			color = "neutral",
			size = UDim2.new(1, -6, 0, 34),
			layoutOrder = index,
			onClick = function()
				playTrackEvent:FireServer(track.Name)
			end,
		})
		rows[track.Name].label.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local watched = nil
function win.refresh()
	buildList()
	local radio = myRadio()
	if radio and radio ~= watched then
		watched = radio
		radio:GetAttributeChangedSignal("NowPlaying"):Connect(highlight)
	end
	highlight()
	task.spawn(checkPass)
end

-- ===== События =====
openRadioMenu.OnClientEvent:Connect(function()
	win.open()
end)

playTrackEvent.OnClientEvent:Connect(function(ok, message)
	if ok == false and typeof(message) == "string" then
		UILib.toast(message, "bad")
	end
	highlight()
end)
