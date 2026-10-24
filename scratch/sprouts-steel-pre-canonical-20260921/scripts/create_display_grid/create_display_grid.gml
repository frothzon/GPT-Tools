// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
///@desc create_display_grid(_x,_y,_width,_height,_hcount,_vcount);
function create_display_grid(_x,_y,_width,_height,_hcount,_vcount){
	return new DisplayGrid(_x,_y,_width,_height,_hcount,_vcount);
}