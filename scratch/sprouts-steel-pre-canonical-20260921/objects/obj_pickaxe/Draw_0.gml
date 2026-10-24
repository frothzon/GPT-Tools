if(type != 0){
    var _angle = image_angle;
    image_angle += angle_offset * image_xscale;
    draw_self();
    image_angle = _angle;
}