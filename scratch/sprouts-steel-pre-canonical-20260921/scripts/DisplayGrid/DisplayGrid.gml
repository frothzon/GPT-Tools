/// @desc DisplayGrid constructor with uniform aspect fitting
function DisplayGrid(_x, _y, _width, _height, _hcount, _vcount, _margin = 2) constructor {
    x = _x;
    y = _y;
    width = _width;
    height = _height;
    hcount = _hcount;
    vcount = _vcount;
    cellMargin = _margin;
    
    xmove = _x;
    ymove = _y;
    moveRatio = 0.6;
    
    // Alignment properties (0 = start, 0.5 = center, 1 = end)
    halign = 0.5; 
    valign = 0.5;

    /// @desc Resizes cells to fit a specific rectangle while maintaining aspect ratio
    /// @param {real} _x1 The left x coordinate of the rectangle
    /// @param {real} _y1 The top y coordinate of the rectangle
    /// @param {real} _w  The total width of the target area
    /// @param {real} _h  The total height of the target area
    static resize_to_rect = function(_x1, _y1, _w, _h) {
        // 1. Calculate maximum possible cell size based on the input width/height
        // This finds the limiting dimension to preserve the aspect ratio
        var _max_w = _w / hcount;
        var _max_h = _h / vcount;
        
        // 2. The smaller of the two becomes our uniform cell size (Square packing)
        var _uniform_size = min(_max_w, _max_h);
        
        width  = _uniform_size;
        height = _uniform_size;
        
        // 3. Calculate total dimensions of the resulting grid
        var _total_grid_w = width * hcount;
        var _total_grid_h = height * vcount;
        
        // 4. Calculate padding based on alignment properties (halign/valign)
        // This centers the grid within the provided rectangle
        var _px = (_w - _total_grid_w) * halign;
        var _py = (_h - _total_grid_h) * valign;
        
        // 5. Set target move positions
        xmove = _x1 + _px;
        ymove = _y1 + _py;
    };

    static pointToIndex = function(px, py) {
        if (point_in_rectangle(px, py, x, y, x + width * hcount, y + height * vcount)) {
            var xoffset = (px - x) div width;
            var yoffset = (py - y) div height;
            if (xoffset >= 0 && xoffset < hcount && yoffset >= 0 && yoffset < vcount) {
                return xoffset + yoffset * hcount;
            }
        }
        return -1;
    };

    static forEach = function(_fcn) {
        var _len = hcount * vcount;
        static _box = { x: 0, y: 0, x2: 0, y2: 0, w: 0, h: 0 }; 
        
        for (var i = 0; i < _len; i++) {
            var _cx = i mod hcount;
            var _cy = i div hcount;
            
            var _bx = x + (_cx * width);
            var _by = y + (_cy * height);
            
            _box.x = _bx + cellMargin;
            _box.y = _by + cellMargin;
            _box.w = width - (cellMargin * 2);
            _box.h = height - (cellMargin * 2);
            _box.x2 = _box.x + _box.w;
            _box.y2 = _box.y + _box.h;
            
            _fcn(i, _box);
        }
    };

    static update = function() {
        x = lerp(x, xmove, moveRatio);
        y = lerp(y, ymove, moveRatio);
    };
    
    static gridRect = function() {
        return {
            x: x, y: y,
            w: hcount * width,
            h: vcount * height
        };
    };
}