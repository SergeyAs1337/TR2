-- StarterPlayer/StarterPlayerScripts/DailyQuestHud  (LocalScript)  v1 — ежедневное задание
-- Заменяет StarterGui/DailyQuestGui (удалить). Стиль админ-панели, строится кодом.
-- Плашка выезжает сверху после каждой засчитанной смерти и при входе в игру:
-- «Ежедневное задание · 7 / 15», полоска с отметками наград (+30, +50, +150),
-- после выполнения — сколько осталось до нового задания.
-- Данные берутся из атрибутов игрока (их ставит everydaycount v2), поэтому плашка
-- всегда показывает правду, даже если событие пришло раньше, чем загрузился скрипт.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

-- Должно совпадать с REWARDS в everydaycount.lua (только для подписей; выдаёт сервер)
local REWARDS = {
	{ deaths = 1, coins = 30 },
	{ deaths = 5, coins = 50 },
	{ deaths = 15, coins = 150 },
}
local SHOW_TIME = 4 -- секунд на экране
local HIDDEN_Y = -140
local SHOWN_Y = 100 -- ниже баннера событий

local player = Players.LocalPlayer
local updateEvent = ReplicatedStorage:WaitForChild("DailyQuestUpdate", 30)

local gui = UILib.screenGui("DailyQuestGui", 14, player)

local panel = UILib.panel(gui, {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
	Size = UDim2.new(0, 400, 0, 96),
	BackgroundColor3 = THEME.background,
	BackgroundTransparency = 0.05,
	Visible = false,
})
UILib.stroke(panel, 1, THEME.border)
UILib.fitScale(panel)

UILib.text(panel, "ЕЖЕДНЕВНОЕ ЗАДАНИЕ", {
	Name = "Caption",
	Position = UDim2.new(0, 16, 0, 10),
	Size = UDim2.new(1, -120, 0, 14),
	TextSize = 12,
	TextColor3 = THEME.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local counter = UILib.text(panel, "", {
	Name = "Counter",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 8),
	Size = UDim2.new(0, 100, 0, 18),
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local title = UILib.text(panel, "", {
	Name = "Title",
	Position = UDim2.new(0, 16, 0, 26),
	Size = UDim2.new(1, -32, 0, 22),
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local bar = UILib.panel(panel, {
	Name = "Bar",
	Position = UDim2.new(0, 16, 0, 56),
	Size = UDim2.new(1, -32, 0, 8),
	BackgroundColor3 = THEME.row,
})
local fill = UILib.panel(bar, {
	Name = "Fill",
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = UILib.palette("good").face,
})

-- Отметки наград под полоской
local marks = {}
local target = 15
local function buildMarks()
	for _, mark in marks do
		mark.label:Destroy()
	end
	marks = {}
	for _, reward in REWARDS do
		local x = math.clamp(reward.deaths / target, 0, 1)
		local label = UILib.text(panel, "+" .. reward.coins, {
			Name = "Reward" .. reward.deaths,
			AnchorPoint = Vector2.new(x >= 1 and 1 or 0.5, 0),
			Position = UDim2.new(0, 16, 0, 68),
			Size = UDim2.new(0, 44, 0, 16),
			TextSize = 12,
			TextColor3 = THEME.muted,
		})
		-- позиция по горизонтали внутри полоски
		label.Position = UDim2.new(0, 16 + (400 - 32) * x, 0, 68)
		marks[reward.deaths] = { label = label, coins = reward.coins }
	end
end
buildMarks()

local function timeUntilReset()
	local now = os.time()
	local d = os.date("!*t", now)
	local secondsToday = d.hour * 3600 + d.min * 60 + d.sec
	local left = 86400 - secondsToday
	local hours = left // 3600
	local minutes = (left % 3600) // 60
	return string.format("%d ч %02d мин", hours, minutes)
end

local function given()
	local set = {}
	local raw = player:GetAttribute("DailyRewardsGiven")
	if typeof(raw) == "string" then
		for piece in string.gmatch(raw, "[^,]+") do
			local n = tonumber(piece)
			if n then
				set[n] = true
			end
		end
	end
	return set
end

local function render()
	local available = player:GetAttribute("DailyQuestAvailable")
	local newTarget = tonumber(player:GetAttribute("DailyQuestTarget")) or 15
	if newTarget ~= target and newTarget > 0 then
		target = newTarget
		buildMarks()
	end
	local deaths = math.clamp(tonumber(player:GetAttribute("DailyDeaths")) or 0, 0, target)
	local done = deaths >= target

	if available == false then
		title.Text = "Задание загружается…"
		counter.Text = ""
	elseif done then
		title.Text = "Выполнено · новое через " .. timeUntilReset()
		counter.Text = string.format("%d / %d", deaths, target)
	else
		title.Text = "Умри " .. target .. " раз за день"
		counter.Text = string.format("%d / %d", deaths, target)
	end

	UILib.tween(fill, 0.3, { Size = UDim2.new(deaths / target, 0, 1, 0) })
	fill.BackgroundColor3 = done and UILib.palette("good").face or UILib.palette("warn").face

	local got = given()
	for threshold, mark in marks do
		mark.label.TextColor3 = got[threshold] and UILib.palette("good").hover or THEME.muted
	end
end

local generation = 0
local function show()
	render()
	generation += 1
	local myGeneration = generation
	panel.Visible = true
	UILib.tween(panel, 0.3, { Position = UDim2.new(0.5, 0, 0, SHOWN_Y) })
	task.delay(SHOW_TIME, function()
		if myGeneration ~= generation then
			return
		end
		UILib.tween(panel, 0.3, { Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.31, function()
			if myGeneration == generation then
				panel.Visible = false
			end
		end)
	end)
end

-- Смерть засчитана: атрибут вырос
local lastDeaths = tonumber(player:GetAttribute("DailyDeaths"))
player:GetAttributeChangedSignal("DailyDeaths"):Connect(function()
	local deaths = tonumber(player:GetAttribute("DailyDeaths"))
	if deaths and deaths ~= lastDeaths then
		lastDeaths = deaths
		show()
	end
end)
player:GetAttributeChangedSignal("DailyRewardsGiven"):Connect(render)

-- Награда: короткое уведомление
if updateEvent then
	updateEvent.OnClientEvent:Connect(function(_deaths, rewardCoins)
		if typeof(rewardCoins) == "number" and rewardCoins > 0 then
			UILib.toast("Ежедневное задание: +" .. UILib.formatNumber(rewardCoins) .. " 🪙", "good", 2.5)
		end
	end)
end

-- При входе: показать один раз, когда данные загрузились
task.spawn(function()
	local waited = 0
	while player:GetAttribute("DailyQuestAvailable") ~= true and waited < 60 do
		waited += task.wait(0.5)
	end
	if player:GetAttribute("DailyQuestAvailable") == true then
		lastDeaths = tonumber(player:GetAttribute("DailyDeaths"))
		show()
	end
end)
