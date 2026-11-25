local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TRUCK_MODEL_NAME = "Furocka"
local SPAWN_PART_NAME = "spawner"
local TRUCK_LIFETIME = 14
local RESPAWN_DELAY = 3
local MAX_TRUCKS = 20

local originalTruck = ReplicatedStorage:FindFirstChild(TRUCK_MODEL_NAME)
local spawnPart = Workspace:FindFirstChild(SPAWN_PART_NAME)

if not originalTruck then
	warn("TruckSpawner Error: Original truck model named '" .. TRUCK_MODEL_NAME .. "' not found in ReplicatedStorage.")
	return
end

if not spawnPart then
	warn("TruckSpawner Error: Spawn part named '" .. SPAWN_PART_NAME .. "' not found in Workspace.")
	return
end

if not spawnPart:IsA("BasePart") then
	warn("TruckSpawner Error: Spawn part '" .. SPAWN_PART_NAME .. "' is not a BasePart and does not have a CFrame.")
	return
end

local activeTrucks = {}

while true do
	-- Очищаем список от уничтоженных грузовиков
	local updatedActiveTrucks = {}
	for i, truckRef in ipairs(activeTrucks) do
		if truckRef and truckRef.Parent then
			table.insert(updatedActiveTrucks, truckRef)
		end
	end
	activeTrucks = updatedActiveTrucks

	if #activeTrucks < MAX_TRUCKS then        
		local clonedTruck = originalTruck:Clone()
		clonedTruck:PivotTo(spawnPart.CFrame)
		clonedTruck.Parent = Workspace
		table.insert(activeTrucks, clonedTruck)

		-- Таймер на уничтожение
		task.delay(TRUCK_LIFETIME, function()
			-- Ищем индекс грузовика, чтобы удалить из списка
			local truckIndex = nil
			for i, t in ipairs(activeTrucks) do
				if t == clonedTruck then
					truckIndex = i
					break
				end
			end

			if clonedTruck and clonedTruck.Parent then
				clonedTruck:Destroy()
			end

			if truckIndex then
				table.remove(activeTrucks, truckIndex)
			end
		end)
	end

	task.wait(RESPAWN_DELAY)
end
