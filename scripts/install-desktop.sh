#!/usr/bin/env bash
# Installation "ordi" : ARTEX via Docker Compose (upstream), PostgreSQL et UI inclus.
#   ./install.sh desktop
# Variables : OPENAI_API_KEY, ARTEX_LLM_BASE_URL, ARTEX_LLM_MODEL (ou saisie interactive).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UP="$ROOT/upstream"

say() { printf '%s\n' "$*"; }
die() { printf 'erreur: %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || die "Docker requis (ou Podman avec 'podman compose')"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 requis"

cd "$UP"
[ -f docker-compose.yml ] || die "submodule upstream absent : git submodule update --init --recursive"

if [ ! -f .env ]; then
  cp .env.example .env
  PG="$(openssl rand -hex 16)"
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$PG/" .env
  say "→ .env créé (mot de passe PostgreSQL généré)"
fi

# --- LLM ---
KEY="${OPENAI_API_KEY:-}"
BASE="${ARTEX_LLM_BASE_URL:-https://openrouter.ai/api/v1}"
MODEL="${ARTEX_LLM_MODEL:-z-ai/glm-5.3-flash}"
if [ -z "$KEY" ]; then
  if [ -t 0 ]; then
    printf 'Clé API OpenAI-compatible (OpenRouter, OpenAI, Z.ai...) : '
    read -rs KEY
    printf '\n'
  fi
fi
[ -n "$KEY" ] || die "clé LLM absente : OPENAI_API_KEY=... ./install.sh desktop"

python3 - "$UP/.env" "$KEY" "$BASE" "$MODEL" <<'PY'
import sys
path, key, base, model = sys.argv[1:5]
lines = []
with open(path) as fh:
    for line in fh:
        if line.startswith("OPENAI_API_KEY="):
            line = f"OPENAI_API_KEY={key}\n"
        elif line.startswith("ARTEX_LLM_BASE_URL="):
            line = f"ARTEX_LLM_BASE_URL={base}\n"
        elif line.startswith("ARTEX_LLM_MODEL="):
            line = f"ARTEX_LLM_MODEL={model}\n"
        elif line.startswith("ARTEX_LLM_PROVIDER="):
            line = "ARTEX_LLM_PROVIDER=openai\n"
        lines.append(line)
with open(path, "w") as fh:
    fh.writelines(lines)
PY
chmod 600 .env

say "→ build + démarrage (peut prendre plusieurs minutes)"
docker compose up -d --build

say ""
say "✓ ARTEX : http://localhost:8787"
say "  Setup token : docker compose logs artex | grep 'Setup token'"
say "  Arrêt       : (cd $UP && docker compose down)"
