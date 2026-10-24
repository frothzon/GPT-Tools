"""One bounded action dispatcher shared by HTTP and stdio MCP."""
from pathlib import Path
from .workspace import load
from .sessions import read_session

ACTION_SCHEMAS = {
    "session": {}, "context": {"spec": "string", "offset": "integer", "limit": "integer", "lineStart": "integer"},
    "prepare_change": {"manifest": "object"}, "verify_change": {"planId": "string", "checks": "array"},
    "apply_change": {"planId": "string", "apply": "boolean"}, "run_scenarios": {"planId": "string", "suite": "object"},
    "report": {}, "recover_status": {}, "recover_rollback": {"transactionId": "string", "apply": "boolean"},
    "docs_lookup": {"identifier": "string", "channel": "string"}, "docs_search": {"query": "string", "channel": "string", "offset": "integer"},
    "docs_coverage": {"channel": "string"},
}

def action(tool_root, session_id, name, args):
    if name not in ACTION_SCHEMAS or not isinstance(args, dict) or set(args) - set(ACTION_SCHEMAS[name]):
        raise ValueError("unknown action or arguments")
    for k, v in args.items():
        kind = ACTION_SCHEMAS[name][k]
        allowed = {"string": str, "integer": int, "boolean": bool, "object": dict, "array": list}[kind]
        if not isinstance(v, allowed) or (kind == "integer" and isinstance(v, bool)): raise ValueError("invalid argument type: " + k)
    session = read_session(tool_root, session_id)
    project = session["project"]["projectFile"]
    if "planId" in args:
        from .change_plans import read_plan
        if read_plan(tool_root, args["planId"])["projectFile"] != project:
            raise ValueError("plan belongs to another project")
    if name == "session": return session
    if name == "context":
        from .context import context
        return context(tool_root, project, args["spec"], offset=args.get("offset", 0), limit=args.get("limit", 100), line_start=args.get("lineStart", 1), docs_channel=session["profile"]["docsChannel"])
    if name == "prepare_change":
        from .change_plans import prepare
        return prepare(tool_root, project, args["manifest"], session["profile"])
    if name == "verify_change":
        from .verification import verify
        return verify(tool_root, args["planId"], args.get("checks", ["structure", "syntax", "compile"]))
    if name == "apply_change":
        from .change_plans import apply
        return apply(tool_root, args["planId"], apply_change=args.get("apply", False))
    if name == "run_scenarios":
        from .scenarios import run
        return run(tool_root, args["planId"], args["suite"])
    if name == "report":
        from .reports import report
        return report(tool_root, session_id)
    if name.startswith("recover"):
        from .recovery import status, rollback
        if name == "recover_status": return [r for r in status(Path(tool_root)) if r.get("root") == session["project"]["root"] or str(r.get("target", "")).startswith(session["project"]["root"] + str(Path('/')))]
        if not args.get("apply"): return {"status": "dry-run", "transactionId": args["transactionId"]}
        return rollback(Path(tool_root), args["transactionId"], Path(project).parent)
    from . import docs
    channel = args.get("channel", session["profile"]["docsChannel"])
    if name == "docs_lookup": return docs.lookup(tool_root, args["identifier"], channel=channel, profile=session["profile"])
    if name == "docs_search": return docs.search(tool_root, args["query"], channel=channel, offset=args.get("offset", 0))
    if name == "docs_coverage": return docs.coverage(tool_root, channel)
    raise ValueError("unimplemented action")
