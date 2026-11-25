do
print("--- H/K. CoinsHud v3 и CoinPopups v3")
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

local sharedUI = nil
local function setup(runner, withStats, startCoins, startDeaths)
	resetWorld(); tweenLog = {}
	local player = mkPlayer("Hud", v3(0, 0, 0)); PlayersSvc.LocalPlayer = player; LocalPlayerRef = player
	local coins, deaths = nil, nil
	local function addStats()
		local ls = newInst("Folder", "leaderstats")
		coins = newInst("IntValue", "Coins"); coins.Value = startCoins or 0; coins.Parent = ls
		deaths = newInst("IntValue", "Deaths"); deaths.Value = startDeaths or 0; deaths.Parent = ls
		ls.Parent = player
		return coins, deaths
	end
	if withStats then addStats() end
	local uilibInst = newInst("ModuleScript", "UILib"); uilibInst.Parent = ReplicatedStorage
	sharedUI = loadUILib(); moduleRegistry[uilibInst] = sharedUI
	methods.WaitForChild = pollingWait
	runner()
	return player, coins, deaths, addStats
end

-- ===== CoinsHud =====
local player, coins, deaths = setup(runCoinsHud, true, 1234567, 42)
local gui = player:FindFirstChild("PlayerGui"):FindFirstChild("CoinsDeaths")
local frame = gui and gui:FindFirstChild("Frame")
local coinsValue = frame:FindFirstChild("Coins"):FindFirstChild("Value")
local deathsValue = frame:FindFirstChild("Deaths"):FindFirstChild("Value")
check("H1. HUD создан кодом, не пересоздаётся при респавне, подстраивается под экран", gui ~= nil and gui.ResetOnSpawn == false and frame:FindFirstChild("FitScale") ~= nil)
check("H1. слева посередине: якорь (0, 0.5)", frame.AnchorPoint[1] == 0 and frame.AnchorPoint[2] == 0.5 and frame.Position[3] == 0.5)
check("H1. плашки монет и смертей, кнопка «⬆ Апгрейды»", coinsValue ~= nil and deathsValue ~= nil and frame:FindFirstChild("UpgradesButton"):FindFirstChild("Face"):FindFirstChild("Label").Text == "⬆  Апгрейды")
runFor(0.5)
check("H2. стартовые значения: монеты «1.23M», смерти «42»", coinsValue.Text == "1.23M" and deathsValue.Text == "42")
coins.Value = 50
check("H3. монеты меняются не мгновенно, а докручиваются…", coinsValue.Text ~= "50")
runFor(0.6)
check("H3. …и через 0.4 с показывают точное значение", coinsValue.Text == "50")
coins.Value = 1000; coins.Value = 123456; runFor(0.6)
check("H3. несколько изменений подряд: показывается последнее, «123 456»", coinsValue.Text == "123 456")
deaths.Value = 43; runFor(0.6)
check("H3. смерти обновляются", deathsValue.Text == "43")
check("H3. один обработчик на монеты", #coins._p._changed.Value.handlers == 1)

-- кнопка меню открывает окно по имени
local w = sharedUI.window({ name = "Upgrades", title = "x" })
frame:FindFirstChild("UpgradesButton"):FindFirstChild("Face").Activated:Fire()
check("H4. кнопка «Апгрейды» открывает окно Upgrades…", w.isOpen())
frame:FindFirstChild("UpgradesButton"):FindFirstChild("Face").Activated:Fire()
check("H4. …и повторным нажатием закрывает", not w.isOpen())
w.gui:Destroy(); local wc = warnCount
frame:FindFirstChild("UpgradesButton"):FindFirstChild("Face").Activated:Fire()
check("H4. окна нет: предупреждение, без ошибки", warnCount == wc + 1)

-- данные грузятся позже
local p2, c2, d2, addLate = setup(runCoinsHud, false)
local v2 = p2:FindFirstChild("PlayerGui"):FindFirstChild("CoinsDeaths"):FindFirstChild("Frame"):FindFirstChild("Coins"):FindFirstChild("Value")
check("H5. пока данных нет, на плашке «…»", v2.Text == "…")
runFor(40)
check("H5. через 40 с данных всё ещё нет: «…», без ошибок", v2.Text == "…")
local late = addLate(); late.Value = 777; runFor(1)
check("H5. когда leaderstats появился, значение подхватилось", v2.Text == "777")
late.Value = 888; runFor(1); check("H5. и дальше обновляется", v2.Text == "888")

local p3 = setup(runCoinsHud, false)
local before = warnCount
runFor(200)
check("H6. leaderstats так и не появился: по предупреждению на монеты и смерти, без падения", warnCount == before + 2)

local p4 = setup(runCoinsHudRaw, true, 1234567)
check("H7. FORMAT_NUMBERS=false: число как есть, «1234567»", p4:FindFirstChild("PlayerGui"):FindFirstChild("CoinsDeaths"):FindFirstChild("Frame"):FindFirstChild("Coins"):FindFirstChild("Value").Text == "1234567")

-- ===== CoinPopups =====
local function popupsOf(g) local out = {}; for _, c in ipairs(methods.GetChildren(g:FindFirstChild("Area"))) do if c.Name == "Popup" then table.insert(out, c) end end return out end
local pl, cn = setup(runCoinPopups, true, 100)
local pg = pl:FindFirstChild("PlayerGui"):FindFirstChild("CoinPopupGui")
local snd = pg:FindFirstChild("CoinSound")
check("K1. CoinPopupGui создан кодом; звук rbxassetid://5613553529, громкость 0.5", pg ~= nil and pg.ResetOnSpawn == false and snd and snd.SoundId == "rbxassetid://5613553529" and snd.Volume == 0.5)
check("K1. пока монеты не менялись, всплывашек нет", #popupsOf(pg) == 0)
cn.Value = 350
local ps = popupsOf(pg)
check("K2. ПЕРВОЕ же изменение монет показывает всплывашку", #ps == 1)
local pop = ps[1]
check("K2. «+250 🪙» цвета монет с контуром, звук сыгран", pop.Text == "+250 🪙" and pop.TextColor3 == sharedUI.THEME.coin and pop:FindFirstChildOfClass("UIStroke") ~= nil and snd.PlayCount == 1)
check("K2. старт возле (0.5, 0.7) с разбросом по X ±100 и Y ±50", pop.Position[1] == 0.5 and pop.Position[3] == 0.7 and math.abs(pop.Position[2]) <= 100 and math.abs(pop.Position[4]) <= 50)
check("K2. появляется с анимацией: стартовый масштаб 0.6", pop:FindFirstChildOfClass("UIScale").Scale == 0.6)
runFor(0.5); check("K3. через 0.5 с всплывашка ещё видна", #popupsOf(pg) == 1)
runFor(0.6); check("K3. через 1.1 с удалена", #popupsOf(pg) == 0)
cn.Value = 250
pop = popupsOf(pg)[1]
check("K4. «−100 🪙» красным", pop.Text == "−100 🪙" and pop.TextColor3 == sharedUI.THEME.palette.bad.hover)
runFor(1.1)
cn.Value = 250
check("K4. то же значение всплывашку не рисует", #popupsOf(pg) == 0)
cn.Value = 1250250; pop = popupsOf(pg)[1]
check("K4. крупная сумма с разделителями и крупнее: «+1 250 000 🪙», размер 30", pop.Text == "+1 250 000 🪙" and pop.TextSize == 30); runFor(1.1)

for i = 1, 30 do cn.Value = cn.Value + i end
check(("K5. шквал из 30 изменений: одновременно не больше 12 (сейчас %d)"):format(#popupsOf(pg)), #popupsOf(pg) == 12)
runFor(1.2)
check("K5. всплывашки исчезли, счётчик освободился", #popupsOf(pg) == 0)
cn.Value = cn.Value + 5
check("K5. после шквала новые снова появляются", #popupsOf(pg) == 1); runFor(1.2)

local pl2, cn2, d22, addLate2 = setup(runCoinPopups, false)
local pg2 = pl2:FindFirstChild("PlayerGui"):FindFirstChild("CoinPopupGui")
runFor(30)
local lateCoins = addLate2(); lateCoins.Value = 500; runFor(1)
check("K6. данные пришли позже: загрузка не даёт всплывашки", #popupsOf(pg2) == 0)
lateCoins.Value = 520
check("K6. а следующее изменение показывает +20", #popupsOf(pg2) == 1 and popupsOf(pg2)[1].Text == "+20 🪙")
local pl3 = setup(runCoinPopups, false)
local b3 = warnCount; runFor(200)
check("K7. leaderstats так и не появился: предупреждение, без падения", warnCount == b3 + 1)
methods.WaitForChild = origWait
Enum = oldEnum
end
