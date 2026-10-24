/// @brief ZAxis class for managing vertical (Z-axis) movement and physics.
/// This class provides functionality for Z-axis motion, including gravity, jumping, and sinusoidal floating effects.
/// Designed for use in a 2D game with simulated vertical movement.
function ZAxis() constructor {

    /// @var self.z
    /// @brief Current Z-axis position.
    /// Represents the vertical position of the object.
    self.z = 0;

    /// @var self.z_gravity
    /// @brief Gravity applied to the Z-axis.
    /// Defines the force pulling the object downward.
    self.z_gravity = 0.5;

    /// @var self.z_speed
    /// @brief Vertical speed along the Z-axis.
    /// Positive values represent upward motion; negative values represent downward motion.
    self.z_speed = 0;

    /// @var self.z_freeze
    /// @brief Whether Z-axis updates are frozen.
    /// If `true`, the Z-axis position will not be updated.
    self.z_freeze = false;

    /// @var self.z_ground
    /// @brief Ground level for the Z-axis.
    /// Represents the position below which the object cannot move.
    self.z_ground = 0;

    /// @var self.z_float
    /// @brief Whether the object is floating.
    /// If `true`, the object will oscillate sinusoidally above the ground.
    self.z_float = false;

    /// @var self.state
    /// @brief Current state of the object.
    /// 0 indicates airborne, 1 indicates grounded.
    self.state = 1;

    /// @brief Generates a sinusoidal wave for floating effects.
    /// Used to calculate oscillating movement for floating objects.
    /// @param {Real} from Minimum value of the wave.
    /// @param {Real} to Maximum value of the wave.
    /// @param {Real} timing Duration of one wave cycle.
    /// @param {Real} offset Offset to adjust the wave's phase.
    /// @return {Real} The calculated wave value for the current time.
    static __wave = function(from, to, timing, offset) {
        var dt = 0.001;
        var at = (to - from) * 0.5;
        return from + at + sin((((current_time * dt) + timing * offset) / timing) * (pi * 2)) * at;
    };

    /// @brief Updates Z-axis physics, including gravity, floating, and landing logic.
    /// Applies gravity, handles landing on the ground, and executes optional landing logic.
    /// @param {Function|Real} onLanding Function to call upon landing (optional).
    static update = function(onLanding = -1) {
        if (!self.z_freeze) {
            // Apply gravity to the Z-axis speed
            self.z_speed -= self.z_gravity;
            self.z += self.z_speed;

            // Ensure the object does not fall below the ground level
            if (self.z < self.z_ground) {
                self.z = self.z_ground;
                self.z_speed = 0;
            }

            // Handle floating behavior
            if (self.z_float) {
                var _sink = -sprite_height * 0.5 + self.__wave(-4, 4, 1.5, 0);
                if (self.z < _sink && self.z_speed < 0) {
                    self.z_speed = 0;
                    self.z = _sink;
                }
            }

            // Handle landing logic
            var _grounded = self.onGround();
            if (_grounded && self.state == 0) {
                self.state = 1;
                if (is_callable(onLanding)) {
                    /// @note Executes the landing function in the parent context.
                    with (other) {
                        onLanding();
                    }
                }
            }

            // Update the state if the object is not grounded
            if (!_grounded) {
                self.state = 0;
            }
        }
    };

    /// @brief Determines if the object is on the ground.
    /// @return {Bool} `true` if the object is grounded, `false` otherwise.
    static onGround = function() {
        return (self.z <= self.z_ground + 1);
    };

    /// @brief Adds a jumping motion to the Z-axis.
    /// Sets the vertical speed to initiate upward movement if the object is grounded.
    /// @param {Real} _spd The speed to apply for the jump.
    static jump = function(_spd) {
        if (self.onGround) {
            self.z_speed = _spd;
        }
    };
}



