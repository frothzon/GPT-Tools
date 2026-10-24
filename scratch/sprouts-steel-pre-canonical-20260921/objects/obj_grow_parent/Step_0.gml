/// @description Update

life++;
var _ratio = life / (grow_time * GAME_FPS);

image_index = min(image_number * _ratio, image_number-1);

if(_ratio >= 1){
    if(plant_target != noone){
        var _targ = instance_create_depth(x, y, 0, plant_target);
        _targ.image_index = image_index;
        _targ.image_speed = 0;
    }
    instance_destroy();
}
