/**
 * @function Button
 * @brief A versatile UI button class for handling interaction and callbacks.
 * @param {real} _x Top-left X position.
 * @param {real} _y Top-left Y position.
 * @param {real} _w Width of the button.
 * @param {real} _h Height of the button.
 * @param {string} _text The label to display.
 * @param {function} _callback The function to execute when clicked.
 * @param {any} _data Optional data to pass back to the callback.
 */
function Button(_x, _y, _w, _h, _text, _callback, _data = undefined) constructor {
    self.x = _x;
    self.y = _y;
    self.w = _w;
    self.h = _h;
    self.text = _text;
    self.callback = _callback;
    self.data = _data; 

    // Visual Properties
    self.sprite = spr_invBox;
    self.font = -1;
    self.enabled = true;
    
    // State Management
    self.hovered = false;
    self.pressed = false;
    
    // Juicy Animation & Delay State
    self.tween_timer = 0;
    self.tween_duration = 15;
    self.delay_timer = 0;
    self.click_pending = false;
    
    // Design Tokens
    self.colors = {
        idle: c_white,
        hover: c_lime,
        click: c_yellow,
        disabled: c_dkgray,
        text_idle: c_white,
        text_hover: c_lime
    };

    /**
     * @function update
     * @brief Handles mouse logic and triggers the delayed callback.
     */
    static update = function() {
        if (!self.enabled) {
            self.hovered = false;
            self.pressed = false;
            return;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        
        if (self.click_pending) {
            if (--self.delay_timer <= 0) {
                if (is_callable(self.callback)) {
                    self.callback(self.data);
                }
                self.click_pending = false;
            }
        }
        
        if (self.tween_timer > 0) self.tween_timer--;
        
        self.hovered = point_in_rectangle(_mx, _my, self.x, self.y, self.x + self.w, self.y + self.h);
        
        if (self.hovered) {
            if (mouse_check_button_pressed(mb_left) || INPUT_MGR.check_pressed("action")) {
                self.pressed = true;
            }
            
            if ((mouse_check_button_released(mb_left) || INPUT_MGR.check_released("action")) && self.pressed) {
                self.tween_timer = self.tween_duration;
                self.click_pending = true;
                self.delay_timer = 5;
                self.pressed = false;
            }
        } else {
            if (mouse_check_button_released(mb_left) || INPUT_MGR.check_released("action")) {
                self.pressed = false;
            }
        }
    };

    /**
     * @function draw
     * @brief Standard draw call (defaults to alpha 1.0).
     */
    static draw = function() {
        self.draw_ext(1.0);
    };

    /**
     * @function draw_ext
     * @brief Draws the button with a specific alpha, useful for fading/scrolling menus.
     * @param {real} _alpha The transparency to draw with.
     */
    static draw_ext = function(_alpha) {
        var _col = self.colors.idle;
        var _t_col = self.colors.text_idle;
        var _img = 0; 
        var _scale = 1.0;
        
        if (!self.enabled) {
            _col = self.colors.disabled;
        } else if (self.pressed) {
            _col = self.colors.click;
            _scale = 0.92;
            _img = 2;
        } else if (self.tween_timer > 0) {
            var _ratio = 1 - (self.tween_timer / self.tween_duration);
            // Using your bounce tween for that click juice
            _scale = tween_bounce_out(0.92, 1.0, _ratio);
            _col = self.colors.idle;
            _img = 0;
        } else if (self.hovered) {
            _col = self.colors.hover;
            _t_col = self.colors.text_hover;
            _img = 1;
        }

        var _draw_w = self.w * _scale;
        var _draw_h = self.h * _scale;
        var _off_x = (self.w - _draw_w) / 2;
        var _off_y = (self.h - _draw_h) / 2;

        // Render Background with alpha
        draw_sprite_stretched_ext(self.sprite, _img, self.x + _off_x, self.y + _off_y, _draw_w, _draw_h, _col, _alpha);
        
        if (self.text != "") {
            draw_set_font(self.font);
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            
            var _tx = self.x + self.w / 2;
            var _ty = self.y + self.h / 2;
            
            // Render text with alpha and scale
            draw_text_outline_transformed(_tx, _ty, self.text, c_black, _t_col, _scale, _alpha);
            
            // Cleanup
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
        }
    };


    static set_position = function(_nx, _ny) {
        self.x = _nx;
        self.y = _ny;
    };
}