if(SCT.check_instance(target.obj)){
    var _padding = SCT.wave(0, 8, 1, 0);
    var _ww = max(target.obj.bbox_right - target.obj.bbox_left, 13) + _padding;
    var _hh = max(target.obj.bbox_bottom - target.obj.bbox_top, 13) + _padding;
    var _xx = target.obj.x - _ww/2;
    var _yy = target.obj.y - _hh/2;
    draw_sprite_stretched(spr_Selector, 0, _xx, _yy, _ww, _hh);
} else {
    draw_sprite_ext(spr_pointer, 0, target.x, target.y, 1, 1, 0, c_white, 0.25);
}

var _hasGP = gamepad_is_connected(0);
var _buttonText = _hasGP ? "A" : "E";
var _targ = noone;
if(!is_struct(crafting_menu.show) && SCT.check_instance(crafting_menu.target)){
    _targ = crafting_menu.target;
    var _xx = (_targ.bbox_right + _targ.bbox_left) * 0.5;
    draw_set_halign(fa_center);
    draw_text_outline(_xx, _targ.bbox_bottom - _targ.sprite_height + SCT.wave(-4, -8, 2, 0), _buttonText, c_black, c_lime);
    draw_set_halign(fa_left);
}

_targ = interact_obj.targ;
if(!interact_obj.held && SCT.check_instance(_targ)){
    if(_targ.zpos.onGround()){
        var _xx = (_targ.bbox_right + _targ.bbox_left) * 0.5;
        draw_set_halign(fa_center);
        draw_text_outline(_xx, _targ.bbox_top - 8, _buttonText, c_black, c_lime);
        draw_set_halign(fa_left);
    }
}