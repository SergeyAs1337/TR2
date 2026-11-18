return {
	ID = "hello_world",
	Name = "Serg20087720",
	OneTime = true,

	Steps = {
		["start"] = {
			Text = "Привет! ты тут новенький?",
			Options = {
				{
					Text = "Да, конечно!",
					Next = "accept"
				},
				{
					Text = "Я уже смешарик.",
					Next = "decline"
				}
			}
		},

		["accept"] = {
			Lines = {
				"Видно что новенький!",
				"Ты ведь  хочешь заработать?",
				"Знаю что хочешь!",
				"Страховка тут бесплатная и за 'несчастные случии' нам платят",
				"Так что можешь идти кидаться под фуру :)"
			},
			Options = {
				{
					Text = "Спасибо вам!",
					Reward = function(player)
						player.leaderstats.Coins.Value += 0
					end
				},
				{
					Text = "Огромное спасибо!",
					Reward = function(player)
						player.leaderstats.Coins.Value += 0
					end
				}
			}
		},

		["decline"] = {
			Text = "А ты не врешь?",
			Options = {
				{
					Text = "Конечно нет!",
					Next = nil
				},
				{
					Text = "Вру...",
					Next = "start"
				}
			}
		}
	}
}
