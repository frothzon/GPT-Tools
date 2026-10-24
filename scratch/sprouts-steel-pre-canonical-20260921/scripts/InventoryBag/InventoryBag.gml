/// @desc InventoryBag constructor for managing game inventories
/// @param {string} _name The display name of the bag
/// @param {real} _x Starting X position
/// @param {real} _y Starting Y position
/// @param {real} _width Width of an individual slot
/// @param {real} _height Height of an individual slot
/// @param {real} _hcount Number of horizontal slots
/// @param {real} _vcount Number of vertical slots
function InventoryBag(_name, _x, _y, _width, _height, _hcount, _vcount) constructor {
    // --- Variables ---
    name = _name;
    var _slot_count = _hcount * _vcount;
    items = array_create(_slot_count, -1);
    quantity = array_create(_slot_count, 0);
    
    // NEW: Property for each individual slot (default 255 = All types)
    slotMasks = array_create(_slot_count, eITEM_TYPE.ANY);
    slotSprite = array_create(_slot_count, TEST_SPR);
    
    // In constructors, 'self' is the pointer. 
    // We keep 'bag_id' if you need it for external systems like your dragSystem.
    bag_id = self; 

    drawGrid = create_display_grid(_x, _y, _width, _height, _hcount, _vcount);
    
    padding = 8;
    visible = true;
    hoverIndex = -1;
    drag = false;
    dragPosition = [0, 0];
    tooltipText = "";
    keycode = TOGGLE_KEY;
    locked = true;
    selected = -1;

    // --- Static Methods (Shared in memory across all instances) ---

    static onClose = function() {
        visible = !visible;
    };

    static onHover = function() {
        // Implementation for hover effects
    };
    
    /// @desc Sets a specific slot to only accept certain types
    static setSlotMask = function(_index, _mask, _sprite=TEST_SPR) {
        if (_index >= 0 && _index < array_length(slotMasks)) {
            slotMasks[_index] = _mask;
            slotSprite[_index] = _sprite;
        }
    };

    static findItem = function(_item_name) {
        var _len = array_length(items);
        for (var i = 0; i < _len; i++) {
            if (items[i] != -1 && items[i].name == _item_name) {
                return i;
            }
        }
        return -1;
    };

    static findQuantity = function(_item_name) {
        var _index = findItem(_item_name);
        if (_index == -1) return 0;
        return quantity[_index];
    };

    static findEmpty = function(_type=255) {
        var _len = array_length(items);
        for (var i = 0; i < _len; i++) {
            // Check if slot is empty AND mask matches item type
            if (items[i] == -1 && (slotMasks[i] & _type)) return i;
        }
        return -1;
    };

    static addItem = function(_item, _amt) {
        var _find = findItem(_item.name);
        if (_find == -1) {
            _find = findEmpty(_item.type);
        }
        
        if (_find == -1) return -1; // Bag full

        if (items[_find] == -1) {
            items[_find] = _item;
            /// if item is removed, 
            /// the amount may be set to an unknown quantity
            /// we need to reset it
            quantity[_find] = 0;
        }
        
        quantity[_find] += _amt;
        
        if (quantity[_find] < 1) {
            quantity[_find] = 0;
            items[_find] = -1;
        }
        return _find;
    };

    static update = function() {
        if (!visible) return;
        
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        
        // --- Gamepad-Friendly Input Detection ---
        var _pressed  = mouse_check_button_pressed(mb_left) || INPUT_MGR.check_pressed("action");
        var _released = mouse_check_button_released(mb_left) || INPUT_MGR.check_released("action");
        var _cancel   = mouse_check_button_pressed(mb_right) || gamepad_button_check_pressed(0, gp_face2);

        drawGrid.update();
        hoverIndex = drawGrid.pointToIndex(_mx, _my);

        if (hoverIndex != -1) {
            IN_UI = true;
            if (global.dragSystem.dragMode) {
                var _heldItem = global.dragSystem.dragItem;

                // 1. DROP LOGIC (On Release)
                if (_released && _heldItem != -1) {
                    var _targetMask = slotMasks[hoverIndex];
                    var _displacedItem = items[hoverIndex];
                    
                    var _canFitTarget = (_heldItem.type & _targetMask);
                    var _canFitSource = true;
                    if (_displacedItem != -1) {
                        var _srcBag = global.dragSystem.sourceBag;
                        var _srcIdx = global.dragSystem.sourceIndex;
                        _canFitSource = (_displacedItem.type & _srcBag.slotMasks[_srcIdx]);
                    }

                    if (_canFitTarget && _canFitSource) {
                        var _srcBag = global.dragSystem.sourceBag;
                        var _srcIdx = global.dragSystem.sourceIndex;
                        
                        _srcBag.items[_srcIdx] = _displacedItem;
                        _srcBag.quantity[_srcIdx] = (_displacedItem != -1) ? quantity[hoverIndex] : 0;
                        
                        items[hoverIndex] = global.dragSystem.dragItem;
                        quantity[hoverIndex] = global.dragSystem.dragQty;
                        
                        global.dragSystem.dragItem = -1;
                        global.dragSystem.dragQty = 0;
                        global.dragSystem.sourceBag = -1;
                        global.dragSystem.sourceIndex = -1;
                    }
                } 
                // 2. PICKUP LOGIC (On Press)
                else if (_pressed && _heldItem == -1) {
                    if (items[hoverIndex] != -1) {
                        global.dragSystem.dragItem = items[hoverIndex];
                        global.dragSystem.dragQty = quantity[hoverIndex];
                        global.dragSystem.sourceBag = bag_id;
                        global.dragSystem.sourceIndex = hoverIndex;
                        
                        items[hoverIndex] = -1;
                        quantity[hoverIndex] = 0;
                        selected = -1;
                    }
                }
            } else if (_pressed) {
                selected = hoverIndex;
            }
        }

        // --- Cancel Logic (Right Click or Gamepad 'B' to Return) ---
        if (_cancel && global.dragSystem.dragItem != -1) {
            var _srcBag = global.dragSystem.sourceBag;
            var _srcIdx = global.dragSystem.sourceIndex;
            
            _srcBag.items[_srcIdx] = global.dragSystem.dragItem;
            _srcBag.quantity[_srcIdx] = global.dragSystem.dragQty;
            
            global.dragSystem.dragItem = -1;
            global.dragSystem.dragQty = 0;
        }
    };
    
    static draw = function() {
        if (!visible) return;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        var _gridRect = drawGrid.gridRect();

        // Background
        draw_sprite_stretched(TEST_BAG_SPR, 0, _gridRect.x - padding, _gridRect.y - padding * 2, _gridRect.w + padding * 2, _gridRect.h + padding * 3);
        
        // Header Text
        draw_text_outline(drawGrid.x, drawGrid.y - string_height(name), name);
        
        var _tooltipText = "";

        drawGrid.forEach(function(_ind, _box) {
            var _img = 0;
            var _col = c_white;
            
            // Highlight logic
            if (hoverIndex == _ind) _img = 1;
            if (_img == 0 && selected == _ind) _img = 2;

            // NEW: Source Highlight (If this slot is where we picked up the item)
            var _isSource = (global.dragSystem.dragItem != -1 && global.dragSystem.sourceBag == bag_id && global.dragSystem.sourceIndex == _ind);
            if (_isSource) _img = 2;

            // NEW: Compatibility Coloring (Show if held item can fit here)
            if (global.dragSystem.dragItem != -1 && hoverIndex == _ind) {
                _col = (global.dragSystem.dragItem.type & slotMasks[_ind]) ? c_lime : c_red;
            }
                
            draw_sprite_stretched_ext(slotSprite[_ind], _img, _box.x, _box.y, _box.w, _box.h, _col, 1);
            
            // NEW: Draw "Ghost" of item in source slot
            if (_isSource) {
                draw_sprite_stretched_ext(global.dragSystem.dragItem.sprite, global.dragSystem.dragItem.index, _box.x, _box.y, _box.w, _box.h, c_white, 0.4);
            }
            
            if (items[_ind] != -1) {
                draw_sprite_stretched(items[_ind].sprite, items[_ind].index, _box.x, _box.y, _box.w, _box.h);
                if (quantity[_ind] > 1) {
                    draw_text_outline(_box.x + 1, _box.y + 1, string(quantity[_ind]), c_black, c_yellow);
                }
                
                if (hoverIndex == _ind) {
                    var _dataInfo = struct_get_names(items[_ind].data);
                    var _txt = items[_ind].name;
                    if (is_array(_dataInfo)) {
                        for (var n = 0; n < array_length(_dataInfo); n++) {
                            _txt += $"\n+{items[_ind].data[$ _dataInfo[n]]} {_dataInfo[n]} "
                        }
                    }
                    _tooltipText = _txt;
                }
            } else if (!_isSource) {
                draw_text_outline(_box.x + 2, _box.y + 2, _ind + 1, c_black, c_ltgray);
            }
        });

        // Draw Exit Button
        if (!locked) {
            var _ex = _gridRect.x + _gridRect.w - 8;
            var _ey = _gridRect.y - 16;
            var _hoverExit = point_in_rectangle(_mx, _my, _ex, _ey, _ex + 16, _ey + 16);
            draw_sprite_stretched(TEST_EXIT, _hoverExit, _ex, _ey, 16, 16);
        }

        // Tooltip & Gamepad Indicator
        if (_tooltipText != "" || (global.dragSystem.dragItem != -1 && gamepad_is_connected(0))) {
            var _displayText = _tooltipText;
            
            // Add "Drop" button prompt if dragging with gamepad
            if (global.dragSystem.dragItem != -1 && gamepad_is_connected(0)) {
                 _displayText += (_displayText != "" ? "\n" : "") + "Press (A) to Drop";
            }

            var _tw = string_width(_displayText);
            var _th = string_height(_displayText);
            var _tx = 4;
            var _ty = display_get_gui_height() - _th - 4;
            
            draw_sprite_stretched(TTIP_SPRITE, 0, _tx - 2, _ty - 2, _tw + 4, _th + 4);
            draw_text(_tx, _ty, _displayText);
        }
    };
}