from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class SourceFile:
    label: str
    path: Path
    kind: str
    aliases: tuple[str, ...] = ()

    def as_dict(self, root: Path) -> dict[str, Any]:
        return {
            "label": self.label,
            "kind": self.kind,
            "path": self.path.relative_to(root).as_posix(),
            "aliases": list(self.aliases),
        }


@dataclass
class ResourceRecord:
    name: str
    type: str
    path: Path
    descriptor: dict[str, Any]
    parent: dict[str, Any] | None = None
    sources: list[SourceFile] = field(default_factory=list)

    def as_dict(self, root: Path, *, include_descriptor: bool = False) -> dict[str, Any]:
        result: dict[str, Any] = {
            "name": self.name,
            "type": self.type,
            "path": self.path.relative_to(root).as_posix(),
            "parent": self.parent,
            "sources": [source.as_dict(root) for source in self.sources],
        }
        if include_descriptor:
            result["descriptor"] = self.descriptor
        return result


@dataclass
class ProjectIndex:
    project_file: Path
    root: Path
    name: str
    ide_version: str | None
    resource_version: str | None
    resources: list[ResourceRecord]
    folders: list[dict[str, Any]]
    included_files: list[dict[str, Any]]
    audio_groups: list[dict[str, Any]]
    texture_groups: list[dict[str, Any]]
    room_order: list[dict[str, Any]]
    raw_project: dict[str, Any]

    @property
    def resources_by_name(self) -> dict[str, ResourceRecord]:
        return {resource.name.casefold(): resource for resource in self.resources}

    def summary(self) -> dict[str, Any]:
        counts: dict[str, int] = {}
        source_count = 0
        for resource in self.resources:
            counts[resource.type] = counts.get(resource.type, 0) + 1
            source_count += len(resource.sources)
        return {
            "project": self.name,
            "projectFile": str(self.project_file),
            "root": str(self.root),
            "ideVersion": self.ide_version,
            "resourceVersion": self.resource_version,
            "resourceCount": len(self.resources),
            "sourceFileCount": source_count,
            "resourceTypes": dict(sorted(counts.items())),
            "folderCount": len(self.folders),
            "includedFileCount": len(self.included_files),
            "audioGroupCount": len(self.audio_groups),
            "textureGroupCount": len(self.texture_groups),
            "roomOrderCount": len(self.room_order),
        }


@dataclass(frozen=True)
class Diagnostic:
    code: str
    severity: str
    message: str
    path: Path | None = None
    line: int | None = None
    column: int | None = None
    resource: str | None = None
    source: str | None = None

    def as_dict(self, root: Path | None = None) -> dict[str, Any]:
        path_value: str | None = None
        if self.path:
            try:
                path_value = self.path.relative_to(root).as_posix() if root else str(self.path)
            except ValueError:
                path_value = str(self.path)
        return {
            "code": self.code,
            "severity": self.severity,
            "message": self.message,
            "path": path_value,
            "line": self.line,
            "column": self.column,
            "resource": self.resource,
            "source": self.source,
        }

