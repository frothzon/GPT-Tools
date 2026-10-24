# GameMaker workbench

The guarded workflow is `session → context → change prepare → change verify → scenario → change apply`. The CLI, local browser interface, and optional stdio MCP adapter call the same service. GameMaker's official `gm-cli` 2.3.0 remains the compiler and ResourceTool backend.

## Start

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' session open 'C:\path\game.yyp' --profile 'C:\path\profile.json' --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' serve SESSION_ID --port 8765
```

Open the printed token URL. The loopback server checks Host, Origin, and an unguessable session token. Keep that URL private. Resources, source context, candidate diffs, verification evidence, recovery status, and official manual search are available in the browser. CLI `report SESSION_ID` also produces a portable local review artifact.

Example profile:

```json
{"toolchain":"GMS2@2024.14.4","target":"windows","runtime":"vm","config":"Default","timeout":180,"docsChannel":"project","language":"en"}
```

## Review and apply

`context PROJECT bag_insert_item --json` finds a callable and reports its owning source, lexical callers, initialization candidates, inheritance, diagnostics, and official API hints. Lexical relationships are candidates, not proof of dynamic dispatch.

Example manifest (replace HASH with the source hash returned by context):

```json
{"operations":[{"kind":"patch","spec":"add_item.code","expectedHash":"HASH","patches":[{"old":"unique original text","new":"replacement text"}]}]}
```

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' change prepare PROJECT --manifest manifest.json --profile profile.json --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' change verify PLAN_ID --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' scenario run PLAN_ID --suite suite.json --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' change apply PLAN_ID --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' change apply PLAN_ID --apply --json
```

Preparation freezes candidate bytes, original hashes, operations, and profile. Apply rejects changed originals, altered candidates, mismatched verification, or failed required checks. Default required checks are structure, syntax, and compilation. Include `requiredChecks` in the manifest to require a scenario. Patches reject ambiguous anchors and preserve BOM/newlines. Transaction recovery refuses to overwrite external edits. Legacy `write`, `resource`, and `resource-tool` remain available for compatibility; use change plans for separately reviewed and verified work.

## Gameplay checks

Suites use deterministic seeds, setup/teardown, named assertions, explicit frames, and a frame budget. Passing requires every expected assertion and the final completion record, plus successful process exit. Compile success is recorded separately from gameplay success. Runtime suites use disposable copies and unique save namespaces; generated code verifies the namespace before setup. Arbitrary GML can still access explicit filesystem paths and is not an OS sandbox.

`tests/fixtures/scenarios/crafting_game_v3.json` checks actual inventory clamps, crafting input costs/timing/completion, and building affordability. An explicit bootstrap can attach to existing startup Create/Step events when ResourceTool injection is unavailable. Screenshot checkpoints are supported for injected test rooms; bootstrap screenshots require an adapter and are currently rejected. Capturing a screenshot does not constitute visual approval.

## Full official manual

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' docs sync --channel project --offline-zip 'C:\ProgramData\GameMakerStudio2\Manual\GMS2-Robohelp-en.zip' --offline-version 2024.14.3.124 --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' docs lookup clamp --channel project --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' docs coverage --channel project --json
& 'C:\Agent Tools\game-maker\gmtool.ps1' docs sync --channel monthly --workers 2 --json
```

The installed official manual contains 3,112 indexed pages and has been completely imported. It is version 2024.14.3.124, not a claim of completeness for today's monthly runtime. The online monthly import currently has 977 of 3,113 enumerated pages; the official server returned HTTP 429. Coverage reports failed URLs and partial status. Import retries stop after rate limiting. Lookup retains official URLs, signatures, argument/return information, caveats, hashes, and provenance; missing runtime availability remains unknown. Use coverage and channel/version evidence when selecting a function. The importer never invents missing documentation.

## MCP

Configure a stdio client to execute `py -3 C:\Agent Tools\game-maker\gmtool-launch.py mcp SESSION_ID`. The adapter exposes the same bounded service actions and project containment as the browser. It is implemented but is not automatically registered in Codex. `registry --markdown` exports the executable recipe contract; consult `capabilities` for version gates before resource edits.

## Evidence and limits

Artifacts and evidence live under `.gmtool-work` in the tools directory. Python regression tests cover plans, stale/tampered candidates, patching, event mapping/inheritance, external-edit recovery, docs, scenario protocol, HTTP authentication, and MCP dispatch. Real GameMaker compilation and runtime checks are recorded in `research/integration-result.json` and `research/project-scenario-result.json`. Browser acceptance evidence is in `research/browser-result.json`.

Resource families still have explicit partial lifecycle coverage; unsupported schema edits are blocked. Current project validation reports unresolved collision target metadata and two undeclared draw files. Those issues were discovered in existing game files and are not silently repaired. Changes can compile while structural checks fail; apply remains blocked under the default policy.
