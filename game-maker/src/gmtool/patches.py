"""Strict minimal edits; no fuzzy matching, normalization, or silent overlap."""
from __future__ import annotations
import re

def patch_bytes(original: bytes, edits: list[dict] | None = None, unified: str | None = None) -> bytes:
    bom = b"\xef\xbb\xbf" if original.startswith(b"\xef\xbb\xbf") else b""
    text = original[len(bom):].decode("utf-8")
    if bool(edits) == bool(unified):
        raise ValueError("provide anchored edits OR a unified diff")
    newline = "\r\n" if "\r\n" in text else "\n"
    if unified:
        lines = text.splitlines(keepends=True)
        diff = unified.splitlines(keepends=True)
        cursor, output, i, count = 0, [], 0, 0
        while i < len(diff):
            line = diff[i]
            if line.startswith(("---", "+++")):
                i += 1
                continue
            match = re.fullmatch(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@[^\r\n]*\r?\n?", line)
            if not match:
                raise ValueError("invalid unified hunk")
            start = int(match[1]) - (0 if match[2] == "0" else 1)
            if start < cursor or start > len(lines):
                raise ValueError("overlapping or out-of-range hunks")
            output.extend(lines[cursor:start]); cursor = start; i += 1
            old_count = new_count = 0
            while i < len(diff) and not diff[i].startswith("@@"):
                entry = diff[i]
                if not entry or entry[0] not in " +-":
                    raise ValueError("invalid hunk line")
                payload = entry[1:]
                if i + 1 < len(diff) and diff[i + 1].startswith("\\ No newline"):
                    payload = payload.rstrip("\r\n"); i += 1
                elif payload.endswith("\n"):
                    payload = payload.rstrip("\r\n") + newline
                if entry[0] in " -":
                    if cursor >= len(lines) or lines[cursor] != payload:
                        raise ValueError("hunk context does not match source bytes")
                    cursor += 1; old_count += 1
                if entry[0] in " +":
                    output.append(payload); new_count += 1
                i += 1
            if old_count != int(match[2] or 1) or new_count != int(match[4] or 1):
                raise ValueError("hunk line counts disagree")
            count += 1
        if not count:
            raise ValueError("diff contains no hunks")
        output.extend(lines[cursor:])
        return bom + "".join(output).encode("utf-8")
    spans = []
    for edit in edits:
        if set(edit) != {"old", "new"} or not isinstance(edit["old"], str) or not edit["old"]:
            raise ValueError("each edit requires nonempty old and new strings")
        old = edit["old"].replace("\r\n", "\n").replace("\n", newline)
        new = edit["new"].replace("\r\n", "\n").replace("\n", newline)
        if text.count(old) != 1:
            raise ValueError("anchor is missing or ambiguous")
        start = text.index(old)
        spans.append((start, start + len(old), new))
    spans.sort()
    if any(a[1] > b[0] for a, b in zip(spans, spans[1:])):
        raise ValueError("overlapping anchored edits")
    for start, end, new in reversed(spans):
        text = text[:start] + new + text[end:]
    return bom + text.encode("utf-8")
