-- ServerStorage/Furocka3/Убивца/Script  v2: не падает, если коснулась деталь без родителя
-- (обломки, удалённые детали). Логика прежняя: касание фуры убивает.
script.Parent.Touched:Connect(function(part)
	local model = part.Parent
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end)
