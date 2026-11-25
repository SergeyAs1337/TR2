do
print("--- W. Нексбот: стены")
local function flat10() return 10 end
local function setupBot(victimPos, buildWorld)
	resetWorld(); local E = loadEvents(); loadedEvents = E; groundFn = flat10; pathFn = nil; pathCalls = 0; pathDelay = 0.05
	startHeartbeat()
	local victim = mkPlayer("Victim", v3(0, 13, 0))
	if buildWorld then buildWorld() end
	E.Start(E.List[6].Name)
	local bot = Workspace:FindFirstChild("Nexbot")
	victim.Character.HumanoidRootPart.Position = victimPos
	return E, bot, bot.HumanoidRootPart, victim
end
local function hpOf(v) return v.Character.Humanoid.Health end

-- W1: упирается в стену, игрок за тонкой стеной не убит
local E, bot, hrp, victim = setupBot(v3(101, 13, -50), function() mkWall("Wall", v3(100, 25, -50), v3(0.4, 30, 40)) end)
runFor(3)
check(("W1. бот упёрся в стену и стоит у неё (x=%.2f, стена с x=99.8)"):format(hrp.Position.X), hrp.Position.X < 99.8 and hrp.Position.X > 97.5)
check("W1. игрок за тонкой стеной в 2.8 студах НЕ убит (нет прямой видимости)", hpOf(victim) > 0)
E.Stop()

-- W2: обход через PathfindingService, ни одного кадра внутри стены
local wallMin, wallMax = v3(99.8, 10, -70), v3(100.2, 40, -30)
local function insideWall(p) return p.X > wallMin.X and p.X < wallMax.X and p.Z > wallMin.Z and p.Z < wallMax.Z and p.Y > wallMin.Y and p.Y < wallMax.Y end
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Wall", v3(100, 25, -50), v3(0.4, 30, 40)) end)
pathFn = function(from, to) return {{Position = from, Action = "Walk"}, {Position = v3(98, 14, -25), Action = "Walk"}, {Position = v3(102, 14, -25), Action = "Walk"}, {Position = to, Action = "Walk"}} end
local clipped, diedAt = false, nil
for i = 1, 60 * 6 do
	runFor(1 / 60)
	if insideWall(hrp.Position) then clipped = true end
	if not diedAt and hpOf(victim) <= 0 then diedAt = i / 60 end
end
check(("W2. бот обошёл стену по пути и убил игрока (за %.1f с)"):format(diedAt or -1), diedAt ~= nil and diedAt < 5)
check("W2. ни в одном кадре бот не оказался внутри стены", not clipped)
check(("W2. путь запрошен немного раз (%d), а не каждый кадр"):format(pathCalls), pathCalls >= 1 and pathCalls <= 3)
E.Stop()

-- W3: скольжение вдоль длинной стены
E, bot, hrp, victim = setupBot(v3(200, 13, 50), function() mkWall("LongWall", v3(100, 25, 0), v3(0.4, 30, 2000)) end)
local z0 = hrp.Position.Z
runFor(4)
check(("W3. бот скользит вдоль стены к цели: z %.0f → %.0f, x=%.1f"):format(z0, hrp.Position.Z, hrp.Position.X), hrp.Position.Z > 40 and hrp.Position.Z < 60 and hrp.Position.X < 99.8)
E.Stop()

-- W4: низкий бордюр (2 студа) не останавливает и не вызывает прыжка
local maxY = 0
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Curb", v3(100, 11, -50), v3(0.4, 2, 200)) end)
for i = 1, 40 do runFor(0.1); maxY = math.max(maxY, hrp.Position.Y) end
check("W4. низкий бордюр: бот переступает, без прыжка, игрок убит", hpOf(victim) <= 0 and maxY < 15 and bot.Sounds.Jump.PlayCount == nil)
E.Stop()

-- W5: пандус (пологая поверхность) не считается стеной
maxY = 0
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Ramp", v3(100, 25, -50), v3(0.4, 30, 200), {RampNormal = v3(-0.6, 0.8, 0)}) end)
for i = 1, 40 do runFor(0.1); maxY = math.max(maxY, hrp.Position.Y) end
check("W5. пологая поверхность не считается стеной: бот идёт дальше", hpOf(victim) <= 0)
E.Stop()

-- W6: незаякоренное (машина, ящик) не преграда
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Truck", v3(100, 25, -50), v3(6, 30, 200), {Anchored = false}) end)
runFor(4)
check("W6. незаякоренный объект бот не останавливает (расталкивает)", hpOf(victim) <= 0)
E.Stop()

-- W7: место появления занято зданием, бот появляется рядом, а не внутри
E, bot, hrp, victim = setupBot(v3(0, 13, 0), function() mkWall("Building", v3(0, 25, -50), v3(30, 30, 30)) end)
local p = hrp.Position
local insideBuilding = p.X > -16.5 and p.X < 16.5 and p.Z > -66.5 and p.Z < -33.5
check(("W7. при занятом месте бот появляется рядом, не внутри здания (%.0f, %.0f)"):format(p.X, p.Z), not insideBuilding and math.abs(math.sqrt(p.X ^ 2 + p.Z ^ 2) - 50) < 0.5)
E.Stop()

-- W8: не засыпает PathfindingService запросами
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("LongWall", v3(100, 25, 0), v3(0.4, 30, 2000)) end)
runFor(10)
check(("W8. без пути бот стоит у стены, запросов пути за 10 с: %d (лимит раз в секунду)"):format(pathCalls), pathCalls >= 5 and pathCalls <= 11 and hrp.Position.X < 99.8)
E.Stop()

-- W9: Stop во время ожидания пути не ломает ничего
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("LongWall", v3(100, 25, 0), v3(0.4, 30, 2000)) end)
pathDelay = 5; pathFn = function(from, to) return {{Position = from, Action = "Walk"}, {Position = to, Action = "Walk"}} end
runFor(1)
E.Stop(); runFor(10)
check("W9. Stop во время расчёта пути: бот удалён, обработчик снят, без ошибок", Workspace:FindFirstChild("Nexbot") == nil and #heartbeat.handlers == 0)

print("--- J. Нексбот: прыжки")
-- J1: дуга прыжка через 4-студовый забор
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Fence", v3(100, 12, -50), v3(0.4, 4, 200)) end)
local maxY2, risenAt, landedAt, minXWhenLow = 0, nil, nil, math.huge
local crossedLow = false
for i = 1, 60 * 3 do
	runFor(1 / 60)
	local y = hrp.Position.Y
	maxY2 = math.max(maxY2, y)
	if not risenAt and y > 14.5 then risenAt = i / 60 end
	if risenAt and not landedAt and y <= 14.01 and i / 60 > risenAt + 0.1 then landedAt = i / 60 end
	-- внутри забора (x в пределах стены ± радиус) бот обязан быть выше его верха (14) + радиус тела
	if hrp.Position.X > 98.4 and hrp.Position.X < 101.6 and y < 15.4 then crossedLow = true end
end
check(("J1. прыжок через забор: пик %.1f (ожидаем ≈26 = 14+12)"):format(maxY2), maxY2 > 25 and maxY2 < 27)
check(("J1. дуга ≈0.7 с (взлёт→посадка %.2f с)"):format((landedAt or 0) - (risenAt or 0)), landedAt and math.abs((landedAt - risenAt) - 0.7) < 0.12)
check("J1. над забором бот всегда выше его верха (не проходит сквозь)", not crossedLow)
check("J1. игрок убит после перепрыгивания", hpOf(victim) <= 0)
check("J1. прыжок один (звук Jump сыгран раз)", bot.Sounds.Jump.PlayCount == 1)
E.Stop()

-- J2: два забора подряд за один прыжок
E, bot, hrp, victim = setupBot(v3(300, 13, -50), function()
	mkWall("Fence1", v3(100, 12, -50), v3(0.4, 4, 200)); mkWall("Fence2", v3(130, 12, -50), v3(0.4, 4, 200)) end)
runFor(5)
check("J2. два забора за 30 студов перепрыгнуты одним прыжком, игрок убит", hpOf(victim) <= 0 and bot.Sounds.Jump.PlayCount == 1)
E.Stop()

-- J3: слишком высокая стена не перепрыгивается
maxY2 = 0
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Tall", v3(100, 40, -50), v3(0.4, 60, 200)) end)
for i = 1, 30 do runFor(0.1); maxY2 = math.max(maxY2, hrp.Position.Y) end
check("J3. стена выше прыжка: бот не прыгает и стоит перед ней", bot.Sounds.Jump.PlayCount == nil and maxY2 < 15 and hrp.Position.X < 99.8)
E.Stop()

-- J4: точка обхода с прыжком
maxY2 = 0
E, bot, hrp, victim = setupBot(v3(200, 13, -50), function() mkWall("Wall", v3(100, 25, -50), v3(0.4, 30, 40)) end)
pathFn = function(from, to) return {{Position = from, Action = "Walk"}, {Position = v3(98, 14, -25), Action = "Walk"}, {Position = v3(102, 14, -25), Action = "Jump"}, {Position = to, Action = "Walk"}} end
for i = 1, 60 * 5 do runFor(1 / 60); maxY2 = math.max(maxY2, hrp.Position.Y) end
check(("J4. точка обхода с Action=Jump: бот прыгает (пик %.1f) и доходит"):format(maxY2), maxY2 > 20 and hpOf(victim) <= 0 and bot.Sounds.Jump.PlayCount >= 1)
E.Stop()

-- J5: на ровной земле без препятствий не прыгает
maxY2 = 0
E, bot, hrp, victim = setupBot(v3(400, 13, -50), nil)
for i = 1, 30 do runFor(0.1); maxY2 = math.max(maxY2, hrp.Position.Y) end
check("J5. на открытой земле бот не прыгает", bot.Sounds.Jump.PlayCount == nil and maxY2 < 14.5)
E.Stop()
end
