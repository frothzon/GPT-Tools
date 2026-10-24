"""Optional newline-delimited stdio MCP adapter over the guarded core."""
from __future__ import annotations
import json
import sys
from .service import ACTION_SCHEMAS, action

def tools_list():
    required = {"context": ["spec"], "prepare_change": ["manifest"], "verify_change": ["planId"], "apply_change": ["planId"], "run_scenarios": ["planId", "suite"], "docs_lookup": ["identifier"], "docs_search": ["query"], "recover_rollback": ["transactionId"]}
    return [{"name": name, "description": "Guarded gmtool " + name + "; writes default to preview and require apply=true.",
             "inputSchema": {"type": "object", "properties": {k: {"type": v} for k, v in fields.items()}, "required": required.get(name, []), "additionalProperties": False}}
            for name, fields in ACTION_SCHEMAS.items()]

def handle(tool_root, session_id, request):
    method = request.get("method"); params = request.get("params", {})
    if method == "initialize":
        versions = {"2024-11-05", "2025-03-26", "2025-06-18"}
        version = params.get("protocolVersion", "2024-11-05")
        return {"protocolVersion": version if version in versions else "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "gmtool", "version": "0.2.0"}}
    if method == "ping": return {}
    if method == "tools/list": return {"tools": tools_list()}
    if method == "tools/call":
        try:
            result = action(tool_root, session_id, params["name"], params.get("arguments", {}))
            return {"content": [{"type": "text", "text": json.dumps(result)}], "isError": False}
        except Exception as exc:
            return {"content": [{"type": "text", "text": str(exc)}], "isError": True}
    raise ValueError("unsupported MCP method")

def serve(tool_root, session_id):
    for line in sys.stdin:
        request = None
        try:
            if len(line) > 2_000_000: raise ValueError("MCP message too large")
            request = json.loads(line)
            if "id" not in request: continue
            result = handle(tool_root, session_id, request)
            response = {"jsonrpc": "2.0", "id": request["id"], "result": result}
        except Exception as exc:
            response = {"jsonrpc": "2.0", "id": request.get("id") if isinstance(request, dict) else None,
                        "error": {"code": -32602, "message": str(exc)}}
        print(json.dumps(response), flush=True)
