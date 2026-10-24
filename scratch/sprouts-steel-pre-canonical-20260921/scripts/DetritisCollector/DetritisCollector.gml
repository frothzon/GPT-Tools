/// @description DetritisCollector class for persistent debris
/// @param {string} _name - Base name for saving surfaces
/// @param {real} _surface_width - Width of each surface in the grid
/// @param {real} _surface_height - Height of each surface in the grid
function DetritisCollector(_name = "detritus", _surface_width = 512, _surface_height = 512) constructor {
    // Properties
    name = _name;
    surface_width = _surface_width;
    surface_height = _surface_height;
    surfaces = [];
    sprites = [];   // Memory backup for surfaces
    is_updated = [];
    needs_disk_save = [];  // Track which cells need disk writes
    grid_width = 0;
    grid_height = 0;
    save_directory = "surfaces/";
    save_timer = current_time;
    save_delay = 500;
    
    // Initialize the surface grid based on room dimensions
    static initialize = function() {
        // Calculate grid dimensions
        grid_width = ceil(room_width / surface_width);
        grid_height = ceil(room_height / surface_height);
        
        // Create 2D array for surfaces
        surfaces = array_create(grid_width);
        sprites = array_create(grid_width);
        for (var i = 0; i < grid_width; i++) {
            surfaces[i] = array_create(grid_height, -1);
            sprites[i] = array_create(grid_height, -1);
            is_updated[i] = array_create(grid_height, 0);
            needs_disk_save[i] = array_create(grid_height, 0);
        }
        
        // Make sure save directory exists
        if (!directory_exists(save_directory)) {
            directory_create(save_directory);
        }
        
        // Load existing surfaces if they exist, or create new ones
        for (var ix = 0; ix < grid_width; ix++) {
            for (var iy = 0; iy < grid_height; iy++) {
                var surf_name = name + "_" + string(ix) + "_" + string(iy);
                var file_path = save_directory + surf_name + ".png";
                
                // Create surface
                surfaces[ix][iy] = surface_create(surface_width, surface_height);
                
                // Clear to transparent
                surface_set_target(surfaces[ix][iy]);
                draw_clear_alpha(c_black, 0);
                
                // Load existing data if it exists
                if (file_exists(file_path)) {
                    // Load the sprite from file
                    var load_id = sprite_add(file_path, 1, false, false, 0, 0);
                    
                    if (sprite_exists(load_id)) {
                        // Try to draw immediately
                        gpu_set_blendmode(bm_normal);
                        draw_sprite_ext(load_id, 0, 0, 0, 1, 1, 0, c_white, 1);
                        
                        // Schedule a delayed load to ensure sprite loads properly
                        var self_ref = self;
                        var ix_ref = ix;
                        var iy_ref = iy;
                        var spr_ref = load_id;
                        var loader_payload = {self_ref: self_ref, ix_ref: ix_ref, iy_ref: iy_ref, spr_ref: spr_ref};
                        
                        var finish_loading = function(loader_payload) {
                            if (!surface_exists(loader_payload.self_ref.surfaces[loader_payload.ix_ref][loader_payload.iy_ref]) || 
                                !sprite_exists(loader_payload.spr_ref)) return;
                            
                            // Create the backup sprite in our array
                            if (sprite_exists(loader_payload.self_ref.sprites[loader_payload.ix_ref][loader_payload.iy_ref])) {
                                sprite_delete(loader_payload.self_ref.sprites[loader_payload.ix_ref][loader_payload.iy_ref]);
                            }
                            
                            // Draw to surface again to ensure it loaded
                            surface_set_target(loader_payload.self_ref.surfaces[loader_payload.ix_ref][loader_payload.iy_ref]);
                            gpu_set_blendmode(bm_normal);
                            draw_sprite_ext(loader_payload.spr_ref, 0, 0, 0, 1, 1, 0, c_white, 1);
                            surface_reset_target();
                            
                            // Create the backup sprite
                            loader_payload.self_ref.sprites[loader_payload.ix_ref][loader_payload.iy_ref] = 
                                sprite_create_from_surface(
                                    loader_payload.self_ref.surfaces[loader_payload.ix_ref][loader_payload.iy_ref], 
                                    0, 0, loader_payload.self_ref.surface_width, loader_payload.self_ref.surface_height, 
                                    false, false, 0, 0
                                );
                            
                            // Now we can delete the temporary sprite
                            sprite_delete(loader_payload.spr_ref);
                        }
                        
                        var time_source = time_source_create(time_source_game, 0.1, time_source_units_seconds, finish_loading, [loader_payload]);
                        time_source_start(time_source);
                    }
                } else {
                    // Create empty backup sprite
                    sprites[ix][iy] = sprite_create_from_surface(surfaces[ix][iy], 0, 0, surface_width, surface_height, false, false, 0, 0);
                }
                
                surface_reset_target();
            }
        }
        
        return self;
    }
    
    /// @description Add debris to the appropriate surface(s)
    /// @param {sprite} _sprite - The sprite to add as debris
    /// @param {real} _index - Sprite image index
    /// @param {real} _x - X position in the room
    /// @param {real} _y - Y position in the room
    /// @param {real} _xscale - X scale (default: 1)
    /// @param {real} _yscale - Y scale (default: 1)
    /// @param {real} _rot - Rotation (default: 0)
    /// @param {real} _alpha - Alpha transparency (default: 1)
    static add_debris = function(_sprite, _index, _x, _y, _xscale = 1, _yscale = 1, _rot = 0, _alpha = 1) {
        // Get sprite dimensions
        var spr_width = sprite_get_width(_sprite) * _xscale;
        var spr_height = sprite_get_height(_sprite) * _yscale;
        var spr_xoffset = sprite_get_xoffset(_sprite) * _xscale;
        var spr_yoffset = sprite_get_yoffset(_sprite) * _yscale;
        
        // Calculate affected area
        var left = _x - spr_xoffset;
        var top = _y - spr_yoffset;
        var right = left + spr_width;
        var bottom = top + spr_height;
        
        // Get affected grid cells
        var start_ix = max(0, floor(left / surface_width));
        var end_ix = min(grid_width - 1, floor(right / surface_width));
        var start_iy = max(0, floor(top / surface_height));
        var end_iy = min(grid_height - 1, floor(bottom / surface_height));
        var can_save = (current_time > save_timer + save_delay);
        
        // Draw to each affected surface
        for (var ix = start_ix; ix <= end_ix; ix++) {
            for (var iy = start_iy; iy <= end_iy; iy++) {
                // Calculate surface boundaries
                var surf_left = ix * surface_width;
                var surf_top = iy * surface_height;
                var surf_right = surf_left + surface_width;
                var surf_bottom = surf_top + surface_height;
                
                // Save this surface
                if(can_save && is_updated[ix][iy]){
                    save_timer = current_time;
                    is_updated[ix][iy] = 0;
                    backup_surface(ix, iy);
                    needs_disk_save[ix][iy] = 1; // Mark for disk save later
                }
                
                // Check if sprite rectangle intersects with this surface
                if (!rectangle_in_rectangle(left, top, right, bottom, surf_left, surf_top, surf_right, surf_bottom)) {
                    continue; // Skip this surface if no intersection
                }
                
                // Make sure surface exists
                if (!surface_exists(surfaces[ix][iy])) {
                    restore_surface(ix, iy);
                }
                
                // Calculate draw position on this surface
                var surf_x = _x - (ix * surface_width);
                var surf_y = _y - (iy * surface_height);
                
                // Draw to surface
                surface_set_target(surfaces[ix][iy]);
                draw_sprite_ext(_sprite, _index, surf_x, surf_y, _xscale, _yscale, _rot, c_white, _alpha);
                surface_reset_target();
                
                is_updated[ix][iy] = true;
            }
        }
        
        return self;
    }
    
    /// @description Restore a surface from backup sprite or disk if needed
    /// @param {real} _ix - Grid X index
    /// @param {real} _iy - Grid Y index
    static restore_surface = function(_ix, _iy) {
        if (_ix < 0 || _ix >= grid_width || _iy < 0 || _iy >= grid_height) return false;
        
        var surf_name = name + "_" + string(_ix) + "_" + string(_iy);
        var file_path = save_directory + surf_name + ".png";
        
        // Create new surface
        surfaces[_ix][_iy] = surface_create(surface_width, surface_height);
        
        // Clear to transparent
        surface_set_target(surfaces[_ix][_iy]);
        draw_clear_alpha(c_black, 0);
        
        // If we have a backup sprite, use it
        if (sprite_exists(sprites[_ix][_iy])) {
            gpu_set_blendmode(bm_normal);
            draw_sprite_ext(sprites[_ix][_iy], 0, 0, 0, 1, 1, 0, c_white, 1);
        }
        // Otherwise load from file if it exists
        else if (file_exists(file_path)) {
            // Load the sprite from file
            var load_id = sprite_add(file_path, 1, false, false, 0, 0);
            if (sprite_exists(load_id)) {
                // Try to draw immediately
                gpu_set_blendmode(bm_normal);
                draw_sprite_ext(load_id, 0, 0, 0, 1, 1, 0, c_white, 1);
                
                // Schedule a delayed load to ensure sprite loads properly
                var self_ref = self;
                var ix_ref = _ix;
                var iy_ref = _iy;
                var spr_ref = load_id;
                var loader_payload = {self_ref: self_ref, ix_ref: ix_ref, iy_ref: iy_ref, spr_ref: spr_ref};
                
                var restore_sprite = function(loader_payload) {
                    if (!surface_exists(loader_payload.self_ref.surfaces[loader_payload.ix_ref][loader_payload.iy_ref]) || 
                        !sprite_exists(loader_payload.spr_ref)) return;
                    
                    // Create the backup sprite in our array
                    if (sprite_exists(loader_payload.self_ref.sprites[loader_payload.ix_ref][loader_payload.iy_ref])) {
                        sprite_delete(loader_payload.self_ref.sprites[loader_payload.ix_ref][loader_payload.iy_ref]);
                    }
                    
                    // Draw to surface again to ensure it loaded
                    surface_set_target(loader_payload.self_ref.surfaces[loader_payload.ix_ref][loader_payload.iy_ref]);
                    gpu_set_blendmode(bm_normal);
                    draw_sprite_ext(loader_payload.spr_ref, 0, 0, 0, 1, 1, 0, c_white, 1);
                    surface_reset_target();
                    
                    // Create the backup sprite
                    loader_payload.self_ref.sprites[loader_payload.ix_ref][loader_payload.iy_ref] = 
                        sprite_create_from_surface(
                            loader_payload.self_ref.surfaces[loader_payload.ix_ref][loader_payload.iy_ref], 
                            0, 0, loader_payload.self_ref.surface_width, loader_payload.self_ref.surface_height, 
                            false, false, 0, 0
                        );
                    
                    // Now we can delete the temporary sprite
                    sprite_delete(loader_payload.spr_ref);
                }
                
                var time_source = time_source_create(time_source_game, 0.1, time_source_units_seconds, restore_sprite, [loader_payload]);
                time_source_start(time_source);
            }
        }
        
        surface_reset_target();
        return true;
    }
    
    /// @description Backup a surface to a sprite
    /// @param {real} _ix - Grid X index
    /// @param {real} _iy - Grid Y index
    static backup_surface = function(_ix, _iy) {
        if (_ix < 0 || _ix >= grid_width || _iy < 0 || _iy >= grid_height) return false;
        if (!surface_exists(surfaces[_ix][_iy])) return false;
        
        // Delete old backup if it exists
        if (sprite_exists(sprites[_ix][_iy])) {
            sprite_delete(sprites[_ix][_iy]);
        }
        
        // Create new backup sprite from surface
        sprites[_ix][_iy] = sprite_create_from_surface(surfaces[_ix][_iy], 0, 0, surface_width, surface_height, false, false, 0, 0);
        
        return true;
    }
    
    /// @description Save surface to disk
    /// @param {real} _ix - Grid X index
    /// @param {real} _iy - Grid Y index
    static save_surface = function(_ix, _iy) {
        if (_ix < 0 || _ix >= grid_width || _iy < 0 || _iy >= grid_height) return false;
        if (!sprite_exists(sprites[_ix][_iy])) return false;
        
        var surf_name = name + "_" + string(_ix) + "_" + string(_iy);
        var file_path = save_directory + surf_name + ".png";
        
        // Save sprite to disk
        sprite_save(sprites[_ix][_iy], 0, file_path);
        needs_disk_save[_ix][_iy] = 0; // Reset disk save flag
        
        return true;
    }
    
    /// @description Draw all surfaces at their correct positions
    static draw = function() {
        for (var ix = 0; ix < grid_width; ix++) {
            for (var iy = 0; iy < grid_height; iy++) {
                // Skip if doesn't exist
                if (!surface_exists(surfaces[ix][iy])) {
                    restore_surface(ix, iy);
                }
                
                // Draw at position
                var pos_x = ix * surface_width;
                var pos_y = iy * surface_height;
                draw_surface(surfaces[ix][iy], pos_x, pos_y);
            }
        }
        
        return self;
    }
    
    /// @description Clear all surfaces (for new game)
    static clear_all = function() {
        for (var ix = 0; ix < grid_width; ix++) {
            for (var iy = 0; iy < grid_height; iy++) {
                // Make sure surface exists
                if (!surface_exists(surfaces[ix][iy])) {
                    surfaces[ix][iy] = surface_create(surface_width, surface_height);
                }
                
                // Clear surface
                surface_set_target(surfaces[ix][iy]);
                draw_clear_alpha(c_black, 0);
                surface_reset_target();
                
                // Clear backup sprite
                if (sprite_exists(sprites[ix][iy])) {
                    sprite_delete(sprites[ix][iy]);
                }
                
                // Create new empty backup
                sprites[ix][iy] = sprite_create_from_surface(surfaces[ix][iy], 0, 0, surface_width, surface_height, false, false, 0, 0);
                
                // Save empty to disk
                needs_disk_save[ix][iy] = 1;
                save_surface(ix, iy);
            }
        }
        
        return self;
    }
    
    /// @description Save all needed surfaces to disk
    static save_all_to_disk = function() {
        for (var ix = 0; ix < grid_width; ix++) {
            for (var iy = 0; iy < grid_height; iy++) {
                // Save to disk if needed
                if (needs_disk_save[ix][iy]) {
                    save_surface(ix, iy);
                }
                // Backup to memory if updated
                if (is_updated[ix][iy] && surface_exists(surfaces[ix][iy])) {
                    backup_surface(ix, iy);
                    is_updated[ix][iy] = 0;
                }
            }
        }
        return self;
    }
    
    /// @description Free all surfaces from memory
    static free = function() {
        // First, make sure everything is backed up and saved
        for (var ix = 0; ix < grid_width; ix++) {
            for (var iy = 0; iy < grid_height; iy++) {
                // Backup to sprite if updated
                if (is_updated[ix][iy] && surface_exists(surfaces[ix][iy])) {
                    backup_surface(ix, iy);
                    is_updated[ix][iy] = 0;
                    needs_disk_save[ix][iy] = 1;
                }
                
                // Save to disk if needed
                if (needs_disk_save[ix][iy]) {
                    save_surface(ix, iy);
                }
                
                // Free the surface
                if (surface_exists(surfaces[ix][iy])) {
                    surface_free(surfaces[ix][iy]);
                }
                
                // Free the sprite (after saving)
                if (sprite_exists(sprites[ix][iy])) {
                    sprite_delete(sprites[ix][iy]);
                }
            }
        }
        
        return self;
    }
    
    /// @description Check if a specific pixel has any debris
    /// @param {real} _x - X position in the room
    /// @param {real} _y - Y position in the room
    /// @returns {bool} - True if the pixel has debris
    static has_debris_at = function(_x, _y) {
        // Convert room coordinates to grid coordinates
        var ix = floor(_x / surface_width);
        var iy = floor(_y / surface_height);
        
        // Check if in bounds
        if (ix < 0 || ix >= grid_width || iy < 0 || iy >= grid_height) return false;
        
        // Make sure surface exists
        if (!surface_exists(surfaces[ix][iy])) {
            restore_surface(ix, iy);
        }
        
        // Get local coordinates
        var local_x = _x - (ix * surface_width);
        var local_y = _y - (iy * surface_height);
        
        // Get pixel alpha
        surface_set_target(surfaces[ix][iy]);
        var alpha = surface_getpixel_ext(surfaces[ix][iy], local_x, local_y) & 255;
        surface_reset_target();
        
        return alpha > 0;
    }

}



