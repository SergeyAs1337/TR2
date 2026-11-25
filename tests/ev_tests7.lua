do
print("--- B. EventBanner, S. UpgradeShop, C. gamble.lua (ответ клиенту)")
local oldEnum = Enum
Enum = setmetatable({}, {__index = function(_, a) return setmetatable({}, {__index = function(_, b) return a .. "." .. b end}) end})
local origWait = methods.WaitForChild
local function pollingWait(self, name, timeout)
	local waited = 0
	while true do
		local c = methods.FindFirstChild(self, name)
		if c then return c end
		if timeout and waited >= timeout then return nil end
		task.wait(0.1); waited += 0.1
	end
end
local function find(root, path) local cur = root; for name in string.gmatch(path, "[^%.]+") do cur = cur and cur:FindFirstChild(name) end return cur end

local UI = nil
local function setupClient(runner, opts)
	opts = opts or {}
	resetWorld(); tweenLog = {}
	local player = mkPlayer("Client", v3(0, 0, 0)); PlayersSvc.LocalPlayer = player; LocalPlayerRef = player
	local coins = nil
	if opts.coins then
		local ls = newInst("Folder", "leaderstats"); ls.Parent = player
		coins = newInst("IntValue", "Coins"); coins.Value = opts.coins; coins.Parent = ls
	end
	local uilibInst = newInst("ModuleScript", "UILib"); uilibInst.Parent = ReplicatedStorage
	UI = loadUILib(); moduleRegistry[uilibInst] = UI
	methods.WaitForChild = pollingWait
	return player, coins
end

-- ===== EventBanner =====
local player = setupClient()
local ann = ReplicatedStorage:FindFirstChild("EventAnnouncement") -- создаётся в resetWorld
runEventBanner()
local banner = find(player:FindFirstChild("PlayerGui"), "EventBanner.Banner")
local nameLabel = find(banner, "EventName")
local tagLabel = find(banner, "Tag")
check("B1. баннер создан кодом и скрыт", banner ~= nil and banner.Visible == false)
ann.OnClientEvent:Fire("🥵🥵Дождь из фур🥵🥵")
check("B2. событие: баннер виден, название, подпись «СОБЫТИЕ», оранжевая полоска", banner.Visible and nameLabel.Text == "🥵🥵Дождь из фур🥵🥵" and tagLabel.Text == "СОБЫТИЕ" and banner:FindFirstChild("Strip").BackgroundColor3 == UI.THEME.palette.warn.face)
runFor(1)
check("B2. выехал сверху на место", banner.Position[4] == 16)
runFor(4.2)
check("B2. через 5.2 с ещё виден (уезжает)", banner.Visible)
runFor(0.8)
check("B2. через 6 с спрятан", banner.Visible == false and banner.Position[4] == -120)
ann.OnClientEvent:Fire("📢 Всем привет!")
check("B3. объявление админа: подпись «ОБЪЯВЛЕНИЕ», синяя полоска, текст без 📢", banner:FindFirstChild("Strip").BackgroundColor3 == UI.THEME.palette.accent.face and tagLabel.Text == "ОБЪЯВЛЕНИЕ" and nameLabel.Text == "Всем привет!")
runFor(3)
ann.OnClientEvent:Fire("💀НЕКСБОТ НА ОХОТЕ💀")
runFor(3)
check("B4. новое объявление заменяет текущее, старый таймер не прячет новое", banner.Visible and nameLabel.Text == "💀НЕКСБОТ НА ОХОТЕ💀" and tagLabel.Text == "СОБЫТИЕ")
runFor(3)
check("B4. новое прячется по своему таймеру", banner.Visible == false)
ann.OnClientEvent:Fire(nil); ann.OnClientEvent:Fire(""); ann.OnClientEvent:Fire(123)
check("B5. nil, пустая строка, число игнорируются (остановка события из админки)", banner.Visible == false)
ann.OnClientEvent:Fire("Дождь")
check("B5. после мусора баннеры работают", banner.Visible and nameLabel.Text == "Дождь")
runFor(7)

-- ===== UpgradeShop =====
local pl, coins = setupClient(nil, { coins = 300 })
local upEvent = newInst("RemoteEvent", "UpgradeRequest"); upEvent.Parent = ReplicatedStorage
runUpgradeShop()
local shopGui = pl:FindFirstChild("PlayerGui"):FindFirstChild("UpgradeGUI")
local cards = find(shopGui, "Window.Panel.Body.Cards")
local function card(name) return cards:FindFirstChild(name) end
local function buyLabel(name) return find(card(name), "BuyButton.Face.Label").Text end
local function filled(name) return math.floor(find(card(name), "Bar.Fill").Size[1] * 10 + 0.5) end
local function buyColor(name) return find(card(name), "BuyButton.Face").BackgroundColor3 end
runFor(1)
check("S1. окно UpgradeGUI создано кодом и закрыто; 4 карточки", shopGui ~= nil and find(shopGui, "Window").Visible == false and card("Health") and card("Speed") and card("Regen") and card("CoinMultiplier"))
check("S1. открывается по имени «Upgrades»", UI.open("Upgrades") and find(shopGui, "Window").Visible)
check("S2. без данных: все на уровне 1, «Купить · 🪙 100»", find(card("Health"), "LevelText").Text == "1 / 10" and buyLabel("Speed") == "Купить · 🪙 100" and filled("Regen") == 1)
check("S2. «было → станет»: 100 ХП → 200 ХП; 16 → 17.8; x1 → x2", find(card("Health"), "Effect").Text == "100 ХП  →  200 ХП" and find(card("Speed"), "Effect").Text == "16  →  17.8" and find(card("CoinMultiplier"), "Effect").Text == "x1  →  x2")
check("S2. реген: 5% / 5с → 5.6% / 4.8с", find(card("Regen"), "Effect").Text == "5% / 5с  →  5.6% / 4.8с")
check("S2. баланс в шапке «Баланс: 🪙 300»", find(shopGui, "Window.Panel.Body.Balance").Text == "Баланс: 🪙 300")

pl:SetAttribute("Upgrades", '{"Health":3,"Speed":10,"Regen":2,"CoinMultiplier":1}')
check("S3. загрузка данных после входа не засыпает уведомлениями «уровень N!»", find(pl:FindFirstChild("PlayerGui"), "Toasts") == nil)
runFor(0.5)
check("S3. атрибут Upgrades пришёл: уровни, полоски и цены обновились", find(card("Health"), "LevelText").Text == "3 / 10" and filled("Health") == 3 and buyLabel("Health") == "Купить · 🪙 400" and buyLabel("Regen") == "Купить · 🪙 200")
check("S3. максимальный уровень: «Максимум», кнопка серая, «· максимум»", buyLabel("Speed") == "Максимум" and buyColor("Speed") == UI.THEME.palette.neutral.face and find(card("Speed"), "Effect").Text == "32 · максимум")
local firedBefore = upEvent._p.fired and #upEvent._p.fired or 0
find(card("Speed"), "BuyButton.Face").Activated:Fire()
check("S3. нажатие на «Максимум» ничего не отправляет на сервер", (upEvent._p.fired and #upEvent._p.fired or 0) == firedBefore)
check("S3. не хватает монет (400 > 300): кнопка серая", buyColor("Health") == UI.THEME.palette.neutral.face)
check("S3. хватает (200 ≤ 300): кнопка зелёная", buyColor("Regen") == UI.THEME.palette.good.face)
coins.Value = 5000
check("S3. монеты выросли: кнопка Health стала зелёной, баланс обновился", buyColor("Health") == UI.THEME.palette.good.face and find(shopGui, "Window.Panel.Body.Balance").Text == "Баланс: 🪙 5 000")

find(card("Regen"), "BuyButton.Face").Activated:Fire()
check("S4. покупка отправляет имя апгрейда на сервер", upEvent._p.fired and #upEvent._p.fired == 1 and upEvent._p.fired[1][1] == "Regen")
pl:SetAttribute("Upgrades", '{"Health":3,"Speed":10,"Regen":3,"CoinMultiplier":1}')
local toastHolder = find(pl:FindFirstChild("PlayerGui"), "Toasts.Holder")
check("S4. уровень вырос: уведомление «💚 Регенерация: уровень 3»", toastHolder and toastHolder:FindFirstChild("Toast") and toastHolder:FindFirstChild("Toast"):FindFirstChild("Label").Text == "💚 Регенерация: уровень 3")
runFor(3)
upEvent.OnClientEvent:Fire("Health", false, "Недостаточно монет!")
check("S5. отказ сервера показывает его текст", toastHolder:FindFirstChild("Toast"):FindFirstChild("Label").Text == "Недостаточно монет!")
upEvent.OnClientEvent:Fire("Health", true)
upEvent.OnClientEvent:Fire("???", false, nil)
check("S5. успех и мусор в ответе не ломают окно", true)
pl:SetAttribute("Upgrades", "не json")
check("S6. битый атрибут: всё на уровне 1, без ошибки", find(card("Health"), "LevelText").Text == "1 / 10")
pl:SetAttribute("Upgrades", '{"Health":99,"Speed":-3}')
check("S6. уровни вне 1..10 зажимаются", find(card("Health"), "LevelText").Text == "10 / 10" and find(card("Speed"), "LevelText").Text == "1 / 10")
runFor(3)

-- окна закрывают друг друга (автомат + апгрейды в одном UILib)
local ge = newInst("RemoteEvent", "GambleEvent"); ge.Parent = ReplicatedStorage
local gs = newInst("Folder", "GlobalStats"); gs.Parent = ReplicatedStorage
local tl = newInst("IntValue", "TotalLost"); tl.Value = 0; tl.Parent = gs
local gsInst = newInst("ModuleScript", "GambleScreen"); gsInst.Parent = ReplicatedStorage; moduleRegistry[gsInst] = loadGambleScreen()
local gamble = moduleRegistry[gsInst].get(pl)
UI.open("Upgrades"); gamble.show()
check("S7. открыли автомат — окно апгрейдов закрылось", gamble.isOpen() and not UI.get("Upgrades").isOpen())
UI.open("Upgrades")
check("S7. и наоборот", UI.get("Upgrades").isOpen() and not gamble.isOpen())
methods.WaitForChild = origWait

-- ===== gamble.lua: ответ клиенту =====
resetWorld()
local nextRoll = 0.5
local oldRandom = Random
Random = {new = function() return {NextNumber = function() return nextRoll end} end}
local stores = {}
local DS = {GetDataStore = function(self, name) stores[name] = stores[name] or {data = {}}; local st = stores[name]
	return {GetAsync = function(_, k) return st.data[k] end, UpdateAsync = function(_, k, f) st.data[k] = f(st.data[k]); return st.data[k] end} end}
local origGS = game.GetService
game.GetService = function(self, n) if n == "DataStoreService" then return DS end return origGS(self, n) end
local origBind = game.BindToClose; game.BindToClose = function() end
local remote = newInst("RemoteEvent", "GambleEvent"); remote.OnServerEvent = Signal(); remote.Parent = ReplicatedStorage
local origClock = os.clock; local fakeClock = 100; os.clock = function() return fakeClock end
runGambleServer()
local gp = mkPlayer("Better", v3(0, 0, 0))
local gls = newInst("Folder", "leaderstats"); gls.Parent = gp
local gc = newInst("IntValue", "Coins"); gc.Value = 1000; gc.Parent = gls
local function bet(amount) remote.OnServerEvent:Fire(gp, amount); fakeClock += 2; local r = remote._p.clientFired; return r and r[#r] end
nextRoll = 0.005; local r = bet(100)
check("C1. x10: ответ { ok, bet = 100, multiplier = 10, win = 1000 }, монеты 1000-100+1000", r[1] == gp and r[2].ok == true and r[2].bet == 100 and r[2].multiplier == 10 and r[2].win == 1000 and gc.Value == 1900)
nextRoll = 0.1; r = bet(100)
check("C1. x2: multiplier = 2, win = 200", r[2].ok and r[2].multiplier == 2 and r[2].win == 200 and gc.Value == 2000)
nextRoll = 0.9; r = bet(100)
local lostNow = ReplicatedStorage:FindFirstChild("GlobalStats"):FindFirstChild("TotalLost").Value
check("C1. проигрыш: multiplier = 0, win = 0, монеты списаны, счётчик проигранного вырос", r[2].ok and r[2].multiplier == 0 and r[2].win == 0 and gc.Value == 1900 and lostNow == 100)
r = bet(1e12)
check("C2. неверная ставка: { ok = false, reason = «Неверная ставка» }, монеты не тронуты", r[2].ok == false and r[2].reason == "Неверная ставка" and gc.Value == 1900)
r = bet("100")
check("C2. ставка-строка: отказ", r[2].ok == false and r[2].reason == "Неверная ставка")
r = bet(5000)
check("C2. ставка больше баланса: «Не хватает монет!»", r[2].ok == false and r[2].reason == "Не хватает монет!" and gc.Value == 1900)
remote.OnServerEvent:Fire(gp, 10); remote.OnServerEvent:Fire(gp, 10)
r = remote._p.clientFired[#remote._p.clientFired]
check("C3. две ставки за секунду: вторая «Не так быстро!», списана одна", r[2].ok == false and r[2].reason == "Не так быстро!" and gc.Value == 1890)
os.clock = origClock; game.GetService = origGS; game.BindToClose = origBind; Random = oldRandom
Enum = oldEnum
end
