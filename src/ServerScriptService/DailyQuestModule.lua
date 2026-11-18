-- ServerScriptService/DailyQuestModule.lua
local DailyQuestModule = {}

local DataStoreService = game:GetService("DataStoreService")
local deathStore = DataStoreService:GetDataStore("DailyDeathQuest")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local updateEvent = ReplicatedStorage:WaitForChild("DailyQuestUpdate")

local questTarget = 15
local rewards = {
	[1] = 30,
	[5] = 50,
	[15] = 150
}

local function getTodayKey()
	local now = os.date("!*t")
	return string.format("day_%d_%02d_%02d", now.year, now.month, now.day)
end

local function loadData(player)
	local key = player.UserId .. "_" .. getTodayKey()
	local data = deathStore:GetAsync(key) or {deaths = 0, rewardsGiven = {}}
	return data
end

local function saveData(player, data)
	local key = player.UserId .. "_" .. getTodayKey()
	deathStore:SetAsync(key, data)
end

function DailyQuestModule.OnPlayerAdded(player)
	local data = loadData(player)
	player:SetAttribute("DailyDeaths", data.deaths)
	updateEvent:FireClient(player, data.deaths)
end

function DailyQuestModule.OnPlayerDied(player)
	local data = loadData(player)
	data.deaths += 1
	player:SetAttribute("DailyDeaths", data.deaths)

	for threshold, coins in pairs(rewards) do
		if data.deaths == threshold and not data.rewardsGiven[threshold] then
			data.rewardsGiven[threshold] = true

			local stats = player:FindFirstChild("leaderstats")
			if stats and stats:FindFirstChild("Coins") then
				stats.Coins.Value += coins
				print(player.Name .. " получил " .. coins .. " монет за " .. threshold .. " смертей!")
			end
		end
	end

	saveData(player, data)
	updateEvent:FireClient(player, data.deaths)
end

return DailyQuestModule
