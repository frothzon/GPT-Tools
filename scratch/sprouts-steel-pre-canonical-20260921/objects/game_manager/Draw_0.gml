with(obj_sortable){
    var _blend = image_blend;
    var _alpha = image_alpha;
    var _scale = image_yscale;
    var _y = y;
    

    image_blend = c_black;
    image_alpha = 0.5;
    image_yscale = 0.6;
    y += 1;
    
    draw_self();
    
    image_blend = _blend;
    image_alpha = _alpha;
    image_yscale = _scale;
    y = _y;

}