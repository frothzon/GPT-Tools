"""Package animation projects as portable GameMaker local asset packages."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import zipfile

from . import gml_codegen, project
from .gml_utils import safe_slug
from gmtool.lossless_json import load as load_gm_json

SCRIPT_NAME = "scr_scml_spriter_interface_system"
SCRIPT_PATH = f"scripts/{SCRIPT_NAME}/{SCRIPT_NAME}.yy"
GUIDE_NAME = "Spriter_Interface_System.md"


def _uuid(key: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "gmtool-animation:" + key))


def _folder(name: str, path: str) -> dict:
    return {"$GMFolder": "", "%Name": name, "folderPath": path,
            "name": name, "resourceType": "GMFolder", "resourceVersion": "2.0"}


def _sprite_yy(name: str, width: int, height: int, frame: str, parent_path: str, parent_name: str) -> dict:
    layer = _uuid(name + ":layer")
    key = _uuid(name + ":key")
    def store(kind: str) -> dict:
        return {"$KeyframeStore<" + kind + ">": "", "Keyframes": [],
                "resourceType": "KeyframeStore<" + kind + ">", "resourceVersion": "2.0"}
    return {
        "$GMSprite": "v2", "%Name": name, "bboxMode": 0, "bbox_bottom": height - 1,
        "bbox_left": 0, "bbox_right": width - 1, "bbox_top": 0, "collisionKind": 1,
        "collisionTolerance": 0, "DynamicTexturePage": False, "edgeFiltering": False,
        "For3D": False,
        "frames": [{"$GMSpriteFrame": "v1", "%Name": frame, "name": frame,
                    "resourceType": "GMSpriteFrame", "resourceVersion": "2.0"}],
        "gridX": 0, "gridY": 0, "height": height, "HTile": False,
        "layers": [{"$GMImageLayer": "", "%Name": layer, "blendMode": 0,
                    "displayName": "default", "isLocked": False, "name": layer,
                    "opacity": 100.0, "resourceType": "GMImageLayer",
                    "resourceVersion": "2.0", "visible": True}],
        "name": name, "nineSlice": None, "origin": 0,
        "parent": {"name": parent_name, "path": parent_path}, "preMultiplyAlpha": False,
        "resourceType": "GMSprite", "resourceVersion": "2.0",
        "sequence": {"$GMSequence": "v1", "%Name": name, "autoRecord": True,
            "backdropHeight": 768, "backdropImageOpacity": 0.5, "backdropImagePath": "",
            "backdropWidth": 1366, "backdropXOffset": 0.0, "backdropYOffset": 0.0,
            "events": store("MessageEventKeyframe"), "eventStubScript": None,
            "eventToFunction": {}, "length": 1.0, "lockOrigin": False,
            "moments": store("MomentsEventKeyframe"), "name": name, "playback": 1,
            "playbackSpeed": 15.0, "playbackSpeedType": 0,
            "resourceType": "GMSequence", "resourceVersion": "2.0",
            "showBackdrop": True, "showBackdropImage": False, "timeUnits": 1,
            "tracks": [{"$GMSpriteFramesTrack": "", "builtinName": 0, "events": [],
                "inheritsTrackColour": True, "interpolation": 1, "isCreationTrack": False,
                "keyframes": {"$KeyframeStore<SpriteFrameKeyframe>": "", "Keyframes": [{
                    "$Keyframe<SpriteFrameKeyframe>": "", "Channels": {"0": {
                        "$SpriteFrameKeyframe": "", "Id": {"name": frame,
                        "path": f"sprites/{name}/{name}.yy"},
                        "resourceType": "SpriteFrameKeyframe", "resourceVersion": "2.0"}},
                    "Disabled": False, "id": key, "IsCreationKey": False, "Key": 0.0,
                    "Length": 1.0, "resourceType": "Keyframe<SpriteFrameKeyframe>",
                    "resourceVersion": "2.0", "Stretch": False}],
                    "resourceType": "KeyframeStore<SpriteFrameKeyframe>", "resourceVersion": "2.0"},
                "modifiers": [], "name": "frames", "resourceType": "GMSpriteFramesTrack",
                "resourceVersion": "2.0", "spriteId": None, "trackColour": 0,
                "tracks": [], "traits": 0}], "visibleRange": None, "volume": 1.0,
            "xorigin": 0, "yorigin": 0},
        "swatchColours": None, "swfPrecision": 0.5,
        "textureGroupId": {"name": "Default", "path": "texturegroups/Default"},
        "type": 0, "VTile": False, "width": width,
    }


def find_projecttool(template: Path) -> Path | None:
    explicit = os.environ.get("PROJECTTOOL")
    if explicit and Path(explicit).is_file():
        return Path(explicit).resolve()
    roots = [template.parent, Path(__file__).resolve().parents[3]]
    for root in roots:
        cache = root / ".gmcache" / "project-tool"
        if cache.is_dir():
            found = sorted(cache.rglob("ProjectTool.exe"))
            if found:
                return found[0].resolve()
    for program_files in (os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)")):
        if program_files:
            candidate = Path(program_files) / "GameMaker/packages/gm-tools/project-tool-win-x64/ProjectTool.exe"
            if candidate.is_file():
                return candidate.resolve()
    import shutil as _shutil
    resolved = _shutil.which("ProjectTool")
    return Path(resolved).resolve() if resolved else None


def _resource(name: str, path: str) -> dict:
    return {"id": {"name": name, "path": path}}


def _register_with_projecttool(tool: Path, root: Path, project_doc: dict, resources: list[dict]) -> list[dict]:
    """Register resource descriptors in a disposable ProjectTool receiver."""
    source = copy.deepcopy(project_doc)
    source["resources"] = resources
    source["RoomOrderNodes"] = []
    source["IncludedFiles"] = []
    source_path = root / "package_source.yyp"
    source_path.write_text(json.dumps(source, ensure_ascii=False), encoding="utf-8")
    receiver = copy.deepcopy(source)
    receiver["resources"] = []
    receiver_path = root / "registration" / "registration.yyp"
    receiver_path.parent.mkdir(parents=True)
    receiver_path.write_text(json.dumps(receiver, ensure_ascii=False), encoding="utf-8")
    options = root / "options"
    options.mkdir(exist_ok=True)
    receiver_options = receiver_path.parent / "options"
    if options.is_dir():
        shutil.copytree(options, receiver_options, dirs_exist_ok=True)
    quote = lambda p: '"' + str(p).replace("\\", "/").replace('"', '\\"') + '"'
    imports = ",".join((root / item["id"]["path"]).as_posix() for item in resources)
    script = root / "register.script"
    script.write_text("\n".join([
        f"PROJECT OPEN SOURCE={quote(receiver_path)} READONLY=FALSE",
        f"IMPORT YY SOURCES={quote(imports)}",
        f"PROJECT SAVE DESTINATION={quote(receiver_path)}", ""]), encoding="utf-8")
    result = subprocess.run([str(tool), "SCRIPT", "PATH=" + str(script)], capture_output=True,
        text=True, encoding="utf-8", errors="replace", timeout=180,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    (root / "projecttool-registration.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    try:
        actual = load_gm_json(receiver_path).value.get("resources", [])
    except Exception as exc:
        raise project.AnimationError(f"ProjectTool registration did not produce a readable project; see {root / 'projecttool-registration.log'}") from exc
    expected_map = {r["id"]["name"]: r["id"]["path"] for r in resources}
    actual_map = {r["id"]["name"]: r["id"]["path"] for r in actual}
    if result.returncode or actual_map != expected_map:
        raise project.AnimationError(f"ProjectTool could not register the staged resources; see {root / 'projecttool-registration.log'}")
    return actual


def export_yymps(model: dict, assets: dict[str, bytes], template_project: str | Path,
                 output: str | Path, project_tool: str | Path | None = None) -> dict:
    """Build a complete sprites/runtime/demo YYMPS without changing the selected project."""
    template = Path(template_project).expanduser().resolve()
    output = Path(output).expanduser().resolve()
    if template.suffix.lower() != ".yyp" or not template.is_file():
        raise project.AnimationError("Choose an existing GameMaker .yyp as the project-format template.")
    tool = Path(project_tool).expanduser().resolve() if project_tool else find_projecttool(template)
    if not tool or not tool.is_file():
        raise project.AnimationError("The official ProjectTool executable was not found. Set PROJECTTOOL or use --project-tool.")
    if not model.get("collections") or not any(c.get("entities") for c in model["collections"]):
        raise project.AnimationError("Import at least one character before exporting a YYMPS.")
    project.validate_project(model, assets)
    template_data = load_gm_json(template).value
    if not template_data.get("MetaData", {}).get("IDEVersion"):
        raise project.AnimationError("The selected GameMaker project has no IDEVersion metadata.")

    generated = copy.deepcopy(model)
    project_id = model.get("id", project.uid())
    suffix = hashlib.sha256(project_id.encode("utf-8")).hexdigest()[:8]
    folders = [
        _folder("SCML-custom", "folders/SCML-custom.yy"),
        _folder("System", "folders/SCML-custom/System.yy"),
        _folder("Imports", "folders/SCML-custom/Imports.yy"),
        _folder("Demo", "folders/SCML-custom/Demo.yy"),
    ]
    resources: list[dict] = []
    outputs: dict[str, bytes] = {}
    used_names: set[str] = set()
    used_collection_folders: set[str] = set()
    for collection in generated["collections"]:
        key = safe_slug(collection.get("key") or "import")
        if key in used_collection_folders:
            raise project.AnimationError(f"Collection keys collide after GameMaker-safe naming: {collection.get('key')!r}")
        used_collection_folders.add(key)
        imports_folder = f"folders/SCML-custom/Imports/{key}.yy"
        sprites_folder = imports_folder[:-3] + "/Sprites.yy"
        folders.extend([_folder(collection.get("key") or key, imports_folder),
                        _folder("Sprites", sprites_folder)])
        parent = {"name": "Sprites", "path": sprites_folder}
        for entity in collection.get("entities", []):
            entity_slug = safe_slug(entity["name"])
            for index, info in enumerate(entity.get("files", [])):
                # Names include stable model/entity/file identity to avoid slug collisions.
                digest = hashlib.sha256((collection["id"] + entity["id"] + str(index) + info["asset_id"]).encode()).hexdigest()[:7]
                name = f"spr_scmlsi_{suffix}_{key}_{entity_slug}_{index:03}_{digest}"
                if name in used_names:
                    raise project.AnimationError(f"Generated duplicate sprite name: {name}")
                used_names.add(name)
                info["sprite_name"] = info["sprite"] = name
                width, height = int(info["width"]), int(info["height"])
                frame = _uuid(name + ":frame")
                sprite_path = f"sprites/{name}/{name}.yy"
                layer = _uuid(name + ":layer")
                image = assets[info["asset_id"]]
                outputs[sprite_path] = json.dumps(_sprite_yy(name, width, height, frame, sprites_folder, "Sprites"), ensure_ascii=False, indent=2).encode("utf-8")
                outputs[f"sprites/{name}/{frame}.png"] = image
                outputs[f"sprites/{name}/layers/{frame}/{layer}.png"] = image
                resources.append(_resource(name, sprite_path))

    # All collections and generated sprites are embedded in one self-contained GML script.
    runtime_collections = [{"id": collection["id"], "key": collection["key"],
                            "model": {"entities": collection.get("entities", [])}}
                           for collection in generated["collections"]]
    script_source = gml_codegen.system_source(runtime_collections)
    outputs[f"scripts/{SCRIPT_NAME}/{SCRIPT_NAME}.gml"] = script_source.encode("utf-8")
    script_yy = {"$GMScript": "v1", "%Name": SCRIPT_NAME, "isCompatibility": False,
        "isDnD": False, "name": SCRIPT_NAME,
        "parent": {"name": "System", "path": "folders/SCML-custom/System.yy"},
        "resourceType": "GMScript", "resourceVersion": "2.0"}
    outputs[SCRIPT_PATH] = json.dumps(script_yy, ensure_ascii=False, indent=2).encode("utf-8")
    outputs[f"scripts/{SCRIPT_NAME}/{GUIDE_NAME}"] = (gml_codegen.TEMPLATES / GUIDE_NAME).read_bytes()
    resources.append(_resource(SCRIPT_NAME, SCRIPT_PATH))

    demo_files, demo_resources = gml_codegen.demo_sources(generated["collections"], suffix)
    for path, data in demo_files.items():
        outputs[path] = data
    for item in demo_resources:
        resource_path = item["id"]["path"]
        name = item["id"]["name"]
        folder = "folders/SCML-custom/Demo.yy"
        raw = json.loads(outputs[resource_path].decode("utf-8"))
        raw["parent"] = {"name": "Demo", "path": folder}
        outputs[resource_path] = json.dumps(raw, ensure_ascii=False, indent=2).encode("utf-8")
        resources.append(item)
    # Build a clean, package-only project document from the chosen IDE/version profile.
    package_project = copy.deepcopy(template_data)
    package_project["resources"] = resources
    package_project["Folders"] = folders
    package_project["IncludedFiles"] = []
    demo_room = next((item for item in demo_resources if item["id"]["path"].startswith("rooms/")), None)
    package_project["RoomOrderNodes"] = ([{"roomId": copy.deepcopy(demo_room["id"])}] if demo_room else [])
    package_project["%Name"] = template.stem
    package_project["name"] = template.stem

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gmtool-animation-package-") as temporary:
        root = Path(temporary)
        for relative, data in outputs.items():
            destination = (root / relative).resolve()
            destination.relative_to(root.resolve())
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        options = template.parent / "options"
        if options.is_dir():
            shutil.copytree(options, root / "options", dirs_exist_ok=True)
        registered = _register_with_projecttool(tool, root, package_project, resources)
        package_project["resources"] = registered
        source_project = root / "package_source.yyp"
        source_project.write_text(json.dumps(package_project, ensure_ascii=False), encoding="utf-8")
        identifier = f"com.gmtool.scmlsi.{suffix}"
        command = (f'EXPORT SOURCE="{source_project.as_posix()}" DESTINATION="{output.as_posix()}" '
                   f'PACKAGETYPE=Package PACKAGEID={identifier} PACKAGENAME="{output.stem}" '
                   f'PACKAGEVERSION=1.0.0 INCLUDERESOURCES="{",".join(r["id"]["name"] for r in registered)}"\n')
        script = root / "export.script"
        script.write_text(command, encoding="utf-8")
        result = subprocess.run([str(tool), "SCRIPT", "PATH=" + str(script)], capture_output=True,
            text=True, encoding="utf-8", errors="replace", timeout=240,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        log_path = output.with_suffix(output.suffix + ".log")
        log_path.write_text(result.stdout + result.stderr, encoding="utf-8")
        if result.returncode or "Created package file:" not in result.stdout or not output.is_file():
            raise project.AnimationError(f"ProjectTool failed to export the YYMPS. Review {log_path}.")
        with zipfile.ZipFile(output) as archive:
            members = archive.namelist()
            sprite_yy_count = sum("/sprites/" in "/" + n and n.endswith(".yy") for n in members)
            script_count = sum(n.endswith(".gml") and "/scripts/" in "/" + n for n in members)
            if sprite_yy_count != len(used_names) or not any(n.endswith(".yy") and "/objects/" in "/" + n for n in members) or not any(n.endswith(".yy") and "/rooms/" in "/" + n for n in members) or script_count < 1:
                raise project.AnimationError("The exported YYMPS is missing one or more sprites, runtime scripts, demo object, or demo room.")
    return {"output": str(output), "bytes": output.stat().st_size,
            "collections": len(generated["collections"]),
            "entities": sum(len(c.get("entities", [])) for c in generated["collections"]),
            "animations": sum(len(e.get("animations", [])) for c in generated["collections"] for e in c.get("entities", [])),
            "sprites": len(used_names), "resources": len(resources),
            "demo": True, "project_tool": str(tool)}
