/// @function StateMachine(_target)
/// @description A constructor-based state machine that manages logic for a specific target instance.
/// @param {Instance.ID} _target The instance (e.g., a player or enemy) this state machine will control.
function StateMachine(_target) constructor {
    
    // --- Properties ---
    
    // Tracks how many frames the current state has been active. Resets to 0 on state change.
    timer = 0;
    
    // The instance ID that this state machine is manipulating (e.g., obj_Player).
    target = _target;
    
    // The current active state function. Defaults to a debug message.
    // We pass (_sm_) so the state function has access to the StateMachine struct itself.
    state = function(_sm_) {
        show_debug_message($"Default state called, time {_sm_.timer}");
    };
    
    // A buffer for the next state. This prevents state-switching mid-update, 
    // ensuring a clean transition on the next frame.
    state_next = state;
    
    // A flag to indicate that a transition to 'state_next' is pending.
    can_change_state = false;
    
    // --- Methods ---

    /// @function change(_function_)
    /// @description Queues a new state function to be switched to at the start of the next update.
    static change_state = function(_function_) {
        state_next = _function_;
        can_change_state = true;
    };
    
    /// @function update()
    /// @description Processes state transitions and executes the current state logic. 
    /// Should be called in the target instance's Step Event.
    static update = function() {
        
        // 1. Handle State Transitions
        // If a change was requested, swap the current state for the next one and reset the timer.
        if (can_change_state) {
            state = state_next;
            timer = 0;
            can_change_state = false;
        }
        
        // 2. Call State Logic
        // We check if the 'state' variable is actually a function or method to prevent crashes.
        if (is_method(state) || is_callable(state)) {
            // Context Switching: 'with(target)' makes 'self' inside the state function 
            // refer to the object (like obj_Player), while 'other' refers to this struct.
            state(self);
        }
        
        // 3. Increment Timer
        // Keep track of how long we've been in this state.
        timer++;
    };
}