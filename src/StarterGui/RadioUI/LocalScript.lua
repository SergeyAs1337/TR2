local player            = game.Players.LocalPlayer
local gui               = script.Parent
local rs                = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- RemoteEvents
local playTrackEvent    = rs:WaitForChild("PlayTrack")
local stopTrackEvent    = rs:WaitForChild("StopTrack")
local pickupEvent       = rs:WaitForChild("PickupRadio")
local openRadioMenu     = rs:WaitForChild("OpenRadioMenu")

-- Данные
local tracksFolder      = rs:WaitForChild("RadioTracks")
local TRACKS_PER_PAGE   = 8
local currentPage       = 1
local allTracks         = {}
local CUSTOM_PASS_ID    = 1253905433

-- UI объекты
local mainFrame   = gui.MainFrame
local trackList   = mainFrame.TrackList
local prev        = mainFrame.PrevPage
local next        = mainFrame.NextPage
local customBtn   = mainFrame.CustomButton
local pickupBtn   = mainFrame.PickupButton
local stopBtn     = mainFrame.StopButton
local closeBtn    = mainFrame.CloseButton

local customFrame = gui.CustomFrame
local customBox   = customFrame.CustomBox
local playCustom  = customFrame.PlayButton
local back        = customFrame.BackButton

-- Собираем список треков
for _, track in ipairs(tracksFolder:GetChildren()) do
	if track:IsA("Sound") then
		table.insert(allTracks, track)
	end
end
table.sort(allTracks, function(a, b) return a.Name < b.Name end)

-- Функция: обновить список треков
local function updateTrackList()
	trackList:ClearAllChildren()

	if not trackList:FindFirstChildOfClass("UIListLayout") then
		Instance.new("UIListLayout", trackList).SortOrder = Enum.SortOrder.LayoutOrder
	end

	local startIdx = (currentPage - 1) * TRACKS_PER_PAGE + 1
	local endIdx   = math.min(#allTracks, startIdx + TRACKS_PER_PAGE - 1)

	for i = startIdx, endIdx do
		local snd = allTracks[i]
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.Text = snd.Name
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = trackList

		btn.MouseButton1Click:Connect(function()
			playTrackEvent:FireServer(snd.SoundId)
		end)
	end
end

-- Событие: открыть GUI
openRadioMenu.OnClientEvent:Connect(function()
	gui.Enabled = true
	mainFrame.Visible = true
	customFrame.Visible = false
	currentPage = 1
	updateTrackList()
end)

-- Переход по страницам
prev.MouseButton1Click:Connect(function()
	if currentPage > 1 then
		currentPage -= 1
		updateTrackList()
	end
end)

next.MouseButton1Click:Connect(function()
	if currentPage < math.ceil(#allTracks / TRACKS_PER_PAGE) then
		currentPage += 1
		updateTrackList()
	end
end)

-- Переход в кастомный ввод
customBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	customFrame.Visible = true
end)

back.MouseButton1Click:Connect(function()
	customFrame.Visible = false
	mainFrame.Visible = true
end)

-- Воспроизведение кастомного трека с проверкой геймпасса
playCustom.MouseButton1Click:Connect(function()
	local id = tonumber(customBox.Text)
	if not id then return end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CUSTOM_PASS_ID)
	end)

	if success then
		if owns then
			playTrackEvent:FireServer(id)
		else
			MarketplaceService:PromptGamePassPurchase(player, CUSTOM_PASS_ID)
		end
	else
		warn("Не удалось проверить геймпасс:", owns)
	end
end)

-- Подобрать радио
pickupBtn.MouseButton1Click:Connect(function()
	pickupEvent:FireServer()
	mainFrame.Visible = false
end)

-- Остановить музыку
stopBtn.MouseButton1Click:Connect(function()
	stopTrackEvent:FireServer()
end)

-- Закрыть GUI
closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)
