from __future__ import annotations

from pathlib import Path


class DiscoveryError(RuntimeError):
    pass


def discover_project(value: str | Path | None) -> Path:
    candidate = Path(value or Path.cwd()).expanduser().resolve()
    if candidate.is_file():
        if candidate.suffix.casefold() != ".yyp":
            raise DiscoveryError(f"expected a .yyp file, got: {candidate}")
        return candidate
    if not candidate.exists():
        raise DiscoveryError(f"path does not exist: {candidate}")
    projects = sorted(candidate.glob("*.yyp"))
    if not projects:
        raise DiscoveryError(f"no .yyp file found in: {candidate}")
    if len(projects) > 1:
        names = ", ".join(project.name for project in projects)
        raise DiscoveryError(f"multiple .yyp files found; specify one explicitly: {names}")
    return projects[0].resolve()

