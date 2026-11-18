--| DropOnDeath.lua  – поместите в ServerScriptService

--------------------------------------------------
--  НАСТРОЙКИ
--------------------------------------------------
local DROP_LIMIT       = 20          -- максимум предметов, которые могут выпасть
local EXCEPTIONS = {                  -- список исключений по имени Tool’а
	FlashLight = true,                -- пример: "Flashlight" не выпадает
	-- SwordOfAdmin = true,           -- добавляйте другие исключения здесь
}

--------------------------------------------------
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
--------------------------------------------------
local function safeHandleCFrame(tool, cframe)
	-- если у Tool есть Handle, помещаем его в нужное место и даём небольшой импульс
	local handle = tool:FindFirstChildWhichIsA("BasePart")
	if handle then
		handle.CFrame = cframe * CFrame.new(math.random(-2,2), 2, math.random(-2,2))
		handle.AssemblyLinearVelocity = Vector3.new(0, 20, 0)
	end
end

local function dropTool(tool, dropCFrame)
	-- проверяем, что это Tool, не исключение и ещё есть «квота» на дроп
	if tool:IsA("Tool") and not EXCEPTIONS[tool.Name] then
		tool.Parent = workspace      -- перемещаем в мир
		safeHandleCFrame(tool, dropCFrame)
		return true                  -- успешно дропнули
	end
	return false
end

--------------------------------------------------
--  ОСНОВНАЯ ЛОГИКА
--------------------------------------------------
game.Players.PlayerAdded:Connect(function(player)
	-- отдельная функция-обработчик для каждого персонажа игрока
	local function setupCharacter(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid.Died:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
			if not root then return end
			local dropCFrame = root.CFrame

			local dropped = 0
			-- сначала смотрим Backpack
			for _, tool in ipairs(player.Backpack:GetChildren()) do
				if dropped >= DROP_LIMIT then break end
				if dropTool(tool, dropCFrame) then
					dropped += 1
				end
			end
			-- затем то, что было в руках/каркасе на момент смерти
			for _, tool in ipairs(character:GetChildren()) do
				if dropped >= DROP_LIMIT then break end
				if dropTool(tool, dropCFrame) then
					dropped += 1
				end
			end
		end)
	end

	-- ставим обработчик на каждое появление (и перерождение) персонажа
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end
end)
