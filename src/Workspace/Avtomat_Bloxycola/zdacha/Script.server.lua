-- Workspace/Avtomat_Bloxycola/zdacha/Script  (Script)  v2 — автомат с Bloxy Cola
-- Что исправлено: скрипт падал, если монеты ещё не загрузились; нет спама покупками,
-- пока автомат «выдаёт» банку (3 секунды). Банка по-прежнему появляется в лотке.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local zdacha = script.Parent
local price = zdacha:WaitForChild("price")
local aktivate = zdacha:WaitForChild("price_aktive")
local spawnPart = zdacha.Parent:WaitForChild("spawn")
local sound = zdacha:FindFirstChild("sliding door close")
local bloxyCola = ReplicatedStorage:WaitForChild("Bloxy_cola")

local okNotify, Notify = pcall(function()
	return require(ServerScriptService:WaitForChild("Notify", 10))
end)

local dispensing = false

aktivate.Triggered:Connect(function(player)
	if dispensing then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local cost = price.Value
	if not coins or typeof(cost) ~= "number" or cost < 0 then
		return
	end
	if coins.Value < cost then
		if okNotify and Notify then
			Notify.send(player, "Не хватает монет: нужно " .. cost, "bad")
		end
		return
	end

	dispensing = true
	coins.Value -= cost
	if sound then
		sound:Play()
	end
	task.wait(3)
	local clone = bloxyCola:Clone()
	clone.Parent = workspace
	local handle = clone:FindFirstChild("Handle")
	if handle then
		handle.Position = spawnPart.Position - Vector3.new(0, 0.2, 0)
	end
	dispensing = false
end)
