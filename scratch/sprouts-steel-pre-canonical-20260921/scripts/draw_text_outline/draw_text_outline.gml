/// @desc draw_text_outline(xto, yto, str, c1=c_black, c2=c_white, w_outline=1)
/// @param x
/// @param y
/// @param string
/// @param c_outline
/// @param c_text
function draw_text_outline(xto, yto, str, c1=c_black, c2=c_white, w_outline=1){
    var font = draw_get_font();
    if(font != -1 && font_get_sdf_enabled(font)){
        /// set effect
        font_enable_effects(font, true, {
            outlineEnable: true,
            outlineDistance: w_outline,
            outlineColour: c1
        });
        
        draw_set_color(c2);
        draw_text(xto,yto,str);
        draw_set_color(c_white);
        
        /// clear effect
        font_enable_effects(font, false, {
            outlineEnable: true,
            outlineDistance: w_outline,
            outlineColour: c1
        });
    } else {
        draw_set_color(c1);
        draw_text(xto+0.71,yto-0.71,str);
        draw_text(xto-0.71,yto-0.71,str);
        draw_text(xto,yto+1,str);
        draw_set_color(c2);
        draw_text(xto,yto,str);
        draw_set_color(c_white);
    }
}
