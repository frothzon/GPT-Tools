/**
* @function create_potion_crafter
* @brief Static helper to generate a Potion Station with time-based recipes.
* @return {Crafter} A pre-configured crafter instance.
*/
function create_potion_crafter() {
    var _crafter = new Crafter();
    _crafter.title = "Alchemy Lab";
    _crafter.sub = "Reagents";
    
    // Health Potion (3 seconds / 180 frames)
    _crafter.add_button(
        "Health Potion", 
        ITEM_POTION_GREEN, 
        [ITEM_APPLE, ITEM_WOOD], 
        [2, 1],
        180 
    );
    
    // Strength Potion (10 seconds / 600 frames)
    _crafter.add_button(
        "Strength Potion", 
        ITEM_POTION_RED, 
        [ITEM_ORANGE, ITEM_IRON], 
        [2, 1],
        600
    );
    
    return _crafter;
};