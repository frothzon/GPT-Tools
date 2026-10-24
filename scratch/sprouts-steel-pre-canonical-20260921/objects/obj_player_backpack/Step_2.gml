if (frontend_mode != "gameplay"){
	if (!frontend_locked){
		scr_sas_frontend_lock_game(id);
	} else {
		instance_deactivate_object(obj_player);
		instance_deactivate_object(obj_sortable);
		IN_UI = true;
	}
}

switch (frontend_mode){
	case "game_select":
		scr_ui_game_select_update(game_select);
		if (!game_select.open) scr_ui_game_select_open(game_select);
		break;
	case "gameplay":
		if (INPUT_MGR.check_pressed("pause")){
			scr_sas_frontend_open_pause(id);
		}
		break;
	case "pause":
		scr_ui_menu_update(pause_menu);
		break;
	case "inventory":
		scr_sas_inventory_refresh(ui_bridge_backpack);
		scr_sas_inventory_refresh(ui_bridge_gear);
		scr_update_bag();
		break;
	case "quests":
		scr_ui_menu_update(quest_menu);
		break;
	case "stats":
		scr_ui_menu_update(stats_menu);
		break;
}

IN_UI = frontend_mode != "gameplay";
