/// @desc Enums for accessing stat array indices globally
enum e_STAT_VAL {
    CURRENT,
    MAX,
    BASE
}

/// @desc Individual Stat Constructor
/// @param {real} _val The initial value for base, max, and current.
function Stat(_val) constructor {
    // [Current, Max, Base]
    values = [_val, _val, _val];

    // --- Methods ---

    /// @desc Returns the current value
    static get_val = function() {
        return values[e_STAT_VAL.CURRENT];
    }

    /// @desc Returns the max value
    static get_max = function() {
        return values[e_STAT_VAL.MAX];
    }

    /// @desc Heals/Adds to the current value, clamped to Max
    static heal = function(_amount) {
        values[e_STAT_VAL.CURRENT] = clamp(values[e_STAT_VAL.CURRENT] + _amount, 0, values[e_STAT_VAL.MAX]);
    }

    /// @desc Subtracts from the current value, clamped to 0
    static damage = function(_amount) {
        values[e_STAT_VAL.CURRENT] = clamp(values[e_STAT_VAL.CURRENT] - _amount, 0, values[e_STAT_VAL.MAX]);
    }

    /// @desc Sets a new Max and Base, and heals to full
    static set_base = function(_new_val) {
        values[e_STAT_VAL.BASE] = _new_val;
        values[e_STAT_VAL.MAX] = _new_val;
        values[e_STAT_VAL.CURRENT] = _new_val;
    }
    
    /// @desc Returns a percentage (0 to 1) useful for health bars
    static get_percent = function() {
        if (values[e_STAT_VAL.MAX] <= 0) return 0;
        return values[e_STAT_VAL.CURRENT] / values[e_STAT_VAL.MAX];
    }
}

/// @desc Container for all Actor attributes
/// @param {real} _hp Initial Health
/// @param {real} _atk Initial Attack
/// @param {real} _def Initial Defense
/// @param {real} _spd Initial Speed
function ActorStats(_hp, _atk, _def, _spd) constructor {
    
    // Initialize Stat Structs
    hp  = new Stat(_hp);
    atk = new Stat(_atk);
    def = new Stat(_def);
    spd = new Stat(_spd);
    
    // Additional RPG Metadata
    level = 1;
    is_alive = true;

    /// @desc Check if HP has reached zero
    static update_status = function() {
        if (hp.get_val() <= 0) {
            is_alive = false;
        }
        return is_alive;
    }

    /// @desc Fully heal all vitals
    static full_restore = function() {
        hp.heal(hp.get_max());
    }
}

