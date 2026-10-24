from __future__ import annotations

from pathlib import Path

from .lossless_json import ParseError, load
from .model import Diagnostic, ProjectIndex, SourceFile


_OPEN_TO_CLOSE = {"(": ")", "[": "]", "{": "}"}
_CLOSE_TO_OPEN = {value: key for key, value in _OPEN_TO_CLOSE.items()}


def _line_column(text: str, offset: int) -> tuple[int, int]:
    line = text.count("\n", 0, offset) + 1
    previous = text.rfind("\n", 0, offset)
    return line, offset - previous


def scan_text(text: str, *, path: Path, resource: str | None = None) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    stack: list[tuple[str, int]] = []
    index = 0
    quote: str | None = None
    quote_start = 0
    line_comment = False
    block_comment = False
    block_start = 0
    escaped = False

    from .symbols import mask
    import re
    lines = mask(text).splitlines()
    for line_number, line in enumerate(lines, 1):
        stripped = line.lstrip()
        if re.match(r"^(?:<{7}(?:\s|$)|={7}\s*$|>{7}(?:\s|$))", stripped):
            column = len(line) - len(stripped) + 1
            diagnostics.append(Diagnostic("GMS010", "error", "unresolved merge-conflict marker", path, line_number, column, resource, "lexer"))

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            elif char == "\n" and quote in {"'", '"'}:
                line, column = _line_column(text, quote_start)
                diagnostics.append(Diagnostic("GMS011", "error", "unterminated string literal", path, line, column, resource, "lexer"))
                quote = None
            index += 1
            continue
        if char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            block_start = index
            index += 2
            continue
        if char in {"'", '"'}:
            quote = char
            quote_start = index
            index += 1
            continue
        if char in _OPEN_TO_CLOSE:
            stack.append((char, index))
        elif char in _CLOSE_TO_OPEN:
            if not stack or stack[-1][0] != _CLOSE_TO_OPEN[char]:
                line, column = _line_column(text, index)
                diagnostics.append(Diagnostic("GMS012", "error", f"unmatched closing delimiter {char!r}", path, line, column, resource, "lexer"))
            else:
                stack.pop()
        index += 1

    if quote:
        line, column = _line_column(text, quote_start)
        diagnostics.append(Diagnostic("GMS011", "error", "unterminated string literal", path, line, column, resource, "lexer"))
    if block_comment:
        line, column = _line_column(text, block_start)
        diagnostics.append(Diagnostic("GMS013", "error", "unterminated block comment", path, line, column, resource, "lexer"))
    for opener, offset in reversed(stack):
        line, column = _line_column(text, offset)
        diagnostics.append(Diagnostic("GMS014", "error", f"unclosed delimiter {opener!r}; expected {_OPEN_TO_CLOSE[opener]!r}", path, line, column, resource, "lexer"))
    return diagnostics


def scan_source(path: Path, *, resource: str | None = None) -> list[Diagnostic]:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        return [Diagnostic("GMS001", "error", "source is not valid UTF-8", path, resource=resource, source="lexer")]
    return scan_text(text, path=path, resource=resource)


def diagnose(index: ProjectIndex, sources: list[tuple[str, SourceFile]] | None = None) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    selected = sources
    if selected is None:
        selected = [(resource.name, source) for resource in index.resources for source in resource.sources]
    for resource_name, source in selected:
        if source.path.is_file() and source.kind in {"gml", "shader-vertex", "shader-fragment"}:
            diagnostics.extend(scan_source(source.path, resource=resource_name))
    for path in [index.project_file, index.project_file.with_suffix(".resource_order")]:
        if not path.is_file():
            continue
        try:
            load(path)
        except ParseError as exc:
            diagnostics.append(Diagnostic("GMS020", "error", str(exc), path, exc.line, exc.column, source="metadata"))
    return diagnostics
