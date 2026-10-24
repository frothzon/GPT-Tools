/// @brief A Textbox system for managing and displaying messages with options.
/// This constructor creates a textbox instance that can display text, handle typing effects, 
/// and provide interactive options for the player.
/// @param {Real} xto The x-coordinate of the textbox.
/// @param {Real} yto The y-coordinate of the textbox.
/// @param {Real} max_w The maximum width of the textbox.
/// @param {Real} max_h The maximum height of the textbox.
/// @param {Function|Real} onShow 
/// @param {Function|Real} onClear
/// @param {Array} key_input_array keys for [up,down,left,right,enter]
function Textbox(xto, yto, max_w, max_h, onShow=-1, onClear=-1, key_input_array=[vk_up,vk_down,vk_left,vk_right,vk_enter]) constructor {
    /// @var self.cam_id
    /// The camera ID to associate with the textbox. Default is 0.
    self.cam_id = 0;
    self.shift_toggle = 0;
    
    /// @var self.rect_sprite
    /// The sprite used for the textbox background.
    self.rect_sprite = spr_panel2;
    self.option_button = spr_panel4;
    self.sys_sprite = spr_panel4;
    self.key_icons = {keyboard: spr_action_keys, gamepad: spr_gamepad_keys};
    __show_menu = show_menu_basic;

    /// @var self.char
    /// Tracks the current character being typed in the message.
    self.char = 0;

    /// @var self.font
    /// The font used to display the message text. Default is -1 (unset).
    self.font = -1;

    /// @var self.messages
    /// Array of message objects currently queued in the textbox.
    self.messages = [];
    self.onShowMessage = onShow;
    self.onClearMessage = onClear;

    /// @var self.draw_rect
    /// Defines the drawing rectangle for the textbox (position and size).
    self.draw_rect = {x: xto, y: yto, w: max_w, h: max_h};
    self.selection = 0;
    self.inputs = key_input_array;

    /// @var self.char_type_delay
    /// Delay (in frames) between typing each character.
    self.char_type_delay = 1;

    /// @var self.char_type
    /// Internal counter for character typing delay.
    self.char_type = 0;

    /// @var self.padding
    /// Padding around the text inside the textbox.
    self.padding = 16;

    /// @brief Adds a message to the textbox queue.
    /// @param _text The text of the message to be added.
    /// @return The index of the newly added message in the queue.
    static add_message = function(_text, _sys="") {
        var _msg = {text: _text, options: [ $"OK" ], methods: [-1], count: 0, name: _sys};
        var _len = array_length(self.messages);
        if(array_length(self.messages) == 0){
            if(is_callable(self.onShowMessage)){
                self.onShowMessage();
                self.selection = 0;
            }
        }
        self.messages[_len] = _msg;
        return _len;
    };

    /// @brief Adds an option to a message in the queue.
    /// @param _index The index of the message to add the option to.
    /// @param _option The option text to display.
    /// @param _method The function to call when this option is selected.
    static add_option = function(_index, _option = $"OK", _method = -1) {
        if (_index < 0 || _index >= array_length(self.messages)) {
            return;
        }
        var _msg = self.messages[_index];
        _msg.options[_msg.count] = _option;
        _msg.methods[_msg.count] = _method;
        _msg.count++;
    };

    /// @brief Checks if the current message has finished typing.
    /// @return True if the message has finished typing, false otherwise.
    static done_typing = function() {
        return (self.char >= string_length(self.messages[0].text));
    };

    /// @brief Updates the state of the textbox, including typing and splitting messages.
    static update = function() {
        if (array_length(self.messages) == 0) {
            return;
        }

        draw_set_font(self.font);
        if (--self.char_type <= 0) {
            self.char_type = self.char_type_delay;
            var _str = string_copy(self.messages[0].text, 1, self.char+1);

            if (!self.done_typing()) {
                self.char++;
            }

            var _wmax = self.draw_rect.w - self.padding * 2;
            var _hmax = self.draw_rect.h - self.padding * 3;

            // If the message is too long, split it into another message.
            var _charStart = self.char-1;
            
            if (string_height_ext(_str, -1, _wmax) >= _hmax && (self.char+2) < string_length(self.messages[0].text)) {
                
                var _needs_dash = true;
                var i = 0;
                for(i = 1; i < 16; i++){
                    if(string_char_at(_str, _charStart) != " "){
                        _charStart--;
                        _needs_dash = true;
                    } else {
                        _needs_dash = false;
                        break;
                    }
                }
                if(_needs_dash){
                    _charStart += i;
                }
                var _textStart = string_copy(self.messages[0].text, 1, _charStart-1);
                var _next = string_copy(self.messages[0].text, _charStart+(!_needs_dash), string_length(self.messages[0].text) - _charStart+1-(!_needs_dash));
                var oldOptions = self.messages[0].options;
                var oldMethods = self.messages[0].methods;
                self.messages[0].options = [ $"OK ({self.inputs[_input.ENTER]})" ];
                self.messages[0].methods = [-1];
                self.messages[0].count = 0;
                self.messages[0].text = _textStart;
                if(_needs_dash){
                    _next = "-" + _next;
                }
                array_insert(self.messages, 1, {text: _next, options: oldOptions, methods: oldMethods, count: 0, name: self.messages[0].name});
            }
        }

        draw_reset();
    };

    /// @brief Draws the textbox and its contents, including options if typing is complete.
    static draw = function() {
        if (array_length(self.messages) == 0) {
            return;
        }

        draw_set_font(self.font);
        draw_set_halign(fa_left);

        // Get mouse position for interaction.
        //var cursor_x = device_mouse_x_to_gui(0);
        //var cursor_y = device_mouse_y_to_gui(0);

        var _options = self.messages[0].options;
        var _methods = self.messages[0].methods;
        var _system = self.messages[0].name;

        // Draw the background rectangle.
        draw_sprite_stretched(self.rect_sprite, 0, self.draw_rect.x, self.draw_rect.y, self.draw_rect.w, self.draw_rect.h);
        // draw system
        if(string_length(_system) > 0){
            draw_set_halign(fa_center);
            var _wt = string_width(_system) + self.padding*2;
            var _ht = self.padding * 1.3;
            var _xt = self.draw_rect.x + _wt/2;
            var _yt = self.draw_rect.y - self.padding * 1.5;
            var _xt2 = _xt - _wt/2;
            var _yt2 = _yt - _ht/2 + string_height("H")/2;
            draw_sprite_stretched(self.sys_sprite, 0, _xt2, _yt2, _wt, _ht);
            __draw_text_outline(_xt, _yt, _system, c_black, c_white, 3);
        }
        draw_set_halign(fa_left);

        // Draw the text and options if available.
        if (string_length(self.messages[0].text) > 0) {
            var _ww = self.draw_rect.w - self.padding * 2;
            var _xx = self.draw_rect.x + self.padding;
            var _yy = self.draw_rect.y + self.padding;
            
            __draw_text_advanced(_xx, _yy, self.messages[0].text, self.char, _ww);

            if (self.done_typing()) {
                var _optionCount = array_length(_options);
                var _shift = new Vector2();
                if(gamepad_is_connected(0)){
                    __gamepad_vector(_shift, 0);
                    if(_shift.length() == 0){
                        self.shift_toggle = 0;
                    } else {
                        show_debug_message(_shift);
                        if(self.shift_toggle == 1){
                            _shift.set_length(0);
                        } else {
                            _shift.x = round(_shift.x);
                            _shift.y = round(_shift.y);
                        }
                        self.shift_toggle = 1;
                    }
                } else {
                    __keyboard_vector(_shift, self.inputs[_input.UP], self.inputs[_input.DOWN], self.inputs[_input.LEFT], self.inputs[_input.RIGHT], false);
                }
                self.selection = clamp(self.selection + _shift.y, 0, _optionCount-1);
                var _index = __show_menu(self.option_button, _xx + _ww/2, self.draw_rect.y + self.draw_rect.h, _options, self.selection);
                if (_index >= 0 && __check_inputs_pressed(self.inputs[_input.ENTER], gp_face1)) {
                    var _method = _methods[_index];
                    if (is_callable(_method)) {
                        _method();
                    }
                    // Remove the completed message.
                    array_delete(self.messages, 0, 1);
                    self.char = 0;
                    
                    if(array_length(self.messages) == 0){
                        if(is_callable(self.onClearMessage)){
                            self.onClearMessage();
                        }
                    }
                }
            }
        }

        draw_reset();
    };
    
    static __gamepad_vector = function(vec2, pad_id, deadzone = 0.2){
        vec2.x = gamepad_axis_value(pad_id, gp_axislh);
        vec2.y = gamepad_axis_value(pad_id, gp_axislv);
        if(vec2.length() < 0.2){
            vec2.x = 0;
            vec2.y = 0;
        } else {
            vec2.normalize();
        }
    }
    
    __draw_text_advanced = draw_text_advanced;
    
    static __check_inputs_pressed = function(_key, _padButton, _device=0){
        return (keyboard_check_pressed(ord(_key)) || gamepad_button_check_pressed(_device, _padButton));
    }
    
    static __daw_input_icons = function(xto, yto, w, h, spr_keyboard, ind_keyboard, spr_gamepad, ind_gamepad, pad_id=0){
        if(gamepad_is_connected(pad_id)){
            draw_sprite_stretched(spr_gamepad, ind_gamepad, xto, yto, w, h);
        } else {
            draw_sprite_stretched(spr_keyboard, ind_keyboard, xto, yto, w, h);
        }
    }
    
    /// @param x
    /// @param y
    /// @param string
    /// @param c_outline
    /// @param c_text
    static __draw_text_outline = function(xto, yto, str, c1=c_black, c2=c_white, w_outline=1){
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
    
    /// @brief Updates a vector based on keyboard input for directional movement.
    /// This function modifies the given vector (`vec2`) based on input keys and normalizes the result.
    /// Supports both `Real` (key codes) and `String` (key characters) as inputs for keys.
    /// @param {Struct} vec2 The vector to update. Must have `x` and `y` components.
    /// @param {Real|String} key_up The key or key code for upward movement.
    /// @param {Real|String} key_down The key or key code for downward movement.
    /// @param {Real|String} key_left The key or key code for leftward movement.
    /// @param {Real|String} key_right The key or key code for rightward movement.
    /// @param {Bool} continuous direct or pressed mode
    static __keyboard_vector = function(vec2, key_up, key_down, key_left, key_right, continuous=true) {
        /// @note If the keys are provided as strings, convert them to key codes and recursively call the function.
        if (is_string(key_up)) {
            __keyboard_vector(vec2, ord(key_up), ord(key_down), ord(key_left), ord(key_right), continuous);
        } else {
            /// @brief Calculate horizontal and vertical movement.
            /// The `keyboard_check` function determines whether the key is pressed.
            if(continuous) {
                vec2.x = keyboard_check(key_right) - keyboard_check(key_left);
                vec2.y = keyboard_check(key_down) - keyboard_check(key_up);
            } else {
                vec2.x = keyboard_check_pressed(key_right) - keyboard_check_pressed(key_left); 
                vec2.y = keyboard_check_pressed(key_down) - keyboard_check_pressed(key_up);
            }
    
            /// @brief Normalize the vector to ensure uniform movement speed.
            vec2.normalize();
        }
    }
}
