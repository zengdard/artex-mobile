#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Arrête ARTEX et le relais ; PostgreSQL reste actif (--all pour l'arrêter aussi).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"

pkill -f "$ROOT/app/artex" 2>/dev/null || true
pkill -f "$ROOT/app/start.sh" 2>/dev/null || true
pkill -f "glm-relay.py" 2>/dev/null || true
rm -f "$ROOT/run/artex.pid" "$ROOT/run/relay.pid"
echo "ARTEX arrêté."

if [ "${1:-}" = "--all" ]; then
  "$ROOT/scripts/pg-termux.sh" stop || true
  echo "PostgreSQL arrêté."
fi
