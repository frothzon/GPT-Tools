# GameMaker Agent Tools

Reusable tooling for reading and changing GameMaker projects without forcing an agent to manually translate between logical resources and GameMaker's on-disk layout.

## Status

The review/verification workbench is implemented. See [WORKBENCH.md](WORKBENCH.md) for the primary workflow, full installed manual, browser interface, MCP adapter, examples, and measured limitations. New commands: `session`, `context`, `change`, `scenario`, `docs`, `report`, `serve`, `mcp`, and `registry`. Plans freeze reviewed bytes and require matching evidence before apply; scenario assertions are distinct from compilation.

| Capability | Status |
| --- | --- |
| Format survey and architecture | Implemented baseline; ongoing per resource/version |
| `gm-cli` environment probe | Implemented by `doctor`; pinned 2.3.0 installed locally |
| Complete resource/content coverage specification | Defined in `RESOURCE_COVERAGE.md` |
| Syntax diagnosis and conservative repair | Local scanner, compiler-mapped diagnostics, explanations, and three EOF-closure repair classes implemented |
| Project discovery and resource index | Implemented for registered resources and code surfaces |
| Logical resource/code lookup | Implemented for scripts, object events, rooms, shaders, and generic resources |
| Lossless `.yy`/`.yyp` handling | Byte-identical parser implemented; general minimal metadata mutation pending |
| Guarded source writes | Implemented with dry-run diff, hashes, journal, atomic replace, and rollback |
| Official ResourceTool bridge | Implemented on disposable copies with diff/apply transactions |
| Resource creation, rename, and removal | Agent-friendly reviewed ResourceTool recipes for generic resources, object events, rooms, sprites, sounds, shaders, scripts, notes, tilesets, groups, and configurations; versioned coverage remains partial |
| Cross-file validation | Baseline implemented; full per-resource contracts pending |
| Compile/test/run adapter | Implemented with pinned `gm-cli`, source hashing, compiler diagnostics, bounded process-tree termination, and Windows VM verification |
| Preview bundles | Generic bundles plus sprite, room, path, and WAV renderers implemented |
| Capability manifest | Implemented with per-family/per-operation status and explicit planned gaps |
| Dependency graph | Implemented for exact metadata references plus explicitly soft/static code references |
| Capability/schema discovery | Implemented via `capabilities`, `schema`, and `inventory` commands |
| Transaction recovery | Implemented via journal inspection and explicit rollback of unfinished transactions |

Do not invoke a planned command until this table identifies it as implemented. “Implemented” here describes the current baseline, not full support under `RESOURCE_COVERAGE.md`; consult the capability output and command help for limitations.

## Target workflow

The entry point is the PowerShell launcher `gmtool.ps1` in this directory. It discovers the `.yyp` from a project path and exposes logical resource names such as `obj_camera.Create`, rather than requiring callers to know that the source lives in `objects/obj_camera/Create_0.gml`.

The intended command families are:

- `inspect` and `find` for project discovery and machine-readable resource indexes.
- `inventory`/`schema`/`capabilities` for explicit support discovery before an agent edits content.
- `graph` for inbound/outbound dependency review before rename/delete operations.
- `read` and `resolve` for logical-to-physical source lookup.
- `write` and `patch` for guarded code changes.
- `add`, `rename`, and `remove` for coordinated resource changes.
- `validate` and `doctor` for format, reference, and environment checks.
- `compile`, `test`, `run`, and `debug` as guarded adapters over YoYo Games' `gm-cli`.
- `diagnose`, `explain-error`, and `repair-syntax` for path-mapped compiler errors and verified minimal fixes.
- `resource-tool` for an official ResourceTool expression on a disposable clone, with optional transactional application of the complete reviewed diff.
- `resource` for common create/edit/list operations expressed as safe, reviewed ResourceTool recipes.
- `preview` for content-addressed agent-readable summaries, normalized data, dependency lists, and media/spatial previews.

See [PLAN.md](PLAN.md) for architecture, safety rules, and milestones. [RESOURCE_COVERAGE.md](RESOURCE_COVERAGE.md) is the exhaustive capability matrix and completion contract for every GameMaker content family. [SYNTAX_REPAIR.md](SYNTAX_REPAIR.md) defines compiler-backed diagnosis and conservative repair of simple GML, shader, and metadata syntax errors.

## Working examples

```powershell
& "C:\Agent Tools\game-maker\gmtool.ps1" doctor
& "C:\Agent Tools\game-maker\gmtool.ps1" inspect C:\path\game.yyp --resources
& "C:\Agent Tools\game-maker\gmtool.ps1" resolve C:\path\game.yyp obj_player.Create
& "C:\Agent Tools\game-maker\gmtool.ps1" graph C:\path\game.yyp obj_player --direction both --json
& "C:\Agent Tools\game-maker\gmtool.ps1" read C:\path\game.yyp obj_player --include-code --json
& "C:\Agent Tools\game-maker\gmtool.ps1" validate C:\path\game.yyp --strict
& "C:\Agent Tools\game-maker\gmtool.ps1" diagnose C:\path\game.yyp obj_player.Step
& "C:\Agent Tools\game-maker\gmtool.ps1" diagnose C:\path\game.yyp --compile --toolchain GMS2@2024.14.4 --json
& "C:\Agent Tools\game-maker\gmtool.ps1" explain-error "got '' expected ')'"
& "C:\Agent Tools\game-maker\gmtool.ps1" repair-syntax C:\path\game.yyp obj_player.Step
& "C:\Agent Tools\game-maker\gmtool.ps1" preview C:\path\game.yyp rm_level
& "C:\Agent Tools\game-maker\gmtool.ps1" test C:\path\game.yyp --target windows --runtime vm
& "C:\Agent Tools\game-maker\gmtool.ps1" run C:\path\game.yyp --target windows --runtime vm --timeout 60
```

`write` and `resource-tool` default to non-project-mutating workflows. `write` needs `--apply` to replace a source file. `resource-tool` always evaluates on a disposable project clone and needs `--apply` to transactionally copy the complete official diff back to the selected project.

The higher-level `resource` command keeps those same clone, diff, validation, journal, and rollback guarantees while exposing common ResourceTool operations without requiring agents to learn its expression syntax:

```powershell
& "C:\Agent Tools\game-maker\gmtool.ps1" capabilities --json
& "C:\Agent Tools\game-maker\gmtool.ps1" recover --json
& "C:\Agent Tools\game-maker\gmtool.ps1" resource C:\path\game.yyp create --type script --name scr_inventory
& "C:\Agent Tools\game-maker\gmtool.ps1" resource C:\path\game.yyp object-event-create --name obj_player --type step --subtype step
& "C:\Agent Tools\game-maker\gmtool.ps1" resource C:\path\game.yyp room-instance-create --room rm_level --object obj_player --x 320 --y 180 --apply
& "C:\Agent Tools\game-maker\gmtool.ps1" resource C:\path\game.yyp sprite-frame-add --name spr_player --path C:\assets\player.png
& "C:\Agent Tools\game-maker\gmtool.ps1" resource C:\path\game.yyp sound-set-file --name snd_theme --path C:\assets\theme.ogg --apply
```

Use `capabilities --json` as the source of truth for each family and operation. Unsupported or version-sensitive mutations fail before the project is touched; use the lower-level `resource-tool` command only when deliberately supplying an official expression.

`run` is intentionally bounded and reports timeout, exit status, compiler diagnostics, and unexpected project rewrites. It is a smoke/debug session, not a claim that gameplay assertions passed; a project-specific runtime harness should be layered on top for screenshots, assertions, crash logs, or performance thresholds.

## Format baseline

The initial fixture project is `C:\Users\johns\GameMakerProjects\Simple3D`, currently saved by GameMaker IDE `2024.14.4.222` with resource version `2.0`.

GameMaker metadata is JSON-like, not strict JSON: current files contain trailing commas and formatting that should not be normalized. The toolchain must use a lossless parser or narrowly targeted text edits so an ordinary code change does not churn unrelated metadata.

## `gm-cli` baseline

[`YoYoGames/gm-cli`](https://github.com/YoYoGames/gm-cli) is the authoritative backend for ResourceTool operations and for compile/run feedback. The local probe on 2026-09-17 found:

- Node.js `v20.20.2` on `PATH`.
- No global `gm-cli` command on `PATH`.
- `@gamemaker/gm-cli` `2.2.0` in the npx cache; it ran successfully and reported `2.3.0` as available.
- The cached package declares Node.js `>=24`, so `doctor` must flag the current runtime mismatch even though help and ResourceTool ran in this probe.
- PowerShell's `gm` command is an alias for `Get-Member`, not GameMaker CLI.

The implementation should pin an approved `gm-cli` version locally under this tool folder and invoke `gm-cli.cmd` explicitly. It must not silently use `@latest` during routine work.

Important observed behavior: `gm-cli resourcetool eval "resource list"` successfully loaded `Simple3D`, but also ran a save/normalization pass and touched 84 `.yy`, `.yyp`, and `.resource_order` files. Treat all ResourceTool modes as potentially mutating. Preview them on a disposable project clone and review semantic and byte-level diffs before applying a structural change to the working project.

## Research evidence

`research/projecttool-resource-types.json` was generated from the ProjectTool `2026.0.176` component installed by `gm-cli`. It reports 140 known serialized classes, including bitmap/vector sprites, room UI and flex content, particles, audio effects and emitters, sequence track/keyframe types, platform options, prefabs, shapes, and style data. It is discovery evidence, not a writable schema; schemas must come from versioned fixtures and round-trip tests.
