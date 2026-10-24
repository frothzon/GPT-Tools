var _ratio = timer / timer_max;
timer++;

x = tween(start_pos.x, end_pos.x, _ratio);
y = tween(start_pos.y, end_pos.y, _ratio);

/// simulated arc using sinosoidal wave
z_pos = tween(z_pos_range[0], z_pos_range[1], sin(_ratio * pi));

if(timer > timer_max){
    var _hit = instance_place(x, y, target_index);
    
    if(SCT.check_instance(_hit)){
        /// do damage to player
        PLAYER_STATS.hp.damage(stats.atk.get_val());
    }
    instance_destroy();
}