/// @desc Centralized Input Management System for Game Maker Studio 2.3+
/// @description This struct handles multi-input mapping for Keyboard and Gamepad.
function InputManager() constructor {
    // Storage for all defined actions
    actions = {};

    /// @desc Define an action and bind keys/buttons to it
    /// @param {string} _name The alias (e.g., "jump")
    /// @param {array} _keys Array of vk_* constants or ord("A")
    /// @param {array} _padButtons Array of gp_* constants
    static add_action = function(_name, _keys = [], _padButtons = []) {
        actions[$ _name] = {
            keys: _keys,
            padButtons: _padButtons,
            pressed: false,
            held: false,
            released: false
        };
    };

    /// @desc Call this once per frame in a persistent controller's Step Event (preferably Begin Step)
    static update = function() {
        var _names = variable_struct_get_names(actions);
        var _count = array_length(_names);
        
        for (var i = 0; i < _count; i++) {
            var _name = _names[i];
            var _action = actions[$ _name];
            
            // Reset local state flags for this frame
            var _is_held = false;
            var _is_pressed = false;
            var _is_released = false;

            // --- Check Keyboard ---
            var _k_count = array_length(_action.keys);
            for (var k = 0; k < _k_count; k++) {
                var _key = _action.keys[k];
                if (keyboard_check(_key)) _is_held = true;
                if (keyboard_check_pressed(_key)) _is_pressed = true;
                if (keyboard_check_released(_key)) _is_released = true;
            }

            // --- Check Gamepad (Slot 0) ---
            if (gamepad_is_connected(0)) {
                var _g_count = array_length(_action.padButtons);
                for (var g = 0; g < _g_count; g++) {
                    var _btn = _action.padButtons[g];
                    
                    // Handle Analog Sticks (Axis) as Digital Buttons (Held state only)
                    // Note: This logic maps directional axis movement to dpad-like constants
                    var _threshold = 0.5;
                    if (_btn == gp_padl && gamepad_axis_value(0, gp_axislh) < -_threshold) _is_held = true;
                    if (_btn == gp_padr && gamepad_axis_value(0, gp_axislh) > _threshold) _is_held = true;
                    if (_btn == gp_padu && gamepad_axis_value(0, gp_axislv) < -_threshold) _is_held = true;
                    if (_btn == gp_padd && gamepad_axis_value(0, gp_axislv) > _threshold) _is_held = true;

                    // Standard Button Checks
                    if (gamepad_button_check(0, _btn)) _is_held = true;
                    if (gamepad_button_check_pressed(0, _btn)) _is_pressed = true;
                    if (gamepad_button_check_released(0, _btn)) _is_released = true;
                }
            }

            // Update the persistent struct values with the results of the check
            _action.held = _is_held;
            _action.pressed = _is_pressed;
            _action.released = _is_released;
        }
    };

    /// @desc Returns true if the action is currently being held down
    /// @param {string} _name The name of the action to check
    static check = function(_name) {
        if (!variable_struct_exists(actions, _name)) return false;
        return actions[$ _name].held;
    };

    /// @desc Returns true only on the frame the action was first pressed
    /// @param {string} _name The name of the action to check
    static check_pressed = function(_name) {
        if (!variable_struct_exists(actions, _name)) return false;
        return actions[$ _name].pressed;
    };

    /// @desc Returns true only on the frame the action was released
    /// @param {string} _name The name of the action to check
    static check_released = function(_name) {
        if (!variable_struct_exists(actions, _name)) return false;
        return actions[$ _name].released;
    };
}