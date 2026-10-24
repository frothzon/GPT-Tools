// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function draw_text_advanced(_xto, _yto, _string, _characters, _width=128){
	
	/// string properties
	var str = string_copy(_string, 1, _characters);
	var maxW = _width;
	var strW = string_width_ext(_string, -1, maxW);
	var strH = string_height_ext(_string, -1, maxW);
	
	/// Textbox
	var margin = 8;
	
	var tbW = strW + margin * 2;
	var tbH = strH + margin * 2;
	
	var tbX = _xto;
	var tbY = _yto;
	
	/// draw text
	var len = string_length(str);
	var xdraw = tbX + margin;
	var ydraw = tbY + margin;
	var cmd = -1;
	var width = 0;
	var height = 0;
	var last_space = -1;
	var xjump = 0;
	var yjump = 0;
	var state = 0;
    var color = c_white;
	
	if(len < 1) return;
	
	for(var i = 0; i < len; i++){
		var char = string_char_at(str, i+1);
		/// set command mode
		if(char == "#"){
			/// get command char
			char = string_char_at(str, i+2);
			/// select command
			switch(char){
				case "r": color = (c_red); break;
				case "g": color = (c_green); break;
				case "b": color = (c_blue); break;
				case "k": color = (c_black);break;
				case "w": color = (c_white);break;
				case "0": state = 0; break;
				case "1": state = 1; break;
				case "2": state = 2; break;
				
			}
			
			/// move past command to continue drawing
			char = string_char_at(str, i+3);
			i += 1;
			continue;
		}
		
		/// effects
		if(state == 0){
			// default
			xjump = 0;
			yjump = 0;
		} else if(state == 1){
			xjump = irandom_range(-1,1);
			yjump = irandom_range(-1,1);
		} else if(state == 2){
			yjump = wave(-1.5,1.5,0.5,i*pi/4);
			xjump = 0;
		}
		
		/// draw text
		draw_text_outline(xdraw + width + xjump, ydraw + height + yjump, char, c_black, color);
		
		/// get position
		width += string_width(char);
		
		/// test for overlap, and wrap around
		if(char == " "){
			var ww = width;
			for(var s = i+1; s < len; s++){
				var cnext = string_char_at(str, s+1);
				ww += string_width(cnext)
				if(cnext = " ") {
					s = len;
				} else if(ww > strW){
					/// wrap around
					width = 0;
					height += string_height("H");
					s = len;
				}
			}
		}
		/// forced wrap around
		if(width > strW){
			draw_text(xdraw + width + string_width("H"), ydraw + height, "-");
			width = 0;
			height += string_height("H");
		}
		
	}
	draw_set_color(c_white);
	//draw_set_color(c_black);
	//draw_text_ext(tbX + margin, tbY + margin, str, -1, strW);
	//draw_set_color(c_white);
	return {x: tbX, y: tbY, w: tbW, h: tbH};
}

