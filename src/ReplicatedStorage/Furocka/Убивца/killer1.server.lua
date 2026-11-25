local part = script.Parent  -- часть фуры
local knockbackForce = 100  -- сила откидывания

part.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if humanoid and hrp and humanoid.Health > 0 then
		-- Откидываем
		local bodyVel = Instance.new("BodyVelocity")
		bodyVel.Velocity = (hrp.Position - part.Position).Unit * knockbackForce + Vector3.new(0, 30, 0)
		bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bodyVel.P = 1000
		bodyVel.Parent = hrp
		game:GetService("Debris"):AddItem(bodyVel, 0.2)

		task.wait(0.3)
		humanoid:TakeDamage(25)
	end
end)
