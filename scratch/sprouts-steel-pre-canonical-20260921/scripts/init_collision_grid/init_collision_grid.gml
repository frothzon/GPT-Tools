// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function init_collision_grid(){
	/// auto run this script at game startup
	gml_pragma("global", "init_collision_grid()");
	
	/// create collision manager
	global.collisionManager = new CollisionGrid();
}

function reset_collision_grid(collObjList){
	global.collisionManager.reset(collObjList);
}