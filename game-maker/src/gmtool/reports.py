from __future__ import annotations
import html
import json
from pathlib import Path
from .sessions import read_session
from .workspace import identifier

STYLE = '''body{font:15px system-ui;background:#101820;color:#e9eef3;margin:0}header{padding:24px 32px;background:#17242f;border-bottom:1px solid #324657}h1{font-size:25px;margin:0 0 8px}small,.muted{color:#a2b5c7}nav{display:flex;gap:8px;padding:16px 32px;position:sticky;top:0;background:#101820}button,input,select,textarea{background:#203342;color:#e9eef3;border:1px solid #526b7d;border-radius:6px;padding:9px}button{cursor:pointer}button.active{background:#256b77}main{padding:0 32px 32px}.panel{background:#17242f;border:1px solid #324657;border-radius:10px;padding:18px;margin:12px 0}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:13px ui-monospace,monospace;background:#0b131a;padding:14px;border-radius:6px}a{color:#75d4de}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:10px;border-bottom:1px solid #324657}.grid{display:grid;grid-template-columns:320px 1fr;gap:16px}.status{font-weight:700;color:#91d4a2}.error{color:#ffa4a4}textarea{width:95%;min-height:170px}section[hidden]{display:none}label{display:block;margin:8px 0}summary{cursor:pointer}'''

def render(session, *, interactive=False):
    data = json.dumps(session, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    script = (Path(__file__).with_name("dashboard.js")).read_text(encoding="utf-8")
    return f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GameMaker Workbench</title><style>{STYLE}</style>
<header><h1>GameMaker Workbench</h1><div id="identity"></div><small>Reviewed changes and explicit verification evidence</small></header>
<nav><button data-view="resources" class="active">Resources</button><button data-view="code">Code and context</button><button data-view="changes">Change review</button><button data-view="verification">Verification</button><button data-view="manual">Manual</button></nav>
<main><div id="notice" role="status"></div><section id="resources"></section><section id="code" hidden></section><section id="changes" hidden></section><section id="verification" hidden></section><section id="manual" hidden></section></main>
<script id="session-data" type="application/json">{data}</script><script>const INTERACTIVE={str(interactive).lower()};{script}</script></html>'''

def report(tool_root, session_id):
    session = read_session(tool_root, session_id)
    output = Path(tool_root) / ".gmtool-work" / "sessions" / identifier(session_id) / "report.html"
    output.write_text(render(session), encoding="utf-8")
    return {"status": "created", "path": str(output), "sessionId": session_id}
