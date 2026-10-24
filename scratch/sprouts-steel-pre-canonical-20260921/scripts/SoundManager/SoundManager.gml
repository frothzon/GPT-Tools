/**
 * Global Sound Manager Constructor
 * Centralizes all audio logic, volume control, and persistence.
 */

function SoundManager() constructor {
    // --- Properties ---
    
    // Volume Levels (0.0 to 1.0)
    volumes = {
        master: 1.0,
        music:  0.8,
        sfx:    1.0,
        ui:     0.9
    };
    
    current_music_inst = -1;
    current_music_id   = -1;
    
    save_filename = "settings_audio.json";

    // --- Core Methods ---

    /**
     * Initializes and sets master gain. Usually called once.
     */
    static init = function() {
        load_settings();
        apply_volumes();
    };

    /**
     * Updates the actual GameMaker audio engine with our internal volume levels.
     */
    static apply_volumes = function() {
        audio_set_master_gain(0, volumes.master);
        // If you use Audio Groups, you would apply them here:
        // audio_group_set_gain(audiogroup_music, volumes.music, 0);
        // audio_group_set_gain(audiogroup_default, volumes.sfx, 0);
        
        // If playing music, update its gain immediately
        if (audio_is_playing(current_music_inst)) {
            audio_sound_gain(current_music_inst, volumes.music, 0);
        }
    };

    /**
     * Plays background music. Handles fading out previous tracks.
     * @param {Asset.GMSound} _sound_id The music asset to play.
     * @param {Bool} _loop Whether to loop the track.
     * @param {Real} _fade_ms Time in milliseconds to fade in.
     */
    static play_music = function(_sound_id, _loop = true, _fade_ms = 1000) {
        if (_sound_id == current_music_id) return; // Already playing

        // Fade out current music if it exists
        if (audio_is_playing(current_music_inst)) {
            audio_sound_gain(current_music_inst, 0, _fade_ms);
            // We don't stop it immediately; the engine handles the gain ramp.
        }

        current_music_id = _sound_id;
        current_music_inst = audio_play_sound(_sound_id, 100, _loop);
        
        // Start at 0 and fade in to our target volume
        audio_sound_gain(current_music_inst, 0, 0);
        audio_sound_gain(current_music_inst, volumes.music, _fade_ms);
    };

    /**
     * Plays a sound effect with optional "juice" (pitch randomization).
     * @param {Asset.GMSound} _sound_id The SFX asset.
     * @param {Real} _pitch_min Minimum pitch multiplier.
     * @param {Real} _pitch_max Maximum pitch multiplier.
     */
    static play_sfx = function(_sound_id, _pitch_min = 0.95, _pitch_max = 1.05) {
        var _inst = audio_play_sound(_sound_id, 10, false);
        audio_sound_gain(_inst, volumes.sfx, 0);
        audio_sound_pitch(_inst, random_range(_pitch_min, _pitch_max));
        return _inst;
    };

    /**
     * Plays an interface/UI sound.
     * @param {Asset.GMSound} _sound_id The UI asset.
     */
    static play_ui = function(_sound_id) {
        var _inst = audio_play_sound(_sound_id, 20, false);
        audio_sound_gain(_inst, volumes.ui, 0);
        // UI sounds usually keep a consistent pitch
        audio_sound_pitch(_inst, 1.0);
        return _inst;
    };

    /**
     * Sets volume for a specific category and saves.
     * @param {String} _type "master", "music", "sfx", or "ui".
     * @param {Real} _val Value between 0 and 1.
     */
    static set_volume = function(_type, _val) {
        if (variable_struct_exists(volumes, _type)) {
            volumes[$ _type] = clamp(_val, 0, 1);
            apply_volumes();
            save_settings();
        }
    };

    // --- Data Persistence ---

    static save_settings = function() {
        var _string = json_stringify(volumes);
        var _buf = buffer_create(string_byte_length(_string) + 1, buffer_fixed, 1);
        buffer_write(_buf, buffer_string, _string);
        buffer_save(_buf, save_filename);
        buffer_delete(_buf);
    };

    static load_settings = function() {
        if (file_exists(save_filename)) {
            var _buf = buffer_load(save_filename);
            var _string = buffer_read(_buf, buffer_string);
            var _data = json_parse(_string);
            
            // Merge loaded data into our volumes struct
            var _keys = variable_struct_get_names(_data);
            for (var i = 0; i < array_length(_keys); i++) {
                volumes[$ _keys[i]] = _data[$ _keys[i]];
            }
            buffer_delete(_buf);
        }
    };
}