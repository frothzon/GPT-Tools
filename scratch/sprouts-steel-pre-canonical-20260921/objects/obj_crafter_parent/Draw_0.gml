/// @description draw

draw_self();

if(stats.hp.get_val() < stats.hp.get_max()){
    var _ratio = stats.hp.get_percent();
    var _barWidth = 12;
    var _xmid = (bbox_left + bbox_right) * 0.5 - _barWidth*0.5;
    var _xbar = lerp(_xmid+1, _xmid + _barWidth-1, _ratio);
    var _ypos = bbox_bottom - 3;
    
    hp_trail = lerp(hp_trail, _ratio, 0.15);
    var _xbar_trail = lerp(_xmid+1, _xmid + _barWidth-1, hp_trail);

    draw_line_width_colour(_xmid,_ypos,_xmid+_barWidth,_ypos,5,c_dkgray,c_dkgray);
    draw_line_width_colour(_xmid+1,_ypos,_xbar_trail,_ypos,3,c_red, c_red);
    draw_line_width_colour(_xmid+1,_ypos,_xbar,_ypos,3,c_lime, c_lime);

}
