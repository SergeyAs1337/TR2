local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local groupName = "NoCollideRagdoll"

-- Создаём группу и настраиваем коллизии
pcall(function()
	if not PhysicsService:CollisionGroupExists(groupName) then
		PhysicsService:CreateCollisionGroup(groupName)
	end
end)

-- Рэгдолл не сталкивается сам с собой, но сталкивается с миром (Default)
PhysicsService:CollisionGroupSetCollidable(groupName, groupName, false)
PhysicsService:CollisionGroupSetCollidable(groupName, "Default", true)

local function convertMotor6D(motor)
	if not motor.Part0 or not motor.Part1 then return end

	local a0 = Instance.new("Attachment")
	a0.CFrame = motor.C0
	a0.Name = "RagdollA0"
	a0.Parent = motor.Part0

	local a1 = Instance.new("Attachment")
	a1.CFrame = motor.C1
	a1.Name = "RagdollA1"
	a1.Parent = motor.Part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.Radius = 0.15
	socket.LimitsEnabled = true
	socket.UpperAngle = 45
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -45
	socket.TwistUpperAngle = 45
	socket.Parent = motor.Part0

	motor:Destroy()
end

local function applyRagdoll(character)
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") then
			convertMotor6D(motor)
		end
	end

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = part.Name ~= "HumanoidRootPart" -- HRP без коллизии, остальное с коллизией
			part.Massless = false
			part.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.5)
			part.CollisionGroup = groupName
		end
	end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		local impulse = Vector3.new(
			math.random(-6, 6),
			math.random(4, 8),
			math.random(-6, 6)
		) * 50
		torso:ApplyImpulse(impulse)
	end
end

local function headIsDetached(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return true
	end

	for _, motor in pairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Name == "Neck" then
			if motor.Part0 == head or motor.Part1 == head then
				return false
			end
		end
	end

	return true
end

local function forceKillIfNeeded(humanoid, character)
	if humanoid.Health <= 0 then return end
	if headIsDetached(character) then
		humanoid.Health = 0
	end
end

local function handleDeath(humanoid, character)
	if humanoid:GetAttribute("RagdollDone") then return end
	humanoid:SetAttribute("RagdollDone", true)
	humanoid.PlatformStand = true
	task.defer(function()
		applyRagdoll(character)
	end)
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	humanoid.Died:Connect(function()
		handleDeath(humanoid, character)
	end)

	humanoid.HealthChanged:Connect(function()
		forceKillIfNeeded(humanoid, character)
	end)

	task.spawn(function()
		while character.Parent and humanoid.Health > 0 do
			task.wait(0.1)
			forceKillIfNeeded(humanoid, character)
		end
	end)
end

local RESPAWN_DELAY = Players.RespawnTime or 5

local function safeRespawn(player)
	if player.Parent == nil then return end
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		player:LoadCharacter()
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)

	player.CharacterRemoving:Connect(function()
		task.delay(RESPAWN_DELAY + 0.1, function()
			safeRespawn(player)
		end)
	end)

	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end