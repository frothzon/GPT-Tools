/// @description setup

image_index = 0;
image_speed = 0;
image_blend = make_colour_rgb(230 + random(25), 230 + random(25), 230 + random(25));

/// check neighbors
recalculate_index = function(){
    
    image_index = 0;
    
    var _next = [
        {x: x+12, y: y},
        {x: x, y: y-12},
        {x: x-12, y: y},
        {x: x, y: y+12},
    ];
    
    
    for(var i = 0; i < 4; i++){
        var _pos = _next[i];
        var _targ = instance_place(_pos.x, _pos.y, obj_soil);
        if(SCT.check_instance(_targ)){
            var _mask = (1 << i);
            image_index |= _mask;
            _mask = ((_mask << 2) | (_mask >> 2)) & 15;
            _targ.image_index |= _mask;
        }
    }
}
recalculate_index();
alarm[1] = random_range(60, 600);
life = 1;
planted_object = noone;