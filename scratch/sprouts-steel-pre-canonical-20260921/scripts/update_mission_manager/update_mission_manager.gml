function update_mission_manager(){

	// 1. Update Mission Timers (Original Code)
	mission_manager_update();

	// 2. NEW: Mission Tracking Input Logic (Press TAB to cycle active mission)
	var _active_count = array_length(self.active_missions);

	if (_active_count > 0 && keyboard_check_pressed(vk_tab)) {
	    // Increment the index and wrap around
	    self.tracked_mission_index++;
	    if (self.tracked_mission_index >= _active_count) {
	        self.tracked_mission_index = 0;
	    }
	}

	// 3. NEW: If a mission just became active and none are tracked, track the first one.
	if (self.tracked_mission_index == -1 && _active_count > 0) {
	    self.tracked_mission_index = 0;
	} 
	// 4. NEW: If there are no active missions, ensure index is -1
	else if (_active_count == 0) {
	    self.tracked_mission_index = -1;
	}	
}