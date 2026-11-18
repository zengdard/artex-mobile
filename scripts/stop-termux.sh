#!/data/data/com.termux/files/usr/bin/bash
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
  pg_ctl -D "$PREFIX/var/lib/postgresql" stop -m fast >/dev/null 2>&1 || true
  echo "PostgreSQL arrêté."
fi
