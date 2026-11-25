-- ReplicatedStorage/Dialogues/hello_world  (ModuleScript)  v2: убраны пустые награды (+0 монет),
-- которые падали с ошибкой, пока не загрузились leaderstats.
return {
	ID = "hello_world",
	Name = "Serg20087720",
	Npc = "Serg20087720", -- модель NPC в Workspace: говорить можно только рядом с ним
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
				"Ты ведь хочешь заработать?",
				"Знаю что хочешь!",
				"Страховка тут бесплатная и за «несчастные случаи» нам платят",
				"Так что можешь идти кидаться под фуру :)"
			},
			Options = {
				{ Text = "Спасибо вам!" },
				{ Text = "Огромное спасибо!" },
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
