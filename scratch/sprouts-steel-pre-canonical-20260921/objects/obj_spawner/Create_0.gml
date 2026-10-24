/// @description setup

alarm[0] = irandom_range(spawn_wait[0], spawn_wait[1]) * GAME_FPS;

slice_size = 16;
world_slices = new Vector2(
    room_width div slice_size,
    room_height div slice_size
);
spawn_position = new Vector2(-100, -100);
total_space = (world_slices.x * world_slices.y) * 0.25;