from __future__ import annotations

from io import BytesIO
from pathlib import Path

import pytest

PIL = pytest.importorskip("PIL")
Image = pytest.importorskip("PIL.Image")
ImageDraw = pytest.importorskip("PIL.ImageDraw")

from gmtool.animation_harness import project


def png(size=(96, 128), color=(70, 160, 110, 255)):
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((size[0] // 4, 0, size[0] * 3 // 4, size[1] - 1), 12, fill=color)
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def character():
    model, assets = project.new_project("Unit Test")
    entity = project.add_character(model, assets, "Test Zombie", png())
    return model, assets, entity


def test_bones_parts_maps_and_archive_roundtrip(tmp_path):
    model, assets, entity = character()
    project.add_bone(model, entity, "arm_hinge", "root", 24)
    art = project.add_part(model, entity, assets, "arm", png((28, 56), (240, 100, 60, 255)), "arm_hinge")
    project.add_clip(entity, "run")

    clip = entity["animations"][0]
    part_track = next(i for i, track in enumerate(clip["timelines"]) if track["name"] == "arm")
    project.add_key(entity, "idle", part_track, 400)
    project.set_key_value(entity, "idle", part_track, 1, "angle", 37)
    project.set_key_value(entity, "idle", part_track, 1, "time_ms", 250)
    assert clip["timelines"][part_track]["keys"][18] == 250
    assert clip["timelines"][part_track]["keys"][21] == 37

    project.add_character_map(entity, "rusted")
    project.set_character_map_entry(entity, "rusted", 0, len(entity["files"]) - 1)
    project.set_preview_maps(model, entity, ["rusted"])
    project.validate_project(model, assets)
    rendered = project.render_frame(model, entity, clip, assets, 250)
    assert Image.open(BytesIO(rendered)).getbbox() is not None

    saved = project.save_project(tmp_path / "roundtrip.gmanim", model, assets)
    loaded, loaded_assets = project.load_project(saved)
    restored = loaded["collections"][0]["entities"][0]
    assert restored["bones"] == ["root", "arm_hinge"]
    assert restored["parts"] == ["body", "arm"]
    assert restored["character_maps"][0]["name"] == "rusted"
    assert len(loaded_assets) == 2
    assert art["asset_id"] in loaded_assets


def test_slice_preserves_attachment_and_emits_two_cutouts():
    pytest.importorskip("numpy")
    model, assets, entity = character()
    upper, lower = project.slice_part(entity, assets, "body", 1,
        [0, 64], [96, 64], [48, 64], overlap=3, cap_radius=8)
    assert entity["parts"] == [upper, lower]
    assert len(entity["bones"]) == 2
    assert all(any(track.get("name") == name for track in entity["animations"][0]["timelines"])
               for name in (upper, lower))
    for part in (upper, lower):
        file_info = next(item for item in entity["files"] if item["name"] == part)
        cutout = Image.open(BytesIO(assets[file_info["asset_id"]])).convert("RGBA")
        assert cutout.getchannel("A").getbbox() is not None
        assert cutout.getchannel("A").getextrema()[0] == 0


def test_export_png_and_gif(tmp_path):
    model, assets, _entity = character()
    model["settings"]["frame_count"] = 3
    png_result = project.export_pngs(model, assets, tmp_path / "png")
    gif_result = project.export_gifs(model, assets, tmp_path / "gif")
    assert png_result["frames"] == 12
    assert png_result["clips"] == 4
    assert len(gif_result["gifs"]) == 4
    assert all(Path(path).is_file() for path in png_result["files"])
    assert all(Path(path).is_file() for path in gif_result["gifs"])
