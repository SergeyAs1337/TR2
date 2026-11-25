-- ServerScriptService/Notify  (ModuleScript, только сервер)  v1
-- Сообщения игроку из любого серверного скрипта:
--   local Notify = require(game:GetService("ServerScriptService"):WaitForChild("Notify"))
--   Notify.send(player, "Не хватает монет!", "bad")   -- уведомление сверху экрана
--   Notify.openScreen(player, "Upgrades")              -- открыть окно (UILib.window с таким name)
-- Клиентская часть: CoinsHud слушает эти события и вызывает UILib.toast / UILib.open.
-- Модуль создаёт RemoteEvent-ы один раз, поэтому их не нужно заводить в Studio руками.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = {}

local function getRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local notifyRemote = getRemote("Notify")
local openScreenRemote = getRemote("OpenScreen")

-- color: accent, good, bad, warn (как в UILib.THEME.palette)
function Notify.send(player, text, color)
	if typeof(player) == "Instance" and player:IsA("Player") and typeof(text) == "string" then
		notifyRemote:FireClient(player, text, color)
	end
end

function Notify.openScreen(player, screenName)
	if typeof(player) == "Instance" and player:IsA("Player") and typeof(screenName) == "string" then
		openScreenRemote:FireClient(player, screenName)
	end
end

return Notify
