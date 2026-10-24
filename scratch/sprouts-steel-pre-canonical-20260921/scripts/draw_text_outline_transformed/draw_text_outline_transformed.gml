/**
 * @function draw_text_outline_transformed
 * @desc Draws a string with an outline, supporting scaling, rotation, and alpha.
 * @param {real} _x X position
 * @param {real} _y Y position
 * @param {string} _str The string to draw
 * @param {color} [_c1=c_black] Outline color
 * @param {color} [_c2=c_white] Text color
 * @param {real} [_alpha=1] Transparency (0-1)
 * @param {real} [_sx=1] Horizontal scale
 * @param {real} [_sy=1] Vertical scale
 * @param {real} [_angle=0] Rotation angle
 * @param {real} [_w=1] Outline thickness
 */
function draw_text_outline_transformed(_x, _y, _str, _c1=c_black, _c2=c_white, _alpha=1, _sx=1, _sy=1, _angle=0, _w=1) {
    var _font = draw_get_font();
    
    // --- Modern SDF Font Logic ---
    if (_font != -1 && font_get_sdf_enabled(_font)) {
        // Enable SDF effects for the outline
        font_enable_effects(_font, true, {
            outlineEnable: true,
            outlineDistance: _w,
            outlineColour: _c1,
            outlineAlpha: _alpha
        });
        
        // Draw the transformed text
        draw_text_transformed_color(_x, _y, _str, _sx, _sy, _angle, _c2, _c2, _c2, _c2, _alpha);
        
        // Disable effects to prevent bleeding into other draw calls
        font_enable_effects(_font, false);
    } 
    // --- Legacy / Standard Font Logic ---
    else {
        // Manual outline drawing via 4-way offsetting
        // We use draw_text_transformed_color for every pass to respect scale/angle/alpha
        draw_text_transformed_color(_x + _w, _y, _str, _sx, _sy, _angle, _c1, _c1, _c1, _c1, _alpha);
        draw_text_transformed_color(_x - _w, _y, _str, _sx, _sy, _angle, _c1, _c1, _c1, _c1, _alpha);
        draw_text_transformed_color(_x, _y + _w, _str, _sx, _sy, _angle, _c1, _c1, _c1, _c1, _alpha);
        draw_text_transformed_color(_x, _y - _w, _str, _sx, _sy, _angle, _c1, _c1, _c1, _c1, _alpha);
        
        // Draw the main text on top
        draw_text_transformed_color(_x, _y, _str, _sx, _sy, _angle, _c2, _c2, _c2, _c2, _alpha);
    }
    
    // Reset draw color and alpha to be safe
    draw_set_color(c_white);
    draw_set_alpha(1);
}