/// @brief A Collision Grid system for managing object collision layers.
/// This constructor initializes a grid-based collision detection system, allowing for pathfinding
/// and movement validation across multiple layers of collision objects.
function CollisionGrid() constructor {
    /// @var {Array} self.grids
    /// Stores multiple mp_grids, each representing a collision layer.
    self.grids = [];
    
    /// @var {Real} self.layerCount
    /// Keeps track of the number of collision layers.
    self.layerCount = 0;
    
    /// @var {Struct} self.position
    /// Defines the grid's position and size within the room.
    /// - `x`, `y`: The starting coordinates of the grid.
    /// - `w`, `h`: The width and height of the grid.
    /// - `dx`, `dy`: The cell size of the grid.
    self.position = { x: -10, y: -10, w: room_width + 20, h: room_height + 20, dx: 16, dy: 16 };
    
    /// @var {Real} self.padding
    /// Increase collision area by this margin
    self.padding=16;
    
    /// @brief Resets and initializes the collision grid layers.
    /// This function clears old grids, then creates and populates new layers based on the provided collision objects.
    /// @param {Array} collObjectsArray An array of collision object instances, each defining a collision layer.
    static reset = function(collObjectsArray) {
        self.position.w = room_width + 20;
        self.position.h = room_height + 20;
        
        /// Set layer count based on the number of provided collision objects.
        self.layerCount = array_length(collObjectsArray);
        
        /// Destroy old collision grids.
        var _mpCount = array_length(self.grids);
        for (var i = 0; i < _mpCount; i++) {
            mp_grid_destroy(self.grids[i]);
        }
        
        /// Calculate grid dimensions.
        var wcount = self.position.w / self.position.dx;
        var vcount = self.position.h / self.position.dy;
        show_debug_message([wcount, vcount]);
        
        /// Create and populate new grids.
        for (var i = 0; i < self.layerCount; i++) {
            /// Create a new collision grid.
            self.grids[i] = mp_grid_create(self.position.x, self.position.y, wcount, vcount, self.position.dx, self.position.dy);
            
            /// Clear any existing data within the grid.
            mp_grid_clear_all(self.grids[i]);
            
            /// Add collision objects to the grid. 
            var _obj = collObjectsArray[i];
            var _x1 = _obj.bbox_left - self.padding;
            var _y1 = _obj.bbox_top - self.padding;
            var _x2 = _obj.bbox_right + self.padding;
            var _y2 = _obj.bbox_bottom + self.padding;
            
            mp_grid_add_rectangle(self.grids[i], _x1, _y1, _x2, _y2);
        }
    };
    
    /// @brief Re-initializes the collision grid layers.
    /// This function clears old grids, then populates new layers based on the provided collision objects.
    /// @param {Array} collObjectsArray An array of collision object instances, each defining a collision layer.
    static rebuild = function(collObjectsArray){
        self.position.w = room_width + 20;
        self.position.h = room_height + 20;
        
        /// Set layer count based on the number of provided collision objects.
        self.layerCount = array_length(collObjectsArray);
        
        /// Calculate grid dimensions.
        var wcount = self.position.w / self.position.dx;
        var vcount = self.position.h / self.position.dy;
        show_debug_message([wcount, vcount]);
        
        /// Create and populate new grids.
        for (var i = 0; i < self.layerCount; i++) {
            
            /// Clear any existing data within the grid.
            mp_grid_clear_all(self.grids[i]);
            
            /// Add collision objects to the grid.
            var _obj = collObjectsArray[i];
            var _x1 = _obj.bbox_left - self.padding;
            var _y1 = _obj.bbox_top - self.padding;
            var _x2 = _obj.bbox_right + self.padding;
            var _y2 = _obj.bbox_bottom + self.padding;
            
            mp_grid_add_rectangle(self.grids[i], _x1, _y1, _x2, _y2);
        }
    }
    
    /// @brief Sets a path through the specified grid layer.
    /// @param {Real} layerId The index of the collision grid layer.
    /// @param {Asset} path The path asset to modify.
    /// @param {Instance} obj The object whose path is being set.
    /// @param {Real} xto The target x-coordinate.
    /// @param {Real} yto The target y-coordinate.
    /// @return {Bool} Returns true if a path was successfully created, otherwise false.
    static grid_set_path = function(layerId, path, obj, xto, yto) {
        var pathCreated = mp_grid_path(self.grids[layerId], path, obj.x, obj.y, xto, yto, 1);
        show_debug_message(pathCreated);
        return pathCreated;
    };
    
    /// @brief Checks if a position within a specified grid layer is free.
    /// @param {Real} layerId The index of the collision grid layer.
    /// @param {Real} xx The x-coordinate to check.
    /// @param {Real} yy The y-coordinate to check.
    /// @return {Bool} Returns true if the position is free (no collision), otherwise false.
    static grid_position_is_free = function(layerId, xx, yy) {
        var _grid = self.grids[layerId];
        var _xto = (xx - self.position.x) div self.position.dx;
        var _yto = (yy - self.position.y) div self.position.dy;
        var _hitX = mp_grid_get_cell(_grid, _xto, _yto) == 0;
        return _hitX;
    };
    
    /// @brief Moves an object within the grid, ensuring it does not collide.
    /// Checks if the destination is free before updating the object's position.
    /// @param {Real} layerId The index of the collision grid layer.
    /// @param {Instance} obj The object to move.
    /// @param {Real} xto The x movement offset.
    /// @param {Real} yto The y movement offset.
    static move_object = function(layerId, obj, xto, yto) {
        if (self.grid_position_is_free(layerId, obj.x + xto, obj.y)) {
            obj.x += xto;
        }
        if (self.grid_position_is_free(layerId, obj.x, obj.y + yto)) {
            obj.y += yto;
        }
    };
}
