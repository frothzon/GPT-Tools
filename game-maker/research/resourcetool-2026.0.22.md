# ResourceTool 2026.0.22 observations

Observed through pinned `@gamemaker/gm-cli` 2.3.0 on 2026-09-17, using a disposable copy of `Simple3D`. ResourceTool saves/normalizes the loaded project even for `HELP` and `RESOURCE TYPES`, so these commands must never be treated as filesystem-read-only.

## Reported top-level resource types

`RESOURCE TYPES` reported 17 types:

- `animcurve`
- `audiogroup`
- `font`
- `includedfile`
- `notes`
- `object`
- `particlesystem`
- `path`
- `room`
- `script`
- `shader`
- `shape`
- `sound`
- `sprite`
- `texturegroup`
- `tileset`
- `timeline`

This list is ResourceTool's currently exposed generic-create set, not GameMaker's complete asset inventory. Sequences, extensions, nested room/sequence/UI types, project/options metadata, configurations, folders, packages, and prefabs still need explicit coverage even when absent from this list.

## Command families observed

- Generic resources: `RESOURCE LIST|TYPES|INFO|SET|CREATE|DELETE`
- Projects: `PROJECT CREATE|RENAME`
- Objects: event list/types/find-or-create/delete/change/set-GML-file
- Rooms: instance and asset creation; item list/delete; layer create/delete/list; tile get/set/list/resize/info
- GML scripts: set GML file
- Sprites: add/delete frame
- Sounds: set audio file
- Tile sets: create/delete/rename/set sprite
- Configurations: list/usages/create/delete/rename/get-active/set-active
- Audio groups: create/delete/rename/list/usages/set
- Texture groups: create/delete/rename/list/usages/set
- Prefabs: list/info/add-reference/remove-reference/customise
- Shaders: set vertex/fragment file
- Notes: set note file
- Paths: add/info/delete points
- Fonts: range, kerning, glyph inspection/editing and set TTF file
- Folders: list/create
- Options: list/get/info/set for supported platform properties

## Integration consequence

Use these commands as an official semantic oracle on disposable copies. For a real project mutation, compare the clone before/after, isolate the intended semantic delta, and either apply an equivalent minimal lossless transaction or present the entire normalization diff for explicit approval. Do not shell directly to the bundled ResourceTool executable as a product dependency; invoke it through pinned `gm-cli`.

The implemented `gmtool resource-tool` bridge now enforces this: it copies the project, runs pinned `gm-cli`, hashes both trees, reports the disposable diff and any forbidden original-project change, and applies the official diff only with explicit `--apply` through a write-ahead multi-file transaction.
