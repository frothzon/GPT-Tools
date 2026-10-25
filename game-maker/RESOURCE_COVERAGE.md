# Exhaustive GameMaker resource coverage

This document defines what “support all GameMaker content” means for the agent toolchain. It is a completion contract, not a wish list. The capability manifest must track every row separately for every supported GameMaker/ProjectTool version.

## Definition of full support

A resource family is fully supported only when all applicable operations below pass automated tests against minimal and complex fixtures:

1. **Discover:** inventory every resource and nested component without modifying the project.
2. **Describe:** return a concise summary, normalized JSON, source paths, schema/version, hashes, dependencies, reverse references, folder/tags/groups, and diagnostics.
3. **Create/ensure:** create from a strict declarative recipe with deterministic defaults; `ensure` is idempotent.
4. **Import/export:** ingest common source formats, retain originals/provenance when requested, and export an editable interchange form.
5. **Edit:** make domain-level changes without requiring an agent to understand `.yy` internals.
6. **Rename/move/duplicate:** update all metadata and known references, including project order and dependent resources.
7. **Delete:** show impact first, reject unsafe deletion by default, and support an explicit dependency-aware plan.
8. **View:** emit an agent-readable artifact bundle with summary, normalized data, dependency links, and a meaningful visual/audio/temporal preview.
9. **Validate:** check schema, binary payloads, references, invariants, target compatibility, and casing.
10. **Round-trip:** open/save in the target GameMaker version and through the pinned ResourceTool without semantic drift; no-op tool operations are byte-identical.
11. **Build/test:** compile a kitchen-sink fixture and run any resource-specific smoke test needed to prove runtime behavior.
12. **Recover:** dry-run, journal, atomic commit, rollback, concurrent-edit detection, and crash recovery all work for the resource.

Parse-only, raw-JSON editing, or successful compilation alone is not full support.

## Cutout animation harness (separate artifact workflow)

The animation editor is a separate content-authoring workflow rather than a claim of full generic GameMaker sprite, sequence, or room coverage. Current evidence: versioned `.gmanim` save/load and hash validation; supported SCML migration; PNG/GIF rendering; rounded attachment slicing; per-key transforms, interpolation, pivots, image selection, events, bones, parts and character maps; and ProjectTool-backed `.yymps` export. The zombie package contains 15 entities, 60 clips, 187 referenced sprite resources, the consolidated runtime, guide, and a demo object/room. The package-only project passed strict structural validation and GameMaker VM compilation. This does not yet establish GameMaker IDE import round-trip, runtime gameplay assertions, exact Spriter-render pixel parity, or support for meshes, nested entities, sound, and crossfades. See [ANIMATION_HARNESS.md](ANIMATION_HARNESS.md).

## Uniform agent interface

All adapters expose the same command vocabulary, with resource-specific options discoverable through `schema` and `--explain`:

```powershell
gmtool inventory game.yyp --type all --json
gmtool schema sprite --version auto --json
gmtool get game.yyp spr_player --view full --json
gmtool create game.yyp sprite --recipe spr_player.json --dry-run
gmtool ensure game.yyp object --recipe obj_player.json
gmtool set game.yyp spr_player origin.x=16 origin.y=24 --dry-run
gmtool patch game.yyp rm_level --recipe room-changes.json --dry-run
gmtool rename game.yyp spr_player spr_hero --references safe --dry-run
gmtool move game.yyp spr_hero --folder "Characters/Player"
gmtool duplicate game.yyp obj_enemy obj_enemy_elite
gmtool delete game.yyp snd_old --impact --dry-run
gmtool import game.yyp sprite walk_strip8.png --name spr_walk --recipe import.json
gmtool export game.yyp seq_intro --format recipe --output out
gmtool preview game.yyp rm_level --output-cache
gmtool graph game.yyp obj_player --direction both
gmtool validate game.yyp --strict --json
```

Every mutating command first produces an operation graph listing file edits, generated IDs, dependency changes, binary transformations, validation steps, and expected preview/build checks. `--apply` commits exactly that graph if input hashes still match.

## Project and organization

| Family | Build/edit coverage | Required view | Critical validation |
| --- | --- | --- | --- |
| Project (`.yyp`) | Identity, metadata, template type, room order, configs, resource registration, included files, prefab references | Project dashboard and resource counts | Unique names/paths, IDE/profile compatibility, complete registrations |
| Folders and resource order | Create/move/rename/delete folders; stable ordering; nested folder paths | Asset-browser tree | Orphans, duplicate paths, missing parents, stable order |
| Tags | Create/delete tags; assign/unassign resources | Tag-to-resource matrix | Unknown resources/tags, duplicates |
| Configurations | Create/inherit/rename/delete configs; config-specific values | Config diff table | Broken inheritance, invalid selected config |
| Platform options | Main plus Windows, macOS, Linux, HTML5/Wasm, Opera GX, Android, iOS/tvOS, consoles, and future discovered targets | Redacted settings report and cross-target diff | Secrets excluded, required icons/files, target-specific ranges and paths |
| Texture groups | Create/edit groups, targets, compression, scaling, borders, load mode; assign resources | Membership and estimated atlas report | Missing group, incompatible settings, duplicate membership |
| Audio groups | Create/edit groups, export settings, targets; assign sounds | Membership and estimated size report | Missing group, invalid target/export configuration |
| Included data files | Add/replace/move/remove files and directories; copy masks | File tree with MIME/size/hash/text preview where safe | Traversal, missing payload, collisions, unsafe size/type |
| Notes | Create/edit/rename/move/delete Markdown/plain notes | Rendered Markdown/text | Encoding, links, path consistency |
| Prefabs, packages, links | Import/export package or prefab, restore dependencies, inspect/apply link changes | Dependency and provenance report | Signatures, unresolved links, version constraints, archive safety |

## Code and executable behavior

| Family | Build/edit coverage | Required view | Critical validation |
| --- | --- | --- | --- |
| Scripts | Create/import/edit/rename/delete GML and declarations; symbol/reference index | Syntax-highlighted source, outline, callers/callees | Parse/compiler errors, duplicate globals/functions, unsafe rename sites |
| Objects | Sprite/mask, parent, persistence/visibility/solid/managed, physics, variables/properties, overrides | Object card, inheritance graph, property table | Parent cycles, missing assets, invalid overrides and physics shapes |
| Object events | All event types/subtypes, collision targets, GML/GML Visual markers, add/remove/reorder | Event matrix and source bundles | Type/number mapping, filename/declaration parity, collision references |
| Shaders | Create/import/edit vertex/fragment stages and supported shader language types | Paired source plus compiled fixture image when possible | Both stages, target language compatibility, compile/link diagnostics |
| Timelines | Create/edit moments and moment code, reorder/remove moments | Timeline plot and moment source panels | Unique/nonnegative moments, matching code files |
| Extensions | Files, functions, constants, options, proxies, frameworks, init/final code, per-target binaries | API surface, platform matrix, file/hash report | ABI/signature fields, missing binaries, permissions, secrets, untrusted executable handling |

Code-aware rename must distinguish code, comments, strings, dynamic lookup, macros, and reflection-like asset access. “Safe” mode changes only proven references; ambiguous sites are reported for review.

GML and shader adapters also implement the compiler-backed `diagnose` and conservative `repair-syntax` contract in `SYNTAX_REPAIR.md`. Syntax repair is tested separately from semantic refactoring and never broadens into an unreviewed code rewrite.

## Images, sprites, tiles, and fonts

| Family | Build/edit coverage | Required view | Critical validation |
| --- | --- | --- | --- |
| Bitmap sprites | Create/import single images, strips, sheets, GIF/APNG where supported; frames, image layers/folders, playback, origin, bounding box/masks, nine-slice, texture settings | Contact sheet/animation, layer tree, mask/origin/nine-slice overlays | Dimensions, frame/layer UUID graph, image presence, alpha, masks, power/size limits |
| Vector sprites and shapes | Create/import supported vector data; shapes, subshapes, fills/gradients, transforms, styles | SVG/PNG render and shape tree | Supported primitives/fills, winding, bounds, renderer compatibility |
| Tile sets | Sprite binding, tile size/offset/separation, masks, animation frames, auto-tile sets | Labeled tile atlas, animation, auto-tile rule diagram | Source grid fit, valid tile indexes, animation powers/ranges, auto-tile references |
| Fonts | System or supplied font source, size/style, anti-aliasing, ranges/glyph selection, texture settings | Glyph atlas and sample strings | Font license/provenance, missing glyphs, overlapping/invalid ranges, target rendering |
| Icons and splash/options images | Generate/import all target-required sizes and variants from a master | Size/contact sheet by target | Exact dimensions, alpha/color rules, missing variants |

Image imports preserve the original source unless explicitly disabled. Transformations are deterministic and record tool/version, color space, resampling, crop, and compression. Generated placeholders must be visually obvious and reproducible.

## Audio

| Family | Build/edit coverage | Required view | Critical validation |
| --- | --- | --- | --- |
| Sounds | Import WAV/MP3/OGG and supported formats; name, volume, pitch, compression/streaming, preload, sample/bit rate, group assignment | Playable audio plus waveform, duration, channels, loudness and codec report | Decode success, clipping, silence, loop metadata, target codec compatibility, missing payload |
| Audio groups | Create/edit/assign/export behavior | Membership, duration and estimated package-size dashboard | Missing members, unsupported export target/settings |
| Audio effects/emitters | Effect chains, parameters, emitter spatial settings and routing | Signal-flow diagram and parameter table; optional rendered sample | Parameter ranges, cycles, missing buses/assets, target support |
| Sequence audio tracks | Sound binding, keyframes, trims, gain/pitch/effect tracks | Playable timeline mixdown where feasible | Bounds, missing sounds, invalid keyframe ranges |

Audio transformations record source hash, codec, sample rate, channels, loudness policy, encoder version, and whether the operation is lossless. Never overwrite the only source-quality file with a lossy derivative.

## Spatial content

| Family | Build/edit coverage | Required view | Critical validation |
| --- | --- | --- | --- |
| Paths | Kind, closed state, precision, ordered points and speeds; import/export common point formats | Scaled path plot with directions, point IDs and room overlay option | Invalid precision/speeds, empty/duplicate points, bounds |
| Rooms | Settings, physics, views/cameras, inheritance, creation code, instance order, persistent state | Layered room render plus hierarchy and settings summary | Unique IDs/names, inheritance cycles, creation-order parity, bounds and references |
| Instance layers/items | Instances, object references, transforms, color, image index/speed, creation code, overridden variables | Rendered bounds/icons and instance table | Missing objects, duplicate instance IDs, invalid property overrides |
| Tile layers | Dimensions, grid, packed tile data, transforms and tile-set binding | Rendered tile map with selectable index/grid overlays | Data dimensions, invalid tile indexes/flags, missing tile set |
| Background layers | Color/sprite, tiling/stretch, speeds, transforms | Rendered background | Missing sprite, invalid values |
| Asset layers | Sprites, sequences, particles and text with transforms/playback | Composite layer render and item table | Asset type/reference, item IDs, text/font validity |
| Path/effect layers | Path resources and effect/filter parameters | Path/effect overlay and parameter report | Missing path/effect, invalid parameter schema |
| Room UI/flex content | UI layers/containers/folders, flex panels/properties, text, sprites, sequences, particles, shapes and style groups | Responsive layout renders at configured viewport sizes, hierarchy and computed bounds | Parent cycles, constraints, IDs, style references, overflow and target support |

Room previews must support layer visibility toggles, camera/view selection, coordinate readout, dependency navigation, and deterministic thumbnails. When static rendering cannot match GameMaker, a purpose-built runtime capture fixture is required and labeled as such.

## Temporal and procedural content

The standalone `gmtool animation` authoring harness stores cutout rigs in versioned `.gmanim` archives and does not make a GameMaker resource family claim. Its editor and PNG/GIF paths have independent acceptance checks. YYMPS package export remains pending until all generated sprites, the runtime script, and demo resources pass the official ProjectTool round trip.

| Family | Build/edit coverage | Required view | Critical validation |
| --- | --- | --- | --- |
| Animation curves | Channels, keyframes, interpolation/tangents, iterations and named channels | Multi-channel curve plot with values/tangents | Time/value domains, ordering, duplicate points, interpolation fields |
| Sequences | Length, playback, speed, origin, nested group/parameter/resource tracks, keyframes, interpolation, moments/messages/events | Track tree, dope sheet/timeline, curve plots, frame thumbnails and optional runtime capture | Keyframe bounds/order, nested references/cycles, channel schemas, event/message payloads |
| Particle systems | Emitters, sprite/texture, shape/distribution, rate, lifetime, motion, color/alpha/scale curves, ordering | Parameter summary plus deterministic short animation/contact sheet | Invalid ranges, missing sprite, excessive counts/lifetimes, unsupported target fields |

Sequence coverage includes sprite, instance, audio, text, graphic, particle-system, nested-sequence, clip-mask, group, parameter/component, code, message/moment, boolean, real, color, string, transform, and effect tracks discovered for the target version.

## Dependency and content graph

The index must model typed edges, not string matching alone:

- project registration, folder, order, tags, config, texture group, and audio group;
- object parent/sprite/mask/collision/property references;
- room-to-object/sprite/tile-set/path/sequence/font/particle/shader references;
- sequence track/keyframe nesting and asset bindings;
- sprite-to-frame/layer/image and tile-set-to-sprite relationships;
- sound-to-audio-group and audio track/effect routing;
- prefab/package links and extension files;
- statically provable GML references, with ambiguous/dynamic references reported separately.

Every rename/delete plan shows inbound hard references, soft/dynamic references, generated code changes, binary impact, and which previews/tests will be invalidated.

## Preview artifact contract

`preview` writes a content-addressed directory outside the project:

```text
manifest.json        # tool/version, source hashes, freshness, diagnostics
summary.md           # concise agent/human description
resource.json        # normalized, stable semantic representation
dependencies.json    # typed inbound/outbound edges
preview.png|svg      # primary visual when applicable
preview.html         # interactive layers/timeline/layout when useful
preview.wav|ogg      # playable audio derivative when applicable
frames/              # contact sheets or bounded animation frames
runtime/             # optional captured logs/screenshots/video and exact build profile
```

The tool must never imply a synthetic preview is pixel- or sample-identical to GameMaker. Preview manifests label the renderer (`static`, `transcoded`, or `GameMaker runtime capture`) and its limitations.

## Schema and version strategy

- Start with the project's `IDEVersion`, resource versions, and the pinned `gm-cli`/ProjectTool versions.
- Harvest the official ProjectTool class inventory and classify every discovered type as resource, nested component, platform option, or internal metadata.
- Build schemas from minimal and complex resources created and saved by the matching GameMaker IDE, not from guesses or a single project.
- Preserve unknown keys and nested types losslessly. A new field does not become writable until fixtures establish its meaning and invariants.
- Differentially compare our result, a GameMaker IDE save, and a ResourceTool save. Semantic equality, byte churn, and added defaults are reported separately.
- Keep migrations explicit between version profiles; never auto-upgrade a working project during an unrelated edit.

## Robustness and security gates

- All mutations use plan/apply hashes, project locking, a write-ahead journal, sibling temporary files, atomic replacement, backup, rollback, and startup recovery.
- Validate identifiers, reserved names, Windows device names, case-only collisions, Unicode normalization, path length, and path traversal.
- Treat images, audio, fonts, archives, extensions, packages, and included files as untrusted. Enforce size/decompression limits and never execute imported extension code during inspection.
- Keep credentials and signing material outside recipes, logs, previews, fixtures, and project reports.
- Preserve media provenance and licensing notes; do not manufacture ownership claims.
- Bound preview time, memory, dimensions, frame count, audio duration, particle count, and runtime capture duration.
- Concurrency tests cover GameMaker IDE saves, file watchers, antivirus locks, interrupted writes, and simultaneous agents.
- Large-project tests establish budgets for indexing, incremental refresh, previews, dependency queries, and transactions.

## Completion gate

Maintain a generated table with rows for GameMaker version × resource family and columns for all twelve lifecycle capabilities. A cell links to its passing fixtures/tests and records limitations. “Full GameMaker support” may be claimed only when every discovered resource/nested type is classified, every matrix row is green, the kitchen-sink project opens and re-saves cleanly in the IDE, and compile plus configured runtime smoke tests pass.
# Workbench integration

Executable per-recipe version gates and family contracts now come from `src/gmtool/operation_registry.py`. `registry --markdown` exports them. The workbench implementation does not imply full lifecycle support for every resource family in the matrix below. Unsupported generic metadata mutation stays blocked. See WORKBENCH.md for verification evidence and limitations.
