# TR2 — что изменено

Архив собран из всех правок за время работы. Папка `src/` повторяет структуру репозитория:
распакуй её поверх корня репозитория, затем перенеси те же скрипты в Studio (таблица ниже).

Содержимое: `src/` — скрипты для игры, `tools/` — одноразовый скрипт переноса (в игру НЕ класть),
`tests/` — тесты на макете Roblox API (необязательно).

## 0. Редизайн интерфейсов (v3, стиль админ-панели)

Все игровые интерфейсы теперь в одном тёмном стиле с админ-панелью: фон `24,26,33`, блоки
`33,36,46`, поля и дорожки `46,50,64`, синий акцент, шрифт Gotham, скругления 8 px, без
обводок и градиентов. Окна сами подстраиваются под экран (телефон / ПК), одновременно открыто
только одно окно, клик по затемнению вокруг окна закрывает его.

**Сменить стиль потом:** весь внешний вид задаётся в `ReplicatedStorage/UILib.lua`: цвета, шрифты,
скругления в `THEME`, форма кнопок в `actionButton`, окна в `window`, уведомления в `toast`.
Окна игры пользуются только ими, поэтому новый стиль — это правка одного файла.

| Файл | Куда | Что |
|---|---|---|
| `ReplicatedStorage/UILib.lua` | ModuleScript, замена | Тема `THEME` и компоненты: `actionButton` (цвета `accent`, `good`, `bad`, `warn`, `neutral`; подсветка и нажатие), `window`, `panel`, `toast`, `text`, `stroke`, `tween`, `bump`, `shake`, `fitScale`, `formatShort` («1.25M»). `UILib.open("Имя")` открывает окно из любого LocalScript. Старые функции v1 оставлены. |
| `ReplicatedStorage/GambleScreen.lua` | ModuleScript, замена | Автомат: три барабана (семёрка + 🍒🍋🔔💎⭐🍀), крутятся и останавливаются по очереди на результате с сервера. x10 — три семёрки, x2 — три одинаковых, проигрыш — разные. Быстрые ставки «½», «x2», «+1К», «Всё», баланс, «Проиграно всеми». Окно после ставки не закрывается. Ставку больше баланса не отправляет. Если сервер не ответил 5 с — барабаны останавливаются. |
| `ServerScriptService/gamble.lua` | Script, замена | Отвечает клиенту результатом. **Ставить вместе с `GambleScreen`**: без ответа сервера барабаны остановятся на «Сервер не ответил». |
| `StarterPlayerScripts/CoinsHud.lua` | LocalScript, замена | Слева посередине: плашки 🪙 монет и 💀 смертей (число плавно «докручивается»), под ними кнопка «⬆ Апгрейды». Свои кнопки меню добавляются в `MENU_BUTTONS`. |
| `StarterPlayerScripts/CoinPopups.lua` | LocalScript, замена | «+250 🪙» с тёмным контуром (читается поверх любого фона) взлетает и тает; крупные суммы (от `BIG_GAIN`) крупнее. |
| `StarterPlayerScripts/EventBanner.lua` | LocalScript, **новый** | Баннер событий сверху: тёмная плашка с оранжевой полоской и подписью «СОБЫТИЕ». Объявления админа («📢 …») — с синей полоской и подписью «ОБЪЯВЛЕНИЕ». Заменяет `StarterGui/EventUI` (удалить). |
| `StarterPlayerScripts/UpgradeShop.lua` | LocalScript, **новый** | Окно апгрейдов: 4 карточки (иконка, «3 / 10», полоска уровня, «было → станет», «Купить · 🪙 цена»; серая, если не хватает монет; «Максимум» на максимуме). Ошибки сервера и «уровень N» — уведомлениями. Заменяет `StarterGui/UpgradeGUI` (удалить). |

Важно:
- **Как открывалось старое окно апгрейдов?** Новое открывается кнопкой в HUD. Если в мире был
  ProximityPrompt / кнопка, которая включала `UpgradeGUI.Frame.Visible`, замени это в LocalScript на
  `require(game.ReplicatedStorage.UILib).open("Upgrades")`.
- Цены и формулы апгрейдов в `UpgradeShop.lua` скопированы из `UpgradeHandler.lua`. Поменяешь
  `LEVEL_PRICES` или формулы на сервере — поменяй и в `UpgradeShop` (списывает всё равно сервер).
- Проверено на макете (437 проверок). **В Studio не проверено:** как выглядят эмодзи
  на разных устройствах, точные размеры на маленьких телефонах. Нужен плейтест.

## 0б. Дейлики, диалоги, радио, эмоции и проверка на дыры

### Новые и переписанные скрипты

| Файл | Куда в Studio | Что |
|---|---|---|
| `ServerScriptService/Notify.lua` | ModuleScript, **новый** | Сообщения игроку с сервера: `Notify.send(player, текст, цвет)` (уведомление) и `Notify.openScreen(player, "Upgrades")` (открыть окно). RemoteEvent-ы `Notify` и `OpenScreen` создаёт сам. Клиентская часть в `CoinsHud`. |
| `ServerScriptService/everydaycount.lua` | Script, замена | **Дейлики починены.** Сбой загрузки больше не считается «новым днём» (раньше награды можно было получить заново, а сохранение затирало прогресс): загрузка повторяется, а пока данных нет, задание не считается и не пишется. Сохранение раз в минуту, при выходе и в `BindToClose` вместо `SetAsync` на каждой смерти (выедало лимит DataStore). `UpdateAsync` со слиянием. Награда ждёт загрузки `leaderstats`, а не теряется. Хранилище и формат прежние — прогресс игроков сохраняется. |
| `StarterPlayerScripts/DailyQuestHud.lua` | LocalScript, **новый** | Плашка задания сверху: «7 / 15», полоска, отметки наград +30/+50/+150, после выполнения — время до нового задания. Читает атрибуты игрока. Заменяет `StarterGui/DailyQuestGui`. |
| `ServerScriptService/dialogsquests.lua` | Script, замена | Движок диалогов: `Reward` может вернуть имя следующего шага, ошибки в `Reward` не ломают диалог, клиенту уходят только тексты, проверка типов, частоты и расстояния до NPC (поле `Npc` в модуле диалога). Запуск с сервера: `ServerStorage.DialogueServer.StartDialogue` (BindableEvent, создаётся сам). |
| `ServerStorage/NPCTemplates/*/quest.lua` | Script, замена | **Диалоги с NPC, судя по коду, не запускались:** это серверные Script-ы, а они сравнивали игрока с `LocalPlayer` (на сервере nil) и звали `FireServer`. Теперь работают и как Script, и с RunContext = Client. Nullbit открывает окно апгрейдов через `Notify` (старый способ ломался на новом окне). |
| `ReplicatedStorage/Dialogues/ice_cream.lua`, `hello_world.lua` | ModuleScript, замена | Мороженое: нормальные шаги «купил / не хватает монет» вместо пустого шага с «…». В `hello_world` убраны награды «+0 монет», которые падали, пока не загрузились монеты. |
| `StarterPlayerScripts/DialogueUI.lua` | LocalScript, **новый** | Окно диалога снизу: имя NPC, печать по буквам (кириллица больше не «ломается»), клик / E / Enter — дальше, варианты кнопками и цифрами 1–9. Заменяет `StarterGui/DialogueGui`. |
| `ServerScriptService/RadioHandler.lua` | Script, замена | **Свой трек теперь проверяет геймпасс на сервере** (раньше только интерфейс: любой мог включить любой звук). Одно радио на игрока, лимит смены трека, проверка ID, атрибут `NowPlaying`, ответ клиенту об ошибке. |
| `StarterPlayerScripts/RadioMenu.lua` | LocalScript, **новый** | Меню радио: «Сейчас играет», список треков, свой трек по ID (без геймпасса предлагает купить), «Стоп», «Подобрать радио». Заменяет `StarterGui/RadioUI`. |
| `ReplicatedStorage/Radio/LocalScript.lua` | LocalScript, замена | Без отладочного вывода на каждый клик. |
| `ServerScriptService/DanceServer.lua` | Script, замена | После смерти во время танца можно снова танцевать (раньше — нет). Новый танец сменяет старый. Останавливается только танец, а не все анимации. Скорость от апгрейда не сбрасывается. Атрибут `Dancing`. |
| `StarterPlayerScripts/EmotionMenu.lua` | LocalScript, **новый** | Меню эмоций (G или кнопка «Эмоции» в HUD, на телефоне тоже): сетка танцев, текущий подсвечен, «Остановить». Остановка пробелом / прыжком / B уходит на сервер, только если игрок танцует. Заменяет `StarterGui/EmotionGui` и `ewq`. |
| `StarterPlayerScripts/CoinsHud.lua` | LocalScript, замена | Кнопка «💃 Эмоции», приём `Notify` и `OpenScreen` с сервера. |

### Найденные дыры и поломки (исправлено)

| Где | Что было | Что стало |
|---|---|---|
| `milkynet/EatServer` | Спам `EatEvent` за 4 секунды до исчезновения предмета давал +100 макс. ХП за каждое событие: **бесконечное здоровье**. | Использования считает сервер, кулдаун, есть можно только свой предмет в руках. |
| `IceCream/EatServer` | То же: лечение +50 на каждое событие. | То же исправление. |
| `RadioHandler` | Геймпасс на свои треки проверялся только на клиенте. | Проверка на сервере. |
| `Stick/Script` | Нет кулдауна (автокликер = гарантированный лазер 9999 урона и бейдж), можно было стрелять из чужой палки, нет проверки точки. | Только своя палка в руках, кулдаун 0.5 с, проверка точки. Шанс и урон прежние. |
| `Sgushenkamet/Script` | Неверная точка роняла скрипт ПОСЛЕ списания банки: кулдаун залипал навсегда. Можно было стрелять из чужого оружия. Один снаряд мог взорваться несколько раз. | Проверки до списания, только своё оружие, один взрыв. |
| `ItemSAVE` | При сбое загрузки при выходе сохранялся пустой рюкзак: **все предметы игрока пропадали**. Предмет в руках не сохранялся. Нет `BindToClose`. | Без успешной загрузки не сохраняет; сохраняет и предмет в руках; повторы и `BindToClose`. |
| `achivki` | До 6 запросов к BadgeService на каждую смерть; две смерти подряд могли выдать монеты за бейдж дважды. | Каждый бейдж проверяется раз за сессию, одна проверка за раз. |
| `lookedachievent` | Событие можно было спамить. | Одна обработка на игрока за сессию. Бейдж всё ещё выдаётся по сигналу клиента (фигуру видит только он), но это только бейдж. |
| Магазины (8 скриптов в `Workspace/Shop`, `swordbuy`), автомат Bloxy Cola | Падали, если монеты ещё не загрузились; «not enough money» только в консоль сервера; автомат колы можно было спамить, пока выдаёт банку. | Безопасные проверки, уведомление игроку, защита от двойного нажатия. Цены прежние (значение `price`). |
| `time_set` | Переход день/ночь шёл 50 секунд вместо 5. | 5 секунд, как задумано. |
| `Furocka3/Убивца/Script` | Падал от касания деталью без родителя. | Проверка. |

### Удалить в Studio

`StarterGui/DailyQuestGui`, `StarterGui/DialogueGui`, `StarterGui/RadioUI`, `StarterGui/EmotionGui`,
`StarterGui/AdminResetGui`, `StarterPlayerScripts/ewq`, `ServerScriptService/DailyQuestModule`,
`ServerScriptService/sbrocs`, `ServerScriptService/voice upgrade` (серверный скрипт с клиентским кодом:
не работал, событие `SendLikelySpeakingUsers` никто не отправляет), `ReplicatedStorage/Radio/RadioModel/Base/Script`
(дубль обработчика радио; новый `RadioHandler` на всякий случай удаляет его и из поставленных радио).
`ScreenGui` с сообщением Нексбота не трогал.

### Что осталось (не исправлял, решать тебе)

- Фуры-убийцы (`Furocka*/Убивца`): `Touched` без паузы — одно касание даёт много срабатываний (урон 25 за каждое). Это влияет на баланс, поэтому не менял.
- Фуры двигаются `PivotTo` каждый кадр на сервере: при 20 фурах это ощутимая нагрузка. Лучше физика или твины на клиенте.
- Дублирование монет при одновременном входе с двух серверов: нужна блокировка сессий (`ProfileStore`).
- Совместимость старых RemoteEvent админки (`EventAnnouncement`, `StopEventRemote` с клиента) в `AdminService` оставлена: проверяет админа, вреда нет, можно удалить.
- `falldam`, `RagdollOnDeath`, `LinkedSword`, `Gravity Coil`, `BloxyColaScript`, двери — без удалённых событий, серьёзных дыр не нашёл, глубоко не переписывал.

## 1. Файлы: заменить или добавить

| Файл в `src/` | Где в Studio | Действие | Что сделано |
|---|---|---|---|
| `ServerScriptService/gamble.lua` | `ServerScriptService/gamble` | замена | Единый обработчик ставок (раньше `gamble` и `losssaved` слушали одно событие: двойное списание и два розыгрыша). Проверка ставки (NaN, дробные, ≤0, >1e9), кулдаун 1 с. Общий счётчик проигранного через `UpdateAsync` + `BindToClose`. Шансы в таблице `OUTCOMES`: 1% x10, 24% x2 (подтвердить, в старых скриптах они расходились). **v2:** отвечает клиенту результатом ставки (`{ ok, bet, multiplier, win }` или `{ ok = false, reason }`), для барабанов автомата. |
| `ServerScriptService/LeaderboardManager.lua` (v4.1) | `ServerScriptService/LeaderboardManager` | замена | Сбой загрузки больше не затирает данные (5 попыток, затем кик). `leaderstats` создаётся после загрузки. Автосохранение раз в 90 с, параллельный `BindToClose`. Рейтинг смертей пишется в `OrderedDataStore`. Награда за смерть умножается на атрибут `CoinMultiplier`. Админ-команды проверяют аргументы. |
| `ServerScriptService/LeaderBoard.lua` | `ServerScriptService/LeaderBoard` | замена | Топ-1000 из `OrderedDataStore`: 10 запросов вместо тысяч `GetAsync`. Имена пачками через `UserService`, надписи переиспользуются. |
| `ServerScriptService/UpgradeHandler.lua` | `ServerScriptService/UpgradeHandler` | замена | Единая система апгрейдов вместо двух. Читает оба хранилища (`PlayerUpgrades`, `PlayerUpgradesV1`), берёт максимум уровней. Защита от двойных кликов, проверка имени апгрейда, запись через `UpdateAsync`. Множитель монет теперь атрибут `CoinMultiplier` (раньше умножал и выигрыши казино: при x3 казино становилось прибыльным). |
| `ServerScriptService/RandomEventController.lua` | `ServerScriptService/RandomEventController` | замена | Ошибка в событии больше не убивает контроллер. Не запускает события на пустом сервере и поверх события админа, не повторяет событие подряд. Выключатель и время следующего события для админ-панели. |
| `ServerScriptService/AdminService.lua` | `ServerScriptService/AdminService` (Script) | **новый** | Серверная часть админ-панели: проверка админа и аргументов на каждый запрос, лимит 8 запросов/с, журнал. Действия: события, монеты, убить/вылечить/заморозить, телепорт, кик, объявление (через фильтр Roblox). Совместим со старым `AdminResetGui`. |
| `ReplicatedStorage/EventManager.lua` | `ReplicatedStorage/EventManager` (ModuleScript) | замена | Починены события: «Дождь» (`RainFall` лежит в модели `ramki`), «Нексбот» падал при запуске. Единые `Events.Start/Stop` (одно событие за раз, ошибка в событии не пробивается наружу). «Дождь из фур»: фура раз в 0.5 с вместо каждого кадра. «Перемешивание»: корректные пары, без сидящих и мёртвых. «Вьетнам»: деревья/дороги/здания не трогаются, ≤120 деталей на взрыв, ≤500 сразу, обломки возвращаются через 10 с. «Нексбот»: собственное движение вместо гуманоида R6 без ног; упирается в стены и скользит вдоль них; обход через `PathfindingService`; прыгает (12 студов); убивает только при прямой видимости; появляется перед игроком. |
| `ReplicatedStorage/UILib.lua` | `ReplicatedStorage/UILib` (ModuleScript) | **новый** | **v3:** тема в стиле админ-панели и компоненты, см. раздел 0. |
| `ReplicatedStorage/GambleScreen.lua` | `ReplicatedStorage/GambleScreen` (ModuleScript) | **новый** | **v3:** автомат с барабанами, см. раздел 0. |
| `ReplicatedStorage/odnorykiy_bandit/LocalScript.lua` | `ReplicatedStorage/odnorykiy_bandit/LocalScript` | замена | Теперь только открывает окно (`GambleScreen`). |
| `StarterPlayer/StarterPlayerScripts/AdminPanel.lua` | `StarterPlayerScripts/AdminPanel` (LocalScript) | **новый** | Админ-панель (кнопка «🛠 Админ» или F2): вкладки События, Игроки, Сервер, Журнал. Строится кодом. |
| `StarterPlayer/StarterPlayerScripts/CoinsHud.lua` | `StarterPlayerScripts/CoinsHud` (LocalScript) | **новый** | **v3:** HUD монет и смертей с кнопкой «Апгрейды», см. раздел 0. |
| `StarterPlayer/StarterPlayerScripts/CoinPopups.lua` | `StarterPlayerScripts/CoinPopups` (LocalScript) | **новый** | **v3:** всплывашки «+N 🪙», см. раздел 0. Первое изменение не теряется, не больше 12 одновременно. |
| `tools/SeedDeathsLeaderboard.lua` | **не в игру** | запустить один раз | Переносит смерти старых игроков в новую таблицу лидеров. Запуск из Command Bar в Studio (опубликованное место, включён доступ Studio к API). Медленно (~60–70 игроков в минуту), можно прерывать и повторять. |

## 2. Что удалить

| Что | Почему |
|---|---|
| `ServerScriptService/losssaved` | Дубль обработчика ставок, заменён `gamble`. |
| `ServerScriptService/hyperscript` | Вторая система апгрейдов, слушает то же событие `UpgradeRequest`. |
| `ServerScriptService/admin` | Заменён `AdminService`. |
| `StarterGui/GambleUI`, `StarterGui/CoinsDeaths`, `StarterGui/CoinPopupGui` | Заменены интерфейсами, построенными кодом (старые удалять после проверки новых). |
| `StarterGui/UpgradeGUI`, `StarterGui/EventUI` | Заменены `UpgradeShop` и `EventBanner` (раздел 0). Если оставить, апгрейды и баннер событий будут показаны дважды. |
| `StarterGui/AdminResetGui` | Заменён `AdminPanel`. |
| `ServerScriptService/CoinPopUp` и RemoteEvent `CoinPopup` | Мёртвый код: функция `giveCoins` нигде не вызывается, клиент событие не слушает. |
| `ServerScriptService/sbrocs` | Тестовый сброс `DailyDeaths` админа при каждом старте сервера. |
| `ServerScriptService/DailyQuestModule` | Никем не подключён (мёртвый дубль `everydaycount`). |
| Остальное из раздела 0б | `DailyQuestGui`, `DialogueGui`, `RadioUI`, `EmotionGui`, `ewq`, `voice upgrade`, `Radio/RadioModel/Base/Script`. |

## 3. Порядок установки

1. **Данные и казино:** `LeaderboardManager`, `LeaderBoard`, `gamble`; удалить `losssaved`; опубликовать; один раз запустить `tools/SeedDeathsLeaderboard.lua`.
2. **Апгрейды:** `UpgradeHandler` и клиентский `UpgradeShop` (вместо `StarterGui/UpgradeGUI`); удалить `hyperscript`. Ставить вместе с п.1: множитель монет работает через `LeaderboardManager` v4.1.
3. **События и админка:** `EventManager`, `RandomEventController`, `EventLabel/LocalScript`; затем `AdminService` и `AdminPanel`; удалить `admin`.
4. **Интерфейсы:** `UILib` → `gamble` (v2) + `GambleScreen` + скрипт инструмента → `CoinsHud` → `CoinPopups` → `EventBanner` → `UpgradeShop`; удалить старые GUI (раздел 2).
5. **Раздел 0б:** сначала `Notify` (ModuleScript), затем серверные скрипты, NPC-скрипты в `ServerStorage/NPCTemplates`, магазины, и в конце LocalScript-ы `DailyQuestHud`, `DialogueUI`, `RadioMenu`, `EmotionMenu`; удалить перечисленное в 0б.

Модули `EventManager`, `UILib`, `GambleScreen` — ModuleScript в `ReplicatedStorage`; `Notify` — ModuleScript в `ServerScriptService`; `AdminService` — Script; `AdminPanel`, `CoinsHud`, `CoinPopups`, `EventBanner`, `UpgradeShop`, `DailyQuestHud`, `DialogueUI`, `RadioMenu`, `EmotionMenu` — LocalScript в `StarterPlayer/StarterPlayerScripts`.

## 4. Что проверено, а что нет

Проверено на макете Roblox API (`tests/run.sh`, 437 проверок, несколько прогонов подряд): данные и сохранение (сбой загрузки, двойной выход), ставки, апгрейды и миграция двух хранилищ, события (дождь из фур, перемешивание, вьетнам, Нексбот: стены, скольжение, обход, прыжки), админ-сервис и панель (нажатия кнопок вплоть до сервера), все новые интерфейсы.

**Не проверено в самом Studio:** внешний вид интерфейсов (размеры и расположение на разных экранах), реальная физика и `PathfindingService`, поведение `Workspace:Spherecast` (используется поле `Distance`), нагрузка на сервере, реальные DataStore. Перед публикацией нужен плейтест.

Чек-лист плейтеста: вход и выход (монеты и предметы на месте), разговор с каждым NPC (мороженое, Nullbit открывает апгрейды), радио (свой трек без геймпасса не играет), эмоции (G, кнопка в HUD, смерть во время танца), дейлик (плашка после смерти, награды), ставка в автомате (одно списание, счётчик меняется), покупка апгрейда (один уровень за клик, после перезахода уровни те же), каждое событие из админ-панели (особенно Вьетнам с лесом и Нексбот у стен), кнопки админ-панели, плашка и всплывашки монет, таблица лидеров.

## 5. Настройки, которые стоит знать

- `gamble.lua`: `OUTCOMES` (шансы), `MAX_BET`, `COOLDOWN`.
- `EventManager.lua`: `TRUCK_RAIN_INTERVAL`, `HEAVY_MODEL_PARTS`, `MAX_PARTS_PER_EXPLOSION`, `MAX_ACTIVE_DEBRIS`, `DEBRIS_LIFETIME`, `NEXBOT_SPEED` (100: игроки от бота не убегут), `NEXBOT_JUMP_HEIGHT`, `NEXBOT_KILL_RADIUS`.
- `LeaderboardManager.lua`: `KICK_ON_LOAD_FAILURE`, `AUTOSAVE_INTERVAL`. `UpgradeHandler.lua`: `READ_LEGACY` (можно выключить, когда убедишься, что всё перенесено), `LEVEL_PRICES`.
- Списки админов (`ADMIN_USER_IDS`) теперь в двух серверных скриптах: `LeaderboardManager` и `AdminService`. Меняй оба одновременно.
- `CoinsHud.lua`, `CoinPopups.lua`: `FORMAT_NUMBERS`; `GambleScreen.lua`: `TEXT_COLOR` (чёрный на тёмно-бордовом читается плохо).

## 6. Не сделано (идеи на дальше)

- Бан в админ-панели (Ban API Roblox), блокировка сессий для защиты от дублирования монет (лучше `ProfileStore`).
- Админ-панель можно перевести на `UILib` (сейчас у неё свои копии функций, стиль тот же).
- `MainMenu` и сообщение Нексбота (`ScreenGui`) остались в старом виде.
- См. также «Что осталось» в разделе 0б.

## 7. Тесты

`bash tests/run.sh` (нужен Luau: https://github.com/luau-lang/luau/releases, `luau` в PATH или `LUAU=/путь/к/luau`).
Тесты на макете, а не на настоящем Roblox, поэтому они не заменяют плейтест.
