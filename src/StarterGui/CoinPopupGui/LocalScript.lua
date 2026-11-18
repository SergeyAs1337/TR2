local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("CoinPopupGui")
local template = gui:WaitForChild("Template")

local lastCoins = nil
local initialized = false

local function showPopup(delta)
	local popup = template:Clone()
	popup.Visible = true
	popup.Text = (delta >= 0 and "+" or "") .. tostring(delta) .. " монет"
	popup.TextColor3 = delta >= 0 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 80, 80)

	local randomXOffset = math.random(-100, 100)
	local randomYOffset = math.random(-50, 50)

	local startPos = UDim2.new(0.5, randomXOffset, 0.7, randomYOffset)
	popup.Position = startPos
	popup.Parent = gui

	-- Проигрываем звук
	local sound = gui:FindFirstChild("CoinSound")
	if sound then
		sound:Play()
	end

	local endPos = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale - 0.05, startPos.Y.Offset)

	local tween = TweenService:Create(popup, TweenInfo.new(1), {
		Position = endPos,
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

local function setupListener()
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
	lastCoins = coins.Value

	coins.Changed:Connect(function(newValue)
		if not initialized then
			lastCoins = newValue
			initialized = true
			return
		end

		local delta = newValue - lastCoins
		if delta ~= 0 then
			showPopup(delta)
		end
		lastCoins = newValue
	end)
end

setupListener()
