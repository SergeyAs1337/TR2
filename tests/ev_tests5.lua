do
print("--- G. GambleScreen v3 и UILib v3")
local oldEnum = Enum
Enum = setmetatable({}, {__index = function(_, a) return setmetatable({}, {__index = function(_, b) return a .. "." .. b end}) end})
local function find(root, path) local cur = root; for name in string.gmatch(path, "[^%.]+") do cur = cur and cur:FindFirstChild(name) end return cur end

local function setupGamble(opts)
	opts = opts or {}
	resetWorld()
	local player = mkPlayer("Gambler", v3(0, 0, 0)); PlayersSvc.LocalPlayer = player; LocalPlayerRef = player
	local ls = newInst("Folder", "leaderstats"); ls.Parent = player
	local coins = newInst("IntValue", "Coins"); coins.Value = opts.coins or 5000; coins.Parent = ls
	local gambleEvent = nil
	if not opts.noRemote then gambleEvent = newInst("RemoteEvent", "GambleEvent"); gambleEvent.Parent = ReplicatedStorage end
	local stats = newInst("Folder", "GlobalStats"); stats.Parent = ReplicatedStorage
	local lost = newInst("IntValue", "TotalLost"); lost.Value = 0; lost.Parent = stats
	local uilibInst = newInst("ModuleScript", "UILib"); uilibInst.Parent = ReplicatedStorage; moduleRegistry[uilibInst] = loadUILib()
	local gsInst = newInst("ModuleScript", "GambleScreen"); gsInst.Parent = ReplicatedStorage; moduleRegistry[gsInst] = loadGambleScreen()
	local tool = newInst("Tool", "odnorykiy_bandit")
	script = {Parent = tool}; runGambleTool()
	return player, tool, gambleEvent, lost, moduleRegistry[gsInst], coins, moduleRegistry[uilibInst]
end
local function reelSymbols(screen) local out = {}; for i, r in ipairs(screen.reels) do out[i] = r.symbol end return out end

local player, tool, ev, lost, GS, coins, UI = setupGamble()
local screen = GS.get(player)
local gui = player:FindFirstChild("PlayerGui"):FindFirstChild("GambleUI")
local holder = gui and gui:FindFirstChild("Window")
check("G1. окно GambleUI создано кодом, закрыто, не пересоздаётся при респавне", gui ~= nil and holder ~= nil and holder.Visible == false and gui.ResetOnSpawn == false)
check("G1. окно: заголовок «Однорукий бандит», три барабана, кнопка «Крутить», крестик", find(holder, "Panel.Header.Title").Text == "🎰 Однорукий бандит" and #screen.reels == 3 and screen.spinButton.label.Text == "Крутить" and find(holder, "Panel.Header.CloseButton") ~= nil)
check("G1. цвета как у админ-панели: фон окна (24,26,33)", find(holder, "Panel").BackgroundColor3 == UI.THEME.background and UI.THEME.background[1] == 24 and UI.THEME.background[2] == 26 and UI.THEME.background[3] == 33)
check("G1. семёрка — та же картинка rbxassetid://85504738002100", find(holder, "Panel.Body.Reels.Reel1.Seven").Image == "rbxassetid://85504738002100")
check("G1. окно подстраивается под экран (FitScale) и появляется с анимацией (PopScale)", holder:FindFirstChild("FitScale") ~= nil and find(holder, "Panel.PopScale") ~= nil)

tool.Activated:Fire()
check("G2. клик инструментом открывает окно, видно затемнение", holder.Visible == true and screen.isOpen() == true and gui:FindFirstChild("Dim").Visible == true)
local lostLabel = find(holder, "Panel.Body.TotalLostLabel")
local balance = find(holder, "Panel.Body.Balance")
check("G2. счётчик «Проиграно всеми: 🪙 0» и баланс «🪙 5 000»", lostLabel.Text == "Проиграно всеми: 🪙 0" and balance.Text == "Баланс: 🪙 5 000")
lost.Value = 1234567
check("G2. счётчик следит за GlobalStats.TotalLost: «1 234 567»", lostLabel.Text == "Проиграно всеми: 🪙 1 234 567")
coins.Value = 4000
check("G2. баланс следит за монетами", balance.Text == "Баланс: 🪙 4 000")

-- быстрые ставки
local bet = screen.betBox
local function chip(i) find(holder, "Panel.Body.BetRow.Chip" .. i .. ".Face").Activated:Fire() end
bet.Text = "250"; chip(1); check("G3. «½»: 250 -> 125", bet.Text == "125")
chip(2); check("G3. «x2»: 125 -> 250", bet.Text == "250")
chip(3); check("G3. «+1К»: 250 -> 1250", bet.Text == "1250")
chip(4); check("G3. «ВСЁ»: ставка = весь баланс 4000", bet.Text == "4000")
bet.Text = "abc"; chip(2); check("G3. мусор в поле + «x2» не ломается (берётся ставка по умолчанию)", bet.Text == "200")

-- неверные ставки
local allBad = true
for _, bad in ipairs({"", "abc", "0", "-5", "1.5", "1e12", "nan", "inf", " "}) do
	bet.Text = bad; screen.spinButton.face.Activated:Fire()
	if (ev._p.fired and #ev._p.fired > 0) or screen.isSpinning() then allBad = false end
end
check("G4. мусорные ставки не уходят на сервер и не крутят барабаны", allBad)
check("G4. подсказка «Неверная ставка»", screen.resultLabel.Text == "Неверная ставка")
bet.Text = "4001"; screen.spinButton.face.Activated:Fire()
check("G4. ставка больше баланса: «Не хватает монет!», на сервер не ушла", screen.resultLabel.Text == "Не хватает монет!" and not ev._p.fired)
runFor(1)

-- выигрыш x10
bet.Text = "250"; screen.spinButton.face.Activated:Fire()
check("G5. ставка 250 ушла на сервер ровно один раз, барабаны крутятся, кнопка выключена", ev._p.fired and #ev._p.fired == 1 and ev._p.fired[1][1] == 250 and screen.isSpinning() and not screen.spinButton.isEnabled())
screen.spinButton.face.Activated:Fire()
check("G5. повторный клик во время прокрутки не шлёт вторую ставку", #ev._p.fired == 1)
ev.OnClientEvent:Fire({ ok = true, bet = 250, multiplier = 10, win = 2500 })
runFor(0.5)
check("G5. ответ пришёл сразу, но барабаны крутятся минимум 0.9 с", screen.isSpinning() and screen.resultLabel.Text == "Крутим…")
runFor(2)
local s = reelSymbols(screen)
check("G5. x10: три семёрки, «Джекпот! +2 500 🪙», кнопка снова активна", s[1] == "7" and s[2] == "7" and s[3] == "7" and screen.resultLabel.Text == "Джекпот! +2 500 🪙" and not screen.isSpinning() and screen.spinButton.isEnabled())
check("G5. окно после ставки остаётся открытым (можно крутить ещё)", screen.isOpen())

-- x2 и проигрыш (несколько раз, т.к. символы случайные)
local x2ok, lossOk = true, true
for k = 1, 25 do
	screen.spinButton.face.Activated:Fire(); ev.OnClientEvent:Fire({ ok = true, bet = 100, multiplier = 2, win = 200 }); runFor(2)
	s = reelSymbols(screen)
	if not (s[1] == s[2] and s[2] == s[3] and s[1] ~= "7" and screen.resultLabel.Text == "x2  +200 🪙") then x2ok = false end
	screen.spinButton.face.Activated:Fire(); ev.OnClientEvent:Fire({ ok = true, bet = 100, multiplier = 0, win = 0 }); runFor(2)
	s = reelSymbols(screen)
	if (s[1] == s[2] and s[2] == s[3]) or screen.resultLabel.Text ~= "Мимо  −100 🪙" then lossOk = false end
end
check("G6. x2: три одинаковых символа (не семёрки), «x2  +200 🪙» (25 прогонов)", x2ok)
check("G6. проигрыш: символы НЕ все одинаковые, «Мимо  −100 🪙» (25 прогонов)", lossOk)

-- отказ сервера и молчание сервера
screen.spinButton.face.Activated:Fire(); ev.OnClientEvent:Fire({ ok = false, reason = "Не так быстро!" }); runFor(2)
check("G7. отказ сервера: показывается причина, кнопка снова активна", screen.resultLabel.Text == "Не так быстро!" and screen.spinButton.isEnabled())
screen.spinButton.face.Activated:Fire(); runFor(4)
check("G7. сервер молчит 4 с: ещё крутится", screen.isSpinning())
runFor(2)
check("G7. сервер молчит больше 5 с: остановка, «Сервер не ответил»", not screen.isSpinning() and screen.resultLabel.Text == "Сервер не ответил")
ev.OnClientEvent:Fire({ ok = true, bet = 100, multiplier = 10, win = 1000 }); runFor(2)
check("G7. запоздавший ответ после таймаута игнорируется", screen.resultLabel.Text == "Сервер не ответил")
ev.OnClientEvent:Fire("мусор"); ev.OnClientEvent:Fire(nil)
check("G7. мусор в ответе не ломает окно", screen.resultLabel.Text == "Сервер не ответил")

-- закрытие
find(holder, "Panel.Header.CloseButton.Face").Activated:Fire(); runFor(0.3)
check("G8. крестик закрывает окно", holder.Visible == false and not screen.isOpen())
tool.Activated:Fire(); gui:FindFirstChild("Dim").Activated:Fire(); runFor(0.3)
check("G8. клик по затемнению закрывает окно", holder.Visible == false)
tool.Activated:Fire(); find(holder, "Panel.Header.CloseButton.Face").Activated:Fire(); tool.Activated:Fire(); runFor(0.3)
check("G8. быстро закрыли и открыли: окно остаётся открытым (старая анимация закрытия не прячет его)", holder.Visible == true)

-- одно окно на игрока
runGambleTool(); runGambleTool()
local count = 0; for _, c in ipairs(methods.GetChildren(player:FindFirstChild("PlayerGui"))) do if c.Name == "GambleUI" then count += 1 end end
check("G9. повторный запуск скрипта инструмента не плодит окна", count == 1 and GS.get(player) == GS.get(player))
gui:Destroy()
local rebuilt = GS.get(player)
check("G9. если окно уничтожили, оно создаётся заново", rebuilt.gui ~= gui and rebuilt.gui.Parent ~= nil)

-- нет GambleEvent
local p2, tool2, ev2, lost2, GS2 = setupGamble({noRemote = true})
local sc2 = GS2.get(p2)
tool2.Activated:Fire(); sc2.betBox.Text = "10"; sc2.spinButton.face.Activated:Fire()
check("G10. нет GambleEvent: ставка не падает с ошибкой, окно остаётся, барабаны не крутятся", sc2.isOpen() and not sc2.isSpinning() and sc2.resultLabel.Text == "Автомат сломан :(")

print("--- U. UILib")
local function col(c, r, g, b) return c and c[1] == r and c[2] == g and c[3] == b end
local UI = loadUILib()
local host = newInst("Frame", "Host")
local called = 0
local b = UI.button(host, "Кнопка", UI.COLORS.good, function() called += 1 end, 40)
check("U1. button (v1): текст, цвет, высота, родитель; Activated вызывает обработчик", b.Text == "Кнопка" and b.Parent == host and b.Size[4] == 40 and col(b.BackgroundColor3, 52, 150, 96) and (function() b.Activated:Fire(); b.Activated:Fire(); return called == 2 end)())
check("U1. button без обработчика не падает", UI.button(host, "x").Text == "x")
local i = UI.input(host, "Подсказка", "5")
check("U2. input: подсказка, текст по умолчанию, ввод не очищается", i.PlaceholderText == "Подсказка" and i.Text == "5" and i.ClearTextOnFocus == false)
check("U2. label и scroll", UI.label(host, "Привет", 30).Text == "Привет" and UI.scroll(host).AutomaticCanvasSize == "AutomaticSize.Y")
check("U2. make: свойства применены, Parent выставлен", UI.make("Frame", {Name = "Z", Visible = false}, host).Parent == host and host:FindFirstChild("Z").Visible == false)
local fired = 0
local c = UI.confirmButton(host, "Опасно", UI.COLORS.bad, function() fired += 1 end)
c.Activated:Fire()
check("U3. confirmButton: первое нажатие только взводит", fired == 0 and c.Text == "Точно? Нажми ещё раз")
c.Activated:Fire()
check("U3. второе выполняет и возвращает текст", fired == 1 and c.Text == "Опасно")
c.Activated:Fire(); runFor(3.5)
check("U3. не нажали второй раз: через 3 с снова обычная кнопка", fired == 1 and c.Text == "Опасно")
local cases = {{0, "0"}, {7, "7"}, {999, "999"}, {1000, "1 000"}, {12345, "12 345"}, {123456, "123 456"}, {1234567, "1 234 567"}, {1000000000000, "1 000 000 000 000"}, {-1234567, "-1 234 567"}, {1234.9, "1 234"}, {-0.5, "0"}, {"15000", "15 000"}, {0 / 0, "0"}, {nil, "0"}, {"abc", "0"}}
local fmtOk = true
for _, tc in ipairs(cases) do local got = UI.formatNumber(tc[1]); if got ~= tc[2] then fmtOk = false; print("   formatNumber(" .. tostring(tc[1]) .. ") = " .. got .. " вместо " .. tc[2]) end end
check("U4. formatNumber: 0, тысячи, миллионы, 1e12, отрицательные, дробные, строки, NaN, nil", fmtOk)
local short = {{0, "0"}, {999999, "999 999"}, {1000000, "1M"}, {1250000, "1.25M"}, {12500000, "12.5M"}, {125000000, "125M"}, {999999999, "999M"}, {1000000000, "1B"}, {2500000000000, "2.5T"}, {-3400000, "-3.4M"}, {1999999, "1.99M"}, {0 / 0, "0"}, {nil, "0"}}
local shortOk = true
for _, tc in ipairs(short) do local got = UI.formatShort(tc[1]); if got ~= tc[2] then shortOk = false; print("   formatShort(" .. tostring(tc[1]) .. ") = " .. got .. " вместо " .. tc[2]) end end
check("U4. formatShort: до миллиона полностью, дальше 1.25M / 12.5M / 125M / 1B / 2.5T, без округления вверх", shortOk)
check("U4. formatTime: 0:00, 0:05, 1:23, 61:01, отрицательное = 0:00", UI.formatTime(0) == "0:00" and UI.formatTime(5) == "0:05" and UI.formatTime(83) == "1:23" and UI.formatTime(3661) == "61:01" and UI.formatTime(-9) == "0:00")

-- actionButton
local clicks = 0
local tb = UI.actionButton(host, { text = "Жми", color = "good", onClick = function() clicks += 1 end })
local P = UI.THEME.palette
tb.face.Activated:Fire()
check("U5. actionButton: текст, цвет, клик вызывает обработчик", tb.label.Text == "Жми" and tb.face.BackgroundColor3 == P.good.face and clicks == 1)
tb.face.MouseEnter:Fire(); check("U5. под курсором подсвечивается", tb.face.BackgroundColor3 == P.good.hover)
tb.face.MouseButton1Down:Fire(); check("U5. нажатие затемняет", tb.face.BackgroundColor3 == P.good.press)
tb.face.MouseButton1Up:Fire(); tb.face.MouseLeave:Fire(); check("U5. отпустили и увели курсор: обычный цвет", tb.face.BackgroundColor3 == P.good.face)
tb.setEnabled(false); tb.face.Activated:Fire()
check("U5. выключенная кнопка не вызывает обработчик, серая, текст приглушён", clicks == 1 and tb.getColor() == "neutral" and tb.face.BackgroundColor3 == P.neutral.face and tb.label.TextColor3 == UI.THEME.muted)
tb.setColor("bad")
check("U5. setColor на выключенной кнопке не перекрашивает…", tb.getColor() == "neutral")
tb.setEnabled(true)
check("U5. …а после включения кнопка красная", tb.getColor() == "bad" and tb.face.BackgroundColor3 == P.bad.face)
check("U5. старое имя toonButton работает", UI.toonButton == UI.actionButton)

-- окна: одно за раз, open/toggle по имени
resetWorld()
local pl = mkPlayer("Win", v3(0, 0, 0)); PlayersSvc.LocalPlayer = pl
local UI2 = loadUILib()
local opened, closed = 0, 0
local w1 = UI2.window({ name = "A", title = "A", onOpen = function() opened += 1 end, onClose = function() closed += 1 end })
local w2 = UI2.window({ name = "B", title = "B" })
check("U6. open по имени", UI2.open("A") == true and w1.isOpen() and opened == 1)
UI2.open("B")
check("U6. открытие второго окна закрывает первое", w2.isOpen() and not w1.isOpen() and closed == 1)
check("U6. toggle по имени", UI2.toggle("B") == true and not w2.isOpen())
check("U6. неизвестное окно: open/toggle возвращают false, без ошибки", UI2.open("Нет") == false and UI2.toggle("Нет") == false)
w1.gui:Destroy()
check("U6. уничтоженное окно не открывается", UI2.open("A") == false)

-- уведомления
UI2.toast("Привет", "green", 1)
local holderT = pl:FindFirstChild("PlayerGui"):FindFirstChild("Toasts"):FindFirstChild("Holder")
local function toasts() local n = 0; for _, ch in ipairs(methods.GetChildren(holderT)) do if ch.Name == "Toast" then n += 1 end end return n end
check("U7. toast появился", toasts() == 1 and holderT:FindFirstChild("Toast"):FindFirstChild("Label").Text == "Привет")
for k = 1, 6 do UI2.toast("t" .. k) end
check("U7. не больше 4 уведомлений сразу", toasts() == 4)
runFor(3)
check("U7. уведомления исчезают сами", toasts() == 0)
Enum = oldEnum
end
