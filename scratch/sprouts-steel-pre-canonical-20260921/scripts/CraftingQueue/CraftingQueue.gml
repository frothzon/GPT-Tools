/**
 * @struct CraftingQueue
 * @brief Manages a sequential list of crafting tasks with timers and item delivery.
 */
function CraftingQueue() constructor {
    self.tasks = [];
    self.is_paused = false;

    /**
     * @function add_task
     * @param {struct} _recipe The recipe data from the button.
     * @param {real} _duration The total time in frames to craft.
     */
    static add_task = function(_recipe, _duration) {
        array_push(self.tasks, {
            recipe: _recipe,
            timer: _duration,
            duration: _duration
        });
    };

    /**
     * @function update
     * @brief Ticks down the current task and handles completion.
     */
    static update = function() {
        if (array_length(self.tasks) == 0 || self.is_paused) return;

        var _current = self.tasks[0];
        _current.timer--;

        if (_current.timer <= 0) {
            // Task Complete!
            var _item_data = ITEMS[_current.recipe.craft];
            BACKPACK.addItem(_item_data, 1);
            SCT.debug_log("Finished: " + _item_data.name);
            SOUND_MGR.play_ui(snd_prize);
            
            // Remove from queue
            array_delete(self.tasks, 0, 1);
        }
    };

    /**
     * @function get_current_progress
     * @return {real} 0 to 1 progress of the active task.
     */
    static get_current_progress = function() {
        if (array_length(self.tasks) == 0) return 0;
        var _c = self.tasks[0];
        return 1 - (_c.timer / _c.duration);
    };

    /**
     * @function get_total_progress
     * @return {real} 0 to 1 progress of the entire queue.
     */
    static get_total_progress = function() {
        var _len = array_length(self.tasks);
        if (_len == 0) return 0;
        
        var _total_time = 0;
        var _remaining_time = 0;
        for (var i = 0; i < _len; i++) {
            _total_time += self.tasks[i].duration;
            _remaining_time += self.tasks[i].timer;
        }
        return 1 - (_remaining_time / _total_time);
    };
}