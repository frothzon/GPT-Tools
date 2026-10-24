if(tool.type == eITEM_TYPE.TOOL_HOE){
    //draw_text(x, y, $"pos = {tool.target.x},{tool.target.y}");
    draw_sprite_ext(spr_soil_auto, 0, tool.target.x, tool.target.y, 1, 1, 0, tool.info ? c_white : c_red, tool.info ? 0.75 : 0.25);
} else if(tool.type == eITEM_TYPE.SEED){
    var _sprite = tool.xref.sprite;
    var _ind = tool.xref.index;
    if(SCT.check_instance(tool.info)){
        if(!SCT.check_instance(tool.info.planted_object))
        {
            var _obj = tool.info;
            draw_sprite_ext(_sprite, _ind, _obj.x, _obj.y, 1, 1, 0, c_black, 0.5);
            draw_sprite_ext(_sprite, _ind, _obj.x, _obj.y - SCT.wave(4, 8, 1, 0), 1, 1, 0, c_white, 0.75);
        }
        
    }
    
} else if(tool.type == eITEM_TYPE.STRUCTURE){
    var _sprite = tool.xref.sprite;
    var _ind = tool.xref.index;
    draw_sprite_ext(_sprite, _ind, tool.target.x, tool.target.y, 1, 1, 0, c_black, 0.5);
}

draw_sprite_ext(sprite_index, image_index, x, y, flip_image ? -image_xscale : image_xscale, image_yscale, image_angle, c_white, image_alpha);
draw_sprite_ext(clothes_index, image_index, x, y, flip_image ? -image_xscale : image_xscale, image_yscale, image_angle, clothes_color, image_alpha);