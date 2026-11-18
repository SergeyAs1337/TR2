-- RadioTool → LocalScript
-- Печатает каждый шаг, чтобы сразу видеть, где цепочка рвётся.

local player            = game.Players.LocalPlayer
local tool              = script.Parent
local rs                = game:GetService("ReplicatedStorage")
local placeRadio        = rs:WaitForChild("PlaceRadio")

local CAN_PLACE = true

local function dbg(...)
	print("[CLIENT]", ...)
end

tool.Activated:Connect(function()
	if not CAN_PLACE then
		dbg("Нельзя ставить повторно, Tool уничтожен или ещё не подобран.")
		return
	end

	dbg("Tool.Activated ✔")

	local mouse = player:GetMouse()
	if not mouse or not mouse.Hit then
		dbg("mouse или mouse.Hit == nil - не удалось получить позицию.")
		return
	end

	local pos = mouse.Hit.Position
	dbg("mouse.Hit →", pos)

	placeRadio:FireServer(pos)
	dbg("PlaceRadio:FireServer отправлен.")

	-- Ждём полсекунды, чтобы вывод в консоли успел появиться
	task.wait(0.5)
end)

-- Когда сервер разрешит ставить заново (после Pickup)
rs:WaitForChild("PickupRadio").OnClientEvent:Connect(function()
	dbg("Получен сигнал с сервера: можно снова ставить радио.")
	CAN_PLACE = true
end)
