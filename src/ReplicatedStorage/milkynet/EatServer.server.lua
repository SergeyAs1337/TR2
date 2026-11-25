-- ReplicatedStorage/milkynet/EatServer  (Script в инструменте)  v2 — даёт +100 к макс. ХП
-- Что исправлено: раньше сервер принимал EatEvent без ограничений. Читер мог отправить
-- событие сотни раз за те 4 секунды, пока предмет не исчез, и получить эффект сотни раз
-- (у milkynet — бесконечное макс. ХП). Теперь использования считает сервер, есть кулдаун,
-- и есть предмет можно только свой и только в руках.

local tool = script.Parent
local eatEvent = tool:WaitForChild("EatEvent")

local MAX_USES = 1
local COOLDOWN = 1 -- секунд между укусами, как в клиентском скрипте
local BONUS_MAX_HEALTH = 100 -- +макс. ХП (до смерти)

local usesLeft = MAX_USES
local lastUse = -math.huge

eatEvent.OnServerEvent:Connect(function(player)
	if usesLeft <= 0 then
		return
	end
	local character = player.Character
	if not character or tool.Parent ~= character then
		return -- предмет должен быть в руках у того, кто ест
	end
	local now = os.clock()
	if now - lastUse < COOLDOWN then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	lastUse = now
	usesLeft -= 1
		humanoid.MaxHealth += BONUS_MAX_HEALTH

	if usesLeft <= 0 then
		task.delay(4, function()
			if tool.Parent then
				tool:Destroy()
			end
		end)
	end
end)
