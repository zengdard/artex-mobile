#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Point d'entrée unique.
#   ./install.sh              (dans Termux) installation mobile directe
#   ./install.sh termux       (PC) déploiement vers le téléphone via adb
#   ./install.sh desktop      (PC) ARTEX via Docker Compose
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d /data/data/com.termux ]; then
  exec bash "$ROOT/scripts/install-mobile.sh" "$@"
fi

case "${1:-}" in
  termux|--termux|mobile)
    exec bash "$ROOT/scripts/install-termux.sh"
    ;;
  desktop|--desktop)
    exec bash "$ROOT/scripts/install-desktop.sh"
    ;;
  *)
    cat <<'EOF'
ARTEX — installation

  Termux (sur le téléphone) :
      pkg install git && git clone https://github.com/zengdard/artex-mobile.git ~/artex
      cd ~/artex && ./install.sh

  PC → téléphone (adb) :
      ./install.sh termux

  PC (Docker Compose) :
      ./install.sh desktop

  Aide : README.md, docs/TERMUX.md
EOF
    ;;
esac
