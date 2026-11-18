class_name TouchControls
extends Control
## Controlli touch: metà sinistra = joystick flottante (appare dove appoggi il dito),
## metà destra = sgancio. Attivi solo su dispositivi con touchscreen.

const STICK_RADIUS := 95.0
const KNOB_RADIUS := 40.0
const POOP_BUTTON_RADIUS := 78.0
const PAUSE_AREA := Vector2(200.0, 130.0)

var move_vector: Vector2 = Vector2.ZERO

## Cacche disponibili, mostrate sul pulsante DROP.
var ammo: int = -1:
	set(value):
		if value == ammo:
			return
		ammo = value
		if visible:
			queue_redraw()

var enabled: bool = false:
	set(value):
		enabled = value
		_reset_state()
		visible = value and is_touch_device()

var _stick_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _poop_queued: bool = false
var _poop_flash: float = 0.0


static func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Restituisce true una sola volta per ogni tocco sul lato destro.
func consume_poop() -> bool:
	var queued := _poop_queued
	_poop_queued = false
	return queued


func _process(delta: float) -> void:
	if _poop_flash <= 0.0:
		return
	_poop_flash = maxf(0.0, _poop_flash - delta * 5.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled:
		return

	var size_px := get_viewport_rect().size
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if touch.position.x > size_px.x - PAUSE_AREA.x and touch.position.y < PAUSE_AREA.y:
				return # lascia lavorare il pulsante pausa
			if touch.position.x < size_px.x * 0.5:
				if _stick_index < 0:
					_stick_index = touch.index
					_origin = touch.position
					_knob = touch.position
					_update_vector()
			else:
				_poop_queued = true
				_poop_flash = 1.0
			queue_redraw()
		elif touch.index == _stick_index:
			_stick_index = -1
			move_vector = Vector2.ZERO
			queue_redraw()
		return

	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _stick_index:
		_knob = drag.position
		_update_vector()
		queue_redraw()


func _draw() -> void:
	var size_px := get_viewport_rect().size

	if _stick_index >= 0:
		draw_circle(_origin, STICK_RADIUS, Color(1.0, 1.0, 1.0, 0.1))
		draw_arc(_origin, STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 3.0)
		draw_circle(_knob, KNOB_RADIUS, Color(1.0, 1.0, 1.0, 0.45))
	else:
		var hint := Vector2(170.0, size_px.y - 170.0)
		draw_arc(hint, STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.18), 3.0)
		draw_circle(hint, KNOB_RADIUS * 0.6, Color(1.0, 1.0, 1.0, 0.15))

	var button := Vector2(size_px.x - 170.0, size_px.y - 170.0)
	var empty := ammo == 0
	var fill := Palette.DANGER if empty else Palette.POOP
	fill.a = (0.25 if empty else 0.3) + _poop_flash * 0.4
	draw_circle(button, POOP_BUTTON_RADIUS * (1.0 + _poop_flash * 0.12), fill)
	draw_arc(button, POOP_BUTTON_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.6), 3.0)

	var font := get_theme_default_font()
	var ink := Color(0.15, 0.12, 0.08)
	draw_string(font, button + Vector2(-POOP_BUTTON_RADIUS, -6.0), "DROP",
		HORIZONTAL_ALIGNMENT_CENTER, POOP_BUTTON_RADIUS * 2.0, 24, ink)
	draw_string(font, button + Vector2(-POOP_BUTTON_RADIUS, 34.0), str(ammo) if ammo >= 0 else "",
		HORIZONTAL_ALIGNMENT_CENTER, POOP_BUTTON_RADIUS * 2.0, 40, Color.WHITE if empty else ink)


func _update_vector() -> void:
	var delta := _knob - _origin
	if delta.length() > STICK_RADIUS:
		# joystick "trascinabile": l'origine segue il dito
		delta = delta.normalized() * STICK_RADIUS
		_origin = _knob - delta
	move_vector = Vector2(delta.x / STICK_RADIUS, -delta.y / STICK_RADIUS)


func _reset_state() -> void:
	_stick_index = -1
	_poop_queued = false
	move_vector = Vector2.ZERO
	queue_redraw()
