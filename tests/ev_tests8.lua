do
print("--- D. Дейлики, Q. диалоги, R. радио, T. танцы, F. еда, I. предметы, UI. новые окна")
local oldEnum = Enum
Enum = setmetatable({}, {__index = function(_, a) return setmetatable({}, {__index = function(_, b) return a .. "." .. b end}) end})
local function find(root, path) local cur = root; for name in string.gmatch(path, "[^%.]+") do cur = cur and cur:FindFirstChild(name) end return cur end

-- ===== общие заглушки сервера =====
local stores = {}
local DS = {GetDataStore = function(self, name)
	stores[name] = stores[name] or {data = {}, fail = false, writes = 0, reads = 0}
	local st = stores[name]
	return {
		GetAsync = function(_, k) st.reads += 1; if st.fail then error("datastore down") end return st.data[k] end,
		SetAsync = function(_, k, v) if st.fail then error("datastore down") end st.writes += 1; st.data[k] = v end,
		UpdateAsync = function(_, k, f) if st.fail then error("datastore down") end local r = f(st.data[k]); if r ~= nil then st.data[k] = r; st.writes += 1 end return st.data[k] end,
	}
end}
local origGS = game.GetService
game.GetService = function(self, n) if n == "DataStoreService" then return DS end return origGS(self, n) end
local origBind = game.BindToClose; game.BindToClose = function() end
local origClock = os.clock; local fakeClock = 1000; os.clock = function() return fakeClock end
local function today() local d = os.date("!*t"); return string.format("%04d-%02d-%02d", d.year, d.month, d.day) end
local function remoteEvent(name, parent) local r = newInst("RemoteEvent", name); r.OnServerEvent = Signal(); r.Parent = parent or ReplicatedStorage; return r end
local function lastClient(remote) local l = remote._p.clientFired; return l and l[#l] end
local function addCoins(player, value) local ls = newInst("Folder", "leaderstats"); local c = newInst("IntValue", "Coins"); c.Value = value; c.Parent = ls; ls.Parent = player; return c, ls end
local function humanoidOf(player) return player.Character:FindFirstChildOfClass("Humanoid") end

-- ===================== D. ежедневное задание (сервер) =====================
resetWorld(); stores = {}
local p = mkPlayer("Daily", v3(0, 0, 0))
local coins = addCoins(p, 0)
local key = tostring(p.UserId)
DS:GetDataStore("DailyDeaths") -- создать хранилище
stores.DailyDeaths.data[key] = {date = today(), deaths = 3, rewardsGiven = "1", completed = false}
RUN.dailyServer()
local upd = ReplicatedStorage:FindFirstChild("DailyQuestUpdate")
check("D1. данные за сегодня загружены: 3 смерти, награда за 1-ю уже была (повторно не выдана)", p:GetAttribute("DailyDeaths") == 3 and p:GetAttribute("DailyQuestAvailable") == true and p:GetAttribute("DailyRewardsGiven") == "1" and coins.Value == 0)
humanoidOf(p).Died:Fire(); humanoidOf(p).Died:Fire()
check("D2. 5-я смерть: +50 монет ровно один раз, награды «1,5»", p:GetAttribute("DailyDeaths") == 5 and coins.Value == 50 and p:GetAttribute("DailyRewardsGiven") == "1,5")
check("D2. клиенту ушло уведомление о награде 50", (function() for _, e in ipairs(upd._p.clientFired) do if e[3] == 50 then return true end end return false end)())
check("D3. сохранение НЕ на каждой смерти (раньше SetAsync каждый раз)", stores.DailyDeaths.writes == 0)
runFor(61)
check("D3. автосохранение через минуту: одна запись, 5 смертей", stores.DailyDeaths.writes == 1 and stores.DailyDeaths.data[key].deaths == 5 and stores.DailyDeaths.data[key].rewardsGiven == "1,5")
for i = 1, 20 do humanoidOf(p).Died:Fire() end
check("D4. 15 и больше: задание выполнено, +150 один раз, счётчик не растёт выше 15", p:GetAttribute("DailyDeaths") == 15 and p:GetAttribute("DailyQuestCompleted") == true and coins.Value == 200)
PlayersSvc.PlayerRemoving:Fire(p)
check("D5. при выходе сохраняется", stores.DailyDeaths.data[key].deaths == 15 and stores.DailyDeaths.data[key].completed == true)

-- старый день в хранилище -> новый день
resetWorld(); stores = {}
local p2 = mkPlayer("Daily2", v3(0, 0, 0)); local c2 = addCoins(p2, 0)
DS:GetDataStore("DailyDeaths"); stores.DailyDeaths.data[tostring(p2.UserId)] = {date = "2000-01-01", deaths = 14, rewardsGiven = "1,5"}
RUN.dailyServer()
check("D6. вчерашние данные: задание с нуля", p2:GetAttribute("DailyDeaths") == 0 and p2:GetAttribute("DailyRewardsGiven") == "")
humanoidOf(p2).Died:Fire()
check("D6. первая смерть нового дня даёт +30", c2.Value == 30)

-- сбой загрузки
resetWorld(); stores = {}
local p3 = mkPlayer("Daily3", v3(0, 0, 0)); local c3 = addCoins(p3, 0)
DS:GetDataStore("DailyDeaths"); stores.DailyDeaths.fail = true
stores.DailyDeaths.data[tostring(p3.UserId)] = {date = today(), deaths = 10, rewardsGiven = "1,5"}
RUN.dailyServer(); runFor(20)
check("D7. загрузка не удалась: задание «недоступно», а не «новый день»", p3:GetAttribute("DailyQuestAvailable") == false)
humanoidOf(p3).Died:Fire()
check("D7. пока нет данных, смерти не считаются и награды не выдаются (раньше можно было получить заново)", p3:GetAttribute("DailyDeaths") == 0 and c3.Value == 0)
runFor(61)
check("D7. и ничего не записывается поверх настоящего прогресса", stores.DailyDeaths.writes == 0 and stores.DailyDeaths.data[tostring(p3.UserId)].deaths == 10)
stores.DailyDeaths.fail = false; runFor(31)
check("D8. хранилище ожило: данные подгрузились сами (10 смертей)", p3:GetAttribute("DailyQuestAvailable") == true and p3:GetAttribute("DailyDeaths") == 10 and c3.Value == 0)

-- монеты ещё не загрузились
resetWorld(); stores = {}
local p4 = mkPlayer("Daily4", v3(0, 0, 0))
RUN.dailyServer()
humanoidOf(p4).Died:Fire()
check("D9. leaderstats ещё нет: смерть засчитана, награда отложена (не помечена выданной)", p4:GetAttribute("DailyDeaths") == 1 and p4:GetAttribute("DailyRewardsGiven") == "")
local c4, ls4 = addCoins(p4, 0); p4.ChildAdded:Fire(ls4)
check("D9. leaderstats появились: отложенные +30 выданы", c4.Value == 30 and p4:GetAttribute("DailyRewardsGiven") == "1")

-- другой сервер уже в новом дне
resetWorld(); stores = {}
local p5 = mkPlayer("Daily5", v3(0, 0, 0)); addCoins(p5, 0)
RUN.dailyServer(); humanoidOf(p5).Died:Fire()
stores.DailyDeaths.data[tostring(p5.UserId)] = {date = "2999-01-01", deaths = 2, rewardsGiven = "1"}
PlayersSvc.PlayerRemoving:Fire(p5)
check("D10. сохранение не затирает запись более нового дня с другого сервера", stores.DailyDeaths.data[tostring(p5.UserId)].date == "2999-01-01")

-- ===================== UI-D. плашка задания (клиент) =====================
resetWorld(); tweenLog = {}
local cp = mkPlayer("DailyClient", v3(0, 0, 0)); PlayersSvc.LocalPlayer = cp; LocalPlayerRef = cp
local uiInst = newInst("ModuleScript", "UILib"); uiInst.Parent = ReplicatedStorage; local UI = loadUILib(); moduleRegistry[uiInst] = UI
local dEvent = remoteEvent("DailyQuestUpdate")
RUN.dailyHud()
local dpanel = find(cp:FindFirstChild("PlayerGui"), "DailyQuestGui.Panel")
check("UI-D1. плашка задания создана и скрыта", dpanel ~= nil and dpanel.Visible == false)
cp:SetAttribute("DailyQuestTarget", 15); cp:SetAttribute("DailyRewardsGiven", "1"); cp:SetAttribute("DailyDeaths", 3); cp:SetAttribute("DailyQuestAvailable", true)
runFor(1)
check("UI-D2. данные пришли: плашка выехала, «3 / 15», «Умри 15 раз за день»", dpanel.Visible and dpanel:FindFirstChild("Counter").Text == "3 / 15" and dpanel:FindFirstChild("Title").Text == "Умри 15 раз за день")
check("UI-D2. выданная награда +30 подсвечена, +50 нет", dpanel:FindFirstChild("Reward1").TextColor3 == UI.THEME.palette.good.hover and dpanel:FindFirstChild("Reward5").TextColor3 == UI.THEME.muted)
runFor(5)
check("UI-D3. через 4 с уехала", dpanel.Visible == false)
cp:SetAttribute("DailyDeaths", 15); runFor(0.5)
check("UI-D4. выполнено: «Выполнено · новое через …»", dpanel.Visible and string.find(dpanel:FindFirstChild("Title").Text, "Выполнено", 1, true) == 1)
dEvent.OnClientEvent:Fire(15, 150)
check("UI-D5. награда: уведомление «+150 🪙»", find(cp:FindFirstChild("PlayerGui"), "Toasts.Holder.Toast.Label").Text == "Ежедневное задание: +150 🪙")
runFor(6)

-- ===================== Q. диалоги (сервер) =====================
resetWorld()
local qp = mkPlayer("Talker", v3(0, 0, 0)); local qc = addCoins(qp, 20)
local backpack = newInst("Backpack", "Backpack"); backpack.Parent = qp
local iceTool = newInst("Tool", "IceCream"); iceTool.Parent = ReplicatedStorage
local dFolder = newInst("Folder", "Dialogues"); dFolder.Parent = ReplicatedStorage
local iceMod = newInst("ModuleScript", "ice_cream"); iceMod.Parent = dFolder; moduleRegistry[iceMod] = RUN.iceCreamModule()
local helloMod = newInst("ModuleScript", "hello_world"); helloMod.Parent = dFolder; moduleRegistry[helloMod] = RUN.helloModule()
local brokenMod = newInst("ModuleScript", "broken"); brokenMod.Parent = dFolder
moduleRegistry[brokenMod] = {Name = "Bug", Steps = {start = {Text = "Ошибка?", Options = {{Text = "Жми", Reward = function() error("упс") end, Next = "after"}}}, after = {Text = "Живой", Options = {{Text = "Ок"}}}}}
local sys = newInst("Folder", "DialogueSystem"); sys.Parent = ReplicatedStorage
local startR = remoteEvent("StartDialogue", sys); local selectR = remoteEvent("SelectDialogueOption", sys)
local npc = mkModelWithPrimary("6V4Ska9", 4, "HumanoidRootPart"); npc.Parent = Workspace
npc:FindFirstChild("HumanoidRootPart").Position = v3(5, 0, 0)
RUN.dialogueServer()
local function say(...) fakeClock += 1; startR.OnServerEvent:Fire(qp, ...) end
local function pick(...) fakeClock += 1; selectR.OnServerEvent:Fire(qp, ...) end
say("ice_cream")
local msg = lastClient(startR)
local onlyStrings = true
for _, line in ipairs(msg[3].Lines) do if type(line) ~= "string" then onlyStrings = false end end
for _, o in ipairs(msg[3].Options) do for k, v in pairs(o) do if type(v) ~= "string" then onlyStrings = false end end end
check("Q1. диалог начался: имя NPC, две реплики, два варианта", msg[1] == qp and msg[2] == "ice_cream" and msg[4] == "V4Ska" and #msg[3].Lines == 2 and #msg[3].Options == 2)
check("Q1. клиенту уходят только строки (без функций Reward)", onlyStrings)
pick(1)
msg = lastClient(startR)
check("Q2. «Да»: −15 монет, мороженое в рюкзаке, «Держи мороженое!»", qc.Value == 5 and backpack:FindFirstChild("IceCream") ~= nil and msg[3].Lines[1] == "Держи мороженое! Приятного аппетита!")
pick(1)
check("Q2. «Спасибо!»: диалог закончен (клиенту nil — закрыть окно)", lastClient(startR)[3] == nil)
say("ice_cream"); pick(1)
check("Q3. денег мало (5 < 15): «не хватает монет», монеты и рюкзак не тронуты", lastClient(startR)[3].Lines[1] == "Ой, у тебя не хватает монет!" and qc.Value == 5)
local n0 = #startR._p.clientFired
pick(1); pick(1); pick(1)
check("Q4. варианты после конца диалога игнорируются", #startR._p.clientFired == n0 + 1)
say("ice_cream"); n0 = #startR._p.clientFired
for _, bad in ipairs({"1", 1.5, 0, 99, -1, nil}) do pick(bad) end
check("Q4. мусорные номера вариантов игнорируются", #startR._p.clientFired == n0)
n0 = #startR._p.clientFired
say(123); say(""); say(string.rep("x", 100)); say("нет_такого")
check("Q4. мусорные id диалогов игнорируются", #startR._p.clientFired == n0)
fakeClock += 1; startR.OnServerEvent:Fire(qp, "ice_cream"); startR.OnServerEvent:Fire(qp, "ice_cream")
check("Q4. два запроса в одну и ту же миллисекунду: второй отброшен (лимит частоты)", #startR._p.clientFired == n0 + 1)
qp.Character:FindFirstChild("HumanoidRootPart").Position = v3(300, 0, 0)
n0 = #startR._p.clientFired; say("ice_cream")
check("Q5. игрок далеко от NPC: купить мороженое «по воздуху» нельзя", #startR._p.clientFired == n0)
qp.Character:FindFirstChild("HumanoidRootPart").Position = v3(0, 0, 0)
local bind = find(ServerStorage, "DialogueServer.StartDialogue")
check("Q6. для NPC-скриптов создан ServerStorage.DialogueServer.StartDialogue", bind ~= nil and bind.ClassName == "BindableEvent")
fakeClock += 1; bind.Event:Fire(qp, "hello_world", nil)
check("Q6. запуск с сервера работает (раньше NPC-скрипт звал FireServer на сервере)", lastClient(startR)[2] == "hello_world")
pick(2); pick(1)
check("Q7. одноразовый диалог пройден: атрибут Completed_hello_world", qp:GetAttribute("Completed_hello_world") == true)
say("hello_world")
check("Q7. повторно: «Привет! Что-то ещё?»", lastClient(startR)[3].Lines[1] == "Привет! Что-то ещё?")
pick(1); check("Q7. и закрывается", lastClient(startR)[3] == nil)
local w0 = warnCount
say("broken"); pick(1)
check("Q8. ошибка в Reward не ломает диалог: предупреждение и следующий шаг", warnCount == w0 + 1 and lastClient(startR)[3].Lines[1] == "Живой")

-- ===================== UI-Q. окно диалога (клиент) =====================
resetWorld()
local qcp = mkPlayer("TalkClient", v3(0, 0, 0)); PlayersSvc.LocalPlayer = qcp; LocalPlayerRef = qcp
uiInst = newInst("ModuleScript", "UILib"); uiInst.Parent = ReplicatedStorage; UI = loadUILib(); moduleRegistry[uiInst] = UI
sys = newInst("Folder", "DialogueSystem"); sys.Parent = ReplicatedStorage
startR = remoteEvent("StartDialogue", sys); selectR = remoteEvent("SelectDialogueOption", sys)
RUN.dialogueUI()
local dp = find(qcp:FindFirstChild("PlayerGui"), "DialogueGui.Panel")
check("UI-Q1. окно диалога создано и скрыто", dp ~= nil and dp.Visible == false)
startR.OnClientEvent:Fire("x", {Lines = {"Привет, путник!", "Вторая строка"}, Options = {{Text = "Да"}, {Text = "Нет"}}}, "V4Ska")
local text = dp:FindFirstChild("DialogText")
check("UI-Q2. показано: имя NPC, текст печатается (не весь сразу)", dp.Visible and find(dp, "NameTag.Label").Text == "V4Ska" and text.Text == "Привет, путник!" and text.MaxVisibleGraphemes ~= -1)
runFor(1)
check("UI-Q2. допечаталось (кириллица целиком, по буквам, а не по байтам)", text.MaxVisibleGraphemes == -1)
dp:FindFirstChild("Advance").Activated:Fire()
check("UI-Q3. клик: следующая строка", text.Text == "Вторая строка")
dp:FindFirstChild("Advance").Activated:Fire()
check("UI-Q3. клик во время печати: строка показывается целиком", text.MaxVisibleGraphemes == -1 and text.Text == "Вторая строка")
dp:FindFirstChild("Advance").Activated:Fire()
local opts = dp:FindFirstChild("OptionsFrame")
check("UI-Q4. реплики кончились: варианты «1. Да» и «2. Нет»", opts.Visible and find(opts, "Option1.Face.Label").Text == "1.  Да" and find(opts, "Option2.Face.Label").Text == "2.  Нет")
find(opts, "Option2.Face").Activated:Fire()
check("UI-Q5. выбор уходит на сервер (номер 2)", selectR._p.fired and selectR._p.fired[1][1] == 2 and not opts.Visible)
startR.OnClientEvent:Fire("x", nil, "V4Ska")
check("UI-Q6. сервер закончил диалог: окно закрыто", dp.Visible == false)
startR.OnClientEvent:Fire("x", {Text = "Одна строка", Options = {{Text = "Ок"}}}, "N")
dp:FindFirstChild("Advance").Activated:Fire(); dp:FindFirstChild("Advance").Activated:Fire()
find(dp, "OptionsFrame.Option1.Face").Activated:Fire(); runFor(5)
check("UI-Q7. сервер не ответил на выбор 4 с: окно закрылось само", dp.Visible == false)
startR.OnClientEvent:Fire("x", "мусор", 5)
check("UI-Q7. мусор от сервера не ломает окно", dp.Visible == false)

-- ===================== R. радио (сервер) =====================
resetWorld(); MarketSvc.owns = {}
local rp = mkPlayer("DJ", v3(0, 10, 0)); local rbp = newInst("Backpack", "Backpack"); rbp.Parent = rp
for _, n in ipairs({"PlaceRadio", "PickupRadio", "PlayTrack", "StopTrack", "OpenRadioMenu"}) do remoteEvent(n) end
local tracks = newInst("Folder", "RadioTracks"); tracks.Parent = ReplicatedStorage
local song = newInst("Sound", "Song A"); song.SoundId = "rbxassetid://111"; song.Parent = tracks
local radioTool = newInst("Tool", "Radio"); radioTool.Parent = ReplicatedStorage
local radioModel = mkModelWithPrimary("RadioModel", 1, "Base"); radioModel.Parent = radioTool
radioModel:FindFirstChild("Base").Size = v3(2, 2, 2)
local oldScript = newInst("Script", "Script"); oldScript.Parent = radioModel:FindFirstChild("Base")
radioTool:Clone().Parent = rbp
RUN.radioServer()
local PR = ReplicatedStorage
local function rfire(name, ...) fakeClock += 2; PR:FindFirstChild(name).OnServerEvent:Fire(rp, ...) end
rfire("PlaceRadio", v3(1e9, 0, 0)); rfire("PlaceRadio", "abc"); rfire("PlaceRadio", v3(0 / 0, 0, 0))
check("R1. мусорная или далёкая позиция: радио не ставится", Workspace:FindFirstChild("DJ_Radio") == nil and rbp:FindFirstChild("Radio") ~= nil)
rfire("PlaceRadio", v3(3, 10, 0))
local placed = Workspace:FindFirstChild("DJ_Radio")
check("R2. радио поставлено, инструмент израсходован, кнопка «Настроить радио»", placed ~= nil and rbp:FindFirstChild("Radio") == nil and find(placed, "Base"):FindFirstChildOfClass("ProximityPrompt") ~= nil)
check("R2. старый дубль-скрипт внутри модели убран", find(placed, "Base.Script") == nil)
radioTool:Clone().Parent = rbp; rfire("PlaceRadio", v3(3, 10, 2))
local count = 0; for _, c in ipairs(methods.GetChildren(Workspace)) do if c.Name == "DJ_Radio" then count += 1 end end
check("R3. второе радио поставить нельзя (одно на игрока)", count == 1)
rfire("PlayTrack", "Song A")
local snd = find(placed, "Base.RadioSound")
check("R4. пресет-трек играет, NowPlaying = «Song A», клиенту «ок»", snd and snd.SoundId == "rbxassetid://111" and snd.IsPlaying and placed:GetAttribute("NowPlaying") == "Song A" and lastClient(PR.PlayTrack)[2] == true)
rfire("PlayTrack", "12345")
check("R5. свой трек без геймпасса: отказ (раньше сервер включал любой ID)", find(placed, "Base.RadioSound").SoundId == "rbxassetid://111" and lastClient(PR.PlayTrack)[2] == false and lastClient(PR.PlayTrack)[3] == "Свои треки — только с геймпассом")
MarketSvc.owns[rp.UserId] = true; fakeClock += 61
rfire("PlayTrack", 12345)
check("R6. с геймпассом: свой трек играет, «Свой трек #12345»", find(placed, "Base.RadioSound").SoundId == "rbxassetid://12345" and placed:GetAttribute("NowPlaying") == "Свой трек #12345")
rfire("PlayTrack", "abc"); check("R7. ID не из цифр: «Неверный ID трека»", lastClient(PR.PlayTrack)[3] == "Неверный ID трека")
rfire("PlayTrack", {}); rfire("PlayTrack", string.rep("1", 100))
check("R7. таблица и слишком длинная строка: без ошибок", find(placed, "Base.RadioSound").SoundId == "rbxassetid://12345")
PR.PlayTrack.OnServerEvent:Fire(rp, "Song A"); PR.PlayTrack.OnServerEvent:Fire(rp, "Song A")
local soundsNow = 0; for _, c in ipairs(methods.GetChildren(find(placed, "Base"))) do if c.Name == "RadioSound" then soundsNow += 1 end end
check("R8. смена трека не чаще раза в секунду, звук всегда один", soundsNow == 1)
rfire("StopTrack")
check("R9. стоп: звука нет, NowPlaying пустой", find(placed, "Base.RadioSound") == nil and placed:GetAttribute("NowPlaying") == "")
rfire("PickupRadio")
check("R10. подобрали: радио исчезло, инструмент снова в рюкзаке", Workspace:FindFirstChild("DJ_Radio") == nil and rbp:FindFirstChild("Radio") ~= nil)
rfire("PlaceRadio", v3(3, 10, 0)); PlayersSvc.PlayerRemoving:Fire(rp)
check("R11. игрок вышел: его радио убрано", Workspace:FindFirstChild("DJ_Radio") == nil)

-- ===================== UI-R. меню радио (клиент) =====================
resetWorld(); MarketSvc.owns = {}; MarketSvc.prompts = {}
local rcp = mkPlayer("DJClient", v3(0, 0, 0)); PlayersSvc.LocalPlayer = rcp; LocalPlayerRef = rcp
uiInst = newInst("ModuleScript", "UILib"); uiInst.Parent = ReplicatedStorage; UI = loadUILib(); moduleRegistry[uiInst] = UI
for _, n in ipairs({"PickupRadio", "PlayTrack", "StopTrack", "OpenRadioMenu"}) do remoteEvent(n) end
tracks = newInst("Folder", "RadioTracks"); tracks.Parent = ReplicatedStorage
for _, n in ipairs({"Бэ", "Аа"}) do local s = newInst("Sound", n); s.Parent = tracks end
RUN.radioMenu()
ReplicatedStorage.OpenRadioMenu.OnClientEvent:Fire()
local rgui = rcp:FindFirstChild("PlayerGui"):FindFirstChild("RadioUI")
local rbody = find(rgui, "Window.Panel.Body")
check("UI-R1. меню открылось по сигналу сервера, треки по алфавиту", find(rgui, "Window").Visible and find(rbody, "TrackList.Track1.Face.Label").Text == "▶  Аа" and find(rbody, "TrackList.Track2.Face.Label").Text == "▶  Бэ")
find(rbody, "TrackList.Track2.Face").Activated:Fire()
check("UI-R2. клик по треку отправляет его имя", ReplicatedStorage.PlayTrack._p.fired[1][1] == "Бэ")
find(rbody, "CustomRow.IdFrame.CustomBox").Text = "555"; find(rbody, "CustomRow.PlayCustom.Face").Activated:Fire()
check("UI-R3. свой трек без геймпасса: предложение купить, на сервер не уходит", #MarketSvc.prompts == 1 and #ReplicatedStorage.PlayTrack._p.fired == 1)
MarketSvc.owns[rcp.UserId] = true; MarketSvc.PromptGamePassPurchaseFinished:Fire(rcp, 1253905433, true)
find(rbody, "CustomRow.PlayCustom.Face").Activated:Fire()
check("UI-R3. купил геймпасс: свой трек уходит на сервер", ReplicatedStorage.PlayTrack._p.fired[2][1] == "555")
find(rbody, "CustomRow.IdFrame.CustomBox").Text = "abc"; find(rbody, "CustomRow.PlayCustom.Face").Activated:Fire()
check("UI-R4. ID не цифрами: уведомление, ничего не отправлено", #ReplicatedStorage.PlayTrack._p.fired == 2)
ReplicatedStorage.PlayTrack.OnClientEvent:Fire(false, "Сначала поставь радио")
check("UI-R5. отказ сервера показывается уведомлением", find(rcp:FindFirstChild("PlayerGui"), "Toasts.Holder") ~= nil)
find(rbody, "BottomRow.PickupButton.Face").Activated:Fire()
check("UI-R6. «Подобрать радио»: событие ушло, меню закрылось", ReplicatedStorage.PickupRadio._p.fired and not UI.get("Radio").isOpen())
runFor(3)

-- ===================== T. танцы (сервер) =====================
resetWorld()
local tp = mkPlayer("Dancer", v3(0, 0, 0)); local th = humanoidOf(tp); th.WalkSpeed = 16; th.JumpPower = 50
local dancesF = newInst("Folder", "Dances"); dancesF.Parent = ReplicatedStorage
local function mkDance(name, looped, block) local a = newInst("Animation", name); a.AnimationId = "rbxassetid://" .. #name; local l = newInst("BoolValue", "Looped"); l.Value = looped; l.Parent = a; local b = newInst("BoolValue", "BlockMovement"); b.Value = block; b.Parent = a; a.Parent = dancesF end
mkDance("Floss", true, true); mkDance("Wave", false, false)
local musicF = newInst("Folder", "DanceMusic"); musicF.Parent = ReplicatedStorage
remoteEvent("DanceRequest"); remoteEvent("DanceEnded")
RUN.danceServer()
local function dfire(name, ...) fakeClock += 1; ReplicatedStorage:FindFirstChild(name).OnServerEvent:Fire(tp, ...) end
dfire("DanceRequest", 123); dfire("DanceRequest", "нет такого")
check("T1. мусорное имя танца: ничего", tp:GetAttribute("Dancing") == nil)
dfire("DanceRequest", "Floss")
check("T2. танец: атрибут Dancing, ходить нельзя (BlockMovement)", tp:GetAttribute("Dancing") == "Floss" and th.WalkSpeed == 0)
dfire("DanceRequest", "Wave")
check("T3. новый танец сменяет старый (раньше игнорировался), скорость вернулась", tp:GetAttribute("Dancing") == "Wave" and th.WalkSpeed == 16)
dfire("DanceEnded"); dfire("DanceRequest", "Floss")
th.Died:Fire()
check("T4. смерть во время танца: запись очищена", tp:GetAttribute("Dancing") == nil)
dfire("DanceRequest", "Floss")
check("T4. после смерти танцевать снова можно (раньше — нет, до прыжка)", tp:GetAttribute("Dancing") == "Floss")
th.WalkSpeed = 24 -- купили апгрейд скорости во время танца
dfire("DanceEnded")
check("T5. скорость, изменённая во время танца, не сбрасывается", th.WalkSpeed == 24 and tp:GetAttribute("Dancing") == nil)

-- ===================== F. еда =====================
resetWorld()
local fp = mkPlayer("Eater", v3(0, 0, 0)); local fh = humanoidOf(fp); fh.Health = 10; fh.MaxHealth = 100
local ice = newInst("Tool", "IceCream"); local ev1 = remoteEvent("EatEvent", ice); ice.Parent = fp.Character
script = {Parent = ice}; RUN.eatIce()
for i = 1, 30 do ev1.OnServerEvent:Fire(fp) end
check("F1. мороженое: 30 событий за раз = один укус (+50), а не 30", fh.Health == 60)
fakeClock += 2; ev1.OnServerEvent:Fire(fp); fakeClock += 2; ev1.OnServerEvent:Fire(fp)
check("F1. всего два укуса, третий не работает", fh.Health == 100 and fh.Health <= fh.MaxHealth)
local milk = newInst("Tool", "milkynet"); local ev2 = remoteEvent("EatEvent", milk); milk.Parent = fp.Character
script = {Parent = milk}; RUN.eatMilk()
for i = 1, 50 do fakeClock += 2; ev2.OnServerEvent:Fire(fp) end
check("F2. молоко: спам не даёт бесконечное макс. ХП (+100 один раз)", fh.MaxHealth == 200)
local other = mkPlayer("Thief", v3(0, 0, 0)); local milk2 = newInst("Tool", "milkynet"); local ev3 = remoteEvent("EatEvent", milk2); milk2.Parent = fp.Character
script = {Parent = milk2}; RUN.eatMilk()
fakeClock += 2; ev3.OnServerEvent:Fire(other)
check("F3. чужую еду (в руках у другого) съесть нельзя", humanoidOf(other).MaxHealth == 100)
runFor(5)

-- ===================== I. сохранение предметов =====================
resetWorld(); stores = {}
DS:GetDataStore("PlayerTools"); stores.PlayerTools.fail = true
local ip = mkPlayer("Hoarder", v3(0, 0, 0)); local ibp = newInst("Backpack", "Backpack"); ibp.Parent = ip
stores.PlayerTools.data["tools_" .. ip.UserId] = {"Stick", "Radio"}
RUN.itemSave(); runFor(30)
PlayersSvc.PlayerRemoving:Fire(ip)
check("I1. загрузка не удалась: при выходе НЕ сохраняется пустой рюкзак (раньше все предметы пропадали)", stores.PlayerTools.writes == 0 and #stores.PlayerTools.data["tools_" .. ip.UserId] == 2)
resetWorld(); stores = {}
DS:GetDataStore("PlayerTools")
local stickT = newInst("Tool", "Stick"); stickT.Parent = ReplicatedStorage
local ip2 = mkPlayer("Keeper", v3(0, 0, 0)); local ibp2 = newInst("Backpack", "Backpack"); ibp2.Parent = ip2
ip2.Parent = newInst("Players", "Players") -- настоящий игрок лежит в Players
stores.PlayerTools.data["tools_" .. ip2.UserId] = {"Stick", "НетТакого", 42}
RUN.itemSave()
check("I2. загрузка: существующие инструменты выданы, мусор пропущен", ibp2:FindFirstChild("Stick") ~= nil and #methods.GetChildren(ibp2) == 1)
ibp2:FindFirstChild("Stick").Parent = ip2.Character
PlayersSvc.PlayerRemoving:Fire(ip2)
check("I3. инструмент в руках при выходе тоже сохраняется", stores.PlayerTools.data["tools_" .. ip2.UserId][1] == "Stick")

-- ===================== UI-E. меню эмоций (клиент) =====================
resetWorld()
local ep = mkPlayer("EmoteClient", v3(0, 0, 0)); PlayersSvc.LocalPlayer = ep; LocalPlayerRef = ep
uiInst = newInst("ModuleScript", "UILib"); uiInst.Parent = ReplicatedStorage; UI = loadUILib(); moduleRegistry[uiInst] = UI
dancesF = newInst("Folder", "Dances"); dancesF.Parent = ReplicatedStorage
for _, n in ipairs({"Wave", "Floss"}) do local a = newInst("Animation", n); a.Parent = dancesF end
local dr = remoteEvent("DanceRequest"); local de = remoteEvent("DanceEnded")
RUN.emotionMenu()
check("UI-E1. клавиша G привязана, окно ещё закрыто", CASvc.bound.ToggleEmotionMenu ~= nil and not UI.get("Emotes").isOpen())
CASvc.bound.ToggleEmotionMenu.fn("ToggleEmotionMenu", "UserInputState.Begin")
local egui = ep:FindFirstChild("PlayerGui"):FindFirstChild("EmotionGui")
check("UI-E2. G открывает меню, танцы по алфавиту", UI.get("Emotes").isOpen() and find(egui, "Window.Panel.Body.DanceList.Dance1.Face.Label").Text == "Floss")
CASvc.bound.StopDanceKey.fn("StopDanceKey", "UserInputState.Begin")
check("UI-E3. пробел, когда игрок не танцует: на сервер ничего не уходит (раньше — на каждый прыжок)", de._p.fired == nil)
find(egui, "Window.Panel.Body.DanceList.Dance2.Face").Activated:Fire()
check("UI-E4. выбор танца: запрос на сервер, меню закрылось", dr._p.fired[1][1] == "Wave" and not UI.get("Emotes").isOpen())
ep:SetAttribute("Dancing", "Wave")
CASvc.bound.StopDanceKey.fn("StopDanceKey", "UserInputState.Begin")
check("UI-E5. танцует + пробел: остановка ушла на сервер", de._p.fired and #de._p.fired == 1)
runFor(1)

os.clock = origClock; game.GetService = origGS; game.BindToClose = origBind
Enum = oldEnum
end
