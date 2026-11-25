-- ReplicatedStorage/EventManager  (ModuleScript, v2)
-- Список событий + единая точка запуска/остановки для сервера.
--
-- ВАЖНО: и RandomEventController, и admin.lua должны запускать события ТОЛЬКО через
-- Events.Start / Events.Stop. Тогда одновременно идёт не больше одного события, а ошибка
-- в одном событии не ломает остальные.
--
-- Клиент (AdminResetGui) по-прежнему читает отсюда только Events.List (имена).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Events = {}

-- ===== Настройки =====
-- Область над картой, куда падают фуры и бомбы (как в прежней версии)
local SKY = { xMin = -700, xMax = -239, zMin = 160, zMax = 430 }

-- Дождь из фур. РАНЬШЕ из-за Heartbeat + wait(2) фура создавалась КАЖДЫЙ КАДР (~60 в секунду).
local TRUCK_RAIN_INTERVAL = 0.5 -- секунд между фурами
local TRUCK_RAIN_HEIGHT = 150
local TRUCK_RAIN_LIFETIME = 3

-- Вьетнам
local BOMBS_PER_WAVE = 3
local BOMB_WAVE_INTERVAL = 5
local BOMB_HEIGHT = 120
local BLAST_RADIUS = 50
local BLAST_PRESSURE = 150000
-- Защита от лагов. Раньше взрыв «разбирал» ВСЕ якорные детали в радиусе, включая деревья
-- (по 31-73 детали каждое), и возвращал их только в конце события: за 120 с поднималась
-- почти вся зона (12 000+ деталей), и физика/репликация ложились.
local HEAVY_MODEL_PARTS = 20 -- детали моделей крупнее этого (деревья, дороги, здания) не трогаем
local MAX_PARTS_PER_EXPLOSION = 120 -- не больше стольких деталей за один взрыв (ближайшие к центру)
local MAX_ACTIVE_DEBRIS = 500 -- не больше стольких «живых» обломков на всю карту сразу
local DEBRIS_LIFETIME = 10 -- через сколько секунд обломки возвращаются на место (0 = только при остановке)
local EXCLUDED_NAMES = {
	Osnova = true, MenuCameraPart = true, spawner = true, spawner2 = true, Baseplate = true,
	SpawnLocation = true, sgushenka_buy = true, Sgushenka_met = true, Milkakyp = true, Stick = true,
	["zachita ot furochek"] = true, buy = true, modelsh = true, RadioBuy = true, swordbuy = true,
	gravitybuy = true, odnoryk = true,
}

-- Нексбот. Это куб с картинкой на BillboardGui и гуманоидом R6 БЕЗ ног: такой гуманоид
-- не умеет стоять и ходить, поэтому бот двигается своим кодом (без Humanoid и физики),
-- но СТЕНЫ его останавливают: он скользит вдоль них, а если застрял, строит обход.
local NEXBOT_SPEED = 100 -- студов в секунду (игроки бегают ~16-32; уменьши, если бот слишком смертелен)
local NEXBOT_HOVER_HEIGHT = 4 -- высота центра куба над землёй
local NEXBOT_BODY_RADIUS = 1.5 -- «толщина» бота при столкновениях (бордюры ниже ~2.5 студов он переступает)
local NEXBOT_WALL_SKIN = 0.1 -- зазор до стены
local NEXBOT_KILL_RADIUS = 5 -- по горизонтали, студов (и нужна прямая видимость: через стену не убивает)
local NEXBOT_KILL_HEIGHT = 10 -- по вертикали (картинка бота высотой 20 студов)
local NEXBOT_SPAWN_DISTANCE = 50 -- студов перед случайным игроком (если там стена, ищется место рядом)
local NEXBOT_PUSH_RADIUS = 15
local NEXBOT_PUSH_SPEED = 120
local NEXBOT_VERTICAL_SPEED = 80 -- как быстро бот поднимается/опускается вслед за рельефом
local NEXBOT_GROUND_PROBE_INTERVAL = 0.1 -- как часто искать землю под ботом
local NEXBOT_RETARGET_RATIO = 1.25 -- другого игрока берём в цель, только если он заметно ближе
local NEXBOT_MAX_DT = 0.1 -- при лаге сервера бот не «прыгает» дальше, чем за 0.1 с хода
local NEXBOT_WALL_NORMAL_Y = 0.5 -- поверхность круче этого считается стеной, положе (пандус, горка) нет
local NEXBOT_STUCK_SECONDS = 0.4 -- сколько бот может не продвигаться, прежде чем строить обход
local NEXBOT_STUCK_PROGRESS = 0.2 -- «не продвигается» = прошёл меньше 20% от возможного
local NEXBOT_PATH_COOLDOWN = 1 -- не чаще раза в секунду просим путь (PathfindingService недёшев)
local NEXBOT_PATH_LIFETIME = 5 -- через сколько секунд путь считается устаревшим
local NEXBOT_PATH_TARGET_DRIFT = 20 -- если игрок ушёл от конца пути дальше этого, путь устарел
local NEXBOT_WAYPOINT_RADIUS = 3 -- на таком расстоянии точка пути считается достигнутой
local NEXBOT_JUMP_HEIGHT = 12 -- высота прыжка, студов (перепрыгивает заборы, ящики, ступени до ~14 студов)
local NEXBOT_JUMP_COOLDOWN = 0.5 -- не чаще раза в полсекунды
local NEXBOT_JUMP_LEAD = 8 -- за сколько студов до точки обхода, где нужен прыжок, бот прыгает

-- ===== Вспомогательное =====
local function randomSkyPosition(height)
	return Vector3.new(math.random(SKY.xMin, SKY.xMax), height, math.random(SKY.zMin, SKY.zMax))
end

local function unanchorAll(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

-- Живые игроки с персонажем: { player, character, hrp, humanoid }
local function getLivingPlayers()
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 then
			table.insert(result, { player = player, character = character, hrp = hrp, humanoid = humanoid })
		end
	end
	return result
end

-- Звук в точке мира. Раньше звук клали внутрь объекта, который удалялся через секунду,
-- и звук обрывался (взрыв бомбы, финальный звук Нексбота).
local function playSoundAt(sound, position, lifetime)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = Workspace

	local clone = sound:Clone()
	clone.Parent = holder
	clone:Play()
	Debris:AddItem(holder, lifetime)
end

-- ===== 1. Дождь =====
local function newRain()
	local emitter = nil
	return {
		Name = "Дождь",
		Start = function()
			-- RainFall лежит внутри модели ramki, а не прямо в Workspace
			local rainFall = Workspace:FindFirstChild("RainFall", true)
			local found = rainFall and rainFall:FindFirstChildOfClass("ParticleEmitter")
			if not found then
				warn("[Events] Дождь: не найден RainFall с ParticleEmitter")
				return false
			end
			emitter = found
			emitter.Enabled = true
			return true
		end,
		Stop = function()
			if emitter then
				emitter.Enabled = false
				emitter = nil
			end
		end,
	}
end

-- ===== 2. А ГДЕ?! (выключаем спавнеры фур) =====
local function newNoTrucks()
	local SPAWNER_SCRIPTS = { "TruckSpawner", "TruckSpawner2" }
	local disabledByUs = {}
	return {
		Name = "😡😡А ГДЕ?!?!😡😡",
		Start = function()
			local serverScripts = game:GetService("ServerScriptService")
			for _, name in SPAWNER_SCRIPTS do
				local spawner = serverScripts:FindFirstChild(name)
				-- включаем обратно только те, что выключили сами
				if spawner and spawner:IsA("Script") and not spawner.Disabled then
					spawner.Disabled = true
					table.insert(disabledByUs, spawner)
				end
			end
			if #disabledByUs == 0 then
				warn("[Events] А ГДЕ?!: спавнеры не найдены или уже выключены")
				return false
			end
			return true
		end,
		Stop = function()
			for _, spawner in disabledByUs do
				if spawner.Parent then
					spawner.Disabled = false
				end
			end
			disabledByUs = {}
		end,
	}
end

-- ===== 3. Дождь из фур =====
local function newTruckRain()
	local runId = 0
	local active = false
	return {
		Name = "🥵🥵Дождь из фур🥵🥵",
		Start = function()
			local truckModel = game:GetService("ServerStorage"):FindFirstChild("Furocka3")
			if not truckModel then
				warn("[Events] Дождь из фур: Furocka3 не найден в ServerStorage")
				return false
			end

			runId += 1
			local myRun = runId
			active = true

			task.spawn(function()
				while active and myRun == runId do
					-- всё настраиваем до Parent, чтобы фура не мелькала на месте шаблона
					local truck = truckModel:Clone()
					truck:PivotTo(CFrame.new(randomSkyPosition(TRUCK_RAIN_HEIGHT)))
					unanchorAll(truck)
					truck.Parent = Workspace
					Debris:AddItem(truck, TRUCK_RAIN_LIFETIME)
					task.wait(TRUCK_RAIN_INTERVAL)
				end
			end)
			return true
		end,
		Stop = function()
			active = false
			runId += 1
		end,
	}
end

-- ===== 4. Перемешивание позиций =====
local function newShuffle()
	return {
		Name = "🔄 Перемешивание позиций",
		Start = function()
			-- Только живые игроки, которые не сидят в транспорте
			local entries = {}
			for _, info in getLivingPlayers() do
				if not info.humanoid.SeatPart then
					table.insert(entries, { character = info.character, hrp = info.hrp, cframe = info.hrp.CFrame })
				end
			end
			if #entries < 2 then
				return false -- перемешивать некого
			end

			-- Случайный цикл: каждый получает место другого, никто не остаётся на своём
			-- и двое не окажутся в одной точке (раньше индексы игроков и позиций расходились).
			for i = #entries, 2, -1 do
				local j = math.random(1, i)
				entries[i], entries[j] = entries[j], entries[i]
			end
			for i, entry in entries do
				local nextEntry = entries[i % #entries + 1]
				entry.newCFrame = nextEntry.cframe
			end
			for _, entry in entries do
				if entry.hrp.Parent then
					entry.character:PivotTo(entry.newCFrame)
					entry.hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end
			return true
		end,
		Stop = function() end,
	}
end

-- ===== 5. Вьетнам =====
local function newVietnam()
	local runId = 0
	local active = false
	local changed = {} -- [деталь] = { CFrame, CastShadow }: то, что подняли взрывы
	local activeCount = 0
	local activeBombs = {}
	local heavyCache = {}

	local overlapParams = OverlapParams.new()

	-- Самая внешняя Model, в которой лежит деталь (дерево целиком, а не его ветка)
	local function outerModel(part)
		local model = part:FindFirstAncestorOfClass("Model")
		while model do
			local parent = model.Parent
			if parent and parent:IsA("Model") then
				model = parent
			else
				break
			end
		end
		return model
	end

	-- «Тяжёлая» модель: деревья, дороги, здания. Их детали взрыв не трогает.
	local function isHeavy(part)
		local model = outerModel(part)
		if not model then
			return false
		end
		local heavy = heavyCache[model]
		if heavy == nil then
			local count = 0
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					count += 1
					if count > HEAVY_MODEL_PARTS then
						break
					end
				end
			end
			heavy = count > HEAVY_MODEL_PARTS
			heavyCache[model] = heavy
		end
		return heavy
	end

	local function restorePart(part)
		local data = changed[part]
		if not data then
			return
		end
		changed[part] = nil
		activeCount -= 1
		if part:IsDescendantOf(Workspace) then
			part.Anchored = true
			part.CFrame = data.CFrame
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CastShadow = data.CastShadow
		end
	end

	local function explode(bomb, explosionSound, myRun)
		local primary = bomb.PrimaryPart
		if not primary or not activeBombs[bomb] then
			return
		end
		activeBombs[bomb] = nil
		local position = primary.Position

		playSoundAt(explosionSound, position, 5)

		local explosion = Instance.new("Explosion")
		explosion.Position = position
		explosion.BlastRadius = BLAST_RADIUS
		explosion.BlastPressure = BLAST_PRESSURE
		explosion.Parent = Workspace

		-- Пространственный запрос вместо перебора всех ~49 000 объектов карты на каждый взрыв
		local inRange = {}
		for _, part in Workspace:GetPartBoundsInRadius(position, BLAST_RADIUS, overlapParams) do
			if part.Anchored and not EXCLUDED_NAMES[part.Name] and not changed[part] then
				local distance = (part.Position - position).Magnitude
				if distance <= BLAST_RADIUS then
					table.insert(inRange, { part = part, distance = distance })
				end
			end
		end
		table.sort(inRange, function(a, b)
			return a.distance < b.distance
		end)

		-- Берём ближайшие к центру, пропуская «тяжёлые» модели, в пределах лимитов
		local budget = math.min(MAX_PARTS_PER_EXPLOSION, MAX_ACTIVE_DEBRIS - activeCount)
		local batch = {}
		for _, entry in inRange do
			if #batch >= budget then
				break
			end
			local part = entry.part
			if not isHeavy(part) then
				changed[part] = { CFrame = part.CFrame, CastShadow = part.CastShadow }
				activeCount += 1
				part.Anchored = false
				part.CastShadow = false
				table.insert(batch, part)
			end
		end

		-- Обломки возвращаются на место сами, чтобы физика не копила тысячи деталей
		if DEBRIS_LIFETIME > 0 and #batch > 0 then
			task.delay(DEBRIS_LIFETIME, function()
				if myRun ~= runId then
					return -- событие уже остановлено, всё вернул Stop
				end
				for _, part in batch do
					restorePart(part)
				end
			end)
		end

		Debris:AddItem(bomb, 1)
	end

	local function spawnBomb(bombTemplate, explosionSound, myRun)
		local bomb = bombTemplate:Clone()
		bomb:PivotTo(CFrame.new(randomSkyPosition(BOMB_HEIGHT)))
		unanchorAll(bomb)
		activeBombs[bomb] = true
		bomb.Parent = Workspace

		bomb.PrimaryPart.Touched:Connect(function(hit)
			if hit:IsDescendantOf(bomb) then
				return
			end
			explode(bomb, explosionSound, myRun)
		end)
	end

	return {
		Name = "💀☠️ВЬЕТНАМ☠️💀",
		Start = function()
			local bombTemplate = game:GetService("ServerStorage"):FindFirstChild("BombModel")
			local explosionSound = ReplicatedStorage:FindFirstChild("RocketExplosionSound")
			if not bombTemplate or not bombTemplate.PrimaryPart then
				warn("[Events] Вьетнам: BombModel (с PrimaryPart) не найден в ServerStorage")
				return false
			end
			if not explosionSound then
				warn("[Events] Вьетнам: RocketExplosionSound не найден в ReplicatedStorage")
				return false
			end

			runId += 1
			local myRun = runId
			active = true
			changed = {}
			activeCount = 0
			activeBombs = {}
			heavyCache = setmetatable({}, { __mode = "k" })

			task.spawn(function()
				while active and myRun == runId do
					for _ = 1, BOMBS_PER_WAVE do
						spawnBomb(bombTemplate, explosionSound, myRun)
					end
					task.wait(BOMB_WAVE_INTERVAL)
				end
			end)
			return true
		end,

		Stop = function()
			active = false
			runId += 1

			for bomb in activeBombs do
				if bomb.Parent then
					bomb:Destroy()
				end
			end
			activeBombs = {}

			-- Вернуть всё, что ещё не вернулось само
			for part in changed do
				restorePart(part)
			end
			changed = {}
			activeCount = 0
		end,
	}
end

-- ===== 6. Нексбот =====
local function newNexbot()
	local runId = 0
	local bot = nil
	local sounds = nil
	local heartbeatConnection = nil

	local function flatDistance(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	-- Земля под точкой. Игроки и сам бот не мешают; детали без коллизии (листва) пропускаются.
	-- Луч стартует чуть выше центра бота, поэтому под низкой крышей он находит пол, а не крышу.
	-- Если земля впереди резко выше и луч стартует «внутри» неё, пробуем с большей высоты.
	local function findGroundY(position, ignore)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		for _, lift in { 1.5, 6, 40 } do
			local result = Workspace:Raycast(position + Vector3.new(0, lift, 0), Vector3.new(0, -(lift + 250), 0), params)
			if result then
				return result.Position.Y
			end
		end
		return nil
	end

	local function getIgnoreList(extra)
		local list = { extra }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(list, player.Character)
			end
		end
		return list
	end

	-- Что считается преградой: заякоренное и с коллизией. Незаякоренное (машины, мелкие предметы)
	-- бот не останавливает, а расталкивает.
	local function castBody(origin, vector, ignore)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		local filter = table.clone(ignore)
		for _ = 1, 4 do
			params.FilterDescendantsInstances = filter
			local result = Workspace:Spherecast(origin, NEXBOT_BODY_RADIUS, vector, params)
			if not result then
				return nil
			end
			if result.Instance and not result.Instance.Anchored then
				table.insert(filter, result.Instance)
			elseif math.abs(result.Normal.Y) > NEXBOT_WALL_NORMAL_Y then
				return nil -- пологая поверхность (пандус, горка): по ней идём, высоту ведёт следование рельефу
			else
				return result
			end
		end
		return nil
	end

	-- Шаг по горизонтали с упором в стены: до стены идём, остаток скользит вдоль неё.
	local function moveWithCollision(position, step, ignore)
		local remaining = step
		local firstHit = nil
		for iteration = 1, 3 do
			local length = remaining.Magnitude
			if length < 1e-4 then
				break
			end
			local direction = remaining / length
			local hit = castBody(position, direction * (length + NEXBOT_WALL_SKIN), ignore)
			if not hit then
				position = position + remaining
				break
			end

			local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			if normal.Magnitude < 0.01 then
				position = position + remaining
				break
			end
			normal = normal.Unit
			firstHit = firstHit or hit

			local allowed = math.max(0, hit.Distance - NEXBOT_WALL_SKIN)
			if hit.Distance < NEXBOT_WALL_SKIN and iteration == 1 then
				position = position + normal * NEXBOT_WALL_SKIN -- уже вплотную: чуть отодвигаем от стены
			end
			position = position + direction * math.min(allowed, length)
			local leftover = direction * math.max(0, length - allowed)
			remaining = leftover - normal * leftover:Dot(normal) -- скольжение вдоль стены
		end
		return position, firstHit
	end

	-- Можно ли перепрыгнуть: на высоте прыжка путь вперёд свободен.
	local function canJumpOver(position, direction, ignore)
		local lifted = position + Vector3.new(0, NEXBOT_JUMP_HEIGHT, 0)
		return castBody(lifted, direction * (NEXBOT_BODY_RADIUS + 3), ignore) == nil
	end

	-- Видно ли игрока: стена между ботом и игроком гасит удар.
	local function hasClearLine(from, to, ignore)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		local filter = table.clone(ignore)
		for _ = 1, 4 do
			params.FilterDescendantsInstances = filter
			local result = Workspace:Raycast(from, to - from, params)
			if not result then
				return true
			end
			if result.Instance and not result.Instance.Anchored then
				table.insert(filter, result.Instance)
			else
				return false
			end
		end
		return true
	end

	local function isSpaceFree(position, ignore)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		for _, part in Workspace:GetPartBoundsInRadius(position, NEXBOT_BODY_RADIUS + 1, params) do
			if part.CanCollide and part.Anchored then
				return false
			end
		end
		return true
	end

	-- Место появления: перед игроком; если там здание или дерево, ищем рядом по кругу.
	local function chooseSpawn(anchor, ignore)
		local look = anchor.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
		local angles = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 }
		for _, radius in { NEXBOT_SPAWN_DISTANCE, 35, 25 } do
			for _, degrees in angles do
				local rad = math.rad(degrees)
				local cos, sin = math.cos(rad), math.sin(rad)
				local direction = Vector3.new(flatLook.X * cos - flatLook.Z * sin, 0, flatLook.X * sin + flatLook.Z * cos)
				local xz = anchor.Position + direction * radius
				local groundY = findGroundY(xz, ignore) or (anchor.Position.Y - 3)
				local candidate = Vector3.new(xz.X, groundY + NEXBOT_HOVER_HEIGHT, xz.Z)
				if isSpaceFree(candidate, ignore) then
					return candidate
				end
			end
		end
		return anchor.Position + flatLook * 20 + Vector3.new(0, 1, 0)
	end

	local function showCrushedBanner(victim)
		for _, viewer in Players:GetPlayers() do
			local playerGui = viewer:FindFirstChild("PlayerGui")
			if playerGui then
				local screenGui = Instance.new("ScreenGui")
				screenGui.ResetOnSpawn = false
				screenGui.IgnoreGuiInset = true

				local textLabel = Instance.new("TextLabel")
				textLabel.Size = UDim2.new(1, 0, 1, 0)
				textLabel.BackgroundTransparency = 1
				textLabel.TextScaled = true
				textLabel.Font = Enum.Font.GothamBlack
				textLabel.TextColor3 = Color3.new(1, 0, 0)
				textLabel.Text = string.upper(victim.DisplayName) .. " БЫЛ ЗАДАВЛЕН"
				textLabel.Parent = screenGui
				screenGui.Parent = playerGui

				task.spawn(function()
					for _ = 1, 40 do
						textLabel.Position = UDim2.new(0, math.random(-10, 10), 0, math.random(-10, 10))
						task.wait(0.02)
					end
					for i = 1, 20 do
						textLabel.TextTransparency = i / 20
						task.wait(0.05)
					end
					screenGui:Destroy()
				end)
			end
		end
	end

	local function stopLoops()
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
	end

	return {
		Name = "💀НЕКСБОТ НА ОХОТЕ💀",
		Start = function()
			local template = game:GetService("ServerStorage"):FindFirstChild("Nexbot")
			if not template then
				warn("[Events] Нексбот: модель Nexbot не найдена в ServerStorage")
				return false
			end

			-- Раньше место брали по workspace.CurrentCamera, а на сервере у игрока камеры нет.
			local living = getLivingPlayers()
			if #living == 0 then
				warn("[Events] Нексбот: на сервере нет живых игроков")
				return false
			end
			local anchor = living[math.random(1, #living)].hrp

			local newBot = template:Clone()
			local hrp = newBot:FindFirstChild("HumanoidRootPart")
			if not hrp then
				newBot:Destroy()
				warn("[Events] Нексбот: в модели нет HumanoidRootPart")
				return false
			end

			-- Гуманоид R6 без ног не умеет ходить: убираем, двигаем бота сами
			local humanoid = newBot:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:Destroy()
			end
			hrp.Anchored = true
			hrp.CanCollide = false -- призрак для игроков: не сбивает их; стены держим кодом, а не физикой
			hrp.CanTouch = false
			hrp.CanQuery = false -- не мешает лучам других скриптов

			stopLoops()
			runId += 1
			local myRun = runId
			bot = newBot
			sounds = newBot:FindFirstChild("Sounds")

			hrp.CFrame = CFrame.new(chooseSpawn(anchor, getIgnoreList(newBot)))
			newBot.Parent = Workspace

			local function isRunning()
				return myRun == runId and bot == newBot and newBot.Parent == Workspace
			end

			local function playSound(name)
				local sound = sounds and sounds:FindFirstChild(name)
				if sound then
					sound:Play()
				end
			end
			playSound("Spawn")
			local chase = sounds and sounds:FindFirstChild("Chase")
			if chase then
				chase.Looped = true
				chase:Play()
			end

			local function crush(info)
				playSound("Hit")
				local delta = info.hrp.Position - hrp.Position
				local direction = delta.Magnitude > 0.01 and delta.Unit or Vector3.yAxis
				info.hrp.AssemblyLinearVelocity = direction * 150 + Vector3.new(0, 100, 0)
				info.humanoid.Health = info.humanoid.Health - 10000
				showCrushedBanner(info.player)
			end

			-- Обход: PathfindingService вызывается только когда бот застрял, и не в кадре движения
			local path = { waypoints = nil, jumps = nil, index = 1, createdAt = 0, endPos = nil, requesting = false, lastRequest = -math.huge }
			local elapsed = 0
			local function requestPath(fromPosition, toPosition)
				if path.requesting or elapsed - path.lastRequest < NEXBOT_PATH_COOLDOWN then
					return
				end
				path.requesting = true
				path.lastRequest = elapsed
				task.spawn(function()
					local computed = game:GetService("PathfindingService"):CreatePath({
						AgentRadius = 2,
						AgentHeight = 5,
						AgentCanJump = true, -- бот прыгает: пути с прыжками ему подходят
					})
					local ok = pcall(function()
						computed:ComputeAsync(fromPosition, toPosition)
					end)
					if ok and computed.Status == Enum.PathStatus.Success and isRunning() then
						local list = {}
						local jumps = {}
						for _, waypoint in computed:GetWaypoints() do
							table.insert(list, waypoint.Position)
							jumps[#list] = waypoint.Action == Enum.PathWaypointAction.Jump
						end
						path.waypoints = list
						path.jumps = jumps
						path.index = 2 -- первая точка — где бот стоит
						path.createdAt = elapsed
						path.endPos = toPosition
					end
					path.requesting = false
				end)
			end

			-- Основной цикл: движение к цели со стенами, следование рельефу, убийство
			local target = nil
			local groundTargetY = hrp.Position.Y
			local sinceProbe = 0
			local stuckTime = 0
			local airborne = false
			local verticalVelocity = 0
			local sinceJump = math.huge
			heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
				if not isRunning() then
					return
				end
				dt = math.min(dt, NEXBOT_MAX_DT)
				elapsed += dt
				local position = hrp.Position
				local alive = getLivingPlayers()
				local ignore = getIgnoreList(newBot)

				-- Цель: ближайший игрок; текущую цель держим, пока другой не станет заметно ближе
				local closest, closestDist = nil, math.huge
				local current, currentDist = nil, math.huge
				for _, info in alive do
					local distance = (info.hrp.Position - position).Magnitude
					if distance < closestDist then
						closest, closestDist = info, distance
					end
					if target and info.player == target then
						current, currentDist = info, distance
					end
				end
				local chosen = closest
				if current and currentDist <= closestDist * NEXBOT_RETARGET_RATIO then
					chosen = current
				end
				target = chosen and chosen.player or nil

				-- Куда идём: по обходу, если он есть и не устарел, иначе прямо к игроку
				local goal = nil
				local wantJump = false
				if chosen then
					goal = chosen.hrp.Position
					if path.waypoints then
						local stale = elapsed - path.createdAt > NEXBOT_PATH_LIFETIME
							or (chosen.hrp.Position - path.endPos).Magnitude > NEXBOT_PATH_TARGET_DRIFT
						if stale then
							path.waypoints = nil
						else
							local waypoint = path.waypoints[path.index]
							-- к этой точке нужен прыжок: прыгаем заранее
							if waypoint and path.jumps[path.index] and flatDistance(position, waypoint) <= NEXBOT_JUMP_LEAD then
								wantJump = true
							end
							while waypoint and flatDistance(position, waypoint) <= NEXBOT_WAYPOINT_RADIUS do
								path.index += 1
								waypoint = path.waypoints[path.index]
							end
							if waypoint then
								goal = waypoint
							else
								path.waypoints = nil
							end
						end
					end
				end

				-- Движение по горизонтали (со стенами)
				local newPosition = position
				if goal then
					local delta = goal - position
					local flat = Vector3.new(delta.X, 0, delta.Z)
					local flatDist = flat.Magnitude
					if flatDist > 0.1 then
						local step = flat.Unit * math.min(NEXBOT_SPEED * dt, flatDist)
						local hit
						newPosition, hit = moveWithCollision(position, step, ignore)
						-- Упёрлись в то, что ниже прыжка: прыгаем, а не скользим вдоль
						if hit and canJumpOver(position, flat.Unit, ignore) then
							wantJump = true
						end

						-- Застрял (упёрся в стену, угол): просим обход
						local progressed = flatDistance(newPosition, position)
						if flatDist > 1.5 and progressed < NEXBOT_SPEED * dt * NEXBOT_STUCK_PROGRESS then
							stuckTime += dt
							if stuckTime >= NEXBOT_STUCK_SECONDS then
								if path.waypoints and stuckTime >= NEXBOT_STUCK_SECONDS * 3 then
									path.waypoints = nil -- и обход не помог: пересчитаем
								end
								requestPath(position, chosen.hrp.Position)
							end
						else
							stuckTime = 0
						end
					end
				else
					stuckTime = 0
				end

				-- Прыжок
				sinceJump += dt
				if wantJump and not airborne and sinceJump >= NEXBOT_JUMP_COOLDOWN then
					airborne = true
					verticalVelocity = math.sqrt(2 * Workspace.Gravity * NEXBOT_JUMP_HEIGHT)
					sinceJump = 0
					playSound("Jump")
				end

				-- Высота: на земле плавно к земле + HOVER (землю ищем не каждый кадр), в прыжке по дуге
				sinceProbe += dt
				if sinceProbe >= NEXBOT_GROUND_PROBE_INTERVAL then
					sinceProbe = 0
					local probed = findGroundY(newPosition, ignore)
					if probed then
						groundTargetY = probed + NEXBOT_HOVER_HEIGHT
					end
				end
				local newY
				if airborne then
					verticalVelocity -= Workspace.Gravity * dt
					newY = newPosition.Y + verticalVelocity * dt
					if verticalVelocity <= 0 and newY <= groundTargetY then
						newY = groundTargetY -- приземлился (на землю или на платформу под ним)
						airborne = false
						verticalVelocity = 0
					end
				else
					local maxVertical = NEXBOT_VERTICAL_SPEED * dt
					newY = newPosition.Y + math.clamp(groundTargetY - newPosition.Y, -maxVertical, maxVertical)
				end
				newPosition = Vector3.new(newPosition.X, newY, newPosition.Z)

				if newPosition ~= position then
					hrp.CFrame = CFrame.new(newPosition)
				end

				-- Убийство по расстоянию и только при прямой видимости: стена спасает
				for _, info in alive do
					local offset = info.hrp.Position - newPosition
					if
						Vector3.new(offset.X, 0, offset.Z).Magnitude <= NEXBOT_KILL_RADIUS
						and math.abs(offset.Y) <= NEXBOT_KILL_HEIGHT
						and info.humanoid.Health > 0
						and hasClearLine(newPosition, info.hrp.Position, ignore)
					then
						crush(info)
					end
				end
			end)

			-- Отталкивание свободных объектов: пространственный запрос вместо перебора
			-- всех ~49 000 объектов Workspace десять раз в секунду.
			local pushParams = OverlapParams.new()
			pushParams.FilterType = Enum.RaycastFilterType.Exclude
			pushParams.FilterDescendantsInstances = { newBot }
			task.spawn(function()
				while isRunning() do
					local pushed = {}
					for _, part in Workspace:GetPartBoundsInRadius(hrp.Position, NEXBOT_PUSH_RADIUS, pushParams) do
						local root = part.AssemblyRootPart or part
						if not part.Anchored and not pushed[root] then
							local delta = part.Position - hrp.Position
							if delta.Magnitude > 0.01 then
								pushed[root] = true -- один толчок на объект, а не на каждую его деталь
								part.AssemblyLinearVelocity += delta.Unit * NEXBOT_PUSH_SPEED
							end
						end
					end
					task.wait(0.1)
				end
			end)

			return true
		end,

		Stop = function()
			runId += 1 -- все циклы бота и ожидающий путь завершаются
			stopLoops()
			local oldBot = bot
			bot = nil
			if not oldBot then
				return
			end

			local oldSounds = sounds
			sounds = nil
			local chase = oldSounds and oldSounds:FindFirstChild("Chase")
			if chase then
				chase:Stop()
			end
			local finale = oldSounds and oldSounds:FindFirstChild("End")
			local hrp = oldBot:FindFirstChild("HumanoidRootPart")
			if finale and hrp then
				playSoundAt(finale, hrp.Position, math.max(finale.TimeLength, 5))
			end
			oldBot:Destroy()
		end,
	}
end

-- ===== Список событий =====
Events.List = {
	newRain(),
	newNoTrucks(),
	newTruckRain(),
	newShuffle(),
	newVietnam(),
	newNexbot(),
}

-- ===== Запуск и остановка (только сервер) =====
local current = nil -- { event, token }
local tokenCounter = 0

local function findEvent(name)
	for _, event in Events.List do
		if event.Name == name then
			return event
		end
	end
	return nil
end

local function announce(name)
	local remote = ReplicatedStorage:FindFirstChild("EventAnnouncement")
	if remote then
		remote:FireAllClients(name)
	end
end

-- Имя идущего сейчас события или nil
function Events.GetCurrent()
	return current and current.event.Name or nil
end

-- Для админ-панели: имя идущего события и когда оно закончится (серверное время, nil = до ручной остановки)
function Events.GetInfo()
	return {
		name = current and current.event.Name or nil,
		endsAt = current and current.endsAt or nil,
	}
end

-- Включение/выключение случайных событий (читает RandomEventController) и время следующего
local randomEnabled = true
local nextRandomAt = nil

function Events.SetRandomEnabled(enabled)
	randomEnabled = enabled == true
end

function Events.IsRandomEnabled()
	return randomEnabled
end

function Events.SetNextRandomAt(serverTime)
	nextRandomAt = serverTime
end

function Events.GetNextRandomAt()
	return nextRandomAt
end

-- Останавливает идущее событие. Если задано name, то только когда идёт именно оно.
function Events.Stop(name)
	if not current then
		return false
	end
	if name ~= nil and current.event.Name ~= name then
		return false
	end

	local event = current.event
	current = nil
	local ok, err = pcall(event.Stop)
	if not ok then
		warn(("[Events] Ошибка при остановке '%s': %s"):format(event.Name, tostring(err)))
	end
	print("Событие закончилось:", event.Name)
	return true
end

-- Запускает событие (предыдущее останавливается). duration в секундах: по истечении
-- событие остановится само; nil значит работать до ручной остановки.
-- Возвращает true или false + причина. Ошибка внутри события сюда не пробивается.
function Events.Start(name, duration)
	if not RunService:IsServer() then
		return false, "запускать события можно только на сервере"
	end
	local event = findEvent(name)
	if not event then
		return false, "неизвестное событие"
	end

	Events.Stop()

	local ok, result = pcall(event.Start)
	if not ok then
		warn(("[Events] Ошибка при запуске '%s': %s"):format(event.Name, tostring(result)))
		pcall(event.Stop) -- убрать то, что успело создаться до ошибки
		return false, tostring(result)
	end
	if result == false then
		pcall(event.Stop)
		return false, "событие не смогло начаться"
	end

	tokenCounter += 1
	local token = tokenCounter
	current = {
		event = event,
		token = token,
		endsAt = duration and (Workspace:GetServerTimeNow() + duration) or nil,
	}
	print("Событие началось:", event.Name)
	announce(event.Name)

	if duration then
		task.delay(duration, function()
			-- таймер старого запуска не должен остановить более новое событие
			if current and current.token == token then
				Events.Stop()
			end
		end)
	end
	return true
end

return Events
