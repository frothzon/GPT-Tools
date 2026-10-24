"""Authoritative executable recipe registry and version gates."""
from __future__ import annotations

RECIPE_NAMES = '''types list info set create delete
object-event-create object-event-delete object-event-list object-event-change object-event-set-gml
room-instance-create room-asset-create room-item-list room-item-delete room-layer-create room-layer-delete room-layer-list
script-set-file shader-set-file note-set-file sprite-frame-add sprite-frame-delete sound-set-file
tileset-create tileset-delete tileset-rename tileset-set-sprite
room-tiles-get room-tiles-set room-tiles-list room-tiles-resize
path-add-point path-info path-delete-point
font-range-list font-add-range font-remove-range font-kerning-list font-add-kerning font-remove-kerning font-glyph-list font-set-file
folder-list folder-create options-list options-get options-info options-set
prefab-list prefab-info prefab-add-reference prefab-remove-reference prefab-customise
audio-group-create audio-group-delete audio-group-rename audio-group-list audio-group-usages audio-group-set
texture-group-create texture-group-delete texture-group-rename texture-group-list texture-group-usages texture-group-set
config-create config-delete config-rename config-list config-usages config-get-active config-set-active'''.split()

READ_RECIPES = {"types", "list", "info"} | {n for n in RECIPE_NAMES if n.endswith(("-list", "-info", "-get", "-usages", "-get-active"))}
TYPE_FAMILY = {"script": "scripts", "object": "objects-events", "shader": "shaders", "room": "rooms", "sprite": "sprites", "sound": "sounds-audio", "path": "paths", "font": "fonts-tilesets", "tileset": "fonts-tilesets", "note": "notes"}
PREFIX_FAMILY = {"object": "objects-events", "room": "rooms", "script": "scripts", "shader": "shaders", "note": "notes", "sprite": "sprites", "sound": "sounds-audio", "tileset": "fonts-tilesets", "font": "fonts-tilesets", "path": "paths", "folder": "folders-order-tags", "options": "configurations-options", "config": "configurations-options", "audio": "groups-prefabs-packages", "texture": "groups-prefabs-packages", "prefab": "groups-prefabs-packages"}

def recipes(project=None):
    known = project is None or (str(project.get("ideVersion", "")).startswith("2024.14.") and project.get("resourceVersion") == "2.0")
    return [{"name": n, "family": PREFIX_FAMILY.get(n.split("-")[0], "selected-resource"),
             "status": "blocked-schema" if n == "set" else "implemented" if known or n in READ_RECIPES else "blocked-version",
             "mutating": n not in READ_RECIPES, "cloneRequired": True,
             "supportedProfiles": ["2024.14.* / resource 2.0"], "evidence": ["tests/test_resource_api.py", "tests/test_workflow.py"]} for n in RECIPE_NAMES]

def family_contracts(project=None):
    result = {}
    for name, data in FAMILIES.items():
        implemented = set(data["implemented"])
        specific = [r for r in recipes(project) if r["family"] == name and r["status"] == "implemented"]
        for recipe in specific:
            operation = recipe["name"]
            if operation.endswith("-create"): implemented.add("create")
            elif operation.endswith("-delete"): implemented.add("delete")
            elif operation.endswith("-rename"): implemented.add("rename")
            elif recipe["mutating"]: implemented.add("patch")
        if project and not str(project.get("ideVersion", "")).startswith("2024.14."):
            implemented -= {"create", "ensure", "patch", "rename", "move", "duplicate", "delete", "import"}
        result[name] = {**data, "implemented": sorted(implemented), "recipes": [r["name"] for r in specific],
                        "note": data["note"] + " Recipe support is listed explicitly; this does not establish the full lifecycle contract."}
    return result

def assert_mutation_supported(index, operation, options=None):
    if operation not in RECIPE_NAMES:
        raise ValueError("unsupported resource recipe")
    if operation in READ_RECIPES:
        return
    if not str(index.ide_version).startswith("2024.14.") or index.resource_version != "2.0":
        raise ValueError(f"resource mutation blocked for unverified format profile {index.ide_version}/{index.resource_version}")
    options = options or {}
    if operation == "create" and options.get("type", "").casefold() not in {"script", "object", "room", "shader"}:
        raise ValueError("generic create is not verified for this resource family")
    if operation == "delete":
        resource = index.resources_by_name.get(str(options.get("name", "")).casefold())
        if resource is None or resource.type not in {"GMScript", "GMObject", "GMRoom", "GMTileSet"}:
            raise ValueError("generic delete is not verified for this resource family")
    if operation == "set":
        raise ValueError("generic property expressions need deliberate resource-tool use; no verified recipe schema")

def schema():
    return {"schemaVersion": 1, "required": ["operations"], "operationKinds": {
        "patch": {"required": ["spec", "expectedHash"], "oneOf": ["edits[{old,new}]", "unifiedDiff"]},
        "replace": {"required": ["spec", "expectedHash", "from"]},
        "resource": {"required": ["operation", "options"], "choices": RECIPE_NAMES}},
        "requiredChecks": ["structure", "syntax", "compile"], "optionalChecks": ["scenario"]}

from typing import Any

# This is deliberately data, rather than a claim inferred from the number of
# fields a .yy file happens to contain.  A family is only marked implemented
# when the corresponding workflow is guarded, tested, and exposed by gmtool.
OPERATIONS = [
    "discover",
    "describe",
    "create",
    "ensure",
    "patch",
    "rename",
    "move",
    "duplicate",
    "delete",
    "import",
    "export",
    "dependencies",
    "preview",
    "validate",
    "roundtrip",
    "build_test",
    "recover",
]

FAMILIES: dict[str, dict[str, Any]] = {
    "project": {"status": "partial", "implemented": ["discover", "describe", "dependencies", "validate", "recover", "build_test"], "note": "Read/index/validate plus guarded compile; structural recipe mutations are pending."},
    "folders-order-tags": {"status": "partial", "implemented": ["discover", "describe", "validate", "preview", "recover"], "note": "Indexed and checked; domain mutations are pending."},
    "configurations-options": {"status": "partial", "implemented": ["discover", "describe", "validate", "recover"], "note": "Preserved and surfaced through project metadata; target-specific recipe editing is pending."},
    "scripts": {"status": "partial", "implemented": ["discover", "describe", "create", "patch", "delete", "export", "dependencies", "preview", "validate", "roundtrip", "build_test", "recover"], "note": "Logical source reads/writes, diagnostics, repair, compile, and ResourceTool-backed create/delete are implemented; generic rename/import/ensure remain pending."},
    "objects-events": {"status": "partial", "implemented": ["discover", "describe", "create", "patch", "delete", "dependencies", "preview", "validate", "roundtrip", "build_test", "recover"], "note": "Event mapping, source editing, and ResourceTool-backed event create/delete are implemented; full object property recipes remain pending."},
    "shaders": {"status": "partial", "implemented": ["discover", "describe", "create", "patch", "dependencies", "preview", "validate", "roundtrip", "build_test", "recover"], "note": "Vertex/fragment source workflow and stage-file recipes are implemented; full shader property/import adapters remain pending."},
    "rooms": {"status": "partial", "implemented": ["discover", "describe", "patch", "create", "delete", "dependencies", "preview", "validate", "roundtrip", "build_test", "recover"], "note": "Room/layer/instance/asset/tile inspection, static preview, and ResourceTool-backed layer/item recipes are implemented; full room settings/UI adapters remain pending."},
    "sprites": {"status": "partial", "implemented": ["discover", "describe", "patch", "dependencies", "preview", "validate", "roundtrip", "recover"], "note": "Descriptor/index, contact-sheet preview, and frame recipes are implemented; full image/layer/import adapters remain pending."},
    "sounds-audio": {"status": "partial", "implemented": ["discover", "describe", "patch", "dependencies", "preview", "validate", "roundtrip", "recover"], "note": "WAV metadata/waveform preview and sound-file recipes are implemented; codec transcode and routing adapters remain pending."},
    "paths": {"status": "partial", "implemented": ["discover", "describe", "patch", "dependencies", "preview", "validate", "roundtrip", "recover"], "note": "Path inspection, plot preview, and point recipes are implemented; import/export and constraint adapters remain pending."},
    "fonts-tilesets": {"status": "partial", "implemented": ["discover", "describe", "patch", "dependencies", "preview", "validate", "roundtrip", "recover"], "note": "Safe discovery, tile/font recipes, and generic previews are available; raster/glyph atlas authoring remains pending."},
    "timelines-sequences-curves": {"status": "partial", "implemented": ["discover", "describe", "dependencies", "preview", "validate", "roundtrip", "recover"], "note": "Generic discovery is available; track/keyframe adapters are pending."},
    "particles": {"status": "partial", "implemented": ["discover", "describe", "dependencies", "preview", "validate", "roundtrip", "recover"], "note": "Generic discovery is available; deterministic particle authoring is pending."},
    "extensions-included-files": {"status": "partial", "implemented": ["discover", "describe", "dependencies", "preview", "validate", "recover"], "note": "Inventory and safety checks are available; package/import mutation is pending."},
    "notes": {"status": "partial", "implemented": ["discover", "describe", "patch", "preview", "validate", "recover"], "note": "Logical text/Markdown access is implemented; ResourceTool-backed note recipes are pending."},
    "groups-prefabs-packages": {"status": "partial", "implemented": ["discover", "describe", "dependencies", "validate", "recover"], "note": "Metadata is preserved and indexed; package/prefab mutation is pending."},
    "unknown-future-types": {"status": "implemented", "implemented": ["discover", "describe", "export", "validate", "recover"], "note": "Unknown descriptors are retained and exportable but intentionally immutable."},
}

