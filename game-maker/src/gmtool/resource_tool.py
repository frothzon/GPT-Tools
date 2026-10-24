from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import shutil
import time
import uuid
from typing import Any

from .gm_cli import CommandResult, invoke, snapshot_diff, source_snapshot
from .model import ProjectIndex

_GMNOTES_RESOURCE = re.compile(rb'"resourceType"\s*:\s*"GMNotes"')
_GMNOTES_VERSION = re.compile(rb'("\$GMNotes"\s*:\s*")v\d+(")')


@dataclass(frozen=True)
class ResourceToolPreview:
    expression: str
    process: CommandResult
    clone_changes: dict[str, list[str]]
    original_changes: dict[str, list[str]]
    original_snapshot: dict[str, str]
    workspace: Path | None

    def as_dict(self) -> dict[str, Any]:
        return {
            "expression": self.expression,
            "process": self.process.as_dict(),
            "cloneChanges": self.clone_changes,
            "originalProjectChanges": self.original_changes,
            "workspace": str(self.workspace) if self.workspace else None,
            "disposableCopy": True,
        }


def _copy_project(index: ProjectIndex, destination: Path) -> Path:
    def ignore(_directory: str, names: list[str]) -> set[str]:
        return {name for name in names if name in {".git", ".gmtool-work", "__pycache__"}}

    shutil.copytree(index.root, destination, ignore=ignore)
    project = destination / index.project_file.name
    if not project.is_file():
        raise RuntimeError(f"project copy is missing {project}")
    return project


def _pin_game_maker_notes_v1(project_root: Path) -> None:
    """Pin candidate note descriptors to v1; ResourceTool may rewrite notes globally.

    Installed ProjectTool cannot downgrade v2 GMNotes, so candidate clones are
    normalized before their diff can be applied to the user's project.
    """
    for descriptor in project_root.rglob("*.yy"):
        data = descriptor.read_bytes()
        if not _GMNOTES_RESOURCE.search(data):
            continue
        normalized = _GMNOTES_VERSION.sub(rb"\g<1>v1\g<2>", data)
        if normalized != data:
            descriptor.write_bytes(normalized)


def preview(
    tool_root: Path,
    index: ProjectIndex,
    expression: str,
    *,
    keep_workspace: bool = False,
    timeout: int = 300,
) -> ResourceToolPreview:
    operation_id = f"{time.strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:12]}"
    operation_root = tool_root / ".gmtool-work" / "resourcetool" / operation_id
    project_copy_root = operation_root / "project"
    operation_root.mkdir(parents=True, exist_ok=False)
    copied_project = _copy_project(index, project_copy_root)
    original_before = source_snapshot(index.root)
    clone_before = source_snapshot(project_copy_root)
    process = invoke(
        tool_root,
        [
            "resourcetool",
            "eval",
            expression,
            str(copied_project),
            f"--cache-dir={tool_root / '.gm-cli-cache'}",
        ],
        cwd=project_copy_root,
        timeout=timeout,
    )
    _pin_game_maker_notes_v1(project_copy_root)
    clone_after = source_snapshot(project_copy_root)
    original_after = source_snapshot(index.root)
    clone_changes = snapshot_diff(clone_before, clone_after)
    original_changes = snapshot_diff(original_before, original_after)
    retained: Path | None = operation_root if keep_workspace else None
    if not keep_workspace:
        shutil.rmtree(operation_root)
    return ResourceToolPreview(expression, process, clone_changes, original_changes, original_before, retained)
