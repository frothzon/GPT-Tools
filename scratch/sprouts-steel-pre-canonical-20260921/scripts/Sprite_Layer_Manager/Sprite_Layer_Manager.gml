// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information

/// @brief Creates a new layer for sprite management at a specified depth.
/// This constructor initializes a sprite layer at a given depth and provides methods for adding and managing sprites.
/// @param {Real} _depth The depth at which to create the layer (default: 0).
function Sprite_Layer(_depth = 0) constructor{
    /// @var {Layer} _layer
    /// The layer ID for this sprite layer.
    _layer = layer_create(_depth);
    
    /// @var {Array} _tiles
    /// Array of sprite IDs managed by this layer.
    _tiles = [];
    
    /// @brief Adds a sprite to the layer.
    /// Creates a new layer sprite at the specified position and adds it to the internal tracking array.
    /// @param {Real} _x The x-coordinate for the sprite.
    /// @param {Real} _y The y-coordinate for the sprite.
    /// @param {Asset} _sprite The sprite resource to use.
    /// @return {Real} The sprite ID that was created.
    static add_sprite = function(_x, _y, _sprite){
        var _spr = layer_sprite_create(self._layer, _x, _y, _sprite);
        array_push(_tiles, _spr);
        return _spr;
    };
    
    /// @brief Cleans up all resources used by this layer.
    /// Destroys all sprites contained in the layer and then the layer itself.
    /// Call this before deleting the struct to prevent memory leaks.
    static cleanup = function(){
        for(var i = 0; i < array_length(_tiles); i++){
            if(layer_sprite_exists(_layer, _tiles[i])){
                layer_sprite_destroy(_tiles[i]);
            }
        }
        _tiles = [];
        layer_destroy(_layer);
    };
}

/// @brief Adds a sprite to a layer managed by the provided layer manager.
/// @param {Struct} _layerManager The Sprite_Layer_Manager instance to use.
/// @param {Asset} _sprite The sprite resource to use.
/// @param {Real} _x The x-coordinate for the sprite.
/// @param {Real} _y The y-coordinate for the sprite.
/// @param {Real} _depth The depth at which to add the sprite (default: 0).
/// @return {Real} The sprite ID that was created.
function sprite_layer_add_sprite(_layerManager, _sprite, _x, _y, _depth=0){
    return _layerManager.add_sprite(_x, _y, _sprite, _depth);
}

/// @brief Adds a tile (static sprite frame) to a layer managed by the provided layer manager.
/// @param {Struct} _layerManager The Sprite_Layer_Manager instance to use.
/// @param {Asset} _sprite The sprite resource to use.
/// @param {Real} _index The frame index of the sprite to display.
/// @param {Real} _x The x-coordinate for the tile.
/// @param {Real} _y The y-coordinate for the tile.
/// @param {Real} _depth The depth at which to add the tile (default: 0).
/// @return {Real} The sprite ID that was created.
function sprite_layer_add_tile(_layerManager, _sprite, _index, _x, _y, _depth=0){
    return _layerManager.add_tile(_x, _y, _sprite, _index, _depth);
}

/// @brief A manager for handling multiple sprite layers at different depths.
/// This constructor creates a system for dynamically managing sprites across multiple depths,
/// automatically creating new layers as needed and providing methods for adding sprites and tiles.
function Sprite_Layer_Manager() constructor {
    
    /// @var {Struct} sources
    /// A struct containing all layer instances, keyed by depth.
    sources = {};
    
    /// @brief Adds a sprite to a layer at the specified depth.
    /// If a layer at the specified depth doesn't exist, one is created automatically.
    /// @param {Real} _x The x-coordinate for the sprite.
    /// @param {Real} _y The y-coordinate for the sprite.
    /// @param {Asset} _sprite The sprite resource to use.
    /// @param {Real} _depth The depth at which to add the sprite.
    /// @return {Real} The sprite ID that was created.
    static add_sprite = function(_x, _y, _sprite, _depth){
        
        /// layer name (key) set to match the depth
        var layer_name = $"lay{_depth}";
        
        /// create key if it doesn't exist in sources
        if(!variable_struct_exists(self.sources, layer_name)){
            variable_struct_set(self.sources, layer_name, new Sprite_Layer(_depth));
        }
        
        /// if struct fails to be created or found, we want to know
        if(!is_struct(self.sources[$ layer_name])) show_error("Something went wrong adding sprite, struct invalid", true);
        
        /// add sprite to the correct layer and return the id
        return self.sources[$ layer_name].add_sprite(_x, _y, _sprite);
    };
    
    /// @brief Adds a static tile to a layer at the specified depth.
    /// Creates a sprite and sets it to display a single frame without animation.
    /// @param {Real} _x The x-coordinate for the tile.
    /// @param {Real} _y The y-coordinate for the tile.
    /// @param {Asset} _sprite The sprite resource to use.
    /// @param {Real} _index The frame index of the sprite to display.
    /// @param {Real} _depth The depth at which to add the tile.
    /// @return {Real} The sprite ID that was created.
    static add_tile = function(_x, _y, _sprite, _index, _depth){
        var _tile = add_sprite(_x, _y, _sprite, _depth);
        layer_sprite_speed(_tile, 0);
        layer_sprite_index(_tile, _index);
        return _tile;
    };
    
    /// @brief Cleans up all resources used by all layers.
    /// Iterates through all managed layers and calls their cleanup methods, then clears the sources struct.
    static cleanup = function(){
        struct_foreach(self.sources, function(_key, _value){
            _value.cleanup();
        });
        self.sources = {};
    };
}


