from __future__ import annotations
from pathlib import Path
import uuid
from .index import build_index
from .gm_cli import source_snapshot, snapshot_diff
from .validation import validate
from .workspace import profile, save, load, identifier, now, digest

def open_session(tool_root, project, profile_value=None):
    from .environment import doctor
    from .capabilities import manifest
    index = build_index(project)
    selected = profile(index, profile_value)
    sid = uuid.uuid4().hex
    result = {"sessionId": sid, "createdAt": now(), "project": index.summary(), "profile": selected,
              "snapshot": source_snapshot(index.root), "resources": [r.as_dict(index.root) for r in index.resources],
              "diagnostics": [d.as_dict(index.root) for d in validate(index)], "environment": doctor(Path(tool_root)),
              "capabilities": manifest(project=index.summary()), "plans": [], "metrics": {"verificationLevels": "explicit"}}
    save(Path(tool_root) / ".gmtool-work" / "sessions" / sid / "session.json", result)
    return result

def read_session(tool_root, sid):
    session = load(Path(tool_root) / ".gmtool-work" / "sessions" / identifier(sid) / "session.json")
    session["projectChanges"] = snapshot_diff(session["snapshot"], source_snapshot(Path(session["project"]["root"])))
    from .workspace import metrics
    session["metrics"] = metrics(tool_root, session["project"]["projectFile"])
    plans = Path(tool_root) / ".gmtool-work" / "plans"
    session["plans"] = []
    if plans.is_dir():
        from .change_plans import read_plan, stale_files
        for directory in sorted(plans.iterdir()):
            try:
                plan = read_plan(tool_root, directory.name)
                if plan["projectFile"] != session["project"]["projectFile"]: continue
                evidence = directory / "verification.json"
                session["plans"].append({"planId": directory.name, "changes": plan["changes"], "diffs": plan["diffs"],
                                         "staleFiles": stale_files(plan), "verification": load(evidence) if evidence.is_file() else None})
            except (ValueError, RuntimeError, FileNotFoundError):
                continue
    return session
