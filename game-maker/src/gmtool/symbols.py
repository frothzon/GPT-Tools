"""Conservative lexical GML index. Confidence is explicit; not a type checker."""
from __future__ import annotations
import re
from .workspace import digest, load, save

def mask(text):
    out = list(text); i = 0
    while i < len(text):
        if text.startswith("//", i):
            end = text.find("\n", i)
            end = len(text) if end < 0 else end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = len(text) if end < 0 else end + 2
        elif text[i] in "\"'":
            quote = text[i]; end = i + 1
            verbatim = i > 0 and text[i - 1] == "@"
            while end < len(text):
                if not verbatim and text[end] == "\\":
                    end += 2; continue
                if text[end] == quote:
                    end += 1; break
                end += 1
        else:
            i += 1; continue
        for j in range(i, min(end, len(text))):
            if out[j] not in "\r\n": out[j] = " "
        i = end
    return "".join(out)

def extract(text):
    code = mask(text)
    symbols = []
    patterns = [("function", r"\bfunction\s+([A-Za-z_]\w*)\s*\(([^)]*)\)\s*(constructor)?"),
                ("static-method", r"\bstatic\s+([A-Za-z_]\w*)\s*=\s*function\s*\(([^)]*)\)"),
                ("enum", r"\benum\s+([A-Za-z_]\w*)"),
                ("macro", r"#macro\s+([A-Za-z_]\w*)")]
    for kind, pattern in patterns:
        for match in re.finditer(pattern, code):
            line = text.count("\n", 0, match.start()) + 1
            body = code.find("{", match.end()) if kind not in {"macro"} else -1
            end = match.end()
            if body >= 0:
                depth = 1; end = body + 1
                while end < len(code) and depth:
                    depth += (code[end] == "{") - (code[end] == "}"); end += 1
            params = [p.strip() for p in match[2].split(",") if p.strip()] if kind in {"function", "static-method"} else []
            preceding = text[:match.start()].splitlines()[-12:]
            symbols.append({"name": match[1], "kind": "constructor" if kind == "function" and match[3] else kind,
                            "line": line, "endLine": text.count("\n", 0, end) + 1, "parameters": params,
                            "jsdoc": [p.strip() for p in preceding if p.strip().startswith("///")], "confidence": "lexical"})
    calls = []
    for match in re.finditer(r"\b([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*\(", code):
        if match[1] in {"if", "for", "while", "switch", "with", "repeat", "function", "catch"}: continue
        if re.search(r"\bfunction\s*$", code[max(0, match.start()-15):match.start()]): continue
        i = match.end(); depth = 1; commas = 0; content = False
        while i < len(code) and depth:
            c = code[i]
            if c in "([{": depth += 1
            elif c in ")]}": depth -= 1
            elif c == "," and depth == 1: commas += 1
            if depth and not c.isspace(): content = True
            i += 1
        # A masked string is still an argument; use the original slice.
        has_arg = bool(text[match.end():max(match.end(), i-1)].strip())
        calls.append({"name": match[1], "line": text.count("\n", 0, match.start()) + 1,
                      "arity": commas + 1 if has_arg else 0, "confidence": "static-name" if "." not in match[1] else "dynamic-receiver"})
    declarations = [{"name": m[1], "line": text.count("\n", 0, m.start()) + 1, "confidence": "lexical"}
                    for m in re.finditer(r"\b((?:global\.)?[A-Za-z_]\w*)\s*=(?!=)", code)]
    tokens = [{"name": m[0], "line": text.count("\n", 0, m.start()) + 1} for m in re.finditer(r"\b[A-Za-z_]\w*\b", code)]
    return {"symbols": symbols, "calls": calls, "declarations": declarations, "tokens": tokens,
            "scopeCaveats": [name for name in ("with", "method", "event_inherited", "variable_instance_get", "variable_struct_get") if re.search(r"\b" + name + r"\b", code)]}

def project_symbols(index, tool_root):
    cache = tool_root / ".gmtool-work" / "symbols"
    records = []
    for resource in index.resources:
        for source in resource.sources:
            if source.kind != "gml" or not source.path.is_file(): continue
            text = source.path.read_bytes().decode("utf-8-sig")
            key = digest({"extractor": 1, "text": text})
            file = cache / (key + ".json")
            extracted = load(file) if file.is_file() else extract(text)
            if not file.is_file(): save(file, extracted)
            records.append({"spec": resource.name + "." + source.label, "resource": resource.name,
                            "path": source.path.relative_to(index.root).as_posix(), "hash": key, **extracted})
    return records
