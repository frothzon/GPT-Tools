/// @description start over

alarm[0] = irandom_range(spawn_wait[0], spawn_wait[1]) * GAME_FPS;
var attempts = 100;
var found = false;

if(instance_number(obj_breakable) >= total_space){
    exit;
}

do {
    var _xto = irandom(world_slices.x) * slice_size + 8;
    var _yto = irandom(world_slices.x) * slice_size + 8;
    
    if(collision_circle(_xto, _yto, 12, [obj_player, obj_solid_parent], false, true) == noone){
        attempts = 0;
        spawn_position.x = _xto;
        spawn_position.y = _yto;
        found = true;
    }
} until (attempts-- <= 0);

if(found){
    var _type = SCT.random_weighted(spawn_weights);
    var _obj = spawn_objs[_type];
    
    instance_create_depth(spawn_position.x, spawn_position.y, 0, _obj);
    
    show_debug_message($"Spawning {object_get_name(_obj.object_index)} at {spawn_position.x}, {spawn_position.y}"); 
}
