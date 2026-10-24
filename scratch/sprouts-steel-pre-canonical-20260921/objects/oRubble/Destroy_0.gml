/// @description Announce that this "enemy" has been destroyed for mission progress
event_bus_post(MISSION_EVENT.ENEMY_KILLED, {
    enemy_instance_id: id,          // The specific instance that was destroyed
    enemy_object_index: object_index  // The type of object (e.g., oCollisionObjects)
});