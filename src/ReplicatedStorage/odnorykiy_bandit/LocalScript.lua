local tool = script.Parent
local player = game.Players.LocalPlayer
local ui = player:WaitForChild("PlayerGui"):WaitForChild("GambleUI")
local mainFrame = ui:WaitForChild("MainFrame")
local playButton = mainFrame:WaitForChild("PlayButton")
local betBox = mainFrame:WaitForChild("BetBox")
local closeButton = mainFrame:WaitForChild("CloseButton")
local lostLabel = mainFrame:WaitForChild("TotalLostLabel")

local remote = game:GetService("ReplicatedStorage"):WaitForChild("GambleEvent")
local totalLost = game.ReplicatedStorage:WaitForChild("GlobalStats"):WaitForChild("TotalLost")

local function formatNumber(n)
	return tostring(n):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
end

local function updateLostText()
	lostLabel.Text = "Проиграно всеми: " .. formatNumber(totalLost.Value)
end

tool.Activated:Connect(function()
	updateLostText()
	mainFrame.Visible = true
end)

playButton.MouseButton1Click:Connect(function()
	local amount = tonumber(betBox.Text)
	if amount and amount > 0 then
		remote:FireServer(amount)
		mainFrame.Visible = false
	end
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

totalLost:GetPropertyChangedSignal("Value"):Connect(updateLostText)
