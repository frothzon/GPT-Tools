stats = new ActorStats(life, damage, defense, max_speed);

show_debug_message($"init stats {stats}");

/// things to drop
drop_items = [];
drop_weights = [];
drop_count = 1;

scaling = new Vector2(0.1,0.1);

hurt_timer = 0;
hp_trail = 1;
pos = new ZAxis();