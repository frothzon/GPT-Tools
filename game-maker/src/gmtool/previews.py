from __future__ import annotations

import hashlib
import html
import json
import math
from pathlib import Path
import wave
from typing import Any, Iterator

from .model import ProjectIndex, ResourceRecord


def _references(value: Any) -> Iterator[dict[str, str]]:
    if isinstance(value, dict):
        name = value.get("name")
        path = value.get("path")
        if isinstance(name, str) and isinstance(path, str):
            yield {"name": name, "path": path}
        for child in value.values():
            yield from _references(child)
    elif isinstance(value, list):
        for child in value:
            yield from _references(child)


def _resource_digest(resource: ResourceRecord) -> str:
    digest = hashlib.sha256()
    paths = [resource.path]
    if resource.path.parent.is_dir():
        paths.extend(path for path in resource.path.parent.rglob("*") if path.is_file() and path != resource.path)
    for path in sorted(paths):
        digest.update(path.name.encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def _write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def _file_inventory(resource: ResourceRecord) -> list[dict[str, Any]]:
    files = [resource.path]
    if resource.path.parent.is_dir():
        files.extend(path for path in resource.path.parent.rglob("*") if path.is_file() and path != resource.path)
    inventory: list[dict[str, Any]] = []
    for path in sorted(set(files)):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        inventory.append({"name": path.name, "path": str(path), "suffix": path.suffix.casefold(), "bytes": path.stat().st_size, "sha256": digest})
    return inventory


def _html_preview(resource: ResourceRecord, output: Path, references: list[dict[str, str]], files: list[dict[str, Any]]) -> None:
    descriptor = html.escape(json.dumps(resource.descriptor, indent=2, ensure_ascii=False))
    dependency_html = "".join(f"<li><code>{html.escape(item['name'])}</code> → <code>{html.escape(item['path'])}</code></li>" for item in references)
    file_html = "".join(f"<li><code>{html.escape(item['name'])}</code> — {item['bytes']} bytes — <code>{item['sha256'][:16]}</code></li>" for item in files)
    sources: list[str] = []
    for source in resource.sources:
        if not source.path.is_file() or source.path.stat().st_size > 200_000:
            continue
        try:
            content = source.path.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeDecodeError):
            continue
        sources.append(f"<details><summary>{html.escape(source.label)} — {html.escape(source.path.name)}</summary><pre>{html.escape(content)}</pre></details>")
    body = "\n".join([
        "<!doctype html><meta charset='utf-8'><title>GameMaker resource preview</title>",
        "<style>body{font:14px system-ui;background:#202124;color:#eee;max-width:1100px;margin:2rem auto;padding:0 1rem}code,pre{font-family:ui-monospace,monospace}pre{white-space:pre-wrap;background:#151619;padding:1rem;border-radius:6px;overflow:auto}a{color:#8ab4f8}summary{cursor:pointer;padding:.5rem 0}li{margin:.25rem 0}</style>",
        f"<h1>{html.escape(resource.name)}</h1><p><b>Type:</b> <code>{html.escape(resource.type)}</code> · <b>Descriptor:</b> <code>{html.escape(str(resource.path))}</code></p>",
        "<h2>Files</h2><ul>" + file_html + "</ul>",
        "<h2>Dependencies</h2><ul>" + (dependency_html or "<li>None discovered in serialized references.</li>") + "</ul>",
        "<h2>Descriptor</h2><pre>" + descriptor + "</pre>",
        "<h2>Text sources</h2>" + ("\n".join(sources) or "<p>No small text sources.</p>"),
    ])
    (output / "preview.html").write_text(body + "\n", encoding="utf-8", newline="\n")


def _summary(resource: ResourceRecord, references: list[dict[str, str]]) -> str:
    lines = [
        f"# {resource.name}",
        "",
        f"- Type: `{resource.type}`",
        f"- Descriptor: `{resource.path}`",
        f"- Source files: {len(resource.sources)}",
        f"- Serialized references: {len(references)}",
    ]
    if resource.parent:
        lines.append(f"- Asset folder: `{resource.parent.get('path', resource.parent.get('name', 'unknown'))}`")
    if resource.sources:
        lines.extend(["", "## Sources", ""])
        lines.extend(f"- `{source.label}` → `{source.path.name}`" for source in resource.sources)
    if references:
        lines.extend(["", "## References", ""])
        seen: set[tuple[str, str]] = set()
        for reference in references:
            key = (reference["name"], reference["path"])
            if key not in seen:
                seen.add(key)
                lines.append(f"- `{reference['name']}` → `{reference['path']}`")
    return "\n".join(lines) + "\n"


def _load_pillow() -> tuple[Any, Any, Any] | None:
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return None
    return Image, ImageDraw, ImageFont


def _sprite_frame_paths(resource: ResourceRecord) -> list[Path]:
    result: list[Path] = []
    for frame in resource.descriptor.get("frames") or []:
        if not isinstance(frame, dict):
            continue
        frame_name = frame.get("name") or frame.get("%Name")
        if isinstance(frame_name, str):
            path = resource.path.parent / f"{frame_name}.png"
            if path.is_file():
                result.append(path)
    return result


def _sprite_preview(resource: ResourceRecord, output: Path) -> list[str]:
    pillow = _load_pillow()
    if pillow is None:
        return ["Pillow is unavailable; sprite image preview was skipped"]
    Image, ImageDraw, _ImageFont = pillow
    frames = _sprite_frame_paths(resource)
    if not frames:
        return ["No renderable top-level sprite frame PNGs were found"]
    images = [Image.open(path).convert("RGBA") for path in frames]
    cell_width = max(image.width for image in images) + 16
    cell_height = max(image.height for image in images) + 32
    columns = min(6, max(1, math.ceil(math.sqrt(len(images)))))
    rows = math.ceil(len(images) / columns)
    sheet = Image.new("RGBA", (cell_width * columns, cell_height * rows), (32, 32, 36, 255))
    draw = ImageDraw.Draw(sheet)
    sequence = resource.descriptor.get("sequence") or {}
    origin_x = int(sequence.get("xorigin", 0)) if isinstance(sequence, dict) else 0
    origin_y = int(sequence.get("yorigin", 0)) if isinstance(sequence, dict) else 0
    bbox = (
        int(resource.descriptor.get("bbox_left", 0)),
        int(resource.descriptor.get("bbox_top", 0)),
        int(resource.descriptor.get("bbox_right", 0)),
        int(resource.descriptor.get("bbox_bottom", 0)),
    )
    for index, image in enumerate(images):
        column = index % columns
        row = index // columns
        x = column * cell_width + 8
        y = row * cell_height + 20
        checker = Image.new("RGBA", image.size, (72, 72, 76, 255))
        checker.alpha_composite(image)
        sheet.alpha_composite(checker, (x, y))
        draw.rectangle((x + bbox[0], y + bbox[1], x + bbox[2], y + bbox[3]), outline=(255, 80, 80, 255), width=1)
        draw.line((x + origin_x - 4, y + origin_y, x + origin_x + 4, y + origin_y), fill=(80, 255, 120, 255), width=1)
        draw.line((x + origin_x, y + origin_y - 4, x + origin_x, y + origin_y + 4), fill=(80, 255, 120, 255), width=1)
        draw.text((x, row * cell_height + 3), f"frame {index}", fill=(240, 240, 240, 255))
    sheet.save(output / "preview.png")
    return []


def _color(value: int) -> tuple[int, int, int, int]:
    return (value & 255, (value >> 8) & 255, (value >> 16) & 255, (value >> 24) & 255)


def _room_preview(index: ProjectIndex, resource: ResourceRecord, output: Path) -> list[str]:
    pillow = _load_pillow()
    if pillow is None:
        return ["Pillow is unavailable; room preview was skipped"]
    Image, ImageDraw, _ImageFont = pillow
    settings = resource.descriptor.get("roomSettings") or {}
    room_width = max(1, int(settings.get("Width", 640)))
    room_height = max(1, int(settings.get("Height", 480)))
    scale = min(1.0, 1024 / room_width, 768 / room_height)
    canvas = Image.new("RGBA", (max(1, round(room_width * scale)), max(1, round(room_height * scale))), (28, 28, 32, 255))
    draw = ImageDraw.Draw(canvas)
    by_name = index.resources_by_name
    legend_entries: list[str] = []
    for layer in reversed(resource.descriptor.get("layers") or []):
        if not isinstance(layer, dict) or layer.get("visible") is False:
            continue
        layer_type = layer.get("resourceType")
        if layer_type == "GMRBackgroundLayer":
            colour = layer.get("colour")
            if isinstance(colour, int):
                draw.rectangle((0, 0, canvas.width, canvas.height), fill=_color(colour))
        if layer_type != "GMRInstanceLayer":
            continue
        for instance in layer.get("instances") or []:
            if not isinstance(instance, dict):
                continue
            x = float(instance.get("x", 0))
            y = float(instance.get("y", 0))
            object_id = instance.get("objectId") or {}
            object_name = object_id.get("name") if isinstance(object_id, dict) else None
            rendered = False
            if isinstance(object_name, str):
                object_resource = by_name.get(object_name.casefold())
                sprite_id = object_resource.descriptor.get("spriteId") if object_resource else None
                sprite_name = sprite_id.get("name") if isinstance(sprite_id, dict) else None
                sprite_resource = by_name.get(sprite_name.casefold()) if isinstance(sprite_name, str) else None
                frames = _sprite_frame_paths(sprite_resource) if sprite_resource else []
                if frames:
                    image = Image.open(frames[0]).convert("RGBA")
                    scale_x = abs(float(instance.get("scaleX", 1.0))) * scale
                    scale_y = abs(float(instance.get("scaleY", 1.0))) * scale
                    image = image.resize((max(1, round(image.width * scale_x)), max(1, round(image.height * scale_y))))
                    rotation = float(instance.get("rotation", 0.0))
                    if rotation:
                        image = image.rotate(-rotation, expand=True)
                    sequence = sprite_resource.descriptor.get("sequence") or {}
                    origin_x = int(sequence.get("xorigin", 0) * scale_x) if isinstance(sequence, dict) else 0
                    origin_y = int(sequence.get("yorigin", 0) * scale_y) if isinstance(sequence, dict) else 0
                    canvas.alpha_composite(image, (round(x * scale) - origin_x, round(y * scale) - origin_y))
                    rendered = True
            if not rendered:
                px, py = round(x * scale), round(y * scale)
                draw.ellipse((px - 3, py - 3, px + 3, py + 3), fill=(255, 180, 40, 255))
            label = str(instance.get("name") or object_name or "instance")
            marker = len(legend_entries) + 1
            px, py = round(x * scale), round(y * scale)
            draw.ellipse((px - 7, py - 7, px + 7, py + 7), fill=(20, 20, 24, 220), outline=(255, 210, 80, 255), width=1)
            draw.text((px - 3, py - 6), str(marker), fill=(255, 255, 255, 255))
            legend_entries.append(f"{marker}. {label} ({object_name or 'unknown'})")
    legend_width = 360
    result = Image.new("RGBA", (canvas.width + legend_width, max(canvas.height, 30 + 17 * len(legend_entries))), (22, 22, 26, 255))
    result.alpha_composite(canvas, (0, 0))
    result_draw = ImageDraw.Draw(result)
    result_draw.text((canvas.width + 12, 10), "Instances", fill=(255, 210, 80, 255))
    for item_index, label in enumerate(legend_entries):
        result_draw.text((canvas.width + 12, 30 + item_index * 17), label, fill=(235, 235, 238, 255))
    result.save(output / "preview.png")
    return []


def _path_preview(resource: ResourceRecord, output: Path) -> list[str]:
    pillow = _load_pillow()
    if pillow is None:
        return ["Pillow is unavailable; path preview was skipped"]
    Image, ImageDraw, _ImageFont = pillow
    points = resource.descriptor.get("points") or []
    parsed = [(float(point.get("x", 0)), float(point.get("y", 0))) for point in points if isinstance(point, dict)]
    if not parsed:
        return ["Path has no points"]
    min_x, max_x = min(x for x, _ in parsed), max(x for x, _ in parsed)
    min_y, max_y = min(y for _, y in parsed), max(y for _, y in parsed)
    width, height, margin = 800, 600, 40
    span_x, span_y = max(1.0, max_x - min_x), max(1.0, max_y - min_y)
    scale = min((width - margin * 2) / span_x, (height - margin * 2) / span_y)
    mapped = [(margin + (x - min_x) * scale, margin + (y - min_y) * scale) for x, y in parsed]
    image = Image.new("RGB", (width, height), (28, 28, 32))
    draw = ImageDraw.Draw(image)
    if len(mapped) > 1:
        draw.line(mapped + ([mapped[0]] if resource.descriptor.get("closed") else []), fill=(80, 180, 255), width=3)
    for index, (x, y) in enumerate(mapped):
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 180, 40))
        draw.text((x + 7, y - 7), str(index), fill=(240, 240, 240))
    image.save(output / "preview.png")
    return []


def _sound_preview(resource: ResourceRecord, output: Path) -> list[str]:
    candidates = [path for path in resource.path.parent.iterdir() if path.suffix.casefold() in {".wav", ".ogg", ".mp3"}]
    if not candidates:
        return ["No supported audio payload was found"]
    source = candidates[0]
    if source.suffix.casefold() != ".wav":
        return [f"Audio payload is {source.suffix}; waveform generation currently supports WAV directly"]
    pillow = _load_pillow()
    if pillow is None:
        return ["Pillow is unavailable; waveform preview was skipped"]
    Image, ImageDraw, _ImageFont = pillow
    try:
        with wave.open(str(source), "rb") as audio:
            channels = audio.getnchannels()
            sample_width = audio.getsampwidth()
            frame_count = audio.getnframes()
            raw = audio.readframes(frame_count)
    except (wave.Error, OSError) as exc:
        return [f"WAV decode failed: {exc}"]
    if sample_width not in {1, 2} or frame_count == 0:
        return [f"Waveform supports non-empty 8/16-bit PCM; found {sample_width * 8}-bit"]
    samples: list[float] = []
    stride = sample_width * channels
    for offset in range(0, len(raw) - stride + 1, stride):
        if sample_width == 1:
            sample = (raw[offset] - 128) / 128
        else:
            sample = int.from_bytes(raw[offset : offset + 2], "little", signed=True) / 32768
        samples.append(sample)
    width, height = 1000, 240
    image = Image.new("RGB", (width, height), (28, 28, 32))
    draw = ImageDraw.Draw(image)
    center = height // 2
    draw.line((0, center, width, center), fill=(80, 80, 88))
    bucket = max(1, len(samples) // width)
    for x in range(width):
        segment = samples[x * bucket : (x + 1) * bucket]
        if not segment:
            break
        low, high = min(segment), max(segment)
        draw.line((x, center - high * (height * 0.45), x, center - low * (height * 0.45)), fill=(80, 200, 255))
    image.save(output / "preview.png")
    return []


def build_preview(tool_root: Path, index: ProjectIndex, resource: ResourceRecord, *, force: bool = False) -> dict[str, Any]:
    digest = _resource_digest(resource)
    output = tool_root / ".gmtool-work" / "previews" / index.name / resource.name / digest[:16]
    manifest_path = output / "manifest.json"
    if manifest_path.is_file() and not force:
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    output.mkdir(parents=True, exist_ok=True)
    references = list(_references(resource.descriptor))
    files = _file_inventory(resource)
    _write_json(output / "resource.json", resource.as_dict(index.root, include_descriptor=True))
    _write_json(output / "dependencies.json", references)
    _write_json(output / "files.json", files)
    (output / "summary.md").write_text(_summary(resource, references), encoding="utf-8", newline="\n")
    _html_preview(resource, output, references, files)
    warnings: list[str] = []
    if resource.type == "GMSprite":
        warnings.extend(_sprite_preview(resource, output))
    elif resource.type == "GMRoom":
        warnings.extend(_room_preview(index, resource, output))
    elif resource.type == "GMPath":
        warnings.extend(_path_preview(resource, output))
    elif resource.type == "GMSound":
        warnings.extend(_sound_preview(resource, output))
    manifest = {
        "resource": resource.name,
        "type": resource.type,
        "sourceHash": digest,
        "project": str(index.project_file),
        "output": str(output),
        "summary": str(output / "summary.md"),
        "normalized": str(output / "resource.json"),
        "dependencies": str(output / "dependencies.json"),
        "files": str(output / "files.json"),
        "previewHtml": str(output / "preview.html"),
        "preview": str(output / "preview.png") if (output / "preview.png").is_file() else None,
        "renderer": "static" if (output / "preview.png").is_file() else "data-only",
        "warnings": warnings,
    }
    audio_payloads = [item["path"] for item in files if item["suffix"] in {".wav", ".ogg", ".mp3", ".flac"}]
    if audio_payloads:
        manifest["audio"] = audio_payloads
    _write_json(manifest_path, manifest)
    return manifest
