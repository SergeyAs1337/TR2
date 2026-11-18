local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local toolsDataStore = DataStoreService:GetDataStore("PlayerTools")

-- Загрузка предметов
local function loadTools(player)
	local userId = player.UserId
	local success, savedTools = pcall(function()
		return toolsDataStore:GetAsync("tools_" .. userId)
	end)

	if success and savedTools then
		local backpack = player:WaitForChild("Backpack")
		for _, toolName in ipairs(savedTools) do
			local tool = ReplicatedStorage:FindFirstChild(toolName)
			if tool and tool:IsA("Tool") then
				local clone = tool:Clone()
				clone.Parent = backpack
			end
		end
	end
end

-- Сохранение предметов
local function saveTools(player)
	local userId = player.UserId
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local toolNames = {}
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(toolNames, item.Name)
		end
	end

	pcall(function()
		toolsDataStore:SetAsync("tools_" .. userId, toolNames)
	end)
end

-- Подключение событий
Players.PlayerAdded:Connect(loadTools)
Players.PlayerRemoving:Connect(saveTools)
