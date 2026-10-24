///////////////////////////////////////
////		  EXAMPLE DATA           ////
///////////////////////////////////////

function create_missions() {
    // Initialize the global mission array
    global.MISSIONS = [];
    
    // --- SQ_001_Rubble Mission ---
    // 1. Define objectives
    var _obj_rubble = [
        { "type": "kill", "target": "oRubble", "amount": "dynamic_count" }
    ];
    
    // 2. Define rewards
    var _rewards_rubble = [
        { "type": "xp", "amount": 100 }
    ];
    
    // 3. Add the mission using the helper function
    var _sq001 = add_mission_struct(
        "SQ_001_Rubble",                               // id
        "Clear the Rubble",                            // name
        "The path is blocked by ancient, fragile walls. Clear them out.", // description
        _obj_rubble,                                   // objectives array
        _rewards_rubble,                               // rewards array
        "mission_sq001_complete_callback",             // on_complete_callback
        [],                                            // prerequisites
        -1                                             // time_limit
    );
    
    // 4. Push the resulting mission struct to the global array
    array_push(global.MISSIONS, _sq001);
}

/// @function add_mission_struct(_id, _name, _description, _objectives, _rewards, _callback_name = undefined, _prereqs = [], _time_limit = -1)
/// @description Creates and returns a mission definition struct ready to be added to global.MISSIONS.
/// @param {String} _id            Unique ID (e.g., "SQ_002_FindKey")
/// @param {String} _name          Display name
/// @param {String} _description   Mission flavour text
/// @param {Array<Struct>} _objectives  Array of objective structs: [ { type: "kill", target: "oEnemy", amount: 5 }, ... ]
/// @param {Array<Struct>} _rewards     Array of reward structs: [ { type: "xp", amount: 100 }, ... ]
/// @param {String|Undefined} _callback_name Optional script name to run on completion (e.g., "mission_sq001_complete_callback")
/// @param {Array<String>} _prereqs     Array of mission IDs that must be completed first
/// @param {Real} _time_limit      Time limit in seconds (-1 for none)
/// @returns {Struct} The structured mission data.
function add_mission_struct(_id, _name, _description, _objectives, _rewards, _callback_name = undefined, _prereqs = [], _time_limit = -1) {
    var _mission_struct = {
        id: _id,
        name: _name,
        description: _description,
        objectives: _objectives,
        rewards: _rewards,
        prerequisites: _prereqs,
        time_limit: _time_limit
    };

    // Only add the callback field if a name was provided
    if (is_string(_callback_name)) {
        variable_struct_set(_mission_struct, "on_complete_callback", _callback_name);
    }
    
    return _mission_struct;
}

// --- Demonstration and Example Usage ---

/// @function create_a_new_mission_data()
/// @description Demonstrates how to use the helper function and convert the result to JSON.
function create_a_new_mission_data() {
    // 1. Define objectives
    var _new_objectives = [
        { type: "collect", target: "Key_Item_01", amount: 1 },
        { type: "location", target: "Town_Center", amount: 1 }
    ];

    // 2. Define rewards
    var _new_rewards = [
        { type: "xp", amount: 500 },
        { type: "money", amount: 200 }
    ];

    // 3. Create the mission struct using the new helper function
    var _mission_struct = add_mission_struct(
        "SQ_002_FindKey",                               // id
        "The Missing Key",                              // name
        "An old man lost his key in the town center.",  // description
        _new_objectives,                                // objectives array
        _new_rewards,                                   // rewards array
        undefined,                                      // no callback needed
        ["SQ_001_Rubble"],                              // prerequisite: "SQ_001_Rubble"
        60                                              // 60 second time limit
    );

    // 4. Demonstration of JSON stringify (as requested)
    // If you were saving this mission to an external file, this is the step you would use.
    var _mission_json_string = json_stringify(_mission_struct);

    show_debug_message("--- New Mission Data (GML Struct) ---");
    show_debug_message(string(_mission_struct));
    show_debug_message("--- New Mission Data (JSON String) ---");
    show_debug_message(_mission_json_string);
    
    // 5. How you would add it to the global array if you wanted to do this manually:
    // array_push(global.MISSIONS, _mission_struct);
}