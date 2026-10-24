function init_game(){
    gml_pragma("global", "init_game()")
    
    // Initialize the global instance
    global.SYS = {
        input: new InputManager(),
        stats: new ActorStats(4, 1, 1, 1.5),
        system: new System(),
        items: [],
        drop_multiplier: 1,
        backpack: new InventoryBag("Backpack", 32, 32, 32, 32, 9, 6),
        gear: new InventoryBag("Equipment", 512, 32, 32, 32, 9, 1),
        sound_mgr: new SoundManager(),
        blaster: new Text_Blaster(),
        tooltip: new Tooltip(spr_toolip_icon),
        ui_hover: false
    };
    
    
    #region =========================== INPUTS ===================================
    
    INPUT_MGR.add_action("left",   [vk_left,  ord("A")], [gp_padl, gp_axislh]);
    INPUT_MGR.add_action("right",  [vk_right, ord("D")], [gp_padr, gp_axislh]);
    INPUT_MGR.add_action("up",     [vk_up,    ord("W")], [gp_padu, gp_axislv]);
    INPUT_MGR.add_action("down",   [vk_down,  ord("S")], [gp_padd, gp_axislv]);
    INPUT_MGR.add_action("action", [ord("E")], [gp_face1]);
    INPUT_MGR.add_action("attack", [vk_space], [gp_shoulderrb]);
    INPUT_MGR.add_action("pause", [ord("P")], [gp_start]);
    INPUT_MGR.add_action("back", [vk_escape], [gp_face2]);
    
    #endregion ===================================================================
    
    #region ============================ ITEMS ===================================
    
    /// @description Explicit Item Constants to prevent Index Corruption
    /// Use these instead of the eITEM enum.
    
    // Consumables (0-13)
    #macro ITEM_APPLE 0
    #macro ITEM_ORANGE 1
    #macro ITEM_POTION_GREEN 2
    #macro ITEM_POTION_RED 3
    #macro ITEM_CORN 4
    #macro ITEM_CARROT 5
    #macro ITEM_CAULIFLOWER 6
    #macro ITEM_TOMATO 7
    #macro ITEM_EGGPLANT 8
    #macro ITEM_TULIP 9
    #macro ITEM_LETTUCE 10
    #macro ITEM_PUMPKIN 11
    #macro ITEM_BEET 12
    #macro ITEM_CUCUMBER 13
    
    // Seeds (14-23)
    #macro ITEM_SEED_CORN 14
    #macro ITEM_SEED_CARROT 15
    #macro ITEM_SEED_CAULIFLOWER 16
    #macro ITEM_SEED_TOMATO 17
    #macro ITEM_SEED_EGGPLANT 18
    #macro ITEM_SEED_TULIP 19
    #macro ITEM_SEED_LETTUCE 20
    #macro ITEM_SEED_PUMPKIN 21
    #macro ITEM_SEED_BEET 22
    #macro ITEM_SEED_CUCUMBER 23
    
    // Materials (24-29)
    #macro ITEM_WOOD 24
    #macro ITEM_STONE 25
    #macro ITEM_IRON 26
    #macro ITEM_BLOCK_WOOD 27
    #macro ITEM_BLOCK_IRON 28
    #macro ITEM_BOTTLE 29
    
    // Tools (30-31)
    #macro ITEM_TOOL_PICKAXE 30
    #macro ITEM_TOOL_HOE 31
    
    // Structures (32-34)
    #macro ITEM_BUILD_ALCHEMY 32
    #macro ITEM_BUILD_TOOLS 33
    #macro ITEM_BUILD_SEEDS 34
    
    // Utility
    #macro ITEM_MAX 35
    
    //================================================= CONSUMABLES ====================================================================//
    
    /// Consumables
    ITEMS[ITEM_APPLE] = create_item("Apple", spr_Apple, "A red apple.", eITEM_TYPE.CONSUMABLE, {hp: 1});
    ITEMS[ITEM_ORANGE] = create_item("Orange", spr_Orange, "An orange.", eITEM_TYPE.CONSUMABLE, {hp: 1});
    /// plant consumables
    ITEMS[ITEM_CORN]           = create_item_ext("Corn", spr_plant_items, 0, "An cob of corn.", eITEM_TYPE.CONSUMABLE, {hp: 15});
    ITEMS[ITEM_CARROT]         = create_item_ext("Carrot", spr_plant_items, 1, "A Carrot.", eITEM_TYPE.CONSUMABLE, {hp: 10});
    ITEMS[ITEM_CAULIFLOWER]    = create_item_ext("Cauliflower", spr_plant_items, 2, "A head of Cauliflower.", eITEM_TYPE.CONSUMABLE, {hp: 10});
    ITEMS[ITEM_TOMATO]         = create_item_ext("Tomato", spr_plant_items, 3, "An ripe Tomato.", eITEM_TYPE.CONSUMABLE, {hp: 15});
    ITEMS[ITEM_EGGPLANT]       = create_item_ext("Eggplant", spr_plant_items, 4, "A juicy Eggplant.", eITEM_TYPE.CONSUMABLE, {hp: 20});
    ITEMS[ITEM_TULIP]          = create_item_ext("Tulip", spr_plant_items, 5, "A pretty Tulip.", eITEM_TYPE.MATERIAL);
    ITEMS[ITEM_LETTUCE]        = create_item_ext("Lettuce", spr_plant_items, 6, "A head of Lettuce.", eITEM_TYPE.CONSUMABLE, {hp: 5});
    ITEMS[ITEM_PUMPKIN]        = create_item_ext("Pumpkin", spr_plant_items, 8, "A huge Pumpkin.", eITEM_TYPE.CONSUMABLE, {hp: 30});
    ITEMS[ITEM_BEET]           = create_item_ext("Beet", spr_plant_items, 11, "A delicous Beet.", eITEM_TYPE.CONSUMABLE, {hp: 12});
    ITEMS[ITEM_CUCUMBER]       = create_item_ext("Cucumber", spr_plant_items, 13, "A long Cucumber.", eITEM_TYPE.CONSUMABLE, {hp: 15});
    
    /// Bottled Item
    ITEMS[ITEM_POTION_GREEN] = create_item("Green Potion", spr_Potion, "An green potion.", eITEM_TYPE.BOTTLED, {hp: 5});
    ITEMS[ITEM_POTION_RED] = create_item("Red Potion", spr_Syrup, "An red potion.", eITEM_TYPE.BOTTLED, {hp: 5});
    /// Seeds
    ITEMS[ITEM_SEED_CORN]          = create_item_ext("Corn Seed", spr_seed_pouches, 1, "A corn kernal bag", eITEM_TYPE.SEED, {plant: obj_grow_corn});
    ITEMS[ITEM_SEED_CARROT]        = create_item_ext("Carrot Seed", spr_seed_pouches, 2, "A Carrot seed bag", eITEM_TYPE.SEED, {plant: obj_grow_carrot});
    ITEMS[ITEM_SEED_CAULIFLOWER]   = create_item_ext("Cauliflower Seed", spr_seed_pouches, 3, "A Cauliflower seed bag", eITEM_TYPE.SEED, {plant: obj_grow_cauliflower});
    ITEMS[ITEM_SEED_TOMATO]        = create_item_ext("Tomato Seed", spr_seed_pouches, 4, "A Tomato seed bag", eITEM_TYPE.SEED, {plant: obj_grow_tomato});
    ITEMS[ITEM_SEED_EGGPLANT]      = create_item_ext("Eggplant Seed", spr_seed_pouches, 5, "A Eggplant seed bag", eITEM_TYPE.SEED, {plant: obj_grow_eggplant});
    ITEMS[ITEM_SEED_TULIP]         = create_item_ext("Tulip bulb", spr_seed_pouches, 6, "A Tulip bulb bag", eITEM_TYPE.SEED, {plant: obj_grow_tulip});
    ITEMS[ITEM_SEED_LETTUCE]       = create_item_ext("Lettuce Seed", spr_seed_pouches, 7, "A Lettuce seed bag", eITEM_TYPE.SEED, {plant: obj_grow_lettuce});
    ITEMS[ITEM_SEED_PUMPKIN]       = create_item_ext("Pumpkin Seed", spr_seed_pouches, 9, "A Pumpkin seed bag", eITEM_TYPE.SEED, {plant: obj_grow_pumpkin});
    ITEMS[ITEM_SEED_BEET]          = create_item_ext("Beet Seed", spr_seed_pouches, 12, "A Beet seed bag", eITEM_TYPE.SEED, {plant: obj_grow_beet});
    ITEMS[ITEM_SEED_CUCUMBER]      = create_item_ext("Cucumber Seed", spr_seed_pouches, 14, "A Cucumber seed bag", eITEM_TYPE.SEED, {plant: obj_grow_cucumber});

    //================================================= MATERIALS ====================================================================//
    /// Materials
    ITEMS[ITEM_WOOD] = create_item("Wood", spr_Wood, "A piece of wood.", eITEM_TYPE.MATERIAL);
    ITEMS[ITEM_STONE] = create_item("Stone", spr_Stone, "A large rock.", eITEM_TYPE.MATERIAL);
    ITEMS[ITEM_IRON] = create_item("Iron", spr_Iron, "A solid piece of dark metal.", eITEM_TYPE.MATERIAL);
    ITEMS[ITEM_BLOCK_WOOD] = create_item("Wood Block", spr_floor_tiles, "A Block of wood.", eITEM_TYPE.MATERIAL);
    ITEMS[ITEM_BLOCK_IRON] = create_item("Iron Block", spr_Block_Iron, "A Block of Iron.", eITEM_TYPE.MATERIAL);
    ITEMS[ITEM_BOTTLE] = create_item("Empty Bottle", spr_Bottle, "A glass jar.", eITEM_TYPE.MATERIAL);
    
    //================================================= TOOLS ====================================================================//
    ITEMS[ITEM_TOOL_PICKAXE] = create_item_ext("Pick Axe", spr_tools, 7, "A pick-axe.", eITEM_TYPE.WEAPON, {dmg: 1});
    ITEMS[ITEM_TOOL_HOE] = create_item_ext("Hoe", spr_tools, 9, "A hoe.", eITEM_TYPE.TOOL_HOE, {dmg: 1});
    
    //================================================= BUILDINGS ====================================================================//
    //ITEMS[ITEM_BUILD_ALCHEMY] = create_item_ext("Alchemy Lab", spr_alchemy_lab, 0, "To Craft Potions", eITEM_TYPE.STRUCTURE, {obj: obj_alchemy_lab});
    //ITEMS[ITEM_BUILD_TOOLS] = create_item_ext("Smithing Hut", spr_seed_extractor, 0, "To Craft Tools", eITEM_TYPE.STRUCTURE, {obj: obj_smithing_hut});
    //ITEMS[ITEM_BUILD_SEEDS] = create_item_ext("Seed Extractor", spr_smithing_hut, 0, "To Extract Seeds", eITEM_TYPE.STRUCTURE, {obj: obj_seed_extractor});
    
    #endregion ===================================================================
    
    #macro INPUT_MGR global.SYS.input
    #macro GAME_FPS game_get_speed(gamespeed_fps)
    #macro PLAYER_STATS global.SYS.stats
    #macro SCT global.SYS.system
    #macro ITEMS global.SYS.items
    #macro DROP_MULT global.SYS.drop_multiplier
    #macro BACKPACK global.SYS.backpack
    #macro GEAR global.SYS.gear
    #macro SOUND_MGR global.SYS.sound_mgr
    #macro BLASTER global.SYS.blaster
    #macro TOOLTIP global.SYS.tooltip
    #macro IN_UI global.SYS.ui_hover
}