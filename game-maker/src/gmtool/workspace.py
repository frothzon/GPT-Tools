"""Shared deterministic storage, path containment, profiles, and project locks."""
from __future__ import annotations
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import uuid
from .transactions import _write_atomic

def now():
    return datetime.now(timezone.utc).isoformat()

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

def save(path, value):
    _write_atomic(Path(path), json.dumps(value, indent=2, ensure_ascii=False).encode("utf-8"))

def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def contained(root, relative):
    root = Path(root).resolve()
    path = (root / relative).resolve()
    if root not in path.parents:
        raise ValueError(f"path escapes workspace: {relative}")
    return path

def identifier(value):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", value):
        raise ValueError("invalid artifact identifier")
    return value

def audit(tool_root, project_file, operation, result):
    directory = Path(tool_root) / ".gmtool-work" / "metrics" / digest(str(Path(project_file).resolve()))
    save(directory / (uuid.uuid4().hex + ".json"), {"projectFile": str(Path(project_file).resolve()), "operation": operation, "createdAt": now(), **result})

def metrics(tool_root, project_file):
    directory = Path(tool_root) / ".gmtool-work" / "metrics" / digest(str(Path(project_file).resolve()))
    records = [load(p) for p in directory.glob("*.json")] if directory.is_dir() else []
    return {"recordedOperations": len(records), "rejectedStaleChanges": sum(r.get("status") == "stale" for r in records),
            "appliedChanges": sum(r.get("operation") == "apply" and r.get("status") == "applied" for r in records),
            "compileAttempts": sum(r.get("operation") == "compile" for r in records),
            "compilePasses": sum(r.get("operation") == "compile" and r.get("status") == "passed" for r in records),
            "unexpectedProjectChanges": sum(bool(r.get("unexpectedProjectChanged")) for r in records),
            "failedScenarioRuns": sum(r.get("operation") == "scenario" and r.get("status") == "failed" for r in records),
            "averageContextSeconds": sum(r.get("durationSeconds", 0) for r in records if r.get("operation") == "context") / max(1, sum(r.get("operation") == "context" for r in records)),
            "mappingAccuracy": "measured by fixtures, not inferred from successful commands"}

def profile(index, value=None):
    supplied = load(value) if isinstance(value, (str, Path)) else (value or {})
    allowed = {"target", "runtime", "toolchain", "config", "timeout", "docsChannel", "language"}
    if set(supplied) - allowed:
        raise ValueError("unknown profile fields: " + ", ".join(set(supplied) - allowed))
    result = {"target": "windows", "runtime": "vm", "toolchain": "GMS2@" + str(index.ide_version or ""),
              "config": "Default", "timeout": 300, "docsChannel": "monthly", "language": "en", **supplied}
    if result["runtime"] not in {"vm", "native"} or not 1 <= result["timeout"] <= 3600:
        raise ValueError("invalid runtime or timeout")
    if not re.fullmatch(r"GMS2@\d+\.\d+\.\d+(?:\.\d+)?", result["toolchain"], re.I):
        raise ValueError("an explicit versioned GMS2 toolchain is required")
    return result

@contextmanager
def project_lock(tool_root, root):
    lock = Path(tool_root) / ".gmtool-work" / "locks" / (digest(str(Path(root).resolve())) + ".json")
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise RuntimeError(f"project is locked; inspect owner before removing stale lock: {lock}")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump({"pid": os.getpid(), "root": str(Path(root).resolve()), "createdAt": now()}, stream)
        yield
    finally:
        lock.unlink(missing_ok=True)
