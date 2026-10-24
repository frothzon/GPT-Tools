
#region ================================== Movement and Animation ====================================
var _right = INPUT_MGR.check("right");
var _left = INPUT_MGR.check("left");
var _up = INPUT_MGR.check("up");
var _down = INPUT_MGR.check("down");

if(is_struct(crafting_menu.show)){
    exit;
}

motion.from_input(_right, _up, _left, _down);

var _len = motion.length();

if(_len > 1){
    motion.normalize();
}

if(_len == 0){
    sprite_index = animations[0];
    clothes_index = clothes[0];
} else {
    sprite_index = animations[1];
    clothes_index = clothes[1];
}

if(motion.x < 0){
    flip_image = 1;
}
if(motion.x > 0){
    flip_image = 0;
}

var _dx = motion.x * PLAYER_STATS.spd.get_val();
var _dy = motion.y * PLAYER_STATS.spd.get_val();

move_to(_dx, _dy);


#endregion =============================================================================================


#region ===================================== Targeting ================================================
var _dist = clamp(point_distance(x,y,mouse_x,mouse_y), 4, target.range);
var _dir = point_direction(x,y,mouse_x,mouse_y);
if(gamepad_is_connected(0)){
    _dist = 12;
    if(motion.length() == 0){
        _dir = target.angle;
    } else {
        _dir = motion.angle();
    }
    
}
target.angle = _dir;
target.x = x + lengthdir_x(_dist, _dir);
target.y = y + lengthdir_y(_dist, _dir) - 3;
target.obj = noone;
if(tool.obj.type == eITEM_TYPE.WEAPON){
    var _selection = collision_circle(target.x, target.y, target.radius, obj_breakable, false, true);
    if(_selection == noone){
        _selection = collision_circle(target.x, target.y, target.radius, obj_crafter_parent, false, true);
        
        /// select other objects with stats if possible
        if(SCT.check_instance(_selection)){
            if(!variable_struct_exists(_selection, "stats")){
                _selection = noone;
            }
        }
    }
    target.obj = _selection;
}
#endregion =============================================================================================

player_change_weapon();