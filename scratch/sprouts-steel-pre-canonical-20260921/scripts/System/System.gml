/// @brief A core system class providing utility functions for debugging, random chance calculations, 
/// instance validation, and movement handling.
/// This class includes static helper methods that can be used globally within the game.
function System() constructor{
    
    /// @var self.debug
    /// A debug flag to enable or disable logging.
    self.debug = true;
    
    /// @brief Logs debug messages to the console if debugging is enabled.
    /// @param {String} text The message to be logged.
    static debug_log = function(text){
        if(self.debug){
            show_debug_message(text);
        }
    };
    
    /// @brief Determines whether a random event occurs based on a given ratio.
    /// @param {Real} ratio A value between 0 and 1 representing the probability of success.
    /// @return {Bool} Returns `true` if the random event occurs, otherwise `false`.
    static chance = function(ratio){
        return(random(1) <= ratio);	
    };
    
    /// @brief Checks whether a given instance exists.
    /// @param {Real} object_id The ID of the instance to check.
    /// @return {Bool} Returns `true` if the instance exists and is valid, otherwise `false`.
    static check_instance = function(object_id) {
        if (!is_undefined(object_id) && object_id >= 0 && instance_exists(object_id)) {
            return true; ///< Object ID is valid and instance exists.
        } else {
            return false; ///< Object ID is invalid or instance does not exist.
        }
    };
    
    /// @brief Moves a target instance by a specified amount while considering collision layers.
    /// @param {Real} target The instance ID of the target to move.
    /// @param {Real} dx The horizontal displacement.
    /// @param {Real} dy The vertical displacement.
    /// @param {String|Real} collision_layer The layer name for tile-based collisions (optional).
    static shove_target = function(target, dx, dy, collision_layer){
        with(target){
            if(is_string(collision_layer)){
                var _walls = layer_tilemap_get_id(collision_layer);
                move_and_collide(dx, dy, _walls);
            } else {
                x += dx; 
                y += dy;
            }
        }
    };
    
    /// @brief Pushes an object away from another instance to resolve collisions.
    /// This function attempts to separate two overlapping objects by pushing them away based on their relative positions.
    /// @param {Real|String} collision_layer The collision layer to check against. If `-1`, no layer-based collision is considered.
    /// @param {Bool} even If `true`, both objects will be pushed apart equally.
    static collide_push = function(src_obj, hit_obj, collision_layer = -1, even = false) {
        with(src_obj){
            
            // Determine push direction
            var dir = (x == hit_obj.x && y == hit_obj.y) ? irandom(360) : point_direction(hit_obj.x, hit_obj.y, x, y);
            var dx = lengthdir_x(1, dir);
            var dy = lengthdir_y(1, dir);
            var esc_test = 32; ///< Escape counter to prevent infinite loops
        
            var _push = SCT.shove_target; ///< Reference to the shove function
        
            // Continue pushing until there is no overlap
            while (place_meeting(x, y, hit_obj)) {
                _push(self, dx, dy, collision_layer);
                if (even) {
                    _push(hit_obj, -dx, -dy, collision_layer);
                }
        
                // Prevent infinite loop by breaking after too many iterations
                if (esc_test-- <= 0) {
                    break;
                }
            }
        }
    };
    
    /// @brief Generates an array of random integers within a given range.
    /// @param {Real} size The number of elements in the array.
    /// @param {Real} minval The minimum possible value.
    /// @param {Real} maxval The maximum possible value.
    /// @return {Array} An array containing `size` random integers between `minval` and `maxval`.
    static create_random_array = function(size, minval, maxval) {
        var out = [];
        for (var i = 0; i < size; i++) {
            out[i] = irandom_range(minval, maxval);
        }
        return out;
    };
    
    
    /// @brief Draws an input method icon based on whether a gamepad is connected.
    /// This function displays the appropriate control icon depending on the presence of a gamepad.
    /// @param {Real} xto The x-coordinate where the icon will be drawn.
    /// @param {Real} yto The y-coordinate where the icon will be drawn.
    /// @param {Real} w The width of the icon.
    /// @param {Real} h The height of the icon.
    /// @param {Asset} spr_keyboard The sprite to use for keyboard input representation.
    /// @param {Real} ind_keyboard The sub-image index for the keyboard sprite.
    /// @param {Asset} spr_gamepad The sprite to use for gamepad input representation.
    /// @param {Real} ind_gamepad The sub-image index for the gamepad sprite.
    /// @param {Real} pad_id The gamepad ID to check (default: `0`).
    static daw_input_icons = function(xto, yto, w, h, spr_keyboard, ind_keyboard, spr_gamepad, ind_gamepad, pad_id=0) {
        if (gamepad_is_connected(pad_id)) {
            draw_sprite_stretched(spr_gamepad, ind_gamepad, xto, yto, w, h);
        } else {
            draw_sprite_stretched(spr_keyboard, ind_keyboard, xto, yto, w, h);
        }
    };
    
    /// @brief Resets the drawing settings to default values.
    /// This function resets alignment, transparency, color, and font settings to their standard defaults.
    static draw_reset = function() {
        draw_set_halign(fa_left); ///< Reset horizontal alignment.
        draw_set_valign(fa_top); ///< Reset vertical alignment.
        draw_set_alpha(1); ///< Reset transparency to full opacity.
        draw_set_color(c_white); ///< Reset drawing color to white.
        draw_set_font(-1); ///< Reset the font to the default.
    };
    
    /// @brief Draws a status bar with a filled portion based on a given ratio.
    /// This function is used to represent things like health bars, mana bars, or progress bars.
    /// @param {Asset} sprite The sprite asset used for the bar.
    /// @param {Real} xto The x-coordinate where the bar is drawn.
    /// @param {Real} yto The y-coordinate where the bar is drawn.
    /// @param {Real} width The total width of the bar.
    /// @param {Real} height The total height of the bar.
    /// @param {Real} ratio The fill percentage (clamped between `0` and `1`).
    static draw_stats_bar = function(sprite, xto, yto, width, height, ratio) {
        draw_sprite_stretched(sprite, 1, xto, yto, width, height); ///< Draw the background of the bar.
        draw_sprite_stretched(sprite, 0, xto, yto, width * clamp(ratio, 0, 1), height); ///< Draw the filled portion of the bar.
    };
    
    
    /// @brief Retrieves the gamepad's left analog stick vector and normalizes it.
    /// This function reads the horizontal and vertical values of the left analog stick, applies a deadzone,
    /// and normalizes the vector if above the threshold.
    /// @param {Array} vec2 A reference to a vector (object with `.x` and `.y` properties) to store the result.
    /// @param {Real} pad_id The ID of the gamepad to read input from.
    /// @param {Real} deadzone The minimum threshold for stick movement before registering input (default: `0.2`).
    static gamepad_vector = function(vec2, pad_id, deadzone = 0.2) {
        vec2.x = gamepad_axis_value(pad_id, gp_axislh);
        vec2.y = gamepad_axis_value(pad_id, gp_axislv);
        
        // Apply deadzone threshold
        if (vec2.length() < deadzone) {
            vec2.x = 0;
            vec2.y = 0;
        } else {
            vec2.normalize(); ///< Normalize vector to maintain consistent movement direction.
        }
    };
    
    /// @brief Retrieves the tilemap ID from a given layer name.
    /// This function finds the tilemap associated with a specific layer name and returns its ID.
    /// @param {String} layer_name The name of the layer containing the tilemap.
    /// @return {Real} The tilemap ID if found; otherwise, returns `-1` if the layer does not exist.
    static get_tilemap = function(layer_name) {
        var layer_id = layer_get_id(layer_name);
        var map_id = layer_tilemap_get_id(layer_id);
        return map_id;
    };
    
    
    /// @brief Updates a vector based on keyboard input for directional movement.
    /// This function modifies the given vector (`vec2`) based on input keys and normalizes the result.
    /// Supports both `Real` (key codes) and `String` (key characters) as inputs for keys.
    /// @param {Struct} vec2 The vector to update. Must have `x` and `y` components.
    /// @param {Real|String} key_up The key or key code for upward movement.
    /// @param {Real|String} key_down The key or key code for downward movement.
    /// @param {Real|String} key_left The key or key code for leftward movement.
    /// @param {Real|String} key_right The key or key code for rightward movement.
    /// @param {Bool} continuous direct or pressed mode
    static keyboard_vector = function(vec2, key_up, key_down, key_left, key_right, continuous=true) {
        /// @note If the keys are provided as strings, convert them to key codes and recursively call the function.
        if (is_string(key_up)) {
            self.keyboard_vector(vec2, ord(key_up), ord(key_down), ord(key_left), ord(key_right), continuous);
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
    };
    
    /// @func linestep(from, to, time, offset);
    /// @desc loops over and over over a set interval
    /// @param {Real} from (start value)
    /// @param {Real} to (end value)
    /// @param {Real} time (seconds)
    /// @param {Real} offset (seconds)
    /// @return {Real} value
    static linestep = function(from, to, time, offset){
        var ts = current_time/1000;
        var ratio = ((ts + offset) % time) / time;
        return lerp(from, to, ratio);
    };
    
    /// @desc Selects a random index from an array based on weighted probabilities.
    /// @param {Array<Real>} _weight_array An array of numbers representing the weight distribution.
    /// @return {Real} The selected index.
    static random_weighted = function(_weight_array) {
        var _size = array_length(_weight_array);
        if (_size == 0) return -1; // Safety check for empty arrays
    
        // 1. Calculate the total sum of all weights
        var _total_weight = 0;
        for (var i = 0; i < _size; ++i) {
            _total_weight += _weight_array[i];
        }
    
        // 2. Pick a random number between 0 and the total (exclusive of the total)
        // We use random() for better precision with small weights.
        var _roll = random(_total_weight);
        var _cursor = 0;
    
        // 3. Iterate and see where the "roll" landed
        for (var i = 0; i < _size; ++i) {
            _cursor += _weight_array[i];
            
            // If our roll is within this current weight's "slice"
            if (_roll < _cursor) {
                return i;
            }
        }
    
        // Fallback for floating point errors
        return _size - 1;
    };
    
    /// @brief Generates a power-of-two value based on a weighted random selection.
    /// This function selects a random index from the provided array using `random_weighted()`,
    /// then returns a power-of-two value where `1 << index` determines the bit shift.
    /// @param {Array} arr An array of weights used for the random selection.
    /// @return {Real} A power-of-two value determined by the weighted selection.
    static random_bit_shift = function(arr) {
        var _shift = self.random_weighted(arr); ///< Randomly selected index based on weighted probabilities.
        var _val = 1 << _shift; ///< Compute the bit-shifted value (power of two).
    
        // Debug output for verification
        self.debug_log("4-bit");
        self.debug_log(_shift);
        self.debug_log(_val);
    
        return _val;
    };
    
    
    /// @brief Rolls a set number of dice and returns the highest value.
    /// This function simulates rolling multiple dice with a given number of sides and
    /// returns the highest roll.
    /// @param {Real} qty The number of dice to roll.
    /// @param {Real} sides The number of sides on each die.
    /// @return {Real} The highest value rolled among all dice.
    static roll_dice = function(qty, sides) {
        var g_highest = 0; ///< Stores the highest rolled value.
        
        // Roll the dice and track the highest value.
        repeat (qty) g_highest = max(g_highest, irandom_range(1, sides));
        
        return g_highest;
    };
    
    /// @brief Checks if there is a tile present at a given position in a specific layer.
    /// This function retrieves the tilemap ID for a given layer and checks if a tile exists
    /// at the specified pixel coordinates.
    /// @param {Real} dx The x-coordinate to check.
    /// @param {Real} dy The y-coordinate to check.
    /// @param {String} layer_name The name of the layer containing the tilemap.
    /// @return {Bool} Returns `true` if a tile exists at the specified position, otherwise `false`.
    static tile_at_position = function(dx, dy, layer_name) {
        var layer_id = layer_get_id(layer_name); ///< Retrieve the layer ID.
        var map_id = layer_tilemap_get_id(layer_id); ///< Get the tilemap ID from the layer.
    
        return (tilemap_get_at_pixel(map_id, dx, dy) > 0); ///< Check if a tile exists at the given coordinates.
    };
    
    /// @brief Creates a smooth oscillating wave motion between two values.
    /// This function generates a sinusoidal wave oscillating between `from` and `to` over a given `time` period.
    /// @param {Real} from The starting value of the wave.
    /// @param {Real} to The ending value of the wave.
    /// @param {Real} time The duration of a full oscillation (in seconds).
    /// @param {Real} offset A phase offset for the wave.
    /// @return {Real} The interpolated wave value at the current moment.
    static wave = function(from, to, time, offset) {
        var a4 = (to - from) * 0.5; ///< Half of the wave amplitude.
    
        // Compute the oscillating wave value using a sine function.
        return from + a4 + sin((((current_time * 0.001) + time * offset) / time) * (pi * 2)) * a4;
    };
    
    /// @brief Creates a smooth oscillating wave motion between two values.
    /// This function generates a sinusoidal wave oscillating between `from` and `to` over a given `time` period.
    /// @param {Real} from The starting value of the wave.
    /// @param {Real} to The ending value of the wave.
    /// @param {Real} ratio between 0 and 1.
    static warp = function(from, to, ratio){
        return lerp(from, to, sin(ratio * pi));
    }
    
    
    /// @brief Wraps a value within a specified range.
    /// This function ensures that a given value stays within the range `[minval, maxval)`,
    /// looping back around if it exceeds the boundaries.
    /// @param {Real} value The value to be wrapped.
    /// @param {Real} minval The lower bound of the range.
    /// @param {Real} maxval The upper bound of the range.
    /// @return {Real} The wrapped value within the specified range.
    static wrap = function(value, minval, maxval) {
        var g_range = maxval - minval; ///< The total range size.
    
        // Adjust value to stay within the range.
        while (value >= maxval) value -= g_range;
        while (value < minval) value += g_range;
    
        return value;
    };
    
    /// @brief Centers the camera on a target position.
    /// This function calculates the new camera position so that it remains centered on the target,
    /// adjusting its view position accordingly.
    /// @param {Real} target_x The x-coordinate of the target.
    /// @param {Real} target_y The y-coordinate of the target.
    /// @param {Real} cam_index The index of the camera to adjust (default: `0`).
    static center_camera = function(target_x, target_y, cam_index = 0) {
        // Get half of the camera's view width (used for centering calculations).
        var half_view_width = camera_get_view_width(view_camera[cam_index]) / 2;
    
        // Get half of the camera's view height (used for centering calculations).
        var half_view_height = camera_get_view_height(view_camera[cam_index]) / 2;
    
        var _sx = surface_get_width(application_surface); ///< Application surface width.
        var _sy = surface_get_height(application_surface); ///< Application surface height.
    
        // Calculate the new top-left corner position of the camera's view.
        var new_view_x = round(target_x - half_view_width);
        var new_view_y = round(target_y - half_view_height);
    
        // Debug message showing camera movement.
        show_debug_message($"Center cam from {camera_get_view_x(view_camera[cam_index])}, {camera_get_view_x(view_camera[cam_index])} to {new_view_x}, {new_view_y}");
    
        // Update the camera's position to the new top-left corner coordinates.
        camera_set_view_pos(view_camera[cam_index], new_view_x, new_view_y);
    };
    
    
    /// @brief Smoothly moves the camera towards a target position.
    /// This function interpolates the camera's position toward a given target `(target_x, target_y)`
    /// using linear interpolation (LERP). It also optionally restricts the camera within the room boundaries.
    /// @param {Real} target_x The target x-coordinate for the camera.
    /// @param {Real} target_y The target y-coordinate for the camera.
    /// @param {Real} ratio The interpolation factor (0 = no movement, 1 = instant movement).
    /// @param {Real} cam_index The index of the camera to move (default: `0`).
    /// @param {Bool} restrict If `true`, the camera is restricted to stay within the room boundaries (default: `true`).
    static move_camera = function(target_x, target_y, ratio, cam_index = 0, restrict = true) {
        
        // Get camera dimensions.
        var cam_width = camera_get_view_width(view_camera[cam_index]);
        var cam_height = camera_get_view_height(view_camera[cam_index]);
    
        // Calculate half of the camera's view dimensions (for centering calculations).
        var half_view_width = cam_width / 2;
        var half_view_height = cam_height / 2;
    
        // Store the camera scaling factor relative to the application surface.
        static cam_position = {dx: 1, dy: 1}; 
    
        var _sx = surface_get_width(application_surface);
        var _sy = surface_get_height(application_surface);
    
        cam_position.dx = _sx / cam_width;
        cam_position.dy = _sy / cam_height;
    
        // Get the current top-left corner position of the camera.
        var view_x = camera_get_view_x(view_camera[cam_index]);
        var view_y = camera_get_view_y(view_camera[cam_index]);
    
        // Calculate the current center position of the camera.
        var camera_center_x = view_x + half_view_width;
        var camera_center_y = view_y + half_view_height;
    
        // Smoothly interpolate towards the target position.
        camera_center_x = lerp(camera_center_x, target_x, ratio);
        camera_center_y = lerp(camera_center_y, target_y, ratio);
    
        // Compute the new top-left position based on the centered target.
        var new_view_x = camera_center_x - half_view_width;
        var new_view_y = camera_center_y - half_view_height;
    
        // Adjust the new camera position based on the scaling factor.
        var cam_x = round(new_view_x * cam_position.dx) / cam_position.dx;
        var cam_y = round(new_view_y * cam_position.dy) / cam_position.dy;
    
        // Restrict camera movement within the room boundaries if enabled.
        if (restrict) {
            cam_x = clamp(cam_x, 0, room_width - cam_width);
            cam_y = clamp(cam_y, 0, room_height - cam_height);
        }
    
        // Update the camera's position to the new top-left corner coordinates.
        camera_set_view_pos(view_camera[cam_index], cam_x, cam_y);
    };
    
    /// @desc rotate_smooth(angle_start, angle_end, angle_ratio);
    /// @param angle_start starting angle for object
    /// @param angle_end ending angle for object
    /// @param angle_ratio step ratio per frame
    function rotate_smooth(angle_start, angle_end, angle_ratio){
    	var _rotDist = angle_difference(angle_end, angle_start)*angle_ratio;
    	return(angle_start+_rotDist);
    };
    
    
}





