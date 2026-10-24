switch (frontend_mode){
	case "game_select":
		scr_ui_game_select_draw(game_select);
		break;
	case "pause":
		scr_ui_menu_draw(pause_menu);
		break;
	case "inventory":
		draw_set_font(fnt_default_ui);
		scr_draw_bag();
		break;
	case "quests":
		scr_ui_menu_draw(quest_menu);
		break;
	case "stats":
		scr_ui_menu_draw(stats_menu);
		break;
}
scr_draw_reset();
