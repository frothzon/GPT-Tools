/// @desc enemy_shoot_projectile(_x1,_y1,_x2,_y2);
function enemy_shoot_projectile(_x1,_y1,_x2,_y2,_time){
    var _proj = instance_create_depth(_x1, _y1, -1000, obj_proj);
    _proj.start_pos.set(_x1, _y1);
    _proj.end_pos.set(_x2, _y2);
    _proj.stats = variable_clone(stats);
    _proj.timer_max = _time * GAME_FPS;
}