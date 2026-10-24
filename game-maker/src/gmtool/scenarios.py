"""Disposable GML assertion suites with authenticated complete runtime records."""
from __future__ import annotations
import json
from pathlib import Path
import re
import shutil
import uuid
from .change_plans import read_plan, plan_dir, stale_files
from .gm_cli import invoke, source_snapshot
from .index import build_index
from .resource_api import build_expression
from .resource_tool import preview
from .verification import build_arguments
from .workspace import digest, load, save, now, contained, audit

PREFIX = "GMTOOL_SCENARIO:"

def collect(output, run_id, candidate_digest, expected, *, exit_code=0, timed_out=False):
    records = []; problems = []
    for line in output.splitlines():
        if PREFIX not in line: continue
        try:
            payload = json.loads(line.split(PREFIX, 1)[1].strip())
            if payload.get("runId") != run_id or payload.get("candidateDigest") != candidate_digest:
                problems.append("record identity mismatch"); continue
            records.append(payload)
        except (json.JSONDecodeError, AttributeError):
            problems.append("malformed scenario record")
    assertions = [r for r in records if r.get("type") == "assertion"]
    completions = [r for r in records if r.get("type") == "complete"]
    names = [r.get("test") for r in assertions]
    if not expected or not assertions: problems.append("suite must execute at least one assertion")
    if set(names) != set(expected) or len(names) != len(expected): problems.append("assertion inventory missing, duplicate, or unexpected")
    if any(r.get("passed") is not True for r in assertions): problems.append("assertion failed")
    if len(completions) != 1 or not records or records[-1].get("type") != "complete": problems.append("missing or misplaced final completion record")
    elif completions[0].get("count") != len(expected): problems.append("completion count mismatch")
    if exit_code != 0: problems.append("runtime process failed")
    if timed_out: problems.append("runtime timed out")
    return {"status": "failed" if problems else "passed", "verificationLevel": "gameplay-assertions", "records": records, "problems": problems, "assertionCount": len(assertions)}

def generate(suite, run_id, candidate_digest, artifact_root):
    if set(suite) - {"name", "seed", "setup", "teardown", "tests", "maxFrames", "checkpoints", "bootstrap"}:
        raise ValueError("unknown scenario suite fields")
    tests = suite.get("tests", [])
    if not tests or len({t.get("name") for t in tests}) != len(tests): raise ValueError("suite requires distinct tests")
    def literal(value): return json.dumps(value, ensure_ascii=True)
    header = f'''random_set_seed({int(suite.get("seed", 1))});
global.gmtool_test_root = {literal(str(artifact_root).replace(chr(92), '/'))};
global.gmtool_test_run = {literal(run_id)};
global.gmtool_test_digest = {literal(candidate_digest)};
function gmtool_emit(_record) {{
    _record.runId = global.gmtool_test_run;
    _record.candidateDigest = global.gmtool_test_digest;
    show_debug_message({literal(PREFIX)} + json_stringify(_record));
}}
function gmtool_assert(_name, _passed) {{
    gmtool_emit({{type: "assertion", test: _name, passed: _passed}});
}}
gmtool_emit({{type: "environment", saveId: game_save_id}});
if (string_pos(global.gmtool_test_run, game_save_id) == 0) {{
    show_debug_message("gmtool: isolated save namespace was not established");
    game_end();
    exit;
}}
'''
    bodies = [suite.get("setup", "")]
    for test in tests:
        if set(test) - {"name", "code", "assert", "frame"} or not isinstance(test.get("assert"), str) or not test["assert"].strip():
            raise ValueError("each test requires name and nonempty assertion expression")
        frame = int(test.get("frame", 1))
        if frame < 1 or frame > int(suite.get("maxFrames", 120)):
            raise ValueError("test frame exceeds frame budget")
        bodies.append(f'if (global.gmtool_test_frame == {frame}) {{\n' + test.get("code", "") + f'\ngmtool_assert({literal(test["name"])}, ({test["assert"]}));\n}}')
    bodies.append(suite.get("teardown", ""))
    bodies.append(f'gmtool_emit({{type: "complete", count: {len(tests)}}});')
    bodies.append("game_end();")
    setup = bodies.pop(0)
    completion = "\n".join(bodies[-3:]); bodies = bodies[:-3]
    final_frame = max(int(t.get("frame", 1)) for t in tests)
    checkpoints = suite.get("checkpoints", [])
    if checkpoints:
        final_frame = max(final_frame, max(int(c["frame"]) + 1 for c in checkpoints))
    if final_frame > int(suite.get("maxFrames", 120)): raise ValueError("checkpoints exceed frame budget")
    return header + setup + f'''\nglobal.gmtool_test_frame = 0;
function gmtool_test_tick() {{
    global.gmtool_test_frame += 1;
''' + "\n".join(bodies) + f'''\nif (global.gmtool_test_frame == {final_frame}) {{
{completion}
}}
}}
'''

def _official_recipe(tool_root, project_file, operation, options):
    result = preview(Path(tool_root), build_index(project_file), build_expression(operation, options), keep_workspace=True)
    if result.process.exit_code or result.process.timed_out or any(result.original_changes.values()):
        raise RuntimeError("scenario resource injection failed: " + result.process.stdout[-2000:] + result.process.stderr[-1000:])
    candidate = result.workspace / "project"; root = project_file.parent
    for category in ("created", "modified"):
        for relative in result.clone_changes[category]:
            target = contained(root, relative); target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contained(candidate, relative).read_bytes())
    for relative in result.clone_changes["deleted"]: contained(root, relative).unlink()

def replace_top_level(path, field, value):
    """Lossless isolated-clone property edit when no official recipe exists."""
    from .lossless_json import load as load_document
    document = load_document(path); tokens = [t for t in document.tokens if t.kind != "trivia"]
    depth = 0; ranges = []
    for i, token in enumerate(tokens):
        if token.kind in {"{", "["}: depth += 1
        elif token.kind in {"}", "]"}: depth -= 1
        if depth == 1 and token.kind == "string" and token.value == field and i+2 < len(tokens) and tokens[i+1].kind == ":":
            start = tokens[i+2].start; j = i+2; level = 0
            while j < len(tokens):
                t = tokens[j]
                if t.kind in {"{", "["}: level += 1
                if t.kind in {"}", "]"}: level -= 1
                if level == 0: break
                j += 1
            ranges.append((start, tokens[j].end))
    if len(ranges) != 1: raise ValueError("clone property is missing or ambiguous: " + field)
    start, end = ranges[0]
    document.text = document.text[:start] + json.dumps(value) + document.text[end:]
    path.write_bytes(document.to_bytes())

def run(tool_root, plan_id, suite):
    """Record blocked setup failures as evidence rather than losing the run."""
    try:
        return _run(tool_root, plan_id, suite)
    except (ValueError, RuntimeError, OSError) as error:
        plan = read_plan(tool_root, plan_id)
        result = {"status": "blocked", "verificationLevel": "gameplay-assertions", "reason": str(error),
                  "assertionCount": 0, "candidateDigest": digest(plan["candidate"]), "profile": plan["profile"],
                  "suiteDigest": digest(suite), "completedAt": now()}
        evidence_path = plan_dir(tool_root, plan_id) / "verification.json"
        evidence = load(evidence_path) if evidence_path.is_file() else {"planId": plan_id, "candidateDigest": digest(plan["candidate"]), "profile": plan["profile"], "checks": {}}
        evidence["checks"]["scenario"] = result
        save(evidence_path, evidence)
        return result

def _run(tool_root, plan_id, suite):
    plan = read_plan(tool_root, plan_id)
    if any(stale_files(plan).values()): return {"status": "stale"}
    if plan["profile"]["target"] != "windows": return {"status": "blocked", "reason": "scenario isolation currently verified only for Windows"}
    run_id = uuid.uuid4().hex
    directory = Path(tool_root) / ".gmtool-work" / "scenarios" / run_id
    root = directory / "project"; artifacts = directory / "artifacts"; artifacts.mkdir(parents=True)
    shutil.copytree(plan_dir(tool_root, plan_id) / "candidate", root)
    project_file = root / Path(plan["projectFile"]).name
    name = "gmtool_test_" + run_id
    obj = "obj_gmtool_test"; room = "rm_gmtool_test"
    code = generate(suite, run_id, digest(plan["candidate"]), artifacts)
    # Unique clone identity selects a distinct default save sandbox. Test code must use
    # gmtool_test_root for explicit paths; arbitrary GML is not OS-sandboxed.
    replace_top_level(project_file, "name", name)
    if "%Name" in build_index(project_file).raw_project: replace_top_level(project_file, "%Name", name)
    # Registered resources can reference the project filename as their parent.
    # Replace only exact JSON string tokens, preserving metadata formatting.
    from .lossless_json import load as load_document
    original_filename = project_file.name
    for metadata in root.rglob("*.yy"):
        document = load_document(metadata)
        for token in reversed(document.tokens):
            if token.kind == "string" and token.value == original_filename:
                document.text = document.text[:token.start] + json.dumps(name + ".yyp") + document.text[token.end:]
        metadata.write_bytes(document.to_bytes())
    new_file = root / (name + ".yyp"); project_file.rename(new_file); project_file = new_file
    if suite.get("bootstrap"):
        from .index import resolve
        bootstrap = suite["bootstrap"]
        if set(bootstrap) - {"create", "step", "preserveCreate"}: raise ValueError("unknown bootstrap fields")
        bootstrap_index = build_index(project_file)
        create_owner, create_source = resolve(bootstrap_index, bootstrap["create"])
        step_owner, step_source = resolve(bootstrap_index, bootstrap["step"])
        if create_source is None or step_source is None or create_source.label != "Create" or not step_source.label.startswith("Step") or create_owner.name != step_owner.name:
            raise ValueError("bootstrap needs existing Create and Step events on the same startup object")
        original = create_source.path.read_text(encoding="utf-8-sig") if bootstrap.get("preserveCreate") else ""
        create_source.path.write_text(original + '\nif (!variable_global_exists("__gmtool_test_owner")) {\nglobal.__gmtool_test_owner = id;\n' + code + '\n}\n', encoding="utf-8")
        step_source.path.write_text('if (variable_global_exists("__gmtool_test_owner") && id == global.__gmtool_test_owner) { gmtool_test_tick(); }\n', encoding="utf-8")
        if suite.get("checkpoints"): raise ValueError("bootstrap screenshots require an explicit draw adapter; use injected test room")
    else:
        _official_recipe(tool_root, project_file, "create", {"type": "object", "name": obj})
        _official_recipe(tool_root, project_file, "object-event-create", {"name": obj, "type": "create"})
        (root / "objects" / obj / "Create_0.gml").write_text(code, encoding="utf-8")
        _official_recipe(tool_root, project_file, "object-event-create", {"name": obj, "type": "step", "subtype": "step_normal"})
        (root / "objects" / obj / "Step_0.gml").write_text("gmtool_test_tick();\n", encoding="utf-8")
    if suite.get("checkpoints"):
        _official_recipe(tool_root, project_file, "object-event-create", {"name": obj, "type": "draw", "subtype": "draw_gui"})
        captures = []
        for checkpoint in suite["checkpoints"]:
            from .workspace import identifier
            filename = identifier(checkpoint["name"]) + ".png"
            captures.append(f'if (global.gmtool_test_frame == {int(checkpoint["frame"])}) {{ surface_save(application_surface, global.gmtool_test_root + "/{filename}"); }}')
        (root / "objects" / obj / "Draw_64.gml").write_text("\n".join(captures), encoding="utf-8")
    if not suite.get("bootstrap"):
        _official_recipe(tool_root, project_file, "create", {"type": "room", "name": room})
        _official_recipe(tool_root, project_file, "room-instance-create", {"room": room, "object": obj, "x": "0", "y": "0"})
        room_record = build_index(project_file).resources_by_name[room.casefold()]
        replace_top_level(project_file, "RoomOrderNodes", [{"roomId": {"name": room, "path": room_record.path.relative_to(root).as_posix()}}])
    harness_digest = digest(source_snapshot(root))
    process = invoke(Path(tool_root), build_arguments(project_file, plan["profile"], Path(tool_root) / ".gm-cli-cache", "run"), cwd=root, timeout=plan["profile"]["timeout"])
    result = collect(process.stdout + "\n" + process.stderr, run_id, digest(plan["candidate"]), [t["name"] for t in suite["tests"]], exit_code=process.exit_code, timed_out=process.timed_out)
    screenshots = []
    for checkpoint in suite.get("checkpoints", []):
        file = artifacts / (checkpoint["name"] + ".png")
        screenshots.append({"name": checkpoint["name"], "path": str(file), "exists": file.is_file()})
        if not file.is_file():
            result["status"] = "failed"; result["problems"].append("missing screenshot checkpoint: " + checkpoint["name"])
    result.update({"runId": run_id, "planId": plan_id, "candidateDigest": digest(plan["candidate"]), "harnessDigest": harness_digest,
                   "suiteDigest": digest(suite), "profile": plan["profile"], "process": process.as_dict(), "artifacts": str(artifacts), "completedAt": now(),
                   "screenshots": screenshots, "visualReview": "required" if screenshots else "not-requested",
                   "saveIsolation": {"cloneName": name, "explicitPathRoot": str(artifacts), "arbitraryCodeSandbox": False}})
    if any(stale_files(plan).values()): result["status"] = "stale"
    save(directory / "result.json", result)
    evidence_path = plan_dir(tool_root, plan_id) / "verification.json"
    evidence = load(evidence_path) if evidence_path.is_file() else {"planId": plan_id, "candidateDigest": digest(plan["candidate"]), "profile": plan["profile"], "checks": {}}
    evidence["checks"]["scenario"] = result
    save(evidence_path, evidence)
    audit(tool_root, plan["projectFile"], "scenario", {"status": result["status"], "assertionCount": result["assertionCount"]})
    return result
