#!/usr/bin/env python3
"""Relais OpenAI-compatible entre ARTEX et OpenCode Go (GLM).

ARTEX parle à http://127.0.0.1:8790/v1 ; ce relais ajoute l'en-tête
`x-opencode-session` exigé par OpenCode Go et transmet le flux SSE.

Le jeton est lu dans ~/.artex-glm.json (0600) :
{"token":"st_...","session":"ses_...","endpoint":"https://opencode.ai/zen/go/v1",
 "model":"glm-5.3-flash"}
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
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


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # silence, no secrets in logs
        return

    def _upstream(self, method: str, path: str, body: bytes | None):
        base = CFG["endpoint"].rstrip("/")
        if base.endswith("/v1") and path.startswith("/v1"):
            path = path[3:]
        url = base + path
        headers = {
            "Authorization": "Bearer " + CFG.get("token", ""),
            "Content-Type": "application/json",
            "User-Agent": "artex-glm-relay/1.0",
        }
        if "opencode.ai" in url:
            headers["x-opencode-session"] = CFG.get("session", "ses_artex")
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        return urllib.request.urlopen(req, timeout=300)

    def _send_error(self, code: int, message: str) -> None:
        data = json.dumps({"error": {"message": message, "type": "relay_error"}}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.rstrip("/") in ("/v1/models", "/models"):
            try:
                with self._upstream("GET", "/models", None) as resp:
                    data = resp.read()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception:
                # liste minimale : suffit à la découverte ARTEX
                data = json.dumps({"object": "list", "data": [{"id": CFG["model"], "object": "model"}]}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            return
        if self.path.rstrip("/") in ("/health", "/v1/health"):
            data = b'{"ok":true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self._send_error(404, "not found")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""
        payload = {}
        try:
            payload = json.loads(body or b"{}")
        except json.JSONDecodeError:
            self._send_error(400, "invalid json")
            return
        if not payload.get("model"):
            payload["model"] = CFG["model"]
            body = json.dumps(payload).encode()

        stream = bool(payload.get("stream"))
        path = self.path if self.path.startswith("/") else "/" + self.path
        try:
            resp = self._upstream("POST", path, body)
        except urllib.error.HTTPError as exc:
            data = exc.read()
            self.send_response(exc.code)
            self.send_header("Content-Type", exc.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        except Exception as exc:  # noqa: BLE001
            self._send_error(502, f"upstream: {type(exc).__name__}: {exc}")
            return

        with resp:
            ctype = resp.headers.get("Content-Type", "application/json")
            if stream:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache")
                self.send_header("Connection", "keep-alive")
                self.end_headers()
                try:
                    while True:
                        chunk = resp.read(4096)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError):
                    pass
                return
            data = resp.read()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)


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
