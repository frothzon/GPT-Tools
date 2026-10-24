/// setup
surface_resize(application_surface, eRES.WIDTH, eRES.HEIGHT);

/// Resize window
var _windowWidth = eRES.WIDTH * eRES.SCALE;
var _windowHeight = eRES.HEIGHT * eRES.SCALE;

window_set_size( _windowWidth, _windowHeight);

display_set_gui_size(eRES.WIDTH*2, eRES.HEIGHT*2);

target_id = obj_player;
target = noone;
position = new Vector2();
lerp_ratio = 0.25;
shake_mag = 0;
shake_timer = 0;
shake = new Vector2();
right_axis = new Vector2();
mouse_pos = new Vector2(mouse_x, mouse_y);

shake_camera = function(_mag, _duration){
    shake_mag = _mag;
    shake_timer = _duration * GAME_FPS;
}

init_dragSystem();

depth = 200;
SOUND_MGR.init();