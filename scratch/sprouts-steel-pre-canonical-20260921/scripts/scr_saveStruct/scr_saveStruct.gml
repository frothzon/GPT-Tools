// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function scr_saveStruct(fname, section, key, bag){
	var _str = json_stringify(bag);
	var encoded = base64_encode(_str);
	ini_open(fname);
	ini_write_string(section, key, encoded);
	ini_close();
}

function scr_loadStruct(fname, section, key){
	ini_open(fname);
	var str = ini_read_string(section, key, "");
	if(str != ""){
		var _decoded = base64_decode(str);
		var _bag = json_parse(_decoded);
		return(_bag);
	}
	return(-1);
}