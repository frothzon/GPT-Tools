# GameMaker tools — agent guide

Operational guide for the tooling in this folder: the `gmtool` CLI and its pinned, official `gm-cli` backend. Read this before touching a GameMaker project. The README status table and `capabilities --json` are the source of truth for what is implemented; never invoke a command the status table does not list as implemented.

## Entry points

- `gmtool.ps1` is the preferred launcher: `& "C:\Agent Tools\game-maker\gmtool.ps1" <command> ...`. `gmtool.cmd` is the cmd.exe equivalent. Both run `py -3 -m gmtool` with `src` on `PYTHONPATH`; Python 3.11+ via the Windows `py` launcher is required.
- Add `--json` to any command for stable machine-readable output.
- `gmtool-compat.ps1` runs the same CLI plus a validation shim that suppresses stale `Collision_0.gml` diagnostics (`GMV022`/`GMV031`/`GMV023`) that the older validator raised for GameMaker 2024.14 targeted collision events. Use it only for projects that produce those specific false positives.
- The official backend is YoYo Games' `@gamemaker/gm-cli`, pinned to 2.3.0 in `package.json` and installed under `node_modules/`. Its metadata requires Node.js >= 24; `doctor` reports any runtime mismatch. Never switch to `@latest` for routine work.
- In PowerShell, `gm` is the built-in alias for `Get-Member`, not the GameMaker CLI. Never invoke `gm` expecting GameMaker; resolve `gm-cli.cmd` explicitly or go through `gmtool.ps1`.
- `.gmtool-work/`, `.gm-cli-cache/`, `.npm-cache/`, `.npm-prefix/`, and `node_modules/` are local caches, clones, previews, and transaction journals (git-ignored). Never hand-edit them or treat them as project data. `*.orig` files are manual backups, not inputs to anything.

## Non-negotiable rules

1. Run `capabilities --json` (optionally passing the project for version/profile context) before planning any resource mutation. Treat the per-family/per-operation manifest as authoritative and stop on any operation reported as `planned`; unsupported mutations must refuse with an explicit diagnostic before the project is touched.
2. Every mutating command is dry-run by default. Only pass `--apply` after reviewing the reported diff; never apply an unreviewed change.
3. `resource` and `resource-tool` always evaluate on a disposable clone of the project. Treat ResourceTool as potentially mutating even for read-only-looking queries — it can run a save/normalization pass over unrelated `.yy`/`.yyp`/`.resource_order` files. Verify `originalProjectChanged` is `false` and review `cloneChanges` before `--apply`.
4. Run `graph <project> <resource> --direction both` before any rename or delete; hard metadata references and soft/static code references are reported separately.
5. Never hand-edit `.yy`/`.yyp` metadata when a tool command exists. GameMaker metadata is JSON-like (trailing commas, non-standard formatting); changes must go through the lossless parser or guarded writes so unrelated bytes are untouched.
6. If an agent or process is interrupted during a mutation, inspect `recover --json` first. Use `recover --rollback --transaction-id <id>` only for an unfinished journal, after checking the journal's recorded project root.
7. Keep the tools project-agnostic. Project-specific behavior belongs in a version profile, fixture, or explicit command option — never a hard-coded project rule.
8. When a capability is added or changed, update the README status table and command examples in the same change, and keep `RESOURCE_COVERAGE.md` acceptance criteria in sync.

## Command catalog

| Phase | Commands |
| --- | --- |
| Environment | `doctor` — Python/Node/gm-cli probe; run once per session in a new environment |
| Discovery | `inspect` (alias `inventory`), `find`, `resolve` — project summary, resource search, logical-to-physical lookup |
| Support discovery | `capabilities [project]`, `schema <family>` — capability manifest and guarded recipe contract |
| Reading | `read` (with `--include-code` or `--raw`), `graph` |
| Code edits | `write <project> <spec> --from <file>` — dry-run diff by default; `--apply` replaces atomically after hash checks |
| Structure changes | `resource <project> <operation> ...` — reviewed ResourceTool recipes on a disposable clone; `resource-tool <project> "<expression>"` — official-expression escape hatch, also clone-first |
| Validation | `validate [--strict]`, `diagnose [spec]` (add `--compile` to run the pinned compiler and map diagnostics back to logical resources) |
| Error help | `explain-error "<message or code>"`, `repair-syntax <project> <spec>` — dry-run by default; `--apply` only after review |
| Build/run | `compile`, `test`, `run` (alias `debug`) — pinned gm-cli adapters with `--target`, `--runtime vm\|native`, `--toolchain`, `--config`, `--timeout` |
| Preview | `preview <project> <resource>` — content-addressed bundle (summary, normalized data, dependencies, sprite/room/path/WAV renders); `--force` rebuilds |
| Recovery | `recover [--rollback --transaction-id <id>]` |

Discover the full `resource` operation list with `gmtool resource --help` (~80 recipes: `types`, `list`, `info`, `set`, `create`, `delete`, `object-event-*`, `room-instance-*`, `room-asset-*`, `room-item-*`, `room-layer-*`, `room-tiles-*`, `script-set-file`, `shader-set-file`, `note-set-file`, `sprite-frame-*`, `sound-set-file`, `tileset-*`, `path-*`, `font-*`, `folder-*`, `options-*`, `prefab-*`, `audio-group-*`, `texture-group-*`, `config-*`).

`run` is intentionally bounded and reports timeout, exit status, compiler diagnostics, and unexpected project rewrites. It is a smoke/debug session, not proof that gameplay assertions passed; layer a project-specific runtime harness on top for screenshots, assertions, crash logs, or performance thresholds. Preserve the exact profile, timeout, exit status, logs, and unexpected-project-change report in your session notes.

## Standard workflows

In the examples below, `$gm = "C:\Agent Tools\game-maker\gmtool.ps1"` and `C:\path\game.yyp` is the target project.

Session start:

```powershell
& $gm doctor
& $gm inspect C:\path\game.yyp --resources --json
& $gm capabilities C:\path\game.yyp --json
```

Code change (script body, object event):

```powershell
# 1. Locate and read the logical source.
& $gm resolve C:\path\game.yyp obj_player.Create --json
& $gm read C:\path\game.yyp obj_player.Create --include-code --json
# 2. Stage replacement source, then preview the diff (dry run).
& $gm write C:\path\game.yyp obj_player.Create --from C:\temp\Create_0.gml --json
# 3. Apply only the reviewed diff, then verify.
& $gm write C:\path\game.yyp obj_player.Create --from C:\temp\Create_0.gml --apply --json
& $gm validate C:\path\game.yyp --strict --json
& $gm test C:\path\game.yyp --target windows --runtime vm --json
```

Structural change (create/edit/delete resources and metadata):

```powershell
# Preview on the disposable clone; review the reported diff and confirm originalProjectChanged is false.
& $gm resource C:\path\game.yyp create --type script --name scr_inventory --json
# Graph first for delete/rename-class operations.
& $gm graph C:\path\game.yyp obj_old --direction both --json
# Apply the exact reviewed diff transactionally.
& $gm resource C:\path\game.yyp create --type script --name scr_inventory --apply --json
& $gm validate C:\path\game.yyp --strict --json
```

Syntax errors (full contract in [SYNTAX_REPAIR.md](SYNTAX_REPAIR.md)):

```powershell
& $gm diagnose C:\path\game.yyp --json                 # add --compile for compiler-backed diagnosis
& $gm explain-error "got '' expected ')'" --json
& $gm repair-syntax C:\path\game.yyp obj_player.Step --json   # dry run; review, then --apply
```

Auto-apply only compiler-verified, high-confidence, minimal fixes (default budget: one file, one root diagnostic, one contiguous edit). Leave ambiguous or semantic changes for explicit review.

Interrupted mutation:

```powershell
& $gm recover --json
& $gm recover --rollback --transaction-id <id> --json  # only for an unfinished journal, after checking its project root
```

## Documents

- [README.md](README.md) — status table (what is implemented) and working examples. The status table outranks every other document.
- [PLAN.md](PLAN.md) — architecture, safety rules, and milestones. Design guidance only, not proof that a command exists.
- [RESOURCE_COVERAGE.md](RESOURCE_COVERAGE.md) — the completion contract defining "full support" per resource family; a family is complete only when its entire lifecycle and preview contract pass.
- [SYNTAX_REPAIR.md](SYNTAX_REPAIR.md) — diagnosis and conservative-repair contract. It describes the target interface; the implemented `repair-syntax` surface is the project/spec form with `--apply` (dry run by default), not `--dry-run`/`--apply-plan`/`--changed`.
- `research/` — format evidence such as the ProjectTool serialized-class inventory. Discovery evidence, not a writable schema.

## Tests

Run the suite from inside `tests/` — two modules import `support` as a top-level module, so a run from this folder's root fails collection:

```powershell
Set-Location 'C:\Agent Tools\game-maker\tests'
$env:PYTHONPATH = 'C:\Agent Tools\game-maker\src'
$env:PYTHONUTF8 = '1'
py -3 -m pytest . -q
```

The regression suite has 53 tests and does not require `gm-cli`, Node, or a GameMaker install. Extend `tests/` for new capabilities; fixtures are written by `tests/support.py::write_fixture`. Use [WORKBENCH.md](WORKBENCH.md) and immutable `change` plans for reviewed work. Never equate compilation, assertions, and visual review. Check manual coverage/channel evidence; the complete installed snapshot is not the complete current monthly channel. Do not suppress unresolved collision metadata diagnostics.

