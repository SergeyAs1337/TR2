-- ServerScriptService/DanceServer  (Script)  v2 — эмоции и танцы
-- RemoteEvent-ы прежние: DanceRequest(имяТанца), DanceEnded().
-- Что исправлено:
--  * после смерти во время танца нельзя было танцевать снова (запись о танце не очищалась);
--  * новый танец во время старого теперь сменяет его (раньше запрос молча игнорировался);
--  * останавливается только анимация танца, а не все анимации персонажа;
--  * скорость после танца возвращается, только если её никто не менял (апгрейд «Скорость»
--    во время танца больше не сбрасывается);
--  * проверка типа имени, лимит частоты, очистка при выходе игрока;
--  * атрибут игрока Dancing = имя танца (интерфейс знает, что игрок танцует).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local dancesFolder = ReplicatedStorage:WaitForChild("Dances")
local musicFolder = ReplicatedStorage:WaitForChild("DanceMusic")
local DanceRequest = ReplicatedStorage:WaitForChild("DanceRequest")
local StopDance = ReplicatedStorage:WaitForChild("DanceEnded")

local MIN_INTERVAL = 0.4 -- секунд между запросами

local playing = {} -- playing[player] = { track, sound, blocked, oldSpeed, oldJump, humanoid }
local lastRequest = {}

local function stopForPlayer(player)
	local data = playing[player]
	if not data then
		return
	end
	playing[player] = nil
	player:SetAttribute("Dancing", nil)

	if data.track then
		pcall(data.track.Stop, data.track)
	end
	if data.sound then
		data.sound:Destroy()
	end
	local humanoid = data.humanoid
	if data.blocked and humanoid and humanoid.Parent then
		-- возвращаем, только если за время танца скорость никто не поменял
		if humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = data.oldSpeed
		end
		if humanoid.JumpPower == 0.001 then
			humanoid.JumpPower = data.oldJump
		end
	end
end

local function rateLimited(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < MIN_INTERVAL then
		return true
	end
	lastRequest[player] = now
	return false
end

DanceRequest.OnServerEvent:Connect(function(player, danceName)
	if typeof(danceName) ~= "string" or #danceName > 64 or rateLimited(player) then
		return
	end
	local animObj = dancesFolder:FindFirstChild(danceName)
	if not animObj or not animObj:IsA("Animation") then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	stopForPlayer(player) -- сменить текущий танец

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animation = Instance.new("Animation")
	animation.AnimationId = animObj.AnimationId
	local ok, track = pcall(function()
		return animator and animator:LoadAnimation(animation) or humanoid:LoadAnimation(animation)
	end)
	if not ok or not track then
		return
	end

	local looped = animObj:FindFirstChild("Looped")
	local blockValue = animObj:FindFirstChild("BlockMovement")
	track.Looped = looped and looped.Value == true or false
	local blockMove = blockValue and blockValue.Value == true or false
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	local soundClone = nil
	local soundTmpl = musicFolder:FindFirstChild(danceName)
	local root = character:FindFirstChild("HumanoidRootPart")
	if soundTmpl and soundTmpl:IsA("Sound") and root then
		soundClone = soundTmpl:Clone()
		soundClone.Looped = track.Looped
		soundClone.Parent = root
		soundClone:Play()
	end

	local data = {
		track = track,
		sound = soundClone,
		blocked = blockMove,
		oldSpeed = humanoid.WalkSpeed,
		oldJump = humanoid.JumpPower,
		humanoid = humanoid,
	}
	playing[player] = data
	player:SetAttribute("Dancing", danceName)

	if blockMove then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0.001
	end

	track.Stopped:Connect(function()
		if playing[player] == data then
			stopForPlayer(player)
		end
	end)
	humanoid.Died:Connect(function()
		if playing[player] == data then
			stopForPlayer(player)
		end
	end)
end)

StopDance.OnServerEvent:Connect(function(player)
	stopForPlayer(player)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		stopForPlayer(player)
	end)
end)
for _, player in Players:GetPlayers() do
	player.CharacterRemoving:Connect(function()
		stopForPlayer(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	stopForPlayer(player)
	lastRequest[player] = nil
end)
