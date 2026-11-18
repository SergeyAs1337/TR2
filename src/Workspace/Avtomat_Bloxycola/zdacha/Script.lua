local zdacha = script.Parent
local price = zdacha.price
local aktivate = zdacha.price_aktive
local spawn = zdacha.Parent.spawn
local sound = zdacha["sliding door close"]

local repstorage = game:GetService("ReplicatedStorage")
local bloxy_cola = repstorage.Bloxy_cola
local pos = spawn.Position

aktivate.Triggered:Connect(function(player)

	if player.leaderstats.Coins.Value >= price.Value then

		player.leaderstats.Coins.Value -= price.Value
		sound:Play()
		task.wait(3)
		local clone = bloxy_cola:Clone()
		clone.Parent = workspace
		clone.Handle.Position = pos - Vector3.new(0,0.2,0)
	else

		print("not enough money")
	end
end)
