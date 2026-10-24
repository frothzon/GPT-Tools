"""Portable animation projects, SCML migration, cutout slicing and exports."""
from __future__ import annotations

import base64
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import uuid
import zipfile
import xml.etree.ElementTree as ET

FORMAT = "gmtool-animation-project"
VERSION = 1
STRIDE = 18
PIVOT_DEFAULT = -9999.0
CURVES = {"instant": 0, "linear": 1, "quadratic": 2, "cubic": 3,
          "quartic": 4, "quintic": 5, "bezier": 6}


class AnimationError(ValueError):
    """An invalid project or animation operation with a user-readable message."""


def uid() -> str:
    return uuid.uuid4().hex


def slug(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_").lower()
    if not value or value[0].isdigit():
        value = "anim_" + value
    return value[:48]


def new_project(name: str = "Untitled Animation") -> tuple[dict, dict[str, bytes]]:
    return ({"format": FORMAT, "version": VERSION, "id": uid(), "name": name,
             "settings": {"canvas": [240, 200], "frame_count": 16, "default_duration_ms": 1000},
             "collections": [{"id": uid(), "key": "characters", "entities": []}]}, {})


def _safe_member(name: str) -> str:
    p = PurePosixPath(name)
    if p.is_absolute() or ".." in p.parts or "\\" in name:
        raise AnimationError(f"Unsafe path in animation archive: {name}")
    return name


def validate_project(project: dict, assets: dict[str, bytes]) -> None:
    if project.get("format") != FORMAT:
        raise AnimationError("This is not a gmtool animation project.")
    if project.get("version") != VERSION:
        raise AnimationError(f"Unsupported animation project version: {project.get('version')}")
    canvas = project.get("settings", {}).get("canvas", [])
    if len(canvas) != 2 or any(not isinstance(v, int) or not 1 <= v <= 8192 for v in canvas):
        raise AnimationError("Canvas width and height must be integers from 1 to 8192.")
    collections = project.get("collections", [])
    if not isinstance(collections, list):
        raise AnimationError("Project collections must be a list.")
    entity_ids, entity_names = set(), set()
    for collection in collections:
        for entity in collection.get("entities", []):
            ident = entity.get("id")
            if not ident or ident in entity_ids:
                raise AnimationError("Character IDs must be present and unique.")
            entity_ids.add(ident)
            name_key = (collection.get("id"), entity.get("name"))
            if name_key in entity_names:
                raise AnimationError(f"Duplicate character name: {entity.get('name')}")
            entity_names.add(name_key)
            part_names = set(entity.get("parts", []))
            bone_names = set(entity.get("bones", []))
            file_ids = {f.get("asset_id") for f in entity.get("files", [])}
            for f in entity.get("files", []):
                if f.get("asset_id") not in assets:
                    raise AnimationError(f"Missing artwork for {entity.get('name')}: {f.get('path')}")
                if f.get("width", 0) < 1 or f.get("height", 0) < 1:
                    raise AnimationError(f"Invalid dimensions for {f.get('path')}")
            for clip in entity.get("animations", []):
                if int(clip.get("duration", 0)) <= 0:
                    raise AnimationError(f"Animation {clip.get('name')} must have a positive duration.")
                for timeline in clip.get("timelines", []):
                    if len(timeline.get("keys", [])) % STRIDE:
                        raise AnimationError(f"Malformed timeline {timeline.get('name')} in {clip.get('name')}.")
                for state in clip.get("mainline", []):
                    for part in state.get("objects", []):
                        if not 0 <= part[0] < len(part_names):
                            raise AnimationError(f"Broken part reference in {clip.get('name')}.")
                    for bone in state.get("bones", []):
                        if not 0 <= bone[0] < len(bone_names):
                            raise AnimationError(f"Broken bone reference in {clip.get('name')}.")


def save_project(path: str | Path, project: dict, assets: dict[str, bytes]) -> Path:
    """Atomically save a portable project ZIP with embedded PNG assets."""
    validate_project(project, assets)
    path = Path(path).expanduser().resolve()
    if path.suffix.lower() != ".gmanim":
        path = path.with_suffix(".gmanim")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    manifest = json.dumps(project, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            archive.writestr("project.json", manifest)
            for asset_id, data in sorted(assets.items()):
                if not re.fullmatch(r"[a-f0-9]{64}", asset_id):
                    raise AnimationError("Artwork IDs must be SHA256 hashes.")
                archive.writestr(f"assets/{asset_id}.png", data)
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return path


def load_project(path: str | Path) -> tuple[dict, dict[str, bytes]]:
    """Read a .gmanim archive with traversal, size and hash checks."""
    path = Path(path).expanduser().resolve()
    if not path.is_file():
        raise AnimationError(f"Animation project does not exist: {path}")
    assets: dict[str, bytes] = {}
    with zipfile.ZipFile(path) as archive:
        names = [_safe_member(n) for n in archive.namelist()]
        if len(names) > 10000 or sum(i.file_size for i in archive.infolist()) > 512 * 1024 * 1024:
            raise AnimationError("Animation project exceeds the supported archive size.")
        if "project.json" not in names:
            raise AnimationError("Animation project is missing project.json.")
        project = json.loads(archive.read("project.json").decode("utf-8"))
        for name in names:
            if not name.startswith("assets/") or not name.endswith(".png"):
                continue
            ident = Path(name).stem
            data = archive.read(name)
            if hashlib.sha256(data).hexdigest() != ident:
                raise AnimationError(f"Artwork hash mismatch in {name}")
            assets[ident] = data
    validate_project(project, assets)
    return project, assets


def image_bytes(data: bytes) -> tuple[bytes, int, int]:
    try:
        from PIL import Image
    except ImportError as exc:
        raise AnimationError("Install gmtool with the animation extra: py -3 -m pip install -e .[animation]") from exc
    try:
        image = Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception as exc:
        raise AnimationError(f"Cannot read PNG artwork: {exc}") from exc
    if image.width > 8192 or image.height > 8192:
        raise AnimationError("Artwork is limited to 8192 pixels per side.")
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue(), image.width, image.height


def store_asset(assets: dict[str, bytes], data: bytes) -> tuple[str, int, int]:
    normalized, width, height = image_bytes(data)
    ident = hashlib.sha256(normalized).hexdigest()
    assets[ident] = normalized
    return ident, width, height


def _curve(key: list[float | int], t: float) -> float:
    kind = int(key[11])
    if kind == 0:
        return 0.0
    if kind == 1:
        return t
    if kind == 2:
        return t * t
    if kind == 3:
        return t * t * t
    if kind == 4:
        return t ** 4
    if kind == 5:
        return t ** 5
    if kind == 6:
        # SCML stores the four cubic Bezier control coordinates in slots 12-15.
        x1, y1, x2, y2 = [float(v) for v in key[12:16]]
        u = t
        for _ in range(8):
            q = 1 - u
            x = 3*q*q*u*x1 + 3*q*u*u*x2 + u*u*u
            dx = 3*q*q*x1 + 6*q*u*(x2-x1) + 3*u*u*(1-x2)
            if abs(dx) < 1e-7: break
            u = min(1, max(0, u - (x-t)/dx))
        q = 1-u
        return 3*q*q*u*y1 + 3*q*u*u*y2 + u*u*u
    return t


def evaluate_track(timeline: dict, time_ms: float) -> list[float]:
    flat = timeline["keys"]
    keys = [flat[i:i+STRIDE] for i in range(0, len(flat), STRIDE)]
    if len(keys) == 1 or time_ms <= keys[0][0]:
        return list(map(float, keys[0]))
    if time_ms >= keys[-1][0]:
        return list(map(float, keys[-1]))
    right = next(i for i, key in enumerate(keys) if key[0] >= time_ms)
    left_key, right_key = keys[right-1], keys[right]
    span = max(1.0, float(right_key[0] - left_key[0]))
    t = _curve(left_key, (time_ms-left_key[0])/span)
    result = list(map(float, left_key))
    for i in range(1, 11):
        if i == 3:
            delta = ((right_key[i]-left_key[i]+180) % 360)-180
            result[i] = left_key[i]+delta*t
        else:
            result[i] = left_key[i] + (right_key[i]-left_key[i])*t
    return result


def _compose(parent: tuple[float, ...] | None, local: list[float]) -> tuple[float, ...]:
    """Compose Spriter component transforms, including mirrored-parent rotation."""
    x, y, angle, sx, sy, alpha = local[:6]
    if parent is None:
        return (x, y, angle, sx, sy, alpha)
    px, py, pa, psx, psy, palpha = parent
    radians = math.radians(pa)
    x2, y2 = x*psx, y*psy
    wx = px + math.cos(radians)*x2 - math.sin(radians)*y2
    wy = py + math.sin(radians)*x2 + math.cos(radians)*y2
    wa = pa + (angle if psx*psy >= 0 else -angle)
    return (wx, wy, wa, psx*sx, psy*sy, palpha*alpha)


def render_frame(project: dict, entity: dict, clip: dict, assets: dict[str, bytes], time_ms: float) -> bytes:
    """Render a cutout pose to a transparent PNG using the normalized rig model."""
    try:
        from PIL import Image
    except ImportError as exc:
        raise AnimationError("Rendering requires Pillow; install gmtool[animation].") from exc
    canvas_w, canvas_h = project["settings"]["canvas"]
    pose_key = clip.get("mainline", [{}])[0]
    for item in clip.get("mainline", []):
        if item.get("time", 0) <= time_ms: pose_key = item
        else: break
    timelines = clip.get("timelines", [])
    bone_world: list[tuple[float, ...]] = []
    for _, timeline_index, _, parent_ref in pose_key.get("bones", []):
        row = evaluate_track(timelines[timeline_index], time_ms)
        parent = bone_world[parent_ref] if 0 <= parent_ref < len(bone_world) else None
        bone_world.append(_compose(parent, row[1:7]))

    # Keep the image legible at default canvas sizes while respecting authored pixel coordinates.
    max_dim = max([f.get("width", 1) for f in entity.get("files", [])] + [100])
    scale = min(1.0, canvas_w/(max_dim*1.5), canvas_h/(max_dim*1.35))
    output = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    records = sorted(pose_key.get("objects", []), key=lambda item: item[4])
    for part_index, timeline_index, _, parent_ref, z_index in records:
        if not 0 <= part_index < len(entity.get("parts", [])):
            continue
        row = evaluate_track(timelines[timeline_index], time_ms)
        file_index = int(row[9])
        if not 0 <= file_index < len(entity.get("files", [])):
            continue
        file_info = entity["files"][file_index]
        asset = assets.get(file_info.get("asset_id", ""))
        if asset is None:
            continue
        sprite = Image.open(io.BytesIO(asset)).convert("RGBA")
        parent = bone_world[parent_ref] if 0 <= parent_ref < len(bone_world) else None
        world = _compose(parent, row[1:7])
        _, _, angle, sx, sy, alpha = world
        keyed_pivot_x, keyed_pivot_y = row[7], row[8]
        pivot_x = float(file_info.get("pivot_x", 0.0))*sprite.width if keyed_pivot_x <= PIVOT_DEFAULT else keyed_pivot_x*sprite.width
        pivot_y = (1-float(file_info.get("pivot_y", 1.0)))*sprite.height if keyed_pivot_y <= PIVOT_DEFAULT else (1-keyed_pivot_y)*sprite.height
        radians = math.radians(angle)
        # Convert Spriter's y-up transform to image/screen y-down coordinates.
        a = scale*math.cos(radians)*sx
        b = scale*math.sin(radians)*sx
        c = scale*math.sin(radians)*sy
        d = -scale*math.cos(radians)*sy
        tx = canvas_w*0.5 + scale*world[0] - a*pivot_x - c*pivot_y
        ty = canvas_h*0.78 - scale*world[1] - b*pivot_x - d*pivot_y
        determinant = a*d-b*c
        if abs(determinant) < 1e-9:
            continue
        ia, ib, ic, id_ = d/determinant, -b/determinant, -c/determinant, a/determinant
        ox = -(ia*tx+ic*ty); oy=-(ib*tx+id_*ty)
        transformed = sprite.transform((canvas_w, canvas_h), Image.Transform.AFFINE,
                                       (ia,ic,ox,ib,id_,oy), resample=Image.Resampling.BICUBIC)
        if alpha < 1:
            channel = transformed.getchannel("A").point(lambda value: round(value*max(0,min(1,alpha))))
            transformed.putalpha(channel)
        output.alpha_composite(transformed)
    stream = io.BytesIO(); output.save(stream, format="PNG")
    return stream.getvalue()


def read_scml(path: str | Path) -> tuple[dict, dict[str, bytes]]:
    """Migrate SCML data to the native archive model; no Spriter app is used."""
    path = Path(path).expanduser().resolve()
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        raise AnimationError(f"Cannot read SCML: {exc}") from exc
    if root.tag != "spriter_data":
        raise AnimationError("Expected an SCML spriter_data document.")
    allowed = {"spriter_data", "folder", "file", "entity", "obj_info", "animation", "mainline", "timeline", "key", "bone_ref", "object_ref", "bone", "object", "character_map", "map", "eventline", "event"}
    unsupported = sorted({node.tag for node in root.iter()} - allowed)
    if unsupported:
        raise AnimationError("Unsupported SCML features: " + ", ".join("<"+x+">" for x in unsupported))
    file_map = {}
    for folder in root.findall("folder"):
        for item in folder.findall("file"):
            key = (folder.get("id", "0"), item.get("id", "0"))
            rel = item.get("name", "")
            image_path = (path.parent / rel).resolve()
            if path.parent not in image_path.parents:
                raise AnimationError(f"Image path escapes the SCML directory: {rel}")
            if not image_path.is_file():
                raise AnimationError(f"SCML artwork is missing: {image_path}")
            ident, width, height = store_asset_placeholder(image_path)
            file_map[key] = {"asset_id": ident, "path": rel.replace("\\", "/"), "width": width, "height": height,
                             "pivot_x": float(item.get("pivot_x", "0")), "pivot_y": float(item.get("pivot_y", "1")),
                             "name": Path(rel).stem}
    assets = {}
    for item in file_map.values(): assets[item["asset_id"]] = store_asset_placeholder_data((path.parent/item["path"]).read_bytes())
    entities = []
    for entity in root.findall("entity"):
        ename = entity.get("name", "character")
        animations_xml = entity.findall("animation")
        bone_names, part_names = [], []
        for info in entity.findall("obj_info"):
            if info.get("type") == "bone" and info.get("name") not in bone_names: bone_names.append(info.get("name", ""))
        all_timelines = [tl for anim in animations_xml for tl in anim.findall("timeline")]
        for timeline in all_timelines:
            kind = timeline.get("object_type", timeline.get("type", "sprite"))
            target = bone_names if kind == "bone" else part_names
            if timeline.get("name") not in target: target.append(timeline.get("name", ""))
        used_pairs = set()
        for anim in animations_xml:
            for obj in anim.findall(".//object"):
                if obj.get("folder") not in (None, "-1"): used_pairs.add((obj.get("folder"), obj.get("file")))
        for cmap in entity.findall("character_map"):
            for m in cmap.findall("map"):
                if m.get("folder", "-1") != "-1": used_pairs.add((m.get("folder"), m.get("file")))
                if m.get("target_folder", "-1") != "-1": used_pairs.add((m.get("target_folder"), m.get("target_file")))
        ordered_pairs = sorted(used_pairs, key=lambda pair:(int(pair[0]), int(pair[1])))
        local_files = [file_map[pair] for pair in ordered_pairs]
        local_index = {pair:i for i,pair in enumerate(ordered_pairs)}
        clips = []
        for anim in animations_xml:
            timelines, timeline_index, timeline_key_index = [], {}, {}
            for timeline in anim.findall("timeline"):
                tid = timeline.get("id", "")
                kind = timeline.get("object_type", timeline.get("type", "sprite"))
                keys = sorted(timeline.findall("key"), key=lambda k:int(k.get("time", "0")))
                timeline_index[tid] = len(timelines)
                timeline_key_index[tid] = {k.get("id", "0"):i for i,k in enumerate(keys)}
                flat = []
                for key in keys:
                    value = key.find("bone" if kind == "bone" else "object")
                    attrs = value.attrib if value is not None else {}
                    folder, file = attrs.get("folder", "-1"), attrs.get("file", "-1")
                    file_index = local_index.get((folder, file), -1) if folder != "-1" else -1
                    curve = key.get("curve_type", "linear").lower()
                    if curve not in CURVES: raise AnimationError(f"Unsupported interpolation curve: {curve}")
                    row = [int(key.get("time", "0")), float(attrs.get("x", 0)), float(attrs.get("y", 0)), float(attrs.get("angle", 0)),
                           float(attrs.get("scale_x", 1)), float(attrs.get("scale_y", 1)), float(attrs.get("a", 1)),
                           float(attrs.get("pivot_x", PIVOT_DEFAULT)), float(attrs.get("pivot_y", PIVOT_DEFAULT)), file_index,
                           int(key.get("spin", 1)), CURVES[curve], *[float(key.get(f"c{i}", .5)) for i in range(1,7)]]
                    flat.extend(row)
                timelines.append({"name":timeline.get("name", ""),"id":tid,"object_type":kind,"key_ids":[k.get("id", "0") for k in keys],"key_count":len(keys),"keys":flat})
            mainline = []
            for mk in sorted(anim.findall("mainline/key"), key=lambda k:int(k.get("time", "0"))):
                bone_refs = mk.findall("bone_ref")
                name_by_ref = {r.get("id", ""):anim.find(f"timeline[@id='{r.get('timeline','')}']").get("name", "") for r in bone_refs}
                ordered, pending = [], list(bone_refs)
                while pending:
                    ready = next((r for r in pending if r.get("parent", "-1") == "-1" or r.get("parent") in {x.get("id") for x in ordered}), None)
                    if ready is None: raise AnimationError(f"Broken bone hierarchy in {ename}/{anim.get('name')}")
                    ordered.append(ready); pending.remove(ready)
                ref_indexes = {r.get("id", ""):i for i,r in enumerate(ordered)}
                bones = []
                for ref in ordered:
                    tl = ref.get("timeline", ""); key = ref.get("key", "0")
                    if tl not in timeline_index or key not in timeline_key_index[tl]: raise AnimationError("Mainline bone points to a missing timeline key.")
                    parent = ref.get("parent", "-1")
                    bones.append([bone_names.index(name_by_ref[ref.get("id", "")]),timeline_index[tl],timeline_key_index[tl][key],-1 if parent=="-1" else ref_indexes[parent]])
                objects = []
                for ref in mk.findall("object_ref"):
                    tl=ref.get("timeline", ""); key=ref.get("key", "0")
                    if tl not in timeline_index or key not in timeline_key_index[tl]: raise AnimationError("Mainline sprite points to a missing timeline key.")
                    timeline=anim.find(f"timeline[@id='{tl}']"); part=part_names.index(timeline.get("name", "")); parent=ref.get("parent", "-1")
                    objects.append([part,timeline_index[tl],timeline_key_index[tl][key],-1 if parent=="-1" else ref_indexes.get(parent,-1),int(ref.get("z_index", 0))])
                mainline.append({"time":int(mk.get("time", 0)),"id":mk.get("id", "0"),"curve":[CURVES.get(mk.get("curve_type", "linear"),1),*[float(mk.get(f"c{i}", .5)) for i in range(1,5)]],"bones":bones,"objects":sorted(objects,key=lambda o:o[4])})
            events=[]
            for line in anim.findall("eventline"):
                name=line.get("name", "event")
                for key in line.findall("key"):
                    children=key.findall("event")
                    if not children: events.append({"time":int(key.get("time",0)),"name":key.get("name",name),"payload":{"text":(key.text or "").strip()}})
                    for child in children: events.append({"time":int(key.get("time",0)),"name":name,"payload":dict(child.attrib)})
            clips.append({"name":anim.get("name","animation"),"id":anim.get("id",""),"duration":int(anim.get("length",1000)),"looping":anim.get("looping","true").lower()=="true","timelines":timelines,"mainline":mainline,"events":sorted(events,key=lambda e:e["time"])})
        maps=[]
        for cmap in entity.findall("character_map"):
            mappings=[]
            for item in cmap.findall("map"):
                source=local_index.get((item.get("folder","-1"),item.get("file","-1")),-1)
                target=local_index.get((item.get("target_folder","-1"),item.get("target_file","-1")),-1)
                mappings.append({"source":source,"target":target})
            maps.append({"name":cmap.get("name","map"),"maps":mappings})
        entities.append({"id":entity.get("id",uid()),"name":ename,"bones":bone_names,"bone_lengths":[12.0 for _ in bone_names],"parts":part_names,"files":local_files,"character_maps":maps,"animations":clips})
    project, _ = new_project(path.stem)
    project["collections"]=[{"id":uid(),"key":"zombies","source":str(path),"entities":entities}]
    validate_project(project, assets)
    return project, assets


def store_asset_placeholder(path: Path) -> tuple[str, int, int]:
    data = path.read_bytes()
    normalized, width, height = image_bytes(data)
    return hashlib.sha256(normalized).hexdigest(), width, height


def store_asset_placeholder_data(data: bytes) -> bytes:
    return image_bytes(data)[0]


def cut_image(data: bytes, p0: list[float], p1: list[float], joint: list[float], overlap: float = 5.0, cap_radius: float = 9.0) -> tuple[bytes, bytes, list[float], list[float], list[float]]:
    """Split RGBA art along a user-drawn line and add a rounded opaque joint core."""
    try:
        import numpy as np
        from PIL import Image
    except ImportError as exc:
        raise AnimationError("Image slicing requires Pillow and NumPy; install gmtool[animation].") from exc
    image = Image.open(io.BytesIO(data)).convert("RGBA")
    pixels = np.asarray(image).copy()
    ax, ay = map(float, p0); bx, by = map(float, p1); jx, jy = map(float, joint)
    dx, dy = bx-ax, by-ay
    length = math.hypot(dx,dy)
    if length < 3: raise AnimationError("Cut line must be at least 3 pixels long.")
    nx, ny = -dy/length, dx/length
    h,w = pixels.shape[:2]
    yy,xx=np.mgrid[0:h,0:w]; xx=xx+.5; yy=yy+.5
    signed=(xx-ax)*nx+(yy-ay)*ny
    disk=(xx-jx)**2+(yy-jy)**2 <= max(2.0,cap_radius)**2
    alpha=pixels[:,:,3] > 0
    if not alpha.any(): raise AnimationError("Cannot slice a fully transparent image.")
    # Preserve the original outline, overlap both halves, and round the shared socket.
    upper=alpha & ((signed <= overlap/2) | disk)
    lower=alpha & ((signed >= -overlap/2) | disk)
    nearest_y,nearest_x=np.where(alpha)
    nearest=int(np.argmin((nearest_x+.5-jx)**2+(nearest_y+.5-jy)**2))
    color=pixels[nearest_y[nearest],nearest_x[nearest],:3]
    for mask in (upper,lower):
        newly=disk & ~mask
        # Extend nearby interior color into transparent pixels inside the cap.
        mask |= newly
    def crop(mask,upper_side):
        arr=pixels.copy();
        original_alpha=arr[:,:,3].copy()
        arr[:,:,3]=np.where(mask,original_alpha,0).astype(np.uint8)
        fill=disk & (arr[:,:,3]==0)
        arr[fill,:3]=color;arr[fill,3]=255
        ys,xs=np.where(arr[:,:,3]>0)
        if not len(xs):raise AnimationError("Cut produced an empty sprite part.")
        # Add a transparent guard border around the cropped part.
        x0=max(0,int(xs.min())-1);y0=max(0,int(ys.min())-1);x1=min(w,int(xs.max())+2);y1=min(h,int(ys.max())+2)
        result=Image.fromarray(arr[y0:y1,x0:x1])
        out=io.BytesIO();result.save(out,format="PNG",optimize=True)
        return out.getvalue(),[x0,y0]
    first,first_offset=crop(upper,True);second,second_offset=crop(lower,False)
    return first,second,[jx,jy],first_offset,second_offset


def _row(time_ms: int, x: float, y: float, angle: float, sx: float, sy: float, alpha: float, file_index: int) -> list[float | int]:
    return [time_ms,x,y,angle,sx,sy,alpha,PIVOT_DEFAULT,PIVOT_DEFAULT,file_index,1,CURVES["linear"],.5,.5,.5,.5,.5,.5]


def _clip(name: str, duration: int, looping: bool, motion: list[tuple[int,float,float,float,float,float,float]]) -> dict:
    bone_keys=[];sprite_keys=[]
    for time_ms,x,y,angle,sx,sy,alpha in motion:
        bone_keys.extend(_row(time_ms,x,y,angle,sx,sy,alpha,-1))
        sprite_keys.extend(_row(time_ms,0,0,0,1,1,1,0))
    return {"name":name,"id":uid(),"duration":duration,"looping":looping,
            "timelines":[{"name":"root","id":"0","object_type":"bone","key_ids":[str(i) for i in range(len(motion))],"key_count":len(motion),"keys":bone_keys},
                         {"name":"body","id":"1","object_type":"sprite","key_ids":[str(i) for i in range(len(motion))],"key_count":len(motion),"keys":sprite_keys}],
            "mainline":[{"time":0,"id":"0","curve":[CURVES["linear"],.5,.5,.5,.5],"bones":[[0,0,0,-1]],"objects":[[0,1,0,0,0]]}],"events":[]}


def add_character(project: dict, assets: dict[str, bytes], name: str, png: bytes, collection: str = "characters") -> dict:
    name=name.strip()
    if not name: raise AnimationError("Enter a character name.")
    if any(e.get("name", "").casefold()==name.casefold() for c in project["collections"] for e in c.get("entities", [])):
        raise AnimationError(f"A character named {name!r} already exists.")
    if not project["collections"]: project["collections"].append({"id":uid(),"key":collection,"entities":[]})
    target=next((c for c in project["collections"] if c.get("key")==collection), project["collections"][0])
    asset_id,width,height=store_asset(assets,png)
    filename=slug(name)+".png"
    frame_count=project["settings"].get("frame_count",16); duration=project["settings"].get("default_duration_ms",1000)
    cycle=duration
    idle=[(0,0,0,0,1,1,1),(cycle//2,0,2,-1,1,1,1),(cycle,0,0,0,1,1,1)]
    walk=[(0,0,0,-2,1,1,1),(cycle//4,0,5,2,1,1,1),(cycle//2,0,0,-2,1,1,1),(cycle*3//4,0,5,2,1,1,1),(cycle,0,0,-2,1,1,1)]
    attack=[(0,0,0,0,1,1,1),(cycle*35//100,5,0,-9,1.04,.96,1),(cycle*65//100,0,0,5,.98,1.02,1),(cycle,0,0,0,1,1,1)]
    die=[(0,0,0,0,1,1,1),(cycle*45//100,7,-4,28,1.05,.96,.9),(cycle*75//100,12,-8,72,1.02,.98,.6),(cycle,14,-10,88,.98,1.02,0)]
    entity={"id":uid(),"name":name,"bones":["root"],"bone_lengths":[12.0],"parts":["body"],
            "files":[{"asset_id":asset_id,"path":filename,"width":width,"height":height,"pivot_x":.5,"pivot_y":.5,"name":filename,"sprite_name":slug(name)+"_body","sprite":slug(name)+"_body"}],"character_maps":[],
            "animations":[_clip("idle",cycle,True,idle),_clip("walk",cycle,True,walk),_clip("attack",cycle,True,attack),_clip("die",cycle,False,die)]}
    # Default body attachment is centered on the root; users can move the pivot and rig handles on the canvas.
    target.setdefault("entities",[]).append(entity)
    validate_project(project,assets)
    return entity


def add_key(entity: dict, animation_name: str, timeline_index: int, time_ms: int) -> int:
    clip=next((a for a in entity["animations"] if a["name"]==animation_name),None)
    if clip is None: raise AnimationError(f"Unknown animation: {animation_name}")
    if not 0 <= timeline_index < len(clip["timelines"]): raise AnimationError("Select a valid timeline.")
    timeline=clip["timelines"][timeline_index];time_ms=max(0,min(int(time_ms),int(clip["duration"])))
    flat=timeline["keys"];keys=[flat[i:i+STRIDE] for i in range(0,len(flat),STRIDE)]
    for index,key in enumerate(keys):
        if int(key[0])==time_ms:return index
    row=evaluate_track(timeline,time_ms);row[0]=time_ms
    insert=next((i for i,key in enumerate(keys) if key[0]>time_ms),len(keys));keys.insert(insert,row)
    timeline["keys"]=[value for key in keys for value in key];timeline["key_ids"].insert(insert,uid());timeline["key_count"]=len(keys)
    for state in clip["mainline"]:
        for bone in state.get("bones",[]):
            if bone[1]==timeline_index:bone[2]=max(0,next((i for i,key in enumerate(keys) if key[0]>=state["time"]),len(keys)-1))
        for part in state.get("objects",[]):
            if part[1]==timeline_index:part[2]=max(0,next((i for i,key in enumerate(keys) if key[0]>=state["time"]),len(keys)-1))
    return insert


def set_key_value(entity: dict, animation_name: str, timeline_index: int, key_index: int, field: str, value: float) -> None:
    fields={"x":1,"y":2,"angle":3,"scale_x":4,"scale_y":5,"alpha":6,"pivot_x":7,"pivot_y":8}
    if field not in fields: raise AnimationError(f"Unsupported key field: {field}")
    clip=next(a for a in entity["animations"] if a["name"]==animation_name)
    timeline=clip["timelines"][timeline_index];offset=key_index*STRIDE
    if offset<0 or offset+STRIDE>len(timeline["keys"]):raise AnimationError("Select a valid keyframe.")
    timeline["keys"][offset+fields[field]]=float(value)


def add_event(entity: dict, animation_name: str, name: str, time_ms: int, payload: dict | None = None) -> dict:
    clip=next((a for a in entity["animations"] if a["name"]==animation_name),None)
    if clip is None:raise AnimationError(f"Unknown animation: {animation_name}")
    if not name.strip():raise AnimationError("Enter an event name.")
    event={"time":max(0,min(int(time_ms),int(clip["duration"]))),"name":name.strip(),"payload":payload or {},"source":"harness"}
    clip.setdefault("events",[]).append(event);clip["events"].sort(key=lambda e:e["time"])
    return event


def export_pngs(project: dict, assets: dict[str, bytes], output: str | Path) -> dict:
    """Render preview frame sequences and contact strips for all clips."""
    from PIL import Image
    output=Path(output).expanduser().resolve(); output.mkdir(parents=True,exist_ok=True)
    width,height=project["settings"]["canvas"]; frame_count=project["settings"].get("frame_count",16)
    result={"frames":0,"clips":0,"files":[]}
    for collection in project.get("collections",[]):
        for entity in collection.get("entities",[]):
            for clip in entity.get("animations",[]):
                folder=output/slug(entity["name"])/slug(clip["name"]);folder.mkdir(parents=True,exist_ok=True)
                frames=[]
                for i in range(frame_count):
                    data=render_frame(project,entity,clip,assets,clip["duration"]*i/frame_count)
                    frame=Image.open(io.BytesIO(data)).convert("RGBA")
                    frames.append(frame);path=folder/f"{i:03}.png";frame.save(path);result["files"].append(str(path));result["frames"]+=1
                strip=Image.new("RGBA",(width*frame_count,height),(0,0,0,0))
                for i,frame in enumerate(frames):strip.alpha_composite(frame,(i*width,0))
                sp=output/slug(entity["name"])/f"{slug(clip['name'])}_strip.png";strip.save(sp);result["files"].append(str(sp));result["clips"]+=1
    return result


def export_gifs(project: dict, assets: dict[str, bytes], output: str | Path) -> dict:
    """Render loop-aware GIFs from exported PNG sequences."""
    from PIL import Image
    output=Path(output).expanduser().resolve();rendered=export_pngs(project,assets,output/"_frames")
    gifs=[]
    for collection in project.get("collections",[]):
        for entity in collection.get("entities",[]):
            for clip in entity.get("animations",[]):
                folder=output/slug(entity["name"])/slug(clip["name"]);folder.mkdir(parents=True,exist_ok=True)
                frames=[Image.open(output/"_frames"/slug(entity["name"])/slug(clip["name"])/f"{i:03}.png").convert("RGBA") for i in range(project["settings"].get("frame_count",16))]
                duration=int(clip["duration"]);bounds=[round((i*duration/len(frames))/10)*10 for i in range(len(frames)+1)];durations=[max(10,bounds[i+1]-bounds[i]) for i in range(len(frames))]
                path=folder/f"{slug(clip['name'])}.gif"
                # GIF palette transparency is binary; retain clean transparent edges with a reserved transparent index.
                frames[0].save(path,save_all=True,append_images=frames[1:],duration=durations,loop=0 if clip.get("looping") else 1,transparency=0,disposal=2,optimize=False)
                gifs.append(str(path))
    return {"gifs":gifs,"png":rendered}
