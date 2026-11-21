class_name ShopPanel
extends Control
## Negozio dal titolo: specie, piumaggi e accessori, con il piccione in 3D che gira e prova ogni oggetto.
## Il catalogo (prezzi, cosa è in vendita) arriva dal server; offline si possono indossare solo gli oggetti
## già posseduti. Cosa indossi lo salva Main (look_changed).

signal look_changed(look: BirdLook)
signal closed

const DIM := Color(1.0, 1.0, 1.0, 0.75)
const TIER_COLORS := {"common": Color("8f9bb3"), "rare": Color("4fa3ff"), "special": Color("ffd54a")}
const PREVIEW_SIZE := Vector2i(420, 400)

## Oggetto del catalogo mostrato in una scheda.
class Item:
	var id: StringName
	var category: String
	var price: int = 0
	var tier: String = "common"
	var owned: bool = false
	var available_until: String = ""

var _equipped := BirdLook.new()
var _preview_look := BirdLook.new()
var _items: Dictionary[StringName, Item] = {}
var _online: bool = false
var _category: String = BirdCatalog.CATEGORY_BIRD
var _selected: StringName = BirdCatalog.PIGEON
var _busy: bool = false
var _request_id: int = 0

var _bird: PigeonModel
var _tabs: Dictionary[String, Button] = {}
var _grid: GridContainer
var _balance: Label
var _item_name: Label
var _item_info: Label
var _action: Button
var _message: Label
var _back_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	set_process(false)


func open(look: BirdLook) -> void:
	_equipped = look.duplicate_look()
	_preview_look = look.duplicate_look()
	_bird.set_look(_preview_look)
	_category = BirdCatalog.CATEGORY_BIRD
	_selected = _equipped.species
	_set_message("")
	_fill_from_cache()
	visible = true
	set_process(true)
	_refresh()
	_back_button.grab_focus()
	_load()


func close() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	_bird.rotation.y += delta * 0.6
	_bird.flap(delta, 7.0, 0.55)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		close()


# ------------------------------------------------------------------ dati

## Prima del server: gli oggetti gratuiti e quelli già comprati (cache), così si può indossare anche offline.
func _fill_from_cache() -> void:
	_items.clear()
	_online = false
	var client := GameServicesClient.instance
	var owned: PackedStringArray = client.owned_items if client != null else PackedStringArray()
	for id: StringName in BirdCatalog.ITEMS:
		if BirdCatalog.FREE.has(id) or owned.has(str(id)):
			var item := Item.new()
			item.id = id
			item.category = BirdCatalog.category_of(id)
			item.owned = true
			_items[id] = item
	_add_none_items()


func _add_none_items() -> void:
	for category: String in [BirdCatalog.CATEGORY_HEAD, BirdCatalog.CATEGORY_FACE, BirdCatalog.CATEGORY_NECK]:
		var key := StringName("%s:none" % category)
		var item := Item.new()
		item.id = BirdCatalog.NONE
		item.category = category
		item.owned = true
		_items[key] = item


func _load() -> void:
	_request_id += 1
	var request_id := _request_id
	var client := GameServicesClient.instance
	if client == null or not client.enabled:
		_set_message("The shop is off in this build.")
		return
	_set_message("Loading…")
	var response := await client.fetch_shop()
	if request_id != _request_id or not is_inside_tree():
		return
	if not response.ok:
		_set_message("Offline: you can wear what you own. Buying needs a connection.")
		_refresh()
		return
	_apply(response.data())
	_set_message("")


func _apply(data: Dictionary) -> void:
	_items.clear()
	_online = true
	var raw_items: Variant = data.get("items", [])
	if raw_items is Array:
		for raw: Variant in raw_items as Array:
			if not raw is Dictionary:
				continue
			var d := raw as Dictionary
			var id := StringName(str(d.get("id", "")))
			if not BirdCatalog.knows(id): # venduto dal server ma non disegnabile da questa versione
				continue
			var item := Item.new()
			item.id = id
			item.category = BirdCatalog.category_of(id)
			item.price = int(d.get("price", 0))
			item.tier = str(d.get("tier", "common"))
			item.owned = d.get("owned", false) == true or item.price == 0
			var until: Variant = d.get("availableUntil", null)
			item.available_until = str(until) if until is String else ""
			_items[id] = item
	_add_none_items()
	_refresh()


func _item(category: String, id: StringName) -> Item:
	if id == BirdCatalog.NONE:
		return _items.get(StringName("%s:none" % category))
	return _items.get(id)


# ------------------------------------------------------------------ azioni

func _select(id: StringName) -> void:
	_selected = id
	_preview_look.set_item(_category, id)
	_bird.set_look(_preview_look)
	_set_message("")
	_refresh()


func _select_category(category: String) -> void:
	_category = category
	_selected = _equipped.get_item(category)
	_preview_look = _equipped.duplicate_look()
	_bird.set_look(_preview_look)
	_refresh()


func _on_action() -> void:
	var item := _item(_category, _selected)
	if item == null or _busy:
		return
	if item.owned:
		_equipped.set_item(_category, _selected)
		look_changed.emit(_equipped.duplicate_look())
		_refresh()
		return
	_buy(item)


func _buy(item: Item) -> void:
	var client := GameServicesClient.instance
	if client == null:
		return
	_busy = true
	_action.disabled = true
	_set_message("")
	var response := await client.buy_item(str(item.id))
	_busy = false
	if not is_inside_tree():
		return
	match response.status:
		200:
			_apply(response.data())
			if GameAudio.instance != null:
				GameAudio.instance.play_ui(GameAudio.Sfx.COMBO, 0.0, 1.2)
			_equipped.set_item(_category, item.id) # appena comprato: lo indossi subito
			look_changed.emit(_equipped.duplicate_look())
			_set_message("%s is yours!" % BirdCatalog.name_of(item.id))
		409:
			_set_message("Not enough golden crumbs.", Palette.DANGER)
		404:
			_set_message("This item is no longer on sale.", Palette.DANGER)
			_load()
		_:
			_set_message("Can't reach the server. Try again later.", Palette.DANGER)
	_refresh()


# ------------------------------------------------------------------ vista

func _refresh() -> void:
	var client := GameServicesClient.instance
	var balance := maxi(0, client.balance) if client != null else 0
	_balance.text = "Golden crumbs: %s" % UiFormat.number(balance)
	for category: String in _tabs:
		_tabs[category].button_pressed = category == _category

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var shown: Array[Item] = []
	var none := _item(_category, BirdCatalog.NONE)
	if none != null:
		shown.append(none)
	for id: StringName in BirdCatalog.ids_in(_category):
		var item := _item(_category, id)
		if item != null:
			shown.append(item)
	for item: Item in shown:
		_grid.add_child(_make_card(item))

	var selected := _item(_category, _selected)
	_item_name.text = BirdCatalog.name_of(_selected)
	if selected == null:
		_item_info.text = ""
		_action.visible = false
		return
	_action.visible = true
	var equipped := _equipped.get_item(_category) == _selected
	if selected.owned:
		_item_info.text = "Equipped" if equipped else "Owned"
		_action.text = "EQUIPPED" if equipped else "EQUIP"
		_action.disabled = equipped or _busy
	else:
		var tier_name: String = {"common": "Common", "rare": "Rare", "special": "Special"}.get(selected.tier, "")
		_item_info.text = str(tier_name) + ("  •  until %s" % selected.available_until.substr(0, 10) if not selected.available_until.is_empty() else "")
		var affordable := balance >= selected.price
		_action.text = "BUY  %s" % UiFormat.number(selected.price) if affordable else "NEED %s" % UiFormat.number(selected.price)
		_action.disabled = not affordable or not _online or _busy


func _make_card(item: Item) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(196.0, 92.0)
	card.focus_mode = Control.FOCUS_ALL
	var selected := item.id == _selected
	var tier_color: Color = TIER_COLORS.get(item.tier, TIER_COLORS["common"])
	var bg := Color(1.0, 1.0, 1.0, 0.16) if selected else Color(1.0, 1.0, 1.0, 0.07)
	var style := UiStyle.flat(bg, 14, 10.0)
	style.border_color = tier_color if not item.owned or item.price > 0 else Color(1.0, 1.0, 1.0, 0.25)
	style.set_border_width_all(4 if selected else 2)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_label := UiStyle.make_label(BirdCatalog.name_of(item.id), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var status := ""
	var status_color := DIM
	if _equipped.get_item(item.category) == item.id:
		status = "EQUIPPED"
		status_color = Palette.INFO
	elif item.owned:
		status = "OWNED" if item.price > 0 else "FREE"
	else:
		status = UiFormat.number(item.price)
		status_color = Palette.GOLDEN_CRUMB
	var status_label := UiStyle.make_label(status, 18, status_color, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status_label)
	var id := item.id
	card.pressed.connect(func() -> void: _select(id))
	return card


func _set_message(text: String, color: Color = DIM) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.PANEL_BG, 26, 22.0))
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiStyle.make_label("SHOP", 44, Palette.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_balance = UiStyle.make_label("", 26, Palette.GOLDEN_CRUMB, HORIZONTAL_ALIGNMENT_RIGHT)
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_balance)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)

	# anteprima 3D in un mondo tutto suo
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	container.stretch = true
	left.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("223049")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.15, 3.4), Vector3(0.0, 0.08, 0.0), Vector3.UP)
	_bird = PigeonModel.new()
	viewport.add_child(_bird)
	_item_name = UiStyle.make_label("", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_item_name)
	_item_info = UiStyle.make_label("", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_item_info)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for category: String in BirdCatalog.CATEGORIES:
		var tab := UiStyle.make_button(str(BirdCatalog.CATEGORY_TITLES[category]), 20)
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(118.0, 48.0)
		tab.add_theme_stylebox_override("normal", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.12), 14))
		tab.add_theme_color_override("font_color", Color.WHITE)
		var c := category
		tab.pressed.connect(func() -> void: _select_category(c))
		tabs.add_child(tab)
		_tabs[category] = tab

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(624.0, 304.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	right.add_child(actions)
	_action = UiStyle.make_button("EQUIP", 26)
	_action.custom_minimum_size = Vector2(300.0, 60.0)
	_action.pressed.connect(_on_action)
	_action.add_theme_stylebox_override("disabled", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.15), 18))
	_action.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.6))
	actions.add_child(_action)
	_back_button = UiStyle.make_button("BACK", 26)
	_back_button.custom_minimum_size = Vector2(200.0, 60.0)
	_back_button.pressed.connect(close)
	actions.add_child(_back_button)

	_message = UiStyle.make_label("", 20, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_message.custom_minimum_size = Vector2(624.0, 0.0)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_message)
