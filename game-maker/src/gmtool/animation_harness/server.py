"""Token-authenticated loopback server for the animation editor."""
from __future__ import annotations
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import secrets
import threading
import webbrowser
from urllib.parse import parse_qs, urlparse

from .service import HarnessState

STATIC=Path(__file__).with_name("static")


def serve(tool_root: Path, project_path: Path | None = None, port: int = 0, open_browser: bool = True) -> None:
    state=HarnessState(tool_root,project_path);token=secrets.token_urlsafe(32);mutex=threading.RLock()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*_):pass
        def respond(self,status,body,content_type="application/json"):
            if isinstance(body,str):raw=body.encode("utf-8")
            elif isinstance(body,(dict,list)):raw=json.dumps(body,ensure_ascii=False).encode("utf-8")
            else:raw=body
            self.send_response(status);self.send_header("Content-Type",content_type+"; charset=utf-8")
            self.send_header("Cache-Control","no-store");self.send_header("X-Content-Type-Options","nosniff")
            self.send_header("Referrer-Policy","no-referrer");self.send_header("Content-Length",str(len(raw)))
            self.end_headers();self.wfile.write(raw)
        def host_ok(self):return self.headers.get("Host")==f"127.0.0.1:{self.server.server_port}"
        def do_GET(self):
            if not self.host_ok():return self.respond(403,{"error":"invalid host"})
            parsed=urlparse(self.path);query=parse_qs(parsed.query)
            if parsed.path=="/health":return self.respond(200,{"status":"ready"})
            if not secrets.compare_digest(query.get("token",[""])[0],token):return self.respond(403,{"error":"session token required"})
            if parsed.path in {"/","/app.js","/style.css"}:
                name={"/":"index.html","/app.js":"app.js","/style.css":"style.css"}[parsed.path]
                content=(STATIC/name).read_text(encoding="utf-8").replace("__TOKEN__",token)
                return self.respond(200,content,"text/html" if name.endswith("html") else "text/javascript" if name.endswith("js") else "text/css")
            return self.respond(404,{"error":"not found"})
        def do_POST(self):
            origin=f"http://127.0.0.1:{self.server.server_port}"
            if self.path!="/api" or not self.host_ok() or self.headers.get("Origin")!=origin or not secrets.compare_digest(self.headers.get("X-Gmtool-Token",""),token):
                return self.respond(403,{"error":"invalid host, origin, or session token"})
            try:
                length=int(self.headers.get("Content-Length","0"))
                if not 0<length<=64*1024*1024:raise ValueError("request must be between 1 byte and 64 MiB")
                payload=json.loads(self.rfile.read(length))
                if set(payload)!={"action","args"} or not isinstance(payload["args"],dict):raise ValueError("invalid action envelope")
                with mutex:result=state.action(payload["action"],payload["args"])
                self.respond(200,result)
            except Exception as exc:self.respond(400,{"error":str(exc)})
    http=ThreadingHTTPServer(("127.0.0.1",port),Handler);http.daemon_threads=True
    origin=f"http://127.0.0.1:{http.server_port}";url=f"{origin}/?token={token}"
    print(json.dumps({"status":"ready","url":url,"project":str(state.path) if state.path else None}),flush=True)
    if open_browser:webbrowser.open(url)
    try:http.serve_forever()
    except KeyboardInterrupt:pass
    finally:http.server_close()
