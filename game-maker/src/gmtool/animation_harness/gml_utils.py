"""Small self-contained GML literal and naming helpers for package generation."""
from __future__ import annotations
import json
import re
from pathlib import Path


def safe_slug(value: str) -> str:
    name=re.sub(r"[^A-Za-z0-9_]+","_",str(value)).strip("_").lower()
    if not name or name[0].isdigit():name="anim_"+name
    return name[:48]


def gml_number(value: float | int) -> str:
    number=float(value)
    if not number.is_integer():return format(number,".15g")
    return str(int(number))


def gml_string(value: str) -> str:
    return json.dumps(str(value),ensure_ascii=False)


def gml_value(value):
    if value is None:return "undefined"
    if isinstance(value,bool):return "true" if value else "false"
    if isinstance(value,(int,float)):return gml_number(value)
    if isinstance(value,str):return gml_string(value)
    if isinstance(value,(list,tuple)):return "["+",".join(gml_value(item) for item in value)+"]"
    if isinstance(value,dict):return "{"+",".join(f"{safe_slug(key)}:{gml_value(item)}" for key,item in value.items())+"}"
    raise TypeError(f"cannot encode {type(value).__name__} as GML")


def load_project(path: str | Path) -> dict:
    text=Path(path).read_text(encoding="utf-8-sig")
    try:return json.loads(text)
    except json.JSONDecodeError:
        # GameMaker's saved JSON-like metadata commonly has trailing commas/comments.
        from gmtool.lossless_json import loads
        return loads(text).value
