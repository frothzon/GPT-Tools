var _targ = instance_find(obj_player, 0);
if(selected && SCT.check_instance(_targ)){
    if(sound_on_evt != noone && play_sound_toggle){
        SOUND_MGR.play_sfx(sound_on_evt);
        play_sound_toggle = false;
    }
    if(is_callable(on_selected) || is_method(on_selected))
    {
        on_selected(_targ);
    }
} else {
    if(!play_sound_toggle && sound_off_evt != noone)
    {
        play_sound_toggle = true;
        SOUND_MGR.play_sfx(sound_off_evt);
    }
}

if(selected && SCT.check_instance(_targ)){
    exit;
}

zpos.update();