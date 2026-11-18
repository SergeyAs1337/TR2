--====================================================================
-- RadioHandler.lua   (ServerScriptService)
--====================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

-- RemoteEvents ------------------------------------------------------
local placeRadio     = ReplicatedStorage:WaitForChild("PlaceRadio")
local pickupRadio    = ReplicatedStorage:WaitForChild("PickupRadio")
local playTrackEvent = ReplicatedStorage:WaitForChild("PlayTrack")
local stopTrackEvent = ReplicatedStorage:WaitForChild("StopTrack")
local openRadioMenu  = ReplicatedStorage:WaitForChild("OpenRadioMenu")

-- Данные ------------------------------------------------------------
local tracksFolder   = ReplicatedStorage:WaitForChild("RadioTracks")
local RADIO_TOOL_TPL = ReplicatedStorage:WaitForChild("Radio")
local MAX_DISTANCE = 20

local function dbg(...) print("[SERVER]", ...) end

----------------------------------------------------------------------
-- УСТАНОВКА РАДИО
----------------------------------------------------------------------
placeRadio.OnServerEvent:Connect(function(player, position)
	if typeof(position) ~= "Vector3" then return end

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local distance = (position - rootPart.Position).Magnitude
	if distance > MAX_DISTANCE then return end

	local tool = player.Backpack:FindFirstChild("Radio")
		or character:FindFirstChild("Radio")
	if not tool then return end

	local radioModel = tool:FindFirstChild("RadioModel")
	if not radioModel then return end

	if not radioModel.PrimaryPart then
		local base = radioModel:FindFirstChildWhichIsA("BasePart")
		if not base then return end
		radioModel.PrimaryPart = base
	end

	-- Клонируем модель
	local clone = radioModel:Clone()
	clone.Name = player.Name .. "_Radio"
	clone:SetAttribute("Owner", player.UserId)

	-- Устанавливаем на землю через Raycast
	local rayOrigin = position + Vector3.new(0, 5, 0)
	local rayDirection = Vector3.new(0, -20, 0)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Blacklist

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result then
		position = result.Position
	end

	-- Поворот к игроку
	local faceDirection = (rootPart.Position - position).Unit
	local heightOffset = clone.PrimaryPart.Size.Y / 2
	local targetPos = position + Vector3.new(0, heightOffset, 0)
	local lookCFrame = CFrame.new(targetPos, targetPos + Vector3.new(faceDirection.X, 0, faceDirection.Z))

	clone:SetPrimaryPartCFrame(lookCFrame)
	clone.Parent = workspace

	-- ProximityPrompt
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

	-- Удаляем Tool
	tool:Destroy()
end)

----------------------------------------------------------------------
-- ПОДБОР РАДИО
----------------------------------------------------------------------
pickupRadio.OnServerEvent:Connect(function(player)
	local radio = workspace:FindFirstChild(player.Name .. "_Radio")
	if not radio then return end

	local tool = RADIO_TOOL_TPL:Clone()
	tool.Parent = player.Backpack
	radio:Destroy()
end)

----------------------------------------------------------------------
-- ВСПОМОГАТЕЛЬНАЯ: поиск пресет-трека
----------------------------------------------------------------------
local function findPreset(idOrName : string)
	local obj = tracksFolder:FindFirstChild(idOrName)
	if obj and obj:IsA("Sound") then return obj end
	for _, s in ipairs(tracksFolder:GetChildren()) do
		if s:IsA("Sound") and s.SoundId == idOrName then
			return s
		end
	end
	return nil
end

----------------------------------------------------------------------
-- ВОСПРОИЗВЕДЕНИЕ ТРЕКА
----------------------------------------------------------------------
playTrackEvent.OnServerEvent:Connect(function(player, rawId)
	local radio = workspace:FindFirstChild(player.Name .. "_Radio")
	if not (radio and radio.PrimaryPart) then return end

	local old = radio.PrimaryPart:FindFirstChildOfClass("Sound")
	if old then old:Destroy() end

	local rawStr = tostring(rawId)
	local preset = findPreset(rawStr) or findPreset("rbxassetid://" .. rawStr)
	if preset then
		local snd = preset:Clone()
		snd.Name = "RadioSound"
		snd.Looped = true
		snd.Volume = 0.7
		snd.EmitterSize = 7
		snd.MaxDistance = 70
		snd.RollOffMode = Enum.RollOffMode.Inverse
		snd.Parent = radio.PrimaryPart
		snd:Play()
		dbg("▶️ Пресет-трек:", preset.Name)
		return
	end

	local id = rawStr
	if not id:match("^rbxassetid://") then
		id = "rbxassetid://" .. id
	end

	local snd = Instance.new("Sound")
	snd.Name = "RadioSound"
	snd.SoundId = id
	snd.Looped = true
	snd.Volume = 0.7
	snd.EmitterSize = 7
	snd.MaxDistance = 70
	snd.RollOffMode = Enum.RollOffMode.Inverse
	snd.Parent = radio.PrimaryPart
	snd:Play()
	dbg("▶️ Кастомный трек:", id)
end)

----------------------------------------------------------------------
-- ОСТАНОВКА ТРЕКА
----------------------------------------------------------------------
stopTrackEvent.OnServerEvent:Connect(function(player)
	local radio = workspace:FindFirstChild(player.Name .. "_Radio")
	if not (radio and radio.PrimaryPart) then return end
	local snd = radio.PrimaryPart:FindFirstChild("RadioSound")
	if snd then snd:Stop(); snd:Destroy() end
end)

----------------------------------------------------------------------
-- УДАЛЕНИЕ РАДИО ПРИ ВЫХОДЕ
----------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(plr)
	local radio = workspace:FindFirstChild(plr.Name .. "_Radio")
	if radio then radio:Destroy() end
end)