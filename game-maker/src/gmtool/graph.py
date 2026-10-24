from __future__ import annotations

import re
from typing import Any, Iterator

from .model import ProjectIndex, ResourceRecord


def _references(value: Any) -> Iterator[tuple[str, str]]:
    if isinstance(value, dict):
        name, path = value.get("name"), value.get("path")
        if isinstance(name, str) and isinstance(path, str):
            yield name, path
        for child in value.values():
            yield from _references(child)
    elif isinstance(value, list):
        for child in value:
            yield from _references(child)


def build_graph(index: ProjectIndex, focus: str | None = None, direction: str = "both") -> dict[str, Any]:
    resources = {resource.name.casefold(): resource for resource in index.resources}
    edges: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()

    def add(source: ResourceRecord, target: ResourceRecord, kind: str, confidence: str, detail: str) -> None:
        key = (source.name.casefold(), target.name.casefold(), kind)
        if key in seen or source.name.casefold() == target.name.casefold():
            return
        seen.add(key)
        edges.append({"from": source.name, "to": target.name, "kind": kind, "confidence": confidence, "detail": detail})

    for resource in index.resources:
        for name, path in _references(resource.descriptor):
            target = resources.get(name.casefold())
            if target:
                add(resource, target, "metadata-reference", "exact", path)
        # This is intentionally reported as a soft/static edge. Dynamic lookup
        # through strings, macros, or external data is never silently treated
        # as a hard rename/delete reference.
        for source in resource.sources:
            if not source.path.is_file() or source.kind not in {"gml", "shader-vertex", "shader-fragment"}:
                continue
            try:
                text = source.path.read_text(encoding="utf-8-sig")
            except (OSError, UnicodeDecodeError):
                continue
            for target in index.resources:
                if target is resource:
                    continue
                if re.search(rf"(?<![A-Za-z0-9_]){re.escape(target.name)}(?![A-Za-z0-9_])", text):
                    add(resource, target, "code-reference", "static-text", source.label)

    selected = focus.casefold() if focus else None
    if selected and selected not in resources:
        raise KeyError(f"resource not found: {focus}")
    if selected:
        filtered: list[dict[str, Any]] = []
        for edge in edges:
            outgoing = edge["from"].casefold() == selected
            incoming = edge["to"].casefold() == selected
            if direction == "out" and outgoing or direction == "in" and incoming or direction == "both" and (outgoing or incoming):
                filtered.append(edge)
        edges = filtered
    nodes = sorted({name for edge in edges for name in (edge["from"], edge["to"])})
    if selected:
        nodes = sorted(set(nodes) | {resources[selected].name})
    else:
        nodes = sorted(resource.name for resource in index.resources)
    return {"focus": focus, "direction": direction, "nodes": nodes, "edges": edges}
