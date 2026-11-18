#!/usr/bin/env bash
# Ouvre l'UI ARTEX du téléphone depuis le PC (adb forward).
set -euo pipefail

SERIAL="${PT_SERIAL:-$("$(dirname "$0")/../../android-bot/phone.sh" samsung 2>/dev/null || true)}"
SERIAL="${SERIAL:-192.168.1.12:5555}"

adb -s "$SERIAL" forward tcp:8787 tcp:8787
echo "UI  : http://127.0.0.1:8787"
echo "API : http://127.0.0.1:8787/api"
command -v xdg-open >/dev/null && xdg-open http://127.0.0.1:8787 >/dev/null 2>&1 || true
