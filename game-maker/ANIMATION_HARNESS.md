# Cutout Animation Harness

The animation harness is a local editor and exporter for layered cutout characters. It can open/create portable `.gmanim` projects, migrate supported Spriter SCML, import transparent PNG art, edit a bone/part timeline, and export preview frames plus a GameMaker `.yymps` asset package. The source is here in `src/gmtool/animation_harness`; it runs from this GameMaker tools installation and does not launch Spriter Pro.

## Install and start

Install the optional raster dependencies once:

```powershell
py -3 -m pip install -e 'C:\Agent Tools\game-maker\.[animation]'
```

Start a fresh project or open an existing one:

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' animation new
& 'C:\Agent Tools\game-maker\gmtool.ps1' animation open C:\art\characters.gmanim
```

These commands open an authenticated editor page on a loopback-only local server. Closing the process closes that session. Project data and PNG assets are stored inside the `.gmanim` archive; open and save use browser file transfer and do not write to source SCML or artwork.

To migrate SCML and open it for editing:

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' animation migrate C:\art\zombies.scml --output C:\art\zombies.gmanim
```

For a headless migration that does not start the editor:

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' animation migrate C:\art\zombies.scml --output C:\art\zombies.gmanim --headless
```

## Editor workflow

- **Add art** imports a single full-character PNG and creates starter `idle`, `walk`, `attack`, and `die` clips.
- **Part** imports an individual PNG attachment and asks which existing bone it should follow. Each animation receives a part track.
- **Bone** appends a child bone with neutral keys in each animation. Pick its parent and display length; then move/rotate the bone by selecting its track and editing keys.
- **Slice Part** shows the selected source attachment at its native image size. Drag a cut across the art. The harness produces two transparent PNG attachments with a rounded, overlapping cap and a pivoted hinge bone. Slicing is destructive to the selected attachment's timeline: save a copy first if you need to preserve the unsliced version.
- **Replace Art** swaps a part's source PNG in all its animation tracks and retains the current transforms. Character maps must be cleared before replacement because their file indices refer to existing attachments.
- Select a clip, track, and key to edit time, local X/Y, angle, scale, alpha, pivot, interpolation curve and controls, per-key image swaps, and sprite draw order. Time is milliseconds; coordinates are pixels; angles are degrees. The stage renders a transparent PNG preview.
- Add a key at the playhead, create clips, or add a named event with JSON payload at the current time. Event markers appear under the timeline.
- Character maps can be created in the inspector by adding source-to-replacement image entries. **Preview** toggles maps on the stage in stack order; deletion also clears that map from the preview stack.
- Play, pause, stop, scrub, or select 0.5× to 2× playback. The editor preview uses the same interpolation and component-transform model as the generated runtime.

PNG preview export writes each clip's frames and contact strip to a ZIP. GIF export writes one looping GIF per clip to a ZIP. These are offline previews, not captures from GameMaker's renderer.

## GameMaker YYMPS export

Provide a `.yyp` whose saved project metadata supplies the GameMaker version and resource profile:

```powershell
& 'C:\Agent Tools\game-maker\gmtool.ps1' animation export C:\art\zombies.gmanim `
  --format yymps --template-project 'C:\Projects\Example\Example.yyp' `
  --output C:\art\zombies.yymps
```

ProjectTool is discovered from `PROJECTTOOL`, a nearby `.gmcache/project-tool`, the tools cache, or the standard GameMaker package install. Set `--project-tool` if it is installed elsewhere. The exporter constructs an isolated temporary project, registers generated assets with ProjectTool, and exports the package. It does not edit the template project. Open/import the resulting `.yymps` with GameMaker's Local Asset Packages workflow.

Each package contains:

- a single `scr_scml_spriter_interface_system` GML script with the runtime and embedded animation definitions;
- all referenced, transparent sprite parts, in `SCML-custom/Imports/<collection>/Sprites` in the asset browser;
- a uniquely named demo object and room under `SCML-custom/Demo`;
- `Spriter_Interface_System.md` beside the script with the player API and integration examples.

The package-only project selects its demo room as the start room so it can be opened and run independently. Importing the local asset package does not change the destination project's start room. Generated sprite IDs are deterministic for the saved `.gmanim` project, and asset registration runs in a disposable receiver.

The generated script exposes `SpriterInterfaceSystem()` and keeps animation definitions and player state in GML structs. Use the guide in the package for playback, image overrides, character maps, pose queries, bone transforms, events, and runtime builders.

## File format and SCML support

`.gmanim` is a versioned ZIP archive. It contains `project.json` plus content-addressed RGBA PNG files. Save/load validates member paths and asset hashes. No parsing or disk access is needed during playback.

Migration currently handles SCML bone and sprite timelines, mainline references and ordering, image changes, pivots, alpha, spin, linear/instant/quadratic/cubic/quartic/quintic/Bézier curves, character maps, and event lines. Unsupported XML element types fail with an explicit message. Nested entities, meshes, sound playback, crossfades, collision shapes, and a Spriter-compatible visual authoring language are not implemented. The animation stage is an authoring/preview renderer, not a drop-in replacement for all Spriter Pro features.

Slicing supports one source file per selected part timeline. If an attachment changes images or a character map swaps it, split each image variant separately after clearing maps. Imported PNGs must have readable alpha; the harness does not automatically remove a white matte.

## Troubleshooting and current limits

- Install Pillow and NumPy with the optional `animation` extra if an image operation reports a missing dependency.
- If export cannot find ProjectTool, set the `PROJECTTOOL` environment variable to its executable or pass `--project-tool`.
- Choose a valid, saved `.yyp` with `MetaData.IDEVersion`; the exporter uses the template's version but packages only the generated animation resources.
- Resource names start with `spr_scmlsi_` and include a project-derived suffix. The runtime script name is fixed so the documented global factory remains stable; inspect destination-project script/function conflicts before importing if it already has another `SpriterInterfaceSystem()` implementation.
- The editor reports whether a local package was generated and checks that ProjectTool included every sprite, the runtime script, demo object, and demo room. A successful package export does not mean it has been imported into another project.

## Verification performed

The checked-in example project is [`examples/zombies.gmanim`](examples/zombies.gmanim), and its complete package is [`dist/zombies-animation-harness.yymps`](dist/zombies-animation-harness.yymps). The machine-readable results are in [`research/animation-harness-validation.json`](research/animation-harness-validation.json) and [`research/animation-harness-package-audit.json`](research/animation-harness-package-audit.json).

The current zombie SCML migrates to 15 entities, 60 animations, and 187 referenced sprite assets. The delivered YYMPS was unpacked as a package-only project, passed strict `gmtool validate`, compiled for Windows VM with GameMaker runtime 2024.14.4.268 / gm-cli 2.3.0, and ran the headless runtime assertions successfully. Playback was compared against approved poses at 1,020 sample times across all 60 animations (maximum transform error `2.025e-13`), and all 60 rendered comparisons passed. All 187 images retained their approved pixels and transparency; replacement sprite-origin fixtures also passed. The audit confirms 190 registered resources and preserves the template's GameMaker version metadata. The source SCML and template project remained unchanged.
