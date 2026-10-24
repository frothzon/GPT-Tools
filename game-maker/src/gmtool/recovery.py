from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .transactions import _write_atomic, sha256_file


def _journals(root: Path) -> list[Path]:
    transaction_root = root / ".gmtool-work" / "transactions"
    if not transaction_root.is_dir():
        return []
    return sorted(path for path in transaction_root.iterdir() if (path / "manifest.json").is_file())


def status(root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for journal in _journals(root):
        try:
            payload = json.loads((journal / "manifest.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            records.append({"journal": str(journal), "state": "unreadable", "error": str(exc)})
            continue
        payload["journal"] = str(journal)
        records.append(payload)
    return records


def _safe_path(root: Path, relative_or_absolute: str) -> Path:
    candidate = Path(relative_or_absolute)
    if not candidate.is_absolute():
        candidate = root / candidate
    resolved = candidate.resolve()
    if resolved != root.resolve() and root.resolve() not in resolved.parents:
        raise RuntimeError(f"recovery path escapes project root: {candidate}")
    return resolved


def rollback(tool_root: Path, transaction_id: str, project_root: Path | None = None) -> dict[str, Any]:
    from .workspace import identifier
    identifier(transaction_id)
    journal = tool_root / ".gmtool-work" / "transactions" / transaction_id
    manifest_path = journal / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"transaction journal not found: {transaction_id}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    state = manifest.get("state")
    if state in {"committed", "rolled-back"}:
        return {"transactionId": transaction_id, "state": state, "changed": False, "message": "transaction is already final"}
    target_value = manifest.get("target")
    if isinstance(target_value, str) and (journal / "before.bin").is_file():
        target_root = project_root.resolve() if project_root else Path(target_value).resolve().parent
        target = _safe_path(target_root, target_value)
        current = sha256_file(target) if target.is_file() else None
        if current not in {manifest.get("beforeHash"), manifest.get("afterHash")}:
            raise RuntimeError("recovery conflict: target changed externally")
        _write_atomic(target, (journal / "before.bin").read_bytes())
    else:
        recorded_root = Path(manifest.get("root") or "").resolve()
        if project_root and recorded_root != project_root.resolve():
            raise RuntimeError(f"recovery project does not match the recorded project root: {recorded_root}")
        project_root = recorded_root
        changes = manifest.get("changes") or {}
        backup_root = journal / "before"
        if "afterHashes" not in manifest or "beforeHashes" not in manifest:
            raise RuntimeError("legacy journal lacks conflict evidence; inspect and recover manually")
        written = manifest.get("writtenPaths", list(manifest["afterHashes"]))
        for relative in written:
            target = _safe_path(project_root, str(relative))
            current = sha256_file(target) if target.is_file() else None
            if current not in {manifest["beforeHashes"].get(relative), manifest["afterHashes"].get(relative)}:
                raise RuntimeError(f"recovery conflict: {relative} changed externally")
        for relative in changes.get("created", []):
            if relative not in written:
                continue
            target = _safe_path(project_root, str(relative))
            if target.is_file():
                target.unlink()
        for relative in list(changes.get("modified", [])) + list(changes.get("deleted", [])):
            if relative not in written:
                continue
            target = _safe_path(project_root, str(relative))
            backup = backup_root / Path(str(relative))
            if backup.is_file():
                _write_atomic(target, backup.read_bytes())
    manifest["state"] = "rolled-back"
    manifest["recoveredAt"] = __import__("time").strftime("%Y-%m-%dT%H:%M:%S%z")
    _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
    return {"transactionId": transaction_id, "state": "rolled-back", "changed": True, "journal": str(journal)}
