"""New workflow commands registered alongside the compatible existing CLI."""
import json
from pathlib import Path
from .workspace import load

COMMANDS = {"session", "context", "change", "scenario", "docs", "report", "serve", "mcp", "registry", "animation"}

def register(commands):
    def sub(name, help):
        p = commands.add_parser(name, help=help); p.add_argument("--json", action="store_true"); return p
    p = sub("session", "open/read a pinned project session"); p.add_argument("operation", choices=["open", "read"]); p.add_argument("project_or_id"); p.add_argument("--profile")
    p = sub("context", "read source, symbols, inheritance and official API context"); p.add_argument("project"); p.add_argument("spec"); p.add_argument("--offset", type=int, default=0); p.add_argument("--limit", type=int, default=100); p.add_argument("--line-start", type=int, default=1); p.add_argument("--line-count", type=int, default=200)
    p = sub("change", "prepare, inspect, verify and apply immutable reviewed candidates"); p.add_argument("operation", choices=["prepare", "read", "verify", "apply"]); p.add_argument("project_or_id"); p.add_argument("--manifest"); p.add_argument("--profile"); p.add_argument("--checks", default="structure,syntax,compile"); p.add_argument("--apply", action="store_true")
    p = sub("scenario", "execute a complete GML assertion suite in a disposable test room"); p.add_argument("operation", choices=["run"]); p.add_argument("plan_id"); p.add_argument("--suite", required=True)
    p = sub("docs", "sync, query, audit and compare official manual snapshots"); p.add_argument("operation", choices=["sync", "coverage", "lookup", "search", "diff"]); p.add_argument("query", nargs="?"); p.add_argument("--channel", choices=["monthly", "lts", "beta", "project"], default="monthly"); p.add_argument("--language", default="en"); p.add_argument("--profile"); p.add_argument("--max-pages", type=int); p.add_argument("--workers", type=int, default=2); p.add_argument("--offline-zip"); p.add_argument("--offline-version"); p.add_argument("--offset", type=int, default=0); p.add_argument("--limit", type=int, default=30); p.add_argument("--from", dest="from_snapshot"); p.add_argument("--to", dest="to_snapshot")
    p = sub("report", "generate a local workbench report"); p.add_argument("session_id"); p.add_argument("--format", choices=["html"], default="html")
    p = sub("serve", "serve the authenticated loopback workbench"); p.add_argument("session_id"); p.add_argument("--port", type=int, default=0)
    p = sub("mcp", "run the optional guarded stdio MCP adapter"); p.add_argument("session_id")
    p = sub("registry", "show or export the executable recipe contract"); p.add_argument("--markdown", action="store_true")
    p = sub("animation", "author cutout rigs and export native animation projects"); p.add_argument("operation", choices=["new", "open", "migrate", "export"]); p.add_argument("path", nargs="?"); p.add_argument("--output"); p.add_argument("--format", choices=["png", "gif", "yymps"]); p.add_argument("--template-project", help="GameMaker .yyp used for YYMPS metadata and IDE-version profile"); p.add_argument("--project-tool", help="official ProjectTool executable; otherwise discovered automatically"); p.add_argument("--headless", action="store_true", help="migrate SCML without launching the browser editor"); p.add_argument("--port", type=int, default=0)

def run(tool_root, args):
    command = args.command
    if command == "session":
        from .sessions import open_session, read_session
        result = open_session(tool_root, args.project_or_id, args.profile) if args.operation == "open" else read_session(tool_root, args.project_or_id)
    elif command == "context":
        from .context import context
        result = context(tool_root, args.project, args.spec, offset=args.offset, limit=args.limit, line_start=args.line_start, line_count=args.line_count)
    elif command == "change":
        from .change_plans import prepare, read_plan, apply
        from .verification import verify
        if args.operation == "prepare":
            if not args.manifest: raise ValueError("prepare requires --manifest")
            result = prepare(tool_root, args.project_or_id, load(args.manifest), args.profile)
        elif args.operation == "read": result = read_plan(tool_root, args.project_or_id)
        elif args.operation == "verify": result = verify(tool_root, args.project_or_id, args.checks.split(","))
        else: result = apply(tool_root, args.project_or_id, apply_change=args.apply)
    elif command == "scenario":
        from .scenarios import run as run_suite
        result = run_suite(tool_root, args.plan_id, load(args.suite))
    elif command == "docs":
        from . import docs
        options = {"channel": args.channel, "language": args.language}
        if args.operation == "sync":
            if args.max_pages is not None and args.max_pages < 1: raise ValueError("max-pages must be positive")
            result = docs.sync(tool_root, **options, max_pages=args.max_pages, workers=args.workers, offline_zip=args.offline_zip, offline_version=args.offline_version)
        elif args.operation == "coverage": result = docs.coverage(tool_root, **options)
        elif args.operation == "lookup": result = docs.lookup(tool_root, args.query or "", **options, profile=load(args.profile) if args.profile else None)
        elif args.operation == "search": result = docs.search(tool_root, args.query or "", **options, offset=args.offset, limit=args.limit)
        else:
            if not args.from_snapshot or not args.to_snapshot: raise ValueError("diff requires --from and --to snapshot IDs")
            result = docs.diff(tool_root, args.from_snapshot, args.to_snapshot, **options)
    elif command == "report":
        from .reports import report
        result = report(tool_root, args.session_id)
    elif command == "serve":
        from .server import serve
        serve(tool_root, args.session_id, args.port); return 0
    elif command == "mcp":
        from .mcp_server import serve
        serve(tool_root, args.session_id); return 0
    elif command == "animation":
        from .animation_harness.cli import run
        result=run(tool_root,args)
        if result is None:return 0
    else:
        from .operation_registry import recipes, schema
        result = {"recipes": recipes(), "changeSchema": schema()}
        if args.markdown:
            print("| Recipe | Family | Status | Mutating |\n| --- | --- | --- | --- |")
            for r in result["recipes"]: print(f"| `{r['name']}` | {r['family']} | {r['status']} | {r['mutating']} |")
            return 0
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 1 if result.get("status") in {"failed", "blocked", "stale"} else 0
