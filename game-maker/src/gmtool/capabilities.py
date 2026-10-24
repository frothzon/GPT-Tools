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
