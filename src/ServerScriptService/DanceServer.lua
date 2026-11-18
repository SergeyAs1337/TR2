local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local dancesFolder  = ReplicatedStorage:WaitForChild("Dances")
local musicFolder   = ReplicatedStorage:WaitForChild("DanceMusic")
local DanceRequest  = ReplicatedStorage:WaitForChild("DanceRequest")
local StopDance     = ReplicatedStorage:WaitForChild("DanceEnded")



local playing = {}

local function restoreMovement(humanoid, data)
	if data.blocked then
		humanoid.WalkSpeed = data.oldSpeed
		humanoid.JumpPower = data.oldJump
	end
end

local function stopForPlayer(player)
	
	local data = playing[player]
	if not data then 
		return 
	end
	playing[player] = nil

	local character = player.Character
	if not character then 
		return 
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		for _, tr in ipairs(humanoid:GetPlayingAnimationTracks()) do
			tr:Stop()
		end
		restoreMovement(humanoid, data)
	end

	if data.sound then
		data.sound:Stop()
		data.sound:Destroy()
	end
end

DanceRequest.OnServerEvent:Connect(function(player, danceName)

	if playing[player] then 
		
		return 
	end

	local character = player.Character
	if not character then 
		return 
	end

	local humanoid  = character:FindFirstChild("Humanoid")
	if not humanoid then 
		return 
	end

	local animObj = dancesFolder:FindFirstChild(danceName)
	if not animObj then 
		return 
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animObj.AnimationId

	local track = humanoid:LoadAnimation(animation)
	track.Looped = animObj:FindFirstChild("Looped") and animObj.Looped.Value or false

	local blockMove = animObj:FindFirstChild("BlockMovement") and animObj.BlockMovement.Value or false
	track:Play()

	local soundTmpl = musicFolder:FindFirstChild(danceName)
	local soundClone
	if soundTmpl then
		soundClone = soundTmpl:Clone()
		soundClone.Looped = track.Looped
		soundClone.Parent = character:WaitForChild("HumanoidRootPart")
		soundClone:Play()
	end

	playing[player] = {
		blocked  = blockMove,
		oldSpeed = humanoid.WalkSpeed,
		oldJump  = humanoid.JumpPower,
		sound    = soundClone,
	}

	if blockMove then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0.001
	end

	if not track.Looped then
		track.Stopped:Connect(function()
			stopForPlayer(player)
		end)
	end
end)

StopDance.OnServerEvent:Connect(function(player)
	stopForPlayer(player)
end)
