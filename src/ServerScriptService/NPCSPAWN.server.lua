local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local NPCTemplates = ServerStorage:WaitForChild("NPCTemplates")

local RespawnDelay = 5      -- Задержка респавна в секундах
local DissolveTime = 10     -- Время растворения NPC в секундах

-- Точки спавна и куда смотреть (NPCName, Position, LookAtPosition)
local NPCSpawnPoints = {
	{Name = "Serg20087720", Position = Vector3.new(-307.272, 3.902, 192.024), LookAt = Vector3.new(-308, 4.502, 200)},
	{Name = "6V4Ska9", Position = Vector3.new(-388.6, 4.202, 44.85), LookAt = Vector3.new(-388.6, 4.202, 54.85)},
	{Name = "Nullbit", Position = Vector3.new(-319.254, 4.202, 131), LookAt = Vector3.new(-322.054, 5.108, 131)},
	-- Добавляй свои NPC здесь
}

-- Функция плавного растворения NPC
local function dissolveEffect(model, duration)
	local elapsed = 0
	local parts = {}

	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end

	while elapsed < duration do
		local alpha = elapsed / duration
		for _, part in pairs(parts) do
			if part and part.Transparency < 1 then
				part.Transparency = math.clamp(alpha, 0, 1)
				if part:FindFirstChildOfClass("Decal") then
					part:FindFirstChildOfClass("Decal").Transparency = math.clamp(alpha, 0, 1)
				end
			end
		end
		elapsed += RunService.Heartbeat:Wait()
	end

	for _, part in pairs(parts) do
		if part then
			part.Transparency = 1
			if part:FindFirstChildOfClass("Decal") then
				part:FindFirstChildOfClass("Decal").Transparency = 1
			end
		end
	end
end

-- Функция спавна и респавна NPC
local function spawnNPC(templateName, position, lookAtPosition)
	local npcTemplate = NPCTemplates:FindFirstChild(templateName)
	if not npcTemplate then
		warn("NPC-шаблон "..templateName.." не найден!")
		return
	end

	local npcClone = npcTemplate:Clone()
	npcClone.Parent = Workspace

	if npcClone.PrimaryPart then
		local npcPos = position
		local lookPos = Vector3.new(lookAtPosition.X, npcPos.Y, lookAtPosition.Z)
		npcClone:SetPrimaryPartCFrame(CFrame.new(npcPos, lookPos))
	end

	local humanoid = npcClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			dissolveEffect(npcClone, DissolveTime)
			wait(RespawnDelay)
			if npcClone then npcClone:Destroy() end
			spawnNPC(templateName, position, lookAtPosition)
		end)
	end
end

-- Спавним всех NPC из списка
for _, npcData in pairs(NPCSpawnPoints) do
	spawnNPC(npcData.Name, npcData.Position, npcData.LookAt)
end
