from __future__ import annotations

import re
from typing import Any


class ResourceRecipeError(ValueError):
    pass


_SAFE_TOKEN = re.compile(r"^[A-Za-z0-9_./:@+\-]+$")


def _value(value: str, *, name: str) -> str:
    if not value:
        raise ResourceRecipeError(f"{name} cannot be empty")
    if "\r" in value or "\n" in value:
        raise ResourceRecipeError(f"{name} cannot contain a newline")
    if name.casefold() in {"path", "file", "outfile"}:
        value = value.replace("\\", "/")
    if _SAFE_TOKEN.fullmatch(value):
        return value
    # ResourceTool accepts quoted argument values. Escape the two characters
    # that would otherwise terminate or alter the expression.
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _args(values: dict[str, Any]) -> str:
    rendered: list[str] = []
    for key, value in values.items():
        if value is None or value is False:
            continue
        if value is True:
            rendered.append(key.upper())
        else:
            rendered.append(f"{key.upper()}={_value(str(value), name=key)}")
    return " ".join(rendered)


def _require(options: dict[str, Any], *names: str) -> None:
    missing = [name for name in names if options.get(name) in (None, "")]
    if missing:
        raise ResourceRecipeError("missing required recipe argument(s): " + ", ".join(missing))


def build_expression(operation: str, options: dict[str, Any]) -> str:
    """Build a documented ResourceTool expression from agent-friendly args."""
    operation = operation.casefold()
    if operation == "types":
        return "RESOURCE TYPES"
    if operation == "list":
        return "RESOURCE LIST" + ((" " + _args({"type": options.get("type")})) if options.get("type") else "")
    if operation == "info":
        _require(options, "expr")
        expression = "RESOURCE INFO " + _args({"expr": options.get("expr"), "keys": options.get("keys"), "list": options.get("list")})
        return expression.rstrip()
    if operation == "set":
        _require(options, "expr", "value")
        return "RESOURCE SET " + _args({"expr": options.get("expr"), "value": options.get("value")})
    if operation == "create":
        _require(options, "type")
        return "RESOURCE CREATE " + _args({"type": options.get("type"), "name": options.get("name"), "parent": options.get("parent"), "folder": options.get("folder")})
    if operation == "delete":
        _require(options, "name")
        return "RESOURCE DELETE " + _args({"name": options.get("name"), "type": options.get("type"), "parent": options.get("parent"), "parenttype": options.get("parenttype")})

    if operation in {"object-event-create", "object-event-delete", "object-event-list", "object-event-change", "object-event-set-gml"}:
        action = {"object-event-create": "FINDORCREATE", "object-event-delete": "DELETE", "object-event-list": "LIST", "object-event-change": "CHANGE", "object-event-set-gml": "SETGMLFILE"}[operation]
        _require(options, "name", "type")
        values = {"name": options.get("name"), "type": options.get("type"), "subtype": options.get("subtype"), "collisionobject": options.get("collisionobject")}
        aliases = {"step": "step_normal", "begin": "step_begin", "end": "step_end"} if str(options.get("type", "")).casefold() == "step" else {"drawgui": "draw_gui"}
        values["subtype"] = aliases.get(str(values["subtype"]).casefold(), values["subtype"])
        if action == "CHANGE":
            _require(options, "newtype")
            values.update({"newtype": options.get("newtype"), "newsubtype": options.get("newsubtype"), "newcollisionobject": options.get("newcollisionobject")})
        if action == "SETGMLFILE":
            _require(options, "path")
            values["path"] = options.get("path")
        return "OBJECT EVENT " + action + " " + _args(values)

    if operation in {"room-instance-create", "room-asset-create"}:
        if operation == "room-instance-create":
            _require(options, "room", "object")
            action = "INSTANCE CREATE"
            values = {"room": options.get("room"), "object": options.get("object"), "name": options.get("name"), "layer": options.get("layer"), "x": options.get("x"), "y": options.get("y")}
        else:
            _require(options, "room")
            action = "ASSET CREATE"
            values = {"room": options.get("room"), "sprite": options.get("sprite"), "sequence": options.get("sequence"), "particlesystem": options.get("particlesystem"), "font": options.get("font"), "name": options.get("name"), "layer": options.get("layer"), "x": options.get("x"), "y": options.get("y")}
        return "ROOM " + action + " " + _args(values)
    if operation in {"room-item-list", "room-item-delete"}:
        action = "LIST" if operation.endswith("list") else "DELETE"
        if action == "DELETE":
            _require(options, "room", "item")
        values = {"room": options.get("room"), "layer": options.get("layer"), "layertype": options.get("layertype"), "item": options.get("item"), "itemtype": options.get("itemtype"), "all": options.get("all")}
        return "ROOM ITEM " + action + " " + _args(values)
    if operation in {"room-layer-create", "room-layer-delete", "room-layer-list"}:
        action = "CREATE" if operation.endswith("create") else "DELETE" if operation.endswith("delete") else "LIST"
        _require(options, "room")
        if action == "CREATE":
            _require(options, "name")
        elif action == "DELETE":
            _require(options, "layer")
        return "ROOM LAYER " + action + " " + _args({"room": options.get("room"), "name": options.get("name"), "layer": options.get("layer"), "type": options.get("type"), "parent": options.get("parent"), "depth": options.get("depth"), "layertype": options.get("layertype")})

    if operation == "script-set-file":
        _require(options, "name", "path")
        return "GML SETGMLFILE " + _args({"name": options.get("name"), "path": options.get("path")})
    if operation == "shader-set-file":
        _require(options, "name", "type", "path")
        return "SHADER SETFILEPATH " + _args({"name": options.get("name"), "type": options.get("type"), "path": options.get("path")})
    if operation == "note-set-file":
        _require(options, "name", "path")
        return "NOTE SETFILEPATH " + _args({"name": options.get("name"), "path": options.get("path")})
    if operation in {"sprite-frame-add", "sprite-frame-delete"}:
        action = "ADDFRAME" if operation.endswith("add") else "DELETEFRAME"
        _require(options, "name")
        _require(options, "path" if action == "ADDFRAME" else "index")
        values = {"name": options.get("name"), "path": options.get("path"), "frame": options.get("frame"), "index": options.get("index")}
        return "SPRITE " + action + " " + _args(values)
    if operation == "sound-set-file":
        _require(options, "name", "path")
        return "SOUND SETFILE " + _args({"name": options.get("name"), "path": options.get("path")})

    if operation in {"room-tiles-get", "room-tiles-set", "room-tiles-list", "room-tiles-resize"}:
        action = {"room-tiles-get": "GET", "room-tiles-set": "SET", "room-tiles-list": "LIST", "room-tiles-resize": "RESIZE"}[operation]
        _require(options, "room")
        if action in {"SET", "RESIZE"}:
            _require(options, "layer")
        values = {"room": options.get("room"), "layer": options.get("layer"), "left": options.get("left"), "top": options.get("top"), "width": options.get("width"), "height": options.get("height"), "data": options.get("data"), "file": options.get("file"), "repeatx": options.get("repeatx"), "repeaty": options.get("repeaty"), "transparent": options.get("transparent"), "padleft": options.get("padleft"), "padright": options.get("padright"), "padtop": options.get("padtop"), "padbottom": options.get("padbottom"), "trimleft": options.get("trimleft"), "trimright": options.get("trimright"), "trimtop": options.get("trimtop"), "trimbottom": options.get("trimbottom"), "outfile": options.get("outfile")}
        return "ROOM LAYER TILES " + action + " " + _args(values)

    if operation.startswith("tileset-"):
        action = {"tileset-create": "CREATE", "tileset-delete": "DELETE", "tileset-rename": "RENAME", "tileset-set-sprite": "SETSPRITE"}.get(operation)
        if action is None:
            raise ResourceRecipeError(f"unknown tileset operation: {operation}")
        _require(options, "name")
        if action == "RENAME":
            _require(options, "newname")
        if action == "SETSPRITE":
            _require(options, "sprite")
        return "TILESET " + action + " " + _args({"name": options.get("name"), "newname": options.get("newname"), "parent": options.get("parent"), "sprite": options.get("sprite"), "tilewidth": options.get("tilewidth"), "tileheight": options.get("tileheight"), "tilexoffset": options.get("tilexoffset"), "tileyoffset": options.get("tileyoffset"), "tilehsep": options.get("tilehsep"), "tilevsep": options.get("tilevsep"), "tilehborder": options.get("tilehborder"), "tilevborder": options.get("tilevborder")})

    if operation.startswith("path-"):
        action = {"path-add-point": "ADDPOINT", "path-info": "INFO", "path-delete-point": "DELETEPOINT"}.get(operation)
        if action is None:
            raise ResourceRecipeError(f"unknown path operation: {operation}")
        _require(options, "name")
        if action == "ADDPOINT":
            _require(options, "points")
        return "PATH " + action + " " + _args({"name": options.get("name"), "points": options.get("points"), "index": options.get("index"), "count": options.get("count")})

    if operation.startswith("font-"):
        action = {"font-range-list": "RANGELIST", "font-add-range": "ADDRANGE", "font-remove-range": "REMOVERANGE", "font-kerning-list": "KERNINGLIST", "font-add-kerning": "ADDKERNING", "font-remove-kerning": "REMOVEKERNING", "font-glyph-list": "GLYPHLIST", "font-set-file": "SETFILE"}.get(operation)
        if action is None:
            raise ResourceRecipeError(f"unknown font operation: {operation}")
        _require(options, "name")
        if action == "SETFILE":
            _require(options, "path")
        return "FONT " + action + " " + _args({"name": options.get("name"), "lower": options.get("lower"), "upper": options.get("upper"), "first": options.get("first"), "second": options.get("second"), "amount": options.get("amount"), "path": options.get("path")})

    if operation in {"folder-list", "folder-create"}:
        if operation == "folder-create":
            _require(options, "folder")
        return "FOLDER " + ("LIST" if operation == "folder-list" else "CREATE") + " " + _args({"folder": options.get("folder"), "type": options.get("type"), "resources": options.get("include_resources")})

    if operation.startswith("options-"):
        action = {"options-list": "LIST", "options-get": "GET", "options-info": "INFO", "options-set": "SET"}.get(operation)
        if action is None:
            raise ResourceRecipeError(f"unknown options operation: {operation}")
        if action != "LIST":
            _require(options, "platform")
        if action == "SET":
            _require(options, "property", "value")
        return "OPTIONS " + action + " " + _args({"platform": options.get("platform"), "property": options.get("property"), "value": options.get("value")})

    if operation.startswith("prefab-"):
        action = {"prefab-list": "LIST", "prefab-info": "INFO", "prefab-add-reference": "ADDREFERENCE", "prefab-remove-reference": "REMOVEREFERENCE", "prefab-customise": "CUSTOMISE"}.get(operation)
        if action is None:
            raise ResourceRecipeError(f"unknown prefab operation: {operation}")
        if action in {"INFO", "ADDREFERENCE", "REMOVEREFERENCE"}:
            _require(options, "collections")
        if action == "CUSTOMISE":
            _require(options, "collection", "prefab")
        return "PREFAB " + action + " " + _args({"downloaded": options.get("downloaded"), "referenced": options.get("referenced"), "forced": options.get("forced"), "collections": options.get("collections"), "collection": options.get("collection"), "prefab": options.get("prefab"), "name": options.get("name")})

    for prefix, command in (("audio-group-", "AUDIOGROUP"), ("texture-group-", "TEXTUREGROUP"), ("config-", "CONFIG")):
        if operation.startswith(prefix):
            suffix = operation[len(prefix):]
            action = {"create": "CREATE", "delete": "DELETE", "rename": "RENAME", "list": "LIST", "usages": "USAGES", "set": "SET", "get-active": "GETACTIVE", "set-active": "SETACTIVE"}.get(suffix)
            if action is None:
                raise ResourceRecipeError(f"unknown {prefix[:-1]} operation: {suffix}")
            if action in {"CREATE", "DELETE", "RENAME", "SETACTIVE"}:
                _require(options, "name")
            if action == "RENAME":
                _require(options, "newname")
            if action == "SET":
                _require(options, "group", "resources")
            if action == "SETACTIVE":
                _require(options, "name")
            return command + " " + action + " " + _args({"name": options.get("name"), "newname": options.get("newname"), "parent": options.get("parent"), "group": options.get("group"), "resources": options.get("resources"), "type": options.get("type"), "config": options.get("config"), "property": options.get("property")})
    raise ResourceRecipeError(f"unsupported ResourceTool recipe operation: {operation}")


def operation_names() -> list[str]:
    from .operation_registry import RECIPE_NAMES
    return list(RECIPE_NAMES)
