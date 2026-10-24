/**
* @function Slider
* @brief A UI slider class for range-based input and volume/setting controls.
* @param {real} _x Starting X position.
* @param {real} _y Starting Y position.
* @param {real} _w Width of the slider track.
* @param {real} _min Minimum value.
* @param {real} _max Maximum value.
* @param {real} _initial Initial value.
* @param {function} _callback Function to execute when value changes.
*/
function HorizontalSlider(_x, _y, _w, _min, _max, _initial, _callback) constructor {
    self.x = _x;
    self.y = _y;
    self.w = _w;
    self.h = 12; // Height of the track area
    self.min_val = _min;
    self.max_val = _max;
    self.value = _initial;
    self.callback = _callback;

    // Visual Properties
    self.handle_w = 12;
    self.handle_h = 20;
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

    /**
    * @function update
    * @brief Handles mouse logic for dragging the slider handle.
    */
    static update = function() {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        
        // 1. Check Hover (Track area + handle buffer)
        self.hovered = point_in_rectangle(_mx, _my, self.x - self.handle_w, self.y - self.handle_h/2, self.x + self.w + self.handle_w, self.y + self.handle_h/2);
        
        // 2. Interaction Logic
        if ((mouse_check_button_pressed(mb_left) || INPUT_MGR.check_pressed("action")) && self.hovered) {
            self.is_dragging = true;
        }
        
        if (self.is_dragging) {
            if (mouse_check_button(mb_left) || INPUT_MGR.check("action")) {
                // Calculate percentage based on mouse X relative to track
                var _rel_x = clamp(_mx - self.x, 0, self.w);
                var _percent = _rel_x / self.w;
                
                // Update Value
                var _old_val = self.value;
                self.value = self.min_val + (self.max_val - self.min_val) * _percent;
                
                // Fire callback if value changed
                if (_old_val != self.value && is_callable(self.callback)) {
                    self.callback(self.value);
                }
            } else {
                self.is_dragging = false;
            }
        }
    };

    /**
    * @function draw
    * @brief Renders the track and the draggable handle.
    */
    static draw = function() {
        var _percent = (self.value - self.min_val) / (self.max_val - self.min_val);
        var _handle_x = self.x + (self.w * _percent);
        
        // 1. Draw Track Background
        draw_sprite_stretched_ext(self.track_sprite, 0, self.x, self.y - self.h/2, self.w, self.h, self.colors.track, 1);
        
        // 2. Draw Fill (Progress)
        draw_sprite_stretched_ext(self.track_sprite, 0, self.x, self.y - self.h/2, self.w * _percent, self.h, self.colors.fill, 1);
        
        // 3. Draw Handle
        var _h_col = (self.is_dragging || self.hovered) ? self.colors.handle_hover : self.colors.handle;
        var _h_img = self.is_dragging ? 2 : (self.hovered ? 1 : 0);
        
        draw_sprite_stretched_ext(self.handle_sprite, _h_img, _handle_x - self.handle_w/2, self.y - self.handle_h/2, self.handle_w, self.handle_h, _h_col, 1);
        
        // 4. Draw Value Label (Optional)
        draw_set_halign(fa_center);
        draw_text_outline(_handle_x, self.y - self.handle_h - 4, string(round(self.value)), c_black, _h_col);
        SCT.draw_reset();
    };
    
    /**
    * @function set_value
    * @brief Manually sets the slider value.
    */
    static set_value = function(_val) {
        self.value = clamp(_val, self.min_val, self.max_val);
    };
}