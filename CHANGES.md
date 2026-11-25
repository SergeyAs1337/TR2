# TR2 — что изменено

Архив собран из всех правок за время работы. Папка `src/` повторяет структуру репозитория:
распакуй её поверх корня репозитория, затем перенеси те же скрипты в Studio (таблица ниже).

Содержимое: `src/` — скрипты для игры, `tools/` — одноразовый скрипт переноса (в игру НЕ класть),
`tests/` — тесты на макете Roblox API (необязательно).

## 0. Редизайн интерфейсов (v2, мультяшный стиль)

Все игровые интерфейсы теперь в одном стиле: толстая тёмная обводка, сочные градиенты,
объёмные кнопки с «тенью» (нажимаются вниз, чуть растут при наведении), pop-анимации.
Окна сами подстраиваются под экран (телефон / ПК), одновременно открыто только одно окно,
клик по затемнению вокруг окна закрывает его.

| Файл | Куда | Что |
|---|---|---|
| `ReplicatedStorage/UILib.lua` | ModuleScript, замена | Тема `THEME` (цвета, шрифт, обводка, палитра кнопок) и компоненты: `toonButton`, `window`, `toast`, `text`, `stroke`, `gradient`, `tween`, `bump`, `shake`, `fitScale`, `formatShort` («1.25M»). `UILib.open("Имя")` открывает окно из любого LocalScript. Старые функции v1 оставлены. |
| `ReplicatedStorage/GambleScreen.lua` | ModuleScript, замена | Автомат: три барабана (семёрка + 🍒🍋🔔💎⭐🍀), крутятся и останавливаются по очереди на результате с сервера. x10 — три семёрки, x2 — три одинаковых, проигрыш — разные. Быстрые ставки «½», «x2», «+1К», «ВСЁ», баланс, «Проиграно всеми». Окно после ставки не закрывается. Ставку больше баланса не отправляет. Если сервер не ответил 5 с — барабаны останавливаются. |
| `ServerScriptService/gamble.lua` | Script, замена | Отвечает клиенту результатом. **Ставить вместе с `GambleScreen`**: без ответа сервера барабаны остановятся на «Сервер не ответил». |
| `StarterPlayerScripts/CoinsHud.lua` | LocalScript, замена | Слева посередине: плашки 🪙 монет и 💀 смертей (число «докручивается» и подпрыгивает), под ними кнопка «⬆ Апгрейды». Свои кнопки меню добавляются в `MENU_BUTTONS`. |
| `StarterPlayerScripts/CoinPopups.lua` | LocalScript, замена | «+250 🪙» выпрыгивает, взлетает и тает; крупные суммы (от `BIG_GAIN`) крупнее. |
| `StarterPlayerScripts/EventBanner.lua` | LocalScript, **новый** | Баннер событий: лента с ярлыком «⚡ СОБЫТИЕ ⚡» выезжает сверху и покачивается. Объявления админа («📢 …») — синие с ярлыком «📢 ОБЪЯВЛЕНИЕ». Заменяет `StarterGui/EventUI` (удалить). |
| `StarterPlayerScripts/UpgradeShop.lua` | LocalScript, **новый** | Окно апгрейдов: 4 карточки (иконка, «Уровень N / 10», полоска из 10 делений, «было → станет», кнопка с ценой; серая, если не хватает монет; «⭐ МАКС» на максимуме). Ошибки сервера и «уровень N!» — уведомлениями. Заменяет `StarterGui/UpgradeGUI` (удалить). |

Важно:
- **Как открывалось старое окно апгрейдов?** Новое открывается кнопкой в HUD. Если в мире был
  ProximityPrompt / кнопка, которая включала `UpgradeGUI.Frame.Visible`, замени это в LocalScript на
  `require(game.ReplicatedStorage.UILib).open("Upgrades")`.
- Цены и формулы апгрейдов в `UpgradeShop.lua` скопированы из `UpgradeHandler.lua`. Поменяешь
  `LEVEL_PRICES` или формулы на сервере — поменяй и в `UpgradeShop` (списывает всё равно сервер).
- Шрифт — `GothamBlack`/`GothamBold`: у мультяшных шрифтов Roblox (FredokaOne, LuckiestGuy) нет
  кириллицы. Сменить шрифт для всей игры: `UILib.THEME.font`.
- Цвета всего интерфейса меняются в одном месте: `UILib.THEME.palette`.
- Проверено на макете (340 проверок). **В Studio не проверено:** как выглядят эмодзи
  на разных устройствах, точные размеры на маленьких телефонах. Нужен плейтест.

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
| `ReplicatedStorage/UILib.lua` | `ReplicatedStorage/UILib` (ModuleScript) | **новый** | **v2:** мультяшная тема и компоненты, см. раздел 0. |
| `ReplicatedStorage/GambleScreen.lua` | `ReplicatedStorage/GambleScreen` (ModuleScript) | **новый** | **v2:** автомат с барабанами, см. раздел 0. |
| `ReplicatedStorage/odnorykiy_bandit/LocalScript.lua` | `ReplicatedStorage/odnorykiy_bandit/LocalScript` | замена | Теперь только открывает окно (`GambleScreen`). |
| `StarterPlayer/StarterPlayerScripts/AdminPanel.lua` | `StarterPlayerScripts/AdminPanel` (LocalScript) | **новый** | Админ-панель (кнопка «🛠 Админ» или F2): вкладки События, Игроки, Сервер, Журнал. Строится кодом. |
| `StarterPlayer/StarterPlayerScripts/CoinsHud.lua` | `StarterPlayerScripts/CoinsHud` (LocalScript) | **новый** | **v2:** HUD монет и смертей с кнопкой «Апгрейды», см. раздел 0. |
| `StarterPlayer/StarterPlayerScripts/CoinPopups.lua` | `StarterPlayerScripts/CoinPopups` (LocalScript) | **новый** | **v2:** мультяшные всплывашки «+N 🪙», см. раздел 0. Первое изменение не теряется, не больше 12 одновременно. |
| `tools/SeedDeathsLeaderboard.lua` | **не в игру** | запустить один раз | Переносит смерти старых игроков в новую таблицу лидеров. Запуск из Command Bar в Studio (опубликованное место, включён доступ Studio к API). Медленно (~60–70 игроков в минуту), можно прерывать и повторять. |

## 2. Что удалить

| Что | Почему |
|---|---|
| `ServerScriptService/losssaved` | Дубль обработчика ставок, заменён `gamble`. |
| `ServerScriptService/hyperscript` | Вторая система апгрейдов, слушает то же событие `UpgradeRequest`. |
| `ServerScriptService/admin` | Заменён `AdminService`. |
| `StarterGui/GambleUI`, `StarterGui/CoinsDeaths`, `StarterGui/CoinPopupGui` | Заменены интерфейсами, построенными кодом (старые удалять после проверки новых). |
| `StarterGui/UpgradeGUI`, `StarterGui/EventUI` | Заменены `UpgradeShop` и `EventBanner` (раздел 0). Если оставить, апгрейды и баннер событий будут показаны дважды. |
| `StarterGui/AdminResetGui` | Заменён `AdminPanel`; пока работает через совместимость, удалять по желанию. |
| `ServerScriptService/CoinPopUp` и RemoteEvent `CoinPopup` | Мёртвый код: функция `giveCoins` нигде не вызывается, клиент событие не слушает. |
| Рекомендуется: `ServerScriptService/sbrocs` | Тестовый сброс `DailyDeaths` админа при каждом старте сервера. |
| Рекомендуется: `ServerScriptService/DailyQuestModule` | Никем не подключён (мёртвый дубль `everydaycount`). |

## 3. Порядок установки

1. **Данные и казино:** `LeaderboardManager`, `LeaderBoard`, `gamble`; удалить `losssaved`; опубликовать; один раз запустить `tools/SeedDeathsLeaderboard.lua`.
2. **Апгрейды:** `UpgradeHandler` и клиентский `UpgradeShop` (вместо `StarterGui/UpgradeGUI`); удалить `hyperscript`. Ставить вместе с п.1: множитель монет работает через `LeaderboardManager` v4.1.
3. **События и админка:** `EventManager`, `RandomEventController`, `EventLabel/LocalScript`; затем `AdminService` и `AdminPanel`; удалить `admin`.
4. **Интерфейсы:** `UILib` → `gamble` (v2) + `GambleScreen` + скрипт инструмента → `CoinsHud` → `CoinPopups` → `EventBanner` → `UpgradeShop`; удалить старые GUI (раздел 2).

Модули `EventManager`, `UILib`, `GambleScreen` — ModuleScript в `ReplicatedStorage`; `AdminService` — Script; `AdminPanel`, `CoinsHud`, `CoinPopups`, `EventBanner`, `UpgradeShop` — LocalScript в `StarterPlayer/StarterPlayerScripts`.

## 4. Что проверено, а что нет

Проверено на макете Roblox API (`tests/run.sh`, 340 проверок, несколько прогонов подряд): данные и сохранение (сбой загрузки, двойной выход), ставки, апгрейды и миграция двух хранилищ, события (дождь из фур, перемешивание, вьетнам, Нексбот: стены, скольжение, обход, прыжки), админ-сервис и панель (нажатия кнопок вплоть до сервера), все новые интерфейсы.

**Не проверено в самом Studio:** внешний вид интерфейсов (размеры и расположение на разных экранах), реальная физика и `PathfindingService`, поведение `Workspace:Spherecast` (используется поле `Distance`), нагрузка на сервере, реальные DataStore. Перед публикацией нужен плейтест.

Чек-лист плейтеста: вход и выход (монеты на месте), ставка в автомате (одно списание, счётчик меняется), покупка апгрейда (один уровень за клик, после перезахода уровни те же), каждое событие из админ-панели (особенно Вьетнам с лесом и Нексбот у стен), кнопки админ-панели, плашка и всплывашки монет, таблица лидеров.

## 5. Настройки, которые стоит знать

- `gamble.lua`: `OUTCOMES` (шансы), `MAX_BET`, `COOLDOWN`.
- `EventManager.lua`: `TRUCK_RAIN_INTERVAL`, `HEAVY_MODEL_PARTS`, `MAX_PARTS_PER_EXPLOSION`, `MAX_ACTIVE_DEBRIS`, `DEBRIS_LIFETIME`, `NEXBOT_SPEED` (100: игроки от бота не убегут), `NEXBOT_JUMP_HEIGHT`, `NEXBOT_KILL_RADIUS`.
- `LeaderboardManager.lua`: `KICK_ON_LOAD_FAILURE`, `AUTOSAVE_INTERVAL`. `UpgradeHandler.lua`: `READ_LEGACY` (можно выключить, когда убедишься, что всё перенесено), `LEVEL_PRICES`.
- Списки админов (`ADMIN_USER_IDS`) теперь в двух серверных скриптах: `LeaderboardManager` и `AdminService`. Меняй оба одновременно.
- `CoinsHud.lua`, `CoinPopups.lua`: `FORMAT_NUMBERS`; `GambleScreen.lua`: `TEXT_COLOR` (чёрный на тёмно-бордовом читается плохо).

## 6. Не сделано (идеи на дальше)

- Палка (`Stick`): урон 9999, нет кулдауна, не проверяется, что инструмент в руках, направление выстрела не проверяется (эксплойт).
- Базука (`Sgushenkamet`): нет проверки `Vector3`, при ошибке пропадает банка и залипает кулдаун.
- Радио: старый `Radio/RadioModel/Base/Script` дублирует обработку `PlayTrack`; нет лимита частоты для кастомных треков.
- Дейлики (`everydaycount`): при сбое загрузки считает день новым (награды можно получить заново), нет `BindToClose`.
- `achivki`: до 6 запросов `UserHasBadgeAsync` на каждую смерть, возможна двойная награда.
- Остальные DataStore-скрипты: `BindToClose` и повторы по образцу `LeaderboardManager`.
- Бан в админ-панели (Ban API Roblox), блокировка сессий для защиты от дублирования монет (лучше `ProfileStore`).
- Интерфейсы по тому же методу: `DailyQuestGui`, `DialogueGui`, `RadioUI` (нужны их скрипты; `MainMenu` лучше оставить в Studio). Админ-панель можно перевести на `UILib`.

## 7. Тесты

`bash tests/run.sh` (нужен Luau: https://github.com/luau-lang/luau/releases, `luau` в PATH или `LUAU=/путь/к/luau`).
Тесты на макете, а не на настоящем Roblox, поэтому они не заменяют плейтест.
