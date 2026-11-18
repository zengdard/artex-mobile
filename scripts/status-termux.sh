#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# État de PostgreSQL, du relais GLM et d'ARTEX.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"

[ -f "$ROOT/artex.env" ] && . "$ROOT/artex.env"
if [ "${ARTEX_PG_REMOTE:-0}" = "1" ]; then
  echo -n "PostgreSQL distant (${ARTEX_PG_HOST:-?}:${ARTEX_PG_PORT:-5432}) : "
  PGPASSWORD="${ARTEX_PG_PASSWORD:-artex}" psql -h "${ARTEX_PG_HOST:-127.0.0.1}"     -p "${ARTEX_PG_PORT:-5432}" -U "${ARTEX_PG_USER:-artex}" -d "${ARTEX_PG_DB:-artex}"     -tAc "select 1" >/dev/null 2>&1 && echo "OK" || echo "inaccessible"
else
  echo -n "PostgreSQL : "
  "$ROOT/scripts/pg-termux.sh" status 2>/dev/null || true
fi
echo -n "Base artex : "
psql -h 127.0.0.1 -U artex -d artex -tAc "select count(*) from information_schema.tables where table_schema='public'" 2>/dev/null \
  | sed 's/^/tables=/;s/$//' || echo "inaccessible"
echo -n "Relais GLM : "
curl -fsS -m 2 http://127.0.0.1:8790/health 2>/dev/null && echo " actif" || echo "arrêté"
echo -n "ARTEX      : "
code=$(curl -s -o /dev/null -m 2 -w '%{http_code}' http://127.0.0.1:8787/ 2>/dev/null || true)
echo "HTTP ${code:-000}"

echo "— dernières lignes —"
tail -n 3 "$ROOT/logs/artex.log" 2>/dev/null || true
