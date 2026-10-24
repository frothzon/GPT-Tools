# Plan: agent-native GameMaker project tools

## Outcome

Build a local CLI that lets an agent work in GameMaker using logical resources and ordinary source-editing habits while the tool handles `.yyp`, `.resource_order`, `.yy`, event filenames, and cross-file references. Use YoYo Games' [`gm-cli`](https://github.com/YoYoGames/gm-cli) as the authoritative backend for ResourceTool operations, compilation, running, and debug feedback. Existing source files remain the source of truth; the tool must not create a second editable copy of project code.

The first supported baseline is GameMaker IDE `2024.14.4.222`, project/resource format `2.0`, as represented by the `Simple3D` project. Other versions are allowed only after a fixture and version profile prove compatibility.

`RESOURCE_COVERAGE.md` is normative for breadth. “All resources supported” means every listed family satisfies the complete lifecycle contract, including agent-readable inspection and a useful preview—not merely that its descriptor can be parsed.

## Design principles

1. **Lossless by default.** Preserve encoding, newline style, key order, indentation, trailing commas, unknown fields, and untouched byte ranges.
2. **Logical names at the boundary.** Accept identifiers such as `Simple3D`, `obj_camera.Create`, `rm_test_3d.CreationCode`, and `shd_ssao.fragment`; return physical paths only as output.
3. **One coordinated transaction.** A resource mutation updates every required descriptor, project entry, ordering entry, code file, and reference—or writes nothing.
4. **Safe agent operation.** Every mutating command supports `--dry-run`, emits a concise diff/operation manifest, detects concurrent file changes, and runs validation before commit.
5. **Machine-readable output.** All read commands support `--json`; diagnostics use stable codes, paths, and actionable messages.
6. **Version-aware behavior.** Never silently guess a schema for an unknown IDE/resource version. Read-only indexing may degrade gracefully; mutation must stop with a clear compatibility error.
7. **Official backend first.** Delegate supported semantics to `gm-cli`; build only the lossless agent workflow, safety layer, indexing, diagnostics normalization, and missing operations around it.
8. **Pinned and reproducible.** Pin an approved `@gamemaker/gm-cli` version locally. Never make normal operation depend on a mutable npx cache or silently download `@latest`.

## Proposed layout

```text
C:\Agent Tools\game-maker\
  gmtool.ps1                 # stable Windows entry point
  package.json               # pinned @gamemaker/gm-cli dependency
  package-lock.json          # reproducible CLI installation
  README.md                  # status and supported commands
  PLAN.md                    # this design
  RESOURCE_COVERAGE.md       # exhaustive resource/operation/view matrix
  SYNTAX_REPAIR.md           # compiler-backed diagnosis/repair contract
  config\defaults.json       # target/runtime/toolchain and timeout defaults
  src\gmtool\                # Python standard-library implementation
    cli.py
    discovery.py
    gm_cli.py                # command discovery, execution, logs, exit codes
    diagnostics.py           # normalize compiler/parser diagnostics
    repair.py                # conservative candidate generation/verification
    index.py
    lossless_json.py         # CST/token-based JSON-with-trailing-commas support
    resources.py
    adapters\                # one lifecycle adapter per resource family
    previews\                # image/audio/timeline/graph preview renderers
    recipes.py               # strict agent-facing declarative input
    transactions.py
    validation.py
    versions\v2024_14.py
  schemas\                   # observed contracts, not destructive serializers
  research\                  # generated inventories and format observations
  tests\
    fixtures\                # small, anonymized format examples
    golden\                  # byte-preservation and expected-diff cases
```

Use a small PowerShell launcher plus a Python standard-library core. The launcher makes invocation predictable on Windows; the core makes parsing, indexing, atomic writes, and tests maintainable. Node.js remains required by the pinned `gm-cli` dependency. `doctor` must report the resolved Python, Node.js, and `gm-cli` executables and versions; compare Node against the package's `engines.node` constraint and fail helpfully on an unsupported combination.

Never call `gm` from PowerShell: it resolves to the built-in `Get-Member` alias. Resolution order should be the tool-local `node_modules\.bin\gm-cli.cmd`, an explicit configured path, then `gm-cli.cmd` on `PATH`. An npx cache may be reported for diagnosis but must not be the normal execution dependency.

## User-facing command model

The exact flags should be settled by executable tests, but the command families should support these workflows:

```powershell
# Understand a project without knowing its disk layout.
gmtool.ps1 inspect C:\path\game.yyp --json
gmtool.ps1 find C:\path\game.yyp obj_camera --json

# Map logical code to its real source and read a complete resource bundle.
gmtool.ps1 resolve C:\path\game.yyp obj_camera.Create
gmtool.ps1 read C:\path\game.yyp obj_camera --include-code --json

# Safely modify code or ensure a missing event/resource exists.
gmtool.ps1 write C:\path\game.yyp obj_camera.Create --from C:\temp\Create.gml --dry-run
gmtool.ps1 add event C:\path\game.yyp obj_camera Draw.GUI --from C:\temp\DrawGUI.gml
gmtool.ps1 add script C:\path\game.yyp camera_math --folder "Simple3D/Scripts/Math" --from C:\temp\camera_math.gml

# Coordinate structural changes and check the result.
gmtool.ps1 rename C:\path\game.yyp script old_name new_name --dry-run
gmtool.ps1 validate C:\path\game.yyp --strict --json

# Compile, test, run, and collect verbose debugging feedback through gm-cli.
gmtool.ps1 compile C:\path\game.yyp --target windows --runtime vm
gmtool.ps1 test C:\path\game.yyp --target windows --runtime vm
gmtool.ps1 debug C:\path\game.yyp --target windows --runtime vm --timeout 60

# Find, explain, and conservatively repair simple syntax errors.
gmtool.ps1 diagnose C:\path\game.yyp --changed --json
gmtool.ps1 explain-error C:\path\game.yyp obj_player.Step --line 42
gmtool.ps1 repair-syntax C:\path\game.yyp --changed --dry-run
```

For existing code, `resolve` should return a path that normal agent tools can inspect or patch directly. `write` exists for callers that want hashing, diff preview, validation, and transaction guarantees. Structural edits must always use coordinated commands.

## `gm-cli` integration contract

Use `gm-cli resourcetool` for its supported understanding and mutation of GameMaker resources, and `gm-cli compile`/`run` for compiler and runtime feedback. Keep raw stdout, stderr, exit code, duration, resolved CLI version, target, runtime, toolchain, and config in every operation record.

ResourceTool must be sandboxed more aggressively than its command names imply. A local probe with `gm-cli` 2.2.0 showed that `resourcetool eval "resource list"` saved and normalized the project, touching 84 metadata files and adding defaults such as `collisionObjectId: null`. Therefore:

1. Copy the project text/metadata into a disposable workspace while referencing or copying required binary assets safely.
2. Run ResourceTool `eval` or `script` only in that disposable workspace for inspection and dry runs.
3. Compare pre/post bytes and parsed semantics.
4. For an approved mutation, translate the intended semantic delta into minimal lossless edits in the real project, or present the full official serialization diff if exact minimal translation is not supported.
5. Hash the real project before and after every direct `gm-cli` call and fail if an unexpected file changes.

MCP mode may be offered as an optional adapter, but it follows the same disposable-copy and diff rules. Interactive `repl` is for human diagnosis, not unattended mutation.

Build/debug behavior:

- Derive the default GMS2 toolchain from the project's `MetaData.IDEVersion` when compatible, while allowing an explicit override.
- Store target, runtime (`vm` or `native`), config, timeout, and optional toolchain options in a project-local config that contains no credentials.
- Run structural validation before compilation. `test` means validate, compile, then optionally run a configured smoke-test room/harness; compilation alone must not be reported as gameplay-test success.
- Use `--errors-only` for concise verification and `--verbose` for debug sessions. Preserve raw logs and map compiler locations back to logical resource names and real paths.
- Put caches, packages, logs, and build outputs under an explicit tool/cache directory, not among GameMaker source files.
- Never print access keys or license contents. Prefer `GAMEMAKER_CLI_LICENSE` or a protected configured path.
- A run/debug timeout must terminate only processes started by that invocation and must distinguish timeout, compile failure, runtime crash, and successful exit.

Syntax diagnosis and repair follow `SYNTAX_REPAIR.md`. Fast local token checks provide immediate locations, but `gm-cli compile` is the authoritative acceptance check. A repair is eligible for automatic application only when it is local, syntax-only, uniquely determined, minimal, verified on a disposable copy, removes the targeted diagnostic, introduces no new diagnostics, and preserves all unrelated bytes. The tool must prefer returning a ranked explanation over guessing.

## Resource adapter architecture

Every resource family must register an adapter with the same contract: `discover`, `describe-schema`, `read`, `create`, `ensure`, `patch`, `rename`, `move`, `duplicate`, `delete`, `import`, `export`, `dependencies`, `preview`, `validate`, and `roundtrip-test`. Unsupported operations must fail explicitly; they must never fall back to generic JSON rewriting.

Agent input uses a strict, versioned recipe format independent of `.yy` layout. Recipes support symbolic references, deterministic defaults, units, color formats, coordinate systems, asset provenance, and `--explain`. They can be validated without touching the project and applied idempotently with `ensure`. The adapter translates the recipe into the detected GameMaker version only after a dry-run operation graph is approved.

Every view operation emits a standard artifact bundle: a concise Markdown summary, normalized JSON, dependency links, diagnostics, and the best available preview (PNG/SVG/HTML, playable audio, contact sheet, waveform, plot, timeline, or runtime capture). Preview artifacts live in a cache outside project sources and include hashes of every input so stale views are detectable.

Unknown future resource types still receive safe raw discovery, byte-preserving copy/export, reference reporting, and a clear unsupported diagnostic. They may not be mutated until a versioned adapter and its full acceptance suite exist.

## Internal model

On discovery, create an in-memory index with:

- project identity, IDE version, resource version, configuration, and target metadata;
- resource name, type, `.yy` path, parent folder, order, and project-list position;
- object event type/number mapped to canonical event names and `.gml` paths;
- script `.gml`, shader `.vsh`/`.fsh`, room creation code, notes, included files, and binary assets;
- inbound and outbound resource references with the source file and token span;
- warnings for duplicates, orphans, missing files, case mismatches, or unsupported structures.

Cache only derived indexes, keyed by project path plus file hashes. Never require cache state to read or repair a project.

## Lossless format strategy

GameMaker files observed in the baseline use quoted keys and values but permit trailing commas. Implement a tokenizer/concrete syntax tree that records whitespace, punctuation, value spans, and original byte offsets. Reads can expose a normal object model; writes replace the smallest possible token span or insert a new member using nearby formatting as the template.

Do not run metadata through `ConvertFrom-Json`/`ConvertTo-Json`, `json.dumps`, or another whole-document serializer. Those are useful only for generated test expectations, never for rewriting existing GameMaker files.

Before a transaction:

1. Hash every input and intended output path.
2. Parse and validate the current project.
3. Build an operation manifest with all edits, creates, moves, and deletes.
4. Render proposed files in memory and validate the rendered project.
5. On commit, verify hashes again, write sibling temporary files, and atomically replace targets.
6. Record a recoverable transaction manifest and keep backups until the command completes successfully.

## Validation contracts

`validate` should report at least:

- exactly one selected `.yyp`, unless explicitly supplied;
- parseability under the detected version profile;
- unique resource names and normalized paths;
- agreement between resource name, directory, descriptor name, and project entry;
- all `.yyp` resource targets exist and all managed descriptors are registered;
- resource-order entries point to real resources without contradictory duplicates;
- object event declarations have matching event files, and event files have declarations;
- all resource references resolve with correct type where known;
- room creation order, layer instances, and instance IDs are internally consistent;
- shader descriptors have the expected source stages;
- sprite frame/layer UUID references and image files are complete;
- casing matches on disk so projects remain portable to case-sensitive systems.

Diagnostics should distinguish errors that block mutation from warnings that may be intentional.

## Delivery phases

### Phase 0: fixture corpus and contracts

- Add a pinned local `gm-cli` dependency and implement `doctor` checks for Node, CLI, package engine constraints, local cache, GameMaker toolchain availability, and the PowerShell `gm` alias collision.
- Copy minimal, anonymized examples for projects, scripts, objects/events, shaders, rooms, sprites, notes, and resource order into `tests/fixtures`.
- Document event type/number mappings for the baseline version.
- Add golden tests proving no-op parsing and writing is byte-identical.
- Capture a golden test proving ResourceTool queries are treated as potentially mutating and that disposable-workspace diffs detect normalization.
- Generate a resource-class inventory from each pinned ProjectTool version and reconcile it against `RESOURCE_COVERAGE.md`; fail CI when a newly discovered class is unclassified.

**Exit:** every baseline resource kind can be identified, parsed losslessly, and round-tripped without a byte change; the pinned `gm-cli` and compatible Node runtime pass `doctor`.

### Phase 1: discovery, index, and read workflow

- Implement `doctor`, `.yyp` discovery, version detection, `inspect`, `find`, `resolve`, and `read`.
- Return stable JSON suitable for another agent or script.
- Resolve scripts, object events, room creation code, and shader stages to their physical source paths.
- Add generic raw inspection plus normalized summaries for every resource family in the coverage matrix.
- Implement dependency graphs, reverse references, folder/tag/config/group membership, binary hashes, and preview cache keys.

**Exit:** an agent can navigate and read the entire code surface without manually interpreting GameMaker filenames.

### Phase 2: validator and guarded code writes

- Implement reference/file validation and stable diagnostic codes.
- Add `write`/`patch` for existing `.gml`, `.vsh`, and `.fsh` files with hash checks, dry runs, diffs, temporary files, and rollback.
- Detect edits made by GameMaker or another process between planning and commit.
- Implement normalized `diagnose` output for GML, shader, and GameMaker metadata parse errors, including cascading-error grouping and logical resource/path mapping.

**Exit:** existing code can be changed with a preview and a clean post-write validation report.

### Phase 2a: conservative syntax repair

- Implement the candidate classes, confidence rules, disposable-copy verification loop, repair budgets, and refusal behavior in `SYNTAX_REPAIR.md`.
- Add `explain-error` and `repair-syntax`, with changed-files/resource filters and machine-readable proposed patches.
- Seed a mutation corpus from valid fixtures and prove accepted fixes compile while unchanged surrounding bytes remain identical.

**Exit:** common single-site syntax mistakes can be found and safely repaired with a reviewed minimal diff; ambiguous cases produce actionable diagnostics without modifying files.

### Phase 2b: compile and debug feedback

- Wrap `gm-cli compile` and `gm-cli run` with pinned-version execution, target/runtime/config profiles, process ownership, timeouts, and normalized logs.
- Implement `test` as validation plus compile, with an opt-in runtime smoke harness rather than claiming that a build is a gameplay test.
- Hash project sources before and after commands and report unexpected rewrites.

**Exit:** an agent can compile after a code change, receive path-mapped diagnostics, and run a bounded debug/smoke session without manually assembling GameMaker toolchain flags.

### Phase 3: common structural mutations

- Use ResourceTool on disposable clones as the semantic oracle for supported mutations, then apply or present reviewed minimal diffs.
- Add/rename/remove scripts.
- Add/rename/remove object events using versioned event mappings.
- Add/rename/remove shaders and included data files.
- Update `.yyp`, `.resource_order`, descriptors, folders, and source files in one transaction.

**Exit:** common code-centric resource changes no longer require manual metadata translation, and their adapters satisfy the complete lifecycle contract.

### Phase 4: complex resources

- Implement the remaining adapters in `RESOURCE_COVERAGE.md`: bitmap/vector sprites, sounds and audio routing, tile sets, fonts, paths, animation curves, timelines, sequences, particles, rooms and room UI, extensions, project settings, platform options, groups, included files, notes, packages, and prefabs.
- Add domain-specific recipe validators and preview renderers for spatial, visual, temporal, audio, font, tile, particle, and relationship content.
- Generate IDs through a centralized provider and test uniqueness/referential integrity.
- Add deterministic import/export/transcode pipelines for image and audio inputs using pinned optional dependencies; preserve originals and provenance and never silently degrade quality.

**Exit:** every matrix row passes minimal and complex create/edit/view/rename/delete/round-trip/compile scenarios. No resource family is marked fully supported based only on parsing.

### Phase 5: GameMaker build feedback

- Expand the Phase 2b adapter to packaging and additional supported targets.
- Add optional runtime test protocols for structured assertions, screenshots, performance counters, and crash artifacts.
- Track `gm-cli`/toolchain compatibility in tested version profiles and make upgrades an explicit, reviewable operation.

**Exit:** supported targets can be tested and packaged reproducibly, with artifacts and diagnostics tied to the exact CLI and toolchain versions.

## Test strategy

- Unit-test tokenization, path normalization, event mapping, minimal insertion, and diagnostics.
- Use golden tests for exact bytes before/after each targeted mutation.
- Use malformed fixtures for dangling references, duplicates, missing event files, stale order entries, bad UUIDs, casing errors, and concurrent edits.
- Clone fixtures into temporary directories for transaction and rollback tests.
- Test `gm-cli` adapters with recorded stdout/stderr plus disposable integration projects; never let ResourceTool integration tests point at the working fixture corpus.
- Verify compile/run wrappers preserve exit codes, respect timeouts, own only their child processes, redact credentials, and detect unexpected project rewrites.
- Run a read-only validation against `Simple3D`; never make it the only test corpus or mutate it from automated tests.
- Before declaring a version supported, open a generated disposable fixture in that GameMaker version and confirm it can save/reopen without metadata churn.
- Maintain a generated “kitchen sink” project containing minimal and complex examples of every supported resource and nested subtype. It must open/save in GameMaker, survive ResourceTool serialization, compile, and regenerate equivalent preview bundles.
- Run dependency-aware mutation sequences, randomized legal recipe tests, crash injection at each transaction stage, archive/path traversal tests, malformed media tests, case/Unicode/long-path tests, and large-project performance tests.
- Record a capability manifest by GameMaker version and resource family. CI must prove every claimed operation rather than treating a version or family as all-or-nothing.

## Scope boundaries

- The tool provides complete programmatic creation, editing, inspection, and preview workflows. It need not reproduce every interactive gesture of GameMaker's visual editors, but any unsupported field or nested subtype must be reported explicitly and preserved losslessly.
- It must never invent undocumented fields when it can copy a structure from an existing same-version resource or refuse safely.
- Bulk formatting is not a feature. Minimal diffs are a compatibility and review requirement.
- Project code remains in the GameMaker project. The tool directory contains implementation, schemas, and fixtures only.
- Creative generators such as image, music, voice, or 3D tools remain pluggable producers. The GameMaker layer owns deterministic placeholder generation, import, transformation, registration, provenance, validation, and preview of their outputs.
