"""Separate structural, scanner, compiler, scenario and visual evidence."""
from __future__ import annotations
from pathlib import Path
import re
import shutil
import tempfile
from .change_plans import read_plan, plan_dir, stale_files
from .compiler import parse_compiler_output
from .diagnostics import diagnose
from .gm_cli import invoke, source_snapshot, snapshot_diff
from .index import build_index
from .validation import validate
from .workspace import digest, now, save, load, audit

def build_arguments(project_file, selected, cache, command="compile"):
    return [command, str(project_file), f"--target={selected['target']}", f"--runtime={selected['runtime']}",
            f"--toolchain={selected['toolchain']}", f"--config={selected['config']}", f"--cache-dir={cache}", "--verbose"]

def compiler_check(tool_root, project_file, selected):
    index = build_index(project_file)
    before = source_snapshot(index.root)
    process = invoke(Path(tool_root), build_arguments(index.project_file, selected, Path(tool_root) / ".gm-cli-cache"), cwd=index.root, timeout=selected["timeout"])
    changes = snapshot_diff(before, source_snapshot(index.root))
    output = process.stdout + "\n" + process.stderr
    diagnostics = parse_compiler_output(output, index)
    versions = sorted(set(re.findall(r"(?:runtime-|Runtime Version\s*[:=]?\s*)(\d+\.\d+\.\d+(?:\.\d+)?)", output, re.I)))
    passed = process.exit_code == 0 and not process.timed_out and not any(changes.values()) and not any(d.severity == "error" for d in diagnostics)
    return {"status": "passed" if passed else "failed", "verificationLevel": "build-check", "profile": selected,
            "process": process.as_dict(), "diagnostics": [d.as_dict(index.root) for d in diagnostics], "projectChanges": changes,
            "resolvedRuntimeVersions": versions, "versionEvidence": "compiler log" if versions else "not reported by backend", "completedAt": now()}

def verify(tool_root, plan_id, checks=("structure", "syntax", "compile")):
    checks = list(checks)
    if set(checks) - {"structure", "syntax", "compile"}:
        raise ValueError("verify supports structure, syntax, compile; use scenario run for gameplay")
    plan = read_plan(tool_root, plan_id)
    stale = stale_files(plan)
    if any(stale.values()):
        return {"status": "stale", "staleFiles": stale}
    directory = plan_dir(tool_root, plan_id)
    evidence_file = directory / "verification.json"
    evidence = load(evidence_file) if evidence_file.is_file() else {"planId": plan_id, "candidateDigest": digest(plan["candidate"]), "profile": plan["profile"], "checks": {}}
    candidate_index = build_index(directory / "candidate" / Path(plan["projectFile"]).name)
    if "structure" in checks:
        items = validate(candidate_index)
        evidence["checks"]["structure"] = {"status": "failed" if any(d.severity == "error" for d in items) else "passed", "diagnostics": [d.as_dict(candidate_index.root) for d in items]}
    if "syntax" in checks:
        items = diagnose(candidate_index)
        evidence["checks"]["syntax"] = {"status": "failed" if any(d.severity == "error" for d in items) else "passed", "verificationLevel": "syntax-hints", "diagnostics": [d.as_dict(candidate_index.root) for d in items]}
        from .symbols import project_symbols
        from .docs import check_calls, coverage
        records = project_symbols(candidate_index, Path(tool_root))
        evidence["documentation"] = {"coverage": coverage(Path(tool_root), plan["profile"]["docsChannel"]),
             "hints": [{"path": r["path"], **d} for r in records for d in check_calls(Path(tool_root), r["calls"], plan["profile"]["docsChannel"])],
             "compatibility": "exact-runtime support not inferred from manual channel"}
    if "compile" in checks:
        staging = Path(tool_root) / ".gmtool-work" / "verification"
        staging.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=staging) as temp:
            base = Path(temp) / "baseline"; candidate = Path(temp) / "candidate"
            from .resource_tool import _copy_project
            _copy_project(build_index(plan["projectFile"]), base)
            shutil.copytree(directory / "candidate", candidate)
            evidence["baselineCompile"] = compiler_check(tool_root, base / Path(plan["projectFile"]).name, plan["profile"])
            try:
                evidence["checks"]["compile"] = compiler_check(tool_root, candidate / Path(plan["projectFile"]).name, plan["profile"])
            except RuntimeError as exc:
                evidence["checks"]["compile"] = {"status": "blocked", "reason": str(exc)}
    for name in ("structure", "syntax", "compile", "scenario", "visual"):
        evidence["checks"].setdefault(name, {"status": "skipped"})
    stale = stale_files(plan)
    evidence["status"] = "stale" if any(stale.values()) else "passed" if all(evidence["checks"][c]["status"] == "passed" for c in checks) else "failed"
    evidence["staleFiles"] = stale
    evidence["completedAt"] = now()
    if "compile" in checks:
        compile_record = evidence["checks"]["compile"]
        audit(tool_root, plan["projectFile"], "compile", {"status": compile_record["status"], "durationSeconds": compile_record.get("process", {}).get("durationSeconds"), "unexpectedProjectChanged": any(compile_record.get("projectChanges", {}).values())})
    save(evidence_file, evidence)
    return evidence
