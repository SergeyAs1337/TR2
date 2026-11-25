svet = script.Parent.SpotLight

light = game.Lighting

svet.Enabled = false

while true do
	
	if light.ClockTime >= 19 or light.ClockTime <= 5 then
	
		svet.Enabled = true
		
	else
		
		svet.Enabled = false
		
	end
	
	wait(1)

end