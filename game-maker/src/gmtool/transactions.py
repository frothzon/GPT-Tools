from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import tempfile
import time
import uuid
from typing import Any, Callable


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


@dataclass(frozen=True)
class TransactionResult:
    transaction_id: str
    target: Path
    before_hash: str
    after_hash: str
    journal: Path
    rolled_back: bool

    def as_dict(self) -> dict[str, Any]:
        return {
            "transactionId": self.transaction_id,
            "target": str(self.target),
            "beforeHash": self.before_hash,
            "afterHash": self.after_hash,
            "journal": str(self.journal),
            "rolledBack": self.rolled_back,
        }


@dataclass(frozen=True)
class FileSetTransactionResult:
    transaction_id: str
    journal: Path
    changes: dict[str, list[str]]
    rolled_back: bool

    def as_dict(self) -> dict[str, Any]:
        return {
            "transactionId": self.transaction_id,
            "journal": str(self.journal),
            "changes": self.changes,
            "rolledBack": self.rolled_back,
        }


def _write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.gmtool-", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def apply_single_file(
    target: Path,
    new_data: bytes,
    *,
    expected_hash: str,
    journal_root: Path,
    verify: Callable[[], list[str]] | None = None,
) -> TransactionResult:
    target = target.resolve()
    original = target.read_bytes()
    before_hash = sha256_bytes(original)
    if before_hash != expected_hash:
        raise RuntimeError(f"concurrent edit detected for {target}; expected {expected_hash}, found {before_hash}")
    after_hash = sha256_bytes(new_data)
    transaction_id = f"{time.strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:12]}"
    journal = journal_root / transaction_id
    journal.mkdir(parents=True, exist_ok=False)
    backup = journal / "before.bin"
    manifest_path = journal / "manifest.json"
    backup.write_bytes(original)
    manifest: dict[str, Any] = {
        "transactionId": transaction_id,
        "target": str(target),
        "beforeHash": before_hash,
        "afterHash": after_hash,
        "state": "prepared",
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
    rolled_back = False
    try:
        _write_atomic(target, new_data)
        manifest["state"] = "written"
        _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
        problems = verify() if verify else []
        if problems:
            raise RuntimeError("post-write verification failed: " + "; ".join(problems))
        if sha256_file(target) != after_hash:
            raise RuntimeError("post-write hash mismatch")
        manifest["state"] = "committed"
        _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
    except Exception as exc:
        current = sha256_file(target) if target.is_file() else None
        if current in {before_hash, after_hash}:
            _write_atomic(target, original)
            rolled_back = True
            manifest["state"] = "rolled-back"
        else:
            manifest["state"] = "rollback-conflict"
        manifest["error"] = str(exc)
        _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
        raise
    return TransactionResult(transaction_id, target, before_hash, after_hash, journal, rolled_back)


def apply_file_set(
    original_root: Path,
    candidate_root: Path,
    *,
    expected_snapshot: dict[str, str],
    changes: dict[str, list[str]],
    journal_root: Path,
    current_snapshot: Callable[[Path], dict[str, str]],
    verify: Callable[[], list[str]] | None = None,
) -> FileSetTransactionResult:
    original_root = original_root.resolve()
    candidate_root = candidate_root.resolve()
    if current_snapshot(original_root) != expected_snapshot:
        raise RuntimeError("concurrent project edit detected; the ResourceTool plan is stale")
    transaction_id = f"{time.strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:12]}"
    journal = journal_root / transaction_id
    backup_root = journal / "before"
    journal.mkdir(parents=True, exist_ok=False)
    manifest_path = journal / "manifest.json"
    touched = sorted(set(changes.get("created", [])) | set(changes.get("modified", [])) | set(changes.get("deleted", [])))
    for relative in touched:
        target = (original_root / Path(relative)).resolve()
        if original_root not in target.parents:
            raise RuntimeError(f"unsafe transaction path: {relative}")
        if target.is_file():
            backup = backup_root / Path(relative)
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(target.read_bytes())
    manifest: dict[str, Any] = {
        "transactionId": transaction_id,
        "root": str(original_root),
        "changes": changes,
        "beforeHashes": {relative: expected_snapshot.get(relative) for relative in touched},
        "afterHashes": {relative: sha256_file(candidate_root / relative) if (candidate_root / relative).is_file() else None for relative in touched},
        "writtenPaths": [],
        "state": "prepared",
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
    rolled_back = False
    try:
        for relative in changes.get("created", []) + changes.get("modified", []):
            source = (candidate_root / Path(relative)).resolve()
            target = (original_root / Path(relative)).resolve()
            if candidate_root not in source.parents or original_root not in target.parents:
                raise RuntimeError(f"unsafe transaction path: {relative}")
            current = sha256_file(target) if target.is_file() else None
            if current != manifest["beforeHashes"][relative]:
                raise RuntimeError(f"concurrent edit before write: {relative}")
            manifest["writtenPaths"].append(relative)
            _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
            _write_atomic(target, source.read_bytes())
        for relative in changes.get("deleted", []):
            target = (original_root / Path(relative)).resolve()
            if original_root not in target.parents:
                raise RuntimeError(f"unsafe transaction path: {relative}")
            if target.is_file():
                if sha256_file(target) != manifest["beforeHashes"][relative]:
                    raise RuntimeError(f"concurrent edit before deletion: {relative}")
                manifest["writtenPaths"].append(relative)
                _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
                target.unlink()
        manifest["state"] = "written"
        _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
        problems = verify() if verify else []
        if problems:
            raise RuntimeError("post-write verification failed: " + "; ".join(problems))
        expected_after = dict(expected_snapshot)
        for relative in touched:
            if manifest["afterHashes"][relative] is None:
                expected_after.pop(relative, None)
            else:
                expected_after[relative] = manifest["afterHashes"][relative]
        if current_snapshot(original_root) != expected_after:
            raise RuntimeError("post-write project hash mismatch")
        manifest["state"] = "committed"
        _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
    except Exception as exc:
        conflicts = []
        for relative in reversed(manifest["writtenPaths"]):
            target = original_root / Path(relative)
            current = sha256_file(target) if target.is_file() else None
            if current not in {manifest["beforeHashes"][relative], manifest["afterHashes"][relative]}:
                conflicts.append(relative)
                continue
            backup = backup_root / Path(relative)
            if backup.is_file():
                _write_atomic(target, backup.read_bytes())
            elif target.is_file():
                target.unlink()
        rolled_back = not conflicts
        manifest["state"] = "rollback-conflict" if conflicts else "rolled-back"
        manifest["conflicts"] = conflicts
        manifest["error"] = str(exc)
        _write_atomic(manifest_path, json.dumps(manifest, indent=2).encode("utf-8"))
        raise
    return FileSetTransactionResult(transaction_id, journal, changes, rolled_back)
