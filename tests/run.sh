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
sed 's/^local RATE_PER_SECOND = 8$/local RATE_PER_SECOND = 100000/' $S/ServerScriptService/AdminService.lua > $T/AdminService_loose.lua
sed 's/^local FORMAT_NUMBERS = true.*$/local FORMAT_NUMBERS = false/' $S/StarterPlayer/StarterPlayerScripts/CoinsHud.lua > $T/CoinsHud_raw.lua
{
  cat ev_head.lua
  echo "local function loadEvents()"; cat $S/ReplicatedStorage/EventManager.lua; echo "end"
  echo "local function runController()"; cat $S/ServerScriptService/RandomEventController.lua; echo "end"
  echo "local function runAdminService()"; cat $T/AdminService_loose.lua; echo "end"
  echo "local function runAdminServiceStrict()"; cat $S/ServerScriptService/AdminService.lua; echo "end"
  echo "local function runAdminPanel()"; cat $S/StarterPlayer/StarterPlayerScripts/AdminPanel.lua; echo "end"
  echo "local function loadUILib()"; cat $S/ReplicatedStorage/UILib.lua; echo "end"
  echo "local function loadGambleScreen()"; cat $S/ReplicatedStorage/GambleScreen.lua; echo "end"
  echo "local function runGambleTool()"; cat $S/ReplicatedStorage/odnorykiy_bandit/LocalScript.lua; echo "end"
  echo "local function runCoinsHud()"; cat $S/StarterPlayer/StarterPlayerScripts/CoinsHud.lua; echo "end"
  echo "local function runCoinsHudRaw()"; cat $T/CoinsHud_raw.lua; echo "end"
  echo "local function runCoinPopups()"; cat $S/StarterPlayer/StarterPlayerScripts/CoinPopups.lua; echo "end"
  echo "local function runEventBanner()"; cat $S/StarterPlayer/StarterPlayerScripts/EventBanner.lua; echo "end"
  echo "local function runUpgradeShop()"; cat $S/StarterPlayer/StarterPlayerScripts/UpgradeShop.lua; echo "end"
  echo "local function runGambleServer()"; cat $S/ServerScriptService/gamble.lua; echo "end"
  cat ev_tests.lua ev_tests2.lua ev_tests3.lua ev_tests4.lua ev_tests5.lua ev_tests6.lua ev_tests7.lua
} > $T/combined.lua
"$LUAU" $T/combined.lua > $T/out.txt 2>&1 || true
grep -E "^(FAIL|ERROR)" $T/out.txt || true
echo "PASS: $(grep -c '^PASS' $T/out.txt)   FAIL/ERROR: $(grep -cE '^(FAIL|ERROR)' $T/out.txt)"
[ "$(grep -cE '^(FAIL|ERROR)' $T/out.txt)" = "0" ]
