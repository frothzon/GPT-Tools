from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any


def _version_tuple(value: str) -> tuple[int, ...]:
    numbers: list[int] = []
    for part in value.lstrip("vV").split("."):
        digits = "".join(character for character in part if character.isdigit())
        if not digits:
            break
        numbers.append(int(digits))
    return tuple(numbers)


def _node_candidates() -> list[Path]:
    candidates: list[Path] = []
    on_path = shutil.which("node")
    if on_path:
        candidates.append(Path(on_path))
    codex_node = Path.home() / ".cache" / "codex-runtimes" / "codex-primary-runtime" / "dependencies" / "node" / "bin" / "node.exe"
    if codex_node.is_file():
        candidates.append(codex_node)
    unique: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate.resolve()).casefold()
        if key not in seen:
            seen.add(key)
            unique.append(candidate.resolve())
    return unique


def _command_version(command: list[str]) -> str | None:
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=15, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    output = (completed.stdout or completed.stderr).strip().splitlines()
    return output[0].strip() if output else None


def resolve_gm_cli(tool_root: Path) -> tuple[Path | None, str]:
    explicit = os.environ.get("GM_CLI_PATH")
    if explicit and Path(explicit).is_file():
        return Path(explicit).resolve(), "GM_CLI_PATH"
    local = tool_root / "node_modules" / ".bin" / "gm-cli.cmd"
    if local.is_file():
        return local.resolve(), "tool-local"
    on_path = shutil.which("gm-cli.cmd") or shutil.which("gm-cli")
    if on_path:
        return Path(on_path).resolve(), "PATH"
    cache_root_value = os.environ.get("LOCALAPPDATA")
    if cache_root_value:
        cache_root = Path(cache_root_value) / "npm-cache" / "_npx"
        try:
            matches = sorted(cache_root.glob("*/node_modules/.bin/gm-cli.cmd"), key=lambda path: path.stat().st_mtime, reverse=True)
            if matches:
                return matches[0].resolve(), "npx-cache-unstable"
        except OSError:
            pass
    return None, "missing"


def doctor(tool_root: Path) -> dict[str, Any]:
    node_results: list[dict[str, Any]] = []
    for candidate in _node_candidates():
        version = _command_version([str(candidate), "--version"])
        node_results.append(
            {
                "path": str(candidate),
                "version": version,
                "meetsNode24": bool(version and _version_tuple(version) >= (24,)),
            }
        )
    gm_cli, gm_cli_source = resolve_gm_cli(tool_root)
    gm_version: str | None = None
    package_version: str | None = None
    if gm_cli:
        package_path = gm_cli.parent.parent / "@gamemaker" / "gm-cli" / "package.json"
        try:
            package_version = json.loads(package_path.read_text(encoding="utf-8"))["version"]
        except (OSError, KeyError, json.JSONDecodeError):
            pass
        if gm_cli.suffix.casefold() == ".cmd":
            gm_version = _command_version(["cmd.exe", "/d", "/s", "/c", f'"{gm_cli}" --version'])
        else:
            gm_version = _command_version([str(gm_cli), "--version"])
    issues: list[dict[str, str]] = []
    if sys.version_info < (3, 11):
        issues.append({"severity": "error", "message": "Python 3.11 or newer is required"})
    if not any(node["meetsNode24"] for node in node_results):
        issues.append({"severity": "error", "message": "Node.js 24 or newer is required by the pinned gm-cli"})
    if gm_cli is None:
        issues.append({"severity": "warning", "message": "gm-cli is not installed locally or on PATH"})
    elif gm_cli_source == "npx-cache-unstable":
        issues.append({"severity": "warning", "message": "gm-cli was found only in the mutable npx cache; install the pinned local dependency"})
    return {
        "toolRoot": str(tool_root),
        "python": {"path": sys.executable, "version": sys.version.split()[0]},
        "node": node_results,
        "gmCli": {
            "path": str(gm_cli) if gm_cli else None,
            "source": gm_cli_source,
            "version": package_version or gm_version,
        },
        "issues": issues,
    }

