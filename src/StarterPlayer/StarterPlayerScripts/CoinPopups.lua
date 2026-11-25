-- StarterPlayer/StarterPlayerScripts/CoinPopups  (LocalScript)  v2 — редизайн
-- Всплывашки «+N 🪙» / «−N 🪙» при изменении Coins. Заменяет StarterGui/CoinPopupGui.
-- Мультяшный стиль: жирные цифры с контуром «выпрыгивают», взлетают и растворяются.
-- Как и в v1: первое изменение после входа не теряется, одновременно не больше MAX_POPUPS.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))

local FORMAT_NUMBERS = true -- «+1 000» вместо «+1000»
local MAX_POPUPS = 12 -- при шквале изменений лишние всплывашки пропускаются
local SOUND_ID = "rbxassetid://5613553529"
local SOUND_VOLUME = 0.5
local FLY_TIME = 1 -- секунд полёта вверх и исчезновения
local GAIN_COLOR = UILib.palette("yellow").top
local LOSS_COLOR = UILib.palette("red").top
local BIG_GAIN = 1000 -- от этой суммы всплывашка крупнее

local player = Players.LocalPlayer

local gui = UILib.screenGui("CoinPopupGui", 6, player)
local area = UILib.make("Frame", {
	Name = "Area",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
}, gui)
UILib.fitScale(area) -- на телефоне цифры не огромные, на большом мониторе не мелкие
local sound = UILib.make("Sound", { Name = "CoinSound", SoundId = SOUND_ID, Volume = SOUND_VOLUME }, gui)

local activePopups = 0

local function showPopup(delta)
	if activePopups >= MAX_POPUPS then
		return
	end
	activePopups += 1

	local amount = FORMAT_NUMBERS and UILib.formatNumber(math.abs(delta)) or tostring(math.abs(delta))
	local xOffset = math.random(-100, 100)
	local yOffset = math.random(-50, 50)
	local big = delta >= BIG_GAIN

	local popup = UILib.text(area, (delta >= 0 and "+" or "−") .. amount .. " 🪙", {
		Name = "Popup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 300, 0, 50),
		Position = UDim2.new(0.5, xOffset, 0.7, yOffset),
		TextColor3 = delta >= 0 and GAIN_COLOR or LOSS_COLOR,
		TextSize = big and 40 or 30,
		TextWrapped = false,
		Rotation = math.random(-8, 8),
		strokeThickness = 3,
	})
	local stroke = popup:FindFirstChildOfClass("UIStroke")
	local scale = UILib.make("UIScale", { Scale = 0.3 }, popup)

	sound:Play()

	-- 1) выпрыгивает, 2) взлетает и растворяется
	UILib.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	UILib.tween(popup, FLY_TIME, {
		Position = UDim2.new(0.5, xOffset, 0.7 - 0.08, yOffset),
	})
	local fade = UILib.tween(popup, FLY_TIME, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if stroke then
		UILib.tween(stroke, FLY_TIME, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	fade.Completed:Connect(function()
		activePopups -= 1
		popup:Destroy()
	end)
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 120)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 30)
	if not coins then
		warn("[CoinPopups] Не нашёл leaderstats.Coins")
		return
	end

	local last = coins.Value
	coins:GetPropertyChangedSignal("Value"):Connect(function()
		local current = coins.Value
		local delta = current - last
		last = current
		if delta ~= 0 then
			showPopup(delta)
		end
	end)
end)
