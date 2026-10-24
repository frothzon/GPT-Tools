if (!IN_UI){
	var _margin = 4;
	var _offset = 12;
	var _startX = _margin + _offset;
	var _startY = _margin + _offset;

	var _size = sprite_get_height(spr_Heart1);
	var _dist = _size + _margin;

	var _hp = PLAYER_STATS.hp.get_val();
	var _hp_max = PLAYER_STATS.hp.get_max();

	for(var i = 0; i < _hp_max; i++){
		var _subImg = 0;
		
		if(i > _hp){
			_subImg = 4;
		} else if(_hp - i < 1.0){
			var _rem = 4 - ceil((_hp - i) * 3);
			_subImg = _rem;
		}
		
		var _scale = 1;
		if(i == ceil(_hp-1)){
			_scale = SCT.wave(0.9, 1.1, 0.7, 0);
		}
		
		draw_sprite_ext(spr_Heart1, _subImg, _startX + _dist * i, _startY, _scale, _scale, 0, c_white, 1);
	}

	TOOLTIP.draw();
	BLASTER.draw();
}
