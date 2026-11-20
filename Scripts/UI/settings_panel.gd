class_name SettingsPanel
extends Control
## Impostazioni, dal titolo e dalla pausa: volume, vibrazione, suggerimenti, informativa privacy.
## DEVELOPER (taratura della difficoltà): sempre nelle build di debug; in quelle di rilascio si sblocca
## toccando 7 volte la versione in fondo.
## Le modifiche valgono subito (changed); il salvataggio su file lo fa Main alla chiusura.

signal changed(volume: float, vibration: bool)
signal tips_reset
signal closed

const PRIVACY_URL := "https://moesagames.ch/privacy"
const DIM := Color(1.0, 1.0, 1.0, 0.75)

var _volume: HSlider
var _volume_value: Label
var _vibration: CheckButton
var _tips_button: Button
var _back_button: Button
var _message: Label
var _dev_button: Button
var _dev_panel: DevPanel
var _version_taps: int = 0
## Taps che mancano allo sblocco del pannello DEVELOPER nelle build di rilascio.
const UNLOCK_TAPS := 7
## Durante open() i controlli si impostano senza mandare changed.
var _loading: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func open(volume: float, vibration: bool) -> void:
	_loading = true
	_volume.value = roundf(volume * 100.0)
	_vibration.button_pressed = vibration
	_loading = false
	_refresh_labels()
	_message.text = ""
	_tips_button.disabled = false
	_dev_button.visible = DevTuning.panel_available()
	_dev_panel.visible = false
	_version_taps = 0
	visible = true
	_back_button.grab_focus()


## Tasto indietro di Android: prima il pannello DEVELOPER, poi le impostazioni.
func close_top() -> void:
	if _dev_panel.visible:
		_dev_panel.close()
	else:
		close()


func close() -> void:
	if not visible:
		return
	if _dev_panel.visible:
		_dev_panel.close()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _dev_panel.visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		close()


func _on_changed() -> void:
	_refresh_labels()
	if not _loading:
		changed.emit(_volume.value / 100.0, _vibration.button_pressed)


func _on_tips_pressed() -> void:
	tips_reset.emit()
	_tips_button.disabled = true
	_message.text = "Tips will show again in your next run."


func _on_version_input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tap or DevTuning.panel_available():
		return
	_version_taps += 1
	var left := UNLOCK_TAPS - _version_taps
	if left > 0 and left <= 3:
		_message.text = "%d more taps for developer options" % left
	elif left <= 0:
		DevTuning.unlocked = true
		DevTuning.save()
		_dev_button.visible = true
		_message.text = "Developer options unlocked"


func _open_dev() -> void:
	_dev_panel.open()


func _on_dev_closed() -> void:
	_dev_button.grab_focus()


func _refresh_labels() -> void:
	_volume_value.text = "%d%%" % int(_volume.value) if _volume.value > 0.0 else "OFF"
	_vibration.text = "ON" if _vibration.button_pressed else "OFF"


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := UiStyle.make_panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	box.add_child(UiStyle.make_label("SETTINGS", 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))

	# volume
	var sound := _row(box, "SOUND")
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 100.0
	_volume.step = 5.0
	_volume.custom_minimum_size = Vector2(300.0, 48.0)
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.add_theme_icon_override("grabber", _grabber_icon(Color.WHITE))
	_volume.add_theme_icon_override("grabber_highlight", _grabber_icon(UiStyle.ACCENT))
	_volume.add_theme_stylebox_override("slider", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.2), 6, 4.0))
	_volume.add_theme_stylebox_override("grabber_area", UiStyle.flat(UiStyle.ACCENT, 6, 4.0))
	_volume.add_theme_stylebox_override("grabber_area_highlight", UiStyle.flat(UiStyle.ACCENT, 6, 4.0))
	_volume.value_changed.connect(func(_value: float) -> void: _on_changed())
	sound.add_child(_volume)
	_volume_value = UiStyle.make_label("", 24, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_volume_value.custom_minimum_size = Vector2(80.0, 0.0)
	sound.add_child(_volume_value)

	# vibrazione
	var vibration := _row(box, "VIBRATION")
	_vibration = CheckButton.new()
	_vibration.add_theme_font_size_override("font_size", 24)
	# interruttore grande, comodo da toccare
	var on := _switch_icon(true)
	var off := _switch_icon(false)
	for icon_name: String in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		_vibration.add_theme_icon_override(icon_name, on)
	for icon_name: String in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		_vibration.add_theme_icon_override(icon_name, off)
	_vibration.toggled.connect(func(_on: bool) -> void: _on_changed())
	vibration.add_child(_vibration)

	box.add_child(_spacer(4.0))

	_tips_button = _wide_button("SHOW TIPS AGAIN")
	_tips_button.pressed.connect(_on_tips_pressed)
	box.add_child(_centered(_tips_button))

	var privacy := _wide_button("PRIVACY POLICY")
	privacy.pressed.connect(func() -> void: OS.shell_open(PRIVACY_URL))
	box.add_child(_centered(privacy))

	_dev_button = _wide_button("DEVELOPER")
	_dev_button.add_theme_color_override("font_color", Color("1d4f66"))
	_dev_button.pressed.connect(_open_dev)
	box.add_child(_centered(_dev_button))

	_message = UiStyle.make_label("", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_message)

	_back_button = UiStyle.make_button("BACK")
	_back_button.pressed.connect(close)
	box.add_child(_centered(_back_button))

	var version := UiStyle.make_label("Pigeon Rush v%s  •  Moesa Games" % GameServicesClient.game_version(), 16,
		Color(1.0, 1.0, 1.0, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	version.mouse_filter = Control.MOUSE_FILTER_STOP
	version.gui_input.connect(_on_version_input)
	box.add_child(version)

	_dev_panel = DevPanel.new()
	add_child(_dev_panel)
	_dev_panel.closed.connect(_on_dev_closed)


## Riga "ETICHETTA  [controllo]": restituisce il contenitore a cui aggiungere i controlli.
func _row(box: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var label := UiStyle.make_label(title, 26, Color.WHITE)
	label.custom_minimum_size = Vector2(190.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	box.add_child(row)
	return row


func _wide_button(text: String) -> Button:
	var button := UiStyle.make_button(text, 26)
	button.custom_minimum_size = Vector2(360.0, 60.0)
	return button


func _centered(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.add_child(control)
	return center


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


## Interruttore a pillola 72×38: acceso giallo con il pallino a destra, spento grigio a sinistra.
static func _switch_icon(on: bool) -> ImageTexture:
	var w := 72
	var h := 38
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var track := UiStyle.ACCENT if on else Color(1.0, 1.0, 1.0, 0.25)
	var radius := h * 0.5
	var knob := Vector2(w - radius, radius) if on else Vector2(radius, radius)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			# pillola: distanza dal segmento tra i due centri delle estremità
			var cx := clampf(p.x, radius, w - radius)
			var track_alpha := clampf(radius - p.distance_to(Vector2(cx, radius)), 0.0, 1.0)
			var color := Color(track, track.a * track_alpha)
			var knob_alpha := clampf(radius - 4.0 - p.distance_to(knob), 0.0, 1.0)
			if knob_alpha > 0.0:
				color = color.lerp(Color.WHITE, knob_alpha)
				color.a = maxf(color.a, knob_alpha)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## Pallino del cursore, disegnato a runtime (niente texture da importare).
static func _grabber_icon(color: Color) -> ImageTexture:
	var size := 32
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)
			var alpha := clampf(size * 0.5 - 1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)
