class_name MissionsPanel
extends Control
## Missioni giornaliere dal titolo: tre obiettivi uguali per tutti, nuovi ogni giorno a mezzanotte UTC.
## Il progresso lo calcola il server sulle partite partite online (con ticket); qui si mostra e si riscuote.

signal closed

const LIST_WIDTH := 640.0
## Tre righe da 116 px più gli spazi.
const LIST_HEIGHT := 368.0
const BAR_SIZE := Vector2(300.0, 18.0)
const DIM := Color(1.0, 1.0, 1.0, 0.75)

var _list: VBoxContainer
var _status: Label
var _reset: Label
var _balance: Label
var _message: Label
var _back_button: Button
var _busy: bool = false
var _request_id: int = 0
var _reset_refresh: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func open() -> void:
	visible = true
	_set_message("")
	_update_balance()
	_update_reset()
	_load()
	_back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_reset_refresh -= delta
	if _reset_refresh <= 0.0:
		_update_reset()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		close()


func _load() -> void:
	_request_id += 1
	var request_id := _request_id
	_clear_list()
	var client := GameServicesClient.instance
	if client == null or not client.enabled:
		_set_status("Missions are off in this build.")
		return
	_set_status("Loading…")
	var response := await client.fetch_missions()
	if request_id != _request_id or not is_inside_tree():
		return
	if not response.ok:
		_set_status("Can't reach the server right now.\nMissions need a connection.")
		return
	_show(response.data())


func _show(data: Dictionary) -> void:
	_clear_list()
	_update_balance()
	var missions: Variant = data.get("missions", [])
	var shown := 0
	if missions is Array:
		for raw: Variant in missions as Array:
			if raw is Dictionary:
				_list.add_child(_make_row(raw as Dictionary))
				shown += 1
	_set_status("" if shown > 0 else "No missions today.")


func _claim(mission_id: String, button: Button) -> void:
	var client := GameServicesClient.instance
	if client == null or _busy:
		return
	_busy = true
	button.disabled = true
	_set_message("")
	var response := await client.claim_mission(mission_id)
	_busy = false
	if not is_inside_tree():
		return
	match response.status:
		200:
			if GameAudio.instance != null:
				GameAudio.instance.play_ui(GameAudio.Sfx.COMBO, 0.0, 1.3)
			_show(response.data())
		404:
			_set_message("New missions are out: this one has expired.", Palette.DANGER)
			_load()
		422:
			_set_message("Not complete yet.", Palette.DANGER)
			_load()
		_:
			button.disabled = false
			_set_message("Can't reach the server. Try again later.", Palette.DANGER)


func _make_row(mission: Dictionary) -> Control:
	var target := maxi(1, _int(mission, "target"))
	var progress := mini(_int(mission, "progress"), target)
	var complete: bool = mission.get("complete", false) == true
	var claimed: bool = mission.get("claimed", false) == true
	var reward := _int(mission, "reward")

	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Color(1.0, 1.0, 1.0, 0.06) if not complete or claimed else Color(Palette.GOLDEN_CRUMB, 0.16)
	row.add_theme_stylebox_override("panel", UiStyle.flat(bg, 16, 10.0))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text)
	var title_color := DIM if claimed else Color.WHITE
	text.add_child(UiStyle.make_label(str(mission.get("title", "?")), 24, title_color))
	text.alignment = BoxContainer.ALIGNMENT_CENTER

	var bar_line := HBoxContainer.new()
	bar_line.add_theme_constant_override("separation", 12)
	bar_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(bar_line)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = target
	bar.value = progress
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.18), 9, 0.0))
	bar.add_theme_stylebox_override("fill", UiStyle.flat(Palette.GOLDEN_CRUMB if complete else UiStyle.ACCENT, 9, 0.0))
	bar_line.add_child(bar)
	bar_line.add_child(UiStyle.make_label("%s / %s" % [UiFormat.number(progress), UiFormat.number(target)], 20, DIM))

	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 4)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(side)
	side.add_child(UiStyle.make_label("+%d" % reward, 26, Palette.GOLDEN_CRUMB, HORIZONTAL_ALIGNMENT_CENTER))
	var button := UiStyle.make_button("CLAIMED" if claimed else "CLAIM", 22)
	button.custom_minimum_size = Vector2(150.0, 50.0)
	button.disabled = claimed or not complete
	if button.disabled:
		button.add_theme_stylebox_override("disabled", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.15), 18))
		button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.5))
	var mission_id := str(mission.get("id", ""))
	button.pressed.connect(func() -> void: _claim(mission_id, button))
	side.add_child(button)
	return row


func _update_balance() -> void:
	var client := GameServicesClient.instance
	var value := maxi(0, client.balance) if client != null else 0
	_balance.text = "Golden crumbs: %s" % UiFormat.number(value)


func _update_reset() -> void:
	var left := GameServicesClient.seconds_to_missions_reset()
	_reset.text = "New missions in %dh %02dm" % [floori(left / 3600.0), floori((left % 3600) / 60.0)]
	_reset_refresh = float(left % 60) + 0.5


func _clear_list() -> void:
	for child in _list.get_children():
		child.queue_free()


func _set_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func _set_message(text: String, color: Color = DIM) -> void:
	_message.text = text
	_message.visible = not text.is_empty()
	_message.add_theme_color_override("font_color", color)


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

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.PANEL_BG, 26, 24.0))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(UiStyle.make_label("DAILY MISSIONS", 44, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_reset = UiStyle.make_label("", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_reset)

	var list_area := Control.new()
	list_area.custom_minimum_size = Vector2(LIST_WIDTH, LIST_HEIGHT)
	list_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(list_area)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_area.add_child(_list)
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status = UiStyle.make_label("", 22, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_area.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	box.add_child(UiStyle.make_label("Only runs started online count.", 18, Color(1.0, 1.0, 1.0, 0.55),
		HORIZONTAL_ALIGNMENT_CENTER))
	_message = UiStyle.make_label("", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_message.visible = false
	box.add_child(_message)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	box.add_child(bottom)
	_balance = UiStyle.make_label("", 24, Palette.GOLDEN_CRUMB)
	_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_balance)
	_back_button = UiStyle.make_button("BACK", 26)
	_back_button.custom_minimum_size = Vector2(200.0, 56.0)
	_back_button.pressed.connect(close)
	bottom.add_child(_back_button)


static func _int(d: Dictionary, key: String) -> int:
	var value: Variant = d.get(key, 0)
	if value is int:
		return value as int
	if value is float:
		return int(value as float)
	return 0
