/// @description initializeation

init_dragSystem();

bag = new InventoryBag("Backpack", 32, 32, 32, 32, 8, 5);
bag2 = new InventoryBag("Equipment", 512, 32, 32, 32, 10, 1);


/// make items
bag.addItem({sprite: ITEM_SPRITE, index: 0, name: "Dark Matter",type: eITEM_TYPE.ANY}, 1);
bag.addItem({sprite: ITEM_SPRITE, index: 0, name: "Fairy Dust",type: eITEM_TYPE.ANY}, 10);
bag.addItem({sprite: ITEM_SPRITE, index: 0, name: "Demon Eye",type: eITEM_TYPE.ANY}, 5);  