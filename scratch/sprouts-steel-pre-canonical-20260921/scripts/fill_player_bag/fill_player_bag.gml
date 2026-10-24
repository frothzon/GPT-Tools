/// @desc fill_player_bag(type, amount);
/// @param type ITEM_name
/// @param amount qty of item to add
function fill_player_bag(type, amount){
    if(GEAR.findItem(ITEMS[type].name) > -1){
        show_debug_message("Adding to GEAR...");
        var _ind = GEAR.addItem(ITEMS[type], amount);  
        return GEAR.quantity[_ind];
    } else {
        var _slot = BACKPACK.addItem(ITEMS[type], amount);  
        show_debug_message($"added at slot {_slot} of {ITEMS[type].name}");
        return BACKPACK.quantity[_slot];
    }
}