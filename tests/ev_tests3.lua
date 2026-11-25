do
print("--- S. AdminService")
local function addStats(p, coins, deaths)
	local ls = newInst("Folder", "leaderstats"); ls.Parent = p
	local c = newInst("IntValue", "Coins"); c.Value = coins; c.Parent = ls
	local d = newInst("IntValue", "Deaths"); d.Value = deaths; d.Parent = ls
end
local function coinsOf(p) return p:FindFirstChild("leaderstats"):FindFirstChild("Coins").Value end
local ADMIN2 = 3322927329
local function setup(strict)
	resetWorld(); local E = loadEvents(); loadedEvents = E
	local log = {}
	local function fake(name) return {Name = name, Start = function() table.insert(log, "start:" .. name) return true end, Stop = function() table.insert(log, "stop:" .. name) end} end
	E.List = {fake("Alpha"), fake("Beta")}
	filterMode = "pass"
	local resetRemote = newInst("RemoteEvent", "ResetPlayerStatsAdminEvent"); resetRemote.OnServerEvent = Signal(); resetRemote.Parent = ReplicatedStorage
	local admin = mkPlayer("Admin", v3(0, 13, 0)); admin.UserId = 940118285
	local alice = mkPlayer("Alice", v3(10, 13, 0)); alice.UserId = 1001
	local bob = mkPlayer("Bob", v3(20, 13, 0)); bob.UserId = 1002
	addStats(admin, 100, 1); addStats(alice, 500, 7); addStats(bob, 50, 0)
	if strict then runAdminServiceStrict() else runAdminService() end
	local req = ReplicatedStorage:FindFirstChild("AdminRequest")
	return E, admin, alice, bob, req.OnServerInvoke, log, resetRemote
end

-- S1 не админ
local E, admin, alice, bob, call, log = setup()
local st = call(alice, "state")
check("S1. не админ: state = {isAdmin=false}, данных нет", type(st) == "table" and st.isAdmin == false and st.players == nil)
local ok, msg = call(alice, "action", "giveCoins", {target = 1001, amount = 999})
check("S1. не админ: действие отклонено, монеты не тронуты", ok == false and msg == "Нет доступа" and coinsOf(alice) == 500)

-- S2 состояние
st = call(admin, "state")
check("S2. state: админ, 3 игрока по алфавиту", st.isAdmin == true and #st.players == 3 and st.players[1].name == "Admin" and st.players[2].name == "Alice" and st.players[3].name == "Bob")
check("S2. state: монеты/смерти/здоровье игрока", st.players[2].coins == 500 and st.players[2].deaths == 7 and st.players[2].health == 100 and st.players[2].isAdmin == false and st.players[1].isAdmin == true)
check("S2. state: события, нет текущего, случайные включены, версия, время работы", #st.events == 2 and st.currentEvent == nil and st.randomEnabled == true and st.server.players == 3 and st.server.placeVersion == 42 and st.server.jobId == "abcdef01" and st.server.uptime == 123)

-- S3 события
ok, msg = call(admin, "action", "startEvent", {name = "Alpha", duration = 1})
st = call(admin, "state")
check("S3. запуск события: длительность 1 поднята до минимума 5 с, видно в state", ok == true and st.currentEvent == "Alpha" and st.eventEndsAt == st.serverTime + 5)
ok = call(admin, "action", "startEvent", {name = "Beta", duration = 99999}); st = call(admin, "state")
check("S3. Beta вытесняет Alpha; длительность ограничена 3600 с", ok and st.currentEvent == "Beta" and st.eventEndsAt == st.serverTime + 3600 and log[#log - 1] == "stop:Alpha")
ok = call(admin, "action", "startEvent", {name = "Beta"}); st = call(admin, "state")
check("S3. без длительности: до ручной остановки (endsAt = nil)", ok and st.eventEndsAt == nil)
check("S3. неизвестное/неверное имя события отклонено", call(admin, "action", "startEvent", {name = "Nope"}) == false and call(admin, "action", "startEvent", {name = 123}) == false and call(admin, "action", "startEvent", {}) == false)
check("S3. остановка", call(admin, "action", "stopEvent") == true and call(admin, "state").currentEvent == nil)
ok, msg = call(admin, "action", "stopEvent")
check("S3. остановка без события -> false", ok == false)
call(admin, "action", "setRandomEvents", {enabled = false})
check("S3. случайные события выключаются и видны в state", E.IsRandomEnabled() == false and call(admin, "state").randomEnabled == false)
check("S3. setRandomEvents с не-boolean отклонён", call(admin, "action", "setRandomEvents", {enabled = "yes"}) == false and E.IsRandomEnabled() == false)
call(admin, "action", "setRandomEvents", {enabled = true})

-- S4 монеты
ok = call(admin, "action", "giveCoins", {target = 1001, amount = 250})
check("S4. выдача по UserId", ok and coinsOf(alice) == 750)
ok = call(admin, "action", "giveCoins", {target = "ALICE", amount = 50})
check("S4. выдача по имени без учёта регистра", ok and coinsOf(alice) == 800)
ok = call(admin, "action", "giveCoins", {target = "bo", amount = 5})
check("S4. однозначное начало имени", ok and coinsOf(bob) == 55)
ok = call(admin, "action", "giveCoins", {target = "a", amount = 5})
check("S4. неоднозначное имя (Admin/Alice) отклонено", ok == false and coinsOf(alice) == 800)
local before = coinsOf(alice)
local badAmounts = {0, -5, 1.5, 0 / 0, 1e12, math.huge, "100", true, {}}
local allRejected = true
for _, a in ipairs(badAmounts) do if call(admin, "action", "giveCoins", {target = 1001, amount = a}) ~= false then allRejected = false end end
if call(admin, "action", "giveCoins", {target = 1001}) ~= false then allRejected = false end
check("S4. мусорные суммы (0, <0, дробные, NaN, 1e12, inf, строка, bool, таблица, nil) отклонены", allRejected and coinsOf(alice) == before)
check("S4. неизвестный игрок / не число / таблица как цель", call(admin, "action", "giveCoins", {target = 777, amount = 5}) == false and call(admin, "action", "giveCoins", {target = {}, amount = 5}) == false and call(admin, "action", "giveCoins", {target = true, amount = 5}) == false)
local loading = mkPlayer("Loading", v3(0, 13, 0)); loading.UserId = 1003
ok, msg = call(admin, "action", "giveCoins", {target = 1003, amount = 5})
check("S4. данные ещё грузятся (нет leaderstats) -> понятный отказ", ok == false and msg == "Данные игрока ещё загружаются")
ok = call(admin, "action", "setCoins", {target = 1001, amount = 0})
check("S4. установить 0 монет", ok and coinsOf(alice) == 0)
ok = call(admin, "action", "setCoins", {target = 1001, amount = 123456})
check("S4. установить 123456", ok and coinsOf(alice) == 123456)
check("S4. setCoins: отрицательные/дробные/слишком большие отклонены", call(admin, "action", "setCoins", {target = 1001, amount = -1}) == false and call(admin, "action", "setCoins", {target = 1001, amount = 2.5}) == false and call(admin, "action", "setCoins", {target = 1001, amount = 2e12}) == false and coinsOf(alice) == 123456)
call(admin, "action", "setCoins", {target = 1001, amount = 999999999999}); call(admin, "action", "giveCoins", {target = 1001, amount = 1000000000})
check("S4. итоговая сумма ограничена потолком 1e12", coinsOf(alice) == 1000000000000)

-- S5 здоровье
bob.Character.Humanoid.Health = 10
ok = call(admin, "action", "heal", {target = 1002})
check("S5. лечение игрока", ok and bob.Character.Humanoid.Health == 100)
bob.Character.Humanoid.Health = 5; alice.Character.Humanoid.Health = 5
local noChar = mkPlayer("Ghost", v3(0, 0, 0), {noCharacter = true}); noChar.UserId = 1004
ok, msg = call(admin, "action", "heal", {all = true})
check("S5. лечить всех: вылечены живые (админ, Alice, Bob, Loading), без персонажа пропущен", ok and bob.Character.Humanoid.Health == 100 and alice.Character.Humanoid.Health == 100 and msg:find("4") ~= nil)
ok = call(admin, "action", "kill", {target = 1002})
check("S5. убить", ok and bob.Character.Humanoid.Health == 0)
check("S5. вылечить мёртвого / игрока без персонажа / убить без персонажа -> false", call(admin, "action", "heal", {target = 1002}) == false and call(admin, "action", "heal", {target = 1004}) == false and call(admin, "action", "kill", {target = 1004}) == false)

-- S6 заморозка
ok = call(admin, "action", "freeze", {target = 1001, frozen = true})
check("S6. заморозка: HRP заякорен, атрибут и state", ok and alice.Character.HumanoidRootPart.Anchored == true and call(admin, "state").players[2].frozen == true)
alice.CharacterAdded:Fire()
check("S6. после возрождения заморозка снимается в state", call(admin, "state").players[2].frozen == false)
call(admin, "action", "freeze", {target = 1001, frozen = true}); call(admin, "action", "freeze", {target = 1001, frozen = false})
check("S6. разморозка", alice.Character.HumanoidRootPart.Anchored == false)

-- S7 телепорт
local bobPos = bob.Character.HumanoidRootPart.Position
ok = call(admin, "action", "bring", {target = 1002})
local p = bob.Character.HumanoidRootPart.Position
check(("S7. bring: Bob рядом с админом (%.0f,%.0f,%.0f), скорость обнулена"):format(p.X, p.Y, p.Z), ok and p.X == 0 and p.Z == -4 and bob.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude == 0)
ok = call(admin, "action", "teleportTo", {target = 1001})
p = admin.Character.HumanoidRootPart.Position
check(("S7. teleportTo: админ рядом с Alice (%.0f,%.0f,%.0f)"):format(p.X, p.Y, p.Z), ok and p.X == 10 and p.Z == 4)
check("S7. телепорт без персонажа у цели -> false", call(admin, "action", "teleportTo", {target = 1004}) == false and call(admin, "action", "bring", {target = 1004}) == false)

-- S8 кик
local admin2 = mkPlayer("Admin2", v3(0, 13, 0)); admin2.UserId = ADMIN2
ok = call(admin, "action", "kick", {target = 1002, reason = "спам"})
check("S8. кик с причиной", ok and bob.kicked == "спам")
check("S8. себя и других админов кикать нельзя", call(admin, "action", "kick", {target = 940118285}) == false and call(admin, "action", "kick", {target = ADMIN2}) == false and admin.kicked == nil and admin2.kicked == nil)
call(admin, "action", "kick", {target = 1001})
check("S8. причина по умолчанию", alice.kicked == "Вы были исключены администратором.")
call(admin, "action", "kick", {target = 1003, reason = string.rep("я", 500)})
check("S8. слишком длинная причина обрезается (≤100 байт)", #loading.kicked <= 100)
check("S8. кик без цели -> false", call(admin, "action", "kick", {}) == false)

-- S9 объявление
announced = {}
ok = call(admin, "action", "announce", {message = "  Привет всем  "})
check("S9. объявление: обрезаны пробелы, добавлен префикс 📢, отправлено всем", ok and announced[#announced] == "📢 Привет всем")
filterMode = "censor"; call(admin, "action", "announce", {message = "this is bad"})
check("S9. текст проходит фильтр (bad → ###)", announced[#announced] == "📢 this is ###")
filterMode = "error"; local nBefore = #announced
ok = call(admin, "action", "announce", {message = "hello"})
check("S9. фильтр недоступен -> не отправляем", ok == false and #announced == nBefore)
filterMode = "pass"
check("S9. пустое / только пробелы / не строка / слишком длинное отклонены", call(admin, "action", "announce", {message = ""}) == false and call(admin, "action", "announce", {message = "   "}) == false and call(admin, "action", "announce", {message = 5}) == false and call(admin, "action", "announce", {message = string.rep("a", 151)}) == false and call(admin, "action", "announce", {message = string.rep("я", 151)}) == false and #announced == nBefore)
check("S9. ровно 150 символов проходят", call(admin, "action", "announce", {message = string.rep("я", 150)}) == true)

-- S10 мусор в запросах
check("S10. неизвестный kind -> nil, неизвестное действие -> false", call(admin, "nonsense") == nil and call(admin, "action", "dropDatabase") == false and call(admin, "action", nil) == false and call(admin, "action", "__index") == false and call(admin, "action", 5) == false)
check("S10. args не таблица -> безопасный отказ", call(admin, "action", "startEvent", "строка") == false and call(admin, "action", "kill", 5) == false)

-- S11 журнал
local E2, admin_, alice_, bob_, call2 = setup()
call2(admin_, "action", "giveCoins", {target = 1001, amount = 10}); call2(admin_, "action", "setRandomEvents", {enabled = false})
st = call2(admin_, "state")
check("S11. журнал: новые сверху, видно кто и что", #st.log == 2 and st.log[1].text == "выключил случайные события" and st.log[2].text == "выдал 10 монет игроку Alice" and st.log[1].admin == "Admin")
for i = 1, 80 do call2(admin_, "action", "setRandomEvents", {enabled = (i % 2 == 0)}) end
st = call2(admin_, "state")
check("S11. журнал ограничен: клиенту отдаётся не больше 40 записей, самые свежие", #st.log == 40)
-- сброс статистики: только запись в журнал
local resetRemote = ReplicatedStorage:FindFirstChild("ResetPlayerStatsAdminEvent")
resetRemote.OnServerEvent:Fire(admin_, "Alice"); resetRemote.OnServerEvent:Fire(alice_, "Bob")
st = call2(admin_, "state")
check("S11. сброс статистики админом попадает в журнал, не админом нет", st.log[1].text == "сбросил статистику игроку Alice" and st.log[2].text ~= "сбросил статистику игроку Bob")

-- S12 старые RemoteEvent-ы (совместимость со старым GUI)
local E3, adm, al, bo, call3 = setup()
local oldStart = ReplicatedStorage:FindFirstChild("EventAnnouncement"); local oldStop = ReplicatedStorage:FindFirstChild("StopEventRemote")
oldStart.OnServerEvent:Fire(al, "Alpha", 30); runFor(1)
check("S12. старый GUI: не админ не запускает", E3.GetCurrent() == nil)
oldStart.OnServerEvent:Fire(adm, "Alpha", 30); runFor(1)
check("S12. старый GUI: админ запускает событие с длительностью", E3.GetCurrent() == "Alpha")
oldStop.OnServerEvent:Fire(adm, "Beta"); runFor(1)
check("S12. старый GUI: остановка чужого имени ничего не делает", E3.GetCurrent() == "Alpha")
oldStop.OnServerEvent:Fire(al, "Alpha"); runFor(1)
check("S12. старый GUI: не админ не останавливает", E3.GetCurrent() == "Alpha")
oldStop.OnServerEvent:Fire(adm, "Alpha"); runFor(1)
check("S12. старый GUI: админ останавливает", E3.GetCurrent() == nil)
oldStart.OnServerEvent:Fire(adm, 123, 5); oldStart.OnServerEvent:Fire(adm, {}, 5); oldStop.OnServerEvent:Fire(adm, {})
check("S12. старый GUI: мусорные аргументы игнорируются", E3.GetCurrent() == nil)

-- S13 ошибка при построении состояния не роняет сервис
local E4, adm4, _, _, call4 = setup()
E4.GetInfo = function() error("boom") end
check("S13. ошибка внутри state -> nil, без падения; действия продолжают работать", call4(adm4, "state") == nil and call4(adm4, "action", "setRandomEvents", {enabled = true}) == true)

-- S14 лимит запросов (настоящее значение 8/с)
local E5, adm5, _, _, call5 = setup(true)
local okCount, limited = 0, 0
for i = 1, 30 do local ok, msg = call5(adm5, "action", "setRandomEvents", {enabled = true}); if ok then okCount += 1 elseif msg:find("часто") then limited += 1 end end
check(("S14. лимит запросов: из 30 мгновенных прошло %d (≈8), отклонено %d"):format(okCount, limited), okCount >= 8 and okCount <= 10 and limited >= 20)
check("S14. state при превышении лимита -> nil", call5(adm5, "state") == nil)

print("--- E. Events: информация и случайные события")
resetWorld(); local EV = loadEvents(); loadedEvents = EV
local lg = {}
local function fk(name) return {Name = name, Start = function() table.insert(lg, name) return true end, Stop = function() end} end
EV.List = {fk("A"), fk("B")}
check("E1. по умолчанию случайные включены, времени следующего нет", EV.IsRandomEnabled() == true and EV.GetNextRandomAt() == nil)
EV.Start("A", 30); local info = EV.GetInfo()
check("E2. GetInfo: имя и серверное время окончания", info.name == "A" and info.endsAt == Workspace:GetServerTimeNow() + 30)
EV.Stop(); info = EV.GetInfo()
check("E2. после остановки пусто", info.name == nil and info.endsAt == nil)
EV.Start("A"); check("E2. без длительности endsAt = nil", EV.GetInfo().endsAt == nil); EV.Stop()

-- контроллер: выключатель и время следующего события
resetWorld(); EV = loadEvents(); loadedEvents = EV; lg = {}
EV.List = {fk("A"), fk("B")}; mkPlayer("p", v3(0, 0, 0))
task.spawn(runController)
local nxt = EV.GetNextRandomAt()
check(("E3. контроллер публикует время следующего события (через %.0f с, в пределах 240–360)"):format(nxt or -1), nxt and nxt - Workspace:GetServerTimeNow() >= 240 and nxt - Workspace:GetServerTimeNow() <= 360)
EV.SetRandomEnabled(false); runFor(1000)
check("E4. при выключенных случайных событиях ничего не запускается и времени следующего нет", #lg == 0 and EV.GetNextRandomAt() == nil)
EV.SetRandomEnabled(true); runFor(200)
check("E5. после включения сразу не стартует (новая пауза ≥240 с)", #lg == 0)
local nxt2 = EV.GetNextRandomAt()
check("E5. после включения снова есть время следующего", nxt2 ~= nil and nxt2 - Workspace:GetServerTimeNow() > 0)
local waited = 0
while not EV.GetCurrent() and waited < 600 do runFor(1); waited += 1 end
check(("E5. событие запустилось по истечении паузы (через %d с после включения, а не сразу)"):format(waited + 200), EV.GetCurrent() ~= nil and waited + 200 >= 240 and waited + 200 <= 360)
check("E6. во время события времени следующего нет", EV.GetNextRandomAt() == nil)
runFor(130)
check("E6. после события снова публикуется время следующего", EV.GetCurrent() == nil and EV.GetNextRandomAt() ~= nil)
end
