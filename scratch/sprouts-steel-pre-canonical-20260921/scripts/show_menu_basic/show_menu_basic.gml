/// @brief Displays a menu at a given position with selectable options.
/// @param button_sprite The sprite used for the menu background or button.
/// @param xdraw The x-coordinate to start drawing the menu.
/// @param ydraw The y-coordinate to start drawing the menu.
/// @param string_array An array of strings representing menu options.
/// @param selection the index that is currently selected
/// @return The index of the selected menu option, or -1 if none is selected.
function show_menu_basic(button_sprite, xdraw, ydraw, string_array, selection) {
    /// Padding around the text for menu items.
    var padding = 8;
    /// Width of the widest menu item.
    var max_width = 64;
    /// Array to store the heights of each menu item.
    var item_heights = [];
    /// Output index for the selected menu item, defaults to -1.
    var selected_index = selection;
    
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);

    // Calculate dimensions for each menu item.
    for (var i = 0; i < array_length(string_array); i++) {
        item_heights[i] = string_height(string_array[i]) + padding;
        max_width = max(max_width, string_width(string_array[i]) + padding);
    }

    // Draw menu and handle mouse interactions.
    for (var i = 0; i < array_length(string_array); i++) {
        var x_start = xdraw - max_width/2;
        var x_end = xdraw + max_width/2;
        var y_start = ydraw;
        var y_end = ydraw + item_heights[i] - 1;
        var text_x = (x_start + x_end) * 0.5;
        var text_y = (y_start + y_end) * 0.5;

        var is_hovered = (i == selected_index);
        // Set color
        var _color = is_hovered ? c_lime : c_white;

        // Draw menu background.
        draw_sprite_stretched_ext(button_sprite, is_hovered, x_start, y_start, max_width, item_heights[i], _color, 1);

        // Draw menu text.
        draw_text_outline(text_x, text_y, string_array[i], c_black, _color);
        
        // draw icon
        if(is_hovered){
            Textbox.__daw_input_icons(text_x + string_width(string_array[i])/2, text_y-16, 32, 32, spr_action_keys, 1, spr_gamepad_keys, 0);
        }

        // Update y-coordinate for the next item.
        ydraw += item_heights[i];
    }

    // Reset text alignment to default.
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    return selected_index;
}
