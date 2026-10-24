from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .model import Diagnostic, ProjectIndex, SourceFile


_ERROR_LINE = re.compile(r"(?:Error\s*:\s*)?(?P<asset>[A-Za-z][A-Za-z0-9_]*)\((?P<line>\d+)\)\s*:\s*(?P<message>.+)$", re.IGNORECASE)
_ASSET_ONLY = re.compile(r"\b(?:gml_)?(?:GlobalScript|Object|Room|Shader)_[A-Za-z0-9_]+\b", re.IGNORECASE)


def _all_sources(index: ProjectIndex) -> list[tuple[str, SourceFile]]:
    return [(resource.name, source) for resource in index.resources for source in resource.sources]


def _match_source(index: ProjectIndex, asset: str) -> tuple[str | None, SourceFile | None]:
    token = asset.removeprefix("gml_")
    # Global scripts are emitted as gml_GlobalScript_<resource>.
    if token.casefold().startswith("globalscript_"):
        name = token.split("_", 1)[1]
        resource = index.resources_by_name.get(name.casefold())
        if resource:
            source = next((item for item in resource.sources if item.kind == "gml"), None)
            return resource.name, source
    # Object and room compiler names contain the logical asset name.  Matching
    # the longest known name handles underscores without guessing a delimiter.
    for resource in sorted(index.resources, key=lambda item: len(item.name), reverse=True):
        if resource.name.casefold() not in token.casefold():
            continue
        if resource.type == "GMObject":
            event_sources = [item for item in resource.sources if item.kind == "gml"]
            # Current AssetCompiler names usually include the physical event
            # stem (for example gml_Object_obj_player_Step_0). Match that
            # suffix when available; fall back to an unresolved logical object
            # rather than guessing between several events.
            for event_source in sorted(event_sources, key=lambda item: len(item.path.stem), reverse=True):
                if event_source.path.stem.casefold() in token.casefold():
                    return resource.name, event_source
            if len(event_sources) == 1:
                return resource.name, event_sources[0]
            return resource.name, None
        if resource.type == "GMRoom":
            source = next((item for item in resource.sources if item.label.casefold() == "creationcode"), None)
            for room_source in resource.sources:
                if room_source.path.stem.casefold() in token.casefold():
                    return resource.name, room_source
            return resource.name, source
        if resource.type == "GMShader":
            return resource.name, None
        for source in resource.sources:
            if source.kind in {"gml", "shader-vertex", "shader-fragment"}:
                return resource.name, source
    return None, None


def parse_compiler_output(output: str, index: ProjectIndex) -> list[Diagnostic]:
    """Normalize AssetCompiler text/JSON errors to stable gmtool diagnostics."""
    diagnostics: list[Diagnostic] = []
    seen: set[tuple[str, int | None, str]] = set()
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("{"):
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                payload = None
            if isinstance(payload, dict) and isinstance(payload.get("errors"), list):
                for error in payload["errors"]:
                    if isinstance(error, dict) and isinstance(error.get("message"), str):
                        nested = parse_compiler_output(error["message"], index)
                        diagnostics.extend(nested or [Diagnostic("GMC001", "error", error["message"], source="compiler")])
                continue
        match = _ERROR_LINE.search(line)
        if not match:
            continue
        asset = match.group("asset")
        line_number = int(match.group("line"))
        message = match.group("message").strip()
        if "exited with non-zero status" in message.casefold():
            continue
        resource_name, source = _match_source(index, asset)
        path = source.path if source else None
        key = (asset, line_number, message)
        if key in seen:
            continue
        seen.add(key)
        diagnostics.append(Diagnostic("GMC001", "error", message, path, line_number, resource=resource_name, source="compiler"))
    # gm-cli commonly emits the same error once in the human log, once in its
    # JSON summary, and once on stderr. Keep the first occurrence only.
    unique: list[Diagnostic] = []
    seen_diagnostics: set[tuple[str | None, int | None, str]] = set()
    for item in diagnostics:
        key = (str(item.path) if item.path else None, item.line, item.message)
        if key not in seen_diagnostics:
            seen_diagnostics.add(key)
            unique.append(item)
    return unique


def explain_diagnostic(message: str, code: str | None = None) -> dict[str, Any]:
    text = message.strip()
    lowered = text.casefold()
    if "unexpected symbol" in lowered or "malformed assignment" in lowered or "expected ')'" in lowered:
        return {"code": code or "GMC001", "title": "Parser found an invalid expression", "cause": "A delimiter, operator, or expression token is missing or out of place. Later compiler messages may be cascading symptoms of the first error.", "nextSteps": ["Inspect the first compiler diagnostic and the preceding line.", "Check parentheses, brackets, braces, commas, and assignment operators.", "Run gmtool diagnose for the local lexer result before editing."], "repair": "A repair is safe to automate only when exactly one delimiter/string/comment closure is uniquely inferred and the candidate compiles."}
    if "unterminated" in lowered or "unclosed" in lowered:
        return {"code": code or "GMS014", "title": "A source construct is not closed", "cause": "The parser reached the end of a string, block comment, or delimiter scope without finding its terminator.", "nextSteps": ["Use the reported line and column to locate the opening token.", "Check whether the closing token is inside a comment or string.", "Use repair-syntax for a compiler-verified one-site closure."], "repair": "Only a single, local, syntax-only closure can be proposed automatically."}
    if "not found" in lowered or "undefined" in lowered or "unknown" in lowered:
        return {"code": code or "GMC001", "title": "The compiler cannot resolve a name", "cause": "The identifier is missing, misspelled, out of scope, or not registered as a GameMaker resource.", "nextSteps": ["Resolve the logical resource with gmtool find/resolve.", "Check spelling and resource registration before changing code.", "Do not treat a dynamic string lookup as a safe rename target."], "repair": "Name resolution is semantic; gmtool will not rewrite it automatically."}
    return {"code": code or "GMC001", "title": "GameMaker compiler diagnostic", "cause": text, "nextSteps": ["Use the mapped path and line when available.", "Inspect the first diagnostic rather than later cascades.", "Re-run compile with --verbose when the short message lacks context."], "repair": "No automatic repair is inferred for this diagnostic."}
