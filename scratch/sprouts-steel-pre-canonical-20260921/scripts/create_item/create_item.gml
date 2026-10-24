/// @desc create_item(_name, _sprite, _desc);
function create_item(_name, _sprite, _desc, _type=eITEM_TYPE.ANY, _data={}){
    var _item = {
        name: _name,
        id: _name,
        sprite: _sprite,
        index: 0,
        desc: _desc,
        type: _type,
        data: _data,
        use_item: function(_item_obj){
            var _heal_amount = 0;
            if (is_struct(_item_obj) && is_struct(_item_obj.data)
                && variable_struct_exists(_item_obj.data, "hp")){
                _heal_amount = _item_obj.data.hp;
            }
            if (_heal_amount <= 0) return false;
            PLAYER_STATS.hp.heal(_heal_amount);
            var _slot = BACKPACK.findItem(_item_obj.name);
            if (_slot >= 0){
                BACKPACK.addItem(_item_obj, -1);
                return true;
            }
            _slot = GEAR.findItem(_item_obj.name);
            if (_slot >= 0){
                GEAR.addItem(_item_obj, -1);
                return true;
            }
            return false;
        }
    };
    return _item;
}
function create_item_ext(_name, _sprite, _index, _desc, _type=eITEM_TYPE.ANY, _data={}){
    var _item = {
        name: _name,
        id: _name,
        sprite: _sprite,
        index: _index,
        desc: _desc,
        type: _type,
        data: _data,
        use_item: function(_item_obj){
            var _heal_amount = 0;
            if (is_struct(_item_obj) && is_struct(_item_obj.data)
                && variable_struct_exists(_item_obj.data, "hp")){
                _heal_amount = _item_obj.data.hp;
            }
            if (_heal_amount <= 0) return false;
            PLAYER_STATS.hp.heal(_heal_amount);
            var _slot = BACKPACK.findItem(_item_obj.name);
            if (_slot >= 0){
                BACKPACK.addItem(_item_obj, -1);
                return true;
            }
            _slot = GEAR.findItem(_item_obj.name);
            if (_slot >= 0){
                GEAR.addItem(_item_obj, -1);
                return true;
            }
            return false;
        }
    };
    return _item;
}

