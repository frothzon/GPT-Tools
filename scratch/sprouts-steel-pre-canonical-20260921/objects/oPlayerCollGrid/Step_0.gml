/// @description move player
if(path_trawler.ready){
    var target = path_trawler.get_next_vector(x, y, 4);
    move_and_collide(target.x, target.y, oStartCollisions);
}