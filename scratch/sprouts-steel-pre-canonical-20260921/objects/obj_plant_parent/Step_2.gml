/// @description update

if(!stats.update_status()){
    if(array_length(drop_weights) > 0){
        repeat(drop_count){
            var _choice = SCT.random_weighted(drop_weights);
            if(_choice >= 0){
                var _drop = instance_create_depth(x,y,0,obj_item);
                var _type = drop_items[_choice];
                _drop.type = _type;
                _drop.amount = DROP_MULT;
                _drop.sprite_index = ITEMS[_type].sprite;
                _drop.image_index = ITEMS[_type].index;
                _drop.image_speed = 0;
            }
        }
    }
    instance_destroy();
}

if(hurt_timer == 0) {
    scaling.x = lerp(scaling.x, 1, 0.2);
    scaling.y = lerp(scaling.y, 1, 0.2);
} else {
    scaling.x = SCT.warp(1.15, 0.85, hurt_timer * 0.1);
    scaling.y = SCT.warp(0.85, 1.15, hurt_timer * 0.1);
    hurt_timer--;
}

pos.update();

/// restore position
if(max_speed == 0){
    x = lerp(x, xstart, 0.5);
    y = lerp(y, ystart, 0.5);
}
