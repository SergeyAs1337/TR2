do
print("--- W. Работа грузчиком (BoxJob + BoxJobHud)")
local oldEnum = Enum
Enum = setmetatable({}, {__index = function(_, a) return setmetatable({}, {__index = function(_, b) return a .. "." .. b end}) end})
local function find(root, path) local cur = root; for name in string.gmatch(path, "[^%.]+") do cur = cur and cur:FindFirstChild(name) end return cur end
local origClock = os.clock; local fakeClock = 5000; os.clock = function() return fakeClock end

local function setup(opts)
	opts = opts or {}
	resetWorld(); tags = {}
	local nmod = newInst("ModuleScript", "Notify"); nmod.Parent = ServerScriptService
	local notes = {}
	moduleRegistry[nmod] = {send = function(pl, text, color) table.insert(notes, {pl, text, color}) end, openScreen = function() end}
	local pickup = mkPart("BoxPickup", v3(0, 0, 0), true); pickup.Size = v3(4, 1, 4); pickup.Parent = Workspace
	local zone = mkPart("BoxDelivery", v3(140, 0, 0), true); zone.Size = v3(10, 8, 10); zone.Parent = Workspace
	local player = mkPlayer("Porter", v3(0, 0, 0))
	local hum = player.Character:FindFirstChildOfClass("Humanoid"); hum.WalkSpeed = 16
	if opts.base then hum:SetAttribute("BaseWalkSpeed", opts.base); hum.WalkSpeed = opts.base end
	local ls = newInst("Folder", "leaderstats"); local coins = newInst("IntValue", "Coins"); coins.Value = 0; coins.Parent = ls; ls.Parent = player
	if opts.mult then player:SetAttribute("CoinMultiplier", opts.mult) end
	RUN.boxJob()
	local prompt = pickup:FindFirstChildOfClass("ProximityPrompt")
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	local function take(n) for i = 1, (n or 1) do fakeClock += 1; prompt.Triggered:Fire(player) end end
	local function walkTo(pos, seconds) fakeClock += seconds or 5; root.Position = pos; runFor(0.3) end
	return player, hum, coins, prompt, take, walkTo, notes, zone, root
end
local function boxes() local f = Workspace:FindFirstChild("CarriedBoxes"); return f and methods.GetChildren(f) or {} end

local player, hum, coins, prompt, take, walkTo, notes, zone, root = setup()
check("W1. на детали BoxPickup появилась кнопка «Взять коробку», её надо зажимать", prompt ~= nil and prompt.ActionText == "Взять коробку" and prompt.HoldDuration == 0.6)
take(1)
local b1 = boxes()[1]
check("W2. взял коробку: физическая коробка в мире, на верёвке к игроку", #boxes() == 1 and b1.Anchored == false and find(b1, "Rope").ClassName == "RopeConstraint" and find(b1, "Rope").Attachment0.Parent == root)
check("W2. физикой коробки управляет игрок, свой носильщик её не толкает", b1._p.NetOwner == player and b1.CollisionGroup == "TR2Boxes")
check("W3. каждая коробка замедляет: 16 -> 14.5", hum.WalkSpeed == 14.5 and player:GetAttribute("BoxesCarried") == 1)
take(1)
local b2 = boxes()[2]
check("W3. вторая коробка висит на первой (цепочка)", find(b2, "Rope").Attachment0.Parent == b1 and hum.WalkSpeed == 13)
take(4)
check("W4. 6 коробок: скорость 7 — меньше 8, больше взять нельзя", #boxes() == 6 and hum.WalkSpeed == 7 and player:GetAttribute("BoxesCanTake") == 0)
take(1)
check("W4. 7-я не берётся, игроку «Слишком тяжело!»", #boxes() == 6 and notes[#notes][2] == "Слишком тяжело! Отнеси коробки в фуру")

-- доставка
walkTo(v3(140, 0, 0), 5)
check("W6. зашёл в триггер фуры: все 6 сданы, 5 × 10 + 15 = 65 (6-я уже по серии x1.5)", #boxes() == 0 and coins.Value == 65 and player:GetAttribute("BoxStreak") == 6)
check("W6. скорость вернулась, уведомление о доставке", hum.WalkSpeed == 16 and string.find(notes[#notes][2], "Доставлено 📦 6", 1, true) ~= nil)
check("W7. после 6 коробок подряд множитель серии x1.5, за коробку 15", player:GetAttribute("BoxStreakMult") == 1.5 and player:GetAttribute("BoxRewardEach") == 15)

-- серия растёт до x10
for round = 1, 20 do
	root.Position = v3(0, 0, 0); take(5); walkTo(v3(140, 0, 0), 5)
end
check(("W8. серия %d: множитель упёрся в x10"):format(player:GetAttribute("BoxStreak")), player:GetAttribute("BoxStreakMult") == 10)

-- множитель монет (апгрейд) умножается на серию
player:SetAttribute("CoinMultiplier", 3)
check("W9. апгрейд x3 × серия x10: 10 × 3 × 10 = 300 за коробку", player:GetAttribute("BoxRewardEach") == 300)
local before = coins.Value
root.Position = v3(0, 0, 0); take(2); walkTo(v3(140, 0, 0), 5)
check("W9. сдал 2 коробки: +600", coins.Value - before == 600)

-- коробка, закинутая в триггер, сдаётся сама
root.Position = v3(0, 0, 0); take(2)
fakeClock += 5; boxes()[2].Position = v3(141, 0, 1); runFor(0.3)
check("W10. закинул одну коробку в фуру, сам снаружи: сдана только она", #boxes() == 1)

-- смерть: коробки взрываются, серия теряется, апгрейд остаётся
take(2)
local exploded = 0
local hadBoxes = #boxes()
hum.Died:Fire()
for _, c in ipairs(methods.GetChildren(Workspace)) do if c.ClassName == "Explosion" then exploded += 1; if c.DestroyJointRadiusPercent ~= 0 then exploded = -100 end end end
check(("W11. смерть: %d коробки исчезли, столько же взрывов (не убивающих)"):format(hadBoxes), #boxes() == 0 and exploded == hadBoxes)
check("W11. серия потеряна, множитель апгрейда остался", player:GetAttribute("BoxStreak") == 0 and player:GetAttribute("BoxStreakMult") == 1 and player:GetAttribute("BoxRewardEach") == 30 and notes[#notes][2] == "Серия потеряна 💥")

-- быстрый игрок (апгрейд скорости) несёт больше
local p2, hum2, coins2, prompt2, take2 = setup({base = 32})
take2(20)
check(("W12. скорость 32 (апгрейд): можно взять больше — %d коробок"):format(#boxes()), #boxes() == 17 and hum2.WalkSpeed == 6.5)
hum2:SetAttribute("BaseWalkSpeed", 16)
check("W12. скорость упала (сменилась база): замедление пересчитано, брать нельзя", hum2.WalkSpeed == 4 and p2:GetAttribute("BoxesCanTake") == 0)

-- коробку уничтожило что-то ещё (событие «Вьетнам»)
local p3, hum3, coins3, prompt3, take3 = setup()
take3(3)
boxes()[2]:Destroy()
check("W13. коробку уничтожил взрыв события: список и скорость пересчитаны, цепочка перевязана", #boxes() == 2 and p3:GetAttribute("BoxesCarried") == 2 and hum3.WalkSpeed == 13 and find(boxes()[2], "Rope").Attachment0.Parent == boxes()[1])

-- выход игрока
PlayersSvc.PlayerRemoving:Fire(p3)
check("W14. игрок вышел: его коробки убраны", #boxes() == 0)

-- телепорт с коробкой к фуре
local p5, hum5, coins5, prompt5, take5, walk5 = setup()
take5(1); walk5(v3(140, 0, 0), 0)
check("W5. взял коробку и через секунду оказался у фуры за 140 studs (телепорт): не сдаётся", #boxes() == 1 and coins5.Value == 0)
walk5(v3(140, 0, 0), 3)
check("W5. прошло достаточно времени: сдаётся", #boxes() == 0 and coins5.Value == 10)

-- монеты ещё не загрузились
local p4, hum4, coins4, prompt4, take4, walk4, notes4, zone4, root4 = setup()
p4:FindFirstChild("leaderstats"):Destroy()
take4(1); walk4(v3(140, 0, 0), 5)
check("W15. монет ещё нет: коробка не сдаётся и не пропадает", #boxes() == 1)

-- клиент: плашка
resetWorld(); tags = {}
local cp = mkPlayer("PorterClient", v3(0, 0, 0)); PlayersSvc.LocalPlayer = cp; LocalPlayerRef = cp
local uiInst = newInst("ModuleScript", "UILib"); uiInst.Parent = ReplicatedStorage; local UI = loadUILib(); moduleRegistry[uiInst] = UI
local folder = newInst("Folder", "CarriedBoxes"); folder.Parent = Workspace
RUN.boxJobHud()
local hp = find(cp:FindFirstChild("PlayerGui"), "BoxJobGui.Panel")
check("UI-W1. плашка работы скрыта, пока нет коробок и серии", hp ~= nil and hp.Visible == false)
cp:SetAttribute("BoxesCarried", 3); cp:SetAttribute("BoxesCanTake", 2); cp:SetAttribute("BoxStreak", 12); cp:SetAttribute("BoxStreakMult", 3); cp:SetAttribute("BoxRewardEach", 60)
check("UI-W2. несёт коробки: «📦 3», «Можно ещё 2», «Серия 12 · x3», «+60 🪙 за коробку»", hp.Visible and hp:FindFirstChild("Boxes").Text == "📦 3" and hp:FindFirstChild("Hint").Text == "Можно ещё 2 · неси в фуру" and hp:FindFirstChild("Streak").Text == "Серия 12 · x3" and hp:FindFirstChild("Reward").Text == "+60 🪙 за коробку")
cp:SetAttribute("BoxStreakMult", 2.5); cp:SetAttribute("BoxesCanTake", 0)
check("UI-W2. дробный множитель «x2.5», «Слишком тяжело»", hp:FindFirstChild("Streak").Text == "Серия 12 · x2.5" and hp:FindFirstChild("Hint").Text == "Слишком тяжело · неси в фуру")
cp:SetAttribute("BoxesCarried", 0); cp:SetAttribute("BoxStreak", 0)
check("UI-W3. нет коробок и серии: плашка спрятана", hp.Visible == false)

-- клиент: удар фуры
local myBox = newInst("Part", "CarryBox"); myBox:SetAttribute("Owner", cp.UserId); myBox.Position = v3(0, 0, 0); myBox.Parent = folder
local chBox = newInst("Part", "CarryBox"); chBox:SetAttribute("Owner", 999999); chBox.Position = v3(0, 0, 0); chBox.Parent = folder
folder.ChildAdded:Fire(myBox); folder.ChildAdded:Fire(chBox); runFor(0.1)
local truck = newInst("Model", "Furocka2"); local tpart = mkPart("Body", v3(-5, 0, 0), true); tpart.Parent = truck; truck.Parent = Workspace
myBox.Touched:Fire(tpart)
local vel = myBox.AssemblyLinearVelocity
check("UI-W4. фура задела свою коробку: коробка улетела от фуры и вверх", vel.X > 50 and vel.Y > 0)
local rootC = cp.Character:FindFirstChild("HumanoidRootPart")
check("UI-W4. игрока дёрнуло за коробкой", rootC.AssemblyLinearVelocity.X > 20)
chBox.Touched:Fire(tpart)
check("UI-W5. чужие коробки клиент не трогает", chBox.AssemblyLinearVelocity.X == 0)
local wall = mkPart("Wall", v3(-5, 0, 0), true); wall.Parent = Workspace
myBox.AssemblyLinearVelocity = v3(0, 0, 0); fakeClock += 1; myBox.Touched:Fire(wall)
check("UI-W6. обычная стена коробку не отбрасывает", myBox.AssemblyLinearVelocity.X == 0)

os.clock = origClock
Enum = oldEnum
end
