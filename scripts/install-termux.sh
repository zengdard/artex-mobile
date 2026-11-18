#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Déploie ARTEX dans Termux (Galaxy) depuis le PC, avec PostgreSQL local et
# le relais OpenCode Go. Idempotent : relançable pour mettre à jour.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${ARTEX_VERSION:-0.6.0}"
SERIAL="${PT_SERIAL:-$("$ROOT/../android-bot/phone.sh" samsung 2>/dev/null || true)}"
SERIAL="${SERIAL:-192.168.1.12:5555}"
PHONE_HOME="/data/data/com.termux/files/home"
PREFIX="/data/data/com.termux/files/usr"
REMOTE_APP="files/home/artex/app"
VDIR="$ROOT/vendor/artex-$VERSION-linux-arm64"

say() { printf '%s\n' "$*"; }
die() { printf 'erreur: %s\n' "$*" >&2; exit 1; }

adb -s "$SERIAL" get-state >/dev/null 2>&1 || die "téléphone $SERIAL non joignable (adb)"
command -v curl >/dev/null || die "curl manquant"

# --- 1. binaire arm64 (release vérifiée) ---
if [ ! -x "$VDIR/artex" ]; then
  say "→ téléchargement d'ARTEX $VERSION (linux-arm64)"
  mkdir -p "$ROOT/vendor"
  cd "$ROOT/vendor"
  curl -sSL -O "https://github.com/BaaRai/ARTEX/releases/download/v$VERSION/artex-$VERSION-linux-arm64.zip"
  curl -sSL -O "https://github.com/BaaRai/ARTEX/releases/download/v$VERSION/SHA256SUMS"
  grep "artex-$VERSION-linux-arm64.zip" SHA256SUMS | sha256sum -c -
  unzip -o -q "artex-$VERSION-linux-arm64.zip"
  cd "$ROOT"
fi
[ -x "$VDIR/artex" ] || die "binaire arm64 absent: $VDIR/artex"

# --- 2. envoi du binaire + skills ---
say "→ envoi de l'application"
tar czf - -C "$VDIR" . | adb -s "$SERIAL" shell \
  "run-as com.termux $PREFIX/bin/python3 -c \"import os,sys,tarfile; d='$REMOTE_APP'; os.makedirs(d,exist_ok=True); tarfile.open(fileobj=sys.stdin.buffer,mode='r:gz').extractall(d)\""

say "→ envoi des scripts"
tar czf - -C "$ROOT" scripts config | adb -s "$SERIAL" shell \
  "run-as com.termux $PREFIX/bin/python3 -c \"import os,sys,tarfile; d='files/home/artex'; os.makedirs(d,exist_ok=True); tarfile.open(fileobj=sys.stdin.buffer,mode='r:gz').extractall(d)\""

# --- 3. config PostgreSQL ---
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/config.json" <<JSON
{
  "database": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "artex",
    "password": "artex",
    "dbname": "artex",
    "sslmode": "disable"
  },
  "skill_dir": "$PHONE_HOME/artex/app/skills"
}
JSON
adb -s "$SERIAL" shell "run-as com.termux sh -c \"mkdir -p files/home/artex/app && cat > files/home/artex/app/config.json\"" <"$TMP/config.json"

# --- 4. jeton GLM (OpenCode Go) pour le relais ---
python3 - "$TMP/glm.json" <<'PY'
import json, os, sqlite3, sys, uuid
out = sys.argv[1]
db = os.path.expanduser("~/.local/share/opencode/opencode.db")
cfg = {
    "endpoint": "https://opencode.ai/zen/go/v1",
    "model": os.environ.get("ARTEX_LLM_MODEL", "glm-5.3-flash"),
    "session": "ses_artex_" + uuid.uuid4().hex,
}
try:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    row = con.execute(
        "select value from credential where integration_id='opencode' and active=1 "
        "order by time_updated desc limit 1"
    ).fetchone()
    if row:
        v = json.loads(row[0])
        if v.get("type") == "oauth" and v.get("access"):
            cfg["token"] = v["access"]
            cfg["refresh_token"] = v.get("refresh")
            cfg["expires_at"] = v.get("expires")
except Exception as exc:
    print(f"avertissement OpenCode DB: {exc}", file=sys.stderr)
if not cfg.get("token"):
    print("aucun jeton OpenCode Go actif", file=sys.stderr)
    sys.exit(1)
with open(out, "w") as fh:
    json.dump(cfg, fh, indent=2)
os.chmod(out, 0o600)
PY
adb -s "$SERIAL" shell "run-as com.termux sh -c \"cat > files/home/.artex-glm.json && chmod 600 files/home/.artex-glm.json\"" <"$TMP/glm.json"

# --- 5. PostgreSQL + base ---
say "→ préparation PostgreSQL (peut prendre 1-2 min)"
adb -s "$SERIAL" shell "run-as com.termux $PREFIX/bin/bash $PHONE_HOME/artex/scripts/bootstrap-termux.sh" || die "bootstrap Termux en échec"

# --- 6. démarrage ---
say "→ démarrage ARTEX"
adb -s "$SERIAL" shell "run-as com.termux $PREFIX/bin/bash $PHONE_HOME/artex/scripts/start-termux.sh" | tee "$TMP/start.log"

adb -s "$SERIAL" forward tcp:8787 tcp:8787 >/dev/null
say ""
say "✓ ARTEX est prêt : http://127.0.0.1:8787"
TOKEN="$(grep -m1 'Setup token' "$TMP/start.log" | sed 's/.*Setup token[^:]*: *//' || true)"
[ -n "$TOKEN" ] && say "  Setup token : $TOKEN"
say "  Statut      : ./scripts/status-termux.sh (sur le téléphone)"
