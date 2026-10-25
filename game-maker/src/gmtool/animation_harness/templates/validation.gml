/// @description Deterministic checks executed inside the actual GameMaker VM.
function spriter_demo_run_checks(_library) {
    var _s = {failures:0, events:[], target:undefined};
    _s.check = method(_s, function(_ok, _label) {
        show_debug_message("[Spriter check] " + (_ok ? "PASS " : "FAIL ") + _label);
        if (!_ok) failures += 1;
    });
    _s.record = method(_s, function(_event) { array_push(events, _event.name); });
    _s.retarget = method(_s, function(_event) { array_push(events, _event.name); target.play("die"); });
    _s.check(array_length(_library.names()) == 15, "15 entities registered");
    var _dome = _library.entity("dome-alone"), _sprite = _dome.files[0].sprite;
    _s.check(array_length(_dome.animations) == 4, "four clips per zombie");
    _s.check(sprite_exists(_sprite), "direct sprite references resolve");
    var _expected = [0,0.25,0.0625,0.015625,0.00390625,0.0009765625,0.12916193];
    for (var _i = 0; _i < 7; ++_i) {
        var _v = _i == 6 ? spriter_curve(0.25,6,0.42,0,0.58,1) : spriter_curve(0.25,_i,0,0,0,0);
        _s.check(abs(_v - _expected[_i]) < 0.0001, "curve " + string(_i));
    }
    var _b = new SpriterRigBuilder("runtime-fixture");
    _b.add_bone("root", undefined, 20).add_bone("child", "root", 10);
    _b.add_part("coat", "child", _sprite, sprite_get_name(_sprite), 0.5, 0.5, 4);
    _b.add_animation("walk",1000,false).add_animation("die",1000,false);
    for (var _i = 0; _i < 3; ++_i) _b.add_key("walk","bone","root",_i * 500,
        {x:_i * 100,y:0,angle:30,scale_x:-2,scale_y:3,alpha:0.8});
    _b.add_key("walk","bone","child",0,{x:10,y:0,angle:40,scale_x:1,scale_y:1,alpha:0.5});
    _b.add_key("walk","part","coat",0,{x:2,y:3,angle:0,scale_x:1,scale_y:1,alpha:0.5,pivot_x:0.1,pivot_y:0.2});
    _b.add_key("walk","part","coat",1000,{x:2,y:3,angle:0,scale_x:1,scale_y:1,alpha:0.5,pivot_x:0.9,pivot_y:0.8});
    var _def = _b.build(), _p = new SpriterPlayer(_def);
    _p.play("walk").seek(750);
    _s.check(abs(_p.get_bone_world("root").x - 150) < 0.001, "builder retains and samples all keys");
    var _child = _p.get_bone_world("child");
    _s.check(abs(_child.angle + 10) < 0.001 && abs(_child.x - (150 - 20 * dcos(30))) < 0.001,
        "mirrored parent rotation and component transforms");
    var _changed = variable_clone(_def);
    for (var _i = 1; _i < array_length(_changed.animations[0].mainline); ++_i)
        _changed.animations[0].mainline[_i].objects[0][3] = 0;
    var _attached = new SpriterPlayer(_changed); _attached.play("walk").seek(750);
    _s.check(abs(_attached.get_part_world("coat").x - (150 - 4 * dcos(30) - 9 * dsin(30))) < 0.001,
        "mainline attachment changes take effect at their keys");
    _changed = variable_clone(_def); _changed.animations[0].mainline[0].curve = [2,0,0,0,0];
    _attached = new SpriterPlayer(_changed); _attached.play("walk").seek(250);
    _s.check(abs(_attached.get_bone_world("root").x - 25) < 0.001, "mainline time easing");
    var _coat = _p.get_part_world("coat");
    _s.check(abs(_coat.alpha - 0.2) < 0.001 && abs(_coat.pivot_x - 0.7) < 0.001 && abs(_coat.pivot_y - 0.65) < 0.001,
        "inherited alpha and interpolated pivots");
    _p.set_bone_transform("child",{x:0,y:0,angle:0,scale_x:1,scale_y:1,alpha:1});
    _s.check(abs(_p.get_bone_world("child").x - 150) < 0.001, "local bone override");
    _p.clear_transforms();
    _s.check(abs(_p.get_bone_world("child").angle + 10) < 0.001, "clearing transforms restores authored pose");
    _def.character_maps = [{name:"hidden",maps:[{source:0,target:-1}]}];
    _p.apply_character_map("hidden");
    _s.check(is_undefined(_p.get_part_world("coat")), "character map hides image");
    _p.set_image("coat",_dome.files[array_length(_dome.files)-1].sprite,0,{x:0.25,y:0.75});
    _s.check(!is_undefined(_p.get_part_world("coat")) && _p.get_part_world("coat").pivot_x == 0.25,
        "explicit replacement overrides hidden character-map entry");
    _p.clear_images(); _p.remove_character_map("hidden");
    _s.check(!is_undefined(_p.get_part_world("coat")), "map removal restores image");
    _p.play("walk").update(4);
    _s.check(_p.time_ms == 1000 && !_p.playing && abs(_p.get_bone_world("root").x - 200) < 0.001,
        "non-looping final pose clamps and holds");
    _p.add_event("walk","zero",0).add_event("walk","quarter",250).add_event("walk","three",750);
    _p.on("zero",_s.record); _p.on("quarter",_s.record); _p.on("three",_s.record);
    _p.play("walk",true,true).update(2.3);
    _s.check(array_length(_s.events) == 8, "time-zero start and multiple-loop crossings");
    var _before = array_length(_s.events); _p.seek(900);
    _s.check(array_length(_s.events) == _before, "seek is silent by default");
    _s.events = []; _p.set_speed(-1).update(2);
    _s.check(string(_s.events) == string(["three","quarter","zero","three","quarter","zero"]),
        "reverse events preserve traversal order across loops");
    _p.pause(); var _held = _p.time_ms; _p.update(1);
    _s.check(_p.time_ms == _held, "pause holds time");
    _p.resume().set_speed(0).update(1); _s.check(_p.time_ms == _held, "zero speed holds time");
    _p.set_speed(1).seek(100).update(0.1); _s.check(abs(_p.time_ms - 200) < 0.001, "resume and speed control");
    _p.stop(); _s.check(!_p.playing && _p.time_ms == 0, "stop restores initial pose and pauses");
    var _q = new SpriterPlayer(_def); _s.target = _q; _s.events = [];
    _q.add_event("walk","quarter",250).add_event("walk","three",750);
    _q.on("quarter",_s.retarget); _q.on("three",_s.record); _q.play("walk").update(2);
    _s.check(_q.animation == "die" && _q.playing && array_length(_s.events) == 2,
        "callback playback changes wait for the complete event batch");
    var _first = new SpriterPlayer(_def), _second = new SpriterPlayer(_def);
    _first.play("walk"); _second.play("walk"); _first.update(0.1);
    _first.set_image("coat",_sprite,0,{x:0,y:0});
    _s.check(_first.time_ms == 100 && _second.time_ms == 0 && _second.get_part_world("coat").pivot_x == 0.1,
        "independent player clocks and image overrides");
    _s.events = []; _second.add_key_event("walk","key", "root",1); _second.on("key",_s.record); _second.update(0.5);
    _s.check(array_length(_s.events) == 1, "events may attach to existing timeline keys");
    show_debug_message("[Spriter check] " + (_s.failures == 0 ? "ALL PASS" : "FAILURES=" + string(_s.failures)));
    return _s.failures;
}

/// @description Emits VM-computed poses for comparison with the original SCML evaluator.
function spriter_demo_export_poses(_library) {
    var _names = _library.names();
    for (var _ei = 0; _ei < array_length(_names); ++_ei) {
        var _def = _library.entity(_names[_ei]), _p = new SpriterPlayer(_def);
        for (var _ai = 0; _ai < array_length(_def.animations); ++_ai) {
            var _clip = _def.animations[_ai]; _p.play(_clip.name);
            for (var _fi = 0; _fi <= 16; ++_fi) {
                var _time = _clip.duration * _fi / 16; _p.seek(_time); var _parts = [];
                for (var _pi = 0; _pi < array_length(_p.object_pose); ++_pi) {
                    var _o = _p.object_pose[_pi];
                    if (_o.active) array_push(_parts,{name:_o.part_name,x:_o.x,y:_o.y,angle:_o.angle,
                        scale_x:_o.scale_x,scale_y:_o.scale_y,alpha:_o.alpha,pivot_x:_o.pivot_x,pivot_y:_o.pivot_y,
                        z:_o.z,path:_def.files[_o.file_index].path});
                }
                show_debug_message("[Spriter pose] " + json_stringify({entity:_def.name,animation:_clip.name,
                    time_ms:_time,local_time:_p.time_ms,bone_names:_def.bones,bones:_p.bone_world,parts:_parts}));
            }
        }
    }
}

/// @description Exports all 60 representative frames from the actual drawing path.
function spriter_demo_render_checks(_library) {
    var _cases = [{name:"dome-alone",camera:[100.42282145071503,161.31563462754514],scale:0.486072449573766},{name:"Grumble-Mulch",camera:[109.02837654257092,172.8722223237327],scale:0.5082700222505482},{name:"Professor-Cerebrisk",camera:[102.56688687005956,149.10030126709896],scale:0.4225861441538298},{name:"Sir-Tusk-A-Lot",camera:[93.85517567728978,166.28288693174554],scale:0.4678489509563165},{name:"Sub-Zero-Self-Esteem",camera:[113.95160185892159,164.17396698971766],scale:0.4482239948256403},{name:"Newly-Turned",camera:[118.850967278626,190.00002264864798],scale:1.0},{name:"Bog-Wader",camera:[126.21958127621804,189.99997120930402],scale:1.0},{name:"Sandblasted",camera:[131.2893966812015,190.000075740744],scale:1.0},{name:"Rootbound",camera:[119.192462987424,189.999914954144],scale:1.0},{name:"Shroud",camera:[122.50870977341873,191.0091231999907],scale:1.0},{name:"Harvester",camera:[122.15256004316001,189.999929150496],scale:1.0},{name:"Foreman-Rustlung",camera:[128.002829745523,190.00000200565],scale:1.0},{name:"Orchid-Widow",camera:[124.80499706084755,189.99993948451942],scale:1.0},{name:"Bellringer",camera:[127.99710508372,191.729351610329],scale:1.0},{name:"Gardener",camera:[123.963872300747,196.5785275],scale:1.0}];
    var _surface = surface_create(240,200);
    var _old_filter = gpu_get_texfilter();
    gpu_set_texfilter(true);
    for (var _i = 0; _i < array_length(_cases); ++_i) {
        var _case = _cases[_i], _def = _library.entity(_case.name), _p = new SpriterPlayer(_def);
        _p.set_transform(0,0,0,_case.scale,_case.scale,1);
        for (var _ai = 0; _ai < array_length(_def.animations); ++_ai) {
            var _clip = _def.animations[_ai], _frame = _clip.name == "die" ? 10 : 4;
            _p.play(_clip.name).seek(_clip.duration * _frame / 16);
            surface_set_target(_surface);
            draw_clear_alpha(c_black,0);
            gpu_set_blendmode_ext_sepalpha(bm_src_alpha,bm_inv_src_alpha,bm_one,bm_inv_src_alpha);
            _p.draw(_case.camera[0],_case.camera[1]);
            surface_reset_target(); gpu_set_blendmode(bm_normal);
            var _file = "spriter-parity-" + _case.name + "-" + _clip.name + ".png";
            surface_save(_surface,_file);
            show_debug_message("[Spriter render] " + json_stringify({entity:_case.name,animation:_clip.name,
                frame:_frame,file:game_save_id + _file}));
        }
    }
    var _case = _cases[0], _p = new SpriterPlayer(_library.entity(_case.name));
    _p.set_transform(0,0,0,_case.scale,_case.scale,1).play("walk").seek(250);
    var _part = variable_clone(_p.object_pose[0]), _original = _part.sprite;
    var _copy = sprite_duplicate(_original); sprite_set_offset(_copy,37,19);
    var _w = sprite_get_width(_original), _h = sprite_get_height(_original);
    var _padding = surface_create(_w+20,_h+20);
    surface_set_target(_padding); draw_clear_alpha(c_black,0);
    gpu_set_blendmode_ext_sepalpha(bm_src_alpha,bm_inv_src_alpha,bm_one,bm_inv_src_alpha);
    draw_sprite(_original,0,10+sprite_get_xoffset(_original),10+sprite_get_yoffset(_original));
    surface_reset_target(); gpu_set_blendmode(bm_normal);
    var _larger = sprite_create_from_surface(_padding,0,0,_w+20,_h+20,false,false,37,19);
    surface_free(_padding);
    var _paths = [];
    for (var _fixture = 0; _fixture < 3; ++_fixture) {
        if (_fixture == 1) _p.set_image(_part.part_name,_copy);
        if (_fixture == 2) _p.set_image(_part.part_name,_larger,0,
            {x:(10+_part.pivot_x*_w)/(_w+20),y:1-(10+(1-_part.pivot_y)*_h)/(_h+20)});
        surface_set_target(_surface); draw_clear_alpha(c_black,0);
        gpu_set_blendmode_ext_sepalpha(bm_src_alpha,bm_inv_src_alpha,bm_one,bm_inv_src_alpha);
        _p.draw(_case.camera[0],_case.camera[1]);
        surface_reset_target(); gpu_set_blendmode(bm_normal);
        var _file = "spriter-image-fixture-" + string(_fixture) + ".png";
        surface_save(_surface,_file); array_push(_paths,game_save_id+_file);
    }
    show_debug_message("[Spriter image fixture] " + json_stringify({files:_paths}));
    sprite_delete(_copy); sprite_delete(_larger);
    gpu_set_texfilter(_old_filter); surface_free(_surface);
    show_debug_message("[Spriter check] RENDER COMPLETE");
}
