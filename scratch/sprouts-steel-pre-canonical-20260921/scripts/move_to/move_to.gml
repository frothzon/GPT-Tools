/// @desc move_to(_dx, _dy);
function move_to(_dx, _dy, _collidables=[layer_tilemap_get_id("collisions"), obj_solid_parent]){

    var _tx = _dx;
    var _ty = _dy;
    
    var _hitX = instance_position(x + _tx, y, obj_interact_parent);
    var _hitY = instance_position(x, y + _ty, obj_interact_parent);

    
    /// stop x movement
    if(SCT.check_instance(_hitX)){
        if(_hitX.zpos.z <= 8){
            _tx = 0;
        }
    }
    
    /// stop y movement
    if(SCT.check_instance(_hitY)){
        if(_hitY.zpos.z <= 8){
            _ty = 0;
        }
    }
    
    //show_debug_message($"can move to {_tx},{_ty}");
    
    move_and_collide(_tx, _ty, _collidables);
}