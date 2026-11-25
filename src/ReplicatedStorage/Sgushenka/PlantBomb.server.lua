local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tool              = script.Parent
local BombScriptTemplate = Tool:WaitForChild("Bomb")       -- скрипт-заготовка
local sgushmesh         = ReplicatedStorage:WaitForChild("sgushmesh")

Tool.Enabled = true

local function plant()
	local character = Tool.Parent
	local player    = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- создаём «телo» бомбы
	local bomb = Instance.new("Part")
	bomb.Size          = Vector3.new(2, 2, 2)
	bomb.Position      = Tool.Handle.Position + Vector3.new(0, 3, 0)
	bomb.Shape         = Enum.PartType.Ball
	bomb.TopSurface    = Enum.SurfaceType.Smooth
	bomb.BottomSurface = Enum.SurfaceType.Smooth
	bomb.BrickColor    = BrickColor.new(21)               -- Bright red
	bomb.Name          = "TimeBomb"
	bomb.Locked        = true

	-- меш-модель
	local mesh = sgushmesh:Clone()
	mesh.Parent = bomb

	-- тег «creator» для корректного начисления килла
	local creator = Instance.new("ObjectValue")
	creator.Name  = "creator"
	creator.Value = player
	creator.Parent = bomb

	bomb.Parent = workspace

	-- копия управляющего скрипта
	local bombLogic = BombScriptTemplate:Clone()
	bombLogic.Parent   = bomb
	bombLogic.Disabled = false
end

Tool.Activated:Connect(function()
	if not Tool.Enabled then return end
	Tool.Enabled = false

	-- «прячем» сгущёнку
	Tool.Handle.Transparency = 1
	plant()                           -- ставим бомбу
	task.wait(6)                      -- откат
	Tool.Handle.Transparency = 0

	Tool.Enabled = true
end)
