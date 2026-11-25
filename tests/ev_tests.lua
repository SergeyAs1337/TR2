local function lastAnn() return announced[#announced] end
local function countPartsNamed(root, name) local n = 0 for _, d in ipairs(methods.GetDescendants(root)) do if d.Name == name then n += 1 end end return n end

print("--- A. Координатор Events.Start/Stop (поддельные события)")
resetWorld(); local E = loadEvents(); loadedEvents = E
local log = {}
local function fake(name, result, boom)
	return {Name = name, Start = function() table.insert(log, "start:" .. name); if boom then error("boom") end return result end,
		Stop = function() table.insert(log, "stop:" .. name) end}
end
E.List = {fake("A", true), fake("B", true), fake("Bad", nil, true), fake("False", false)}
local ok, err = E.Start("Нет такого")
check("A1. неизвестное событие -> false", ok == false)
ok = E.Start("A", 5)
check("A2. запуск A: current=A, объявлено клиентам", ok == true and E.GetCurrent() == "A" and lastAnn() == "A")
runFor(3); ok = E.Start("B", 4)
check("A3. запуск B останавливает A", ok and E.GetCurrent() == "B" and table.concat(log, ",") == "start:A,stop:A,start:B")
runFor(2.5)
check("A4. таймер старого A (t=5) НЕ останавливает новое B", E.GetCurrent() == "B")
runFor(2)
check("A5. B останавливается своим таймером (t=7)", E.GetCurrent() == nil and log[#log] == "stop:B")
local annBefore = #announced
ok = E.Start("Bad")
check("A6. ошибка в Start: false, нет current, нет объявления, вызван cleanup Stop", ok == false and E.GetCurrent() == nil and #announced == annBefore and log[#log] == "stop:Bad")
ok = E.Start("False")
check("A7. Start вернул false: событие не объявляется", ok == false and #announced == annBefore)
check("A8. Stop без события -> false", E.Stop() == false)
E.Start("A"); check("A9. Stop('B') при текущем A ничего не делает", E.Stop("B") == false and E.GetCurrent() == "A")
check("A10. Stop('A') останавливает", E.Stop("A") == true and E.GetCurrent() == nil)

print("--- B. RandomEventController")
resetWorld(); E = loadEvents(); loadedEvents = E; log = {}
E.List = {fake("A", true), fake("B", true), fake("Bad", nil, true), fake("False", false)}
task.spawn(runController)
runFor(1500)
check("B1. на пустом сервере события не запускаются", #log == 0)
mkPlayer("p1", v3(0, 0, 0)); runFor(6000)
local sawBad, sawFalse = false, false
for _, l in ipairs(log) do if l == "start:Bad" then sawBad = true end if l == "start:False" then sawFalse = true end end
check(("B2. контроллер пережил ошибку Bad и отказ False и продолжает работать (успешных запусков %d за 6000 с)"):format(#announced), sawBad and sawFalse and #announced >= 10)
local adjacentSame = false
for i = 2, #announced do if announced[i] == announced[i - 1] then adjacentSame = true end end
check("B3. одно событие не выпадает дважды подряд", not adjacentSame and #announced > 5)
check("B4. объявлены только успешные события (A и B)", (function() for _, n in ipairs(announced) do if n ~= "A" and n ~= "B" then return false end end return true end)())
-- админ запустил событие вручную: контроллер ждёт
resetWorld(); E = loadEvents(); loadedEvents = E; log = {}
E.List = {fake("A", true), fake("B", true)}; mkPlayer("p1", v3(0, 0, 0))
E.Start("A"); local before = #log
task.spawn(runController); runFor(3000)
check("B5. пока идёт событие админа (без таймера), контроллер ничего не запускает", #log == before and E.GetCurrent() == "A")
E.Stop(); runFor(1500)
check("B6. после остановки контроллер продолжает", #log > before)

print("--- C. Реальные события")
resetWorld(); E = loadEvents(); loadedEvents = E
local rainName, noTrucksName, truckRainName, shuffleName, vietnamName, nexbotName = E.List[1].Name, E.List[2].Name, E.List[3].Name, E.List[4].Name, E.List[5].Name, E.List[6].Name
check("C0. имена событий не изменились", rainName == "Дождь" and noTrucksName == "😡😡А ГДЕ?!?!😡😡" and truckRainName == "🥵🥵Дождь из фур🥵🥵" and shuffleName == "🔄 Перемешивание позиций" and vietnamName == "💀☠️ВЬЕТНАМ☠️💀" and nexbotName == "💀НЕКСБОТ НА ОХОТЕ💀")

-- Дождь
local emitter = Workspace:FindFirstChild("RainFall", true):FindFirstChildOfClass("ParticleEmitter")
check("C1. Дождь включается (RainFall внутри ramki)", E.Start(rainName) == true and emitter.Enabled == true)
E.Stop(); check("C1. Дождь выключается", emitter.Enabled == false)
Workspace:FindFirstChild("ramki").Parent = nil
local okRain = E.Start(rainName)
check("C1. нет RainFall -> false, без ошибки", okRain == false and E.GetCurrent() == nil)

-- А ГДЕ?!
resetWorld(); E = loadEvents(); loadedEvents = E
local s1, s2 = ServerScriptService:FindFirstChild("TruckSpawner"), ServerScriptService:FindFirstChild("TruckSpawner2")
E.Start(noTrucksName)
check("C2. оба спавнера выключены", s1.Disabled and s2.Disabled)
E.Stop(); check("C2. оба включены обратно", not s1.Disabled and not s2.Disabled)
s2.Disabled = true; E.Start(noTrucksName); E.Stop()
check("C2. выключенный заранее спавнер остаётся выключенным", not s1.Disabled and s2.Disabled)

-- Дождь из фур
resetWorld(); E = loadEvents(); loadedEvents = E
E.Start(truckRainName, 120)
local maxAlive, samples = 0, 0
for t = 1, 125 do runFor(1); local alive = countPartsNamed(Workspace, "Furocka3"); if alive > maxAlive then maxAlive = alive end end
local made = cloneCount["Furocka3"]
check(("C3. за 120 с создано ~240 фур (создано %d)"):format(made), made >= 239 and made <= 242)
check(("C3. одновременно живёт не больше ~8 фур (макс %d), раньше ~180"):format(maxAlive), maxAlive <= 8)
runFor(30); check("C3. после остановки фуры не создаются", cloneCount["Furocka3"] == made and E.GetCurrent() == nil)
resetWorld(); E = loadEvents(); loadedEvents = E; E.Start(truckRainName); runFor(0.1)
local truck = Workspace:FindFirstChild("Furocka3")
local pos = truck.PrimaryPart.Position
check("C3. фура создана в небе в заданной области, части не заякорены", pos.Y == 150 and pos.X >= -700 and pos.X <= -239 and pos.Z >= 160 and pos.Z <= 430 and (function() for _, d in ipairs(methods.GetDescendants(truck)) do if d.Anchored then return false end end return true end)())

-- Перемешивание
resetWorld(); E = loadEvents(); loadedEvents = E
local pA = mkPlayer("A", v3(10, 0, 0)); local pB = mkPlayer("B", v3(20, 0, 0)); local pC = mkPlayer("C", v3(30, 0, 0)); local pD = mkPlayer("D", v3(40, 0, 0))
local pE = mkPlayer("E", v3(0, 0, 0), {noCharacter = true}); local pF = mkPlayer("F", v3(50, 0, 0), {seated = true}); local pG = mkPlayer("G", v3(60, 0, 0), {health = 0})
pA.Character.HumanoidRootPart.AssemblyLinearVelocity = v3(0, -50, 0)
local function xs() return pA.Character.HumanoidRootPart.Position.X, pB.Character.HumanoidRootPart.Position.X, pC.Character.HumanoidRootPart.Position.X, pD.Character.HumanoidRootPart.Position.X end
local ok2 = E.Start(shuffleName)
local a, b, c, d = xs()
local set = {[a] = true, [b] = true, [c] = true, [d] = true}
check("C4. перемешивание запущено", ok2 == true)
check("C4. позиции A..D — перестановка (никто не потерялся и не задвоился)", set[10] and set[20] and set[30] and set[40] and a ~= b and a ~= c and a ~= d and b ~= c and b ~= d and c ~= d)
check("C4. никто не остался на своём месте", a ~= 10 and b ~= 20 and c ~= 30 and d ~= 40)
check("C4. сидящий и погибший не тронуты", pF.Character.HumanoidRootPart.Position.X == 50 and pG.Character.HumanoidRootPart.Position.X == 60)
check("C4. скорость обнулена", pA.Character.HumanoidRootPart.AssemblyLinearVelocity.Y == 0)
-- повторяем много раз: всегда перестановка без дублей
local allGood = true
for i = 1, 200 do E.Stop(); E.Start(shuffleName); local x1, x2, x3, x4 = xs(); local s = {[x1] = true, [x2] = true, [x3] = true, [x4] = true}; if not (s[10] and s[20] and s[30] and s[40]) then allGood = false end end
check("C4. 200 перемешиваний подряд: всегда ровно те же 4 позиции", allGood)
resetWorld(); E = loadEvents(); loadedEvents = E; mkPlayer("solo", v3(1, 1, 1))
check("C4. один игрок: событие не стартует (false), без ошибок", E.Start(shuffleName) == false and E.GetCurrent() == nil)

-- Вьетнам
resetWorld(); E = loadEvents(); loadedEvents = E
local wsDescCalls = 0
local origGD = methods.GetDescendants
E.Start(vietnamName)
local bombs = {}; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "BombModel" then table.insert(bombs, c) end end
check("C5. первая волна: 3 бомбы на высоте 120", #bombs == 3 and bombs[1].PrimaryPart.Position.Y == 120)
local bomb = bombs[1]; local bp = bomb.PrimaryPart.Position
local near = mkPart("Wall", bp + v3(10, 0, 0), true); near.Parent = Workspace
local edge = mkPart("Wall2", bp + v3(49, 0, 0), true); edge.Parent = Workspace
local outside = mkPart("Wall3", bp + v3(51, 0, 0), true); outside.Parent = Workspace
local base = mkPart("Baseplate", bp + v3(5, 0, 0), true); base.Parent = Workspace
local loose = mkPart("Loose", bp + v3(5, 0, 0), false); loose.Parent = Workspace
local nearPos = near.Position
local hitter = mkPart("Hitter", bp, false); hitter.Parent = Workspace
bomb.PrimaryPart.Touched:Fire(hitter)
check("C5. части в радиусе 50 подняты, вне радиуса/исключённые/уже свободные не затронуты", not near.Anchored and not edge.Anchored and outside.Anchored and base.Anchored and not loose.Anchored)
local expl = nil; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.ClassName == "Explosion" then expl = c end end
check("C5. взрыв: радиус 50, давление 150000", expl and expl.BlastRadius == 50 and expl.BlastPressure == 150000)
local soundHolder = nil; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.ClassName == "Part" and c:FindFirstChild("RocketExplosionSound") then soundHolder = c end end
check("C5. звук взрыва в отдельной точке (не обрывается вместе с бомбой)", soundHolder ~= nil)
bomb.PrimaryPart.Touched:Fire(hitter)
local explCount = 0; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.ClassName == "Explosion" then explCount += 1 end end
check("C5. повторное касание не даёт второго взрыва", explCount == 1)
near.Position = v3(0, -300, 0) -- «упала» после взрыва
E.Stop(); runFor(2)
check("C5. Stop: части вернулись на место и заякорены", near.Anchored and near.Position.X == nearPos.X and edge.Anchored)
local bombsLeft = 0; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "BombModel" then bombsLeft += 1 end end
check("C5. Stop: все бомбы удалены", bombsLeft == 0)
runFor(30); bombsLeft = 0; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "BombModel" then bombsLeft += 1 end end
check("C5. после Stop новые бомбы не появляются", bombsLeft == 0)

-- Вьетнам: лес, лимиты, возврат обломков
print("--- C5b. Вьетнам: деревья и лимиты (мотивация: лаги от деревьев)")
resetWorld(); E = loadEvents(); loadedEvents = E
E.Start(vietnamName)
local forestBombs = {}; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "BombModel" then table.insert(forestBombs, c) end end
local fb = forestBombs[1]; local center = fb.PrimaryPart.Position
local treeParts, lightParts = {}, {}
for i = 1, 12 do -- 12 деревьев по 40 деталей, часть деталей во вложенной модели «Branches»
	local tree = newInst("Model", "Tree" .. i); tree.Parent = Workspace
	local branches = newInst("Model", "Branches"); branches.Parent = tree
	for j = 1, 40 do
		local p = mkPart("Leaf", center + v3(math.random(-20, 20), math.random(0, 15), math.random(-20, 20)), true)
		p.Parent = (j > 15) and branches or tree
		table.insert(treeParts, p)
	end
end
for i = 1, 90 do -- 90 заборов по 4 детали (лёгкие модели)
	local fence = newInst("Model", "Fence" .. i); fence.Parent = Workspace
	for j = 1, 4 do
		local p = mkPart("Plank", center + v3(math.random(-40, 40), 1, math.random(-40, 40)), true); p.Parent = fence; table.insert(lightParts, p)
	end
end
local hitter2 = mkPart("Hitter", center, false); hitter2.Parent = Workspace
fb.PrimaryPart.Touched:Fire(hitter2)
local treesUnanchored, lightUnanchored = 0, 0
for _, p in ipairs(treeParts) do if not p.Anchored then treesUnanchored += 1 end end
for _, p in ipairs(lightParts) do if not p.Anchored then lightUnanchored += 1 end end
check(("V1. деревья (480 деталей в моделях >20 деталей, с вложенными ветками) не тронуты: поднято %d"):format(treesUnanchored), treesUnanchored == 0)
check(("V2. лёгкие детали подняты, но не больше лимита на взрыв 120: поднято %d"):format(lightUnanchored), lightUnanchored == 120)
-- это именно ближайшие к центру?
local maxUp, minDown = 0, math.huge
for _, p in ipairs(lightParts) do local d = (p.Position - center).Magnitude; if not p.Anchored then maxUp = math.max(maxUp, d) else minDown = math.min(minDown, d) end end
check("V3. подняты ближайшие к центру детали", maxUp <= minDown + 1e-9)
-- глобальный лимит: серия взрывов в одном месте
local exploded = 1
for wave = 1, 4 do
	runFor(5)
	for _, c in ipairs(methods.GetChildren(Workspace)) do
		if c.Name == "BombModel" and c ~= fb and not rawget(c, "_p").boom then
			rawget(c, "_p").boom = true; c.PrimaryPart.Position = center; c.PrimaryPart.Touched:Fire(hitter2); exploded += 1
		end
	end
end
-- ещё света, чтобы было что поднимать
local moreLight = {}
for i = 1, 600 do local p = mkPart("Plank", center + v3(math.random(-45, 45), 1, math.random(-45, 45)), true); p.Parent = Workspace; table.insert(moreLight, p) end
for _, c in ipairs(methods.GetChildren(Workspace)) do
	if c.Name == "BombModel" and not rawget(c, "_p").boom then rawget(c, "_p").boom = true; c.PrimaryPart.Position = center; c.PrimaryPart.Touched:Fire(hitter2); exploded += 1 end
end
local activeNow = 0
for _, p in ipairs(lightParts) do if not p.Anchored then activeNow += 1 end end
for _, p in ipairs(moreLight) do if not p.Anchored then activeNow += 1 end end
check(("V4. после %d взрывов живых обломков не больше глобального лимита 500 (сейчас %d)"):format(exploded, activeNow), activeNow <= 500 and activeNow > 120)
-- возврат обломков через 10 с
local sample = lightParts[1]
for _, p in ipairs(lightParts) do if (p.Position - center).Magnitude < (sample.Position - center).Magnitude then sample = p end end
local samplePos = sample.Position -- ближайшая к центру: поднята первым взрывом наверняка
sample.Position = v3(0, -100, 0)
runFor(30)
local stillUp = 0
for _, p in ipairs(lightParts) do if not p.Anchored then stillUp += 1 end end
for _, p in ipairs(moreLight) do if not p.Anchored then stillUp += 1 end end
check(("V5. через %d с все обломки вернулись на место и заякорены (осталось свободных: %d)"):format(30, stillUp), stillUp == 0 and sample.Anchored and sample.Position.X == samplePos.X and sample.Position.Y == samplePos.Y)
-- Stop возвращает сразу
local another = nil; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "BombModel" and not rawget(c, "_p").boom then another = c end end
if another then another.PrimaryPart.Position = center; another.PrimaryPart.Touched:Fire(hitter2) end
local upBeforeStop = 0; for _, p in ipairs(lightParts) do if not p.Anchored then upBeforeStop += 1 end end
E.Stop()
local upAfterStop = 0; for _, p in ipairs(lightParts) do if not p.Anchored then upAfterStop += 1 end end
check(("V6. Stop сразу возвращает всё (было свободных %d, стало %d)"):format(upBeforeStop, upAfterStop), upBeforeStop > 0 and upAfterStop == 0)

-- Нексбот (кинематический)
print("--- C6. Нексбот (собственное движение без гуманоида)")
local function flat10() return 10 end
local function botOf() return Workspace:FindFirstChild("Nexbot") end
local function dist2d(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

resetWorld(); E = loadEvents(); loadedEvents = E; groundFn = flat10
check("N0. нет игроков: Нексбот не стартует, бот не остаётся в мире", E.Start(nexbotName) == false and botOf() == nil)
local solo = mkPlayer("Solo", v3(0, 13, 0))
ServerStorage:FindFirstChild("Nexbot").Parent = nil
check("N0. нет шаблона Nexbot -> false без ошибки", E.Start(nexbotName) == false)

resetWorld(); E = loadEvents(); loadedEvents = E; groundFn = flat10; startHeartbeat()
local victim = mkPlayer("Victim", v3(0, 13, 0))
check("N1. Нексбот запущен", E.Start(nexbotName) == true)
local bot = botOf(); local hrp = bot.HumanoidRootPart
check("N2. гуманоид удалён, куб заякорен и не сталкивается с игроками/лучами", bot:FindFirstChildOfClass("Humanoid") == nil and hrp.Anchored == true and hrp.CanCollide == false and hrp.CanTouch == false and hrp.CanQuery == false)
check("N3. появился в 50 студах перед игроком, на высоте земля+4", math.abs(dist2d(hrp.Position, victim.Character.HumanoidRootPart.Position) - 50) < 0.5 and math.abs(hrp.Position.Y - 14) < 0.01)
-- гонка на дальнюю дистанцию
victim.Character.HumanoidRootPart.Position = v3(500, 13, 0)
local startPos = hrp.Position
local firstDist = dist2d(startPos, victim.Character.HumanoidRootPart.Position)
local maxStep, last = 0, hrp.Position
local diedAt = nil
for i = 1, 70 do
	runFor(0.1)
	local p = hrp.Position
	if i % 10 == 0 then maxStep = math.max(maxStep, dist2d(p, last)); last = p end
	if not diedAt and victim.Character.Humanoid.Health <= 0 then diedAt = i * 0.1 end
	if i == 10 then
		check(("N4. за 1 с бот пробегает ≈100 студов (пробежал %.1f)"):format(dist2d(startPos, p)), math.abs(dist2d(startPos, p) - 100) < 3)
	end
end
check(("N5. скорость не больше 100 студов/с (макс. путь за 1 с = %.1f, допуск один кадр)"):format(maxStep), maxStep <= 101.8)
local expected = (firstDist - 5) / 100
check(("N6. игрок убит в ожидаемое время (≈%.1f с, убит на %.1f с)"):format(expected, diedAt or -1), diedAt and math.abs(diedAt - expected) < 0.35)
local posAfterKill = hrp.Position
runFor(3)
check("N7. когда живых нет, бот стоит на месте и ничего не ломается", dist2d(hrp.Position, posAfterKill) < 0.001)
-- возрождение: новый персонаж снова становится целью
local oldChar = victim.Character
local newHrp = mkPart("HumanoidRootPart", v3(120, 13, 0)); local newHum = newInst("Humanoid"); newHum.Health = 100
local newChar = newInst("Model", "Victim_char2"); newHrp.Parent = newChar; newHum.Parent = newChar; rawget(newChar, "_p").PrimaryPart = newHrp
victim.Character = newChar
runFor(5)
check("N8. после возрождения игрока бот находит и убивает его снова", newHum.Health <= 0)
E.Stop()

-- скачок лага
resetWorld(); E = loadEvents(); loadedEvents = E; groundFn = flat10
local lagVictim = mkPlayer("Lag", v3(0, 13, 0)); E.Start(nexbotName); bot = botOf(); hrp = bot.HumanoidRootPart
lagVictim.Character.HumanoidRootPart.Position = v3(2000, 13, 0)
local before = hrp.Position; heartbeat:Fire(5)
check(("N9. скачок лага (dt=5 с) не телепортирует бота: сдвиг %.1f студов, не больше 10"):format((hrp.Position - before).Magnitude), (hrp.Position - before).Magnitude <= 10.2)
E.Stop()

-- рельеф: холм
resetWorld(); E = loadEvents(); loadedEvents = E; startHeartbeat()
groundFn = function(x, z) if x >= 200 then return 40 end return 10 end
local hillVictim = mkPlayer("Hill", v3(0, 13, 0)); E.Start(nexbotName); bot = botOf(); hrp = bot.HumanoidRootPart
hillVictim.Character.HumanoidRootPart.Position = v3(700, 13, 0)
local maxVert, lastY, belowGround = 0, hrp.Position.Y, false
local yBefore = hrp.Position.Y
for i = 1, 40 do
	runFor(0.1); local y = hrp.Position.Y
	maxVert = math.max(maxVert, math.abs(y - lastY)); lastY = y
	if hrp.Position.X >= 200 and y < 40 + 4 - 4.5 and i > 30 then belowGround = true end
end
check(("N10. бот поднимается на холм плавно (макс. изменение высоты за 0.1 с = %.2f, лимит 8.0) и держится над землёй"):format(maxVert), maxVert <= 8.2 and lastY > 43 and lastY < 45 and not belowGround and yBefore < 15)
E.Stop(); groundFn = flat10

-- убийство и вертикаль
resetWorld(); E = loadEvents(); loadedEvents = E; groundFn = flat10; startHeartbeat()
local vk = mkPlayer("Vk", v3(0, 13, 0)); E.Start(nexbotName); bot = botOf(); hrp = bot.HumanoidRootPart
local spot = hrp.Position
local high = mkPlayer("High", spot + v3(0, 12, 0)); local low = mkPlayer("Low", spot + v3(3, 4, 0))
vk.Character.HumanoidRootPart.Position = v3(5000, 13, 0); high.Character.HumanoidRootPart.Position = spot + v3(0, 12, 0)
-- чтобы бот не уходил к дальним, держим игроков рядом: High прямо над ботом на 12 студов, Low рядом
runFor(0.2)
check("N11. игрок выше 10 студов над ботом не убит, игрок рядом убит (вертикальный допуск)", high.Character.Humanoid.Health > 0 and low.Character.Humanoid.Health <= 0)
local function banners(pl) local g = pl:FindFirstChild("PlayerGui"); return g and #methods.GetChildren(g) or -1 end
check("N12. баннер «БЫЛ ЗАДАВЛЕН» показан всем с PlayerGui (по одному на убийство)", banners(vk) == 1 and banners(high) == 1 and banners(low) == 1)
local bg = methods.GetChildren(low:FindFirstChild("PlayerGui"))[1]
check("N12. текст баннера", bg and bg:FindFirstChild("TextLabel").Text == "LOW БЫЛ ЗАДАВЛЕН")
runFor(0.5)
check("N13. мёртвый игрок не плодит баннеров повторно", banners(vk) == 1 and banners(low) == 1 or banners(low) == 1)
E.Stop()

-- гистерезис цели
resetWorld(); E = loadEvents(); loadedEvents = E; groundFn = flat10; startHeartbeat()
local pa = mkPlayer("A", v3(0, 13, 0)); E.Start(nexbotName); bot = botOf(); hrp = bot.HumanoidRootPart
local bp0 = hrp.Position
local pb = mkPlayer("B", v3(-300, 13, 0)); pa.Character.HumanoidRootPart.Position = bp0 + v3(300, -1, 0)
runFor(0.1) -- выбрали A (B дальше или равен); теперь B становится чуть ближе, но не на 25%
pb.Character.HumanoidRootPart.Position = bp0 + v3(-(hrp.Position.X - bp0.X) - 270, -1, 0) + v3(hrp.Position.X - bp0.X, 0, 0)
pb.Character.HumanoidRootPart.Position = hrp.Position + v3(-270, -1, 0)
runFor(1)
check("N14. бот не мечется между двумя почти равноудалёнными игроками (держит цель)", hrp.Position.X > bp0.X + 50)
E.Stop()

-- толчок предметов и очистка
resetWorld(); E = loadEvents(); loadedEvents = E; groundFn = flat10
local pp = mkPlayer("P", v3(0, 13, 0)); E.Start(nexbotName); bot = botOf(); hrp = bot.HumanoidRootPart; local bp = hrp.Position
local far = mkPart("FarLoose", bp + v3(100, 0, 0), false); far.Parent = Workspace
local l1 = mkPart("LooseA", bp + v3(5, 0, 0), false); l1.Parent = Workspace
local l2 = mkPart("LooseB", bp + v3(5, 0, 1), false); l2.Parent = Workspace
rawget(l1, "_p").AssemblyRootPart = l1; rawget(l2, "_p").AssemblyRootPart = l1
runFor(0.1)
check("N15. толчок: сборка из 2 деталей получила ОДИН толчок 120, далёкие предметы не тронуты", math.abs(l1.AssemblyLinearVelocity.Magnitude + l2.AssemblyLinearVelocity.Magnitude - 120) < 0.1 and far.AssemblyLinearVelocity.Magnitude == 0)
check("N16. один обработчик Heartbeat", #heartbeat.handlers == 1)
E.Start(nexbotName)
local nb = 0; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "Nexbot" then nb += 1 end end
check("N17. повторный запуск: один бот и один обработчик Heartbeat", nb == 1 and #heartbeat.handlers == 1)
E.Stop(); runFor(0.5)
check("N18. Stop: бот удалён, обработчик Heartbeat снят", botOf() == nil and #heartbeat.handlers == 0)
local finaleHolder = nil; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.ClassName == "Part" and c:FindFirstChild("End") then finaleHolder = c end end
check("N19. финальный звук End проигран отдельно от бота", finaleHolder ~= nil and finaleHolder:FindFirstChild("End").IsPlaying == true)

