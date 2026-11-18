#!/data/data/com.termux/files/usr/bin/python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Relais OpenAI-compatible entre ARTEX et OpenCode Go (GLM).

ARTEX parle à http://127.0.0.1:8790/v1 ; ce relais ajoute l'en-tête
`x-opencode-session` exigé par OpenCode Go et transmet le flux SSE.
Il utilise `curl` (fiable sous Termux) plutôt qu'urllib.

Jeton : ~/.artex-glm.json (0600).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONFIG = os.path.expanduser("~/.artex-glm.json")
DEFAULT_ENDPOINT = "https://opencode.ai/zen/go/v1"


def load() -> dict:
    cfg = {}
    try:
        with open(CONFIG, encoding="utf-8") as fh:
            cfg = json.load(fh)
    except (OSError, json.JSONDecodeError):
        pass
    cfg.setdefault("endpoint", DEFAULT_ENDPOINT)
    cfg.setdefault("model", "glm-5.3-flash")
    cfg.setdefault("session", "ses_artex")
    if os.environ.get("ARTEX_GLM_TOKEN"):
        cfg["token"] = os.environ["ARTEX_GLM_TOKEN"]
    return cfg


CFG = load()
CURL = "/data/data/com.termux/files/usr/bin/curl"


def upstream_url(path: str) -> str:
    base = CFG["endpoint"].rstrip("/")
    if base.endswith("/v1") and path.startswith("/v1"):
        path = path[3:]
    return base + path


def curl_headers() -> list[str]:
    args = [
        "-H", "Authorization: Bearer " + CFG.get("token", ""),
        "-H", "Content-Type: application/json",
    ]
    if "opencode.ai" in CFG["endpoint"]:
        args += ["-H", "x-opencode-session: " + CFG.get("session", "ses_artex")]
    return args


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        return

    def _send(self, code: int, body: bytes, ctype: str = "application/json") -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") in ("/health", "/v1/health"):
            self._send(200, b'{"ok":true}')
            return
        if self.path.rstrip("/") in ("/v1/models", "/models"):
            proc = subprocess.run(
                [CURL, "-sS", "-m", "30", upstream_url("/v1/models")] + curl_headers(),
                capture_output=True, timeout=40,
            )
            if proc.returncode == 0 and proc.stdout:
                self._send(200, proc.stdout)
            else:
                body = json.dumps({"object": "list", "data": [{"id": CFG["model"], "object": "model"}]}).encode()
                self._send(200, body)
            return
        self._send(404, b'{"error":{"message":"not found"}}')

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(body or b"{}")
        except json.JSONDecodeError:
            self._send(400, b'{"error":{"message":"invalid json"}}')
            return
        if not payload.get("model"):
            payload["model"] = CFG["model"]
            body = json.dumps(payload).encode()
        stream = bool(payload.get("stream"))
        path = self.path if self.path.startswith("/") else "/" + self.path
        url = upstream_url(path)

        cmd = [CURL, "-sS", "-N", "-m", "300", "-X", "POST", url] + curl_headers()
        cmd += ["--data-binary", "@-"]
        try:
            proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                    stderr=subprocess.DEVNULL)
        except OSError as exc:
            self._send(502, json.dumps({"error": {"message": str(exc)}}).encode())
            return
        try:
            proc.stdin.write(body)
            proc.stdin.close()
        except (BrokenPipeError, OSError):
            pass

        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()
            try:
                while True:
                    chunk = proc.stdout.read(4096)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                proc.kill()
            return

        out = proc.stdout.read()
        proc.wait(timeout=10)
        if not out:
            self._send(502, b'{"error":{"message":"empty upstream response"}}')
            return
        self._send(200, out)


def main() -> int:
    port = int(os.environ.get("ARTEX_RELAY_PORT", "8790"))
    if not CFG.get("token"):
        print("relais: aucun jeton dans ~/.artex-glm.json", file=sys.stderr)
        return 2
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"relais GLM prêt sur http://127.0.0.1:{port}/v1 (modèle {CFG['model']})", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
