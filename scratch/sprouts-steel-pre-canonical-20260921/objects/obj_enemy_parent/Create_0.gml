// Inherit the parent event
event_inherited();

behavior = new StateMachine(id);

wander_behavior = {
    timer: 0,
    time_range: [1, 5],
    next_pos: new Vector2(),
    range: 100
};

range_padding = 8;
target_object = noone;
knockback_timer = 0;
knockback_push = true;
speed_multiplier = 1;

motion = new Vector2();


#region ======================= Creature States =======================

/// @desc step_towards(_dist, _dir);
step_towards = function(_dist, _dir, _stop=8){
    if(_dist > _stop){
        
        var _dx = lengthdir_x(stats.spd.get_val() * speed_multiplier, _dir);
        var _dy = lengthdir_y(stats.spd.get_val() * speed_multiplier, _dir);
        
        move_to(_dx, _dy);
    }
}

/// @desc sm_wander(_sm_)
/// @param _sm_ StateMachine
sm_wander = function(_sm_){
    
    wander_behavior.timer--;
    
    if(wander_behavior.timer <= 0){
        wander_behavior.next_pos.set(
            xstart + random_range(-1, 1) * wander_behavior.range,
            ystart + random_range(-1, 1) * wander_behavior.range
        );
        wander_behavior.timer = random_range(wander_behavior.time_range[0], wander_behavior.time_range[1]) * GAME_FPS;
    }
    
    var _dist = wander_behavior.next_pos.get_distance(x,y);
    var _dir = wander_behavior.next_pos.get_direction(x, y) + 180;
    
    speed_multiplier = wander_speed;
    
    step_towards(_dist, _dir);
    
    if(SCT.check_instance(target_object)){
        if(distance_to_object(target_object) <= chase_range){
            show_debug_message($"called {sm_chase} in {_sm_}");
            _sm_.change_state(sm_chase);
        }
    }
}

/// @desc sm_chase(_sm_)
/// @param _sm_ StateMachine
sm_chase = function(_sm_){
    if(SCT.check_instance(target_object)){
        var _dist = distance_to_object(target_object);
        if(_dist > chase_range + range_padding){
            _sm_.change_state(sm_wander);
            return;
        }
        if(_dist < attack_range){
            _sm_.change_state(sm_attack);
            return;
        }
        
        var _dir = point_direction(x,y,target_object.x, target_object.y);
        
        speed_multiplier = 1;
        
        step_towards(_dist, _dir, attack_range - range_padding);
        
        
    } else {
        _sm_.change_state(sm_wander);
    }
}

/// @desc sm_attack(_sm_)
/// @param _sm_ StateMachine
sm_attack = function(_sm_){
    if(SCT.check_instance(target_object)){
        var _dist = distance_to_object(target_object);
        if(_dist > attack_range + range_padding){
            _sm_.change_state(sm_chase);
        }
        
        /// perform attack
        if(_sm_.timer > GAME_FPS * attack_delay_sec){
            /// do damage
            //PLAYER_STATS.hp.damage(stats.atk.get_val());
            enemy_shoot_projectile(x, y, target_object.x, target_object.y, proj_delay_sec);
          
            /// reset timer
            _sm_.timer = 0;
        }
        
    } else {
        _sm_.change_state(sm_wander);
    }
}


behavior.change_state(sm_wander);

#endregion ============================================================

/// @desc sm_knockback()
sm_knockback = function(){
    
    if(knockback_timer <= 0){
        knockback_push = true;
        image_blend = c_white;
        return;
    }
    
    knockback_timer--;
    
    /// wait for knockback recovery
    image_blend = merge_colour(c_white, c_red, SCT.wave(0, 1, 0.25, 0));
    
    if(SCT.check_instance(target_object) && knockback_push){
        var _dist = distance_to_object(target_object);
        var _dir = point_direction(target_object.x, target_object.y,x,y);
        
        
        var _dx = lengthdir_x(8, _dir);
        var _dy = lengthdir_y(8, _dir);
        
        move_to(_dx, _dy, layer_tilemap_get_id("collisions"));
        
        knockback_push = false;
    }
}