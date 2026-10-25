"""Stateful operations shared by the editor HTTP API and headless CLI."""
from __future__ import annotations

import base64
import copy
import io
import json
from pathlib import Path
import zipfile

from . import project as model


class HarnessState:
    def __init__(self, tool_root: Path, project_path: Path | None = None):
        self.tool_root=Path(tool_root).resolve()
        self.project,self.assets=model.load_project(project_path) if project_path else model.new_project()
        self.path=Path(project_path).resolve() if project_path else None

    def entity(self, collection_id: str, entity_id: str) -> dict:
        for collection in self.project["collections"]:
            if collection["id"]==collection_id:
                for entity in collection.get("entities",[]):
                    if entity["id"]==entity_id:return entity
        raise model.AnimationError("Select a character in the project tree.")

    def snapshot(self) -> dict:
        return {"project":self.project,"assets":{key:base64.b64encode(value).decode("ascii") for key,value in self.assets.items()},"path":str(self.path) if self.path else None}

    def action(self, name: str, args: dict) -> dict:
        if name=="snapshot":return self.snapshot()
        if name=="new_project":
            self.project,self.assets=model.new_project(args.get("name","Untitled Animation"));self.path=None
            return self.snapshot()
        if name=="load_path":
            path=Path(args["path"]).expanduser().resolve();self.project,self.assets=model.load_project(path);self.path=path
            return self.snapshot()
        if name=="load_upload":
            data=base64.b64decode(args["archive"],validate=True)
            temporary=self.tool_root/".gmtool-work"/"animation-upload.gmanim";temporary.parent.mkdir(parents=True,exist_ok=True);temporary.write_bytes(data)
            try:self.project,self.assets=model.load_project(temporary);self.path=None
            finally:temporary.unlink(missing_ok=True)
            return self.snapshot()
        if name=="save":
            if args.get("path"):self.path=Path(args["path"]).expanduser().resolve()
            if self.path:
                saved=model.save_project(self.path,self.project,self.assets);self.path=saved;return {"path":str(saved)}
            data=project_archive(self.project,self.assets)
            return {"download":"project.gmanim","archive":base64.b64encode(data).decode("ascii")}
        if name=="migrate_scml":
            self.project,self.assets=model.read_scml(args["path"]);self.path=None
            return self.snapshot()
        if name=="add_character":
            entity=model.add_character(self.project,self.assets,args["name"],base64.b64decode(args["png"],validate=True),args.get("collection","characters"))
            asset_ids={f["asset_id"] for f in entity["files"]}
            return {"entity_id":entity["id"],"project":self.project,"new_assets":{i:base64.b64encode(self.assets[i]).decode("ascii") for i in asset_ids}}
        if name=="add_part":
            entity=self.entity(args["collection_id"],args["entity_id"])
            info=model.add_part(self.project,entity,self.assets,args["name"],base64.b64decode(args["png"],validate=True),args.get("bone","root"),float(args.get("pivot_x",.5)),float(args.get("pivot_y",.5)))
            return {"part":info["name"],"project":self.project,"new_assets":{info["asset_id"]:base64.b64encode(self.assets[info["asset_id"]]).decode("ascii")}}
        if name=="add_bone":
            entity=self.entity(args["collection_id"],args["entity_id"])
            bone=model.add_bone(self.project,entity,args["name"],args.get("parent","root"),float(args.get("length",18)))
            model.validate_project(self.project,self.assets)
            return {"bone":bone,"project":self.project}
        if name=="add_character_map":
            entity=self.entity(args["collection_id"],args["entity_id"])
            mapping=model.add_character_map(entity,args["name"])
            return {"map":mapping,"project":self.project}
        if name=="set_character_map_entry":
            entity=self.entity(args["collection_id"],args["entity_id"])
            mapping=model.set_character_map_entry(entity,args["name"],int(args["source"]),int(args["target"]))
            return {"map":mapping,"project":self.project}
        if name=="remove_character_map":
            entity=self.entity(args["collection_id"],args["entity_id"])
            removed=model.remove_character_map(self.project,entity,args["name"])
            return {"removed":removed,"project":self.project}
        if name=="set_preview_maps":
            entity=self.entity(args["collection_id"],args["entity_id"])
            active=model.set_preview_maps(self.project,entity,args.get("names",[]))
            return {"active":active,"project":self.project}
        if name=="replace_part_art":
            entity=self.entity(args["collection_id"],args["entity_id"])
            info=model.replace_part_art(entity,self.assets,args["part"],base64.b64decode(args["png"],validate=True))
            return {"part":args["part"],"project":self.project,"new_assets":{info["asset_id"]:base64.b64encode(self.assets[info["asset_id"]]).decode("ascii")}}
        if name=="slice":
            entity=self.entity(args["collection_id"],args["entity_id"])
            upper,lower=model.slice_part(entity,self.assets,args["part"],int(args["timeline_index"]),args["p0"],args["p1"],args["joint"],float(args.get("overlap",5)),float(args.get("cap_radius",9)))
            ids={f["asset_id"] for f in entity["files"] if f["name"] in {upper,lower}}
            return {"parts":[upper,lower],"project":self.project,"new_assets":{i:base64.b64encode(self.assets[i]).decode("ascii") for i in ids}}
        if name=="part_art":
            entity=self.entity(args["collection_id"],args["entity_id"]);part=args["part"]
            clip=next((c for c in entity["animations"] if c["name"]==args.get("animation")),entity["animations"][0])
            timeline=next((t for t in clip["timelines"] if t.get("object_type")=="sprite" and t.get("name")==part),None)
            if timeline is None:raise model.AnimationError(f"No sprite track for {part}")
            row=timeline["keys"][:model.STRIDE];file_index=int(row[9]);file_info=entity["files"][file_index]
            return {"image":base64.b64encode(self.assets[file_info["asset_id"]]).decode("ascii"),"width":file_info["width"],"height":file_info["height"],"timeline_index":clip["timelines"].index(timeline)}
        if name=="add_key":
            entity=self.entity(args["collection_id"],args["entity_id"])
            index=model.add_key(entity,args["animation"],int(args["timeline_index"]),int(args["time_ms"]))
            return {"key_index":index,"project":self.project}
        if name=="set_keys":
            entity=self.entity(args["collection_id"],args["entity_id"]);animation=args["animation"]
            values=args.get("values",{});ordered=[(field,value) for field,value in values.items() if field!="time_ms"]
            if "time_ms" in values:ordered.append(("time_ms",values["time_ms"]))
            for field,value in ordered:model.set_key_value(entity,animation,int(args["timeline_index"]),int(args["key_index"]),field,float(value))
            clip=next(a for a in entity["animations"] if a["name"]==animation);timeline_index=int(args["timeline_index"])
            if clip["timelines"][timeline_index].get("object_type")=="sprite":
                for state in clip.get("mainline",[]):
                    for ref in state.get("objects",[]):
                        if ref[1]==timeline_index:ref[4]=int(args.get("z",ref[4]))
                    state["objects"].sort(key=lambda ref:ref[4])
            return {"project":self.project}
        if name=="set_key":
            entity=self.entity(args["collection_id"],args["entity_id"])
            model.set_key_value(entity,args["animation"],int(args["timeline_index"]),int(args["key_index"]),args["field"],float(args["value"]))
            return {"project":self.project}
        if name=="add_event":
            entity=self.entity(args["collection_id"],args["entity_id"])
            event=model.add_event(entity,args["animation"],args["name"],int(args["time_ms"]),args.get("payload",{}))
            return {"event":event,"project":self.project}
        if name=="add_clip":
            entity=self.entity(args["collection_id"],args["entity_id"]);clip=model.add_clip(entity,args["name"])
            return {"clip":clip["name"],"project":self.project}
        if name=="render":
            entity=self.entity(args["collection_id"],args["entity_id"])
            clip=next((c for c in entity["animations"] if c["name"]==args["animation"]),None)
            if clip is None:raise model.AnimationError("Select an animation.")
            return {"png":base64.b64encode(model.render_frame(self.project,entity,clip,self.assets,float(args["time_ms"]))).decode("ascii")}
        if name in {"export_png","export_gif"}:
            return self.export(name)
        if name=="export_yymps":
            from . import exporter
            output=self.tool_root/".gmtool-work"/"animation-exports"/self.project["id"]/(model.slug(self.project.get("name","animation"))+".yymps")
            report=exporter.export_yymps(self.project,self.assets,args.get("template_project", ""),output,args.get("project_tool"))
            return {"download":output.name,"archive":base64.b64encode(output.read_bytes()).decode("ascii"),"report":report}
        raise model.AnimationError(f"Unknown editor action: {name}")

    def export(self, kind: str) -> dict:
        output=self.tool_root/".gmtool-work"/"animation-exports"/self.project["id"]
        output.mkdir(parents=True,exist_ok=True)
        if kind=="export_png":
            result=model.export_pngs(self.project,self.assets,output/"png")
            archive_name="animation-png.zip"
        else:
            result=model.export_gifs(self.project,self.assets,output/"gif")
            archive_name="animation-gif.zip"
        zip_path=output/archive_name
        base=output/"png" if kind=="export_png" else output/"gif"
        with zipfile.ZipFile(zip_path,"w",zipfile.ZIP_DEFLATED) as zf:
            for path in base.rglob("*"):
                if path.is_file():zf.write(path,path.relative_to(base).as_posix())
        return {"download":archive_name,"archive":base64.b64encode(zip_path.read_bytes()).decode("ascii"),"report":result}


def project_archive(project: dict, assets: dict[str,bytes]) -> bytes:
    from tempfile import TemporaryDirectory
    with TemporaryDirectory(prefix="gmtool-animation-") as folder:
        path=model.save_project(Path(folder)/"project.gmanim",project,assets)
        return path.read_bytes()
