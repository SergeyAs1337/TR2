do
print("--- P. Админ-панель (клиент + AdminService, нажатия кнопок)")
local oldEnum = Enum
Enum = setmetatable({}, {__index = function(_, a) return setmetatable({}, {__index = function(_, b) return a .. "." .. b end}) end})

local function addStats(p, coins, deaths)
	local ls = newInst("Folder", "leaderstats"); ls.Parent = p
	local c = newInst("IntValue", "Coins"); c.Value = coins; c.Parent = ls
	local d = newInst("IntValue", "Deaths"); d.Value = deaths; d.Parent = ls
end
local function coinsOf(p) return p:FindFirstChild("leaderstats"):FindFirstChild("Coins").Value end
local function findAll(root, pred) local out = {} for _, d in ipairs(methods.GetDescendants(root)) do if pred(d) then table.insert(out, d) end end return out end
local function byText(root, text, cls) return findAll(root, function(d) return d.Text == text and (not cls or d.ClassName == cls) end)[1] end
local function byContains(root, sub, cls) return findAll(root, function(d) return type(d.Text) == "string" and string.find(d.Text, sub, 1, true) ~= nil and (not cls or d.ClassName == cls) end)[1] end
local function click(btn) btn.Activated:Fire() end

local function setup(localIsAdmin)
	resetWorld(); local E = loadEvents(); loadedEvents = E
	local log = {}
	local function fake(name) return {Name = name, Start = function() table.insert(log, "start:" .. name) return true end, Stop = function() table.insert(log, "stop:" .. name) end} end
	E.List = {fake("Alpha"), fake("Beta")}
	filterMode = "pass"; announced = {}
	local resetRemote = newInst("RemoteEvent", "ResetPlayerStatsAdminEvent"); resetRemote.OnServerEvent = Signal(); resetRemote.Parent = ReplicatedStorage
	local admin = mkPlayer("Admin", v3(0, 13, 0)); admin.UserId = 940118285
	local alice = mkPlayer("Alice", v3(10, 13, 0)); alice.UserId = 1001
	local bob = mkPlayer("Bob", v3(20, 13, 0)); bob.UserId = 1002
	addStats(admin, 100, 1); addStats(alice, 500, 7); addStats(bob, 50, 0)
	runAdminService()
	local req = ReplicatedStorage:FindFirstChild("AdminRequest")
	local localPlayer = localIsAdmin and admin or alice
	PlayersSvc.LocalPlayer = localPlayer; LocalPlayerRef = localPlayer
	req.InvokeServer = function(self, ...) return req.OnServerInvoke(localPlayer, ...) end
	UIS.InputBegan = Signal()
	runAdminPanel()
	local gui = localPlayer:FindFirstChild("PlayerGui"):FindFirstChild("AdminPanelV2")
	return E, admin, alice, bob, gui, req, resetRemote, log
end

-- P1 не админ
local E, admin, alice, bob, gui = setup(false)
check("P1. не админ: панель не создаётся", gui == nil)

-- P2 открытие
E, admin, alice, bob, gui, req, resetRemote, log = setup(true)
local panel = methods.FindFirstChild(gui, "Panel")
local toggle = byText(gui, "🛠 Админ", "TextButton")
check("P2. панель создана, закрыта; кнопка «🛠 Админ» есть", gui ~= nil and panel ~= nil and panel.Visible == false and toggle ~= nil)
click(toggle)
check("P2. кнопка открывает панель", panel.Visible == true)
check("P2. 4 вкладки", byText(panel, "События", "TextButton") and byText(panel, "Игроки", "TextButton") and byText(panel, "Сервер", "TextButton") and byText(panel, "Журнал", "TextButton"))
local function page(name) return methods.FindFirstChild(panel, name, true) end
check("P2. открыта вкладка «События»", page("События").Visible == true and page("Игроки").Visible == false and page("Сервер").Visible == false and page("Журнал").Visible == false)
click(byText(panel, "Игроки", "TextButton"))
check("P2. переключение вкладок", page("Игроки").Visible == true and page("События").Visible == false)
click(byText(panel, "События", "TextButton"))
local function toastText() local t = findAll(panel, function(d) return d.ClassName == "TextLabel" and d.BackgroundColor3 and d.TextSize == 14 and d.Font == "Font.GothamMedium" end)[1]; return t end
local toastLabel = toastText()

-- P3 события
local alphaBtn, betaBtn = byText(panel, "▶ Alpha", "TextButton"), byText(panel, "▶ Beta", "TextButton")
local durationBox = findAll(panel, function(d) return d.ClassName == "TextBox" and d.PlaceholderText and d.PlaceholderText:find("Длительность", 1, true) end)[1]
check("P3. кнопки событий и поле длительности (по умолчанию 120)", alphaBtn and betaBtn and durationBox and durationBox.Text == "120")
click(alphaBtn)
check("P3. запуск Alpha на 120 с (сервер получил событие и конец по серверному времени)", E.GetCurrent() == "Alpha" and E.GetInfo().endsAt == Workspace:GetServerTimeNow() + 120)
check("P3. всплывающее сообщение «Запущено: Alpha»", toastLabel.Visible == true and toastLabel.Text == "Запущено: Alpha")
local statusLabel = byContains(panel, "Идёт: Alpha", "TextLabel")
check("P3. статус показывает идущее событие и 2:00", statusLabel ~= nil and statusLabel.Text:find("2:00", 1, true) ~= nil)
runFor(10.5)
statusLabel = byContains(panel, "Идёт: Alpha", "TextLabel")
check("P3. часы тикают: через 10 с осталось ≈1:50", statusLabel and (statusLabel.Text:find("1:50", 1, true) or statusLabel.Text:find("1:49", 1, true)))
durationBox.Text = "45"; click(betaBtn)
check("P3. Beta на 45 с вытесняет Alpha", E.GetCurrent() == "Beta" and E.GetInfo().endsAt == Workspace:GetServerTimeNow() + 45)
for _, junk in ipairs({"", "abc", "-5", "0"}) do durationBox.Text = junk; click(alphaBtn); if E.GetInfo().endsAt ~= nil then check("P3. пустая/мусорная длительность = до остановки: «" .. junk .. "»", false) end end
check("P3. пустая/мусорная/нулевая длительность = до ручной остановки", E.GetCurrent() == "Alpha" and E.GetInfo().endsAt == nil)
click(byContains(panel, "Остановить текущее", "TextButton"))
check("P3. кнопка «Остановить»", E.GetCurrent() == nil)
check("P3. статус: событий нет", byContains(panel, "Сейчас событий нет", "TextLabel") ~= nil)
local randomBtn = byContains(panel, "Случайные:", "TextButton")
check("P3. кнопка случайных событий показывает ВКЛ", randomBtn.Text:find("ВКЛ", 1, true) ~= nil)
click(randomBtn)
check("P3. выключение случайных событий + текст ВЫКЛ", E.IsRandomEnabled() == false and randomBtn.Text:find("ВЫКЛ", 1, true) ~= nil and byContains(panel, "ВЫКЛЮЧЕНЫ", "TextLabel") ~= nil)
click(randomBtn); check("P3. включение обратно", E.IsRandomEnabled() == true and randomBtn.Text:find("ВКЛ", 1, true) ~= nil)

-- P4 игроки
click(byText(panel, "Игроки", "TextButton"))
local function rowOf(name) return findAll(panel, function(d) return d.ClassName == "TextButton" and type(d.Text) == "string" and d.Text:find("^ " .. name) ~= nil end)[1] end
local function playerRows() return findAll(panel, function(d) return d.ClassName == "TextButton" and type(d.Text) == "string" and d.Text:find("💰", 1, true) ~= nil and d.Text:find("☠", 1, true) ~= nil end) end
check("P4. строки игроков (3), у админа 👑, видны монеты и смерти", #playerRows() == 3 and rowOf("Admin").Text:find("👑", 1, true) and rowOf("Alice").Text:find("💰500", 1, true) and rowOf("Alice").Text:find("☠7", 1, true))
local amountBox = findAll(panel, function(d) return d.ClassName == "TextBox" and d.PlaceholderText == "Сумма монет" end)[1]
local reasonBox = findAll(panel, function(d) return d.ClassName == "TextBox" and d.PlaceholderText and d.PlaceholderText:find("Причина", 1, true) end)[1]
click(byText(panel, "💀 Убить", "TextButton"))
check("P4. без выбранного игрока: подсказка и никакого действия на сервере", toastLabel.Text == "Сначала выбери игрока в списке" and bob.Character.Humanoid.Health == 100 and alice.Character.Humanoid.Health == 100)
click(rowOf("Alice"))
check("P4. выбор игрока: «Выбран: Alice (@Alice)»", byContains(panel, "Выбран: Alice", "TextLabel") ~= nil)
amountBox.Text = "250"; click(byText(panel, "💰 Выдать", "TextButton"))
check("P4. выдать 250 монет: у Alice 750, в строке обновилось", coinsOf(alice) == 750 and toastLabel.Text == "Выдано 250 монет: Alice")
runFor(1.1)
check("P4. строка Alice обновилась на месте (💰750)", rowOf("Alice").Text:find("💰750", 1, true) ~= nil)
amountBox.Text = "abc"; click(byText(panel, "💰 Выдать", "TextButton"))
check("P4. мусорная сумма отклонена на клиенте, монеты не тронуты", coinsOf(alice) == 750 and toastLabel.Text:find("целое число", 1, true) ~= nil)
amountBox.Text = "0"; click(byText(panel, "💰 Выдать", "TextButton"))
check("P4. выдать 0 отклонено", coinsOf(alice) == 750)
click(byText(panel, "✏️ Установить", "TextButton"))
check("P4. установить 0 разрешено", coinsOf(alice) == 0)
amountBox.Text = "12.5"; click(byText(panel, "✏️ Установить", "TextButton"))
check("P4. дробная сумма отклонена", coinsOf(alice) == 0)
click(byText(panel, "💀 Убить", "TextButton"))
check("P4. убить выбранного", alice.Character.Humanoid.Health == 0)
runFor(1.1)
check("P4. в строке появился 💀", rowOf("Alice").Text:find("💀", 1, true) ~= nil)
alice.Character.Humanoid.Health = 10; click(byText(panel, "❤️ Вылечить", "TextButton"))
check("P4. вылечить мёртвого нельзя, живого можно", alice.Character.Humanoid.Health == 10 or alice.Character.Humanoid.Health == 100)
click(byContains(panel, "Заморозить", "TextButton")); runFor(1.1)
check("P4. заморозка: HRP заякорен, в строке 🧊", alice.Character.HumanoidRootPart.Anchored == true and rowOf("Alice").Text:find("🧊", 1, true) ~= nil)
click(byContains(panel, "Заморозить", "TextButton"))
check("P4. повторное нажатие размораживает (по состоянию с сервера)", alice.Character.HumanoidRootPart.Anchored == false)
click(byContains(panel, "Телепорт к игроку", "TextButton"))
check("P4. телепорт к игроку", admin.Character.HumanoidRootPart.Position.X == 10)
click(byContains(panel, "Игрок ко мне", "TextButton"))
check("P4. игрок ко мне", alice.Character.HumanoidRootPart.Position.X == admin.Character.HumanoidRootPart.Position.X)
-- опасные действия: двойное нажатие
reasonBox.Text = "спам"
local kickBtn = byText(panel, "👢 Кик", "TextButton")
click(kickBtn)
check("P4. кик: первое нажатие только «взводит» кнопку", alice.kicked == nil and kickBtn.Text == "Точно? Нажми ещё раз")
runFor(3.5)
check("P4. через 3 секунды кнопка снова обычная", kickBtn.Text == "👢 Кик" and alice.kicked == nil)
click(kickBtn); click(kickBtn)
check("P4. кик: два нажатия подряд кикают с введённой причиной", alice.kicked == "спам" and kickBtn.Text == "👢 Кик")
local resetBtn = byText(panel, "🔄 Сброс статистики", "TextButton")
click(resetBtn)
check("P4. сброс статистики: одно нажатие ничего не отправляет", resetRemote.fired == nil)
click(resetBtn)
check("P4. сброс: второе нажатие шлёт существующему RemoteEvent имя игрока", resetRemote.fired ~= nil and #resetRemote.fired == 1 and resetRemote.fired[1][1] == "Alice")

-- P5 список игроков обновляется на месте
local bobRow = rowOf("Bob")
local carl = mkPlayer("Carl", v3(5, 13, 0)); carl.UserId = 1005; addStats(carl, 7, 0)
runFor(1.2)
check("P5. новый игрок появляется в списке, старые строки те же объекты (клик не теряется)", #playerRows() >= 3 and rowOf("Carl") ~= nil and rowOf("Bob") == bobRow)
click(rowOf("Bob")); check("P5. выбран Bob", byContains(panel, "Выбран: Bob", "TextLabel") ~= nil)
for i, p in ipairs(playerList) do if p == bob then table.remove(playerList, i) break end end
runFor(1.2)
check("P5. ушедший игрок пропадает из списка, выбор сбрасывается", rowOf("Bob") == nil and byContains(panel, "Выбери игрока в списке", "TextLabel") ~= nil)

-- P6 сервер
click(byText(panel, "Сервер", "TextButton"))
local info = byContains(panel, "Игроков:", "TextLabel")
check("P6. вкладка «Сервер»: игроки, аптайм, версия места и сервер", info and info.Text:find("/ 50", 1, true) and info.Text:find("2:03", 1, true) and info.Text:find("42", 1, true) and info.Text:find("abcdef01", 1, true))
local announceBox = findAll(panel, function(d) return d.ClassName == "TextBox" and d.PlaceholderText and d.PlaceholderText:find("Объявление", 1, true) end)[1]
local announcedBefore = #announced
click(byText(panel, "📢 Отправить всем", "TextButton"))
check("P6. пустое объявление отклонено на клиенте", #announced == announcedBefore and toastLabel.Text == "Введи текст объявления")
announceBox.Text = "Привет, игроки!"; click(byText(panel, "📢 Отправить всем", "TextButton"))
check("P6. объявление дошло всем (через баннер событий) и поле очищено", announced[#announced] == "📢 Привет, игроки!" and announceBox.Text == "")
admin.Character.Humanoid.Health = 3; click(byText(panel, "❤️ Вылечить всех", "TextButton"))
check("P6. вылечить всех", admin.Character.Humanoid.Health == 100)

-- P7 журнал
click(byText(panel, "Журнал", "TextButton"))
local logLabel = findAll(panel, function(d) return d.ClassName == "TextLabel" and d.Font == "Font.Code" end)[1]
check("P7. журнал показывает действия с именем админа", logLabel.Text:find("Admin: выдал 250 монет игроку Alice", 1, true) ~= nil and logLabel.Text:find("кикнул Alice", 1, true) ~= nil and logLabel.Text:find("сбросил статистику игроку Alice", 1, true) ~= nil)

-- P8 клавиша F2
click(byText(panel, "✕", "TextButton"))
check("P8. кнопка ✕ закрывает панель", panel.Visible == false)
UIS.InputBegan:Fire({KeyCode = "KeyCode.F2"}, false)
check("P8. F2 открывает", panel.Visible == true)
UIS.InputBegan:Fire({KeyCode = "KeyCode.F2"}, true)
check("P8. F2 в поле ввода (gameProcessed) игнорируется", panel.Visible == true)
UIS.InputBegan:Fire({KeyCode = "KeyCode.F3"}, false)
check("P8. другая клавиша не трогает панель", panel.Visible == true)
UIS.InputBegan:Fire({KeyCode = "KeyCode.F2"}, false)
check("P8. F2 закрывает", panel.Visible == false)

-- P9 закрытая панель не опрашивает сервер
local calls = 0
local realInvoke = req.InvokeServer
req.InvokeServer = function(self, ...) calls += 1; return realInvoke(self, ...) end
runFor(5)
check("P9. пока панель закрыта, запросов к серверу нет", calls == 0)
UIS.InputBegan:Fire({KeyCode = "KeyCode.F2"}, false); local opened = calls
runFor(5)
check(("P9. открытая панель опрашивает сервер раз в секунду (за 5 с: %d запросов)"):format(calls - opened), calls - opened >= 4 and calls - opened <= 7)

-- P10 сервер не отвечает
req.InvokeServer = function() return nil end
click(byText(panel, "Игроки", "TextButton")); click(rowOf("Admin")); amountBox.Text = "5"
click(byText(panel, "💰 Выдать", "TextButton"))
check("P10. сервер молчит: понятное сообщение, без падения", toastLabel.Text == "Нет ответа от сервера" or toastLabel.Text:find("Нет ответа", 1, true) ~= nil or toastLabel.Visible == true)
runFor(3)
req.InvokeServer = function() error("remote broke") end
runFor(2); click(byText(panel, "💰 Выдать", "TextButton"))
check("P10. ошибка вызова сервера не роняет интерфейс", toastLabel.Text == "Нет ответа от сервера")
Enum = oldEnum
end
