# Spriter Interface System

This script contains the complete cutout animation runtime and every collection imported by **Spriter_GML_Interface.exe**. Rig definitions are structs. Players share definition data within their system and keep separate clocks, listeners, images, and local overrides. Treat definitions as immutable.

Definition data is embedded inside the script as normalized JSON and decoded into structs once on first entity lookup. There are no external runtime data files. Playback updates neither parse data nor access files. Call `describe_entity(collection, entity)` during loading if you want to preload that definition before spawning players. This representation avoids a GameMaker 2024.14 VM initialization failure caused by thousands of nested literal initializer functions in one script.

## Import and update

1. Save and close the target project in GameMaker.
2. Run the portable interface, select its `.yyp`, and select **New Import** or an existing collection.
3. Choose an SCML file. A new collection gets a permanent lowercase key, such as `zombies`.
4. Select **Analyze**. Review additions, replacements, removals, and detected manual edits.
5. Confirm the project is saved and closed, then **Apply**. Reopen it after completion.

The asset browser groups the system, imported sprites, and a unique demo under **SCML-custom**. The physical sprite/script locations follow GameMaker conventions. This guide sits beside the sole system script. Do not edit generated assets: an update replaces managed output. Unrelated assets are preserved.

Collections update independently. Cached normalized definitions under `.spriter-interface` let the tool retain collections whose original SCML files are temporarily unavailable. Select a new source file when updating a relocated collection. Keep this metadata with the project; it is not runtime Included Files. Restore interrupted updates through the GUI before applying another import. Recovery archives are outside the project in `%LOCALAPPDATA%/Spriter_GML_Interface/Backups`.

## Create, Step, and Draw

```gml
// Create event of a controller or character instance.
spriter_interface_system = SpriterInterfaceSystem();
if (!spriter_interface_system.create_player("zombie_1", "zombies", "dome-alone")) {
    show_debug_message("Could not create zombie_1: check the collection/entity names.");
}
spriter_interface_system.play("zombie_1", "walk");

// Step event. delta_time is microseconds; update takes seconds.
spriter_interface_system.update(delta_time / 1000000);

// Draw event. Positions are GameMaker room pixels.
spriter_interface_system.draw("zombie_1", x, y);
```

`SpriterInterfaceSystem()` is a factory that returns a struct; `new` is not required. Keep the returned struct in a variable accessible to the code controlling it. A central controller may own several named players; call its system's `update()` once per Step, then draw each player where needed. Separate systems are independent. No additional global runtime functions or object assets are needed.

```gml
spriter_interface_system.create_player("zombie_2", "zombies", "Grumble-Mulch");
spriter_interface_system.play("zombie_2", "idle");
spriter_interface_system.set_speed("zombie_1", 0.75);
// In Draw: each player can have a different position.
spriter_interface_system.draw("zombie_1", 200, 300);
spriter_interface_system.draw("zombie_2", 400, 300);
```

## Discovery and lifecycle

| Method | Result and failure behavior |
| --- | --- |
| `list_imports()` | Sorted collection keys. |
| `list_entities(collection)` | Original SCML names; empty array for an unknown collection. |
| `list_animations(collection, entity)` | Original animation names; empty array for an unknown entity. |
| `describe_entity(collection, entity)` | Shared definition struct, or `undefined`. Do not modify it. |
| `create_player(name, collection, entity)` | `true` when created; `false` for a duplicate player name or unknown definition. Never overwrites an existing player. |
| `remove_player(name)` | Removes playback/listener/override state; `false` if absent. |
| `get_player_state(name)` | Snapshot containing collection, entity, animation, time_ms, duration_ms, speed, and playing; `undefined` if absent. |
| `update(delta_seconds)` | Advances every current player once; returns the system. Players removed by callbacks are safely skipped. |

Methods below take the **player name as the first argument**. Control/drawing methods return `false` when the player is missing, otherwise `true` after applying the operation. Unknown clip/part/bone/map names are logged and ignored by the underlying runtime. Query methods return `undefined` when their target is unavailable.

## Playback

| Method | Meaning |
| --- | --- |
| `play(player, animation, restart=true, loop_override=undefined)` | Immediate clip change. Restart begins at zero for forward playback or at the duration for reverse playback. |
| `pause(player)` / `resume(player)` | Hold/continue the current clock. |
| `stop(player)` | Return to the initial pose and pause. |
| `set_speed(player, multiplier)` | Positive forward, negative reverse, zero holds time. |
| `seek(player, time_ms, emit_events=false)` | Seek in milliseconds; silent by default. Non-looping clips clamp, looping clips wrap. |
| `set_transform(player, x, y, angle=0, scale_x=1, scale_y=1, alpha=1)` | Root transform. Negative scales mirror the rig. |
| `draw(player, x, y)` | Draw active parts in authored order at room coordinates. |
| `set_bone_overlay(player, enabled)` | Toggle bone lines during drawing. |
| `draw_bones(player, x, y)` | Draw only the bone overlay. |

## Events and callback scope

```gml
// Bind to the controller instance if the callback uses instance variables.
footstep_count = 0;
footstep_listener = spriter_interface_system.on("zombie_1", "footstep",
    method(id, function(event_data) {
        footstep_count += 1;
        show_debug_message(event_data.animation);
    }));

spriter_interface_system.add_event("zombie_1", "walk", "footstep", 250, {side:"left"});
// Later, remove this listener:
spriter_interface_system.off("zombie_1", "footstep", footstep_listener);
```

GML methods do not capture the caller's local variables. Bind persistent state with `method(instance_or_struct, function...)`. Internal runtime methods are bound to their owners and do not rely on your variable scope.

- `on(player, event_name, callback)` returns a listener token, or `undefined` for an unknown player.
- `off(player, event_name, token)` returns whether the listener was removed.
- `add_event(player, animation, name, time_ms, payload=undefined)` adds an event to this player only.
- `add_key_event(player, animation, name, timeline_name, key_index, payload=undefined)` uses a zero-based timeline key index. Generated `key_ids` retain original SCML IDs.

Callbacks receive `name`, `animation`, `time_ms`, `cycle`, `direction`, `payload`, and `source`. SCML event-line names are preserved. Forward/reverse crossings, loop boundaries, and multiple loops per update each produce the appropriate events in traversal order. Time-zero events fire on explicit start and loop entries. Playback commands requested inside callbacks apply after the current batch.

## Images and character maps

`set_image(player, part_name, sprite_asset, subimage=0, pivot_override=undefined)` replaces one attachment. An optional `{x, y}` pivot uses normalized SCML coordinates, with Y measured from the bottom. Sprite dimensions and origins are respected. `clear_image(player, part)` removes one override; `clear_images(player)` removes all. A sprite value of `-1` hides the part.

`apply_character_map(player, map_name, reset=false)` applies a map; `remove_character_map(player, map_name)` removes it; `clear_character_maps(player)` removes all maps. Later maps take precedence. Explicit image overrides take precedence even over a map that hides the image. Default pivots follow mapped images; explicitly keyed pivots interpolate.

## Local transforms and attachments

Transforms contain `x`, `y`, `angle`, `scale_x`, `scale_y`, and `alpha`.

- `set_bone_transform(player, bone, transform)` replaces that bone's sampled local transform; children inherit it.
- `set_part_transform(player, part, transform)` adds position/angle offsets and multiplies scale/alpha. Optional `pivot_x` and `pivot_y` replace pivots.
- `clear_bone_transform(player, bone)`, `clear_part_transform(player, part)`, and `clear_transforms(player)` restore authored sampling.
- `get_bone_world(player, bone)` returns room-space position, angle, scales, and alpha.
- `get_part_world(player, part)` also returns image/pivot details; inactive parts return `undefined`.

Local SCML coordinates use upward Y. Drawing and world queries use downward room Y. Angles are counter-clockwise degrees. Spriter component transforms are preserved, including mirrored-parent rotation and nonuniform scales, without inherited affine shear.

## Construct rigs at runtime

```gml
var builder = spriter_interface_system.new_builder("practice");
builder.add_bone("root", undefined, 24);
builder.add_part("body", "root", spr_body, "spr_body", 0.5, 0.5, 0);
builder.add_animation("idle", 1000, true);
builder.add_key("idle", "bone", "root", 0,
    {x:0,y:0,angle:0,scale_x:1,scale_y:1,alpha:1});
builder.add_event("idle", "breath", 500, {kind:"loop"});
spriter_interface_system.register_definition("custom", builder.build());
spriter_interface_system.create_player("practice_1", "custom", "practice");
spriter_interface_system.play("practice_1", "idle");
```

Add parents before children. `add_key(animation, "bone"|"part", target, time_ms, transform, metadata=undefined)` accepts optional numeric `curve`, `spin`, and `c1` through `c4`. Curves: 0 instant, 1 linear, 2 quadratic, 3 cubic, 4 quartic, 5 quintic, 6 Bezier. Bezier controls are x1,y1,x2,y2. `build()` produces a reusable definition; later builder changes do not change it. Invalid authoring data raises a GameMaker error. Registering a name again affects newly created players, while existing players retain their definitions.

## Demo, support, and recovery

The unique demo room is appended after existing rooms. Open it in the Room Editor and run it as the starting room in a test copy, or place its unique controller in an existing test room. Controls: Tab changes collection; Left/Right entity; Up/Down animation; Space pauses; Q/E speed through zero; R reverse; A/D seek; B bones; I swaps an image.

Supported: bone/sprite cutouts, mainline attachment/order changes, file changes, pivots, alpha, spin, mirrored scales, all listed curves, character maps, and event lines. Unsupported features fail analysis before import. Meshes, nested entities, sound playback, crossfades, collision systems, and a visual rig editor are outside this version. No XML parsing or file access occurs in playback updates.

If application startup reports an interrupted transaction, use **Restore Interrupted Update**, reopen/review the project, and analyze again. The recovery ZIP contains every overwritten/deleted file. Updates never write the source SCML or source artwork.

Implementation references: [official SCML reference](https://www.brashmonkey.com/ScmlDocs/ScmlReference.html), [GML structs](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Overview/Structs.htm).
