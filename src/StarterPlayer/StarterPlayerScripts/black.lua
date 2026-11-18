local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local figureModel = ReplicatedStorage:WaitForChild("BlackFigure")
local awardBadgeEvent = ReplicatedStorage:WaitForChild("AwardBadge")

local badgeGiven = false

local function spawnFigure()
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart")

	local clone = figureModel:Clone()
	clone.Parent = workspace

	for _, obj in pairs(clone:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Transparency = 0
			obj.Anchored = true
			obj.CanCollide = false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 0
		end
	end

	for _, partName in pairs({"Head", "HumanoidRootPart", "Left Arm", "Left Leg", "Right Arm", "Right Leg", "Torso"}) do
		local part = clone:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = Color3.new(0, 0, 0)
			part.Material = Enum.Material.SmoothPlastic
			part.Transparency = 0
		end
	end

	local backOffset = -rootPart.CFrame.LookVector * math.random(15, 25)
	local sideOffset = rootPart.CFrame.RightVector * math.random(-10, 10)

	local spawnPos = rootPart.Position + backOffset + sideOffset
	spawnPos = Vector3.new(spawnPos.X, rootPart.Position.Y + 3, spawnPos.Z)

	if clone.PrimaryPart then
		clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	else
		clone:PivotTo(CFrame.new(spawnPos))
	end

	local hrp = clone:FindFirstChild("HumanoidRootPart")
	local head = clone:FindFirstChild("Head")

	local fading = false
	local fadeTime = 2

	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not clone or not clone.Parent or not hrp then
			connection:Disconnect()
			return
		end

		local cameraPos = camera.CFrame.Position
		local camLook = camera.CFrame.LookVector
		local toCamera = (cameraPos - hrp.Position)
		toCamera = Vector3.new(toCamera.X, 0, toCamera.Z).Unit
		hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + toCamera)

		if head then
			head.CFrame = CFrame.lookAt(head.Position, cameraPos)
		end

		local toFigure = (hrp.Position - cameraPos).Unit

		if camLook:Dot(toFigure) > 0.94 and not fading then
			fading = true
			local elapsed = 0
			RunService:BindToRenderStep("FadeOutFigure", Enum.RenderPriority.Camera.Value + 1, function(step)
				elapsed += step
				local alpha = math.clamp(elapsed / fadeTime, 0, 1)
				for _, obj in pairs(clone:GetDescendants()) do
					if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
						obj.Transparency = alpha
					end
				end
				if alpha >= 1 then
					RunService:UnbindFromRenderStep("FadeOutFigure")
					clone:Destroy()
					if not badgeGiven then
						badgeGiven = true
						awardBadgeEvent:FireServer()
					end
				end
			end)
		end
	end)
end

while true do
	task.wait(math.random(1000, 2000))
	spawnFigure()
end
