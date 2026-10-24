from __future__ import annotations
from pathlib import Path
import time
from .index import build_index, resolve_effective, inheritance_chain
from .symbols import project_symbols
from .transactions import sha256_bytes
from .validation import validate

def context(tool_root, project, spec, *, offset=0, limit=100, line_start=1, line_count=200, docs_channel="monthly"):
    started = time.monotonic()
    if offset < 0 or not 1 <= limit <= 500 or line_start < 1 or not 1 <= line_count <= 2000:
        raise ValueError("invalid pagination")
    index = build_index(project)
    records = project_symbols(index, Path(tool_root))
    try:
        owner, source = resolve_effective(index, spec)
    except KeyError:
        matches = [(r, s) for r in records for s in r["symbols"] if s["name"].casefold() == spec.casefold()]
        if len(matches) != 1:
            raise KeyError(f"symbol is missing or ambiguous: {spec}; candidates: " + ", ".join(r["spec"] for r, _ in matches))
        owner, source = resolve_effective(index, matches[0][0]["spec"])
    selected = [r for r in records if r["resource"] == owner.name and (source is None or r["path"] == source.path.relative_to(index.root).as_posix())]
    names = {s["name"] for r in selected for s in r["symbols"]}
    calls = {c["name"] for r in selected for c in r["calls"]}
    declared = {d["name"] for r in selected for d in r["declarations"]}
    relations = []
    for record in records:
        related_calls = [c for c in record["calls"] if c["name"] in names]
        related_defs = [s for s in record["symbols"] if s["name"] in calls]
        initializers = [d for d in record["declarations"] if d["name"] in declared]
        if related_calls or related_defs or initializers:
            relations.append({"spec": record["spec"], "path": record["path"], "calls": related_calls, "definitions": related_defs, "initializationCandidates": initializers, "confidence": "lexical-candidate"})
    code = []
    for item in owner.sources if source is None else [source]:
        if not item.path.is_file(): continue
        raw = item.path.read_bytes(); lines = raw.decode("utf-8-sig").splitlines()
        code.append({"spec": owner.name + "." + item.label, "path": str(item.path), "expectedHash": sha256_bytes(raw),
                     "lineStart": line_start, "lineEnd": min(len(lines), line_start + line_count - 1), "totalLines": len(lines),
                     "hasMore": line_start + line_count <= len(lines), "content": "\n".join(lines[line_start-1:line_start-1+line_count])})
    from .docs import lookup, coverage, check_calls
    doc_entries = [lookup(Path(tool_root), name, channel=docs_channel) for name in sorted(calls) if "." not in name]
    doc_entries = [d for d in doc_entries if d["status"] == "found"]
    requested = next((r for r in index.resources if spec.casefold().startswith(r.name.casefold() + ".") or spec.casefold() == r.name.casefold()), owner)
    chain = inheritance_chain(index, requested) if requested.type == "GMObject" else [owner]
    resources = sorted({t["name"] for r in selected for t in r["tokens"] if t["name"].casefold() in index.resources_by_name})
    from .workspace import audit
    audit(tool_root, index.project_file, "context", {"status": "read", "durationSeconds": time.monotonic() - started})
    return {"project": index.summary(), "requested": spec, "effectiveOwner": owner.name, "inherited": owner.name != requested.name,
            "inheritance": [r.name for r in chain], "code": code, "symbols": [{k: v for k, v in r.items() if k != "tokens"} for r in selected],
            "relations": relations[offset:offset+limit], "pagination": {"offset": offset, "limit": limit, "total": len(relations), "hasMore": offset + limit < len(relations)},
            "resourceReferences": resources, "diagnostics": [d.as_dict(index.root) for d in validate(index) if d.resource == owner.name],
            "builtins": doc_entries, "documentationCoverage": coverage(Path(tool_root), docs_channel),
            "apiHints": [d for r in selected for d in check_calls(Path(tool_root), r["calls"], docs_channel)],
            "analysisLimits": "Lexical candidates; dynamic dispatch, with scopes, bindings and field ownership are not type-proven."}
