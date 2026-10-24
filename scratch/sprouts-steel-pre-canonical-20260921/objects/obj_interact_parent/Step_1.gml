
if(zpos.onGround()){
    if(timer-- <= 0){
        timer = 90;
        zpos.jump(10);
    }
}