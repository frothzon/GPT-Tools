/**
 * Converts world coordinates to GUI coordinates.
 * Useful for drawing HUD elements on top of world objects in the Draw GUI event.
 * @param {Real} _x World X position.
 * @param {Real} _y World Y position.
 * @returns {Array<Real>} An array [gui_x, gui_y].
 */
function world_to_gui(_x, _y) {
    var _cam = view_camera[0];
    var _cam_x = camera_get_view_x(_cam);
    var _cam_y = camera_get_view_y(_cam);
    var _cam_w = camera_get_view_width(_cam);
    var _cam_h = camera_get_view_height(_cam);
    
    var _gui_w = display_get_gui_width();
    var _gui_h = display_get_gui_height();
    
    // Calculate the normalized position (0 to 1) within the camera view, 
    // then scale by the GUI dimensions.
    var _gui_x = (_x - _cam_x) * (_gui_w / _cam_w);
    var _gui_y = (_y - _cam_y) * (_gui_h / _cam_h);
    
    return [_gui_x, _gui_y];
}