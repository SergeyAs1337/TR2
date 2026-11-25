-- ReplicatedStorage/Stick/Script  v2: выстрел только из своей палки в руках, кулдаун 0.5 с,
-- проверка точки прицела. Шанс и урон прежние.
local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local FireSound = Handle:FindFirstChild("FireSound")
local Remote = Tool:WaitForChild("FireRequest")

local BadgeService = game:GetService("BadgeService")

local BADGE_ID = 4296499034843943
local DAMAGE = 9999
local BEAM_LENGTH = 500
local FIRE_CHANCE = 1 / 365 -- шанс, что палка «выстрелит»

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
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
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

local COOLDOWN = 0.5 -- секунд между попытками одного игрока (раньше без ограничений)
local MAX_AIM_DISTANCE = 1000
local lastShot = {}

local function validTarget(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

Remote.OnServerEvent:Connect(function(player, mouseHit)
	local character = player.Character
	if not character then return end
	-- стрелять можно только палкой, которую ЭТОТ игрок держит в руках
	-- (раньше можно было «выстрелить» из чужой палки)
	if Tool.Parent ~= character then return end
	if not validTarget(mouseHit) then return end
	local fromCheck = Handle.Position
	if (mouseHit - fromCheck).Magnitude < 0.5 or (mouseHit - fromCheck).Magnitude > MAX_AIM_DISTANCE then return end

	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < COOLDOWN then return end
	lastShot[player] = now

	-- Проверяем шанс выстрела
	if math.random() > FIRE_CHANCE then
		return
	end

	-- Воспроизводим звук, если есть
	if FireSound then
		FireSound:Play()
	end

	local ignoreList = {character, Tool}
	local fromPosition = Handle.Position + Vector3.new(0, Handle.Size.Y / 2, 0)

	fireLaser(fromPosition, mouseHit, ignoreList)

	task.spawn(tryAwardBadge, player)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastShot[player] = nil
end)
