#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Arrête ARTEX et le relais ; PostgreSQL reste actif (--all pour l'arrêter aussi).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"

pkill -f "[a]rtex -addr" 2>/dev/null || true
pkill -f "app/[a]rtex" 2>/dev/null || true
pkill -f "[s]tart.sh -addr" 2>/dev/null || true
pkill -f "[g]lm-relay.py" 2>/dev/null || true
rm -f "$ROOT/run/artex.pid" "$ROOT/run/relay.pid"
echo "ARTEX arrêté."

if [ "${1:-}" = "--all" ]; then
  [ -f "$ROOT/artex.env" ] && . "$ROOT/artex.env"
  if [ "${ARTEX_PG_REMOTE:-0}" = "1" ]; then
    echo "PostgreSQL distant : non arrêté."
  else
    "$ROOT/scripts/pg-termux.sh" stop || true
    echo "PostgreSQL arrêté."
  fi
fi
