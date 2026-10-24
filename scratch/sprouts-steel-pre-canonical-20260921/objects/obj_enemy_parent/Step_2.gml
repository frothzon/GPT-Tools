// Inherit the parent event
event_inherited();

target_object = collision_circle(x, y, chase_range, obj_player, 0, 1);

behavior.update();

sm_knockback();