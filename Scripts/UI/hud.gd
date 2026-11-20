class_name Hud
extends Control
## HUD costruito da codice. Legge lo stato della sessione ogni frame e aggiorna i testi solo se cambiano.

signal pause_pressed

const FONT_COLOR := &"font_color"

var _score: Label
var _distance: Label
var _best: Label
## Riga del pannello DEVELOPER: difficoltà e traffico in tempo reale.
var _dev: Label
var _combo: Label
var _speed: Label
var _lock: Label
var _low_fly: Label
var _ammo_count: Label
var _ammo: IconBar
var _boost: IconBar
var _ammo_panel: PanelContainer
var _route_name: Label
var _route_bar: ProgressBar
var _conditions: Label
var _banner: Control
var _banner_title: Label
var _banner_subtitle: Label
var _banner_bonus: Label
var _banner_time: float = 0.0
var _banner_delay: float = 0.0

var _last_score: int = -1
var _last_distance: int = -1
var _last_combo: int = -1
var _last_boost: int = -1
var _last_ammo: int = -1
var _combo_pop: float = 0.0
var _ammo_pop: float = 0.0
var _empty_blink: float = 0.0
var _ammo_text_color: Color = Color.WHITE
var _last_segment: int = -1
var _last_lap: int = -1

const BANNER_TIME := 2.8
## Suggerimenti delle prime partite (TutorialHints): quanto restano a schermo.
const HINT_TIME := 4.0

var _hint: PanelContainer
var _hint_label: Label
var _hint_time: float = 0.0
var _hint_queue: PackedStringArray = PackedStringArray()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- in alto a sinistra: punteggio ---
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 0)
	_score = UiStyle.make_label("0", 48, Color.WHITE)
	_distance = UiStyle.make_label("0 m", 24, Color(1.0, 1.0, 1.0, 0.9))
	_best = UiStyle.make_label("", 20, Palette.GOLD)
	left.add_child(_score)
	left.add_child(_distance)
	left.add_child(_best)
	_dev = UiStyle.make_label("", 18, Color("7fdcff"))
	_dev.visible = false
	left.add_child(_dev)
	add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 22)

	# --- in alto a destra: pausa e boost ---
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 8)

	var pause := Button.new()
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	pause.custom_minimum_size = Vector2(64.0, 56.0)
	pause.add_theme_font_size_override("font_size", 26)
	pause.add_theme_stylebox_override("normal", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.35), 12))
	pause.add_theme_stylebox_override("hover", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.5), 12))
	pause.add_theme_stylebox_override("pressed", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.6), 12))
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	var pause_row := HBoxContainer.new()
	pause_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_row.alignment = BoxContainer.ALIGNMENT_END
	pause_row.add_child(pause)
	right.add_child(pause_row)

	var boost_row := HBoxContainer.new()
	boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boost_row.alignment = BoxContainer.ALIGNMENT_END
	boost_row.add_theme_constant_override("separation", 10)
	boost_row.add_child(UiStyle.make_label("BOOST", 18, Color(1.0, 1.0, 1.0, 0.8)))
	_boost = IconBar.new()
	_boost.max_value = GameConfig.MAX_BOOST_STACKS
	_boost.shape = IconBar.IconShape.SEGMENT
	_boost.on_color = Palette.INFO
	_boost.icon_size = 30.0
	_boost.gap = 4.0
	boost_row.add_child(_boost)
	right.add_child(boost_row)

	_speed = UiStyle.make_label("", 20, Palette.INFO, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_speed)

	add_child(right)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 22)

	# --- centro in alto: tratta e avanzamento, sotto la combo ---
	var route := VBoxContainer.new()
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route.add_theme_constant_override("separation", 4)
	_route_name = UiStyle.make_label("", 20, Color(1.0, 1.0, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	route.add_child(_route_name)
	_route_bar = ProgressBar.new()
	_route_bar.show_percentage = false
	_route_bar.custom_minimum_size = Vector2(300.0, 10.0)
	_route_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_bar.add_theme_stylebox_override("background", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.4), 5, 0.0))
	_route_bar.add_theme_stylebox_override("fill", UiStyle.flat(Palette.INFO, 5, 0.0))
	route.add_child(_route_bar)
	_conditions = UiStyle.make_label("", 18, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	route.add_child(_conditions)
	add_child(route)
	route.grow_horizontal = Control.GROW_DIRECTION_BOTH
	route.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)

	_combo = UiStyle.make_label("", 44, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_combo)
	_combo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 100)
	_combo.pivot_offset = Vector2(0.0, 30.0)

	# --- centro in basso: suggerimenti + pannello munizioni ---
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 6)
	bottom.add_child(_build_hint())
	_lock = UiStyle.make_label("TARGET LOCKED! Drop now", 30, Palette.RETICLE, HORIZONTAL_ALIGNMENT_CENTER)
	_low_fly = UiStyle.make_label("LOW FLYING  x1.5", 22, Palette.INFO, HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_lock)
	bottom.add_child(_low_fly)
	bottom.add_child(_build_ammo_panel())
	add_child(bottom)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_lock.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_low_fly.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_build_banner()


## Bonus di meteo e ora sotto la barra della tratta ("NIGHT ×1.3  ·  FOG ×1.2"); vuoto = nascosto.
func set_conditions(text: String) -> void:
	_conditions.text = text
	_conditions.visible = not text.is_empty()


## Cartello all'ingresso di una tratta: "WELCOME TO TICINO", nome della tratta, bonus.
## delay: attesa prima di mostrarlo (a inizio partita, dopo il "GO!").
func show_route_banner(title: String, subtitle: String, bonus: int, delay: float = 0.0) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_bonus.text = "+%s" % UiFormat.number(bonus) if bonus > 0 else ""
	_banner_time = BANNER_TIME
	_banner_delay = delay
	_banner.visible = delay <= 0.0
	_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_banner.scale = Vector2.ONE * 1.15


func set_best(best: int) -> void:
	_best.text = "Best %s" % UiFormat.number(best) if best > 0 else ""


func refresh(dt: float, session: GameSession, locked: bool, low_flying: bool) -> void:
	var score := session.score
	if score.score != _last_score:
		_last_score = score.score
		_score.text = UiFormat.number(_last_score)

	var metres := int(score.distance)
	if metres != _last_distance:
		_last_distance = metres
		_distance.text = "%s m" % UiFormat.number(metres)

	_refresh_ammo(dt, session.ammo)

	var stacks := session.speed.boost_stacks
	_boost.set_value(stacks)
	if stacks != _last_boost:
		_last_boost = stacks
		_speed.text = "SPEED x%s" % UiFormat.multiplier(session.speed.multiplier) if stacks > 0 else ""

	var combo := score.combo
	if combo != _last_combo:
		if combo > _last_combo and combo >= 2:
			_combo_pop = 1.0
		_last_combo = combo
		_combo.text = "COMBO x%d" % score.combo_multiplier if combo >= 2 else ""

	_combo_pop = maxf(0.0, _combo_pop - dt * 4.0)
	var pop_scale := 1.0 + _combo_pop * 0.35
	_combo.scale = Vector2(pop_scale, pop_scale)
	var combo_alpha := 0.5 + 0.5 * clampf(score.combo_time_left * 2.0, 0.0, 1.0) if combo >= 2 else 0.0
	_combo.modulate = Color(1.0, 1.0, 1.0, combo_alpha)

	_fade_to(_lock, 1.0 if locked and session.ammo > 0 else 0.0, dt)
	_fade_to(_low_fly, 1.0 if low_flying else 0.0, dt)

	_dev.visible = DevTuning.show_overlay
	if _dev.visible:
		var segment := session.route.segment
		_dev.text = "DIFF %d%%  •  TRAFFIC x%.2f (segment x%.2f)  •  %s" % [roundi(session.difficulty * 100.0),
			DevTuning.traffic_multiplier() * segment.traffic, segment.traffic, segment.id]

	_refresh_route(session.route)
	_tick_banner(dt)
	_tick_hint(dt)


## Suggerimento sopra le munizioni; se ce n'è già uno, arriva dopo.
func show_hint(text: String) -> void:
	if text.is_empty():
		return
	if _hint_time > 0.0:
		if not _hint_queue.has(text):
			_hint_queue.append(text)
		return
	_hint_label.text = text
	_hint_time = HINT_TIME
	_hint.visible = true
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)


func clear_hints() -> void:
	_hint_queue.clear()
	_hint_time = 0.0
	_hint.visible = false


func _tick_hint(dt: float) -> void:
	if _hint_time <= 0.0:
		return
	_hint_time = maxf(0.0, _hint_time - dt)
	var shown := HINT_TIME - _hint_time
	_hint.modulate = Color(1.0, 1.0, 1.0, minf(shown / 0.25, 1.0) * minf(_hint_time / 0.4, 1.0))
	if _hint_time <= 0.0:
		_hint.visible = false
		if not _hint_queue.is_empty():
			var next := _hint_queue[0]
			_hint_queue.remove_at(0)
			show_hint(next)


func _build_hint() -> Control:
	_hint = PanelContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.flat(Color(0.05, 0.07, 0.12, 0.78), 14, 14.0)
	style.border_color = Palette.GOLD
	style.set_border_width_all(2)
	_hint.add_theme_stylebox_override("panel", style)
	_hint_label = UiStyle.make_label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(620.0, 0.0)
	_hint.add_child(_hint_label)
	_hint.visible = false
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_hint)
	return center


func _refresh_route(route: RouteTracker) -> void:
	if route.segment_index != _last_segment or route.lap != _last_lap:
		_last_segment = route.segment_index
		_last_lap = route.lap
		var lap_text := "LAP %d  •  " % route.lap if route.lap > 1 else ""
		_route_name.text = "%s%s" % [lap_text, route.segment.name]
	_route_bar.value = route.progress * 100.0


func _tick_banner(dt: float) -> void:
	if _banner_time <= 0.0:
		return
	if _banner_delay > 0.0:
		_banner_delay -= dt
		_banner.visible = _banner_delay <= 0.0
		return
	_banner_time = maxf(0.0, _banner_time - dt)
	var shown := BANNER_TIME - _banner_time
	# entra in 0,25 s, resta, esce nell'ultimo mezzo secondo
	var alpha := minf(shown / 0.25, 1.0) * minf(_banner_time / 0.5, 1.0)
	_banner.modulate = Color(1.0, 1.0, 1.0, alpha)
	var s := lerpf(1.15, 1.0, minf(shown / 0.25, 1.0))
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(s, s)
	if _banner_time <= 0.0:
		_banner.visible = false


func _build_banner() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# verde dei cartelli autostradali svizzeri
	var style := UiStyle.flat(Color("1f6b3a"), 14, 18.0)
	style.border_color = Color.WHITE
	style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_banner_title = UiStyle.make_label("", 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_subtitle = UiStyle.make_label("", 24, Color(1.0, 1.0, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_banner_bonus = UiStyle.make_label("", 30, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_banner_title)
	box.add_child(_banner_subtitle)
	box.add_child(_banner_bonus)
	panel.add_child(box)

	_banner = CenterContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(panel)
	add_child(_banner)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_left = -400.0
	_banner.offset_right = 400.0
	_banner.offset_top = 130.0
	_banner.offset_bottom = 290.0
	_banner.visible = false


## Pannello ben visibile con le cacche disponibili: icone + "6/10".
func _build_ammo_panel() -> Control:
	_ammo_panel = PanelContainer.new()
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.45), 16, 10.0))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiStyle.make_label("POOP", 22, Color(1.0, 1.0, 1.0, 0.85)))
	_ammo = IconBar.new()
	_ammo.max_value = GameConfig.MAX_AMMO
	_ammo.shape = IconBar.IconShape.POOP
	_ammo.on_color = Palette.POOP
	_ammo.off_color = Color(1.0, 1.0, 1.0, 0.15)
	_ammo.icon_size = 30.0
	_ammo.gap = 4.0
	row.add_child(_ammo)
	_ammo_count = UiStyle.make_label("", 30, Color.WHITE)
	_ammo_count.custom_minimum_size = Vector2(78.0, 0.0)
	row.add_child(_ammo_count)
	_ammo_panel.add_child(row)

	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_ammo_panel)
	return holder


func _refresh_ammo(dt: float, ammo: int) -> void:
	if ammo != _last_ammo:
		if ammo > _last_ammo and _last_ammo >= 0:
			_ammo_pop = 1.0 # ricarica dalle briciole
		_last_ammo = ammo
		_ammo.set_value(ammo)
		_ammo_count.text = "%d/%d" % [ammo, GameConfig.MAX_AMMO]

	_ammo_pop = maxf(0.0, _ammo_pop - dt * 3.0)

	if ammo == 0:
		# vuoto: lampeggia in rosso
		_empty_blink += dt
		var on := fposmod(_empty_blink, 0.5) < 0.25
		_set_ammo_text_color(Palette.DANGER if on else Color.WHITE)
		_ammo_panel.modulate = Color(1.0, 0.6 if on else 1.0, 0.6 if on else 1.0)
	else:
		_empty_blink = 0.0
		_set_ammo_text_color(Palette.CRUMB if _ammo_pop > 0.0 else Color.WHITE)
		var glow := 1.0 + _ammo_pop * 0.4
		var tint := Color(glow, glow, glow)
		if _ammo_panel.modulate != tint:
			_ammo_panel.modulate = tint


## Cambia il colore solo se serve: ogni override del tema forza un nuovo layout del testo.
func _set_ammo_text_color(color: Color) -> void:
	if color == _ammo_text_color:
		return
	_ammo_text_color = color
	_ammo_count.add_theme_color_override(FONT_COLOR, color)


static func _fade_to(control: Control, alpha: float, dt: float) -> void:
	var current := control.modulate.a
	var next := move_toward(current, alpha, dt * 6.0)
	if not is_equal_approx(current, next):
		control.modulate = Color(1.0, 1.0, 1.0, next)
