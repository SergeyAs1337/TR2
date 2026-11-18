local pokypka = script.Parent
local price = pokypka.price
local aktivate = pokypka.price_aktive
local sound = pokypka.ui_buy

local repstorage = game:GetService("ReplicatedStorage")
local sword = repstorage.LinkedSword

aktivate.Triggered:Connect(function(player)

	if player.leaderstats.Deaths.Value >= price.Value then

		player.leaderstats.Deaths.Value -= price.Value
		sound:Play()
		local clone = sword:Clone()
		clone.Parent = player:WaitForChild("Backpack")
	else

		print("not enough money")
	end
end)
