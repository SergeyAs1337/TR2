-- tools/cleanup_old_scripts.lua — удалить в Studio старые скрипты и интерфейсы,
-- которые заменены новыми (Rojo сам ничего не удаляет).
--
-- Как запустить: в Studio View -> Command Bar, вставь весь этот файл и нажми Enter.
-- Сначала ПРОБНЫЙ прогон (DRY_RUN = true): в Output покажется, что будет удалено.
-- Потом поменяй DRY_RUN на false и запусти ещё раз. Удаление можно отменить Ctrl+Z.

local DRY_RUN = true

-- путь от game, через точку
local OBSOLETE = {
	-- раздел 2 CHANGES.md
	"ServerScriptService.losssaved", -- дубль ставок, заменён gamble
	"ServerScriptService.hyperscript", -- вторая система апгрейдов
	"ServerScriptService.admin", -- заменён AdminService
	"ServerScriptService.CoinPopUp", -- мёртвый код
	"ServerScriptService.sbrocs", -- сброс дейлика админа при каждом старте
	"ServerScriptService.DailyQuestModule", -- мёртвый дубль everydaycount
	"ServerScriptService.voice upgrade", -- серверный скрипт с клиентским кодом, не работал
	"StarterGui.GambleUI",
	"StarterGui.CoinsDeaths",
	"StarterGui.CoinPopupGui",
	"StarterGui.UpgradeGUI",
	"StarterGui.EventUI",
	"StarterGui.AdminResetGui",
	"StarterGui.DailyQuestGui",
	"StarterGui.DialogueGui",
	"StarterGui.RadioUI",
	"StarterGui.EmotionGui",
	"StarterPlayer.StarterPlayerScripts.ewq", -- вошёл в EmotionMenu
	"ReplicatedStorage.Radio.RadioModel.Base.Script", -- дубль обработчика радио
	"ReplicatedStorage.CoinPopup", -- RemoteEvent мёртвого CoinPopUp
}

local function resolve(path)
	local current = game
	for name in string.gmatch(path, "[^%.]+") do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
if not DRY_RUN then
	ChangeHistoryService:SetWaypoint("TR2 cleanup: до")
end

local found = 0
for _, path in OBSOLETE do
	local instance = resolve(path)
	if instance then
		found += 1
		if DRY_RUN then
			print("[cleanup] будет удалено:", path, "(" .. instance.ClassName .. ")")
		else
			instance:Destroy()
			print("[cleanup] удалено:", path)
		end
	end
end

if DRY_RUN then
	print(("[cleanup] пробный прогон: найдено %d из %d. Поставь DRY_RUN = false и запусти снова."):format(found, #OBSOLETE))
else
	ChangeHistoryService:SetWaypoint("TR2 cleanup: после")
	print(("[cleanup] готово: удалено %d. Отменить — Ctrl+Z."):format(found))
end
