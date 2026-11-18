local object = script.Parent

task.delay(30, function()
	if object and object.Parent then
		object:Destroy()
	end
end)
