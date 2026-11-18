# Installation manuelle dans Termux

Si `make deploy` échoue, voici les étapes équivalentes, à exécuter dans Termux.

## 1. Paquets

```bash
pkg update
pkg install -y postgresql python curl openssl-tool
```

## 2. PostgreSQL

```bash
export PREFIX=/data/data/com.termux/files/usr
export TMPDIR=$PREFIX/tmp
mkdir -p $PREFIX/var/lib/postgresql $TMPDIR

initdb -D $PREFIX/var/lib/postgresql -U artex --auth=trust --locale=C
pg_ctl -D $PREFIX/var/lib/postgresql \
  -l ~/artex/logs/postgres.log \
  -o "-k $TMPDIR -h 127.0.0.1" start

createdb -h 127.0.0.1 -U artex artex
psql -h 127.0.0.1 -U artex -d artex -c 'select version();'
```

`--auth=trust` est acceptable ici : PostgreSQL n'écoute que sur `127.0.0.1` et la base ne
contient que les données ARTEX. Ne pas exposer le port sur le Wi-Fi.

## 3. Binaire ARTEX

Sur le PC :

```bash
cd ~/artex
curl -sSLO https://github.com/BaaRai/ARTEX/releases/download/v0.6.0/artex-0.6.0-linux-arm64.zip
curl -sSLO https://github.com/BaaRai/ARTEX/releases/download/v0.6.0/SHA256SUMS
grep linux-arm64 SHA256SUMS | sha256sum -c -
unzip -o artex-0.6.0-linux-arm64.zip -d vendor/
```

Puis pousser `vendor/artex-0.6.0-linux-arm64/*` dans `~/artex/app` (le script `install-termux.sh`
le fait via `run-as` + tar, sans passer par `/sdcard`).

## 4. Configuration

`~/artex/app/config.json` :

```json
{
  "database": {
    "host": "127.0.0.1", "port": 5432,
    "user": "artex", "password": "artex",
    "dbname": "artex", "sslmode": "disable"
  },
  "skill_dir": "/data/data/com.termux/files/home/artex/app/skills"
}
```

`~/.artex-glm.json` (0600) :

```json
{
  "endpoint": "https://opencode.ai/zen/go/v1",
  "model": "glm-5.3-flash",
  "token": "st_...",
  "session": "ses_artex_local"
}
```

## 5. Démarrage

```bash
~/artex/scripts/start-termux.sh
```

Le script démarre PostgreSQL si besoin, le relais sur `:8790`, puis ARTEX sur `:8787`.
Il affiche le **setup token** au premier lancement (`grep "Setup token" ~/artex/logs/artex.log`).

Depuis le PC :

```bash
adb forward tcp:8787 tcp:8787
xdg-open http://127.0.0.1:8787
```

## 6. Arrêt / état

```bash
~/artex/scripts/status-termux.sh
~/artex/scripts/stop-termux.sh          # garde PostgreSQL
~/artex/scripts/stop-termux.sh --all    # arrête aussi PostgreSQL
```

## Dépannage

| Symptôme | Cause | Remède |
|---|---|---|
| `run-as: package not debuggable` | Termux réinstallé/signé autrement | vérifier `pm path com.termux` ; sinon pousser via `/sdcard` avec permission stockage |
| `initdb: locale not supported` | locale Android | garder `--locale=C` |
| `pg_ctl: could not start server` | socket/permissions | vérifier `~/artex/logs/postgres.log`, `TMPDIR` accessible |
| `database "artex" does not exist` | createdb non passé | `createdb -h 127.0.0.1 -U artex artex` |
| UI : connexion refusée | ARTEX pas démarré | `tail -50 ~/artex/logs/artex.log` |
| 401/403 sur les appels LLM | jeton OpenCode Go expiré | relancer `make deploy` (rafraîchit le jeton) |
| relais : `aucun jeton` | `~/.artex-glm.json` absent | `ls -l ~/.artex-glm.json`, refaire `make deploy` |
| réponses LLM lentes | téléphone en veille / RAM | `svc power stayon true`, fermer les grosses apps |
| adb ne voit plus le téléphone | changement de Wi-Fi / port TLS | `phone.sh samsung` sur le PC, ou USB + `adb tcpip 5555` |

## Changer de modèle

Éditer `~/.artex-glm.json` puis redémarrer le relais :

```bash
pkill -f glm-relay.py
~/artex/scripts/start-termux.sh
```

Ou définir `ARTEX_LLM_MODEL` avant le démarrage. Le relais réécrit `model` si le client
n'en envoie pas ; sinon le modèle demandé par ARTEX est conservé.
