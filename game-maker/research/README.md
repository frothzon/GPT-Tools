# Format research

Files in this directory are generated observations used to design version profiles. They are not schemas and must not be copied into projects.

`projecttool-resource-types.json` was produced by the `SHOWVERSIONEDTYPES` command from ProjectTool `2026.0.176`, installed in the local `gm-cli` cache on 2026-09-17. It contains 140 serialized class/version entries. Regenerate and diff it whenever the pinned `gm-cli`/ProjectTool changes.

The inventory proves that coverage must include nested types such as sequence tracks/keyframes, room UI/flex items, vector sprite shapes and fills, audio effects/emitters, platform options, and prefab metadata in addition to top-level Asset Browser resources.

`resourcetool-2026.0.22.md` records the top-level resource types and command families exposed through pinned `gm-cli` 2.3.0. It also records the observed save-on-query behavior that requires disposable-copy execution.
