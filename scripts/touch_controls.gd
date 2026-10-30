class_name TouchControls
extends Control
## On-screen controls for phones and tablets.
## Left half: floating stick (appears where the thumb lands, 8 directions).
## Right side: 1 2 / 3 4 attack buttons, plus 1+2 (throw) and 3+4 (Surge) shortcuts and a pause button.
## Main reads x, y (stick, screen-relative) and held (button bits) exactly like the keyboard.

signal pause_pressed

var x := 0
var y := 0
var held := 0
var font: Font
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var touches := {}          # touch index -> button bits it is holding
var buttons: Array = []    # [{bits, label, center, radius, color}]
var pause_rect := Rect2()
const DEAD := 22.0         # pixels before the stick registers a direction


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Size from the viewport directly (rotation / window resizes re-run the layout).
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	position = Vector2.ZERO
	size = s
	var r := clampf(s.y * 0.085, 34.0, 70.0)          # button radius scales with the screen
	var c := Vector2(s.x - r * 3.4, s.y - r * 3.4)     # center of the 2x2 grid
	var g := r * 1.15
	var P := Color(0.45, 0.85, 1.0)
	var K := Color(1.0, 0.7, 0.35)
	buttons = [
		{bits = 1, label = "1", center = c + Vector2(-g, -g), radius = r, color = P},
		{bits = 2, label = "2", center = c + Vector2(g, -g), radius = r, color = P},
		{bits = 4, label = "3", center = c + Vector2(-g, g), radius = r, color = K},
		{bits = 8, label = "4", center = c + Vector2(g, g), radius = r, color = K},
		{bits = 3, label = "1+2", center = c + Vector2(-g * 2.9, -g * 0.2), radius = r * 0.62, color = Color(0.75, 0.6, 1.0)},
		{bits = 12, label = "3+4", center = c + Vector2(-g * 2.9, g * 1.35), radius = r * 0.62, color = Color(1.0, 0.5, 0.6)},
	]
	pause_rect = Rect2(Vector2(s.x / 2 - 34, s.y - 64), Vector2(68, 50))
	queue_redraw()


func reset() -> void:
	x = 0; y = 0; held = 0; stick_id = -1; touches.clear()
	_layout()


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if pause_rect.has_point(e.position):
				pause_pressed.emit()
				get_viewport().set_input_as_handled()
				return
			var b := _button_at(e.position)
			if b >= 0:
				touches[e.index] = b
			elif e.position.x < size.x * 0.5 and stick_id < 0:
				stick_id = e.index
				stick_origin = e.position
				stick_pos = e.position
		else:
			touches.erase(e.index)
			if e.index == stick_id:
				stick_id = -1
		_update()
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_pos = e.position
		elif touches.has(e.index):
			# sliding a thumb across buttons (e.g. 1 -> 2 for a string) presses the new one
			var b := _button_at(e.position)
			if b >= 0: touches[e.index] = b
		_update()
		get_viewport().set_input_as_handled()


func _button_at(p: Vector2) -> int:
	for b in buttons:
		if p.distance_to(b.center) <= b.radius * 1.12:
			return b.bits
	return -1


func _update() -> void:
	held = 0
	for i in touches:
		held |= touches[i]
	x = 0; y = 0
	if stick_id >= 0:
		var d := stick_pos - stick_origin
		if d.length() > DEAD:
			var a := fposmod(atan2(-d.y, d.x), TAU)      # 0 = right, counter-clockwise
			var oct := int(round(a / (TAU / 8.0))) % 8
			x = [1, 1, 0, -1, -1, -1, 0, 1][oct]
			y = [0, 1, 1, 1, 0, -1, -1, -1][oct]
	queue_redraw()


func _draw() -> void:
	# stick
	if stick_id >= 0:
		var r := clampf(size.y * 0.11, 50.0, 95.0)
		var d := (stick_pos - stick_origin).limit_length(r)
		draw_circle(stick_origin, r, Color(1, 1, 1, 0.08))
		draw_arc(stick_origin, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(stick_origin + d, r * 0.42, Color(0.45, 0.85, 1.0, 0.55))
	else:
		var hint := Vector2(size.x * 0.16, size.y * 0.72)
		draw_arc(hint, 56, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)
		if font: draw_string(font, hint + Vector2(-40, 6), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1, 1, 1, 0.3))
	# buttons
	for b in buttons:
		var on: bool = (held & b.bits) == b.bits
		var c: Color = b.color
		draw_circle(b.center, b.radius, Color(c, 0.55 if on else 0.18))
		draw_arc(b.center, b.radius, 0, TAU, 40, Color(c, 0.95 if on else 0.6), 3.0)
		if font:
			var fs := int(b.radius * (0.7 if b.label.length() == 1 else 0.42))
			var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, b.center + Vector2(-w / 2, fs * 0.36), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	# pause
	draw_rect(pause_rect, Color(0, 0, 0, 0.35))
	draw_rect(pause_rect, Color(1, 1, 1, 0.4), false, 2.0)
	var pc := pause_rect.get_center()
	draw_rect(Rect2(pc + Vector2(-12, -12), Vector2(8, 24)), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(pc + Vector2(4, -12), Vector2(8, 24)), Color(1, 1, 1, 0.85))
