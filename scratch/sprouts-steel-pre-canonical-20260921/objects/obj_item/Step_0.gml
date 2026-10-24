
if(!pos.onGround()){
    x += motion.x;
    y += motion.y;
}

if(!collected && place_meeting(x,y,obj_player) && pos.onGround()){
    /// add to inventory
    show_debug_message($"Gear check = {GEAR.findItem(ITEMS[type].name)}");
    
    var _total = fill_player_bag(type, amount);
    
    collected = true;
    
    SOUND_MGR.play_sfx(snd_pickup);
    
    TOOLTIP.add($"Picked up {amount} {ITEMS[type].name}({_total})", sprite_index, c_lime);
}

if(collected){
    image_alpha -= 0.05;
    y -= 0.5;
    
    if(image_alpha <= 0.1){
        instance_destroy();
    }
}

pos.update();

