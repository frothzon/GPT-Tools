if(other.zpos.z <= 8){
    var _collidables = [layer_tilemap_get_id("collisions"), obj_solid_parent];
    SCT.collide_push(id, other, _collidables);
}
