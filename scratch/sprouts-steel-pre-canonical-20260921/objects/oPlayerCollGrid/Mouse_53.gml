/// @description update path



var _setPath = global.collisionManager.grid_set_path(0, path, id, mouse_x, mouse_y);
if(_setPath){
    path_trawler.extract_path(path, 16);
}