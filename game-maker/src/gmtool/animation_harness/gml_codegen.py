"""Generate the single GML factory without global runtime helpers or captured locals."""
from __future__ import annotations
import copy
import hashlib
import json
import re
from pathlib import Path
from . import gml_utils as converter

TEMPLATES = Path(__file__).parent / 'templates'
SCRIPT = 'scr_scml_spriter_interface_system'
SCRIPT_DIR = f'scripts/{SCRIPT}'
GUIDE = f'{SCRIPT_DIR}/Spriter_Interface_System.md'


def functions(source: str):
    """Read top-level GML function bodies, respecting strings and comments."""
    result = []
    for match in re.finditer(r'^function (\w+)\(([^\n]*)\)( constructor)?\s*\{', source, re.M):
        start, pos, depth, state = match.end(), match.end(), 1, ''
        while depth and pos < len(source):
            char, following = source[pos], source[pos:pos+2]
            if state in ('"', "'"):
                if char == '\\': pos += 2; continue
                if char == state: state = ''
            elif state == '//':
                if char == '\n': state = ''
            elif state == '/*':
                if following == '*/': state = ''; pos += 2; continue
            elif following in ('//','/*'): state = following; pos += 2; continue
            elif char in ('"', "'"): state = char
            elif char == '{': depth += 1
            elif char == '}': depth -= 1
            pos += 1
        if depth: raise ValueError(f'Unclosed GML function {match[1]}')
        result.append((match[1],match[2],bool(match[3]),source[start:pos-1]))
    return result


def rewrite_runtime(body, owner='self'):
    body = re.sub(r'\b(spriter_\w+)\s*\(', lambda m:f'{owner}._{m[1]}(',body)
    return body


def literal(value):
    if isinstance(value,dict):
        fields=[]
        for key,item in value.items():
            if key == 'sprite':
                if not re.fullmatch(r'[A-Za-z_]\w*',item): raise ValueError('Invalid sprite identifier in cache')
                encoded=item
            else: encoded=literal(item)
            fields.append(f'{key}:{encoded}')
        return '{'+','.join(fields)+'}'
    if isinstance(value,list): return '['+','.join(map(literal,value))+']'
    return converter.gml_value(value)


def json_method(name,value,tail='return _data;'):
    """Materialize immutable definition data once, without thousands of nested GML initializer functions.

    Large nested GML struct literals inside one factory compile on 2024.14 but crash its VM
    during Script_Prepare. Embedded normalized JSON avoids that linker path. It is decoded
    only on first entity lookup, never during playback updates and never from external files.
    """
    data=json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False)
    lines=[f'    _sys.{name}=method(_sys,function() {{ var _json="";']
    for index in range(0,len(data),16000):lines.append('        _json += '+converter.gml_string(data[index:index+16000])+';')
    lines.append('        var _data=json_parse(_json); '+tail+' });')
    return '\n'.join(lines)


def system_source(collections):
    lines=['/// @function SpriterInterfaceSystem()',
           '/// @description Creates an independent named-player system. Times are milliseconds; update uses seconds.',
           '/// @returns {Struct} System exposing collections, players, playback, events, and rig construction.',
           'function SpriterInterfaceSystem() {', '    var _sys = {};']
    for name,args,constructor,body in functions((TEMPLATES/'runtime.gml').read_text(encoding='utf-8-sig')):
        if constructor:
            params=(args+', ' if args else '')+'_owner'
            body='\n    self.system = _owner;'+rewrite_runtime(body,'self.system')
            lines.append(f'    _sys._{name} = method(_sys,function({params}) {{ var _result = {{}}; with (_result) {{{body}\n    }} return _result; }});')
        else:
            lines.append(f'    _sys._{name} = method(_sys,function({args}) {{{rewrite_runtime(body)}\n    }});')
    lines.extend(['    _sys._players = {};','    _sys._imports = {};','    _sys._libraries = {};'])
    for collection in collections:
        key,identity,model=collection['key'],collection['id'],collection['model']
        registrations=[]
        for entity in model['entities']:
            token=identity[:8]+'_'+hashlib.sha256(entity['name'].encode()).hexdigest()[:10]
            clip_calls=[]
            for index,clip in enumerate(entity['animations']):
                func=f'_data_clip_{token}_{index}'
                lines.append(json_method(func,clip))
                clip_calls.append(f'self.{func}()')
            definition={key:value for key,value in entity.items() if key!='animations'}
            func=f'_data_entity_{token}'
            assignments=[]
            for index,image in enumerate(entity['files']):
                if not re.fullmatch(r'[A-Za-z_]\w*',image['sprite']):raise ValueError('Invalid sprite identifier in model cache')
                assignments.append(f'_data.files[{index}].sprite={image["sprite"]};')
            assignments.append('_data.animations=['+','.join(clip_calls)+']; return _data;')
            lines.append(json_method(func,definition,' '.join(assignments)))
            registrations.append((entity['name'],func))
        lines.append(f'    variable_struct_set(_sys._imports,{literal(key)},{{id:{literal(identity)},entities:{literal([e[0] for e in registrations])},factories:{{}}}});')
        for entity,func in registrations:
            lines.append(f'    variable_struct_set(variable_struct_get(_sys._imports,{literal(key)}).factories,{literal(entity)},_sys.{func});')
    lines.append('''
    _sys._new_player = method(_sys,function(_definition) { return self._SpriterPlayer(_definition,self); });
    _sys.new_builder = method(_sys,function(_name) { return self._SpriterRigBuilder(_name,self); });
    _sys._get_library = method(_sys,function(_key) {
        if (!variable_struct_exists(self._imports,_key)) return undefined;
        if (!variable_struct_exists(self._libraries,_key)) {
            var _library = self._SpriterLibrary(self);
            var _factories = variable_struct_get(self._imports,_key).factories;
            var _names = variable_struct_get_names(_factories);
            for (var _i=0;_i<array_length(_names);++_i) _library.register(_names[_i],variable_struct_get(_factories,_names[_i]));
            variable_struct_set(self._libraries,_key,_library);
        }
        return variable_struct_get(self._libraries,_key);
    });
    /// @returns {Array<String>} Managed collection keys, sorted alphabetically.
    _sys.list_imports = method(_sys,function() { var _names=variable_struct_get_names(self._imports); array_sort(_names,true); return _names; });
    /// @returns {Array<String>} Entity names; empty for an unknown collection.
    _sys.list_entities = method(_sys,function(_import) { var _library=self._get_library(_import); return is_undefined(_library)?[]:_library.names(); });
    /// @returns {Struct|Undefined} Shared definition, treated as immutable; undefined for an unknown collection/entity.
    _sys.describe_entity = method(_sys,function(_import,_entity) { var _library=self._get_library(_import); return is_undefined(_library)?undefined:_library.entity(_entity); });
    /// @returns {Array<String>} Original SCML clip names; empty when the entity cannot be found.
    _sys.list_animations = method(_sys,function(_import,_entity) {
        var _definition=self.describe_entity(_import,_entity),_names=[];
        if (!is_undefined(_definition)) for(var _i=0;_i<array_length(_definition.animations);++_i) array_push(_names,_definition.animations[_i].name);
        return _names;
    });
    /// @returns {Bool} Creates a named player. Duplicate names or unknown definitions return false without replacing a player.
    _sys.create_player = method(_sys,function(_name,_import,_entity) {
        if(variable_struct_exists(self._players,_name)) return false;
        var _definition=self.describe_entity(_import,_entity);
        if(is_undefined(_definition)) return false;
        var _player=self._new_player(_definition); _player.interface_import=_import; _player.interface_entity=_entity;
        variable_struct_set(self._players,_name,_player); return true;
    });
    /// @returns {Bool} Removes a named player and its listener/override state; false when absent.
    _sys.remove_player = method(_sys,function(_name) {
        if(!variable_struct_exists(self._players,_name)) return false;
        variable_struct_remove(self._players,_name); return true;
    });
    _sys._player = method(_sys,function(_name) { return variable_struct_exists(self._players,_name)?variable_struct_get(self._players,_name):undefined; });
    /// @returns {Struct|Undefined} Snapshot of playback state; undefined for an unknown player.
    _sys.get_player_state = method(_sys,function(_name) {
        var _p=self._player(_name); if(is_undefined(_p)) return undefined;
        return {name:_name,collection:_p.interface_import,entity:_p.interface_entity,animation:_p.animation,
            time_ms:_p.time_ms,speed:_p.speed,playing:_p.playing,duration_ms:_p.clip_index<0?0:_p._clip().duration};
    });
    /// @param {Real} delta_seconds Elapsed seconds. Advances a snapshot of all current players once.
    /// @returns {Struct} This system. Players removed by a callback are skipped safely.
    _sys.update = method(_sys,function(_delta_seconds) {
        var _names=variable_struct_get_names(self._players);
        for(var _i=0;_i<array_length(_names);++_i) { var _p=self._player(_names[_i]); if(!is_undefined(_p)) _p.update(_delta_seconds); }
        return self;
    });
    /// @returns {Bool} Enables/disables the named player's bone overlay; false when absent.
    _sys.set_bone_overlay = method(_sys,function(_name,_enabled) {var _p=self._player(_name);if(is_undefined(_p))return false;_p.show_bones=_enabled;return true;});
    /// @returns {Bool} Registers a built definition for this system; existing names are replaced for future players.
    _sys.register_definition = method(_sys,function(_import,_definition) {
        if(!is_struct(_definition)) return false;
        if(!variable_struct_exists(self._imports,_import)) variable_struct_set(self._imports,_import,{id:"runtime",entities:[],factories:{}});
        var _library=self._get_library(_import);
        _library.register(_definition.name,method({definition:_definition},function(){return self.definition;}));
        variable_struct_set(_library.cache,_definition.name,_definition); return true;
    });
''')
    methods={
        'play':('_animation,_restart=true,_loop_override=undefined','_animation,_restart,_loop_override','bool'),
        'pause':('','','bool'),'resume':('','','bool'),'stop':('','','bool'),
        'set_speed':('_multiplier','_multiplier','bool'),'seek':('_time_ms,_emit_events=false','_time_ms,_emit_events','bool'),
        'draw':('_x,_y','_x,_y','bool'),'draw_bones':('_x,_y','_x,_y','bool'),
        'set_transform':('_x,_y,_angle=0,_scale_x=1,_scale_y=1,_alpha=1','_x,_y,_angle,_scale_x,_scale_y,_alpha','bool'),
        'set_image':('_part,_sprite,_subimage=0,_pivot=undefined','_part,_sprite,_subimage,_pivot','bool'),
        'clear_image':('_part','_part','bool'),'clear_images':('','','bool'),
        'apply_character_map':('_map,_reset=false','_map,_reset','bool'),
        'remove_character_map':('_map','_map','bool'),'clear_character_maps':('','','bool'),
        'set_bone_transform':('_bone,_transform','_bone,_transform','bool'),
        'clear_bone_transform':('_bone','_bone','bool'),'set_part_transform':('_part,_transform','_part,_transform','bool'),
        'clear_part_transform':('_part','_part','bool'),'clear_transforms':('','','bool'),
        'get_bone_world':('_bone','_bone','value'),'get_part_world':('_part','_part','value'),
        'on':('_event,_callback','_event,_callback','value'),'off':('_event,_token','_event,_token','boolvalue'),
        'add_event':('_animation,_event,_time_ms,_payload=undefined','_animation,_event,_time_ms,_payload','bool'),
        'add_key_event':('_animation,_event,_timeline,_key_index,_payload=undefined','_animation,_event,_timeline,_key_index,_payload','bool')}
    for name,(args,call,kind) in methods.items():
        signature='_player_name'+(','+args if args else '')
        failure='undefined' if kind=='value' else 'false'
        expression=f'_p.{name}({call})'
        returncode=f'return {expression};' if kind in ('value','boolvalue') else expression+'; return true;'
        lines.append(f'    /// @function SpriterInterfaceSystem.{name}({signature})\n'
                     f'    /// @description Named-player {name}; time arguments use milliseconds, positions use room pixels, and angles use degrees.\n'
                     f'    /// @returns {{Any}} {failure} for an unknown player; otherwise '+('the underlying result.' if kind in ('value','boolvalue') else 'true after applying the operation.')+'\n'
                     f'    _sys.{name}=method(_sys,function({signature}) {{var _p=self._player(_player_name);if(is_undefined(_p))return {failure};{returncode}}});')
    lines.extend(['    return _sys;','}',''])
    return '\n'.join(lines)


def demo_sources(collections, project_id):
    suffix=project_id[:8];obj=f'o_scmlsi_demo_{suffix}';room=f'rm_scmlsi_demo_{suffix}'
    create='''spriter_interface_system = SpriterInterfaceSystem();
demo_imports = spriter_interface_system.list_imports();
demo_import_index = 0; demo_entity_index = 0; demo_animation_index = 0;
demo_bones = false; demo_swapped = false; demo_events = [];
demo_select = function(_import_index,_entity_index) {
    demo_import_index=(_import_index+array_length(demo_imports)) mod array_length(demo_imports);
    demo_import=demo_imports[demo_import_index];
    demo_entities=spriter_interface_system.list_entities(demo_import);
    demo_entity_index=(_entity_index+array_length(demo_entities)) mod array_length(demo_entities);
    demo_entity=demo_entities[demo_entity_index];
    demo_definition=spriter_interface_system.describe_entity(demo_import,demo_entity);
    demo_animations=spriter_interface_system.list_animations(demo_import,demo_entity);
    demo_animation_index=0;
    for(var _i=0;_i<array_length(demo_animations);++_i)if(demo_animations[_i]=="idle")demo_animation_index=_i;
    spriter_interface_system.remove_player("demo");
    spriter_interface_system.create_player("demo",demo_import,demo_entity);
    spriter_interface_system.set_transform("demo",0,0,0,2,2,1);
    spriter_interface_system.set_bone_overlay("demo",demo_bones);
    for(var _i=0;_i<array_length(demo_definition.animations);++_i) {
        var _clip=demo_definition.animations[_i];
        spriter_interface_system.add_event("demo",_clip.name,"demo_marker",_clip.duration*0.5);
    }
    spriter_interface_system.on("demo","demo_marker",method(id,function(_event){
        array_push(demo_events,_event.animation+" @ "+string(_event.time_ms)+" ms");
        if(array_length(demo_events)>4)array_delete(demo_events,0,1);
    }));
    demo_swapped=false;demo_events=[];
    spriter_interface_system.play("demo",demo_animations[demo_animation_index]);
};
demo_test_mode=false;
for(var _arg=1;_arg<=parameter_count();++_arg)if(parameter_string(_arg)=="--spriter-test")demo_test_mode=true;
if(array_length(demo_imports)>0)demo_select(0,0);
'''
    # Validation methods are installed only by the demo object, never as script assets/global functions.
    for name,args,constructor,body in functions((TEMPLATES/'validation.gml').read_text(encoding='utf-8-sig')):
        body=re.sub(r'new SpriterPlayer\(', 'self._new_player(',body)
        body=re.sub(r'new SpriterRigBuilder\(', 'self.new_builder(',body)
        body=rewrite_runtime(body)
        create+=f'\nspriter_interface_system._{name}=method(spriter_interface_system,function({args}) {{{body}\n}});\n'
    create+='''
if(demo_test_mode) {
    try {
        var _lib=spriter_interface_system._get_library("zombies");
        var _ok=spriter_interface_system.create_player("api-check","zombies","dome-alone");
        spriter_interface_system.play("api-check","walk");spriter_interface_system.update(0.1);
        show_debug_message("[Spriter check] "+(_ok && spriter_interface_system.get_player_state("api-check").time_ms==100 ? "PASS " : "FAIL ")+"named-player public API");
        spriter_interface_system.remove_player("api-check");
        spriter_interface_system._spriter_demo_run_checks(_lib);
        spriter_interface_system._spriter_demo_export_poses(_lib);
    } catch(_error) {show_debug_message("[Spriter check] ERROR "+json_stringify(_error));game_end();}
}
'''
    step='''if(array_length(demo_imports)==0)exit;
if(keyboard_check_pressed(vk_tab))demo_select(demo_import_index+1,0);
if(keyboard_check_pressed(vk_right))demo_select(demo_import_index,demo_entity_index+1);
if(keyboard_check_pressed(vk_left))demo_select(demo_import_index,demo_entity_index-1);
if(keyboard_check_pressed(vk_up)||keyboard_check_pressed(vk_down)) {
    demo_animation_index=(demo_animation_index+(keyboard_check_pressed(vk_up)?1:-1)+array_length(demo_animations)) mod array_length(demo_animations);
    spriter_interface_system.play("demo",demo_animations[demo_animation_index]);
}
var _state=spriter_interface_system.get_player_state("demo");
if(keyboard_check_pressed(vk_space)){if(_state.playing)spriter_interface_system.pause("demo");else spriter_interface_system.resume("demo");}
if(keyboard_check_pressed(ord("Q")))spriter_interface_system.set_speed("demo",_state.speed-0.5);
if(keyboard_check_pressed(ord("E")))spriter_interface_system.set_speed("demo",_state.speed+0.5);
if(keyboard_check_pressed(ord("R")))spriter_interface_system.set_speed("demo",_state.speed==0?-1:-_state.speed);
if(keyboard_check_pressed(ord("A")))spriter_interface_system.seek("demo",max(0,_state.time_ms-100));
if(keyboard_check_pressed(ord("D")))spriter_interface_system.seek("demo",min(_state.duration_ms,_state.time_ms+100));
if(keyboard_check_pressed(ord("B"))){demo_bones=!demo_bones;spriter_interface_system.set_bone_overlay("demo",demo_bones);}
if(keyboard_check_pressed(ord("I")) && array_length(demo_definition.files)>1) {
    var _part=demo_definition.parts[0];
    if(demo_swapped)spriter_interface_system.clear_image("demo",_part);
    else spriter_interface_system.set_image("demo",_part,demo_definition.files[1].sprite);
    demo_swapped=!demo_swapped;
}
spriter_interface_system.update(delta_time/1000000);
'''
    draw='''if(demo_test_mode) {
    try {spriter_interface_system._spriter_demo_render_checks(spriter_interface_system._get_library("zombies"));}
    catch(_error){show_debug_message("[Spriter check] ERROR "+json_stringify(_error));}
    game_end();exit;
}
draw_clear_alpha(make_color_rgb(24,27,32),1);draw_set_color(c_white);
if(array_length(demo_imports)==0){draw_text(24,24,"Import an SCML collection with Spriter GML Interface.");exit;}
var _state=spriter_interface_system.get_player_state("demo");
draw_text(24,20,"SPRITER INTERFACE SYSTEM");
draw_text(24,52,demo_import+" / "+demo_entity+" / "+_state.animation);
draw_text(24,78,"Time: "+string_format(_state.time_ms,0,1)+" ms   Speed: "+string(_state.speed)+"   "+(_state.playing?"Playing":"Paused"));
spriter_interface_system.draw("demo",room_width*0.5,room_height*0.5+90);
draw_text(24,room_height-160,"Tab: collection   Left/Right: entity   Up/Down: animation   Space: pause");
draw_text(24,room_height-136,"Q/E: speed   R: reverse   A/D: seek   B: bones   I: replace image");
for(var _i=0;_i<array_length(demo_events);++_i)draw_text(24,room_height-104+_i*20,demo_events[_i]);
'''
    obj_yy=converter.load_project(TEMPLATES/'demo_object.yy')
    obj_yy['name']=obj_yy['%Name']=obj;obj_yy['parent']={'name':'Demo','path':'folders/SCML-custom/Demo.yy'}
    room_yy=converter.load_project(TEMPLATES/'demo_room.yy')
    room_yy['name']=room_yy['%Name']=room;room_yy['parent']={'name':'Demo','path':'folders/SCML-custom/Demo.yy'}
    room_yy['instanceCreationOrder']=[{'name':'inst_'+suffix,'path':f'rooms/{room}/{room}.yy'}]
    for layer in room_yy['layers']:
        for inst in layer.get('instances',[]):
            inst['name']=inst['%Name']='inst_'+suffix;inst['objectId']={'name':obj,'path':f'objects/{obj}/{obj}.yy'}
    files={f'objects/{obj}/{obj}.yy':json.dumps(obj_yy).encode(),f'objects/{obj}/Create_0.gml':create.encode(),
           f'objects/{obj}/Step_0.gml':step.encode(),f'objects/{obj}/Draw_0.gml':draw.encode(),
           f'rooms/{room}/{room}.yy':json.dumps(room_yy).encode()}
    resources=[{'id':{'name':obj,'path':f'objects/{obj}/{obj}.yy'}},{'id':{'name':room,'path':f'rooms/{room}/{room}.yy'}}]
    return files,resources
