local Events = {}

Events.List = {
	{
		Name = "Дождь",
		Start = function()
			game.Workspace.RainFall.ParticleEmitter.Enabled = true
		end,
		Stop = function()
			game.Workspace.RainFall.ParticleEmitter.Enabled = false
		end
	},

	{
		Name = "😡😡А ГДЕ?!?!😡😡",
		Start = function()
			local scripts = {
				game.ServerScriptService:FindFirstChild("TruckSpawner"),
				game.ServerScriptService:FindFirstChild("TruckSpawner2")
			}

			for _, script in ipairs(scripts) do
				if script then
					script.Disabled = true
				end
			end
		end,
		Stop = function()
			local scripts = {
				game.ServerScriptService:FindFirstChild("TruckSpawner"),
				game.ServerScriptService:FindFirstChild("TruckSpawner2")
			}

			for _, script in ipairs(scripts) do
				if script then
					script.Disabled = false
				end
			end
		end
	},

	{
		Name = "🥵🥵Дождь из фур🥵🥵",
		Start = function()
			local debris = game:GetService("Debris")
			local runService = game:GetService("RunService")
			local workspace = game:GetService("Workspace")
			local truckModel = game.ServerStorage:FindFirstChild("Furocka3") -- фура

			if not truckModel then
				warn("TruckModel не найден в ServerStorage!")
				return
			end

			local raining = true
			local eventConnection

			local function spawnFallingTruck()
				local clone = truckModel:Clone()
				clone.Parent = workspace
				local x = math.random(-700, -239)
				local z = math.random(160, 430)
				clone:SetPrimaryPartCFrame(CFrame.new(x, 150, z)) -- высоко в небе

				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
					end
				end

				debris:AddItem(clone, 3)
			end

			eventConnection = runService.Heartbeat:Connect(function()
				if raining then
					spawnFallingTruck()
					wait(2)
				end
			end)

			_G.TruckRainStop = function()
				raining = false
				if eventConnection then eventConnection:Disconnect() end
			end
		end,

		Stop = function()
			if _G.TruckRainStop then
				_G.TruckRainStop()
				_G.TruckRainStop = nil
			end
		end
	},

	{
		Name = "🔄 Перемешивание позиций",
		Start = function()
			local players = game.Players:GetPlayers()
			local positions = {}

			-- Сохраняем текущие позиции игроков
			for _, player in ipairs(players) do
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					table.insert(positions, player.Character.HumanoidRootPart.CFrame)
				end
			end

			-- Перемешиваем позиции в случайном порядке
			local shuffledPositions = {}
			for i = 1, #positions do
				local index = math.random(1, #positions)
				table.insert(shuffledPositions, table.remove(positions, index))
			end

			-- Устанавливаем игрокам новые позиции
			for i, player in ipairs(players) do
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") and shuffledPositions[i] then
					char.HumanoidRootPart.CFrame = shuffledPositions[i]
				end
			end
		end,
		Stop = function()
			-- Ничего не нужно делать при остановке
		end
	},
	{
		Name = "💀☠️ВЬЕТНАМ☠️💀",
		Start = function()
			local debris = game:GetService("Debris")
			local workspace = game:GetService("Workspace")
			local serverStorage = game:GetService("ServerStorage")
			local replicatedStorage = game:GetService("ReplicatedStorage")

			local bombTemplate = serverStorage:FindFirstChild("BombModel")
			local explosionSound = replicatedStorage:FindFirstChild("RocketExplosionSound")

			local excludedNames = {
				"Osnova", "MenuCameraPart", "spawner", "spawner2", "Baseplate", "SpawnLocation",
				"sgushenka_buy", "Sgushenka_met", "Milkakyp", "Stick", "zachita ot furochek",
				"buy", "modelsh", "RadioBuy", "swordbuy", "gravitybuy", "odnoryk"
			}

			if not bombTemplate then
				warn("BombModel не найден в ServerStorage!")
				return
			end
			if not explosionSound then
				warn("RocketExplosionSound не найден в ReplicatedStorage!")
				return
			end

			local changedParts = {}
			local activeBombs = {}
			_G.VietnamChangedParts = changedParts
			_G.VietnamActiveBombs = activeBombs

			local active = true

			local function spawnBomb()
				if not active then return end
				local bomb = bombTemplate:Clone()
				bomb.Parent = workspace
				table.insert(activeBombs, bomb)

				local x = math.random(-700, -239)
				local z = math.random(160, 430)
				bomb:SetPrimaryPartCFrame(CFrame.new(x, 120, z))

				for _, part in ipairs(bomb:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
					end
				end

				local exploded = false

				local function explode()
					if exploded or not active then return end
					exploded = true

					local soundClone = explosionSound:Clone()
					soundClone.Parent = bomb.PrimaryPart
					soundClone:Play()
					debris:AddItem(soundClone, 5)

					local explosion = Instance.new("Explosion")
					explosion.Position = bomb.PrimaryPart.Position
					explosion.BlastRadius = 50
					explosion.BlastPressure = 150000
					explosion.Parent = workspace

					for _, part in ipairs(workspace:GetDescendants()) do
						if part:IsA("BasePart") and part.Anchored and not table.find(excludedNames, part.Name)
							and (part.Position - explosion.Position).Magnitude <= explosion.BlastRadius then
							table.insert(changedParts, {
								Part = part,
								OriginalCFrame = part.CFrame,
								OriginalCastShadow = part.CastShadow
							})
							part.Anchored = false
							part.CastShadow = false
						end
					end

					debris:AddItem(bomb, 1)
				end

				bomb.PrimaryPart.Touched:Connect(function(hit)
					if hit:IsDescendantOf(bomb) then return end
					explode()
				end)
			end

			-- Цикл спавна бомб: каждые 5 секунд по 3 штуки
			task.spawn(function()
				while active do
					for i = 1, 3 do
						spawnBomb()
					end
					task.wait(5)
				end
			end)

			-- Функция остановки ивента
			_G.StopVietnam = function()
				active = false
			end
		end,

		Stop = function()
			if _G.StopVietnam then
				_G.StopVietnam()
				_G.StopVietnam = nil
			end

			-- Удалить все активные бомбы
			if _G.VietnamActiveBombs then
				for _, bomb in ipairs(_G.VietnamActiveBombs) do
					if bomb and bomb.Parent then
						bomb:Destroy()
					end
				end
				_G.VietnamActiveBombs = nil
			end

			-- Восстановить все части
			if _G.VietnamChangedParts then
				for _, data in ipairs(_G.VietnamChangedParts) do
					local part = data.Part
					if part and part:IsDescendantOf(workspace) then
						part.Anchored = true
						part.CFrame = data.OriginalCFrame
						part.Velocity = Vector3.zero
						part.RotVelocity = Vector3.zero
						part.CastShadow = data.OriginalCastShadow
					end
				end
				_G.VietnamChangedParts = nil
			end
		end
	},
	{
		Name = "💀НЕКСБОТ НА ОХОТЕ💀",
		Start = function()
			local ServerStorage = game:GetService("ServerStorage")
			local Players = game:GetService("Players")
			local RunService = game:GetService("RunService")
			local PathfindingService = game:GetService("PathfindingService")
			local Workspace = game:GetService("Workspace")

			local nexbotTemplate = ServerStorage:FindFirstChild("Nexbot")
			if not nexbotTemplate then
				warn("❌ Nexbot model not found in ServerStorage!")
				return
			end

			local nexbot = nexbotTemplate:Clone()
			nexbot.Parent = Workspace
			local hrp = nexbot:WaitForChild("HumanoidRootPart")
			local humanoid = nexbot:WaitForChild("Humanoid")
			local sounds = nexbot:WaitForChild("Sounds")

			-- Звуки
			if sounds:FindFirstChild("Spawn") then
				sounds.Spawn:Play()
			end
			if sounds:FindFirstChild("Chase") then
				sounds.Chase.Looped = true
				sounds.Chase:Play()
			end

			-- Спавн на поверхности перед камерой
			local camera = workspace.CurrentCamera
			local startPos = camera.CFrame.Position + camera.CFrame.LookVector * 50

			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {nexbot}
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

			local rayResult = workspace:Raycast(startPos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), raycastParams)
			if rayResult then
				hrp.CFrame = CFrame.new(rayResult.Position + Vector3.new(0, 4, 0))
			else
				hrp.CFrame = CFrame.new(startPos + Vector3.new(0, 10, 0))
			end

			humanoid.WalkSpeed = 100
			humanoid.JumpPower = 200
			humanoid.AutoRotate = true

			local chasing = true

			-- Поиск ближайшего игрока
			local function getClosestPlayer()
				local closestPlayer = nil
				local closestDist = math.huge
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
						local dist = (plr.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
						if dist < closestDist then
							closestDist = dist
							closestPlayer = plr
						end
					end
				end
				return closestPlayer
			end

			-- Касание игрока
			hrp.Touched:Connect(function(hit)
				local char = hit.Parent
				local plr = Players:GetPlayerFromCharacter(char)
				if plr and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
					if sounds:FindFirstChild("Hit") then
						sounds.Hit:Play()
					end

					-- Отбрасывание
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then
						local direction = (root.Position - hrp.Position).Unit
						root.Velocity = direction * 150 + Vector3.new(0, 100, 0)
					end

					char.Humanoid.Health = char.Humanoid.Health - 10000

					-- Текст "НИК БЫЛ ЗАДАВЛЕН"
					for _, p in ipairs(Players:GetPlayers()) do
						local screenGui = Instance.new("ScreenGui")
						screenGui.ResetOnSpawn = false
						screenGui.IgnoreGuiInset = true

						local textLabel = Instance.new("TextLabel")
						textLabel.Size = UDim2.new(1, 0, 1, 0)
						textLabel.BackgroundTransparency = 1
						textLabel.TextScaled = true
						textLabel.Font = Enum.Font.GothamBlack
						textLabel.TextColor3 = Color3.new(1, 0, 0)
						textLabel.Text = string.upper(plr.DisplayName) .. " БЫЛ ЗАДАВЛЕН"
						textLabel.Parent = screenGui

						screenGui.Parent = p:WaitForChild("PlayerGui")

						task.spawn(function()
							for i = 1, 40 do
								textLabel.Position = UDim2.new(0, math.random(-10, 10), 0, math.random(-10, 10))
								task.wait(0.02)
							end
							for i = 1, 20 do
								textLabel.TextTransparency = i / 20
								task.wait(0.05)
							end
							screenGui:Destroy()
						end)
					end
				end
			end)

			-- Основной цикл ИИ
			task.spawn(function()
				while chasing and nexbot.Parent == Workspace do
					local target = getClosestPlayer()
					if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
						local path = PathfindingService:CreatePath({
							AgentRadius = 2,
							AgentHeight = 5,
							AgentCanJump = true
						})
						path:ComputeAsync(hrp.Position, target.Character.HumanoidRootPart.Position)
						if path.Status == Enum.PathStatus.Success then
							for _, waypoint in ipairs(path:GetWaypoints()) do
								if not chasing then break end
								humanoid:MoveTo(waypoint.Position)
								if waypoint.Action == Enum.PathWaypointAction.Jump then
									humanoid.Jump = true
								end
								humanoid.MoveToFinished:Wait()
							end
						end
					end
					task.wait(0.3)
				end
			end)

			-- Отталкивание свободных объектов
			task.spawn(function()
				while chasing and nexbot.Parent == Workspace do
					for _, part in ipairs(Workspace:GetDescendants()) do
						if part:IsA("BasePart") and not part.Anchored and (part.Position - hrp.Position).Magnitude < 15 then
							part.Velocity += (part.Position - hrp.Position).Unit * 120
						end
					end
					task.wait(0.1)
				end
			end)

			-- Сохраняем активное состояние для Stop
			script._NexbotInstance = nexbot
			script._Active = true
		end,

		Stop = function()
			local ServerStorage = game:GetService("ServerStorage")
			local Debris = game:GetService("Debris")
			local nexbot = script._NexbotInstance
			if nexbot then
				local sounds = nexbot:FindFirstChild("Sounds")
				if sounds and sounds:FindFirstChild("Chase") then
					sounds.Chase:Stop()
				end
				if sounds and sounds:FindFirstChild("End") then
					sounds.End:Play()
					Debris:AddItem(sounds.End, sounds.End.TimeLength)
				end
				nexbot:Destroy()
			end
			script._Active = false
		end
	}



}

return Events
