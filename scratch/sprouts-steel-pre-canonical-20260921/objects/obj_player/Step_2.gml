#region ============================= player tool code (pickaxe) ====================================================
if(SCT.check_instance(tool.obj)){
    var _bagSelection = GEAR.selected;
    var _tool = _bagSelection > -1 ? GEAR.items[_bagSelection] : noone;
    
    /// load tool if detected
    if(is_struct(_tool) && interact_obj.held == false){
        if(tool.xref != _tool){
            tool.xref = _tool;
            tool.sprite = _tool.sprite;
            tool.index = _tool.index;
            tool.type = _tool.type;
        }
    } else {
        tool.xref = noone;
        tool.type = 0;
    }
    
    if(flip_image){
        tool.angle = -25;
    } else {
        tool.angle = 25;
    }
    var _bobbing = -lengthdir_y(1, image_index / sprite_get_number(sprite_index) * 180);
    var _lerpRatio = tool.cooldown > 0 ? 0.15 : 0.5;
    tool.obj.x = x + lengthdir_x(8, 90 + tool.obj.image_angle);
    tool.obj.y = y + _bobbing + lengthdir_y(8, 90 + tool.obj.image_angle) - 4;
    tool.obj.image_angle = SCT.rotate_smooth(tool.obj.image_angle, tool.angle, _lerpRatio);
    tool.obj.depth = depth-1;
    tool.obj.sprite_index = tool.sprite;
    tool.obj.image_index = tool.index;
    tool.obj.type = tool.type;
    tool.obj.image_xscale = flip_image ? -1 : 1;
    
    var _xx = (round(target.x / 16) << 4);
    var _yy = (round(target.y / 16) << 4);
    tool.target.x = _xx;
    tool.target.y = _yy;
    
    if(tool.type == eITEM_TYPE.TOOL_HOE)
        tool.info = !place_meeting(_xx, _yy, [obj_soil, obj_solid_parent]);
    if(tool.type == eITEM_TYPE.SEED)
        tool.info = instance_position(_xx, _yy, obj_soil);
    
    if(tool.cooldown > 0){
        tool.cooldown--;
    }
    
    if((INPUT_MGR.check("attack") || (mouse_check_button(mb_left)) && !IN_UI) && tool.cooldown <= 0){
        tool.cooldown = GAME_FPS * 0.6;
        if(flip_image){
        tool.obj.image_angle = 120;
        } else {
            tool.obj.image_angle = -120;
        }

        var _itemIndex = is_struct(tool.xref) ? GEAR.findItem(tool.xref.name) : -1;
        
        switch(tool.type){
            case eITEM_TYPE.WEAPON:
                /// do damage (if it is a weapon)
                if(SCT.check_instance(target.obj)){
                    SOUND_MGR.play_sfx(snd_whack);
                    var _dmg = PLAYER_STATS.atk.get_val();
                    BLASTER.add_text(_dmg, irandom_range(target.obj.bbox_left, target.obj.bbox_right), target.obj.bbox_top, GAME_FPS, [c_red, c_yellow]);
                    
                    target.obj.stats.hp.damage(_dmg);
                    target.obj.hurt_timer = GAME_FPS * 0.3;
                    if(variable_instance_exists(target.obj, "behavior")){
                        with(target.obj){
                            knockback_timer = GAME_FPS * 0.25;
                        }
                    }
                } else {
                    SOUND_MGR.play_sfx(snd_weapon_use);
                }
                
                
                break;
            case eITEM_TYPE.TOOL_HOE:
                if(!SCT.check_instance(target.obj)){
                    if(tool.info){
                        SOUND_MGR.play_sfx(snd_hoe);
                        instance_create_depth(_xx, _yy, 0, obj_soil);
                    }
                }
                break;
            case eITEM_TYPE.CONSUMABLE:
                /// remove consumable, increase hp
                if(_itemIndex > -1){
                    var _amount = tool.xref.data.hp;
                    PLAYER_STATS.hp.heal(_amount);
                    GEAR.addItem(tool.xref, -1);
                }
                break;
            case eITEM_TYPE.BOTTLED:
                /// add bottle to inventory, remove consumable, increase hp
                if(_itemIndex > -1){
                    var _amount = tool.xref.data.hp;
                    PLAYER_STATS.hp.heal(_amount);
                    GEAR.addItem(tool.xref, -1);
                }
                fill_player_bag(ITEM_BOTTLE, 1);
                break;
            case eITEM_TYPE.SEED:
                /// plant seed
                var _plant = tool.xref.data.plant;
                show_debug_message($"Tool info for seed {tool.xref}");
                if(!SCT.check_instance(target.obj) && _itemIndex > -1 && SCT.check_instance(tool.info) && _plant >= 0){
                    
                    if(SCT.check_instance(tool.info.planted_object)) break;
                        
                    show_debug_message(_plant);
                        
                    SOUND_MGR.play_sfx(snd_plant);
                    tool.info.planted_object = instance_create_depth(target.obj.x, target.obj.y, 0, 0);
                    tool.info = noone;
                    GEAR.addItem(tool.xref, -1);
                }
                break;
            case eITEM_TYPE.STRUCTURE:
                var _building = tool.xref.data.obj;
                
                if(_building >= 0){
                    show_debug_message($"Creating object from {tool.xref.data}, object is {_building}, is it {object_get_name(obj_alchemy_lab)}?");
                    
                    var _temp = instance_create_depth(tool.info.x, tool.info.y, 0, obj_iron_ore);
                    GEAR.addItem(tool.xref, -1);
                }
                
                
                break;
        }

        
    }
}
#endregion ============================================================================================================

#region ============================================== CRAFTING =======================================================


var _actionKey = INPUT_MGR.check_pressed("action");
var _backKey = INPUT_MGR.check_pressed("back");

var _nearestInteract = collision_circle(target.x, target.y, 8, obj_interact_parent, 0, 1);
var _nearestBuilding = SCT.check_instance(_nearestInteract) ? noone : collision_circle(target.x, target.y, 8, obj_crafter_parent, 0, 1);

crafting_menu.target = _nearestBuilding;

if(SCT.check_instance(_nearestBuilding)){
    crafting_menu.in_range = true;
    if(_actionKey && crafting_menu.show != _nearestBuilding.crafter){
        
        SOUND_MGR.play_sfx(snd_interact);
        __data__ = _nearestBuilding.crafter;
        var _ff = function(){
            crafting_menu.show = __data__;
            __data__ = undefined;
        }
        call_later(2, time_source_units_frames, _ff);
        
    }
    if(_backKey && crafting_menu.show == _nearestBuilding.crafter){
        SOUND_MGR.play_sfx(snd_interact);
        crafting_menu.show = noone;
    }
}

#endregion ============================================================================================================


#region ============================================ INTERACTABLE =====================================================


if(interact_obj.held == false){
    interact_obj.targ = _nearestInteract;
}

if(SCT.check_instance(interact_obj.targ) ){
    interact_obj.in_range = true;
    
    if(_actionKey){
        interact_obj.held = !interact_obj.held;
        interact_obj.push_state(interact_obj.held ? interact_obj.targ : noone);
    }
} else {
    interact_obj.held = false;
    interact_obj.push_state(noone);   
}


#endregion ============================================================================================================