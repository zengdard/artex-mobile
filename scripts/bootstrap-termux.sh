#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Prépare PostgreSQL et l'arborescence ARTEX dans Termux (idempotent).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export TMPDIR="$PREFIX/tmp"
export LD_LIBRARY_PATH="$PREFIX/lib"
mkdir -p "$ROOT/logs" "$ROOT/run" "$ROOT/app/data" "$TMPDIR"
[ -f "$ROOT/artex.env" ] && . "$ROOT/artex.env"

if [ "${ARTEX_PG_REMOTE:-0}" = "1" ]; then
  echo "→ base distante ${ARTEX_PG_HOST:-?}:${ARTEX_PG_PORT:-5432}, PostgreSQL local ignoré"
  exit 0
fi

echo "→ paquets Termux"
pkg install -y postgresql python curl openssl-tool >/dev/null 2>&1 || true

if [ ! -x "$PREFIX/opt/pg16/bin/initdb" ]; then
  echo "→ PostgreSQL 16 absent, compilation (15-20 min)"
  "$ROOT/scripts/build-pg16.sh"
fi

"$ROOT/scripts/pg-termux.sh" init
"$ROOT/scripts/pg-termux.sh" start

if ! "$PREFIX/opt/pg16/bin/psql" -h 127.0.0.1 -p 5432 -U artex -d postgres -tAc \
      "select 1 from pg_database where datname='artex'" 2>/dev/null | grep -q 1; then
  echo "→ création de la base artex"
  "$PREFIX/opt/pg16/bin/createdb" -h 127.0.0.1 -p 5432 -U artex artex
fi

chmod 755 "$ROOT/scripts/"*.sh 2>/dev/null || true
chmod 755 "$ROOT/app/artex" 2>/dev/null || true
echo "✓ PostgreSQL prêt (127.0.0.1:5432/artex)"
