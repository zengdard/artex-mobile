#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Gère le PostgreSQL 16 natif installé dans $PREFIX/opt/pg16 (sans proot).
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/opt/pg16/bin:$PREFIX/bin:$PATH"
PGDATA="${ARTEX_PGDATA:-$HOME/.artex-pgdata}"
LOG="${ARTEX_PG_LOG:-$HOME/artex/logs/postgres.log}"
PORT="${ARTEX_PG_PORT:-5432}"
SOCKDIR="${TMPDIR:-$PREFIX/tmp}"

cmd="${1:-status}"
mkdir -p "$(dirname "$LOG")" "$SOCKDIR"

if [ ! -x "$PREFIX/opt/pg16/bin/initdb" ]; then
  echo "PostgreSQL 16 absent : $PREFIX/opt/pg16/bin/initdb" >&2
  echo "Lancer scripts/build-pg16.sh (compilation ~15-20 min) ou installer l'archive." >&2
  exit 1
fi

case "$cmd" in
  init)
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      mkdir -p "$(dirname "$PGDATA")"
      initdb -D "$PGDATA" -U artex --auth=trust --locale=C
    fi
    ;;
  start)
    if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
      echo "PostgreSQL déjà actif (port $PORT)"
      exit 0
    fi
    pg_ctl -D "$PGDATA" -l "$LOG" -o "-k $SOCKDIR -h 127.0.0.1 -p $PORT" start
    ;;
  stop)
    pg_ctl -D "$PGDATA" stop -m fast
    ;;
  status)
    if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
      echo "PostgreSQL actif (port $PORT, data $PGDATA)"
    else
      echo "PostgreSQL arrêté (data $PGDATA)"
      exit 1
    fi
    ;;
  *)
    echo "usage: pg-termux.sh init|start|stop|status" >&2
    exit 2
    ;;
esac
