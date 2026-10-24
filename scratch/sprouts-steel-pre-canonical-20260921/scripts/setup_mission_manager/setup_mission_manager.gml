function setup_mission_manager(){
	/// @description Initialize the Mission Manager and start a quest

	// Run the setup function from the MissionSystem script to establish the singleton
	mission_manager_setup();

	// NEW: Variable to track which active mission is currently selected for UI display.
	// It is an index into the self.active_missions array.
	self.tracked_mission_index = -1;

	// For demonstration, let's automatically activate our first mission.
	// In a real game, you might do this when a player talks to an NPC.
	if (get_mission_status("SQ_001_Rubble") == MISSION_STATUS.NotStarted)
	{
	    activate_mission("SQ_001_Rubble");
	}	
}