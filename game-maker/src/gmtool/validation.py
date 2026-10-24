from __future__ import annotations

from pathlib import Path
from typing import Any, Iterator

from .index import EVENT_PREFIXES, event_filename
from .lossless_json import ParseError, load
from .model import Diagnostic, ProjectIndex


def _walk_references(value: Any) -> Iterator[tuple[str, str]]:
    if isinstance(value, dict):
        name = value.get("name")
        path = value.get("path")
        if isinstance(name, str) and isinstance(path, str):
            yield name, path
        for child in value.values():
            yield from _walk_references(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_references(child)


def _case_exact(root: Path, relative: str) -> bool:
    current = root
    for part in Path(relative.replace("/", "\\")).parts:
        if not current.is_dir():
            return False
        names = {item.name for item in current.iterdir()}
        if part not in names:
            return False
        current = current / part
    return True


def validate(index: ProjectIndex) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    seen_names: dict[str, Path] = {}
    seen_paths: dict[str, str] = {}
    registered_paths = {resource.path.relative_to(index.root).as_posix().casefold() for resource in index.resources}

    try:
        project_doc = load(index.project_file)
        for duplicate in project_doc.duplicate_keys:
            diagnostics.append(Diagnostic("GMV002", "error", f"duplicate metadata key: {duplicate}", index.project_file, source="metadata"))
    except ParseError as exc:
        diagnostics.append(Diagnostic("GMV001", "error", str(exc), index.project_file, exc.line, exc.column, source="metadata"))
        return diagnostics

    for resource in index.resources:
        folded_name = resource.name.casefold()
        relative = resource.path.relative_to(index.root).as_posix()
        folded_path = relative.casefold()
        if folded_name in seen_names:
            diagnostics.append(Diagnostic("GMV010", "error", f"duplicate resource name: {resource.name}", resource.path, resource=resource.name))
        else:
            seen_names[folded_name] = resource.path
        if folded_path in seen_paths:
            diagnostics.append(Diagnostic("GMV011", "error", f"duplicate resource path: {relative}", resource.path, resource=resource.name))
        else:
            seen_paths[folded_path] = resource.name
        if not resource.path.is_file():
            diagnostics.append(Diagnostic("GMV012", "error", "registered descriptor is missing", resource.path, resource=resource.name))
            continue
        if not _case_exact(index.root, relative):
            diagnostics.append(Diagnostic("GMV013", "warning", "registered path casing differs from disk", resource.path, resource=resource.name))
        try:
            document = load(resource.path)
        except ParseError as exc:
            diagnostics.append(Diagnostic("GMV001", "error", str(exc), resource.path, exc.line, exc.column, resource.name, "metadata"))
            continue
        for duplicate in document.duplicate_keys:
            diagnostics.append(Diagnostic("GMV002", "error", f"duplicate metadata key: {duplicate}", resource.path, resource=resource.name, source="metadata"))
        descriptor_name = resource.descriptor.get("name") or resource.descriptor.get("%Name")
        if descriptor_name and descriptor_name != resource.name:
            diagnostics.append(Diagnostic("GMV014", "error", f"descriptor name {descriptor_name!r} does not match registration {resource.name!r}", resource.path, resource=resource.name))
        if resource.type == "Unknown":
            diagnostics.append(Diagnostic("GMV015", "warning", "resource type is missing or unknown", resource.path, resource=resource.name))

        if resource.type == "GMNotes" and resource.descriptor.get("$GMNotes") != "v1":
            diagnostics.append(Diagnostic(
                "GMV024",
                "error",
                "GameMaker notes must remain at $GMNotes v1; ProjectTool cannot downgrade v2 notes",
                resource.path,
                resource=resource.name,
                source="metadata",
            ))

        if resource.type == "GMObject":
            declared: set[str] = set()
            for event in resource.descriptor.get("eventList") or []:
                if not isinstance(event, dict):
                    continue
                event_type = event.get("eventType")
                event_num = event.get("eventNum")
                if not isinstance(event_type, int) or not isinstance(event_num, int):
                    diagnostics.append(Diagnostic("GMV020", "error", "object event is missing numeric eventType/eventNum", resource.path, resource=resource.name))
                    continue
                filename = event_filename(event_type, event_num, event.get("collisionObjectId"), index.ide_version)
                if filename is None:
                    if event_type == 4:
                        diagnostics.append(Diagnostic("GMV025", "error", "targeted collision event has no collisionObjectId; target cannot be inferred safely", resource.path, resource=resource.name))
                    else:
                        diagnostics.append(Diagnostic("GMV021", "warning", f"unknown object event type: {event_type}", resource.path, resource=resource.name))
                    continue
                declared.add(filename.casefold())
                source_path = resource.path.parent / filename
                if not source_path.is_file():
                    diagnostics.append(Diagnostic("GMV022", "error", f"declared event source is missing: {filename}", source_path, resource=resource.name))
            known_prefixes = tuple(f"{prefix}_" for prefix in EVENT_PREFIXES.values())
            for source_path in resource.path.parent.glob("*.gml"):
                if source_path.name.startswith(known_prefixes) and source_path.name.casefold() not in declared:
                    diagnostics.append(Diagnostic("GMV023", "warning", f"event source has no descriptor declaration: {source_path.name}", source_path, resource=resource.name))

        if resource.type == "GMShader":
            for suffix in (".vsh", ".fsh"):
                source_path = resource.path.with_suffix(suffix)
                if not source_path.is_file():
                    diagnostics.append(Diagnostic("GMV030", "error", f"shader stage is missing: {source_path.name}", source_path, resource=resource.name))

        if resource.type == "GMSprite":
            for frame in resource.descriptor.get("frames") or []:
                if not isinstance(frame, dict):
                    diagnostics.append(Diagnostic("GMV060", "error", "sprite frame entry is not an object", resource.path, resource=resource.name))
                    continue
                frame_name = frame.get("name") or frame.get("%Name")
                if isinstance(frame_name, str):
                    image_path = resource.path.parent / f"{frame_name}.png"
                    if not image_path.is_file():
                        diagnostics.append(Diagnostic("GMV061", "error", f"sprite frame image is missing: {image_path.name}", image_path, resource=resource.name))
                else:
                    diagnostics.append(Diagnostic("GMV062", "error", "sprite frame has no stable name", resource.path, resource=resource.name))

        if resource.type == "GMRoom":
            creation_value = resource.descriptor.get("creationCodeFile")
            if isinstance(creation_value, str) and creation_value:
                creation_path = index.root / Path(creation_value.replace("/", "\\"))
                if not creation_path.is_file():
                    diagnostics.append(Diagnostic("GMV063", "error", f"room creation code is missing: {creation_value}", creation_path, resource=resource.name))
            instance_ids: set[str] = set()
            for layer in resource.descriptor.get("layers") or []:
                if not isinstance(layer, dict):
                    continue
                for instance in layer.get("instances") or []:
                    if not isinstance(instance, dict):
                        continue
                    instance_name = instance.get("name")
                    if isinstance(instance_name, str):
                        if instance_name in instance_ids:
                            diagnostics.append(Diagnostic("GMV064", "error", f"duplicate room instance id: {instance_name}", resource.path, resource=resource.name))
                        instance_ids.add(instance_name)

        for source in resource.sources:
            if not source.path.is_file():
                diagnostics.append(Diagnostic("GMV031", "error", f"source file is missing for {source.label}", source.path, resource=resource.name))

        for reference_name, reference_path in _walk_references(resource.descriptor):
            normalized = reference_path.replace("\\", "/").casefold()
            if normalized.startswith(("folders/", "texturegroups/", "audiogroups/", "configs/", "tags/")):
                continue
            target = index.root / Path(reference_path.replace("/", "\\"))
            if not target.exists() and normalized not in registered_paths:
                diagnostics.append(Diagnostic("GMV040", "error", f"reference target is missing: {reference_name} -> {reference_path}", resource.path, resource=resource.name))

    for included in index.included_files:
        if not isinstance(included, dict):
            continue
        file_name = included.get("name")
        directory = included.get("filePath", "")
        if isinstance(file_name, str) and isinstance(directory, str):
            included_path = index.root / Path(directory.replace("/", "\\")) / file_name
            if not included_path.is_file():
                diagnostics.append(Diagnostic("GMV070", "error", f"included file is missing: {included_path.relative_to(index.root).as_posix()}", included_path, source="metadata"))

    order_file = index.project_file.with_suffix(".resource_order")
    if order_file.exists():
        try:
            order_doc = load(order_file)
            for section in ("ResourceOrderSettings", "FolderOrderSettings"):
                for entry in order_doc.value.get(section, []) if isinstance(order_doc.value, dict) else []:
                    if not isinstance(entry, dict):
                        continue
                    path = entry.get("path")
                    if isinstance(path, str) and not path.startswith("folders/"):
                        if path.casefold() not in registered_paths:
                            diagnostics.append(Diagnostic("GMV050", "warning", f"resource-order entry is stale: {path}", order_file, source="metadata"))
        except ParseError as exc:
            diagnostics.append(Diagnostic("GMV001", "error", str(exc), order_file, exc.line, exc.column, source="metadata"))

    return diagnostics
