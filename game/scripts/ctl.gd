## Entrada: teclado, mouse (captura de ponteiro) e controle, com detecção de "acabou de apertar".
class_name Ctl

static var mdx := 0.0
static var mdy := 0.0
static var wheel := 0
static var prev := {}
static var cur := {}
static var mouse_p := [false, false, false, false]
static var captured := false

static func on_event(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: mdx += e.relative.x; mdy += e.relative.y
		elif e.button_mask & MOUSE_BUTTON_MASK_LEFT: mdx += e.relative.x; mdy += e.relative.y
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: wheel -= 1
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: wheel += 1
		elif e.button_index <= 3: mouse_p[e.button_index] = true

static func key(k: Key) -> bool: return Input.is_physical_key_pressed(k)
static func pressed(k: Key) -> bool:
	var c := Input.is_physical_key_pressed(k); cur[k] = c
	return c and not prev.get(k, false)
static func mouse(b: int) -> bool: return Input.is_mouse_button_pressed(b)
static func mouse_pressed(b: int) -> bool: return mouse_p[b]

static func pad() -> Dictionary:
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): return {}
	var id: int = pads[0]
	var dz := func(v: float) -> float: return 0.0 if absf(v) < 0.16 else v
	var out := { "lx": dz.call(Input.get_joy_axis(id, JOY_AXIS_LEFT_X)), "ly": dz.call(Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)), "rx": dz.call(Input.get_joy_axis(id, JOY_AXIS_RIGHT_X)), "ry": dz.call(Input.get_joy_axis(id, JOY_AXIS_RIGHT_Y)),
		"lt": Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT) > 0.4, "rt": Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) > 0.4, "b": {}, "p": {} }
	for b in 16:
		var c := Input.is_joy_button_pressed(id, b); out.b[b] = c; var key_id := 1000 + b
		out.p[b] = c and not prev.get(key_id, false); cur[key_id] = c
	return out

static func frame() -> void:
	for k in cur: prev[k] = cur[k]
	mdx = 0; mdy = 0; wheel = 0; mouse_p = [false, false, false, false]

static func capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
