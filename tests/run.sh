#!/usr/bin/env bash
# Прогон тестов на макете Roblox API (деревья, взрывы, Нексбот, админка, интерфейсы и т. д.).
# Нужен интерпретатор Luau: https://github.com/luau-lang/luau/releases (положи `luau` в PATH
# или задай LUAU=/путь/к/luau). Запуск из любой папки: bash tests/run.sh
# Тесты используют случайность, при желании запусти несколько раз подряд.
set -e
cd "$(dirname "$0")"
LUAU=${LUAU:-luau}
S=../src
T=$(mktemp -d)
sed 's/^local RATE_PER_SECOND = 8$/local RATE_PER_SECOND = 100000/' $S/ServerScriptService/AdminService.server.lua > $T/AdminService_loose.lua
sed 's/^local FORMAT_NUMBERS = true.*$/local FORMAT_NUMBERS = false/' $S/StarterPlayer/StarterPlayerScripts/CoinsHud.client.lua > $T/CoinsHud_raw.lua
{
  cat ev_head.lua
  echo "local function loadEvents()"; cat $S/ReplicatedStorage/EventManager.lua; echo "end"
  echo "local function runController()"; cat $S/ServerScriptService/RandomEventController.server.lua; echo "end"
  echo "local function runAdminService()"; cat $T/AdminService_loose.lua; echo "end"
  echo "local function runAdminServiceStrict()"; cat $S/ServerScriptService/AdminService.server.lua; echo "end"
  echo "local function runAdminPanel()"; cat $S/StarterPlayer/StarterPlayerScripts/AdminPanel.client.lua; echo "end"
  echo "local function loadUILib()"; cat $S/ReplicatedStorage/UILib.lua; echo "end"
  echo "local function loadGambleScreen()"; cat $S/ReplicatedStorage/GambleScreen.lua; echo "end"
  echo "local function runGambleTool()"; cat $S/ReplicatedStorage/odnorykiy_bandit/LocalScript.client.lua; echo "end"
  echo "local function runCoinsHud()"; cat $S/StarterPlayer/StarterPlayerScripts/CoinsHud.client.lua; echo "end"
  echo "local function runCoinsHudRaw()"; cat $T/CoinsHud_raw.lua; echo "end"
  echo "local function runCoinPopups()"; cat $S/StarterPlayer/StarterPlayerScripts/CoinPopups.client.lua; echo "end"
  echo "local function runEventBanner()"; cat $S/StarterPlayer/StarterPlayerScripts/EventBanner.client.lua; echo "end"
  echo "local function runUpgradeShop()"; cat $S/StarterPlayer/StarterPlayerScripts/UpgradeShop.client.lua; echo "end"
  echo "local function runGambleServer()"; cat $S/ServerScriptService/gamble.server.lua; echo "end"
  echo "local RUN = {}"
  for pair in "dailyServer:ServerScriptService/everydaycount.server.lua" "dailyHud:StarterPlayer/StarterPlayerScripts/DailyQuestHud.client.lua" \
      "dialogueServer:ServerScriptService/dialogsquests.server.lua" "dialogueUI:StarterPlayer/StarterPlayerScripts/DialogueUI.client.lua" \
      "iceCreamModule:ReplicatedStorage/Dialogues/ice_cream.lua" "helloModule:ReplicatedStorage/Dialogues/hello_world.lua" \
      "radioServer:ServerScriptService/RadioHandler.server.lua" "radioMenu:StarterPlayer/StarterPlayerScripts/RadioMenu.client.lua" \
      "danceServer:ServerScriptService/DanceServer.server.lua" "emotionMenu:StarterPlayer/StarterPlayerScripts/EmotionMenu.client.lua" \
      "eatIce:ReplicatedStorage/IceCream/EatServer.server.lua" "eatMilk:ReplicatedStorage/milkynet/EatServer.server.lua" \
      "itemSave:ServerScriptService/ItemSAVE.server.lua" \
      "boxJob:ServerScriptService/BoxJob.server.lua" "boxJobHud:StarterPlayer/StarterPlayerScripts/BoxJobHud.client.lua"; do
    echo "RUN.${pair%%:*} = function()"; cat "$S/${pair#*:}"; echo; echo "end"
  done
  cat ev_tests.lua ev_tests2.lua ev_tests3.lua ev_tests4.lua ev_tests5.lua ev_tests6.lua ev_tests7.lua ev_tests8.lua ev_tests9.lua
} > $T/combined.lua
"$LUAU" $T/combined.lua > $T/out.txt 2>&1 || true
if [ -n "$KEEP" ]; then cp $T/combined.lua $T/out.txt "$KEEP"/; fi
# Ошибка выполнения (стек) тоже считается провалом: раньше она могла оборвать часть тестов незаметно
grep -nE "^(FAIL|ERROR)|stacktrace:|attempt to" $T/out.txt || true
BAD=$(grep -cE "^(FAIL|ERROR)|stacktrace:" $T/out.txt || true)
echo "PASS: $(grep -c 'PASS ' $T/out.txt)   FAIL/ERROR: $BAD"
[ "$BAD" = "0" ]
