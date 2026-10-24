/// @param x
/// @param y
/// @param string
/// @param c_outline
/// @param c_text
/// @param width
function draw_text_outline_width(xto, yto, str, c1=c_black, c2=c_white, width=1000){
    var font = draw_get_font();
    if(font != -1 && font_get_sdf_enabled(font)){
        /// set effect
        font_enable_effects(font, true, {
            outlineEnable: true,
            outlineDistance: 1,
            outlineColour: c1
        });
        
        draw_set_color(c2);
        draw_text_ext(xto,yto,str,-1,width);
        draw_set_color(c_white);
        
        /// clear effect
        font_enable_effects(font, false, {
            outlineEnable: true,
            outlineDistance: 1,
            outlineColour: c1
        });
    } else {
        draw_set_color(c1);
        draw_text_ext(xto+0.71,yto-0.71,str,-1,width);
        draw_text_ext(xto-0.71,yto-0.71,str,-1,width);
        draw_text_ext(xto,yto+1,str,-1,width);
        draw_set_color(c2);
        draw_text_ext(xto,yto,str,-1,width);
        draw_set_color(c_white);
    }
}
