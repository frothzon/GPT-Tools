/// @function spriter_lerp(a, b, t)
/// @description Interpolates numeric values. Internal helper used by SpriterPlayer.
function spriter_lerp(_a, _b, _t) {
    return _a + (_b - _a) * _t;
}

/// @description Reads an optional struct field without raising a missing-variable error.
function spriter_value(_struct, _name, _fallback) {
    return is_struct(_struct) && variable_struct_exists(_struct, _name) ? variable_struct_get(_struct, _name) : _fallback;
}

/// @function spriter_curve(t, kind, c1, c2, c3, c4)
/// @description Evaluates a Spriter easing curve. Controls are normalized between 0 and 1.
function spriter_curve(_t, _kind, _c1, _c2, _c3, _c4) {
    _t = clamp(_t, 0, 1);
    if (_kind == 0) return 0; // instant
    if (_kind == 1) return _t; // linear
    var _u = 1 - _t;
    if (_kind == 2) return 2 * _u * _t * _c1 + _t * _t;
    if (_kind == 6) {
        // Bezier controls are x1,y1,x2,y2. Invert x before evaluating y.
        var _lo = 0, _hi = 1, _v = _t;
        for (var _iteration = 0; _iteration < 24; ++_iteration) {
            _v = (_lo + _hi) * 0.5;
            var _iv = 1 - _v;
            var _x = 3 * _iv * _iv * _v * _c1 + 3 * _iv * _v * _v * _c3 + _v * _v * _v;
            if (_x < _t) _lo = _v; else _hi = _v;
        }
        var _iv = 1 - _v;
        return 3 * _iv * _iv * _v * _c2 + 3 * _iv * _v * _v * _c4 + _v * _v * _v;
    }
    if (_kind == 3) {
        return 3 * _u * _u * _t * _c1 + 3 * _u * _t * _t * _c2 + _t * _t * _t;
    }
    if (_kind == 4) {
        return 4 * _u * _u * _u * _t * _c1 + 6 * _u * _u * _t * _t * _c2
            + 4 * _u * _t * _t * _t * _c3 + _t * _t * _t * _t;
    }
    if (_kind == 5) {
        return 5 * _u * _u * _u * _u * _t * _c1 + 10 * _u * _u * _u * _t * _t * _c2
            + 10 * _u * _u * _t * _t * _t * _c3 + 5 * _u * _t * _t * _t * _t * _c4
            + _t * _t * _t * _t * _t;
    }
    return _t;
}

/// @function spriter_compose(out, out_index, parent, parent_index, local, local_index)
/// @description Composes component translation, rotation, scale, and alpha using Spriter's TRS rules.
function spriter_compose(_out, _oi, _parent, _pi, _local, _li) {
    var _px = _parent[_pi], _py = _parent[_pi + 1];
    var _pa = _parent[_pi + 2], _psx = _parent[_pi + 3], _psy = _parent[_pi + 4];
    var _lx = _local[_li], _ly = _local[_li + 1];
    var _c = dcos(_pa), _s = dsin(_pa);
    _out[_oi] = _px + _c * _lx * _psx - _s * _ly * _psy;
    _out[_oi + 1] = _py + _s * _lx * _psx + _c * _ly * _psy;
    _out[_oi + 2] = _pa + _local[_li + 2] * sign(_psx * _psy);
    _out[_oi + 3] = _psx * _local[_li + 3];
    _out[_oi + 4] = _psy * _local[_li + 4];
    _out[_oi + 5] = _parent[_pi + 5] * _local[_li + 5];
}

/// @function spriter_sample_timeline(clip, timeline_index, key_index, time_ms, out, out_index)
/// @description Samples one timeline into nine values: x, y, angle, scales, alpha, pivots, and file index.
function spriter_sample_timeline(_clip, _timeline_index, _key_index, _time_ms, _looping, _out, _oi, _files) {
    var _tl = _clip.timelines[_timeline_index];
    var _count = _tl.key_count;
    if (_count <= 0) return;
    var _stride = 18;
    var _ki = clamp(_key_index, 0, _count - 1);
    var _a = _ki * _stride;
    var _next = _ki + 1;
    var _duration = _clip.duration;
    var _loop = _looping;
    var _ta = _tl.keys[_a];
    var _tb;
    var _b = _a;
    var _sample_time = _time_ms;
    if (_next < _count) {
        _b = _next * _stride;
        _tb = _tl.keys[_b];
    } else if (_loop && _count > 1) {
        _b = 0;
        _tb = _tl.keys[0] + _duration;
        if (_sample_time < _ta) _sample_time += _duration;
    } else {
        _tb = _ta;
    }
    var _t = 0;
    if (_tb > _ta) _t = (_sample_time - _ta) / (_tb - _ta);
    var _e = spriter_curve(_t, _tl.keys[_a + 11], _tl.keys[_a + 12], _tl.keys[_a + 13], _tl.keys[_a + 14], _tl.keys[_a + 15]);
    var _spin = _tl.keys[_a + 10];
    var _angle_b = _tl.keys[_b + 3];
    if (_spin == 0) _angle_b = _tl.keys[_a + 3];
    else if (_spin > 0) while (_angle_b < _tl.keys[_a + 3]) _angle_b += 360;
    else while (_angle_b > _tl.keys[_a + 3]) _angle_b -= 360;
    _out[_oi] = spriter_lerp(_tl.keys[_a + 1], _tl.keys[_b + 1], _e);
    _out[_oi + 1] = spriter_lerp(_tl.keys[_a + 2], _tl.keys[_b + 2], _e);
    _out[_oi + 2] = spriter_lerp(_tl.keys[_a + 3], _angle_b, _e);
    _out[_oi + 3] = spriter_lerp(_tl.keys[_a + 4], _tl.keys[_b + 4], _e);
    _out[_oi + 4] = spriter_lerp(_tl.keys[_a + 5], _tl.keys[_b + 5], _e);
    _out[_oi + 5] = spriter_lerp(_tl.keys[_a + 6], _tl.keys[_b + 6], _e);
    var _bpx = _tl.keys[_b + 7], _bpy = _tl.keys[_b + 8], _bfile = _tl.keys[_b + 9];
    if (_bfile >= 0 && _bfile < array_length(_files)) {
        if (_bpx < -1000) _bpx = _files[_bfile].pivot_x;
        if (_bpy < -1000) _bpy = _files[_bfile].pivot_y;
    }
    _out[_oi + 6] = _tl.keys[_a + 7] < -1000 ? _tl.keys[_a + 7] : spriter_lerp(_tl.keys[_a + 7], _bpx, _e);
    _out[_oi + 7] = _tl.keys[_a + 8] < -1000 ? _tl.keys[_a + 8] : spriter_lerp(_tl.keys[_a + 8], _bpy, _e);
    _out[_oi + 8] = _tl.keys[_a + 9];
    // Files switch at keys. Explicit pivots interpolate; default pivots follow character maps.
}

/// @function spriter_mainline_index(clip, time_ms)
/// @description Returns the active mainline key index at a local animation time.
function spriter_mainline_index(_clip, _time_ms) {
    var _lo = 0, _hi = array_length(_clip.mainline) - 1, _answer = 0;
    while (_lo <= _hi) {
        var _mid = floor((_lo + _hi) * 0.5);
        if (_clip.mainline[_mid].time <= _time_ms) { _answer = _mid; _lo = _mid + 1; }
        else _hi = _mid - 1;
    }
    return _answer;
}

/// @function spriter_find_name(values, name)
/// @description Returns the index of a named definition entry, or -1 when it does not exist.
function spriter_find_name(_values, _name) {
    for (var _i = 0; _i < array_length(_values); ++_i) if (_values[_i] == _name) return _i;
    return -1;
}

/// @function SpriterLibrary()
/// @description Shared registry for generated entity struct factories.
/// @returns {Struct} A new registry; definitions are created lazily on entity() lookup.
function SpriterLibrary() constructor {
    self.factories = {};
    self.cache = {};
    /// @function SpriterLibrary.register
    /// @param {String} entity_name Exact SCML entity name.
    /// @param {Function} factory Function returning an immutable rig definition struct.
    /// @returns {Struct} This library, for chaining.
    self.register = function(_name, _factory) {
        variable_struct_set(self.factories, _name, _factory);
        return self;
    };
    /// @function SpriterLibrary.entity
    /// @param {String} entity_name Exact SCML entity name.
    /// @returns {Struct|Undefined} Shared definition; logs and returns undefined for an unknown name.
    self.entity = function(_name) {
        if (variable_struct_exists(self.cache, _name)) return variable_struct_get(self.cache, _name);
        if (!variable_struct_exists(self.factories, _name)) {
            show_debug_message("SpriterLibrary: unknown entity '" + string(_name) + "'.");
            return undefined;
        }
        var _definition = variable_struct_get(self.factories, _name)();
        variable_struct_set(self.cache, _name, _definition);
        return _definition;
    };
    /// @function SpriterLibrary.names
    /// @returns {Array<String>} Registered entity names in ascending order.
    self.names = function() {
        var _names = [];
        var _keys = variable_struct_get_names(self.factories);
        for (var _i = 0; _i < array_length(_keys); ++_i) array_push(_names, _keys[_i]);
        array_sort(_names, true);
        return _names;
    };
}

/// @function SpriterRigBuilder(name)
/// @description Creates an editable rig and clips that compile into the same shared struct format as converted SCML.
/// @param {String} name Name stored in the reusable definition.
/// @returns {Struct} A new builder. Invalid authored data is reported when added or built.
function SpriterRigBuilder(_name) constructor {
    self.name = _name;
    self.bones = [];
    self.parts = [];
    self.animations = [];
    /// @function SpriterRigBuilder.add_bone
    /// @param {String} bone_name Unique bone name.
    /// @param {String|Undefined} parent_name Parent added earlier, or undefined for a root.
    /// @param {Real} length Debug drawing length in pixels.
    /// @returns {Struct} This builder; build() reports unknown or out-of-order parent names.
    self.add_bone = function(_bone_name, _parent_name, _length = 12) {
        if (spriter_find_name(self.bones, _bone_name) >= 0) show_error("SpriterRigBuilder: duplicate bone '" + _bone_name + "'.", true);
        array_push(self.bones, _bone_name);
        self._bone_defs = is_undefined(self._bone_defs) ? [] : self._bone_defs;
        array_push(self._bone_defs, {name:_bone_name, parent:_parent_name, length:_length});
        return self;
    };
    /// @function SpriterRigBuilder.add_part
    /// @param {String} part_name Unique attachment name.
    /// @param {String} bone_name Parent bone name.
    /// @param {Asset.GMSprite} sprite GameMaker sprite asset to render.
    /// @param {String} sprite_name Stable readable asset name stored in the definition.
    /// @param {Real} pivot_x Horizontal pivot fraction from 0 to 1.
    /// @param {Real} pivot_y Vertical pivot fraction from 0 to 1, measured from the bottom like SCML.
    /// @param {Real} z Draw order; lower values draw first.
    /// @returns {Struct} This builder; build() reports unknown parent names.
    self.add_part = function(_part_name, _bone_name, _sprite, _sprite_name, _pivot_x = 0, _pivot_y = 1, _z = undefined) {
        if (spriter_find_name(self.parts, _part_name) >= 0) show_error("SpriterRigBuilder: duplicate part '" + _part_name + "'.", true);
        array_push(self.parts, _part_name);
        _pivot_x = is_undefined(_pivot_x) ? 0 : _pivot_x;
        _pivot_y = is_undefined(_pivot_y) ? 1 : _pivot_y;
        _z = is_undefined(_z) ? array_length(self._part_defs) : _z;
        array_push(self._part_defs, {name:_part_name, bone:_bone_name, sprite:_sprite, sprite_name:_sprite_name,
            width:sprite_get_width(_sprite), height:sprite_get_height(_sprite), pivot_x:_pivot_x, pivot_y:_pivot_y, z:_z});
        return self;
    };
    self._bone_defs = [];
    self._part_defs = [];
    /// @function SpriterRigBuilder.add_animation
    /// @param {String} animation_name Unique animation name.
    /// @param {Real} duration_ms Positive clip duration in milliseconds.
    /// @param {Bool} looping Whether playback wraps at the duration.
    /// @returns {Struct} This builder.
    self.add_animation = function(_animation_name, _duration_ms, _looping = true) {
        if (_duration_ms <= 0) show_error("SpriterRigBuilder: animation duration must be greater than zero.", true);
        for (var _i = 0; _i < array_length(self.animations); ++_i) if (self.animations[_i].name == _animation_name)
            show_error("SpriterRigBuilder: duplicate animation '" + _animation_name + "'.", true);
        array_push(self.animations, {name:_animation_name, duration:_duration_ms, looping:_looping, keys:[], events:[]});
        return self;
    };
    self._animation = function(_animation_name) {
        for (var _i = 0; _i < array_length(self.animations); ++_i) if (self.animations[_i].name == _animation_name) return self.animations[_i];
        show_error("SpriterRigBuilder: unknown animation '" + _animation_name + "'.", true);
        return undefined;
    };
    /// @function SpriterRigBuilder.add_key
    /// @param {String} animation_name Existing clip name.
    /// @param {String} target_type Either "bone" or "part".
    /// @param {String} target_name Existing bone or part name.
    /// @param {Real} time_ms Key time in milliseconds, from zero through clip duration.
    /// @param {Struct} transform Full local transform: x, y, angle, scale_x, scale_y, alpha; parts may set pivot_x/pivot_y.
    /// @param {Struct|Undefined} metadata Optional curve, spin, and c1 through c4 values.
    /// @returns {Struct} This builder; unknown targets and out-of-range times raise an error.
    self.add_key = function(_animation_name, _target_type, _target_name, _time_ms, _transform, _metadata = undefined) {
        var _animation = self._animation(_animation_name);
        if (_time_ms < 0 || _time_ms > _animation.duration) show_error("SpriterRigBuilder: key time falls outside the animation.", true);
        if (_target_type != "bone" && _target_type != "part") show_error("SpriterRigBuilder: target type must be 'bone' or 'part'.", true);
        array_push(_animation.keys, {type:_target_type, target:_target_name, time:_time_ms, transform:_transform, metadata:_metadata});
        return self;
    };
    /// @function SpriterRigBuilder.add_event
    /// @param {String} animation_name Existing clip name.
    /// @param {String} event_name Name passed to player listeners.
    /// @param {Real} time_ms Event time in milliseconds.
    /// @param {Any} payload Optional event payload.
    /// @returns {Struct} This builder; unknown clips and out-of-range times raise an error.
    self.add_event = function(_animation_name, _event_name, _time_ms, _payload = undefined) {
        var _animation = self._animation(_animation_name);
        if (_time_ms < 0 || _time_ms > _animation.duration) show_error("SpriterRigBuilder: event time falls outside the animation.", true);
        array_push(_animation.events, {name:_event_name, time:_time_ms, payload:_payload, source:"builder"});
        return self;
    };
    /// @function SpriterRigBuilder.build
    /// @returns {Struct} Immutable entity definition shared safely by multiple players.
    /// @description Raises an error for duplicate names, invalid parents, or an empty animation list.
    self.build = function() {
        if (array_length(self.animations) == 0) show_error("SpriterRigBuilder: add at least one animation before build().", true);
        var _bone_lookup = {}, _part_lookup = {};
        for (var _i = 0; _i < array_length(self.bones); ++_i) variable_struct_set(_bone_lookup, self.bones[_i], _i);
        for (var _i = 0; _i < array_length(self.parts); ++_i) variable_struct_set(_part_lookup, self.parts[_i], _i);
        var _bone_defs = self._bone_defs;
        var _part_defs = self._part_defs;
        var _files = [];
        for (var _i = 0; _i < array_length(_part_defs); ++_i) {
            var _p = _part_defs[_i];
            if (!variable_struct_exists(_bone_lookup, _p.bone)) show_error("SpriterRigBuilder: part '" + _p.name + "' refers to an unknown bone.", true);
            array_push(_files, {folder_id:"builder", file_id:string(_i), path:_p.sprite_name, width:_p.width, height:_p.height,
                pivot_x:_p.pivot_x, pivot_y:_p.pivot_y, sprite_name:_p.sprite_name, sprite:_p.sprite});
        }
        var _clips = [];
        for (var _ai = 0; _ai < array_length(self.animations); ++_ai) {
            var _src = self.animations[_ai];
            var _timeline_map = {}, _timelines = [];
            for (var _bi = 0; _bi < array_length(_bone_defs); ++_bi) {
                var _bd = _bone_defs[_bi];
                var _parent = -1;
                if (!is_undefined(_bd.parent) && _bd.parent != "") {
                    if (!variable_struct_exists(_bone_lookup, _bd.parent)) show_error("SpriterRigBuilder: bone '" + _bd.name + "' refers to an unknown parent.", true);
                    _parent = variable_struct_get(_bone_lookup, _bd.parent);
                    if (_parent >= _bi) show_error("SpriterRigBuilder: add each parent bone before its children.", true);
                }
                variable_struct_set(_timeline_map, "bone:" + _bd.name, array_length(_timelines));
                array_push(_timelines, {name:_bd.name, object_type:"bone", authored:false, key_count:1, keys:[0,0,0,0,1,1,1,-1,-1,-1,0,1,0.5,0.5,0.5,0.5,0.5,0.5]});
            }
            for (var _pi = 0; _pi < array_length(_part_defs); ++_pi) {
                var _pd = _part_defs[_pi];
                variable_struct_set(_timeline_map, "part:" + _pd.name, array_length(_timelines));
                array_push(_timelines, {name:_pd.name, object_type:"sprite", authored:false, key_count:1,
                    keys:[0,0,0,0,1,1,1,_pd.pivot_x,_pd.pivot_y,_pi,0,1,0.5,0.5,0.5,0.5,0.5,0.5]});
            }
            for (var _ki = 0; _ki < array_length(_src.keys); ++_ki) {
                var _src_key = _src.keys[_ki];
                var _map_name = _src_key.type + ":" + _src_key.target;
                if (!variable_struct_exists(_timeline_map, _map_name)) show_error("SpriterRigBuilder: key targets unknown " + _map_name + ".", true);
                var _ti = variable_struct_get(_timeline_map, _map_name);
                var _tl = _timelines[_ti];
                if (!_tl.authored) { _tl.keys = []; _tl.key_count = 0; _tl.authored = true; }
                var _tr = _src_key.transform;
                var _curve = spriter_value(_src_key.metadata, "curve", 1);
                var _file = _src_key.type == "part" ? variable_struct_get(_part_lookup, _src_key.target) : -1;
                array_push(_tl.keys, _src_key.time, _tr.x, _tr.y, _tr.angle, _tr.scale_x, _tr.scale_y, _tr.alpha,
                    _src_key.type == "part" ? spriter_value(_tr, "pivot_x", _part_defs[_file].pivot_x) : -1,
                    _src_key.type == "part" ? spriter_value(_tr, "pivot_y", _part_defs[_file].pivot_y) : -1,
                    _file, spriter_value(_src_key.metadata, "spin", 1), _curve,
                    spriter_value(_src_key.metadata, "c1", 0.5), spriter_value(_src_key.metadata, "c2", 0.5),
                    spriter_value(_src_key.metadata, "c3", 0.5), spriter_value(_src_key.metadata, "c4", 0.5), 0.5, 0.5);
                _tl.key_count += 1;
                _timelines[_ti] = _tl;
            }
            // Keep each track ordered before handing the clip to the player.
            for (var _ti = 0; _ti < array_length(_timelines); ++_ti) {
                var _tl = _timelines[_ti];
                if (_tl.key_count > 1) {
                    var _records = [];
                    for (var _ki = 0; _ki < _tl.key_count; ++_ki) {
                        var _record = [];
                        array_copy(_record, 0, _tl.keys, _ki * 18, 18);
                        array_push(_records, _record);
                    }
                    array_sort(_records, function(_a, _b) { return _a[0] - _b[0]; });
                    _tl.keys = [];
                    for (var _ki = 0; _ki < array_length(_records); ++_ki) for (var _f = 0; _f < 18; ++_f) array_push(_tl.keys, _records[_ki][_f]);
                    _timelines[_ti] = _tl;
                }
            }
            var _main_bones = [], _main_objects = [];
            for (var _bi = 0; _bi < array_length(_bone_defs); ++_bi) {
                var _bd = _bone_defs[_bi];
                var _parent = is_undefined(_bd.parent) || _bd.parent == "" ? -1 : variable_struct_get(_bone_lookup, _bd.parent);
                array_push(_main_bones, [_bi, variable_struct_get(_timeline_map, "bone:" + _bd.name), 0, _parent]);
            }
            for (var _pi = 0; _pi < array_length(_part_defs); ++_pi) {
                var _pd = _part_defs[_pi];
                array_push(_main_objects, [_pi, variable_struct_get(_timeline_map, "part:" + _pd.name), 0,
                    variable_struct_get(_bone_lookup, _pd.bone), _pd.z]);
            }
            array_sort(_main_objects, function(_a, _b) { return _a[4] - _b[4]; });
            var _times = [0], _mainline = [];
            for (var _ti = 0; _ti < array_length(_timelines); ++_ti) {
                var _tl = _timelines[_ti];
                for (var _ki = 0; _ki < _tl.key_count; ++_ki) {
                    var _time = _tl.keys[_ki * 18];
                    if (!array_contains(_times, _time)) array_push(_times, _time);
                }
            }
            array_sort(_times, true);
            for (var _mi = 0; _mi < array_length(_times); ++_mi) {
                var _time = _times[_mi], _bones = variable_clone(_main_bones), _objects = variable_clone(_main_objects);
                for (var _kind = 0; _kind < 2; ++_kind) {
                    var _refs = _kind == 0 ? _bones : _objects;
                    for (var _ri = 0; _ri < array_length(_refs); ++_ri) {
                        var _tl = _timelines[_refs[_ri][1]], _active = 0;
                        for (var _ki = 0; _ki < _tl.key_count; ++_ki) if (_tl.keys[_ki * 18] <= _time) _active = _ki;
                        _refs[_ri][2] = _active;
                    }
                }
                array_push(_mainline, {time:_time, bones:_bones, objects:_objects});
            }
            var _clip = {name:_src.name, duration:_src.duration, looping:_src.looping, timelines:_timelines,
                mainline:_mainline, events:variable_clone(_src.events)};
            array_push(_clips, _clip);
        }
        var _bone_lengths = [];
        for (var _i = 0; _i < array_length(_bone_defs); ++_i) array_push(_bone_lengths, _bone_defs[_i].length);
        return {name:self.name, bones:variable_clone(self.bones), bone_lengths:_bone_lengths,
            parts:variable_clone(self.parts), files:_files, character_maps:[], animations:_clips};
    };
}

/// @function SpriterPlayer(definition)
/// @description Creates independent playback and override state over a shared rig definition.
/// @param {Struct} definition Rig definition from a builder or generated entity factory.
/// @returns {Struct} A paused player at the first clip's initial pose; a non-struct argument raises an error.
function SpriterPlayer(_definition) constructor {
    if (!is_struct(_definition)) show_error("SpriterPlayer: expected a rig definition struct.", true);
    self.definition = _definition;
    self.animation = "";
    self.clip_index = -1;
    self.playing = false;
    self.speed = 1;
    self.time_ms = 0;
    self.clock_ms = 0;
    self.loop_override = undefined;
    self.root_x = 0;
    self.root_y = 0;
    self.root_angle = 0;
    self.root_scale_x = 1;
    self.root_scale_y = 1;
    self.root_alpha = 1;
    self.show_bones = false;
    self.bone_world = array_create(array_length(self.definition.bones) * 6, 0);
    self.bone_local = array_create(array_length(self.definition.bones) * 9, 0);
    self.object_world = array_create(array_length(self.definition.parts) * 6, 0);
    self.root_pose = [0, 0, 0, 1, 1, 1];
    self.sample = array_create(9, 0);
    self.object_pose = [];
    self.image_overrides = {};
    self.bone_overrides = {};
    self.part_overrides = {};
    self.active_maps = [];
    self.extra_events = {};
    self.listeners = {};
    self.listener_id = 0;
    self.dispatching = false;
    self.deferred = [];
    self.draw_debug = false;
    self._clip = function() { return self.clip_index < 0 ? undefined : self.definition.animations[self.clip_index]; };
    self._set_time = function() {
        var _clip = self._clip();
        if (is_undefined(_clip)) return;
        if (self.loop_override == false || (is_undefined(self.loop_override) && !_clip.looping)) {
            self.time_ms = clamp(self.clock_ms, 0, _clip.duration);
        } else {
            self.time_ms = ((self.clock_ms mod _clip.duration) + _clip.duration) mod _clip.duration;
        }
        spriter_evaluate(self);
    };
    /// @function SpriterPlayer.play
    /// @param {String} animation_name Clip to start.
    /// @param {Bool} restart Restart from the direction's start when true.
    /// @param {Bool|Undefined} loop_override Overrides the clip's SCML loop setting.
    /// @returns {Struct} This player; an unknown clip is logged and ignored.
    self.play = function(_name, _restart, _loop_override) {
        _restart = is_undefined(_restart) ? true : _restart;
        if (self.dispatching) { array_push(self.deferred, {kind:"play", name:_name, restart:_restart, loop:_loop_override}); return self; }
        var _index = -1;
        for (var _i = 0; _i < array_length(self.definition.animations); ++_i) if (self.definition.animations[_i].name == _name) { _index = _i; break; }
        if (_index < 0) { show_debug_message("SpriterPlayer: unknown animation '" + string(_name) + "'."); return self; }
        var _changed = _index != self.clip_index;
        self.clip_index = _index;
        self.animation = _name;
        self.loop_override = _loop_override;
        var _clip = self._clip();
        if (_restart || _changed) self.clock_ms = self.speed < 0 ? _clip.duration : 0;
        self.playing = true;
        self._set_time();
        if (_restart || _changed) spriter_dispatch(self, spriter_events_start(self));
        return self;
    };
    /// @function SpriterPlayer.pause
    /// @returns {Struct} This player, with the clock held at its current time.
    self.pause = function() {
        if (self.dispatching) { array_push(self.deferred, {kind:"pause"}); return self; }
        self.playing = false; return self;
    };
    /// @function SpriterPlayer.resume
    /// @returns {Struct} This player with playback enabled.
    self.resume = function() {
        if (self.dispatching) { array_push(self.deferred, {kind:"resume"}); return self; }
        self.playing = true; return self;
    };
    /// @function SpriterPlayer.stop
    /// @returns {Struct} This player paused at the clip's initial pose.
    self.stop = function() {
        if (self.dispatching) { array_push(self.deferred, {kind:"stop"}); return self; }
        self.playing = false; self.clock_ms = 0; self._set_time(); return self;
    };
    /// @function SpriterPlayer.set_speed
    /// @param {Real} multiplier Positive plays forward, negative plays backward, and zero holds time.
    /// @returns {Struct} This player.
    self.set_speed = function(_speed) {
        if (self.dispatching) { array_push(self.deferred, {kind:"speed", speed:_speed}); return self; }
        self.speed = _speed; return self;
    };
    /// @function SpriterPlayer.seek
    /// @param {Real} time_ms Target clip time in milliseconds; clamped to the clip duration.
    /// @param {Bool} emit_events Emit events crossed by this seek when true; defaults to false.
    /// @returns {Struct} This player.
    self.seek = function(_time_ms, _emit_events = false) {
        _emit_events = is_undefined(_emit_events) ? false : _emit_events;
        if (self.dispatching) { array_push(self.deferred, {kind:"seek", time:_time_ms, emit:_emit_events}); return self; }
        var _clip = self._clip();
        if (is_undefined(_clip)) return self;
        var _target = clamp(_time_ms, 0, _clip.duration);
        var _old = self.time_ms;
        self.clock_ms = _target;
        self._set_time();
        if (_emit_events && _target != _old) spriter_dispatch(self, spriter_events_at(self, _old, _target, _target >= _old ? 1 : -1));
        return self;
    };
    /// @function SpriterPlayer.on
    /// @param {String} event_name Event line or code-defined event name.
    /// @param {Function} callback Receives an event struct with animation, time_ms, cycle, direction, payload, and source.
    /// @returns {Real} Listener token accepted by off().
    self.on = function(_event_name, _callback) {
        if (!variable_struct_exists(self.listeners, _event_name)) variable_struct_set(self.listeners, _event_name, []);
        self.listener_id += 1;
        var _items = variable_struct_get(self.listeners, _event_name);
        array_push(_items, {id:self.listener_id, callback:_callback});
        variable_struct_set(self.listeners, _event_name, _items);
        return self.listener_id;
    };
    /// @function SpriterPlayer.off
    /// @param {String} event_name Listener event name.
    /// @param {Real} listener_id Token returned by on().
    /// @returns {Bool} True if the listener was removed.
    self.off = function(_event_name, _listener_id) {
        if (!variable_struct_exists(self.listeners, _event_name)) return false;
        var _items = variable_struct_get(self.listeners, _event_name), _new = [], _removed = false;
        for (var _i = 0; _i < array_length(_items); ++_i) {
            if (_items[_i].id == _listener_id) _removed = true;
            else array_push(_new, _items[_i]);
        }
        variable_struct_set(self.listeners, _event_name, _new);
        return _removed;
    };
    /// @function SpriterPlayer.add_event
    /// @param {String} animation_name Existing clip name.
    /// @param {String} event_name Name passed to listeners.
    /// @param {Real} time_ms Event time in milliseconds.
    /// @param {Any} payload Optional event payload.
    /// @returns {Struct} This player; an unknown clip simply receives an unused event entry.
    self.add_event = function(_animation_name, _event_name, _time_ms, _payload = undefined) {
        if (!variable_struct_exists(self.extra_events, _animation_name)) variable_struct_set(self.extra_events, _animation_name, []);
        var _items = variable_struct_get(self.extra_events, _animation_name);
        array_push(_items, {name:_event_name, time:_time_ms, payload:_payload, source:"runtime"});
        variable_struct_set(self.extra_events, _animation_name, _items);
        return self;
    };
    /// @function SpriterPlayer.add_key_event
    /// @param {String} animation_name Clip containing the timeline key.
    /// @param {String} event_name Name passed to listeners.
    /// @param {String} timeline_name Bone or part timeline name.
    /// @param {Real} key_index Zero-based key index after conversion.
    /// @param {Any} payload Optional event payload.
    /// @returns {Struct} This player; invalid clips, timelines, or keys are logged and ignored.
    self.add_key_event = function(_animation_name, _event_name, _timeline_name, _key_index, _payload = undefined) {
        for (var _ai = 0; _ai < array_length(self.definition.animations); ++_ai) {
            var _clip = self.definition.animations[_ai];
            if (_clip.name != _animation_name) continue;
            for (var _ti = 0; _ti < array_length(_clip.timelines); ++_ti) {
                var _tl = _clip.timelines[_ti];
                if (_tl.name == _timeline_name && _key_index >= 0 && _key_index < _tl.key_count) {
                    return self.add_event(_animation_name, _event_name, _tl.keys[_key_index * 18], _payload);
                }
            }
        }
        show_debug_message("SpriterPlayer: add_key_event could not find the requested key.");
        return self;
    };
    /// @function SpriterPlayer.apply_character_map
    /// @param {String} map_name Character map name from the entity.
    /// @param {Bool} reset Clear existing maps before applying this one.
    /// @returns {Struct} This player; unknown maps are logged and ignored.
    self.apply_character_map = function(_map_name, _reset = false) {
        _reset = is_undefined(_reset) ? false : _reset;
        if (_reset) self.active_maps = [];
        for (var _i = 0; _i < array_length(self.definition.character_maps); ++_i) if (self.definition.character_maps[_i].name == _map_name) {
            array_push(self.active_maps, self.definition.character_maps[_i]); self._set_time(); return self;
        }
        show_debug_message("SpriterPlayer: unknown character map '" + string(_map_name) + "'.");
        return self;
    };
    /// @function SpriterPlayer.clear_character_maps
    /// @returns {Struct} This player, using the authored images again.
    self.clear_character_maps = function() { self.active_maps = []; self._set_time(); return self; };
    /// @function SpriterPlayer.remove_character_map
    /// @param {String} map_name Map name to remove from this player's active stack.
    /// @returns {Struct} This player; removing an inactive map is harmless.
    self.remove_character_map = function(_map_name) {
        for (var _i = array_length(self.active_maps) - 1; _i >= 0; --_i)
            if (self.active_maps[_i].name == _map_name) array_delete(self.active_maps, _i, 1);
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.set_image
    /// @param {String} part_name Part/timeline name.
    /// @param {Asset.GMSprite} sprite Replacement sprite asset.
    /// @param {Real} subimage Sprite frame index, default 0.
    /// @param {Struct|Undefined} pivot_override Optional normalized pivot {x, y}; omitted values keep the authored pivot.
    /// @returns {Struct} This player; unknown parts are logged and ignored.
    self.set_image = function(_part_name, _sprite, _subimage = 0, _pivot_override = undefined) {
        var _part_index = spriter_find_name(self.definition.parts, _part_name);
        if (_part_index < 0) { show_debug_message("SpriterPlayer: unknown part '" + string(_part_name) + "'."); return self; }
        if (_sprite != -1 && !sprite_exists(_sprite)) { show_debug_message("SpriterPlayer: invalid replacement sprite."); return self; }
        _subimage = is_undefined(_subimage) ? 0 : _subimage;
        variable_struct_set(self.image_overrides, string(_part_index), {sprite:_sprite, sprite_name:_sprite == -1 ? "" : sprite_get_name(_sprite), subimage:_subimage,
            pivot_override:_pivot_override});
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.clear_image
    /// @param {String} part_name Part/timeline name.
    /// @returns {Struct} This player, with the SCML or character-map image restored.
    self.clear_image = function(_part_name) {
        var _part_index = spriter_find_name(self.definition.parts, _part_name);
        if (_part_index >= 0 && variable_struct_exists(self.image_overrides, string(_part_index))) variable_struct_remove(self.image_overrides, string(_part_index));
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.clear_images
    /// @returns {Struct} This player, with all explicit image overrides removed.
    self.clear_images = function() { self.image_overrides = {}; self._set_time(); return self; };
    /// @function SpriterPlayer.set_bone_transform
    /// @param {String} bone_name Bone name.
    /// @param {Struct} transform Full local transform: x, y, angle, scale_x, scale_y, alpha.
    /// @returns {Struct} This player; unknown bones are logged and ignored.
    self.set_bone_transform = function(_bone_name, _transform) {
        if (spriter_find_name(self.definition.bones, _bone_name) < 0) { show_debug_message("SpriterPlayer: unknown bone '" + string(_bone_name) + "'."); return self; }
        variable_struct_set(self.bone_overrides, _bone_name, _transform);
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.clear_bone_transform
    /// @param {String} bone_name Bone name.
    /// @returns {Struct} This player.
    self.clear_bone_transform = function(_bone_name) {
        if (variable_struct_exists(self.bone_overrides, _bone_name)) variable_struct_remove(self.bone_overrides, _bone_name);
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.set_part_transform
    /// @param {String} part_name Part/timeline name.
    /// @param {Struct} transform Full local transform: x, y, angle, scale_x, scale_y, alpha.
    /// @returns {Struct} This player; unknown parts are logged and ignored.
    self.set_part_transform = function(_part_name, _transform) {
        if (spriter_find_name(self.definition.parts, _part_name) < 0) { show_debug_message("SpriterPlayer: unknown part '" + string(_part_name) + "'."); return self; }
        variable_struct_set(self.part_overrides, _part_name, _transform);
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.clear_part_transform
    /// @param {String} part_name Part/timeline name.
    /// @returns {Struct} This player.
    self.clear_part_transform = function(_part_name) {
        if (variable_struct_exists(self.part_overrides, _part_name)) variable_struct_remove(self.part_overrides, _part_name);
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.clear_transforms
    /// @returns {Struct} This player with authored local bone and part transforms restored.
    self.clear_transforms = function() {
        self.bone_overrides = {}; self.part_overrides = {}; self._set_time(); return self;
    };
    /// @function SpriterPlayer.set_transform
    /// @param {Real} x GameMaker room x coordinate used by draw().
    /// @param {Real} y GameMaker room y coordinate used by draw().
    /// @param {Real} angle Root rotation in degrees counter-clockwise.
    /// @param {Real} scale_x Root horizontal scale; negative values mirror.
    /// @param {Real} scale_y Root vertical scale; negative values mirror.
    /// @param {Real} alpha Root opacity from 0 to 1.
    /// @returns {Struct} This player.
    self.set_transform = function(_x, _y, _angle = 0, _scale_x = 1, _scale_y = 1, _alpha = 1) {
        self.root_x = _x; self.root_y = _y;
        self.root_angle = is_undefined(_angle) ? 0 : _angle;
        self.root_scale_x = is_undefined(_scale_x) ? 1 : _scale_x;
        self.root_scale_y = is_undefined(_scale_y) ? 1 : _scale_y;
        self.root_alpha = is_undefined(_alpha) ? 1 : _alpha;
        self._set_time(); return self;
    };
    /// @function SpriterPlayer.get_bone_world
    /// @param {String} bone_name Bone name.
    /// @returns {Struct|Undefined} Current room-space position, rotation, scale, and alpha; undefined for an unknown bone.
    self.get_bone_world = function(_bone_name) {
        var _index = spriter_find_name(self.definition.bones, _bone_name);
        if (_index < 0) return undefined;
        var _o = _index * 6;
        return {x:self.root_x + self.bone_world[_o], y:self.root_y - self.bone_world[_o + 1],
            angle:self.bone_world[_o + 2], scale_x:self.bone_world[_o + 3], scale_y:self.bone_world[_o + 4],
            alpha:self.bone_world[_o + 5]};
    };
    /// @function SpriterPlayer.get_part_world
    /// @param {String} part_name Attachment/timeline name.
    /// @returns {Struct|Undefined} Room-space transform, pivots, and image details, or undefined for an inactive/unknown part.
    self.get_part_world = function(_part_name) {
        for (var _i = 0; _i < array_length(self.object_pose); ++_i) {
            var _pose = self.object_pose[_i];
            if (_pose.active && _pose.part_name == _part_name) {
                var _result = variable_clone(_pose);
                _result.x += self.root_x; _result.y = self.root_y - _result.y;
                return _result;
            }
        }
        return undefined;
    };
    /// @function SpriterPlayer.update
    /// @param {Real} delta_seconds Elapsed seconds since the previous update; playback speed scales this value.
    /// @returns {Struct} This player after advancing and dispatching crossed events.
    self.update = function(_delta_seconds) {
        if (!self.playing || self.speed == 0 || _delta_seconds <= 0) return self;
        var _clip = self._clip();
        if (is_undefined(_clip)) return self;
        var _old_clock = self.clock_ms;
        var _old_time = self.time_ms;
        self.clock_ms += _delta_seconds * 1000 * self.speed;
        var _loop = self.loop_override == true || (is_undefined(self.loop_override) && _clip.looping);
        var _events = [];
        if (_loop) {
            _events = spriter_events_unwrapped(self, _old_clock, self.clock_ms);
        } else {
            self.clock_ms = clamp(self.clock_ms, 0, _clip.duration);
            var _new_time = self.clock_ms;
            if (_new_time != _old_time) _events = spriter_events_at(self, _old_time, _new_time, _new_time > _old_time ? 1 : -1);
        }
        self._set_time();
        if (!_loop && ((self.speed > 0 && self.clock_ms >= _clip.duration) || (self.speed < 0 && self.clock_ms <= 0))) self.playing = false;
        if (array_length(_events) > 0) spriter_dispatch(self, _events);
        return self;
    };
    /// @function SpriterPlayer.draw
    /// @param {Real} x GameMaker room x coordinate for the rig origin.
    /// @param {Real} y GameMaker room y coordinate for the rig origin.
    /// @returns {Struct} This player after drawing all active image parts in z order.
    self.draw = function(_x, _y) {
        self.root_x = _x; self.root_y = _y; self._set_time();
        for (var _i = 0; _i < array_length(self.object_pose); ++_i) {
            var _o = self.object_pose[_i];
            if (!_o.active || _o.sprite < 0 || _o.alpha <= 0) continue;
            var _w = _o.width, _h = _o.height;
            var _px = _o.pivot_x * _w, _py = (1 - _o.pivot_y) * _h;
            var _sx = _o.scale_x, _sy = _o.scale_y;
            var _angle = _o.angle;
            var _c = dcos(_angle), _s = dsin(_angle);
            var _dx = (sprite_get_xoffset(_o.sprite) - _px) * _sx;
            var _dy = (_py - sprite_get_yoffset(_o.sprite)) * _sy;
            var _draw_x = _x + _o.x + _c * _dx - _s * _dy;
            var _draw_y = _y - (_o.y + _s * _dx + _c * _dy);
            var _subimage = _o.subimage;
            draw_sprite_ext(_o.sprite, _subimage, _draw_x, _draw_y, _sx, _sy, _angle, c_white, clamp(_o.alpha, 0, 1));
        }
        if (self.show_bones) self.draw_bones(_x, _y);
        return self;
    };
    /// @function SpriterPlayer.draw_bones
    /// @param {Real} x GameMaker room x coordinate for the rig origin.
    /// @param {Real} y GameMaker room y coordinate for the rig origin.
    /// @returns {Struct} This player after drawing bone debug lines.
    self.draw_bones = function(_x, _y) {
        draw_set_color(make_color_rgb(80, 240, 150));
        var _defs = is_undefined(self.definition.bone_lengths) ? [] : self.definition.bone_lengths;
        for (var _i = 0; _i < array_length(self.definition.bones); ++_i) {
            var _o = _i * 6, _x1 = _x + self.bone_world[_o];
            var _y1 = _y - self.bone_world[_o + 1];
            var _length = _i < array_length(_defs) ? _defs[_i] : 12;
            var _a = self.bone_world[_o + 2];
            draw_line(_x1, _y1, _x1 + dcos(_a) * _length * self.bone_world[_o + 3],
                _y1 - dsin(_a) * _length * self.bone_world[_o + 3]);
            draw_circle(_x1, _y1, 2, false);
        }
        draw_set_color(c_white);
    };
    if (array_length(self.definition.animations) > 0) {
        self.clip_index = 0; self.animation = self.definition.animations[0].name; self._set_time();
    }
}

/// @function spriter_evaluate(player)
/// @description Updates reusable world-pose and draw-part buffers for the player's current clip and time.
function spriter_evaluate(_player) {
    var _clip = _player.clip_index < 0 ? undefined : _player.definition.animations[_player.clip_index];
    if (is_undefined(_clip) || array_length(_clip.mainline) == 0) return;
    var _main_index = spriter_mainline_index(_clip, _player.time_ms);
    var _main = _clip.mainline[_main_index], _sample_time = _player.time_ms;
    var _looping = _player.loop_override == true || (is_undefined(_player.loop_override) && _clip.looping);
    if (variable_struct_exists(_main,"curve") && _main.curve[0] != 1) {
        var _end = _main_index + 1 < array_length(_clip.mainline) ? _clip.mainline[_main_index + 1].time : _clip.duration;
        if (_end > _main.time) {
            var _curve = _main.curve;
            _sample_time = spriter_lerp(_main.time,_end,spriter_curve((_player.time_ms-_main.time)/(_end-_main.time),
                _curve[0],_curve[1],_curve[2],_curve[3],_curve[4]));
        }
    }
    var _root = _player.root_pose;
    _root[2] = _player.root_angle; _root[3] = _player.root_scale_x; _root[4] = _player.root_scale_y; _root[5] = _player.root_alpha;
    for (var _b = 0; _b < array_length(_player.definition.bones); ++_b) {
        var _o = _b * 6;
        _player.bone_world[_o] = 0; _player.bone_world[_o + 1] = 0; _player.bone_world[_o + 2] = 0;
        _player.bone_world[_o + 3] = 1; _player.bone_world[_o + 4] = 1; _player.bone_world[_o + 5] = 1;
    }
    for (var _i = 0; _i < array_length(_main.bones); ++_i) {
        var _ref = _main.bones[_i], _bone = _ref[0], _timeline = _ref[1], _key = _ref[2], _parent = _ref[3];
        var _li = _bone * 9;
        var _looping = _player.loop_override == true || (is_undefined(_player.loop_override) && _clip.looping);
        spriter_sample_timeline(_clip, _timeline, _key, _sample_time, _looping, _player.bone_local, _li, _player.definition.files);
        if (variable_struct_exists(_player.bone_overrides, _player.definition.bones[_bone])) {
            var _override = variable_struct_get(_player.bone_overrides, _player.definition.bones[_bone]);
            _player.bone_local[_li] = _override.x; _player.bone_local[_li + 1] = _override.y;
            _player.bone_local[_li + 2] = _override.angle; _player.bone_local[_li + 3] = _override.scale_x;
            _player.bone_local[_li + 4] = _override.scale_y; _player.bone_local[_li + 5] = _override.alpha;
        }
        if (_parent < 0) spriter_compose(_player.bone_world, _bone * 6, _root, 0, _player.bone_local, _li);
        else spriter_compose(_player.bone_world, _bone * 6, _player.bone_world, _parent * 6, _player.bone_local, _li);
    }
    var _required = array_length(_main.objects);
    while (array_length(_player.object_pose) < _required) array_push(_player.object_pose, {active:false});
    while (array_length(_player.object_world) < _required * 6) array_push(_player.object_world, 0);
    for (var _i = 0; _i < array_length(_player.object_pose); ++_i) _player.object_pose[_i].active = false;
    for (var _i = 0; _i < _required; ++_i) {
        var _ref = _main.objects[_i], _part = _ref[0], _timeline = _ref[1], _key = _ref[2], _parent = _ref[3], _z = _ref[4];
        var _looping = _player.loop_override == true || (is_undefined(_player.loop_override) && _clip.looping);
        spriter_sample_timeline(_clip, _timeline, _key, _sample_time, _looping, _player.sample, 0, _player.definition.files);
        var _local = _player.sample;
        if (variable_struct_exists(_player.part_overrides, _player.definition.parts[_part])) {
            var _override = variable_struct_get(_player.part_overrides, _player.definition.parts[_part]);
            _local[0] += _override.x; _local[1] += _override.y; _local[2] += _override.angle;
            _local[3] *= _override.scale_x; _local[4] *= _override.scale_y; _local[5] *= _override.alpha;
            if (variable_struct_exists(_override,"pivot_x")) _local[6] = _override.pivot_x;
            if (variable_struct_exists(_override,"pivot_y")) _local[7] = _override.pivot_y;
        }
        var _pose = _player.object_pose[_i], _world_offset = _i * 6;
        if (_parent < 0) spriter_compose(_player.object_world, _world_offset, _root, 0, _local, 0);
        else spriter_compose(_player.object_world, _world_offset, _player.bone_world, _parent * 6, _local, 0);
        var _file_index = _local[8];
        if (_file_index < 0 || _file_index >= array_length(_player.definition.files)) { _pose.active = false; continue; }
        var _authored_file = _player.definition.files[_file_index];
        var _has_override = variable_struct_exists(_player.image_overrides, string(_part));
        for (var _mi = 0; _mi < array_length(_player.active_maps); ++_mi) {
            var _maps = _player.active_maps[_mi].maps;
            for (var _map_i = 0; _map_i < array_length(_maps); ++_map_i) if (_maps[_map_i].source == _file_index) {
                _file_index = _maps[_map_i].target; break;
            }
        }
        var _hidden = _file_index < 0 || _file_index >= array_length(_player.definition.files);
        if (_hidden && !_has_override) { _pose.active = false; continue; }
        var _file = _hidden ? _authored_file : _player.definition.files[_file_index];
        var _sprite = _file.sprite, _sprite_name = _file.sprite_name, _subimage = 0;
        var _pivot_file = _has_override ? _authored_file : _file;
        var _pivot_x = _local[6] < -1000 ? _pivot_file.pivot_x : _local[6];
        var _pivot_y = _local[7] < -1000 ? _pivot_file.pivot_y : _local[7];
        if (_has_override) {
            var _img = variable_struct_get(_player.image_overrides, string(_part));
            _sprite = _img.sprite; _sprite_name = _img.sprite_name; _subimage = _img.subimage;
            if (is_struct(_img.pivot_override)) { _pivot_x = _img.pivot_override.x; _pivot_y = _img.pivot_override.y; }
        }
        if (_sprite < 0) { _pose.active = false; continue; }
        _pose.active = true; _pose.part = _part; _pose.part_name = _player.definition.parts[_part];
        _pose.file_index = _file_index; _pose.sprite = _sprite; _pose.sprite_name = _sprite_name; _pose.subimage = _subimage; _pose.z = _z;
        _pose.x = _player.object_world[_world_offset]; _pose.y = _player.object_world[_world_offset + 1];
        _pose.angle = _player.object_world[_world_offset + 2]; _pose.scale_x = _player.object_world[_world_offset + 3];
        _pose.scale_y = _player.object_world[_world_offset + 4]; _pose.alpha = _player.object_world[_world_offset + 5];
        _pose.pivot_x = _pivot_x; _pose.pivot_y = _pivot_y;
        _pose.width = sprite_get_width(_sprite); _pose.height = sprite_get_height(_sprite);
        _player.object_pose[_i] = _pose;
    }
}

/// @function spriter_events_for_clip(player)
/// @description Returns the combined SCML and code-defined event list for the current clip.
function spriter_events_for_clip(_player) {
    var _clip = _player._clip(), _events = [];
    if (is_undefined(_clip)) return _events;
    for (var _i = 0; _i < array_length(_clip.events); ++_i) array_push(_events, _clip.events[_i]);
    if (variable_struct_exists(_player.extra_events, _clip.name)) {
        var _extra = variable_struct_get(_player.extra_events, _clip.name);
        for (var _i = 0; _i < array_length(_extra); ++_i) array_push(_events, _extra[_i]);
    }
    return _events;
}

/// @function spriter_events_at(player, from_ms, to_ms, direction)
/// @description Builds event payloads crossed between local times for seek and non-looping playback.
function spriter_events_at(_player, _from, _to, _direction) {
    var _source = spriter_events_for_clip(_player), _result = [];
    for (var _i = 0; _i < array_length(_source); ++_i) {
        var _e = _source[_i], _crossed = _direction > 0 ? (_e.time > _from && _e.time <= _to) : (_e.time >= _to && _e.time < _from);
        if (_crossed) array_push(_result, {name:_e.name, animation:_player.animation, time_ms:_e.time,
            cycle:0, direction:_direction, payload:_e.payload, source:_e.source});
    }
    array_sort(_result, function(_a, _b) { return (_a.time_ms - _b.time_ms) * _a.direction; });
    return _result;
}

/// @function spriter_events_start(player)
/// @description Creates the time-zero event batch emitted on explicit animation start.
function spriter_events_start(_player) {
    var _source = spriter_events_for_clip(_player), _result = [];
    for (var _i = 0; _i < array_length(_source); ++_i) if (_source[_i].time == 0) {
        array_push(_result, {name:_source[_i].name, animation:_player.animation, time_ms:0,
            cycle:0, direction:_player.speed < 0 ? -1 : 1, payload:_source[_i].payload, source:_source[_i].source});
    }
    return _result;
}

/// @function spriter_events_unwrapped(player, from_clock, to_clock)
/// @description Enumerates all event crossings, including every loop, in chronological playback order.
function spriter_events_unwrapped(_player, _from, _to) {
    var _source = spriter_events_for_clip(_player), _result = [], _clip = _player._clip();
    var _duration = _clip.duration, _direction = _to >= _from ? 1 : -1;
    var _low = min(_from, _to), _high = max(_from, _to);
    for (var _i = 0; _i < array_length(_source); ++_i) {
        var _e = _source[_i];
        var _first = floor((_low - _e.time) / _duration) - 1;
        var _last = ceil((_high - _e.time) / _duration) + 1;
        for (var _cycle = _first; _cycle <= _last; ++_cycle) {
            var _at = _cycle * _duration + _e.time;
            var _crossed = _direction > 0 ? (_at > _from && _at <= _to) : (_at >= _to && _at < _from);
            if (_crossed) array_push(_result, {name:_e.name, animation:_player.animation, time_ms:_e.time,
                cycle:_cycle, direction:_direction, payload:_e.payload, source:_e.source, _at:_at});
        }
    }
    array_sort(_result, function(_a, _b) {
        if (_a._at != _b._at) return (_a._at - _b._at) * _a.direction;
        if (_a.time_ms != _b.time_ms) return (_a.time_ms - _b.time_ms) * -_a.direction;
        return 0;
    });
    return _result;
}

/// @function spriter_dispatch(player, events)
/// @description Invokes event listeners from a stable event batch and applies callback playback commands afterward.
function spriter_dispatch(_player, _events) {
    if (array_length(_events) == 0) return;
    _player.dispatching = true;
    for (var _ei = 0; _ei < array_length(_events); ++_ei) {
        var _event = _events[_ei];
        if (!variable_struct_exists(_player.listeners, _event.name)) continue;
        var _items = variable_struct_get(_player.listeners, _event.name);
        var _snapshot = array_create(array_length(_items)); array_copy(_snapshot, 0, _items, 0, array_length(_items));
        for (var _li = 0; _li < array_length(_snapshot); ++_li) _snapshot[_li].callback(_event);
    }
    _player.dispatching = false;
    var _commands = _player.deferred; _player.deferred = [];
    for (var _ci = 0; _ci < array_length(_commands); ++_ci) {
        var _c = _commands[_ci];
        if (_c.kind == "play") _player.play(_c.name, _c.restart, _c.loop);
        else if (_c.kind == "pause") _player.pause();
        else if (_c.kind == "resume") _player.resume();
        else if (_c.kind == "stop") _player.stop();
        else if (_c.kind == "speed") _player.set_speed(_c.speed);
        else if (_c.kind == "seek") _player.seek(_c.time, _c.emit);
    }
}
