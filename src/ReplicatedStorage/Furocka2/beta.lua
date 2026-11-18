local fura = script.Parent
while true do
	local currentPivot = fura:GetPivot()
	local offsetCFrame = CFrame.new(1, 0, 0) -- Смещение на 3 единицы по оси X
	local newPivot = currentPivot * offsetCFrame
	fura:PivotTo(newPivot)
	task.wait()
end

