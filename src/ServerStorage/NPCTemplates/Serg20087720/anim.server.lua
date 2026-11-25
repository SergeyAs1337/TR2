local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")

-- Создай объект Animation
local idleAnimation = Instance.new("Animation")
idleAnimation.AnimationId = "rbxassetid://93428808306378" -- замените на свой ID

-- Загрузи и проигрывай
local idleTrack = humanoid:LoadAnimation(idleAnimation)
idleTrack.Looped = true
idleTrack:Play()
