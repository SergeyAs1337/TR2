local Tool = script.Parent
local enabled = true
local usesLeft = 3
local cooldownTime = 5
local MAX_TOTAL_USES = 25

-- Получаем или создаём статистику игрока
local function getStatsFolder(player)
	local stats = player:FindFirstChild("DrinkStats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "DrinkStats"
		stats.Parent = player
	end

	local useCounter = stats:FindFirstChild("DrinkUses")
	if not useCounter then
		useCounter = Instance.new("IntValue")
		useCounter.Name = "DrinkUses"
		useCounter.Value = 0
		useCounter.Parent = stats
	end

	return useCounter
end

-- Сброс счётчика при смерти
local function setupDeathReset(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			local stats = player:FindFirstChild("DrinkStats")
			if stats then
				local uses = stats:FindFirstChild("DrinkUses")
				if uses then
					uses.Value = 0
				end
			end
		end)
	end
end

-- Выдача ачивки
local function awardAchievement(player)
	local badgeService = game:GetService("BadgeService")
	local badgeId = 4276506129124377 -- 🔁 Замени на свой реальный Badge ID

	pcall(function()
		badgeService:AwardBadge(player.UserId, badgeId)
	end)
end

-- Получить персонажа и игрока из инструмента
local function getCharacterAndPlayer()
	local parent = Tool.Parent
	if parent and parent:IsA("Model") and parent:FindFirstChild("Humanoid") then
		local player = game.Players:GetPlayerFromCharacter(parent)
		return parent, player
	end
	return nil, nil
end

-- При активации
function onActivated()
	if not enabled or usesLeft <= 0 then return end
	enabled = false
	usesLeft -= 1

	local character, player = getCharacterAndPlayer()
	if character and player then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			-- ✅ Применяем бонусы сразу
			humanoid.Health = math.min(humanoid.Health + 20, humanoid.MaxHealth)
			humanoid.WalkSpeed += 2

			local counter = getStatsFolder(player)
			counter.Value += 1

			if counter.Value >= MAX_TOTAL_USES then
				humanoid.Health = 0
				awardAchievement(player)
			end
		end
	end

	-- Анимация
	Tool.GripForward = Vector3.new(0, -0.759, -0.651)
	Tool.GripPos = Vector3.new(1.5, -0.5, 0.3)
	Tool.GripRight = Vector3.new(1, 0, 0)
	Tool.GripUp = Vector3.new(0, 0.651, -0.759)

	if Tool:FindFirstChild("Handle") and Tool.Handle:FindFirstChild("DrinkSound") then
		Tool.Handle.DrinkSound:Play()
	end

	task.wait(3)

	-- Возврат положения
	Tool.GripForward = Vector3.new(-0.976, 0, -0.217)
	Tool.GripPos = Vector3.new(0.03, 0, 0)
	Tool.GripRight = Vector3.new(0.217, 0, -0.976)
	Tool.GripUp = Vector3.new(0, 1, 0)

	-- Удаление после 2 использований
	if usesLeft <= 0 then
		task.wait(1)
		Tool:Destroy()
	else
		task.delay(cooldownTime, function()
			enabled = true
		end)
	end
end

function onEquipped()
	local character, player = getCharacterAndPlayer()
	if player and character then
		setupDeathReset(player, character)
	end

	if Tool:FindFirstChild("Handle") and Tool.Handle:FindFirstChild("OpenSound") then
		Tool.Handle.OpenSound:Play()
	end
end

function onUnequipped()
	enabled = true -- Сброс на всякий случай
end

Tool.Activated:Connect(onActivated)
Tool.Equipped:Connect(onEquipped)
Tool.Unequipped:Connect(onUnequipped)
