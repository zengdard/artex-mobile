#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Démarre PostgreSQL (si besoin), le relais GLM et ARTEX.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export TMPDIR="$PREFIX/tmp"
export LD_LIBRARY_PATH="$PREFIX/lib"
mkdir -p "$ROOT/logs" "$ROOT/run"

# Base locale (PG16 compilé) ou distante (ARTEX_PG_HOST dans artex.env).
[ -f "$ROOT/artex.env" ] && . "$ROOT/artex.env"
if [ "${ARTEX_PG_REMOTE:-0}" != "1" ]; then
  "$ROOT/scripts/pg-termux.sh" start
fi

if ! curl -fsS -m 2 http://127.0.0.1:8790/health >/dev/null 2>&1; then
  nohup python3 "$ROOT/scripts/glm-relay.py" >"$ROOT/logs/relay.log" 2>&1 &
  echo $! >"$ROOT/run/relay.pid"
  sleep 1
fi

MODEL_CFG=$(python3 -c "import json;print(json.load(open('$HOME/.artex-glm.json')).get('model','glm-5.3-flash'))" 2>/dev/null || echo glm-5.3-flash)
export OPENAI_API_KEY="${OPENAI_API_KEY:-relay}"
export ARTEX_LLM_PROVIDER=openai
export ARTEX_LLM_BASE_URL=http://127.0.0.1:8790/v1
export ARTEX_LLM_MODEL="${ARTEX_LLM_MODEL:-$MODEL_CFG}"
export ARTEX_SKILL_DIR="$ROOT/app/skills"
export ARTEX_NOISE_PROFILE="${ARTEX_NOISE_PROFILE:-balanced}"

if curl -fsS -m 2 http://127.0.0.1:8787/ >/dev/null 2>&1; then
  echo "ARTEX déjà actif : http://127.0.0.1:8787"
  exit 0
fi

cd "$ROOT/app"
nohup ./start.sh -addr 127.0.0.1:8787 -proxy 127.0.0.1:8788 >"$ROOT/logs/artex.log" 2>&1 &
echo $! >"$ROOT/run/artex.pid"

for _ in $(seq 1 40); do
  grep -q "Setup token" "$ROOT/logs/artex.log" 2>/dev/null && break
  sleep 1
done
grep -m1 "Setup token" "$ROOT/logs/artex.log" || true
echo "UI : http://127.0.0.1:8787"
