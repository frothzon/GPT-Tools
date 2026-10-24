/**
 * @function VerticalSlider
 * @brief A UI slider class for vertical range-based input.
 * @param {real} _x Starting X position (Center of track).
 * @param {real} _y Starting Y position (Top of track).
 * @param {real} _h Height of the slider track.
 * @param {real} _min Minimum value (At the bottom).
 * @param {real} _max Maximum value (At the top).
 * @param {real} _initial Initial value.
 * @param {function} _callback Function to execute when value changes.
 */
function VerticalSlider(_x, _y, _h, _min, _max, _initial, _callback) constructor {
    self.x = _x;
    self.y = _y;
    self.h = _h;
    self.w = 12; // Width of the track area
    self.min_val = _min;
    self.max_val = _max;
    self.value = _initial;
    self.callback = _callback;

    // Visual Properties
    self.handle_w = 20;
    self.handle_h = 12;
    self.track_sprite = spr_invBox;  
    self.handle_sprite = spr_invBox; 
    
    // State Management
    self.is_dragging = false;
    self.hovered = false;
    
    // Design Tokens
    self.colors = {
        track: c_dkgray,
        fill: c_lime,
        handle: c_white,
        handle_hover: c_yellow
    };

    static update = function() {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        
        self.hovered = point_in_rectangle(
            _mx, _my, 
            self.x - self.handle_w / 2, 
            self.y - self.handle_h, 
            self.x + self.handle_w / 2, 
            self.y + self.h + self.handle_h
        );
        
        if ((mouse_check_button_pressed(mb_left) || INPUT_MGR.check_pressed("action")) && self.hovered) {
            self.is_dragging = true;
        }
        
        if (self.is_dragging) {
            if (mouse_check_button(mb_left) || INPUT_MGR.check("action")) {
                var _rel_y = clamp(_my - self.y, 0, self.h);
                var _percent = 1 - (_rel_y / self.h);
                
                var _old_val = self.value;
                self.value = self.min_val + (self.max_val - self.min_val) * _percent;
                
                if (_old_val != self.value && is_callable(self.callback)) {
                    self.callback(self.value);
                }
            } else {
                self.is_dragging = false;
            }
        }
    };

    static draw = function() {
        var _percent = (self.value - self.min_val) / (self.max_val - self.min_val);
        var _handle_y = self.y + (self.h * (1 - _percent));
        
        draw_sprite_stretched_ext(self.track_sprite, 0, self.x - self.w / 2, self.y, self.w, self.h, self.colors.track, 1);
        
        var _fill_h = self.h * _percent;
        draw_sprite_stretched_ext(self.track_sprite, 0, self.x - self.w / 2, self.y + (self.h - _fill_h), self.w, _fill_h, self.colors.fill, 1);
        
        var _h_col = (self.is_dragging || self.hovered) ? self.colors.handle_hover : self.colors.handle;
        var _h_img = self.is_dragging ? 2 : (self.hovered ? 1 : 0);
        
        draw_sprite_stretched_ext(self.handle_sprite, _h_img, self.x - self.handle_w / 2, _handle_y - self.handle_h / 2, self.handle_w, self.handle_h, _h_col, 1);
    };
    
    static set_value = function(_val) {
        self.value = clamp(_val, self.min_val, self.max_val);
    };
}