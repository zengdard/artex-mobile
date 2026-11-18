#!/data/data/com.termux/files/usr/bin/bash
# Installation directe d'ARTEX dans Termux (sans PC).
#   git clone <repo> ~/artex && cd ~/artex && ./install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export TMPDIR="$PREFIX/tmp"
export LD_LIBRARY_PATH="$PREFIX/lib"
VERSION="${ARTEX_VERSION:-0.6.0}"
SHA256="${ARTEX_SHA256:-48778ec3de4e742c117cef57dce5e4067fb2649eeddd49f025d002765f3d1401}"
PREFIX_HOME="$HOME"

say() { printf '%s\n' "$*"; }
die() { printf 'erreur: %s\n' "$*" >&2; exit 1; }

[ -d /data/data/com.termux ] || die "ce script doit tourner dans Termux"
mkdir -p "$ROOT/app" "$ROOT/logs" "$ROOT/run" "$TMPDIR"

say "→ paquets Termux"
pkg install -y postgresql python curl openssl-tool unzip >/dev/null 2>&1 || true

# --- binaire arm64 ---
if [ ! -x "$ROOT/app/artex" ]; then
  say "→ téléchargement d'ARTEX $VERSION (linux-arm64)"
  ZIP="$TMPDIR/artex-$VERSION.zip"
  curl -fsSL -o "$ZIP" \
    "https://github.com/BaaRai/ARTEX/releases/download/v$VERSION/artex-$VERSION-linux-arm64.zip"
  if command -v sha256sum >/dev/null; then
    echo "$SHA256  $ZIP" | sha256sum -c - >/dev/null
  else
    got=$(openssl dgst -sha256 "$ZIP" | sed 's/.*= //')
    [ "$got" = "$SHA256" ] || die "SHA-256 invalide"
  fi
  rm -rf "$TMPDIR/artex-extract"
  unzip -oq "$ZIP" -d "$TMPDIR/artex-extract"
  cp -a "$TMPDIR/artex-extract/artex-$VERSION-linux-arm64/." "$ROOT/app/"
  chmod 755 "$ROOT/app/artex"
fi

# --- jeton GLM ---
ENDPOINT="${ARTEX_GLM_ENDPOINT:-https://opencode.ai/zen/go/v1}"
MODEL="${ARTEX_LLM_MODEL:-glm-5.3-flash}"
TOKEN="${ARTEX_GLM_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$HOME/.artex-glm.json" ]; then
  TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/.artex-glm.json')).get('token',''))" 2>/dev/null || true)
fi
if [ -z "$TOKEN" ]; then
  if [ -t 0 ]; then
    printf 'Jeton OpenCode Go (st_...) ou clé API du fournisseur : '
    read -rs TOKEN
    printf '\n'
  fi
fi
[ -n "$TOKEN" ] || die "jeton absent : relancer avec ARTEX_GLM_TOKEN=... ./install.sh"

python3 - "$HOME/.artex-glm.json" "$ENDPOINT" "$MODEL" "$TOKEN" <<'PY'
import json, os, sys
path, endpoint, model, token = sys.argv[1:5]
cfg = {"endpoint": endpoint, "model": model, "token": token, "session": "ses_artex_mobile"}
os.makedirs(os.path.dirname(path), exist_ok=True)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as fh:
    json.dump(cfg, fh, indent=2)
PY

cat >"$ROOT/app/config.json" <<JSON
{
  "database": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "artex",
    "password": "artex",
    "dbname": "artex",
    "sslmode": "disable"
  },
  "skill_dir": "$PREFIX_HOME/artex/app/skills"
}
JSON

# --- PostgreSQL + base ---
"$ROOT/scripts/bootstrap-termux.sh"

# --- démarrage ---
say "→ démarrage"
"$ROOT/scripts/start-termux.sh" | tee "$ROOT/logs/last-start.log"

say ""
say "ARTEX tourne sur le téléphone : http://127.0.0.1:8787"
grep -m1 'Setup token' "$ROOT/logs/last-start.log" || say "Setup token : voir ~/artex/logs/artex.log"
say "Statut : $ROOT/scripts/status-termux.sh"
