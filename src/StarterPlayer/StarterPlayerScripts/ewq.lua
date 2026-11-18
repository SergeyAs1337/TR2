local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local StopDance = ReplicatedStorage:WaitForChild("DanceEnded")

local function stopDance()
	StopDance:FireServer()
end

-- Привязываем обработчик к пробелу и геймпаду, но не мешаем стандартному действию
ContextActionService:BindAction(
	"StopDanceKey",
	function(_, state)
		if state == Enum.UserInputState.Begin then
			stopDance()
		end
		return Enum.ContextActionResult.Pass -- <<< позволяет прыгать
	end,
	false,
	Enum.KeyCode.Space,
	Enum.KeyCode.ButtonB
)

-- Остановка танца при прыжке
local function connectJump(humanoid)
	humanoid.Jumping:Connect(function()
		stopDance()
	end)
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	connectJump(humanoid)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
