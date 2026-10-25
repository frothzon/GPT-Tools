from __future__ import annotations

from typing import Any

from . import __version__


from .operation_registry import OPERATIONS, FAMILIES


def manifest(*, project: dict[str, Any] | None = None) -> dict[str, Any]:
    from .operation_registry import recipes, schema, family_contracts
    result: dict[str, Any] = {
        "toolVersion": __version__,
        "contract": "RESOURCE_COVERAGE.md",
        "operations": OPERATIONS,
        "animationHarness": {
            "status": "partial",
            "projectFormat": "gmtool-animation-project/1",
            "editor": "implemented",
            "operations": {"new": "implemented", "open": "implemented", "migrate_scml": "implemented", "add_bone": "implemented", "add_part": "implemented", "replace_part_art": "implemented", "slice_cutout": "implemented", "edit_keyframes": "implemented", "events": "implemented", "export_png": "implemented", "export_gif": "implemented", "export_yymps": "implemented"},
            "note": "Local authenticated cutout editor with portable .gmanim projects; YYMPS generation stages and registers sprite, runtime, and demo assets through official ProjectTool without modifying the selected template project. Feature support remains limited to the documented SCML subset."
        },
        "families": {},
        "recipes": recipes(project),
        "changeSchema": schema(),
        "verificationLevels": {"test": "build-check", "run": "runtime-execution", "scenario": "gameplay-assertions"},
        "safety": {
            "mutationsRequireApply": True,
            "resourceToolUsesDisposableClone": True,
            "metadataPreservation": "lossless-parse-and-guarded-source; full minimal metadata editing pending",
            "unsupportedMutation": "refuse-with-explicit-diagnostic",
        },
    }
    for family, data in family_contracts(project).items():
        implemented = set(data["implemented"])
        result["families"][family] = {
            "status": data["status"],
            "operations": {operation: ("implemented" if operation in implemented else "planned") for operation in OPERATIONS},
            "note": data["note"],
            "recipes": data["recipes"],
        }
    if project:
        result["project"] = project
    return result
