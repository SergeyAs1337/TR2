return {
	ID = "ice_cream",
	Name = "V4Ska",
	OneTime = false,

	Steps = {
		["start"] = {
			Lines = {
				"Привет привет!",
				"Хочешь мороженного? Всего 15 монет!"
			},
			Options = {
				{
					Text = "Да, с радостью!",
					Next = "try_buy"
				},
				{
					Text = "Нет, не хочу",
					Next = "decline"
				}
			}
		},

		["try_buy"] = {
			Text = "", -- текст будет проигнорирован, используется Reward-функция для логики
			Options = {
				{
					Text = "…", -- автоматически переходит на buy или not_enough
					Reward = function(player)
						local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
						if coins and coins.Value >= 15 then
							coins.Value -= 15

							local replicatedStorage = game:GetService("ReplicatedStorage")
							local iceCream = replicatedStorage:FindFirstChild("IceCream")
							if iceCream then
								local clone = iceCream:Clone()
								clone.Parent = player:FindFirstChild("Backpack") or player
							end

							-- Установим шаг вручную
							local event = game.ReplicatedStorage:WaitForChild("DialogueSystem"):WaitForChild("StartDialogue")
							event:FireClient(player, "ice_cream", {
								Text = "Держи мороженое! Приятного аппетита!",
								Options = {
									{ Text = "Спасибо!" }
								},
								Name = "V4Ska"
							})
						else
							local event = game.ReplicatedStorage:WaitForChild("DialogueSystem"):WaitForChild("StartDialogue")
							event:FireClient(player, "ice_cream", {
								Text = "Ой, у тебя не хватает монет!",
								Options = {
									{ Text = "Жаль..." }
								},
								Name = "V4Ska"
							})
						end
					end
				}
			}
		},

		["decline"] = {
			Text = "Ну ладно, если передумаешь — подходи!",
			Options = {
				{
					Text = "Окей!",
					Next = nil
				}
			}
		}
	}
}
