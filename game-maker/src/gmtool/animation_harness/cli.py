"""Command-line entry points for the local animation authoring harness."""
from __future__ import annotations
import json
from pathlib import Path

from . import project
from .server import serve
from .service import HarnessState


def run(tool_root: Path, args):
    if args.operation=="new":
        path=Path(args.path).expanduser().resolve() if args.path else None
        if path:
            model,assets=project.new_project(path.stem)
            path=project.save_project(path,model,assets)
        serve(tool_root,path,args.port);return None
    if args.operation=="open":
        if not args.path:raise ValueError("animation open requires a .gmanim path")
        serve(tool_root,Path(args.path).expanduser().resolve(),args.port);return None
    if args.operation=="migrate":
        if not args.path:raise ValueError("animation migrate requires an SCML source path")
        model,assets=project.read_scml(args.path)
        output=Path(args.output).expanduser().resolve() if args.output else Path(tool_root)/".gmtool-work"/"animation-projects"/(project.slug(model["name"])+".gmanim")
        saved=project.save_project(output,model,assets)
        report={"status":"migrated","path":str(saved),"entities":sum(len(c["entities"]) for c in model["collections"]),"animations":sum(len(e["animations"]) for c in model["collections"] for e in c["entities"]),"artwork":len(assets)}
        print(json.dumps(report,indent=2))
        if getattr(args,"headless",False):return report
        serve(tool_root,saved,args.port);return None
    if args.operation=="export":
        if not args.path or not args.format or not args.output:raise ValueError("animation export requires a project path, --format, and --output")
        state=HarnessState(Path(tool_root),Path(args.path));out=Path(args.output).expanduser().resolve()
        if args.format=="png":result=project.export_pngs(state.project,state.assets,out)
        elif args.format=="gif":result=project.export_gifs(state.project,state.assets,out)
        elif args.format=="yymps":
            if not args.template_project:raise ValueError("YYMPS export requires --template-project <project.yyp>")
            from .exporter import export_yymps
            result=export_yymps(state.project,state.assets,args.template_project,out,args.project_tool)
        else:raise ValueError(f"Unsupported export format: {args.format}")
        print(json.dumps({"status":"exported","format":args.format,"output":str(out),**result},indent=2));return {"status":"ok"}
    raise ValueError(f"Unknown animation operation: {args.operation}")
