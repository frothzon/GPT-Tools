/// @brief A 2D vector class for mathematical operations.
/// Provides various vector operations such as normalization, scaling, dot product, and angle manipulation.
/// @param {Real} vx The x-component of the vector (default: 0).
/// @param {Real} vy The y-component of the vector (default: 0).
function Vector2(vx = 0, vy = 0) constructor {
    x = vx;
    y = vy;

    /// @brief Normalizes the vector to unit length (1).
    /// If the vector's length is 0 or already 1, it remains unchanged.
    static normalize = function() {
        var dis = length();
        if (dis == 1 || dis == 0) return;
        x /= dis;
        y /= dis;
    };

    /// @brief Calculates the length (magnitude) of the vector.
    /// Ensures x and y are not NaN before computing.
    /// @return {Real} The length of the vector.
    static length = function() {
        if (is_nan(self.x))
            self.x = 0;
        if (is_nan(self.y))
            self.y = 0;
        return point_distance(0, 0, x, y);
    };

    /// @brief Sets the vector components to new values.
    /// @param {Real} vx The new x-component.
    /// @param {Real} vy The new y-component.
    static set = function(vx, vy) {
        x = vx;
        y = vy;
    };

    /// @brief Adds another vector to this vector.
    /// @param {Vector2} v2 The vector to add.
    static add = function(v2) {
        x += v2.x;
        y += v2.y;
    };

    /// @brief Computes the dot product of this vector with another vector.
    /// @param {Vector2} v2 The vector to compute the dot product with.
    /// @return {Real} The dot product result.
    static dot = function(v2) {
        return dot_product(x, y, v2.x, v2.y);
    };

    /// @brief Scales the vector by a scalar value.
    /// @param {Real} value The scalar multiplier.
    static scale = function(value) {
        x *= value;
        y *= value;
    };

    /// @brief Computes the angle of the vector in degrees.
    /// @return {Real} The angle in degrees from the positive x-axis.
    static angle = function() {
        return point_direction(0, 0, x, y);
    };

    /// @brief Sets the vector components using length and direction.
    /// @param {Real} length The length of the vector.
    /// @param {Real} angle The direction in degrees.
    static lengthdir = function(length, angle) {
        x = lengthdir_x(length, angle);
        y = lengthdir_y(length, angle);
    };

    /// @brief Moves the vector in a specified direction by a certain length.
    /// @param {Real} length The distance to move.
    /// @param {Real} angle The direction in degrees.
    static add_lengthdir = function(length, angle) {
        x += lengthdir_x(length, angle);
        y += lengthdir_y(length, angle);
    };

    /// @brief Sets the vector's angle while maintaining its length.
    /// @param {Real} angle The new angle in degrees.
    static set_angle = function(angle) {
        var _len = self.length();
        self.lengthdir(_len, angle);
    };

    /// @brief Sets the vector's length while maintaining its direction.
    /// @param {Real} len The new length.
    static set_length = function(len) {
        self.normalize();
        self.scale(len);
    };

    /// @brief Linearly interpolates the vector towards a target point.
    /// @param {Real} xto The target x-coordinate.
    /// @param {Real} yto The target y-coordinate.
    /// @param {Real} ratio The interpolation ratio (0.0 to 1.0).
    static lerp_to = function(xto, yto, ratio) {
        self.x = lerp(self.x, xto, ratio);
        self.y = lerp(self.y, yto, ratio);
    };
    
    static from_input = function(right, up, left, down){
        self.x = right - left;
        self.y = down - up;
        return self;
    };
    
    /// @brief Get distance from self to vx, vy
    /// @param vx x-position
    /// @param vy y-position
    static get_distance = function(vx, vy){
        return point_distance(self.x, self.y, vx, vy);
    };
    
    /// @brief Get distance from self to vx, vy
    /// @param vx x-position
    /// @param vy y-position
    static get_direction = function(vx, vy){
        return point_direction(self.x, self.y, vx, vy);
    };
}





