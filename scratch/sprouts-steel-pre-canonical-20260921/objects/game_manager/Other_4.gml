enum eRES {
    WIDTH = 320,
    HEIGHT = 180,
    SCALE = 4
};

var _camera = camera_create_view(0, 0, eRES.WIDTH, eRES.HEIGHT, 0, noone, -1, -1, eRES.WIDTH/2, eRES.HEIGHT/2);

view_enabled = true;
view_visible[0] = true;

view_set_camera(0, _camera);