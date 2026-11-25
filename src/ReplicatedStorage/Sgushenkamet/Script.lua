-- ReplicatedStorage/Sgushenkamet/Script  v2: проверка точки и что оружие в руках у стреляющего,
-- кулдаун ставится до создания ракеты, один взрыв на ракету.
--[[  ----- Настройка -----  ]]
local RS              = game:GetService("ReplicatedStorage")
local Debris          = game:GetService("Debris")

local rocketTemplate  = RS:WaitForChild("CanRocket")           -- Part (+ Mesh) ориентирован вдоль оси +Z
local fireSoundAsset  = RS:WaitForChild("RocketFireSound")     -- Sound
local boomSoundAsset  = RS:WaitForChild("RocketExplosionSound")-- Sound
local cooldownTime    = 2                                      -- секунд

--[[  ----- Переменные -----  ]]
local tool       = script.Parent
local fireEvent  = tool:WaitForChild("FireBazooka")            -- RemoteEvent
local cooldowns  = {}                                          -- { player = true }

--[[  ----- Логика выстрела -----  ]]
local function validTarget(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

fireEvent.OnServerEvent:Connect(function(player, targetPosition)
	-- Анти-спам
	if cooldowns[player] then return end

	-- Стрелять можно только из своего сгущёнкомёта в руках и в настоящую точку.
	-- Раньше неверная точка роняла скрипт уже ПОСЛЕ списания банки и кулдаун залипал навсегда.
	local character = player.Character
	if not (character and character:FindFirstChild("Head")) then return end
	if tool.Parent ~= character then return end
	if not validTarget(targetPosition) then return end
	local offset = targetPosition - character.Head.Position
	if offset.Magnitude < 1 then return end

	-- Проверяем, есть ли сгущёнка
	local backpack  = player:FindFirstChild("Backpack")
	local sgushenka = (backpack and backpack:FindFirstChild("Sgushenka")) or character:FindFirstChild("Sgushenka")
	if not sgushenka then
		return
	end
	sgushenka:Destroy()               -- расходуем банку
	cooldowns[player] = true          -- ставим кулдаун
	task.delay(cooldownTime, function()
		cooldowns[player] = nil
	end)

	-- Направление и позиция старта
	local direction = offset.Unit
	local spawnPos  = character.Head.Position + direction * 5  -- на 5 юнитов впереди головы

	-- Создаём ракету
	local rocket    = rocketTemplate:Clone()
	rocket.CFrame   = CFrame.new(spawnPos, targetPosition)     -- смотрит на цель
	rocket.Anchored = false
	rocket.CanCollide = true
	rocket.Parent   = workspace

	-- Звук выстрела (внутри ракеты)
	do
		local fireSnd = fireSoundAsset:Clone()
		fireSnd.Parent = rocket
		fireSnd:Play()
		Debris:AddItem(fireSnd, 5)
	end

	-- Движение ракеты
	local bv        = Instance.new("BodyVelocity")
	bv.Velocity     = direction * 100                          -- скорость
	bv.MaxForce     = Vector3.new(1e6, 1e6, 1e6)
	bv.Parent       = rocket

	-- Обработчик столкновения
	local exploded = false
	rocket.Touched:Connect(function(hit)
		if exploded then return end                             -- один взрыв на ракету
		if hit:IsDescendantOf(character) then return end        -- не взрываем владельца
		if not rocket.Parent then return end                   -- уже уничтожена?
		exploded = true

		-- 1) Звук взрыва из невидимого Part'а
		local soundPart       = Instance.new("Part")
		soundPart.Size        = Vector3.new(1,1,1)
		soundPart.Transparency= 1
		soundPart.Anchored    = true
		soundPart.CanCollide  = false
		soundPart.CFrame      = rocket.CFrame
		soundPart.Parent      = workspace

		local boomSnd         = boomSoundAsset:Clone()
		boomSnd.Parent        = soundPart
		boomSnd:Play()

		-- 2) Взрыв-объект Roblox
		local explosion       = Instance.new("Explosion")
		explosion.Position    = rocket.Position
		explosion.BlastRadius = 25
		explosion.BlastPressure = 5000
		explosion.Parent      = workspace

		-- 3) Очистка
		rocket:Destroy()
		Debris:AddItem(soundPart, 5)
		Debris:AddItem(boomSnd, 5)
	end)

	-- Безопасное авто-удаление ракеты (если ни с кем не столкнулась)
	Debris:AddItem(rocket, 5)

end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
