-- ReplicatedStorage/Dialogues/ice_cream  (ModuleScript)  v2
-- Мороженое у V4Ska. Reward у «Да» возвращает следующий шаг: "bought" или "not_enough"
-- (движок dialogsquests v2 поддерживает это), поэтому больше не нужен пустой шаг с «…».

local PRICE = 15
local ITEM_NAME = "IceCream" -- инструмент в ReplicatedStorage

local function buy(player)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local backpack = player:FindFirstChildOfClass("Backpack")
	local item = game:GetService("ReplicatedStorage"):FindFirstChild(ITEM_NAME)
	if not coins or not backpack or not item then
		return "broken"
	end
	if coins.Value < PRICE then
		return "not_enough"
	end
	-- проверка и списание без yield: дважды купить на одни монеты нельзя
	coins.Value -= PRICE
	item:Clone().Parent = backpack
	return "bought"
end

return {
	ID = "ice_cream",
	Name = "V4Ska",
	Npc = "6V4Ska9", -- модель NPC в Workspace: говорить можно только рядом с ним
	OneTime = false,

	Steps = {
		start = {
			Lines = {
				"Привет-привет!",
				"Хочешь мороженого? Всего " .. PRICE .. " монет!",
			},
			Options = {
				{ Text = "Да, с радостью! (" .. PRICE .. " 🪙)", Reward = buy },
				{ Text = "Нет, не хочу", Next = "decline" },
			},
		},

		bought = {
			Text = "Держи мороженое! Приятного аппетита!",
			Options = { { Text = "Спасибо!" } },
		},

		not_enough = {
			Text = "Ой, у тебя не хватает монет!",
			Options = { { Text = "Жаль…" } },
		},

		broken = {
			Text = "Ой, мороженое закончилось. Загляни попозже!",
			Options = { { Text = "Ладно" } },
		},

		decline = {
			Text = "Ну ладно, если передумаешь — подходи!",
			Options = { { Text = "Окей!" } },
		},
	},
}
