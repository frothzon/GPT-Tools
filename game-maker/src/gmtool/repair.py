from __future__ import annotations

from dataclasses import dataclass
import difflib
from pathlib import Path
import shutil
import time
import uuid
from typing import Any

from .diagnostics import scan_text
from .gm_cli import CommandResult, invoke, snapshot_diff, source_snapshot
from .model import Diagnostic, ProjectIndex, SourceFile


@dataclass(frozen=True)
class RepairCandidate:
    code: str
    rationale: str
    original: str
    repaired: str
    insertion: str
    bom: bool = False

    def diff(self, relative_path: str) -> str:
        return "".join(
            difflib.unified_diff(
                self.original.splitlines(keepends=True),
                self.repaired.splitlines(keepends=True),
                fromfile=relative_path,
                tofile=relative_path,
            )
        )

    def to_bytes(self) -> bytes:
        return (b"\xef\xbb\xbf" if self.bom else b"") + self.repaired.encode("utf-8")


@dataclass(frozen=True)
class RepairVerification:
    accepted: bool
    reason: str
    process: CommandResult | None
    original_changes: dict[str, list[str]]
    workspace: Path | None

    def as_dict(self) -> dict[str, Any]:
        return {
            "accepted": self.accepted,
            "reason": self.reason,
            "process": self.process.as_dict() if self.process else None,
            "originalProjectChanges": self.original_changes,
            "workspace": str(self.workspace) if self.workspace else None,
        }


def _insert_before_terminal_newline(text: str, insertion: str) -> str:
    if text.endswith("\r\n"):
        return text[:-2] + insertion + "\r\n"
    if text.endswith("\n") or text.endswith("\r"):
        return text[:-1] + insertion + text[-1]
    return text + insertion


def propose(path: Path, *, resource: str | None = None) -> tuple[list[Diagnostic], list[RepairCandidate]]:
    raw = path.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = (raw[3:] if bom else raw).decode("utf-8")
    diagnostics = [item for item in scan_text(text, path=path, resource=resource) if item.severity == "error"]
    if len(diagnostics) != 1:
        return diagnostics, []
    diagnostic = diagnostics[0]
    candidate: RepairCandidate | None = None
    if diagnostic.code == "GMS013":
        repaired = _insert_before_terminal_newline(text, "*/")
        candidate = RepairCandidate(diagnostic.code, "close the single unterminated block comment at end of file", text, repaired, "*/", bom)
    elif diagnostic.code == "GMS014":
        expected = diagnostic.message.rsplit("expected ", 1)[-1].strip().strip("'")
        if expected in {")", "]", "}"}:
            repaired = _insert_before_terminal_newline(text, expected)
            candidate = RepairCandidate(diagnostic.code, f"close the single unclosed delimiter with {expected!r} at end of file", text, repaired, expected, bom)
    elif diagnostic.code == "GMS011" and diagnostic.line is not None:
        lines = text.splitlines(keepends=True)
        if 1 <= diagnostic.line <= len(lines):
            line = lines[diagnostic.line - 1]
            quote_offset = max(0, (diagnostic.column or 1) - 1)
            quote = line[quote_offset : quote_offset + 1]
            if quote in {"'", '"'}:
                if line.endswith("\r\n"):
                    lines[diagnostic.line - 1] = line[:-2] + quote + "\r\n"
                elif line.endswith(("\n", "\r")):
                    lines[diagnostic.line - 1] = line[:-1] + quote + line[-1]
                else:
                    lines[diagnostic.line - 1] = line + quote
                candidate = RepairCandidate(diagnostic.code, "close the single unterminated string at the end of its line", text, "".join(lines), quote, bom)
    if candidate and any(item.severity == "error" for item in scan_text(candidate.repaired, path=path, resource=resource)):
        candidate = None
    return diagnostics, [candidate] if candidate else []


def default_toolchain(index: ProjectIndex) -> str | None:
    if not index.ide_version:
        return None
    parts = index.ide_version.split(".")
    return "GMS2@" + ".".join(parts[:3]) if len(parts) >= 3 else None


def compile_arguments(
    tool_root: Path,
    project_file: Path,
    *,
    target: str,
    runtime: str,
    config: str,
    toolchain: str | None,
) -> list[str]:
    arguments = [
        "compile",
        str(project_file),
        f"--target={target}",
        f"--runtime={runtime}",
        f"--config={config}",
        f"--cache-dir={tool_root / '.gm-cli-cache'}",
        "--errors-only",
    ]
    if toolchain:
        arguments.append(f"--toolchain={toolchain}")
    return arguments


def verify_candidate(
    tool_root: Path,
    index: ProjectIndex,
    source: SourceFile,
    candidate: RepairCandidate,
    *,
    target: str = "windows",
    runtime: str = "vm",
    config: str = "Default",
    toolchain: str | None = None,
    timeout: int = 900,
    keep_workspace: bool = False,
) -> RepairVerification:
    operation_id = f"{time.strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:12]}"
    operation_root = tool_root / ".gmtool-work" / "repairs" / operation_id
    project_copy = operation_root / "project"
    operation_root.mkdir(parents=True, exist_ok=False)
    shutil.copytree(index.root, project_copy, ignore=shutil.ignore_patterns(".git", ".gmtool-work", "__pycache__"))
    relative_source = source.path.relative_to(index.root)
    copied_source = project_copy / relative_source
    copied_source.write_bytes(candidate.to_bytes())
    original_before = source_snapshot(index.root)
    resolved_toolchain = toolchain or default_toolchain(index)
    process = invoke(
        tool_root,
        compile_arguments(
            tool_root,
            project_copy / index.project_file.name,
            target=target,
            runtime=runtime,
            config=config,
            toolchain=resolved_toolchain,
        ),
        cwd=project_copy,
        timeout=timeout,
    )
    original_after = source_snapshot(index.root)
    original_changes = snapshot_diff(original_before, original_after)
    changed_original = any(original_changes.values())
    accepted = process.exit_code == 0 and not changed_original
    if process.timed_out:
        reason = "candidate compilation timed out"
    elif process.exit_code != 0:
        reason = "candidate did not compile"
    elif changed_original:
        reason = "verification unexpectedly changed the original project"
    else:
        reason = "candidate compiled and the original project remained unchanged"
    retained = operation_root if keep_workspace else None
    if not keep_workspace:
        shutil.rmtree(operation_root)
    return RepairVerification(accepted, reason, process, original_changes, retained)
