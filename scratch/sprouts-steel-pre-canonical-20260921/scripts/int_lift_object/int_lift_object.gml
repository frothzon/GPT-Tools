function int_lift_object(_targ){
    if(cooldown >= 0){
        var _ratio = 0.5;
        cooldown--;
        zpos.z = lerp(zpos.z, 16, _ratio);
        if(zpos.z >= 15){
            x = lerp(x, _targ.target.x, _ratio);
            y = lerp(y, _targ.target.y, _ratio);
        }
    } else {
        zpos.z = 16;
        x = _targ.target.x;
        y = _targ.target.y;
    }
}