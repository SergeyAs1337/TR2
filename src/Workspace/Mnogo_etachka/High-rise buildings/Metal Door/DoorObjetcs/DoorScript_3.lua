--Es importante seguir las recomendaciones del video tutorial. Rodrikius12

--Variables
local PrimaryPart = script.Parent.Parent.PrimaryPart
local open = false
local Door = script.Parent.Parent
local Proximity = script.Parent:WaitForChild("ProximityPrompt")
local OpenSound = script.Parent.Sounds.Open
local CloseSound = script.Parent.Sounds.Close

--Colocamos Sounds y Proximity en la puerta
OpenSound.Parent = Door
CloseSound.Parent = Door
Proximity.Parent = Door 

--Evento del ProximityPrompt
Proximity.Triggered:Connect(function(Players)
	
	
	if open == false then
		open = true
		OpenSound:Play()
		Proximity.ActionText = "Close"
		for i = 1, 20 do 
			Proximity.MaxActivationDistance = 0
			script.Parent.Parent:SetPrimaryPartCFrame(PrimaryPart.CFrame*CFrame.Angles(0, math.rad(5), 0))
			wait()
			Proximity.MaxActivationDistance = 10
		end
	else
		open = false
		CloseSound:Play()
		Proximity.ActionText = "Open"
		for i = 1, 20 do
			Proximity.MaxActivationDistance = 0
			script.Parent.Parent:SetPrimaryPartCFrame(PrimaryPart.CFrame*CFrame.Angles(0, math.rad(-5), 0))
			wait()
			Proximity.MaxActivationDistance = 10
		end
	end
	
end)


