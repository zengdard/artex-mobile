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

echo "→ paquets Termux"
pkg install -y postgresql python curl openssl-tool >/dev/null 2>&1 || true

PGDATA="$PREFIX/var/lib/postgresql"
if [ ! -f "$PGDATA/PG_VERSION" ]; then
  echo "→ initdb"
  mkdir -p "$PGDATA"
  initdb -D "$PGDATA" -U artex --auth=trust --locale=C >/dev/null
fi

if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "→ démarrage PostgreSQL"
  pg_ctl -D "$PGDATA" -l "$ROOT/logs/postgres.log" \
    -o "-k $TMPDIR -h 127.0.0.1" start >/dev/null
  sleep 3
fi

if ! psql -h 127.0.0.1 -U artex -d postgres -tAc \
      "select 1 from pg_database where datname='artex'" 2>/dev/null | grep -q 1; then
  echo "→ création de la base artex"
  createdb -h 127.0.0.1 -U artex artex
fi

chmod 755 "$ROOT/scripts/"*.sh 2>/dev/null || true
chmod 755 "$ROOT/app/artex" 2>/dev/null || true
echo "✓ PostgreSQL prêt (127.0.0.1:5432/artex)"
