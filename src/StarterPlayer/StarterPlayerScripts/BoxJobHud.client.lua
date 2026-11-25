-- StarterPlayer/StarterPlayerScripts/BoxJobHud  (LocalScript)  v1 — работа грузчиком
-- 1) Плашка снизу экрана, пока игрок несёт коробки или у него есть серия:
--    «📦 3 · можно ещё 2», «Серия 12 · x3», «+60 🪙 за коробку», подсказка «Неси в фуру».
--    Данные — атрибуты игрока от сервера (BoxJob).
-- 2) Удар фуры: коробками управляет физика игрока, поэтому отбрасывает их клиент.
--    Фура задела коробку -> коробка улетает, а верёвка (и небольшой рывок) тащит игрока за ней.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

-- ===== Настройки удара =====
local TRUCK_NAME_PATTERN = "^Furocka" -- модели фур: Furocka, Furocka2, Furocka3...
local FAST_PART_SPEED = 35 -- любая деталь быстрее этого тоже отбрасывает коробку
local FLING_SPEED = 90 -- скорость коробки после удара
local FLING_UP = 35
local PLAYER_PULL = 45 -- рывок игрока в сторону улетевшей коробки
local HIT_COOLDOWN = 0.6

local player = Players.LocalPlayer

-- ===================================================================================
-- Плашка
-- ===================================================================================
local gui = UILib.screenGui("BoxJobGui", 8, player)

local panel = UILib.panel(gui, {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0, 420, 0, 64),
	BackgroundColor3 = THEME.background,
	BackgroundTransparency = 0.05,
	Visible = false,
})
UILib.stroke(panel, 1, THEME.border)
UILib.fitScale(panel)
local panelScale = UILib.make("UIScale", { Name = "Bump", Scale = 1 }, panel)

UILib.make("Frame", { -- оранжевая полоска: работа
	Name = "Strip",
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.new(0, 4, 1, -20),
	BackgroundColor3 = UILib.palette("warn").face,
	BorderSizePixel = 0,
}, panel)

local boxesLabel = UILib.text(panel, "", {
	Name = "Boxes",
	Position = UDim2.new(0, 24, 0, 8),
	Size = UDim2.new(0.5, -24, 0, 24),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local hintLabel = UILib.text(panel, "", {
	Name = "Hint",
	Position = UDim2.new(0, 24, 0, 34),
	Size = UDim2.new(0.5, -24, 0, 20),
	TextSize = 13,
	Font = THEME.fontBody,
	TextColor3 = THEME.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local streakLabel = UILib.text(panel, "", {
	Name = "Streak",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 8),
	Size = UDim2.new(0.5, -14, 0, 24),
	TextSize = 18,
	TextColor3 = UILib.palette("warn").hover,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local rewardLabel = UILib.text(panel, "", {
	Name = "Reward",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 34),
	Size = UDim2.new(0.5, -14, 0, 20),
	TextSize = 13,
	Font = THEME.fontBody,
	TextColor3 = THEME.muted,
	TextXAlignment = Enum.TextXAlignment.Right,
})

local function num(name)
	local value = player:GetAttribute(name)
	return typeof(value) == "number" and value or 0
end

local function formatMult(value)
	local text = string.format("%.1f", value)
	return (string.gsub(text, "%.0$", ""))
end

local lastStreak = 0
local function render()
	local carried = num("BoxesCarried")
	local canTake = num("BoxesCanTake")
	local streak = num("BoxStreak")
	local mult = math.max(1, num("BoxStreakMult"))

	panel.Visible = carried > 0 or streak > 0
	boxesLabel.Text = "📦 " .. carried
	if carried == 0 then
		hintLabel.Text = "Возьми коробки на почте"
	elseif canTake > 0 then
		hintLabel.Text = "Можно ещё " .. canTake .. " · неси в фуру"
	else
		hintLabel.Text = "Слишком тяжело · неси в фуру"
	end
	streakLabel.Text = "Серия " .. streak .. " · x" .. formatMult(mult)
	rewardLabel.Text = "+" .. UILib.formatNumber(num("BoxRewardEach")) .. " 🪙 за коробку"

	if streak > lastStreak then
		UILib.bump(panelScale, 1.06)
	end
	lastStreak = streak
end

for _, name in { "BoxesCarried", "BoxesCanTake", "BoxStreak", "BoxStreakMult", "BoxRewardEach" } do
	player:GetAttributeChangedSignal(name):Connect(render)
end
render()

-- ===================================================================================
-- Удар фуры по своим коробкам
-- ===================================================================================
local function isTruckPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if string.match(model.Name, TRUCK_NAME_PATTERN) then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function fling(box, hit)
	local away = box.Position - hit.Position
	away = Vector3.new(away.X, 0, away.Z)
	local hitVelocity = hit.AssemblyLinearVelocity
	if hitVelocity.Magnitude > 1 then
		away = Vector3.new(hitVelocity.X, 0, hitVelocity.Z) -- летит туда, куда ехала фура
	end
	if away.Magnitude < 0.01 then
		away = Vector3.new(0, 0, 1)
	end
	local direction = away.Unit
	box.AssemblyLinearVelocity = direction * FLING_SPEED + Vector3.new(0, FLING_UP, 0)

	-- верёвка натянется и потащит игрока; добавим рывок, чтобы это чувствовалось сразу
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		root.AssemblyLinearVelocity = direction * PLAYER_PULL + Vector3.new(0, FLING_UP * 0.5, 0)
	end
end

local watched = {}
local function watchBox(box)
	if watched[box] or not box:IsA("BasePart") or box:GetAttribute("Owner") ~= player.UserId then
		return
	end
	watched[box] = true
	local lastHit = -math.huge
	box.Touched:Connect(function(hit)
		local now = os.clock()
		if now - lastHit < HIT_COOLDOWN or hit.Name == "CarryBox" or hit:IsDescendantOf(player.Character or box) then
			return
		end
		if isTruckPart(hit) or hit.AssemblyLinearVelocity.Magnitude > FAST_PART_SPEED then
			lastHit = now
			fling(box, hit)
		end
	end)
	box.AncestryChanged:Connect(function(_, parent)
		if not parent then
			watched[box] = nil
		end
	end)
end

task.spawn(function()
	local folder = Workspace:WaitForChild("CarriedBoxes", 60)
	if not folder then
		return
	end
	for _, box in folder:GetChildren() do
		watchBox(box)
	end
	folder.ChildAdded:Connect(function(box)
		-- атрибут Owner ставится до появления в мире, но на всякий случай подождём кадр
		task.defer(watchBox, box)
	end)
end)
