/**
* @class Animator
* @brief A class for handling animations based on direction and angle in GameMaker Language.
* 
* The Animator class manages directional animations and provides utility methods
* to add animation sets, update animations based on angles, and control playback.
*/
function Animator() constructor {

    self.animations = [];
    self.index = -1;
    self.callback = -1;

    /**
    * @function add_animation_set
    * @brief Adds a new set of directional animations to the animator.
    * 
    * @param anim_right Animation for the right direction.
    * @param anim_up Animation for the upward direction.
    * @param anim_left Animation for the left direction.
    * @param anim_down Animation for the downward direction.
    * @return The index of the newly added animation set.
    */
    static add_animation_set = function(anim_right, anim_up, anim_left, anim_down) {
        var _animatedSet = [anim_right, anim_up, anim_left, anim_down];
        var _index = array_length(self.animations);
        self.animations[_index] = _animatedSet;
        return _index;
    };

    /**
    * @function set_animation
    * @brief Sets the current animation by index and optionally defines a callback function.
    * 
    * @param _index The index of the animation set to play.
    * @param _callback (Optional) A function to call when the animation completes.
    */
    static set_animation = function(_index, _callback = -1) {
        if(self.index != _index){
            self.index = _index;
            other.image_index = 0;
            self.callback = _callback;
        }
    };

    /**
    * @function update
    * @brief Updates the animation based on the given angle.
    * 
    * @param _angle The angle (in degrees) used to determine the animation direction.
    * 
    * This method sets the sprite index based on the angle, updates the animation frame,
    * and executes the callback function if provided.
    */
    static update = function(_angle) {
        if (self.index == -1) return;

        var _sprite = self.animations[self.index];
        var _direction = round(_angle / 90) % 4;

        // Set the sprite index for the current direction
        other.sprite_index = self.animations[self.index][_direction];

        // Run the callback function when the animation completes
        if (other.image_index == other.image_number && is_callable(self.callback)) {
            var _callable = self.callback;
            _callable(other);
        }
    };
}



