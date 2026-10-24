from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from .discovery import discover_project
from .lossless_json import load
from .model import ProjectIndex, ResourceRecord, SourceFile


EVENT_PREFIXES = {
    0: "Create",
    1: "Destroy",
    2: "Alarm",
    3: "Step",
    4: "Collision",
    5: "Keyboard",
    6: "Mouse",
    7: "Other",
    8: "Draw",
    9: "KeyPress",
    10: "KeyRelease",
    11: "Trigger",
    12: "CleanUp",
    13: "Gesture",
    14: "PreCreate",
}

_EVENT_SUBTYPES = {
    (3, 0): "Step",
    (3, 1): "Step.Begin",
    (3, 2): "Step.End",
    (8, 0): "Draw",
    (8, 64): "Draw.GUI",
    (8, 72): "Draw.Begin",
    (8, 73): "Draw.End",
    (8, 74): "Draw.GUIBegin",
    (8, 75): "Draw.GUIEnd",
    (7, 2): "Other.GameStart",
    (7, 3): "Other.GameEnd",
    (7, 4): "Other.RoomStart",
    (7, 5): "Other.RoomEnd",
    (7, 7): "Other.AnimationEnd",
    (7, 8): "Other.EndOfPath",
}


def event_filename(event_type: int, event_num: int, collision_object: Any = None, ide_version: str | None = None) -> str | None:
    if event_type == 4 and isinstance(collision_object, dict) and collision_object.get("name"):
        name = collision_object["name"]
        if not isinstance(name, str) or not name.replace("_", "").isalnum():
            raise ValueError("invalid collision target name")
        return f"Collision_{name}.gml"
    if event_type == 4 and str(ide_version).startswith("2024.14."):
        return None
    prefix = EVENT_PREFIXES.get(event_type)
    return f"{prefix}_{event_num}.gml" if prefix else None


def event_label(event_type: int, event_num: int, collision_object: Any = None) -> str:
    if event_type == 4 and isinstance(collision_object, dict) and collision_object.get("name"):
        return f"Collision.{collision_object['name']}"
    if (event_type, event_num) in _EVENT_SUBTYPES:
        return _EVENT_SUBTYPES[(event_type, event_num)]
    prefix = EVENT_PREFIXES.get(event_type, f"Event{event_type}")
    if event_num == 0 and event_type in {0, 1, 12, 14}:
        return prefix
    return f"{prefix}.{event_num}"


def _source_kind(path: Path) -> str:
    return {
        ".gml": "gml",
        ".vsh": "shader-vertex",
        ".fsh": "shader-fragment",
        ".md": "markdown",
        ".json": "json",
    }.get(path.suffix.casefold(), "text")


def _generic_sources(directory: Path, extensions: Iterable[str]) -> list[SourceFile]:
    result: list[SourceFile] = []
    allowed = {extension.casefold() for extension in extensions}
    for path in sorted(directory.glob("*")):
        if path.is_file() and path.suffix.casefold() in allowed:
            result.append(SourceFile(path.stem, path, _source_kind(path), (path.name,)))
    return result


def _object_sources(directory: Path, descriptor: dict[str, Any], ide_version: str | None = None) -> list[SourceFile]:
    result: list[SourceFile] = []
    claimed: set[Path] = set()
    events = descriptor.get("eventList") or []
    if isinstance(events, list):
        for event in events:
            if not isinstance(event, dict):
                continue
            event_type = event.get("eventType")
            event_num = event.get("eventNum")
            if not isinstance(event_type, int) or not isinstance(event_num, int):
                continue
            filename = event_filename(event_type, event_num, event.get("collisionObjectId"), ide_version)
            if not filename:
                continue
            path = directory / filename
            label = event_label(event_type, event_num, event.get("collisionObjectId"))
            result.append(SourceFile(label, path, "gml", (path.stem, path.name)))
            claimed.add(path.resolve())
    for source in _generic_sources(directory, {".gml"}):
        if source.path.resolve() not in claimed:
            result.append(source)
    return result


def _sources_for(path: Path, descriptor: dict[str, Any], resource_type: str, ide_version: str | None = None) -> list[SourceFile]:
    directory = path.parent
    if resource_type == "GMObject":
        return _object_sources(directory, descriptor, ide_version)
    if resource_type == "GMScript":
        sources = _generic_sources(directory, {".gml"})
        return [
            SourceFile("code" if source.path.stem == path.stem else source.label, source.path, source.kind, source.aliases)
            for source in sources
        ]
    if resource_type == "GMShader":
        result: list[SourceFile] = []
        for suffix, label, kind in ((".vsh", "vertex", "shader-vertex"), (".fsh", "fragment", "shader-fragment")):
            source = directory / f"{path.stem}{suffix}"
            result.append(SourceFile(label, source, kind, (source.stem, source.name)))
        return result
    if resource_type == "GMRoom":
        result = _generic_sources(directory, {".gml"})
        return [
            SourceFile("CreationCode" if source.path.name == "RoomCreationCode.gml" else source.label, source.path, source.kind, source.aliases)
            for source in result
        ]
    if resource_type == "GMNotes":
        return _generic_sources(directory, {".md", ".txt"})
    if resource_type in {"GMTimeline", "GMExtension"}:
        return _generic_sources(directory, {".gml", ".js", ".cpp", ".c", ".h", ".cs", ".java"})
    return []


def build_index(value: str | Path | None) -> ProjectIndex:
    project_file = discover_project(value)
    root = project_file.parent
    project_doc = load(project_file)
    project = project_doc.value
    if not isinstance(project, dict):
        raise ValueError(f"project root must be an object: {project_file}")

    metadata = project.get("MetaData") or {}
    ide_version = metadata.get("IDEVersion") if isinstance(metadata, dict) else None
    resources: list[ResourceRecord] = []
    for entry in project.get("resources") or []:
        if not isinstance(entry, dict):
            continue
        identity = entry.get("id")
        if not isinstance(identity, dict):
            continue
        name = identity.get("name")
        relative_path = identity.get("path")
        if not isinstance(name, str) or not isinstance(relative_path, str):
            continue
        from .workspace import contained
        descriptor_path = contained(root, Path(relative_path.replace("/", "\\")))
        descriptor: dict[str, Any] = {}
        resource_type = "Unknown"
        parent: dict[str, Any] | None = None
        if descriptor_path.is_file():
            document = load(descriptor_path)
            if isinstance(document.value, dict):
                descriptor = document.value
                resource_type = str(descriptor.get("resourceType") or "Unknown")
                parent_value = descriptor.get("parent")
                parent = parent_value if isinstance(parent_value, dict) else None
        resources.append(
            ResourceRecord(
                name=name,
                type=resource_type,
                path=descriptor_path,
                descriptor=descriptor,
                parent=parent,
                sources=_sources_for(descriptor_path, descriptor, resource_type, ide_version),
            )
        )

    metadata = project.get("MetaData") or {}
    return ProjectIndex(
        project_file=project_file,
        root=root,
        name=str(project.get("name") or project.get("%Name") or project_file.stem),
        ide_version=metadata.get("IDEVersion") if isinstance(metadata, dict) else None,
        resource_version=project.get("resourceVersion"),
        resources=resources,
        folders=list(project.get("Folders") or []),
        included_files=list(project.get("IncludedFiles") or []),
        audio_groups=list(project.get("AudioGroups") or []),
        texture_groups=list(project.get("TextureGroups") or []),
        room_order=list(project.get("RoomOrderNodes") or []),
        raw_project=project,
    )


def find_resources(index: ProjectIndex, query: str) -> list[ResourceRecord]:
    needle = query.casefold()
    matches: list[ResourceRecord] = []
    for resource in index.resources:
        fields = [resource.name, resource.type, resource.path.as_posix()]
        fields.extend(source.label for source in resource.sources)
        fields.extend(alias for source in resource.sources for alias in source.aliases)
        if any(needle in field.casefold() for field in fields):
            matches.append(resource)
    return matches


def resolve(index: ProjectIndex, spec: str) -> tuple[ResourceRecord, SourceFile | None]:
    exact = index.resources_by_name.get(spec.casefold())
    if exact:
        return exact, None

    candidates = sorted(index.resources, key=lambda item: len(item.name), reverse=True)
    for resource in candidates:
        prefix = resource.name + "."
        if not spec.casefold().startswith(prefix.casefold()):
            continue
        suffix = spec[len(prefix) :].casefold()
        matches = []
        for source in resource.sources:
            names = {source.label.casefold(), source.path.stem.casefold(), source.path.name.casefold()}
            names.update(alias.casefold() for alias in source.aliases)
            if suffix in names:
                matches.append(source)
        if len(matches) > 1:
            raise KeyError(f"ambiguous source {spec}: " + ", ".join(s.label for s in matches))
        if matches:
            return resource, matches[0]
    raise KeyError(f"resource or source not found: {spec}")


def inheritance_chain(index: ProjectIndex, resource: ResourceRecord) -> list[ResourceRecord]:
    chain = [resource]
    seen = {resource.name.casefold()}
    while isinstance(chain[-1].descriptor.get("parentObjectId"), dict):
        name = chain[-1].descriptor["parentObjectId"].get("name", "").casefold()
        if name in seen:
            raise ValueError("object inheritance cycle")
        parent = index.resources_by_name.get(name)
        if parent is None:
            break
        seen.add(name)
        chain.append(parent)
    return chain


def resolve_effective(index: ProjectIndex, spec: str) -> tuple[ResourceRecord, SourceFile | None]:
    try:
        return resolve(index, spec)
    except KeyError as error:
        if "ambiguous" in str(error):
            raise
        for resource in sorted(index.resources, key=lambda r: len(r.name), reverse=True):
            prefix = resource.name + "."
            if spec.casefold().startswith(prefix.casefold()) and resource.type == "GMObject":
                suffix = spec[len(prefix):]
                for parent in inheritance_chain(index, resource)[1:]:
                    try:
                        return resolve(index, parent.name + "." + suffix)
                    except KeyError:
                        continue
        raise
