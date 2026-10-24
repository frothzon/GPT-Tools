/// @description destroy

if(!stats.update_status()){
    var _drop = instance_create_depth(x,y,0,obj_item);

    _drop.type = item_on_destroy;
    _drop.amount = 1;
    _drop.sprite_index = sprite_index;
    
    instance_destroy(id);
}
