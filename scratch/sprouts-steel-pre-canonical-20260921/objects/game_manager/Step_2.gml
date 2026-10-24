// Run the update logic to poll hardware every frame
INPUT_MGR.update();

target = instance_find(target_id, 0);

if(target >= 0 && instance_exists(target)){
    var _ww = eRES.WIDTH * 0.5;
    var _hh = eRES.HEIGHT * 0.5;
    
    position.x = lerp(position.x, target.x - _ww, lerp_ratio);
    position.y = lerp(position.y, target.y - _hh, lerp_ratio);
    
    if(shake_timer > 0){
        shake_timer--;
        shake.x = random_range(-shake_mag, shake_mag);
        shake.y = random_range(-shake_mag, shake_mag);
    } else {
        shake.x = 0;
        shake.y = 0;
    }
    
    var _px = round(position.x * eRES.SCALE) / eRES.SCALE + shake.x;
    var _py = round(position.y * eRES.SCALE) / eRES.SCALE + shake.y;
    
    camera_set_view_pos(view_camera[0], _px, _py);
}

with(obj_sortable){
    depth = -y;
}

BLASTER.update();
TOOLTIP.update();