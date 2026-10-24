// ===== Full Project Inventory: scripts/scr_ui_core/scr_ui_core.gml =====
/// @desc Lightweight UI entity/component storage.
///
/// UI entities are intentionally small structs. Flex Panel nodes, input
/// state, buttons, tweens, and visual effects all attach as components so the
/// same systems can be reused by menus outside the inventory.

function scr_ui_world_create(_options = undefined){
	return {
		entities: [],
		events: [],
		next_id: 0,
		dirty_layout: true,
		destroyed: false,
		options: is_struct(_options) ? _options : {}
	};
}

function scr_ui_entity_get(_world, _entity_id){
	if (!is_struct(_world) || !is_array(_world.entities)
		|| _entity_id < 0 || _entity_id >= array_length(_world.entities)){
		return undefined;
	}
	var _entity = _world.entities[_entity_id];
	if (!is_struct(_entity) || !_entity.alive){
		return undefined;
	}
	return _entity;
}

function scr_ui_entity_create(_world, _parent_id = -1){
	if (!is_struct(_world) || _world.destroyed){
		return -1;
	}

	var _entity_id = _world.next_id;
	_world.next_id += 1;
	var _entity = {
		id: _entity_id,
		alive: true,
		parent: _parent_id,
		children: [],
		components: {}
	};
	array_push(_world.entities, _entity);

	var _parent = scr_ui_entity_get(_world, _parent_id);
	if (is_struct(_parent)){
		array_push(_parent.children, _entity_id);
	}
	return _entity_id;
}

function scr_ui_component_add(_world, _entity_id, _component_type, _component_value){
	var _entity = scr_ui_entity_get(_world, _entity_id);
	if (!is_struct(_entity) || !is_string(_component_type) || string_length(_component_type) <= 0){
		return false;
	}
	variable_struct_set(_entity.components, _component_type, _component_value);
	return true;
}

function scr_ui_component_get(_world, _entity_id, _component_type){
	var _entity = scr_ui_entity_get(_world, _entity_id);
	if (!is_struct(_entity) || !variable_struct_exists(_entity.components, _component_type)){
		return undefined;
	}
	return variable_struct_get(_entity.components, _component_type);
}

function scr_ui_component_has(_world, _entity_id, _component_type){
	var _entity = scr_ui_entity_get(_world, _entity_id);
	return is_struct(_entity) && variable_struct_exists(_entity.components, _component_type);
}

function scr_ui_component_remove(_world, _entity_id, _component_type){
	var _entity = scr_ui_entity_get(_world, _entity_id);
	if (!is_struct(_entity) || !variable_struct_exists(_entity.components, _component_type)){
		return false;
	}
	variable_struct_remove(_entity.components, _component_type);
	return true;
}

function scr_ui_entity_destroy(_world, _entity_id){
	var _entity = scr_ui_entity_get(_world, _entity_id);
	if (!is_struct(_entity)){
		return false;
	}

	while (array_length(_entity.children) > 0){
		var _child_id = _entity.children[array_length(_entity.children) - 1];
		array_delete(_entity.children, array_length(_entity.children) - 1, 1);
		scr_ui_entity_destroy(_world, _child_id);
	}

	var _parent = scr_ui_entity_get(_world, _entity.parent);
	if (is_struct(_parent)){
		for (var _index = array_length(_parent.children) - 1; _index >= 0; _index--){
			if (_parent.children[_index] == _entity_id){
				array_delete(_parent.children, _index, 1);
				break;
			}
		}
	}
	_entity.alive = false;
	_entity.components = {};
	return true;
}

function scr_ui_world_destroy(_world){
	if (!is_struct(_world) || _world.destroyed){
		return;
	}
	for (var _index = 0; _index < array_length(_world.entities); _index++){
		scr_ui_entity_destroy(_world, _index);
	}
	_world.events = [];
	_world.destroyed = true;
}

function scr_ui_event_emit(_world, _event_type, _entity_id = -1, _payload = undefined){
	if (!is_struct(_world) || _world.destroyed){
		return false;
	}
	array_push(_world.events, {
		type: _event_type,
		entity: _entity_id,
		payload: _payload
	});
	return true;
}

function scr_ui_events_drain(_world){
	if (!is_struct(_world)){
		return [];
	}
	var _events = _world.events;
	_world.events = [];
	return _events;
}

function scr_ui_world_mark_layout_dirty(_world){
	if (is_struct(_world)){
		_world.dirty_layout = true;
	}
}

function scr_ui_world_step(_world, _delta_seconds){
	if (!is_struct(_world) || _world.destroyed){
		return;
	}
	scr_ui_tween_step(_world, _delta_seconds);
	scr_ui_juice_step(_world, _delta_seconds);
	scr_ui_text_juice_step(_world, _delta_seconds);
	scr_ui_button_clear_pressed(_world);
}

// ===== Full Project Inventory: scripts/scr_ui_motion/scr_ui_motion.gml =====
/// @desc Generic UI tweens and event-driven juice components.

function scr_ui_visual_ensure(_world, _entity_id){
	var _visual = scr_ui_component_get(_world, _entity_id, "visual");
	if (!is_struct(_visual)){
		_visual = {
			alpha: 1,
			scale: 1,
			offset_x: 0,
			offset_y: 0,
			juice_scale: 1,
			juice_alpha: 1,
			juice_offset_x: 0,
			juice_offset_y: 0
		};
		scr_ui_component_add(_world, _entity_id, "visual", _visual);
	}
	return _visual;
}

function scr_ui_motion_set_path(_world, _entity_id, _path, _value){
	var _separator = string_pos(".", _path);
	if (_separator <= 1){
		return false;
	}
	var _component_name = string_copy(_path, 1, _separator - 1);
	var _field_name = string_copy(_path, _separator + 1, string_length(_path));
	var _component = scr_ui_component_get(_world, _entity_id, _component_name);
	if (!is_struct(_component)){
		return false;
	}
	variable_struct_set(_component, _field_name, _value);
	return true;
}

function scr_ui_motion_get_path(_world, _entity_id, _path){
	var _separator = string_pos(".", _path);
	if (_separator <= 1){
		return undefined;
	}
	var _component_name = string_copy(_path, 1, _separator - 1);
	var _field_name = string_copy(_path, _separator + 1, string_length(_path));
	var _component = scr_ui_component_get(_world, _entity_id, _component_name);
	if (!is_struct(_component) || !variable_struct_exists(_component, _field_name)){
		return undefined;
	}
	return variable_struct_get(_component, _field_name);
}

function scr_ui_ease(_kind, _amount){
	var _t = clamp(_amount, 0, 1);
	switch (_kind){
		case "quad_in": return _t * _t;
		case "quad_out": return 1 - (1 - _t) * (1 - _t);
		case "cubic_out": return 1 - power(1 - _t, 3);
		case "back_out":
			var _overshoot = 1.70158;
			var _adjusted = _t - 1;
			return 1 + (_overshoot + 1) * power(_adjusted, 3) + _overshoot * power(_adjusted, 2);
		case "smoothstep": return _t * _t * (3 - 2 * _t);
	}
	return _t;
}

function scr_ui_tween_to(_world, _entity_id, _path, _to, _duration, _ease_kind = "smoothstep", _delay = 0){
	var _from = scr_ui_motion_get_path(_world, _entity_id, _path);
	if (is_undefined(_from)){
		return false;
	}
	var _tweens = scr_ui_component_get(_world, _entity_id, "tweens");
	if (!is_struct(_tweens)){
		_tweens = {tracks: []};
		scr_ui_component_add(_world, _entity_id, "tweens", _tweens);
	}
	array_push(_tweens.tracks, {
		path: _path,
		from: _from,
		to: _to,
		duration: max(0.0001, _duration),
		delay: max(0, _delay),
		elapsed: 0,
		ease: _ease_kind
	});
	return true;
}

function scr_ui_tween_step(_world, _delta_seconds){
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _entity = scr_ui_entity_get(_world, _entity_index);
		if (!is_struct(_entity) || !variable_struct_exists(_entity.components, "tweens")){
			continue;
		}
		var _tweens = variable_struct_get(_entity.components, "tweens");
		for (var _track_index = array_length(_tweens.tracks) - 1; _track_index >= 0; _track_index--){
			var _track = _tweens.tracks[_track_index];
			_track.elapsed += max(0, _delta_seconds);
			var _active_time = _track.elapsed - _track.delay;
			if (_active_time < 0){
				continue;
			}
			var _progress = clamp(_active_time / _track.duration, 0, 1);
			var _eased = scr_ui_ease(_track.ease, _progress);
			var _value = lerp(_track.from, _track.to, _eased);
			scr_ui_motion_set_path(_world, _entity_index, _track.path, _value);
			if (_progress >= 1){
				array_delete(_tweens.tracks, _track_index, 1);
			}
		}
	}
}

function scr_ui_juice_trigger(_world, _entity_id, _effect_name, _options = undefined){
	var _juice = scr_ui_component_get(_world, _entity_id, "juice");
	if (!is_struct(_juice)){
		_juice = {effects: []};
		scr_ui_component_add(_world, _entity_id, "juice", _juice);
	}
	var _duration = 0.16;
	var _amplitude = 4;
	if (is_struct(_options)){
		if (variable_struct_exists(_options, "duration")) _duration = _options.duration;
		if (variable_struct_exists(_options, "amplitude")) _amplitude = _options.amplitude;
	}
	array_push(_juice.effects, {
		name: _effect_name,
		elapsed: 0,
		duration: max(0.01, _duration),
		amplitude: _amplitude
	});
}

function scr_ui_juice_step(_world, _delta_seconds){
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _entity = scr_ui_entity_get(_world, _entity_index);
		if (!is_struct(_entity) || !variable_struct_exists(_entity.components, "juice")){
			continue;
		}
		var _juice = variable_struct_get(_entity.components, "juice");
		var _visual = scr_ui_visual_ensure(_world, _entity_index);
		_visual.juice_scale = 1;
		_visual.juice_alpha = 1;
		_visual.juice_offset_x = 0;
		_visual.juice_offset_y = 0;

		for (var _effect_index = array_length(_juice.effects) - 1; _effect_index >= 0; _effect_index--){
			var _effect = _juice.effects[_effect_index];
			_effect.elapsed += max(0, _delta_seconds);
			var _progress = clamp(_effect.elapsed / _effect.duration, 0, 1);
			var _wave = sin(_progress * pi);
			switch (_effect.name){
				case "focus":
					_visual.juice_scale = max(_visual.juice_scale, 1 + _wave * 0.04);
					break;
				case "press":
					_visual.juice_scale = min(_visual.juice_scale, 1 - _wave * 0.06);
					break;
				case "enter":
					_visual.juice_offset_y += (1 - scr_ui_ease("cubic_out", _progress)) * -18;
					_visual.juice_alpha = min(_visual.juice_alpha, clamp(_progress * 1.4, 0, 1));
					break;
				case "shake":
					_visual.juice_offset_x += sin(_effect.elapsed * 70) * _effect.amplitude * (1 - _progress);
					break;
			}
			if (_progress >= 1){
				array_delete(_juice.effects, _effect_index, 1);
			}
		}
	}
}

function scr_ui_visual_rect(_world, _entity_id, _rect){
	var _visual = scr_ui_visual_ensure(_world, _entity_id);
	var _scale = _visual.scale * _visual.juice_scale;
	var _width = _rect.width * _scale;
	var _height = _rect.height * _scale;
	var _center_x = _rect.left + _rect.width * 0.5 + _visual.offset_x + _visual.juice_offset_x;
	var _center_y = _rect.top + _rect.height * 0.5 + _visual.offset_y + _visual.juice_offset_y;
	return {
		left: _center_x - _width * 0.5,
		top: _center_y - _height * 0.5,
		width: _width,
		height: _height,
		alpha: _visual.alpha * _visual.juice_alpha
	};
}

// ===== Full Project Inventory: scripts/scr_ui_button/scr_ui_button.gml =====
/// @desc Reusable UI button component.

function scr_ui_button() constructor{
	label = "";
	command = "";
	payload = undefined;
	enabled = true;
	activatable = true;
	focused = false;
	hovered = false;
	pressed = false;
	style = {};
}

function scr_ui_button_create(_world, _options = undefined, _parent_id = -1){
	var _entity_id = scr_ui_entity_create(_world, _parent_id);
	if (_entity_id < 0){
		return -1;
	}

	var _button = new scr_ui_button();
	var _group = "default";
	var _route = {};
	if (is_struct(_options)){
		if (variable_struct_exists(_options, "label")) _button.label = _options.label;
		if (variable_struct_exists(_options, "command")) _button.command = _options.command;
		if (variable_struct_exists(_options, "payload")) _button.payload = _options.payload;
		if (variable_struct_exists(_options, "enabled")) _button.enabled = _options.enabled;
		if (variable_struct_exists(_options, "activatable")) _button.activatable = _options.activatable;
		if (variable_struct_exists(_options, "style")) _button.style = _options.style;
		if (variable_struct_exists(_options, "group")) _group = _options.group;
		if (variable_struct_exists(_options, "route")) _route = _options.route;
	}

	scr_ui_component_add(_world, _entity_id, "button", _button);
	scr_ui_component_add(_world, _entity_id, "focusable", {
		group: _group,
		enabled: _button.enabled,
		route: _route
	});
	scr_ui_component_add(_world, _entity_id, "visual", {
		alpha: 1,
		scale: 1,
		offset_x: 0,
		offset_y: 0,
		juice_scale: 1,
		juice_alpha: 1,
		juice_offset_x: 0,
		juice_offset_y: 0
	});
	scr_ui_component_add(_world, _entity_id, "juice", {effects: []});
	return _entity_id;
}

function scr_ui_button_set_enabled(_world, _entity_id, _enabled){
	var _button = scr_ui_component_get(_world, _entity_id, "button");
	var _focusable = scr_ui_component_get(_world, _entity_id, "focusable");
	if (!is_struct(_button) || !is_struct(_focusable)){
		return false;
	}
	_button.enabled = _enabled;
	_focusable.enabled = _enabled;
	if (!_enabled){
		_button.focused = false;
		_button.hovered = false;
	}
	return true;
}

function scr_ui_button_set_focused(_world, _entity_id, _focused){
	var _button = scr_ui_component_get(_world, _entity_id, "button");
	if (!is_struct(_button) || !_button.enabled || _button.focused == _focused){
		return;
	}
	_button.focused = _focused;
	if (_focused){
		scr_ui_juice_trigger(_world, _entity_id, "focus", {duration: 0.16});
	}
}

function scr_ui_button_set_hovered(_world, _entity_id, _hovered){
	var _button = scr_ui_component_get(_world, _entity_id, "button");
	if (!is_struct(_button) || !_button.enabled || _button.hovered == _hovered){
		return;
	}
	_button.hovered = _hovered;
	if (_hovered){
		scr_ui_juice_trigger(_world, _entity_id, "focus", {duration: 0.12});
	}
}

function scr_ui_button_activate(_world, _entity_id){
	var _button = scr_ui_component_get(_world, _entity_id, "button");
	if (!is_struct(_button) || !_button.enabled || !_button.activatable){
		return false;
	}
	_button.pressed = true;
	scr_ui_juice_trigger(_world, _entity_id, "press", {duration: 0.12});
	scr_ui_event_emit(_world, "button_activate", _entity_id, {
		command: _button.command,
		payload: _button.payload
	});
	return true;
}

function scr_ui_button_visual_state(_world, _entity_id){
	var _button = scr_ui_component_get(_world, _entity_id, "button");
	if (!is_struct(_button) || !_button.enabled){
		return 0;
	}
	if (_button.pressed || _button.focused){
		return 2;
	}
	if (_button.hovered){
		return 1;
	}
	return 0;
}

function scr_ui_button_clear_pressed(_world){
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _button = scr_ui_component_get(_world, _entity_index, "button");
		if (is_struct(_button)){
			_button.pressed = false;
		}
	}
}

// ===== Full Project Inventory: scripts/scr_ui_input/scr_ui_input.gml =====
/// @desc Normalize keyboard and mouse input into reusable UI actions.

function scr_ui_input_create(_bindings = undefined){
	var _input = {
		bindings: {
			toggle: ord("P"),
			confirm: vk_enter,
			back: vk_escape,
			up: vk_up,
			down: vk_down,
			left: vk_left,
			right: vk_right,
			focus: vk_tab
		},
		down: {},
		pressed: {},
		released: {},
		repeated: {},
		repeat_clock: {},
		repeat_delay: 14,
		repeat_rate: 5,
		mouse_x: 0,
		mouse_y: 0,
		mouse_initialized: false,
		mouse_moved: false,
		mouse_activity: false,
		mouse_down: false,
		mouse_pressed: false,
		mouse_released: false,
		wheel: 0,
		keyboard_activity: false,
		last_input: "keyboard"
	};

	if (is_struct(_bindings)){
		var _keys = variable_struct_get_names(_bindings);
		for (var _index = 0; _index < array_length(_keys); _index++){
			var _key = _keys[_index];
			var _value = variable_struct_get(_bindings, _key);
			if (_key == "cancel"){
				_input.bindings.back = _value;
			} else {
				variable_struct_set(_input.bindings, _key, _value);
			}
		}
	}
	return _input;
}

function scr_ui_input_binding_down(_binding){
	if (is_array(_binding)){
		for (var _index = 0; _index < array_length(_binding); _index++){
			if (keyboard_check(_binding[_index])){
				return true;
			}
		}
		return false;
	}
	return !is_undefined(_binding) && keyboard_check(_binding);
}

function scr_ui_input_poll(_input){
	if (!is_struct(_input)){
		return;
	}
	var _previous_down = _input.down;
	_input.down = {};
	_input.pressed = {};
	_input.released = {};
	_input.repeated = {};
	_input.keyboard_activity = false;
	_input.mouse_moved = false;
	_input.mouse_activity = false;

	var _actions = variable_struct_get_names(_input.bindings);
	for (var _index = 0; _index < array_length(_actions); _index++){
		var _action = _actions[_index];
		var _binding = variable_struct_get(_input.bindings, _action);
		var _is_down = scr_ui_input_binding_down(_binding);
		var _target_action = scr_sas_ui_target_action(_action);
		if (_target_action != "" && variable_global_exists("SYS") && is_struct(global.SYS)
			&& variable_struct_exists(global.SYS, "input") && is_struct(global.SYS.input)
			&& variable_struct_exists(global.SYS.input, "actions") && is_struct(global.SYS.input.actions)
			&& variable_struct_exists(global.SYS.input.actions, _target_action)){
			var _target_state = variable_struct_get(global.SYS.input.actions, _target_action);
			if (is_struct(_target_state) && variable_struct_exists(_target_state, "held")){
				_is_down = _is_down || _target_state.held;
			}
		}
		var _was_down = variable_struct_exists(_previous_down, _action) && variable_struct_get(_previous_down, _action);
		variable_struct_set(_input.down, _action, _is_down);

		if (_is_down && !_was_down){
			variable_struct_set(_input.pressed, _action, true);
			variable_struct_set(_input.repeated, _action, true);
			variable_struct_set(_input.repeat_clock, _action, _input.repeat_delay);
			_input.keyboard_activity = true;
		} else if (_is_down){
			var _clock = variable_struct_exists(_input.repeat_clock, _action) ? variable_struct_get(_input.repeat_clock, _action) - 1 : _input.repeat_delay - 1;
			if (_clock <= 0){
				variable_struct_set(_input.repeated, _action, true);
				_clock = _input.repeat_rate;
				_input.keyboard_activity = true;
			}
			variable_struct_set(_input.repeat_clock, _action, _clock);
		} else {
			variable_struct_set(_input.repeat_clock, _action, 0);
		}

		if (_was_down && !_is_down){
			variable_struct_set(_input.released, _action, true);
		}
	}

	var _mouse_x = device_mouse_x_to_gui(0);
	var _mouse_y = device_mouse_y_to_gui(0);
	if (_input.mouse_initialized){
		_input.mouse_moved = _mouse_x != _input.mouse_x || _mouse_y != _input.mouse_y;
	} else {
		_input.mouse_initialized = true;
	}
	_input.mouse_x = _mouse_x;
	_input.mouse_y = _mouse_y;
	var _was_mouse_down = _input.mouse_down;
	var _mouse_down = mouse_check_button(mb_left);
	var _mouse_pressed_edge = mouse_check_button_pressed(mb_left);
	var _mouse_released_edge = mouse_check_button_released(mb_left);
	_input.mouse_down = _mouse_down;
	_input.mouse_pressed = _mouse_pressed_edge || (_mouse_down && !_was_mouse_down);
	_input.mouse_released = _mouse_released_edge || (!_mouse_down && _was_mouse_down);
	_input.wheel = mouse_wheel_up() - mouse_wheel_down();
	_input.mouse_activity = _input.mouse_moved || _input.mouse_pressed || _input.mouse_released || _input.wheel != 0;
	if (_input.mouse_activity){
		_input.last_input = "mouse";
	} else if (_input.keyboard_activity){
		_input.last_input = "keyboard";
	}
}

function scr_ui_input_action_pressed(_input, _action, _allow_repeat = true){
	if (!is_struct(_input)){
		return false;
	}
	var _pressed = variable_struct_exists(_input.pressed, _action) && variable_struct_get(_input.pressed, _action);
	if (_pressed || !_allow_repeat){
		return _pressed;
	}
	return variable_struct_exists(_input.repeated, _action) && variable_struct_get(_input.repeated, _action);
}

function scr_ui_input_key_pressed(_keycode){
	return keyboard_check_pressed(_keycode);
}

// ===== Full Project Inventory: scripts/scr_ui_navigation/scr_ui_navigation.gml =====
/// @desc Hierarchical focus navigation for reusable UI entities.

function scr_ui_navigation_create(_world, _input){
	return {
		world: _world,
		input: _input,
		states: {},
		current: "closed",
		previous: "closed",
		focus_group: "",
		focusables: [],
		focus_entity: -1,
		last_focus: {},
		stack: [],
		open_state: "closed",
		mode: "keyboard",
		last_event: undefined
	};
}

function scr_ui_navigation_register_state(_navigation, _name, _options = undefined){
	if (!is_struct(_navigation) || !is_string(_name)){
		return false;
	}
	var _state = {group: "", back_state: "", left_state: "", right_state: "", up_state: "", down_state: "", confirm_state: "", focus_state: ""};
	if (is_struct(_options)){
		var _keys = variable_struct_get_names(_options);
		for (var _index = 0; _index < array_length(_keys); _index++){
			var _key = _keys[_index];
			variable_struct_set(_state, _key, variable_struct_get(_options, _key));
		}
	}
	variable_struct_set(_navigation.states, _name, _state);
	return true;
}

function scr_ui_navigation_state(_navigation){
	if (!is_struct(_navigation) || !variable_struct_exists(_navigation.states, _navigation.current)){
		return undefined;
	}
	return variable_struct_get(_navigation.states, _navigation.current);
}

function scr_ui_navigation_collect_focusables(_navigation, _group){
	var _output = [];
	var _world = _navigation.world;
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _entity = scr_ui_entity_get(_world, _entity_index);
		if (!is_struct(_entity)){
			continue;
		}
		var _focusable = scr_ui_component_get(_world, _entity_index, "focusable");
		var _button = scr_ui_component_get(_world, _entity_index, "button");
		if (is_struct(_focusable) && _focusable.group == _group && _focusable.enabled
			&& is_struct(_button) && _button.enabled){
			array_push(_output, _entity_index);
		}
	}
	return _output;
}

function scr_ui_navigation_set_focus(_navigation, _entity_id){
	var _world = _navigation.world;
	if (_navigation.focus_entity == _entity_id){
		return;
	}
	if (_navigation.focus_entity >= 0){
		scr_ui_button_set_focused(_world, _navigation.focus_entity, false);
	}
	_navigation.focus_entity = -1;
	if (_entity_id >= 0){
		var _button = scr_ui_component_get(_world, _entity_id, "button");
		if (is_struct(_button) && _button.enabled){
			_navigation.focus_entity = _entity_id;
			scr_ui_button_set_focused(_world, _entity_id, true);
			if (string_length(_navigation.focus_group) > 0){
				variable_struct_set(_navigation.last_focus, _navigation.focus_group, _entity_id);
			}
		}
	}
}

function scr_ui_navigation_set_state(_navigation, _state_name, _initial_index = 0){
	if (!is_struct(_navigation) || !variable_struct_exists(_navigation.states, _state_name)){
		return false;
	}
	_navigation.previous = _navigation.current;
	_navigation.current = _state_name;
	var _state = scr_ui_navigation_state(_navigation);
	_navigation.focus_group = _state.group;
	_navigation.focusables = scr_ui_navigation_collect_focusables(_navigation, _navigation.focus_group);
	if (array_length(_navigation.focusables) <= 0){
		scr_ui_navigation_set_focus(_navigation, -1);
	} else {
		var _focus_index = clamp(_initial_index, 0, array_length(_navigation.focusables) - 1);
		if (variable_struct_exists(_navigation.last_focus, _navigation.focus_group)){
			var _last_entity = variable_struct_get(_navigation.last_focus, _navigation.focus_group);
			var _last_index = scr_ui_navigation_focus_index(_navigation, _last_entity);
			if (_last_index >= 0){
				_focus_index = _last_index;
			}
		}
		scr_ui_navigation_set_focus(_navigation, _navigation.focusables[_focus_index]);
	}
	return true;
}

function scr_ui_navigation_push(_navigation, _state_name, _initial_index = 0){
	if (!is_struct(_navigation) || !variable_struct_exists(_navigation.states, _state_name)){
		return false;
	}
	array_push(_navigation.stack, _navigation.current);
	return scr_ui_navigation_set_state(_navigation, _state_name, _initial_index);
}

function scr_ui_navigation_pop(_navigation, _fallback_state = "closed"){
	if (!is_struct(_navigation)){
		return false;
	}
	var _target_state = _fallback_state;
	if (array_length(_navigation.stack) > 0){
		_target_state = _navigation.stack[array_length(_navigation.stack) - 1];
		array_delete(_navigation.stack, array_length(_navigation.stack) - 1, 1);
	}
	return scr_ui_navigation_set_state(_navigation, _target_state, 0);
}

function scr_ui_navigation_focus_index(_navigation, _entity_id){
	for (var _index = 0; _index < array_length(_navigation.focusables); _index++){
		if (_navigation.focusables[_index] == _entity_id){
			return _index;
		}
	}
	return -1;
}

function scr_ui_navigation_refresh_group(_navigation){
	if (!is_struct(_navigation) || string_length(_navigation.focus_group) <= 0){
		return;
	}
	_navigation.focusables = scr_ui_navigation_collect_focusables(_navigation, _navigation.focus_group);
	if (array_length(_navigation.focusables) <= 0){
		scr_ui_navigation_set_focus(_navigation, -1);
		return;
	}
	var _current_index = scr_ui_navigation_focus_index(_navigation, _navigation.focus_entity);
	if (_current_index < 0){
		scr_ui_navigation_set_focus(_navigation, _navigation.focusables[0]);
	}
}

function scr_ui_navigation_move(_navigation, _direction){
	var _focus_index = scr_ui_navigation_focus_index(_navigation, _navigation.focus_entity);
	if (_focus_index < 0 || array_length(_navigation.focusables) <= 0){
		return;
	}
	var _current_focusable = scr_ui_component_get(_navigation.world, _navigation.focus_entity, "focusable");
	var _next_entity = -1;
	if (is_struct(_current_focusable) && is_struct(_current_focusable.route)
		&& variable_struct_exists(_current_focusable.route, _direction)){
		_next_entity = variable_struct_get(_current_focusable.route, _direction);
	}
	if (_next_entity >= 0){
		scr_ui_navigation_set_focus(_navigation, _next_entity);
		return;
	}
	var _step = (_direction == "up" || _direction == "left") ? -1 : 1;
	var _next_index = (_focus_index + _step + array_length(_navigation.focusables)) mod array_length(_navigation.focusables);
	scr_ui_navigation_set_focus(_navigation, _navigation.focusables[_next_index]);
}

function scr_ui_navigation_clear_hovered(_navigation){
	var _world = _navigation.world;
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _button = scr_ui_component_get(_world, _entity_index, "button");
		if (is_struct(_button)){
			scr_ui_button_set_hovered(_world, _entity_index, false);
		}
	}
}

function scr_ui_navigation_state_for_group(_navigation, _group){
	if (!is_struct(_navigation) || !is_struct(_navigation.states) || !is_string(_group)){
		return "";
	}
	var _state_names = variable_struct_get_names(_navigation.states);
	for (var _index = 0; _index < array_length(_state_names); _index++){
		var _state_name = _state_names[_index];
		var _state = variable_struct_get(_navigation.states, _state_name);
		if (is_struct(_state) && variable_struct_exists(_state, "group") && _state.group == _group){
			return _state_name;
		}
	}
	return "";
}

function scr_ui_navigation_pointer_entity(_navigation, _include_all_groups = false){
	var _input = _navigation.input;
	var _world = _navigation.world;
	var _target_entity = -1;
	var _entity_ids = _navigation.focusables;
	if (_include_all_groups){
		_entity_ids = [];
		for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
			var _entity = scr_ui_entity_get(_world, _entity_index);
			var _focusable = scr_ui_component_get(_world, _entity_index, "focusable");
			var _button = scr_ui_component_get(_world, _entity_index, "button");
			if (is_struct(_entity) && is_struct(_focusable) && _focusable.enabled
				&& is_struct(_button) && _button.enabled){
				array_push(_entity_ids, _entity_index);
			}
		}
	}
	for (var _index = 0; _index < array_length(_entity_ids); _index++){
		var _entity_id = _entity_ids[_index];
		if (scr_ui_flex_hit_test(_world, _entity_id, _input.mouse_x, _input.mouse_y)){
			_target_entity = _entity_id;
		}
	}
	return _target_entity;
}

function scr_ui_navigation_hover(_navigation, _target_entity = -1, _include_all_groups = false){
	var _world = _navigation.world;
	if (_target_entity < 0){
		_target_entity = scr_ui_navigation_pointer_entity(_navigation, _include_all_groups);
	}
	if (_include_all_groups){
		for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
			var _button = scr_ui_component_get(_world, _entity_index, "button");
			if (is_struct(_button)){
				scr_ui_button_set_hovered(_world, _entity_index, _entity_index == _target_entity);
			}
		}
	} else {
		for (var _index = 0; _index < array_length(_navigation.focusables); _index++){
			var _entity_id = _navigation.focusables[_index];
			scr_ui_button_set_hovered(_world, _entity_id, _entity_id == _target_entity);
		}
	}
	if (_target_entity >= 0){
		var _focusable = scr_ui_component_get(_world, _target_entity, "focusable");
		if (!_include_all_groups || (is_struct(_focusable) && _focusable.group == _navigation.focus_group)){
			scr_ui_navigation_set_focus(_navigation, _target_entity);
		}
	}
	return _target_entity;
}

function scr_ui_navigation_activate(_navigation, _entity_id = -1, _transition_state = true){
	var _target_entity = _entity_id >= 0 ? _entity_id : _navigation.focus_entity;
	if (_target_entity < 0){
		return;
	}
	var _state = scr_ui_navigation_state(_navigation);
	var _button = scr_ui_component_get(_navigation.world, _target_entity, "button");
	if (!is_struct(_button) || !_button.enabled || !_button.activatable){
		return;
	}
	if (!scr_ui_button_activate(_navigation.world, _target_entity)){
		return;
	}
	_navigation.last_event = {
		type: "button",
		entity: _target_entity,
		command: _button.command,
		payload: _button.payload
	};
	if (_transition_state){
		var _next_state = _state.confirm_state;
		if (_button.command == "close"){
			_next_state = "closed";
		}
		if (is_string(_next_state) && string_length(_next_state) > 0){
			scr_ui_navigation_set_state(_navigation, _next_state, 0);
		}
	}
}

function scr_ui_navigation_mouse_focus(_navigation, _entity_id){
	var _world = _navigation.world;
	var _focusable = scr_ui_component_get(_world, _entity_id, "focusable");
	if (!is_struct(_focusable) || !_focusable.enabled){
		return false;
	}
	var _target_state = scr_ui_navigation_state_for_group(_navigation, _focusable.group);
	if (string_length(_target_state) > 0 && _navigation.current != _target_state){
		scr_ui_navigation_set_state(_navigation, _target_state, 0);
	}
	if (_focusable.group == _navigation.focus_group){
		scr_ui_navigation_set_focus(_navigation, _entity_id);
	}
	return true;
}

function scr_ui_navigation_update(_navigation){
	_navigation.last_event = undefined;
	var _input = _navigation.input;
	var _state = scr_ui_navigation_state(_navigation);
	if (!is_struct(_state)){
		return;
	}

	if (_navigation.current == "closed"){
		if (scr_ui_input_action_pressed(_input, "toggle", false)){
			scr_ui_navigation_set_state(_navigation, _navigation.open_state, 0);
			_navigation.last_event = {type: "open"};
		}
		return;
	}

	var _keyboard_claimed = _input.keyboard_activity && !_input.mouse_pressed;
	var _confirm_pressed = scr_ui_input_action_pressed(_input, "confirm", false);
	if (_keyboard_claimed){
		_navigation.mode = "keyboard";
		scr_ui_navigation_clear_hovered(_navigation);
	}
	if (scr_ui_input_action_pressed(_input, "toggle", false) || scr_ui_input_action_pressed(_input, "back", false)){
		var _back_state = string_length(_state.back_state) > 0 ? _state.back_state : "closed";
		scr_ui_navigation_set_state(_navigation, _back_state, 0);
		_navigation.last_event = {type: _back_state == "closed" ? "close" : "back"};
		return;
	}

	if (_input.mouse_pressed && !_keyboard_claimed){
		_navigation.mode = "mouse";
		var _pointer_entity = scr_ui_navigation_pointer_entity(_navigation, true);
		if (_pointer_entity >= 0 && scr_ui_navigation_mouse_focus(_navigation, _pointer_entity)){
			scr_ui_navigation_hover(_navigation, _pointer_entity, true);
			scr_ui_navigation_activate(_navigation, _pointer_entity, false);
			return;
		}
	}

	if (_input.mouse_activity && !_keyboard_claimed && !_confirm_pressed){
		_navigation.mode = "mouse";
		scr_ui_navigation_hover(_navigation, -1, true);
		return;
	}

	var _direction = "";
	if (scr_ui_input_action_pressed(_input, "up")) _direction = "up";
	if (scr_ui_input_action_pressed(_input, "down")) _direction = "down";
	if (scr_ui_input_action_pressed(_input, "left")) _direction = "left";
	if (scr_ui_input_action_pressed(_input, "right")) _direction = "right";
	if (string_length(_direction) > 0){
		var _current_focusable = scr_ui_component_get(_navigation.world, _navigation.focus_entity, "focusable");
		var _has_route = is_struct(_current_focusable) && is_struct(_current_focusable.route)
			&& variable_struct_exists(_current_focusable.route, _direction);
		var _state_field = scr_concat(_direction, "_state");
		var _state_target = variable_struct_exists(_state, _state_field) ? variable_struct_get(_state, _state_field) : "";
		if (_has_route){
			scr_ui_navigation_move(_navigation, _direction);
		} else if (is_string(_state_target) && string_length(_state_target) > 0){
			scr_ui_navigation_set_state(_navigation, _state_target, 0);
		} else {
			scr_ui_navigation_move(_navigation, _direction);
		}
	}

	if (scr_ui_input_action_pressed(_input, "focus", false)){
		if (string_length(_state.focus_state) > 0){
			scr_ui_navigation_set_state(_navigation, _state.focus_state, 0);
		}
	}
	if (_confirm_pressed){
		scr_ui_navigation_activate(_navigation);
	}
}

// ===== Full Project Inventory: scripts/scr_ui_flex/scr_ui_flex.gml =====
/// @desc Flex Panel bindings shared by UI entities.

function scr_ui_flex_bind(_world, _entity_id, _node, _role = ""){
	if (!is_struct(_world) || _entity_id < 0){
		return false;
	}
	scr_ui_component_add(_world, _entity_id, "flex", {
		node: _node,
		role: _role
	});
	scr_ui_component_add(_world, _entity_id, "bounds", {
		left: 0,
		top: 0,
		width: 0,
		height: 0
	});
	scr_ui_visual_ensure(_world, _entity_id);
	return true;
}

function scr_ui_flex_sync(_world){
	if (!is_struct(_world) || _world.destroyed){
		return;
	}
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _entity = scr_ui_entity_get(_world, _entity_index);
		if (!is_struct(_entity) || !variable_struct_exists(_entity.components, "flex")){
			continue;
		}
		var _flex = variable_struct_get(_entity.components, "flex");
		var _bounds = scr_ui_component_get(_world, _entity_index, "bounds");
		if (!is_struct(_bounds)){
			_bounds = {};
			scr_ui_component_add(_world, _entity_index, "bounds", _bounds);
		}
		var _position = flexpanel_node_layout_get_position(_flex.node, false);
		_bounds.left = _position.left;
		_bounds.top = _position.top;
		_bounds.width = _position.width;
		_bounds.height = _position.height;
	}
	_world.dirty_layout = false;
}

function scr_ui_flex_recalculate(_world, _root_node, _width, _height, _direction = flexpanel_direction.LTR){
	if (!is_struct(_world) || _world.destroyed){
		return;
	}
	flexpanel_calculate_layout(_root_node, _width, _height, _direction);
	scr_ui_flex_sync(_world);
}

function scr_ui_flex_hit_test(_world, _entity_id, _x, _y){
	var _bounds = scr_ui_component_get(_world, _entity_id, "bounds");
	if (!is_struct(_bounds)){
		return false;
	}
	var _hit_rect = _bounds;
	if (is_struct(scr_ui_component_get(_world, _entity_id, "visual"))){
		_hit_rect = scr_ui_visual_rect(_world, _entity_id, _bounds);
	}
	return point_in_rectangle(_x, _y, _hit_rect.left, _hit_rect.top, _hit_rect.left + _hit_rect.width, _hit_rect.top + _hit_rect.height);
}

// ===== Full Project Inventory: scripts/scr_ui_text_layout/scr_ui_text_layout.gml =====
/// @desc Shared text measurement, wrapping, markup, and drawing for UI systems.

function scr_ui_text_layout_build(_text, _font = -1, _max_width = 1000, _line_height = -1, _palette = undefined){
	if (!is_string(_text)){
		_text = string(_text);
	}

	var _previous_font = draw_get_font();
	if (is_real(_font) && _font >= 0){
		draw_set_font(_font);
	}

	var _resolved_line_height = _line_height > 0 ? _line_height : string_height("Hg") + 2;
	var _runs = [];
	var _text_length = string_length(_text);
	var _x = 0;
	var _y = 0;
	var _line_width = 0;
	var _max_line_width = 0;
	var _line_start = 0;
	var _last_space = -1;
	var _visible_index = 0;
	var _color = c_white;
	var _effect = 0;
	var _colors = {
		error: c_red,
		good: c_green,
		accent: c_blue,
		warning: c_yellow,
		muted: c_gray,
		text: c_white
	};
	if (is_struct(_palette)){
		var _palette_keys = variable_struct_get_names(_palette);
		for (var _palette_index = 0; _palette_index < array_length(_palette_keys); _palette_index++){
			var _palette_key = _palette_keys[_palette_index];
			variable_struct_set(_colors, _palette_key, variable_struct_get(_palette, _palette_key));
		}
	}

	for (var _index = 1; _index <= _text_length; _index++){
		var _char = string_char_at(_text, _index);
		if (_char == "\r"){
			continue;
		}

		if (_char == "#" && _index < _text_length){
			var _command = string_char_at(_text, _index + 1);
			switch (_command){
				case "r": _color = _colors.error; _index++; continue;
				case "g": _color = _colors.good; _index++; continue;
				case "b": _color = _colors.accent; _index++; continue;
				case "y": _color = _colors.warning; _index++; continue;
				case "m": _color = _colors.muted; _index++; continue;
				case "k": _color = c_black; _index++; continue;
				case "w": _color = _colors.text; _index++; continue;
				case "0": _effect = 0; _index++; continue;
				case "1": _effect = 1; _index++; continue;
				case "2": _effect = 2; _index++; continue;
			}
		}

		if (_char == "\n"){
			_x = 0;
			_line_width = 0;
			_y += _resolved_line_height;
			_line_start = array_length(_runs);
			_last_space = -1;
			continue;
		}

		if (_char == " " && _x == 0){
			continue;
		}

		var _char_width = string_width(_char);
		if (_max_width > 0 && _x > 0 && _x + _char_width > _max_width){
			if (_last_space >= _line_start){
				var _space_run = _runs[_last_space];
				_space_run.draw = false;
				var _move_start = _last_space + 1;
				var _base_x = 0;
				if (_move_start < array_length(_runs)){
					_base_x = _runs[_move_start].x;
				}
				_y += _resolved_line_height;
				_x = 0;
				_line_width = 0;
				for (var _move_index = _move_start; _move_index < array_length(_runs); _move_index++){
					var _move_run = _runs[_move_index];
					_move_run.x -= _base_x;
					_move_run.y = _y;
					var _move_width = string_width(_move_run.char);
					_x = max(_x, _move_run.x + _move_width);
					_line_width = _x;
				}
				_line_start = _move_start;
				_last_space = -1;
			} else {
				_x = 0;
				_line_width = 0;
				_y += _resolved_line_height;
				_line_start = array_length(_runs);
				_last_space = -1;
			}
		}

		array_push(_runs, {
			char: _char,
			x: _x,
			y: _y,
			color: _color,
			effect: _effect,
			visible_index: _visible_index,
			draw: true
		});
		_visible_index++;
		_x += _char_width;
		_line_width = _x;
		_max_line_width = max(_max_line_width, _line_width);
		if (_char == " "){
			_last_space = array_length(_runs) - 1;
		}
	}

	draw_set_font(_previous_font);
	return {
		runs: _runs,
		width: _max_line_width,
		height: max(_resolved_line_height, _y + _resolved_line_height),
		line_height: _resolved_line_height,
		characters: _visible_index
	};
}

function scr_ui_text_layout_draw(_layout, _x, _y, _font = -1, _style = undefined, _visible_characters = -1){
	if (!is_struct(_layout) || !is_array(_layout.runs)){
		return;
	}

	var _previous_font = draw_get_font();
	if (is_real(_font) && _font >= 0){
		draw_set_font(_font);
	}

	var _text_color = c_white;
	var _outline_color = c_black;
	var _outline_width = 1;
	var _alpha = 1;
	if (is_struct(_style)){
		if (variable_struct_exists(_style, "text_color")) _text_color = _style.text_color;
		if (variable_struct_exists(_style, "outline_color")) _outline_color = _style.outline_color;
		if (variable_struct_exists(_style, "outline_width")) _outline_width = _style.outline_width;
		if (variable_struct_exists(_style, "alpha")) _alpha = _style.alpha;
	}

	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_alpha(_alpha);
	for (var _index = 0; _index < array_length(_layout.runs); _index++){
		var _run = _layout.runs[_index];
		if (!_run.draw || (_visible_characters >= 0 && _run.visible_index >= _visible_characters)){
			continue;
		}

		var _run_color = _run.color == c_white ? _text_color : _run.color;
		var _offset_x = 0;
		var _offset_y = 0;
		if (_run.effect == 1){
			_offset_x = sin(current_time * 0.03 + _run.visible_index) * 0.8;
			_offset_y = cos(current_time * 0.04 + _run.visible_index) * 0.8;
		} else if (_run.effect == 2){
			_offset_y = sin(current_time * 0.01 + _run.visible_index * 0.45) * 1.5;
		}

		if (_outline_width > 0){
			draw_text_outline(_x + _run.x + _offset_x, _y + _run.y + _offset_y, _run.char, _outline_color, _run_color, _outline_width);
		} else {
			draw_set_color(_run_color);
			draw_text(_x + _run.x + _offset_x, _y + _run.y + _offset_y, _run.char);
		}
	}

	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_font(_previous_font);
}

// ===== Full Project Inventory: scripts/scr_ui_text_juice/scr_ui_text_juice.gml =====
/// @desc ECS-backed text channels with cached layout and event-driven juice.

function scr_ui_text_juice_default_channel(_options = undefined){
	var _channel = {
		text: "",
		font: -1,
		max_width: 1000,
		line_height: -1,
		palette: undefined,
		text_color: c_white,
		outline_color: c_black,
		outline_width: 1,
		alpha: 1,
		align: "left",
		valign: "top",
		reveal: false,
		reveal_characters: -1,
		reveal_speed: 60,
		reveal_timer: 0,
		offset_x: 0,
		offset_y: 0,
		layout: undefined,
		layout_width: -1,
		dirty: true,
		change_effect: "",
		effects: []
	};
	if (is_struct(_options)){
		var _keys = variable_struct_get_names(_options);
		for (var _index = 0; _index < array_length(_keys); _index++){
			var _key = _keys[_index];
			if (variable_struct_exists(_channel, _key)){
				variable_struct_set(_channel, _key, variable_struct_get(_options, _key));
			}
		}
	}
	return _channel;
}

function scr_ui_text_juice_channels(_world, _entity_id){
	var _channels = scr_ui_component_get(_world, _entity_id, "text_juice");
	if (!is_struct(_channels)){
		_channels = {channels: {}};
		scr_ui_component_add(_world, _entity_id, "text_juice", _channels);
	}
	return _channels;
}

function scr_ui_text_juice_get(_world, _entity_id, _channel_name = "default"){
	var _channels = scr_ui_component_get(_world, _entity_id, "text_juice");
	if (!is_struct(_channels) || !variable_struct_exists(_channels.channels, _channel_name)){
		return undefined;
	}
	return variable_struct_get(_channels.channels, _channel_name);
}

function scr_ui_text_juice_attach(_world, _entity_id, _channel_name = "default", _options = undefined){
	var _channels = scr_ui_text_juice_channels(_world, _entity_id);
	if (!variable_struct_exists(_channels.channels, _channel_name)){
		variable_struct_set(_channels.channels, _channel_name, scr_ui_text_juice_default_channel(_options));
	}
	return variable_struct_get(_channels.channels, _channel_name);
}

function scr_ui_text_juice_palette_changed(_previous_palette, _next_palette){
	if (!is_struct(_previous_palette) || !is_struct(_next_palette)) return _previous_palette != _next_palette;
	var _next_keys = variable_struct_get_names(_next_palette);
	var _previous_keys = variable_struct_get_names(_previous_palette);
	if (array_length(_next_keys) != array_length(_previous_keys)) return true;
	for (var _index = 0; _index < array_length(_next_keys); _index++){
		var _key = _next_keys[_index];
		if (!variable_struct_exists(_previous_palette, _key)
			|| variable_struct_get(_previous_palette, _key) != variable_struct_get(_next_palette, _key)) return true;
	}
	return false;
}

function scr_ui_text_juice_set(_world, _entity_id, _channel_name, _text, _options = undefined){
	var _channel = scr_ui_text_juice_get(_world, _entity_id, _channel_name);
	if (!is_struct(_channel)){
		_channel = scr_ui_text_juice_attach(_world, _entity_id, _channel_name, _options);
	}
	var _next_text = is_string(_text) ? _text : string(_text);
	if (_channel.text != _next_text){
		_channel.text = _next_text;
		_channel.dirty = true;
		_channel.reveal_timer = 0;
		_channel.reveal_characters = _channel.reveal ? 0 : -1;
		if (is_struct(_options) && variable_struct_exists(_options, "change_effect")
			&& string_length(_options.change_effect) > 0){
			scr_ui_text_juice_trigger(_world, _entity_id, _channel_name, _options.change_effect, {
				duration: variable_struct_exists(_options, "effect_duration") ? _options.effect_duration : 0.2,
				amplitude: variable_struct_exists(_options, "effect_amplitude") ? _options.effect_amplitude : 1
			});
		}
	}
	if (is_struct(_options)){
		var _keys = variable_struct_get_names(_options);
		for (var _index = 0; _index < array_length(_keys); _index++){
			var _key = _keys[_index];
			if (variable_struct_exists(_channel, _key) && _key != "text"){
				var _previous_value = variable_struct_get(_channel, _key);
				var _next_value = variable_struct_get(_options, _key);
				variable_struct_set(_channel, _key, _next_value);
				if (_key == "font" || _key == "max_width" || _key == "line_height"
					|| (_key == "palette" && scr_ui_text_juice_palette_changed(_previous_value, _next_value))) _channel.dirty = true;
				if (_key == "reveal" && _previous_value != _channel.reveal){
					_channel.reveal_characters = _channel.reveal ? 0 : -1;
					_channel.reveal_timer = 0;
				}
			}
		}
	}
	return _channel;
}

function scr_ui_text_juice_trigger(_world, _entity_id, _channel_name, _effect_name, _options = undefined){
	var _channel = scr_ui_text_juice_get(_world, _entity_id, _channel_name);
	if (!is_struct(_channel)){
		_channel = scr_ui_text_juice_attach(_world, _entity_id, _channel_name);
	}
	var _duration = 0.2;
	var _amplitude = 1;
	if (is_struct(_options)){
		if (variable_struct_exists(_options, "duration")) _duration = _options.duration;
		if (variable_struct_exists(_options, "amplitude")) _amplitude = _options.amplitude;
		if (variable_struct_exists(_options, "reveal_speed")) _channel.reveal_speed = _options.reveal_speed;
	}
	if (_effect_name == "reveal"){
		_channel.reveal = true;
		_channel.reveal_characters = 0;
		_channel.reveal_timer = 0;
	}
	array_push(_channel.effects, {
		name: _effect_name,
		elapsed: 0,
		duration: max(0.01, _duration),
		amplitude: _amplitude
	});
}

function scr_ui_text_juice_step(_world, _delta_seconds){
	for (var _entity_index = 0; _entity_index < array_length(_world.entities); _entity_index++){
		var _channels = scr_ui_component_get(_world, _entity_index, "text_juice");
		if (!is_struct(_channels)) continue;
		var _names = variable_struct_get_names(_channels.channels);
		for (var _channel_index = 0; _channel_index < array_length(_names); _channel_index++){
			var _channel = variable_struct_get(_channels.channels, _names[_channel_index]);
			_channel.offset_x = 0;
			_channel.offset_y = 0;
			_channel.alpha = 1;
			if (_channel.reveal && is_struct(_channel.layout)){
				if (_channel.reveal_characters < _channel.layout.characters){
					_channel.reveal_timer += max(0, _delta_seconds) * _channel.reveal_speed;
					while (_channel.reveal_timer >= 1 && _channel.reveal_characters < _channel.layout.characters){
						_channel.reveal_timer -= 1;
						_channel.reveal_characters++;
					}
				}
			}
			for (var _effect_index = array_length(_channel.effects) - 1; _effect_index >= 0; _effect_index--){
				var _effect = _channel.effects[_effect_index];
				_effect.elapsed += max(0, _delta_seconds);
				var _progress = clamp(_effect.elapsed / _effect.duration, 0, 1);
				var _wave = sin(_progress * pi);
				switch (_effect.name){
					case "jitter":
						_channel.offset_x += sin(_effect.elapsed * 75) * _effect.amplitude * (1 - _progress);
						_channel.offset_y += cos(_effect.elapsed * 61) * _effect.amplitude * (1 - _progress);
						break;
					case "wave":
						_channel.offset_y -= _wave * _effect.amplitude;
						break;
					case "fade":
						_channel.alpha *= clamp(1 - _progress, 0, 1);
						break;
				}
				if (_progress >= 1) array_delete(_channel.effects, _effect_index, 1);
			}
		}
	}
}

function scr_ui_text_juice_draw(_world, _entity_id, _channel_name, _x, _y, _max_width = -1, _style = undefined){
	var _channel = scr_ui_text_juice_get(_world, _entity_id, _channel_name);
	if (!is_struct(_channel) || string_length(_channel.text) <= 0) return;
	var _width = _max_width > 0 ? _max_width : _channel.max_width;
	if (_channel.dirty || !is_struct(_channel.layout) || _channel.layout_width != _width){
		_channel.layout = scr_ui_text_layout_build(_channel.text, _channel.font, _width, _channel.line_height, _channel.palette);
		_channel.layout_width = _width;
		_channel.dirty = false;
	}
	var _visual = scr_ui_visual_ensure(_world, _entity_id);
	var _draw_x = _x + _channel.offset_x + _visual.offset_x + _visual.juice_offset_x;
	var _draw_y = _y + _channel.offset_y + _visual.offset_y + _visual.juice_offset_y;
	if (_channel.align == "center") _draw_x -= _channel.layout.width * 0.5;
	if (_channel.align == "right") _draw_x -= _channel.layout.width;
	if (_channel.valign == "middle") _draw_y -= _channel.layout.height * 0.5;
	if (_channel.valign == "bottom") _draw_y -= _channel.layout.height;
	var _draw_style = {
		text_color: _channel.text_color,
		outline_color: _channel.outline_color,
		outline_width: _channel.outline_width,
		alpha: _channel.alpha * _visual.alpha * _visual.juice_alpha
	};
	if (is_struct(_style)){
		var _keys = variable_struct_get_names(_style);
		for (var _index = 0; _index < array_length(_keys); _index++){
			variable_struct_set(_draw_style, _keys[_index], variable_struct_get(_style, _keys[_index]));
		}
	}
	scr_ui_text_layout_draw(_channel.layout, _draw_x, _draw_y, _channel.font, _draw_style, _channel.reveal ? _channel.reveal_characters : -1);
}

// ===== Full Project Inventory: scripts/scr_ui_textbox/scr_ui_textbox.gml =====
/// @desc Flex Panel and ECS backed textbox controller.

function scr_ui_textbox_default_theme(){
	return {
		panel: c_white,
		panel_alt: c_white,
		text: c_white,
	muted: make_color_rgb(180, 190, 220),
	accent: make_color_rgb(255, 218, 120),
	good: make_color_rgb(137, 242, 158),
	error: make_color_rgb(255, 104, 112),
		warning: make_color_rgb(255, 218, 120),
		outline: c_black,
		choice_text: c_white,
		choice_hover: make_color_rgb(255, 238, 150),
		choice_selected: make_color_rgb(255, 218, 120)
	};
}

function scr_ui_textbox_merge(_base, _override){
	if (!is_struct(_override)){
		return _base;
	}
	var _keys = variable_struct_get_names(_override);
	for (var _index = 0; _index < array_length(_keys); _index++){
		var _key = _keys[_index];
		var _value = variable_struct_get(_override, _key);
		if (variable_struct_exists(_base, _key)
			&& is_struct(variable_struct_get(_base, _key))
			&& is_struct(_value)){
			variable_struct_set(_base, _key, scr_ui_textbox_merge(variable_struct_get(_base, _key), _value));
		} else {
			variable_struct_set(_base, _key, _value);
		}
	}
	return _base;
}

function scr_ui_textbox_normalize_choice(_choice){
	if (is_string(_choice)){
		return {label: _choice, command: "", callback: undefined, payload: undefined};
	}
	if (is_struct(_choice)){
		var _result = {
			label: variable_struct_exists(_choice, "label") ? string(_choice.label) : "OK",
			command: variable_struct_exists(_choice, "command") ? _choice.command : "",
			callback: variable_struct_exists(_choice, "callback") ? _choice.callback : undefined,
			payload: variable_struct_exists(_choice, "payload") ? _choice.payload : undefined
		};
		return _result;
	}
	return {label: string(_choice), command: "", callback: undefined, payload: undefined};
}

function scr_ui_textbox_normalize_message(_message){
	var _result = {
		text: "",
		speaker: "",
		choices: [],
		auto_close: false,
		auto_close_seconds: 0,
		callback: undefined,
		payload: undefined
	};
	if (is_string(_message) || is_real(_message)){
		_result.text = string(_message);
		return _result;
	}
	if (!is_struct(_message)){
		return _result;
	}
	if (variable_struct_exists(_message, "text")) _result.text = string(_message.text);
	if (variable_struct_exists(_message, "speaker")) _result.speaker = string(_message.speaker);
	if (variable_struct_exists(_message, "name")) _result.speaker = string(_message.name);
	var _has_auto_close = variable_struct_exists(_message, "auto_close");
	if (variable_struct_exists(_message, "auto_close_seconds") && is_real(_message.auto_close_seconds)){
		_result.auto_close_seconds = max(0, _message.auto_close_seconds);
		if (!_has_auto_close) _result.auto_close = _result.auto_close_seconds > 0;
	}
	if (variable_struct_exists(_message, "duration") && is_real(_message.duration)){
		_result.auto_close_seconds = max(0, _message.duration);
		if (!_has_auto_close) _result.auto_close = _result.auto_close_seconds > 0;
	}
	if (_has_auto_close && !is_undefined(_message.auto_close)) _result.auto_close = _message.auto_close ? true : false;
	if (variable_struct_exists(_message, "wait_for_input") && !is_undefined(_message.wait_for_input) && _message.wait_for_input){
		_result.auto_close = false;
	}
	if (variable_struct_exists(_message, "callback")) _result.callback = _message.callback;
	if (variable_struct_exists(_message, "payload")) _result.payload = _message.payload;
	var _raw_choices = [];
	if (variable_struct_exists(_message, "choices") && is_array(_message.choices)) _raw_choices = _message.choices;
	if (variable_struct_exists(_message, "options") && is_array(_message.options)) _raw_choices = _message.options;
	for (var _choice_index = 0; _choice_index < array_length(_raw_choices); _choice_index++){
		array_push(_result.choices, scr_ui_textbox_normalize_choice(_raw_choices[_choice_index]));
	}
	return _result;
}

function scr_ui_textbox_node_rect(_textbox, _entity_id){
	var _bounds = scr_ui_component_get(_textbox.world, _entity_id, "bounds");
	if (!is_struct(_bounds)){
		return {left: 0, top: 0, width: 0, height: 0, alpha: 1};
	}
	var _rect = scr_ui_visual_rect(_textbox.world, _entity_id, _bounds);
	if (_entity_id != _textbox.panel_entity){
		var _panel_visual = scr_ui_visual_ensure(_textbox.world, _textbox.panel_entity);
		_rect.left += _panel_visual.offset_x + _panel_visual.juice_offset_x;
		_rect.top += _panel_visual.offset_y + _panel_visual.juice_offset_y;
		_rect.alpha *= _panel_visual.alpha * _panel_visual.juice_alpha;
	}
	return _rect;
}

function scr_ui_textbox_sync_ecs(_textbox){
	var _component = scr_ui_component_get(_textbox.world, _textbox.root_entity, "textbox");
	if (!is_struct(_component)){
		return;
	}
	_component.state = _textbox.state;
	_component.open = _textbox.open;
	_component.modal = _textbox.modal;
	_component.interactive = _textbox.interactive;
	_component.message_index = _textbox.message_index;
}

function scr_ui_textbox_set_choice_buttons(_textbox, _enabled){
	var _choices = is_struct(_textbox.current) && is_array(_textbox.current.choices) ? _textbox.current.choices : [];
	for (var _index = 0; _index < array_length(_textbox.choice_entities); _index++){
		var _entity_id = _textbox.choice_entities[_index];
		var _button = scr_ui_component_get(_textbox.world, _entity_id, "button");
		var _has_choice = _index < array_length(_choices);
		if (is_struct(_button)){
			_button.label = _has_choice ? _choices[_index].label : "";
			_button.payload = _has_choice ? {choice_index: _index} : undefined;
			_button.command = "textbox_choice";
			_button.activatable = _has_choice;
		}
		scr_ui_button_set_enabled(_textbox.world, _entity_id, _enabled && _has_choice);
	}
	if (is_struct(_textbox.navigation)){
		scr_ui_navigation_refresh_group(_textbox.navigation);
	}
}

function scr_ui_textbox_load_current(_textbox){
	if (array_length(_textbox.messages) <= 0){
		scr_ui_textbox_close(_textbox);
		return;
	}
	_textbox.message_index = 0;
	_textbox.current = _textbox.messages[0];
	_textbox.reveal_characters = 0;
	_textbox.reveal_timer = 0;
	_textbox.selection = 0;
	_textbox.auto_close_timer = _textbox.current.auto_close ? _textbox.current.auto_close_seconds : 0;
	_textbox.state = "reading";
	scr_ui_textbox_set_choice_buttons(_textbox, false);
	if (is_struct(_textbox.navigation)){
		scr_ui_navigation_set_state(_textbox.navigation, "reading", 0);
	}
	if (is_callable(_textbox.current.callback)){
		_textbox.current.callback();
	}
	scr_ui_textbox_sync_ecs(_textbox);
}

function scr_ui_textbox_create(_world = undefined, _options = undefined, _parent_id = -1){
	var _settings = is_struct(_options) ? _options : {};
	if (!is_struct(_world)){
		_world = scr_ui_world_create({kind: "textbox"});
	}

	var _input_owned = true;
	var _input = undefined;
	if (variable_struct_exists(_settings, "input") && is_struct(_settings.input)){
		_input = _settings.input;
		_input_owned = variable_struct_exists(_settings, "input_owned") ? _settings.input_owned : false;
	} else {
		var _bindings = variable_struct_exists(_settings, "bindings") ? _settings.bindings : undefined;
		_input = scr_ui_input_create(_bindings);
	}

	var _theme = scr_ui_textbox_default_theme();
	if (variable_struct_exists(_settings, "theme")) _theme = scr_ui_textbox_merge(_theme, _settings.theme);
	var _sprites = {
		panel: spr_panel2,
		choice: spr_panel4,
		speaker: spr_panel4
	};
	if (variable_struct_exists(_settings, "sprites")) _sprites = scr_ui_textbox_merge(_sprites, _settings.sprites);

	var _layout = {
		position: "absolute",
		left: "6%",
		bottom: 16,
		width: "88%",
		height: 220,
		padding: 12,
		gap: 6,
		header_height: 26,
		choice_height: 28,
		choice_gap: 4,
		prompt_height: 22
	};
	if (variable_struct_exists(_settings, "layout")) _layout = scr_ui_textbox_merge(_layout, _settings.layout);
	var _max_choices = variable_struct_exists(_settings, "max_choices") ? max(1, _settings.max_choices) : 3;
	var _choice_specs = [];
	for (var _choice_index = 0; _choice_index < _max_choices; _choice_index++){
		array_push(_choice_specs, {
			name: scr_concat("textbox_choice_", _choice_index),
			height: _layout.choice_height,
			flexShrink: 0,
			data: {kind: "textbox_choice", index: _choice_index}
		});
	}
	var _choices_height = _max_choices * _layout.choice_height + max(0, _max_choices - 1) * _layout.choice_gap;
	var _panel_spec = {
		name: "textbox_panel",
		position: _layout.position,
		left: _layout.left,
		bottom: _layout.bottom,
		width: _layout.width,
		height: _layout.height,
		padding: _layout.padding,
		gapRow: _layout.gap,
		flexDirection: "column",
		data: {kind: "textbox_panel"},
		nodes: [
			{name: "textbox_speaker", height: _layout.header_height, flexShrink: 0, data: {kind: "textbox_speaker"}},
			{name: "textbox_body", flex: 1, minHeight: 0, data: {kind: "textbox_body"}},
			{name: "textbox_choices", height: _choices_height, flexShrink: 0, flexDirection: "column", gapRow: _layout.choice_gap, data: {kind: "textbox_choices"}, nodes: _choice_specs},
			{name: "textbox_prompt", height: _layout.prompt_height, flexShrink: 0, data: {kind: "textbox_prompt"}}
		]
	};
	if (variable_struct_exists(_layout, "top")){
		variable_struct_remove(_panel_spec, "bottom");
		_panel_spec.top = _layout.top;
	}
	var _root_spec = {
		name: "textbox_root",
		width: "100%",
		height: "100%",
		data: {kind: "textbox_root"},
		nodes: [_panel_spec]
	};
	var _flex_root = flexpanel_create_node(_root_spec);
	var _flex_panel = flexpanel_node_get_child(_flex_root, 0);
	var _flex_speaker = flexpanel_node_get_child(_flex_panel, 0);
	var _flex_body = flexpanel_node_get_child(_flex_panel, 1);
	var _flex_choices = flexpanel_node_get_child(_flex_panel, 2);
	var _flex_prompt = flexpanel_node_get_child(_flex_panel, 3);
	var _flex_choice_nodes = [];
	for (var _node_index = 0; _node_index < _max_choices; _node_index++){
		array_push(_flex_choice_nodes, flexpanel_node_get_child(_flex_choices, _node_index));
	}

	var _root_entity = scr_ui_entity_create(_world, _parent_id);
	var _panel_entity = scr_ui_entity_create(_world, _root_entity);
	var _speaker_entity = scr_ui_entity_create(_world, _panel_entity);
	var _body_entity = scr_ui_entity_create(_world, _panel_entity);
	var _choices_entity = scr_ui_entity_create(_world, _panel_entity);
	var _prompt_entity = scr_ui_entity_create(_world, _panel_entity);
	scr_ui_flex_bind(_world, _root_entity, _flex_root, "textbox_root");
	scr_ui_flex_bind(_world, _panel_entity, _flex_panel, "textbox_panel");
	scr_ui_flex_bind(_world, _speaker_entity, _flex_speaker, "textbox_speaker");
	scr_ui_flex_bind(_world, _body_entity, _flex_body, "textbox_body");
	scr_ui_flex_bind(_world, _choices_entity, _flex_choices, "textbox_choices");
	scr_ui_flex_bind(_world, _prompt_entity, _flex_prompt, "textbox_prompt");	scr_ui_component_add(_world, _body_entity, "text", {layout: undefined, visible_characters: 0});
	scr_ui_component_add(_world, _speaker_entity, "text", {layout: undefined, visible_characters: -1});
	scr_ui_component_add(_world, _prompt_entity, "text", {layout: undefined, visible_characters: -1});

	var _textbox = {
		world: _world,
		input: _input,
		input_owned: _input_owned,
		root_entity: _root_entity,
		panel_entity: _panel_entity,
		speaker_entity: _speaker_entity,
		body_entity: _body_entity,
		choices_entity: _choices_entity,
		prompt_entity: _prompt_entity,
		choice_entities: [],
		flex: {root: _flex_root, panel: _flex_panel, speaker: _flex_speaker, body: _flex_body, choices: _flex_choices, prompt: _flex_prompt, choice_nodes: _flex_choice_nodes},
		layout: _layout,
		theme: _theme,
		sprites: _sprites,
		font: variable_struct_exists(_settings, "font") ? _settings.font : fnt_default_ui,
		messages: [],
		current: undefined,
		message_index: -1,
		state: "closed",
		open: false,
		modal: variable_struct_exists(_settings, "modal") ? _settings.modal : true,
		interactive: variable_struct_exists(_settings, "interactive") ? _settings.interactive : true,
		char_delay: variable_struct_exists(_settings, "char_delay") ? max(0, _settings.char_delay) : 0.025,
		reveal_characters: 0,
		reveal_timer: 0,
		auto_close_timer: 0,
		selection: 0,
		max_choices: _max_choices,
		on_show: variable_struct_exists(_settings, "on_show") ? _settings.on_show : undefined,
		on_clear: variable_struct_exists(_settings, "on_clear") ? _settings.on_clear : undefined,
		navigation: undefined
	};
	for (var _button_index = 0; _button_index < _max_choices; _button_index++){
		var _choice_entity = scr_ui_button_create(_world, {
			label: "",
			command: "textbox_choice",
			group: "textbox_choices",
			enabled: false,
			route: {}
		}, _choices_entity);
		array_push(_textbox.choice_entities, _choice_entity);
		scr_ui_flex_bind(_world, _choice_entity, _flex_choice_nodes[_button_index], "textbox_choice");
	}
	_textbox.navigation = scr_ui_navigation_create(_world, _input);
	_textbox.navigation.open_state = "reading";
	scr_ui_navigation_register_state(_textbox.navigation, "closed", {group: ""});
	scr_ui_navigation_register_state(_textbox.navigation, "reading", {group: "", back_state: "closed"});
	scr_ui_navigation_register_state(_textbox.navigation, "choices", {group: "textbox_choices", back_state: "reading", confirm_state: "choices"});
	scr_ui_navigation_set_state(_textbox.navigation, "closed");
	scr_ui_component_add(_world, _root_entity, "textbox", {state: "closed", open: false, modal: _textbox.modal, interactive: _textbox.interactive, message_index: -1});
	return _textbox;
}

function scr_ui_textbox_set_theme(_textbox, _theme){
	if (!is_struct(_textbox)) return;
	_textbox.theme = scr_ui_textbox_merge(scr_ui_textbox_default_theme(), _theme);
}

function scr_ui_textbox_style_value(_value){
	if (is_string(_value)){
		if (string_lower(_value) == "auto") return {value: 0, unit: flexpanel_unit.auto};
		var _percent = string_pos("%", _value);
		if (_percent > 0) return {value: real(string_copy(_value, 1, _percent - 1)), unit: flexpanel_unit.percent};
	}
	return {value: real(_value), unit: flexpanel_unit.point};
}

function scr_ui_textbox_set_layout(_textbox, _layout){
	if (!is_struct(_textbox) || !is_struct(_layout)) return;
	_textbox.layout = scr_ui_textbox_merge(_textbox.layout, _layout);
	var _panel = _textbox.flex.panel;
	if (variable_struct_exists(_layout, "position")){
		flexpanel_node_style_set_position_type(_panel, _layout.position == "absolute" ? flexpanel_position_type.absolute : flexpanel_position_type.relative);
	}
	if (variable_struct_exists(_layout, "width")){
		var _width = scr_ui_textbox_style_value(_layout.width);
		flexpanel_node_style_set_width(_panel, _width.value, _width.unit);
	}
	if (variable_struct_exists(_layout, "height")){
		var _height = scr_ui_textbox_style_value(_layout.height);
		flexpanel_node_style_set_height(_panel, _height.value, _height.unit);
	}
	if (variable_struct_exists(_layout, "left")){
		var _left = scr_ui_textbox_style_value(_layout.left);
		flexpanel_node_style_set_position(_panel, flexpanel_edge.left, _left.value, _left.unit);
	}
	if (variable_struct_exists(_layout, "top")){
		var _top = scr_ui_textbox_style_value(_layout.top);
		flexpanel_node_style_set_position(_panel, flexpanel_edge.top, _top.value, _top.unit);
	}
	if (variable_struct_exists(_layout, "bottom")){
		var _bottom = scr_ui_textbox_style_value(_layout.bottom);
		flexpanel_node_style_set_position(_panel, flexpanel_edge.bottom, _bottom.value, _bottom.unit);
	}
}

function scr_ui_textbox_rebind_input(_textbox, _input, _input_owned = false){
	if (!is_struct(_textbox) || !is_struct(_input)) return false;
	_textbox.input = _input;
	_textbox.input_owned = _input_owned;
	_textbox.navigation.input = _input;
	return true;
}

function scr_ui_textbox_enqueue(_textbox, _message){
	if (!is_struct(_textbox)) return -1;
	var _message_data = scr_ui_textbox_normalize_message(_message);
	var _message_index = array_length(_textbox.messages);
	array_push(_textbox.messages, _message_data);
	if (!_textbox.open){
		scr_ui_textbox_open(_textbox);
	}
	return _message_index;
}

function scr_ui_textbox_add_choice(_textbox, _message_index, _label = "OK", _command = "", _callback = undefined, _payload = undefined){
	if (!is_struct(_textbox) || _message_index < 0 || _message_index >= array_length(_textbox.messages)) return false;
	var _message = _textbox.messages[_message_index];
	array_push(_message.choices, {label: string(_label), command: _command, callback: _callback, payload: _payload});
	if (_textbox.message_index == _message_index){
		scr_ui_textbox_set_choice_buttons(_textbox, _textbox.state == "choices");
	}
	return true;
}

function scr_ui_textbox_open(_textbox){
	if (!is_struct(_textbox)) return false;
	if (array_length(_textbox.messages) <= 0) return false;
	var _was_open = _textbox.open;
	_textbox.open = true;
	if (is_undefined(_textbox.current) || !_was_open){
		scr_ui_textbox_load_current(_textbox);
	}
	if (is_struct(_textbox.navigation) && _textbox.navigation.current == "closed"){
		scr_ui_navigation_set_state(_textbox.navigation, "reading", 0);
	}
	var _visual = scr_ui_visual_ensure(_textbox.world, _textbox.panel_entity);
	_visual.alpha = 0;
	_visual.offset_y = 12;
	scr_ui_tween_to(_textbox.world, _textbox.panel_entity, "visual.alpha", 1, 0.16, "quad_out");
	scr_ui_tween_to(_textbox.world, _textbox.panel_entity, "visual.offset_y", 0, 0.2, "cubic_out");
	scr_ui_juice_trigger(_textbox.world, _textbox.panel_entity, "enter", {duration: 0.22});
	if (!_was_open && is_callable(_textbox.on_show)) _textbox.on_show();
	scr_ui_textbox_sync_ecs(_textbox);
	return true;
}

function scr_ui_textbox_close(_textbox){
	if (!is_struct(_textbox)) return;
	var _was_open = _textbox.open;
	_textbox.open = false;
	_textbox.state = "closed";
	_textbox.current = undefined;
	_textbox.message_index = -1;
	_textbox.messages = [];
	_textbox.reveal_characters = 0;
	_textbox.auto_close_timer = 0;
	scr_ui_textbox_set_choice_buttons(_textbox, false);
	if (is_struct(_textbox.navigation)) scr_ui_navigation_set_state(_textbox.navigation, "closed", 0);
	if (_was_open && is_callable(_textbox.on_clear)) _textbox.on_clear();
	scr_ui_textbox_sync_ecs(_textbox);
}

function scr_ui_textbox_is_open(_textbox){
	return is_struct(_textbox) && _textbox.open;
}

function scr_ui_textbox_is_modal(_textbox){
	return is_struct(_textbox) && _textbox.open && _textbox.modal;
}

function scr_ui_textbox_done_typing(_textbox){
	if (!is_struct(_textbox) || !is_struct(_textbox.current)) return true;
	return _textbox.reveal_characters >= string_length(_textbox.current.text);
}

function scr_ui_textbox_advance(_textbox){
	if (!is_struct(_textbox) || !_textbox.open || !is_struct(_textbox.current)) return;
	if (!scr_ui_textbox_done_typing(_textbox)){
		_textbox.reveal_characters = string_length(_textbox.current.text);
		_textbox.reveal_timer = 0;
		return;
	}
	if (array_length(_textbox.current.choices) > 0){
		_textbox.state = "choices";
		scr_ui_textbox_set_choice_buttons(_textbox, true);
		scr_ui_navigation_set_state(_textbox.navigation, "choices", _textbox.selection);
		scr_ui_textbox_sync_ecs(_textbox);
		return;
	}
	array_delete(_textbox.messages, 0, 1);
	if (array_length(_textbox.messages) > 0){
		scr_ui_textbox_load_current(_textbox);
	} else {
		scr_ui_textbox_close(_textbox);
	}
}

function scr_ui_textbox_handle_navigation_event(_textbox){
	if (!is_struct(_textbox.navigation)) return;
	var _event = _textbox.navigation.last_event;
	if (!is_struct(_event) || _event.type != "button") return;
	if (_event.command != "textbox_choice" || !is_struct(_event.payload)) return;
	var _choice_index = _event.payload.choice_index;
	var _choices = is_struct(_textbox.current) ? _textbox.current.choices : [];
	if (_choice_index < 0 || _choice_index >= array_length(_choices)) return;
	var _choice = _choices[_choice_index];
	_textbox.selection = _choice_index;
	if (is_callable(_choice.callback)) _choice.callback();
	if (is_string(_choice.command) && string_length(_choice.command) > 0){
		scr_ui_event_emit(_textbox.world, _choice.command, _textbox.choice_entities[_choice_index], _choice.payload);
	}
	array_delete(_textbox.messages, 0, 1);
	if (array_length(_textbox.messages) > 0) scr_ui_textbox_load_current(_textbox); else scr_ui_textbox_close(_textbox);
}

function scr_ui_textbox_update(_textbox, _delta_seconds = -1){
	if (!is_struct(_textbox)) return;
	var _dt = _delta_seconds;
	if (_dt < 0) _dt = delta_time / 1000000;
	_dt = max(0, _dt);
	if (_textbox.open && is_struct(_textbox.current)){
		if (!scr_ui_textbox_done_typing(_textbox)){
			if (_textbox.char_delay <= 0){
				_textbox.reveal_characters = string_length(_textbox.current.text);
			} else {
				_textbox.reveal_timer += _dt;
				while (_textbox.reveal_timer >= _textbox.char_delay && !scr_ui_textbox_done_typing(_textbox)){
					_textbox.reveal_timer -= _textbox.char_delay;
					_textbox.reveal_characters++;
				}
			}
		}
		if (_textbox.interactive){
			if (scr_ui_input_action_pressed(_textbox.input, "back", false)){
				scr_ui_textbox_close(_textbox);
			} else if (_textbox.state == "reading" && scr_ui_input_action_pressed(_textbox.input, "confirm", false)){
				scr_ui_textbox_advance(_textbox);
			} else if (_textbox.state == "choices"){
				scr_ui_navigation_update(_textbox.navigation);
				scr_ui_textbox_handle_navigation_event(_textbox);
				if (_textbox.state == "choices" && _textbox.navigation.current == "reading"){
					_textbox.state = "reading";
					scr_ui_textbox_set_choice_buttons(_textbox, false);
					scr_ui_textbox_sync_ecs(_textbox);
				}
			}
		}
		if (_textbox.open && _textbox.current.auto_close && _textbox.auto_close_timer > 0 && scr_ui_textbox_done_typing(_textbox)
			&& array_length(_textbox.current.choices) <= 0){
			_textbox.auto_close_timer -= _dt;
			if (_textbox.auto_close_timer <= 0) scr_ui_textbox_close(_textbox);
		}
	}
	scr_ui_world_step(_textbox.world, _dt);
	scr_ui_textbox_sync_ecs(_textbox);
}

function scr_ui_textbox_draw(_textbox){
	if (!is_struct(_textbox) || !_textbox.open) return;
	var _gui_width = display_get_gui_width();
	var _gui_height = display_get_gui_height();
	flexpanel_calculate_layout(_textbox.flex.root, _gui_width, _gui_height, flexpanel_direction.LTR);
	scr_ui_flex_sync(_textbox.world);
	var _theme = _textbox.theme;
	var _palette = {
		error: _theme.error,
		good: variable_struct_exists(_theme, "good") ? _theme.good : _theme.choice_selected,
		accent: _theme.accent,
		warning: variable_struct_exists(_theme, "warning") ? _theme.warning : _theme.accent,
		muted: _theme.muted,
		text: _theme.text
	};
	var _panel = scr_ui_textbox_node_rect(_textbox, _textbox.panel_entity);
	var _speaker = scr_ui_textbox_node_rect(_textbox, _textbox.speaker_entity);
	var _body = scr_ui_textbox_node_rect(_textbox, _textbox.body_entity);
	var _prompt = scr_ui_textbox_node_rect(_textbox, _textbox.prompt_entity);
	draw_sprite_stretched_ext(_textbox.sprites.panel, 0, _panel.left, _panel.top, _panel.width, _panel.height, c_white, _panel.alpha);
	var _speaker_text = is_struct(_textbox.current) ? _textbox.current.speaker : "";
	if (string_length(_speaker_text) > 0){
		draw_sprite_stretched_ext(_textbox.sprites.speaker, 0, _speaker.left, _speaker.top, _speaker.width, _speaker.height, c_white, _speaker.alpha);
		var _speaker_layout = scr_ui_text_layout_build(_speaker_text, _textbox.font, max(1, _speaker.width - 16), -1, _palette);
		scr_ui_text_layout_draw(_speaker_layout, _speaker.left + 8, _speaker.top + 4, _textbox.font, {text_color: _theme.accent, outline_color: _theme.outline, outline_width: 1});
	}
	var _body_layout = scr_ui_text_layout_build(is_struct(_textbox.current) ? _textbox.current.text : "", _textbox.font, max(1, _body.width - 8), -1, _palette);
	var _body_component = scr_ui_component_get(_textbox.world, _textbox.body_entity, "text");
	if (is_struct(_body_component)){
		_body_component.layout = _body_layout;
		_body_component.visible_characters = _textbox.reveal_characters;
	}
	scr_ui_text_layout_draw(_body_layout, _body.left + 4, _body.top + 2, _textbox.font, {text_color: _theme.text, outline_color: _theme.outline, outline_width: 1}, _textbox.reveal_characters);
	for (var _choice_index = 0; _choice_index < array_length(_textbox.choice_entities); _choice_index++){
		var _choice_entity = _textbox.choice_entities[_choice_index];
		var _button = scr_ui_component_get(_textbox.world, _choice_entity, "button");
		if (!is_struct(_button) || !_button.enabled) continue;
		var _choice_rect = scr_ui_textbox_node_rect(_textbox, _choice_entity);
		var _choice_state = scr_ui_button_visual_state(_textbox.world, _choice_entity);
		var _choice_color = _choice_state >= 2 ? _theme.choice_selected : (_choice_state == 1 ? _theme.choice_hover : c_white);
		draw_sprite_stretched_ext(_textbox.sprites.choice, _choice_state, _choice_rect.left, _choice_rect.top, _choice_rect.width, _choice_rect.height, c_white, _choice_rect.alpha);
		var _choice_layout = scr_ui_text_layout_build(_button.label, _textbox.font, max(1, _choice_rect.width - 16), -1, _palette);
		scr_ui_text_layout_draw(_choice_layout, _choice_rect.left + 8, _choice_rect.top + 5, _textbox.font, {text_color: _choice_color, outline_color: _theme.outline, outline_width: 1});
	}
	var _prompt_text = _textbox.state == "choices" ? "Choose" : "ENTER  Advance     ESC  Close";
	var _prompt_layout = scr_ui_text_layout_build(_prompt_text, _textbox.font, max(1, _prompt.width - 8), -1, _palette);
	scr_ui_text_layout_draw(_prompt_layout, _prompt.left + 4, _prompt.top + 2, _textbox.font, {text_color: _theme.muted, outline_color: _theme.outline, outline_width: 1});
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

// ===== Full Project Inventory: scripts/scr_bag_create/scr_bag_create.gml =====
/*
	Bag API:

	scr_bag_create(slot_count, name, options)
	scr_bag_search(bag, item, identifier)
	scr_bag_add_item(bag, item, quantity)
	scr_bag_swap_slots(bag_a, bag_b, index_a, index_b)

	A bag stores item structs in `items` and matching quantities in `amount`.
	The optional `options` struct can override or extend the bag fields,
	including `identifier`, `resizable`, and `on_change`.
*/

/// create a new bag
/// @param slot_count
/// @param name
/// @param bag_options
function scr_bag_create(slot_count, _name="bag", _bag_options=undefined){
	var _bag = {
		items: array_create(slot_count, -1),
		amount: array_create(slot_count, 0),
		resizable: true,
		name: _name,
		identifier: "id"
	}
	if (!is_undefined(_bag_options) && is_struct(_bag_options)){
		var _keys = variable_struct_get_names(_bag_options);
		for (var _index = 0; _index < array_length(_keys); _index++){
			var _key = _keys[_index];
			variable_struct_set(_bag, _key, variable_struct_get(_bag_options, _key));
		}
	}
	return(_bag);
}

/// Return the first slot containing an item with the same identifier, or -1.
function scr_bag_search(_bag_obj, _item_obj, _identifier = undefined){
	if (!is_struct(_bag_obj) || !variable_struct_exists(_bag_obj, "items")){
		return(-1);
	}
	if (is_undefined(_identifier)){
		_identifier = variable_struct_exists(_bag_obj, "identifier") ? _bag_obj.identifier : "id";
	}
	if(!is_struct(_item_obj) || !variable_struct_exists(_item_obj, _identifier)){
		show_error("object identifier invalid", 0);
		return -1;
	}
	var _item_id = variable_struct_get(_item_obj, _identifier);
	for(var _index = 0; _index < array_length(_bag_obj.items); _index++){
		if(is_struct(_bag_obj.items[_index]) && variable_struct_exists(_bag_obj.items[_index], _identifier)){
			var _bag_item_id = variable_struct_get(_bag_obj.items[_index], _identifier);
			
			if(_bag_item_id == _item_id){
				return(_index);
			}
		}
	}
	return(-1);
}

/// Add or remove a quantity. Returns true when the request was applied.
function scr_bag_add_item(_bag_obj, _item_obj, _quantity){
	if (!is_struct(_bag_obj) || !is_struct(_item_obj) || _quantity == 0){
		return(false);
	}

	var _index = scr_bag_search(_bag_obj, _item_obj);
	var _success = false;
	if (_index >= 0){
		var _next_amount = _bag_obj.amount[_index] + _quantity;
		if (_next_amount <= 0){
			_bag_obj.items[_index] = -1;
			_bag_obj.amount[_index] = 0;
		} else {
			_bag_obj.amount[_index] = _next_amount;
		}
		_success = true;
	} else if (_quantity > 0){
		var _slot_count = array_length(_bag_obj.items);
		for (var _slot_index = 0; _slot_index < _slot_count; _slot_index++){
			if (!is_struct(_bag_obj.items[_slot_index])){
				_index = _slot_index;
				break;
			}
		}
		if (_index < 0){
			if (variable_struct_exists(_bag_obj, "resizable") && _bag_obj.resizable){
				array_push(_bag_obj.items, _item_obj);
				array_push(_bag_obj.amount, _quantity);
				_success = true;
			} 
		} else {
			_bag_obj.items[_index] = _item_obj;
			_bag_obj.amount[_index] = _quantity;
			_success = true;
		}
	}

	if (variable_struct_exists(_bag_obj, "on_change")){
		_bag_obj.on_change(_bag_obj, _item_obj, _quantity, _success);
	}
	return(_success);
}

/// Swap two occupied or empty slots. Returns false for invalid bags or indices.
function scr_bag_swap_slots(_bag_a, _bag_b, _index_a, _index_b){
	if (!is_struct(_bag_a) || !is_struct(_bag_b)
		|| !variable_struct_exists(_bag_a, "items") || !variable_struct_exists(_bag_b, "items")
		|| !variable_struct_exists(_bag_a, "amount") || !variable_struct_exists(_bag_b, "amount")
		|| _index_a < 0 || _index_b < 0
		|| _index_a >= array_length(_bag_a.items) || _index_b >= array_length(_bag_b.items)){
		return(false);
	}
	
	var _item_a = _bag_a.items[_index_a];
	var _amount_a = _bag_a.amount[_index_a];
	_bag_a.items[_index_a] = _bag_b.items[_index_b];
	_bag_a.amount[_index_a] = _bag_b.amount[_index_b];
	_bag_b.items[_index_b] = _item_a;
	_bag_b.amount[_index_b] = _amount_a;
	return(true);
}

// ===== Full Project Inventory: scripts/scr_recipe_requirements/scr_recipe_requirements.gml =====
/// @desc Build an atomic recipe requirement report before any inventory mutation.

function scr_recipe_requirement_index(_entries, _item){
	if (!is_struct(_item) || !variable_struct_exists(_item, "id")) return -1;
	for (var _index = 0; _index < array_length(_entries); _index++){
		var _entry = _entries[_index];
		if (is_struct(_entry.item) && variable_struct_exists(_entry.item, "id") && _entry.item.id == _item.id){
			return _index;
		}
	}
	return -1;
}

function scr_recipe_requirement_report(_recipe, _bag){
	var _report = {
		valid: false,
		can_craft: false,
		consumed: false,
		success: false,
		entries: [],
		recipe: _recipe,
		bag: _bag
	};
	if (!is_struct(_recipe) || !is_struct(_bag) || !is_struct(_recipe.data)
		|| !variable_struct_exists(_recipe.data, "use") || !variable_struct_exists(_recipe.data, "qty")
		|| !is_array(_recipe.data.use) || !is_array(_recipe.data.qty)){
		return _report;
	}
	_report.valid = array_length(_recipe.data.use) == array_length(_recipe.data.qty);
	if (!_report.valid) return _report;
	_report.can_craft = true;
	for (var _index = 0; _index < array_length(_recipe.data.use); _index++){
		var _item = _recipe.data.use[_index];
		var _required = max(0, _recipe.data.qty[_index]);
		var _entry_index = scr_recipe_requirement_index(_report.entries, _item);
		if (_entry_index < 0){
			var _slot = scr_bag_search(_bag, _item);
			var _available = _slot >= 0 ? _bag.amount[_slot] : 0;
			array_push(_report.entries, {
				item: _item,
				name: is_struct(_item) && variable_struct_exists(_item, "name") ? _item.name : "Unknown",
				slot: _slot,
				required: _required,
				available: _available,
				enough: _available >= _required,
				missing: max(0, _required - _available)
			});
		} else {
			var _existing = _report.entries[_entry_index];
			_existing.required += _required;
			_existing.enough = _existing.available >= _existing.required;
			_existing.missing = max(0, _existing.required - _existing.available);
		}
	}
	for (var _entry_index = 0; _entry_index < array_length(_report.entries); _entry_index++){
		if (!_report.entries[_entry_index].enough) _report.can_craft = false;
	}
	return _report;
}

function scr_recipe_requirement_consume(_report){
	if (!is_struct(_report) || !_report.valid || !_report.can_craft || !is_struct(_report.bag)) return false;
	for (var _index = 0; _index < array_length(_report.entries); _index++){
		var _entry = _report.entries[_index];
		if (_entry.required > 0 && !scr_bag_add_item(_report.bag, _entry.item, -_entry.required)){
			return false;
		}
	}
	_report.consumed = true;
	_report.success = true;
	return true;
}

function scr_recipe_attempt(_recipe, _bag){
	var _report = scr_recipe_requirement_report(_recipe, _bag);
	if (_report.can_craft){
		scr_recipe_requirement_consume(_report);
	}
	return _report;
}

// ===== Full Project Inventory: scripts/scr_setup_bag/scr_setup_bag.gml =====
/// @desc Create a category definition for scr_setup_bag.
/// @param name
/// @param bag_obj
/// @param kind
/// @param category_options
function scr_inventory_category(_name, _bag_obj, _kind = "items", _category_options = undefined){
	var _category = {
		name: _name,
		bag: _bag_obj,
		kind: _kind
	};
	if (!is_undefined(_category_options) && is_struct(_category_options)){
		_category = scr_inventory_merge_options(_category, _category_options);
	}
	return _category;
}

/// @desc Return the complete, themeable inventory setup used by the demo.
/// @param slot_count
function scr_inventory_default_options(_slot_count = 20){
	var _items_bag = scr_bag_create(_slot_count, "Items");
	var _equipment_bag = scr_bag_create(_slot_count, "Equipment");
	var _recipes_bag = scr_bag_create(_slot_count, "Recipes");
	var _quests_bag = scr_bag_create(_slot_count, "Quests");
	var _beastiary_bag = scr_bag_create(_slot_count, "Bestiary");

	return {
		slot_count: _slot_count,
		page_size: 10,
		categories: [
			scr_inventory_category("Items", _items_bag, "items"),
			scr_inventory_category("Equipment", _equipment_bag, "equipment"),
			scr_inventory_category("Recipes", _recipes_bag, "recipes"),
			scr_inventory_category("Quests", _quests_bag, "quests"),
			scr_inventory_category("Bestiary", _beastiary_bag, "beastiary")
		],
		labels: {
			title: "INVENTORY",
			party: "ARIN  LV 07",
			currency: "G  0420",
			leave: "Close",
			no_selection: "Choose an item",
			empty_slot: "—",
			use: "Use",
			craft: "Craft",
			inspect: "Inspect"
		},
		layout: {
			padding: 16,
			gap: 8,
			header_height: 48,
			footer_height: 28,
			nav_width: 124,
			details_width: 238,
			slot_header_height: 28,
			slot_height: 52,
			slot_columns: 2,
			slot_gap: 6
		},
		input: {
			toggle: ord("P"),
			confirm: vk_enter,
			cancel: vk_escape,
			up: vk_up,
			down: vk_down,
			left: vk_left,
			right: vk_right,
			focus: vk_tab,
			shop_toggle: ord("Q")
		},
		sprites: {
			frame: spr_invBox
		},
		textbox: {
			modal: false,
			interactive: false,
			max_choices: 1,
			char_delay: 0.02,
			layout: {
				height: 220,
				left: "6%",
				bottom: 16,
				width: "88%",
				choice_height: 0,
				choice_gap: 0
			}
		},
		font: fnt_default_ui,
		theme: {
			canvas: make_color_rgb(7, 9, 24),
			panel: make_color_rgb(18, 22, 52),
			panel_alt: make_color_rgb(28, 31, 68),
			panel_deep: make_color_rgb(10, 13, 34),
			shadow: make_color_rgb(4, 5, 12),
			text: make_color_rgb(235, 238, 255),
			muted: make_color_rgb(153, 164, 202),
			gold: make_color_rgb(255, 218, 120),
			accent: make_color_rgb(116, 224, 255),
			good: make_color_rgb(137, 242, 158),
			error: make_color_rgb(255, 104, 112),
			frame_normal: 0,
			frame_hover: 1,
			frame_selected: 2
		},
		callbacks: {
			on_open: function(_inventory = undefined){},
			on_close: function(_inventory = undefined){},
			on_category_changed: function(_index = -1, _bag = undefined){},
			on_item_selected: function(_index = -1, _bag = undefined){},
			on_item_activated: function(_item_obj = undefined, _index = -1){}
		}
	};
}

/// @desc Merge user options recursively so themes and layout sections can be overridden independently.
/// @param base_options
/// @param override_options
function scr_inventory_merge_options(_base_options, _override_options){
	if (is_undefined(_override_options) || !is_struct(_override_options)){
		return _base_options;
	}

	var _keys = variable_struct_get_names(_override_options);
	for (var _index = 0; _index < array_length(_keys); _index++){
		var _key = _keys[_index];
		var _value = variable_struct_get(_override_options, _key);
		if (variable_struct_exists(_base_options, _key)
			&& is_struct(variable_struct_get(_base_options, _key))
			&& is_struct(_value)){
			var _merged = scr_inventory_merge_options(variable_struct_get(_base_options, _key), _value);
			variable_struct_set(_base_options, _key, _merged);
		} else {
			variable_struct_set(_base_options, _key, _value);
		}
	}
	return _base_options;
}

/// @desc Set up bags, a native Flex Panel layout tree, and the inventory controller in one call.
/// @example scr_setup_bag({slot_count: 32, page_size: 12, layout: {slot_columns: 3}, theme: {gold: c_lime}})
/// @param inventory_options
function scr_setup_bag(_inventory_options = undefined){
	var _options = scr_inventory_default_options();
	if (!is_undefined(_inventory_options) && is_struct(_inventory_options)
		&& variable_struct_exists(_inventory_options, "slot_count")
		&& !variable_struct_exists(_inventory_options, "categories")){
		_options = scr_inventory_default_options(_inventory_options.slot_count);
	}
	_options = scr_inventory_merge_options(_options, _inventory_options);
	options = _options;

	page_size = max(1, options.page_size);
	list = [];
	category_indices = {};
	for (var _category_index = 0; _category_index < array_length(options.categories); _category_index++){
		var _category = options.categories[_category_index];
		var _category_bag = undefined;
		if (variable_struct_exists(_category, "bag")){
			_category_bag = _category.bag;
		}
		if (is_undefined(_category_bag) || !is_struct(_category_bag)){
			var _slot_count = variable_struct_exists(_category, "slot_count") ? _category.slot_count : 20;
			_category_bag = scr_bag_create(_slot_count, _category.name);
			_category.bag = _category_bag;
		}
		array_push(list, _category_bag);
		if (variable_struct_exists(_category, "kind")){
			variable_struct_set(category_indices, _category.kind, _category_index);
		}
	}
	array_push(list, {name: options.labels.leave, kind: "leave"});
	category_count = array_length(list) - 1;

	state = -1;
	focus = 1;
	button_index = -1;
	index_start = 0;
	index_select = -1;
	index_current = -1;
	user_selections = array_create(10, -1);
	crafting_list = [];

	layout = {};
	layout = scr_inventory_build_layout(options);
	layout_width = display_get_gui_width();
	layout_height = display_get_gui_height();
	scr_inventory_ui_rebuild();
	scr_inventory_layout_refresh();
}

/// @desc Look up a category by its semantic kind so custom category orders remain supported.
function scr_inventory_category_index(_kind){
	if (is_struct(category_indices) && variable_struct_exists(category_indices, _kind)){
		return variable_struct_get(category_indices, _kind);
	}
	return -1;
}

/// @desc Build the nested native Flex Panel tree used for every inventory surface.
/// @param inventory_options
function scr_inventory_build_layout(_inventory_options){
	if (variable_instance_exists(id, "ui_world") && is_struct(ui_world)){
		scr_ui_world_destroy(ui_world);
	}
	if (is_struct(layout) && variable_struct_exists(layout, "root")){
		flexpanel_delete_node(layout.root, true);
	}

	var _layout_options = _inventory_options.layout;
	var _slot_nodes = [];
	var _nav_nodes = [];
	var _slot_columns = max(1, _layout_options.slot_columns);
	var _slot_width = scr_concat(floor(100 / _slot_columns) - 2, "%");

	for (var _slot_index = 0; _slot_index < page_size; _slot_index++){
		array_push(_slot_nodes, {
			name: scr_concat("slot_", _slot_index),
			width: _slot_width,
			height: _layout_options.slot_height,
			flexShrink: 0,
			data: {kind: "slot", index: _slot_index}
		});
	}
	for (var _category_index = 0; _category_index <= category_count; _category_index++){
		array_push(_nav_nodes, {
			name: scr_concat("category_", _category_index),
			flex: 1,
			minHeight: 30,
			data: {kind: "category", index: _category_index}
		});
	}

	var _detail_nodes = [
		{name: "detail_title", height: 28, flexShrink: 0},
		{name: "detail_preview", height: 112, flexShrink: 0, alignItems: "center", justifyContent: "center"},
		{name: "detail_text", flex: 1, minHeight: 60},
		{name: "detail_action", height: 30, flexShrink: 0}
	];

	var _root_spec = {
		name: "inventory_root",
		width: "100%",
		height: "100%",
		flexDirection: "column",
		padding: _layout_options.padding,
		gapRow: _layout_options.gap,
		data: {kind: "root"},
		nodes: [
			{
				name: "header",
				height: _layout_options.header_height,
				flexShrink: 0,
				data: {kind: "header"}
			},
			{
				name: "body",
				flex: 1,
				minHeight: 0,
				flexDirection: "row",
				gapColumn: _layout_options.gap,
				data: {kind: "body"},
				nodes: [
					{
						name: "category_nav",
						width: _layout_options.nav_width,
						flexShrink: 0,
						flexDirection: "column",
						gapRow: _layout_options.slot_gap,
						data: {kind: "nav"},
						nodes: _nav_nodes
					},
					{
						name: "slot_surface",
						flex: 1,
						minWidth: 160,
						flexDirection: "column",
						gapRow: _layout_options.gap,
						data: {kind: "slots"},
						nodes: [
							{name: "slot_header", height: _layout_options.slot_header_height, flexShrink: 0},
							{
								name: "slot_grid",
								flex: 1,
								flexDirection: "row",
								flexWrap: "wrap",
								gapRow: _layout_options.slot_gap,
								gapColumn: _layout_options.slot_gap,
								alignContent: "flex-start",
								data: {kind: "slot_grid"},
								nodes: _slot_nodes
							}
						]
					},
					{
						name: "details",
						width: _layout_options.details_width,
						flexShrink: 0,
						padding: 10,
						gapRow: 4,
						flexDirection: "column",
						data: {kind: "details"},
						nodes: _detail_nodes
					}
				]
			},
			{
				name: "footer",
				height: _layout_options.footer_height,
				flexShrink: 0,
				data: {kind: "footer"}
			}
		]
	};

	var _root = flexpanel_create_node(_root_spec);
	var _body = flexpanel_node_get_child(_root, 1);
	var _nav = flexpanel_node_get_child(_body, 0);
	var _slot_surface = flexpanel_node_get_child(_body, 1);
	var _details = flexpanel_node_get_child(_body, 2);
	var _slot_grid = flexpanel_node_get_child(_slot_surface, 1);

	var _nav_handles = [];
	for (var _nav_index = 0; _nav_index <= category_count; _nav_index++){
		array_push(_nav_handles, flexpanel_node_get_child(_nav, _nav_index));
	}
	var _slot_handles = [];
	for (var _grid_index = 0; _grid_index < page_size; _grid_index++){
		array_push(_slot_handles, flexpanel_node_get_child(_slot_grid, _grid_index));
	}

	return {
		root: _root,
		header: flexpanel_node_get_child(_root, 0),
		body: _body,
		nav: _nav,
		nav_nodes: _nav_handles,
		slot_surface: _slot_surface,
		slot_header: flexpanel_node_get_child(_slot_surface, 0),
		slot_grid: _slot_grid,
		slot_nodes: _slot_handles,
		details: _details,
		detail_title: flexpanel_node_get_child(_details, 0),
		detail_preview: flexpanel_node_get_child(_details, 1),
		detail_text: flexpanel_node_get_child(_details, 2),
		detail_action: flexpanel_node_get_child(_details, 3),
		footer: flexpanel_node_get_child(_root, 2)
	};
}

/// @desc Recalculate the native Flex Panel tree after a window or GUI-size change.
function scr_inventory_layout_refresh(){
	if (!is_struct(layout) || !variable_struct_exists(layout, "root")){
		return;
	}
	layout_width = display_get_gui_width();
	layout_height = display_get_gui_height();
	flexpanel_calculate_layout(layout.root, layout_width, layout_height, flexpanel_direction.LTR);
	if (variable_instance_exists(id, "ui_world") && is_struct(ui_world)){
		scr_ui_flex_sync(ui_world);
	}
}

// ===== Full Project Inventory: scripts/scr_ui_inventory/scr_ui_inventory.gml =====
/// @desc High-level inventory wiring for the reusable UI components.

function scr_inventory_ui_rebuild(_restore_state = "closed", _restore_category = 0, _restore_slot = -1){
	if (variable_instance_exists(id, "ui_world") && is_struct(ui_world)){
		scr_ui_world_destroy(ui_world);
	}

	ui_world = scr_ui_world_create();
	ui_input = scr_ui_input_create(options.input);
	var _textbox_theme = {
		panel: options.theme.panel_deep,
		panel_alt: options.theme.panel_alt,
		text: options.theme.text,
		muted: options.theme.muted,
		accent: options.theme.gold,
		good: options.theme.good,
		error: options.theme.error,
		warning: options.theme.gold,
		outline: options.theme.shadow,
		choice_text: options.theme.text,
		choice_hover: options.theme.accent,
		choice_selected: options.theme.gold
	};
	var _textbox_options = {
		input: ui_input,
		input_owned: false,
		font: options.font,
		theme: _textbox_theme,
		sprites: {panel: spr_panel2, choice: spr_panel4, speaker: spr_panel4},
		modal: false,
		interactive: false,
		max_choices: 1,
		layout: {choice_height: 0, choice_gap: 0}
	};
	if (variable_struct_exists(options, "textbox") && is_struct(options.textbox)){
		_textbox_options = scr_ui_textbox_merge(_textbox_options, options.textbox);
	}
	if (!variable_instance_exists(id, "ui_textbox") || !is_struct(ui_textbox)){
		ui_textbox = scr_ui_textbox_create(undefined, _textbox_options);
	} else {
		scr_ui_textbox_rebind_input(ui_textbox, ui_input, false);
		scr_ui_textbox_set_theme(ui_textbox, _textbox_options.theme);
		ui_textbox.font = options.font;
	}
	ui_textbox_consumed_input = false;
	ui_navigation = scr_ui_navigation_create(ui_world, ui_input);
	ui_navigation.open_state = "categories";
	ui_root_entity = scr_ui_entity_create(ui_world);
	scr_ui_flex_bind(ui_world, ui_root_entity, layout.root, "root");

	ui_category_entities = [];
	ui_slot_entities = [];
	ui_action_entities = [];

	for (var _category_index = 0; _category_index <= category_count; _category_index++){
		var _command = _category_index == category_count ? "close" : "category_select";
		var _payload = {category_index: _category_index};
		var _button_entity = scr_ui_button_create(ui_world, {
			label: list[_category_index].name,
			command: _command,
			payload: _payload,
			group: "categories",
			route: {}
		}, ui_root_entity);
		array_push(ui_category_entities, _button_entity);
		scr_ui_flex_bind(ui_world, _button_entity, layout.nav_nodes[_category_index], "category");
	}
	for (var _category_route_index = 0; _category_route_index <= category_count; _category_route_index++){
		var _category_focusable = scr_ui_component_get(ui_world, ui_category_entities[_category_route_index], "focusable");
		if (_category_route_index > 0) _category_focusable.route.up = ui_category_entities[_category_route_index - 1];
		if (_category_route_index < category_count) _category_focusable.route.down = ui_category_entities[_category_route_index + 1];
	}

	var _slot_columns = max(1, options.layout.slot_columns);
	for (var _slot_index = 0; _slot_index < page_size; _slot_index++){
		var _slot_entity = scr_ui_button_create(ui_world, {
			label: "",
			command: "slot_select",
			payload: {slot_index: _slot_index},
			group: "slots",
			route: {},
			enabled: false
		}, ui_root_entity);
		array_push(ui_slot_entities, _slot_entity);
		scr_ui_flex_bind(ui_world, _slot_entity, layout.slot_nodes[_slot_index], "slot");
	}
	for (var _slot_route_index = 0; _slot_route_index < page_size; _slot_route_index++){
		var _slot_focusable = scr_ui_component_get(ui_world, ui_slot_entities[_slot_route_index], "focusable");
		if (_slot_route_index >= _slot_columns) _slot_focusable.route.up = ui_slot_entities[_slot_route_index - _slot_columns];
		if (_slot_route_index + _slot_columns < page_size) _slot_focusable.route.down = ui_slot_entities[_slot_route_index + _slot_columns];
		if (_slot_route_index mod _slot_columns > 0) _slot_focusable.route.left = ui_slot_entities[_slot_route_index - 1];
		if (_slot_route_index mod _slot_columns < _slot_columns - 1 && _slot_route_index + 1 < page_size) _slot_focusable.route.right = ui_slot_entities[_slot_route_index + 1];
	}

	var _primary_action = scr_ui_button_create(ui_world, {
		label: options.labels.use,
		command: "activate_item",
		group: "actions",
		enabled: false,
		route: {down: -1}
	}, ui_root_entity);
	var _cancel_action = scr_ui_button_create(ui_world, {
		label: options.labels.leave,
		command: "action_back",
		group: "actions",
		enabled: true,
		route: {up: _primary_action}
	}, ui_root_entity);
	var _primary_focusable = scr_ui_component_get(ui_world, _primary_action, "focusable");
	_primary_focusable.route.down = _cancel_action;
	array_push(ui_action_entities, _primary_action);
	array_push(ui_action_entities, _cancel_action);

	scr_ui_navigation_register_state(ui_navigation, "closed", {group: ""});
	scr_ui_navigation_register_state(ui_navigation, "categories", {
		group: "categories",
		back_state: "closed",
		right_state: "slots",
		confirm_state: "slots",
		focus_state: "slots"
	});
	scr_ui_navigation_register_state(ui_navigation, "slots", {
		group: "slots",
		back_state: "categories",
		left_state: "categories",
		confirm_state: "actions",
		focus_state: "categories"
	});
	scr_ui_navigation_register_state(ui_navigation, "actions", {
		group: "actions",
		back_state: "slots",
		left_state: "slots",
		focus_state: "slots"
	});
	scr_ui_navigation_set_state(ui_navigation, "closed");

	state = -1;
	index_select = -1;
	index_current = -1;
	ui_open = false;
	if (_restore_state != "closed"){
		ui_open = true;
		state = clamp(_restore_category, 0, category_count - 1);
		index_current = _restore_slot;
		scr_ui_navigation_set_state(ui_navigation, "categories", state);
		scr_inventory_ui_select_category(state, false);
		if (_restore_state == "actions"){
			scr_ui_navigation_set_state(ui_navigation, "actions", 0);
		}
	}
	scr_inventory_ui_sync_slots();
	scr_inventory_ui_sync_context();
	scr_inventory_ui_sync_text();
}

function scr_inventory_text_palette(){
	return {
		error: options.theme.error,
		good: options.theme.good,
		accent: options.theme.accent,
		warning: options.theme.gold,
		muted: options.theme.muted,
		text: options.theme.text
	};
}

function scr_inventory_text_set(_channel_name, _text, _color, _max_width = 1000, _align = "left", _valign = "top", _reveal = false, _change_effect = ""){
	if (!is_struct(ui_world) || ui_root_entity < 0) return;
	scr_ui_text_juice_set(ui_world, ui_root_entity, _channel_name, _text, {
		font: options.font,
		max_width: _max_width,
		palette: scr_inventory_text_palette(),
		text_color: _color,
		outline_color: options.theme.shadow,
		outline_width: 1,
		align: _align,
		valign: _valign,
		reveal: _reveal,
		change_effect: _change_effect,
		effect_duration: 0.2,
		effect_amplitude: 1
	});
}

function scr_inventory_item_detail_markup(_item_obj){
	if (!is_struct(_item_obj)) return "";
	var _text = variable_struct_exists(_item_obj, "desc") ? string(_item_obj.desc) : "";
	if (!is_struct(_item_obj.data)) return _text;
	if (variable_struct_exists(_item_obj.data, "hp")) _text += scr_concat("\n\n#gRestore:#w ", _item_obj.data.hp, " HP");
	if (variable_struct_exists(_item_obj.data, "dmg")) _text += scr_concat("\n\n#yDamage:#w ", _item_obj.data.dmg);
	if (variable_struct_exists(_item_obj.data, "plant")) _text += "\n\n#gPlantable seed#0";
	if (variable_struct_exists(_item_obj.data, "type")){
		_text += scr_concat("\n\n#yType:#w ", _item_obj.data.type);
		if (variable_struct_exists(_item_obj.data, "effect")) _text += scr_concat("\n#gEffect:#w ", _item_obj.data.effect);
		if (variable_struct_exists(_item_obj.data, "power")) _text += scr_concat("\n#yPower:#w ", _item_obj.data.power);
		if (variable_struct_exists(_item_obj.data, "defense")) _text += scr_concat("\n#yDefense:#w ", _item_obj.data.defense);
		return _text;
	}
	if (variable_struct_exists(_item_obj.data, "use") && variable_struct_exists(_item_obj.data, "qty")
		&& is_array(_item_obj.data.use) && is_array(_item_obj.data.qty)){
		var _report = scr_recipe_requirement_report(_item_obj, list[scr_inventory_category_index("items")]);
		_text += "\n\n#yRequirements:#w";
		for (var _entry_index = 0; _entry_index < array_length(_report.entries); _entry_index++){
			var _entry = _report.entries[_entry_index];
			var _prefix = _entry.enough ? "#g[OK] " : "#r[MISSING] ";
			_text += scr_concat("\n", _prefix, _entry.name, "  ", _entry.required, " / ", _entry.available, "#w");
		}
		if (variable_struct_exists(_item_obj.data, "time")) _text += scr_concat("\n\n#yTime:#w ", scr_timestring(_item_obj.data.time));
		return _text;
	}
	if (variable_struct_exists(_item_obj.data, "toString") && is_callable(_item_obj.data.toString)){
		_text += scr_concat("\n\n", _item_obj.data.toString());
	}
	return _text;
}

function scr_inventory_ui_sync_text(){
	if (!is_struct(ui_world) || ui_root_entity < 0 || !is_struct(options)) return;
	var _theme = options.theme;
	scr_inventory_text_set("closed_hint", "[P] Open inventory", _theme.gold, 220, "left", "middle", false, "wave");
	scr_inventory_text_set("header_title", options.labels.title, _theme.gold, 260, "left", "middle", false, "wave");
	scr_inventory_text_set("header_subtitle", "SORT YOUR TOOLS  /  SEEDS  /  FINDINGS", _theme.muted, 420, "left", "middle");
	scr_inventory_text_set("header_party", options.labels.party, _theme.accent, 240, "right", "middle");
	scr_inventory_text_set("header_currency", options.labels.currency, _theme.gold, 240, "right", "middle", false, "wave");
	scr_inventory_text_set("footer", "[TAB] Focus  [ARROWS] Move  [ENTER] Use  [P] Close", _theme.muted, 520, "left", "middle");
	scr_inventory_text_set("footer_tag", "GARDEN JOURNAL", _theme.accent, 220, "right", "middle");
	var _category_index = state >= 0 ? clamp(state, 0, max(0, category_count - 1)) : 0;
	var _bag = list[_category_index];
	for (var _nav_index = 0; _nav_index <= category_count; _nav_index++){
		var _selected = state == _nav_index;
		var _nav_color = _selected ? _theme.gold : _theme.text;
		scr_inventory_text_set(scr_concat("category_", _nav_index), scr_concat(_selected ? "> " : "  ", list[_nav_index].name), _nav_color, 112, "left", "middle", false, _selected ? "wave" : "");
	}
	var _bag_length = array_length(_bag.items);
	var _slot_end = min(_bag_length, index_start + page_size);
	scr_inventory_text_set("slot_header", list[_category_index].name, _theme.accent, 260, "left", "middle", false, "wave");
	scr_inventory_text_set("slot_count", scr_concat("SLOTS ", index_start + 1, "-", max(index_start + 1, _slot_end), " / ", _bag_length), _theme.muted, 180, "right", "middle");
	for (var _visible_index = 0; _visible_index < page_size; _visible_index++){
		var _bag_index = index_start + _visible_index;
		var _item_obj = _bag_index >= 0 && _bag_index < _bag_length ? _bag.items[_bag_index] : -1;
		var _slot_name = is_struct(_item_obj) ? _item_obj.name : "";
		var _slot_color = is_struct(_item_obj) ? scr_inventory_rarity_color(_item_obj, _theme) : _theme.muted;
		scr_inventory_text_set(scr_concat("slot_index_", _visible_index), string(_bag_index + 1), _theme.muted, 24, "left", "top");
		scr_inventory_text_set(scr_concat("slot_name_", _visible_index), is_struct(_item_obj) ? _slot_name : options.labels.empty_slot, _slot_color, 118, "left", "middle", false, _slot_name != "" ? "wave" : "");
		var _amount = _bag_index >= 0 && _bag_index < array_length(_bag.amount) ? _bag.amount[_bag_index] : 0;
		scr_inventory_text_set(scr_concat("slot_amount_", _visible_index), _amount > 1 ? scr_concat("x", _amount) : "", _theme.gold, 48, "right", "middle", false, "wave");
		var _shortcut_text = "";
		for (var _shortcut_index = 0; _shortcut_index < array_length(user_selections); _shortcut_index++){
			if (user_selections[_shortcut_index] == _bag_index) _shortcut_text = string(_shortcut_index);
		}
		scr_inventory_text_set(scr_concat("slot_shortcut_", _visible_index), _shortcut_text, _theme.good, 24, "right", "top");
	}
	var _detail_index = index_current >= 0 ? index_current : index_select;
	var _detail_item = _detail_index >= 0 && _detail_index < _bag_length ? _bag.items[_detail_index] : -1;
	if (is_struct(_detail_item)){
		scr_inventory_text_set("details_title", _detail_item.name, scr_inventory_rarity_color(_detail_item, _theme), options.layout.details_width - 20, "left", "middle", false, "wave");
		scr_inventory_text_set("details_body", scr_inventory_item_detail_markup(_detail_item), _theme.text, options.layout.details_width - 20, "left", "top", true, "reveal");
	} else {
		scr_inventory_text_set("details_title", options.labels.inspect, _theme.accent, options.layout.details_width - 20, "left", "middle", false, "wave");
		scr_inventory_text_set("details_body", options.labels.no_selection, _theme.muted, options.layout.details_width - 20, "left", "middle", false, "fade");
	}
	var _recipe_category = scr_inventory_category_index("recipes");
	scr_inventory_text_set("action", is_struct(_detail_item) ? scr_concat("[ENTER] ", state == _recipe_category ? options.labels.craft : options.labels.use) : "", _theme.gold, 220, "center", "middle", false, "wave");
	var _craft_text = "";
	if (state == _recipe_category && array_length(crafting_list) > 0){
		var _crafting_data = crafting_list[0];
		_craft_text = scr_concat("Brewing ", _crafting_data.itemObj.name, "  ", scr_timestring(_crafting_data.remaining()));
	}
	scr_inventory_text_set("craft_queue", _craft_text, _theme.good, 240, "left", "middle", false, "wave");
}

function scr_inventory_ui_sync_slots(){
	if (!is_struct(ui_world) || !is_array(ui_slot_entities) || array_length(ui_slot_entities) <= 0){
		return;
	}
	var _category_index = clamp(state, 0, max(0, category_count - 1));
	var _bag = list[_category_index];
	for (var _visible_index = 0; _visible_index < array_length(ui_slot_entities); _visible_index++){
		var _entity_id = ui_slot_entities[_visible_index];
		var _button = scr_ui_component_get(ui_world, _entity_id, "button");
		var _slot_index = index_start + _visible_index;
		var _item = -1;
		if (_slot_index >= 0 && _slot_index < array_length(_bag.items)){
			_item = _bag.items[_slot_index];
		}
		var _enabled = true;
		if (is_struct(_button)){
			_button.payload = {slot_index: _slot_index};
			_button.label = is_struct(_item) ? _item.name : "";
			_button.activatable = is_struct(_item);
		}
		scr_ui_button_set_enabled(ui_world, _entity_id, _enabled);
	}
	if (is_struct(ui_navigation)){
		scr_ui_navigation_refresh_group(ui_navigation);
	}

	var _action_enabled = index_current >= 0 && index_current < array_length(_bag.items) && is_struct(_bag.items[index_current]);
	if (array_length(ui_action_entities) > 0){
		var _primary_button = scr_ui_component_get(ui_world, ui_action_entities[0], "button");
		if (is_struct(_primary_button)){
			_primary_button.label = _category_index == scr_inventory_category_index("recipes") ? options.labels.craft : options.labels.use;
		}
		scr_ui_button_set_enabled(ui_world, ui_action_entities[0], _action_enabled);
	}
}

function scr_inventory_ui_sync_context(){
	if (!is_struct(ui_navigation)){
		return;
	}
	var _focus_button = scr_ui_component_get(ui_world, ui_navigation.focus_entity, "button");
	if (is_struct(_focus_button) && is_struct(_focus_button.payload)){
		if (ui_navigation.current == "categories" && variable_struct_exists(_focus_button.payload, "category_index")){
			var _focused_category = _focus_button.payload.category_index;
			if (_focused_category < category_count){
				state = _focused_category;
			}
		}
		if ((ui_navigation.current == "slots" || ui_navigation.current == "actions")
			&& variable_struct_exists(_focus_button.payload, "slot_index")){
			index_current = _focus_button.payload.slot_index;
			index_select = index_current;
		}
	}

	if (ui_navigation.current == "closed"){
		state = -1;
		button_index = -1;
		index_select = -1;
	} else {
		button_index = state;
	}
}

function scr_inventory_ui_open(){
	if (!is_struct(ui_navigation) || ui_open){
		return;
	}
	ui_open = true;
	state = clamp(state < 0 ? 0 : state, 0, max(0, category_count - 1));
	index_start = 0;
	index_current = -1;
	index_select = -1;
	if (ui_navigation.current == "closed"){
		scr_ui_navigation_set_state(ui_navigation, "categories", state);
	}
	var _visual = scr_ui_visual_ensure(ui_world, ui_root_entity);
	_visual.alpha = 0;
	_visual.offset_y = -18;
	scr_ui_tween_to(ui_world, ui_root_entity, "visual.alpha", 1, 0.18, "quad_out");
	scr_ui_tween_to(ui_world, ui_root_entity, "visual.offset_y", 0, 0.22, "cubic_out");
	scr_ui_juice_trigger(ui_world, ui_root_entity, "enter", {duration: 0.22});
	if (variable_struct_exists(options.callbacks, "on_open")){
		options.callbacks.on_open();
	}
}

function scr_inventory_ui_close(){
	if (!is_struct(ui_navigation) || (!ui_open && ui_navigation.current == "closed")){
		return;
	}
	ui_open = false;
	scr_ui_navigation_set_state(ui_navigation, "closed");
	state = -1;
	index_select = -1;
	button_index = -1;
	scr_ui_juice_trigger(ui_world, ui_root_entity, "press", {duration: 0.1});
	if (variable_struct_exists(options.callbacks, "on_close")){
		options.callbacks.on_close();
	}
}

function scr_inventory_ui_select_category(_category_index, _notify = true){
	if (_category_index < 0 || _category_index >= category_count){
		return;
	}
	state = _category_index;
	index_start = 0;
	index_current = -1;
	index_select = -1;
	scr_ui_navigation_set_state(ui_navigation, "slots", 0);
	scr_inventory_ui_sync_slots();
	scr_inventory_ui_sync_text();
	if (_notify && variable_struct_exists(options.callbacks, "on_category_changed")){
		options.callbacks.on_category_changed(state, list[state]);
	}
}

/// @desc Format recipe requirements as a readable, color-coded RPG feedback message.
function scr_inventory_recipe_feedback_markup(_report, _success){
	var _heading = _success ? "#2#g[OK] Recipe queued#0#w" : "#1#r[MISSING] Cannot craft#0#w";
	var _text = _heading + "\n#yQTY / TOTAL#w";
	if (is_struct(_report) && is_array(_report.entries)){
		for (var _index = 0; _index < array_length(_report.entries); _index++){
			var _entry = _report.entries[_index];
			var _prefix = _entry.enough ? "#g[OK] " : "#r[MISSING] ";
			_text += scr_concat("\n", _prefix, _entry.name, "  ", _entry.required, " / ", _entry.available, "#w");
		}
	}
	return _text;
}

/// @desc Show an RPG-style notification with configurable layering and input behavior.
/// @param owner_instance Optional bag instance id. Pass this when calling from a struct/method callback.
/// @param panel_options Supports auto_close, auto_close_seconds, wait_for_input, interactive, and modal.
function scr_inventory_textbox_notify(_text, _speaker = "SYSTEM", _duration_seconds = 0, _panel_effect = "enter", _panel_options = undefined, _owner_instance = undefined){
	var _target_instance = _owner_instance;
	if (is_undefined(_target_instance)){
		_target_instance = is_real(self) ? self : undefined;
	}
	if (is_undefined(_target_instance) || !instance_exists(_target_instance)){
		return false;
	}

	var _options = is_struct(_panel_options) ? _panel_options : {};
	var _auto_close_seconds = is_real(_duration_seconds) ? max(0, _duration_seconds) : 0;
	var _auto_close = _auto_close_seconds > 0;
	var _has_auto_close = variable_struct_exists(_options, "auto_close");
	if (variable_struct_exists(_options, "auto_close_seconds") && is_real(_options.auto_close_seconds)){
		_auto_close_seconds = max(0, _options.auto_close_seconds);
		if (!_has_auto_close) _auto_close = _auto_close_seconds > 0;
	}
	if (_has_auto_close && !is_undefined(_options.auto_close)) _auto_close = _options.auto_close ? true : false;
	if (variable_struct_exists(_options, "wait_for_input") && !is_undefined(_options.wait_for_input) && _options.wait_for_input){
		_auto_close = false;
	}
	var _interactive = !_auto_close;
	var _modal = _interactive;
	if (variable_struct_exists(_options, "interactive") && !is_undefined(_options.interactive)) _interactive = _options.interactive ? true : false;
	if (variable_struct_exists(_options, "modal") && !is_undefined(_options.modal)) _modal = _options.modal ? true : false;
	var _message = {
		text: string(_text),
		speaker: string(_speaker),
		auto_close: _auto_close,
		auto_close_seconds: _auto_close_seconds
	};
	var _result = false;
	with (_target_instance){
		if (!variable_instance_exists(id, "ui_textbox") || !is_struct(ui_textbox)){
			_result = false;
		} else {
			scr_ui_textbox_close(ui_textbox);
			ui_textbox.modal = _modal;
			ui_textbox.interactive = _interactive;
			scr_ui_textbox_enqueue(ui_textbox, _message);
			if (is_string(_panel_effect) && string_length(_panel_effect) > 0){
				scr_ui_juice_trigger(ui_textbox.world, ui_textbox.panel_entity, _panel_effect, _panel_options);
			}
			_result = true;
		}
	}
	return _result;
}

function scr_inventory_ui_handle_event(_event){
	if (!is_struct(_event)){
		return;
	}
	switch (_event.type){
		case "open":
			scr_inventory_ui_open();
			break;
		case "close":
			scr_inventory_ui_close();
			break;
		case "button":
			switch (_event.command){
				case "close":
					scr_inventory_ui_close();
					break;
				case "category_select":
					if (is_struct(_event.payload)) scr_inventory_ui_select_category(_event.payload.category_index);
					break;
				case "slot_select":
					if (is_struct(_event.payload)){
						index_current = _event.payload.slot_index;
						index_select = index_current;
						scr_inventory_ui_sync_slots();
					}
					break;
				case "activate_item":
					scr_inventory_activate_item();
					scr_ui_navigation_set_state(ui_navigation, "slots", 0);
					scr_inventory_ui_sync_slots();
					break;
				case "action_back":
					scr_ui_navigation_set_state(ui_navigation, "slots", 0);
					break;
			}
			break;
	}
}

function scr_inventory_ui_update(){
	if (!is_struct(ui_world) || !is_struct(ui_navigation)){
		return;
	}
	var _delta_seconds = delta_time / 1000000;
	ui_textbox_consumed_input = false;
	scr_ui_input_poll(ui_input);
	var _textbox_was_open = variable_instance_exists(id, "ui_textbox") && is_struct(ui_textbox) && scr_ui_textbox_is_open(ui_textbox);
	var _textbox_was_interactive = _textbox_was_open && ui_textbox.interactive;
	if (variable_instance_exists(id, "ui_textbox") && is_struct(ui_textbox)){
		scr_ui_textbox_update(ui_textbox, _delta_seconds);
	}
	if (_textbox_was_open && _textbox_was_interactive) ui_textbox_consumed_input = true;
	if (variable_instance_exists(id, "ui_textbox") && scr_ui_textbox_is_modal(ui_textbox)){
		scr_ui_world_step(ui_world, _delta_seconds);
		return;
	}
	scr_inventory_ui_sync_slots();
	scr_inventory_ui_sync_context();

	if (ui_navigation.current == "slots" && ui_input.wheel != 0){
		var _bag = list[state];
		var _last_start = max(0, array_length(_bag.items) - page_size);
		index_start = clamp(index_start - ui_input.wheel, 0, _last_start);
		index_current = -1;
		scr_inventory_ui_sync_slots();
	}

	scr_ui_navigation_update(ui_navigation);
	var _navigation_event = ui_navigation.last_event;
	scr_inventory_ui_handle_event(_navigation_event);
	var _handled_entity = is_struct(_navigation_event) && variable_struct_exists(_navigation_event, "entity") ? _navigation_event.entity : -1;
	var _ui_events = scr_ui_events_drain(ui_world);
	for (var _event_index = 0; _event_index < array_length(_ui_events); _event_index++){
		var _ui_event = _ui_events[_event_index];
		if (is_struct(_ui_event) && _ui_event.type == "button_activate" && _ui_event.entity != _handled_entity){
			var _button_payload = _ui_event.payload;
			if (is_struct(_button_payload)){
				scr_inventory_ui_handle_event({
					type: "button",
					entity: _ui_event.entity,
					command: variable_struct_exists(_button_payload, "command") ? _button_payload.command : "",
					payload: variable_struct_exists(_button_payload, "payload") ? _button_payload.payload : undefined
				});
			}
		}
	}
	scr_inventory_ui_sync_context();
	scr_inventory_ui_sync_text();

	if (state == scr_inventory_category_index("items") && index_current >= 0){
		for (var _shortcut_index = 0; _shortcut_index < 10; _shortcut_index++){
			if (scr_ui_input_key_pressed(ord(string(_shortcut_index)))){
				user_selections[_shortcut_index] = index_current;
			}
		}
	}
	if (state == scr_inventory_category_index("recipes") && index_current >= 0
		&& scr_ui_input_key_pressed(ord("C"))){
		scr_inventory_activate_item();
	}

	scr_ui_world_step(ui_world, _delta_seconds);
}

/// @desc Public convenience API for an inventory controller instance.
function scr_inventory_open(){
	scr_inventory_ui_open();
}

function scr_inventory_close(){
	scr_inventory_ui_close();
}

function scr_inventory_set_category(_kind){
	var _category_index = scr_inventory_category_index(_kind);
	if (_category_index >= 0){
		scr_inventory_ui_select_category(_category_index);
	}
	return _category_index;
}

// ===== Full Project Inventory: scripts/scr_draw_bag/scr_draw_bag.gml =====
/// @desc Draw the inventory using positions calculated by the native Flex Panel tree.
function scr_draw_bag(){
	if (!is_struct(options)){
		return;
	}

	var _theme = options.theme;
	var _sprites = options.sprites;
	draw_set_font(options.font);
	draw_set_alpha(1);

	if (state == -1){
		var _hint_rect = {left: 16, top: 16, width: 238, height: 42};
		scr_inventory_draw_box(_hint_rect, _theme.panel_deep, _sprites.frame, _theme.frame_normal);
		draw_set_halign(fa_left);
		draw_set_valign(fa_middle);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "closed_hint", _hint_rect.left + 12, _hint_rect.top + _hint_rect.height * 0.5);
		scr_draw_reset();
		if (variable_instance_exists(id, "ui_textbox") && is_struct(ui_textbox)){
			scr_ui_textbox_draw(ui_textbox);
			scr_draw_reset();
		}
		return;
	}

	var _width = display_get_gui_width();
	var _height = display_get_gui_height();
	draw_set_color(_theme.canvas);
	draw_set_alpha(0.78);
	draw_rectangle(0, 0, _width, _height, false);
	draw_set_alpha(1);

	var _root = flexpanel_node_layout_get_position(layout.root, false);
	scr_inventory_draw_box(_root, _theme.panel_deep, _sprites.frame, _theme.frame_normal, ui_root_entity);

	var _header = flexpanel_node_layout_get_position(layout.header, false);
	scr_inventory_draw_box(_header, _theme.panel, _sprites.frame, _theme.frame_normal);
		draw_set_halign(fa_left);
		draw_set_valign(fa_middle);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "header_title", _header.left + 12, _header.top + 9);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "header_subtitle", _header.left + 12, _header.top + 27);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "header_party", _header.left + _header.width - 12, _header.top + 10);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "header_currency", _header.left + _header.width - 12, _header.top + 28);

	var _nav = flexpanel_node_layout_get_position(layout.nav, false);
	scr_inventory_draw_box(_nav, _theme.panel, _sprites.frame, _theme.frame_normal);
		for (var _nav_index = 0; _nav_index <= category_count; _nav_index++){
		var _nav_pos = flexpanel_node_layout_get_position(layout.nav_nodes[_nav_index], false);
		var _nav_entity = ui_category_entities[_nav_index];
		var _nav_frame = scr_ui_button_visual_state(ui_world, _nav_entity);
		if (state == _nav_index) _nav_frame = _theme.frame_selected;
		scr_inventory_draw_box(_nav_pos, state == _nav_index ? _theme.panel_alt : _theme.panel_deep, _sprites.frame, _nav_frame, _nav_entity);
			scr_ui_text_juice_draw(ui_world, ui_root_entity, scr_concat("category_", _nav_index), _nav_pos.left + 10, _nav_pos.top + _nav_pos.height * 0.5);
	}

	var _slot_surface = flexpanel_node_layout_get_position(layout.slot_surface, false);
	scr_inventory_draw_box(_slot_surface, _theme.panel, _sprites.frame, _theme.frame_normal);
	var _slot_header = flexpanel_node_layout_get_position(layout.slot_header, false);
		var _bag_length = array_length(list[state].items);
		var _slot_end = min(_bag_length, index_start + page_size);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "slot_header", _slot_header.left + 10, _slot_header.top + _slot_header.height * 0.5);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "slot_count", _slot_header.left + _slot_header.width - 10, _slot_header.top + _slot_header.height * 0.5);

	var _bag = list[state];
	var _recipe_category = scr_inventory_category_index("recipes");
	for (var _visible_index = 0; _visible_index < page_size; _visible_index++){
		var _slot_pos = flexpanel_node_layout_get_position(layout.slot_nodes[_visible_index], false);
		var _bag_index = index_start + _visible_index;
		var _is_hover = index_select == _bag_index;
		var _is_current = index_current == _bag_index;
		var _slot_frame = _is_current ? _theme.frame_selected : (_is_hover ? _theme.frame_hover : _theme.frame_normal);
		scr_inventory_draw_box(_slot_pos, _is_current ? _theme.panel_alt : _theme.panel_deep, _sprites.frame, _slot_frame, ui_slot_entities[_visible_index]);

		scr_ui_text_juice_draw(ui_world, ui_root_entity, scr_concat("slot_index_", _visible_index), _slot_pos.left + 7, _slot_pos.top + 5);

		var _item_obj = -1;
		if (_bag_index >= 0 && _bag_index < _bag_length){
			_item_obj = _bag.items[_bag_index];
		}
		if (is_struct(_item_obj)){
			if (variable_struct_exists(_item_obj, "draw_icon")){
				_item_obj.draw_icon(_slot_pos.left + 24, _slot_pos.top + 7, min(38, _slot_pos.height - 12));
			} else {
				draw_sprite_stretched(_item_obj.sprite, _item_obj.index, _slot_pos.left + 24, _slot_pos.top + 7, 38, 38);
			}
		}
		scr_ui_text_juice_draw(ui_world, ui_root_entity, scr_concat("slot_name_", _visible_index), _slot_pos.left + 70, _slot_pos.top + _slot_pos.height * 0.5, max(32, _slot_pos.width - 112));
		scr_ui_text_juice_draw(ui_world, ui_root_entity, scr_concat("slot_amount_", _visible_index), _slot_pos.left + _slot_pos.width - 8, _slot_pos.top + _slot_pos.height * 0.5);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, scr_concat("slot_shortcut_", _visible_index), _slot_pos.left + _slot_pos.width - 8, _slot_pos.top + 4);

	}

	var _details = flexpanel_node_layout_get_position(layout.details, false);
	scr_inventory_draw_box(_details, _theme.panel, _sprites.frame, _theme.frame_normal);
	var _detail_title = flexpanel_node_layout_get_position(layout.detail_title, false);
	var _detail_preview = flexpanel_node_layout_get_position(layout.detail_preview, false);
	var _detail_text = flexpanel_node_layout_get_position(layout.detail_text, false);
	var _detail_action = flexpanel_node_layout_get_position(layout.detail_action, false);
	var _detail_index = index_current;
	if (_detail_index < 0){
		_detail_index = index_select;
	}
	var _detail_item = -1;
	if (_detail_index >= 0 && _detail_index < array_length(_bag.items)){
		_detail_item = _bag.items[_detail_index];
	}

	if (is_struct(_detail_item)){
		scr_inventory_draw_item_details(_detail_item, _detail_preview, _detail_text, _theme);
	} else {
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
	}
	scr_ui_text_juice_draw(ui_world, ui_root_entity, "details_title", _detail_title.left, _detail_title.top + _detail_title.height * 0.5);
	scr_ui_text_juice_draw(ui_world, ui_root_entity, "details_body", _detail_text.left, _detail_text.top + 4, _detail_text.width);

	if (is_struct(_detail_item)){
		scr_inventory_draw_box(_detail_action, _theme.panel_alt, _sprites.frame, _theme.frame_hover, ui_action_entities[0]);
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "action", _detail_action.left + _detail_action.width * 0.5, _detail_action.top + _detail_action.height * 0.5);
	}

	var _footer = flexpanel_node_layout_get_position(layout.footer, false);
	scr_inventory_draw_box(_footer, _theme.panel, _sprites.frame, _theme.frame_normal);
	scr_ui_text_juice_draw(ui_world, ui_root_entity, "footer", _footer.left + 10, _footer.top + _footer.height * 0.5);
	scr_ui_text_juice_draw(ui_world, ui_root_entity, "footer_tag", _footer.left + _footer.width - 10, _footer.top + _footer.height * 0.5);

	if (state == _recipe_category && array_length(crafting_list) > 0){
		var _crafting_data = crafting_list[0];
		var _ratio = _crafting_data.ratio();
		var _queue_x = _slot_surface.left + 10;
		var _queue_y = _slot_surface.top + _slot_surface.height - 22;
		scr_ui_text_juice_draw(ui_world, ui_root_entity, "craft_queue", _queue_x, _queue_y);
		draw_set_color(_theme.panel_deep);
		draw_rectangle(_queue_x + 155, _queue_y - 5, _queue_x + 225, _queue_y + 5, false);
		draw_set_color(_theme.good);
		draw_rectangle(_queue_x + 155, _queue_y - 5, _queue_x + 155 + 70 * clamp(_ratio, 0, 1), _queue_y + 5, false);
	}

	scr_draw_reset();
	if (variable_instance_exists(id, "ui_textbox") && is_struct(ui_textbox)){
		scr_ui_textbox_draw(ui_textbox);
		scr_draw_reset();
	}
}

/// @desc Draw a framed rectangle, optionally applying an entity's visual component.
function scr_inventory_draw_box(_rect, _fill, _frame_sprite, _frame_index, _entity_id = -1){
	var _draw_rect = _rect;
	var _draw_alpha = 1;
	if (_entity_id >= 0 && is_struct(ui_world)){
		_draw_rect = scr_ui_visual_rect(ui_world, _entity_id, _rect);
		_draw_alpha = _draw_rect.alpha;
	}
	draw_set_alpha(_draw_alpha);
	draw_set_color(_fill);
	draw_rectangle(_draw_rect.left, _draw_rect.top, _draw_rect.left + _draw_rect.width, _draw_rect.top + _draw_rect.height, false);
	draw_set_color(c_white);
	if (_frame_sprite >= 0){
		draw_sprite_stretched(_frame_sprite, _frame_index, _draw_rect.left, _draw_rect.top, _draw_rect.width, _draw_rect.height);
	}
	draw_set_alpha(1);
}

/// @desc Choose a readable item color from a per-item rarity field.
function scr_inventory_rarity_color(_item_obj, _theme){
	if (variable_struct_exists(_item_obj, "rarity")){
		switch (_item_obj.rarity){
			case "uncommon": return _theme.good;
			case "rare": return _theme.accent;
			case "epic": return make_color_rgb(220, 156, 255);
		}
	}
	return _theme.text;
}

/// @desc Draw the selected item's preview and its structured metadata.
function scr_inventory_draw_item_details(_item_obj, _preview_rect, _text_rect, _theme){
	var _icon_size = min(90, _preview_rect.height - 16);
	var _icon_x = _preview_rect.left + (_preview_rect.width - _icon_size) * 0.5;
	var _icon_y = _preview_rect.top + (_preview_rect.height - _icon_size) * 0.5;
	draw_set_color(_theme.panel_deep);
	draw_rectangle(_icon_x - 4, _icon_y - 4, _icon_x + _icon_size + 4, _icon_y + _icon_size + 4, false);
	draw_set_color(c_white);
	if (variable_struct_exists(_item_obj, "draw_icon")){
		_item_obj.draw_icon(_icon_x, _icon_y, _icon_size);
	} else {
		draw_sprite_stretched(_item_obj.sprite, _item_obj.index, _icon_x, _icon_y, _icon_size, _icon_size);
	}
}

// ===== Full Project Inventory: scripts/scr_update_bag/scr_update_bag.gml =====
/// @desc Update the inventory controller and its reusable UI systems.
function scr_update_bag(){
	if (!is_struct(options) || !is_struct(layout)){
		return;
	}

	var _gui_width = display_get_gui_width();
	var _gui_height = display_get_gui_height();
	if (_gui_width != layout_width || _gui_height != layout_height){
		var _restore_state = is_struct(ui_navigation) ? ui_navigation.current : "closed";
		var _restore_category = state;
		var _restore_slot = index_current;
		scr_inventory_build_layout(options);
		scr_inventory_ui_rebuild(_restore_state, _restore_category, _restore_slot);
		scr_inventory_layout_refresh();
	}

	var _craft_count = array_length(crafting_list);
	if (_craft_count > 0){
		var _craft_data = crafting_list[0];
		if (_craft_data.update() == 1){
			var _item_category = scr_inventory_category_index("items");
			if (_item_category >= 0){
				scr_bag_add_item(list[_item_category], _craft_data.itemObj, 1);
			}
			array_delete(crafting_list, 0, 1);
			scr_inventory_textbox_notify(scr_concat("#2#gCrafted ", _craft_data.itemObj.name, "#0"), "CRAFTING", 1.8, "enter", {duration: 0.24}, id);
			show_debug_message("recipe complete");
		}
	}

	scr_inventory_ui_update();
}

/// @desc Use an item or enqueue a recipe from the selected action.
function scr_inventory_activate_item(){
	if (state < 0 || state >= category_count){
		return;
	}
	var _bag = list[state];
	if (index_current < 0 || index_current >= array_length(_bag.items) || !is_struct(_bag.items[index_current])){
		return;
	}
		var _item_obj = _bag.items[index_current];
		if (state == scr_inventory_category_index("recipes")){
			var _item_category = scr_inventory_category_index("items");
			var _item_bag = _item_category >= 0 ? list[_item_category] : undefined;
			var _recipe_report = scr_recipe_attempt(_item_obj, _item_bag);
			if (_recipe_report.success){
				if (is_struct(_item_obj.data) && variable_struct_exists(_item_obj.data, "grab")){
					array_push(crafting_list, _item_obj.data.grab());
				}
				scr_inventory_textbox_notify(scr_inventory_recipe_feedback_markup(_recipe_report, true), "CRAFTING", 2.2, "enter", {duration: 0.24}, id);
			} else {
			scr_inventory_textbox_notify(scr_inventory_recipe_feedback_markup(_recipe_report, false), "CRAFTING", 2.2, "shake", {duration: 0.3, amplitude: 6}, id);
		}
	} else {
		var _used = false;

		if (variable_struct_exists(_item_obj, "use_item") && is_callable(_item_obj.use_item)){

			_used = _item_obj.use_item(_item_obj);

		}

		scr_inventory_textbox_notify(_used ? scr_concat("#2#gUsed ", _item_obj.name, "#0") : scr_concat("#1#rCannot use ", _item_obj.name, "#0"), "ITEMS", 1.2, "enter", {duration: 0.18}, id);
	}
	if (variable_struct_exists(options.callbacks, "on_item_activated")){
		options.callbacks.on_item_activated(_item_obj, state);
	}
}

// ===== Sprouts and Steel integration helpers =====
function scr_sas_ui_target_action(_action){
	switch (_action){
		case "toggle": return "pause";
		case "confirm": return "action";
		case "back": return "back";
		case "up": return "up";
		case "down": return "down";
		case "left": return "left";
		case "right": return "right";
	}
	return "";
}
function scr_sas_inventory_bridge(_source, _name){
	return {
		name: _name,
		items: _source.items,
		amount: _source.quantity,
		source: _source,
		identifier: "name",
		resizable: false
	};
}
function scr_sas_inventory_refresh(_bridge){
	if (is_struct(_bridge) && variable_struct_exists(_bridge, "source") && is_struct(_bridge.source)){
		_bridge.items = _bridge.source.items;
		_bridge.amount = _bridge.source.quantity;
	}
	return _bridge;
}
function scr_concat(){
	var _result = "";
	for (var _index = 0; _index < argument_count; _index++){
		_result += string(argument[_index]);
	}
	return _result;
}
function scr_timestring(_seconds){
	var _value = max(0, _seconds);
	if (_value < 60) return scr_concat(round(_value), "s");
	var _minutes = floor(_value / 60);
	var _remaining = round(_value - _minutes * 60);
	return scr_concat(_minutes, "m ", string_format(_remaining, 2, 0), "s");
}
function scr_draw_reset(){
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_font(-1);
}




// ===== Full Project Inventory: scripts/scr_ui_menu/scr_ui_menu.gml =====
/// @desc High-level, themeable menu screens built from Flex, ECS, and navigation.

function scr_ui_menu_merge(_base, _override){
	if (!is_struct(_override)) return _base;
	var _keys = variable_struct_get_names(_override);
	for (var _index = 0; _index < array_length(_keys); _index++){
		var _key = _keys[_index];
		var _value = variable_struct_get(_override, _key);
		var _base_value = variable_struct_exists(_base, _key) ? variable_struct_get(_base, _key) : undefined;
		if (variable_struct_exists(_base, _key) && is_struct(_base_value) && is_struct(_value)
			&& !is_callable(_base_value) && !is_callable(_value)){
			variable_struct_set(_base, _key, scr_ui_menu_merge(_base_value, _value));
		} else {
			variable_struct_set(_base, _key, _value);
		}
	}
	return _base;
}

function scr_ui_menu_default_options(){
	return {
		title: "MENU",
		subtitle: "",
		footer: "ARROWS MOVE    ENTER SELECT    ESC BACK",
		description: "",
		items: [],
		max_items: 8,
		variant: "list",
		font: -1,
		input: undefined,
		input_owned: true,
		modal: true,
		layout: {
			width: "82%",
			height: "76%",
			padding: 18,
			gap: 8,
			title_height: 32,
			subtitle_height: 24,
			item_height: 42,
			card_height: 96,
			description_height: 68,
			footer_height: 26,
			item_width: "100%"
		},
		theme: {
			canvas: make_color_rgb(7, 9, 24),
			overlay_alpha: 0.82,
			panel: make_color_rgb(18, 22, 52),
			panel_alt: make_color_rgb(31, 36, 78),
			panel_deep: make_color_rgb(10, 13, 34),
			text: make_color_rgb(235, 238, 255),
			muted: make_color_rgb(153, 164, 202),
			gold: make_color_rgb(255, 218, 120),
			accent: make_color_rgb(116, 224, 255),
			good: make_color_rgb(137, 242, 158),
			error: make_color_rgb(255, 104, 112),
			shadow: make_color_rgb(4, 5, 12),
			frame_normal: 0,
			frame_hover: 1,
			frame_selected: 2,
			frame_disabled: 0
		},
		sprites: {frame: -1},
		callbacks: {
			on_open: function(_menu = undefined){},
			on_close: function(_menu = undefined){},
			on_select: function(_menu = undefined, _item = undefined, _index = -1){},
			on_activate: function(_menu = undefined, _item = undefined, _index = -1){},
			on_cancel: function(_menu = undefined){}
		}
	};
}

function scr_ui_menu_item(_label, _command = "select", _payload = undefined, _options = undefined){
	var _item = {
		label: string(_label),
		detail: "",
		command: _command,
		payload: _payload,
		enabled: true,
		activatable: true,
		icon: -1,
		icon_index: 0,
		accent: undefined,
		label_color: undefined,
		detail_color: undefined,
		index_color: undefined
	};
	if (is_struct(_options)) _item = scr_ui_menu_merge(_item, _options);
	return _item;
}

function scr_ui_menu_normalize_item(_item, _index){
	if (is_string(_item)) return scr_ui_menu_item(_item, "select", {index: _index});
	if (!is_struct(_item)) return scr_ui_menu_item("", "select", {index: _index}, {enabled: false, activatable: false});
	var _result = scr_ui_menu_item(
		variable_struct_exists(_item, "label") ? _item.label : "",
		variable_struct_exists(_item, "command") ? _item.command : "select",
		variable_struct_exists(_item, "payload") ? _item.payload : {index: _index}
	);
	_result = scr_ui_menu_merge(_result, _item);
	if (!variable_struct_exists(_result, "index")) _result.index = _index;
	return _result;
}

function scr_ui_menu_build_layout(_menu){
	var _item_nodes = [];
	for (var _index = 0; _index < _menu.options.max_items; _index++){
		array_push(_item_nodes, {
			name: scr_concat("menu_item_", _index),
			width: _menu.options.layout.item_width,
			height: _menu.options.variant == "game_select" ? _menu.options.layout.card_height : _menu.options.layout.item_height,
			flexShrink: 0,
			data: {kind: "menu_item", index: _index}
		});
	}
	var _panel_spec = {
		name: "menu_panel",
		width: _menu.options.layout.width,
		height: _menu.options.layout.height,
		flexDirection: "column",
		padding: _menu.options.layout.padding,
		gapRow: _menu.options.layout.gap,
		data: {kind: "menu_panel"},
		nodes: [
			{name: "menu_title", height: _menu.options.layout.title_height, flexShrink: 0, data: {kind: "menu_title"}},
			{name: "menu_subtitle", height: _menu.options.layout.subtitle_height, flexShrink: 0, data: {kind: "menu_subtitle"}},
			{
				name: "menu_items",
				flex: 1,
				minHeight: 0,
				flexDirection: "column",
				gapRow: _menu.options.layout.gap,
				data: {kind: "menu_items"},
				nodes: _item_nodes
			},
			{name: "menu_description", height: _menu.options.layout.description_height, flexShrink: 0, data: {kind: "menu_description"}},
			{name: "menu_footer", height: _menu.options.layout.footer_height, flexShrink: 0, data: {kind: "menu_footer"}}
		]
	};
	var _root = flexpanel_create_node({
		name: "menu_root",
		width: "100%",
		height: "100%",
		flexDirection: "column",
		alignItems: "center",
		justifyContent: "center",
		data: {kind: "menu_root"},
		nodes: [_panel_spec]
	});
	var _panel = flexpanel_node_get_child(_root, 0);
	var _items = flexpanel_node_get_child(_panel, 2);
	var _item_handles = [];
	for (var _item_index = 0; _item_index < _menu.options.max_items; _item_index++){
		array_push(_item_handles, flexpanel_node_get_child(_items, _item_index));
	}
	return {
		root: _root,
		panel: _panel,
		title: flexpanel_node_get_child(_panel, 0),
		subtitle: flexpanel_node_get_child(_panel, 1),
		items: _item_handles,
		description: flexpanel_node_get_child(_panel, 3),
		footer: flexpanel_node_get_child(_panel, 4)
	};
}

function scr_ui_menu_create(_options = undefined){
	var _settings = scr_ui_menu_merge(scr_ui_menu_default_options(), _options);
	var _has_world = variable_struct_exists(_settings, "world") && is_struct(_settings.world);
	var _has_input = variable_struct_exists(_settings, "input") && is_struct(_settings.input);
	var _input_bindings = variable_struct_exists(_settings, "input_bindings") ? _settings.input_bindings : undefined;
	var _world = _has_world ? _settings.world : scr_ui_world_create({kind: "menu"});
	var _input = _has_input ? _settings.input : scr_ui_input_create(_input_bindings);
	var _menu = {
		kind: "menu",
		options: _settings,
		world: _world,
		input: _input,
		input_owned: _settings.input_owned,
		layout: undefined,
		navigation: undefined,
		root_entity: -1,
		panel_entity: -1,
		item_entities: [],
		items: [],
		open: false,
		layout_width: -1,
		layout_height: -1,
		selected_index: -1,
		last_selected_index: -2,
		description: _settings.description,
		status: "",
		owns_world: !_has_world
	};
	_menu.items = [];
	for (var _item_index = 0; _item_index < array_length(_settings.items); _item_index++){
		array_push(_menu.items, scr_ui_menu_normalize_item(_settings.items[_item_index], _item_index));
	}
	_menu.layout = scr_ui_menu_build_layout(_menu);
	_menu.root_entity = scr_ui_entity_create(_world);
	_menu.panel_entity = scr_ui_entity_create(_world, _menu.root_entity);
	scr_ui_flex_bind(_world, _menu.root_entity, _menu.layout.root, "menu_root");
	scr_ui_flex_bind(_world, _menu.panel_entity, _menu.layout.panel, "menu_panel");
	scr_ui_text_juice_attach(_world, _menu.panel_entity, "title");
	scr_ui_text_juice_attach(_world, _menu.panel_entity, "subtitle");
	scr_ui_text_juice_attach(_world, _menu.panel_entity, "description");
	scr_ui_text_juice_attach(_world, _menu.panel_entity, "footer");
	for (var _entity_index = 0; _entity_index < _settings.max_items; _entity_index++){
		var _entity_id = scr_ui_button_create(_world, {
			label: "",
			command: "select",
			payload: {index: _entity_index},
			group: "menu_items",
			enabled: false,
			route: {}
		}, _menu.panel_entity);
		array_push(_menu.item_entities, _entity_id);
		scr_ui_flex_bind(_world, _entity_id, _menu.layout.items[_entity_index], "menu_item");
		scr_ui_text_juice_attach(_world, _entity_id, "label");
		scr_ui_text_juice_attach(_world, _entity_id, "detail");
		scr_ui_text_juice_attach(_world, _entity_id, "index");
	}
	_menu.navigation = scr_ui_navigation_create(_world, _input);
	_menu.navigation.open_state = "menu";
	scr_ui_navigation_register_state(_menu.navigation, "closed", {group: ""});
	scr_ui_navigation_register_state(_menu.navigation, "menu", {group: "menu_items", back_state: "closed"});
	scr_ui_navigation_set_state(_menu.navigation, "closed");
	scr_ui_menu_set_items(_menu, _menu.items);
	scr_ui_menu_sync(_menu);
	scr_ui_menu_layout_refresh(_menu);
	return _menu;
}

function scr_ui_menu_layout_refresh(_menu){
	if (!is_struct(_menu) || !is_struct(_menu.layout) || !variable_struct_exists(_menu.layout, "root")){
		return;
	}
	var _width = display_get_gui_width();
	var _height = display_get_gui_height();
	var _layout_dirty = is_struct(_menu.world) && variable_struct_exists(_menu.world, "dirty_layout") && _menu.world.dirty_layout;
	if (_menu.layout_width != _width || _menu.layout_height != _height || _layout_dirty){
		scr_ui_flex_recalculate(_menu.world, _menu.layout.root, _width, _height);
		_menu.layout_width = _width;
		_menu.layout_height = _height;
	}
}

function scr_ui_menu_set_items(_menu, _items){
	if (!is_struct(_menu) || !is_array(_items)) return false;
	_menu.items = [];
	var _limit = min(array_length(_items), _menu.options.max_items);
	for (var _index = 0; _index < _limit; _index++){
		array_push(_menu.items, scr_ui_menu_normalize_item(_items[_index], _index));
	}
	_menu.selected_index = array_length(_menu.items) > 0 ? 0 : -1;
	for (var _entity_index = 0; _entity_index < array_length(_menu.item_entities); _entity_index++){
		var _entity_id = _menu.item_entities[_entity_index];
		var _item = _entity_index < array_length(_menu.items) ? _menu.items[_entity_index] : undefined;
		var _button = scr_ui_component_get(_menu.world, _entity_id, "button");
		if (is_struct(_button)){
			_button.label = is_struct(_item) ? _item.label : "";
			_button.command = is_struct(_item) ? _item.command : "select";
			_button.payload = is_struct(_item) ? {index: _entity_index, data: _item.payload} : {index: _entity_index, data: undefined};
			_button.activatable = is_struct(_item) ? _item.activatable : false;
		}
		scr_ui_button_set_enabled(_menu.world, _entity_id, is_struct(_item) && _item.enabled);
		var _focusable = scr_ui_component_get(_menu.world, _entity_id, "focusable");
		if (is_struct(_focusable)){
			_focusable.route.up = _entity_index > 0 ? _menu.item_entities[_entity_index - 1] : -1;
			_focusable.route.down = _entity_index + 1 < _limit ? _menu.item_entities[_entity_index + 1] : -1;
			_focusable.route.left = -1;
			_focusable.route.right = -1;
		}
	}
	if (is_struct(_menu.navigation)){
		scr_ui_navigation_refresh_group(_menu.navigation);
		if (_menu.open) scr_ui_navigation_set_state(_menu.navigation, "menu", 0);
	}
	scr_ui_world_mark_layout_dirty(_menu.world);
	scr_ui_menu_sync(_menu);
	return true;
}

function scr_ui_menu_sync(_menu){
	if (!is_struct(_menu) || !is_struct(_menu.options)) return;
	var _theme = _menu.options.theme;
	var _palette = {
		error: _theme.error,
		good: _theme.good,
		accent: _theme.accent,
		warning: _theme.gold,
		muted: _theme.muted,
		text: _theme.text
	};
	var _text_options = {
		font: _menu.options.font,
		palette: _palette,
		outline_color: _theme.shadow,
		outline_width: 1
	};
	scr_ui_text_juice_set(_menu.world, _menu.panel_entity, "title", _menu.options.title, scr_ui_menu_merge(_text_options, {text_color: _theme.gold, align: "left", valign: "middle", change_effect: "wave"}));
	scr_ui_text_juice_set(_menu.world, _menu.panel_entity, "subtitle", _menu.options.subtitle, scr_ui_menu_merge(_text_options, {text_color: _theme.muted, align: "left", valign: "middle"}));
	scr_ui_text_juice_set(_menu.world, _menu.panel_entity, "description", _menu.description, scr_ui_menu_merge(_text_options, {text_color: _theme.text, align: "left", valign: "top", reveal: false}));
	var _footer_text = string_length(_menu.status) > 0 ? scr_concat(_menu.options.footer, "    ", _menu.status) : _menu.options.footer;
	scr_ui_text_juice_set(_menu.world, _menu.panel_entity, "footer", _footer_text, scr_ui_menu_merge(_text_options, {text_color: _theme.accent, align: "left", valign: "middle"}));
	for (var _index = 0; _index < array_length(_menu.item_entities); _index++){
		var _entity_id = _menu.item_entities[_index];
		var _item = _index < array_length(_menu.items) ? _menu.items[_index] : undefined;
		var _button = scr_ui_component_get(_menu.world, _entity_id, "button");
		var _enabled = is_struct(_item) && _item.enabled;
		var _color = !_enabled ? _theme.muted : (_index == _menu.selected_index ? _theme.gold : _theme.text);
		var _detail_color = !_enabled ? _theme.muted : _theme.accent;
		var _index_color = _theme.muted;
		if (is_struct(_item) && is_real(_item.label_color)) _color = _item.label_color;
		if (is_struct(_item) && is_real(_item.detail_color)) _detail_color = _item.detail_color;
		if (is_struct(_item) && is_real(_item.index_color)) _index_color = _item.index_color;
		scr_ui_text_juice_set(_menu.world, _entity_id, "label", is_struct(_item) ? _item.label : "", scr_ui_menu_merge(_text_options, {text_color: _color, max_width: 360, align: "left", valign: "middle", change_effect: _index == _menu.selected_index ? "wave" : ""}));
		scr_ui_text_juice_set(_menu.world, _entity_id, "detail", is_struct(_item) ? _item.detail : "", scr_ui_menu_merge(_text_options, {text_color: _detail_color, max_width: 360, align: "right", valign: "middle"}));
		scr_ui_text_juice_set(_menu.world, _entity_id, "index", is_struct(_item) ? scr_concat(string(_index + 1), ".") : "", scr_ui_menu_merge(_text_options, {text_color: _index_color, max_width: 32, align: "left", valign: "middle"}));
		if (is_struct(_button)) _button.label = is_struct(_item) ? _item.label : "";
	}
}

function scr_ui_menu_open(_menu){
	if (!is_struct(_menu) || _menu.open) return false;
	_menu.open = true;
	scr_ui_navigation_set_state(_menu.navigation, "menu", 0);
	var _visual = scr_ui_visual_ensure(_menu.world, _menu.panel_entity);
	_visual.alpha = 0;
	_visual.offset_y = -18;
	scr_ui_tween_to(_menu.world, _menu.panel_entity, "visual.alpha", 1, 0.18, "quad_out");
	scr_ui_tween_to(_menu.world, _menu.panel_entity, "visual.offset_y", 0, 0.22, "cubic_out");
	scr_ui_juice_trigger(_menu.world, _menu.panel_entity, "enter", {duration: 0.22});
	if (is_callable(_menu.options.callbacks.on_open)) _menu.options.callbacks.on_open(_menu);
	return true;
}

function scr_ui_menu_close(_menu){
	if (!is_struct(_menu) || !_menu.open) return false;
	_menu.open = false;
	scr_ui_navigation_set_state(_menu.navigation, "closed");
	if (is_callable(_menu.options.callbacks.on_close)) _menu.options.callbacks.on_close(_menu);
	return true;
}

function scr_ui_menu_current_item(_menu){
	if (!is_struct(_menu) || _menu.selected_index < 0 || _menu.selected_index >= array_length(_menu.items)) return undefined;
	return _menu.items[_menu.selected_index];
}

function scr_ui_menu_handle_button_event(_menu, _event){
	if (!is_struct(_menu) || !is_struct(_event)
		|| (_event.type != "button" && _event.type != "button_activate")){
		return false;
	}
	var _command = variable_struct_exists(_event, "command") ? _event.command : "";
	var _payload = variable_struct_exists(_event, "payload") ? _event.payload : undefined;
	if (_event.type == "button_activate" && is_struct(_payload)){
		_command = variable_struct_exists(_payload, "command") ? _payload.command : "";
		_payload = variable_struct_exists(_payload, "payload") ? _payload.payload : undefined;
	}

	var _item_index = is_struct(_payload) && variable_struct_exists(_payload, "index") ? _payload.index : -1;
	var _item = _item_index >= 0 && _item_index < array_length(_menu.items) ? _menu.items[_item_index] : undefined;
	if (_command == "close"){
		scr_ui_menu_close(_menu);
		return true;
	}
	if (is_struct(_item) && is_callable(_menu.options.callbacks.on_activate)){
		_menu.selected_index = _item_index;
		_menu.options.callbacks.on_activate(_menu, _item, _item_index);
		return true;
	}
	return false;
}

function scr_ui_menu_process_selection(_menu){
	var _focus_entity = _menu.navigation.focus_entity;
	var _button = scr_ui_component_get(_menu.world, _focus_entity, "button");
	var _payload = is_struct(_button) ? _button.payload : undefined;
	var _index = is_struct(_payload) && variable_struct_exists(_payload, "index") ? _payload.index : -1;
	if (_index >= 0 && _index < array_length(_menu.items) && _index != _menu.selected_index){
		_menu.selected_index = _index;
		var _item = _menu.items[_index];
		_menu.description = variable_struct_exists(_item, "description") ? _item.description : _menu.options.description;
		if (is_callable(_menu.options.callbacks.on_select)) _menu.options.callbacks.on_select(_menu, _item, _index);
		scr_ui_menu_sync(_menu);
	}
	if (_menu.last_selected_index != _menu.selected_index){
		_menu.last_selected_index = _menu.selected_index;
		var _current_item = scr_ui_menu_current_item(_menu);
		if (is_struct(_current_item)){
			_menu.description = variable_struct_exists(_current_item, "description") ? _current_item.description : _menu.options.description;
			scr_ui_menu_sync(_menu);
		}
	}
}

function scr_ui_menu_update(_menu, _delta_seconds = -1){
	if (!is_struct(_menu)) return;
	if (_delta_seconds < 0) _delta_seconds = delta_time / 1000000;
	scr_ui_menu_layout_refresh(_menu);
	if (_menu.input_owned) scr_ui_input_poll(_menu.input);
	if (_menu.open){
		scr_ui_navigation_update(_menu.navigation);
		if (_menu.navigation.current == "closed" && _menu.open){
			if (is_callable(_menu.options.callbacks.on_cancel)) _menu.options.callbacks.on_cancel(_menu);
			scr_ui_menu_close(_menu);
		}
		var _event = _menu.navigation.last_event;
		var _handled_entity = -1;
		if (scr_ui_menu_handle_button_event(_menu, _event)){
			_handled_entity = variable_struct_exists(_event, "entity") ? _event.entity : -1;
		}
		var _events = scr_ui_events_drain(_menu.world);
		for (var _event_index = 0; _event_index < array_length(_events); _event_index++){
			var _ui_event = _events[_event_index];
			if (is_struct(_ui_event) && _ui_event.type == "button_activate" && _ui_event.entity != _handled_entity){
				scr_ui_menu_handle_button_event(_menu, _ui_event);
			}
		}
		scr_ui_menu_process_selection(_menu);
	}
	scr_ui_world_step(_menu.world, _delta_seconds);
}

function scr_ui_menu_draw_box(_rect, _fill, _frame_sprite, _frame_index, _alpha = 1){
	draw_set_alpha(_alpha);
	draw_set_color(_fill);
	draw_rectangle(_rect.left, _rect.top, _rect.left + _rect.width, _rect.top + _rect.height, false);
	draw_set_color(c_white);
	if (_frame_sprite >= 0) draw_sprite_stretched(_frame_sprite, _frame_index, _rect.left, _rect.top, _rect.width, _rect.height);
	draw_set_alpha(1);
}

function scr_ui_menu_draw(_menu){
	if (!is_struct(_menu) || !_menu.open) return;
	var _width = display_get_gui_width();
	var _height = display_get_gui_height();
	var _theme = _menu.options.theme;
	draw_set_color(_theme.canvas);
	draw_set_alpha(_theme.overlay_alpha);
	draw_rectangle(0, 0, _width, _height, false);
	draw_set_alpha(1);
	scr_ui_menu_layout_refresh(_menu);
	var _panel_rect = scr_ui_component_get(_menu.world, _menu.panel_entity, "bounds");
	var _panel_visual_rect = scr_ui_visual_rect(_menu.world, _menu.panel_entity, _panel_rect);
	scr_ui_menu_draw_box(_panel_visual_rect, _theme.panel, _menu.options.sprites.frame, _theme.frame_normal, _panel_visual_rect.alpha);
	draw_set_font(_menu.options.font);
	scr_ui_text_juice_draw(_menu.world, _menu.panel_entity, "title", _panel_rect.left + _menu.options.layout.padding, _panel_rect.top + _menu.options.layout.padding);
	scr_ui_text_juice_draw(_menu.world, _menu.panel_entity, "subtitle", _panel_rect.left + _menu.options.layout.padding, _panel_rect.top + _menu.options.layout.padding + _menu.options.layout.title_height);
	var _currency_channel = scr_ui_text_juice_get(_menu.world, _menu.panel_entity, "currency");
	if (is_struct(_currency_channel)){
		var _currency_y = _panel_rect.top + _menu.options.layout.padding + _menu.options.layout.title_height;
		scr_ui_text_juice_draw(_menu.world, _menu.panel_entity, "currency", _panel_rect.left + _panel_rect.width - _menu.options.layout.padding, _currency_y, max(64, _menu.options.layout.width == "auto" ? _panel_rect.width - 32 : 260));
	}
	var _currency_delta_channel = scr_ui_text_juice_get(_menu.world, _menu.panel_entity, "currency_delta");
	if (is_struct(_currency_delta_channel)){
		var _currency_delta_y = _panel_rect.top + _menu.options.layout.padding + _menu.options.layout.title_height - 12;
		scr_ui_text_juice_draw(_menu.world, _menu.panel_entity, "currency_delta", _panel_rect.left + _panel_rect.width - _menu.options.layout.padding, _currency_delta_y, 180);
	}
	for (var _index = 0; _index < array_length(_menu.item_entities); _index++){
		var _item = _index < array_length(_menu.items) ? _menu.items[_index] : undefined;
		if (!is_struct(_item) || !_item.enabled) continue;
		var _entity_id = _menu.item_entities[_index];
		var _bounds = scr_ui_component_get(_menu.world, _entity_id, "bounds");
		var _visual_rect = scr_ui_visual_rect(_menu.world, _entity_id, _bounds);
		var _frame = scr_ui_button_visual_state(_menu.world, _entity_id);
		if (_index == _menu.selected_index) _frame = _theme.frame_selected;
		var _fill = _index == _menu.selected_index ? _theme.panel_alt : _theme.panel_deep;
		scr_ui_menu_draw_box(_visual_rect, _fill, _menu.options.sprites.frame, _frame, _visual_rect.alpha);
		if (_item.icon >= 0) draw_sprite_ext(_item.icon, _item.icon_index, _visual_rect.left + 10, _visual_rect.top + _visual_rect.height * 0.5, 1, 1, 0, c_white, _visual_rect.alpha);
		scr_ui_text_juice_draw(_menu.world, _entity_id, "index", _visual_rect.left + 10, _visual_rect.top + _visual_rect.height * 0.5);
		scr_ui_text_juice_draw(_menu.world, _entity_id, "label", _visual_rect.left + 38, _visual_rect.top + _visual_rect.height * 0.5, max(64, _visual_rect.width - 132));
		scr_ui_text_juice_draw(_menu.world, _entity_id, "detail", _visual_rect.left + _visual_rect.width - 12, _visual_rect.top + _visual_rect.height * 0.5, 120);
	}
	var _description_rect = flexpanel_node_layout_get_position(_menu.layout.description, false);
	var _footer_rect = flexpanel_node_layout_get_position(_menu.layout.footer, false);
	draw_set_color(_theme.panel_deep);
	draw_set_alpha(_panel_visual_rect.alpha);
	draw_rectangle(_description_rect.left, _description_rect.top, _description_rect.left + _description_rect.width, _description_rect.top + _description_rect.height, false);
	draw_set_alpha(1);
	scr_ui_text_juice_draw(_menu.world, _menu.panel_entity, "description", _description_rect.left + 10, _description_rect.top + 8, max(32, _description_rect.width - 20));
	scr_ui_text_juice_draw(_menu.world, _menu.panel_entity, "footer", _footer_rect.left + 10, _footer_rect.top + _footer_rect.height * 0.5);
	scr_draw_reset();
}

function scr_ui_menu_destroy(_menu){
	if (!is_struct(_menu)) return;
	if (is_struct(_menu.layout) && variable_struct_exists(_menu.layout, "root")) flexpanel_delete_node(_menu.layout.root, true);
	if (_menu.owns_world) scr_ui_world_destroy(_menu.world);
	_menu.open = false;
}


// ===== Full Project Inventory: scripts/scr_ui_game_select/scr_ui_game_select.gml =====
/// @desc Zelda-like save/file selection built on the reusable menu screen.

function scr_ui_game_select_slot(_name, _description = "", _options = undefined){
	var _slot = {
		name: string(_name),
		description: string(_description),
		detail: "NEW FILE",
		status: "",
		hearts: "",
		location: "",
		payload: undefined,
		enabled: true
	};
	if (is_struct(_options)) _slot = scr_ui_menu_merge(_slot, _options);
	return _slot;
}

function scr_ui_game_select_default_options(){
	return {
		title: "SELECT ADVENTURE",
		subtitle: "Choose a file to continue your journey",
		footer: "ARROWS MOVE    ENTER SELECT    ESC BACK",
		max_items: 3,
		variant: "game_select",
		layout: {height: "80%", item_height: 96, card_height: 96, description_height: 54},
		slots: [
			scr_ui_game_select_slot("FILE 1", "A new adventure awaits.", {detail: "NEW FILE"}),
			scr_ui_game_select_slot("FILE 2", "The wind carries an old song.", {detail: "EMPTY"}),
			scr_ui_game_select_slot("FILE 3", "A quiet save at dusk.", {detail: "EMPTY"})
		],
		callbacks: {
			on_game_selected: function(_screen = undefined, _slot = undefined, _index = -1){},
			on_cancel: function(_screen = undefined){}
		}
	};
}

function scr_ui_game_select_create(_options = undefined){
	var _settings = scr_ui_menu_merge(scr_ui_game_select_default_options(), _options);
	var _slots = variable_struct_exists(_settings, "slots") && is_array(_settings.slots) ? _settings.slots : [];
	_settings.items = [];
	_settings.max_items = max(1, min(_settings.max_items, array_length(_slots) > 0 ? array_length(_slots) : _settings.max_items));
	for (var _index = 0; _index < array_length(_slots); _index++){
		var _slot = scr_ui_game_select_slot("FILE " + string(_index + 1));
		if (is_struct(_slots[_index])) _slot = scr_ui_menu_merge(_slot, _slots[_index]);
		var _detail = _slot.detail;
		if (string_length(_slot.status) > 0) _detail = _slot.status;
		if (string_length(_slot.hearts) > 0) _detail = scr_concat(_detail, "   ", _slot.hearts);
		if (string_length(_slot.location) > 0) _detail = scr_concat(_detail, "   ", _slot.location);
		array_push(_settings.items, scr_ui_menu_item(_slot.name, "game_select", {slot_index: _index}, {
			detail: _detail,
			description: _slot.description,
			enabled: _slot.enabled,
			icon: variable_struct_exists(_slot, "icon") ? _slot.icon : -1,
			icon_index: variable_struct_exists(_slot, "icon_index") ? _slot.icon_index : 0
		}));
	}
	var _user_activate = is_struct(_settings.callbacks) && variable_struct_exists(_settings.callbacks, "on_activate") ? _settings.callbacks.on_activate : undefined;
	_settings.callbacks.on_activate = function(_screen, _item, _index){
		var _slot_index = _index;
		if (is_struct(_item.payload) && variable_struct_exists(_item.payload, "slot_index")) _slot_index = _item.payload.slot_index;
		_screen.selected_slot = _slot_index >= 0 && _slot_index < array_length(_screen.game_slots) ? _screen.game_slots[_slot_index] : undefined;
		if (is_callable(_screen.options.callbacks.on_game_selected)) _screen.options.callbacks.on_game_selected(_screen, _screen.selected_slot, _slot_index);
		if (is_callable(_screen.game_select_user_activate)) _screen.game_select_user_activate(_screen, _item, _index);
	};
	var _screen = scr_ui_menu_create(_settings);
	_screen.kind = "game_select";
	_screen.game_select_user_activate = _user_activate;
	_screen.game_slots = [];
	for (var _slot_index = 0; _slot_index < array_length(_slots); _slot_index++){
		array_push(_screen.game_slots, is_struct(_slots[_slot_index]) ? _slots[_slot_index] : scr_ui_game_select_slot("FILE " + string(_slot_index + 1)));
	}
	_screen.selected_slot = undefined;
	return _screen;
}

function scr_ui_game_select_set_slots(_screen, _slots){
	if (!is_struct(_screen) || _screen.kind != "game_select" || !is_array(_slots)) return false;
	_screen.game_slots = _slots;
	var _items = [];
	for (var _index = 0; _index < array_length(_slots); _index++){
		var _slot = is_struct(_slots[_index]) ? _slots[_index] : scr_ui_game_select_slot("FILE " + string(_index + 1));
		var _detail = variable_struct_exists(_slot, "detail") ? _slot.detail : "NEW FILE";
		if (variable_struct_exists(_slot, "status") && string_length(_slot.status) > 0) _detail = _slot.status;
		array_push(_items, scr_ui_menu_item(_slot.name, "game_select", {slot_index: _index}, {
			detail: _detail,
			description: variable_struct_exists(_slot, "description") ? _slot.description : "",
			enabled: !variable_struct_exists(_slot, "enabled") || _slot.enabled
		}));
	}
	scr_ui_menu_set_items(_screen, _items);
	return true;
}

function scr_ui_game_select_open(_screen){ return scr_ui_menu_open(_screen); }
function scr_ui_game_select_close(_screen){ return scr_ui_menu_close(_screen); }
function scr_ui_game_select_update(_screen, _delta_seconds = -1){ scr_ui_menu_update(_screen, _delta_seconds); }
function scr_ui_game_select_draw(_screen){ scr_ui_menu_draw(_screen); }


// ===== Sprouts and Steel frontend integration =====
/// @desc Shared visual language for the title, pause, journal, stats, and inventory screens.
function scr_sas_frontend_theme(){
	return {
		canvas: make_color_rgb(7, 16, 17),
		overlay_alpha: 0.90,
		panel: make_color_rgb(20, 39, 39),
		panel_alt: make_color_rgb(35, 68, 58),
		panel_deep: make_color_rgb(10, 24, 25),
		text: make_color_rgb(235, 244, 226),
		muted: make_color_rgb(157, 183, 164),
		gold: make_color_rgb(247, 196, 91),
		accent: make_color_rgb(126, 218, 176),
		good: make_color_rgb(150, 235, 145),
		error: make_color_rgb(255, 116, 108),
		shadow: make_color_rgb(2, 8, 8),
		frame_normal: 0,
		frame_hover: 1,
		frame_selected: 2,
		frame_disabled: 0
	};
}

function scr_sas_frontend_input_bindings(){
	return {
		toggle: ord("P"),
		confirm: [vk_enter, ord("E")],
		back: vk_escape,
		up: [vk_up, ord("W")],
		down: [vk_down, ord("S")],
		left: [vk_left, ord("A")],
		right: [vk_right, ord("D")],
		focus: vk_tab
	};
}

function scr_sas_frontend_menu_base(_input, _title, _subtitle, _footer, _max_items = 8){
	return {
		title: _title,
		subtitle: _subtitle,
		footer: _footer,
		max_items: _max_items,
		font: fnt_default_ui,
		input: _input,
		input_owned: true,
		theme: scr_sas_frontend_theme(),
		sprites: {frame: spr_invBox},
		layout: {
			width: "80%",
			height: "90%",
			padding: 12,
			gap: 3,
			title_height: 24,
			subtitle_height: 16,
			item_height: 22,
			card_height: 50,
			description_height: 34,
			footer_height: 18,
			item_width: "100%"
		}
	};
}

function scr_sas_frontend_create_game_select(_owner, _input){
	var _options = scr_sas_frontend_menu_base(
		_input,
		"SPROUTS & STEEL",
		"GROW  /  GATHER  /  SURVIVE",
		"ARROWS / WASD MOVE    ENTER / E SELECT    ESC BACK",
		3
	);
	_options.variant = "game_select";
	_options.layout = scr_ui_menu_merge(_options.layout, {
		width: "88%",
		height: "92%",
		padding: 16,
		gap: 5,
		title_height: 30,
		subtitle_height: 18,
		card_height: 52,
		description_height: 32,
		footer_height: 18
	});
	_options.slots = [
		scr_ui_game_select_slot(
			"NEW HARVEST",
			"Begin a new season beneath the old oak.",
			{detail: "ENTER FIELD", location: "MEADOW", hearts: "HEARTS 04"}
		),
		scr_ui_game_select_slot(
			"CONTINUE",
			"Resume the latest field notes and keep the garden growing.",
			{detail: "CURRENT RUN", status: "READY", location: "FIELD CAMP", hearts: "HEARTS 04"}
		),
		scr_ui_game_select_slot(
			"PRACTICE GARDEN",
			"A calm place to test tools, seeds, and new routes.",
			{detail: "PRACTICE", location: "TRAINING PLOT", hearts: "HEARTS 04"}
		)
	];
	_options.callbacks = {
		on_game_selected: function(_screen = undefined, _slot = undefined, _index = -1){
			if (is_struct(_screen) && instance_exists(_screen.owner)){
				scr_sas_frontend_start_game(_screen.owner, _index);
			}
		},
		on_cancel: function(_screen = undefined){}
	};
	var _screen = scr_ui_game_select_create(_options);
	_screen.owner = _owner;
	return _screen;
}

function scr_sas_frontend_create_pause_menu(_owner, _input){
	var _options = scr_sas_frontend_menu_base(
		_input,
		"PAUSED",
		"THE GARDEN IS WAITING",
		"ARROWS / WASD MOVE    ENTER / E SELECT    P RESUME",
		5
	);
	_options.layout = scr_ui_menu_merge(_options.layout, {
		width: "74%",
		height: "90%",
		padding: 16,
		gap: 5,
		title_height: 28,
		subtitle_height: 18,
		item_height: 29,
		description_height: 34,
		footer_height: 20
	});
	_options.items = [
		scr_ui_menu_item("RESUME", "resume", undefined, {
			detail: "BACK TO FIELD",
			description: "Return to the field and keep the season moving."
		}),
		scr_ui_menu_item("INVENTORY", "inventory", undefined, {
			detail: "BAG / EQUIPMENT",
			description: "Sort your tools, seeds, materials, and equipment."
		}),
		scr_ui_menu_item("QUESTS", "quests", undefined, {
			detail: "FIELD NOTES",
			description: "Review active objectives and the story growing around them."
		}),
		scr_ui_menu_item("STATS", "stats", undefined, {
			detail: "PLAYER PROFILE",
			description: "Read your current health, power, defense, and speed."
		}),
		scr_ui_menu_item("TITLE SCREEN", "title", undefined, {
			detail: "LEAVE FIELD",
			description: "Return to the harvest screen. Your current field remains unchanged."
		})
	];
	_options.callbacks = {
		on_activate: function(_menu = undefined, _item = undefined, _index = -1){
			if (is_struct(_menu) && instance_exists(_menu.owner) && is_struct(_item)){
				scr_sas_frontend_pause_command(_menu.owner, _item.command);
			}
		},
		on_cancel: function(_menu = undefined){
			if (is_struct(_menu) && instance_exists(_menu.owner)){
				scr_sas_frontend_pause_command(_menu.owner, "resume");
			}
		}
	};
	var _menu = scr_ui_menu_create(_options);
	_menu.owner = _owner;
	return _menu;
}

function scr_sas_frontend_create_info_menu(_owner, _input, _kind, _title, _subtitle, _footer){
	var _options = scr_sas_frontend_menu_base(_input, _title, _subtitle, _footer, 7);
	_options.description = "Select a note to read more.";
	_options.callbacks = {
		on_activate: function(_menu = undefined, _item = undefined, _index = -1){},
		on_cancel: function(_menu = undefined){
			if (is_struct(_menu) && instance_exists(_menu.owner)){
				scr_sas_frontend_return_to_pause(_menu.owner);
			}
		}
	};
	var _menu = scr_ui_menu_create(_options);
	_menu.owner = _owner;
	_menu.info_kind = _kind;
	return _menu;
}

function scr_sas_frontend_start_game(_owner, _slot_index = -1){
	if (!instance_exists(_owner)) return;
	if (is_struct(_owner.game_select) && _owner.game_select.open){
		scr_ui_game_select_close(_owner.game_select);
	}
	_owner.frontend_mode = "gameplay";
	scr_sas_frontend_unlock_game(_owner);
}

function scr_sas_frontend_lock_game(_owner){
	if (!instance_exists(_owner)) return;
	instance_deactivate_object(obj_player);
	instance_deactivate_object(obj_sortable);
	_owner.frontend_locked = true;
	IN_UI = true;
}

function scr_sas_frontend_unlock_game(_owner){
	if (!instance_exists(_owner)) return;
	instance_activate_object(obj_player);
	instance_activate_object(obj_sortable);
	_owner.frontend_locked = false;
	IN_UI = false;
}

function scr_sas_frontend_open_pause(_owner){
	if (!instance_exists(_owner) || _owner.frontend_mode != "gameplay") return;
	_owner.frontend_mode = "pause";
	scr_sas_frontend_lock_game(_owner);
	if (is_struct(_owner.pause_menu) && !_owner.pause_menu.open){
		scr_ui_menu_open(_owner.pause_menu);
	}
}

function scr_sas_frontend_pause_command(_owner, _command){
	if (!instance_exists(_owner)) return;
	switch (_command){
		case "resume":
			if (is_struct(_owner.pause_menu)) scr_ui_menu_close(_owner.pause_menu);
			_owner.frontend_mode = "gameplay";
			scr_sas_frontend_unlock_game(_owner);
			break;
		case "inventory":
			if (is_struct(_owner.pause_menu)) scr_ui_menu_close(_owner.pause_menu);
			_owner.frontend_mode = "inventory";
			scr_sas_frontend_lock_game(_owner);
			with (_owner) scr_inventory_open();
			break;
		case "quests":
			if (is_struct(_owner.pause_menu)) scr_ui_menu_close(_owner.pause_menu);
			_owner.frontend_mode = "quests";
			scr_sas_frontend_lock_game(_owner);
			scr_sas_frontend_refresh_quests(_owner.quest_menu);
			if (is_struct(_owner.quest_menu)) scr_ui_menu_open(_owner.quest_menu);
			break;
		case "stats":
			if (is_struct(_owner.pause_menu)) scr_ui_menu_close(_owner.pause_menu);
			_owner.frontend_mode = "stats";
			scr_sas_frontend_lock_game(_owner);
			scr_sas_frontend_refresh_stats(_owner.stats_menu);
			if (is_struct(_owner.stats_menu)) scr_ui_menu_open(_owner.stats_menu);
			break;
		case "title":
			if (is_struct(_owner.pause_menu)) scr_ui_menu_close(_owner.pause_menu);
			_owner.frontend_mode = "game_select";
			scr_sas_frontend_lock_game(_owner);
			if (is_struct(_owner.game_select) && !_owner.game_select.open){
				scr_ui_game_select_open(_owner.game_select);
			}
			break;
	}
}

function scr_sas_frontend_return_to_pause(_owner){
	if (!instance_exists(_owner) || _owner.frontend_shutting_down) return;
	if (is_struct(_owner.game_select) && _owner.game_select.open) scr_ui_game_select_close(_owner.game_select);
	if (is_struct(_owner.quest_menu) && _owner.quest_menu.open) scr_ui_menu_close(_owner.quest_menu);
	if (is_struct(_owner.stats_menu) && _owner.stats_menu.open) scr_ui_menu_close(_owner.stats_menu);
	_owner.frontend_mode = "pause";
	scr_sas_frontend_lock_game(_owner);
	if (is_struct(_owner.pause_menu) && !_owner.pause_menu.open){
		scr_ui_menu_open(_owner.pause_menu);
	}
}

function scr_sas_frontend_quest_item(_mission, _status){
	var _name = "FIELD NOTE";
	var _description = "A field note with no description yet.";
	if (is_struct(_mission)){
		if (variable_struct_exists(_mission, "name")) _name = string(_mission.name);
		if (variable_struct_exists(_mission, "description")) _description = string(_mission.description);
		var _objectives = variable_struct_exists(_mission, "objectives") ? _mission.objectives : [];
		if (is_array(_objectives)){
			for (var _objective_index = 0; _objective_index < array_length(_objectives); _objective_index++){
				var _objective = _objectives[_objective_index];
				var _objective_text = "";
				if (is_struct(_objective) && variable_struct_exists(_objective, "get_display_string")){
					var _display_method = variable_struct_get(_objective, "get_display_string");
					if (is_callable(_display_method)) _objective_text = _display_method();
				}
				if (string_length(_objective_text) > 0){
					_description = scr_concat(_description, "\\n", _objective_text);
				}
			}
		}
	}
	return scr_ui_menu_item(_name, "quest_details", undefined, {
		detail: _status,
		description: _description,
		detail_color: _status == "COMPLETE" ? scr_sas_frontend_theme().good : scr_sas_frontend_theme().accent
	});
}

function scr_sas_frontend_refresh_quests(_menu){
	if (!is_struct(_menu)) return;
	var _items = [];
	var _status = "JOURNAL";
	var _manager_ready = false;
	var _manager = undefined;
	if (variable_global_exists("mission_manager")){
		var _manager_ref = global.mission_manager;
		if (instance_exists(_manager_ref)){
			_manager = _manager_ref;
			_manager_ready = true;
		}
	}
	if (_manager_ready){
		var _active = is_array(_manager.active_missions) ? _manager.active_missions : [];
		for (var _active_index = 0; _active_index < array_length(_active); _active_index++){
			if (array_length(_items) >= _menu.options.max_items) break;
			array_push(_items, scr_sas_frontend_quest_item(_active[_active_index], "ACTIVE"));
		}
		if (array_length(_items) == 0 && is_array(_manager.completed_missions)){
			for (var _completed_index = 0; _completed_index < array_length(_manager.completed_missions); _completed_index++){
				if (array_length(_items) >= _menu.options.max_items) break;
				var _completed_id = string(_manager.completed_missions[_completed_index]);
				var _completed_mission = undefined;
				if (is_struct(_manager.available_missions) && variable_struct_exists(_manager.available_missions, _completed_id)){
					_completed_mission = variable_struct_get(_manager.available_missions, _completed_id);
				}
				if (is_struct(_completed_mission)){
					array_push(_items, scr_sas_frontend_quest_item(_completed_mission, "COMPLETE"));
				}
			}
		}
		if (array_length(_items) == 0 && is_struct(_manager.available_missions)){
			var _available_names = variable_struct_get_names(_manager.available_missions);
			for (var _available_index = 0; _available_index < array_length(_available_names); _available_index++){
				if (array_length(_items) >= _menu.options.max_items) break;
				var _available_mission = variable_struct_get(_manager.available_missions, _available_names[_available_index]);
				if (is_struct(_available_mission)){
					array_push(_items, scr_sas_frontend_quest_item(_available_mission, "AVAILABLE"));
				}
			}
		}
	}
	if (array_length(_items) == 0 && variable_global_exists("MISSIONS") && is_array(global.MISSIONS)){
		for (var _mission_index = 0; _mission_index < array_length(global.MISSIONS); _mission_index++){
			if (array_length(_items) >= _menu.options.max_items) break;
			array_push(_items, scr_sas_frontend_quest_item(global.MISSIONS[_mission_index], "AVAILABLE"));
		}
	}
	if (array_length(_items) == 0){
		array_push(_items, scr_ui_menu_item("CLEAR THE RUBBLE", "quest_details", undefined, {
			detail: "FIELD NOTE",
			description: "The old path is blocked by ancient, fragile walls. Clear the rubble and open the way forward."
		}));
	}
	_menu.status = _status;
	scr_ui_menu_set_items(_menu, _items);
	_menu.description = is_struct(_items[0]) && variable_struct_exists(_items[0], "description")
		? _items[0].description
		: "Select a field note to read more.";
	_menu.last_selected_index = -2;
	scr_ui_menu_sync(_menu);
}

function scr_sas_frontend_bag_occupied(_bag){
	if (!is_struct(_bag) || !variable_struct_exists(_bag, "items") || !is_array(_bag.items)) return 0;
	var _items = _bag.items;
	var _count = 0;
	for (var _index = 0; _index < array_length(_items); _index++){
		if (is_struct(_items[_index])) _count++;
	}
	return _count;
}

function scr_sas_frontend_stat_item(_label, _detail, _description){
	return scr_ui_menu_item(_label, "stat_details", undefined, {
		detail: _detail,
		description: _description,
		detail_color: scr_sas_frontend_theme().accent
	});
}

function scr_sas_frontend_refresh_stats(_menu){
	if (!is_struct(_menu)) return;
	var _items = [];
	var _stats = undefined;
	if (variable_global_exists("SYS") && is_struct(global.SYS) && variable_struct_exists(global.SYS, "stats")){
		_stats = global.SYS.stats;
	}
	if (is_struct(_stats)){
		var _stat_fields = [
			{key: "hp", label: "HEALTH", description: "Vitality and current condition."},
			{key: "atk", label: "ATTACK", description: "Power carried into each strike."},
			{key: "def", label: "DEFENSE", description: "Resilience when the field pushes back."},
			{key: "spd", label: "SPEED", description: "How quickly you cross the garden."}
		];
		for (var _stat_index = 0; _stat_index < array_length(_stat_fields); _stat_index++){
			var _stat_data = _stat_fields[_stat_index];
			if (!variable_struct_exists(_stats, _stat_data.key)) continue;
			var _stat = variable_struct_get(_stats, _stat_data.key);
			var _current = 0;
			var _maximum = 0;
			if (is_struct(_stat)){
				if (variable_struct_exists(_stat, "get_val") && is_callable(_stat.get_val)) _current = _stat.get_val();
				if (variable_struct_exists(_stat, "get_max") && is_callable(_stat.get_max)) _maximum = _stat.get_max();
			}
			array_push(_items, scr_sas_frontend_stat_item(
				_stat_data.label,
				scr_concat(string(round(_current)), " / ", string(round(_maximum))),
				_stat_data.description
			));
		}
		if (variable_struct_exists(_stats, "level")){
			array_push(_items, scr_sas_frontend_stat_item(
				"FIELD LEVEL",
				string(_stats.level),
				"Your current level and long-term growth."
			));
		}
	}
	if (is_struct(BACKPACK)){
		array_push(_items, scr_sas_frontend_stat_item(
			"BACKPACK",
			scr_concat(scr_sas_frontend_bag_occupied(BACKPACK), " ITEMS"),
			"Seeds, materials, and discoveries carried between clearings."
		));
	}
	if (is_struct(GEAR)){
		array_push(_items, scr_sas_frontend_stat_item(
			"EQUIPMENT",
			scr_concat(scr_sas_frontend_bag_occupied(GEAR), " ITEMS"),
			"Tools and equipment ready for the next stretch of path."
		));
	}
	if (array_length(_items) == 0){
		array_push(_items, scr_sas_frontend_stat_item(
			"FIELD DATA",
			"UNAVAILABLE",
			"Field statistics will appear when the season systems finish loading."
		));
	}
	_menu.status = "LIVE DATA";
	scr_ui_menu_set_items(_menu, _items);
	_menu.description = is_struct(_items[0]) && variable_struct_exists(_items[0], "description")
		? _items[0].description
		: "Select a stat to inspect.";
	_menu.last_selected_index = -2;
	scr_ui_menu_sync(_menu);
}

