/// @desc player_change_weapon();
function player_change_weapon() {
    // 1. Keyboard Input (1-9 keys)
    for (var i = 1; i <= 9; i++) {
        var _key = ord(string(i));
        if (keyboard_check_pressed(_key)) {
            GEAR.selected = i - 1;
        }
    }
    // Check '0' for the 10th slot
    if (keyboard_check_pressed(ord("0"))) {
        GEAR.selected = 9;
    }

    // 2. Gamepad Input (Shoulder buttons)
    if (gamepad_is_connected(0)) {
        // L1 (Shoulder Left) counts down
        if (gamepad_button_check_pressed(0, gp_shoulderl)) {
            GEAR.selected--;
            SOUND_MGR.play_ui(snd_tick);
        }
        
        // R1 (Shoulder Right) counts up
        if (gamepad_button_check_pressed(0, gp_shoulderr)) {
            GEAR.selected++;
            SOUND_MGR.play_ui(snd_tick);
        }
        
        if(GEAR.selected > array_length(GEAR.items) - 1){
            GEAR.selected = 0;
        }
        if(GEAR.selected < 0){
            GEAR.selected = array_length(GEAR.items) - 1;
        }
    }
}