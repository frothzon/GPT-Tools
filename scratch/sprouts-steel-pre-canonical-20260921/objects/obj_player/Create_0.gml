motion = new Vector2();

animations = [
    spr_player_bird_idle2,
    spr_player_bird_run2
];

clothes = [
    spr_bird_clothes_idle,
    spr_bird_clothes_run
];

clothes_index = 0;
clothes_color = #5c84e0;
flip_image = false;

target = {
    x: 0,
    y: 0,
    obj: -4,
    range: 16,
    radius: 6,
    angle: 0
};

tool = {
    obj: instance_create_depth(0,0,0,obj_pickaxe),
    sprite: spr_Pickaxe,
    index: 0,
    angle: 0,
    cooldown: 0,
    xref: noone,
    type: 0,
    target: new Vector2(),
    info: 0
};

BACKPACK.addItem(ITEMS[ITEM_SEED_CORN], 15);
GEAR.addItem(ITEMS[ITEM_TOOL_PICKAXE], 1); 
GEAR.addItem(ITEMS[ITEM_TOOL_HOE], 1);
GEAR.selected = 0;

crafting_menu = {
    show: noone,
    in_range: false,
    target: noone
};


interact_obj = {
    targ: noone,
    in_range: false,
    held: false,
    push_state: function(_them){
        with(obj_interact_parent){
            selected = false;
            cooldown = 0;
        }
        if(SCT.check_instance(_them)){
            _them.selected = true;
            _them.cooldown = _them.cooldown_max;
        }
    }
};
