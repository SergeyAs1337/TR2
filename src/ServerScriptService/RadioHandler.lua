-- ServerScriptService/RadioHandler  (Script)  v2
-- Радио: поставить из инструмента, выбрать трек, свой трек по ID (геймпасс), остановить, подобрать.
-- Что исправлено:
--  * свой трек: геймпасс проверяется НА СЕРВЕРЕ (раньше только в интерфейсе: любой мог
--    включить любой звук без геймпасса). Без геймпасса сервер отвечает отказом;
--  * одно радио на игрока (раньше можно было наставить несколько с одним именем);
--  * лимит частоты смены трека, проверка ID (только цифры), без отладочного спама в консоль;
--  * атрибут NowPlaying на модели радио: интерфейс показывает, что играет;
--  * дубль-обработчик PlayTrack в Radio/RadioModel/Base/Script больше не нужен (удалить).
-- RemoteEvent-ы прежние: PlaceRadio, PickupRadio, PlayTrack, StopTrack, OpenRadioMenu.
-- Ответ клиенту: PlayTrack:FireClient(player, успех, сообщение).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local placeRadio = ReplicatedStorage:WaitForChild("PlaceRadio")
local pickupRadio = ReplicatedStorage:WaitForChild("PickupRadio")
local playTrackEvent = ReplicatedStorage:WaitForChild("PlayTrack")
local stopTrackEvent = ReplicatedStorage:WaitForChild("StopTrack")
local openRadioMenu = ReplicatedStorage:WaitForChild("OpenRadioMenu")

local tracksFolder = ReplicatedStorage:WaitForChild("RadioTracks")
local RADIO_TOOL_TPL = ReplicatedStorage:WaitForChild("Radio")

-- ===== Настройки =====
local CUSTOM_PASS_ID = 1253905433 -- геймпасс на свои треки (как в старом RadioUI)
local MAX_PLACE_DISTANCE = 20
local TRACK_COOLDOWN = 1 -- секунд между сменами трека
local PASS_RECHECK = 60 -- через сколько секунд снова спрашивать Roblox, если геймпасса не было
local SOUND_PROPS = {
	Looped = true,
	Volume = 0.7,
	RollOffMinDistance = 7,
	RollOffMaxDistance = 70,
	RollOffMode = Enum.RollOffMode.Inverse,
}

local radios = {} -- radios[player] = модель радио в мире
local lastTrackAt = {}
local passCache = {} -- passCache[userId] = { owns, checkedAt }

local function getRadio(player)
	local radio = radios[player]
	if radio and radio.Parent and radio.PrimaryPart then
		return radio
	end
	radios[player] = nil
	return nil
end

local function ownsCustomPass(player)
	local cached = passCache[player.UserId]
	if cached and (cached.owns or os.clock() - cached.checkedAt < PASS_RECHECK) then
		return cached.owns
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, CUSTOM_PASS_ID)
	if not ok then
		warn("[Radio] Не удалось проверить геймпасс: " .. tostring(owns))
		return false
	end
	passCache[player.UserId] = { owns = owns == true, checkedAt = os.clock() }
	return owns == true
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == CUSTOM_PASS_ID then
		passCache[player.UserId] = { owns = true, checkedAt = os.clock() }
	end
end)

local function finiteVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function stopSound(radio)
	local snd = radio.PrimaryPart:FindFirstChild("RadioSound")
	if snd then
		snd:Stop()
		snd:Destroy()
	end
	radio:SetAttribute("NowPlaying", "")
end

-- ===== Установка =====
placeRadio.OnServerEvent:Connect(function(player, position)
	if not finiteVector(position) then
		return
	end
	if getRadio(player) then
		return -- одно радио на игрока: сначала подбери старое
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or (position - rootPart.Position).Magnitude > MAX_PLACE_DISTANCE then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (backpack and backpack:FindFirstChild("Radio")) or character:FindFirstChild("Radio")
	if not tool or not tool:IsA("Tool") then
		return
	end
	local radioModel = tool:FindFirstChild("RadioModel")
	if not radioModel then
		return
	end
	if not radioModel.PrimaryPart then
		local base = radioModel:FindFirstChildWhichIsA("BasePart")
		if not base then
			return
		end
		radioModel.PrimaryPart = base
	end

	local clone = radioModel:Clone()
	clone.Name = player.Name .. "_Radio"
	clone:SetAttribute("Owner", player.UserId)
	clone:SetAttribute("NowPlaying", "")
	-- старый дубль-скрипт внутри модели больше не нужен
	for _, child in clone:GetDescendants() do
		if child.ClassName == "Script" then
			child:Destroy()
		end
	end

	-- Ставим на землю
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
	if result then
		position = result.Position
	end

	local flat = Vector3.new(rootPart.Position.X - position.X, 0, rootPart.Position.Z - position.Z)
	local facing = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local targetPos = position + Vector3.new(0, clone.PrimaryPart.Size.Y / 2, 0)
	clone:PivotTo(CFrame.lookAt(targetPos, targetPos + facing))
	clone.Parent = Workspace
	radios[player] = clone

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Настроить радио"
	prompt.ObjectText = "Радио"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = clone.PrimaryPart
	prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer == player then
			openRadioMenu:FireClient(trigPlayer)
		end
	end)

	tool:Destroy()
end)

-- ===== Подбор =====
pickupRadio.OnServerEvent:Connect(function(player)
	local radio = getRadio(player)
	if not radio then
		return
	end
	radios[player] = nil
	radio:Destroy()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		RADIO_TOOL_TPL:Clone().Parent = backpack
	end
	pickupRadio:FireClient(player) -- инструмент снова можно ставить
end)

-- ===== Треки =====
local function findPreset(value)
	local obj = tracksFolder:FindFirstChild(value)
	if obj and obj:IsA("Sound") then
		return obj
	end
	for _, s in tracksFolder:GetChildren() do
		if s:IsA("Sound") and (s.SoundId == value or s.SoundId == "rbxassetid://" .. value) then
			return s
		end
	end
	return nil
end

playTrackEvent.OnServerEvent:Connect(function(player, rawId)
	if typeof(rawId) ~= "string" and typeof(rawId) ~= "number" then
		return
	end
	local value = tostring(rawId)
	if #value == 0 or #value > 64 then
		return
	end

	local now = os.clock()
	if lastTrackAt[player] and now - lastTrackAt[player] < TRACK_COOLDOWN then
		return
	end
	lastTrackAt[player] = now

	local radio = getRadio(player)
	if not radio then
		playTrackEvent:FireClient(player, false, "Сначала поставь радио")
		return
	end

	local preset = findPreset(value)
	local sound, title
	if preset then
		sound = preset:Clone()
		title = preset.Name
	else
		-- свой трек: только ID из цифр и только с геймпассом
		local digits = string.match(value, "^rbxassetid://(%d+)$") or string.match(value, "^(%d+)$")
		if not digits or #digits > 20 then
			playTrackEvent:FireClient(player, false, "Неверный ID трека")
			return
		end
		if not ownsCustomPass(player) then
			playTrackEvent:FireClient(player, false, "Свои треки — только с геймпассом")
			return
		end
		if getRadio(player) ~= radio then
			return -- радио убрали, пока проверяли геймпасс
		end
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. digits
		title = "Свой трек #" .. digits
	end

	stopSound(radio)
	sound.Name = "RadioSound"
	for key, propValue in SOUND_PROPS do
		sound[key] = propValue
	end
	sound.Parent = radio.PrimaryPart
	sound:Play()
	radio:SetAttribute("NowPlaying", title)
	playTrackEvent:FireClient(player, true, title)
end)

stopTrackEvent.OnServerEvent:Connect(function(player)
	local radio = getRadio(player)
	if radio then
		stopSound(radio)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local radio = radios[player]
	if radio then
		radio:Destroy()
	end
	radios[player] = nil
	lastTrackAt[player] = nil
	passCache[player.UserId] = nil
end)
