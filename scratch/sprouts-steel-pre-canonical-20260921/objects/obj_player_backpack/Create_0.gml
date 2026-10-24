frontend_shutting_down = false;
frontend_mode = "game_select";
frontend_locked = true;
frontend_input = scr_ui_input_create(scr_sas_frontend_input_bindings());

pack_enabled = false;
pause_surf = -1;
bg_image = spr_pause_bg;
bg_alpha = 0;

ui_bridge_backpack = scr_sas_inventory_bridge(BACKPACK, "BACKPACK");
ui_bridge_gear = scr_sas_inventory_bridge(GEAR, "EQUIPMENT");

scr_setup_bag({
	page_size: 12,
	categories: [
		scr_inventory_category("Backpack", ui_bridge_backpack, "items"),
		scr_inventory_category("Equipment", ui_bridge_gear, "equipment")
	],
	labels: {
		title: "BACKPACK",
		party: "SPROUTS / STEEL",
		currency: "SEEDS / TOOLS",
		leave: "Close",
		no_selection: "Select an item",
		empty_slot: "—",
		use: "Use",
		craft: "Craft",
		inspect: "Details"
	},
	layout: {
		padding: 14,
		gap: 8,
		header_height: 48,
		footer_height: 30,
		nav_width: 136,
		details_width: 250,
		slot_header_height: 28,
		slot_height: 54,
		slot_columns: 2,
		slot_gap: 6
	},
	input: scr_sas_frontend_input_bindings(),
	sprites: { frame: spr_invBox },
	font: fnt_default_ui,
	theme: scr_sas_frontend_theme(),
	callbacks: {
		on_open: function(){
			pack_enabled = true;
			frontend_mode = "inventory";
			scr_sas_frontend_lock_game(id);
			IN_UI = true;
			SOUND_MGR.play_ui(snd_select);
		},
		on_close: function(){
			pack_enabled = false;
			if (!frontend_shutting_down){
				scr_sas_frontend_return_to_pause(id);
			}
			SOUND_MGR.play_ui(snd_cancel);
		},
		on_item_activated: function(_item_obj = undefined, _category_index = -1){
			if (_category_index == scr_inventory_category_index("equipment") && is_struct(_item_obj)){
				var _gear_slot = GEAR.findItem(_item_obj.name);
				if (_gear_slot >= 0) GEAR.selected = _gear_slot;
			}
		}
	}
});

game_select = scr_sas_frontend_create_game_select(id, frontend_input);
pause_menu = scr_sas_frontend_create_pause_menu(id, frontend_input);
quest_menu = scr_sas_frontend_create_info_menu(
	id,
	frontend_input,
	"quests",
	"QUESTS",
	"FIELD NOTES & OBJECTIVES",
	"ARROWS / WASD MOVE    ENTER DETAILS    ESC BACK"
);
stats_menu = scr_sas_frontend_create_info_menu(
	id,
	frontend_input,
	"stats",
	"FIELD STATS",
	"THE SHAPE OF YOUR SEASON",
	"ARROWS / WASD MOVE    ENTER DETAILS    ESC BACK"
);

scr_sas_frontend_lock_game(id);
scr_ui_game_select_open(game_select);
IN_UI = true;
