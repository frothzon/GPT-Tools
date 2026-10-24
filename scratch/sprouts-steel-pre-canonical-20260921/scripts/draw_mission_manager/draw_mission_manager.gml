function draw_mission_manager(){

	var _active_count = array_length(self.active_missions);
	// If there are no active missions, or none are being tracked, no need to draw anything.
	if (_active_count == 0 || self.tracked_mission_index == -1) {
	    exit;
	}

	// --- Set up drawing variables ---
	var _display_w = display_get_gui_width();
	var _margin = 20; // Padding from the edge of the screen
	var _box_w = 400; // Width of the mission box
	var _x1 = _display_w - _box_w - _margin;
	var _y1 = _margin;
	var _line_height = 24;
	var _text_padding = 10;
	var _title_font = -1; // Replace with your title font if you have one
	var _body_font = -1; // Replace with your body font

	// --- Draw the list of Active Missions (The "Mission Tracker") ---
	draw_set_font(_body_font);
	draw_set_halign(fa_right);
	draw_set_valign(fa_top);
	var _list_x = _display_w - _margin;
	var _list_y = _margin;

	draw_set_color(c_white);
	draw_text(_list_x, _list_y, "Active Missions (Press TAB)");
	_list_y += _line_height;

	for (var i = 0; i < _active_count; i++) {
	    var _mission_name = self.active_missions[i].name;
	    var _is_tracked = (i == self.tracked_mission_index);
    
	    // Highlight the currently tracked mission
	    draw_set_color(_is_tracked ? c_yellow : c_gray);
	    draw_set_alpha(_is_tracked ? 1.0 : 0.7);
    
	    var _indicator = _is_tracked ? " >> " : " - ";
	    draw_text(_list_x, _list_y, _indicator + _mission_name);
	    _list_y += _line_height;
	}

	// --- Draw the detailed UI for the TRACKED Mission ---
	var _mission = self.active_missions[self.tracked_mission_index];

	// Reset starting Y for the detailed box, positioning it below the mission list
	var _list_height = _line_height * (_active_count + 1);
	_y1 = _margin + _list_height + _margin;

	// Calculate the required height for the box based on content
	var _box_h = _line_height * 2; // For title and description
	_box_h += (array_length(_mission.objectives) * _line_height); // Add space for each objective
	_box_h += _text_padding * 2;

	// --- Draw the background box ---
	draw_set_color(c_black);
	draw_set_alpha(0.7);
	draw_rectangle(_x1, _y1, _x1 + _box_w, _y1 + _box_h, false);
	draw_set_alpha(1.0); // Reset alpha

	// --- Draw Mission Title ---
	draw_set_font(_title_font);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_color(c_yellow);
	draw_text(_x1 + _text_padding, _y1 + _text_padding, _mission.name);
	var _current_y = _y1 + _text_padding + _line_height;

	// --- Draw Mission Objectives ---
	draw_set_font(_body_font);
	draw_set_color(c_white);
	for (var j = 0; j < array_length(_mission.objectives); j++) {
	    var _obj = _mission.objectives[j];
	    var _display_text = _obj.get_display_string();
    
	    // If the objective is complete, draw it in gray
	    if (_obj.is_completed) {
	        draw_set_color(c_gray);
	    }
    
	    draw_text(_x1 + _text_padding, _current_y, _display_text);
	    _current_y += _line_height;
    
	    // Reset color for the next objective
	    draw_set_color(c_white);
	}

	// Reset drawing settings to default after drawing the UI
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_color(c_white);	
}