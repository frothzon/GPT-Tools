/// @desc Initialises the global drag system and item constants
function init_dragSystem() {
    // Powers of 2 for Bitmasking
    enum eITEM_TYPE {
        ANY             = 65535,
        GENERAL         = 1,
        WEAPON          = 2,
        ARMOR           = 4,
        CONSUMABLE      = 8,
        QUEST           = 16,
        MATERIAL        = 32,
        BOTTLED         = 64,
        SEED            = 128,
        TOOL_HOE        = 256,
        STRUCTURE       = 512
        // Add more up to 128 for an 8-bit mask
    }

    global.dragSystem = {
        dragItem: -1,
        dragQty: -1,
        // Source Tracking
        sourceBag: -1,   // The InventoryBag instance we picked from
        sourceIndex: -1, // The array index we picked from
        dragMode: true,
        showQty: false,
        
        set: function(_bag, _index) {
            bag = _bag;
            index = _index;
        },
        
        draw: function() {
            if (dragItem != -1) {
                var _mx = device_mouse_x_to_gui(0);
                var _my = device_mouse_y_to_gui(0);
                // Draw the item currently being held by the mouse
                draw_sprite_stretched(dragItem.sprite, dragItem.index, _mx - 16, _my - 16, 32, 32); 
                
                // Draw quantity if greater than 1
                if (dragQty > 1 && showQty) {
                    draw_set_halign(fa_right);
                    draw_text_outline(_mx + 16, _my + 8, string(dragQty));
                    draw_set_halign(fa_left);
                }
            }
        }
    };

    #macro TEST_SPR spr_invBox
    #macro TEST_BAG_SPR spr_invContainer
    #macro TEST_EXIT spr_exit
    #macro TOGGLE_KEY ord("P")
    #macro ITEM_SPRITE spr_items
    #macro TTIP_SPRITE spr_tooltip
}