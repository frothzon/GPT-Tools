/// @description slowly destroy

if(SCT.check_instance(planted_object)){
    life = 1;
} else {
    life -= 0.1;
    alarm[1] = random_range(60, 600) * GAME_FPS;
    if(life <= 0.5){
        instance_destroy();
    }
}

