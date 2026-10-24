from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from . import __version__
from .capabilities import FAMILIES, manifest as capabilities_manifest
from .compiler import explain_diagnostic, parse_compiler_output
from .diagnostics import diagnose, scan_source, scan_text
from .discovery import DiscoveryError
from .environment import doctor
from .gm_cli import invoke, snapshot_diff, source_snapshot
from .graph import build_graph
from .index import build_index, find_resources, resolve
from .lossless_json import ParseError
from .model import Diagnostic, ProjectIndex, ResourceRecord, SourceFile
from .previews import build_preview
from .resource_tool import preview as resource_tool_preview
from .recovery import rollback as rollback_transaction, status as recovery_status
from .repair import compile_arguments, default_toolchain, propose, verify_candidate
from .resource_api import build_expression, operation_names
from .transactions import apply_file_set, apply_single_file, sha256_bytes
from .validation import validate


TOOL_ROOT = Path(__file__).resolve().parents[2]


def _emit_json(value: Any) -> None:
    print(json.dumps(value, indent=2, ensure_ascii=False))


def _add_json(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--json", action="store_true", help="emit stable machine-readable JSON")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="gmtool", description="Agent-friendly GameMaker project tools")
    parser.add_argument("--version", action="version", version=f"gmtool {__version__}")
    commands = parser.add_subparsers(dest="command", required=True)
    from .workflow_cli import register
    register(commands)

    doctor_parser = commands.add_parser("doctor", help="inspect Python, Node.js, and gm-cli availability")
    _add_json(doctor_parser)

    inspect_parser = commands.add_parser("inspect", aliases=["inventory"], help="summarize a GameMaker project")
    inspect_parser.add_argument("project", nargs="?", default=".")
    inspect_parser.add_argument("--resources", action="store_true", help="include resource records")
    _add_json(inspect_parser)

    find_parser = commands.add_parser("find", help="find resources and logical source labels")
    find_parser.add_argument("project")
    find_parser.add_argument("query")
    _add_json(find_parser)

    resolve_parser = commands.add_parser("resolve", help="resolve a logical resource or source to disk")
    resolve_parser.add_argument("project")
    resolve_parser.add_argument("spec")
    _add_json(resolve_parser)

    graph_parser = commands.add_parser("graph", help="show typed metadata and static code dependencies")
    graph_parser.add_argument("project")
    graph_parser.add_argument("spec", nargs="?")
    graph_parser.add_argument("--direction", choices=("in", "out", "both"), default="both")
    _add_json(graph_parser)

    read_parser = commands.add_parser("read", help="read a resource descriptor or logical source")
    read_parser.add_argument("project")
    read_parser.add_argument("spec")
    read_parser.add_argument("--include-code", action="store_true")
    read_parser.add_argument("--raw", action="store_true", help="return original descriptor text")
    _add_json(read_parser)

    write_parser = commands.add_parser("write", help="preview or atomically replace an existing logical source")
    write_parser.add_argument("project")
    write_parser.add_argument("spec")
    write_parser.add_argument("--from", dest="source_file", required=True, help="replacement source file")
    write_parser.add_argument("--apply", action="store_true", help="apply after preview checks; default is dry run")
    _add_json(write_parser)

    validate_parser = commands.add_parser("validate", help="validate metadata and cross-file invariants")
    validate_parser.add_argument("project", nargs="?", default=".")
    validate_parser.add_argument("--strict", action="store_true", help="treat warnings as failure")
    _add_json(validate_parser)

    diagnose_parser = commands.add_parser("diagnose", help="scan source and metadata for simple syntax errors")
    diagnose_parser.add_argument("project", nargs="?", default=".")
    diagnose_parser.add_argument("spec", nargs="?")
    diagnose_parser.add_argument("--compile", action="store_true", help="also run the pinned compiler and map its diagnostics")
    diagnose_parser.add_argument("--target", default="windows")
    diagnose_parser.add_argument("--runtime", choices=("vm", "native"), default="vm")
    diagnose_parser.add_argument("--toolchain")
    diagnose_parser.add_argument("--config", default="Default")
    diagnose_parser.add_argument("--verbose", action="store_true")
    diagnose_parser.add_argument("--timeout", type=int, default=900)
    _add_json(diagnose_parser)

    capabilities_parser = commands.add_parser("capabilities", help="show the versioned resource-family capability manifest")
    capabilities_parser.add_argument("project", nargs="?", help="optional project for version/profile context")
    _add_json(capabilities_parser)

    schema_parser = commands.add_parser("schema", help="show the guarded recipe contract for a resource family")
    schema_parser.add_argument("family")
    _add_json(schema_parser)

    explain_parser = commands.add_parser("explain-error", help="explain a GameMaker compiler or gmtool diagnostic")
    explain_parser.add_argument("message", help="diagnostic code/message or quoted compiler message")
    explain_parser.add_argument("--code")
    _add_json(explain_parser)

    recover_parser = commands.add_parser("recover", help="inspect or explicitly roll back unfinished transaction journals")
    recover_parser.add_argument("project", nargs="?", help="optional project .yyp or project root to filter journals")
    recover_parser.add_argument("--transaction-id")
    recover_parser.add_argument("--rollback", action="store_true", help="roll back one unfinished transaction; requires --transaction-id")
    _add_json(recover_parser)

    for command_name, help_text in (("compile", "compile through the pinned official gm-cli"), ("test", "validate and compile through the pinned official gm-cli")):
        build_parser = commands.add_parser(command_name, help=help_text)
        build_parser.add_argument("project", nargs="?", default=".")
        build_parser.add_argument("--target", default="windows")
        build_parser.add_argument("--runtime", choices=("vm", "native"), default="vm")
        build_parser.add_argument("--toolchain")
        build_parser.add_argument("--config", default="Default")
        build_parser.add_argument("--verbose", action="store_true")
        build_parser.add_argument("--timeout", type=int, default=900)
        _add_json(build_parser)

    run_parser = commands.add_parser("run", aliases=["debug"], help="run a bounded GameMaker smoke/debug session through pinned gm-cli")
    run_parser.add_argument("project", nargs="?", default=".")
    run_parser.add_argument("--target", default="windows")
    run_parser.add_argument("--runtime", choices=("vm", "native"), default="vm")
    run_parser.add_argument("--toolchain")
    run_parser.add_argument("--config", default="Default")
    run_parser.add_argument("--verbose", action="store_true")
    run_parser.add_argument("--timeout", type=int, default=60)
    _add_json(run_parser)

    resource_tool_parser = commands.add_parser("resource-tool", help="run an official ResourceTool expression on a disposable project copy")
    resource_tool_parser.add_argument("project")
    resource_tool_parser.add_argument("expression")
    resource_tool_parser.add_argument("--apply", action="store_true", help="apply the complete reviewed official diff transactionally")
    resource_tool_parser.add_argument("--keep-workspace", action="store_true")
    resource_tool_parser.add_argument("--timeout", type=int, default=300)
    _add_json(resource_tool_parser)

    resource_parser = commands.add_parser("resource", help="run a reviewed, agent-friendly ResourceTool recipe on a disposable copy")
    resource_parser.add_argument("project")
    resource_parser.add_argument("operation", choices=operation_names())
    resource_parser.add_argument("--apply", action="store_true", help="apply the complete reviewed official diff transactionally")
    resource_parser.add_argument("--keep-workspace", action="store_true")
    resource_parser.add_argument("--timeout", type=int, default=300)
    # Common recipe fields. Unsupported combinations are rejected by the
    # recipe builder before ResourceTool is invoked.
    for name in ("type", "name", "new-name", "parent", "parenttype", "folder", "expr", "value", "subtype", "collisionobject", "newtype", "newsubtype", "newcollisionobject", "path", "room", "object", "layer", "layertype", "item", "itemtype", "x", "y", "sequence", "particlesystem", "font", "depth", "frame", "index", "sprite", "tilewidth", "tileheight", "tilexoffset", "tileyoffset", "tilehsep", "tilevsep", "tilehborder", "tilevborder", "group", "resources", "config", "property", "points", "count", "lower", "upper", "first", "second", "amount", "platform", "collections", "collection", "prefab", "left", "top", "width", "height", "data", "file", "repeatx", "repeaty", "transparent", "outfile", "padleft", "padright", "padtop", "padbottom", "trimleft", "trimright", "trimtop", "trimbottom"):
        resource_parser.add_argument(f"--{name}", dest=name.replace("-", "_"))
    for name in ("keys", "list", "all", "downloaded", "referenced", "forced"):
        resource_parser.add_argument(f"--{name}", action="store_true")
    resource_parser.add_argument("--include-resources", dest="include_resources", action="store_true", help="include resources in a folder listing")
    _add_json(resource_parser)

    preview_parser = commands.add_parser("preview", help="build an agent-readable resource preview bundle")
    preview_parser.add_argument("project")
    preview_parser.add_argument("spec")
    preview_parser.add_argument("--force", action="store_true")
    _add_json(preview_parser)

    repair_parser = commands.add_parser("repair-syntax", help="propose and compiler-verify a conservative syntax repair")
    repair_parser.add_argument("project")
    repair_parser.add_argument("spec")
    repair_parser.add_argument("--apply", action="store_true")
    repair_parser.add_argument("--target", default="windows")
    repair_parser.add_argument("--runtime", choices=("vm", "native"), default="vm")
    repair_parser.add_argument("--toolchain")
    repair_parser.add_argument("--config", default="Default")
    repair_parser.add_argument("--timeout", type=int, default=900)
    repair_parser.add_argument("--keep-workspace", action="store_true")
    _add_json(repair_parser)
    return parser


def _load_index(project: str) -> ProjectIndex:
    return build_index(project)


def _print_resource(resource: ResourceRecord, root: Path) -> None:
    print(f"{resource.name} [{resource.type}] {resource.path.relative_to(root).as_posix()}")
    for source in resource.sources:
        status = "" if source.path.is_file() else " [missing]"
        print(f"  {source.label}: {source.path.relative_to(root).as_posix()}{status}")


def _diagnostic_summary(items: list[Diagnostic]) -> dict[str, int]:
    result = {"errors": 0, "warnings": 0, "info": 0}
    for item in items:
        key = {"error": "errors", "warning": "warnings"}.get(item.severity, "info")
        result[key] += 1
    return result


def _print_diagnostics(items: list[Diagnostic], root: Path) -> None:
    for item in items:
        location = ""
        if item.path:
            try:
                location = item.path.relative_to(root).as_posix()
            except ValueError:
                location = str(item.path)
            if item.line:
                location += f":{item.line}"
                if item.column:
                    location += f":{item.column}"
            location += ": "
        print(f"{location}{item.severity.upper()} {item.code} {item.message}")


def _resource_operation(index: ProjectIndex, expression: str, *, apply: bool, keep_workspace: bool, timeout: int) -> tuple[Any, dict[str, Any]]:
    """Evaluate ResourceTool on a clone and, optionally, apply its reviewed diff."""
    result = resource_tool_preview(
        TOOL_ROOT,
        index,
        expression,
        keep_workspace=keep_workspace or apply,
        timeout=timeout,
    )
    payload = result.as_dict()
    original_changed = any(result.original_changes.values())
    if apply and result.process.exit_code == 0 and not original_changed:
        if result.workspace is None:
            raise RuntimeError("ResourceTool workspace was not retained for apply")
        candidate_root = result.workspace / "project"
        candidate_index = build_index(candidate_root / index.project_file.name)
        candidate_errors = [item for item in validate(candidate_index) if item.severity == "error"]
        if candidate_errors:
            payload["applyStatus"] = "blocked-validation"
            payload["candidateDiagnostics"] = [item.as_dict(candidate_root) for item in candidate_errors]
        else:
            transaction = apply_file_set(
                index.root,
                candidate_root,
                expected_snapshot=result.original_snapshot,
                changes=result.clone_changes,
                journal_root=TOOL_ROOT / ".gmtool-work" / "transactions",
                current_snapshot=source_snapshot,
                verify=lambda: [item.message for item in validate(build_index(index.project_file)) if item.severity == "error"],
            )
            payload["applyStatus"] = "applied"
            payload["transaction"] = transaction.as_dict()
            if not keep_workspace:
                import shutil

                shutil.rmtree(result.workspace)
                payload["workspace"] = None
    payload["originalProjectChanged"] = original_changed
    return result, payload


def _recipe_options(args: argparse.Namespace) -> dict[str, Any]:
    values = vars(args).copy()
    # argparse names are snake_case while ResourceTool uses compact upper-case
    # argument names such as NEWNAME and PARENTTYPE.
    aliases = {"new_name": "newname", "parenttype": "parenttype", "collisionobject": "collisionobject", "newcollisionobject": "newcollisionobject", "layertype": "layertype", "itemtype": "itemtype", "newtype": "newtype", "newsubtype": "newsubtype"}
    for source, target in aliases.items():
        if source in values:
            values[target] = values[source]
    return values


def _run(args: argparse.Namespace) -> int:
    from .workflow_cli import COMMANDS, run as run_workflow
    if args.command in COMMANDS:
        return run_workflow(TOOL_ROOT, args)
    if args.command == "doctor":
        result = doctor(TOOL_ROOT)
        if args.json:
            _emit_json(result)
        else:
            print(f"Python: {result['python']['version']} ({result['python']['path']})")
            for node in result["node"]:
                marker = "ok" if node["meetsNode24"] else "too old"
                print(f"Node: {node['version']} ({node['path']}) [{marker}]")
            gm = result["gmCli"]
            print(f"gm-cli: {gm['version'] or 'not found'} ({gm['source']})")
            for issue in result["issues"]:
                print(f"{issue['severity'].upper()}: {issue['message']}")
        return 1 if any(issue["severity"] == "error" for issue in result["issues"]) else 0

    if args.command == "capabilities":
        project_context = None
        if args.project:
            project_context = _load_index(args.project).summary()
        result = capabilities_manifest(project=project_context)
        if args.json:
            _emit_json(result)
        else:
            print(f"gmtool {result['toolVersion']} capability manifest ({result['contract']})")
            for family, data in result["families"].items():
                implemented = sum(value == "implemented" for value in data["operations"].values())
                print(f"{family}: {data['status']} ({implemented}/{len(data['operations'])} operations) - {data['note']}")
        return 0

    if args.command == "schema":
        family = args.family.casefold()
        if family not in FAMILIES:
            raise KeyError(f"resource family schema not found: {args.family}")
        from .operation_registry import family_contracts
        data = family_contracts()[family]
        result = {"family": args.family, "status": data["status"], "operations": data["implemented"], "recipes": data["recipes"], "allOperations": capabilities_manifest()["operations"], "note": data["note"]}
        if args.json:
            _emit_json(result)
        else:
            print(f"{args.family}: {data['status']}")
            print(data["note"])
            print("Implemented operations: " + ", ".join(data["implemented"]))
        return 0

    if args.command == "explain-error":
        result = explain_diagnostic(args.message, args.code)
        if args.json:
            _emit_json(result)
        else:
            print(f"{result['title']} [{result['code']}]")
            print(result["cause"])
            print("Next steps:")
            for step in result["nextSteps"]:
                print(f"- {step}")
            print(f"Repair policy: {result['repair']}")
        return 0

    if args.command == "recover":
        project_root = None
        if args.project:
            candidate = Path(args.project).expanduser().resolve()
            project_root = candidate.parent if candidate.is_file() else candidate
        if args.rollback:
            if not args.transaction_id:
                raise ValueError("recover --rollback requires --transaction-id")
            result = rollback_transaction(TOOL_ROOT, args.transaction_id, project_root)
        else:
            result = recovery_status(TOOL_ROOT)
            if project_root:
                result = [item for item in result if str(item.get("root", "")).casefold() == str(project_root).casefold() or str(item.get("target", "")).casefold().startswith(str(project_root).casefold())]
        if args.json:
            _emit_json(result)
        else:
            if isinstance(result, list):
                if not result:
                    print("No transaction journals found.")
                for item in result:
                    print(f"{item.get('transactionId', '?')}: {item.get('state', 'unknown')} ({item.get('journal', '')})")
            else:
                print(f"{result['transactionId']}: {result['state']}")
        return 0

    index = _load_index(args.project)
    if args.command in {"inspect", "inventory"}:
        result = index.summary()
        if args.resources:
            result["resources"] = [resource.as_dict(index.root) for resource in index.resources]
        if args.json:
            _emit_json(result)
        else:
            print(f"{result['project']} - GameMaker {result['ideVersion'] or 'unknown'}")
            print(f"{result['resourceCount']} resources, {result['sourceFileCount']} source files, {result['includedFileCount']} included files")
            for resource_type, count in result["resourceTypes"].items():
                print(f"  {resource_type}: {count}")
        return 0

    if args.command == "find":
        matches = find_resources(index, args.query)
        if args.json:
            _emit_json([resource.as_dict(index.root) for resource in matches])
        else:
            for resource in matches:
                _print_resource(resource, index.root)
        return 0 if matches else 1

    if args.command == "resolve":
        resource, source = resolve(index, args.spec)
        path = source.path if source else resource.path
        result = {
            "spec": args.spec,
            "resource": resource.name,
            "type": resource.type,
            "label": source.label if source else "descriptor",
            "path": str(path),
            "exists": path.is_file(),
        }
        if args.json:
            _emit_json(result)
        else:
            print(path)
        return 0 if path.is_file() else 1

    if args.command == "graph":
        result = build_graph(index, args.spec, args.direction)
        if args.json:
            _emit_json(result)
        else:
            print(f"{len(result['nodes'])} nodes, {len(result['edges'])} edges")
            for edge in result["edges"]:
                print(f"{edge['from']} -[{edge['kind']}/{edge['confidence']}]-> {edge['to']} ({edge['detail']})")
        return 0

    if args.command == "read":
        resource, source = resolve(index, args.spec)
        if source:
            content = source.path.read_text(encoding="utf-8-sig")
            if args.json:
                _emit_json({"resource": resource.name, "label": source.label, "path": str(source.path), "content": content})
            else:
                print(content, end="" if content.endswith("\n") else "\n")
            return 0
        if args.raw:
            content = resource.path.read_text(encoding="utf-8-sig")
            if args.json:
                _emit_json({"resource": resource.name, "path": str(resource.path), "content": content})
            else:
                print(content, end="" if content.endswith("\n") else "\n")
            return 0
        result = resource.as_dict(index.root, include_descriptor=True)
        if args.include_code:
            result["code"] = [
                {
                    "label": source_item.label,
                    "path": source_item.path.relative_to(index.root).as_posix(),
                    "content": source_item.path.read_text(encoding="utf-8-sig") if source_item.path.is_file() else None,
                }
                for source_item in resource.sources
            ]
        if args.json:
            _emit_json(result)
        else:
            print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    if args.command == "write":
        resource, source = resolve(index, args.spec)
        if source is None:
            raise ValueError("write requires a logical source such as obj_player.Create or shd_example.vertex")
        if not source.path.is_file():
            raise FileNotFoundError(source.path)
        replacement_path = Path(args.source_file).expanduser().resolve()
        replacement = replacement_path.read_bytes()
        try:
            replacement_text = replacement.decode("utf-8-sig")
        except UnicodeDecodeError as exc:
            raise ValueError("replacement source must be UTF-8") from exc
        original = source.path.read_bytes()
        original_text = original.decode("utf-8-sig")
        before_hash = hashlib.sha256(original).hexdigest()
        after_hash = sha256_bytes(replacement)
        syntax_items = scan_text(replacement_text, path=source.path, resource=resource.name)
        syntax_errors = [item for item in syntax_items if item.severity == "error"]
        diff = "".join(
            difflib.unified_diff(
                original_text.splitlines(keepends=True),
                replacement_text.splitlines(keepends=True),
                fromfile=source.path.relative_to(index.root).as_posix(),
                tofile=source.path.relative_to(index.root).as_posix(),
            )
        )
        result: dict[str, Any] = {
            "status": "no-change" if before_hash == after_hash else ("blocked" if syntax_errors else "ready"),
            "dryRun": not args.apply,
            "resource": resource.name,
            "label": source.label,
            "target": str(source.path),
            "replacement": str(replacement_path),
            "beforeHash": before_hash,
            "afterHash": after_hash,
            "diff": diff,
            "diagnostics": [item.as_dict(index.root) for item in syntax_items],
        }
        if args.apply and before_hash != after_hash:
            if syntax_errors:
                result["status"] = "blocked"
            elif not syntax_errors:
                transaction = apply_single_file(
                    source.path,
                    replacement,
                    expected_hash=before_hash,
                    journal_root=TOOL_ROOT / ".gmtool-work" / "transactions",
                    verify=lambda: [item.message for item in scan_source(source.path, resource=resource.name) if item.severity == "error"],
                )
                result["transaction"] = transaction.as_dict()
                result["status"] = "applied"
                result["dryRun"] = False
        if args.json:
            _emit_json(result)
        else:
            if diff:
                print(diff, end="" if diff.endswith("\n") else "\n")
            for item in syntax_items:
                print(f"{item.severity.upper()} {item.code}: {item.message}")
            print(f"Status: {result['status']} ({'dry run' if result['dryRun'] else 'written'})")
        return 0 if result["status"] in {"no-change", "ready", "applied"} else 1

    if args.command == "validate":
        items = validate(index)
        summary = _diagnostic_summary(items)
        if args.json:
            _emit_json({"summary": summary, "diagnostics": [item.as_dict(index.root) for item in items]})
        else:
            _print_diagnostics(items, index.root)
            print(f"{summary['errors']} errors, {summary['warnings']} warnings")
        return 1 if summary["errors"] or (args.strict and summary["warnings"]) else 0

    if args.command == "diagnose":
        selected: list[tuple[str, SourceFile]] | None = None
        if args.spec:
            resource, source = resolve(index, args.spec)
            selected = [(resource.name, source)] if source else [(resource.name, item) for item in resource.sources]
        items = diagnose(index, selected)
        compiler_items: list[Diagnostic] = []
        compiler_process = None
        if args.compile:
            command = [
                "compile",
                str(index.project_file),
                f"--target={args.target}",
                f"--runtime={args.runtime}",
                f"--config={args.config}",
                f"--cache-dir={TOOL_ROOT / '.gm-cli-cache'}",
            ]
            if args.toolchain:
                command.append(f"--toolchain={args.toolchain}")
            command.append("--verbose" if args.verbose else "--errors-only")
            before = source_snapshot(index.root)
            compiler_process = invoke(TOOL_ROOT, command, cwd=index.root, timeout=args.timeout)
            after = source_snapshot(index.root)
            compiler_items = parse_compiler_output(compiler_process.stdout + "\n" + compiler_process.stderr, index)
            items.extend(compiler_items)
        summary = _diagnostic_summary(items)
        if args.json:
            result = {"summary": summary, "diagnostics": [item.as_dict(index.root) for item in items]}
            if compiler_process:
                result["compiler"] = {"process": compiler_process.as_dict(), "diagnostics": [item.as_dict(index.root) for item in compiler_items], "projectChanges": snapshot_diff(before, after)}
            _emit_json(result)
        else:
            _print_diagnostics(items, index.root)
            print(f"{summary['errors']} errors, {summary['warnings']} warnings")
            if compiler_process:
                print(f"Compiler exited {compiler_process.exit_code} in {compiler_process.duration_seconds:.2f}s")
        return 1 if summary["errors"] or (compiler_process and (compiler_process.exit_code != 0 or compiler_process.timed_out or any(snapshot_diff(before, after).values()))) else 0

    if args.command in {"compile", "test"}:
        validation_items = validate(index)
        validation_summary = _diagnostic_summary(validation_items)
        if validation_summary["errors"]:
            result = {
                "status": "validation-failed",
                "validation": {
                    "summary": validation_summary,
                    "diagnostics": [item.as_dict(index.root) for item in validation_items],
                },
            }
            if args.json:
                _emit_json(result)
            else:
                _print_diagnostics(validation_items, index.root)
                print("Compilation skipped because structural validation failed.")
            return 1
        command = [
            "compile",
            str(index.project_file),
            f"--target={args.target}",
            f"--runtime={args.runtime}",
            f"--config={args.config}",
            f"--cache-dir={TOOL_ROOT / '.gm-cli-cache'}",
        ]
        if args.toolchain:
            command.append(f"--toolchain={args.toolchain}")
        command.append("--verbose" if args.verbose else "--errors-only")
        before = source_snapshot(index.root)
        process = invoke(TOOL_ROOT, command, cwd=index.root, timeout=args.timeout)
        after = source_snapshot(index.root)
        changes = snapshot_diff(before, after)
        unexpected_changes = any(changes.values())
        result = {
            "status": "passed" if process.exit_code == 0 and not unexpected_changes else "failed",
            "verificationLevel": "build-check",
            "mode": args.command,
            "profile": {
                "target": args.target,
                "runtime": args.runtime,
                "toolchain": args.toolchain,
                "config": args.config,
            },
            "validation": {"summary": validation_summary},
            "process": process.as_dict(),
            "compilerDiagnostics": [item.as_dict(index.root) for item in parse_compiler_output(process.stdout + "\n" + process.stderr, index)],
            "projectChanges": changes,
            "note": "Compilation proves buildability, not gameplay behavior." if args.command == "test" else None,
        }
        if args.json:
            _emit_json(result)
        else:
            if process.stdout:
                print(process.stdout, end="" if process.stdout.endswith("\n") else "\n")
            if process.stderr:
                print(process.stderr, file=sys.stderr, end="" if process.stderr.endswith("\n") else "\n")
            print(f"gm-cli exited {process.exit_code} in {process.duration_seconds:.2f}s")
            if unexpected_changes:
                print(f"ERROR: gm-cli changed project files: {changes}")
            if args.command == "test":
                print("NOTE: compilation proves buildability, not gameplay behavior.")
        return 0 if result["status"] == "passed" else 1

    if args.command in {"run", "debug"}:
        command = [
            "run",
            str(index.project_file),
            f"--target={args.target}",
            f"--runtime={args.runtime}",
            f"--config={args.config}",
            f"--cache-dir={TOOL_ROOT / '.gm-cli-cache'}",
        ]
        if args.toolchain:
            command.append(f"--toolchain={args.toolchain}")
        command.append("--verbose" if args.verbose else "--errors-only")
        before = source_snapshot(index.root)
        process = invoke(TOOL_ROOT, command, cwd=index.root, timeout=args.timeout)
        after = source_snapshot(index.root)
        changes = snapshot_diff(before, after)
        result = {
            "status": "timed-out" if process.timed_out else "passed" if process.exit_code == 0 and not any(changes.values()) else "failed",
            "profile": {"target": args.target, "runtime": args.runtime, "toolchain": args.toolchain, "config": args.config, "timeout": args.timeout},
            "process": process.as_dict(),
            "compilerDiagnostics": [item.as_dict(index.root) for item in parse_compiler_output(process.stdout + "\n" + process.stderr, index)],
            "projectChanges": changes,
            "note": "run/debug is a bounded smoke/debug session; configure a runtime assertion harness for gameplay claims.",
            "verificationLevel": "runtime-execution",
        }
        if args.json:
            _emit_json(result)
        else:
            if process.stdout:
                print(process.stdout, end="" if process.stdout.endswith("\n") else "\n")
            if process.stderr:
                print(process.stderr, file=sys.stderr, end="" if process.stderr.endswith("\n") else "\n")
            print(f"gm-cli run exited {process.exit_code} in {process.duration_seconds:.2f}s")
            if process.timed_out:
                print("Run timed out; the invocation process tree was terminated.")
            if any(changes.values()):
                print(f"ERROR: gm-cli changed project files: {changes}")
        return 0 if result["status"] == "passed" else 1

    if args.command in {"resource-tool", "resource"}:
        from .operation_registry import assert_mutation_supported
        if args.command == "resource":
            assert_mutation_supported(index, args.operation, _recipe_options(args))
        expression = args.expression if args.command == "resource-tool" else build_expression(args.operation, _recipe_options(args))
        result, payload = _resource_operation(
            index,
            expression,
            apply=args.apply,
            keep_workspace=args.keep_workspace,
            timeout=args.timeout,
        )
        original_changed = payload["originalProjectChanged"]
        if args.json:
            _emit_json(payload)
        else:
            if result.process.stdout:
                print(result.process.stdout, end="" if result.process.stdout.endswith("\n") else "\n")
            if result.process.stderr:
                print(result.process.stderr, file=sys.stderr, end="" if result.process.stderr.endswith("\n") else "\n")
            changed_count = sum(len(values) for values in result.clone_changes.values())
            print(f"Disposable copy changed files: {changed_count}")
            print(f"Original project changed files: {sum(len(values) for values in result.original_changes.values())}")
            if "applyStatus" in payload:
                print(f"Apply status: {payload['applyStatus']}")
            if "transaction" in payload:
                print(f"Transaction: {payload['transaction']['transactionId']}")
            if payload.get("workspace"):
                print(f"Workspace retained: {payload['workspace']}")
        apply_failed = args.apply and payload.get("applyStatus") != "applied"
        return 0 if result.process.exit_code == 0 and not original_changed and not apply_failed else 1

    if args.command == "preview":
        resource, source = resolve(index, args.spec)
        if source is not None:
            raise ValueError("preview currently accepts a resource name, not an individual source label")
        result = build_preview(TOOL_ROOT, index, resource, force=args.force)
        if args.json:
            _emit_json(result)
        else:
            print(result["output"])
            if result.get("preview"):
                print(f"Preview: {result['preview']}")
            for warning in result.get("warnings", []):
                print(f"WARNING: {warning}")
        return 0

    if args.command == "repair-syntax":
        resource, source = resolve(index, args.spec)
        if source is None or source.kind not in {"gml", "shader-vertex", "shader-fragment"}:
            raise ValueError("repair-syntax requires a GML or shader source spec")
        diagnostics, candidates = propose(source.path, resource=resource.name)
        payload: dict[str, Any] = {
            "resource": resource.name,
            "label": source.label,
            "path": str(source.path),
            "diagnostics": [item.as_dict(index.root) for item in diagnostics],
            "candidateCount": len(candidates),
            "status": "refused" if not candidates else "candidate",
        }
        exit_code = 1
        if len(candidates) == 1:
            candidate = candidates[0]
            payload["candidate"] = {
                "code": candidate.code,
                "rationale": candidate.rationale,
                "insertion": candidate.insertion,
                "diff": candidate.diff(source.path.relative_to(index.root).as_posix()),
            }
            verification = verify_candidate(
                TOOL_ROOT,
                index,
                source,
                candidate,
                target=args.target,
                runtime=args.runtime,
                config=args.config,
                toolchain=args.toolchain,
                timeout=args.timeout,
                keep_workspace=args.keep_workspace,
            )
            payload["verification"] = verification.as_dict()
            payload["status"] = "verified" if verification.accepted else "refused"
            if verification.accepted:
                exit_code = 0
                if args.apply:
                    before_hash = hashlib.sha256(source.path.read_bytes()).hexdigest()

                    def verify_committed() -> list[str]:
                        local_errors = [item.message for item in scan_source(source.path, resource=resource.name) if item.severity == "error"]
                        if local_errors:
                            return local_errors
                        before_compile = source_snapshot(index.root)
                        process = invoke(
                            TOOL_ROOT,
                            compile_arguments(
                                TOOL_ROOT,
                                index.project_file,
                                target=args.target,
                                runtime=args.runtime,
                                config=args.config,
                                toolchain=args.toolchain or default_toolchain(index),
                            ),
                            cwd=index.root,
                            timeout=args.timeout,
                        )
                        after_compile = source_snapshot(index.root)
                        changes = snapshot_diff(before_compile, after_compile)
                        problems: list[str] = []
                        if process.exit_code != 0:
                            problems.append("committed candidate did not compile")
                        if any(changes.values()):
                            problems.append(f"compiler changed project files: {changes}")
                        return problems

                    transaction = apply_single_file(
                        source.path,
                        candidate.to_bytes(),
                        expected_hash=before_hash,
                        journal_root=TOOL_ROOT / ".gmtool-work" / "transactions",
                        verify=verify_committed,
                    )
                    payload["transaction"] = transaction.as_dict()
                    payload["status"] = "applied"
        if args.json:
            _emit_json(payload)
        else:
            for item in diagnostics:
                print(f"{item.severity.upper()} {item.code}: {item.message}")
            if payload.get("candidate"):
                print(payload["candidate"]["diff"], end="" if payload["candidate"]["diff"].endswith("\n") else "\n")
                print(f"Candidate: {payload['candidate']['rationale']}")
            if payload.get("verification"):
                print(f"Verification: {payload['verification']['reason']}")
            print(f"Status: {payload['status']}")
        return exit_code
    raise RuntimeError(f"unhandled command: {args.command}")


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    parser = _parser()
    args = parser.parse_args(argv)
    try:
        return _run(args)
    except (DiscoveryError, ParseError, KeyError, OSError, RuntimeError, ValueError) as exc:
        if getattr(args, "json", False):
            _emit_json({"error": type(exc).__name__, "message": str(exc)})
        else:
            print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
