# GameMaker coding interface and verification improvement plan

Reviewed 2026-10-03. This is a proposal, not an implemented command catalog. Existing commands remain governed by README.md and `capabilities --json`.

The goal is to make correct GameMaker work the easy default: obtain the relevant context, prepare a small coordinated change, verify it against the actual compiler and game behavior, and apply exactly the change that was reviewed. Extend the existing gmtool Python core and pinned official gm-cli backend. Keep reusable implementation, fixtures, and documentation in this tool directory.

## What was reviewed and verified

Reviewed AGENTS.md, README.md, PLAN.md, the command dispatcher, resource index, capability manifest, source transactions, compiler diagnostics, backend adapter, compatibility shim, and representative project GML and object descriptors.

| Observation | Evidence and implication |
| --- | --- |
| A substantial harness already exists | Logical read/resolve, source writes, disposable ResourceTool clones, dependency graphs, recovery, validation, previews, and compile/run adapters are implemented. Preserve these foundations. |
| Fixture suite passes | Ran the documented pytest command from tests/: **33 passed**. These tests do not establish compiler integration or gameplay correctness. |
| Environment probe succeeds | Python 3.11.4, local gm-cli 2.3.0, and a compatible Node 24.19.0 are available. PATH also contains Node 20.20.2; the adapter explicitly selects compatible Node. No upgrade is required by this review. |
| Project needs a matching format fixture | crafting_game_v3 reports IDE 2024.14.2.213, resource format 2.0, 310 resources, 254 indexed source entries, 138 scripts, and 38 objects. Indexed entries include potentially missing paths; this is not a count of confirmed physical files. |
| Collision mapping is demonstrably wrong in the core | index.py derives filenames from eventType/eventNum alone. Project collision descriptors carry collisionObjectId and real files use Collision_obj_player.gml and similar names. Core validation reports 12 errors and 8 warnings; all 12 errors involve Collision_0.gml. A compatibility shim suppresses matching diagnostics but does not correct core logical resolution. |
| Other validator findings need individual review | Two warnings concern undeclared draw files. Do not automatically delete them or suppress them with collision findings. |
| Reviewed source is not bound to later application | `write` computes the current source hash on every invocation. Its transaction detects concurrent edits during that invocation, but a separate preview and apply do not share a durable reviewed plan. A change between them can become the new baseline silently. |
| Source writes have limited validation | `write` replaces an entire source file and checks a delimiter/string/comment scanner. It does not compile the candidate before committing it. Scanner acceptance must never be presented as full GML correctness. |
| The test command is a build check | cli.py routes both compile and test to gm-cli compile, with an explicit gameplay disclaimer. Keep backwards compatibility, but expose the verification level prominently. |
| Capability descriptions drift | README describes recipes for families the coarse manifest still marks planned, including configuration/group operations. The manifest is static; adding project summary does not enforce version-specific support. Resolve inconsistencies with tests before enabling operations. |
| Context needs to follow GML semantics | scripts/add_item defines bag_insert_item rather than a function matching the asset name. BuildingCard contains constructor static methods and bound callbacks; obj_player has a parent object and multiple step/draw events. Resource-name search alone cannot explain this code. |
| Existing local change must be preserved | git status showed options/windows/options_windows.yy already modified. This review did not change game code or metadata. |

No game compilation, execution, or visual gameplay validation was performed. The project findings above are static inspection and tool output, not a claim that the game is broken.

## Available tools and their roles

- **gmtool CLI:** primary GameMaker boundary. Retain its dry-run defaults, clone-first ResourceTool integration, source hashes, journals, and recovery.
- **Official gm-cli:** authoritative backend for resource semantics and builds. Installed documentation also describes manual search and a ResourceTool MCP server. Any agent-facing integration should wrap gmtool protections rather than expose unrestricted ResourceTool writes to the working project.
- **Shell, rg, file patches, Git:** inspect implementation, develop tooling, review diffs, and run fixture tests. Use guarded logical operations for game source and resource mutations when supported.
- **Codex file/review panels:** show code, diffs, and reports with clickable source locations. A custom desktop extension API was not established by this review; start with a local report that can be opened in a panel.
- **Web/manual lookup:** verify uncertain built-in behavior against official documentation and the selected GameMaker version. Return source links and version context.
- **Browser automation:** can inspect a future local dashboard. Native app automation is disabled in this session, so it is not a dependable GameMaker IDE control channel.
- **Generic media/document/site tools:** useful for their own tasks, but do not validate GML or replace the build harness. No additional plugin is necessary for the first implementation.

The normal Windows sandbox failed before starting both shell and Node REPL processes with an ACL setup error. Reviewed commands ran successfully through approved shell escalation. This is an execution-environment problem to report separately from GameMaker diagnostics; a new harness cannot itself repair the host sandbox.

## Proposed workflow

`Open session -> inspect context -> prepare patch -> review diff -> verify candidate -> apply exact plan -> report evidence`

Every result should identify the project, logical resource, source hashes, operation, selected profile, diagnostics, and evidence artifacts. Every verification stage has an explicit passed/failed/skipped/blocked state. “No parsed errors” is not proof of a successful build; timeout is not a gameplay pass.

The following command names are **proposed** and must not be invoked until implemented and added to the command catalog:

```text
gmtool session open <project> --profile <profile> --json
gmtool context <project> <logical-spec-or-symbol> --json
gmtool change prepare <project> --manifest <change.json> --json
gmtool change verify <plan-id> --checks structure,compile --json
gmtool scenario run <plan-id> --suite <suite> --json
gmtool change apply <plan-id> --json
gmtool report <session-id> --format html
```

### 1. Correct the foundation first

Create one version-aware event resolver used by indexing, validation, compiler diagnostic mapping, source edits, previews, and resource recipes. Represent collision events by target identity, not eventNum alone; return a logical name such as obj_item_potion.Collision.obj_player. Include inherited events and effective owning source in reads. An ambiguous alias must refuse and enumerate exact alternatives.

Add fixtures for the project's 2024.14 format and the existing Simple3D baseline. Verify each target collision maps to its own real source, a missing targeted source remains an error, and numeric legacy handling is selected only when supported by evidence. Replace suppression with accurate mapping, then retire the shim after parity checks.

Generate CLI help, schemas, capability manifests, and documentation status from one operation registry. Track support at recipe and version level as well as family level; attach acceptance-test evidence. A recipe listed in help must agree with the manifest, and planned/unknown-version mutations must refuse before writing.

Separate structural validation, syntax hints, compiler results, runtime execution, gameplay assertions, and visual review in the result contract. Keep the existing test alias but label it `build-check`; introduce scenario testing as a distinct operation.

### 2. Make code changes small and reproducible

Add a patch API that accepts logical source IDs, expected content hashes, and exact anchored replacements or unified hunks. Reject missing/duplicate anchors and overlapping edits. Preserve BOM, newline style, encoding, and every untouched byte. Full-file replacement remains available explicitly.

A prepared change stores immutable candidate bytes, original hashes, project identity, operation schema version, profile, diff, dependency impacts, and a content-derived plan ID. Compile and validate that exact candidate in a disposable workspace. Applying a plan uses stored bytes rather than recomputing ResourceTool expressions or reading a mutable replacement file.

Check all relevant source/metadata hashes again before application, including dependencies used by validation. If the IDE, OneDrive, or another process changes them, mark the plan stale and require a new preview and verification. Bind validation evidence to the candidate digest and profile. Preserve existing uncommitted changes as the baseline.

Support code and resource operations in one coordinated change. Reuse existing file-set transactions; add a project lock, interrupted-state recovery, and conflict-aware rollback. Individual filesystem replacements are atomic, but a multi-file filesystem change is not globally atomic: journal every step and expose incomplete state until recovery finishes. Never overwrite an external edit during rollback.

### 3. Supply the context needed to write better GML

Build a source-range index of functions, constructors, static methods, enums, macros, declarations, references, and JSDoc parameters. Distinguish script asset names from callable names. Start with conservative extraction, then use a parser only after proving support for the targeted GML syntax; do not market regex results as full semantic analysis.

`context` should return the selected source, parent/event chain, initialization sites, likely callers and callees, struct/global field definitions, relevant resource references, existing diagnostics, and nearby project conventions. Show reference confidence and unresolved dynamic dispatch explicitly. Include methods bound through method(self, ...), with-scope changes, and event_inherited where relevant; avoid inventing inferred types.

Cache by source digest, update incrementally, and paginate by source ranges. Never silently truncate critical context. Provide a concise default bundle and links to expanded evidence.

Add version-scoped built-in documentation lookup with signatures, availability, and official source links. Cache consulted references; refuse to assert support based on documentation for a different runtime. Suggested API use and semantic edits remain compiler-verified changes.

### 3a. Complete official function reference

Make comprehensive documentation a P1 deliverable alongside context lookup. The existing proposal for consulted-reference caching is insufficient for complete function discovery. Use the official manual as the authority and build a searchable local catalog of all discoverable documented built-ins, variables, constants, language constructs, and related topics. Project functions and extension APIs belong in separately identified catalogs.

Maintain two selectable views: the current stable/manual channel for discovering current APIs, and the project's selected runtime/profile for writing compatible code. Monthly, LTS, and beta are distinct documentation channels; a channel or retrieval date alone does not prove compatibility with an exact historical runtime. Mark availability unknown when version evidence is absent; verify through release notes and compiler fixtures where feasible.

For each entry, store exact identifier, category, signature/overloads, parameter and return information, documented defaults, side effects, execution-context requirements, platform limitations, deprecation/replacement information, example links, source URL, documentation channel, retrieval time, content hash, and version evidence. Preserve documented unknowns rather than inventing fields.

Prefer supported official manual/index distribution interfaces where available. Investigate the manual's navigation/index assets to enumerate documented pages; the official gm-cli manual semantic reader is useful for retrieval but does not establish exhaustive coverage or exact identifier resolution. Use exact-name lookup first, then semantic search for discovery. Cache permitted content locally with attribution and original links; do not publish a copied manual as part of the dashboard.

Proposed additional interfaces, not yet implemented:

```text
gmtool docs sync --channel monthly --language en --json
gmtool docs coverage --channel monthly --json
gmtool docs lookup <identifier> --profile <profile> --json
gmtool docs search <query> --profile <profile> --json
gmtool docs diff --from <snapshot> --to <snapshot> --json
```

Integration: when context includes built-in calls, attach exact signatures and relevant caveats automatically. Offer search, category browsing, source links, and current/project-version filters in the dashboard. Add checks for confidently known arity and platform/version mismatches; uncertain dynamic calls remain warnings. Refresh explicitly or through a user-authorized schedule, stage new snapshots, and retain the prior version on failed updates.

Acceptance requires an enumeration manifest, documented-entry counts by category, unresolved entries, failed downloads, duplicate/alias handling, extraction tests, and spot checks against original pages. Validate coverage against the selected official index and, if available, runtime symbol metadata. Report documented coverage separately from runtime-symbol coverage. Do not claim every runtime function is documented or that the catalog is complete merely because a crawl finished. Measure exact lookup accuracy and whether deliberately wrong argument order or unsupported APIs are detected. Show missing/stale documentation explicitly in verification reports.

### 4. Verify behavior in the actual runtime

Use gmtool's pinned compile/run wrappers with an explicit profile containing target, VM/native choice, toolchain, configuration, and timeout. Resolve and record the actual runtime/compiler versions. Establish a baseline build separately from each candidate; inherited project problems must be visible rather than silently accepted or mistaken for regressions.

Create a small GML scenario harness in reusable fixtures, with a project-specific adapter supplied explicitly. Inject test-only resources into the disposable candidate workspace, never into production by default. Use deterministic seeds, explicit setup/teardown, bounded frames, isolated save directories, and state assertions. The game should emit structured assertion records and a final completion record; the collector may use captured debug output or a run-specific artifact file.

Require matching run ID and candidate digest, expected test inventory, nonzero assertions for assertion suites, clean process completion, and a valid final record. Missing tests, crashes, incomplete output, timeout, or malformed reports fail or block. Screenshots alone cannot prove inventory/crafting state.

Initial proposed project scenarios:

- Inventory insertion clamps to item_limit and preserves unrelated inventory entries, using the intended inventory owner.
- Crafting success consumes the correct quantities and grants output; failure leaves state unchanged.
- Building affordability and placement agree; invalid placement does not charge resources.
- Parent/player initialization and room transition retain the intended persistent state without duplicate instances.
- Targeted item collision executes the intended handler once.
- Relevant GUI/render changes receive screenshots at fixed checkpoints plus human visual review when assertions cannot establish appearance.

Extract expected behavior from current code and the user's intended design before committing assertions. These are candidate suites, not claims that every behavior is already specified. Define performance budgets only after measuring a reproducible baseline.

### 5. Put a clean interface over the same core

Build a local dashboard with four views: **Resources**, **Code and context**, **Change review**, and **Verification**. Display event names and collision targets, inherited source ownership, symbols, a focused diff, stale-plan status, diagnostics linked to exact lines, and evidence for each verification stage. Keep project/profile and candidate identity visible.

Expose Prepare, Verify, Apply reviewed plan, and Recover actions. Block application only for stale inputs, unsupported mutations, or unmet selected verification requirements, with a concrete reason. Do not add repetitive human confirmation to already authorized routine edits; the agent can inspect the diff and proceed within the user's request. Destructive behavior still follows existing authorization rules.

Start with a generated HTML report opened in the Codex browser panel. Add an interactive localhost service only after the transaction API is stable. Bind to loopback, use a per-session token for mutations, check request origins, and constrain project paths. The interface must call the same operation registry/core as the CLI; it must not implement an independent writer.

Afterward expose a small optional MCP surface: session, context, prepare_change, verify_change, apply_change, run_scenarios, and report. Return structured diagnostics and artifact links; prohibit arbitrary shell expressions and raw working-project ResourceTool evaluation. Tool availability in Codex requires explicit installation/configuration and should not be assumed.

## Implementation order and acceptance criteria

| Priority | Deliverable | Completion evidence |
| --- | --- | --- |
| P0 | Correct event identity and accurate validation | Real-format collision fixtures pass; missing targets still fail; remaining project warnings are separately explained. |
| P0 | One registry and truthful verification states | Automated help/schema/manifest parity checks; build-check cannot appear as gameplay-tested; unknown version refuses unsupported writes. |
| P1 | Immutable change plans and minimal patches | Preview/apply race, replacement-file changes, duplicate anchors, byte preservation, external edit, and interruption tests pass. Applying a stale plan writes nothing. |
| P1 | Candidate validation/build orchestration | Malformed and noncompiling candidates leave the working project unchanged; evidence is tied to exact candidate and resolved profile. |
| P1 | Focused context and symbol discovery | Finds bag_insert_item in add_item, distinguishes static methods, resolves inherited event ownership, and labels uncertain references. |
| P2 | Runtime scenario protocol and initial adapters | Deliberate logic regression fails an assertion; timeout/crash/missing completion/zero tests cannot pass; production saves are untouched. |
| P2 | Local report and dashboard | Resource -> source -> diff -> evidence is navigable; Apply uses stored plans; stale state is visible. |
| P3 | Optional MCP and broader resource coverage | Same core contract passes through CLI and MCP; expand only against RESOURCE_COVERAGE.md lifecycle fixtures. |

First useful release: P0 plus immutable source plans, minimal patches, a focused context bundle, and compiler evidence. This directly improves daily coding before broad resource authoring or a polished dashboard.

Track rejected stale changes, accidental unrelated file changes, diagnostic mapping accuracy, first-compile success rate, regressions caught before apply, and context/build duration. Use a fixed task set: edit a player event, alter an inventory function, add a script/event, and exercise a collision handler. Compare baseline and improved workflow on disposable copies; prioritize fewer wrong edits over fewer tool calls. Completion requires evidence from real compiler/runtime integration in addition to fixture tests.

## Implementation locations and compatibility

- Extend index.py and validation.py with a shared version-aware event model.
- Add operation_registry.py and contract tests; derive capabilities.py and documented examples from that registry.
- Add change_plans.py and patches.py above transactions.py and recovery.py.
- Add context.py and symbols.py above existing index/graph facilities.
- Add verification.py and scenarios.py above gm_cli.py and compiler.py.
- Add report rendering after stable result schemas; add server/MCP adapters last.
- Keep project profiles and adapters explicit and project-agnostic in the core. Keep the existing CLI working while new workflows are adopted.

## Official references

- [YoYoGames gm-cli](https://github.com/YoYoGames/gm-cli): official backend; also described by the installed pinned package README.
- [Building and testing via command line](https://manual.gamemaker.io/lts/en/Settings/Building_via_Command_Line.htm): official command-line build integration. Confirm details against the selected toolchain; do not substitute arbitrary current-version commands into a pinned profile.
- [show_debug_message](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/Debugging/show_debug_message.htm): supported debug output, suitable as one transport for scenario records.
- [GameMaker debugger](https://manual.gamemaker.io/lts/en/IDE_Tools/The_Debugger.htm): interactive diagnosis for behavior that needs deeper inspection.

This review delivered the plan only. It preserved the existing implementation and game files; proposed commands and interfaces require implementation and verification before use.
# Implementation delivery

Implemented the shared registry, corrected event ownership and inherited context, lexical symbol context, strict patches, immutable candidates, stale/hash gates, conflict-aware recovery, separate compile/scenario evidence, complete installed-manual indexing with partial online coverage reporting, authenticated loopback workbench, and optional stdio MCP adapter. See WORKBENCH.md for commands and acceptance evidence. Broad resource lifecycle completion remains governed by RESOURCE_COVERAGE.md; current online monthly documentation was rate limited and is explicitly partial. Existing production game metadata was preserved.
