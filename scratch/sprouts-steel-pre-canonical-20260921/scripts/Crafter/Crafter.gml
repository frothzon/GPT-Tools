/**
 * @function Crafter
 * @brief A Crafting system that manages recipes, inventory deduction, and a timed production queue.
 */
function Crafter() constructor {
    self.title = "Crafting";
    self.sub = "Materials Required";
    self.buttons = [];
    self.recipe_buttons = []; 
    
    self.selected_recipe = -1;
    self.padding = 16;
    self.menu_w = 420;
    self.menu_h = 160; // Recipe list height

    // Queue System
    self.queue = new CraftingQueue();
    self.status_h = 100; // Height of the status panel below the list

    // Gamepad Navigation
    self.gp_nav_index = 0;
    self.gp_nav_cooldown = 0;
    self.gp_nav_cooldown_max = 10;

    // Scrolling Logic
    self.max_visible = 3;
    self.scroll_y = 0;        
    self.target_scroll_y = 0; 
    self.scrollbar = undefined;

    static add_button = function(_name, _craftItem, _materials, _quantities, _duration = 180) {
        var _ind = array_length(self.buttons);
        var _recipe = {
            name: _name,
            craft: _craftItem,
            materials: _materials,
            quantities: _quantities,
            duration: _duration
        };
        
        array_push(self.buttons, _recipe);
        
        var _btn = new Button(0, 0, 80, 20, "CRAFT", method(self, function(_recipe_idx) {
            if (self.remove_quantities(_recipe_idx)) {
                var _recipe_data = self.buttons[_recipe_idx];
                self.queue.add_task(_recipe_data, _recipe_data.duration);
                SCT.debug_log("Queued: " + _recipe_data.name);
                SOUND_MGR.play_ui(snd_interact);
            }
        }), _ind);
        
        array_push(self.recipe_buttons, _btn);
        self.refresh_scrollbar();
        
        return _ind;
    };

    static refresh_scrollbar = function() {
        var _count = array_length(self.buttons);
        if (_count > self.max_visible) {
            var _max_offset = _count - self.max_visible;
            self.scrollbar = new VerticalSlider(
                0, 0, 0, 0, _max_offset, _max_offset, 
                method(self, function(_val) {
                    var _max_offset = array_length(self.buttons) - self.max_visible;
                    self.target_scroll_y = _max_offset - _val;
                })
            );
        } else {
            self.scrollbar = undefined;
            self.target_scroll_y = 0;
            self.scroll_y = 0;
        }
    };

    static validate_quantities = function(_index) {
        if (_index < 0 || _index >= array_length(self.buttons)) {
            return { can_craft: false, held_quantities: [] };
        }
        
        var _recipe = self.buttons[_index];
        var _held = [];
        var _possible = true;
        
        for (var i = 0; i < array_length(_recipe.materials); i++) {
            var _mat_name = ITEMS[_recipe.materials[i]].name;
            var _req_qty = _recipe.quantities[i];
            var _total = BACKPACK.findQuantity(_mat_name) + GEAR.findQuantity(_mat_name);
            _held[i] = _total;
            if (_total < _req_qty) _possible = false;
        }
        
        return { can_craft: _possible, held_quantities: _held };
    };

    static remove_quantities = function(_index) {
        var _val = self.validate_quantities(_index);
        if (!_val.can_craft) return false;
        
        var _recipe = self.buttons[_index];
        for (var i = 0; i < array_length(_recipe.materials); i++) {
            var _item = ITEMS[_recipe.materials[i]];
            var _amount_needed = _recipe.quantities[i];
            
            var _in_bp = BACKPACK.findQuantity(_item.name);
            var _take_bp = min(_in_bp, _amount_needed);
            
            if (_take_bp > 0) {
                BACKPACK.addItem(_item, -_take_bp);
                _amount_needed -= _take_bp;
            }
            if (_amount_needed > 0) {
                GEAR.addItem(_item, -_amount_needed);
            }
        }
        return true;
    };

    static show_craft_menu = function(_sprite, _xto, _yto, _w, _h, _mx, _my) {
        var _count = array_length(self.buttons);
        if (_count == 0) return -1;
        
        var _item_h = _h / self.max_visible;
        var _selected = -1;
        var _menu_left = _xto - _w/2;

        // --- GAMEPAD NAVIGATION LOGIC ---
        if (gamepad_is_connected(0)) {
            var _v = (gamepad_axis_value(0, gp_axislv) > 0.5) - (gamepad_axis_value(0, gp_axislv) < -0.5);
            if (_v == 0) _v = gamepad_button_check_pressed(0, gp_padd) - gamepad_button_check_pressed(0, gp_padu);

            if (_v != 0 && self.gp_nav_cooldown <= 0) {
                self.gp_nav_index = clamp(self.gp_nav_index + _v, 0, _count - 1);
                self.gp_nav_cooldown = self.gp_nav_cooldown_max;
                
                var _max_scroll = max(0, _count - self.max_visible);
                if (self.gp_nav_index < self.target_scroll_y) {
                    self.target_scroll_y = self.gp_nav_index;
                } else if (self.gp_nav_index >= self.target_scroll_y + self.max_visible) {
                    self.target_scroll_y = self.gp_nav_index - (self.max_visible - 1);
                }
                self.target_scroll_y = clamp(self.target_scroll_y, 0, _max_scroll);
                
                if (self.scrollbar != undefined) {
                    self.scrollbar.set_value(_max_scroll - self.target_scroll_y);
                }
            }
            
            var _rel_pos_nav = self.gp_nav_index - self.scroll_y;
            var _ry_nav = _yto + (_rel_pos_nav * _item_h);
            var _win_w = window_get_width();
            var _win_h = window_get_height();
            var _gui_w = display_get_gui_width();
            var _gui_h = display_get_gui_height();
            var _snap_x = _menu_left + _w - 40 - 6; 
            var _snap_y = _ry_nav + (_item_h / 2);
            window_mouse_set((_snap_x / _gui_w) * _win_w, (_snap_y / _gui_h) * _win_h);
        }
        if (self.gp_nav_cooldown > 0) self.gp_nav_cooldown--;
        
        var _diff = self.target_scroll_y - self.scroll_y;
        if (abs(_diff) > 0.001) {
            self.scroll_y += _diff * 0.2; 
        } else {
            self.scroll_y = self.target_scroll_y;
        }

        if (point_in_rectangle(_mx, _my, _menu_left, _yto, _menu_left + _w, _yto + _h)) {
            var _wheel = mouse_wheel_down() - mouse_wheel_up();
            if (_wheel != 0) {
                var _max_scroll = max(0, _count - self.max_visible);
                self.target_scroll_y = clamp(self.target_scroll_y + _wheel, 0, _max_scroll);
                if (self.scrollbar != undefined) {
                    self.scrollbar.set_value(_max_scroll - self.target_scroll_y);
                }
            }
        }

        if (self.scrollbar != undefined) {
            self.scrollbar.x = _menu_left + _w + 15;
            self.scrollbar.y = _yto;
            self.scrollbar.h = _h;
            self.scrollbar.update();
        }

        for (var i = 0; i < _count; i++) {
            var _rel_pos = i - self.scroll_y;
            var _ry = _yto + (_rel_pos * _item_h);

            if (_ry + _item_h < _yto || _ry > _yto + _h) continue;

            var _recipe = self.buttons[i];
            var _btn = self.recipe_buttons[i];
            var _val = self.validate_quantities(i);
            
            var _icon_pad = 6;
            var _icon_size = _item_h - (_icon_pad * 2);
            var _btn_w = (gamepad_is_connected(0)) ? 80 : 60;
            var _btn_h = _item_h * 0.7;
            
            var _in_view = (_ry >= _yto - 5 && _ry + _item_h <= _yto + _h + 5);
            var _hover = _in_view && point_in_rectangle(_mx, _my, _menu_left, _ry, _menu_left + _w, _ry + _item_h);
            
            if (_hover) _selected = i;
            
            var _base_col = _val.can_craft ? c_white : c_gray;
            var _alpha = 1.0;
            
            if (_ry < _yto) _alpha = 1 - ((_yto - _ry) / _item_h);
            if (_ry + _item_h > _yto + _h) _alpha = 1 - (((_ry + _item_h) - (_yto + _h)) / _item_h);

            draw_sprite_stretched_ext(_sprite, 0, _menu_left, _ry, _w, _item_h, _base_col, _alpha);
            
            var _item_data = ITEMS[_recipe.craft];
            draw_sprite_stretched_ext(_item_data.sprite, _item_data.index, _menu_left + _icon_pad, _ry + _icon_pad, _icon_size, _icon_size, c_white, _alpha);
            
            var _text_area_x = _menu_left + _icon_size + (_icon_pad * 3);
            draw_set_halign(fa_left);
            draw_set_valign(fa_bottom);
            draw_text_outline_transformed(_text_area_x, _ry + (_item_h / 2) - 1, _recipe.name, c_black, _base_col, _alpha);
            
            draw_set_valign(fa_top);
            var _mat_x = _text_area_x;
            for (var m = 0; m < array_length(_recipe.materials); m++) {
                var _m_item = ITEMS[_recipe.materials[m]];
                var _has = _val.held_quantities[m];
                var _needs = _recipe.quantities[m];
                var _m_col = (_has >= _needs) ? _base_col : c_red;
                var _m_str = string(_has) + "/" + string(_needs) + " " + _m_item.name;
                draw_text_outline_transformed(_mat_x, _ry + (_item_h / 2) + 1, _m_str, c_black, _m_col, _alpha);
                _mat_x += string_width(_m_str) + 8;
            }
            
            _btn.set_position(_menu_left + _w - _btn_w - _icon_pad, _ry + (_item_h - _btn_h)/2);
            _btn.w = _btn_w;
            _btn.h = _btn_h;
            _btn.enabled = _val.can_craft && _in_view;
            _btn.text = (gamepad_is_connected(0)) ? "(A)CRAFT" : "CRAFT";

            if (_alpha > 0.5) {
                if (_btn.hovered && INPUT_MGR.check_pressed("action")) {
                     _btn.pressed = true;
                     _btn.click_pending = true;
                     _btn.delay_timer = 5;
                    SOUND_MGR.play_ui(snd_interact);
                }
                _btn.update();
            }
            _btn.draw_ext(_alpha);
        }
        
        if (self.scrollbar != undefined) self.scrollbar.draw();
        return _selected;
    };

    /**
     * @function draw_status_panel
     * @brief Renders the crafting queue, progress bars, and upcoming items.
     */
    static draw_status_panel = function(_x, _y, _w) {
        var _left = _x - _w/2;
        var _q_len = array_length(self.queue.tasks);
        
        // Draw Background Panel
        draw_sprite_stretched_ext(spr_invBox, 0, _left, _y, _w, self.status_h, c_white, 0.8);
        
        if (_q_len == 0) {
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_text_outline(_x, _y + self.status_h/2, "STATION IDLE", c_black, c_dkgray);
            return;
        }

        var _cur = self.queue.tasks[0];
        var _item = ITEMS[_cur.recipe.craft];
        var _padding = 8;
        
        // 1. Current Item Icon & Progress
        var _icon_size = 40;
        draw_sprite_stretched(_item.sprite, _item.index, _left + _padding, _y + _padding, _icon_size, _icon_size);
        
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_text_outline(_left + _padding + _icon_size + 8, _y + _padding, "Crafting: " + _item.name, c_black, c_white);
        
        // Current Progress Bar
        var _bar_w = _w - (_padding * 2) - _icon_size - 16;
        var _bar_x = _left + _padding + _icon_size + 8;
        var _bar_y = _y + _padding + 22;
        var _bar_h = 12;
        var _prog = self.queue.get_current_progress();
        
        draw_sprite_stretched_ext(spr_invBox, 0, _bar_x, _bar_y, _bar_w, _bar_h, c_black, 1);
        draw_sprite_stretched_ext(spr_invBox, 0, _bar_x + 1, _bar_y + 1, (_bar_w - 2) * _prog, _bar_h - 2, c_lime, 1);

        // 2. Queue Waitlist (Icons only)
        var _list_y = _y + _padding + 45;
        draw_text_outline(_left + _padding, _list_y, "Next Up:", c_black, c_silver);
        
        var _qx = _left + _padding + 70;
        for (var i = 1; i < min(_q_len, 6); i++) {
            var _q_item = ITEMS[self.queue.tasks[i].recipe.craft];
            draw_sprite_stretched(_q_item.sprite, _q_item.index, _qx, _list_y - 4, 24, 24);
            _qx += 28;
        }
        if (_q_len > 6) draw_text_outline(_qx, _list_y, "...", c_black, c_white);

        // 3. Global Queue Progress Bar
        var _total_bar_y = _y + self.status_h - 18;
        var _total_prog = self.queue.get_total_progress();
        draw_set_halign(fa_center);
        draw_text_transformed(_x, _total_bar_y - 12, "Total Completion", 0.7, 0.7, 0);
        
        draw_sprite_stretched_ext(spr_invBox, 0, _left + _padding, _total_bar_y, _w - (_padding * 2), 10, c_black, 1);
        draw_sprite_stretched_ext(spr_invBox, 0, _left + _padding + 1, _total_bar_y + 1, (_w - (_padding * 2) - 2) * _total_prog, 8, c_yellow, 1);
    };

    static update = function() {
        self.queue.update();
    };

    static draw = function(_x, _y) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        
        // High Level Logic Control
        self.update();
        
        draw_set_halign(fa_center);
        draw_set_font(fnt_default_ui_title);
        draw_text_outline(_x, _y - 26, self.title, c_black, c_yellow);
        
        draw_set_font(fnt_default_ui);
        // Recipe List
        self.selected_recipe = self.show_craft_menu(spr_invBox, _x, _y, self.menu_w, self.menu_h, _mx, _my);
        
        // Queue Status Panel (Offset below the recipe list)
        self.draw_status_panel(_x, _y + self.menu_h + 10, self.menu_w);
        
        draw_set_font(-1);
    };
}