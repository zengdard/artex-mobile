# ARTEX Mobile — ARTEX sur Galaxy / Termux

Déploiement **mobile dédié** d'[ARTEX](https://github.com/BaaRai/ARTEX) (pentest autonome
multi-agents) sur un Android non rooté, **dans Termux**, avec PostgreSQL local, UI sur
`127.0.0.1:8787` et un relais vers **OpenCode Go / GLM**.

Le même dépôt s'installe aussi **sur ordinateur** via Docker Compose.

| Mode | Commande | Cible |
|---|---|---|
| **Termux direct** | `./install.sh` (dans Termux) | téléphone seul, sans PC |
| **PC → téléphone** | `./install.sh termux` (PC + adb) | installe/déploie sur le Galaxy |
| **Ordinateur** | `./install.sh desktop` | Docker Compose + PostgreSQL |

- upstream : [`BaaRai/ARTEX`](https://github.com/BaaRai/ARTEX) — submodule `upstream/`
- release mobile : `0.6.0`, binaire `linux-arm64` vérifié SHA-256
- LLM par défaut : `glm-5.3-flash` via OpenCode Go

## Installation dans Termux (recommandé sur téléphone)

```bash
pkg install git
git clone https://github.com/zengdard/artex-mobile.git ~/artex
cd ~/artex
./install.sh
```

Le script demande le jeton OpenCode Go (`st_...`) ou accepte `ARTEX_GLM_TOKEN` :

```bash
ARTEX_GLM_TOKEN=st_... ./install.sh
```

Il installe PostgreSQL, initialise la base `artex`, télécharge le binaire arm64, écrit
`~/artex/app/config.json` et `~/.artex-glm.json` (`0600`), puis démarre ARTEX et affiche le
**setup token**.

> Le clone n'a pas besoin des submodules pour le mode mobile : seul le binaire arm64 est utilisé.

## Installation depuis un PC vers le téléphone

Téléphone joignable en adb (USB ou débogage sans fil) :

```bash
git clone --recurse-submodules https://github.com/zengdard/artex-mobile.git ~/artex
cd ~/artex
./install.sh termux      # ou: make deploy
```

Le script :

1. télécharge et vérifie la release arm64 dans `vendor/` ;
2. l'envoie dans `~/artex/app` sur le téléphone (`run-as` + tar, sans `/sdcard`) ;
3. installe PostgreSQL, initialise la base, écrit la config et le jeton OpenCode Go ;
4. démarre PostgreSQL, le relais et ARTEX ;
5. ouvre `adb forward tcp:8787` et affiche le setup token.

```bash
make ui        # http://127.0.0.1:8787
make status
make logs
make stop
```

## Installation sur ordinateur (Docker)

```bash
git clone --recurse-submodules https://github.com/zengdard/artex-mobile.git ~/artex
cd ~/artex
OPENAI_API_KEY=sk-... ./install.sh desktop
# ou sans clé : le script la demande
```

Le script écrit `upstream/.env` (mot de passe PostgreSQL généré, provider OpenAI-compatible),
puis lance `docker compose up -d --build`. UI : <http://localhost:8787>.

Pour utiliser OpenCode Go sur ordi, lancer le relais local et pointer ARTEX dessus :

```bash
python3 scripts/glm-relay.py &          # http://127.0.0.1:8790/v1
# dans upstream/.env :
# ARTEX_LLM_BASE_URL=http://host.docker.internal:8790/v1
# OPENAI_API_KEY=relay
```
(sur Linux, ajouter `extra_hosts: ["host.docker.internal:host-gateway"]` au service `artex`).

## Architecture sur le téléphone

```
┌──────────────────────────── Termux (u0_a231) ────────────────────────────┐
│                                                                          │
│  ARTEX (Go arm64)  :8787  ──►  PostgreSQL 18  :5432                      │
│         │                                                                │
│         └──► relais OpenAI  :8790  ──►  OpenCode Go / GLM                │
│                                                                          │
│  app/ · skills/ · data/ · keys/ (secrets AES-GCM)                        │
└──────────────────────────────────────────────────────────────────────────┘
             ▲ adb forward tcp:8787
             │
        PC / navigateur
```

Le relais ajoute l'en-tête `x-opencode-session` exigé par OpenCode Go (et relaie le SSE).
Il ne l'ajoute que si l'endpoint contient `opencode.ai`, donc il fonctionne aussi avec
OpenRouter, Ollama ou une passerelle OpenAI-compatible.

## ARTEX n'analyse pas les APK

ARTEX teste des **services réseau/web** (HTTP, bash, scanners). Pour l'audit **statique des
applications installées** (manifeste, composants exportés, secrets), utiliser
[`pentest-harness`](https://github.com/zengdard) (`pt`) sur le téléphone.

| Besoin | Outil |
|---|---|
| Manifeste, composants exportés, secrets d'un APK | `pt` (statique) |
| Tester un service HTTP / une app web / un lab | ARTEX (dynamique) |

> N'utiliser ARTEX que contre des systèmes dont tu es propriétaire ou pour lesquels tu as une
> autorisation écrite. Licence AGPL-3.0.

## Arborescence

```
artex-mobile/
├── upstream/                 # submodule BaaRai/ARTEX (source, AGPL)
├── vendor/                   # release arm64 téléchargée (ignorée par git)
├── scripts/
│   ├── install-mobile.sh     # Termux direct
│   ├── install-termux.sh     # PC → téléphone
│   ├── install-desktop.sh    # Docker Compose
│   ├── bootstrap-termux.sh   # PostgreSQL + base
│   ├── start-termux.sh
│   ├── stop-termux.sh
│   ├── status-termux.sh
│   ├── open-ui.sh
│   └── glm-relay.py
├── config/config.example.json
├── docs/TERMUX.md
├── docs/constat-2026-11-17.md
├── install.sh
└── Makefile
```

## Jeton et modèle

Jeton OpenCode Go :

```json
{"endpoint":"https://opencode.ai/zen/go/v1","model":"glm-5.3-flash",
 "token":"st_...","session":"ses_artex_mobile"}
```

fichier `~/.artex-glm.json`, mode `0600`. Il expire (≈ 30 jours) : relancer `./install.sh`
ou `make deploy` pour le rafraîchir.

Autre fournisseur (OpenRouter, Ollama, Z.ai) : modifier `endpoint`, `model`, `token` dans ce
fichier puis redémarrer :

```bash
~/artex/scripts/stop-termux.sh
~/artex/scripts/start-termux.sh
```

## Limites

- **PostgreSQL + ARTEX + UI** : ~300–500 Mo de RAM. Éviter une campagne ARTEX pendant un gros
  scan `pt`.
- Les scanners de l'image Docker (nmap, nuclei, httpx, ffuf, sqlmap…) ne sont pas dans la
  release arm64. Installer `nmap`/`curl` via `pkg` pour les outils réseau de base.
- UI liée à `127.0.0.1` : passer par `adb forward` (ou un tunnel SSH), ne pas exposer sur le Wi-Fi.
- Android peut tuer Termux en arrière-plan : `svc power stayon true` pendant un run.

## Dépannage

Voir [`docs/TERMUX.md`](docs/TERMUX.md).

## Audit des apps installées

Ce dépôt ne publie pas l'inventaire des apps du téléphone. Pour l'audit statique local,
utiliser `pentest-harness` et garder les rapports hors du dépôt.
