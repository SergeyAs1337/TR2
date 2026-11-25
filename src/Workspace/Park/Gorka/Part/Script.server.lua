script.Parent.Touched:Connect(function(hit)
	if hit.Parent:FindFirstChild("Humanoid") then
		hit.Parent:FindFirstChild("Humanoid").Sit = true
	end
end)