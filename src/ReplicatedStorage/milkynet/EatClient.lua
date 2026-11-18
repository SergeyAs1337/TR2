local tool = script.Parent
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local animation = tool:WaitForChild("EatAnimation")
local sound = tool:WaitForChild("EatSound")
local eatEvent = tool:WaitForChild("EatEvent")

local usesLeft = 1
local cooldown = false

tool.Activated:Connect(function()
	if cooldown or usesLeft <= 0 then return end
	cooldown = true

	if humanoid then
		local track = humanoid:LoadAnimation(animation)
		track:Play()
		sound:Play()

		eatEvent:FireServer()

		usesLeft -= 1
	end

	task.wait(1) -- небольшой кулдаун
	cooldown = false
end)
