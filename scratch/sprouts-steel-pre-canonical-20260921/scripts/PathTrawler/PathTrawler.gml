/// @brief A utility class for following a path by extracting waypoints at set intervals.
/// The PathTrawler class extracts a path into discrete points and provides navigation utilities.
function PathTrawler() constructor {
    
    /// @var self.points
    /// Array of points extracted from the path, each containing x, y coordinates and a ratio.
    self.points = [];
    
    /// @var self.radius
    /// The radius around each point used for determining when to advance to the next point.
    self.radius = 8;
    
    /// @var self.index
    /// The current index in the points array.
    self.index = 0;
    
    /// @var self.last_index
    /// The last index in the points array (used to determine the endpoint).
    self.last_index = 0;
    
    /// @var self.start_over
    /// Boolean indicating whether the path should restart when reaching the last point.
    self.start_over = false;
    
    /// @var self.ready
    /// Boolean indicating if the path data has been successfully extracted and is ready to use.
    self.ready = false;
    
    /// @brief Extracts a path into discrete points spaced at given intervals.
    /// @param {Asset} _path The path asset to extract points from.
    /// @param {Real} _stepSize The distance between each extracted point.
    static extract_path = function(_path, _stepSize = 32) {
        var _len = path_get_length(_path);
        var _steps = _len / _stepSize;
        self.points = [];
        self.radius = _stepSize div 2;
        self.index = 0;
        self.last_index = _steps - 1;
        
        for (var i = 0; i < _steps; i++) {
            var _ratio = clamp((i + 1) / _steps, 0, 1);
            var _xx = path_get_x(_path, _ratio);
            var _yy = path_get_y(_path, _ratio);
            self.points[i] = {x: _xx, y: _yy, r: _ratio};
        }
        
        if (array_length(self.points)) {
            self.ready = true;
        }
    };
    
    /// @brief Retrieves the next point in the path relative to an object's position.
    /// @param {Real} obj_x The x-coordinate of the object.
    /// @param {Real} obj_y The y-coordinate of the object.
    /// @return {Struct|Real} Returns the next point struct or -1 if the path is not ready.
    static get_next_point = function(obj_x, obj_y) {
        if (!self.ready) {
            return -1;
        }
        
        var _loc = self.points[self.index];
        var _dist = point_distance(obj_x, obj_y, _loc.x, _loc.y);
        
        // Check if the object has reached the current point
        if (_dist <= self.radius) {
            if (self.index >= self.last_index) {
                if (self.start_over) {
                    self.index = 0;
                } else {
                    self.ready = false;
                }
            } else {
                self.index++;
            }
        }
        
        return self.points[self.index];
    };
    
    /// @brief Computes the directional vector to the next point, scaled by a given speed.
    /// @param {Real} obj_x The x-coordinate of the object.
    /// @param {Real} obj_y The y-coordinate of the object.
    /// @param {Real} _speed The movement speed of the object.
    /// @return {Struct|Real} Returns a struct with x, y movement values or -1 if the path is not ready.
    static get_next_vector = function(obj_x, obj_y, _speed) {
        if (!self.ready) {
            return -1;
        }
        
        var _target = self.get_next_point(obj_x, obj_y);
        var _dx = _target.x - obj_x;
        var _dy = _target.y - obj_y;
        var _length = point_distance(0, 0, _dx, _dy);
        var _next = {x: 0, y: 0};
        
        // Normalize and scale the vector to the given speed
        if (_length > 0) {
            _next.x = (_dx / _length) * _speed;
            _next.y = (_dy / _length) * _speed;
        }
        
        return _next;
    };
    
    /// @brief Draws the path and highlights the current point.
    static draw_path_trawler = function() {
        if (!self.ready) {
            return -1;
        }
        
        for (var i = 0; i < array_length(self.points); i++) {
            var _point = self.points[i];
            var _highlight = (i == self.index);
            var _color = _highlight ? c_lime : c_white;
            
            draw_circle_color(_point.x, _point.y, self.radius, _color, _color, true);
            
            if (i > 0) {
                var _prev = self.points[i - 1];
                draw_line_color(_prev.x, _prev.y, _point.x, _point.y, _color, _color);
            }
        }
    };
    
    /// @brief Converts the extracted path points into a JSON string.
    /// @return {String} JSON representation of the points array.
    toString = function() {
        return json_stringify(self.points, 1);
    };
}
