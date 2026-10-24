/// @brief Text Blaster class for managing dynamic, animated text particles.
/// This class provides functionality for creating, updating, and drawing text particles with customizable animations.
function Text_Blaster() constructor {

    /// @var self.text_particles
    /// @brief Array of active text particles.
    /// Stores all text particles currently being managed by the class.
    self.text_particles = [];

    /// @brief Enum defining types of interpolated parameters for text particles.
    /// Used to specify the type of data being interpolated in animations.
    enum _textPartType {
        pVEC,   ///< Vector2 interpolation.
        pREAL,  ///< Real number interpolation.
        pCOLOR  ///< Color interpolation.
    };

    /// @brief Adds a new text particle to the system.
    /// @param {String} _string The text content of the particle.
    /// @param {Real} _x The initial x-coordinate of the particle.
    /// @param {Real} _y The initial y-coordinate of the particle.
    /// @param {Real} _life The lifetime of the particle in steps. Default is `GAME_SPEED`.
    /// @param {Array} _colors Array of colors for the text animation. Default is `[c_white]`.
    /// @param {Class} _Vec2 The vector2 class pointer
    /// @return {Real} The index of the newly added text particle.
    static add_text = function(_string = "test", _x = 16, _y = 16, _life = game_get_speed(gamespeed_fps), _colors = [c_white], _Vec2 = Vector2) {
        var _textPart = {
            str: _string,  ///< Text content of the particle.
            x: _x,         ///< Current x-coordinate of the particle.
            y: _y,         ///< Current y-coordinate of the particle.
            life_start: _life, ///< Initial lifetime of the particle.
            life: _life,   ///< Remaining lifetime of the particle.
            font: -1,      ///< Font used for the text. Defaults to -1 (default font).
            params: {      ///< Animation parameters for the particle.
                colors: _colors, ///< Array of colors for interpolation.
                alphas: [1, 1, 0], ///< Array of alpha values for fade-out effects.
                delta_spd: [new _Vec2(0, -1)], ///< Array of speed vectors for movement.
                delta_acc: [new _Vec2(0, 0)], ///< Array of acceleration vectors for movement.
                scales: [1, 1.25], ///< Array of scales for size animation.
                angles: [0, 0] ///< Array of angles for rotation animation.
            },
            values: {       ///< Current calculated values for the particle.
                speed_default: new _Vec2(), ///< Default speed vector.
                accel_default: new _Vec2(), ///< Default acceleration vector.
                alpha: 0,     ///< Current alpha value.
                color: 0,     ///< Current color value.
                scale: 1,     ///< Current scale value.
                angle: 0      ///< Current rotation angle.
            }
        };
        var _index = array_length(self.text_particles);
        self.text_particles[_index] = _textPart;
        return _index;
    };

    /// @brief Interpolates values in an array based on a ratio.
    /// Supports real numbers, vectors, and colors for interpolation.
    /// @param {Array} array_data The array of values to interpolate.
    /// @param {Real} ratio The interpolation ratio (0 to 1).
    /// @param {Real} type The type of data to interpolate (`pREAL`, `pVEC`, or `pCOLOR`).
    /// @return {Any} The interpolated value based on the input type.
    static lerp_array = function(array_data, ratio, type = _textPartType.pREAL) {
        var _length = array_length(array_data);
        var _value = ratio * (_length - 1);
        var _index = floor(_value);
        var _ratio = frac(_value);
        if (_index == 0 && _ratio == 0) {
            return array_data[0];
        }
        if (_index == _length - 1) {
            return array_data[1];
        }
        if (type == _textPartType.pREAL) {
            return lerp(array_data[_index], array_data[_index + 1], _ratio);
        } else if (type == _textPartType.pVEC) {
            var _vec1 = array_data[_index];
            var _vec2 = array_data[_index + 1];
            return new Vector2(lerp(_vec1.x, _vec2.x, _ratio), lerp(_vec1.y, _vec2.y, _ratio));
        } else if (type == _textPartType.pCOLOR) {
            return merge_color(array_data[_index], array_data[_index + 1], _ratio);
        }
    };

    /// @brief Updates the text particles' positions and animations.
    /// Applies motion, fading, scaling, and other animations based on their parameters.
    static update = function() {
        var _count = array_length(self.text_particles);
        if (_count == 0) {
            return;
        }
        for (var i = _count - 1; i >= 0; i--) {
            var _textPart = self.text_particles[i];
            var _ratio = 1 - _textPart.life / _textPart.life_start;

            _textPart.life--;
            if (_textPart.life <= 0) {
                array_delete(self.text_particles, i, 1);
            }

            var _values = _textPart.values;
            var _params = _textPart.params;

            // Update movement
            _values.speed_default = lerp_array(_params.delta_spd, _ratio, _textPartType.pVEC);
            var _accel = lerp_array(_params.delta_acc, _ratio, _textPartType.pVEC);
            _values.accel_default.x += _accel.x;
            _values.accel_default.y += _accel.y;

            // Update animations
            _values.alpha = lerp_array(_params.alphas, _ratio, _textPartType.pREAL);
            _values.scale = lerp_array(_params.scales, _ratio, _textPartType.pREAL);
            _values.angle = lerp_array(_params.angles, _ratio, _textPartType.pREAL);
            _values.color = lerp_array(_params.colors, _ratio, _textPartType.pCOLOR);

            // Update position
            _textPart.x += _values.speed_default.x + _values.accel_default.x;
            _textPart.y += _values.speed_default.y + _values.accel_default.y;
        }
    };

    /// @brief Draws all active text particles.
    /// Applies transformations and animations, including scaling, rotation, and coloring.
    static draw = function() {
        var _count = array_length(self.text_particles);
        if (_count == 0) {
            return;
        }
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        for (var i = _count - 1; i >= 0; i--) {
            var _textPart = self.text_particles[i];
            var _values = _textPart.values;
            var _coords = world_to_gui(_textPart.x, _textPart.y);
            draw_set_font(_textPart.font);
            draw_text_outline_transformed(
                _coords[0], _coords[1], _textPart.str, c_black, _values.color, _values.alpha, _values.scale, _values.scale, _values.angle, 1);
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1);
        draw_set_color(c_white);
        draw_set_font(-1);
    };
    
    
}