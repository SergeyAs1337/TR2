local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local FireSound = Handle:FindFirstChild("FireSound")
local Remote = Tool:WaitForChild("FireRequest")

local BadgeService = game:GetService("BadgeService")

local BADGE_ID = 4296499034843943
local DAMAGE = 9999
local BEAM_LENGTH = 500
local FIRE_CHANCE = 1 / 365 -- 1 к 1 для теста (выпадает всегда)

local function tryAwardBadge(player)
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, BADGE_ID)
	end)

	if not success then
		warn("[Badge] Ошибка проверки ачивки у "..player.Name..":", hasBadge)
		return
	end

	if hasBadge then
		print("[Badge] У игрока "..player.Name.." уже есть ачивка.")
		return
	end

	local awarded, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, BADGE_ID)
	end)

	if awarded then
		print("[Badge] Ачивка выдана игроку: "..player.Name)
	else
		warn("[Badge] Ошибка выдачи ачивки игроку "..player.Name..":", err)
	end
end

local function fireLaser(fromPos, toPos, ignoreList)
	local direction = (toPos - fromPos).Unit * BEAM_LENGTH
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = ignoreList

	local result = workspace:Raycast(fromPos, direction, rayParams)
	local hitPosition = toPos
	if result then
		hitPosition = result.Position
	end

	-- Создаём визуальный луч
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.BrickColor = BrickColor.new("Really red")
	beam.Transparency = 0
	beam.Size = Vector3.new(0.5, 0.5, (hitPosition - fromPos).Magnitude)
	beam.CFrame = CFrame.new(fromPos, hitPosition) * CFrame.new(0, 0, -beam.Size.Z / 2)
	beam.Parent = workspace

	task.spawn(function()
		for i = 1, 10 do
			beam.Transparency = i / 10
			task.wait(0.05)
		end
		beam:Destroy()
	end)

	-- Урон по Хуманоиду
	if result and result.Instance then
		local model = result.Instance:FindFirstAncestorWhichIsA("Model")
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(DAMAGE)
			end
		end
	end
end

Remote.OnServerEvent:Connect(function(player, mouseHit)
	local character = player.Character
	if not character then return end

	-- Проверяем шанс выстрела
	if math.random() > FIRE_CHANCE then
		print("[Server] Палка не сработала.")
		return
	end

	-- Воспроизводим звук, если есть
	if FireSound then
		FireSound:Play()
	end

	local ignoreList = {character, Tool}
	local fromPosition = Handle.Position + Vector3.new(0, Handle.Size.Y / 2, 0)

	fireLaser(fromPosition, mouseHit, ignoreList)

	tryAwardBadge(player)

	print(player.Name .. " выстрелил палкой по курсору!")
end)
