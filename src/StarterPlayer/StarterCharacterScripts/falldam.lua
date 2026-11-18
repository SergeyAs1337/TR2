-- Визуальный Ragdoll при падении (без урона) + защита от Gravity Coil + лимит HP
local char = script.Parent
local humanoid = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

local FALL_TIME = 0.5
local RAGDOLL_TIME = 2
local FALL_SPEED = -20
local STARTUP_PROTECT = 1.0

local motorInfos = {}
for _, m in ipairs(char:GetDescendants()) do
	if m:IsA("Motor6D") and m.Part0 and m.Part1 then
		table.insert(motorInfos, {
			name = m.Name,
			part0 = m.Part0.Name,
			part1 = m.Part1.Name,
			c0 = m.C0,
			c1 = m.C1
		})
	end
end

local ragdolled = false
local falling = false
local fallStartTime = nil
local scriptStart = tick()
local dead = false

local function setCollision(state)
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.CanCollide = state
		end
	end
end

local function findMotor(info)
	local p0 = char:FindFirstChild(info.part0)
	if not p0 then return nil end
	local m = p0:FindFirstChild(info.name)
	if m and m:IsA("Motor6D") then return m end
	return nil
end

local function restoreMotor(info)
	local p0 = char:FindFirstChild(info.part0)
	local p1 = char:FindFirstChild(info.part1)
	if not (p0 and p1) then return false end
	local existing = findMotor(info)
	if existing then
		pcall(function() existing.Enabled = true end)
		return true
	end
	local success, err = pcall(function()
		local m = Instance.new("Motor6D")
		m.Name = info.name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = info.c0 or CFrame.new()
		m.C1 = info.c1 or CFrame.new()
		m.Parent = p0
		m.Enabled = true
	end)
	if not success then warn("Ragdoll restore error:", err) end
	return true
end

local function removeRagdollArtifacts()
	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("Attachment") and tostring(v.Name):match("^Ragdoll_att_") then
			v:Destroy()
		elseif v:IsA("BallSocketConstraint") and tostring(v.Name):match("^RagdollSocket_") then
			v:Destroy()
		elseif v:IsA("WeldConstraint") and v.Name == "RagdollWeld" then
			v:Destroy()
		end
	end
end

local function forceRecover()
	for _, info in ipairs(motorInfos) do
		pcall(function() restoreMotor(info) end)
	end
	removeRagdollArtifacts()
	setCollision(false)
	task.wait()
	pcall(function()
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Standing)
	end)
	ragdolled = false
end

local function isHoldingGravityTool()
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return false end
	return tool.Name == "Gravity Coil"
end

local function setRagdoll(state)
	if ragdolled == state then return end
	ragdolled = state

	if state then
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			humanoid.PlatformStand = true
		end)
		setCollision(true)
		for _, info in ipairs(motorInfos) do
			pcall(function()
				local p0 = char:FindFirstChild(info.part0)
				local p1 = char:FindFirstChild(info.part1)
				if not (p0 and p1) then return end

				local att0Name = "Ragdoll_att_" .. info.name .. "_0"
				local att1Name = "Ragdoll_att_" .. info.name .. "_1"
				local socketName = "RagdollSocket_" .. info.name

				if not p0:FindFirstChild(att0Name) then
					local att0 = Instance.new("Attachment")
					att0.Name = att0Name
					att0.CFrame = info.c0 or CFrame.new()
					att0.Parent = p0
				end
				if not p1:FindFirstChild(att1Name) then
					local att1 = Instance.new("Attachment")
					att1.Name = att1Name
					att1.CFrame = info.c1 or CFrame.new()
					att1.Parent = p1
				end
				if not p0:FindFirstChild(socketName) then
					local socket = Instance.new("BallSocketConstraint")
					socket.Name = socketName
					socket.Attachment0 = p0:FindFirstChild(att0Name)
					socket.Attachment1 = p1:FindFirstChild(att1Name)
					socket.Parent = p0
				end

				local existing = findMotor(info)
				if existing then
					pcall(function() existing.Enabled = false end)
				end
			end)
		end
		task.delay(RAGDOLL_TIME, forceRecover)
	else
		for _, info in ipairs(motorInfos) do
			pcall(function() restoreMotor(info) end)
		end
		removeRagdollArtifacts()
		setCollision(false)
		task.wait()
		pcall(function()
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.Standing)
		end)
		ragdolled = false
	end
end

local function fixAccessories(enable)
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") and acc:FindFirstChild("Handle") then
			local handle = acc.Handle
			if enable then
				if not handle:FindFirstChild("RagdollWeld") then
					local weld = Instance.new("WeldConstraint")
					weld.Name = "RagdollWeld"
					weld.Part0 = char:FindFirstChild("Head") or hrp
					weld.Part1 = handle
					weld.Parent = handle
				end
			else
				local weld = handle:FindFirstChild("RagdollWeld")
				if weld then weld:Destroy() end
			end
		end
	end
end

-- Начальная очистка
task.defer(function()
	pcall(removeRagdollArtifacts)
	for _, info in ipairs(motorInfos) do
		restoreMotor(info)
	end
	setCollision(false)
end)

-- Флаг смерти
humanoid.Died:Connect(function()
	dead = true
	forceRecover()
end)

-- Главный цикл падения
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
	if dead then return end
	if not hrp or not hrp.Parent then return end
	if tick() - scriptStart < STARTUP_PROTECT then return end

	local velY = hrp.Velocity.Y

	if velY < FALL_SPEED and not falling then
		falling = true
		fallStartTime = tick()
	end

	-- Рэгдолл от падения
	if falling and not ragdolled and fallStartTime and (tick() - fallStartTime >= FALL_TIME) then
		if not isHoldingGravityTool() and humanoid.Health > 10 then -- проверка HP
			setRagdoll(true)
			fixAccessories(true)
		end
	end

	-- Приземление
	local landed = false
	if falling then
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			landed = true
		elseif math.abs(hrp.Velocity.Y) < 1 and (tick() - fallStartTime > 0.15) then
			landed = true
		end
	end

	if landed then
		falling = false
		if ragdolled then
			task.delay(RAGDOLL_TIME, function()
				if not dead then
					setRagdoll(false)
					fixAccessories(false)
				end
			end)
		else
			removeRagdollArtifacts()
		end
		fallStartTime = nil
	end
end)
