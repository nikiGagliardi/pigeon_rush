class_name Actions
extends RefCounted
## Nomi delle input action e loro registrazione via codice: tastiera, frecce e gamepad.

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const POOP := &"poop"
const PAUSE := &"pause"


static func ensure_registered() -> void:
	if InputMap.has_action(POOP):
		return # già registrate (es. dopo reload_current_scene)

	_add_keys(MOVE_LEFT, [KEY_A, KEY_LEFT])
	_add_axis(MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_add_button(MOVE_LEFT, JOY_BUTTON_DPAD_LEFT)

	_add_keys(MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_add_axis(MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_add_button(MOVE_RIGHT, JOY_BUTTON_DPAD_RIGHT)

	_add_keys(MOVE_UP, [KEY_W, KEY_UP])
	_add_axis(MOVE_UP, JOY_AXIS_LEFT_Y, -1.0)
	_add_button(MOVE_UP, JOY_BUTTON_DPAD_UP)

	_add_keys(MOVE_DOWN, [KEY_S, KEY_DOWN])
	_add_axis(MOVE_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	_add_button(MOVE_DOWN, JOY_BUTTON_DPAD_DOWN)

	_add_keys(POOP, [KEY_SPACE, KEY_J])
	_add_button(POOP, JOY_BUTTON_A)
	_add_axis(POOP, JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_add_keys(PAUSE, [KEY_ESCAPE, KEY_P])
	_add_button(PAUSE, JOY_BUTTON_START)


static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


static func _add_keys(action: StringName, keys: Array[Key]) -> void:
	_ensure(action)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


static func _add_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


static func _add_button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
