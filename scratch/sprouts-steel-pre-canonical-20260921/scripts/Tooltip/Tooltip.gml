/// @brief Tooltip system for displaying temporary messages on the screen.
/// This function acts as a constructor for creating and managing tooltip items.
/// Tooltips display messages with optional images and text colors.
function Tooltip(_image = spr_panel1) constructor {
    /// @var self.items
    /// Array of tooltip items, where each item contains a string, image, time, and color.
    self.items = [];
    
    /// @var self.time_displayed
    /// Time duration (in steps) each tooltip is displayed on the screen.
    self.time_displayed = game_get_speed(gamespeed_fps) * 2;
    
    /// @var self.image
    /// The sprite used as the background for tooltip messages.
    self.image = _image;
    
    self.min_size = 32;
    self.padding = 4;
    self.bottom_offset = 64;
    
    /// @brief Adds a new tooltip to the system.
    /// @param _string The text to display in the tooltip.
    /// @param _image The sprite to display alongside the text.
    /// @param _textColor The color of the tooltip text.
    static add = function(_string, _image, _textColor) {
        /// @var _item
        /// A single tooltip item containing its string, image, time, and color.
        var _item = {str: _string, img: _image, time: 0, col: _textColor};
        array_push(self.items, _item);
    };
    
    /// @brief Updates the tooltip system, removing items when their display time elapses.
    static update = function() {
        for (var i = array_length(self.items) - 1; i >= 0; i--) {
            /// @var _item The current tooltip item being processed.
            var _item = self.items[i];
            _item.time++;
            if (_item.time >= self.time_displayed) {
                array_delete(self.items, i, 1);
            }
        }
    };
    
    /// @brief Draws all active tooltips on the screen.
    static draw = function() {
        /// @var _yy Vertical position for drawing tooltips, starting near the bottom of the GUI.
        var _yy = display_get_gui_height() - self.padding * 2 - self.min_size - self.bottom_offset;
        var _count = array_length(self.items);
        
        for (var i = _count-1; i > -1; i--) {
            /// @var _item The current tooltip item being drawn.
            var _item = self.items[i];
            /// @var _ww Width of the tooltip background, determined by the string width.
            var _ww = string_width(_item.str) + self.min_size + self.padding;
            /// @var _hh Height of the tooltip background, capped at 32 pixels.
            var _hh = max(self.min_size , string_height(_item.str));
            /// @var _xx Horizontal position for drawing the tooltip, starting from the right edge of the GUI.
            var _xx = display_get_gui_width() - _ww - self.padding * 2;
            /// @var _color Color of the tooltip text.
            var _color = _item.col;
            
            /// Draw the tooltip background.
            var p2 = self.padding * 2;
            draw_sprite_stretched(self.image, 0, _xx-self.padding, _yy-self.padding, _ww+p2, _hh+p2);
            /// Draw the tooltip image.
            draw_sprite_stretched(_item.img, 0, _xx, _yy, self.min_size , self.min_size );
            /// Set text alignment for the tooltip text.
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            /// Draw the tooltip text with an outline for better visibility.
            draw_text_outline(_xx + self.min_size + 2, _yy + _hh / 2, _item.str, c_black, _color, 2);
            /// Adjust the vertical position for the next tooltip.
            _yy -= _hh * 1.25 + self.padding * 2;
        }
    };
}