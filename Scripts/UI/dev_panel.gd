class_name DevPanel
extends Control
## Pannello DEVELOPER (dalle impostazioni): curva della difficoltà e densità del traffico, per tararle provando.
## I valori valgono subito (dalla prossima fila di traffico) e si salvano alla chiusura, vedi DevTuning.

signal closed

const DIM := Color(1.0, 1.0, 1.0, 0.75)

var _ramp: HSlider
var _curve: HSlider
var _minimum: HSlider
var _traffic: HSlider
var _overlay: CheckButton
var _values: Dictionary[HSlider, Label] = {}
var _preview: Label
var _back_button: Button
var _loading: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func open() -> void:
	DevTuning.difficulty_at(0.0) # carica il file se non è ancora stato letto
	_loading = true
	_ramp.value = DevTuning.ramp_km
	_curve.value = DevTuning.curve
	_minimum.value = roundf(DevTuning.min_difficulty * 100.0)
	_traffic.value = DevTuning.traffic
	_overlay.button_pressed = DevTuning.show_overlay
	_loading = false
	_refresh()
	visible = true
	_back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	DevTuning.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		close()


func _on_changed() -> void:
	if _loading:
		return
	DevTuning.ramp_km = _ramp.value
	DevTuning.curve = _curve.value
	DevTuning.min_difficulty = _minimum.value / 100.0
	DevTuning.traffic = _traffic.value
	DevTuning.show_overlay = _overlay.button_pressed
	_refresh()


func _on_reset() -> void:
	DevTuning.reset()
	open()


func _refresh() -> void:
	_values[_ramp].text = "%.1f km" % _ramp.value
	_values[_curve].text = "%.2f" % _curve.value
	_values[_minimum].text = "%d%%" % int(_minimum.value)
	_values[_traffic].text = "x%.2f" % _traffic.value
	_overlay.text = "ON" if _overlay.button_pressed else "OFF"
	var note := "" if DevTuning.is_default() else "\nNot default: runs stay off the leaderboard"
	_preview.text = DevTuning.preview() + note


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.PANEL_BG, 26, 24.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UiStyle.make_label("DEVELOPER", 40, Color("7fdcff"), HORIZONTAL_ALIGNMENT_CENTER))
	_ramp = _slider_row(box, "MAX DIFFICULTY AT", 4.0, 20.0, 0.5)
	_curve = _slider_row(box, "CURVE", 0.4, 1.6, 0.05)
	_minimum = _slider_row(box, "START DIFFICULTY", 0.0, 60.0, 5.0)
	_traffic = _slider_row(box, "TRAFFIC", 0.5, 1.5, 0.05)

	var overlay := _row(box, "SHOW IN HUD")
	_overlay = CheckButton.new()
	_overlay.add_theme_font_size_override("font_size", 22)
	var on := SettingsPanel._switch_icon(true)
	var off := SettingsPanel._switch_icon(false)
	for icon_name: String in ["checked", "checked_mirrored"]:
		_overlay.add_theme_icon_override(icon_name, on)
	for icon_name: String in ["unchecked", "unchecked_mirrored"]:
		_overlay.add_theme_icon_override(icon_name, off)
	_overlay.toggled.connect(func(_on: bool) -> void: _on_changed())
	overlay.add_child(_overlay)

	_preview = UiStyle.make_label("", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_preview.custom_minimum_size = Vector2(620.0, 0.0)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_preview)
	box.add_child(UiStyle.make_label("Curve < 1: harder early, then slower. Changes apply from the next traffic row.", 16,
		Color(1.0, 1.0, 1.0, 0.55), HORIZONTAL_ALIGNMENT_CENTER))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var reset := UiStyle.make_button("DEFAULTS", 24)
	reset.custom_minimum_size = Vector2(220.0, 56.0)
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	_back_button = UiStyle.make_button("BACK", 24)
	_back_button.custom_minimum_size = Vector2(220.0, 56.0)
	_back_button.pressed.connect(close)
	buttons.add_child(_back_button)


func _row(box: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := UiStyle.make_label(title, 22, Color.WHITE)
	label.custom_minimum_size = Vector2(230.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	box.add_child(row)
	return row


func _slider_row(box: VBoxContainer, title: String, min_value: float, max_value: float, step: float) -> HSlider:
	var row := _row(box, title)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(280.0, 44.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.add_theme_icon_override("grabber", SettingsPanel._grabber_icon(Color.WHITE))
	slider.add_theme_icon_override("grabber_highlight", SettingsPanel._grabber_icon(UiStyle.ACCENT))
	slider.add_theme_stylebox_override("slider", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.2), 6, 4.0))
	slider.add_theme_stylebox_override("grabber_area", UiStyle.flat(UiStyle.ACCENT, 6, 4.0))
	slider.add_theme_stylebox_override("grabber_area_highlight", UiStyle.flat(UiStyle.ACCENT, 6, 4.0))
	slider.value_changed.connect(func(_value: float) -> void: _on_changed())
	row.add_child(slider)
	var value := UiStyle.make_label("", 22, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	value.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(value)
	_values[slider] = value
	return slider
