from __future__ import annotations

from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import subprocess
import time
from typing import Any, Iterable

from .environment import _node_candidates, _version_tuple


@dataclass(frozen=True)
class CommandResult:
    command: list[str]
    exit_code: int
    stdout: str
    stderr: str
    duration_seconds: float
    timed_out: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "command": self.command,
            "exitCode": self.exit_code,
            "stdout": self.stdout,
            "stderr": self.stderr,
            "durationSeconds": round(self.duration_seconds, 3),
            "timedOut": self.timed_out,
        }


def compatible_node() -> Path:
    for candidate in _node_candidates():
        try:
            completed = subprocess.run([str(candidate), "--version"], capture_output=True, text=True, timeout=10, check=False)
        except (OSError, subprocess.SubprocessError):
            continue
        if _version_tuple(completed.stdout.strip()) >= (24,):
            return candidate
    raise RuntimeError("Node.js 24 or newer is required for the pinned gm-cli")


def cli_entry(tool_root: Path) -> Path:
    entry = tool_root / "node_modules" / "@gamemaker" / "gm-cli" / "dist" / "cli.js"
    if not entry.is_file():
        raise RuntimeError(f"pinned gm-cli is not installed; expected {entry}")
    return entry


def invoke(
    tool_root: Path,
    arguments: Iterable[str],
    *,
    cwd: Path | None = None,
    timeout: int = 900,
) -> CommandResult:
    environment = os.environ.copy()
    npm_cache = tool_root / ".npm-cache"
    npm_prefix = tool_root / ".npm-prefix"
    npm_cache.mkdir(parents=True, exist_ok=True)
    npm_prefix.mkdir(parents=True, exist_ok=True)
    environment["NPM_CONFIG_CACHE"] = str(npm_cache)
    environment["npm_config_cache"] = str(npm_cache)
    environment["NPM_CONFIG_PREFIX"] = str(npm_prefix)
    environment["npm_config_prefix"] = str(npm_prefix)
    environment["NPM_CONFIG_USERCONFIG"] = str(tool_root / ".npmrc")
    argument_list = [str(value) for value in arguments]
    if argument_list and argument_list[0] == "resourcetool":
        environment["NPM_CONFIG_OFFLINE"] = "true"
        environment["npm_config_offline"] = "true"
    command = [str(compatible_node()), str(cli_entry(tool_root)), *argument_list]
    started = time.monotonic()
    creationflags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    process = subprocess.Popen(
        command,
        cwd=str(cwd) if cwd else None,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        creationflags=creationflags,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        return CommandResult(command, process.returncode, stdout, stderr, time.monotonic() - started)
    except subprocess.TimeoutExpired as exc:
        # gm-cli run can own a game process. Kill the process tree started by
        # this invocation so a timed-out smoke/debug run cannot leak a game.
        if os.name == "nt":
            try:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, text=True, timeout=10, check=False)
            except (OSError, subprocess.SubprocessError):
                pass
        if process.poll() is None:
            process.kill()
        stdout, stderr = process.communicate()
        if not stdout:
            stdout = exc.stdout.decode("utf-8", "replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        if not stderr:
            stderr = exc.stderr.decode("utf-8", "replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        return CommandResult(command, 124, stdout, stderr, time.monotonic() - started, True)


def source_snapshot(root: Path) -> dict[str, str]:
    ignored_directories = {".git", ".gmtool-work", "__pycache__", "build", "dist"}
    result: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file() or any(part in ignored_directories for part in path.relative_to(root).parts):
            continue
        digest = hashlib.sha256()
        try:
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
        except OSError as exc:
            raise RuntimeError(f"cannot hash project file {path}: {exc}") from exc
        result[path.relative_to(root).as_posix()] = digest.hexdigest()
    return result


def snapshot_diff(before: dict[str, str], after: dict[str, str]) -> dict[str, list[str]]:
    before_keys = set(before)
    after_keys = set(after)
    return {
        "created": sorted(after_keys - before_keys),
        "deleted": sorted(before_keys - after_keys),
        "modified": sorted(key for key in before_keys & after_keys if before[key] != after[key]),
    }
