"""Loopback-only workbench; token, Host and Origin checked on all requests."""
from __future__ import annotations
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import secrets
import threading
from urllib.parse import urlparse, parse_qs
from .reports import render
from .sessions import read_session
from .service import action

def create_server(tool_root, session_id, port=0):
    token = secrets.token_urlsafe(32)
    mutex = threading.Lock()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def send(self, status, value, content_type="application/json"):
            raw = value.encode() if isinstance(value, str) else json.dumps(value).encode()
            self.send_response(status)
            self.send_header("Content-Type", content_type + "; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers(); self.wfile.write(raw)
        def allowed_host(self):
            return self.headers.get("Host") == f"127.0.0.1:{self.server.server_port}"
        def do_GET(self):
            if not self.allowed_host(): return self.send(403, {"error": "invalid host"})
            parsed = urlparse(self.path)
            if parsed.path == "/health": return self.send(200, {"status": "ready"})
            # Require bootstrap token in query; API subsequently uses header token.
            if parsed.path != "/" or not secrets.compare_digest(parse_qs(parsed.query).get("token", [""])[0], token):
                return self.send(403, {"error": "session token required"})
            self.send(200, render(read_session(tool_root, session_id), interactive=True), "text/html")
        def do_POST(self):
            origin = f"http://127.0.0.1:{self.server.server_port}"
            if self.path != "/api" or not self.allowed_host() or self.headers.get("Origin") != origin or not secrets.compare_digest(self.headers.get("X-Gmtool-Token", ""), token):
                return self.send(403, {"error": "invalid host, origin, or session token"})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 2_000_000: raise ValueError("invalid request size")
                payload = json.loads(self.rfile.read(length))
                if set(payload) != {"action", "args"}: raise ValueError("invalid action envelope")
                with mutex: result = action(tool_root, session_id, payload["action"], payload["args"])
                self.send(200, result)
            except Exception as exc:
                self.send(400, {"error": str(exc)})
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server, token

def serve(tool_root, session_id, port=0):
    server, token = create_server(tool_root, session_id, port)
    origin = f"http://127.0.0.1:{server.server_port}"
    print(json.dumps({"status": "ready", "url": f"{origin}/?token={token}#token={token}", "sessionId": session_id}), flush=True)
    try: server.serve_forever()
    finally: server.server_close()
