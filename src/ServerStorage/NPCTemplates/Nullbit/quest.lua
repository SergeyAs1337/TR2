local npc = script.Parent
local prompt = npc:WaitForChild("TalkPrompt")

prompt.Triggered:Connect(function(player)
	local playerGui = player:WaitForChild("PlayerGui")
	local up = playerGui:WaitForChild("UpgradeGUI")
	local guis = up.Frame
	local button = up.CloseButton

	guis.Visible = true
	button.Visible = true
end)
