local Lighting = game:GetService("Lighting")
local Lamps = workspace:WaitForChild("Lamps"):GetChildren()

-- Настройки
local DAY_TIME = 5 * 60
local NIGHT_TIME = 3 * 60
local TRANSITION_TIME = 5
local DAY_CLOCK = 14
local NIGHT_CLOCK = 0

-- Функция управления фонарями
local function setLampsEnabled(enabled)
	for _, lamp in ipairs(Lamps) do
		for _, obj in ipairs(lamp:GetDescendants()) do
			if obj:IsA("Light") then
				obj.Enabled = enabled
			end
		end
	end
end

-- Плавный переход между временами суток
local function smoothTransition(startTime, endTime, duration)
	local steps = duration / 0.01
	local delta = (endTime - startTime) / steps

	for i = 1, steps do
		Lighting.ClockTime = (Lighting.ClockTime + delta) % 24
		task.wait(0.1)
	end

	Lighting.ClockTime = endTime % 24
end

-- Основной цикл
while true do
	-- День
	Lighting.ClockTime = DAY_CLOCK
	setLampsEnabled(false) -- Выключаем фонари
	task.wait(DAY_TIME)

	-- Переход к ночи
	smoothTransition(DAY_CLOCK, NIGHT_CLOCK, TRANSITION_TIME)

	-- Ночь
	setLampsEnabled(true) -- Включаем фонари
	task.wait(NIGHT_TIME)

	-- Переход к дню
	smoothTransition(NIGHT_CLOCK, DAY_CLOCK, TRANSITION_TIME)
end
