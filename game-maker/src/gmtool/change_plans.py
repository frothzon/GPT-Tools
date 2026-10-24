"""Content-addressed reviewed changes with isolated candidates and stale-input checks."""
from __future__ import annotations
import difflib
from pathlib import Path
import shutil
import tempfile
from .diagnostics import scan_text
from .gm_cli import source_snapshot, snapshot_diff
from .index import build_index, resolve
from .resource_api import build_expression
from .resource_tool import _copy_project, preview
from .transactions import sha256_bytes, apply_file_set
from .validation import validate
from .workspace import contained, digest, identifier, load, save, now, profile, project_lock, audit

def plan_dir(tool_root, plan_id):
    return Path(tool_root) / ".gmtool-work" / "plans" / identifier(plan_id)

def read_plan(tool_root, plan_id, *, check_candidate=True):
    directory = plan_dir(tool_root, plan_id)
    plan = load(directory / "plan.json")
    identity = {key: plan[key] for key in ("schemaVersion", "projectFile", "before", "candidate", "profile", "requiredChecks", "operations")}
    if digest(identity) != plan_id:
        raise RuntimeError("plan identity has been altered")
    if check_candidate and source_snapshot(directory / "candidate") != plan["candidate"]:
        raise RuntimeError("stored candidate bytes have been altered")
    return plan

def stale_files(plan):
    return snapshot_diff(plan["before"], source_snapshot(Path(plan["projectFile"]).parent))

def prepare(tool_root, project, manifest, profile_value=None):
    from .patches import patch_bytes
    from .operation_registry import assert_mutation_supported
    index = build_index(project)
    if set(manifest) - {"operations", "profile", "requiredChecks"}:
        raise ValueError("unknown change manifest fields")
    operations = manifest.get("operations")
    if not isinstance(operations, list) or not operations:
        raise ValueError("change needs at least one operation")
    selected = profile(index, profile_value or manifest.get("profile"))
    required = manifest.get("requiredChecks", ["structure", "syntax", "compile"])
    if not isinstance(required, list) or set(required) - {"structure", "syntax", "compile", "scenario"} or "structure" not in required or "syntax" not in required:
        raise ValueError("requiredChecks must include structure and syntax; optional compile/scenario")
    with project_lock(tool_root, index.root):
        before = source_snapshot(index.root)
        staging = Path(tool_root) / ".gmtool-work" / "staging"
        staging.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=staging) as temp:
            candidate = Path(temp) / "candidate"
            _copy_project(index, candidate)
            if source_snapshot(candidate) != before:
                raise RuntimeError("source changed while candidate was copied")
            reviewed_operations, touched = [], set()
            for op in operations:
                kind = op.get("kind")
                if kind in {"patch", "replace"}:
                    if set(op) - {"kind", "spec", "expectedHash", "edits", "unifiedDiff", "from"}:
                        raise ValueError("unknown source operation fields")
                    resource, source = resolve(build_index(candidate), op["spec"])
                    if source is None or source.kind not in {"gml", "shader-vertex", "shader-fragment", "text", "markdown"}:
                        raise ValueError("source operation requires a concrete logical source")
                    relative = source.path.relative_to(candidate).as_posix()
                    contained(candidate, relative)
                    if relative in touched:
                        raise ValueError("combine edits to one source in a single operation")
                    touched.add(relative)
                    original = source.path.read_bytes()
                    if op.get("expectedHash") != sha256_bytes(original):
                        raise RuntimeError("expectedHash is required and must match the read source")
                    replacement = patch_bytes(original, op.get("edits"), op.get("unifiedDiff")) if kind == "patch" else Path(op["from"]).read_bytes()
                    text = replacement.decode("utf-8-sig")
                    errors = scan_text(text, path=source.path, resource=resource.name) if source.kind in {"gml", "shader-vertex", "shader-fragment"} else []
                    if any(d.severity == "error" for d in errors):
                        raise ValueError("candidate has syntax hints: " + "; ".join(d.message for d in errors))
                    source.path.write_bytes(replacement)
                    reviewed_operations.append({"kind": kind, "spec": op["spec"], "expectedHash": op["expectedHash"], "afterHash": sha256_bytes(replacement)})
                elif kind == "resource":
                    if set(op) - {"kind", "operation", "options"}:
                        raise ValueError("unknown resource operation fields")
                    candidate_index = build_index(candidate)
                    assert_mutation_supported(candidate_index, op["operation"], op.get("options", {}))
                    expression = build_expression(op["operation"], op.get("options", {}))
                    result = preview(Path(tool_root), candidate_index, expression, keep_workspace=True, timeout=selected["timeout"])
                    if result.process.exit_code or result.process.timed_out or any(result.original_changes.values()):
                        raise RuntimeError("ResourceTool candidate preparation failed: " + result.process.stderr)
                    new_candidate = result.workspace / "project"
                    for category in ("created", "modified"):
                        for relative in result.clone_changes[category]:
                            target = contained(candidate, relative); target.parent.mkdir(parents=True, exist_ok=True)
                            target.write_bytes(contained(new_candidate, relative).read_bytes())
                    for relative in result.clone_changes["deleted"]:
                        contained(candidate, relative).unlink()
                    reviewed_operations.append({"kind": kind, "operation": op["operation"], "expression": expression, "changes": result.clone_changes})
                else:
                    raise ValueError("unsupported change operation")
            after = source_snapshot(candidate)
            if source_snapshot(index.root) != before:
                raise RuntimeError("working project changed during preparation")
            identity = {"schemaVersion": 1, "projectFile": str(index.project_file), "before": before, "candidate": after, "profile": selected, "requiredChecks": required, "operations": reviewed_operations}
            plan_id = digest(identity)
            directory = plan_dir(tool_root, plan_id)
            changes = snapshot_diff(before, after)
            diffs = []
            for relative in changes["created"] + changes["modified"] + changes["deleted"]:
                a = contained(index.root, relative).read_bytes() if relative in before else b""
                b = contained(candidate, relative).read_bytes() if relative in after else b""
                try:
                    diff = "".join(difflib.unified_diff(a.decode("utf-8-sig").splitlines(True), b.decode("utf-8-sig").splitlines(True), fromfile=relative, tofile=relative))
                except UnicodeDecodeError:
                    diff = f"Binary change: {relative}"
                diffs.append({"path": relative, "diff": diff})
            plan = {**identity, "planId": plan_id, "createdAt": now(), "changes": changes, "diffs": diffs,
                    "dependencyImpacts": {"basis": "full project snapshot", "dynamicReferences": "not statically proven"}}
            if not directory.exists():
                directory.mkdir(parents=True)
                shutil.copytree(candidate, directory / "candidate")
                save(directory / "plan.json", plan)
            audit(tool_root, index.project_file, "prepare", {"status": "prepared", "planId": plan_id})
            return {"status": "prepared", "dryRun": True, **read_plan(tool_root, plan_id), "originalProjectChanged": False}

def apply(tool_root, plan_id, *, apply_change=False):
    plan = read_plan(tool_root, plan_id)
    root = Path(plan["projectFile"]).parent
    with project_lock(tool_root, root):
        changes = stale_files(plan)
        if any(changes.values()):
            audit(tool_root, plan["projectFile"], "apply", {"status": "stale", "planId": plan_id})
            return {"status": "stale", "planId": plan_id, "staleFiles": changes, "dryRun": True}
        directory = plan_dir(tool_root, plan_id)
        evidence_path = directory / "verification.json"
        evidence = load(evidence_path) if evidence_path.is_file() else {}
        if evidence.get("candidateDigest") != digest(plan["candidate"]) or evidence.get("profile") != plan["profile"]:
            return {"status": "blocked", "reason": "verify this exact candidate and profile first", "dryRun": True}
        unmet = [check for check in plan["requiredChecks"] if evidence.get("checks", {}).get(check, {}).get("status") != "passed"]
        if unmet:
            return {"status": "blocked", "reason": "required checks have not passed", "checks": unmet, "dryRun": True}
        if not apply_change:
            return {"status": "ready", "planId": plan_id, "dryRun": True, "changes": plan["changes"], "diffs": plan["diffs"]}
        tx = apply_file_set(root, directory / "candidate", expected_snapshot=plan["before"], changes=plan["changes"],
            journal_root=Path(tool_root) / ".gmtool-work" / "transactions", current_snapshot=source_snapshot,
            verify=lambda: [d.message for d in validate(build_index(plan["projectFile"])) if d.severity == "error"])
        result = {"status": "applied", "planId": plan_id, "dryRun": False, "transaction": tx.as_dict(), "appliedAt": now()}
        save(directory / "application.json", result)
        audit(tool_root, plan["projectFile"], "apply", {"status": "applied", "planId": plan_id})
        return result
