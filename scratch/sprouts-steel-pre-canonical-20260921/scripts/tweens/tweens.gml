/// @desc A collection of easing functions following the lerp signature: tween_*(start, end, ratio)

// --- LINEAR ---

/// @function tween_linear(start, end, ratio)
function tween_linear(_start, _end, _ratio) {
    return lerp(_start, _end, _ratio);
}

// --- QUADRATIC ---

/// @function tween_quad_in(start, end, ratio)
function tween_quad_in(_start, _end, _ratio) {
    return lerp(_start, _end, _ratio * _ratio);
}

/// @function tween_quad_out(start, end, ratio)
function tween_quad_out(_start, _end, _ratio) {
    return lerp(_start, _end, _ratio * (2 - _ratio));
}

/// @function tween_quad_inout(start, end, ratio)
function tween_quad_inout(_start, _end, _ratio) {
    var _t = (_ratio < 0.5) ? 2 * _ratio * _ratio : -1 + (4 - 2 * _ratio) * _ratio;
    return lerp(_start, _end, _t);
}

// --- CUBIC ---

/// @function tween_cubic_in(start, end, ratio)
function tween_cubic_in(_start, _end, _ratio) {
return lerp(_start, _end, _ratio * _ratio * _ratio);
}

/// @function tween_cubic_out(start, end, ratio)
function tween_cubic_out(_start, _end, _ratio) {
    var _t = (--_ratio) * _ratio * _ratio + 1;
    return lerp(_start, _end, _t);
}

/// @function tween_cubic_inout(start, end, ratio)
function tween_cubic_inout(_start, _end, _ratio) {
    var _t = (_ratio < 0.5) ? 4 * _ratio * _ratio * _ratio : (_ratio - 1) * (2 * _ratio - 2) * (2 * _ratio - 2) + 1;
    return lerp(_start, _end, _t);
}

// --- SINE ---

/// @function tween_sine_in(start, end, ratio)
function tween_sine_in(_start, _end, _ratio) {
    var _t = 1 - cos((_ratio * pi) / 2);
    return lerp(_start, _end, _t);
}

/// @function tween_sine_out(start, end, ratio)
function tween_sine_out(_start, _end, _ratio) {
    var _t = sin((_ratio * pi) / 2);
    return lerp(_start, _end, _t);
}

/// @function tween_sine_inout(start, end, ratio)
function tween_sine_inout(_start, _end, _ratio) {
    var _t = -(cos(pi * _ratio) - 1) / 2;
    return lerp(_start, _end, _t);
}

// --- BACK (Overshoot) ---

/// @function tween_back_in(start, end, ratio)
function tween_back_in(_start, _end, _ratio) {
    var _s = 1.70158;
    var _t = _ratio * _ratio * ((_s + 1) * _ratio - _s);
    return lerp(_start, _end, _t);
}

/// @function tween_back_out(start, end, ratio)
function tween_back_out(_start, _end, _ratio) {
    var _s = 1.70158;
    var _t = (--_ratio) * _ratio * ((_s + 1) * _ratio + _s) + 1;
    return lerp(_start, _end, _t);
}

/// @function tween_back_inout(start, end, ratio)
function tween_back_inout(_start, _end, _ratio) {
    var _s = 1.70158 * 1.525;
    var _t;
    _ratio *= 2;
    if (_ratio < 1) {
    _t = 0.5 * (_ratio * _ratio * ((_s + 1) * _ratio - _s));
    } else {
    _ratio -= 2;
    _t = 0.5 * (_ratio * _ratio * ((_s + 1) * _ratio + _s) + 2);
    }
    return lerp(_start, _end, _t);
}

// --- BOUNCE ---

/// @function tween_bounce_out(start, end, ratio)
function tween_bounce_out(_start, _end, _ratio) {
    var _t = _ratio;
    if (_t < (1 / 2.75)) {
    _t = 7.5625 * _t * _t;
    } else if (_t < (2 / 2.75)) {
    _t -= (1.5 / 2.75);
    _t = 7.5625 * _t * _t + 0.75;
    } else if (_t < (2.5 / 2.75)) {
    _t -= (2.25 / 2.75);
    _t = 7.5625 * _t * _t + 0.9375;
    } else {
    _t -= (2.625 / 2.75);
    _t = 7.5625 * _t * _t + 0.984375;
    }
    return lerp(_start, _end, _t);
}

// --- ELASTIC ---

/// @function tween_elastic_out(start, end, ratio)
function tween_elastic_out(_start, _end, _ratio) {
    if (_ratio == 0) return _start;
    if (_ratio == 1) return _end;
    var _p = 0.3;
    var _t = power(2, -10 * _ratio) * sin((_ratio - _p / 4) * (2 * pi) / _p) + 1;
    return lerp(_start, _end, _t);
}