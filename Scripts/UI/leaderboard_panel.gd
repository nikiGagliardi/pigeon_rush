class_name LeaderboardPanel
extends Control
## Classifica mondiale dal titolo: di sempre, della settimana e della sfida di oggi.
## In fondo: nome in classifica (modificabile) e cancellazione dei dati online (richiesta da Google Play).

signal closed

const BOARDS: Array[String] = ["all", "week", "daily"]
const BOARD_LABELS: Array[String] = ["ALL TIME", "THIS WEEK", "TODAY'S CHALLENGE"]
const LIST_SIZE := Vector2(660.0, 270.0)
const DELETE_CONFIRM_TIME := 4.0
const DIM := Color(1.0, 1.0, 1.0, 0.75)

var _board: String = "all"
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _status: Label
## Esito di nome e cancellazione, sotto la lista (lo stato della lista resta al centro).
var _message: Label
var _me: Label
var _name_label: Label
var _name_row: HBoxContainer
var _edit_row: HBoxContainer
var _name_edit: LineEdit
var _rename_button: Button
var _delete_button: Button
var _back_button: Button
var _busy: bool = false
var _delete_armed: float = 0.0
## Le risposte arrivate dopo un cambio di scheda vengono ignorate.
var _request_id: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func open() -> void:
	visible = true
	_set_message("")
	_show_name_row()
	_select(_board)
	_back_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if _delete_armed > 0.0:
		_delete_armed -= delta
		if _delete_armed <= 0.0:
			_delete_button.text = "DELETE MY ONLINE DATA"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		close()


# ------------------------------------------------------------------ classifica

func _select(board: String) -> void:
	_board = board
	for i in _tabs.size():
		_style_tab(_tabs[i], BOARDS[i] == board)
	_load_board()


func _load_board() -> void:
	_request_id += 1
	var request_id := _request_id
	_clear_list()
	_me.text = ""
	var client := GameServicesClient.instance
	if client == null or not client.enabled:
		_set_status("Online leaderboards are off in this build.")
		return
	_set_status("Loading…")
	var response := await client.fetch_leaderboard(_board)
	if request_id != _request_id or not is_inside_tree():
		return
	if not response.ok:
		_set_status("Can't reach the leaderboard right now.\nCheck your connection and try again.")
		return
	_show_board(response.data())


func _show_board(data: Dictionary) -> void:
	var entries: Variant = data.get("entries", [])
	var shown := 0
	if entries is Array:
		for raw: Variant in entries as Array:
			if raw is Dictionary:
				_list.add_child(_make_row(raw as Dictionary))
				shown += 1
	if shown == 0:
		_set_status("No scores yet: be the first!" if _board != "daily" else "Nobody has flown today's challenge yet.")
	else:
		_set_status("")

	var total := _int(data, "total")
	var me: Variant = data.get("me", null)
	if me is Dictionary:
		var me_data := me as Dictionary
		_me.text = "You: #%s of %s  •  best %s" % [
			UiFormat.number(_int(me_data, "rank")), UiFormat.number(total), UiFormat.number(_int(me_data, "score"))]
	else:
		_me.text = "Finish a run online to get on this board." if _board != "daily" else "Fly today's challenge to get on this board."


func _make_row(entry: Dictionary) -> Control:
	var is_me: bool = entry.get("isMe", false) == true
	var color := Palette.GOLD if is_me else Color.WHITE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)

	var rank := UiStyle.make_label("%d." % _int(entry, "rank"), 22, color, HORIZONTAL_ALIGNMENT_RIGHT)
	rank.custom_minimum_size = Vector2(70.0, 0.0)
	row.add_child(rank)

	var p_name := UiStyle.make_label("%s#%04d" % [str(entry.get("displayName", "?")), _int(entry, "nameSuffix")], 22, color)
	p_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_name.clip_text = true
	row.add_child(p_name)

	var score := UiStyle.make_label(UiFormat.number(_int(entry, "score")), 22, color, HORIZONTAL_ALIGNMENT_RIGHT)
	score.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(score)
	return row


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


# ------------------------------------------------------------------ nome e cancellazione

func _show_name_row() -> void:
	var client := GameServicesClient.instance
	var online := client != null and client.enabled
	_name_row.visible = true
	_edit_row.visible = false
	_name_label.text = "Your name: %s" % client.full_name() if online and client.has_account() else "Your name: (not online yet)"
	_rename_button.disabled = not online or _busy
	_delete_button.disabled = not online or _busy or not client.has_account()
	_delete_button.text = "DELETE MY ONLINE DATA"
	_delete_armed = 0.0


func _start_rename() -> void:
	var client := GameServicesClient.instance
	_name_row.visible = false
	_edit_row.visible = true
	_name_edit.text = client.display_name if client != null else ""
	_name_edit.grab_focus()
	_name_edit.select_all()


func _save_name() -> void:
	var client := GameServicesClient.instance
	if client == null or _busy:
		return
	var new_name := _name_edit.text.strip_edges()
	if new_name.length() < 3:
		_set_message("Names need at least 3 characters.", Palette.DANGER)
		return
	_busy = true
	_set_message("Saving…")
	var response := await client.rename(new_name)
	_busy = false
	if not is_inside_tree():
		return
	match response.status:
		200:
			_set_message("Name saved.")
			_show_name_row()
			_load_board()
		400:
			_set_message("Letters, numbers, spaces, _ - . only (3–16 characters).", Palette.DANGER)
		409:
			_set_message("That name is taken. Try another one.", Palette.DANGER)
		_:
			_set_message("Can't reach the server. Try again later.", Palette.DANGER)


## Primo tocco: chiede conferma. Secondo tocco entro DELETE_CONFIRM_TIME: cancella.
func _on_delete_pressed() -> void:
	var client := GameServicesClient.instance
	if client == null or _busy:
		return
	if _delete_armed <= 0.0:
		_delete_armed = DELETE_CONFIRM_TIME
		_delete_button.text = "TAP AGAIN TO DELETE"
		_set_message("This deletes your online name, scores and ranks. Your local records stay on this phone.", Palette.DANGER)
		return
	_delete_armed = 0.0
	_busy = true
	_set_message("Deleting…")
	var deleted := await client.delete_account()
	_busy = false
	if not is_inside_tree():
		return
	_show_name_row()
	if deleted:
		_set_message("Your online data has been deleted.")
		_load_board()
	else:
		_set_message("Can't reach the server. Try again later.", Palette.DANGER)


# ------------------------------------------------------------------ costruzione

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
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UiStyle.make_label("WORLD LEADERBOARD", 44, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	for i in BOARDS.size():
		var tab := UiStyle.make_button(BOARD_LABELS[i], 22)
		tab.custom_minimum_size = Vector2(210.0 if i < 2 else 250.0, 52.0)
		var board := BOARDS[i]
		tab.pressed.connect(func() -> void: _select(board))
		tabs.add_child(tab)
		_tabs.append(tab)

	var list_area := Control.new()
	list_area.custom_minimum_size = LIST_SIZE
	list_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(list_area)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_area.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_status = UiStyle.make_label("", 22, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_area.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_message = UiStyle.make_label("", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(LIST_SIZE.x, 0.0)
	_message.visible = false
	box.add_child(_message)

	_me = UiStyle.make_label("", 22, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_me)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	box.add_child(bottom)

	_name_row = HBoxContainer.new()
	_name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_row.add_theme_constant_override("separation", 12)
	bottom.add_child(_name_row)
	_name_label = UiStyle.make_label("", 20, DIM)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_row.add_child(_name_label)
	_rename_button = _small_button("CHANGE NAME", 200.0)
	_rename_button.pressed.connect(_start_rename)
	_name_row.add_child(_rename_button)

	_edit_row = HBoxContainer.new()
	_edit_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_row.add_theme_constant_override("separation", 12)
	bottom.add_child(_edit_row)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Your name"
	_name_edit.custom_minimum_size = Vector2(240.0, 52.0)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _save_name())
	_edit_row.add_child(_name_edit)
	var save := _small_button("SAVE", 110.0)
	save.pressed.connect(_save_name)
	_edit_row.add_child(save)
	var cancel := _small_button("CANCEL", 130.0)
	cancel.pressed.connect(_show_name_row)
	_edit_row.add_child(cancel)

	_delete_button = _small_button("DELETE MY ONLINE DATA", 300.0)
	_delete_button.add_theme_stylebox_override("normal", UiStyle.flat(Palette.DANGER.darkened(0.15), 14))
	_delete_button.add_theme_stylebox_override("hover", UiStyle.flat(Palette.DANGER, 14))
	_delete_button.add_theme_color_override("font_color", Color.WHITE)
	_delete_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_delete_button.pressed.connect(_on_delete_pressed)

	_back_button = UiStyle.make_button("BACK", 26)
	_back_button.custom_minimum_size = Vector2(200.0, 56.0)
	_back_button.pressed.connect(close)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	actions.add_child(_delete_button)
	actions.add_child(_back_button)
	box.add_child(actions)


func _small_button(text: String, width: float) -> Button:
	var button := UiStyle.make_button(text, 20)
	button.custom_minimum_size = Vector2(width, 52.0)
	return button


func _style_tab(tab: Button, selected: bool) -> void:
	var color := UiStyle.ACCENT if selected else Color(1.0, 1.0, 1.0, 0.18)
	tab.add_theme_stylebox_override("normal", UiStyle.flat(color, 14))
	tab.add_theme_color_override("font_color", UiStyle.TEXT_DARK if selected else Color.WHITE)


static func _int(d: Dictionary, key: String) -> int:
	var value: Variant = d.get(key, 0)
	if value is int:
		return value as int
	if value is float:
		return int(value as float)
	return 0
