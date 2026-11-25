-- ServerScriptService/BoxJob  (Script)  v1 — работа грузчиком: коробки с почты в фуру
--
-- Как это работает:
--  * на почте игрок ЗАЖИМАЕТ кнопку (ProximityPrompt) и берёт коробку. Коробка физическая
--    и висит на верёвке: первая привязана к игроку, следующие — цепочкой к предыдущей;
--  * мир влияет на коробки: фура отбрасывает их и тащит игрока за собой (это делает
--    клиент в BoxJobHud, потому что физикой коробок управляет игрок);
--  * каждая коробка замедляет на SLOW_PER_BOX. Если скорость уже меньше MIN_PICKUP_SPEED,
--    взять ещё нельзя. Быстрее (апгрейд «Скорость») — значит, больше коробок за раз;
--  * коробки нужно донести до блока-триггера в фуре: игрок заходит в него — сдаются все
--    коробки, а коробка, закинутая в триггер, сдаётся сама;
--  * награда за коробку: BOX_REWARD × множитель монет (апгрейд) × множитель серии;
--  * серия = сколько коробок сдано подряд без смерти. Множитель серии растёт до x10.
--    В отличие от апгрейда, серия теряется при смерти;
--  * при смерти коробки взрываются и исчезают.
--
-- Настройка в Studio (один раз):
--  1. На почте поставь Part (можно невидимый) и назови его BoxPickup — или повесь на любую
--     деталь тег BoxPickup. Кнопка «Взять коробку» появится на ней сама.
--  2. В фуре поставь Part-триггер (Anchored, CanCollide = false, Transparency = 1) с именем
--     BoxDelivery — или с тегом BoxDelivery. Фура может ездить: триггер проверяется по
--     его текущему положению.
--
-- Атрибуты игрока для интерфейса: BoxesCarried, BoxesCanTake, BoxStreak, BoxStreakMult,
-- BoxRewardEach. Сообщения игроку — через ServerScriptService/Notify.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

-- ===== Настройки =====
local BOX_REWARD = 10 -- монет за коробку до множителей
local SLOW_PER_BOX = 1.5 -- насколько каждая коробка замедляет
local MIN_PICKUP_SPEED = 8 -- если скорость ниже, взять ещё нельзя
local MIN_WALK_SPEED = 4 -- ниже этого коробки не замедляют (чтобы не встать совсем)
local MAX_BOXES = 25 -- жёсткий предел на игрока (нагрузка на физику)
local STREAK_STEP = 5 -- каждые 5 коробок подряд...
local STREAK_BONUS = 0.5 -- ...+0.5 к множителю серии
local MAX_STREAK_MULT = 10 -- до x10
local PICKUP_HOLD = 0.6 -- сколько секунд зажимать кнопку
local PICKUP_COOLDOWN = 0.4
local ROPE_LENGTH = 4.5
local BOX_SIZE = Vector3.new(2, 2, 2)
local BOX_DENSITY = 0.6 -- лёгкая: игрок тянет без усилия, но фура её отбрасывает
local MAX_TRAVEL_SPEED = 70 -- studs/с: быстрее от почты до фуры донести нельзя (защита от телепорта)
local CHECK_INTERVAL = 0.2
local TRIGGER_MARGIN = 1.5 -- запас вокруг триггера, studs
local EXPLOSION_RADIUS = 6
local EXPLOSION_PRESSURE = 60000 -- толкает, но не убивает (DestroyJointRadiusPercent = 0)

local PICKUP_TAG = "BoxPickup"
local DELIVERY_TAG = "BoxDelivery"
local BOX_GROUP = "TR2Boxes"
local CHARACTER_GROUP = "TR2Characters"

local okNotify, Notify = pcall(function()
	return require(ServerScriptService:WaitForChild("Notify", 10))
end)
local function notify(player, text, color)
	if okNotify and Notify then
		Notify.send(player, text, color)
	end
end

-- Коробки не толкают своего же носильщика (иначе дёргается персонаж), но сталкиваются с миром
pcall(function()
	PhysicsService:RegisterCollisionGroup(BOX_GROUP)
	PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(BOX_GROUP, CHARACTER_GROUP, false)
end)

local boxFolder = Workspace:FindFirstChild("CarriedBoxes")
if not boxFolder then
	boxFolder = Instance.new("Folder")
	boxFolder.Name = "CarriedBoxes"
	boxFolder.Parent = Workspace
end

-- carriers[player] = { boxes = { box, ... }, info = { [box] = { at, from } }, streak, baseSpeed, lastPickup }
local carriers = {}

-- ===== Расчёты =====
local function streakMultiplier(streak)
	return math.min(MAX_STREAK_MULT, 1 + math.floor(streak / STREAK_STEP) * STREAK_BONUS)
end

local function coinMultiplier(player)
	local value = player:GetAttribute("CoinMultiplier")
	if typeof(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(math.floor(value), 1, 10)
end

local function rewardFor(player, streak)
	return math.floor(BOX_REWARD * coinMultiplier(player) * streakMultiplier(streak))
end

local function getData(player)
	local data = carriers[player]
	if not data then
		data = { boxes = {}, info = {}, streak = 0, baseSpeed = nil, lastPickup = -math.huge }
		carriers[player] = data
	end
	return data
end

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character
end

local function baseSpeed(player, data)
	local humanoid = humanoidOf(player)
	local fromUpgrade = humanoid and humanoid:GetAttribute("BaseWalkSpeed")
	if typeof(fromUpgrade) == "number" then
		return fromUpgrade
	end
	return data.baseSpeed or (humanoid and humanoid.WalkSpeed) or 16
end

local function speedWith(player, data, count)
	return math.max(MIN_WALK_SPEED, baseSpeed(player, data) - count * SLOW_PER_BOX)
end

local function canTakeMore(player, data)
	local count = #data.boxes
	if count >= MAX_BOXES then
		return 0
	end
	-- сколько ещё можно взять, пока текущая скорость не ниже порога
	local more = 0
	while count + more < MAX_BOXES and speedWith(player, data, count + more) >= MIN_PICKUP_SPEED do
		more += 1
	end
	return more
end

local function publish(player)
	local data = getData(player)
	player:SetAttribute("BoxesCarried", #data.boxes)
	player:SetAttribute("BoxesCanTake", canTakeMore(player, data))
	player:SetAttribute("BoxStreak", data.streak)
	player:SetAttribute("BoxStreakMult", streakMultiplier(data.streak))
	player:SetAttribute("BoxRewardEach", rewardFor(player, data.streak))
end

local function applySpeed(player)
	local data = carriers[player]
	local humanoid = humanoidOf(player)
	if not data or not humanoid or humanoid.Health <= 0 then
		return
	end
	if humanoid.WalkSpeed == 0 and player:GetAttribute("Dancing") then
		return -- танец с блокировкой движения: скорость вернёт DanceServer
	end
	if not data.baseSpeed and humanoid:GetAttribute("BaseWalkSpeed") == nil then
		data.baseSpeed = humanoid.WalkSpeed -- без UpgradeHandler: запоминаем скорость до коробок
	end
	humanoid.WalkSpeed = #data.boxes > 0 and speedWith(player, data, #data.boxes) or baseSpeed(player, data)
end

-- ===== Верёвки =====
local function attachmentOn(part, name)
	local attachment = part:FindFirstChild(name)
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = part
	end
	return attachment
end

-- Цепочка: игрок -> коробка 1 -> коробка 2 -> ...
local function relink(player)
	local data = carriers[player]
	local _, character = humanoidOf(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	local previous = attachmentOn(root, "BoxRopeAttachment")
	for _, box in data.boxes do
		local rope = box:FindFirstChild("Rope")
		if not rope then
			rope = Instance.new("RopeConstraint")
			rope.Name = "Rope"
			rope.Length = ROPE_LENGTH
			rope.Visible = true
			rope.Thickness = 0.12
			rope.Color = BrickColor.new("Brown")
			rope.Attachment1 = attachmentOn(box, "Front")
			rope.Parent = box
		end
		rope.Attachment0 = previous
		previous = attachmentOn(box, "Back")
	end
end

-- ===== Снять коробки =====
local function removeBox(player, box, explode)
	local data = carriers[player]
	if not data then
		return
	end
	local index = table.find(data.boxes, box)
	if index then
		table.remove(data.boxes, index)
	end
	data.info[box] = nil
	if explode and box.Parent then
		local explosion = Instance.new("Explosion")
		explosion.Position = box.Position
		explosion.BlastRadius = EXPLOSION_RADIUS
		explosion.BlastPressure = EXPLOSION_PRESSURE
		explosion.DestroyJointRadiusPercent = 0 -- красиво, но никого не убивает
		explosion.Parent = Workspace
	end
	if box.Parent then
		box:Destroy()
	end
end

local function dropAll(player, explode)
	local data = carriers[player]
	if not data then
		return
	end
	for _, box in table.clone(data.boxes) do
		removeBox(player, box, explode)
	end
end

-- ===== Взять коробку =====
local function spawnBox(player, root)
	local box = Instance.new("Part")
	box.Name = "CarryBox"
	box.Size = BOX_SIZE
	box.Color = Color3.fromRGB(176, 132, 82)
	box.Material = Enum.Material.Wood
	pcall(function()
		box.Material = Enum.Material.Cardboard -- есть не во всех версиях: тогда остаётся дерево
	end)
	box.CustomPhysicalProperties = PhysicalProperties.new(BOX_DENSITY, 0.5, 0.2)
	box.CollisionGroup = BOX_GROUP
	box:SetAttribute("Owner", player.UserId)
	box.CFrame = root.CFrame * CFrame.new(0, 1, 3 + #getData(player).boxes * 0.5)

	box.Parent = boxFolder
	pcall(box.SetNetworkOwner, box, player) -- физикой управляет игрок: плавно и без задержки
	return box
end

local function onPickup(player, pickupPart)
	local humanoid, character = humanoidOf(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	local data = getData(player)
	local now = os.clock()
	if now - data.lastPickup < PICKUP_COOLDOWN then
		return
	end
	data.lastPickup = now

	if canTakeMore(player, data) <= 0 then
		notify(player, "Слишком тяжело! Отнеси коробки в фуру", "bad")
		return
	end

	local box = spawnBox(player, root)
	table.insert(data.boxes, box)
	data.info[box] = { at = now, from = pickupPart.Position }
	box.AncestryChanged:Connect(function(_, parent)
		if not parent then
			-- коробку уничтожило что-то ещё (взрыв события и т.п.): просто убираем из списка
			local current = carriers[player]
			if current and table.find(current.boxes, box) then
				removeBox(player, box, false)
				relink(player)
				applySpeed(player)
				publish(player)
			end
		end
	end)
	relink(player)
	applySpeed(player)
	publish(player)
end

-- ===== Сдать коробки =====
local function insideZone(zone, position)
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X + TRIGGER_MARGIN
		and math.abs(localPos.Y) <= half.Y + TRIGGER_MARGIN
		and math.abs(localPos.Z) <= half.Z + TRIGGER_MARGIN
end

local function legit(data, box, zone, now)
	local info = data.info[box]
	if not info then
		return false
	end
	local distance = (zone.Position - info.from).Magnitude
	return now - info.at >= distance / MAX_TRAVEL_SPEED
end

local function deliver(player, boxes)
	local data = carriers[player]
	if not data or #boxes == 0 then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then
		return -- монеты ещё не загрузились: коробки остаются у игрока
	end
	local total = 0
	for _, box in boxes do
		total += rewardFor(player, data.streak)
		data.streak += 1
		removeBox(player, box, false)
	end
	coins.Value += total
	relink(player)
	applySpeed(player)
	publish(player)
	notify(player, ("Доставлено 📦 %d · +%d 🪙 · серия %d (x%s)"):format(
		#boxes, total, data.streak, tostring(streakMultiplier(data.streak))), "good")
end

local zones = {}
local pickups = {}

local function addZone(part)
	if part:IsA("BasePart") and not table.find(zones, part) then
		table.insert(zones, part)
	end
end

local function setupPickup(part)
	if not part:IsA("BasePart") or pickups[part] then
		return
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BoxPrompt"
		prompt.ActionText = "Взять коробку"
		prompt.ObjectText = "Почта"
		prompt.HoldDuration = PICKUP_HOLD
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	pickups[part] = prompt
	prompt.Triggered:Connect(function(player)
		onPickup(player, part)
	end)
end

for _, part in CollectionService:GetTagged(PICKUP_TAG) do
	setupPickup(part)
end
for _, part in CollectionService:GetTagged(DELIVERY_TAG) do
	addZone(part)
end
CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(setupPickup)
CollectionService:GetInstanceAddedSignal(DELIVERY_TAG):Connect(addZone)
for _, item in Workspace:GetDescendants() do
	if item.Name == PICKUP_TAG then
		setupPickup(item)
	elseif item.Name == DELIVERY_TAG then
		addZone(item)
	end
end
Workspace.DescendantAdded:Connect(function(item)
	-- дешёвая проверка имени: фуры с триггером могут появляться во время игры
	if item.Name == DELIVERY_TAG then
		addZone(item)
	elseif item.Name == PICKUP_TAG then
		setupPickup(item)
	end
end)

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		-- убираем исчезнувшие триггеры (уехавшие фуры)
		for i = #zones, 1, -1 do
			if not zones[i].Parent then
				table.remove(zones, i)
			end
		end
		local now = os.clock()
		for player, data in carriers do
			if #data.boxes > 0 then
				local _, character = humanoidOf(player)
				local root = character and character:FindFirstChild("HumanoidRootPart")
				for _, zone in zones do
					local ready = {}
					local playerInside = root and insideZone(zone, root.Position)
					for _, box in data.boxes do
						if (playerInside or insideZone(zone, box.Position)) and legit(data, box, zone, now) then
							table.insert(ready, box)
						end
					end
					if #ready > 0 then
						deliver(player, ready)
						break
					end
				end
			end
		end
	end
end)

-- ===== Персонаж, смерть, выход =====
local function onCharacterAdded(player, character)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = CHARACTER_GROUP
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = CHARACTER_GROUP
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	player.CharacterRemoving:Once(function()
		dropAll(player, true) -- персонаж пропал без смерти (респавн админом и т.п.)
		publish(player)
	end)
	humanoid:GetAttributeChangedSignal("BaseWalkSpeed"):Connect(function()
		applySpeed(player)
		publish(player)
	end)
	humanoid.Died:Connect(function()
		local data = carriers[player]
		if not data then
			return
		end
		local hadStreak = data.streak > 0
		dropAll(player, true) -- коробки взрываются
		data.streak = 0 -- серия теряется при смерти (апгрейд — нет)
		data.baseSpeed = nil
		publish(player)
		if hadStreak then
			notify(player, "Серия потеряна 💥", "bad")
		end
	end)
	publish(player)
end

local function onPlayerAdded(player)
	getData(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	player:GetAttributeChangedSignal("CoinMultiplier"):Connect(function()
		publish(player)
	end)
	publish(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	dropAll(player, false)
	carriers[player] = nil
end)
