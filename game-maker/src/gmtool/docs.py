"""Version-scoped official-manual catalog with auditable sitemap coverage."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import Counter
from datetime import datetime, timezone
from html.parser import HTMLParser
from functools import lru_cache
import hashlib
from pathlib import Path
import re
import urllib.parse
import urllib.request
import urllib.error
import threading
import time
import zipfile
import xml.etree.ElementTree as ET
from .workspace import digest, load, save, now, identifier

CHANNELS = {"monthly", "lts", "beta", "project"}

class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []; self.links = []; self.skip = 0; self.title = []; self.in_title = False
        self.rows = []; self.row = None; self.cell = None
    def handle_starttag(self, tag, attrs):
        if tag in {"script", "style"}: self.skip += 1
        if tag == "title": self.in_title = True
        if tag == "tr": self.row = []
        if tag in {"td", "th"}: self.cell = []
        if tag in {"p", "div", "tr", "h1", "h2", "h3", "h4", "li", "pre", "br"}: self.parts.append("\n")
        if tag in {"td", "th"}: self.parts.append(" | ")
        if tag == "a":
            href = dict(attrs).get("href")
            if href: self.links.append(href)
    def handle_endtag(self, tag):
        if tag in {"script", "style"}: self.skip = max(0, self.skip - 1)
        if tag == "title": self.in_title = False
        if tag in {"td", "th"} and self.row is not None and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split())); self.cell = None
        if tag == "tr" and self.row is not None:
            self.rows.append(self.row); self.row = None
        if tag in {"p", "div", "tr", "h1", "h2", "h3", "h4", "li", "pre"}: self.parts.append("\n")
    def handle_data(self, data):
        if self.skip: return
        self.parts.append(data)
        if self.in_title: self.title.append(data)
        if self.cell is not None: self.cell.append(data)
    def text(self):
        return "\n".join(" ".join(line.split()) for line in "".join(self.parts).splitlines() if line.strip())

def base_url(channel, language):
    if channel not in CHANNELS or not re.fullmatch(r"[a-z]{2}", language):
        raise ValueError("unsupported documentation channel or language")
    return f"https://manual.gamemaker.io/{'monthly' if channel == 'project' else channel}/{language}/"

def fetch(url):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "manual.gamemaker.io":
        raise ValueError("manual importer only fetches official HTTPS pages")
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (gmtool local documentation cache)"})
    with urllib.request.urlopen(request, timeout=25) as response:
        if urllib.parse.urlparse(response.url).hostname != "manual.gamemaker.io":
            raise ValueError("manual redirect leaves official host")
        return response.read().decode("utf-8-sig")

def enumerate_pages(xml, base):
    tree = ET.fromstring(xml)
    urls = set()
    for node in tree.iter():
        if node.tag.rsplit("}", 1)[-1] != "loc" or not node.text: continue
        url = urllib.parse.urljoin(base, node.text.strip())
        if url.startswith(base) and urllib.parse.urlparse(url).path.endswith((".htm", ".html")):
            urls.add(url.split("#")[0])
    return sorted(urls)

def extract(html, url, channel, language):
    page = Page(); page.feed(html); text = page.text()
    title = "".join(page.title).strip() or Path(urllib.parse.urlparse(url).path).stem
    name = title if re.fullmatch(r"[A-Za-z_]\w*", title) else Path(urllib.parse.urlparse(url).path).stem
    signatures = []
    for line in text.splitlines():
        for match in re.finditer(r"\b" + re.escape(name) + r"\s*\(([^()]*)\)\s*;?", line):
            signature = name + "(" + match[1].strip() + ")"
            if signature not in signatures: signatures.append(signature)
        if signatures and len(signatures) >= 4: break
    def section(heading):
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if line.casefold().rstrip(":") == heading.casefold():
                result = []
                for following in lines[i+1:]:
                    if re.match(r"^(?:syntax|returns|arguments|examples?|description)(?:\s+\d+)?(?:\s*:|\s*$)", following, re.I): break
                    result.append(following)
                return result or None
        return None
    # Only the dedicated Syntax section provides authoritative arity.
    syntax_lines = section("Syntax") or []
    canonical = next((s for s in signatures if any(s.replace(" ", "") in l.replace(" ", "") for l in syntax_lines)), None)
    args = canonical[canonical.find("(")+1:-1].strip() if canonical else None
    parameters = [p.strip() for p in args.split(",") if p.strip()] if args is not None else None
    arity = None
    if parameters is not None and not any("..." in p for p in parameters):
        required = 0; optional = False
        for p in parameters:
            optional = optional or "[" in p or "=" in p
            if not optional: required += 1
        arity = {"min": required, "max": len(parameters), "basis": "documented Syntax section"}
    caution = [line for line in text.splitlines() if re.search(r"\b(?:NOTE|WARNING|deprecated|obsolete|only available|not supported|platform)\b", line, re.I)]
    category = urllib.parse.urlparse(url).path.split("/GML_Reference/", 1)[-1].rsplit("/", 1)[0]
    kind = "function" if canonical else "variable-or-constant" if re.fullmatch(r"[a-z][a-z0-9_]*", name) else "topic"
    argument_rows = []
    active = False
    for row in page.rows:
        if row and row[0].casefold() == "argument": active = True; continue
        if active and len(row) >= 2:
            argument_rows.append({"name": row[0], "type": row[1], "description": row[2] if len(row) > 2 else None})
    return {"identifier": name, "title": title, "kind": kind, "category": category, "signatures": signatures,
            "canonicalSignature": canonical, "parameters": parameters, "arity": arity, "returns": section("Returns"),
            "argumentDetails": argument_rows or section("Arguments"), "defaults": [p for p in parameters or [] if "=" in p] or None,
            "sideEffects": None, "contextRequirements": [c for c in caution if re.search(r"\b(?:event|scope|instance)\b", c, re.I)] or None,
            "platformLimitations": [c for c in caution if re.search(r"\b(?:Windows|macOS|HTML5|platform|Android|iOS|Opera)\b", c, re.I)] or None, "caveats": caution, "deprecated": bool(re.search(r"\b(?:deprecated|obsolete)\b", text, re.I)),
            "replacement": None, "exampleLinks": [url + "#example"] if section("Example") else [],
            "sourceUrl": url, "channel": channel, "language": language, "retrievedAt": now(),
            "contentHash": hashlib.sha256(html.encode()).hexdigest(), "versionEvidence": [], "availability": "unknown-for-exact-runtime",
            "text": text, "links": [urllib.parse.urljoin(url, h) for h in page.links]}

def catalog_root(tool_root, channel, language="en"):
    base_url(channel, language)
    return Path(tool_root) / ".gmtool-work" / "docs" / channel / language

def current(tool_root, channel="monthly", language="en"):
    root = catalog_root(tool_root, channel, language)
    pointer = root / "current.json"
    if not pointer.is_file(): return None
    catalog = root / "snapshots" / identifier(load(pointer)["snapshotId"]) / "catalog.json"
    return _cached_catalog(str(catalog), catalog.stat().st_mtime_ns)

@lru_cache(maxsize=6)
def _cached_catalog(path, modified):
    return load(path)

def sync(tool_root, channel="monthly", language="en", *, max_pages=None, workers=2, fetcher=fetch, offline_zip=None, offline_version=None):
    if channel == "project" and not offline_zip:
        raise ValueError("project documentation requires an official offline ZIP and version provenance")
    base = base_url(channel, language)
    archive = None
    if offline_zip:
        if not offline_version: raise ValueError("offline ZIP import requires --offline-version")
        archive = zipfile.ZipFile(offline_zip)
        prefix = next((n[:-len('sitemap.xml')] for n in archive.namelist() if n.endswith('sitemap.xml')), None)
        if prefix is None: raise ValueError("offline ZIP has no official sitemap")
        def offline_fetch(url):
            relative = urllib.parse.unquote(url[len(base):])
            if ".." in Path(relative).parts: raise ValueError("unsafe manual ZIP entry")
            return archive.read(prefix + relative).decode("utf-8-sig")
        fetcher = offline_fetch
    sitemap = fetcher(base + "sitemap.xml")
    enumerated = enumerate_pages(sitemap, base)
    if not enumerated: raise ValueError("official sitemap has no topics")
    # Full manual includes GML, IDE, and platform topics; all are indexed.
    # Prioritize code reference; report every omitted page if limited.
    enumerated.sort(key=lambda u: ("/GML_Reference/" not in u, u))
    selected = enumerated[:max_pages] if max_pages is not None else enumerated
    root = catalog_root(tool_root, channel, language); pages_root = root / "pages"
    old = current(tool_root, channel, language)
    old_by_url = {e["sourceUrl"]: e for e in old["entries"]} if old else {}
    results, failures = [], []
    limited = threading.Event()
    throttle = threading.Lock()
    last_request = [0.0]
    def get(url):
        if limited.is_set(): raise RuntimeError("download paused after server rate limit; retry later")
        if fetcher is fetch:
            with throttle:
                delay = max(0, .15 - (time.monotonic() - last_request[0]))
                if delay: time.sleep(delay)
                last_request[0] = time.monotonic()
        try:
            content = fetcher(url)
        except urllib.error.HTTPError as exc:
            if exc.code == 429: limited.set()
            raise
        entry = extract(content, url, channel, language)
        if offline_zip:
            entry["offlineManualVersion"] = offline_version
            entry["versionEvidence"] = [{"manualArchiveVersion": offline_version, "compatibility": "not equivalent to exact runtime support"}]
        save(pages_root / (digest(url) + ".json"), entry)
        return entry
    with ThreadPoolExecutor(max_workers=min(8, max(1, workers))) as pool:
        futures = {pool.submit(get, url): url for url in selected}
        for future in as_completed(futures):
            url = futures[future]
            try: results.append(future.result())
            except Exception as error:
                failures.append({"url": url, "error": str(error)})
                if url in old_by_url:
                    results.append({**old_by_url[url], "stale": True})
    results.sort(key=lambda e: e["sourceUrl"])
    snapshot_id = digest({"extractorSchema": 2, "sitemap": sitemap, "hashes": [(e["sourceUrl"], e["contentHash"]) for e in results], "failures": failures})
    counts = Counter(e["category"] for e in results)
    aliases = {}
    for e in results: aliases.setdefault(e["identifier"], []).append(e["sourceUrl"])
    complete = not failures and len(selected) == len(enumerated)
    catalog = {"snapshotId": snapshot_id, "channel": channel, "language": language, "createdAt": now(), "entries": results,
               "coverage": {"status": "complete-index" if complete else "partial", "enumerationSource": base + "sitemap.xml", "enumeratedPages": len(enumerated),
                            "selectedPages": len(selected), "downloadedPages": len(results)-sum(bool(e.get("stale")) for e in results), "failedDownloads": failures,
                            "unresolvedEntries": [e["sourceUrl"] for e in results if e["kind"] == "function" and not e["canonicalSignature"]],
                            "duplicates": {k: v for k, v in aliases.items() if len(v) > 1}, "byCategory": dict(counts),
                            "runtimeSymbolCoverage": "not measured", "exactRuntimeCompatibility": "not established"}}
    if offline_zip:
        catalog["coverage"]["offlineManualVersion"] = offline_version
        catalog["coverage"]["enumerationSource"] = str(Path(offline_zip).resolve()) + "!/sitemap.xml"
        catalog["coverage"]["archiveHash"] = hashlib.sha256(Path(offline_zip).read_bytes()).hexdigest()
    save(root / "snapshots" / snapshot_id / "catalog.json", catalog)
    save(root / "snapshots" / snapshot_id / "enumeration.json", {"urls": enumerated, "sitemapHash": hashlib.sha256(sitemap.encode()).hexdigest()})
    # Failed refresh preserves prior active snapshot. First partial import is explicitly partial.
    activated = complete or old is None
    if activated: save(root / "current.json", {"snapshotId": snapshot_id})
    if archive: archive.close()
    return {"snapshotId": snapshot_id, "activated": activated, **catalog["coverage"]}

def coverage(tool_root, channel="monthly", language="en"):
    catalog = current(tool_root, channel, language)
    return {"status": "missing", "channel": channel} if catalog is None else {"snapshotId": catalog["snapshotId"], **catalog["coverage"]}

def lookup(tool_root, name, *, channel="monthly", language="en", profile=None, include_text=False):
    catalog = current(tool_root, channel, language)
    if catalog is None: return {"status": "missing-catalog", "identifier": name, "channel": channel}
    matches = [e for e in catalog["entries"] if e["identifier"].casefold() == name.casefold()]
    if not matches: return {"status": "not-found", "identifier": name, "channel": channel}
    matches.sort(key=lambda e: ("/GML_Reference/" not in e["sourceUrl"], e["canonicalSignature"] is None, e["sourceUrl"]))
    entries = [{k: v for k, v in e.items() if include_text or k not in {"text", "links"}} for e in matches]
    return {"status": "found", "identifier": name, "entries": entries, "snapshotId": catalog["snapshotId"], "profile": profile,
            "compatibility": "unknown-for-exact-runtime" if profile else "documentation-channel-only"}

def search(tool_root, query, *, channel="monthly", language="en", offset=0, limit=30):
    if offset < 0 or not 1 <= limit <= 500: raise ValueError("invalid documentation pagination")
    catalog = current(tool_root, channel, language)
    if catalog is None: return {"status": "missing-catalog", "entries": []}
    words = query.casefold().split()
    exact = [e for e in catalog["entries"] if e["identifier"].casefold() == query.casefold()]
    hits = []
    for e in exact or catalog["entries"]:
        hay = (e["identifier"] + " " + e["category"] + " " + e["text"]).casefold()
        if all(w in hay for w in words):
            score = 100 if query.casefold() == e["identifier"].casefold() else sum(10 for w in words if w in e["identifier"].casefold())
            hits.append((score, e))
    hits.sort(key=lambda h: (-h[0], h[1]["identifier"]))
    return {"status": "found", "total": len(hits), "hasMore": offset + limit < len(hits), "offset": offset,
            "entries": [{k: v for k, v in e.items() if k not in {"text", "links"}} for _, e in hits[offset:offset+limit]]}

def diff(tool_root, before, after, channel="monthly", language="en"):
    root = catalog_root(tool_root, channel, language) / "snapshots"
    a = load(root / identifier(before) / "catalog.json"); b = load(root / identifier(after) / "catalog.json")
    old = {e["sourceUrl"]: e["contentHash"] for e in a["entries"]}; new = {e["sourceUrl"]: e["contentHash"] for e in b["entries"]}
    from .gm_cli import snapshot_diff
    return snapshot_diff(old, new)

def check_calls(tool_root, calls, channel="monthly"):
    findings = []
    for call in calls:
        if call["confidence"] != "static-name": continue
        result = lookup(tool_root, call["name"], channel=channel)
        if result["status"] != "found": continue
        arities = [e["arity"] for e in result["entries"] if e["arity"] and not e.get("stale")]
        if arities and not any(a["min"] <= call["arity"] <= a["max"] for a in arities):
            findings.append({"code": "GMDOC001", "severity": "warning", "line": call["line"], "message": f"{call['name']} call has {call['arity']} arguments; documented arity differs", "sources": [e["sourceUrl"] for e in result["entries"]]})
    return findings
