frontend_shutting_down = true;
if (variable_instance_exists(id, "ui_open") && ui_open){
	scr_inventory_ui_close();
}
if (is_struct(game_select)) scr_ui_menu_destroy(game_select);
if (is_struct(pause_menu)) scr_ui_menu_destroy(pause_menu);
if (is_struct(quest_menu)) scr_ui_menu_destroy(quest_menu);
if (is_struct(stats_menu)) scr_ui_menu_destroy(stats_menu);
if (variable_instance_exists(id, "ui_world") && is_struct(ui_world)){
	scr_ui_world_destroy(ui_world);
}
if (is_struct(layout) && variable_struct_exists(layout, "root")){
	flexpanel_delete_node(layout.root, true);
}
if (surface_exists(pause_surf)){
	surface_free(pause_surf);
}
